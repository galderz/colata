import java.util.concurrent.ThreadLocalRandom;

public class FloatToIntBits
{
    static void test(int[] ints, float[] floats)
    {
        for (int i = 0; i < ints.length; i++)
        {
            final float aFloat = floats[i];
            final int bits = Float.floatToIntBits(floats[i]);
            ints[i] = bits;
        }
    }

    public static void main(String[] args)
    {
        final int[] ints = new int[10_000];
        final float[] floats = new float[10_000];

        for (int i = 0; i < 100_000; i++)
        {
            test(ints, floats);
        }
    }
}
