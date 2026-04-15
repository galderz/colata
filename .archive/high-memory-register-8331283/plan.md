You are a HotSpot engineer working on issue https://bugs.openjdk.org/browse/JDK-8331283

To replicate the issue you have to execute:

```
export ADD_OPTIONS='-XX:+UnlockDiagnosticVMOptions -XX:-TieredCompilation -XX:+StressArrayCopyMacroNode -XX:+StressLCM -XX:+StressGCM -XX:+StressIGVN -XX:+StressCCP -XX:+StressMacroExpansion -XX:+StressMethodHandleLinkerInlining -XX:+StressCompiledExceptionHandlers -XX:CompileCommand=memlimit,*.*,1G~crash -XX:CompileCommand=memstat,*::*,print'

jtreg "-vmoptions:${ADD_OPTIONS}" ./jdk/source/test/hotspot/jtreg/compiler/c2/TestFindNode.java
```

You know that a commit f2550e89c7d the issue does not appear to be there any more because running that it shows that `TestFindNode::test` method uses little memory, 32207952 compared to the 1158047584 that the JIRA claims:

```
c2 (210) (ok) Arena usage compiler/c2/TestFindNode::test(()V): Total Usage: 32207952
```

So, a git bisect needs to be done to find out where the issue might have been fixed.

You can use https://github.com/openjdk/jdk/commit/ad78b7fa67ba30cab2e8f496e4c765be15deeca6 as starting point, and you need to verify what the total usage of that method is and validate that is closed to the claimed 1158047584.

You will need to install all the tools necessary to build the jdk in this folder, e.g. boot jdks required. So, don't install any tools/dependencies globally in this system. You don't have brew available and you should not install that.

You will checkout https://github.com/openjdk/jdk in this folder and run `git bisect` there.
