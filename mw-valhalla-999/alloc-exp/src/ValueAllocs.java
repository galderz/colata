import java.lang.management.ManagementFactory;
import javax.management.ObjectName;

/**
 * Small scenarios that exercise java.lang.Integer allocation. Run each scenario
 * with and without --enable-preview (Integer becomes a value class under preview).
 *
 * Scenarios (first argument):
 *   fresh        Fresh boxes (values > 127) escape into an Object[].
 *                An Integer is allocated per iteration in BOTH modes; under preview C2
 *                scalarizes the box and materializes it at the escape point (aastore)
 *                instead of at the `new` in Integer.valueOf.        -> not an "extra" object
 *   cached-call  Cached boxes (0..63) pass through a non-inlined method `id(Integer)` and
 *                are stored into an Object[]. Without preview no Integer is ever allocated
 *                (IntegerCache). Under preview C2 passes/returns the value scalarized
 *                (fields in registers), so the caller has to materialize a NEW heap copy at
 *                the escape point.                                     -> "extra" objects
 *   flat-field   Cached boxes (0..63) are stored in an Integer field of a holder object and
 *                later read back and stored into an Object[]. Without preview the field
 *                holds a reference to the cached box. Under preview the field is flattened
 *                (payload inlined in the holder), so reading it back and letting it escape
 *                requires a NEW heap copy.                             -> "extra" objects
 *
 * Second argument: number of outer iterations (each inner loop is -Dinner=N iterations, default 1_000_000).
 * At exit, prints the exact number of instances of the classes of interest, taken from a
 * GC.class_histogram. Run with -XX:+UseEpsilonGC so that the histogram includes every
 * object ever allocated (Epsilon never reclaims memory). -Dhistogram=false skips it (the JMX machinery
 * behind it allocates a lot, which matters when every allocation is traced).
 */
public class ValueAllocs {
    static final int INNER = Integer.getInteger("inner", 1_000_000);
    static Object[] sink = new Object[1024];

    static final class Holder {
        Integer v;
    }

    static Holder[] holders = new Holder[1024];

    // ---- fresh ---------------------------------------------------------------------
    static Integer box(int i) {
        return Integer.valueOf(i);
    }

    static void fresh() {
        for (int i = 0; i < INNER; i++) {
            Integer v = box(i + 1000);
            sink[i & 1023] = v;
        }
    }

    // ---- cached-call ---------------------------------------------------------------
    // Run with -XX:CompileCommand=dontinline,ValueAllocs::id (the scripts do that)
    static Integer id(Integer x) {
        return x;
    }

    static void cachedCall() {
        for (int i = 0; i < INNER; i++) {
            sink[i & 1023] = id(Integer.valueOf(i & 63));
        }
    }

    // ---- flat-field ----------------------------------------------------------------
    static void flatFieldStore(int k) {
        for (int j = 0; j < holders.length; j++) {
            holders[j].v = Integer.valueOf((j + k) & 63);
        }
    }

    static void flatFieldLoad() {
        for (int i = 0; i < INNER; i++) {
            sink[i & 1023] = holders[i & 1023].v;
        }
    }

    static void flatField(int k) {
        flatFieldStore(k);
        flatFieldLoad();
    }

    public static void main(String[] args) throws Exception {
        String scenario = args.length > 0 ? args[0] : "fresh";
        int iters = args.length > 1 ? Integer.parseInt(args[1]) : 50;
        for (int j = 0; j < holders.length; j++) holders[j] = new Holder();

        for (int k = 0; k < iters; k++) {
            switch (scenario) {
                case "fresh" -> fresh();
                case "cached-call" -> cachedCall();
                case "flat-field" -> flatField(k);
                default -> throw new IllegalArgumentException(scenario);
            }
        }
        System.out.println("scenario=" + scenario + " iterations=" + iters + " x " + INNER
                + " Integer.isValue=" + Integer.class.isValue());
        if (Boolean.parseBoolean(System.getProperty("histogram", "true"))) printHistogram();
    }

    static void printHistogram() throws Exception {
        String histo = (String) ManagementFactory.getPlatformMBeanServer().invoke(
                new ObjectName("com.sun.management:type=DiagnosticCommand"),
                "gcClassHistogram",
                new Object[] { new String[] { "-all" } },
                new String[] { String[].class.getName() });
        for (String line : histo.split("\n")) {
            if (line.matches(".*\\s(java\\.lang\\.Integer|ValueAllocs\\$Holder)( \\(.*\\))?$")) {
                String[] f = line.trim().split("\\s+");
                System.out.printf("histogram: %-22s instances=%,d bytes=%,d%n", f[3], Long.parseLong(f[1]), Long.parseLong(f[2]));
            }
        }
    }
}
