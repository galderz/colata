#!/usr/bin/env bash
set -eux

DIR=$1

pushd $DIR

vmstat 1 &
vmstat_pid=$!

CONF=release make build-jdk

kill -SIGTERM $vmstat_pid

popd
