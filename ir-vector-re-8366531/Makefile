CLASS ?= Test
ID ?= ir-vector-re

NO_WARNINGS_ERRORS := true

default: run

TOPDIR = ..
include $(TOPDIR)/make/MakeBase.gmk
include $(TOPDIR)/make/OpenJDK.gmk

base_jvm_args += -Xbatch
base_jvm_args += -XX:CompileCommand=compileonly,$(CLASS)::test
base_jvm_args += -XX:CompileCommand=printcompilation,$(CLASS)::*
base_jvm_args += -XX:-TieredCompilation

ifdef JVM_ARGS_APPEND
  jvm_args += $(base_jvm_args)
  jvm_args += $(JVM_ARGS_APPEND)
else ifdef JVM_ARGS
  jvm_args = $(JVM_ARGS)
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
