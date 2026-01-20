import static java.lang.IO.*;
import static java.lang.System.nanoTime;
import static java.util.concurrent.TimeUnit.*;

import java.lang.String;
import java.util.Random;

final class TestCommonLongMaxMiddle
{
    static final int ITER = 100_000;

    static final int NUM_RUNS = 10;

    static final int SIZE = 10_000;

    static final Random RND = new Random(42);

    static Object[] test(long[] input_155) {
        long result = Integer.MIN_VALUE;
        long result2 = Long.MIN_VALUE;
        for (int i = 0; i < input_155.length; i += 8) {
            var v0 = input_155[i + 0];
            var v1 = input_155[i + 1];
            var v2 = input_155[i + 2];
            var v3 = input_155[i + 3];
            var v4 = input_155[i + 4];
            var v5 = input_155[i + 5];
            var v6 = input_155[i + 6];
            var v7 = input_155[i + 7];
            var u0 = Math.max(v0, result);
            var u1 = Math.max(v1, u0);
            var u2 = Math.max(v2, u1);
            var u3 = Math.max(v3, u2);
            if (u3 == input_155.hashCode()) {
                System.out.print("");
            }
            var u4 = Math.max(v4, u3);
            var u5 = Math.max(v5, u4);
            var u6 = Math.max(v6, u5);
            var u7 = Math.max(v7, u6);

            long t0 = Long.max(v0, v1);
            long t1 = Long.max(v2, t0);
            long t2 = Long.max(v3, t1);
            long t3 = Long.max(result, t2);
            if (t3 == input_155.hashCode()) {
                System.out.print("");
            }
            long t4 = Long.max(v4, t3);
            long t5 = Long.max(v5, t4);
            long t6 = Long.max(v6, t5);
            long t7 = Long.max(v7, t6);
            result = u7;
            result2 = t7;
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
