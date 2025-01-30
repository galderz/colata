#!/usr/bin/env bash

set -e -x

bash configure \
    --with-boot-jdk=$(dirname $(dirname $(readlink -f $(which java))))
