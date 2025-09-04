#!/usr/bin/env bash

set -ex

CLEAN="false"
DRY_RUN="false"
BASE_RUN="false"
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

# Check for the dry-run parameter
if [[ "$1" == "--dry-run=true" ]]; then
    DRY_RUN="true"
fi

# Check for the base run parameter
if [[ "$1" == "--base-run=true" ]]; then
    BASE_RUN="true"
fi

benchmark_all()
{
    local branch=$1
    local extra_args=$2
    local rff_prefix=$3
    local dry_run=$4

    local prefix="micro:org\.openjdk\.bench\.vm\.compiler\.TypeVectorOperations.TypeVectorOperationsSuperWord\.convert"

    if [[ $DRY_RUN == "true" ]]; then
        args="${extra_args} -f 1 -i 1 -r 1 -wi 0"
    else
        args="${extra_args}"
    fi

    log TEST=\"${prefix}\.*Bits\.*\" MICRO=\"OPTIONS=-rff ${rff_prefix}.csv ${args}\" CONF=release LOG=warn make test
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
benchmark_branch "topic.fp-bits-vector" "" "noprof" $DRY_RUN
#benchmark_branch "topic.fp-bits-vector.base" "-prof ${ASM_PROFILER};FORK=1" "perfasm"
#benchmark_branch "topic.avoid-cmov.0521.base" "-prof perfnorm:events=${EVENTS}" "perfnorm"
if [[ $BASE_RUN == "true" ]]; then
    benchmark_branch "topic.fp-bits-vector.base" "" "noprof-base" $DRY_RUN
fi
