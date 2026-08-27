import jdk.internal.misc.Unsafe;
import java.util.Objects;

public class UnsafeDiffOffset
{
    private static final Unsafe UNSAFE = Unsafe.getUnsafe();
    private static final int BASE = (int) UNSAFE.arrayBaseOffset(byte[].class);

    public static void main(String[] args)
    {
        // Especially with a debug build, the JVM startup can take a while,
        // so it can take a while until our code is executed.
        System.out.println("Run");

        byte[] b = new byte[1024];
	int index = 42;
        b[index] = 22;

        // Repeatedly call the test method, so that it can become hot and
        // get JIT compiled.
        for (int i = 0; i < 10_000; i++)
        {
            test(b, index);
        }
        System.out.println("Done");
    }

    static int test(byte[] b, int i) {
        i = Integer.min(Integer.max(i, 0), 1000);
	return UNSAFE.getByte(b, (long) i) + UNSAFE.getByte(b, (long) i + 1);
        // return b[i] + b[i + 1];
    }
}
