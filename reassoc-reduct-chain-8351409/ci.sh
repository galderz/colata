#!/usr/bin/env bash

set -e -x

if [[ "$1" == "--clean=true" ]]; then
  make clean-jtreg
fi

tests=(
    "test/hotspot/jtreg/compiler/loopopts/TestReductionReassociationForAssociativeAdds.java"
    "test/hotspot/jtreg/compiler/gcbarriers/TestMinMaxLongLoopBarrier.java"
    # "test/hotspot/jtreg/compiler/c2/Test5091921.java"
    # "test/hotspot/jtreg/compiler/codecache/TestStressCodeBuffers.java"
    # "test/hotspot/jtreg/compiler/intrinsics/sha/sanity/TestSHA1Intrinsics.java"
    # "test/hotspot/jtreg/compiler/loopopts/superword/ReductionPerf.java"
    # "test/hotspot/jtreg/compiler/vectorapi/VectorMaskLoadStoreTest.java"
    # "test/hotspot/jtreg/compiler/c2/cmove/TestFPComparison2.java"
    # "test/hotspot/jtreg/compiler/loopopts/superword/RedTest_int.java"
    # "test/hotspot/jtreg/compiler/loopopts/superword/RedTest_long.java"
)

TEST="${tests[*]}" make jtreg
