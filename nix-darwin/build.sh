#!/usr/bin/env bash

set -e -x

#pushd jdk && LOG=debug,cmdlines make
pushd jdk && make
