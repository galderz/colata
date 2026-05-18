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
else
  RUN_PREFIX = ""
endif

run: $(benchmarks_jar)
> $(RUN_PREFIX) $(RUN_JAVA_HOME)/bin/java -jar $< -bm thrpt -tu ms -rff results.csv

$(benchmarks_jar):
> cd $(BENCHMARKS_REPO)
> JAVA_HOME=$(JDK_17_HOME) mvn install
