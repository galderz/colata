import java.lang.foreign.*;
import java.util.*;

/**
 * $ make PRINT=BEFORE_LOOP_UNROLLING
 *  1181  MoveI2F  === _ 1182  [[ 1180 ]]  !orig=997 !jvms: VarHandleSegmentAsFloats::get @ bci:49 (line 64) VarHandleSegmentAsFloats::get @ bci:10 (line 53) VarHandleGuards::guard_LJ_F @ bci:49 (line 280) AbstractMemorySegmentImpl::get @ bci:8 (line 788) Test::test @ bci:19 (line 11)
 *
 * VarHandleSegmentAsFloats::get
 * @ForceInline
 * static float get(VarHandle ob, Object obb, long base, long offset) {
 *     SegmentVarHandle handle = (SegmentVarHandle)ob;
 *     AbstractMemorySegmentImpl bb = handle.checkSegment(obb, base, true);
 *     int rawValue = SCOPED_MEMORY_ACCESS.getIntUnaligned(bb.sessionImpl(),
 *             bb.unsafeGetBase(),
 *             offset(bb, base, offset),
 *             handle.be);
 *     return Float.intBitsToFloat(rawValue);
 * }
 */
class MoveIntToFloat
{
    static final int ITER = 10_000;

    static void test(MemorySegment src, float[] dst)
    {
        for (int i = 0; i < 2_000; i++) {
            float v = (float) src.get(ValueLayout.JAVA_FLOAT_UNALIGNED, 4L * i);
            dst[i] = v;
        }
    }

    public static void main(String[] args)
    {
        Random rnd = new Random();
        MemorySegment src = MemorySegment.ofArray(new float[2_000]);
        for (int i = 0; i < 2_000; i++) {
            src.set(ValueLayout.JAVA_FLOAT_UNALIGNED, 4L * i, rnd.nextFloat());
        }

        float[] dst = new float[2_000];
        for (long i = 0; i < ITER; i++)
        {
            test(src, dst);
        }
    }
}
