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

# Modules that compile against hibernate-core / quarkus-hibernate-orm.
# These are EXCLUDED from Phase 1 and built with --enable-preview in Phase 2.
HIBERNATE_MODULES=(
  extensions/hibernate-orm/runtime
  extensions/hibernate-orm/runtime-dev
  extensions/hibernate-orm/deployment-spi
  extensions/hibernate-orm/deployment
  extensions/panache/panache-hibernate-common/runtime
  extensions/panache/panache-hibernate-common/deployment
  extensions/panache/hibernate-orm-panache-common/runtime
  extensions/panache/hibernate-orm-panache-common/deployment
  extensions/panache/hibernate-orm-panache/runtime
  extensions/panache/hibernate-orm-panache/deployment
)

# Flags for Phase 2 builds (--enable-preview, JDK 28 target, skip tools
# that cannot handle JDK 28 class files).
PREVIEW_FLAGS="-Dmaven.compiler.enablePreview=true -Dmaven.compiler.release=28 -Dformat.skip=true -Dforbiddenapis.skip=true"

# The Maven JVM itself must run with --enable-preview so it can load
# preview-enabled classes (e.g. hibernate-processor annotation processor,
# deployment classes during augmentation).
PREVIEW_MAVEN_OPTS="${MAVEN_OPTS:-} --enable-preview"

# --------------------------------------------------------------------------
# Phase 1 — Build dependencies + independent extensions  (NO --enable-preview)
# --------------------------------------------------------------------------
echo "============================================================"
echo "Phase 1: Building dependencies (no --enable-preview)"
echo "============================================================"

# Build the -am (also-make) closure of all hibernate-dependent modules plus
# the independent extensions needed by /tmp/quarkus3, then exclude the
# hibernate-dependent modules so they are NOT compiled in this phase.
INCLUDE_PL=""
EXCLUDE_PL=""
for m in "${HIBERNATE_MODULES[@]}"; do
  INCLUDE_PL="$INCLUDE_PL -pl $m"
  EXCLUDE_PL="$EXCLUDE_PL -pl !$m"
done

JAVA_HOME="$JAVA_28_HOME" ./mvnw install -Dquickly \
  -am \
  $INCLUDE_PL \
  -pl extensions/resteasy-reactive/rest-jackson/deployment \
  -pl extensions/hibernate-validator/deployment \
  -pl extensions/smallrye-health/deployment \
  -pl extensions/config-yaml/deployment \
  -pl extensions/micrometer-opentelemetry/deployment \
  -pl extensions/jdbc/jdbc-postgresql/deployment \
  -pl extensions/container-image/container-image-jib/deployment \
  -pl extensions/observability-devservices/sink/lgtm \
  -pl extensions/observability-devservices/deployment \
  -pl test-framework/junit-mockito \
  -pl devtools/maven \
  -pl '!devtools/maven' \
  $EXCLUDE_PL

# --------------------------------------------------------------------------
# Phase 2 — Build hibernate-dependent modules WITH --enable-preview
#
# Built in dependency order.  Each step uses -f to build a reactor POM
# that contains the runtime + deployment submodules.
# --------------------------------------------------------------------------
echo ""
echo "============================================================"
echo "Phase 2a: Building panache-hibernate-common (--enable-preview)"
echo "============================================================"

echo ""
echo "============================================================"
echo "Phase 2a: Building panache-hibernate-common (JDK 28, --enable-preview)"
echo "============================================================"

MAVEN_OPTS="$PREVIEW_MAVEN_OPTS" JAVA_HOME="$JAVA_28_HOME" ./mvnw install \
  -f extensions/panache/panache-hibernate-common \
  -DskipTests \
  $PREVIEW_FLAGS

echo ""
echo "============================================================"
echo "Phase 2b: Building extensions/hibernate-orm (JDK 28, --enable-preview)"
echo "============================================================"

MAVEN_OPTS="$PREVIEW_MAVEN_OPTS" JAVA_HOME="$JAVA_28_HOME" ./mvnw install \
  -f extensions/hibernate-orm \
  -DskipTests \
  $PREVIEW_FLAGS
# --------------------------------------------------------------------------
# Phase 2 — Build hibernate-dependent modules WITH --enable-preview
#
# Built in dependency order.  Each step uses -f to build a reactor POM
# that contains the runtime + deployment submodules.
# --------------------------------------------------------------------------
echo ""
echo "============================================================"
echo "Phase 2a: Building panache-hibernate-common (--enable-preview)"
echo "============================================================"

MAVEN_OPTS="$PREVIEW_MAVEN_OPTS" ./mvnw install \
  -f extensions/panache/panache-hibernate-common \
  -DskipTests \
  $PREVIEW_FLAGS

echo ""
echo "============================================================"
echo "Phase 2b: Building extensions/hibernate-orm (--enable-preview)"
echo "============================================================"

MAVEN_OPTS="$PREVIEW_MAVEN_OPTS" ./mvnw install \
  -f extensions/hibernate-orm \
  -DskipTests \
  $PREVIEW_FLAGS

echo ""
echo "============================================================"
echo "Phase 2c: Building hibernate-orm-panache-common (--enable-preview)"
echo "============================================================"

MAVEN_OPTS="$PREVIEW_MAVEN_OPTS" ./mvnw install \
  -f extensions/panache/hibernate-orm-panache-common \
  -DskipTests \
  $PREVIEW_FLAGS

echo ""
echo "============================================================"
echo "Phase 2d: Building hibernate-orm-panache (--enable-preview)"
echo "============================================================"

MAVEN_OPTS="$PREVIEW_MAVEN_OPTS" ./mvnw install \
  -f extensions/panache/hibernate-orm-panache \
  -DskipTests \
  $PREVIEW_FLAGS

# --------------------------------------------------------------------------
# Phase 3 — Build quarkus-maven-plugin with JDK 25
#
# The sisu-maven-plugin used by devtools/maven cannot parse JDK 28 class
# files from jrt:/java.base.  Building with JDK 25 avoids this.
# devtools/maven has no dependency on hibernate-orm.
# --------------------------------------------------------------------------
echo ""
echo "============================================================"
echo "Phase 3: Building quarkus-maven-plugin (JDK 25)"
echo "============================================================"

JAVA_HOME="$JAVA_25_HOME" ./mvnw install -Dquickly \
  -pl devtools/maven

echo ""
echo "============================================================"
echo "Build complete."
echo "============================================================"
