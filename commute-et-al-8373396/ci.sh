#!/usr/bin/env bash

set -e -x

if [[ "$1" == "--clean=true" ]]; then
  make clean-jtreg
fi

tests=(
    "test/hotspot/jtreg/compiler/c2/irTests/TestMinMaxIdeal.java"
)

TEST="${tests[*]}" make jtreg jtreg-format
