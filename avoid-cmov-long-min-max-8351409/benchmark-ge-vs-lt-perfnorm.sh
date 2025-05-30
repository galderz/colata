#!/usr/bin/env bash

set -ex

CLEAN="true"

ASM_PROFILER="perfasm"
NORM_PROFILER="perfnorm"

# Check for clean parameter
if [[ "$1" == "--clean=false" ]]; then
    read -p "Are you sure you want to run without cleaning first? (yes/no): " RESPONSE
    if [[ "$RESPONSE" == "yes" ]]; then
        CLEAN="false"
    else
        echo "Exiting because you don't want to apply the changes."
        exit 1
    fi
fi

benchmark_all()
{
    local branch=$1
    local extra_args=$2

    local test="micro:org.openjdk.bench.java.lang.MinMaxVector.longReductionMultiplyMax"
    local micro_args="OPTIONS=-p probability=100 -jvmArgs -XX:-UseSuperWord"

    log TEST=\"${test}\" MICRO=\"${micro_args} ${extra_args}\" CONF=release BUILD_LOG=warn make test
}

benchmark_branch()
{
    local branch=$1

    pushd $HOME/src/jdk-avoid-cmov-long-min-max
    git checkout ${branch}
    popd

    # Tracking regression needs to
    if [[ $CLEAN == "true" ]]; then
        CONF=release BUILD_LOG=warn make configure clean-jdk build-jdk
    fi

    benchmark_all ${branch} "-prof $NORM_PROFILER:events=${PERF_EVENTS};FORK=1"
    benchmark_all ${branch} "-prof $ASM_PROFILER;FORK=1"
}

log()
{
    echo "$*"
    eval "$*"
}

benchmark_branch "topic.avoid-cmov-long-min-max.0408.branch-never-ge"
benchmark_branch "topic.avoid-cmov-long-min-max.0408.branch-never-lt"
