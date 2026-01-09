import java.util.concurrent.ThreadLocalRandom;

class LongMaxMax
{
    static final int ITER = 10_000;

    static long test(long a, long b)
    {
        return Math.max(a, Math.max(a, b));
    }

    public static void main(String[] args)
    {
        for (long i = 0; i < ITER; i++)
        {
            long a = ThreadLocalRandom.current().nextLong();
            long b = ThreadLocalRandom.current().nextLong();
            test(a, b);
        }
    }
}