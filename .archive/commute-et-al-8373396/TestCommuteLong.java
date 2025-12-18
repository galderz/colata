/**
 * No commute:
 */
public class TestCommuteLong
{
    private static long test(long a, long b)
    {
        return Long.max(a, b) + Long.max(b, a);
    }

    public static void main(String[] args)
    {
        for (int i = 0; i < 20_000; i++)
        {
            test(42l, 42l);
        }
    }
}