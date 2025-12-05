ID ?= use-random-data

default: run

TOPDIR = ..
include $(TOPDIR)/nix-make/MakeBase.gmk
include $(TOPDIR)/nix-make/OpenJDK.gmk

run: test
> cat $(java_build_dir)/test-support/jtreg_test_hotspot_jtreg_compiler_loopopts_superword_MinMaxRed_Long_java/compiler/loopopts/superword/MinMaxRed_Long.jtr
.PHONY: run
