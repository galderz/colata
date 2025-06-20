#!/usr/bin/env bash

set -ex

CLEAN="false"
ASM_PROFILER="perfasm"
EVENTS="cycles,instructions,branch-misses,br_mis_pred,inst_retired"

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

benchmark_all()
{
    local branch=$1
    local extra_args=$2
    local rffPrefix=$3

    log TEST=\"micro:org\.openjdk\.bench\.java\.lang\.MinMaxVector\.long\" MICRO=\"OPTIONS=-jvmArgsAppend -XX:-UseSuperWord -rff ${rffPrefix}-mmv.csv ${extra_args}\" CONF=release LOG=warn make test
}

benchmark_branch()
{
    local branch=$1
    local extra_args=$2
    local common_args="-p includeEquals=true -bm thrpt -tu ms -jvmArgsAppend -XX:+UnlockDiagnosticVMOptions -jvmArgsAppend -XX:+UseNewCode -jvmArgsAppend -XX:+UseNewCode2;FORK=1"

    pushd $HOME/src/jdk-avoid-cmov-long-min-max
    git checkout ${branch}
    popd

    # Tracking regression needs to
    if [[ $CLEAN == "true" ]]; then
        CONF=release BUILD_LOG=warn make configure clean-jdk build-jdk
    fi

    benchmark_all ${branch} "${extra_args} -p probability=80 ${common_args}" "branch-never-probability80"
    benchmark_all ${branch} "${extra_args} -p probability=100 ${common_args}" "branch-never-probability100"
}

log()
{
    echo "$*"
    eval "$*"
}

if [[ $CLEAN == "true" ]]; then
  CONF=release BUILD_LOG=warn make configure clean-jdk build-jdk
fi

# DisableIntrinsic requires UnlockDiagnosticVMOptions
# UseNewCode / UseNewCode requires UnlockDiagnosticVMOptions

benchmark_branch "topic.avoid-cmov.0521.aarch64-x64.out-of-line-x64" "-prof ${ASM_PROFILER}"
benchmark_branch "topic.avoid-cmov.0521.aarch64-x64.out-of-line-x64" "-prof perfnorm:events=${EVENTS}"
benchmark_branch "topic.avoid-cmov.0521.aarch64-x64.out-of-line-x64" ""
