import java.util.concurrent.TimeUnit;
import java.util.Random;

public class PrimitiveAndIfUnrolled
{
    public static long test(long[] array)
    {
        long x = Integer.MIN_VALUE;
        for (int i = 0; i < array.length; i+=4)
        {
            long v0 = array[i + 0];
            long v1 = array[i + 1];
            long v2 = array[i + 2];
            long v3 = array[i + 3];

            // Expand
            // x = Math.max(v3, Math.max(v2, Math.max(v1, Math.max(v0, x))));
            // To
            long t0 = Math.max(v0, x);
            long t1 = Math.max(v1, t0);
            long t2 = Math.max(v2, t1);
            x = Math.max(v3, t2);
        }
        return x;
    }

    public static void main(String[] args)
    {
        Random r = new Random(42);
        long[] array = new long[10_000];
        for (int i = 0; i < array.length; i++)
        {
            array[i] = r.nextLong() & 0xFFFF_FFFFL;
        }

        System.out.println("Warmup");
        for (int i = 0; i < 100_000; i++)
        {
            test(array);
        }

        System.out.println("Running");
        for (int run = 0; run < 10; run++)
        {
            for (int i = 0; i < array.length; i++)
            {
                array[i] = r.nextLong() & 0xFFFF_FFFFL;
            }
            long t0 = System.nanoTime();
            long operations = 0;
            for (int i = 0; i < 100_000; i++)
            {
                test(array);
                operations++;
            }
            long t1 = System.nanoTime();
            System.out.printf(
                "Throughput: %d ops/ms%n"
                , operations / TimeUnit.NANOSECONDS.toMillis(t1 - t0)
            );
        }
    }
}
