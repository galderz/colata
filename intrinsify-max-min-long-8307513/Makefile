TOPDIR = ..
include $(TOPDIR)/make/MakeBase.gmk

default: run

ID ?= intrinsify-max-min-long

BOOT_JDK_VERSION ?= 23
CLASS ?= Test
JDK_HOME ?= $(HOME)/1/jdk-$(ID)
PATTERN ?= test
PROBABILITY ?= 100
include $(TOPDIR)/make/OpenJDK.gmk

AVX ?=
ifdef AVX
  jvm_args += -XX:UseAVX=$(AVX)
endif

SVE ?=
ifdef SVE
  jvm_args += -XX:UseSVE=$(SVE)
endif

base_jvm_args += -Xbatch
base_jvm_args += -Xlog:os
base_jvm_args += -XX:-BackgroundCompilation
base_jvm_args += -XX:CompileCommand=compileonly,$(CLASS)::$(PATTERN)

comp_jvm_args = -XX:CompileCommand=printcompilation,$(CLASS)::$(PATTERN)
#comp_jvm_args = -XX:CompileCommand=print,$(CLASS)::$(PATTERN)
#comp_jvm_args += -XX:+LogCompilation
#comp_jvm_args += -XX:+PrintAssembly

ideal_jvm_args += -XX:+PrintIdeal
#ideal_jvm_args += -XX:CompileCommand=PrintIdealPhase,$(CLASS)::$(PATTERN),"BEFORE_MACRO_EXPANSION"
#ideal_jvm_args += -XX:CompileCommand=PrintIdealPhase,$(CLASS)::$(PATTERN),"ITER_GVN4"
#ideal_jvm_args += -XX:CompileCommand=PrintIdealPhase,$(CLASS)::$(PATTERN),"BEFORE_REMOVEUSELESS"
#ideal_jvm_args += -XX:CompileCommand=PrintIdealPhase,$(CLASS)::$(PATTERN),"BEFORE_BEAUTIFY_LOOPS"
#ideal_jvm_args += -XX:CompileCommand=PrintIdealPhase,$(CLASS)::$(PATTERN),"AFTER_BEAUTIFY_LOOPS"
#ideal_jvm_args += -XX:CompileCommand=PrintIdealPhase,$(CLASS)::$(PATTERN),"PHASEIDEALLOOP_ITERATIONS"
#ideal_jvm_args += -XX:CompileCommand=PrintIdealPhase,$(CLASS)::$(PATTERN),"BARRIER_EXPANSION"
#ideal_jvm_args += -XX:CompileCommand=PrintIdealPhase,$(CLASS)::$(PATTERN),"OPTIMIZE_FINISHED"

loop_jvm_args += -XX:+TraceLoopOpts

vector_jvm_args += -XX:CompileCommand=TraceAutoVectorization,$(CLASS)::$(PATTERN),ALL
vector_jvm_args += -XX:+TraceNewVectors

jvm_args += $(base_jvm_args)

ifdef COMP_ARGS
  jvm_args += $(comp_jvm_args)
endif

ifdef IDEAL_ARGS
  jvm_args += $(ideal_jvm_args)
endif

ifdef VECTOR_ARGS
  jvm_args += $(vector_jvm_args)
endif

ifdef LOOP_ARGS
  jvm_args += $(loop_jvm_args)
endif

# Other args
#jvm_args += -XX:+PrintCompilation

OSR ?= true
ifeq ($(OSR),false)
  jvm_args += -XX:-UseOnStackReplacement
endif

# E.g. IGV=3 (0 print nothing except IGVPrintLevel directives, 6 all details)
IGV ?=
ifdef IGV
  jvm_args += -XX:PrintIdealGraphLevel=$(IGV)
endif

run: clear-logs $(java)
> $(call_java) \
>   $(jvm_args) \
>   $(shell pwd)/$(CLASS).java $(PROBABILITY)
.PHONY: run

perf: $(java)
> cd $(JDK_HOME)
> CONF=$(conf_name) make test TEST="test/hotspot/jtreg/compiler/loopopts/superword/ReductionPerf.java"
> grep -E -i -w '^(long max|long min)' $(java_build_dir)/test-support/jtreg_test_hotspot_jtreg_compiler_loopopts_superword_ReductionPerf_java/compiler/loopopts/superword/ReductionPerf.jtr
.PHONY: perf

rr: $(java)
> rr $(java) \
>   -XX:CompileCommand=printcompilation,$(CLASS)::$(PATTERN) \
>   -XX:CompileCommand=compileonly,$(CLASS)::$(PATTERN) \
>   -Xbatch \
>   -XX:+TraceLoopOpts \
>   -XX:+TraceSuperWord \
>   -XX:LoopMaxUnroll=5 \
>   $(shell pwd)/$(CLASS).java
.PHONY: rr

benchmarks_dir = benchmarks
benchmarks_jar = $(benchmarks_dir)/target/benchmarks.jar

$(benchmarks_jar): $(shell find $(benchmarks_dir)/src -type f -name '*.java')
$(benchmarks_jar): $(java)
> pushd $(benchmarks_dir)
> JAVA_HOME=$(opt)/java-21 $(opt)/boot-maven-3/bin/mvn verify
> popd
> touch $@

benchmarks: $(benchmarks_jar)
> $(java) -jar $< MinMaxLoop.longLoop \
>   -f 1 \
>   -prof perf \
>   -prof perfnorm \
>   -prof perfasm \
>   -jvmArgs -XX:+UnlockExperimentalVMOptions \
>   -jvmArgs -XX:+UseEpsilonGC \
>   -jvmArgs -XX:-UseOnStackReplacement \
>   -jvmArgs -XX:LoopStripMiningIter=0 \
>   -p size=10000 \
.PHONY: benchmarks

clean-benchmarks: $(benchmarks_jar)
> pushd $(benchmarks_dir)
> JAVA_HOME=$(opt)/java-21 $(opt)/boot-maven-3/bin/mvn clean
> popd
.PHONY: clean-benchmarks

# Other flags used:
# >   -ea \
# >   -XX:CompileCommand=print,$(CLASS)::$(PATTERN) \
# >   -XX:+LogCompilation \
# >   -XX:+PrintCFG \
# >   -XX:+PrintIdeal \
# >   -XX:+PrintIR \
# >   -XX:+PrintLIRWithAssembly \
# >   -XX:+PrintNMethods \
# >   -XX:+PrintMethodData \
# >   -XX:+PrintOptoAssembly \
# >   -XX:+PrintIdeal \
# >   -XX:+PrintIntrinsics \
# >   -XX:+TraceLoopOpts \
# >   -XX:+TraceNewVectors \
# >   -XX:+TraceOptoParse \
# >   -XX:+TraceSuperWord \
# >   -XX:CompileCommand=PrintIdealPhase,$(CLASS)::$(PATTERN),"BEFORE_MACRO_EXPANSION,AFTER_MACRO_EXPANSION_STEP"

# Other env variables used:
> DYLD_PRINT_LIBRARIES=1 \
