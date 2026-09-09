import jdk.internal.value.ValueClass;

/**
 * Run individual allocation scenarios in isolation for heap analysis.
 *
 * Usage: java ... HeapScenario <scenario-name> [iterations]
 *
 * Designed to run with Epsilon GC and -XX:+HeapDumpOnOutOfMemoryError
 * so the heap dump captures all objects without GC interference.
 * A manual heap dump is taken at end if no OOME occurs.
 *
 * Compile:
 *   javac --enable-preview --source 28 \
 *     --add-exports java.base/jdk.internal.value=ALL-UNNAMED \
 *     HeapScenario.java
 */
public class HeapScenario {

    static value class SmallVP {
        int x;
        public SmallVP(int x) { this.x = x; }
    }

    static value class LargeVP {
        int x; int y;
        public LargeVP(int x, int y) { this.x = x; this.y = y; }
    }

    static class IdentityPoint {
        final int x, y;
        IdentityPoint(int x, int y) { this.x = x; this.y = y; }
    }

    static class Container {
        LargeVP[] storage;
        int size;
        Container(LargeVP[] arr) { this.storage = arr; this.size = 0; }
        void add(LargeVP v) {
            storage[size % storage.length] = v;
            size++;
        }
    }

    static volatile Object sink;
    static LargeVP typedSink;

    static final int ARR_LEN = 1024;

    // ── Scenarios ────────────────────────────────────────────────────
    static void smallFlatWrite(int N) {
        SmallVP[] arr = new SmallVP[ARR_LEN];
        for (int i = 0; i < N; i++)
            arr[i % ARR_LEN] = new SmallVP(i);
        sink = arr;
    }

    static void smallFlatRead(int N) {
        SmallVP[] arr = new SmallVP[ARR_LEN];
        for (int i = 0; i < ARR_LEN; i++) arr[i] = new SmallVP(i);
        for (int i = 0; i < N; i++)
            sink = arr[i % ARR_LEN];
    }

    static void largeFlatNRWrite(int N) {
        LargeVP[] arr = (LargeVP[]) ValueClass.newNullRestrictedAtomicArray(
                LargeVP.class, ARR_LEN, new LargeVP(0, 0));
        for (int i = 0; i < N; i++)
            arr[i % ARR_LEN] = new LargeVP(i, i + 1);
        sink = arr;
    }

    static void largeFlatNRRead(int N) {
        LargeVP[] arr = (LargeVP[]) ValueClass.newNullRestrictedAtomicArray(
                LargeVP.class, ARR_LEN, new LargeVP(0, 0));
        for (int i = 0; i < ARR_LEN; i++) arr[i] = new LargeVP(i, i + 1);
        for (int i = 0; i < N; i++)
            sink = arr[i % ARR_LEN];
    }

    static void largeRegWrite(int N) {
        LargeVP[] arr = new LargeVP[ARR_LEN];
        for (int i = 0; i < N; i++)
            arr[i % ARR_LEN] = new LargeVP(i, i + 1);
        sink = arr;
    }

    static void largeRegRead(int N) {
        LargeVP[] arr = new LargeVP[ARR_LEN];
        for (int i = 0; i < ARR_LEN; i++) arr[i] = new LargeVP(i, i + 1);
        for (int i = 0; i < N; i++)
            sink = arr[i % ARR_LEN];
    }

    static void flatWriteNoEscape(int N) {
        LargeVP[] arr = (LargeVP[]) ValueClass.newNullRestrictedAtomicArray(
                LargeVP.class, ARR_LEN, new LargeVP(0, 0));
        for (int i = 0; i < N; i++)
            arr[i % ARR_LEN] = new LargeVP(i, i + 1);
        sink = arr;
    }

    static LargeVP createValue(int i) {
        return new LargeVP(i, i + 1);
    }
    static void processAndStore(Container c, LargeVP v) {
        doStore(c, v);
    }
    static void doStore(Container c, LargeVP v) {
        c.add(v);
    }

    static void flatWriteEscaping(int N) {
        LargeVP[] arr = (LargeVP[]) ValueClass.newNullRestrictedAtomicArray(
                LargeVP.class, ARR_LEN, new LargeVP(0, 0));
        Container c = new Container(arr);
        for (int i = 0; i < N; i++) {
            LargeVP v = createValue(i);
            processAndStore(c, v);
        }
        sink = arr;
    }

    static void flatReadTyped(int N) {
        LargeVP[] arr = (LargeVP[]) ValueClass.newNullRestrictedAtomicArray(
                LargeVP.class, ARR_LEN, new LargeVP(0, 0));
        for (int i = 0; i < ARR_LEN; i++) arr[i] = new LargeVP(i, i + 1);
        for (int i = 0; i < N; i++)
            typedSink = arr[i % ARR_LEN];
    }

    static void boxedAllocations(int N) {
        for (int i = 0; i < N; i++)
            sink = new LargeVP(i, i + 1);
    }

    static void identityBaseline(int N) {
        for (int i = 0; i < N; i++)
            sink = new IdentityPoint(i, i + 1);
    }

    // ─────────────────────────────────────────────────────────────────

    static void dumpHeap(String path) {
        try {
            // Use com.sun.management HotSpotDiagnosticMXBean
            var server = java.lang.management.ManagementFactory.getPlatformMBeanServer();
            var bean = java.lang.management.ManagementFactory.newPlatformMXBeanProxy(
                    server,
                    "com.sun.management:type=HotSpotDiagnostic",
                    com.sun.management.HotSpotDiagnosticMXBean.class);
            bean.dumpHeap(path, true);
        } catch (Exception e) {
            System.err.println("Failed to dump heap: " + e);
        }
    }

    public static void main(String[] args) {
        if (args.length < 1) {
            System.err.println("Usage: HeapScenario <scenario> [iterations] [heapdump-path]");
            System.exit(1);
        }
        String scenario = args[0];
        int N = args.length > 1 ? Integer.parseInt(args[1]) : 2_000_000;
        String dumpPath = args.length > 2 ? args[2] : null;

        System.out.println("Scenario: " + scenario + ", iterations: " + N);

        try {
            switch (scenario) {
                case "smallFlatWrite"    -> smallFlatWrite(N);
                case "smallFlatRead"     -> smallFlatRead(N);
                case "largeFlatNRWrite"  -> largeFlatNRWrite(N);
                case "largeFlatNRRead"   -> largeFlatNRRead(N);
                case "largeRegWrite"     -> largeRegWrite(N);
                case "largeRegRead"      -> largeRegRead(N);
                case "flatWriteNoEscape" -> flatWriteNoEscape(N);
                case "flatWriteEscaping" -> flatWriteEscaping(N);
                case "flatReadTyped"     -> flatReadTyped(N);
                case "boxedAllocations"  -> boxedAllocations(N);
                case "identityBaseline"  -> identityBaseline(N);
                default -> {
                    System.err.println("Unknown scenario: " + scenario);
                    System.exit(1);
                }
            }
        } catch (OutOfMemoryError e) {
            System.out.println("OOME hit");
            // HeapDumpOnOutOfMemoryError will handle the dump
            return;
        }

        // No OOME during the scenario itself.
        // Force an OOME with a big byte[] so HeapDumpOnOutOfMemoryError fires.
        // This ensures we get a heap dump showing everything that remains.
        System.out.println("Scenario completed, forcing OOME for heap dump …");
        try {
            // Allocate something huge to trigger OOME
            sink = new byte[Integer.MAX_VALUE];
        } catch (OutOfMemoryError e) {
            // HeapDumpOnOutOfMemoryError will capture the dump
            System.out.println("Forced OOME for heap dump");
        }
    }
}
