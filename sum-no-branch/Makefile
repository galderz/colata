TOPDIR = ..
include $(TOPDIR)/make/MakeBase.gmk

default: run

CLASS ?= Test
JDK_HOME ?= $(HOME)/1/jdk-sum-no-branch
BOOT_JDK_VERSION ?= 23
include $(TOPDIR)/make/OpenJDK.gmk

base_jvm_args += -Xbatch
base_jvm_args += -Xlog:os
base_jvm_args += -XX:-BackgroundCompilation
base_jvm_args += -XX:CompileCommand=compileonly,$(CLASS)::test

jvm_args += $(base_jvm_args)

comp_jvm_args += -XX:+LogCompilation
comp_jvm_args += -XX:+PrintAssembly

ifdef COMP_ARGS
  jvm_args += $(comp_jvm_args)
endif

vector_jvm_args += -XX:CompileCommand=TraceAutoVectorization,$(CLASS)::test,ALL
vector_jvm_args += -XX:+TraceNewVectors

ifdef VECTOR_ARGS
  jvm_args += $(vector_jvm_args)
endif

run: $(java)
> $(call_java) \
>   $(jvm_args) \
>   $(shell pwd)/$(CLASS).java
.PHONY: run
