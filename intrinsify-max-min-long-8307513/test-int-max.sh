#!/usr/bin/env bash

set -e -x

PROBABILITY=50 CLASS=TestIntMax PATTERN=test* COMP_ARGS=true make
PROBABILITY=80 CLASS=TestIntMax PATTERN=test* COMP_ARGS=true make
PROBABILITY=100 CLASS=TestIntMax PATTERN=test* COMP_ARGS=true make
