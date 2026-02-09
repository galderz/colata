#!/usr/bin/env bash

set -e -x

if [[ "$1" == "--clean=true" ]]; then
  make clean-jtreg
fi

tests=(
    "test/hotspot/jtreg/compiler/valhalla/inlinetypes/TestBufferLost.java"
)

# Run individual tests first
TEST="${tests[*]}" make jtreg

# Run full valhalla testsuite
TEST=compiler/valhalla/inlinetypes make test
