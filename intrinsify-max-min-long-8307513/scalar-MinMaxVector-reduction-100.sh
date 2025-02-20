#!/usr/bin/env bash

set -e -x

benchmark()
{
    local profiler_opts=$1

    TEST="micro:org.openjdk.bench.java.lang.MinMaxVector.intReductionMultiplyMax"  MICRO="FORK=1;OPTIONS=-p probability=100 -jvmArgs -XX:+UnlockDiagnosticVMOptions -jvmArgs -XX:DisableIntrinsic=_max -jvmArgs -XX:-UseSuperWord $profiler_opts" CONF=release BUILD_LOG=warn make micro
    TEST="micro:org.openjdk.bench.java.lang.MinMaxVector.intReductionMultiplyMax"  MICRO="FORK=1;OPTIONS=-p probability=100 -jvmArgs -XX:-UseSuperWord $profiler_opts" CONF=release BUILD_LOG=warn make micro
    TEST="micro:org.openjdk.bench.java.lang.MinMaxVector.intReductionMultiplyMin"  MICRO="FORK=1;OPTIONS=-p probability=100 -jvmArgs -XX:+UnlockDiagnosticVMOptions -jvmArgs -XX:DisableIntrinsic=_min -jvmArgs -XX:-UseSuperWord $profiler_opts" CONF=release BUILD_LOG=warn make micro
    TEST="micro:org.openjdk.bench.java.lang.MinMaxVector.intReductionMultiplyMin"  MICRO="FORK=1;OPTIONS=-p probability=100 -jvmArgs -XX:-UseSuperWord $profiler_opts" CONF=release BUILD_LOG=warn make micro
    TEST="micro:org.openjdk.bench.java.lang.MinMaxVector.longReductionMultiplyMax" MICRO="FORK=1;OPTIONS=-p probability=100 -jvmArgs -XX:+UnlockDiagnosticVMOptions -jvmArgs -XX:DisableIntrinsic=_max -jvmArgs -XX:-UseSuperWord $profiler_opts" CONF=release BUILD_LOG=warn make micro
    TEST="micro:org.openjdk.bench.java.lang.MinMaxVector.longReductionMultiplyMax" MICRO="FORK=1;OPTIONS=-p probability=100 -jvmArgs -XX:-UseSuperWord $profiler_opts" CONF=release BUILD_LOG=warn make micro
    TEST="micro:org.openjdk.bench.java.lang.MinMaxVector.longReductionMultiplyMin" MICRO="FORK=1;OPTIONS=-p probability=100 -jvmArgs -XX:+UnlockDiagnosticVMOptions -jvmArgs -XX:DisableIntrinsic=_min -jvmArgs -XX:-UseSuperWord $profiler_opts" CONF=release BUILD_LOG=warn make micro
    TEST="micro:org.openjdk.bench.java.lang.MinMaxVector.longReductionMultiplyMin" MICRO="FORK=1;OPTIONS=-p probability=100 -jvmArgs -XX:-UseSuperWord $profiler_opts" CONF=release BUILD_LOG=warn make micro
    TEST="micro:org.openjdk.bench.java.lang.MinMaxVector.intReductionSimpleMax"    MICRO="FORK=1;OPTIONS=-p probability=100 -jvmArgs -XX:+UnlockDiagnosticVMOptions -jvmArgs -XX:DisableIntrinsic=_max -jvmArgs -XX:-UseSuperWord $profiler_opts" CONF=release BUILD_LOG=warn make micro
    TEST="micro:org.openjdk.bench.java.lang.MinMaxVector.intReductionSimpleMax"    MICRO="FORK=1;OPTIONS=-p probability=100 -jvmArgs -XX:-UseSuperWord $profiler_opts" CONF=release BUILD_LOG=warn make micro
    TEST="micro:org.openjdk.bench.java.lang.MinMaxVector.intReductionSimpleMin"    MICRO="FORK=1;OPTIONS=-p probability=100 -jvmArgs -XX:+UnlockDiagnosticVMOptions -jvmArgs -XX:DisableIntrinsic=_min -jvmArgs -XX:-UseSuperWord $profiler_opts" CONF=release BUILD_LOG=warn make micro
    TEST="micro:org.openjdk.bench.java.lang.MinMaxVector.intReductionSimpleMin"    MICRO="FORK=1;OPTIONS=-p probability=100 -jvmArgs -XX:-UseSuperWord $profiler_opts" CONF=release BUILD_LOG=warn make micro
    TEST="micro:org.openjdk.bench.java.lang.MinMaxVector.longReductionSimpleMax"   MICRO="FORK=1;OPTIONS=-p probability=100 -jvmArgs -XX:+UnlockDiagnosticVMOptions -jvmArgs -XX:DisableIntrinsic=_max -jvmArgs -XX:-UseSuperWord $profiler_opts" CONF=release BUILD_LOG=warn make micro
    TEST="micro:org.openjdk.bench.java.lang.MinMaxVector.longReductionSimpleMax"   MICRO="FORK=1;OPTIONS=-p probability=100 -jvmArgs -XX:-UseSuperWord $profiler_opts" CONF=release BUILD_LOG=warn make micro
    TEST="micro:org.openjdk.bench.java.lang.MinMaxVector.longReductionSimpleMin"   MICRO="FORK=1;OPTIONS=-p probability=100 -jvmArgs -XX:+UnlockDiagnosticVMOptions -jvmArgs -XX:DisableIntrinsic=_min -jvmArgs -XX:-UseSuperWord $profiler_opts" CONF=release BUILD_LOG=warn make micro
    TEST="micro:org.openjdk.bench.java.lang.MinMaxVector.longReductionSimpleMin"   MICRO="FORK=1;OPTIONS=-p probability=100 -jvmArgs -XX:-UseSuperWord $profiler_opts" CONF=release BUILD_LOG=warn make micro
}

benchmark ""
benchmark "-prof perfasm"
