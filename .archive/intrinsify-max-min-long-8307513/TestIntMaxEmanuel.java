import java.util.Random;

public class TestIntMaxEmanuel {
  private static Random RANDOM = new Random();

  public static void main(String[] args) {
    int[] a = new int[64 * 1024];
    for (int i = 0; i < a.length; i++) {
      a[i] = RANDOM.nextInt();
    }


    {
      System.out.println("Warmup");
      for (int i = 0; i < 10_000; i++) { test1(a); }
      System.out.println("Run");
      long t0 = System.nanoTime();
      for (int i = 0; i < 10_000; i++) { test1(a); }
      long t1 = System.nanoTime();
      System.out.println("Time: " + (t1 - t0));
    }

    {
      System.out.println("Warmup");
      for (int i = 0; i < 10_000; i++) { test2(a); }
      System.out.println("Run");
      long t0 = System.nanoTime();
      for (int i = 0; i < 10_000; i++) { test2(a); }
      long t1 = System.nanoTime();
      System.out.println("Time: " + (t1 - t0));
    }
  }

  public static int test1(int[] a) {
    int x = Integer.MIN_VALUE;
    for (int i = 0; i < a.length; i++) {
      x = Math.max(x, a[i]);
    }
    return x;
  }

  public static int test2(int[] a) {
    int x = Integer.MIN_VALUE;
    for (int i = 0; i < a.length; i++) {
      x = (x >= a[i]) ? x : a[i];
    }
    return x;
  }
}
