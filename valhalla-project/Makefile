REMOTE_NAME ?= valhalla
REMOTE_BRANCH ?= lworld

ID ?= $(REMOTE_NAME)-$(REMOTE_BRANCH)
CLASS ?= Test
WORKTREE ?= project

# Workaround temporary errors
NO_WARNINGS_ERRORS := true

default: run

TOPDIR = ..
include $(TOPDIR)/nix-make/MakeBase.gmk
include $(TOPDIR)/nix-make/OpenJDK.gmk

base_jvm_args += -Xbatch
base_jvm_args += -Xlog:os
base_jvm_args += -XX:-BackgroundCompilation
base_jvm_args += -XX:CompileCommand=compileonly,$(CLASS)::test

jvm_args += $(base_jvm_args)

# E.g. IGV=3 (0 print nothing except IGVPrintLevel directives, 6 all details)
IGV ?=
ifdef IGV
  jvm_args += -XX:PrintIdealGraphLevel=$(IGV)
endif

jvm_args += --enable-preview
#jvm_args += -XX:+PrintIdeal
#jvm_args += -XX:CompileCommand=PrintIdealPhase,$(CLASS).test,"OPTIMIZE_FINISHED"

run: clear-logs $(java)
> $(java) \
>   $(jvm_args) $(shell pwd)/$(CLASS).java
.PHONY: run
