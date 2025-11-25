#!/usr/bin/env bash

set -e -x

if [[ "$1" == "--clean=true" ]]; then
  make clean-jtreg
fi

tests=(
    # "test/hotspot/jtreg/compiler/loopopts/superword/ReductionPerf.java"
    # "test/hotspot/jtreg/compiler/c2/irTests/TestIfMinMax.java"
    # "test/hotspot/jtreg/compiler/c2/irTests/TestReductionReassociation.java"
    # "test/hotspot/jtreg/compiler/c2/irTests/TestReductionReassociationManual.java"
    "test/hotspot/jtreg/compiler/loopopts/TestReductionReassociationFuzzer.java"
    "test/hotspot/jtreg/compiler/loopopts/TestReductionReassociation.java"
)

TEST="${tests[*]}" make jtreg
