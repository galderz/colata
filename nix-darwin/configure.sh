#!/usr/bin/env bash

set -e -x

pushd $(HOME)/1/jdk && bash configure \
    --with-boot-jdk=$(dirname $(dirname $(readlink -f $(which java)))) \
    --with-devkit=$DEVKIT_ROOT
