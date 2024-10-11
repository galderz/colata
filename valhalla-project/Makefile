TOPDIR = ..
include $(TOPDIR)/make/MakeBase.gmk

default: run

BOOT_JDK_VERSION ?= 22
CLASS ?= Scalarization
JDK_HOME ?= $(HOME)/1/valhalla-lworld
include $(TOPDIR)/make/OpenJDK.gmk

jvm_args += --enable-preview
#jvm_args += -XX:+PrintIdeal
#jvm_args += -XX:CompileCommand=PrintIdealPhase,$(CLASS).test,"OPTIMIZE_FINISHED"

run: clear-logs $(java)
> $(call_java) \
>   $(jvm_args) \
>   $(shell pwd)/$(CLASS).java
.PHONY: run
