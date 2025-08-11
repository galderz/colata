import java.util.concurrent.ThreadLocalRandom;
import java.util.stream.LongStream;
import java.util.Arrays;

public class Test
{
    static final int RANGE = 1_024;
    static final int ITER = 10_000;

    static double[] test(double[] result, long[] values)
    {
        for (int i = 0; i < values.length; i++)
        {
            final long value = values[i];
            final double bits = Double.longBitsToDouble(value);
            result[i] = bits;
        }
        return result;
    }

    public static void main(String[] args)
    {
        final long[] values = init();
        final double[] expected = test(new double[RANGE], values);

        System.out.println("Expected: " + Arrays.toString(expected));

        final double[] result = new double[RANGE];
        for (int i = 0; i < ITER; i++)
        {
            test(result, values);
            validate(expected, result);
        }
    }

    static long[] init()
    {
        final long[] longs = new long[RANGE];
        for (int i = 0; i < RANGE; i++)
        {
            longs[i] = i;
        }
        return longs;
    }

    static void validate(double[] expected, double[] actual)
    {
        if (Arrays.equals(expected, actual))
        {
            System.out.print(".");
        }
        else
        {
            throw new AssertionError(String.format(
                "Failed, expected: %s, actual: %s"
                , Arrays.toString(expected)
                , Arrays.toString(actual)
            ));
        }
    }
}
