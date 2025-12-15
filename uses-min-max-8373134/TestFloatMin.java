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
 *    1  125  MinF  === _ 10 11  [[ 137 ]]  !jvms: Float::min @ bci:2 (line 1367) TestFloatMin::test @ bci:22 (line 32)
 *    1   11  Parm  === 3  [[ 137 125 71 82 38 49 60 ]] Parm1: float !orig=[114] !jvms: TestFloatMin::test @ bci:-1 (line 28)
 *    0  137  MinF  === _ 11 125  [[ 138 ]]  !jvms: Float::min @ bci:2 (line 1367) TestFloatMin::test @ bci:25 (line 32)
 * New node:
 * dist dump
 * ---------------------------------------------
 *    1   11  Parm  === 3  [[ 137 125 71 82 38 49 60 ]] Parm1: float !orig=[114] !jvms: TestFloatMin::test @ bci:-1 (line 28)
 *    1   10  Parm  === 3  [[ 125 60 82 71 38 49 ]] Parm0: float !jvms: TestFloatMin::test @ bci:-1 (line 28)
 *    0  125  MinF  === _ 10 11  [[ 137 ]]  !jvms: Float::min @ bci:2 (line 1367) TestFloatMin::test @ bci:22 (line 32)
 */
public class TestFloatMin
{
    private static float test(float b, float a)
    {
        int i;
        for (i = -10; i < 1; i++)
        {
        }
        float c = a * i;
        return Float.min(a, Float.min(b, c));
    }

    public static void main(String[] args)
    {
        for (int i = 0; i < 20_000; i++)
        {
            test(42.0f, 42.0f);
        }
    }
}
