class GetClass
{
    public static void main(String[] args)
    {
        final Object[] points =
            new Object[] {
                new Point(10, 20)
                , new Point(50, 60)
        };

        for (Object point : points)
        {
            System.out.println(point.getClass());
        }
    }

    value record Point(int x, int y) {}
}
