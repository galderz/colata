#!/usr/bin/env bash

set -e -x

if [[ "$1" == "--clean=true" ]]; then
  make clean-jtreg
fi

tests=(
    "test/hotspot/jtreg/compiler/loopopts/superword/TestCompatibleUseDefTypeSize.java"
)

TEST="${tests[*]}" make jtreg
