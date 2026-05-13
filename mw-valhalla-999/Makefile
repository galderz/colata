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
include $(TOPDIR)/make/Hibernate.gmk
include $(TOPDIR)/make/Quarkus.gmk

JOL_CLASS ?= RequestMatch

jol_quarkus_jar = jol-quarkus/target/jol-quarkus.jar
quarkus_jar = getting-started-command-mode/target/quarkus-app/quarkus-run.jar
hibernate_jar = hibernate-orm-quickstart/target/quarkus-app/quarkus-run.jar

run-hibernate: $(hibernate_jar)
> $(compile_jdk)/bin/java -jar $<

$(hibernate_jar): $(shell find hibernate-orm-quickstart/src -type f -name '*.java')
$(hibernate_jar): $(quarkus_extensions_hibernate_orm_jar)
> cd hibernate-orm-quickstart
> JAVA_HOME=$(compile_jdk) ./mvnw package -DskipTests

run-quarkus: $(quarkus_jar)
> $(java) -XX:+PrintFieldLayout --enable-preview -jar $<

$(quarkus_jar): $(shell find getting-started-command-mode/src -type f -name '*.java')
$(quarkus_jar): getting-started-command-mode/pom.xml
> cd getting-started-command-mode
> JAVA_HOME=$(compile_jdk) ./mvnw package

run-jol: $(jol_quarkus_jar)
> $(boot_jdk_java) -cp $< jol.quarkus.$(JOL_CLASS)Jol

$(jol_quarkus_jar): $(shell find jol-quarkus/src -type f -name '*.java')
$(jol_quarkus_jar): jol-quarkus/pom.xml
> cd jol-quarkus
> mvn -DskipTests package

clean:
> rm -drf jol-quarkus/target
> rm -drf getting-started-command-mode/target
.PHONY: clean
