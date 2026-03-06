ID ?= segment-ir-tests
CLASS ?= Test

# Workaround for compiler errors after upgrade to Xcode 16.3 on Nix:
# .../src/java.desktop/macosx/native/libjsound/PLATFORM_API_MacOSX_Ports.cpp:127:39: error: variable length arrays in C++ are a Clang extension [-Werror,-Wvla-cxx-extension]
#    127 |                 AudioDeviceID devices[count];
#        |                                       ^~~~~
NO_WARNINGS_ERRORS := true

default: run

TOPDIR = ..
include $(TOPDIR)/make/MakeBase.gmk
include $(TOPDIR)/make/OpenJDK.gmk

base_jvm_args += -Xbatch
base_jvm_args += -XX:-BackgroundCompilation
base_jvm_args += -XX:CompileCommand=compileonly,$(CLASS)::test
base_jvm_args += -XX:CompileCommand=dontinline,*::*dontinline*

ifdef IDEAL
  jvm_args += -XX:+PrintIdeal
endif

jvm_args += $(base_jvm_args)

run: print-branch-commit clear-logs $(java)
> $(java) \
>   $(jvm_args) $(shell pwd)/$(CLASS).java
.PHONY: run
