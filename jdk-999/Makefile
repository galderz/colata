CLASS ?= Test
JDK_HOME ?= $(HOME)/src/jdk

NO_WARNINGS_ERRORS := true

TOPDIR = ..
include $(TOPDIR)/make/MakeBase.gmk
include $(TOPDIR)/make/OpenJDK.gmk

default: run

run: clear-logs $(java)
> $(call_java) \
>   $(shell pwd)/$(CLASS).java
.PHONY: run
