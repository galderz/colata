#!/usr/bin/env bash
# Ground truth: exact number of java.lang.Integer instances allocated per scenario and mode.
# Epsilon GC never frees memory, so the class histogram taken at exit counts every allocation.
# Usage: histogram.sh [iterations=50]      Output: target/histogram.txt
set -euo pipefail
source "$(dirname "$0")/env.sh"
ITERS="${1:-50}"
mkdir -p "$TARGET"
OUT="$TARGET/histogram.txt"
{
  printf "%-12s %-9s %15s %15s\n" scenario mode "Integer objs" "Integer bytes"
  for s in "${SCENARIOS[@]}"; do
    for m in "${MODES[@]}"; do
      line=$("$JAVA" $(mode_flags $m) "${COMMON_FLAGS[@]}" -cp "$CLASSES" ValueAllocs "$s" "$ITERS" | grep "histogram: java.lang.Integer ")
      objs=$(sed -E 's/.*instances=([0-9,]+).*/\1/' <<<"$line"); bytes=$(sed -E 's/.*bytes=([0-9,]+).*/\1/' <<<"$line")
      printf "%-12s %-9s %15s %15s\n" "$s" "$m" "$objs" "$bytes"
    done
  done
} | tee "$OUT"
