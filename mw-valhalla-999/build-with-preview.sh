#!/bin/bash
#
# Build script for Quarkus with JEP 401 value classes in hibernate-orm.
#
# The custom hibernate-core jar is compiled with JDK 28, so every Quarkus
# module that compiles against hibernate-core (directly or via
# quarkus-hibernate-orm) must also be compiled with JDK 28 + --enable-preview.
#
# Phase 1: Build all dependencies of extensions/hibernate-orm, plus the
#          other extensions needed by the hibernate-orm-quickstart
#          (quarkus-rest, quarkus-rest-jackson, quarkus-jdbc-postgresql),
#          plus the quarkus-maven-plugin.  Uses the default JDK (25).
#
# Phase 2: Build modules that compile against hibernate-core / quarkus-hibernate-orm
#          with JDK 28 + --enable-preview:
#            - extensions/panache/panache-hibernate-common  (depends on hibernate-core)
#            - extensions/hibernate-orm                     (depends on hibernate-core)
#
set -euo pipefail
set -x

MAVEN_OPTS="${MAVEN_OPTS:+$MAVEN_OPTS }-Xmx4g"
export MAVEN_OPTS

# --------------------------------------------------------------------------
# Phase 1 — Build everything hibernate-orm needs + other quickstart
#           extensions + quarkus-maven-plugin  (default JDK, NO --enable-preview)
#
# Strategy: ask Maven to compute the dependency closure (-am / --also-make)
# of the hibernate-orm submodules, panache-hibernate-common, the other
# quickstart extension deployment modules, and the maven plugin.  Then
# EXCLUDE the modules that compile against hibernate-core so they are NOT
# built in this phase (they will be built with JDK 28 in Phase 2).
#
# Excluded modules (contain Java that references hibernate-core classes):
#   - extensions/hibernate-orm/runtime
#   - extensions/hibernate-orm/runtime-dev
#   - extensions/hibernate-orm/deployment-spi
#   - extensions/hibernate-orm/deployment
#   - extensions/panache/panache-hibernate-common/runtime
#   - extensions/panache/panache-hibernate-common/deployment
#
# Their *parent* POMs (packaging=pom, no Java) remain in the reactor.
# --------------------------------------------------------------------------
echo "============================================================"
echo "Phase 1: Building dependencies (default JDK, no --enable-preview)"
echo "============================================================"

JAVA_HOME="$JAVA_25_HOME" ./mvnw install -Dquickly \
  -pl devtools/maven

JAVA_HOME="$JAVA_28_HOME" ./mvnw install -Dquickly \
  -am \
  -pl extensions/hibernate-orm/runtime \
  -pl extensions/hibernate-orm/runtime-dev \
  -pl extensions/hibernate-orm/deployment-spi \
  -pl extensions/hibernate-orm/deployment \
  -pl extensions/panache/panache-hibernate-common/runtime \
  -pl extensions/panache/panache-hibernate-common/deployment \
  -pl extensions/resteasy-reactive/rest/deployment \
  -pl extensions/resteasy-reactive/rest-jackson/deployment \
  -pl extensions/jdbc/jdbc-postgresql/deployment \
  -pl '!extensions/hibernate-orm/runtime' \
  -pl '!extensions/hibernate-orm/runtime-dev' \
  -pl '!extensions/hibernate-orm/deployment-spi' \
  -pl '!extensions/hibernate-orm/deployment' \
  -pl '!extensions/panache/panache-hibernate-common/runtime' \
  -pl '!extensions/panache/panache-hibernate-common/deployment'

# --------------------------------------------------------------------------
# Phase 2 — Build modules that reference hibernate-core with JDK 28 +
#           --enable-preview.
#
# Order matters:
#   2a. panache-hibernate-common  — depends on hibernate-core directly
#   2b. extensions/hibernate-orm  — depends on hibernate-core + panache-hibernate-common-deployment
#
# All other dependencies were installed in Phase 1.
# Tests are skipped — they may need additional flags / containers.
# --------------------------------------------------------------------------
PREVIEW_FLAGS="-Dmaven.compiler.enablePreview=true -Dmaven.compiler.release=28 -Dformat.skip=true -Dforbiddenapis.skip=true"

echo ""
echo "============================================================"
echo "Phase 2a: Building panache-hibernate-common (JDK 28, --enable-preview)"
echo "============================================================"

JAVA_HOME="$JAVA_28_HOME" ./mvnw install \
  -f extensions/panache/panache-hibernate-common \
  -DskipTests \
  $PREVIEW_FLAGS

echo ""
echo "============================================================"
echo "Phase 2b: Building extensions/hibernate-orm (JDK 28, --enable-preview)"
echo "============================================================"

JAVA_HOME="$JAVA_28_HOME" ./mvnw install \
  -f extensions/hibernate-orm \
  -DskipTests \
  $PREVIEW_FLAGS

echo ""
echo "============================================================"
echo "Build complete."
echo "============================================================"
