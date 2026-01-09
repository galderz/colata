#!/usr/bin/env bash

set -e -x

TEST="micro:org.openjdk.bench.java.lang.MinMaxVector.long" MICRO="FORK=1;OPTIONS=-jvmArgs -XX:+UnlockDiagnosticVMOptions -jvmArgs -XX:DisableIntrinsic=_maxL,_minL -jvmArgs -XX:-UseSuperWord" CONF=release BUILD_LOG=warn make micro
TEST="micro:org.openjdk.bench.java.lang.MinMaxVector.long" MICRO="FORK=1;OPTIONS=-jvmArgs -XX:+UnlockDiagnosticVMOptions -jvmArgs -XX:DisableIntrinsic=_maxL,_minL -jvmArgs -XX:-UseSuperWord -prof perfasm" CONF=release BUILD_LOG=warn make micro
TEST="micro:org.openjdk.bench.java.lang.MinMaxVector.long" MICRO="FORK=1;OPTIONS=-jvmArgs -XX:+UnlockDiagnosticVMOptions -jvmArgs -XX:DisableIntrinsic=_maxL,_minL -jvmArgs -XX:UseAVX=2 -jvmArgs -XX:-UseSuperWord" CONF=release BUILD_LOG=warn make micro
TEST="micro:org.openjdk.bench.java.lang.MinMaxVector.long" MICRO="FORK=1;OPTIONS=-jvmArgs -XX:+UnlockDiagnosticVMOptions -jvmArgs -XX:DisableIntrinsic=_maxL,_minL -jvmArgs -XX:UseAVX=2 -jvmArgs -XX:-UseSuperWord -prof perfasm" CONF=release BUILD_LOG=warn make micro

TEST="micro:org.openjdk.bench.java.lang.MinMaxVector.long" MICRO="FORK=1;OPTIONS=-jvmArgs -XX:-UseSuperWord" CONF=release BUILD_LOG=warn make micro
TEST="micro:org.openjdk.bench.java.lang.MinMaxVector.long" MICRO="FORK=1;OPTIONS=-jvmArgs -XX:-UseSuperWord -prof perfasm" CONF=release BUILD_LOG=warn make micro
TEST="micro:org.openjdk.bench.java.lang.MinMaxVector.long" MICRO="FORK=1;OPTIONS=-jvmArgs -XX:UseAVX=2 -jvmArgs -XX:-UseSuperWord" CONF=release BUILD_LOG=warn make micro
TEST="micro:org.openjdk.bench.java.lang.MinMaxVector.long" MICRO="FORK=1;OPTIONS=-jvmArgs -XX:UseAVX=2 -jvmArgs -XX:-UseSuperWord -prof perfasm" CONF=release BUILD_LOG=warn make micro
