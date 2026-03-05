#!/bin/bash
set -eux

pushd $1

JAVA_HOME=$2 \
  sh igv.sh &

popd
