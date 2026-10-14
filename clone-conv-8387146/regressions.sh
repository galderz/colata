#!/usr/bin/env bash

set -e -x

if [[ "$1" == "--clean=true" ]]; then
  make clean-jtreg
fi

tests=(
    "test/hotspot/jtreg/compiler/c2/igvn/TestMissingCompressBitsAndExpandBitsIdeal.jtr"
    "test/hotspot/jtreg/compiler/intrinsics/TestBitShuffleOpers.jtr"
    "test/hotspot/jtreg/compiler/valhalla/valuetypes/TestMismatchHandling.jtr"
    "test/hotspot/jtreg/gc/TestGCALotAtAllSafepoints_Z.jtr"
    "test/hotspot/jtreg/compiler/gallery/TestNormalMapping_visual.jtr"
    "test/hotspot/jtreg/compiler/gallery/TestParticleLife_visual.jtr"
    "test/hotspot/jtreg/compiler/vectorapi/VectorExpressionFuzzer.jtr"
    "test/hotspot/jtreg/compiler/vectorapi/VectorStoreMaskIdentityStressTest.jtr"
)

TEST="${tests[*]}" make jtreg
