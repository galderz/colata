#!/usr/bin/env bash

set -ex

list=$(find "src" -mindepth 1 -type d -print \
  | xargs -n 1 basename \
  | sed '1d' \
  | paste -sd ' ')

GEN=${list} make gen

for dir in src/*/ ; do
    GEN="$(basename "$dir")" make run-gen
done
