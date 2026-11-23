#!/usr/bin/env bash
# Reproduce everything under target/:
#   target/histogram.txt                         exact Integer counts (ground truth)
#   target/{jfr-sampled,jfr-exact,ap}/*.jfr       recordings
#   target/analysis/<variant>/<scenario>-<mode>.txt   AllocAnalyzer reports
# Takes ~5 minutes.
set -euo pipefail
cd "$(dirname "$0")"
source ./env.sh
./build.sh
./histogram.sh
for s in "${SCENARIOS[@]}"; do
  for m in "${MODES[@]}"; do
    echo "### recording $s $m"
    ./record-jfr.sh "$s" "$m" sampled >/dev/null 2>&1
    ./record-jfr.sh "$s" "$m" exact   >/dev/null 2>&1
    ./record-ap.sh  "$s" "$m"         >/dev/null 2>&1
  done
done
./analyze-all.sh
echo "done: see $TARGET"
