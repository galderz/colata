BASE_JDK ?= jdk-valhalla-lworld
CLASS ?= Test
ID ?= array-in-value
REMOTE_NAME ?= valhalla-upstream
REMOTE_BRANCH ?= lworld

# Use JMH snapshot to access xctraceasm profiler
JMH_SNAPSHOT ?= false

# Workaround temporary errors
NO_WARNINGS_ERRORS := true

default: run

TOPDIR = ..
include $(TOPDIR)/nix-make/MakeBase.gmk
include $(TOPDIR)/nix-make/OpenJDK.gmk

base_jvm_args += -Xbatch
base_jvm_args += -Xlog:os
base_jvm_args += -XX:-BackgroundCompilation
base_jvm_args += -XX:CompileCommand=compileonly,$(CLASS)::test

ideal_jvm_args += -XX:CompileCommand=PrintIdealPhase,$(CLASS)::test,"BEFORE_ITER_GVN"

ifdef IDEAL_ARGS
  jvm_args += $(ideal_jvm_args)
endif

valhalla_jvm_args += --enable-preview

jvm_args += $(base_jvm_args)
jvm_args += $(valhalla_jvm_args)

gen_file = target/$(CLASS).java

# todo generate src-gen jar with all dependencies

$(gen_file): $(shell find src-gen -type f -name '*.java' | grep -v '/target/' | sed 's: :\\ :g')
$(gen_file): $(shell find src-gen -type f -name '*.xml' | grep -v '/target/' | sed 's: :\\ :g')
$(gen_file): $(java)
> pushd src-gen
> JAVA_HOME=$(java_home) mvn package
> popd
> $(java) -cp $(shell pwd)/src-gen/target/src-gen.jar:$(HOME)/.m2/repository/com/squareup/javapoet/1.13.0/javapoet-1.13.0.jar src.Gen

gen: $(gen_file)
.PHONY: gen

run: clear-logs $(gen_file)
> $(java) \
>   $(jvm_args) $(shell pwd)/target/$(CLASS).java
.PHONY: run
