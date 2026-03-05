public class Test
{
    private static long test(long b, long a)
    {
        int i;
        for (i = -10; i < 1; i++) {
        }
        long c = a * i;
        return Long.min(Long.max(c, b), a);
    }

    public static void main(String[] args)
    {
        for (int i = 0; i < 20_000; i++)
        {
            test(42l, 42l);
        }
    }
}
