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

    log TEST=\"micro:org\.openjdk\.bench\.java\.lang\.MinMaxVector\.longClipping\" MICRO=\"OPTIONS=-jvmArgs -XX:-UseSuperWord -rff ${rffPrefix}-clipping.csv ${extra_args}\" CONF=release LOG=warn make test
}

benchmark_branch()
{
    local branch=$1
    local extra_args=$2
    local common_args="-p includeEquals=true -bm thrpt -tu ms"

    pushd $HOME/src/jdk-avoid-cmov-long-min-max
    git checkout ${branch}
    popd

    # Tracking regression needs to
    if [[ $CLEAN == "true" ]]; then
        CONF=release BUILD_LOG=warn make configure clean-jdk build-jdk
    fi

    if [[ $branch != *base ]]; then
        # Branch always max: -XX:-UseNewCode
        # Branch always min: -XX:-UseNewCode2
        # Branch never max:  -XX:+UseNewCode
        # Branch never min:  -XX:+UseNewCode2
        benchmark_all ${branch} "${extra_args} ${common_args} -jvmArgs -XX:+UnlockDiagnosticVMOptions -jvmArgs -XX:-UseNewCode -jvmArgs -XX:-UseNewCode2 -prof $ASM_PROFILER;FORK=1" "branch-always"
        benchmark_all ${branch} "${extra_args} ${common_args} -jvmArgs -XX:+UnlockDiagnosticVMOptions -jvmArgs -XX:+UseNewCode -jvmArgs -XX:+UseNewCode2 -prof $ASM_PROFILER;FORK=1" "branch-never"
    else
        benchmark_all ${branch} "${extra_args} ${common_args} -prof $ASM_PROFILER;FORK=1" "base"
    fi
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

benchmark_branch "topic.avoid-cmov.0521.aarch64-x64" ""
benchmark_branch "topic.avoid-cmov.0521.base" ""
