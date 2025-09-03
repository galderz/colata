import java.util.concurrent.TimeUnit;
import java.util.Random;

public class PrimitiveAndIf
{
    public static long test(long[] array)
    {
        long x = Integer.MIN_VALUE;
        for (int i = 0; i < array.length; i++)
        {
            long v = array[i];
            x = Math.max(x, v);
        }
        return x;
    }

    // Identical, mirror, implementation of the compiled method.
    // Used to validate that the compiled and non-compiled methods return the same thing at the end.
    public static long mirror(long[] array)
    {
        long x = Integer.MIN_VALUE;
        for (int i = 0; i < array.length; i++)
        {
            long v = array[i];
            x = Math.max(x, v);
        }
        return x;
    }

    public static void main(String[] args)
    {
        Random r = new Random(42);
        long[] array = new long[10_000];
        for (int i = 0; i < array.length; i++)
        {
            array[i] = r.nextLong() & 0xFFFF_FFFFL;
        }

        System.out.println("Warmup");
        for (int i = 0; i < 100_000; i++)
        {
            test(array);
        }

        System.out.println("Running");
        int numRuns = 10;
        for (int run = 1; run <= numRuns; run++)
        {
            for (int i = 0; i < array.length; i++)
            {
                array[i] = r.nextLong() & 0xFFFF_FFFFL;
            }

            long expected = mirror(array);

            long t0 = System.nanoTime();
            long operations = 0;
            for (int i = 0; i < 100_000; i++)
            {
                test(array);
                operations++;
            }
            long t1 = System.nanoTime();
            System.out.printf(
                "Throughput: %d ops/ms%n"
                , operations / TimeUnit.NANOSECONDS.toMillis(t1 - t0)
            );

            if (numRuns == run)
            {
                System.out.println("Validate");
                long value = test(array);
                validate(expected, value);
            }
        }
    }

    static void validate(long expected, long actual)
    {
        if (expected == actual)
        {
            blackhole(actual);
        }
        else
        {
            throw new AssertionError(String.format(
                "Failed, expected: %s, actual: %s"
                , expected
                , actual
            ));
        }
    }

    static void blackhole(long value)
    {
        if (value == System.nanoTime())
        {
            System.out.println(value);
        }
    }
}
