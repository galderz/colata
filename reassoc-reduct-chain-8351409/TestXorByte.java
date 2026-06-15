import static java.lang.IO.*;
import static java.lang.System.nanoTime;
import static java.util.concurrent.TimeUnit.*;

import java.util.Random;

public class TestXorByte
{
    static final int ITER = 100_000;

    static final int NUM_RUNS = 10;

    static final int SIZE = 10_000;

    static final Random RND = new Random(42);

    static byte testByte(byte[] a1, byte[] a2, byte[] a3)
    {
        byte result = 0;
        for (int i = 0; i < a1.length; i++)
        {
            var val = (byte)((a1[i] * a2[i]) + (a1[i] * a3[i]) + (a2[i] * a3[i]));
            result ^= val;
        }
        return result;
    }

    static void main()
    {
        var b1 = new byte[SIZE];
        var b2 = new byte[SIZE];
        var b3 = new byte[SIZE];
        init(b1, b2, b3);
        var expectedB = expectB(b1, b2, b3);
        validateB(expectedB, b1, b2, b3);

        println("Warmup");
        for (int i = 0; i < ITER; i++)
        {
            testByte(b1, b2, b3);
        }
        println("Running Byte");
        for (int run = 1; run <= NUM_RUNS; run++)
        {
            var t0 = nanoTime();
            long operations = 0;
            for (int i = 0; i < ITER; i++)
            {
                blackhole(testByte(b1, b2, b3));
                operations++;
            }
            var t1 = nanoTime();
            var durationNs = t1 - t0;
            var outputTimeUnit = MILLISECONDS;
            var throughput = operations * NANOSECONDS.convert(1, outputTimeUnit) / durationNs;
            println("Throughput: %d ops/ms".formatted(throughput));
            if (NUM_RUNS == run)
            {
                validateB(expectedB, b1, b2, b3);
            }
        }
    }

    static byte expectB(byte[] a1, byte[] a2, byte[] a3)
    {
        byte result = 0;
        for (int i = 0; i < a1.length; i++)
        {
            var val = (byte)((a1[i] * a2[i]) + (a1[i] * a3[i]) + (a2[i] * a3[i]));
            result ^= val;
        }
        return result;
    }

    static void validateB(byte expected, byte[] a1, byte[] a2, byte[] a3)
    {
        println("Validate");
        var value = testByte(a1, a2, a3);
        assertEquals(expected, value);
    }

    static void init(
        byte[] b1
        , byte[] b2
        , byte[] b3
    ) {
        for (int i = 0; i < b1.length; i++)
        {
            b1[i] = (byte) RND.nextInt();
            b2[i] = (byte) RND.nextInt();
            b3[i] = (byte) RND.nextInt();
        }
    }

    static void assertEquals(byte expected, byte actual)
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

    static void blackhole(byte value)
    {
        if (value == nanoTime())
        {
            println(value);
        }
    }
}