# Building Elsewhere

Define a ~.env~ in the root of this repository with:

```shell
A_ROOT=/home/tester/galder
BOOT_JDK_VERSION=24
```

Then apply it with:

```shell
set -o allexport && source .env && set +o allexport
```
