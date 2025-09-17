#!/usr/bin/env bash

set -ex

benchmark()
{
    local gen=$1

    GEN=${gen} make gen
    GEN=${gen} make run-gen
    GEN=${gen} ASM_ARGS=true make run-gen
}

BRANCH=topic.avoid-cmov-long-min-max.base make checkout

benchmark Base
benchmark Unroll2
benchmark Reassoc2
benchmark Unroll4
benchmark Reassoc4
benchmark Unroll8
benchmark Reassoc8
benchmark Unroll16
benchmark Reassoc16
