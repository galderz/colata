import static java.lang.IO.*;
import static java.lang.System.nanoTime;
import static java.util.concurrent.TimeUnit.*;

import java.lang.String;
import java.util.Random;
import jdk.incubator.vector.Float16;

final class TestCommonHalfFloatMin {
    static final int ITER = 100_000;

    static final int NUM_RUNS = 1;

    static final int SIZE = 10_000;

    static final Random RND = new Random(42);

    static Object[] test(Float16[] input_32) {
        Float16 result = Float16.MAX_VALUE;
        Float16 result2 = Float16.MAX_VALUE;
        for (int i = 0; i < input_32.length; i += 4) {
            Float16 v0 = input_32[i + 0];
            Float16 v1 = input_32[i + 1];
            Float16 v2 = input_32[i + 2];
            Float16 v3 = input_32[i + 3];
            Float16 u0 = Float16.min(v0, result);
            Float16 u1 = Float16.min(v1, u0);
            Float16 u2 = Float16.min(v2, u1);
            Float16 u3 = Float16.min(v3, u2);
            result = u3;
            Float16 t0 = Float16.min(v0, v1);
            Float16 t1 = Float16.min(v2, t0);
            Float16 t2 = Float16.min(v3, t1);
            Float16 t3 = Float16.min(result, t2);
            result2 = t3;
        }
        return new Object[] {result, result2};
    }

    public static void main(String[] args) {
        var array = new Float16[SIZE];
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

    static void init(Float16[] array) {
        for (int i = 0; i < array.length; i++) {
            array[i] = Float16.shortBitsToFloat16((short) RND.nextInt(Short.MAX_VALUE + 1));
        }
    }

    static void blackhole(Object[] value) {
        if (value.hashCode() == nanoTime()) {
            println(value);
        }
    }
}
