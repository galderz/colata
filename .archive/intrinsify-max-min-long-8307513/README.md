# Useful Commands

Run a test on macos with `xctraceasm` profiler:
```shell
TEST="micro:lang.MathVectorizedBench.reductionMultiLongMax" MICRO="FORK=1;OPTIONS=-prof xctraceasm" m micro
```

If disassembling is not working try:
```shell
TEST="micro:lang.MathVectorizedBench.reductionMultiLongMax" MICRO="FORK=1;VM_OPTIONS=-Xlog:os;OPTIONS=-prof xctraceasm -v EXTRA" m micro
```

It will give you messages with tips on where it's looking for things:
```shell
[0.008s][info][os] shared library load of hsdis-aarch64.dylib failed, dlopen(hsdis-aarch64.dylib, 0x0001): Library not loaded: libcapstone.5.dylib
  Referenced from: <141CB1D5-204E-31C1-9EE3-AABE5934B4AF> /Users/galder/1/jdk-intrinsify-max-min-long/build/fast-darwin-arm64/images/jdk/lib/hsdis-aarch64.dylib
  Reason: tried: 'libcapstone.5.dylib' (no such file), '/System/Volumes/Preboot/Cryptexes/OSlibcapstone.5.dylib' (no such file), 'libcapstone.5.dylib' (no such file), '/Users/galder/1/jdk-intrinsify-max-min-long/build/fast-darwin-arm64/images/test/libcapstone.5.dylib' (no such file), '/System/Volumes/Preboot/Cryptexes/OS/Users/galder/1/jdk-intrinsify-max-min-long/build/fast-darwin-arm64/images/test/libcapstone.5.dylib' (no such file), '/Users/galder/1/jdk-intrinsify-max-min-long/build/fast-darwin-arm64/images/test/libcapstone.5.dylib' (no such file)
[0.008s][warning][os] Loading hsdis library failed
```

If you have multiple parameters you can run with a single one via:
```shell
TEST="micro:lang.MathVectorizedBench.reductionMultiLongMax" MICRO="FORK=1;OPTIONS=-prof xctraceasm -p size=16384" m micro
```

Running microbenchmark on base JDK with multiple jvm arguments:
```shell
CONF=release TEST="micro:lang.MathLoopBench.reductionSingleLongMax" MICRO="OPTIONS=-p size=16384 -jvmArgs -XX:+UnlockDiagnosticVMOptions -jvmArgs -XX:+PrintMethodData" JDK_HOME=$HOME/1/jdk m test
```

Running microbenchmark tracing vectorization:
```shell
TEST="micro:lang.MinMaxLoopBench.longReductionMax" MICRO='OPTIONS=-p size=10000 -f 1 -wi 0 -i 1 -v EXTRA -jvmArgs -Xlog:os -jvmArgs -XX:CompileCommand=TraceAutoVectorization,org.openjdk.bench.java.lang.MinMaxLoopBench::longReductionMax,ALL' JDK_HOME=/root/1/jdk-intrinsify-max-min-long.intrinsic make test
```

Running relevant tests:
```shell
TEST="test/hotspot/jtreg/compiler/loopopts/superword/MinMaxRed_Long.java" make test
TEST="test/hotspot/jtreg/compiler/c2/irTests/TestMinMaxIdentities.java" make test
TEST="test/hotspot/jtreg/compiler/intrinsics/math/TestMinMaxInlining.java" make test
```

Check if the test is actually running.
When `MinMaxRed_Long` does not actually run you see:
```shell
$ cat ./test-support/jtreg_test_hotspot_jtreg_compiler_loopopts_superword_MinMaxRed_Long_java/compiler/loopopts/superword/MinMaxRed_Long.jtr
...
Messages from Test VM
---------------------
[IREncodingPrinter] Disabling IR matching for rule 1 of 1 in maxReductionImplement: None of the feature constraints met (applyIfCPUFeatureOr): avx512, true
[IREncodingPrinter] Disabling IR matching for rule 1 of 1 in minReductionImplement: None of the feature constraints met (applyIfCPUFeatureOr): avx512, true
```
When `MinMaxRed_Long` runs you see:
```shell
$ cat ./build/fast-linux-aarch64/test-support/jtreg_test_hotspot_jtreg_compiler_loopopts_superword_MinMaxRed_Long_java/compiler/loopopts/superword/MinMaxRed_Long.jtr
----------System.err:(3/35)----------

JavaTest Message: Test complete.

result: Passed. Execution successful
```
