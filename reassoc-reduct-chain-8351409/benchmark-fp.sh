#!/usr/bin/env bash

set -ex

CLEAN="false"
EVENTS="cycles,instructions,branch-misses,br_mis_pred,inst_retired"
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

benchmark_all()
{
    local branch=$1
    local extra_args=$2
    local rff_prefix=$3

    log TEST=\"micro:org\.openjdk\.bench\.vm\.compiler\.VectorReduction2\.NoSuperword.\\\(double\\\|float\\\)\\\(Max\\\|Min\\\)\" MICRO=\"OPTIONS=-rff ${rff_prefix}-xor.csv ${extra_args}\" CONF=release LOG=warn make test
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

    make print-branch-commit

    # Tracking regression needs to
    if [[ $CLEAN == "true" ]]; then
        CONF=release BUILD_LOG=warn make configure clean-jdk build-jdk
    fi

    benchmark_all ${branch} "${extra_args} ${common_args};FORK=1" "${rff_suffix}"
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

benchmark_branch "topic.reassoc-reduct-chain.all-add.base" "-prof ${ASM_PROFILER}" "base-perfasm"
benchmark_branch "topic.reassoc-reduct-chain.all-add.base" "-prof perfnorm:events=${EVENTS}" "base-perfnorm"
benchmark_branch "topic.reassoc-reduct-chain.all-add.base" "" "base-noprof"
benchmark_branch "topic.reassoc-reduct-chain.all-add.fp" "-jvmArgsAppend -XX:+UnlockDiagnosticVMOptions -jvmArgsAppend -XX:+UseNewCode2 -prof ${ASM_PROFILER}" "newcode2-perfasm"
benchmark_branch "topic.reassoc-reduct-chain.all-add.fp" "-jvmArgsAppend -XX:+UnlockDiagnosticVMOptions -jvmArgsAppend -XX:+UseNewCode2 -prof perfnorm:events=${EVENTS}" "newcode2-perfnorm"
benchmark_branch "topic.reassoc-reduct-chain.all-add.fp" "-jvmArgsAppend -XX:+UnlockDiagnosticVMOptions -jvmArgsAppend -XX:+UseNewCode2 " "newcode2-noprof"
benchmark_branch "topic.reassoc-reduct-chain.all-add.fp" "-prof ${ASM_PROFILER}" "patch-perfasm"
benchmark_branch "topic.reassoc-reduct-chain.all-add.fp" "-prof perfnorm:events=${EVENTS}" "patch-perfnorm"
benchmark_branch "topic.reassoc-reduct-chain.all-add.fp" "" "patch-noprof"

zipdir="$HOME/src/jdk-reassoc-reduct-chain/build/release-linux-x86_64/images/test"
zipfile="results-benchmark-$(date +%Y%m%d-%H%M%S).zip"
zip -j "$zipfile" "$zipdir"/*.csv && realpath "$zipfile"
