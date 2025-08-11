#!/usr/bin/env bash

set -e -x

concat () (
    IFS=
    printf '%s' "$*"
)

tests=(
  "test/hotspot/jtreg/compiler/c2/irTests/ConvF2HFIdealizationTests.java"
  "test/hotspot/jtreg/compiler/c2/irTests/TestFloat16ScalarOperations.java"
  "test/hotspot/jtreg/compiler/loopopts/superword/TestCompatibleUseDefTypeSize.java"
)

TEST="${tests[*]}" make test
