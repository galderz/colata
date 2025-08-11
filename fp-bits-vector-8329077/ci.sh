#!/usr/bin/env bash

set -e -x

tests=\
  "test/hotspot/jtreg/compiler/c2/irTests/ConvF2HFIdealizationTests.java"\
  "test/hotspot/jtreg/compiler/c2/irTests/TestFloat16ScalarOperations.java"\
  "test/hotspot/jtreg/compiler/loopopts/superword/TestCompatibleUseDefTypeSize.java"

TEST="$(printf '"%s" ' "$tests")" make test
