import java.util.concurrent.TimeUnit;
import java.util.Random;

public class PrimitiveAndIf
{
    public static long test(long[] array)
    {
        long x = Integer.MIN_VALUE;
        for (int i = 0; i < array.length; i++)
        {
            long v = array[i];
            // Control flow that prevents vectorization:
            if (v < 0)
            {
                throw new RuntimeException("some error condition, probably deopt");
            }
            x = Math.max(x, v);
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
