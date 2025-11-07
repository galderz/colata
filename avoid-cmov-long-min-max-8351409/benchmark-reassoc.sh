#!/usr/bin/env bash

set -ex

CLEAN="false"

ASM_PROFILER="perfasm"

# Check for clean parameter
if [[ "$1" == "--clean=true" ]]; then
    read -p "Are you sure you want to clean first? (yes/no): " RESPONSE
    if [[ "$RESPONSE" == "yes" ]]; then
        CLEAN="true"
    else
        echo "Exiting because you don't want to apply the changes."
        exit 1
    fi
fi

benchmark_branch()
{
    local branch=$1
    local rff_prefix=$2
    local prefix="micro:org\.openjdk\.bench\.java\.lang\.MinMaxVector\.longReduction"
    local micro_args="OPTIONS=-p probability=100 -jvmArgs -XX:-UseSuperWord -rff ${rff_prefix}-mmv.csv;FORK=1"

    pushd $HOME/src/jdk-avoid-cmov-long-min-max
    git checkout ${branch}
    popd

    # Tracking regression needs to
    if [[ $CLEAN == "true" ]]; then
        CONF=release BUILD_LOG=warn make configure clean-jdk build-jdk
    fi

    # log TEST=\"${prefix}\\\(?:Simple\\\|Multiply\\\)Max\" MICRO=\"${micro_args} ${extra_args} -prof $ASM_PROFILER;FORK=1\" CONF=release LOG=warn make test
    log TEST=\"${prefix}\\\(?:Simple\\\|Multiply\\\)Max\" MICRO=\"${micro_args}\" CONF=release LOG=warn make test
}

log()
{
    echo "$*"
    eval "$*"
}

# Clean .csv files from previous runs
CONF=release make clean-csv

benchmark_branch "topic.avoid-cmov-long-min-max.base" "base"
benchmark_branch "topic.avoid-cmov-long-min-max.reassoc-simple" "reassoc-simple"
benchmark_branch "topic.avoid-cmov-long-min-max" "reassoc-tree"
