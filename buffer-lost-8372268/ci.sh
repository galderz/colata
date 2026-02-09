#!/usr/bin/env bash

set -e -x

if [[ "$1" == "--clean=true" ]]; then
  make clean-jtreg
fi

tests=(
    "test/hotspot/jtreg/compiler/valhalla/inlinetypes/TestBufferLost.java"
)

TEST="${tests[*]}" make jtreg
