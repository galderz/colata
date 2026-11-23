import java.io.IOException;
import java.io.InputStream;
import java.lang.classfile.Attributes;
import java.lang.classfile.ClassFile;
import java.lang.classfile.ClassModel;
import java.lang.classfile.MethodModel;
import java.lang.classfile.Opcode;
import java.lang.classfile.attribute.CodeAttribute;
import java.net.URI;
import java.nio.file.FileSystem;
import java.nio.file.FileSystems;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.*;
import java.util.jar.JarFile;
import java.util.stream.Collectors;
import jdk.jfr.consumer.RecordedEvent;
import jdk.jfr.consumer.RecordedFrame;
import jdk.jfr.consumer.RecordedMethod;
import jdk.jfr.consumer.RecordingFile;

/**
 * Classifies Java heap allocations recorded in a JFR file (JDK JFR or async-profiler JFR output),
 * with a focus on value objects (JEP 401) materialized by C2-compiled code.
 *
 * Usage:
 *   java tools/AllocAnalyzer.java [options] <recording.jfr>
 *
 * Options:
 *   --cp <path[:path]>     where to find application classes (to decode bytecodes)
 *   --preview | --no-preview
 *                          whether the recorded JVM ran with --enable-preview. Selects the preview
 *                          variants of JDK classes (META-INF/preview), e.g. value class Integer.
 *                          Auto-detected from jdk.JVMInformation when present (JDK JFR only).
 *   --jit-is-c2            treat "JIT compiled" frames as C2. Implied when the recording has
 *                          C1-labelled frames (async-profiler cstack=vmx) or when the JVM ran with
 *                          -XX:-TieredCompilation (detected from jdk.JVMInformation).
 *   --baseline <file.jfr>  identity (non-preview) recording of the same workload. Prints, per
 *                          allocated class and C2 compilation unit, how much more is allocated
 *                          in the analyzed recording: allocations that did not exist without
 *                          value classes.
 *   --top <n>              number of stacks to print (default 8)
 *   --all                  print top stacks for every category, not only C2
 *   --class <substring>    only consider allocated classes containing <substring>
 *   --depth <n>            max Java frames per printed stack (default 10)
 *   --native               print all native frames above the Java code (default: only the
 *                          runtime entry points)
 */
public class AllocAnalyzer {

    // ------------------------------------------------------------------ options
    static Boolean preview;          // null = auto
    static Boolean jitIsC2;          // null = auto
    static int top = 8, depth = 10;
    static boolean all, showNative;
    static String classFilter;
    static Path baseline;
    static final List<Path> classPath = new ArrayList<>();

    public static void main(String[] args) throws Exception {
        Path file = null;
        for (int i = 0; i < args.length; i++) {
            switch (args[i]) {
                case "--cp" -> Arrays.stream(args[++i].split(":")).map(Path::of).forEach(classPath::add);
                case "--preview" -> preview = true;
                case "--no-preview" -> preview = false;
                case "--jit-is-c2" -> jitIsC2 = true;
                case "--baseline" -> baseline = Path.of(args[++i]);
                case "--top" -> top = Integer.parseInt(args[++i]);
                case "--depth" -> depth = Integer.parseInt(args[++i]);
                case "--all" -> all = true;
                case "--native" -> showNative = true;
                case "--class" -> classFilter = args[++i];
                case "-h", "--help" -> { usage(); return; }
                default -> {
                    if (args[i].startsWith("-")) { usage(); System.exit(1); }
                    file = Path.of(args[i]);
                }
            }
        }
        if (file == null) { usage(); System.exit(1); }

        Recording rec = Recording.load(file, preview, jitIsC2);
        rec.printReport();
        if (baseline != null) {
            Recording base = Recording.load(baseline, false, jitIsC2);
            printComparison(base, rec);
        }
    }

    static void usage() {
        System.out.println("usage: java AllocAnalyzer.java [--cp path] [--preview|--no-preview] [--jit-is-c2]"
                + " [--baseline identity.jfr] [--top n] [--all] [--class s] [--depth n] [--native] recording.jfr");
    }

    // ------------------------------------------------------------------ model
    enum Tier { C2, C1, JIT, INTERPRETER, NATIVE_METHOD, NONE }

