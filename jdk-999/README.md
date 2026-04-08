# Latest JDK

This project can be used for building JDKs that support other efforts.

Here are a few examples:

Building latest GraalVM master depends on specific JDK tags.
So you can point to that specific tag and build graal builder image:

```bash
make configure build-graal-builder-image
```

# Introduction to C2

## VM flags to control compilation

By default, compilation happens in the background,
so program might finish before compilation has finished:

```bash
CLASS=First JVM_ARGS=-XX:CompileCommand=printcompilation,First::* make
rm -f *.log
/Users/g/src/jdk/build/fast-darwin-arm64/jdk/bin/java \
   -XX:CompileCommand=printcompilation,First::* \
   /Users/g/src/colata/jdk-999/First.java
CompileCommand: PrintCompilation First.* bool PrintCompilation = true
Run
Done
1399 1838       2       First::test (4 bytes)
```

With `-Xbatch` you disable background compilation.
We explicitly wait for any compilation to finish before continuing the execution in that method.
We also see that the blocking behaviour has made the overall execution much slower.
This is because the VM now blocks the execution any time a compilation needs to be made -
and not just in our `First` class but also during the JVM startup:

```bash
CLASS=First JVM_ARGS="-Xbatch -XX:CompileCommand=printcompilation,First::*" make
rm -f *.log
/Users/g/src/jdk/build/fast-darwin-arm64/jdk/bin/java \
   -Xbatch -XX:CompileCommand=printcompilation,First::* \
   /Users/g/src/colata/jdk-999/First.java
CompileCommand: PrintCompilation First.* bool PrintCompilation = true
Run
2734 1903    b  3       First::test (4 bytes)
2734 1904    b  4       First::test (4 bytes)
Done
```

We can stop tiered compilation at a certain tier,
for example to avoid any C2 compilations and only allow C1.
We also restrict compilation,
so that we don't have to wait for all classes and methods used from startup of the JVM to be compiled:

```bash
CLASS=First JVM_ARGS="-XX:TieredStopAtLevel=3 -XX:CompileCommand=compileonly,First::test -Xbatch -XX:CompileCommand=printcompilation,First::*" make
rm -f *.log
/Users/g/src/jdk/build/fast-darwin-arm64/jdk/bin/java \
   -XX:TieredStopAtLevel=3 -XX:CompileCommand=compileonly,First::test -Xbatch -XX:CompileCommand=printcompilation,First::* \
   /Users/g/src/colata/jdk-999/First.java
CompileCommand: compileonly First.test bool compileonly = true
CompileCommand: PrintCompilation First.* bool PrintCompilation = true
Run
1412  102    b  3       First::test (4 bytes)
Done
```

## C2 IR

With `-XX:+PrintIdeal`,
we can display the C2 machine independent IR (intermediate representation),
sometimes also called “ideal graph” or just “C2 IR”,
after most optimizations are done, and before code generation:

```bash
CLASS=First JVM_ARGS_APPEND=-XX:+PrintIdeal make
rm -f *.log
/Users/g/src/jdk/build/fast-darwin-arm64/jdk/bin/java \
   -Xbatch -XX:CompileCommand=compileonly,First::test -XX:CompileCommand=printcompilation,First::* -XX:-TieredCompilation -XX:+PrintIdeal \
   /Users/g/src/colata/jdk-999/First.java
CompileCommand: compileonly First.test bool compileonly = true
CompileCommand: PrintCompilation First.* bool PrintCompilation = true
Run
1693  102    b        First::test (4 bytes)
AFTER: PrintIdeal
  0  Root  === 0 24  [[ 0 1 3 ]] inner 
  1  Con  === 0  [[ ]]  #top
  3  Start  === 3 0  [[ 3 5 6 7 8 9 10 11 ]]  #{0:control, 1:abIO, 2:memory, 3:rawptr:BotPTR, 4:return_address, 5:int, 6:int}
  5  Parm  === 3  [[ 24 ]] Control !jvms: First::test @ bci:-1 (line 21)
  6  Parm  === 3  [[ 24 ]] I_O !jvms: First::test @ bci:-1 (line 21)
  7  Parm  === 3  [[ 24 ]] Memory  Memory: @ptr:BotPTR+bot, idx=Bot; !jvms: First::test @ bci:-1 (line 21)
  8  Parm  === 3  [[ 24 ]] FramePtr !jvms: First::test @ bci:-1 (line 21)
  9  Parm  === 3  [[ 24 ]] ReturnAdr !jvms: First::test @ bci:-1 (line 21)
 10  Parm  === 3  [[ 23 ]] Parm0: int !jvms: First::test @ bci:-1 (line 21)
 11  Parm  === 3  [[ 23 ]] Parm1: int !jvms: First::test @ bci:-1 (line 21)
 23  AddI  === _ 10 11  [[ 24 ]]  !jvms: First::test @ bci:2 (line 21)
 24  Return  === 5 6 7 8 9 returns 23  [[ 0 ]] 
Done
```