ID ?= double-while-loop

NO_WARNINGS_ERRORS := true

default: run

TOPDIR = ..
include $(TOPDIR)/make/MakeBase.gmk
include $(TOPDIR)/make/OpenJDK.gmk

benchmarks_jar = $(BENCHMARKS_REPO)/target/benchmarks.jar

ifdef JDK_17_HOME
  RUN_JAVA_HOME = $(JAVA_17_HOME)
else
  RUN_JAVA_HOME = $(java_home)
endif

run: $(benchmarks_jar)
> $(RUN_JAVA_HOME)/bin/java -jar $< org.xceptance.B03* -bm thrpt

$(benchmarks_jar):
> cd $(BENCHMARKS_REPO)
> JAVA_HOME=$(JDK_17_HOME) mvn install
