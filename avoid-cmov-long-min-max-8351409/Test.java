import java.util.Arrays;

public class Test
{
    static final int RANGE = 1024;
    static final int ITER = 10_000;

    // Initializes data with increasing values,
    // so max one of the branches is the one that is always taken
    static long init(long[] data)
    {
        for (int i = 0; i < RANGE; i++)
        {
            data[i] = i + 1;
        }
        return maxOf(data);
    }

    static long test(long[] data)
    {
        long max = Long.MIN_VALUE;
        for (int i = 0; i < RANGE; i++)
        {
            final long value = 11 * data[i];
            final long tmp = Math.max(max, value);
            max = tmp;
        }
        return max;
    }

    static long maxOf(long[] data)
    {
        long max = Long.MIN_VALUE;
        for (int i = 0; i < RANGE; i++)
        {
            final long value = 11 * data[i];
            final long tmp = (max >= value) ? max : value;
            max = tmp;
        }
        return max;
    }

    static void validate(long expected, long actual)
    {
        if (expected == actual)
        {
            System.out.print(".");
        }
        else
        {
            throw new AssertionError("Failed, expected: " + expected + ", actual: " + actual);
        }
    }

    public static void main(String[] args)
    {
        long[] data = new long[RANGE];
        long expectedMax = init(data);
        System.out.println("Expected max: " + expectedMax);

        long result = 0;
        for (long i = 0; i < ITER; i++)
        {
            result = test(data);
            validate(expectedMax, result);
        }
    }
}
