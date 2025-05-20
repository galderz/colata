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

# Linux

Make sure you enter on the linux Nix shell:

```shell
> nix-shell linux.nix
```
