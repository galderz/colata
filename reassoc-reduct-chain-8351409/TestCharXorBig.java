import static java.lang.IO.*;
import static java.lang.System.nanoTime;
import static java.util.concurrent.TimeUnit.*;

import java.lang.String;
import java.util.Random;

final class TestCharXorBig
{
  static final int ITER = 100_000;

  static final int NUM_RUNS = 10;

  static final int SIZE = 10_000;

  static final Random RND = new Random(42);

  static char test(char[] a1, char[] a2, char[] a3) {
    char result = 0;
    for (int i = 0; i < a1.length; i++) {
      var val = (char)((a1[i] * a2[i]) + (a1[i] * a3[i]) + (a2[i] * a3[i]));
      result ^= val;
    }
    return result;
  }

  public static void main(String[] args) {
    var a1 = new char[SIZE];
    var a2 = new char[SIZE];
    var a3 = new char[SIZE];
    init(a1, a2, a3);
    var expected = expect(a1, a2, a3);
    validate(expected, a1, a2, a3);
    println("Warmup");
    for (int i = 0; i < ITER; i++) {
      test(a1, a2, a3);
    }
    println("Running");
    for (int run = 1; run <= NUM_RUNS; run++) {
      var t0 = nanoTime();
      long operations = 0;
      for (int i = 0; i < ITER; i++) {
        blackhole(test(a1, a2, a3));
        operations++;
      }
      var t1 = nanoTime();
      var durationNs = t1 - t0;
      var outputTimeUnit = MILLISECONDS;
      var throughput = operations * NANOSECONDS.convert(1, outputTimeUnit) / durationNs;
      println("Throughput: %d ops/ms".formatted(throughput));
      if (NUM_RUNS == run) {
        validate(expected, a1, a2, a3);
      }
    }
  }

  static void init(char[] a1, char[] a2, char[] a3) {
    for (int i = 0; i < a1.length; i++) {
      a1[i] = (char) RND.nextInt();
      a2[i] = (char) RND.nextInt();
      a3[i] = (char) RND.nextInt();
    }
  }

  static char expect(char[] a1, char[] a2, char[] a3) {
    char result = 0;
    for (int i = 0; i < a1.length; i++) {
      var val = (char)((a1[i] * a2[i]) + (a1[i] * a3[i]) + (a2[i] * a3[i]));
      result ^= val;
    }
    return result;
  }

  static void blackhole(double value) {
    if (value == nanoTime()) {
      println(value);
    }
  }

  static void validate(char expected, char[] a1, char[] a2, char[] a3) {
    println("Validate");
    var value = test(a1, a2, a3);
    assertEquals(expected, value);
  }

  static void assertEquals(char expected, char actual) {
    if(expected == actual) {
      blackhole(actual);
    } else {
      throw new AssertionError("Failed: expected: %d, actual: %d".formatted(expected, actual));
    }
  }
}
