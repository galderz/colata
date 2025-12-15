/**
 * int c = a * i;
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
 *    1  124  MinI  === _ 11 10  [[ 136 ]]  !jvms: Integer::min @ bci:2 (line 1948) TestIntMin::test @ bci:21 (line 21)
 *    1   10  Parm  === 3  [[ 136 124 71 82 38 49 60 ]] Parm0: int !orig=[113] !jvms: TestIntMin::test @ bci:-1 (line 17)
 *    0  136  MinI  === _ 10 124  [[ 137 ]]  !jvms: Integer::min @ bci:2 (line 1948) TestIntMin::test @ bci:24 (line 21)
 * New node:
 * dist dump
 * ---------------------------------------------
 *    1   10  Parm  === 3  [[ 136 124 71 82 38 49 60 ]] Parm0: int !orig=[113] !jvms: TestIntMin::test @ bci:-1 (line 17)
 *    1   11  Parm  === 3  [[ 124 60 82 71 38 49 ]] Parm1: int !jvms: TestIntMin::test @ bci:-1 (line 17)
 *    0  124  MinI  === _ 11 10  [[ 136 ]]  !jvms: Integer::min @ bci:2 (line 1948) TestIntMin::test @ bci:21 (line 21)
 */
public class TestIntMin
{
    private static int test(int a, int b)
    {
        int i;
        for (i = -10; i < 1; i++)
        {
        }
        int c = a * i;
        return Integer.min(a, Integer.min(b, c));
    }

    public static void main(String[] args)
    {
        for (int i = 0; i < 20_000; i++)
        {
            test(42, 42);
        }
    }
}
