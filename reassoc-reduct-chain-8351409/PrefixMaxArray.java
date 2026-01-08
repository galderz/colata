import static java.lang.IO.*;
import static java.lang.System.nanoTime;
import static java.util.concurrent.TimeUnit.*;

import java.util.*;

final class PrefixMaxArray
{
    static final int ITER = 100_000;

    static final int NUM_RUNS = 10;

    static final int SIZE = 1_000;

    static final Random RND = new Random(42);

    static void test(long[] array, long[] result)
    {
        result[0] = array[0];
        for (int i = 1; i < array.length; i++)
        {
            result[i] = Math.max(result[i - 1], array[i]);
        }
    }

    public static void main(String[] args)
    {
        var array = new long[SIZE];
        var result = new long[SIZE];
        var expected = new long[SIZE];
        init(array);
        test(array, expected);
        validate(expected, array, result);
        println("Warmup");
        for (int i = 0; i < ITER; i++)
        {
            Arrays.fill(result, 0L);
            test(array, result);
        }
        println("Running");
        for (int run = 1; run <= NUM_RUNS; run++)
        {
            var t0 = nanoTime();
            long operations = 0;
            for (int i = 0; i < ITER; i++)
            {
                Arrays.fill(result, 0L);
                test(array, result);
                operations++;
            }
            var t1 = nanoTime();
            var durationNs = t1 - t0;
            var outputTimeUnit = MILLISECONDS;
            var throughput = operations * NANOSECONDS.convert(1, outputTimeUnit) / durationNs;
            println("Throughput: %d ops/ms".formatted(throughput));
            if (NUM_RUNS == run)
            {
                validate(expected, array, result);
            }
        }
    }

    static void init(long[] array)
    {
        for (int i = 0; i < array.length; i++)
        {
            array[i] = RND.nextLong() & 0xFFFF_FFFFL;
        }
    }

    static void blackhole(long[] value)
    {
        if (value.hashCode() == nanoTime())
        {
            println(value);
        }
    }

    static void validate(long[] expected, long[] array, long[] result)
    {
        println("Validate");
        Arrays.fill(result, 0L);
        test(array, result);
        assertEquals(expected, result);
    }

    static void assertEquals(long[] expected, long[] actual)
    {
        if (Arrays.equals(expected, actual))
        {
            blackhole(actual);
        }
        else
        {
            printDiff(expected, actual, 10);
            throw new AssertionError("Failed array contents don't match, see above for differences");
        }
    }

    static void printDiff(long[] a, long[] b, int maxDiffs) {
        int minLen = Math.min(a.length, b.length);
        int diffs = 0;

        for (int i = 0; i < minLen; i++)
        {
            long valueA = a[i];
            long valueB = b[i];
            if (valueA != valueB)
            {
                System.out.printf(
                    "idx=%d: a=%d (0x%016X)  b=%d (0x%016X)%n"
                    , i
                    , valueA
                    , valueA
                    , valueB
                    , valueB
                );
                if (++diffs >= maxDiffs)
                {
                    System.out.printf("...stopped after %d differences%n", diffs);
                    return;
                }
            }
        }

        System.out.printf(
            "Done. Compared %d elements, found %d differences. (len a=%d, len b=%d)%n"
            , minLen
            , diffs
            , a.length
            , b.length
        );
    }
}
