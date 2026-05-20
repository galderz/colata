ID ?= double-while-loop

NO_WARNINGS_ERRORS := true

default: run

TOPDIR = ..
include $(TOPDIR)/make/MakeBase.gmk
include $(TOPDIR)/make/OpenJDK.gmk

benchmarks_jar = $(BENCHMARKS_REPO)/target/benchmarks.jar

trace_jvm_args += -Xbatch
trace_jvm_args += -XX:+TraceLoopOpts
trace_jvm_args += -XX:-TieredCompilation
trace_jvm_args += -XX:CompileCommand=compileonly,*Csv*::parse
trace_jvm_args += -XX:CompileCommand=dontinline,*Blackhole::consume
trace_jvm_args += -XX:CompileCommand=dontinline,com.xceptance.common.util.SimpleArrayList::clear

NIXOS := $(wildcard /etc/NIXOS)

ifdef NIXOS
  RUN_CMD += numactl
  RUN_CMD += --physcpubind=0,2,4,6,8,10
  RUN_CMD += --membind=0
  HIGH_FREQ = 1900
  LOW_FREQ = 800
endif

RUN_CMD += $(java)

# Tracing
#
# BENCHMARK=B05f_QuotedWarmupAndUnquotedTest make trace

TRACE_CMD += $(RUN_CMD)

ifdef JVM_ARGS_APPEND
  TRACE_CMD += $(trace_jvm_args)
  TRACE_CMD += $(JVM_ARGS_APPEND)
else ifdef JVM_ARGS
  TRACE_CMD += $(JVM_ARGS)
else
  TRACE_CMD += $(trace_jvm_args)
endif

run: low-freq run-benchmark high-freq
.PHONY: run

run-benchmark: clear-logs
run-benchmark: $(benchmarks_jar)
> $(RUN_CMD) -jar $< -bm thrpt -tu ms -rff result.csv
.PHONY: run-benchmark

$(benchmarks_jar):
> cd $(BENCHMARKS_REPO)
> JAVA_HOME=$(JAVA_21_HOME) mvn install

low-freq:
ifeq ($(shell uname -s),Linux)
> $(TOPDIR)/make/set-cpu-freq.sh $(LOW_FREQ)
endif
.PHONY: low-freq

high-freq:
ifeq ($(shell uname -s),Linux)
> $(TOPDIR)/make/set-cpu-freq.sh $(HIGH_FREQ)
endif
.PHONY: high-freq

trace: clear-logs
trace: $(benchmarks_jar)
> $(TRACE_CMD) -jar $< -bm thrpt -tu ms -i 3 -wi 5 -f 0 $(BENCHMARK)
.PHONY: trace
