/**
 * No flatten:
 *  22  ConI  === 0  [[ 33 ]]  #int:1
 *  33  MaxI  === _ 10 22  [[ 46 ]]  !jvms: Integer::max @ bci:2 (line 1934) TestFlatten::test @ bci:2 (line 8)
 *  34  ConI  === 0  [[ 46 ]]  #int:2
 *  46  MaxI  === _ 33 34  [[ 47 ]]  !jvms: Integer::max @ bci:2 (line 1934) TestFlatten::test @ bci:6 (line 8)
 */
public class TestFlatten
{
    private static int test(int a)
    {
        return Integer.max(Integer.max(a, 1), 2);
    }

    public static void main(String[] args)
    {
        for (int i = 0; i < 20_000; i++)
        {
            test(42);
        }
    }
}