import static java.lang.IO.*;

final class Test
{
    static final int ITER = 100_000;

    static MyValueEmpty test(EmptyContainer c1, MixedContainer c2, MyValueEmpty empty)
    {
        c2 = new MixedContainer(c2.val, c1);
        return c2.getNoInline().getNoInline();
    }

    public static void main(String[] args)
    {
        println("Warmup");
        for (int i = 0; i < ITER; i++)
        {
            MyValueEmpty empty = test(new EmptyContainer(new MyValueEmpty()), new MixedContainer(0, new EmptyContainer(new MyValueEmpty())), new MyValueEmpty());
            if (!empty.equals(new MyValueEmpty())) {
                throw new RuntimeException("Not equals");
            }
        }
    }

    static value class MixedContainer
    {
        public int val;
        private EmptyContainer empty;

        MixedContainer(int val, EmptyContainer empty)
        {
            this.val = val;
            this.empty = empty;
        }

        EmptyContainer getInline() {
            return empty;
        }

        EmptyContainer getNoInline() {
            return empty;
        }
    }

    static value class EmptyContainer {
        private MyValueEmpty empty;

        EmptyContainer(MyValueEmpty empty)
        {
            this.empty = empty;
        }

        MyValueEmpty getInline() { return empty; }

        MyValueEmpty getNoInline() { return empty; }
    }

    static value class MyValueEmpty {
        public long hash() { return 0; }

        public MyValueEmpty copy(MyValueEmpty other) { return other; }

        @Override
        public String toString() {
            return "MyValueEmpty[]";
        }
    }
}
