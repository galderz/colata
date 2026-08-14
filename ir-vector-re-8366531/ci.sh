#!/usr/bin/env bash

set -e -x

if [[ "$1" == "--clean=true" ]]; then
  make clean-jtreg
fi

tests=(
    "test/hotspot/jtreg/compiler/loopopts/superword/TestCompatibleUseDefTypeSize.java"
    "test/hotspot/jtreg/compiler/loopopts/superword/TestReinterpretAndCast.java"
    "test/hotspot/jtreg/compiler/vectorapi/reshape/TestVectorReinterpret.java"
)

JAVA_OPTIONS="-XX:UseAVX=1" TEST="${tests[*]}" make jtreg
TEST="${tests[*]}" make jtreg
