#!/usr/bin/env bash

set -e -x

CONF=release TEST="micro:compiler.VectorReduction2.WithSuperword.longMaxSimple" MICRO="OPTIONS=-prof perfasm" ID=intrinsify-max-min-long.0205.base.update-master make micro
CONF=release TEST="micro:compiler.VectorReduction2.WithSuperword.longMaxSimple" MICRO="OPTIONS=-prof perfasm" make micro
CONF=release TEST="micro:compiler.VectorReduction2.NoSuperword.longMaxDotProduct" MICRO="OPTIONS=-prof perfasm" ID=intrinsify-max-min-long.0205.base.update-master make micro
CONF=release TEST="micro:compiler.VectorReduction2.NoSuperword.longMaxDotProduct" MICRO="OPTIONS=-prof perfasm" make micro
CONF=release TEST="micro:compiler.VectorReduction2.NoSuperword.longMaxSimple" MICRO="OPTIONS=-prof perfasm" ID=intrinsify-max-min-long.0205.base.update-master make micro
CONF=release TEST="micro:compiler.VectorReduction2.NoSuperword.longMaxSimple" MICRO="OPTIONS=-prof perfasm" make micro
