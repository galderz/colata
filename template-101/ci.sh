#!/usr/bin/env bash

set -e -x

if [[ "$1" == "--clean=true" ]]; then
  make clean-jtreg
fi

tests=(
    # "test/hotspot/jtreg/compiler/valhalla/inlinetypes/templating/TestOne.java"
    #"test/hotspot/jtreg/compiler/valhalla/inlinetypes/templating/ExampleNoNames.java"
    #"test/hotspot/jtreg/compiler/valhalla/inlinetypes/templating/ExampleStructuralNames.java"
    #"test/hotspot/jtreg/compiler/valhalla/inlinetypes/templating/ExampleTwoBooleansNoNames.java"
    "test/hotspot/jtreg/compiler/valhalla/inlinetypes/templating/ExampleTwoLongsNoNames.java"
)

TEST="${tests[*]}" make jtreg
