import static java.lang.IO.*;
import static java.lang.System.nanoTime;
import static java.util.concurrent.TimeUnit.*;

import java.lang.String;
import java.util.Random;

final class TestIntAdd {
  static final int ITER = 100_000;

  static final int NUM_RUNS = 10;

  static final int SIZE = 10_000;

  static final Random RND = new Random(42);

  static int test(int[] array) {
    int result = Integer.MIN_VALUE;
    for (int i = 0; i < array.length; i++) {
      var v = array[i];
      result = v + result;
    }
    return result;
  }

//  private static long getArrayLong_dontinline(int i, long[] array) {
//    return array[i];
//  }

  public static void main(String[] args) {
    var array = new int[SIZE];
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

  static void init(int[] array) {
    for (int i = 0; i < array.length; i++) {
      array[i] = RND.nextInt() & 0xFFFF;
    }
  }

  static int expect(int[] array) {
    int result = Integer.MIN_VALUE;
    for (int i = 0; i < array.length; i++) {
      var v = array[i];
      var t = v + result;
      result = t;
    }
    return result;
  }

  static void blackhole(long value) {
    if (value == nanoTime()) {
      println(value);
    }
  }

  static void validate(int expected, int[] array) {
    println("Validate");
    var value = test(array);
    assertEquals(expected, value);
  }

  static void assertEquals(int expected, int actual) {
    if(expected == actual) {
      blackhole(actual);
    } else {
      throw new AssertionError("Failed: expected: %d, actual: %d".formatted(expected, actual));
    }
  }
}
