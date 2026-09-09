import jdk.internal.value.ValueClass;
import jdk.internal.misc.Unsafe;

/**
 * Comprehensive test: allocation events for value classes in various array contexts.
 *
 * Value classes used:
 *   SmallVP    – 1 int  (4+1=5 → rounds to 8 ≤ MAX_ATOMIC_OP_SIZE → nullable flat OK)
 *   LargeVP    – 2 ints (8+1=9 → rounds to 16 > MAX_ATOMIC_OP_SIZE → nullable flat NOT OK)
 *
 * Array types:
 *   small[]             – new SmallVP[]         (nullable → flat via NULLABLE_ATOMIC_FLAT)
 *   large[]             – new LargeVP[]         (nullable → NOT flat, oop refs)
 *   largeNR[]           – newNullRestrictedAtomicArray(LargeVP) (null-free → flat via NULL_FREE_ATOMIC_FLAT)
 *
 * Scenarios:
 *   1  smallFlatWrite           – write into small[] (flat, nullable)
 *   2  smallFlatRead            – read from small[] (flat, nullable)
 *   3  largeFlatNRWrite         – write into largeNR[] (flat, null-restricted)
 *   4  largeFlatNRRead          – read from largeNR[] (flat, null-restricted)
 *   5  largeRegWrite            – write into large[] (NOT flat, oop refs)
 *   6  largeRegRead             – read from large[] (NOT flat, oop refs)
 *   7  flatWriteNoEscape        – write into largeNR[] where C2 scalarises (baseline)
 *   8  flatWriteEscaping        – write into largeNR[] where value escapes through a method call chain
 *   9  flatReadTyped            – read from largeNR[] into a non-volatile typed local
 *  10  boxedAllocations         – value → Object (always heap)
 *  11  identityBaseline         – identity class → Object (always heap)
 *
 * Compile:
 *   javac --enable-preview --source 28 \
 *     --add-exports java.base/jdk.internal.value=ALL-UNNAMED \
 *     --add-exports java.base/jdk.internal.misc=ALL-UNNAMED \
 *     FlatAllocReproducer.java
 *
 * Run:
 *   java --enable-preview \
 *     --add-opens java.base/jdk.internal.value=ALL-UNNAMED \
 *     --add-opens java.base/jdk.internal.misc=ALL-UNNAMED \
 *     FlatAllocReproducer
 */
public class FlatAllocReproducer {

    // ---- Small value class: nullable flat OK ----
    static value class SmallVP {
        int x;
        public SmallVP(int x) { this.x = x; }
    }

    // ---- Large value class: nullable flat NOT OK, null-free flat OK ----
    static value class LargeVP {
        int x; int y;
        public LargeVP(int x, int y) { this.x = x; this.y = y; }
    }

    // ---- Identity class (for comparison) ----
    static class IdentityPoint {
        final int x, y;
        IdentityPoint(int x, int y) { this.x = x; this.y = y; }
    }

    // ---- An intermediate container that prevents escape analysis ----
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
    static LargeVP typedSink;  // non-volatile, typed

    // ── Scenario 1: write into small[] (flat, nullable) ──
    static void smallFlatWrite(SmallVP[] arr, int count) {
        int len = arr.length;
        for (int i = 0; i < count; i++)
            arr[i % len] = new SmallVP(i);
    }

    // ── Scenario 2: read from small[] (flat, nullable) ──
    static void smallFlatRead(SmallVP[] arr, int count) {
        int len = arr.length;
        for (int i = 0; i < count; i++)
            sink = arr[i % len];
    }

    // ── Scenario 3: write into largeNR[] (flat, null-restricted) ──
    static void largeFlatNRWrite(LargeVP[] arr, int count) {
        int len = arr.length;
        for (int i = 0; i < count; i++)
            arr[i % len] = new LargeVP(i, i + 1);
    }

    // ── Scenario 4: read from largeNR[] (flat, null-restricted) ──
    static void largeFlatNRRead(LargeVP[] arr, int count) {
        int len = arr.length;
        for (int i = 0; i < count; i++)
            sink = arr[i % len];
    }

    // ── Scenario 5: write into large[] (NOT flat, oop refs) ──
    static void largeRegWrite(LargeVP[] arr, int count) {
        int len = arr.length;
        for (int i = 0; i < count; i++)
            arr[i % len] = new LargeVP(i, i + 1);
    }

    // ── Scenario 6: read from large[] (NOT flat, oop refs) ──
    static void largeRegRead(LargeVP[] arr, int count) {
        int len = arr.length;
        for (int i = 0; i < count; i++)
            sink = arr[i % len];
    }

    // ── Scenario 7: write into largeNR[] – simple, C2 can scalarise ──
    static void flatWriteNoEscape(LargeVP[] arr, int count) {
        int len = arr.length;
        for (int i = 0; i < count; i++)
            arr[i % len] = new LargeVP(i, i + 1);
    }