    /** One frame, normalized across JDK JFR and async-profiler JFR. */
    record Frame(String kind, String lib, String clazz, String method, String descriptor,
                 int bci, int line, boolean java) {
        String javaName() { return simpleClass(clazz) + "." + method + "(" + params(descriptor) + ")"; }
    }

    /** One allocation event. */
    record Alloc(String objClass, List<Frame> frames, long weight) {}

    /** Classification result of one allocation (all fields used for grouping). */
    record Site(String objClass, boolean valueClass, String category, Tier tier, String runtimePath,
                String opcode, String compileUnit, List<Frame> javaFrames, List<Frame> nativeFrames) {}

    static final class Stat { long events, weight; void add(long w) { events++; weight += w; } }

    // ------------------------------------------------------------------ recording
    static final class Recording {
        final Path file;
        final boolean previewMode, c2Mode;
        final String source;
        final String eventsUsed;
        final ClassInfo classes;
        long total, events;
        // aggregates
        final Map<String, Stat> byCat = new TreeMap<>();
        final Map<String, Stat> byCatClass = new LinkedHashMap<>();
        final Map<Site, Stat> bySite = new HashMap<>();
        final Map<String, Stat> c2ByClassAndUnit = new HashMap<>();

        Recording(Path file, boolean previewMode, boolean c2Mode, String source, String eventsUsed) {
            this.file = file; this.previewMode = previewMode; this.c2Mode = c2Mode;
            this.source = source; this.eventsUsed = eventsUsed;
            this.classes = new ClassInfo(previewMode);
        }

        static Recording load(Path file, Boolean previewOpt, Boolean jitOpt) throws IOException {
            // Pass 1: recording properties
            String jvmArgs = null;
            boolean hasSample = false, hasC1Frames = false, hasNativeFrames = false;
            try (RecordingFile rf = new RecordingFile(file)) {
                while (rf.hasMoreEvents()) {
                    RecordedEvent e = rf.readEvent();
                    String n = e.getEventType().getName();
                    if (n.equals("jdk.JVMInformation")) jvmArgs = e.getString("jvmArguments");
                    else if (n.equals("jdk.ObjectAllocationSample")) hasSample = true;
                    if (!hasNativeFrames && n.startsWith("jdk.ObjectAllocation") && e.getStackTrace() != null) {
                        for (RecordedFrame f : e.getStackTrace().getFrames()) {
                            String t = f.getType();
                            if ("C1 compiled".equals(t)) hasC1Frames = true;
                            if ("C++".equals(t) || "Kernel".equals(t)) hasNativeFrames = true;
                        }
                    }
                }
            }
            boolean pv = previewOpt != null ? previewOpt : jvmArgs != null && jvmArgs.contains("--enable-preview");
            boolean c2 = jitOpt != null ? jitOpt
                    : hasC1Frames || hasNativeFrames // async-profiler vmx labels C1 frames explicitly
                      || (jvmArgs != null && jvmArgs.contains("-XX:-TieredCompilation"));
            String source = hasNativeFrames ? "async-profiler (mixed stacks)" : "JDK JFR";
            String used = hasSample ? "jdk.ObjectAllocationSample"
                    : "jdk.ObjectAllocationInNewTLAB + jdk.ObjectAllocationOutsideTLAB";
            if (previewOpt == null && jvmArgs == null)
                System.err.println("warning: " + file + ": cannot detect --enable-preview, assuming "
                        + (pv ? "preview" : "no preview") + " (use --preview / --no-preview)");
            Recording r = new Recording(file, pv, c2, source, used);

            // Pass 2: classify and aggregate
            try (RecordingFile rf = new RecordingFile(file)) {
                while (rf.hasMoreEvents()) {
                    RecordedEvent e = rf.readEvent();
                    long w;
                    switch (e.getEventType().getName()) {
                        // JDK JFR: weight = bytes this sample stands for
                        case "jdk.ObjectAllocationSample" -> w = e.getLong("weight");
                        // async-profiler: tlabSize = sampling interval in bytes; JDK: size of the new TLAB
                        case "jdk.ObjectAllocationInNewTLAB" -> { if (hasSample) continue; w = e.getLong("tlabSize"); }
                        // one event per allocation (e.g. with -XX:-UseTLAB)
                        case "jdk.ObjectAllocationOutsideTLAB" -> { if (hasSample) continue; w = e.getLong("allocationSize"); }
                        default -> { continue; }
                    }
                    if (e.getStackTrace() == null) continue;
                    String cls = e.getClass("objectClass").getName();
                    if (classFilter != null && !cls.contains(classFilter)) continue;
                    List<Frame> frames = new ArrayList<>();
                    for (RecordedFrame f : e.getStackTrace().getFrames()) frames.add(toFrame(f));
                    r.add(r.classify(new Alloc(cls, frames, w)), w);
                }
            }
            return r;
        }

