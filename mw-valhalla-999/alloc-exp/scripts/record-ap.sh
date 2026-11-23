#!/usr/bin/env bash
# Record allocations with async-profiler in mixed-stack mode (cstack=vmx), JFR output.
# Tiered compilation stays ON: in vmx mode async-profiler labels C1 frames "C1 compiled" and C2 frames
# "JIT compiled", and records the native/stub frames between the Java code and the allocation
# (e.g. "new_instance_blob (C2 runtime)", "store_value_type_fields_to_buf_blob").
# Usage: record-ap.sh <scenario> <identity|preview> [iterations=50]
# Output: target/ap/<scenario>-<mode>.jfr
set -euo pipefail
source "$(dirname "$0")/env.sh"
SCEN="$1"; MODE="$2"; ITERS="${3:-50}"
OUTDIR="$TARGET/ap"; mkdir -p "$OUTDIR"
OUT="$OUTDIR/$SCEN-$MODE.jfr"
set -x
"$JAVA" $(mode_flags "$MODE") "${COMMON_FLAGS[@]}" \
  -agentpath:"$ASPROF_LIB"=start,event=alloc,alloc=128k,cstack=vmx,file="$OUT" \
  -cp "$CLASSES" ValueAllocs "$SCEN" "$ITERS"
