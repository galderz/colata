import java.util.Random;

import static java.lang.IO.*;
import static java.lang.System.nanoTime;

public class Test
{
    static void main()
    {
        println("Run");

        var array = array();
        for (int i = 0; i < 10_000; i++)
        {
            var result = test(array);
            blackhole(result);
        }

        println("Done");
    }

    static long test(long[] array)
    {
        long result = Long.MIN_VALUE;
        for (int i = 0; i < array.length; i++)
        {
            var v = array[i];
            result = Math.max(v, result);
        }
        return result;
    }

    static long[] array()
    {
        var array = new long[10_000];
        var rnd = new Random(42);
        for (int i = 0; i < array.length; i++)
        {
            array[i] = rnd.nextLong() & 0xFFFF_FFFFL;
        }
        return array;
    }

    static void blackhole(long value)
    {
        if (value == nanoTime())
        {
            println(value);
        }
    }
}