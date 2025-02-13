TOPDIR = ..
include $(TOPDIR)/make/MakeBase.gmk

default: run

BOOT_JDK_VERSION ?= 23
CLASS ?= Test
JDK_HOME ?= $(HOME)/1/jdk
include $(TOPDIR)/make/OpenJDK.gmk

run: clear-logs $(java)
> $(call_java) \
>   $(shell pwd)/$(CLASS).java
.PHONY: run
