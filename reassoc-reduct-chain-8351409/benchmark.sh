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

    log TEST=\"micro:org\.openjdk\.bench\.vm\.compiler\.VectorReduction2\.NoSuperword\" MICRO=\"OPTIONS=-rff ${rff_prefix}-vr2.csv ${extra_args}\" CONF=release LOG=warn make test
    # log TEST=\"micro:org\.openjdk\.bench\.java\.lang\.MinMaxVector\.long\" MICRO=\"OPTIONS=-jvmArgsAppend -XX:-UseSuperWord -rff ${rff_prefix}-mmv.csv ${extra_args}\" CONF=release LOG=warn make test
}

benchmark_branch()
{
    local branch=$1
    local extra_args=$2
    local rff_suffix=$3
    local common_args="-bm thrpt -tu ms"

    pushd $HOME/src/jdk-reassoc-reduct-chain
    git checkout ${branch}
    popd

    # Tracking regression needs to
    if [[ $CLEAN == "true" ]]; then
        CONF=release BUILD_LOG=warn make configure clean-jdk build-jdk
    fi

    if [[ $branch != *base ]]; then
        benchmark_all ${branch} "${extra_args} ${common_args};FORK=1" "patch-${rff_suffix}"
    else
        benchmark_all ${branch} "${extra_args} ${common_args};FORK=1" "base-${rff_suffix}"
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

# Clean .csv files from previous runs
CONF=release make clean-csv

# DisableIntrinsic requires UnlockDiagnosticVMOptions
# UseNewCode / UseNewCode requires UnlockDiagnosticVMOptions

benchmark_branch "topic.reassoc-reduct-chain" "-prof ${ASM_PROFILER}" "perfasm"
benchmark_branch "topic.reassoc-reduct-chain" "-prof perfnorm:events=${EVENTS}" "perfnorm"
benchmark_branch "topic.reassoc-reduct-chain" "" "noprof"
benchmark_branch "topic.reassoc-reduct-chain.base" "-prof ${ASM_PROFILER}" "perfasm"
benchmark_branch "topic.reassoc-reduct-chain.base" "-prof perfnorm:events=${EVENTS}" "perfnorm"
benchmark_branch "topic.reassoc-reduct-chain.base" "" "noprof"

zipdir="$HOME/src/jdk-reassoc-reduct-chain/build/release-linux-x86_64/images/test"
zipfile="results-benchmark-$(date +%Y%m%d-%H%M%S).zip"
zip -j "$zipfile" "$zipdir"/*.csv && realpath "$zipfile"
