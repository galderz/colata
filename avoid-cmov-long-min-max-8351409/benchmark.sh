#!/usr/bin/env bash

set -eux

benchmark_all()
{
    local branch=$1
    local extra_args=$2

    pushd $HOME/1/jdk-avoid-cmov-long-min-max
    git checkout ${branch}
    popd

    local class="micro:org.openjdk.bench.java.lang.MinMaxVector"
    local micro_args="OPTIONS=-p probability=100 -jvmArgs -XX:-UseSuperWord"

    log TEST=\"${class}.longReductionMultiplyMax\" MICRO=\"${micro_args} ${extra_args}\" CONF=release BUILD_LOG=warn make test
    log TEST=\"${class}.longReductionSimpleMax\" MICRO=\"${micro_args} ${extra_args}\" CONF=release BUILD_LOG=warn make test
}

log()
{
    echo "$*"
    eval "$*"
}

benchmark_all "topic.avoid-cmov-long-min-max.0327.cmov" ""
benchmark_all "topic.avoid-cmov-long-min-max.0327.branch-always" ""
benchmark_all "topic.avoid-cmov-long-min-max.0327.branch-never" ""

if [ "$(uname)" = "Darwin" ]; then
  PROFILER="xctraceasm"
else
  PROFILER="perfasm"
fi

benchmark_all "topic.avoid-cmov-long-min-max.0327.cmov" "-prof $PROFILER;FORK=1"
benchmark_all "topic.avoid-cmov-long-min-max.0327.branch-always" "-prof $PROFILER;FORK=1"
benchmark_all "topic.avoid-cmov-long-min-max.0327.branch-never" "-prof $PROFILER;FORK=1"
