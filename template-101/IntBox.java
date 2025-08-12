/**
 * 0  Root  === 0 117  [[ 0 1 3 45 ]] inner
 * 3  Start  === 3 0  [[ 3 5 6 7 8 9 ]]  #{0:control, 1:abIO, 2:memory, 3:rawptr:BotPTR, 4:return_address}
 * 5  Parm  === 3  [[ 117 ]] Control !orig=[30],[39],[102] !jvms: Test::test @ bci:-1 (line 5)
 * 6  Parm  === 3  [[ 117 ]] I_O !orig=[36] !jvms: Test::test @ bci:-1 (line 5)
 * 7  Parm  === 3  [[ 117 ]] Memory  Memory: @BotPTR *+bot, idx=Bot; !orig=[50] !jvms: Test::test @ bci:-1 (line 5)
 * 8  Parm  === 3  [[ 117 ]] FramePtr !jvms: Test::test @ bci:-1 (line 5)
 * 9  Parm  === 3  [[ 117 ]] ReturnAdr !jvms: Test::test @ bci:-1 (line 5)
 * 45  ConI  === 0  [[ 117 ]]  #int:123
 * 117  Return  === 5 6 7 8 9 returns 45  [[ 0 ]]
 */
public class IntBox
{
    static int test()
    {
        var box = new BoxI(123);
        return box.field;
    }

    static value

    class BoxI
    {
        final int field;

        BoxI(int field)
        {
            this.field = field;
        }
    }

    static final int ITER = 10_000;

    public static void main(String[] args)
    {
        final int gold = 123;

        for (int i = 0; i < ITER; i++)
        {
            int result = test();
            validate(gold, result);
        }
    }

    static void validate(int expected, int actual)
    {
        if (expected == actual)
        {
            System.out.print(".");
        }
        else
        {
            throw new AssertionError(String.format(
                "Failed, expected: %s, actual: %s"
                , expected
                , actual
            ));
        }
    }
}