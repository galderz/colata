import static java.lang.IO.*;
import static java.lang.System.nanoTime;
import static java.util.concurrent.TimeUnit.*;

import java.lang.String;
import java.util.Random;

final class TestIfMinMax
{
    static final int ITER = 100_000;

    static final int NUM_RUNS = 10;

    static final int SIZE = 10_000;

    static final Random RND = new Random(42);

    static Object[] test(long[] a, long[] b)
    {
        long r = 0;

        for (int i = 0; i < a.length; i++)
        {
            long aI = a[i] * b[i];

            r = aI > r ? aI : r;
        }

        return new Object[]{a, b, r};
    }

    public static void main(String[] args)
    {
        var array = new Object[2];
        init(array);
        println("Warmup");
        for (int i = 0; i < ITER; i++)
        {
            test((long[]) array[0], (long[]) array[1]);
        }
        println("Running");
        for (int run = 1; run <= NUM_RUNS; run++)
        {
            init(array);
            Object[] expected = null;
            if (NUM_RUNS == run)
            {
                expected = expect((long[]) array[0], (long[]) array[1]);
            }
            var t0 = nanoTime();
            long operations = 0;
            for (int i = 0; i < ITER; i++)
            {
                test((long[]) array[0], (long[]) array[1]);
                operations++;
            }
            var t1 = nanoTime();
            var durationNs = t1 - t0;
            var outputTimeUnit = MILLISECONDS;
            var throughput = operations * NANOSECONDS.convert(1, outputTimeUnit) / durationNs;
            println("Throughput: %d ops/ms".formatted(throughput));
            if (NUM_RUNS == run)
            {
                println("Validate");
                var value = test((long[]) array[0], (long[]) array[1]);
                validate((long) expected[2], (long) value[2]);
            }
        }
    }

    static void init(Object[] array)
    {
        long[] a = new long[512];
        long[] b = new long[512];

        // Fill from 1 to 125
        for (int i = 0; i < 125; i++)
        {
            a[i] = i + 1;
            b[i] = 1;
        }

        // Fill from -1 to -125
        for (int i = 125; i < 250; i++)
        {
            a[i] = -(i - 124);
            b[i] = 1;
        }

        for (int i = 250; i < 512; i++)
        {
            a[i] = RND.nextLong();
            b[i] = 1;
        }

        array[0] = a;
        array[1] = b;
    }

    static Object[] expect(long[] a, long[] b)
    {
        long r = 0;
        for (int i = 0; i < a.length; i++)
        {
            long aI = a[i] * b[i];

            r = aI > r ? aI : r;
        }

        return new Object[]{a, b, r};
    }

    static void blackhole(long value)
    {
        if (value == nanoTime())
        {
            println(value);
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
            throw new AssertionError("Failed: expected: %d, actual: %d".formatted(expected, actual));
        }
    }
}
