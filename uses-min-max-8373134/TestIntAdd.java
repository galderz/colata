/**
 * int c = a * i;
 * is going to optimize to c = a;
 *
 * But we want that to happen sometimes after parsing.
 * One way to get that is with an empty counted loop.
 * On the first pass of loop opts, the loop goes away,
 * i is replaced by 1 and a*i is enqueued for igvn,
 * which causes c = a, which causes a + b to be processed
 * but nothing pushes a + (b - a) for igvn.
 *
 * Missed Identity optimization:
 * Old node:
 * dist dump
 * ---------------------------------------------
 *    1  114  SubI  === _ 10 11  [[ 115 ]]  !jvms: TestIntAdd::test @ bci:21 (line 21)
 *    1   11  Parm  === 3  [[ 114 115 71 82 38 49 60 ]] Parm1: int !orig=[113] !jvms: TestIntAdd::test @ bci:-1 (line 17)
 *    0  115  AddI  === _ 11 114  [[ 116 ]]  !jvms: TestIntAdd::test @ bci:22 (line 21)
 * New node:
 * dist dump
 * ---------------------------------------------
 *    1    3  Start  === 3 0  [[ 3 5 6 7 8 9 10 11 ]]  #{0:control, 1:abIO, 2:memory, 3:rawptr:BotPTR, 4:return_address, 5:int, 6:int}
 *    0   10  Parm  === 3  [[ 114 60 82 71 38 49 ]] Parm0: int !jvms: TestIntAdd::test @ bci:-1 (line 17)
 */
public class TestIntAdd
{
    private static int test(int b, int a)
    {
        int i;
        for (i = -10; i < 1; i++)
        {
        }
        int c = a * i;
        return a + (b - c);
    }

    public static void main(String[] args)
    {
        for (int i = 0; i < 20_000; i++)
        {
            test(42, 42);
        }
    }
}
