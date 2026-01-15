import static java.lang.IO.*;
import static java.lang.System.nanoTime;
import static java.util.concurrent.TimeUnit.*;

import java.lang.String;
import java.util.Random;

final class TestCommonLongAdd {
    static final int ITER = 100_000;

    static final int NUM_RUNS = 10;

    static final int SIZE = 10_000;

    static final Random RND = new Random(42);

    static Object[] test(long[] input_17) {
        long result = Long.MIN_VALUE;
        long result2 = Long.MIN_VALUE;
        for (int i = 0; i < input_17.length; i += 4) {
            long v0 = input_17[i + 0];
            long v1 = input_17[i + 1];
            long v2 = input_17[i + 2];
            long v3 = input_17[i + 3];
            long u0 = v0 + result;
            long u1 = v1 + u0;
            long u2 = v2 + u1;
            long u3 = v3 + u2;
            result = u3;
            long t0 = v0 + v1;
            long t1 = v2 + t0;
            long t2 = v3 + t1;
            long t3 = result + t2;
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
            for (int i = 0; i < ITER; i++) {
                blackhole(test(array));
            }
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
