#!/usr/bin/env bash

set -e -x

CONF=release TEST="micro:compiler.VectorReduction2.NoSuperword.int" make micro
CONF=release TEST="micro:compiler.VectorReduction2.WithSuperword.int" make micro

CONF=release TEST="micro:lang.MinMaxVector.int" MICRO="FORK=1;OPTIONS=-jvmArgs -XX:UseAVX=2" make micro
CONF=release TEST="micro:lang.MinMaxVector.int" MICRO="FORK=1" make micro