        void add(Site s, long w) {
            total += w; events++;
            byCat.computeIfAbsent(s.category, k -> new Stat()).add(w);
            byCatClass.computeIfAbsent(s.category + "\u0000" + s.objClass, k -> new Stat()).add(w);
            if (all || s.tier == Tier.C2 || s.tier == Tier.JIT) bySite.computeIfAbsent(trim(s), k -> new Stat()).add(w);
            if (s.tier == Tier.C2 || s.tier == Tier.JIT)
                c2ByClassAndUnit.computeIfAbsent(s.objClass + "\u0000" + s.compileUnit, k -> new Stat()).add(w);
        }

        static Frame toFrame(RecordedFrame f) {
            RecordedMethod m = f.getMethod();
            String type = f.getType() == null ? "?" : f.getType();
            String clazz = m.getType() == null ? "" : m.getType().getName();
            boolean java = switch (type) {
                case "Interpreted", "JIT compiled", "Inlined", "C1 compiled" -> true;
                default -> false;   // Native, C++, Kernel
            };
            // "Native": JDK JFR = Java native method (real class name);
            // async-profiler = C function (class = library name such as "libjvm.so", or "" for stubs)
            if (type.equals("Native") && !clazz.isEmpty() && !clazz.contains(".so")) java = true;
            String lib = java ? null : clazz;
            return new Frame(type, lib, clazz, m.getName(), m.getDescriptor(),
                    f.getBytecodeIndex(), f.getLineNumber(), java);
        }

        // ---------------------------------------------------------- classification
        Site classify(Alloc a) {
            List<Frame> fs = a.frames;
            int topJava = -1;
            for (int i = 0; i < fs.size(); i++) if (fs.get(i).java) { topJava = i; break; }
            boolean value = classes.isValueClass(a.objClass);
            if (topJava < 0) {
                return new Site(a.objClass, value, "VM internal (no Java frame)", Tier.NONE, "", "", "",
                        List.of(), nativeAbove(fs, fs.size()));
            }
            List<Frame> javaFrames = fs.subList(topJava, fs.size()).stream().filter(Frame::java).toList();
            List<Frame> natives = nativeAbove(fs, topJava);
            String path = runtimePath(fs, topJava);

            // Tier of the allocating code = tier of the nmethod containing the top Java frame:
            // skip "Inlined" frames down to the compilation root.
            int root = topJava;
            while (root < fs.size() - 1 && fs.get(root).kind.equals("Inlined") && fs.get(root + 1).java) root++;
            Frame rootFrame = fs.get(root);
            Tier tier = switch (rootFrame.kind) {
                case "Interpreted" -> Tier.INTERPRETER;
                case "C1 compiled" -> Tier.C1;
                case "JIT compiled", "Inlined" -> c2Mode ? Tier.C2 : Tier.JIT;
                default -> Tier.NATIVE_METHOD;
            };
            Frame topFrame = fs.get(topJava);
            String op = classes.opcodeAt(topFrame.clazz, topFrame.method, topFrame.descriptor, topFrame.bci);
            String unit = rootFrame.javaName();

            String category;
            boolean deopt = natives.stream().anyMatch(f -> f.method.startsWith("Deoptimization::"));
            switch (tier) {
                case INTERPRETER -> category = "Interpreter (ignored)";
                case C1 -> category = "C1 (ignored)";
                case NATIVE_METHOD -> category = "Native method";
                default -> {
                    String t = tier == Tier.C2 ? "C2" : "JIT(C1|C2)";
                    if (deopt) category = t + " value object: rematerialized on deoptimization";
                    else if (!value) category = t + " identity object";
                    else if (op.equals("new")) category = t + " value object: allocated at `new`";
                    else category = t + " value object: MATERIALIZED at `" + op + "`";
                }
            }
            return new Site(a.objClass, value, category, tier, path, op, unit, javaFrames, natives);
        }

