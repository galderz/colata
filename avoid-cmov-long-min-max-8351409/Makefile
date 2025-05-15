ID ?= avoid-cmov-long-min-max
CLASS ?= Test

# Temporary workaround lack of JDK 24 Nix packages
BOOT_JDK_VERSION ?= 24

# Workaround for compiler errors after upgrade to Xcode 16.3 on Nix:
# .../src/java.desktop/macosx/native/libjsound/PLATFORM_API_MacOSX_Ports.cpp:127:39: error: variable length arrays in C++ are a Clang extension [-Werror,-Wvla-cxx-extension]
#    127 |                 AudioDeviceID devices[count];
#        |                                       ^~~~~
NO_WARNINGS_ERRORS := true

# Use JMH snapshot to access xctraceasm profiler
JMH_SNAPSHOT ?= true

# Number of forks to run JMH benchmark manually with
JMH_FORKS ?= 0

default: run

TOPDIR = ..
include $(TOPDIR)/nix-make/MakeBase.gmk
include $(TOPDIR)/nix-make/OpenJDK.gmk

base_jvm_args += -Xbatch
base_jvm_args += -Xlog:os
base_jvm_args += -XX:-BackgroundCompilation
base_jvm_args += -XX:CompileCommand=compileonly,$(CLASS)::test

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
>   $(jvm_args) $(shell pwd)/$(CLASS).java
.PHONY: run

jmh_args += -f
jmh_args += $(JMH_FORKS)

ifdef JMH_PROFILERS
  jmh_args += -prof
  jmh_args += $(JMH_PROFILERS)
endif

run-benchmarks: $(benchmarks_jar) test
> $(java) -jar $< MinMaxVector.longReductionMultiplyMax \
>   $(jmh_args) \
>   -p size=2048 \
>   -p probability=100
.PHONY: run-benchmarks
