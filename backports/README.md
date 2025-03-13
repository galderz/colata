# Backports

This project can be used for testing JDK backports.

Create a new backport for JDK 21:

```shell
BASE=21 ID=translet-name-ignored make new-worktree
```

Checkout a backport:

```shell
BASE=21 ID=translet-name-ignored make checkout-worktree
```

Build and test a backport for JDK 21:

```shell
TEST="tier1 tier2" BASE=21 ID=translet-name-ignored make configure build-jdk test
```

