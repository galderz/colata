#!/usr/bin/env bash

set -e -x

if [[ "$1" == "--clean=true" ]]; then
  make clean-jtreg
fi

tests=(
#    "test/hotspot/jtreg/compiler/codegen/TestBooleanVect.java"
    "test/hotspot/jtreg/compiler/c2/irTests/TestMinMaxIdeal.java"
)

# TEST="${tests[*]}" JAVA_OPTIONS="-XX:VerifyIterativeGVN=1110" make jtreg jtreg-format
TEST="${tests[*]}" make jtreg jtreg-format
