import java.util.Arrays;

public class Test
{
    static final int RANGE = 1024;
    static final int ITER = 10_000;

    // Initializes data with increasing values,
    // so max one of the branches is the one that is always taken
    static void init(long[] data)
    {
        for (int i = 0; i < RANGE; i++)
        {
            data[i] = i + 1;
        }
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

    public static void main(String[] args)
    {
        long[] data = new long[RANGE];
        init(data);

        long result = 0;
        for (long i = 0; i < ITER; i++)
        {
            result = test(data);
        }

        // Validate
        if (result == 11 * Arrays.stream(data).max().getAsLong())
        {
            System.out.println("Success");
        }
        else
        {
            throw new AssertionError("Failed, max: " + result);
        }
    }
}
