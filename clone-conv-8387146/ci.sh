#!/usr/bin/env bash

set -e -x

if [[ "$1" == "--clean=true" ]]; then
  make clean-jtreg
fi

# "test/hotspot/jtreg/compiler/loopopts/superword/TestReductions.java"
# "test/hotspot/jtreg/compiler/c2/TestByteArrayAddressing.java"
tests=(
    "test/hotspot/jtreg/compiler/c2/TestArrayAddressing.java"
)

TEST="${tests[*]}" make jtreg jtreg-format
