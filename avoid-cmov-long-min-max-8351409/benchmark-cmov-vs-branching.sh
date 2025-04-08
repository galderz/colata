#!/usr/bin/env bash

set -ex

CLEAN="true"

if [ "$(uname)" = "Darwin" ]; then
  PROFILER="xctraceasm"
  DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
else
  PROFILER="perfasm"
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

    pushd $HOME/1/jdk-avoid-cmov-long-min-max
    git checkout ${branch}
    popd

    local prefix="micro:org\.openjdk\.bench\.java\.lang\.MinMaxVector\.longReduction"
    local micro_args="OPTIONS=-p probability=100 -jvmArgs -XX:-UseSuperWord"

    log TEST=\"${prefix}\\\(?:Simple\\\|Multiply\\\)Max\" MICRO=\"${micro_args} ${extra_args}\" CONF=release BUILD_LOG=warn make test
}

log()
{
    echo "$*"
    eval "$*"
}

if [[ $CLEAN == "true" ]]; then
  CONF=release BUILD_LOG=warn make configure clean-jdk build-jdk
fi

benchmark_all "topic.avoid-cmov-long-min-max.0327.cmov" ""
benchmark_all "topic.avoid-cmov-long-min-max.0327.branch-always" ""
benchmark_all "topic.avoid-cmov-long-min-max.0327.branch-never" ""
# DisableIntrinsic requires UnlockDiagnosticVMOptions
benchmark_all "topic.avoid-cmov-long-min-max.base" "-jvmArgs -XX:+UnlockDiagnosticVMOptions -jvmArgs -XX:DisableIntrinsic=_maxL"

benchmark_all "topic.avoid-cmov-long-min-max.0327.cmov" "-prof $PROFILER;FORK=1"
benchmark_all "topic.avoid-cmov-long-min-max.0327.branch-always" "-prof $PROFILER;FORK=1"
benchmark_all "topic.avoid-cmov-long-min-max.0327.branch-never" "-prof $PROFILER;FORK=1"
# DisableIntrinsic requires UnlockDiagnosticVMOptions
benchmark_all "topic.avoid-cmov-long-min-max.base" "-jvmArgs -XX:+UnlockDiagnosticVMOptions -jvmArgs -XX:DisableIntrinsic=_maxL -prof $PROFILER;FORK=1"
