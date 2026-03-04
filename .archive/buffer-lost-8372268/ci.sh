#!/usr/bin/env bash

set -e -x

if [[ "$1" == "--clean=true" ]]; then
  make clean-jtreg
fi

tests=(
    # "test/hotspot/jtreg/compiler/valhalla/inlinetypes/TestBufferLost.java"
    "test/hotspot/jtreg/compiler/valhalla/inlinetypes/TestArrayMetadata.java#xcomp"
    "test/hotspot/jtreg/compiler/valhalla/inlinetypes/TestArrays.java#id0"
)

# Run individual tests first
TEST="${tests[*]}" make jtreg

# Run full valhalla testsuite
TEST=compiler/valhalla/inlinetypes make test
