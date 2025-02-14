import java.util.concurrent.ThreadLocalRandom;

public class Test
{
    static void test(int[] ints, float[] floats)
    {
        for (int i = 0; i < ints.length; i++)
        {
            ints[i] = Float.floatToRawIntBits(floats[i]);
        }
    }

    public static void main(String[] args)
    {
        final int[] ints = new int[10_000];
        final float[] floats = new float[10_000];
        // init(ints);

        for (int i = 0; i < 100_000; i++)
        {
            test(ints, floats);
        }
    }

//    static void init(int[] ints) {
//        final ThreadLocalRandom rand = ThreadLocalRandom.current();
//        for (int i = 0; i < ints.length; i++)
//        {
//            ints[i] = rand.nextInt();
//        }
//    }
}
