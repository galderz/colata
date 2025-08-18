#!/usr/bin/env bash

set -e -x

TEST="test/hotspot/jtreg/compiler/valhalla/inlinetypes/templating/TestOne.java" make jtreg
