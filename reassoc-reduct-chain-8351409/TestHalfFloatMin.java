import static java.lang.IO.*;
import static java.lang.System.nanoTime;
import static java.util.concurrent.TimeUnit.*;

import java.lang.String;
import java.util.Random;
import jdk.incubator.vector.Float16;

final class TestHalfFloatMin {
  static final int ITER = 100_000;

  static final int NUM_RUNS = 1;

  static final int SIZE = 10_000;

  static final Random RND = new Random(42);

  static Float16 test(Float16 array) {
    Float16 result = Float16.MAX_VALUE;
    for (int i = 0; i < array.length; i ++) {
      var v = array[i];
      result = Float16.min(v, result);
    }
    return result;
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

  static void blackhole(Float16 value) {
    if (value.hashCode() == nanoTime()) {
      println(value);
    }
  }
}
