#!/usr/bin/env bash

set -e -x

CONF=release TEST="micro:compiler.VectorReduction2.WithSuperword.intMaxSimple" MICRO="OPTIONS=-prof perfasm" make micro
CONF=release TEST="micro:compiler.VectorReduction2.NoSuperword.intMaxDotProduct" MICRO="OPTIONS=-prof perfasm" make micro
CONF=release TEST="micro:compiler.VectorReduction2.NoSuperword.intMaxSimple" MICRO="OPTIONS=-prof perfasm" make micro

CONF=release TEST="micro:lang.MinMaxVector.intClippingRange" MICRO="FORK=1;OPTIONS=-p range=100 -prof perfasm" make micro
CONF=release TEST="micro:lang.MinMaxVector.intLoopMax" MICRO="FORK=1;OPTIONS=-p probability=100 -prof perfasm" make micro
CONF=release TEST="micro:lang.MinMaxVector.intReductionMax" MICRO="FORK=1;OPTIONS=-p probability=100 -prof perfasm" make micro
CONF=release TEST="micro:lang.MinMaxVector.intClippingRange" MICRO="FORK=1;OPTIONS=-p range=100 -prof perfasm -jvmArgs -XX:UseAVX=2" make micro
CONF=release TEST="micro:lang.MinMaxVector.intLoopMax" MICRO="FORK=1;OPTIONS=-p probability=100 -prof perfasm -jvmArgs -XX:UseAVX=2" make micro
CONF=release TEST="micro:lang.MinMaxVector.intReductionMax" MICRO="FORK=1;OPTIONS=-p probability=100 -prof perfasm -jvmArgs -XX:UseAVX=2" make micro
