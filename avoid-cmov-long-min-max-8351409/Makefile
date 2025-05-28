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
JMH_FORKS ?= 1

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

ifdef NO_SUPERWORD
  jvm_args += -XX:-UseSuperWord
endif

ifdef BRANCH_NEVER_MAX
  jvm_args += -XX:+UseNewCode
endif

ifdef BRANCH_NEVER_MIN
  jvm_args += -XX:+UseNewCode2
endif

jvm_args += $(base_jvm_args)

run: clear-logs $(java)
> $(java) \
>   $(jvm_args) $(shell pwd)/$(CLASS).java
.PHONY: run

fork_jmh_args += -jar
fork_jmh_args += $(benchmarks_jar)
fork_jmh_args += MinMaxVector.longReductionMultiplyMax
fork_jmh_args += -f
fork_jmh_args += $(JMH_FORKS)
fork_jmh_args += -jvmArgs
fork_jmh_args += -XX:-UseSuperWord
fork_jmh_args += -p
fork_jmh_args += size=2048
fork_jmh_args += -p
fork_jmh_args += probability=100

ifdef JMH_PROFILERS
  jmh_args += -prof
  jmh_args += $(JMH_PROFILERS)
endif

fork-benchmarks: $(benchmarks_jar)
> $(java) \
>   $(fork_jmh_args)
.PHONY: fork-benchmarks

debug_jmh_args += -Xbatch
debug_jmh_args += -XX:-BackgroundCompilation
debug_jmh_args += -XX:CompileCommand=compileonly,org.openjdk.bench.java.lang.MinMaxVector::longReductionMultiplyMax
debug_jmh_args += -XX:+PrintNMethods
debug_jmh_args += -XX:-UseSuperWord
debug_jmh_args += -jar
debug_jmh_args += $(benchmarks_jar)
debug_jmh_args += MinMaxVector.longReductionMultiplyMax
debug_jmh_args += -f
debug_jmh_args += 0
debug_jmh_args += -p
debug_jmh_args += size=2048
debug_jmh_args += -p
debug_jmh_args += probability=100

debug-benchmarks: $(benchmarks_jar)
> $(java) \
>   $(debug_jmh_args)
.PHONY: debug-benchmarks
