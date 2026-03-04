ID ?= buffer-lost
CLASS ?= Test

default: run

# Workaround for compiler errors:
# In file included from /Users/g/src/jdk-buffer-lost/test/hotspot/jtreg/vmTestbase/nsk/jvmti/scenarios/multienv/MA04/ma04t002/libma04t002.cpp:33:
#  /Users/g/src/jdk-buffer-lost/test/hotspot/jtreg/vmTestbase/nsk/jvmti/scenarios/multienv/MA04/ma04t002/ma04t002.cpp:129:99: error: variable 'dummy' is uninitialized when passed as a const pointer argument here [-Werror,-Wuninitialized-const-pointer]
#    129 |     if (!NSK_JVMTI_VERIFY(jvmti->IterateOverHeap(JVMTI_HEAP_OBJECT_EITHER, heap_object_callback, &dummy))) {
NO_WARNINGS_ERRORS := true

TOPDIR = ..
include $(TOPDIR)/nix-make/MakeBase.gmk
include $(TOPDIR)/nix-make/OpenJDK.gmk

base_jvm_args += -Xbatch
base_jvm_args += -Xlog:os
base_jvm_args += -XX:-BackgroundCompilation
base_jvm_args += -XX:CompileCommand=compileonly,$(CLASS)::test
base_jvm_args += -XX:CompileCommand=dontinline,*::*dontinline*
# Default scenario
base_jvm_args += --enable-preview
# base_jvm_args += --add-exports
# base_jvm_args += java.base/jdk.internal.value=ALL-UNNAMED
# base_jvm_args += --add-exports
# base_jvm_args += java.base/jdk.internal.vm.annotation=ALL-UNNAMED
# base_jvm_args += --add-exports
# base_jvm_args += java.base/jdk.internal.misc=ALL-UNNAMED
base_jvm_args += -XX:+IgnoreUnrecognizedVMOptions
base_jvm_args += -DVerifyIR=false
base_jvm_args += -XX:+AlwaysIncrementalInline
base_jvm_args += -XX:FlatArrayElementMaxOops=0
base_jvm_args += -XX:-UseArrayFlattening
base_jvm_args += -XX:-UseFieldFlattening
base_jvm_args += -XX:+InlineTypePassFieldsAsArgs
base_jvm_args += -XX:+InlineTypeReturnedAsFields
# Extra parameter
base_jvm_args += -XX:-UseArrayFlattening

jvm_args += $(base_jvm_args)

run: print-branch-commit clear-logs $(java)
> $(java) \
>   $(jvm_args) $(shell pwd)/$(CLASS).java
.PHONY: run
