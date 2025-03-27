#!/usr/bin/env bash

set -eux

# Create a JMH bundle from a local snapshot.

JDK_HOME=$1
pushd ${JDK_HOME}

JMH_VERSION=1.38-SNAPSHOT
COMMONS_MATH3_VERSION=3.6.1
JOPT_SIMPLE_VERSION=5.0.4

BUNDLE_NAME=jmh-$JMH_VERSION.tar.gz

#SCRIPT_DIR="$(cd "$(dirname $0)" > /dev/null && pwd)"
BUILD_DIR="${JDK_HOME}/build/jmh"
JAR_DIR="$BUILD_DIR/jars"

mkdir -p $BUILD_DIR $JAR_DIR
cd $JAR_DIR
rm -f *

copyJar()
{
    local uri="${HOME}/.m2/repository/$1/$2/$3/$2-$3.jar"
    cp ${uri} .
}

copyJar org/apache/commons commons-math3 $COMMONS_MATH3_VERSION
copyJar net/sf/jopt-simple jopt-simple $JOPT_SIMPLE_VERSION
copyJar org/openjdk/jmh jmh-core $JMH_VERSION
copyJar org/openjdk/jmh jmh-generator-annprocess $JMH_VERSION

tar -cvzf ../$BUNDLE_NAME *

echo "Created $BUILD_DIR/$BUNDLE_NAME"

popd
