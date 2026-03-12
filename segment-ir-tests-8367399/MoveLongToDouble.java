import java.lang.foreign.*;
import java.util.*;

/**
 * $ make PRINT=BEFORE_LOOP_UNROLLING
 *   1179  MoveL2D  === _ 1180  [[ 1178 ]]  !orig=995 !jvms: VarHandleSegmentAsDoubles::get @ bci:49 (line 64) VarHandleSegmentAsDoubles::get @ bci:10 (line 53) VarHandleGuards::guard_LJ_D @ bci:49 (line 293) AbstractMemorySegmentImpl::get @ bci:8 (line 812) Test::test @ bci:19 (line 28)
 *
 * VarHandleSegmentAsDoubles::get
 * @ForceInline
 * static double get(VarHandle ob, Object obb, long base, long offset) {
 *     SegmentVarHandle handle = (SegmentVarHandle)ob;
 *     AbstractMemorySegmentImpl bb = handle.checkSegment(obb, base, true);
 *     long rawValue = SCOPED_MEMORY_ACCESS.getLongUnaligned(bb.sessionImpl(),
 *             bb.unsafeGetBase(),
 *             offset(bb, base, offset),
 *             handle.be);
 *     return Double.longBitsToDouble(rawValue);
 * }
 */
class MoveLongToDouble
{
    static final int ITER = 10_000;

    static void test(MemorySegment src, double[] dst)
    {
        for (int i = 0; i < 2_000; i++)
        {
            double v = (double) src.get(ValueLayout.JAVA_DOUBLE_UNALIGNED, 8L * i);
            dst[i] = v;
        }
    }

    public static void main(String[] args)
    {
        Random rnd = new Random();
        MemorySegment src = MemorySegment.ofArray(new double[2_000]);
        for (int i = 0; i < 2_000; i++) {
            src.set(ValueLayout.JAVA_DOUBLE_UNALIGNED, 8L * i, rnd.nextDouble());
        }

        double[] dst = new double[2_000];
        for (long i = 0; i < ITER; i++)
        {
            test(src, dst);
        }
    }
}
