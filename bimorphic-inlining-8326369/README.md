# Useful commands

Running a jtreg test outside of `make test`:
```shell
TEST_DIR="test/hotspot/jtreg/compiler/inlining" TEST_FILE="InlineBimorphicVirtualCallAfterMorphismChanged.java" m test-jtreg
```
