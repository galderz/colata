/**
 * Reproducer: async-profiler alloc event does not capture value class allocations.
 *
 * This program allocates both regular (identity) classes and value classes in
 * tight loops.  When profiled with  asprof -e alloc  we expect to see both
 * kinds of allocations in the flame graph / summary.  Value-class allocations
 * are missing.
 *
 * Compile:  javac --enable-preview --source 28 AllocReproducer.java
 * Run:      java  --enable-preview AllocReproducer
 */
public class AllocReproducer {

    // ---- identity (regular) class ----
    static class IdentityPoint {
        final int x, y;
        IdentityPoint(int x, int y) { this.x = x; this.y = y; }
        @Override public String toString() { return "I(" + x + "," + y + ")"; }
    }

    // ---- value class (JEP 401) ----
    static value class ValuePoint {
        int x;
        int y;
        public ValuePoint(int x, int y) { this.x = x; this.y = y; }
        @Override public String toString() { return "V(" + x + "," + y + ")"; }
    }

    // Prevent dead-code elimination
    static volatile Object sink;

    /**
     * Allocate identity-class instances in a loop.
     * Should appear in alloc profile.
     */
    static void allocateIdentity(int count) {
        for (int i = 0; i < count; i++) {
            sink = new IdentityPoint(i, i + 1);
        }
    }

    /**
     * Allocate value-class instances in a loop.
     * Should appear in alloc profile but currently does NOT with async-profiler.
     */
    static void allocateValue(int count) {
        for (int i = 0; i < count; i++) {
            sink = new ValuePoint(i, i + 1);
        }
    }

    public static void main(String[] args) throws Exception {
        final int ITERATIONS = 50_000_000;

        System.out.println("Starting allocation reproducer …");
        System.out.println("  Identity class: " + IdentityPoint.class);
        System.out.println("  Value    class: " + ValuePoint.class);
        System.out.println("  Iterations per round: " + ITERATIONS);
        System.out.println();

        // Warm up
        allocateIdentity(1_000_000);
        allocateValue(1_000_000);

        // Steady-state – profile this part
        for (int round = 0; round < 5; round++) {
            System.out.println("Round " + round);
            allocateIdentity(ITERATIONS);
            allocateValue(ITERATIONS);
        }

        System.out.println("Done.");
    }
}
