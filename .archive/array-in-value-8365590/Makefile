BASE_JDK ?= jdk-valhalla-lworld
CLASS ?= Test
ID ?= array-in-value
REMOTE_NAME ?= valhalla-upstream
REMOTE_BRANCH ?= lworld

# Workaround temporary errors
NO_WARNINGS_ERRORS := true

default: run

TOPDIR = ..
include $(TOPDIR)/nix-make/MakeBase.gmk
include $(TOPDIR)/nix-make/OpenJDK.gmk

target = $(shell pwd)/target/$(CLASS)

base_jvm_args += -Xbatch
base_jvm_args += -Xlog:os
base_jvm_args += -XX:-BackgroundCompilation
base_jvm_args += -XX:CompileCommand=compileonly,Test::test

#ideal_jvm_args += -XX:CompileCommand=PrintIdealPhase,Test::test,"BEFORE_MACRO_EXPANSION"
ideal_jvm_args += -XX:CompileCommand=PrintIdealPhase,Test::test,"BEFORE_ITER_GVN"
#ideal_jvm_args += -XX:+PrintIdeal

ifdef IDEAL_ARGS
  jvm_args += $(ideal_jvm_args)
endif

valhalla_jvm_args += --enable-preview
valhalla_jvm_args += -XX:-DoEscapeAnalysis
valhalla_jvm_args += -XX:+PrintEliminateAllocations
valhalla_jvm_args += -XX:+PrintOptoStatistics
#valhalla_jvm_args += -XX:+PrintFieldLayout

jvm_args += $(base_jvm_args)
jvm_args += $(valhalla_jvm_args)

javac_args += --enable-preview
javac_args += --source
javac_args += 25

# E.g. IGV=3 (0 print nothing except IGVPrintLevel directives, 6 all details)
IGV ?=
ifdef IGV
  jvm_args += -XX:PrintIdealGraphLevel=$(IGV)
endif

gen_file = $(target)/Test.java

# todo generate src-gen jar with all dependencies

$(gen_file): $(shell find src-gen -type f -name '*.java' | grep -v '/target/' | sed 's: :\\ :g')
$(gen_file): $(shell find src-gen -type f -name '*.xml' | grep -v '/target/' | sed 's: :\\ :g')
$(gen_file): $(java)
> pushd src-gen
> JAVA_HOME=$(java_home) mvn package
> popd
> mkdir -p $(target)
> $(java) -cp $(shell pwd)/src-gen/target/src-gen.jar:$(HOME)/.m2/repository/com/squareup/javapoet/1.13.0/javapoet-1.13.0.jar src.Gen $(CLASS)

gen: $(gen_file)
.PHONY: gen

run: clear-logs $(java)
> cd $(target)
> $(java) \
>   $(jvm_args) Test.java
.PHONY: run

compile: $(java)
> cd $(target)
> $(javac) $(javac_args) $(CLASS).java
> $(javap) -v Test.class
