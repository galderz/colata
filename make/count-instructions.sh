#!/usr/bin/env bash

# Usage:
#   ./count-instructions.sh assembly-output.txt
#   some-command | ./count-instructions.sh

set -euo pipefail

awk '
  /^[[:space:]]*0x[[:xdigit:]]+:/ {
      line = $0
      sub(/^[[:space:]]*0x[[:xdigit:]]+:[[:space:]]*/, "", line)

      split(line, fields, /[[:space:]]+/)
      instruction = fields[1]

      if (instruction != "") {
          counts[instruction]++
      }
  }

  END {
      for (instruction in counts) {
          printf "%-16s %d\n", instruction, counts[instruction]
      }
  }
' "${1:-/dev/stdin}" | sort -k1,1
