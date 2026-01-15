#!/usr/bin/env bash

set -e -x

if [[ "$1" == "--clean=true" ]]; then
  make clean-jtreg
fi

#TEST="test/hotspot/jtreg/compiler/codegen/TestBooleanVect.java" JAVA_OPTIONS="-XX:VerifyIterativeGVN=1110" make jtreg

tests=(
    "test/hotspot/jtreg/compiler/igvn/TestMinMaxIdentity.java"
)

TEST="${tests[*]}" make jtreg jtreg-format
