#!/usr/bin/env bash

set -e -x

CONF=release TEST="micro:lang.MinMaxVector.longClippingRange" MICRO="FORK=1;OPTIONS=-p range=100 -prof perfasm" ID=intrinsify-max-min-long.0205.base.update-master make micro
CONF=release TEST="micro:lang.MinMaxVector.longClippingRange" MICRO="FORK=1;OPTIONS=-p range=100 -prof perfasm" make micro
CONF=release TEST="micro:lang.MinMaxVector.longLoopMax" MICRO="FORK=1;OPTIONS=-p probability=100 -prof perfasm" ID=intrinsify-max-min-long.0205.base.update-master make micro
CONF=release TEST="micro:lang.MinMaxVector.longLoopMax" MICRO="FORK=1;OPTIONS=-p probability=100 -prof perfasm" make micro
CONF=release TEST="micro:lang.MinMaxVector.longReductionMax" MICRO="FORK=1;OPTIONS=-p probability=100 -prof perfasm" ID=intrinsify-max-min-long.0205.base.update-master make micro
CONF=release TEST="micro:lang.MinMaxVector.longReductionMax" MICRO="FORK=1;OPTIONS=-p probability=100 -prof perfasm" make micro
CONF=release TEST="micro:lang.MinMaxVector.longClippingRange" MICRO="FORK=1;OPTIONS=-p range=100 -prof perfasm -jvmArgs -XX:UseAVX=2" ID=intrinsify-max-min-long.0205.base.update-master make micro
CONF=release TEST="micro:lang.MinMaxVector.longClippingRange" MICRO="FORK=1;OPTIONS=-p range=100 -prof perfasm -jvmArgs -XX:UseAVX=2" make micro
CONF=release TEST="micro:lang.MinMaxVector.longReductionMax" MICRO="FORK=1;OPTIONS=-p probability=100 -prof perfasm -jvmArgs -XX:UseAVX=2" ID=intrinsify-max-min-long.0205.base.update-master make micro
CONF=release TEST="micro:lang.MinMaxVector.longReductionMax" MICRO="FORK=1;OPTIONS=-p probability=100 -prof perfasm -jvmArgs -XX:UseAVX=2" make micro
