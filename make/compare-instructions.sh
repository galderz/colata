#!/usr/bin/env bash

# Usage:
#   ./compare-instructions.sh first.log second.log
#
# DELTA is SECOND minus FIRST.

set -euo pipefail

if [[ $# -ne 2 ]]; then
    echo "Usage: $0 <first-log-file> <second-log-file>" >&2
    exit 1
fi

first_file=$1
second_file=$2

for file in "$first_file" "$second_file"; do
    if [[ ! -r "$file" ]]; then
        echo "Error: cannot read file: $file" >&2
        exit 1
    fi
done

awk -v first_name="$first_file" -v second_name="$second_file" '
function process_line(line, file_number, fields, instruction) {
    if (line !~ /^[[:space:]]*0x[[:xdigit:]]+:/) {
        return
    }

    sub(/^[[:space:]]*0x[[:xdigit:]]+:[[:space:]]*/, "", line)

    split(line, fields, /[[:space:]]+/)
    instruction = fields[1]

    if (instruction == "") {
        return
    }

    instructions[instruction] = 1

    if (file_number == 1) {
        first[instruction]++
    } else {
        second[instruction]++
    }
}

FNR == 1 {
    file_number++
}

{
    process_line($0, file_number)
}

END {
    print "FIRST : " first_name
    print "SECOND: " second_name
    print ""

    printf "%-18s %10s %10s %10s  %s\n",
           "INSTRUCTION", "FIRST", "SECOND", "DELTA", "STATUS"

    printf "%-18s %10s %10s %10s  %s\n",
           "-----------", "-----", "------", "-----", "------"

    for (instruction in instructions) {
        first_count  = first[instruction]  + 0
        second_count = second[instruction] + 0
        delta        = second_count - first_count

        if (delta == 0) {
            status = "SAME"
        } else if (first_count == 0) {
            status = "ADDED"
        } else if (second_count == 0) {
            status = "REMOVED"
        } else if (delta > 0) {
            status = "INCREASED"
        } else {
            status = "DECREASED"
        }

        printf "%-18s %10d %10d %+10d  %s\n",
               instruction,
               first_count,
               second_count,
               delta,
               status
    }
}
' "$first_file" "$second_file" |
{
    IFS= read -r first_label
    IFS= read -r second_label
    IFS= read -r blank
    IFS= read -r header
    IFS= read -r separator

    printf '%s\n%s\n\n%s\n%s\n' \
        "$first_label" \
        "$second_label" \
        "$header" \
        "$separator"

    sort -k1,1
}
