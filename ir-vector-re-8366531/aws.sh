#!/usr/bin/env bash

set -e -x

sudo apt install make

make tools-apt

pushd $HOME/src
git clone https://github.com/galderz/jdk

pushd jdk
git worktree add \
  -b topic.ir-vector-re.expand-use \
  ../jdk-ir-vector-re \
  origin/topic.ir-vector-re.expand-use
popd

pushd colata/ir-vector-re-8366531

BOOT_JDK_VERSION=25 make boot-jdk
export JAVA_25_HOME=$HOME/opt/boot-java-25

BOOT_JDK_VERSION=26 make boot-jdk
export JAVA_26_HOME=$HOME/opt/boot-java-26

NO_HSDIS=true make configure build-jdk

TEST="test/hotspot/jtreg/compiler/vectorapi/reshape/TestVectorReinterpret.java" make clean-jtreg jtreg
