#!/usr/bin/env bash

set -e -x

concat () (
    IFS=
    printf '%s' "$*"
)

tests=(
  "test/hotspot/jtreg/compiler/loopopts/superword/TestCompatibleUseDefTypeSize.java"
)

TEST="${tests[*]}" JTREG="JAVA_OPTIONS=-XX:UseAVX=1" make jtreg
TEST="${tests[*]}" make jtreg
