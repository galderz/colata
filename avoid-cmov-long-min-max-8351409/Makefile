ID ?= avoid-cmov-long-min-max
CLASS ?= Test

default: run

TOPDIR = ..
include $(TOPDIR)/nix-make/MakeBase.gmk
include $(TOPDIR)/nix-make/OpenJDK.gmk

base_jvm_args += -Xbatch
base_jvm_args += -Xlog:os
base_jvm_args += -XX:-BackgroundCompilation
base_jvm_args += -XX:CompileCommand=compileonly,$(CLASS)::test

comp_jvm_args += -XX:CompileCommand=print,$(CLASS)::test
#comp_jvm_args += -XX:CompileCommand=printcompilation,$(CLASS)::test

ideal_jvm_args += -XX:+PrintIdeal

ifdef COMP_ARGS
  jvm_args += $(comp_jvm_args)
endif

ifdef IDEAL_ARGS
  jvm_args += $(ideal_jvm_args)
endif

jvm_args += $(base_jvm_args)

run: clear-logs $(java)
> $(java) \
>   $(jvm_args) \
>   $(shell pwd)/$(CLASS).java
.PHONY: run
