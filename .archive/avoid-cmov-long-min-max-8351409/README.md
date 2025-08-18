# Useful commands

Interacting with this project is done withing a Nix shell.
So all commands assume you're inside it:

```shell
> nix-shell
[nix-shell:...]$
```

# Create or checkout worktree

```shell
$ make new-worktree
```

Or:

```shell
$ make checkout-worktree
```

# Download boot JDK if not available in Nix

```shell
$ make boot-jdk
```

# Build the full JDK

```shell
$ make configure build-jdk
```

# Debugging JMH issues

```shell
JMH_ARGS="-p probability=100 -jvmArgs -XX:-UseSuperWord -prof xctracenorm org.openjdk.bench.java.lang.MinMaxVector.longReductionMultiplyMax" CONF=release DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make debug-jmh
```

# Running a JMH benchmark

```shell
TEST="micro:org.openjdk.bench.java.lang.MinMaxVector.longReductionMultiplyMax" MICRO="OPTIONS=-p probability=100 -p includeEquals=true -jvmArgs -XX:-UseSuperWord;FORK=1" make test
```

# Running a JMH benchmark with xctraceasm profiler

```shell
TEST="micro:org.openjdk.bench.java.lang.MinMaxVector.longReductionMultiplyMax" MICRO="OPTIONS=-p probability=100 -p includeEquals=true -jvmArgs -XX:-UseSuperWord -jvmArgs -XX:+UseNewCode -prof xctraceasm;FORK=1" DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make test
```

# Run a JMH benchmark with PrintMethodData

```shell
TEST="micro:org.openjdk.bench.java.lang.MinMaxVector.longClipping" MICRO="OPTIONS=-jvmArgs -XX:+UnlockDiagnosticVMOptions -jvmArgs -XX:+PrintMethodData -jvmArgs -XX:-UseSuperWord -p includeEquals=true -jvmArgs -XX:+UnlockDiagnosticVMOptions -jvmArgs -XX:-UseNewCode -jvmArgs -XX:-UseNewCode2;FORK=1" CONF=release LOG=warn make test
```

# Debugging with lldb a normal run

```bash
$ nix-shell
$ cd /Users/galder/src/jdk-avoid-cmov-long-min-max
$ $DEVKIT_ROOT/Xcode/Contents/Developer/usr/bin/lldb /Users/galder/src/jdk-avoid-cmov-long-min-max/build/slow-darwin-arm64/jdk/bin/java

(lldb) b addnode.cpp:124
(lldb) settings set target.run-args \-Xbatch \-Xlog:os \-XX:-BackgroundCompilation \-XX:CompileCommand=compileonly,Test::test /Users/galder/src/colata/avoid-cmov-long-min-max-8351409/Test.java
```

# Debugging with lldb a JMH benchmark

First run the JMH benchmark with `slow` configuration so that the `benchmarks.jar` file is built:

```bash
TEST="micro:org.openjdk.bench.java.lang.MinMaxVector.longReductionMultiplyMax" MICRO="OPTIONS=-p probability=100 -p includeEquals=true -jvmArgs -XX:-UseSuperWord -jvmArgs -XX:+UseNewCode;FORK=1" CONF=slow make test
```

```bash
$ nix-shell
$ CONF=slow make lldb

(lldb) b nmethod.cpp:1729
(lldb) settings set target.run-args \-Xbatch \-XX:-BackgroundCompilation \-XX:CompileCommand=compileonly,org.openjdk.bench.java.lang.MinMaxVector::longReductionMultiplyMax \-XX:+PrintNMethods \-XX:-UseSuperWord \-XX:+UseNewCode \-jar /Users/galder/src/jdk-avoid-cmov-long-min-max/build/slow-darwin-arm64/images/test/micro/benchmarks.jar MinMaxVector.longReductionMultiplyMax \-f 0 \-p size=2048 \-p probability=100 \-p includeEquals=true
```

# Debugging with gdb a JMH benchmark

First run the JMH benchmark with `slow` configuration so that the `benchmarks.jar` file is built:

```bash
TEST="micro:org.openjdk.bench.java.lang.MinMaxVector.longClipping" MICRO="OPTIONS=-p range=100 -jvmArgs -XX:+UnlockDiagnosticVMOptions -jvmArgs -XX:-UseSuperWord -jvmArgs -XX:+UseNewCode -jvmArgs -XX:+UseNewCode2;FORK=1" CONF=slow LOG=warn make test
```

```bash
cd jdk
emacs
gud-gdb /home/g/src/jdk-avoid-cmov-long-min-max/build/slow-linux-x86_64/jdk/bin/java

(gdb) b nmethod.cpp:1729
(gdb) set args -Xbatch -XX:-BackgroundCompilation -XX:CompileCommand=compileonly,org.openjdk.bench.java.lang.MinMaxVector::longClippingRange -XX:+PrintNMethods -XX:-UseSuperWord -XX:+UseNewCode -XX:+UseNewCode2 -jar /home/g/src/jdk-avoid-cmov-long-min-max/build/slow-linux-x86_64/images/test/micro/benchmarks.jar MinMaxVector.longClippingRange -f 0 -p range=100
```

# Linux

Make sure you enter on the linux Nix shell:

```shell
> nix-shell linux.nix
```
