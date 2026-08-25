#!/usr/bin/env bash

set -e -x

if [[ "$1" == "--clean=true" ]]; then
  make clean-jtreg
fi

java_options=
if [[ "$1" == "--new-code=true" ]]; then
  java_options="-XX:+UseNewCode"
else
  java_options="-XX:-UseNewCode"
fi

# "test/hotspot/jtreg/compiler/loopopts/superword/TestReductions.java"
# "test/hotspot/jtreg/compiler/c2/TestByteArrayAddressing.java"
# "test/hotspot/jtreg/compiler/c2/TestArrayAddressing.java"
tests=(
    "test/hotspot/jtreg/compiler/c2/TestArrayAddressingUnsafe.java"
)

# Run like in base
JAVA_OPTIONS="$java_options" TEST="${tests[*]}" make jtreg jtreg-format
