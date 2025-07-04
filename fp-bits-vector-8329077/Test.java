import java.util.concurrent.ThreadLocalRandom;
import java.util.stream.IntStream;
import java.util.Arrays;
import java.util.HexFormat;

public class Test
{
    static final int RANGE = 1_000;
    static final int ITER = 10_000;

    static int[] test(int[] ints, float[] floats)
    {
        for (int i = 0; i < ints.length; i++)
        {
            final float aFloat = floats[i];
            final int bits = Float.floatToRawIntBits(aFloat);
            ints[i] = bits;
        }
        return ints;
    }

    public static void main(String[] args)
    {
        final float[] floats = init();
        final int[] ints = new int[RANGE];
        final int[] expected = test(ints, floats);
        final HexFormat hex = HexFormat.of();
        System.out.println("Expected: " + IntStream.of(expected).mapToObj(hex::toHexDigits).toList());

        int[] result = null;
        for (int i = 0; i < ITER; i++)
        {
            result = test(ints, floats);
            validate(expected, result, hex);
        }
    }

    static float[] init()
    {
        final float[] floats = new float[RANGE];
        for (int i = 0; i < RANGE; i++)
        {
            floats[i] = i;
        }
        return floats;
    }

    static void validate(int[] expected, int[] actual, HexFormat hex)
    {
        if (Arrays.equals(expected, actual))
        {
            System.out.print(".");
        }
        else
        {
            throw new AssertionError(String.format(
                "Failed, expected: %s, actual: %s"
                , IntStream.of(expected).mapToObj(hex::toHexDigits).toList()
                , IntStream.of(actual).mapToObj(hex::toHexDigits).toList()
            ));
        }
    }
}
