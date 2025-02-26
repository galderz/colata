#!/usr/bin/env bash

set -e -x

# Production run
# First run all with intrinsics disabled, then enabled
TEST="micro:org.openjdk.bench.java.lang.MinMaxVector.longLoopMax" MICRO="FORK=1;OPTIONS=-p probability=100 -jvmArgs -XX:+UnlockDiagnosticVMOptions -jvmArgs -XX:DisableIntrinsic=_maxL -jvmArgs -XX:-UseSuperWord" CONF=release BUILD_LOG=warn make micro
TEST="micro:org.openjdk.bench.java.lang.MinMaxVector.longLoopMax" MICRO="FORK=1;OPTIONS=-p probability=100 -jvmArgs -XX:UseAVX=2" CONF=release BUILD_LOG=warn make micro
TEST="micro:org.openjdk.bench.java.lang.MinMaxVector.longLoopMin" MICRO="FORK=1;OPTIONS=-p probability=100 -jvmArgs -XX:+UnlockDiagnosticVMOptions -jvmArgs -XX:DisableIntrinsic=_minL -jvmArgs -XX:-UseSuperWord" CONF=release BUILD_LOG=warn make micro
TEST="micro:org.openjdk.bench.java.lang.MinMaxVector.longLoopMin" MICRO="FORK=1;OPTIONS=-p probability=100 -jvmArgs -XX:UseAVX=2" CONF=release BUILD_LOG=warn make micro

# Profiling run
# Alternatve intrinsic enable/disabled for easier capturing
TEST="micro:org.openjdk.bench.java.lang.MinMaxVector.longLoopMax" MICRO="FORK=1;OPTIONS=-p probability=100 -jvmArgs -XX:+UnlockDiagnosticVMOptions -jvmArgs -XX:DisableIntrinsic=_maxL -jvmArgs -XX:-UseSuperWord -prof perfasm" CONF=release BUILD_LOG=warn make micro
TEST="micro:org.openjdk.bench.java.lang.MinMaxVector.longLoopMax" MICRO="FORK=1;OPTIONS=-p probability=100 -jvmArgs -XX:UseAVX=2 -prof perfasm" CONF=release BUILD_LOG=warn make micro
TEST="micro:org.openjdk.bench.java.lang.MinMaxVector.longLoopMin" MICRO="FORK=1;OPTIONS=-p probability=100 -jvmArgs -XX:+UnlockDiagnosticVMOptions -jvmArgs -XX:DisableIntrinsic=_minL -jvmArgs -XX:-UseSuperWord -prof perfasm" CONF=release BUILD_LOG=warn make micro
TEST="micro:org.openjdk.bench.java.lang.MinMaxVector.longLoopMin" MICRO="FORK=1;OPTIONS=-p probability=100 -jvmArgs -XX:UseAVX=2 -prof perfasm" CONF=release BUILD_LOG=warn make micro
