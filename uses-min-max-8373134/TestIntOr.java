/**
 * int c = a * i;
 * is going to optimize to c = a;
 *
 * But we want that to happen sometimes after parsing.
 * One way to get that is with an empty counted loop.
 * On the first pass of loop opts, the loop goes away,
 * i is replaced by 1 and a*i is enqueued for igvn,
 * which causes c = a, which causes a | b to be processed
 * but nothing pushes a | (b | c) for igvn.
 *
 *  114  OrI  === _ 10 11  [[ 115 ]]  !jvms: TestIntOr::test @ bci:21 (line 21)
 *  115  OrI  === _ 11 114  [[ 116 ]]  !jvms: TestIntOr::test @ bci:22 (line 21)
 */
public class TestIntOr
{
    private static int test(int b, int a)
    {
        int i;
        for (i = -10; i < 1; i++)
        {
        }
        int c = a * i;
        return a | (b | c);
    }

//    private static int test2(int b, int a)
//    {
//        int i;
//        for (i = -10; i < 0; i++)
//        {
//        }
//        int c = a * i;
//        return a | (b | c);
//    }

//    private static int test(int b, int a)
//    {
//        int i;
//        for (i = -10; i < 0; i++)
//        {
//        }
//        // return 0 | (b | 0);
//        // int c = a * i;
//        // return c | (b | a);
//        int c = a & i;
//        return a | (b | c);
//    }

//    private static int test(int a, int b)
//    {
//        int i;
//        for (i = -10; i < 0; i++)
//        {
//        }
//        // return 0 | (b | 0);
//        int c = a * i;
//        return a | (b | c);
//    }

//    private static int test(int b, int a)
//    {
//        int i;
//        for (i = -10; i < 0; i++)
//        {
//        }
//        // return 0 | (b | 0);
//        int c = a * i;
//        return a | (b | c);
//    }

    public static void main(String[] args)
    {
        for (int i = 0; i < 20_000; i++)
        {
            test(42, 42);
        }
    }
}
