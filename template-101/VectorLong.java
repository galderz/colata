import java.util.*;

public class VectorLong
{
    static final int ITER = 10_000;
    static final int MAX_LOOP = 1_000;
    static final Random R = new Random();

    static long test(int loop)
    {
        Vector v = null;
        for (int i = 0; i < loop; i++)
        {
//            v = new Vector(R.nextInt(), R.nextInt())
//                .add(new Vector(R.nextLong(), R.nextLong()));

            v = sum(
                new Vector(R.nextLong(), R.nextLong())
                , new Vector(R.nextLong(), R.nextLong())
                , new Vector(R.nextLong(), R.nextLong())
                , R.nextBoolean()
            );
        }
        return v.hashCode();
    }

//    private static Vector sum(Vector a, Vector b)
//    {
//        return a.add(b);
//    }

    private static Vector sum(Vector a, Vector b, Vector c, boolean blackhole)
    {
        final Vector x = a.add(b);
        if (blackhole)
        {
            return blackhole(x);
        }

        return x.add(c);
    }

    private static Vector blackhole(Vector a)
    {
        return new Vector(a.x(), a.y());
    }

    public static void main(String[] args)
    {
        for (int i = 0; i < ITER; i++)
        {
            var result = test(R.nextInt(MAX_LOOP) + 1);
            validate(result);
        }
    }

    static void validate(long result)
    {
        if (result == System.nanoTime())
        {
            System.out.println("x");
        }
        else
        {
            System.out.print("");
        }
    }
}

value record Vector(long x, long y)
{
    public Vector add(Vector other)
    {
        return new Vector(x + other.x, y + other.y);
    }
}
