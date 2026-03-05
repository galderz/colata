# Latest JDK

This project can be used for building JDKs that support other efforts.

Here are a few examples:

Building latest GraalVM master depends on specific JDK tags.
So you can point to that specific tag and build graal builder image:

```bash
make configure build-graal-builder-image
```
