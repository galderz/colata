import static java.lang.IO.*;
import static java.lang.System.nanoTime;
import static java.util.concurrent.TimeUnit.*;

import java.lang.String;
import java.util.Random;

final class Test {
  static final int ITER = 100_000;

  static final int NUM_RUNS = 10;

  static final int SIZE = 10_000;

  static final Random RND = new Random(42);

  static long test(long[] array) {
    long result = Integer.MIN_VALUE;;
    for (int i = 0; i < array.length; i += 16) {
      var v0 = array[i + 0];
      var v1 = array[i + 1];
      var v2 = array[i + 2];
      var v3 = array[i + 3];
      var t0 = Math.max(v0, v1);
      var t1 = Math.max(v2, v3);
      var t2 = Math.max(t0, t1);
      result = Math.max(result, t2);
      var v4 = array[i + 4];
      var v5 = array[i + 5];
      var v6 = array[i + 6];
      var v7 = array[i + 7];
      var t3 = Math.max(v4, v5);
      var t4 = Math.max(v6, v7);
      var t5 = Math.max(t3, t4);
      result = Math.max(result, t5);
      var v8 = array[i + 8];
      var v9 = array[i + 9];
      var v10 = array[i + 10];
      var v11 = array[i + 11];
      var t6 = Math.max(v8, v9);
      var t7 = Math.max(v10, v11);
      var t8 = Math.max(t6, t7);
      result = Math.max(result, t8);
      var v12 = array[i + 12];
      var v13 = array[i + 13];
      var v14 = array[i + 14];
      var v15 = array[i + 15];
      var t9 = Math.max(v12, v13);
      var t10 = Math.max(v14, v15);
      var t11 = Math.max(t9, t10);
      result = Math.max(result, t11);
    }
    return result;
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
      init(array);
      long expected = 0;
      if (NUM_RUNS == run) {
        expected = expect(array);
      }
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
        println("Validate");
        var value = test(array);
        validate(expected, value);
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
      result = Math.max(v, result);
    }
    return result;
  }

  static void blackhole(long value) {
    if (value == nanoTime()) {
      println(value);
    }
  }

  static void validate(long expected, long actual) {
    if(expected == actual) {
      blackhole(actual);
    } else {
      throw new AssertionError("Failed: expected: %d, actual: %d".formatted(expected, actual));
    }
  }
}
