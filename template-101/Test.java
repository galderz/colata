public class Test
{
    // static BoxJI test()
    static long test()
    {
        // var box = new BoxL(new BoxIJ(65535L, -67108872));
        var box = new BoxJI(65535L, -67108872);
        // return box;
        return box.fieldJ;
    }

    static value class BoxL
    {
        final BoxJI field;

        public BoxL(BoxJI field)
        {
            this.field = field;
        }
    }

    static value class BoxJI
    {
        final long fieldJ;
        final int fieldI;

        BoxJI(long fieldJ, int fieldI)
        {
            this.fieldJ = fieldJ;
            this.fieldI = fieldI;
        }
    }

    static final int ITER = 10_000;

    public static void main(String[] args)
    {
        for (int i = 0; i < ITER; i++)
        {
            var result = test();
            validate(result, 65535L);
        }
    }

    static void validate(long expected, long actual)
    {
        if (expected == actual)
        {
            System.out.print(".");
        }
        else
        {
            throw new AssertionError(String.format(
                "Failed, expected: %s, actual: %s"
                , expected
                , actual
            ));
        }
    }

//    static void validate(BoxIJ result)
//    {
//        if (result.hashCode() == System.nanoTime())
//        {
//            System.out.println("x");
//        }
//        else
//        {
//            System.out.print(".");
//        }
//    }
}