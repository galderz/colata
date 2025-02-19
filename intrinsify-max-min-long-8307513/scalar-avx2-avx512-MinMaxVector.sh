#!/usr/bin/env bash

set -e -x

CONF=release TEST="micro:org.openjdk.bench.java.lang.MinMaxVector.long" MICRO="FORK=1;OPTIONS=-jvmArgs -XX:DisableIntrinsic=_maxL -jvmArgs -XX:-UseSuperWord" make micro
CONF=release TEST="micro:org.openjdk.bench.java.lang.MinMaxVector.long" MICRO="FORK=1;OPTIONS=-jvmArgs -XX:DisableIntrinsic=_maxL -jvmArgs -XX:-UseSuperWord -prof perfasm" make micro
CONF=release TEST="micro:org.openjdk.bench.java.lang.MinMaxVector.long" MICRO="FORK=1;OPTIONS=-jvmArgs -XX:DisableIntrinsic=_maxL -jvmArgs -XX:UseAVX=2 -jvmArgs -XX:-UseSuperWord" make micro
CONF=release TEST="micro:org.openjdk.bench.java.lang.MinMaxVector.long" MICRO="FORK=1;OPTIONS=-jvmArgs -XX:DisableIntrinsic=_maxL -jvmArgs -XX:UseAVX=2 -jvmArgs -XX:-UseSuperWord -prof perfasm" make micro

CONF=release TEST="micro:org.openjdk.bench.java.lang.MinMaxVector.long" MICRO="FORK=1;OPTIONS=-jvmArgs -XX:-UseSuperWord" make micro
CONF=release TEST="micro:org.openjdk.bench.java.lang.MinMaxVector.long" MICRO="FORK=1;OPTIONS=-jvmArgs -XX:-UseSuperWord -prof perfasm" make micro
CONF=release TEST="micro:org.openjdk.bench.java.lang.MinMaxVector.long" MICRO="FORK=1;OPTIONS=-jvmArgs -XX:UseAVX=2 -jvmArgs -XX:-UseSuperWord" make micro
CONF=release TEST="micro:org.openjdk.bench.java.lang.MinMaxVector.long" MICRO="FORK=1;OPTIONS=-jvmArgs -XX:UseAVX=2 -jvmArgs -XX:-UseSuperWord -prof perfasm" make micro
