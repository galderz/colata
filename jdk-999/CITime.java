public class CITime {
    public static void main(String[] args)
    {
        // Especially with a debug build, the JVM startup can take a while,
        // so it can take a while until our code is executed.
        System.out.println("Run");

        // Repeatedly call the test method, so that it can become hot and
        // get JIT compiled.
        int[] array = new int[10_000];
        for (int i = 0; i < 10_000; i++)
        {
            test(array);
        }
        System.out.println("Done");
    }

    public static void test(int[] array)
    {
        // Add 42 to every element in the array: load, add, store
        for (int i = 0; i < array.length; i++)
        {
            array[i] += 42;
        }
    }
}