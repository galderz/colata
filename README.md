# Remote Environments

Define a `.env` file in the root of this repository checkout,
with variables that override default parameters as needed for each environment.
E.g.

```shell
$ cat .env
A_ROOT=/local/example
BOOT_JDK_HOME=/local/example/opt/boot-java-24
```

Then execute:

```bash
set -o allexport && source .env && set +o allexport
```

# Update devkit to new XCode version

Enter a Nix shell with `make`:

```shell
> nix-shell -p gnumake
[nix-shell:...]$
```

Create devkit

```shell
$ make devkit
```

Add devkit to Nix store:

```shell
$ make store-devkit
```
