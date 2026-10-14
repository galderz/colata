#!/usr/bin/env bash

set -e -x

if [[ "$1" == "--clean=true" ]]; then
  make clean-jtreg
fi

tests=(
    "test/hotspot/jtreg/compiler/c2/igvn/TestMissingCompressBitsAndExpandBitsIdeal.java"
    "test/hotspot/jtreg/compiler/intrinsics/TestBitShuffleOpers.java"
    "test/hotspot/jtreg/compiler/valhalla/valuetypes/TestMismatchHandling.java"
    "test/hotspot/jtreg/gc/TestGCALotAtAllSafepoints.java"
    "test/hotspot/jtreg/compiler/gallery/TestNormalMapping.java"
    "test/hotspot/jtreg/compiler/gallery/TestParticleLife.java"
    "test/hotspot/jtreg/compiler/vectorapi/VectorExpressionFuzzer.java"
    "test/hotspot/jtreg/compiler/vectorapi/VectorStoreMaskIdentityStressTest.java"
)

TEST="${tests[*]}" make jtreg
