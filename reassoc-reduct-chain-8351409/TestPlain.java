import static java.lang.IO.*;
import static java.lang.System.nanoTime;
import static java.util.concurrent.TimeUnit.*;

import java.lang.String;
import java.util.Random;

// Same loop as in https://github.com/galderz/jdk/blob/33b057c686b52aa192ef98c54881cb215467a921/test/hotspot/jtreg/compiler/loopopts/TestReductionReassociation.java
final class TestPlain {
    static final int ITER = 100_000;

    static final int NUM_RUNS = 10;

    static final int SIZE = 10_000;

    static final Random RND = new Random(42);

    static Object[] test(long[] array) {
        long result = Integer.MIN_VALUE;
        long result2 = Integer.MIN_VALUE;
        for (int i = 0; i < array.length; i += 4) {
            long v0 = array[i + 0];
            long v1 = array[i + 1];
            long v2 = array[i + 2];
            long v3 = array[i + 3];

            // result = max(v3, max(v2, max(v1, max(v0, result))))
            long u0 = Math.max(v0, result);
            long u1 = Math.max(v1, u0);
            long u2 = Math.max(v2, u1);
            long u3 = Math.max(v3, u2);
            result = u3;

            // result2 = max(result, max(max(v0, v1), max(v2, v3))
            long t0 = Math.max(v0, v1);
            long t1 = Math.max(v2, v3);
            long t2 = Math.max(t0, t1);
            long t3 = Math.max(result, t2);
            result2 = t3;
        }

        return new Object[]{result, result2};
    }

    public static void main(String[] args) {
        var array = new long[SIZE];
        init(array);
        var expected = expect(array);
        validate(expected, array);
        println("Warmup");
        for (int i = 0; i < ITER; i++) {
            test(array);
        }
        println("Running");
        for (int run = 1; run <= NUM_RUNS; run++) {
            var t0 = nanoTime();
            long operations = 0;
            for (int i = 0; i < ITER; i++) {
                test(array);
                operations++;
            }
            var t1 = nanoTime();
            var durationNs = t1 - t0;
            var outputTimeUnit = MILLISECONDS;
            var throughput = operations * NANOSECONDS.convert(1, outputTimeUnit) / durationNs;
            println("Throughput: %d ops/ms".formatted(throughput));
            if (NUM_RUNS == run) {
                validate(expected, array);
            }
        }
    }

    static void init(long[] array) {
        for (int i = 0; i < array.length; i++) {
            array[i] = RND.nextLong() & 0xFFFF_FFFFL;
        }
    }

    static long expect(long[] array) {
        long result = Integer.MIN_VALUE;
        for (int i = 0; i < array.length; i++) {
            var v = array[i];
            var t = Math.max(v, result);
            result = t;
        }
        return result;
    }

    static void blackhole(long value) {
        if (value == nanoTime()) {
            println(value);
        }
    }

    static void validate(long expected, long[] array) {
        println("Validate");
        var value = test(array);
        assertEquals(expected, (long) value[0]);
        assertEquals(expected, (long) value[1]);
        // assertEquals(expected, value);
    }

    static void assertEquals(long expected, long actual) {
        if(expected == actual) {
            blackhole(actual);
        } else {
            throw new AssertionError("Failed: expected: %d, actual: %d".formatted(expected, actual));
        }
    }
}
