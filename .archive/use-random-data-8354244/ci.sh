#!/usr/bin/env bash

set -e -x

TEST="test/hotspot/jtreg/compiler/loopopts/superword/MinMaxRed_Long.java" make
