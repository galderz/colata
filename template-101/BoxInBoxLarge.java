public class BoxInBoxLarge
{
    static BoxOuter test()
    {
        long f1 = 1234L;
        int f2 = 56;
        var large = new BoxLarge(f1, f2);
        var box = new BoxOuter(large);
        return box;
    }

    static value

    class BoxOuter
    {
        final BoxLarge field;

        public BoxOuter(BoxLarge field)
        {
            this.field = field;
        }
    }

    static value

    class BoxLarge
    {
        final long f1;
        final int f2;

        BoxLarge(long f1, int f2)
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
 *   27  Allocate  === 5 6 7 8 1 (25 23 24 1 1 _ _ _ 21 1 22 1 1 ) [[ 28 29 30 37 38 39 ]]  rawptr:NotNull ( int:>=0, java/lang/Object:NotNull *, bool, top, bool, bottom, java/lang/Object:NotNull *, long ) allocationKlass:BoxInBoxLarge$BoxLarge BoxInBoxLarge::test @ bci:7 (line 7) !jvms: BoxInBoxLarge::test @ bci:7 (line 7)
 *
 * NotScalar (Object is referenced by node) 215  InlineType  === _ 198 99 99 21 22  [[ 216 277 ]]  #BoxInBoxLarge$BoxLarge:NotNull:exact *  Oop:BoxInBoxLarge$BoxLarge:NotNull:exact * !orig=116 !jvms: BoxInBoxLarge::test @ bci:13 (line 7)
 *   >>>>  216  EncodeP  === _ 215  [[ 217 ]]  #narrowoop: BoxInBoxLarge$BoxLarge:NotNull:exact * !orig=[255] !jvms: BoxInBoxLarge$BoxOuter::<init> @ bci:2 (line 20) BoxInBoxLarge::test @ bci:22 (line 8)
 * Scalar  141  CheckCastPP  === 138 136  [[ 248 186 186 176 176 186 158 158 176 ]]  #BoxInBoxLarge$BoxOuter:NotNull:exact *  Oop:BoxInBoxLarge$BoxOuter:NotNull:exact * !jvms: BoxInBoxLarge::test @ bci:17 (line 8)
 * Scalar   44  CheckCastPP  === 41 39  [[ 112 ]]  #BoxInBoxLarge$BoxLarge:NotNull:exact *  Oop:BoxInBoxLarge$BoxLarge:NotNull:exact * !jvms: BoxInBoxLarge::test @ bci:7 (line 7)
 * ++++ Eliminated: 27 Allocate
 *
 * NotScalar (Object is referenced by node) 215  InlineType  === _ 198 99 99 21 22  [[ 216 277 ]]  #BoxInBoxLarge$BoxLarge:NotNull:exact *  Oop:BoxInBoxLarge$BoxLarge:NotNull:exact * !orig=116 !jvms: BoxInBoxLarge::test @ bci:13 (line 7)
 *   >>>>  216  EncodeP  === _ 215  [[ 217 ]]  #narrowoop: BoxInBoxLarge$BoxLarge:NotNull:exact * !orig=[255] !jvms: BoxInBoxLarge$BoxOuter::<init> @ bci:2 (line 20) BoxInBoxLarge::test @ bci:22 (line 8)
 * Scalar  141  CheckCastPP  === 138 136  [[ 248 186 186 176 176 186 158 158 176 ]]  #BoxInBoxLarge$BoxOuter:NotNull:exact *  Oop:BoxInBoxLarge$BoxOuter:NotNull:exact * !jvms: BoxInBoxLarge::test @ bci:17 (line 8)
 *
 * NotScalar (Object is referenced by node) 215  InlineType  === _ 198 99 99 21 22  [[ 216 277 ]]  #BoxInBoxLarge$BoxLarge:NotNull:exact *  Oop:BoxInBoxLarge$BoxLarge:NotNull:exact * !orig=116 !jvms: BoxInBoxLarge::test @ bci:13 (line 7)
 *   >>>>  216  EncodeP  === _ 215  [[ 217 ]]  #narrowoop: BoxInBoxLarge$BoxLarge:NotNull:exact * !orig=[255] !jvms: BoxInBoxLarge$BoxOuter::<init> @ bci:2 (line 20) BoxInBoxLarge::test @ bci:22 (line 8)
 * Scalar  141  CheckCastPP  === 138 136  [[ 248 186 186 176 176 186 158 158 176 ]]  #BoxInBoxLarge$BoxOuter:NotNull:exact *  Oop:BoxInBoxLarge$BoxOuter:NotNull:exact * !jvms: BoxInBoxLarge::test @ bci:17 (line 8)
 */
