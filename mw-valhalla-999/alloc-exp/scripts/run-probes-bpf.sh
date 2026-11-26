#!/usr/bin/env bash
# Run the BPF probe for the scenarios shown in the README (needs root and a kernel where BPF works,
# e.g. an isx VM instance). Usage: sudo JAVA_HOME_EXP=... [LIBJVM_DEBUGINFO=...] scripts/run-probes-bpf.sh
set -euo pipefail
cd "$(dirname "$0")"
for sm in "cached-call identity" "cached-call preview" "flat-field preview" "fresh preview"; do
  echo "### probe-bpf $sm"
  ./probe-bpf.sh $sm > /dev/null
done
