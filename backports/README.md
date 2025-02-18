# Backports

This project can be used for testing JDK backports.

Create a new backport for JDK 21:

```shell
WORKTREE_BASE=21 ID=21.translet-name-ignored make new-worktree
```

Checkout a backport:

```shell
ID=jdk24u.translet-name-ignored make checkout-backport
```

Build and test a backport
```shell
ID=jdk24u.translet-name-ignored TEST="tier1 tier2" make configure build-jdk test
```
