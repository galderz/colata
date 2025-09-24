#!/usr/bin/env bash

set -ex

benchmark()
{
    local gen=$1

    GEN=${gen} make gen
    GEN=${gen} NO_UNROLL=true make run-gen
    GEN=${gen} NO_UNROLL=true ASM_ARGS=true make run-gen
}

BRANCH=topic.avoid-cmov-long-min-max.base make checkout

benchmark Unroll16
benchmark Reassoc4x4
benchmark ReTree4x4
benchmark ReTree8x2
benchmark ReTree16x1

#benchmark Unroll16
#benchmark Reassoc16
#benchmark Reassoc8x2
#benchmark Reassoc4x4
#benchmark Reassoc2x8

#benchmark Unroll2
#benchmark Reassoc2
#benchmark Unroll4
#benchmark Reassoc4
#benchmark Unroll8
#benchmark Reassoc8
#benchmark Unroll16
