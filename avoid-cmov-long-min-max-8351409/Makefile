ID ?= avoid-cmov-long-min-max
BASE ?= latest
CLASS ?= Test

default: run

TOPDIR = ..
include $(TOPDIR)/make/MakeBase.gmk
include $(TOPDIR)/make/OpenJDK.gmk

base_jvm_args += -Xbatch
base_jvm_args += -Xlog:os
base_jvm_args += -XX:-BackgroundCompilation
base_jvm_args += -XX:CompileCommand=compileonly,$(CLASS)::test

comp_jvm_args += -XX:CompileCommand=print,$(CLASS)::test
#comp_jvm_args += -XX:CompileCommand=printcompilation,$(CLASS)::test

ifdef COMP_ARGS
  jvm_args += $(comp_jvm_args)
endif

jvm_args += $(base_jvm_args)

run: clear-logs $(java)
> $(call_java) \
>   $(jvm_args) \
>   $(shell pwd)/$(CLASS).java
.PHONY: run
