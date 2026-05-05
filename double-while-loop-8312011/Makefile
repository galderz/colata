ID ?= double-while-loop

NO_WARNINGS_ERRORS := true

default: run

TOPDIR = ..
include $(TOPDIR)/make/MakeBase.gmk
include $(TOPDIR)/make/OpenJDK.gmk

benchmarks_jar = $(BENCHMARKS_REPO)/target/benchmarks.jar

run: $(benchmarks_jar)
> $(JDK_17_HOME)/bin/java -jar $< org.xceptance.B03*

$(benchmarks_jar):
> cd $(BENCHMARKS_REPO)
> JAVA_HOME=$(JDK_17_HOME) mvn install
