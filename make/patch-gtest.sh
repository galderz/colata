#!/usr/bin/env bash

set -e -x

GTEST_DIR=$1

sed -i.bak 's/PrintTo(ImplicitCast_<char32_t>(c), os);/PrintTo(static_cast<char32_t>(c), os);/g' \
  "$GTEST_DIR/googletest/include/gtest/gtest-printers.h"
