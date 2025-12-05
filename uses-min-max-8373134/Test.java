import static java.lang.IO.*;

final class Test
{
    static final int ITER = 100_000;
    static final int SIZE = 997;
    static final int UNALIGN_OFF = 5;

    static void test(boolean[] a, boolean[] b)
    {
        for (int i = 0; i < a.length - UNALIGN_OFF; i += 1)
        {
            a[i + UNALIGN_OFF] = false;
            b[i] = false;
        }
    }

    public static void main(String[] args)
    {
        boolean[] a1 = new boolean[SIZE];
        boolean[] a2 = new boolean[SIZE];
        println("Warmup");
        for (int i = 0; i < ITER; i++)
        {
            test(a1, a2);
        }
    }
}
