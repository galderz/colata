#!/usr/bin/env bash
# Bisect bpftrace problems with the allocation probe: runs increasingly complete bpftrace programs
# against a small ValueAllocs run and records, for each step, the program, stdout/stderr and exit code.
# A step that crashes bpftrace (exit 139 = SIGSEGV) is re-run under gdb to capture a backtrace.
#
# Usage: sudo JAVA_HOME_EXP=... scripts/bpf-smoke.sh [first-step=0] [last-step=7]
# Output: target/probe-bpf/smoke/step<N>.{bt,out,err,gdb.txt} and target/probe-bpf/smoke/summary.txt
set -uo pipefail
source "$(dirname "$0")/env.sh"
[[ $EUID -eq 0 ]] || { echo "run as root: sudo JAVA_HOME_EXP=$JAVA_HOME $0 $*" >&2; exit 1; }
command -v bpftrace >/dev/null || { echo "bpftrace not installed" >&2; exit 1; }
trap 'chown -R --reference="$EXP_DIR" "$TARGET" 2>/dev/null || true' EXIT
FIRST="${1:-0}"; LAST="${2:-7}"
[[ "$TARGET/offsets.env" -nt "$LIBJVM" ]] || "$(dirname "$0")/offsets.sh" >/dev/null
source "$TARGET/offsets.env"
[[ -d "$CLASSES" ]] || "$(dirname "$0")/build.sh" >/dev/null
OUT="$TARGET/probe-bpf/smoke"; mkdir -p "$OUT"
LIB="$(realpath "$LIBJVM")"
ALLOC=_ZN13InstanceKlass17allocate_instanceEP10JavaThread
NEWC2=_ZN11OptoRuntime14new_instance_CEP5KlassP10JavaThread
# small workload: 2 x 200k iterations, every allocation through the runtime (-XX:-UseTLAB)
CMD="$JAVA --enable-preview ${COMMON_FLAGS[*]} -XX:-UseTLAB -XX:+UnlockDiagnosticVMOptions -XX:+DumpPerfMapAtExit \
 -Dinner=200000 -Dhistogram=false -cp $CLASSES ValueAllocs cached-call 2"

step_program() {
  case "$1" in
    0) cat <<EOF
// 0: bpftrace works at all
BEGIN { printf("hello\n"); exit(); }
EOF
    ;;
    1) cat <<EOF
// 1: one uprobe on libjvm.so by mangled symbol name, no filter
uprobe:$LIB:$ALLOC { @n = count(); }
EOF
    ;;
    2) cat <<EOF
// 2: + pid filter on the child started with -c
uprobe:$LIB:$ALLOC /pid == cpid/ { @n = count(); }
EOF
    ;;
    3) cat <<EOF
// 3: + user memory reads (Klass* -> Symbol*), fixed-length str()
uprobe:$LIB:$ALLOC /pid == cpid/ {
  \$sym = *(uint64 *)(arg0 + $KLASS_NAME);
  @len[*(uint16 *)(\$sym + $SYMBOL_LENGTH)] = count();
  @cls[str(\$sym + $SYMBOL_BODY, 32)] = count();
}
EOF
    ;;
    4) cat <<EOF
// 4: + variable-length str() (length read from user memory)
uprobe:$LIB:$ALLOC /pid == cpid/ {
  \$sym = *(uint64 *)(arg0 + $KLASS_NAME);
  @cls[str(\$sym + $SYMBOL_BODY, *(uint16 *)(\$sym + $SYMBOL_LENGTH))] = count();
}
EOF
    ;;
    5) cat <<EOF
// 5: + one uprobe/uretprobe context pair and a string-valued per-thread map
uprobe:$LIB:$NEWC2 /pid == cpid/ { @ctx[tid] = "C2  OptoRuntime::new_instance_C"; }
uretprobe:$LIB:$NEWC2 /pid == cpid/ { delete(@ctx[tid]); }
uprobe:$LIB:$ALLOC /pid == cpid/ {
  \$ctx = @ctx[tid];
  if (\$ctx == "") { \$ctx = "VM  other runtime path"; }
  @alloc[\$ctx] = count();
}
END { clear(@ctx); }
EOF
    ;;
    6) cat <<EOF
// 6: + C2 return pc read through JavaThread::_anchor._last_Java_sp
uprobe:$LIB:$NEWC2 /pid == cpid/ { @ctx[tid] = "C2  OptoRuntime::new_instance_C"; }
uretprobe:$LIB:$NEWC2 /pid == cpid/ { delete(@ctx[tid]); }
uprobe:$LIB:$ALLOC /pid == cpid/ {
  if (@ctx[tid] != "") {
    @c2_site[*(uint64 *)(*(uint64 *)(arg1 + $THREAD_LAST_JAVA_SP) + 8)] = count();
  }
}
END { clear(@ctx); printf("cpid=%d\n", cpid); }
EOF
    ;;
    7) # 7: the complete generated program used by probe-bpf.sh
       sed -e "s|@LIBJVM@|$LIB|g" -e "s|@KLASS_NAME@|$KLASS_NAME|g" -e "s|@SYMBOL_LENGTH@|$SYMBOL_LENGTH|g" \
           -e "s|@SYMBOL_BODY@|$SYMBOL_BODY|g" -e "s|@THREAD_LAST_JAVA_SP@|$THREAD_LAST_JAVA_SP|g" \
           "$EXP_DIR/probe/alloc_ctx.bt.in"
    ;;
  esac
}

{
  echo "date:      $(date -Is)"
  echo "kernel:    $(uname -r)"
  echo "bpftrace:  $(bpftrace --version 2>&1)"
  echo "java:      $("$JAVA" -version 2>&1 | tail -1)"
  echo "libjvm:    $LIB"
  echo "offsets:   KLASS_NAME=$KLASS_NAME SYMBOL_LENGTH=$SYMBOL_LENGTH SYMBOL_BODY=$SYMBOL_BODY THREAD_LAST_JAVA_SP=$THREAD_LAST_JAVA_SP"
} > "$OUT/summary.txt"
bpftrace --info > "$OUT/bpftrace-info.txt" 2>&1 || true

for n in $(seq "$FIRST" "$LAST"); do
  step_program "$n" > "$OUT/step$n.bt"
  if [[ $n == 0 ]]; then run=(bpftrace "$OUT/step$n.bt"); else run=(bpftrace "$OUT/step$n.bt" -c "$CMD"); fi
  timeout 300 "${run[@]}" > "$OUT/step$n.out" 2> "$OUT/step$n.err"
  rc=$?
  status=ok; [[ $rc -ne 0 ]] && status="FAILED (exit $rc)"
  [[ $rc -eq 139 ]] && status="CRASHED (SIGSEGV)"
  [[ $rc -eq 124 ]] && status="TIMEOUT"
  printf "step %d: %-20s %s\n" "$n" "$status" "$(head -1 "$OUT/step$n.bt")" | tee -a "$OUT/summary.txt"
  if [[ $rc -eq 139 ]] && command -v gdb >/dev/null; then
    timeout 300 gdb -q -batch -nx -ex "set debuginfod enabled on" -ex run -ex "bt 40" -ex "info sharedlibrary" \
      --args "${run[@]}" > "$OUT/step$n.gdb.txt" 2>&1 || true
    echo "        backtrace: $OUT/step$n.gdb.txt" | tee -a "$OUT/summary.txt"
  fi
done
echo "results in $OUT (send the whole directory)"
