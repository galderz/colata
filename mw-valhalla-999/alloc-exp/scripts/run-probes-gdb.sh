#!/usr/bin/env bash
# Run the gdb stand-in probe for the scenarios shown in the README (~10 minutes in total).
set -euo pipefail
cd "$(dirname "$0")"
for sm in "cached-call identity" "cached-call preview" "flat-field preview" "fresh preview"; do
  echo "### probe-gdb $sm"
  ./probe-gdb.sh $sm > /dev/null
done
