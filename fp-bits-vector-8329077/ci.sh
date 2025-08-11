#!/usr/bin/env bash

set -e -x

TEST="test/hotspot/jtreg/compiler/loopopts/superword/TestCompatibleUseDefTypeSize.java" make test
TEST="test/hotspot/jtreg/compiler/c2/irTests/ConvF2HFIdealizationTests.java" make test
