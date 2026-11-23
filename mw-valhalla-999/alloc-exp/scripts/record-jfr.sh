#!/usr/bin/env bash
# Record allocations with the JDK's built-in JFR.
# Usage: record-jfr.sh <scenario> <identity|preview> <sampled|exact> [iterations]
#   sampled  jdk.ObjectAllocationSample (throttled to 10000/s, weight = estimated bytes). Default 50 iterations.
#   exact    -XX:-UseTLAB: every allocation takes the runtime slow path, so every allocation emits a
#            jdk.ObjectAllocationOutsideTLAB event with its stack trace. Default 3 iterations.
#            -XX:-UseTLAB only changes macro expansion (after escape analysis/scalarization), so the set
#            of allocations C2 decides to keep is unchanged.
# JIT tier: JFR cannot tell C1 from C2 frames, so by default the run uses -XX:-TieredCompilation
#   (every "JIT compiled" frame is then C2). Set TIERED=1 to keep tiered compilation.
# Output: target/jfr-<variant>/<scenario>-<mode>.jfr
set -euo pipefail
source "$(dirname "$0")/env.sh"
SCEN="$1"; MODE="$2"; VARIANT="$3"
case "$VARIANT" in
  sampled) ITERS="${4:-50}"
           EV="jdk.ObjectAllocationSample#throttle=10000/s" ; TLAB=() ;;
  exact)   ITERS="${4:-3}"
           EV="jdk.ObjectAllocationSample#enabled=false,+jdk.ObjectAllocationOutsideTLAB#enabled=true"; TLAB=(-XX:-UseTLAB) ;;
  *) echo "variant must be sampled|exact" >&2; exit 1 ;;
esac
TIER=(-XX:-TieredCompilation); [[ "${TIERED:-0}" == 1 ]] && TIER=()
OUTDIR="$TARGET/jfr-$VARIANT"; mkdir -p "$OUTDIR"
OUT="$OUTDIR/$SCEN-$MODE.jfr"
set -x
"$JAVA" $(mode_flags "$MODE") "${COMMON_FLAGS[@]}" "${TIER[@]}" "${TLAB[@]}" \
  -XX:StartFlightRecording:filename="$OUT",settings=default,$EV \
  -XX:FlightRecorderOptions:stackdepth=128 -Xlog:jfr+startup=warning \
  -cp "$CLASSES" ValueAllocs "$SCEN" "$ITERS"
