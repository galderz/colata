import java.lang.foreign.*;
import java.util.*;

/**
 * $ make PRINT=BEFORE_LOOP_UNROLLING
 *  1211  MoveD2L  === _ 1577  [[ 1210 ]]  !orig=873 !jvms: VarHandleSegmentAsDoubles::set @ bci:39 (line 79) VarHandleSegmentAsDoubles::set @ bci:12 (line 69) VarHandleGuards::guard_LJD_V @ bci:51 (line 657) AbstractMemorySegmentImpl::set @ bci:10 (line 818) Test::test @ bci:22 (line 28)
 *
 * VarHandleSegmentAsDoubles::set
 * @ForceInline
 * static void set(VarHandle ob, Object obb, long base, long offset, double value) {
 *     SegmentVarHandle handle = (SegmentVarHandle)ob;
 *     AbstractMemorySegmentImpl bb = handle.checkSegment(obb, base, false);
 *     SCOPED_MEMORY_ACCESS.putLongUnaligned(bb.sessionImpl(),
 *             bb.unsafeGetBase(),
 *             offset(bb, base, offset),
 *             Double.doubleToRawLongBits(value),
 *             handle.be);
 * }
 */
class MoveDoubleToLong
{
    static final int ITER = 10_000;

    static void test(double[] src, MemorySegment dst)
    {
        for (int i = 0; i < 2_000; i++)
        {
            dst.set(ValueLayout.JAVA_DOUBLE_UNALIGNED, 8L * i, src[i]);
        }
    }

    public static void main(String[] args)
    {
        Random rnd = new Random();
        double[] src = new double[2_000];
        for (int i = 0; i < 2_000; i++) {
            src[i] = rnd.nextDouble();
        }

        MemorySegment dst = MemorySegment.ofArray(new double[2_000]);
        for (long i = 0; i < ITER; i++)
        {
            test(src, dst);
        }
    }
}
