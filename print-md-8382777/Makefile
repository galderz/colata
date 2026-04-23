CLASS ?= Test
ID ?= print-md

NO_WARNINGS_ERRORS := true

default: run

TOPDIR = ..
include $(TOPDIR)/make/MakeBase.gmk
include $(TOPDIR)/make/OpenJDK.gmk

base_jvm_args += -Xbatch
base_jvm_args += -XX:CompileCommand=compileonly,$(CLASS)::test
base_jvm_args += -XX:CompileCommand=printcompilation,$(CLASS)::*
base_jvm_args += -XX:-TieredCompilation

# Use these exact JVM arguments, examples:
#
# Inspect which methods are compiled:
# JVM_ARGS=-XX:CompileCommand=printcompilation,*::*
#
# Narrow down the methods
# JVM_ARGS=-XX:CompileCommand=printcompilation,First::*
#
# Force all executions to run on interpreter
# JVM_ARGS="-Xint -XX:CompileCommand=printcompilation,First::*"
#
# Disable background compilation
# JVM_ARGS="-Xbatch -XX:CompileCommand=printcompilation,First::*"
#
# Stop at C1 compilation:
# JVM_ARGS="-XX:TieredStopAtLevel=3 -Xbatch -XX:CompileCommand=compileonly,First::test -XX:CompileCommand=printcompilation,First::*"
#
# Only C2 compilation:
# JVM_ARGS="-XX:-TieredCompilation -Xbatch -XX:CompileCommand=compileonly,First::test -XX:CompileCommand=printcompilation,First::*"
JVM_ARGS ?=

# Append to default JVM arguments, examples:
#
# Display the C2 machine independent IR:
# JVM_ARGS_APPEND=-XX:+PrintIdeal
#
# Display assembly, OptoAssembly output and bytecode
# JVM_ARGS_APPEND=-XX:CompileCommand=print,First::test
#
# Display assembly and OptoAssembly output (without bytecode)
# JVM_ARGS_APPEND=-XX:CompileCommand=printassembly,First::test
#
# Display inlining decisions
# JVM_ARGS_APPEND=-XX:CompileCommand=printinlining,Inline::test
#
# Display CPU information
# JVM_ARGS_APPEND=-Xlog:os+cpu=info
#
# Display method data, e.g. branch taken/not-taken counters while on interpreter
# JVM_ARGS_APPEND=-XX:+PrintMethodData
JVM_ARGS_APPEND ?=

ifdef JVM_ARGS_APPEND
  jvm_args += $(base_jvm_args)
  jvm_args += $(JVM_ARGS_APPEND)
else ifdef JVM_ARGS
  jvm_args += $(JVM_ARGS)
else
  jvm_args += $(base_jvm_args)
endif

ifdef RR
  call_java += rr
endif

call_java += $(java)

run: clear-logs $(java)
> $(call_java) \
>   $(jvm_args) \
>   $(shell pwd)/$(CLASS).java
.PHONY: run
