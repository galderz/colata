import java.lang.foreign.*;

/**
 * $ CLASS=MoveFloatToInt make PRINT=BEFORE_LOOP_UNROLLING
 *  2069  MoveF2I  === _ 2070  [[ 2068 ]]  !orig=1654 !jvms: VarHandleSegmentAsFloats::set @ bci:39 (line 79) VarHandleSegmentAsFloats::set @ bci:12 (line 69) VarHandleGuards::guard_LJF_V @ bci:51 (line 642) AbstractMemorySegmentImpl::set @ bci:10 (line 794) Test::test @ bci:37 (line 11)
 *
 * VarHandleSegmentAsFloats::set
 * @ForceInline
 * static void set(VarHandle ob, Object obb, long base, long offset, float value) {
 *     SegmentVarHandle handle = (SegmentVarHandle)ob;
 *     AbstractMemorySegmentImpl bb = handle.checkSegment(obb, base, false);
 *     SCOPED_MEMORY_ACCESS.putIntUnaligned(bb.sessionImpl(),
 *             bb.unsafeGetBase(),
 *             offset(bb, base, offset),
 *             Float.floatToRawIntBits(value),
 *             handle.be);
 */
class MoveFloatToInt
{
    static final int ITER = 10_000;

    static void test(MemorySegment src, MemorySegment dst)
    {
        for (int i = 0; i < 2_000; i++)
        {
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
