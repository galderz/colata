import jdk.incubator.vector.Float16;

/**
 * long c = a * i;
 * is going to optimize to c = a;
 *
 * But we want that to happen sometimes after parsing.
 * One way to get that is with an empty counted loop.
 * On the first pass of loop opts, the loop goes away,
 * i is replaced by 1 and a*i is enqueued for igvn,
 * which causes c = a, which causes max(a, b) to be processed
 * but nothing pushes max(a, max(a, b)) for igvn.
 */
public class TestFloat16Max
{
//    private static Float16 test(Float16 a, Float16 b)
//    {
//        int i;
//        for (i = -10; i < 1; i++)
//        {
//        }
//        Float16 c = Float16.multiply(a, Float16.shortBitsToFloat16((short) i));
//        return Float16.max(a, Float16.max(c, b));
//    }

    private static Float16 test(Float16 b, Float16 a)
    {
        int i;
        for (i = -10; i < 1; i++)
        {
        }
        Float16 c = Float16.multiply(a, Float16.valueOf(i));
        return Float16.max(a, Float16.max(c, b));
    }

    public static void main(String[] args)
    {
        for (int i = 0; i < 20_000; i++)
        {
            // test(Float16.shortBitsToFloat16((short) 42), Float16.shortBitsToFloat16((short) 42));
            // test(Float16.valueOf(42), Float16.valueOf(42));
            test(Float16.valueOf(42), Float16.valueOf(42));
        }
    }
}