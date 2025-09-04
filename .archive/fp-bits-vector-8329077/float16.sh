#!/usr/bin/env bash

set -e -x

concat () (
    IFS=
    printf '%s' "$*"
)

tests=(
  "test/hotspot/jtreg/compiler/c2/irTests/ConvF2HFIdealizationTests.java"
  "test/hotspot/jtreg/compiler/c2/irTests/TestFloat16ScalarOperations.java"
  "test/hotspot/jtreg/compiler/intrinsics/float16/*"
  "test/hotspot/jtreg/compiler/vectorization/TestFloat16ToFloatConv.java"
  "test/hotspot/jtreg/compiler/vectorization/TestFloat16VectorConvChain.java"
  "test/hotspot/jtreg/compiler/vectorization/TestFloat16VectorOperations.java"
  "test/hotspot/jtreg/compiler/vectorization/TestFloatConversionsVector.java"
  "test/hotspot/jtreg/compiler/vectorization/TestFloatConversionsVectorNaN.java"
)

TEST="${tests[*]}" make jtreg
