#!/usr/bin/env bash

set -e -x

TEST="test/hotspot/jtreg/compiler/loopopts/superword/TestCompatibleUseDefTypeSize.java" make test
