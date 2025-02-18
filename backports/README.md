# Backports

This project can be used for testing JDK backports.

Create a new backport for JDK 21:

```shell
BASE=21 ID=translet-name-ignored make new-worktree
```

Build and test a backport for JDK 21:

```shell
ID=21.translet-name-ignored BOOT_JDK_VERSION=21 TEST="tier1 tier2" make configure build-jdk test
```

Checkout a backport:

```shell
ID=jdk24u.translet-name-ignored make checkout-backport
```

Build and test a backport
```shell
ID=jdk24u.translet-name-ignored TEST="tier1 tier2" make configure build-jdk test
```
