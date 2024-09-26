TOPDIR = ..
include $(TOPDIR)/make/MakeBase.gmk

default: run

BOOT_JDK_VERSION ?= 22
CLASS ?= Test
JDK_HOME ?= $(HOME)/1/valhalla-lworld
include $(TOPDIR)/make/OpenJDK.gmk

run: clear-logs $(java)
> $(call_java) \
>   $(jvm_args) \
>   $(shell pwd)/$(CLASS).java
.PHONY: run
