#!/usr/bin/env bash

set -e -x

#pushd jdk && LOG=debug,cmdlines make
pushd $(HOME)/1/jdk && make clean
