#!/usr/bin/env bash
# Analyze every recording under target/{jfr-sampled,jfr-exact,ap}/ into target/analysis/<variant>/*.txt
set -euo pipefail
cd "$(dirname "$0")"
source ./env.sh
for v in jfr-sampled jfr-exact ap; do
  mkdir -p "$TARGET/analysis/$v"
  for s in "${SCENARIOS[@]}"; do
    for m in "${MODES[@]}"; do
      [[ -f "$TARGET/$v/$s-$m.jfr" ]] || continue
      echo "### analyzing $v/$s-$m"
      ./analyze.sh "$TARGET/$v/$s-$m.jfr" --top 3 > "$TARGET/analysis/$v/$s-$m.txt" 2>&1
    done
  done
done
