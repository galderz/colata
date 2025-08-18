#!/usr/bin/env bash

set -e -x

cd /Users/galder/src/jdk-template-101/build/fast-darwin-arm64/test-support/jtreg_test_hotspot_jtreg_compiler_valhalla_inlinetypes_templating_TestOne_java/scratch/0 && \
DOCS_JDK_IMAGE_DIR=/Users/galder/src/jdk-template-101/build/fast-darwin-arm64/images/docs \
HOME=/Users/galder \
LANG=en_GB.UTF-8 \
LC_ALL=C.UTF-8 \
PATH=/bin:/usr/bin:/usr/sbin \
TEST_IMAGE_DIR=/Users/galder/src/jdk-template-101/build/fast-darwin-arm64/images/test \
XDG_CONFIG_DIRS=/Users/galder/.nix-profile/etc/xdg:/etc/profiles/per-user/galder/etc/xdg:/run/current-system/sw/etc/xdg:/nix/var/nix/profiles/default/etc/xdg \
XDG_DATA_DIRS=/nix/store/72vc94jw3ahn2d3yk3a5yqvr85s8v40l-ant-1.10.15/share:/nix/store/ya954fbyialirl4dbxqwmyl4sf9k6rzb-autoconf-2.72/share:/nix/store/qq5jzjzncl8j14gf2x76rii3n22557hb-pigz-2.8/share:/Users/galder/.nix-profile/share:/etc/profiles/per-user/galder/share:/run/current-system/sw/share:/nix/var/nix/profiles/default/share \
    /Users/galder/src/jdk-template-101/build/fast-darwin-arm64/jdk/bin/java \
        -Dtest.vm.opts='-XX:MaxRAMPercentage=3.57143 -Dtest.boot.jdk=/nix/store/bndjn9f1xzsvx9m59ppnm7wddxhlk765-temurin-bin-24.0.0 -Djava.io.tmpdir=/Users/galder/src/jdk-template-101/build/fast-darwin-arm64/test-support/jtreg_test_hotspot_jtreg_compiler_valhalla_inlinetypes_templating_TestOne_java/tmp' \
        -Dtest.tool.vm.opts='-J-XX:MaxRAMPercentage=3.57143 -J-Dtest.boot.jdk=/nix/store/bndjn9f1xzsvx9m59ppnm7wddxhlk765-temurin-bin-24.0.0 -J-Djava.io.tmpdir=/Users/galder/src/jdk-template-101/build/fast-darwin-arm64/test-support/jtreg_test_hotspot_jtreg_compiler_valhalla_inlinetypes_templating_TestOne_java/tmp' \
        -Dtest.compiler.opts= \
        -Dtest.java.opts=--enable-preview \
        -Dtest.jdk=/Users/galder/src/jdk-template-101/build/fast-darwin-arm64/jdk \
        -Dcompile.jdk=/Users/galder/src/jdk-template-101/build/fast-darwin-arm64/jdk \
        -Dtest.timeout.factor=4.0 \
        -Dtest.nativepath=/Users/galder/src/jdk-template-101/build/fast-darwin-arm64/images/test/hotspot/jtreg/native \
        -Dtest.root=/Users/galder/src/jdk-template-101/test/hotspot/jtreg \
        -Dtest.name=compiler/valhalla/inlinetypes/templating/TestOne.java \
        -Dtest.verbose=Verbose[p=SUMMARY,f=FULL,e=FULL,t=false,m=false] \
        -Dtest.file=/Users/galder/src/jdk-template-101/test/hotspot/jtreg/compiler/valhalla/inlinetypes/templating/TestOne.java \
        -Dtest.main.class=compiler.valhalla.inlinetypes.templating.TestOne \
        -Dtest.src=/Users/galder/src/jdk-template-101/test/hotspot/jtreg/compiler/valhalla/inlinetypes/templating \
        -Dtest.src.path=/Users/galder/src/jdk-template-101/test/hotspot/jtreg/compiler/valhalla/inlinetypes/templating:/Users/galder/src/jdk-template-101/test/lib:/Users/galder/src/jdk-template-101/test/hotspot/jtreg \
        -Dtest.classes=/Users/galder/src/jdk-template-101/build/fast-darwin-arm64/test-support/jtreg_test_hotspot_jtreg_compiler_valhalla_inlinetypes_templating_TestOne_java/classes/0/compiler/valhalla/inlinetypes/templating/TestOne.d \
        -Dtest.class.path=/Users/galder/src/jdk-template-101/build/fast-darwin-arm64/test-support/jtreg_test_hotspot_jtreg_compiler_valhalla_inlinetypes_templating_TestOne_java/classes/0/compiler/valhalla/inlinetypes/templating/TestOne.d:/Users/galder/src/jdk-template-101/build/fast-darwin-arm64/test-support/jtreg_test_hotspot_jtreg_compiler_valhalla_inlinetypes_templating_TestOne_java/classes/0/compiler/valhalla/inlinetypes/templating/TestOne.d/test/lib:/Users/galder/src/jdk-template-101/build/fast-darwin-arm64/test-support/jtreg_test_hotspot_jtreg_compiler_valhalla_inlinetypes_templating_TestOne_java/classes/0/compiler/valhalla/inlinetypes/templating/TestOne.d \
        -Dtest.class.path.prefix=/Users/galder/src/jdk-template-101/build/fast-darwin-arm64/test-support/jtreg_test_hotspot_jtreg_compiler_valhalla_inlinetypes_templating_TestOne_java/classes/0/compiler/valhalla/inlinetypes/templating/TestOne.d:/Users/galder/src/jdk-template-101/test/hotspot/jtreg/compiler/valhalla/inlinetypes/templating:/Users/galder/src/jdk-template-101/build/fast-darwin-arm64/test-support/jtreg_test_hotspot_jtreg_compiler_valhalla_inlinetypes_templating_TestOne_java/classes/0/compiler/valhalla/inlinetypes/templating/TestOne.d/test/lib \
        -Dtest.modules=java.base/jdk.internal.misc \
        -classpath /Users/galder/src/jdk-template-101/build/fast-darwin-arm64/test-support/jtreg_test_hotspot_jtreg_compiler_valhalla_inlinetypes_templating_TestOne_java/classes/0/compiler/valhalla/inlinetypes/templating/TestOne.d:/Users/galder/src/jdk-template-101/test/hotspot/jtreg/compiler/valhalla/inlinetypes/templating:/Users/galder/src/jdk-template-101/build/fast-darwin-arm64/test-support/jtreg_test_hotspot_jtreg_compiler_valhalla_inlinetypes_templating_TestOne_java/classes/0/compiler/valhalla/inlinetypes/templating/TestOne.d/test/lib:/Users/galder/src/jdk-template-101/test/lib:/Users/galder/src/jdk-template-101/test/hotspot/jtreg:/Users/galder/opt/jtreg/build/images/jtreg/lib/javatest.jar:/Users/galder/opt/jtreg/build/images/jtreg/lib/jtreg.jar \
        --enable-preview \
        compiler.valhalla.inlinetypes.templating.TestOne
