/**
 * int c = a * i;
 * is going to optimize to c = a;
 *
 * But we want that to happen sometimes after parsing.
 * One way to get that is with an empty counted loop.
 * On the first pass of loop opts, the loop goes away,
 * i is replaced by 1 and a*i is enqueued for igvn,
 * which causes c = a, which causes max(a, b) to be processed
 * but nothing pushes max(a, max(a, b)) for igvn.
 *
 * Missed Identity optimization:
 * Old node:
 * dist dump
 * ---------------------------------------------
 *    1  127  MaxD  === _ 10 12  [[ 139 ]]  !jvms: Double::max @ bci:2 (line 1561) TestDoubleMax::test @ bci:27 (line 32)
 *    1   12  Parm  === 3  [[ 139 127 73 84 40 51 62 ]] Parm2: double !orig=[116] !jvms: TestDoubleMax::test @ bci:-1 (line 28)
 *    0  139  MaxD  === _ 12 127  [[ 140 ]]  !jvms: Double::max @ bci:2 (line 1561) TestDoubleMax::test @ bci:30 (line 32)
 * New node:
 * dist dump
 * ---------------------------------------------
 *    1   12  Parm  === 3  [[ 139 127 73 84 40 51 62 ]] Parm2: double !orig=[116] !jvms: TestDoubleMax::test @ bci:-1 (line 28)
 *    1   10  Parm  === 3  [[ 127 62 84 73 40 51 ]] Parm0: double !jvms: TestDoubleMax::test @ bci:-1 (line 28)
 *    0  127  MaxD  === _ 10 12  [[ 139 ]]  !jvms: Double::max @ bci:2 (line 1561) TestDoubleMax::test @ bci:27 (line 32)
 */
public class TestDoubleMax
{
//    // Works fine
//    private static float test(float a, float b)
//    {
//        int i;
//        for (i = -10; i < 1; i++)
//        {
//        }
//        float c = a * i;
//        return Float.max(a, Float.max(b, c));
//    }

    private static double test(double b, double a)
    {
        int i;
        for (i = -10; i < 1; i++)
        {
        }
        double c = a * i;
        return Double.max(a, Double.max(b, c));
    }

    public static void main(String[] args)
    {
        for (int i = 0; i < 20_000; i++)
        {
            test(42.0f, 42.0f);
        }
    }
}
