import java.util.stream.IntStream;

class Scalarization
{
    public static void main(String[] args)
    {
        final Point[] array = init();
        for (int i = 0; i < 10_000; i++)
        {
            final int result = test(array);
            blackhole(result);
        }
    }

    static Point[] init()
    {
        return IntStream.range(0, 9)
            .mapToObj(i -> new Point(i, i))
            .toArray(Point[]::new);
    }

    static int test(Point[] array)
    {
        int x = 0;
        int y = 0;
        for (ArrayCursor<Point> cursor = new ArrayCursor<>(array, 0)
             ; cursor.hasNext()
             ; cursor = cursor.advance()
        )
        {
            final Point point = cursor.get();
            x += point.x;
            y += point.y;
        }
        return x + y;
    }

    value record ArrayCursor<T>(T[] base, int offset)
    {
        boolean hasNext()
        {
            return offset < base.length;
        }

        ArrayCursor<T> advance()
        {
            return new ArrayCursor<>(base, offset + 1);
        }

        T get()
        {
            return base[offset];
        }
    }

    static void blackhole(Object obj)
    {
        if (obj.hashCode() == System.nanoTime())
        {
            System.out.println(obj);
        }
    }

    record Point(int x, int y) {}
}