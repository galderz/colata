CLASS ?= BranchProbability
ID ?= fp-mmv-bench

# Workaround for compiler errors after upgrade to Xcode 16.3 on Nix:
# .../src/java.desktop/macosx/native/libjsound/PLATFORM_API_MacOSX_Ports.cpp:127:39: error: variable length arrays in C++ are a Clang extension [-Werror,-Wvla-cxx-extension]
#    127 |                 AudioDeviceID devices[count];
#        |                                       ^~~~~
NO_WARNINGS_ERRORS := true

default: run

TOPDIR = ..
include $(TOPDIR)/make/MakeBase.gmk
include $(TOPDIR)/make/OpenJDK.gmk

base_jvm_args += -ea

jvm_args += $(base_jvm_args)

call_java += $(java)

run: clear-logs $(java)
> $(call_java) \
>   $(jvm_args) \
>   $(shell pwd)/$(CLASS).java
.PHONY: run
