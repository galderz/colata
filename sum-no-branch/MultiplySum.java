import java.util.Random;
import java.util.concurrent.ThreadLocalRandom;

class MultiplySum
{
    static final int ITER = 100_000;
    static final int SIZE = 16 * 1024;
    static final int THRESHOLD = 4096;

    static int test(int[] array)
    {
        int sum = 0;

        for (final int value : array)
        {
            int v = 11 * value;
            sum += v;
        }

        return sum;
    }

    public static void main(String[] args)
    {
        final ThreadLocalRandom random = ThreadLocalRandom.current();
        final int[] array = new int[SIZE];
        for (int i = 0; i < SIZE; i++)
        {
            array[i] = random.nextInt(THRESHOLD);
        }

        // Get the sum once to compare with each iteration
        final int gold = test(array);

        for (int i = 0; i < ITER; i++)
        {
            final int result = test(array);
            verify("sum", result, gold);
        }
    }

    static void verify(String context, long total, long gold)
    {
        if (total != gold)
        {
            throw new RuntimeException("Wrong result for " + context + ": " + total + " != " + gold);
        }
    }
}
