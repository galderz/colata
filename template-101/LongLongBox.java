public class LongLongBox
{
    static BoxJJ test()
    {
        var box = new BoxJJ(65535L, -67108872L);
        return box;
    }

    static value class BoxJJ
    {
        final long j1;
        final long j2;

        BoxJJ(long j1, long j2)
        {
            this.j1 = j1;
            this.j2 = j2;
        }
    }

    static final int ITER = 10_000;

    public static void main(String[] args)
    {
        for (int i = 0; i < ITER; i++)
        {
            var result = test();
            validate(result);
        }
    }

    static void validate(BoxJJ result)
    {
        if (result.hashCode() == System.nanoTime())
        {
            System.out.println("x");
        }
        else
        {
            System.out.print(".");
        }
    }
}