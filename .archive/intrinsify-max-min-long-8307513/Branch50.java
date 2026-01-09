import java.util.concurrent.ThreadLocalRandom;

class Branch50
{
    static final int RANGE = 1024;
    static final int ITER = 10_000;

    public static void ReductionInit(long[] longs, int probability)
    {
        int aboveCount, abovePercent;

        // Iterate until you find a set that matches the requirement probability
        do
        {
            long max = ThreadLocalRandom.current().nextLong(10);
            longs[0] = max;

            aboveCount = 0;
            for (int i = 1; i < longs.length; i++)
            {
                long value;
                if (ThreadLocalRandom.current().nextLong(101) <= probability)
                {
                    long increment = ThreadLocalRandom.current().nextLong(10);
                    value = max + increment;
                    aboveCount++;
                }
                else
                {
                    // Decrement by at least 1
                    long decrement = ThreadLocalRandom.current().nextLong(10) + 1;
                    value = max - decrement;
                }
                longs[i] = value;
                max = Math.max(max, value);
            }

            abovePercent = ((aboveCount + 1) * 100) / longs.length;
        } while (abovePercent != probability);
    }

    static long test(long[] data, long sum)
    {
        for (int i = 0; i < RANGE; i++)
        {
            final long v = 11 * data[i];
            sum = Math.max(sum, v);
        }
        return sum;
    }

    public static void main(String[] args)
    {
        long[] data = new long[RANGE];
        ReductionInit(data, 50);
        for (long i = 0; i < ITER; i++)
        {
            test(data, i);
        }
    }
}
