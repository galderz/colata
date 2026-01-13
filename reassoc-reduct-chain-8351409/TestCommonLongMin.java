import static java.lang.IO.*;
import static java.lang.System.nanoTime;
import static java.util.concurrent.TimeUnit.*;

import java.lang.String;
import java.util.Random;

final class TestCommonLongMin {
    static final int ITER = 100_000;

    static final int NUM_RUNS = 10;

    static final int SIZE = 10_000;

    static final Random RND = new Random(42);

    static Object[] test(long[] input_122) {
        long result = Long.MAX_VALUE;
        long result2 = Long.MAX_VALUE;
        for (int i = 0; i < input_122.length; i += 4) {
            long v0 = input_122[i + 0];
            long v1 = input_122[i + 1];
            long v2 = input_122[i + 2];
            long v3 = input_122[i + 3];
            long u0 = Long.min(v0, result);
            long u1 = Long.min(v1, u0);
            long u2 = Long.min(v2, u1);
            long u3 = Long.min(v3, u2);
            result = u3;
            long t0 = Long.min(v0, v1);
            long t1 = Long.min(v2, t0);
            long t2 = Long.min(v3, t1);
            long t3 = Long.min(result, t2);
            result2 = t3;
        }
        return new Object[] {result, result2};
    }

    public static void main(String[] args) {
        var array = new long[SIZE];
        init(array);
        println("Warmup");
        for (int i = 0; i < ITER; i++) {
            test(array);
        }
        println("Running");
        for (int run = 1; run <= NUM_RUNS; run++) {
            var t0 = nanoTime();
            long operations = 0;
            for (int i = 0; i < ITER; i++) {
                blackhole(test(array));
                operations++;
            }
            var t1 = nanoTime();
            var durationNs = t1 - t0;
            var outputTimeUnit = MILLISECONDS;
            var throughput = operations * NANOSECONDS.convert(1, outputTimeUnit) / durationNs;
            println("Throughput: %d ops/ms".formatted(throughput));
        }
    }

    static void init(long[] array) {
        for (int i = 0; i < array.length; i++) {
            array[i] = RND.nextLong() & 0xFFFF_FFFFL;
        }
    }

    static void blackhole(Object[] value) {
        if (value.hashCode() == nanoTime()) {
            println(value);
        }
    }
}
