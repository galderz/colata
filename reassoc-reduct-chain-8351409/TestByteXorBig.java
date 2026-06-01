import static java.lang.IO.*;
import static java.lang.System.nanoTime;
import static java.util.concurrent.TimeUnit.*;

import java.lang.String;
import java.util.Random;

final class TestByteXorBig
{
  static final int ITER = 100_000;

  static final int NUM_RUNS = 10;

  static final int SIZE = 10_000;

  static final Random RND = new Random(42);

  static byte test(byte[] a1, byte[] a2, byte[] a3) {
    byte result = 0;
    for (int i = 0; i < a1.length; i++) {
      var val = (byte)((a1[i] * a2[i]) + (a1[i] * a3[i]) + (a2[i] * a3[i]));
      result ^= val;
    }
    return result;
  }

  public static void main(String[] args) {
    var a1 = new byte[SIZE];
    var a2 = new byte[SIZE];
    var a3 = new byte[SIZE];
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

  static void init(byte[] a1, byte[] a2, byte[] a3) {
    for (int i = 0; i < a1.length; i++) {
      a1[i] = (byte) RND.nextInt();
      a2[i] = (byte) RND.nextInt();
      a3[i] = (byte) RND.nextInt();
    }
  }

  static byte expect(byte[] a1, byte[] a2, byte[] a3) {
    byte result = 0;
    for (int i = 0; i < a1.length; i++) {
      var val = (byte)((a1[i] * a2[i]) + (a1[i] * a3[i]) + (a2[i] * a3[i]));
      result ^= val;
    }
    return result;
  }

  static void blackhole(byte value) {
    if (value == nanoTime()) {
      println(value);
    }
  }

  static void validate(byte expected, byte[] a1, byte[] a2, byte[] a3) {
    println("Validate");
    var value = test(a1, a2, a3);
    assertEquals(expected, value);
  }

  static void assertEquals(byte expected, byte actual) {
    if(expected == actual) {
      blackhole(actual);
    } else {
      throw new AssertionError("Failed: expected: %d, actual: %d".formatted(expected, actual));
    }
  }
}
