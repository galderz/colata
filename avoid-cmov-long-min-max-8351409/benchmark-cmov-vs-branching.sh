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

    local prefix="micro:org\.openjdk\.bench\.java\.lang\.MinMaxVector\.longReduction"
    local micro_args="OPTIONS=-jvmArgs -XX:-UseSuperWord"

    log TEST=\"${prefix}\\\(?:Simple\\\|Multiply\\\)Max\" MICRO=\"${micro_args} ${extra_args}\" CONF=release BUILD_LOG=warn make test
}

benchmark_branch()
{
    local branch=$1
    local extra_args=$2

    pushd $HOME/src/jdk-avoid-cmov-long-min-max
    git checkout ${branch}
    popd

    # Tracking regression needs to
    if [[ $CLEAN == "true" ]]; then
        CONF=release BUILD_LOG=warn make configure clean-jdk build-jdk
    fi

#    for probability in \
#      50 \
#      80 \
#      100
#    do
    benchmark_all ${branch} "${extra_args} -prof $ASM_PROFILER;FORK=1"
#    done
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

benchmark_branch "topic.avoid-cmov-long-min-max.0408.base" ""
# benchmark_branch "topic.avoid-cmov-long-min-max.0408.base" "-jvmArgs -XX:+UnlockDiagnosticVMOptions -jvmArgs -XX:DisableIntrinsic=_maxL"
benchmark_branch "topic.avoid-cmov-long-min-max.0408.branch-never-ge" ""
