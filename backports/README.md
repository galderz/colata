# Backports

This project can be used for testing JDK backports.

Checkout a backport:

```shell
ID=jdk24u.translet-name-ignored make checkout-backport
```

Build and test a backport
```shell
ID=jdk24u.translet-name-ignored TEST="tier1 tier2" make configure build-jdk test
```
