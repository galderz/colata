#!/usr/bin/env bash

set -ex

CLEAN="false"
EVENTS="cycles,instructions,branch-misses,br_mis_pred,inst_retired"

if [ "$(uname)" = "Darwin" ]; then
  ASM_PROFILER="xctraceasm"
  DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
else
  ASM_PROFILER="perfasm"
fi

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

benchmark()
{
    local branch=$1
    local extra_args=$2
    local rff_prefix=$3
    local common_args="-bm thrpt -tu ms;FORK=1"

    pushd $HOME/src/jdk-fp-mmv-bench
    git checkout ${branch}
    popd

    log TEST=\"micro:org\.openjdk\.bench\.java\.lang\.MinMaxVector\.doubleReduction\" MICRO=\"OPTIONS=-jvmArgsAppend -XX:-UseSuperWord -rff ${rff_prefix}-mmv.csv ${extra_args} ${common_args}\" CONF=release LOG=warn make test
}

log()
{
    echo "$*"
    eval "$*"
}

benchmark "topic.fp-mmv-bench" "-prof ${ASM_PROFILER}" "perfasm"
if [ "$(uname)" = "Linux" ]; then
  benchmark "topic.fp-mmv-bench" "-prof perfnorm:events=${EVENTS}" "perfnorm"
fi
benchmark "topic.fp-mmv-bench" "" "noprof"
