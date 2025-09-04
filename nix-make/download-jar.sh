#!/usr/bin/env bash
set -eux

GROUP_ID=$1
ARTIFACT_ID=$2
VERSION=$3

LIB_DIR="target/lib"

MAVEN_MIRROR=${MAVEN_MIRROR:-https://repo.maven.apache.org/maven2}

mkdir -p $LIB_DIR
cd $LIB_DIR

download() {
  local url="${MAVEN_MIRROR}/$1/$2/$3/$2-$3.jar"
  if command -v curl > /dev/null; then
    curl -OL --fail $url
  elif command -v wget > /dev/null; then
    wget $url
  else
    echo "Could not find either curl or wget"
    exit 1
  fi
}

download $GROUP_ID $ARTIFACT_ID $VERSION
