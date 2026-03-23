#!/usr/bin/env bash

set -e -x

if [[ "$1" == "--clean=true" ]]; then
  make clean-jtreg
fi

tests=(
    "test/hotspot/jtreg/compiler/c2/TestFindNode.java"
)

JAVA_OPTIONS='-XX:+UnlockDiagnosticVMOptions -XX:-TieredCompilation -XX:+StressArrayCopyMacroNode -XX:+StressLCM -XX:+StressGCM -XX:+StressIGVN -XX:+StressCCP -XX:+StressMacroExpansion -XX:+StressMethodHandleLinkerInlining -XX:+StressCompiledExceptionHandlers -XX:CompileCommand=memlimit,*.*,1G~crash -XX:CompileCommand=memstat,*::*,print'

TEST="${tests[*]}" JAVA_OPTIONS=${JAVA_OPTIONS} make jtreg
