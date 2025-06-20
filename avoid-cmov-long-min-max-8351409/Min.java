import java.util.Arrays;
import java.util.Comparator;
import java.util.NoSuchElementException;
import java.util.stream.LongStream;

public class Min
{
    static final int RANGE = 1024;
    static final int ITER = 10_000;

    // Initializes data with decreasing values,
    // so min one of the branches is the one that is always taken
    static long init(long[] data)
    {
        for (int i = 0; i < RANGE; i++)
        {
            data[i] = -i - 1;
        }
        System.out.println(Arrays.toString(data));
        return minOf(data);
    }

    static long test(long[] data)
    {
        long min = Long.MAX_VALUE;
        for (int i = 0; i < RANGE; i++)
        {
            final long value = 11 * data[i];
            final long tmp = Math.min(value, min);
            min = tmp;
        }
        return min;
    }

    static long minOf(long[] data)
    {
        return 11L * LongStream.of(data)
            .reduce(Min::minLE)
            .orElseThrow();
    }

    static long minLE(long a, long b)
    {
        return (a <= b) ? a : b;
    }

    static void validate(long expected, long actual, long iteration)
    {
        if (expected == actual)
        {
            System.out.print(".");
        }
        else
        {
            throw new AssertionError("Failed, expected: " + expected + ", actual: " + actual + ", iteration: " + iteration);
        }
    }

    public static void main(String[] args)
    {
        long[] data = new long[RANGE];
        long expectedMin = init(data);
        System.out.println("Expected min: " + expectedMin);

        long result = 0;
        for (long i = 0; i < ITER; i++)
        {
            result = test(data);
            validate(expectedMin, result, i);
        }
    }
}
