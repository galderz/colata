# Useful commands

Interacting with this project is done withing a Nix shell.
So all commands assume you're inside it:

```shell
> nix-shell
[nix-shell:...]$
```

# Create worktree

```shell
$ make new-worktree
```

# Build the full JDK

```shell
$ make configure build-jdk
```

# Replicate issue

```shell
TEST="micro:org.openjdk.bench.java.lang.MinMaxVector.longReductionMultiplyMax" MICRO="OPTIONS=-p probability=100 -jvmArgs -XX:-UseSuperWord -prof xctracenorm -v EXTRA;FORK=1" DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer BUILD_LOG=warn make test
```

# Debugging JMH issues

```shell
JMH_ARGS="-p probability=100 -jvmArgs -XX:-UseSuperWord -prof xctracenorm org.openjdk.bench.java.lang.MinMaxVector.longReductionMultiplyMax" DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make debug-jmh
```