        /** Native frames between the allocation and the top Java frame (allocator internals dropped). */
        static List<Frame> nativeAbove(List<Frame> fs, int topJava) {
            List<Frame> r = new ArrayList<>();
            for (int i = 0; i < topJava; i++) {
                Frame f = fs.get(i);
                if ("libasyncProfiler.so".equals(f.lib)) continue;
                r.add(f);
            }
            return r;
        }

        /** "stub -> runtime entry" just above the top Java frame, e.g. "new_instance_blob (C2 runtime) -> OptoRuntime::new_instance_C". */
        static String runtimePath(List<Frame> fs, int topJava) {
            if (topJava == 0) return "";
            List<String> p = new ArrayList<>();
            for (int i = topJava - 1; i >= 0 && p.size() < 2; i--) {
                Frame f = fs.get(i);
                if ("libasyncProfiler.so".equals(f.lib)) break;
                p.add(f.method);
            }
            return String.join(" -> ", p);
        }

        // ---------------------------------------------------------- report
        void printReport() {
            System.out.println("=".repeat(100));
            System.out.println("Recording : " + file);
            System.out.println("Source    : " + source + ", events: " + eventsUsed + " (" + events + " events)");
            System.out.println("Mode      : " + (previewMode ? "--enable-preview (value classes)" : "identity (no preview)")
                    + ", JIT frames: " + (c2Mode ? "C2 (C1 distinguishable or disabled)" : "C1 or C2 (not distinguishable)"));
            System.out.println("Weight    : estimated bytes allocated (sum of event weights) = " + mb(total));
            System.out.println();

            System.out.println("Allocations by category");
            System.out.printf("  %-58s %10s %12s %7s%n", "category", "events", "est. bytes", "share");
            byCat.entrySet().stream().sorted((a, b) -> Long.compare(b.getValue().weight, a.getValue().weight)).forEach(e ->
                    System.out.printf("  %-58s %10d %12s %6.1f%%%n", e.getKey(), e.getValue().events,
                            mb(e.getValue().weight), pct(e.getValue().weight, total)));
            System.out.println();

            // ---- value classes in compiled code, per class
            System.out.println("Value-class allocations in JIT-compiled code, by class and category");
            System.out.printf("  %-36s %-50s %10s %12s%n", "class", "category", "events", "est. bytes");
            byCatClass.entrySet().stream()
                    .filter(e -> e.getKey().contains(" value object"))
                    .sorted((a, b) -> Long.compare(b.getValue().weight, a.getValue().weight))
                    .forEach(e -> {
                        String[] k = e.getKey().split("\u0000");
                        System.out.printf("  %-36s %-50s %10d %12s%n", k[1], k[0], e.getValue().events, mb(e.getValue().weight));
                    });
            System.out.println();

            // ---- top stacks
            System.out.println("Top " + top + " allocation stacks" + (all ? "" : " in JIT-compiled code (interpreter/C1 hidden, use --all)")
                    + "; '>' marks the allocating frame");
            List<Map.Entry<Site, Stat>> sorted = bySite.entrySet().stream()
                    .sorted((a, b) -> Long.compare(b.getValue().weight, a.getValue().weight)).limit(top).toList();
            int n = 0;
            for (Map.Entry<Site, Stat> e : sorted) {
                Site s = e.getKey(); Stat st = e.getValue();
                System.out.println();
                System.out.printf("#%d  %.1f%% of all  events=%d  est.bytes=%s%n", ++n, pct(st.weight, total), st.events, mb(st.weight));
                System.out.println("    class     : " + s.objClass + (s.valueClass ? "  [value class]" : "  [identity class]"));
                System.out.println("    category  : " + s.category);
                System.out.println("    runtime   : " + (s.runtimePath.isEmpty() ? "n/a (recording has Java frames only)" : s.runtimePath));
                System.out.println("    comp.unit : " + s.compileUnit + "  [" + s.tier + "]");
                System.out.println("    stack     :");
                List<Frame> nat = s.nativeFrames;
                if (!showNative && nat.size() > 2) {
                    System.out.println("        ... " + (nat.size() - 2) + " allocator frames (use --native)");
                    nat = nat.subList(nat.size() - 2, nat.size());
                }
                for (Frame f : nat)
                    System.out.printf("        %-14s %s%s%n", "[" + f.kind + "]", f.lib == null || f.lib.isEmpty() ? "" : f.lib + "`", f.method);
                boolean first = true;
                int shown = 0;
                for (Frame f : s.javaFrames) {
                    if (shown++ == depth) { System.out.println("        ... " + (s.javaFrames.size() - depth) + " more"); break; }
                    String op = classes.opcodeAt(f.clazz, f.method, f.descriptor, f.bci);
                    System.out.printf("      %s %-14s %-48s bci=%-4d line=%-4d %s%n", first ? ">" : " ",
                            "[" + f.kind + "]", f.javaName(), f.bci, f.line, op);
                    first = false;
                }
            }
            System.out.println();
        }

