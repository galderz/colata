TOPDIR = ..
include $(TOPDIR)/make/MakeBase.gmk

default: run

BOOT_JDK_VERSION ?= 23
CLASS ?= Test
ID ?= fp-bits-vector
JDK_HOME ?= $(HOME)/1/jdk-$(ID)
include $(TOPDIR)/make/OpenJDK.gmk

base_jvm_args += -Xbatch
base_jvm_args += -Xlog:os
base_jvm_args += -XX:-BackgroundCompilation
base_jvm_args += -XX:CompileCommand=compileonly,$(CLASS)::test

comp_jvm_args += -XX:CompileCommand=print,$(CLASS)::test

ideal_jvm_args += -XX:CompileCommand=PrintIdealPhase,$(CLASS)::test,"BEFORE_LOOP_UNROLLING"
#ideal_jvm_args += -XX:CompileCommand=PrintIdealPhase,$(CLASS)::test,"PHASEIDEALLOOP_ITERATIONS"
#ideal_jvm_args += -XX:+PrintIdeal

vector_jvm_args += -XX:CompileCommand=TraceAutoVectorization,$(CLASS)::test,ALL
vector_jvm_args += -XX:+TraceNewVectors
#vector_jvm_args += -XX:+TraceLoopOpts

method_jvm_args += -XX:+PrintMethodData

ifdef COMP_ARGS
  jvm_args += $(comp_jvm_args)
endif

ifdef IDEAL_ARGS
  jvm_args += $(ideal_jvm_args)
endif

ifdef VECTOR_ARGS
  jvm_args += $(vector_jvm_args)
endif

ifdef METHOD_ARGS
  jvm_args += $(method_jvm_args)
endif

# E.g. IGV=3 (0 print nothing except IGVPrintLevel directives, 6 all details)
IGV ?=
ifdef IGV
  jvm_args += -XX:PrintIdealGraphLevel=$(IGV)
endif

jvm_args += $(base_jvm_args)

run: clear-logs $(java)
> $(call_java) \
>   $(jvm_args) \
>   $(shell pwd)/$(CLASS).java
.PHONY: run
