#!/usr/bin/env bash

set -e -x

pushd jdk && bash configure \
    --with-boot-jdk=$(dirname $(dirname $(readlink -f $(which java))))
