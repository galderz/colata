public class TestCommuteIntMin
{
    private static int test(int a, int b)
    {
        return Integer.min(a, b) + Integer.min(b, a);
    }

    public static void main(String[] args)
    {
        for (int i = 0; i < 20_000; i++)
        {
            test(42, 42);
        }
    }
}
