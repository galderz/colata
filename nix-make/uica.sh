#!/usr/bin/env bash
set -eux

DIR=$1

for asmfile in "${DIR}"/*.asm; do
    base="${asmfile%.asm}"   # strip .asm extension
    echo "Assembling $asmfile → ${base}.o"
    as "${asmfile}" -o "${base}.o"
    ./uiCA.py "${base}.o" -arch CLX -trace ${base}.html
done
