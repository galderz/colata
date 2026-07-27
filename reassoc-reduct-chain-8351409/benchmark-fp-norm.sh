#!/usr/bin/env bash

set -ex

CLEAN="false"
# 1. Dynamic work
EVENTS_1="cycles,instructions,branches,branch-misses,uops_retired.retire_slots"
# 2. Dynamic branch-path length
EVENTS_2="cycles,instructions,br_inst_retired.conditional,br_inst_retired.near_taken,branch-misses"
# 3. Front-end delivery
EVENTS_3="cycles,instructions,uops_issued.any,idq_uops_not_delivered.core,uops_retired.retire_slots,int_misc.recovery_cycles"

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

    log TEST=\"micro:org\.openjdk\.bench\.vm\.compiler\.VectorReduction2\.NoSuperword.\\\(double\\\|float\\\)\\\(Max\\\|Min\\\)\" MICRO=\"OPTIONS=-rff ${rff_prefix}-fp.csv ${extra_args}\" CONF=release LOG=warn make test
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

benchmark_branch "topic.reassoc-reduct-chain.all-add.base" "-prof perfnorm:events=${EVENTS_1}" "base-perfnorm-dyw"
benchmark_branch "topic.reassoc-reduct-chain.all-add.base" "-prof perfnorm:events=${EVENTS_2}" "base-perfnorm-dybr"
benchmark_branch "topic.reassoc-reduct-chain.all-add.base" "-prof perfnorm:events=${EVENTS_3}" "base-perfnorm-fe"
benchmark_branch "topic.reassoc-reduct-chain.all-add.fp" "-jvmArgsAppend -XX:+UnlockDiagnosticVMOptions -jvmArgsAppend -XX:+UseNewCode2 -prof perfnorm:events=${EVENTS_1}" "newcode2-perfnorm-dyw"
benchmark_branch "topic.reassoc-reduct-chain.all-add.fp" "-jvmArgsAppend -XX:+UnlockDiagnosticVMOptions -jvmArgsAppend -XX:+UseNewCode2 -prof perfnorm:events=${EVENTS_2}" "newcode2-perfnorm-dybr"
benchmark_branch "topic.reassoc-reduct-chain.all-add.fp" "-jvmArgsAppend -XX:+UnlockDiagnosticVMOptions -jvmArgsAppend -XX:+UseNewCode2 -prof perfnorm:events=${EVENTS_3}" "newcode2-perfnorm-fr"

zipdir="$HOME/src/jdk-reassoc-reduct-chain/build/release-linux-x86_64/images/test"
zipfile="results-benchmark-$(date +%Y%m%d-%H%M%S).zip"
zip -j "$zipfile" "$zipdir"/*.csv && realpath "$zipfile"
