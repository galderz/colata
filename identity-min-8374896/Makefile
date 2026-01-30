ID ?= identity-min
CLASS ?= Test

default: run

TOPDIR = ..
include $(TOPDIR)/nix-make/MakeBase.gmk
include $(TOPDIR)/nix-make/OpenJDK.gmk

base_jvm_args += -Xbatch
base_jvm_args += -XX:-BackgroundCompilation
base_jvm_args += -XX:CompileCommand=compileonly,$(CLASS)::test
base_jvm_args += -XX:CompileCommand=dontinline,*::*dontinline*

ifneq ($(CONF),release)
  base_jvm_args += -XX:VerifyIterativeGVN=1000
endif

jvm_args += $(base_jvm_args)

run: print-branch-commit clear-logs $(java)
> $(java) \
>   $(jvm_args) $(shell pwd)/$(CLASS).java
.PHONY: run
