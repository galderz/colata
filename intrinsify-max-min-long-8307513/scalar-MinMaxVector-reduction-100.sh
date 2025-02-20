#!/usr/bin/env bash

set -e -x

# Production run
# First run all with intrinsics disabled, then enabled
TEST="micro:org.openjdk.bench.java.lang.MinMaxVector.intReductionMultiplyMax"  MICRO="FORK=1;OPTIONS=-p probability=100 -jvmArgs -XX:+UnlockDiagnosticVMOptions -jvmArgs -XX:DisableIntrinsic=_max -jvmArgs -XX:-UseSuperWord" CONF=release BUILD_LOG=warn make micro
TEST="micro:org.openjdk.bench.java.lang.MinMaxVector.intReductionMultiplyMin"  MICRO="FORK=1;OPTIONS=-p probability=100 -jvmArgs -XX:+UnlockDiagnosticVMOptions -jvmArgs -XX:DisableIntrinsic=_min -jvmArgs -XX:-UseSuperWord" CONF=release BUILD_LOG=warn make micro
TEST="micro:org.openjdk.bench.java.lang.MinMaxVector.longReductionMultiplyMax" MICRO="FORK=1;OPTIONS=-p probability=100 -jvmArgs -XX:+UnlockDiagnosticVMOptions -jvmArgs -XX:DisableIntrinsic=_maxL -jvmArgs -XX:-UseSuperWord" CONF=release BUILD_LOG=warn make micro
TEST="micro:org.openjdk.bench.java.lang.MinMaxVector.longReductionMultiplyMin" MICRO="FORK=1;OPTIONS=-p probability=100 -jvmArgs -XX:+UnlockDiagnosticVMOptions -jvmArgs -XX:DisableIntrinsic=_minL -jvmArgs -XX:-UseSuperWord" CONF=release BUILD_LOG=warn make micro
TEST="micro:org.openjdk.bench.java.lang.MinMaxVector.intReductionSimpleMax"    MICRO="FORK=1;OPTIONS=-p probability=100 -jvmArgs -XX:+UnlockDiagnosticVMOptions -jvmArgs -XX:DisableIntrinsic=_max -jvmArgs -XX:-UseSuperWord" CONF=release BUILD_LOG=warn make micro
TEST="micro:org.openjdk.bench.java.lang.MinMaxVector.intReductionSimpleMin"    MICRO="FORK=1;OPTIONS=-p probability=100 -jvmArgs -XX:+UnlockDiagnosticVMOptions -jvmArgs -XX:DisableIntrinsic=_min -jvmArgs -XX:-UseSuperWord" CONF=release BUILD_LOG=warn make micro
TEST="micro:org.openjdk.bench.java.lang.MinMaxVector.longReductionSimpleMax"   MICRO="FORK=1;OPTIONS=-p probability=100 -jvmArgs -XX:+UnlockDiagnosticVMOptions -jvmArgs -XX:DisableIntrinsic=_maxL -jvmArgs -XX:-UseSuperWord" CONF=release BUILD_LOG=warn make micro
TEST="micro:org.openjdk.bench.java.lang.MinMaxVector.longReductionSimpleMin"   MICRO="FORK=1;OPTIONS=-p probability=100 -jvmArgs -XX:+UnlockDiagnosticVMOptions -jvmArgs -XX:DisableIntrinsic=_minL -jvmArgs -XX:-UseSuperWord" CONF=release BUILD_LOG=warn make micro
TEST="micro:org.openjdk.bench.java.lang.MinMaxVector.intReductionMultiplyMax"  MICRO="FORK=1;OPTIONS=-p probability=100 -jvmArgs -XX:-UseSuperWord" CONF=release BUILD_LOG=warn make micro
TEST="micro:org.openjdk.bench.java.lang.MinMaxVector.intReductionMultiplyMin"  MICRO="FORK=1;OPTIONS=-p probability=100 -jvmArgs -XX:-UseSuperWord" CONF=release BUILD_LOG=warn make micro
TEST="micro:org.openjdk.bench.java.lang.MinMaxVector.longReductionMultiplyMax" MICRO="FORK=1;OPTIONS=-p probability=100 -jvmArgs -XX:-UseSuperWord" CONF=release BUILD_LOG=warn make micro
TEST="micro:org.openjdk.bench.java.lang.MinMaxVector.longReductionMultiplyMin" MICRO="FORK=1;OPTIONS=-p probability=100 -jvmArgs -XX:-UseSuperWord" CONF=release BUILD_LOG=warn make micro
TEST="micro:org.openjdk.bench.java.lang.MinMaxVector.intReductionSimpleMax"    MICRO="FORK=1;OPTIONS=-p probability=100 -jvmArgs -XX:-UseSuperWord" CONF=release BUILD_LOG=warn make micro
TEST="micro:org.openjdk.bench.java.lang.MinMaxVector.intReductionSimpleMin"    MICRO="FORK=1;OPTIONS=-p probability=100 -jvmArgs -XX:-UseSuperWord" CONF=release BUILD_LOG=warn make micro
TEST="micro:org.openjdk.bench.java.lang.MinMaxVector.longReductionSimpleMax"   MICRO="FORK=1;OPTIONS=-p probability=100 -jvmArgs -XX:-UseSuperWord" CONF=release BUILD_LOG=warn make micro
TEST="micro:org.openjdk.bench.java.lang.MinMaxVector.longReductionSimpleMin"   MICRO="FORK=1;OPTIONS=-p probability=100 -jvmArgs -XX:-UseSuperWord" CONF=release BUILD_LOG=warn make micro

