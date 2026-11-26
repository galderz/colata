#!/usr/bin/env bash
# Reproduce everything under target/:
#   target/histogram.txt                         exact Integer counts (ground truth)
#   target/{jfr-sampled,jfr-exact,ap}/*.jfr       recordings
#   target/analysis/<variant>/<scenario>-<mode>.txt   AllocAnalyzer reports
#   target/probe-bpf/*.txt or target/probe-gdb/*.txt  per-HotSpot-entry-point counts (run-probes.sh:
#                                                BPF if it works here, else gdb; PROBES=bpf|gdb|none)
# Takes ~3 minutes with the BPF probe, ~8-13 minutes with the gdb fallback.
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
./run-probes.sh
echo "done: see $TARGET"
