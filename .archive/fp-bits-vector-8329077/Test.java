import java.util.Arrays;

public class Test
{
    static final int RANGE = 1_024;
    static final int ITER = 10_000;

    static void test(short[] result, float[] input)
    {
        for (int i = 0; i < input.length; i++)
        {
            final float v = input[i];
            final short r = Float.floatToFloat16(v);
            result[i] = r;
        }
    }

    public static void main(String[] args)
    {
        final float[] input = init();
        final short[] gold = new short[RANGE];
        test(gold, input);

        System.out.println("Expected: " + Arrays.toString(gold));

        final short[] result = new short[RANGE];
        for (int i = 0; i < ITER; i++)
        {
            test(result, input);
            validate(gold, result);
            Arrays.fill(result, (short) 0);
        }
    }

    static float[] init()
    {
        final float[] result = new float[RANGE];
        for (int i = 0; i < RANGE; i++)
        {
            result[i] = i;
        }
        return result;
    }

    static void validate(short[] expected, short[] actual)
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
