ID ?= use-random-data

# Temporary workaround lack of JDK 24 Nix packages
BOOT_JDK_VERSION ?= 24

ifeq ($(os),darwin)
  # Use JMH snapshot to access xctraceasm profiler
  JMH_SNAPSHOT := true
else ifeq ($(os),linux)
  JMH_SNAPSHOT := false
endif

default: run

TOPDIR = ..
include $(TOPDIR)/nix-make/MakeBase.gmk
include $(TOPDIR)/nix-make/OpenJDK.gmk

run: test
> cat $(java_build_dir)/test-support/jtreg_test_hotspot_jtreg_compiler_loopopts_superword_MinMaxRed_Long_java/compiler/loopopts/superword/MinMaxRed_Long.jtr
.PHONY: run
