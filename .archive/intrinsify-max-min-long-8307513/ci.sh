#!/usr/bin/env bash

set -e -x

TEST="test/hotspot/jtreg/compiler/loopopts/superword/MinMaxRed_Long.java" make test
TEST="test/hotspot/jtreg/compiler/c2/irTests/TestMinMaxIdentities.java" make test
TEST="test/hotspot/jtreg/compiler/intrinsics/math/TestMinMaxInlining.java" make test
