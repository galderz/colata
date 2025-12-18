/**
 * No push:
 *  34  MaxI  === _ 10 23  [[ 46 ]]  !jvms: Integer::max @ bci:2 (line 1934) TestPushLeft::test @ bci:2 (line 9)
 *  46  MaxI  === _ 34 11  [[ 59 ]]  !jvms: Integer::max @ bci:2 (line 1934) TestPushLeft::test @ bci:6 (line 9)
 *  58  MaxI  === _ 10 11  [[ 59 ]]  !jvms: Integer::max @ bci:2 (line 1934) TestPushLeft::test @ bci:11 (line 9)
 *  59  AddI  === _ 46 58  [[ 60 ]]  !jvms: TestPushLeft::test @ bci:14 (line 9)
 */
public class TestPushLeft
{
    // Convert "(x+1)+y" into "(x+y)+1".  Push constants down the expression tree.
    private static int test(int a, int b)
    {
        return Integer.max(Integer.max(a, 1), b) + Integer.max(a, b);
    }

    public static void main(String[] args)
    {
        for (int i = 0; i < 20_000; i++)
        {
            test(42, 42);
        }
    }
}