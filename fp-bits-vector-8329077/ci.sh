#!/usr/bin/env bash

set -e -x

#TEST="test/hotspot/jtreg/compiler/jvmci/jdk.vm.ci.runtime.test/src/jdk/vm/ci/runtime/test/ConstantPoolTest.java" make test
#TEST="test/hotspot/jtreg/compiler/loopopts/superword/TestCompatibleUseDefTypeSize.java" make test
TEST="test/hotspot/jtreg/compiler/c2/irTests/TestVectorFPConversion.java" make test