        /** Grouping key: truncate the stack so that identical sites merge. */
        Site trim(Site s) {
            List<Frame> jf = s.javaFrames.size() > depth ? s.javaFrames.subList(0, depth) : s.javaFrames;
            return new Site(s.objClass, s.valueClass, s.category, s.tier, s.runtimePath, s.opcode, s.compileUnit,
                    List.copyOf(jf), List.copyOf(s.nativeFrames));
        }

    }

    static void printComparison(Recording base, Recording cur) {
        System.out.println("=".repeat(100));
        System.out.println("Extra allocations vs identity baseline " + base.file);
        System.out.println("  JIT-compiled allocations per (class, compilation unit); classes that are value classes in the");
        System.out.println("  analyzed run only. 'extra' = analyzed - baseline: objects that only exist because the class is a");
        System.out.println("  value class (e.g. a scalarized value that had to be re-materialized as a heap object).");
        Map<String, Stat> b = base.c2ByClassAndUnit, c = cur.c2ByClassAndUnit;
        Set<String> keys = new TreeSet<>(); keys.addAll(b.keySet()); keys.addAll(c.keySet());
        System.out.println("  (events = number of sampled allocations; with -XX:-UseTLAB recordings, events = objects)");
        System.out.printf("  %-20s %-34s %11s %11s %11s %11s %11s %11s%n", "class", "compilation unit",
                "base.events", "events", "extra.ev", "base.bytes", "bytes", "extra.bytes");
        keys.stream()
                .filter(k -> cur.classes.isValueClass(k.split("\u0000")[0]))
                .sorted(Comparator.comparingLong((String k) -> -(w(c, k) - w(b, k))))
                .limit(20)
                .forEach(k -> {
                    String[] p = k.split("\u0000");
                    long d = w(c, k) - w(b, k);
                    long de = ev(c, k) - ev(b, k);
                    System.out.printf("  %-20s %-34s %11d %11d %11s %11s %11s %11s%n", p[0], p[1], ev(b, k), ev(c, k),
                            (de >= 0 ? "+" : "") + de, mb(w(b, k)), mb(w(c, k)), (d >= 0 ? "+" : "") + mb(d));
                });
        System.out.println();
    }

    static long w(Map<String, Stat> m, String k) { Stat s = m.get(k); return s == null ? 0 : s.weight; }
    static long ev(Map<String, Stat> m, String k) { Stat s = m.get(k); return s == null ? 0 : s.events; }

    // ------------------------------------------------------------------ class file access
    /** Reads class files of the analyzed JDK (jrt:/, preview-aware) and of --cp entries. */
    static final class ClassInfo {
        final boolean preview;
        final Map<String, Optional<ClassModel>> cache = new HashMap<>();
        final Map<String, String> opcodeCache = new HashMap<>();
        static final String[] OPCODES = new String[256];
        FileSystem jrt;
        List<Path> modules;

        static {
            for (Opcode op : Opcode.values())
                if (op.bytecode() < 256 && OPCODES[op.bytecode()] == null) OPCODES[op.bytecode()] = op.name().toLowerCase();
        }

        ClassInfo(boolean preview) { this.preview = preview; }

        Optional<ClassModel> model(String className) {
            return cache.computeIfAbsent(className, this::load);
        }