    // ── Scenario 8: write into largeNR[] – value escapes through method chain ──
    static void flatWriteEscaping(Container c, int count) {
        for (int i = 0; i < count; i++) {
            LargeVP v = createValue(i);        // allocated in a separate method
            processAndStore(c, v);             // passed through method chain
        }
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

    // ── Scenario 9: read from largeNR[] into non-volatile typed local ──
    static void flatReadTyped(LargeVP[] arr, int count) {
        int len = arr.length;
        for (int i = 0; i < count; i++)
            typedSink = arr[i % len];  // non-volatile, concrete type
    }

    // ── Scenario 10: value class → Object (always boxes) ──
    static void boxedAllocations(int count) {
        for (int i = 0; i < count; i++)
            sink = new LargeVP(i, i + 1);
    }

    // ── Scenario 11: identity class baseline ──
    static void identityBaseline(int count) {
        for (int i = 0; i < count; i++)
            sink = new IdentityPoint(i, i + 1);
    }

    public static void main(String[] args) throws Exception {
        final int N = 10_000_000;
        final int ARR_LEN = 1024;
        final Unsafe U = Unsafe.getUnsafe();

        // Create arrays
        SmallVP[] smallArr = new SmallVP[ARR_LEN];
        LargeVP[] largeNRArr = (LargeVP[]) ValueClass.newNullRestrictedAtomicArray(
                LargeVP.class, ARR_LEN, new LargeVP(0, 0));
        LargeVP[] largeRegArr = new LargeVP[ARR_LEN];
        Container container = new Container(
                (LargeVP[]) ValueClass.newNullRestrictedAtomicArray(
                        LargeVP.class, ARR_LEN, new LargeVP(0, 0)));

        // Report array properties
        System.out.println("====== Array properties ======");
        reportArray("smallArr   (new SmallVP[])                  ", smallArr, U);
        reportArray("largeNRArr (newNullRestrictedAtomicArray)    ", largeNRArr, U);
        reportArray("largeRegArr(new LargeVP[])                  ", largeRegArr, U);
        System.out.println();

        // Warm up
        smallFlatWrite(smallArr, 500_000);
        smallFlatRead(smallArr, 500_000);
        largeFlatNRWrite(largeNRArr, 500_000);
        largeFlatNRRead(largeNRArr, 500_000);
        largeRegWrite(largeRegArr, 500_000);
        largeRegRead(largeRegArr, 500_000);
        flatWriteNoEscape(largeNRArr, 500_000);
        flatWriteEscaping(container, 500_000);
        flatReadTyped(largeNRArr, 500_000);
        boxedAllocations(500_000);
        identityBaseline(500_000);
        Thread.sleep(500);

        // Populate arrays for reads
        for (int i = 0; i < ARR_LEN; i++) {
            smallArr[i] = new SmallVP(i);
            largeNRArr[i] = new LargeVP(i, i + 1);
            largeRegArr[i] = new LargeVP(i, i + 1);
        }

        // Steady state
        System.out.println("==== Steady-state start ====");

        System.out.println("[ 1/11] smallFlatWrite …");
        smallFlatWrite(smallArr, N);

        System.out.println("[ 2/11] smallFlatRead …");
        smallFlatRead(smallArr, N);

        System.out.println("[ 3/11] largeFlatNRWrite …");
        largeFlatNRWrite(largeNRArr, N);

        System.out.println("[ 4/11] largeFlatNRRead …");
        largeFlatNRRead(largeNRArr, N);

        System.out.println("[ 5/11] largeRegWrite …");
        largeRegWrite(largeRegArr, N);

        System.out.println("[ 6/11] largeRegRead …");
        largeRegRead(largeRegArr, N);

        System.out.println("[ 7/11] flatWriteNoEscape …");
        flatWriteNoEscape(largeNRArr, N);

        System.out.println("[ 8/11] flatWriteEscaping …");
        flatWriteEscaping(container, N);

        System.out.println("[ 9/11] flatReadTyped …");
        flatReadTyped(largeNRArr, N);

        System.out.println("[10/11] boxedAllocations …");
        boxedAllocations(N);

        System.out.println("[11/11] identityBaseline …");
        identityBaseline(N);

        System.out.println("==== Done ====");
    }

    static void reportArray(String label, Object arr, Unsafe U) {
        long shallow = U.getObjectSize(arr);
        int len = java.lang.reflect.Array.getLength(arr);
        boolean flat = ValueClass.isFlatArray((Object[]) arr);
        System.out.printf("  %s flat=%-5s  shallow=%,6d bytes  (%d bytes/elem)%n",
                label, flat, shallow, (shallow - 16) / len);
    }
}
