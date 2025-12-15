/**
 * long c = a * i;
 * is going to optimize to c = a;
 *
 * But we want that to happen sometimes after parsing.
 * One way to get that is with an empty counted loop.
 * On the first pass of loop opts, the loop goes away,
 * i is replaced by 1 and a*i is enqueued for igvn,
 * which causes c = a, which causes min(a, b) to be processed
 * but nothing pushes min(a, min(a, b)) for igvn.
 *
 * Missed Identity optimization:
 * Old node:
 * dist dump
 * ---------------------------------------------
 *    1  127  MinL  === _ 10 12  [[ 139 ]]  !jvms: Long::min @ bci:2 (line 1959) TestLongMin::test @ bci:27 (line 21)
 *    1   12  Parm  === 3  [[ 139 127 73 84 40 51 62 ]] Parm2: long !orig=[116] !jvms: TestLongMin::test @ bci:-1 (line 17)
 *    0  139  MinL  === _ 12 127  [[ 140 ]]  !jvms: Long::min @ bci:2 (line 1959) TestLongMin::test @ bci:30 (line 21)
 * New node:
 * dist dump
 * ---------------------------------------------
 *    1   12  Parm  === 3  [[ 139 127 73 84 40 51 62 ]] Parm2: long !orig=[116] !jvms: TestLongMin::test @ bci:-1 (line 17)
 *    1   10  Parm  === 3  [[ 127 62 84 73 40 51 ]] Parm0: long !jvms: TestLongMin::test @ bci:-1 (line 17)
 *    0  127  MinL  === _ 10 12  [[ 139 ]]  !jvms: Long::min @ bci:2 (line 1959) TestLongMin::test @ bci:27 (line 21)
 */
public class TestLongMin
{
    private static long test(long b, long a)
    {
        int i;
        for (i = -10; i < 1; i++)
        {
        }
        long c = a * i;
        return Long.min(a, Long.min(c, b));
    }

    public static void main(String[] args)
    {
        for (int i = 0; i < 20_000; i++)
        {
            test(42, 42);
        }
    }
}