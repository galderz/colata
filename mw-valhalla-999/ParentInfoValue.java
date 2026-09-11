import java.util.Arrays;
import java.util.Random;

class ParentInfoValue
{
    static final Random R = new Random(42);

    static class Init
    {
        ParentInfoList list = new ParentInfoList();
    }

    static void main()
    {
        System.out.println("Run");
        for (int i = 0; i < 1_000_000; i++)
        {
            run();
        }
        System.out.println("Done");
    }

    static void run()
    {
        final Init init = new Init();
        testRegister(init);
        testRegister(init);
        testRegister(init);
        testEnd(init);
    }

    static void testRegister(Init init)
    {
        init.list.add(new ParentInfo(new Object(), R.nextInt()));
    }

    static void testEnd(Init init)
    {
        var toLoad = init.list;
        for ( int i = 0; i < toLoad.size; i++ ) {
            final var parentInfo = toLoad.elementData[i];
            final Object parentInstance = parentInfo.parentInstance;
            final var propertyIndex = parentInfo.propertyIndex;
            blackhole(parentInstance, propertyIndex);
        }
    }

    static void blackhole(Object obj, int i) {
        if (obj.hashCode() + i == System.nanoTime()) {
            System.out.println(obj + " " + i);
        }
    }

    private static value class ParentInfo
    {
        private final Object parentInstance;
        private final short propertyIndex;

        public ParentInfo(Object parentInstance, int propertyIndex)
        {
            this.parentInstance = parentInstance;
            this.propertyIndex = (short) propertyIndex;
        }
    }

    private static final class ParentInfoList
    {
        private static final int DEFAULT_CAPACITY = 10;

        private static final ParentInfo[] DEFAULTCAPACITY_EMPTY_ELEMENTDATA = {};

        private ParentInfo[] elementData;

        private int size;

        private int modCount = 0;

        ParentInfoList()
        {
            this.elementData = DEFAULTCAPACITY_EMPTY_ELEMENTDATA;
        }

        void add(ParentInfo e)
        {
            add(e, elementData, size);
        }

        void add(ParentInfo e, ParentInfo[] elementData, int s)
        {
            if (s == elementData.length)
                elementData = grow();
            elementData[s] = e;
            size = s + 1;
        }

        private ParentInfo[] grow()
        {
            return grow(size + 1);
        }

        private ParentInfo[] grow(int minCapacity)
        {
            int oldCapacity = elementData.length;
            if (oldCapacity > 0 || elementData != DEFAULTCAPACITY_EMPTY_ELEMENTDATA)
            {
                int newCapacity = newLength(oldCapacity,
                    minCapacity - oldCapacity, /* minimum growth */
                    oldCapacity >> 1           /* preferred growth */);
                return elementData = Arrays.copyOf(elementData, newCapacity);
            }
            else
            {
                return elementData = new ParentInfo[Math.max(DEFAULT_CAPACITY, minCapacity)];
            }
        }

        public static final int SOFT_MAX_ARRAY_LENGTH = Integer.MAX_VALUE - 8;

        public static int newLength(int oldLength, int minGrowth, int prefGrowth)
        {
            // preconditions not checked because of inlining
            // assert oldLength >= 0
            // assert minGrowth > 0

            int prefLength = oldLength + Math.max(minGrowth, prefGrowth); // might overflow
            if (0 < prefLength && prefLength <= SOFT_MAX_ARRAY_LENGTH)
            {
                return prefLength;
            }
            else
            {
                // put code cold in a separate method
                return hugeLength(oldLength, minGrowth);
            }
        }

        private static int hugeLength(int oldLength, int minGrowth)
        {
            int minLength = oldLength + minGrowth;
            if (minLength < 0)
            { // overflow
                throw new OutOfMemoryError(
                    "Required array length " + oldLength + " + " + minGrowth + " is too large");
            }
            else if (minLength <= SOFT_MAX_ARRAY_LENGTH)
            {
                return SOFT_MAX_ARRAY_LENGTH;
            }
            else
            {
                return minLength;
            }
        }
    }

}
