ID ?= template-101
CLASS ?= Test

# Use JMH snapshot to access xctraceasm profiler
JMH_SNAPSHOT ?= false

# Workaround temporary errors
NO_WARNINGS_ERRORS := true

default: run

base_jvm_args += -Xbatch
base_jvm_args += -Xlog:os
base_jvm_args += -XX:-BackgroundCompilation
base_jvm_args += -XX:CompileCommand=compileonly,$(CLASS)::test

ideal_jvm_args += -XX:CompileCommand=PrintIdealPhase,$(CLASS)::test,"BEFORE_ITER_GVN"
#ideal_jvm_args += -XX:CompileCommand=PrintIdealPhase,$(CLASS)::test,"AFTER_MACRO_EXPANSION"
#ideal_jvm_args += -XX:+PrintIdeal

ifdef IDEAL_ARGS
  jvm_args += $(ideal_jvm_args)
endif

# Preview required
valhalla_jvm_args += --enable-preview
# Avoid escape analysis
valhalla_jvm_args += -XX:-DoEscapeAnalysis
# Print eliminated allocations
valhalla_jvm_args += -XX:+PrintEliminateAllocations
valhalla_jvm_args += -XX:+PrintOptoStatistics
# Print field layout
valhalla_jvm_args += -XX:+PrintFieldLayout
valhalla_jvm_args += -XX:+PrintInlining

jvm_args += $(base_jvm_args)
jvm_args += $(valhalla_jvm_args)

TOPDIR = ..
include $(TOPDIR)/nix-make/MakeBase.gmk
include $(TOPDIR)/nix-make/OpenJDK.gmk

run: clear-logs $(java)
> $(java) \
>   $(jvm_args) $(shell pwd)/$(CLASS).java
.PHONY: run
