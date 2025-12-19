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

# Create devkit

```shell
$ make devkit
```

# Add devkit to Nix store

```shell
$ make store-devkit
cd .../build/devkit
nix-store --add-fixed --recursive sha256 $(ls -d Xcode* | head -n 1)
/nix/store/fqdg3ybx87d3kpg2gqqxl5h4xlwj4wrq-Xcode16.2-MacOSX15
```
