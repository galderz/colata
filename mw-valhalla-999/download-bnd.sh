#!/usr/bin/env bash

set -e

mkdir -p /tmp/cache-bnd
cd /tmp/cache-bnd

cat > settings.gradle <<'EOF'
pluginManagement {
    repositories {
        gradlePluginPortal()
        mavenCentral()
    }
}
EOF

cat > build.gradle <<'EOF'
plugins {
    id 'biz.aQute.bnd.builder' version '7.2.1'
}
EOF

cp ~/src/hibernate-orm/gradlew .
cp -r ~/src/hibernate-orm/gradle .
JAVA_HOME=$JAVA_25_HOME ./gradlew help
