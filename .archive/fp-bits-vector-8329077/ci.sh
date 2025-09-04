#!/usr/bin/env bash

set -e -x

JAVA_HOME=$(make -q print-java-home)
JDK_HOME=$(make -q print-jdk-home)
JTREG_BIN=$(make -q print-jtreg-bin)

tests=(
  "test/hotspot/jtreg/compiler/loopopts/superword/TestCompatibleUseDefTypeSize.java"
)

make test-image

pushd ${JDK_HOME}
if [ "$(uname)" = "Linux" ]; then
    JAVA_HOME=${JAVA_HOME} ${JTREG_BIN} -verbose:all -vmoption:-XX:UseAVX=1 ${tests[*]}
fi
JAVA_HOME=${JAVA_HOME} ${JTREG_BIN} -verbose:all ${tests[*]}
popd
