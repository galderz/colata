import java.lang.foreign.*;

class Test
{
    static final int ITER = 10_000;

    static void test(MemorySegment src, MemorySegment dst)
    {
        for (int i = 0; i < 2_000; i++) {
            float v = (float) src.get(ValueLayout.JAVA_DOUBLE_UNALIGNED, 8L * i);
            dst.set(ValueLayout.JAVA_FLOAT_UNALIGNED, 4L * i, v);
        }
    }

    public static void main(String[] args)
    {
        MemorySegment src = MemorySegment.ofArray(new float[4_000]);
        MemorySegment dst = MemorySegment.ofArray(new float[2_000]);
        for (long i = 0; i < ITER; i++)
        {
            test(src, dst);
        }
    }
}
