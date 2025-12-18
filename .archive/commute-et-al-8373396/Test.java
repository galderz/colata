/**
 * No commute:
 *  33  MaxI  === _ 10 11  [[ 46 ]]  !jvms: Integer::max @ bci:2 (line 1934) Test::test @ bci:2 (line 7)
 *  45  MaxI  === _ 11 10  [[ 46 ]]  !jvms: Integer::max @ bci:2 (line 1934) Test::test @ bci:7 (line 7)
 *  46  AddI  === _ 33 45  [[ 47 ]]  !jvms: Test::test @ bci:10 (line 7)
 */
public class Test
{
    private static int test(int a, int b)
    {
        return Integer.max(a, b) + Integer.max(b, a);
    }

    public static void main(String[] args)
    {
        for (int i = 0; i < 20_000; i++)
        {
            test(42, 42);
        }
    }
}