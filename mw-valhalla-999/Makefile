ID ?= mw-valhalla

# Workaround for compiler errors after upgrade to Xcode 16.3 on Nix:
# .../src/java.desktop/macosx/native/libjsound/PLATFORM_API_MacOSX_Ports.cpp:127:39: error: variable length arrays in C++ are a Clang extension [-Werror,-Wvla-cxx-extension]
#    127 |                 AudioDeviceID devices[count];
#        |                                       ^~~~~
NO_WARNINGS_ERRORS := true

default: build-jdk

TOPDIR = ..
include $(TOPDIR)/make/MakeBase.gmk
include $(TOPDIR)/make/OpenJDK.gmk

JOL_CLASS ?= RequestMatch

jol_quarkus_jar = jol-quarkus/target/jol-quarkus.jar

run-jol: $(jol_quarkus_jar)
> $(boot_jdk_java) -cp $< jol.quarkus.$(JOL_CLASS)Jol

$(jol_quarkus_jar): $(shell find jol-quarkus/src -type f -name '*.java')
$(jol_quarkus_jar): jol-quarkus/pom.xml
> cd jol-quarkus
> mvn -DskipTests package
