import jdk.internal.misc.Unsafe;
import java.util.Objects;

public class UnsafeGetByte
{
    private static final Unsafe UNSAFE = Unsafe.getUnsafe();
    private static final int BASE = (int) UNSAFE.arrayBaseOffset(byte[].class);

    public static void main(String[] args)
    {
        // Especially with a debug build, the JVM startup can take a while,
        // so it can take a while until our code is executed.
        System.out.println("Run");

        byte[] a = new byte[1024];
        byte[] b = new byte[1024];
        a[42] = 20;
        b[42] = 22;

        int offset = BASE + 42;

        // Repeatedly call the test method, so that it can become hot and
        // get JIT compiled.
        for (int i = 0; i < 10_000; i++)
        {
            test(a, b, offset);
        }
        System.out.println("Done");
    }

    // The test method we will focus on.
    public static int test(byte[] a, byte[] b, int offset)
    {
        int checkedOffset = Objects.checkIndex(offset, 1000);
        return UNSAFE.getByte(a, (long) checkedOffset) + UNSAFE.getByte(b, (long) checkedOffset);
    }
}
