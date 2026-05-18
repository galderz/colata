ID ?= double-while-loop

NO_WARNINGS_ERRORS := true

default: run

TOPDIR = ..
include $(TOPDIR)/make/MakeBase.gmk
include $(TOPDIR)/make/OpenJDK.gmk

benchmarks_jar = $(BENCHMARKS_REPO)/target/benchmarks.jar

NIXOS := $(wildcard /etc/NIXOS)

ifdef NIXOS
  RUN_CMD += numactl
  RUN_CMD += --cpunodebind=1
  RUN_CMD += --membind=1
  HIGH_FREQ = 1900
  LOW_FREQ = 800
endif

ifdef JAVA_17_HOME
  RUN_CMD = $(JAVA_17_HOME)/bin/java
else
  RUN_CMD = $(java_home)/bin/java
endif

run: low-freq run-benchmark high-freq
.PHONY: run

run-benchmark: $(benchmarks_jar)
> $(RUN_CMD) -jar $< -bm thrpt -tu ms -rff result.csv
.PHONY: run-benchmark

$(benchmarks_jar):
> cd $(BENCHMARKS_REPO)
> JAVA_HOME=$(JDK_17_HOME) mvn install

low-freq:
> $(TOPDIR)/make/set-cpu-freq.sh $(LOW_FREQ)
.PHONY: low-freq

high-freq:
> TOPDIR/make/set-cpu-freq.sh $(HIGH_FREQ)
.PHONY: high-freq
