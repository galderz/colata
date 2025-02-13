# Latest JDK

This project can be used for building JDKs that support other efforts,
or testing backports.

Here are a few examples:

Building latest GraalVM master depends on specific JDK tags.
So you can point to that specific tag and build graal builder image:

```bash
make configure build-graal-builder-image
```

Building a backport branch and test it:

```bash
JDK_HOME=$HOME/1/jdk24u-translet-name-ignored TEST="tier1,tier2" make configure build-jdk test  
```
