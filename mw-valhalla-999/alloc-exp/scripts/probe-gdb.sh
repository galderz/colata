#!/usr/bin/env bash
# Exact per-entry-point allocation counts using gdb breakpoints (works without BPF privileges).
# Same probe logic as the BPF script, but ~1000x slower: defaults to a small run
# (-Dinner=1000 x 300 iterations = 300k allocations, ~1-2 minutes).
# Usage: probe-gdb.sh <scenario> <identity|preview> [iterations=300] [inner=1000]
# Output: target/probe-gdb/<scenario>-<mode>.raw (+ .perf.map, .txt report)
set -euo pipefail
source "$(dirname "$0")/env.sh"
SCEN="$1"; MODE="$2"; ITERS="${3:-300}"; INNER="${4:-1000}"
[[ "$TARGET/offsets.env" -nt "$LIBJVM" ]] || "$(dirname "$0")/offsets.sh" >/dev/null   # cached: gdb needs ~80s to load debuginfo
OUTDIR="$TARGET/probe-gdb"; mkdir -p "$OUTDIR"
RAW="$OUTDIR/$SCEN-$MODE.raw"
# let gdb find libjvm.debuginfo via its .gnu_debuglink: <debug-dir>/<dir of libjvm.so>/libjvm.debuginfo
DBG="$TARGET/.debug"; mkdir -p "$DBG$(dirname "$(realpath "$LIBJVM")")"
ln -sf "$LIBJVM_DEBUGINFO" "$DBG$(dirname "$(realpath "$LIBJVM")")/libjvm.debuginfo"
rm -f /tmp/perf-*.map
PROBE_OFFSETS="$TARGET/offsets.env" PROBE_OUT="$RAW" \
timeout "${PROBE_TIMEOUT:-300}" gdb -q -batch -nx -ex "set debuginfod enabled off" -ex "set debug-file-directory $DBG" \
  -ex "set pagination off" -ex "set breakpoint pending on" \
  -ex "handle SIGSEGV SIGILL SIGBUS SIGFPE SIGUSR2 nostop noprint pass" \
  -ex "source $EXP_DIR/probe/alloc_ctx_gdb.py" -ex run \
  --args "$JAVA" $(mode_flags "$MODE") "${COMMON_FLAGS[@]}" -XX:-UseTLAB \
         -XX:+UnlockDiagnosticVMOptions -XX:+DumpPerfMapAtExit -Dinner="$INNER" -Dhistogram=false \
         -cp "$CLASSES" ValueAllocs "$SCEN" "$ITERS" > "$OUTDIR/$SCEN-$MODE.gdb.log" 2>&1
PID=$(sed -n 's/^cpid=//p' "$RAW")
cp "/tmp/perf-$PID.map" "$OUTDIR/$SCEN-$MODE.perf.map"
python3 "$EXP_DIR/probe/probe-report.py" "$RAW" "$OUTDIR/$SCEN-$MODE.perf.map" | tee "$OUTDIR/$SCEN-$MODE.txt"
