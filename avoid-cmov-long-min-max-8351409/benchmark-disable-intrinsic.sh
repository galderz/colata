#!/usr/bin/env bash

set -ex

CLEAN="true"

if [ "$(uname)" = "Darwin" ]; then
  ASM_PROFILER="xctraceasm"
  DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
else
  ASM_PROFILER="perfasm"
fi

# Check for clean parameter
if [[ "$1" == "--clean=false" ]]; then
    CLEAN="false"
fi

benchmark_all()
{
    local branch=$1
    local extra_args=$2
    local rffPrefix=$3

    log TEST=\"micro:org\.openjdk\.bench\.java\.lang\.MinMaxVector\.long\" MICRO=\"OPTIONS=-jvmArgs -XX:-UseSuperWord -rff ${rffPrefix}-disable-intrinsic.csv ${extra_args}\" CONF=release LOG=warn make test
}

benchmark_branch()
{
    local branch=$1
    local extra_args=$2
    local common_args="-p includeEquals=true -bm thrpt -tu ms -jvmArgs -XX:+UnlockDiagnosticVMOptions -jvmArgs -XX:DisableIntrinsic=_maxL,_minL"

    pushd $HOME/src/jdk-avoid-cmov-long-min-max
    git checkout ${branch}
    popd

    # Tracking regression needs to
    if [[ $CLEAN == "true" ]]; then
        CONF=release BUILD_LOG=warn make configure clean-jdk build-jdk
    fi

    benchmark_all ${branch} "${extra_args} ${common_args} -prof $ASM_PROFILER;FORK=1" "base"
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

benchmark_branch "topic.avoid-cmov.0521.base" ""
