Given the following Java code:

```java
public class First
{
    public static void main(String[] args)
    {
        // Especially with a debug build, the JVM startup can take a while,
        // so it can take a while until our code is executed.
        System.out.println("Run");

        // Repeatedly call the test method, so that it can become hot and
        // get JIT compiled.
        for (int i = 0; i < 10_000; i++)
        {
            test(i, i + 1);
        }
        System.out.println("Done");
    }

    // The test method we will focus on.
    public static int test(int a, int b)
    {
        return a + b;
    }
}
```

Running it with `-XX:+PrintIdeal` we can display the C2 machine independent IR (intermediate representation),
sometimes also called “ideal graph” or just “C2 IR”, after most optimizations are done,
and before code generation:

```bash
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

Your objective is to represent this IR output in a way that helps the reader make a mental model on how the IR works.
To do that:

1. Generate a visual graph on how the IR nodes are linked together.
2. Improve the visual graph output to show how data that comes into the IR can move through the graph at each step,
assuming a single threaded execution. There should be controls to execute the IR one step at the time forwards or backwards,
and there should be controls to go back to the beginning or the end.

You can use any programming language that you want to implement.
Take the advantage of the latest technology to best represent this.
Before attempting to install any dependencies, ask the user in case they want to do this separately.
