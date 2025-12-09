/**
 * long c = a * i;
 * is going to optimize to c = a;
 *
 * But we want that to happen sometimes after parsing.
 * One way to get that is with an empty counted loop.
 * On the first pass of loop opts, the loop goes away,
 * i is replaced by 1 and a*i is enqueued for igvn,
 * which causes c = a, which causes max(a, b) to be processed
 * but nothing pushes max(a, max(a, b)) for igvn.
 */
public class TestLongMax
{
    private static long test(long a, long b)
    {
        int i;
        for (i = -10; i < 1; i++)
        {
        }
        long c = a * i;
        return Long.max(a, Long.max(b, c));
    }

    public static void main(String[] args)
    {
        for (int i = 0; i < 20_000; i++)
        {
            test(42l, 42l);
        }
    }
}