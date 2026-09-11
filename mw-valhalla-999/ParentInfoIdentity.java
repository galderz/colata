import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.Random;

class ParentInfoIdentity
{
    static final Random R = new Random(42);

    static class Init
    {
        List<ParentInfo> list = new ArrayList();
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
        for ( int i = 0; i < toLoad.size(); i++ ) {
            final var parentInfo = toLoad.get(i);
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

    private static class ParentInfo
    {
        private final Object parentInstance;
        private final short propertyIndex;

        public ParentInfo(Object parentInstance, int propertyIndex)
        {
            this.parentInstance = parentInstance;
            this.propertyIndex = (short) propertyIndex;
        }
    }
}
