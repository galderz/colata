import java.util.Random;
import java.util.concurrent.ThreadLocalRandom;

class Test
{
    static final int SIZE = 16 * 1024;
    static final int THRESHOLD = 4096;

    static int test(int[] array)
    {
        int sum = 0;

        for (final int value : array)
        {
            sum += value;
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

        final int result = test(array);
        blackhole(result);

    }

    static void blackhole(int value)
    {
        if ((long) value == System.nanoTime())
        {
            System.out.println(value);
        }
    }
}
