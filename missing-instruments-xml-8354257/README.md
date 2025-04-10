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

# Debugging JMH issues

```shell
JMH_ARGS="-p probability=100 -jvmArgs -XX:-UseSuperWord -prof xctracenorm org.openjdk.bench.java.lang.MinMaxVector.longReductionMultiplyMax" CONF=release DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make debug-jmh
```
