public class BoxInBoxSmall
{
    static BoxOuter test()
    {
        short f1 = 1234;
        byte f2 = 56;
        var small = new BoxSmall(f1, f2);
        var box = new BoxOuter(small);
        return box;
    }

    static value

    class BoxOuter
    {
        final BoxSmall field;

        public BoxOuter(BoxSmall field)
        {
            this.field = field;
        }
    }

    static value

    class BoxSmall
    {
        final short f1;
        final byte f2;

        BoxSmall(short f1, byte f2)
        {
            this.f1 = f1;
            this.f2 = f2;
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

    static void validate(BoxOuter result)
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
/**
 * AFTER: BEFORE_ITER_GVN
 *   27  Allocate  === 5 6 7 8 1 (25 23 24 1 1 _ _ _ 21 22 1 1 ) [[ 28 29 30 37 38 39 ]]  rawptr:NotNull ( int:>=0, java/lang/Object:NotNull *, bool, top, bool, bottom, java/lang/Object:NotNull *, long ) allocationKlass:BoxInBoxSmall$BoxSmall BoxInBoxSmall::test @ bci:7 (line 7) !jvms: BoxInBoxSmall::test @ bci:7 (line 7)
 *  126  Allocate  === 114 38 115 8 1 (124 123 24 1 1 _ _ _ 1 1 250 1 99 21 22 ) [[ 127 128 129 136 137 138 ]]  rawptr:NotNull ( int:>=0, java/lang/Object:NotNull *, bool, top, bool, bottom, java/lang/Object:NotNull *, long ) allocationKlass:BoxInBoxSmall$BoxOuter BoxInBoxSmall::test @ bci:17 (line 8) !jvms: BoxInBoxSmall::test @ bci:17 (line 8)
 *
 * Scalar  143  CheckCastPP  === 140 138  [[ 224 ]]  #BoxInBoxSmall$BoxOuter:NotNull:exact *  Oop:BoxInBoxSmall$BoxOuter:NotNull:exact * !jvms: BoxInBoxSmall::test @ bci:17 (line 8)
 * ++++ Eliminated: 126 Allocate
 * Scalar   44  CheckCastPP  === 41 39  [[ 113 ]]  #BoxInBoxSmall$BoxSmall:NotNull:exact *  Oop:BoxInBoxSmall$BoxSmall:NotNull:exact * !jvms: BoxInBoxSmall::test @ bci:7 (line 7)
 * ++++ Eliminated: 27 Allocate
 *
 * --- Compiler Statistics ---
 * Objects scalar replaced = 2, Monitor objects removed = 0, GC barriers removed = 0, Memory barriers removed = 4
 *
 * Why are allocations removed here? Because the "use" of CheckCastPP are MemBarStoreStore:
 *
 * bool PhaseMacroExpand::can_eliminate_allocation(PhaseIterGVN* igvn, AllocateNode *alloc, GrowableArray <SafePointNode *>* safepoints) {
 *       } else if (res_type->is_inlinetypeptr() && (use->Opcode() == Op_MemBarRelease || use->Opcode() == Op_MemBarStoreStore)) {
 *         // Inline type buffer allocations are followed by a membar
 *
 *   224  MemBarStoreStore  === 140 1 156 1 1 143  [[ 225 226 ]]  !jvms: BoxInBoxSmall$BoxOuter::<init> @ bci:-1 (line 20) BoxInBoxSmall::test @ bci:22 (line 8)
 *   113  MemBarStoreStore  === 41 1 52 1 1 44  [[ 114 115 ]]  !jvms: BoxInBoxSmall$BoxSmall::<init> @ bci:-1 (line 33) BoxInBoxSmall::test @ bci:13 (line 7)
 */
