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
