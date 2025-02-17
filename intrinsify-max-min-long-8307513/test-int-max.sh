#!/usr/bin/env bash

set -e -x

PATTERN=test* COMP_ARGS=true PROBABILITY=50 make
PATTERN=test* COMP_ARGS=true PROBABILITY=80 make
PATTERN=test* COMP_ARGS=true PROBABILITY=100 make
