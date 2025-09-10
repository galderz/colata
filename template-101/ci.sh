#!/usr/bin/env bash

set -e -x

make clean-jtreg

#TEST="test/hotspot/jtreg/compiler/valhalla/inlinetypes/templating/TestOne.java" make jtreg
TEST="test/hotspot/jtreg/compiler/valhalla/inlinetypes/templating/ExampleNoNames.java" make jtreg
TEST="test/hotspot/jtreg/compiler/valhalla/inlinetypes/templating/ExampleStructuralNames.java" make jtreg
