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

# Disabling loop unrolling.
# Can be useful when seeing different assembly in main loop and post/pre loop.
# Disabling it temporarily can help focus on issues with assembly without having 2 sets of assembly to analyse.
# base_jvm_args += -XX:LoopMaxUnroll=0

comp_jvm_args += -XX:CompileCommand=print,$(CLASS)::test
#comp_jvm_args += -XX:CompileCommand=printcompilation,$(CLASS)::test

ideal_jvm_args += -XX:+PrintIdeal

asm_jvm_args += -XX:+PrintNMethods
#asm_jvm_args += -XX:+PrintAssembly

ifdef COMP_ARGS
  jvm_args += $(comp_jvm_args)
endif

ifdef IDEAL_ARGS
  jvm_args += $(ideal_jvm_args)
endif

ifdef ASM_ARGS
  jvm_args += $(asm_jvm_args)
endif

jvm_args += $(base_jvm_args)

run: clear-logs $(java)
> $(java) \
>   $(jvm_args) \
>   $(shell pwd)/$(CLASS).java
.PHONY: run
