import static java.lang.IO.*;
import static java.lang.System.nanoTime;
import static java.util.concurrent.TimeUnit.*;

import java.util.Random;

public class TestXorShort
{
    static final int ITER = 100_000;

    static final int NUM_RUNS = 10;

    static final int SIZE = 10_000;

    static final Random RND = new Random(42);

    static short testShort(short[] a1, short[] a2, short[] a3)
    {
        short result = 0;
        for (int i = 0; i < a1.length; i++)
        {
            var val = (short)((a1[i] * a2[i]) + (a1[i] * a3[i]) + (a2[i] * a3[i]));
            result ^= val;
        }
        return result;
    }

    static void main()
    {
        var s1 = new short[SIZE];
        var s2 = new short[SIZE];
        var s3 = new short[SIZE];
        init(s1, s2, s3);
        var expectedS = expectS(s1, s2, s3);
        validateS(expectedS, s1, s2, s3);

        println("Warmup");
        for (int i = 0; i < ITER; i++)
        {
            testShort(s1, s2, s3);
        }
        println("Running Short");
        for (int run = 1; run <= NUM_RUNS; run++)
        {
            var t0 = nanoTime();
            long operations = 0;
            for (int i = 0; i < ITER; i++)
            {
                blackhole(testShort(s1, s2, s3));
                operations++;
            }
            var t1 = nanoTime();
            var durationNs = t1 - t0;
            var outputTimeUnit = MILLISECONDS;
            var throughput = operations * NANOSECONDS.convert(1, outputTimeUnit) / durationNs;
            println("Throughput: %d ops/ms".formatted(throughput));
            if (NUM_RUNS == run)
            {
                validateS(expectedS, s1, s2, s3);
            }
        }
    }

    static short expectS(short[] a1, short[] a2, short[] a3)
    {
        short result = 0;
        for (int i = 0; i < a1.length; i++)
        {
            var val = (short)((a1[i] * a2[i]) + (a1[i] * a3[i]) + (a2[i] * a3[i]));
            result ^= val;
        }
        return result;
    }

    static void validateS(short expected, short[] a1, short[] a2, short[] a3)
    {
        println("Validate");
        var value = testShort(a1, a2, a3);
        assertEquals(expected, value);
    }

    static void init(
        short[] s1
        , short[] s2
        , short[] s3
    ) {
        for (int i = 0; i < s1.length; i++)
        {
            s1[i] = (short) RND.nextInt();
            s2[i] = (short) RND.nextInt();
            s3[i] = (short) RND.nextInt();
        }
    }

    static void assertEquals(short expected, short actual)
    {
        if(expected == actual)
        {
            blackhole(actual);
        }
        else
        {
            throw new AssertionError("Failed: expected: %d, actual: %d".formatted(expected, actual));
        }
    }

    static void blackhole(short value)
    {
        if (value == nanoTime())
        {
            println(value);
        }
    }
}