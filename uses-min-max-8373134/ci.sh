#!/usr/bin/env bash

set -e -x

if [[ "$1" == "--clean=true" ]]; then
  make clean-jtreg
fi

tests=(
    "test/hotspot/jtreg/compiler/codegen/TestBooleanVect.java"
)

TEST="${tests[*]}" JAVA_OPTIONS="-XX:VerifyIterativeGVN=1110" make jtreg
