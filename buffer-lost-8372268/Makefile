ID ?= buffer-lost

default: build-jdk

# Workaround for compiler errors:
# In file included from /Users/g/src/jdk-buffer-lost/test/hotspot/jtreg/vmTestbase/nsk/jvmti/scenarios/multienv/MA04/ma04t002/libma04t002.cpp:33:
#  /Users/g/src/jdk-buffer-lost/test/hotspot/jtreg/vmTestbase/nsk/jvmti/scenarios/multienv/MA04/ma04t002/ma04t002.cpp:129:99: error: variable 'dummy' is uninitialized when passed as a const pointer argument here [-Werror,-Wuninitialized-const-pointer]
#    129 |     if (!NSK_JVMTI_VERIFY(jvmti->IterateOverHeap(JVMTI_HEAP_OBJECT_EITHER, heap_object_callback, &dummy))) {
NO_WARNINGS_ERRORS := true

TOPDIR = ..
include $(TOPDIR)/nix-make/MakeBase.gmk
include $(TOPDIR)/nix-make/OpenJDK.gmk
