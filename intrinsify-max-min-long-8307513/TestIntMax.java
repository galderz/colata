import java.util.Random;
import java.util.concurrent.ThreadLocalRandom;
import java.text.DecimalFormat;
import java.text.DecimalFormatSymbols;

class Test
{
    static final int RANGE = 16 * 1024;
    static final int ITER = 100_000;

    public static void main(String[] args)
    {
        final int probability = Integer.parseInt(args[0]);

        final DecimalFormatSymbols symbols = new DecimalFormatSymbols();
        symbols.setGroupingSeparator(' ');
        final DecimalFormat format = new DecimalFormat("#,###", symbols);

        System.out.printf("Probability: %d%%%n", probability);
        int[] a = new int[64 * 1024];
        init(a, probability);

        {
            System.out.println("Warmup");
            for (int i = 0; i < 10_000; i++)
            {
                test1(a);
            }
            System.out.println("Run");
            long t0 = System.nanoTime();
            for (int i = 0; i < 10_000; i++)
            {
                test1(a);
            }
            long t1 = System.nanoTime();
            System.out.println("Time: " + format.format(t1 - t0));
        }

        {
            System.out.println("Warmup");
            for (int i = 0; i < 10_000; i++)
            {
                test2(a);
            }
            System.out.println("Run");
            long t0 = System.nanoTime();
            for (int i = 0; i < 10_000; i++)
            {
                test2(a);
            }
            long t1 = System.nanoTime();
            System.out.println("Time: " + format.format(t1 - t0));
        }
    }

    public static int test1(int[] a)
    {
        int x = Integer.MIN_VALUE;
        for (int i = 0; i < a.length; i++)
        {
            x = Math.max(x, a[i]);
        }
        return x;
    }

    public static int test2(int[] a)
    {
        int x = Integer.MIN_VALUE;
        for (int i = 0; i < a.length; i++)
        {
            x = (x >= a[i]) ? x : a[i];
        }
        return x;
    }

    public static void init(int[] ints, int probability)
    {
        int aboveCount, abovePercent;

        do
        {
            int max = ThreadLocalRandom.current().nextInt(10);
            ints[0] = max;

            aboveCount = 0;
            for (int i = 1; i < ints.length; i++)
            {
                int value;
                if (ThreadLocalRandom.current().nextInt(101) <= probability)
                {
                    int increment = ThreadLocalRandom.current().nextInt(10);
                    value = max + increment;
                    aboveCount++;
                }
                else
                {
                    // Decrement by at least 1
                    int decrement = ThreadLocalRandom.current().nextInt(10) + 1;
                    value = max - decrement;
                }
                ints[i] = value;
                max = Math.max(max, value);
            }

            abovePercent = ((aboveCount + 1) * 100) / ints.length;
        } while (abovePercent != probability);
    }
}
