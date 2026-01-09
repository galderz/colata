import static java.lang.IO.*;
import static java.lang.System.nanoTime;
import static java.util.concurrent.TimeUnit.*;

import java.lang.String;
import java.util.Random;

final class TestCommute {
  static final int ITER = 100_000;

  static final int NUM_RUNS = 10;

  static final int SIZE = 10_000;

  static final Random RND = new Random(42);

  static long test(long[] array) {
    long result = Integer.MIN_VALUE;
    for (int i = 0; i < array.length; i += 4) {
      var v0 = array[i + 0];
      var v1 = array[i + 1];
      var v2 = array[i + 2];
      var v3 = array[i + 3];
      var t0 = Math.max(result, v0);
      var t1 = Math.max(t0, v1);
      var t2 = Math.max(t1, v2);
      var t3 = Math.max(t2, v3);
      // result = max(v3, max(v2, max(v1, max(v0, result))))
      result = t3;
    }
    return result;
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
    assertEquals(expected, value);
  }

  static void assertEquals(long expected, long actual) {
    if(expected == actual) {
      blackhole(actual);
    } else {
      throw new AssertionError("Failed: expected: %d, actual: %d".formatted(expected, actual));
    }
  }
}
