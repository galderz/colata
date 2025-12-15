/**
 * long c = a * i;
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
 *    1  117  SubL  === _ 10 12  [[ 118 ]]  !jvms: TestLongAdd::test @ bci:27 (line 21)
 *    1   12  Parm  === 3  [[ 117 118 73 84 40 51 62 ]] Parm2: long !orig=[116] !jvms: TestLongAdd::test @ bci:-1 (line 17)
 *    0  118  AddL  === _ 12 117  [[ 119 ]]  !jvms: TestLongAdd::test @ bci:28 (line 21)
 * New node:
 * dist dump
 * ---------------------------------------------
 *    1    3  Start  === 3 0  [[ 3 5 6 7 8 9 10 12 ]]  #{0:control, 1:abIO, 2:memory, 3:rawptr:BotPTR, 4:return_address, 5:long, 6:half, 7:long, 8:half}
 *    0   10  Parm  === 3  [[ 117 62 84 73 40 51 ]] Parm0: long !jvms: TestLongAdd::test @ bci:-1 (line 17)
 */
public class TestLongAdd
{
    private static long test(long b, long a)
    {
        int i;
        for (i = -10; i < 1; i++)
        {
        }
        long c = a * i;
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