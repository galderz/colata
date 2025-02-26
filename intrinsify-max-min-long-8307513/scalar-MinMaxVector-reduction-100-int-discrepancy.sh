#!/usr/bin/env bash

set -e -x

if [ "$(uname)" = "Darwin" ]; then
  PROFILER="xctraceasm"
else
  PROFILER="perfasm"
fi

# Profiling run
# Alternate intrinsic enable/disabled for easier capturing
TEST="micro:org.openjdk.bench.java.lang.MinMaxVector.intReductionMultiplyMin"  MICRO="FORK=1;OPTIONS=-p probability=100 -jvmArgs -XX:+UnlockDiagnosticVMOptions -jvmArgs -XX:DisableIntrinsic=_min -jvmArgs -XX:-UseSuperWord -prof ${PROFILER}" CONF=release BUILD_LOG=warn make micro
TEST="micro:org.openjdk.bench.java.lang.MinMaxVector.intReductionMultiplyMin"  MICRO="FORK=1;OPTIONS=-p probability=100 -jvmArgs -XX:-UseSuperWord -prof ${PROFILER}" CONF=release BUILD_LOG=warn make micro
TEST="micro:org.openjdk.bench.java.lang.MinMaxVector.intReductionSimpleMin"    MICRO="FORK=1;OPTIONS=-p probability=100 -jvmArgs -XX:+UnlockDiagnosticVMOptions -jvmArgs -XX:DisableIntrinsic=_min -jvmArgs -XX:-UseSuperWord -prof ${PROFILER}" CONF=release BUILD_LOG=warn make micro
TEST="micro:org.openjdk.bench.java.lang.MinMaxVector.intReductionSimpleMin"    MICRO="FORK=1;OPTIONS=-p probability=100 -jvmArgs -XX:-UseSuperWord -prof ${PROFILER}" CONF=release BUILD_LOG=warn make micro

# Production run
# First run all with intrinsics disabled, then enabled
TEST="micro:org.openjdk.bench.java.lang.MinMaxVector.intReductionMultiplyMin"  MICRO="FORK=1;OPTIONS=-p probability=100 -jvmArgs -XX:+UnlockDiagnosticVMOptions -jvmArgs -XX:DisableIntrinsic=_min -jvmArgs -XX:-UseSuperWord" CONF=release BUILD_LOG=warn make micro
TEST="micro:org.openjdk.bench.java.lang.MinMaxVector.intReductionSimpleMin"    MICRO="FORK=1;OPTIONS=-p probability=100 -jvmArgs -XX:+UnlockDiagnosticVMOptions -jvmArgs -XX:DisableIntrinsic=_min -jvmArgs -XX:-UseSuperWord" CONF=release BUILD_LOG=warn make micro
TEST="micro:org.openjdk.bench.java.lang.MinMaxVector.intReductionMultiplyMin"  MICRO="FORK=1;OPTIONS=-p probability=100 -jvmArgs -XX:-UseSuperWord" CONF=release BUILD_LOG=warn make micro
TEST="micro:org.openjdk.bench.java.lang.MinMaxVector.intReductionSimpleMin"    MICRO="FORK=1;OPTIONS=-p probability=100 -jvmArgs -XX:-UseSuperWord" CONF=release BUILD_LOG=warn make micro
