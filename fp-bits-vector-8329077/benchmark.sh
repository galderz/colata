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

benchmark_all()
{
    local branch=$1
    local extra_args=$2
    local rff_prefix=$3

    local prefix="micro:org\.openjdk\.bench\.vm\.compiler\.TypeVectorOperations.TypeVectorOperationsSuperWord\.convert"

    log TEST=\"${prefix}\.*Bits\.*\" MICRO=\"OPTIONS=-rff ${rff_prefix}.csv ${extra_args}\" CONF=release LOG=warn make test
}

benchmark_branch()
{
    local branch=$1
    local extra_args=$2
    local rff_suffix=$3
    local common_args="-bm thrpt -tu ms"

    BRANCH=$1 make checkout

    # Tracking regression needs to
    if [[ $CLEAN == "true" ]]; then
        CONF=release BUILD_LOG=warn make configure clean-jdk build-jdk
    fi

    benchmark_all ${branch} "${common_args} ${extra_args}" "${rff_suffix}"
}

log()
{
    echo "$*"
    eval "$*"
}

if [[ $CLEAN == "true" ]]; then
  CONF=release BUILD_LOG=warn make configure clean-jdk build-jdk
fi

# Clean .csv files from previous runs
CONF=release make clean-csv

# DisableIntrinsic requires UnlockDiagnosticVMOptions
# UseNewCode / UseNewCode requires UnlockDiagnosticVMOptions

#benchmark_branch "topic.fp-bits-vector" "-prof ${ASM_PROFILER};FORK=1" "perfasm"
#benchmark_branch "topic.avoid-cmov.0521.aarch64-x64" "-prof perfnorm:events=${EVENTS}" "perfnorm"
benchmark_branch "topic.fp-bits-vector" "" "noprof"
#benchmark_branch "topic.fp-bits-vector.base" "-prof ${ASM_PROFILER};FORK=1" "perfasm"
#benchmark_branch "topic.avoid-cmov.0521.base" "-prof perfnorm:events=${EVENTS}" "perfnorm"
benchmark_branch "topic.fp-bits-vector.base" "" "noprof-base"
