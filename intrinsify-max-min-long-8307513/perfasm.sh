#!/usr/bin/env bash

set -e -x

echo "### Analysis: longClippingRange avx512=on base"
CONF=release TEST="micro:lang.MinMaxVector.longClippingRange" MICRO="FORK=1;OPTIONS=-p range=100 -prof perfasm" ID=intrinsify-max-min-long.0205.base.update-master make micro

echo "### Analysis: longClippingRange avx512=on patch"
CONF=release TEST="micro:lang.MinMaxVector.longClippingRange" MICRO="FORK=1;OPTIONS=-p range=100 -prof perfasm" make micro

echo "### Analysis: longLoopMax avx512=on base"
CONF=release TEST="micro:lang.MinMaxVector.longLoopMax" MICRO="FORK=1;OPTIONS=-p probability=100 -prof perfasm" ID=intrinsify-max-min-long.0205.base.update-master make micro

echo "### Analysis: longLoopMax avx512=on patch"
CONF=release TEST="micro:lang.MinMaxVector.longLoopMax" MICRO="FORK=1;OPTIONS=-p probability=100 -prof perfasm" make micro

echo "### Analysis: longReductionMax avx512=on base"
CONF=release TEST="micro:lang.MinMaxVector.longReductionMax" MICRO="FORK=1;OPTIONS=-p probability=100 -prof perfasm" ID=intrinsify-max-min-long.0205.base.update-master make micro

echo "### Analysis: longReductionMax avx512=on patch"
CONF=release TEST="micro:lang.MinMaxVector.longReductionMax" MICRO="FORK=1;OPTIONS=-p probability=100 -prof perfasm" make micro

echo "### Analysis: longClippingRange avx512=off base"
CONF=release TEST="micro:lang.MinMaxVector.longClippingRange" MICRO="FORK=1;OPTIONS=-p range=100 -prof perfasm -jvmArgs -XX:UseAVX=2" ID=intrinsify-max-min-long.0205.base.update-master make micro

echo "### Analysis: longClippingRange avx512=off patch"
CONF=release TEST="micro:lang.MinMaxVector.longClippingRange" MICRO="FORK=1;OPTIONS=-p range=100 -prof perfasm -jvmArgs -XX:UseAVX=2" make micro

echo "### Analysis: longReductionMax avx512=off base"
CONF=release TEST="micro:lang.MinMaxVector.longReductionMax" MICRO="FORK=1;OPTIONS=-p probability=100 -prof perfasm -jvmArgs -XX:UseAVX=2" ID=intrinsify-max-min-long.0205.base.update-master make micro

echo "### Analysis: longReductionMax avx512=off patch"
CONF=release TEST="micro:lang.MinMaxVector.longReductionMax" MICRO="FORK=1;OPTIONS=-p probability=100 -prof perfasm -jvmArgs -XX:UseAVX=2" make micro

