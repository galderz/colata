#!/usr/bin/env bash

set -e -x

concat () (
    IFS=
    printf '%s' "$*"
)

tests=(
  "test/hotspot/jtreg/compiler/loopopts/superword/TestCompatibleUseDefTypeSize.java"
)

#JTREG="JAVA_OPTIONS=-XX:+PrintIdeal"
TEST="${tests[*]}" make jtreg
