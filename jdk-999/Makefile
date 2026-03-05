CLASS ?= Test
JDK_HOME ?= $(HOME)/src/jdk

NO_WARNINGS_ERRORS := true

TOPDIR = ..
include $(TOPDIR)/nix-make/MakeBase.gmk
include $(TOPDIR)/nix-make/OpenJDK.gmk

default: run

run: clear-logs $(java)
> $(call_java) \
>   $(shell pwd)/$(CLASS).java
.PHONY: run
