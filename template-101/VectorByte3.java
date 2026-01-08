import java.util.*;

public class VectorByte3
{
    static final int ITER = 10_000;
    static final int MAX_LOOP = 1_000;
    static final Random R = new Random();

    static long test(int loop)
    {
        Vector v = null;
        for (int i = 0; i < loop; i++)
        {
            v = sum(
                new Vector((byte) R.nextLong(), (byte) R.nextLong())
                , new Vector((byte) R.nextLong(), (byte) R.nextLong())
            );
        }
        return v.hashCode();
    }

    private static Vector sum(Vector a, Vector b)
    {
        return a.add(b);
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

value class Vector
{
    byte x;
    byte y;

    Vector(byte x, byte y)
    {
        this.x = x;
        this.y = y;
    }

    public Vector add(Vector other)
    {
        return new Vector((byte) (x + other.x), (byte) (y + other.y));
    }
}
