import java.util.Objects;

public class CheckIndex
{
    public static void main(String[] args)
    {
        // Especially with a debug build, the JVM startup can take a while,
        // so it can take a while until our code is executed.
        System.out.println("Run");
 
        byte[] a = new byte[1024];
        byte[] b = new byte[1024];
	int index = 42;
        a[index] = 20;
        b[index] = 22;

        // Repeatedly call the test method, so that it can become hot and
        // get JIT compiled.
        for (int i = 0; i < 10_000; i++)
        {
            test(a, b, index);
        }
        System.out.println("Done");
    }

    static int test(byte[] a, byte[] b, int index) {
	int checked = Objects.checkIndex(index, 1000);
        // i = Integer.min(Integer.max(i, 0), 1000);
        // return a[i] + b[i + 1];
	return a[checked] + b[checked];
    }
}
