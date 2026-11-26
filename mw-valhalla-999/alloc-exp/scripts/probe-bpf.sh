#!/usr/bin/env bash
# Exact per-entry-point allocation counts with bpftrace uprobes (needs root + uprobes; does NOT work in
# an unprivileged container, see README). Same output/report as probe-gdb.sh, but fast enough for
# full-size runs.
# Usage: sudo [JAVA_HOME_EXP=<jdk>] scripts/probe-bpf.sh <scenario> <identity|preview> [iterations=5] [inner=1000000]
# Output: target/probe-bpf/<scenario>-<mode>.raw (+ .perf.map, .txt report, generated .bt)
set -euo pipefail
source "$(dirname "$0")/env.sh"
SCEN="$1"; MODE="$2"; ITERS="${3:-5}"; INNER="${4:-1000000}"
command -v bpftrace >/dev/null || { echo "bpftrace not installed (dnf/apt install bpftrace)" >&2; exit 1; }
[[ $EUID -eq 0 ]] || { echo "run as root: sudo $0 $*" >&2; exit 1; }
# runs as root: hand generated files back to the owner of the checkout, even on failure
trap 'chown -R --reference="$EXP_DIR" "$TARGET" 2>/dev/null || true' EXIT
[[ "$TARGET/offsets.env" -nt "$LIBJVM" ]] || "$(dirname "$0")/offsets.sh" >/dev/null   # cached: gdb needs ~80s to load debuginfo
OUTDIR="$TARGET/probe-bpf"; mkdir -p "$OUTDIR"
BT="$OUTDIR/alloc_ctx.bt"; RAW="$OUTDIR/$SCEN-$MODE.raw"
sed -e "s|@LIBJVM@|$(realpath "$LIBJVM")|g" "$EXP_DIR/probe/alloc_ctx.bt.in" > "$BT"
while IFS='=' read -r k v; do sed -i "s|@$k@|$v|g" "$BT"; done < "$TARGET/offsets.env"
grep -q '@[A-Z_]*@' "$BT" && { echo "unsubstituted placeholders in $BT" >&2; exit 1; }
# The JVM is started by bpftrace (-c) so that probes are filtered on its pid (cpid).
CMD="$JAVA $(mode_flags "$MODE") ${COMMON_FLAGS[*]} -XX:-UseTLAB -XX:+UnlockDiagnosticVMOptions \
 -XX:+DumpPerfMapAtExit -Dinner=$INNER -Dhistogram=false -cp $CLASSES ValueAllocs $SCEN $ITERS"
CMD=$(echo $CMD)   # collapse repeated spaces: bpftrace -c turns each extra space into an empty argument
bpftrace -q -o "$RAW" "$BT" -c "$CMD"
PID=$(sed -n 's/^cpid=//p' "$RAW")
mv "/tmp/perf-$PID.map" "$OUTDIR/$SCEN-$MODE.perf.map" 2>/dev/null || echo "warning: no perf map for pid $PID" >&2
python3 "$EXP_DIR/probe/probe-report.py" "$RAW" "$OUTDIR/$SCEN-$MODE.perf.map" | tee "$OUTDIR/$SCEN-$MODE.txt"