        Optional<ClassModel> load(String className) {
            if (className.contains("[") || className.contains("/0x") || className.contains("$$Lambda")) return Optional.empty();
            String res = className.replace('.', '/') + ".class";
            try {
                byte[] bytes = readJdk(res);
                if (bytes == null) bytes = readClassPath(res);
                return bytes == null ? Optional.empty() : Optional.of(ClassFile.of().parse(bytes));
            } catch (Exception e) {
                return Optional.empty();
            }
        }

        byte[] readJdk(String res) throws IOException {
            if (jrt == null) {
                // previewMode=true overlays the preview variants (META-INF/preview) of JDK classes,
                // e.g. java/lang/Integer.class becomes the value class.
                jrt = FileSystems.newFileSystem(URI.create("jrt:/"), Map.of("previewMode", String.valueOf(preview)));
                try (var s = Files.list(jrt.getPath("/modules"))) { modules = s.toList(); }
            }
            for (Path m : modules) {
                Path p = m.resolve(res);
                if (Files.exists(p)) return Files.readAllBytes(p);
            }
            return null;
        }

        byte[] readClassPath(String res) throws IOException {
            for (Path cp : classPath) {
                if (Files.isDirectory(cp)) {
                    Path p = cp.resolve(res);
                    if (Files.exists(p)) return Files.readAllBytes(p);
                } else if (Files.exists(cp)) {
                    try (JarFile jar = new JarFile(cp.toFile())) {
                        var e = jar.getJarEntry(res);
                        if (e != null) try (InputStream in = jar.getInputStream(e)) { return in.readAllBytes(); }
                    }
                }
            }
            return null;
        }

        /** Value class = preview class file (minor 0xFFFF) without ACC_IDENTITY (0x0020), not an interface. */
        boolean isValueClass(String className) {
            return model(className).map(cm -> {
                int flags = cm.flags().flagsMask();
                return cm.minorVersion() == 0xFFFF && (flags & 0x0020) == 0 && (flags & ClassFile.ACC_INTERFACE) == 0;
            }).orElse(false);
        }

        String opcodeAt(String className, String method, String descriptor, int bci) {
            if (bci < 0) return "";
            String key = className + "." + method + descriptor + "@" + bci;
            return opcodeCache.computeIfAbsent(key, k -> model(className).flatMap(cm -> {
                for (MethodModel mm : cm.methods()) {
                    if (mm.methodName().equalsString(method) && mm.methodType().equalsString(descriptor)) {
                        return mm.findAttribute(Attributes.code()).map(code -> {
                            byte[] b = ((CodeAttribute) code).codeArray();
                            return bci < b.length ? OPCODES[b[bci] & 0xff] : "?";
                        });
                    }
                }
                return Optional.empty();
            }).orElse("?"));
        }
    }

    // ------------------------------------------------------------------ formatting
    static String simpleClass(String c) {
        if (c == null) return "";
        return c.replace('/', '.');
    }

    static String params(String desc) {
        if (desc == null || !desc.startsWith("(")) return "";
        List<String> out = new ArrayList<>();
        int i = 1;
        while (desc.charAt(i) != ')') {
            int dims = 0;
            while (desc.charAt(i) == '[') { dims++; i++; }
            String t;
            char ch = desc.charAt(i);
            if (ch == 'L') {
                int end = desc.indexOf(';', i);
                String full = desc.substring(i + 1, end);
                t = full.substring(full.lastIndexOf('/') + 1);
                i = end + 1;
            } else {
                t = switch (ch) {
                    case 'I' -> "int"; case 'J' -> "long"; case 'Z' -> "boolean"; case 'B' -> "byte";
                    case 'C' -> "char"; case 'S' -> "short"; case 'F' -> "float"; case 'D' -> "double";
                    default -> String.valueOf(ch);
                };
                i++;
            }
            out.add(t + "[]".repeat(dims));
        }
        return String.join(", ", out);
    }

    static String mb(long bytes) {
        double a = Math.abs(bytes);
        if (a >= 1 << 20) return String.format("%.1f MB", bytes / (double) (1 << 20));
        if (a >= 1 << 10) return String.format("%.1f KB", bytes / 1024.0);
        return bytes + " B";
    }

    static double pct(long part, long total) { return total == 0 ? 0 : 100.0 * part / total; }
}
