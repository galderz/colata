import java.util.concurrent.ThreadLocalRandom;
import java.util.stream.LongStream;
import java.util.Arrays;
import java.util.HexFormat;

public class DoubleToRawLongBits
{
    static final int RANGE = 1_024;
    static final int ITER = 10_000;

    static long[] test(long[] longs, double[] doubles)
    {
        for (int i = 0; i < longs.length; i++)
        {
            final double aDouble = doubles[i];
            final long bits = Double.doubleToRawLongBits(aDouble);
            longs[i] = bits;
        }
        return longs;
    }

    public static void main(String[] args)
    {
        final double[] doubles = init();
        final long[] longs = new long[RANGE];
        final long[] expected = test(longs, doubles);
        final HexFormat hex = HexFormat.of();
        System.out.println("Expected: " + LongStream.of(expected).mapToObj(hex::toHexDigits).toList());

        long[] result = null;
        for (int i = 0; i < ITER; i++)
        {
            result = test(longs, doubles);
            validate(expected, result, hex);
        }
    }

    static double[] init()
    {
        final double[] doubles = new double[RANGE];
        for (int i = 0; i < RANGE; i++)
        {
            doubles[i] = i;
        }
        return doubles;
    }

    static void validate(long[] expected, long[] actual, HexFormat hex)
    {
        if (Arrays.equals(expected, actual))
        {
            System.out.print(".");
        }
        else
        {
            throw new AssertionError(String.format(
                "Failed, expected: %s, actual: %s"
                , LongStream.of(expected).mapToObj(hex::toHexDigits).toList()
                , LongStream.of(actual).mapToObj(hex::toHexDigits).toList()
            ));
        }
    }
}
