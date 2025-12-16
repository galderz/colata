ID ?= uses-min-max
CLASS ?= Test

BOOT_JDK_VERSION ?= 25

default: run

TOPDIR = ..
include $(TOPDIR)/nix-make/MakeBase.gmk
include $(TOPDIR)/nix-make/OpenJDK.gmk

base_jvm_args += -Xbatch
base_jvm_args += -XX:-BackgroundCompilation
base_jvm_args += -XX:-UseOnStackReplacement
base_jvm_args += -XX:-UseSuperWord
base_jvm_args += -XX:-TieredCompilation
base_jvm_args += -XX:CompileCommand=compileonly,$(CLASS)::test
base_jvm_args += -XX:VerifyIterativeGVN=1000

ifdef NO_LOOP_UNROLL
  # Disabling loop unrolling.
  # Can be useful when seeing different assembly in main loop and post/pre loop.
  # Disabling it temporarily can help focus on issues with assembly without having 2 sets of assembly to analyse.
  base_jvm_args += -XX:LoopMaxUnroll=0
endif

comp_jvm_args += -XX:CompileCommand=print,$(CLASS)::test
#comp_jvm_args += -XX:CompileCommand=printcompilation,$(CLASS)::test

ideal_jvm_args += -XX:+PrintIdeal

asm_jvm_args += -XX:+PrintNMethods

#loop_jvm_args += -XX:CompileCommand=PrintIdealPhase,$(CLASS)::test,"AFTER_LOOP_OPTS"
#loop_jvm_args += -XX:CompileCommand=PrintIdealPhase,$(CLASS)::test,"BEFORE_ITER_GVN,AFTER_ITER_GVN"
loop_jvm_args += -XX:CompileCommand=PrintIdealPhase,$(CLASS)::test,"BEFORE_ITER_GVN"

gvn_jvm_args += -XX:+TraceIterativeGVN

super_jvm_args += -XX:+TraceSuperWord

ifdef COMP_ARGS
  jvm_args += $(comp_jvm_args)
endif

ifdef IDEAL_ARGS
  jvm_args += $(ideal_jvm_args)
endif

ifdef ASM_ARGS
  jvm_args += $(asm_jvm_args)
endif

ifdef LOOP_ARGS
  jvm_args += $(loop_jvm_args)
endif

ifdef GVN_ARGS
  jvm_args += $(gvn_jvm_args)
endif

ifdef SUPER_ARGS
  jvm_args += $(super_jvm_args)
endif

ifdef BRANCH_NEVER_MAX
  jvm_args += -XX:+UseNewCode
endif

ifdef BRANCH_NEVER_MIN
  jvm_args += -XX:+UseNewCode2
endif

# E.g. IGV=3 (0 print nothing except IGVPrintLevel directives, 6 all details)
IGV ?=
ifdef IGV
  jvm_args += -XX:PrintIdealGraphLevel=$(IGV)
endif

ifdef NO_UNROLL
  jvm_args += -XX:LoopMaxUnroll=0
endif

AVX ?=
ifdef AVX
  jvm_args += -XX:UseAVX=$(AVX)
endif

jvm_args += $(base_jvm_args)

compile: $(java)
> $(javac) $(javac_args) $(CLASS).java
> $(javap) -v $(CLASS).class
.PHONY: compile

run: clear-logs $(java)
> $(java) \
>   $(jvm_args) $(shell pwd)/$(CLASS).java
.PHONY: run
