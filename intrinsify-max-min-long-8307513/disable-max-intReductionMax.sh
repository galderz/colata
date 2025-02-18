#!/usr/bin/env bash

set -e -x

# To find out method:
# CONF=release TEST="micro:lang.MinMaxVector.intReductionMax" MICRO="FORK=1;OPTIONS=-jvmArgs -XX:+PrintCompilation -v EXTRA" make micro
# ...
# 5536  487 %     4       org.openjdk.bench.java.lang.jmh_generated.MinMaxVector_intReductionMax_jmhTest::intReductionMax_thrpt_jmhStub @ 13 (59 bytes)   made not entrant

CONF=release TEST="micro:org.openjdk.bench.java.lang.MinMaxVector.intReductionSimpleMax" MICRO="FORK=1" make micro
CONF=release TEST="micro:org.openjdk.bench.java.lang.MinMaxVector.intReductionSimpleMax" MICRO="FORK=1;OPTIONS=-prof perfasm" make micro
CONF=release TEST="micro:org.openjdk.bench.java.lang.MinMaxVector.intReductionSimpleMax" MICRO="FORK=1;OPTIONS=-jvmArgs -XX:CompileCommand=option,org.openjdk.bench.java.lang.jmh_generated.MinMaxVector_intReductionSimpleMax_jmhTest::intReductionSimpleMax_thrpt_jmhStub,ccstrlist,DisableIntrinsic,_max" make micro
CONF=release TEST="micro:org.openjdk.bench.java.lang.MinMaxVector.intReductionSimpleMax" MICRO="FORK=1;OPTIONS=-jvmArgs -XX:CompileCommand=option,org.openjdk.bench.java.lang.jmh_generated.MinMaxVector_intReductionSimpleMax_jmhTest::intReductionSimpleMax_thrpt_jmhStub,ccstrlist,DisableIntrinsic,_max -prof perfasm" make micro
CONF=release TEST="micro:org.openjdk.bench.java.lang.MinMaxVector.intReductionMultiplyMax" MICRO="FORK=1" make micro
CONF=release TEST="micro:org.openjdk.bench.java.lang.MinMaxVector.intReductionMultiplyMax" MICRO="FORK=1;OPTIONS=-prof perfasm" make micro
CONF=release TEST="micro:org.openjdk.bench.java.lang.MinMaxVector.intReductionMultiplyMax" MICRO="FORK=1;OPTIONS=-jvmArgs -XX:CompileCommand=option,org.openjdk.bench.java.lang.jmh_generated.MinMaxVector_intReductionMultiplyMax_jmhTest::intReductionMultiplyMax_thrpt_jmhStub,ccstrlist,DisableIntrinsic,_max" make micro
CONF=release TEST="micro:org.openjdk.bench.java.lang.MinMaxVector.intReductionMultiplyMax" MICRO="FORK=1;OPTIONS=-jvmArgs -XX:CompileCommand=option,org.openjdk.bench.java.lang.jmh_generated.MinMaxVector_intReductionMultiplyMax_jmhTest::intReductionMultiplyMax_thrpt_jmhStub,ccstrlist,DisableIntrinsic,_max -prof perfasm" make micro
