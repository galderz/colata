import static java.lang.IO.*;
import static java.lang.System.nanoTime;
import static java.util.concurrent.TimeUnit.*;

import java.util.Random;

public class TestXor
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
        var b1 = new byte[SIZE];
        var b2 = new byte[SIZE];
        var b3 = new byte[SIZE];
        var s1 = new short[SIZE];
        var s2 = new short[SIZE];
        var s3 = new short[SIZE];
        init(b1, b2, b3, s1, s2, s3);
        var expectedB = expectB(b1, b2, b3);
        validateB(expectedB, b1, b2, b3);
        var expectedS = expectS(s1, s2, s3);
        validateS(expectedS, s1, s2, s3);

        println("Warmup");
        for (int i = 0; i < ITER; i++)
        {
            testByte(b1, b2, b3);
            testShort(s1, s2, s3);
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
        println("Validate B");
        var value = testByte(a1, a2, a3);
        assertEquals(expected, value);
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
        println("Validate B");
        var value = testShort(a1, a2, a3);
        assertEquals(expected, value);
    }

    static void init(
        byte[] b1
        , byte[] b2
        , byte[] b3
        , short[] s1
        , short[] s2
        , short[] s3
    ) {
        for (int i = 0; i < b1.length; i++)
        {
            b1[i] = (byte) RND.nextInt();
            b2[i] = (byte) RND.nextInt();
            b3[i] = (byte) RND.nextInt();
            s1[i] = (short) RND.nextInt();
            s2[i] = (short) RND.nextInt();
            s3[i] = (short) RND.nextInt();
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

    static void blackhole(byte value)
    {
        if (value == nanoTime())
        {
            println(value);
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