# Profiling run
# Alternatve intrinsic enable/disabled for easier capturing
TEST="micro:org.openjdk.bench.java.lang.MinMaxVector.intReductionMultiplyMax"  MICRO="FORK=1;OPTIONS=-p probability=100 -jvmArgs -XX:+UnlockDiagnosticVMOptions -jvmArgs -XX:DisableIntrinsic=_max -jvmArgs -XX:-UseSuperWord -prof perfasm" CONF=release BUILD_LOG=warn make micro
TEST="micro:org.openjdk.bench.java.lang.MinMaxVector.intReductionMultiplyMax"  MICRO="FORK=1;OPTIONS=-p probability=100 -jvmArgs -XX:-UseSuperWord -prof perfasm" CONF=release BUILD_LOG=warn make micro
TEST="micro:org.openjdk.bench.java.lang.MinMaxVector.intReductionMultiplyMin"  MICRO="FORK=1;OPTIONS=-p probability=100 -jvmArgs -XX:+UnlockDiagnosticVMOptions -jvmArgs -XX:DisableIntrinsic=_min -jvmArgs -XX:-UseSuperWord -prof perfasm" CONF=release BUILD_LOG=warn make micro
TEST="micro:org.openjdk.bench.java.lang.MinMaxVector.intReductionMultiplyMin"  MICRO="FORK=1;OPTIONS=-p probability=100 -jvmArgs -XX:-UseSuperWord -prof perfasm" CONF=release BUILD_LOG=warn make micro
TEST="micro:org.openjdk.bench.java.lang.MinMaxVector.longReductionMultiplyMax" MICRO="FORK=1;OPTIONS=-p probability=100 -jvmArgs -XX:+UnlockDiagnosticVMOptions -jvmArgs -XX:DisableIntrinsic=_maxL -jvmArgs -XX:-UseSuperWord -prof perfasm" CONF=release BUILD_LOG=warn make micro
TEST="micro:org.openjdk.bench.java.lang.MinMaxVector.longReductionMultiplyMax" MICRO="FORK=1;OPTIONS=-p probability=100 -jvmArgs -XX:-UseSuperWord -prof perfasm" CONF=release BUILD_LOG=warn make micro
TEST="micro:org.openjdk.bench.java.lang.MinMaxVector.longReductionMultiplyMin" MICRO="FORK=1;OPTIONS=-p probability=100 -jvmArgs -XX:+UnlockDiagnosticVMOptions -jvmArgs -XX:DisableIntrinsic=_minL -jvmArgs -XX:-UseSuperWord -prof perfasm" CONF=release BUILD_LOG=warn make micro
TEST="micro:org.openjdk.bench.java.lang.MinMaxVector.longReductionMultiplyMin" MICRO="FORK=1;OPTIONS=-p probability=100 -jvmArgs -XX:-UseSuperWord -prof perfasm" CONF=release BUILD_LOG=warn make micro
TEST="micro:org.openjdk.bench.java.lang.MinMaxVector.intReductionSimpleMax"    MICRO="FORK=1;OPTIONS=-p probability=100 -jvmArgs -XX:+UnlockDiagnosticVMOptions -jvmArgs -XX:DisableIntrinsic=_max -jvmArgs -XX:-UseSuperWord -prof perfasm" CONF=release BUILD_LOG=warn make micro
TEST="micro:org.openjdk.bench.java.lang.MinMaxVector.intReductionSimpleMax"    MICRO="FORK=1;OPTIONS=-p probability=100 -jvmArgs -XX:-UseSuperWord -prof perfasm" CONF=release BUILD_LOG=warn make micro
TEST="micro:org.openjdk.bench.java.lang.MinMaxVector.intReductionSimpleMin"    MICRO="FORK=1;OPTIONS=-p probability=100 -jvmArgs -XX:+UnlockDiagnosticVMOptions -jvmArgs -XX:DisableIntrinsic=_min -jvmArgs -XX:-UseSuperWord -prof perfasm" CONF=release BUILD_LOG=warn make micro
TEST="micro:org.openjdk.bench.java.lang.MinMaxVector.intReductionSimpleMin"    MICRO="FORK=1;OPTIONS=-p probability=100 -jvmArgs -XX:-UseSuperWord -prof perfasm" CONF=release BUILD_LOG=warn make micro
TEST="micro:org.openjdk.bench.java.lang.MinMaxVector.longReductionSimpleMax"   MICRO="FORK=1;OPTIONS=-p probability=100 -jvmArgs -XX:+UnlockDiagnosticVMOptions -jvmArgs -XX:DisableIntrinsic=_maxL -jvmArgs -XX:-UseSuperWord -prof perfasm" CONF=release BUILD_LOG=warn make micro
TEST="micro:org.openjdk.bench.java.lang.MinMaxVector.longReductionSimpleMax"   MICRO="FORK=1;OPTIONS=-p probability=100 -jvmArgs -XX:-UseSuperWord -prof perfasm" CONF=release BUILD_LOG=warn make micro
TEST="micro:org.openjdk.bench.java.lang.MinMaxVector.longReductionSimpleMin"   MICRO="FORK=1;OPTIONS=-p probability=100 -jvmArgs -XX:+UnlockDiagnosticVMOptions -jvmArgs -XX:DisableIntrinsic=_minL -jvmArgs -XX:-UseSuperWord -prof perfasm" CONF=release BUILD_LOG=warn make micro
TEST="micro:org.openjdk.bench.java.lang.MinMaxVector.longReductionSimpleMin"   MICRO="FORK=1;OPTIONS=-p probability=100 -jvmArgs -XX:-UseSuperWord -prof perfasm" CONF=release BUILD_LOG=warn make micro
