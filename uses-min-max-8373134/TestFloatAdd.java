/**
 * No identity optimization due to rounding.
 */
public class TestFloatAdd
{
    private static float test(float a, float b)
    {
        int i;
        for (i = -10; i < 1; i++)
        {
        }
        float c = a * i;
        return a + (b - c);
    }

    public static void main(String[] args)
    {
        for (int i = 0; i < 20_000; i++)
        {
            test(42f, 42f);
        }
    }
}
