ID ?= double-while-loop

NO_WARNINGS_ERRORS := true

default: run

TOPDIR = ..
include $(TOPDIR)/make/MakeBase.gmk
include $(TOPDIR)/make/OpenJDK.gmk

benchmarks_jar = $(BENCHMARKS_REPO)/target/benchmarks.jar

ifdef JAVA_17_HOME
  RUN_JAVA_HOME = $(JAVA_17_HOME)
else
  RUN_JAVA_HOME = $(java_home)
endif

NIXOS := $(wildcard /etc/NIXOS)

ifdef NIXOS
  RUN_PREFIX = "numactl --cpunodebind=1 --membind=1"
  HIGH_FREQ = 1900
  LOW_FREQ = 800
else
  RUN_PREFIX = ""
endif

run: low-freq run-benchmark high-freq
.PHONY: run

run-benchmark: $(benchmarks_jar)
> $(RUN_PREFIX) $(RUN_JAVA_HOME)/bin/java -jar $< -bm thrpt -tu ms -rff result.csv
.PHONY: run-benchmark

$(benchmarks_jar):
> cd $(BENCHMARKS_REPO)
> JAVA_HOME=$(JDK_17_HOME) mvn install

low-freq:
> TOPDIR/make/set-cpu-freq.sh $(LOW_FREQ)
.PHONY: low-freq

high-freq:
> TOPDIR/make/set-cpu-freq.sh $(HIGH_FREQ)
.PHONY: high-freq
