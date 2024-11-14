# Useful Commands

Is SuperWord enabled by default?
```shell
CONF=release m print-flags | grep UseSuperWord
     bool UseSuperWord                             = true                                   {C2 product} {default}
```

Run a microbenchmark in the JDK
```shell
CONF=release TEST="micro:compiler.VectorReduction2.WithSuperword.intAddSimple" m micro
```

Run a microbenchmark in the JDK with perfasm:
```shell
CONF=release TEST="micro:compiler.VectorReduction2.WithSuperword.intAddSimple" MICRO="FORK=1;OPTIONS=-prof perfasm" m micro
```

Run a microbenchmark in the JDK with additional VM args, e.g. trace vectorization.
This needs to be done in a build that has fast or slow debug,
a release build won't recognise the option.

In this particular case the method is in a static inner class,
so the `TEST` and `CompileCommand` arguments vary slightly.

```shell
TEST="micro:compiler.VectorReduction2.WithSuperword.intAddSimple" MICRO='OPTIONS=-jvmArgs -XX:CompileCommand=TraceAutoVectorization,org.openjdk.bench.vm.compiler.VectorReduction2::intAddSimple,ALL' m micro
```

**NOTE**: The exact pattern to pass in to compile command might be tricky to figure out.
Best run with `-XX:+PrintCompilation`

```shell
TEST="micro:compiler.VectorReduction2.WithSuperword.intAddSimple" MICRO='OPTIONS=-v EXTRA -jvmArgs -Xlog:os -jvmArgs -XX:+PrintCompilation' m micro
```
