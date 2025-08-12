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
 * Scalar  143  CheckCastPP  === 140 138  [[ 224 ]]  #BoxInBoxSmall$BoxOuter:NotNull:exact *  Oop:BoxInBoxSmall$BoxOuter:NotNull:exact * !jvms: BoxInBoxSmall::test @ bci:17 (line 8)
 * ++++ Eliminated: 126 Allocate
 * Scalar   44  CheckCastPP  === 41 39  [[ 113 ]]  #BoxInBoxSmall$BoxSmall:NotNull:exact *  Oop:BoxInBoxSmall$BoxSmall:NotNull:exact * !jvms: BoxInBoxSmall::test @ bci:7 (line 7)
 * ++++ Eliminated: 27 Allocate
 * AFTER: AFTER_MACRO_EXPANSION
 *    0  Root  === 0 239  [[ 0 1 3 21 22 99 240 ]] inner
 *    1  Con  === 0  [[ ]]  #top
 *    3  Start  === 3 0  [[ 3 5 6 7 8 9 ]]  #{0:control, 1:abIO, 2:memory, 3:rawptr:BotPTR, 4:return_address}
 *    5  Parm  === 3  [[ 239 ]] Control !orig=[32],[41],[114],[131],[140],[225] !jvms: BoxInBoxSmall::test @ bci:-1 (line 5)
 *    6  Parm  === 3  [[ 239 ]] I_O !orig=[38],[137] !jvms: BoxInBoxSmall::test @ bci:-1 (line 5)
 *    7  Parm  === 3  [[ 239 ]] Memory  Memory: @BotPTR *+bot, idx=Bot; !orig=[51] !jvms: BoxInBoxSmall::test @ bci:-1 (line 5)
 *    8  Parm  === 3  [[ 239 ]] FramePtr !jvms: BoxInBoxSmall::test @ bci:-1 (line 5)
 *    9  Parm  === 3  [[ 239 ]] ReturnAdr !jvms: BoxInBoxSmall::test @ bci:-1 (line 5)
 *   21  ConI  === 0  [[ 239 ]]  #int:1234
 *   22  ConI  === 0  [[ 239 ]]  #int:56
 *   99  ConI  === 0  [[ 239 ]]  #int:1
 *  239  Return  === 5 6 7 8 9 returns 240 21 22 99 1  [[ 0 ]]
 *  240  ConL  === 0  [[ 239 ]]  #long:34084862658545
 *
 * --- Compiler Statistics ---
 * Objects scalar replaced = 2, Monitor objects removed = 0, GC barriers removed = 0, Memory barriers removed = 4
 */
