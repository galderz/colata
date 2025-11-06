#!/usr/bin/env bash

set -ex

for dir in src/*/ ; do
    GEN="$(basename "$dir")" make gen
done
