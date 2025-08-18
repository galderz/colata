class Test
{
    static value class MyValue
    {
        int x = 42;
        // int y = 42;
    }

    public static void testFill(MyValue[] array)
    {
        for (int i = 0; i < array.length; ++i)
        {
            array[i] = new MyValue();
        }
    }

    public static void testCopy(MyValue[] array1, MyValue[] array2)
    {
        for (int i = 0; i < array1.length; ++i)
        {
            array1[i] = array2[i];
        }
    }

    public static void main(String[] args)
    {
        MyValue[] array = new MyValue[100];
        for (int i = 0; i < 100_000; ++i)
        {
            testFill(array);
            testCopy(array, array);
        }
    }
}
