import java.util.concurrent.ThreadLocalRandom;

public class DoubleMax
{
    static final int ITER = 10_000;

    static double test(double a, double b)
    {
        return Math.max(a, b);
    }

    public static void main(String[] args)
    {
        for (long i = 0; i < ITER; i++)
        {
            double a = ThreadLocalRandom.current().nextDouble();
            double b = ThreadLocalRandom.current().nextDouble();
            test(a, b);
        }
    }
}
