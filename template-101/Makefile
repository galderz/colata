ID ?= template-101
CLASS ?= Test

# Use JMH snapshot to access xctraceasm profiler
JMH_SNAPSHOT ?= false

# Workaround temporary errors
NO_WARNINGS_ERRORS := true

default: run

base_jvm_args += --enable-preview
base_jvm_args += -Xbatch
base_jvm_args += -Xlog:os
base_jvm_args += -XX:-BackgroundCompilation
base_jvm_args += -XX:CompileCommand=compileonly,$(CLASS)::test

ideal_jvm_args += -XX:+PrintIdeal

ifdef IDEAL_ARGS
  jvm_args += $(ideal_jvm_args)
endif

# Avoid escape analysis
jvm_args += -XX:-DoEscapeAnalysis

jvm_args += $(base_jvm_args)

TOPDIR = ..
include $(TOPDIR)/nix-make/MakeBase.gmk
include $(TOPDIR)/nix-make/OpenJDK.gmk

run: clear-logs $(java)
> $(java) \
>   $(jvm_args) $(shell pwd)/$(CLASS).java
.PHONY: run
