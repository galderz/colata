# Value Class Flat Array Allocation Profiling

## Overview

When profiling value class allocations, the interaction between array flattening and allocation events is counter-intuitive. This document presents a comprehensive investigation covering:

- When `new ValueClass[N]` is flat vs not flat (it depends on the size of the value class)
- Why flat and non-flat arrays show **opposite allocation patterns** for reads vs writes
- How C2 escape analysis eliminates allocations in flat write paths
- Whether crossing method boundaries defeats scalarisation
- How reading into a typed non-volatile field differs from a volatile `Object` sink

```
    ┌─────────────────┬───────────────────┬──────────────────┐
    │                 │ FLAT array        │ NON-FLAT array   │
    ├─────────────────┼───────────────────┼──────────────────┤
    │ Write (aastore) │ Few/no allocs     │ Allocs (new+oop) │
    │                 │ (scalarised→flat) │                  │
    ├─────────────────┼───────────────────┼──────────────────┤
    │ Read (aaload)   │ ALLOCS (buffering)│ No allocs        │
    │                 │ (flat→heap copy)  │ (returns oop)    │
    └─────────────────┴───────────────────┴──────────────────┘
```

## Critical: `--enable-preview` changes flag defaults

**All flattening flags default to `true` ONLY when `--enable-preview` is passed.** Without it, `UseArrayFlattening` and all sub-flags are `false`.

```bash
# Without --enable-preview: all false
java -XX:+UnlockDiagnosticVMOptions -XX:+PrintFlagsFinal -version 2>&1 | grep UseArrayFlattening
#   UseArrayFlattening = false

# With --enable-preview: all true
java --enable-preview -XX:+UnlockDiagnosticVMOptions -XX:+PrintFlagsFinal -version 2>&1 | grep UseArrayFlattening
#   UseArrayFlattening = true
```

Always check flag values with `--enable-preview`.

## When is `new ValueClass[N]` flat?

A regular `new ValueClass[N]` creates a **nullable** array. Whether it is flat depends on whether the value class has a `NULLABLE_ATOMIC_FLAT` layout, which requires:

```
round_up_power_of_2(payload_bytes + null_marker_byte) ≤ MAX_ATOMIC_OP_SIZE (8 bytes on aarch64)
```

| Value class | Payload | +null marker | Rounded | ≤ 8? | `new VC[N]` flat? |
|---|---|---|---|---|---|
| `SmallVP { int x }` | 4 bytes | 5 bytes | 8 | ✅ | YES (`NULLABLE_ATOMIC_FLAT: 8/8`) |
| `LargeVP { int x, y }` | 8 bytes | 9 bytes | 16 | ❌ | NO (`NULLABLE_ATOMIC_FLAT: -/-`) |
| `TinyVP { short x, byte y }` | 3 bytes | 4 bytes | 4 | ✅ | YES (`NULLABLE_ATOMIC_FLAT: 4/4`) |

For value classes too large for nullable flat, a **null-restricted** array is needed for flattening:

```java
import jdk.internal.value.ValueClass;
LargeVP[] flat = (LargeVP[]) ValueClass.newNullRestrictedAtomicArray(
        LargeVP.class, N, new LargeVP(0, 0));
// ValueClass.isFlatArray(flat) == true
```

This is consistent with JEP 401 — the spec allows flattening of nullable arrays, but the JVM can only do so when the payload+null_marker fits in a single atomic operation. The JDK source (`fieldLayoutBuilder.cpp`) checks:

```cpp
int nullable_atomic_size = round_up_power_of_2(new_raw_size);
if (nullable_atomic_size <= (int)MAX_ATOMIC_OP_SIZE) {
    _nullable_atomic_layout_size_in_bytes = nullable_atomic_size;
}
```

## Environment

| Component | Version / Path |
|-----------|---------------|
| JDK (release) | `~/src/jdk/build/release-linux-aarch64/images/jdk` — OpenJDK 28-internal |
| JDK (fastdebug) | `~/src/jdk/build/fast-linux-aarch64/jdk` — OpenJDK 28-internal fastdebug |
| async-profiler | `~/src/async-profiler/` (patched with `can_support_value_objects` fix) |
| Architecture | `aarch64` (linux) |

## Reproducer

**File: `FlatAllocReproducer.java`**

Tests 11 scenarios across three array types:

| Array variable | Created with | Flat? | Why |
|---|---|:---:|---|
| `smallArr` | `new SmallVP[N]` | ✅ | 1 int: 4+1=5 → round to 8 ≤ `MAX_ATOMIC_OP_SIZE` |
| `largeNRArr` | `ValueClass.newNullRestrictedAtomicArray(LargeVP)` | ✅ | Null-free: 8 bytes payload, no null marker needed |
| `largeRegArr` | `new LargeVP[N]` | ❌ | 2 ints: 8+1=9 → round to 16 > `MAX_ATOMIC_OP_SIZE` |

Scenarios:

| # | Method | Array | What it tests |
|---|--------|-------|---------------|
| 1 | `smallFlatWrite` | small (flat) | Write into nullable flat array |
| 2 | `smallFlatRead` | small (flat) | Read from nullable flat array → `volatile Object` |
| 3 | `largeFlatNRWrite` | largeNR (flat) | Write into null-restricted flat array |
| 4 | `largeFlatNRRead` | largeNR (flat) | Read from null-restricted flat array → `volatile Object` |
| 5 | `largeRegWrite` | largeReg (not flat) | Write into non-flat oop-ref array |
| 6 | `largeRegRead` | largeReg (not flat) | Read from non-flat oop-ref array → `volatile Object` |
| 7 | `flatWriteNoEscape` | largeNR (flat) | Simple flat write (EA baseline) |
| 8 | `flatWriteEscaping` | largeNR (flat) | Flat write via 4-method chain (`createValue` → `processAndStore` → `doStore` → `Container.add`) |
| 9 | `flatReadTyped` | largeNR (flat) | Read from flat array → non-volatile `LargeVP` field |
| 10 | `boxedAllocations` | — | `new LargeVP(…)` → `volatile Object` |
| 11 | `identityBaseline` | — | `new IdentityPoint(…)` → `volatile Object` |

**Compile & run:**

```bash
javac --enable-preview --source 28 \
    --add-exports java.base/jdk.internal.value=ALL-UNNAMED \
    --add-exports java.base/jdk.internal.misc=ALL-UNNAMED \
    FlatAllocReproducer.java

./run_flat_alloc_tests.sh
```

## Observed results

### A) Layout diagnostics (`PrintInlineLayout` + `PrintFlatArrayLayout`)

```
SmallVP:
  NULLABLE_ATOMIC_FLAT layout: 8/8          ← new SmallVP[N] IS flat
  NULL_FREE_ATOMIC_FLAT layout: 4/4

LargeVP:
  NULLABLE_ATOMIC_FLAT layout: -/-          ← new LargeVP[N] is NOT flat
  NULL_FREE_ATOMIC_FLAT layout: 8/8         ← null-restricted array IS flat

Flat Type Array: [LSmallVP;
  layout kind: NULLABLE_ATOMIC_FLAT, element size 8
Flat Type Array: [LLargeVP;
  layout kind: NULL_FREE_ATOMIC_FLAT, element size 8
```

Runtime verification:

```
smallArr   (new SmallVP[])                flat=true   shallow=8,208 bytes (8 bytes/elem)
largeNRArr (newNullRestrictedAtomicArray) flat=true   shallow=8,208 bytes (8 bytes/elem)
largeRegArr(new LargeVP[])               flat=false  shallow=4,112 bytes (4 bytes/elem)
```

### B) C2 escape analysis (`PrintEscapeAnalysis` + `PrintEliminateAllocations`)

```
smallFlatWrite       Scalar=2   NotScalar=0    → all allocs eliminated
smallFlatRead        Scalar=8   NotScalar=8    → allocs for buffering
largeFlatNRWrite     Scalar=3   NotScalar=0    → all allocs eliminated
largeFlatNRRead      Scalar=12  NotScalar=12   → allocs for buffering
largeRegWrite        Scalar=18  NotScalar=15   → some eliminated, some kept
largeRegRead         no alloc nodes in C2 IR   → zero allocs
flatWriteNoEscape    Scalar=3   NotScalar=0    → all eliminated (baseline)
flatWriteEscaping    Scalar=3   NotScalar=0    → all eliminated (C2 inlined full chain!)
flatReadTyped        Scalar=12  NotScalar=12   → allocs still present
boxedAllocations     Scalar=12  NotScalar=10   → some eliminated, some kept
identityBaseline     no alloc nodes in C2 IR   → C2 handles directly
```

Key observations from C2:

1. **`flatWriteEscaping`**: Despite the 4-method chain (`createValue` → `processAndStore` → `doStore` → `Container.add`), C2 inlines everything and produces `Scalar=3, NotScalar=0`. The JIT inlining log shows all methods were inlined (value classes enable `InlineTypePassFieldsAsArgs`, making inlining very effective).

2. **`flatReadTyped`**: Using a non-volatile typed `LargeVP` sink does NOT reduce allocations vs `volatile Object` sink. C2 still shows `Scalar=12, NotScalar=12` — the buffering from flat storage to heap happens regardless of the sink type, because the `aaload` from a flat array always materialises a heap buffer.

3. **`largeRegRead`**: Zero Allocate nodes — returning an existing oop from a non-flat array needs no allocation at all.

### C) JDK built-in JFR (JIT run)

```
Scenario                  Samples
─────────────────────────────────
smallFlatWrite                  7    ← flat write: few (scalarised)
smallFlatRead                 162    ← flat read: many (buffering)
largeFlatNRWrite               10    ← flat write: few
largeFlatNRRead               216    ← flat read: many
largeRegWrite                 155    ← non-flat write: many (new + oop)
largeRegRead                    0    ← non-flat read: zero (returns oop)
flatWriteNoEscape               8    ← same as largeFlatNRWrite
flatWriteEscaping               8    ← SAME! C2 inlined full chain
flatReadTyped                 154    ← SAME as largeFlatNRRead (typed sink doesn't help)
boxedAllocations              154    ← boxing: many
identityBaseline              101    ← identity: many
```

### D) Async-profiler default mode (patched, JVMTI SampledObjectAlloc)

```
smallFlatWrite                  4
smallFlatRead                 328
largeFlatNRWrite               12
largeFlatNRRead               512
largeRegWrite                 477
largeRegRead                    0
flatWriteNoEscape               6
flatWriteEscaping               6
flatReadTyped                 453
boxedAllocations              459
identityBaseline              310
```

### E) Interpreter-only (`-Xint`, 4k TLABs)

```
smallFlatWrite             40,859
smallFlatRead              40,859
largeFlatNRWrite           61,406
largeFlatNRRead            61,405
largeRegWrite              61,405
largeRegRead                    0    ← STILL zero even in interpreter
flatWriteNoEscape          61,407
flatWriteEscaping          61,404
flatReadTyped              61,405
boxedAllocations           61,405
identityBaseline           40,858
```

In interpreter mode, no scalarisation occurs — all writes allocate. Flat reads still allocate (buffering). But non-flat reads still show zero (returns existing oop).

Note `smallFlatWrite` has ~40k events vs `largeFlatNRWrite` ~61k: SmallVP objects are 16 bytes vs LargeVP's 24 bytes → fewer TLAB refills for smaller objects.

## Analysis

### Why `flatWriteEscaping` is the same as `flatWriteNoEscape`

C2 inlined the entire method chain. The inlining log confirms:

```
@ 8   createValue (12 bytes)         inline (hot)
@ 14  processAndStore (6 bytes)      inline (hot)
  @ 2   doStore (6 bytes)            inline (hot)
    @ 2   Container::add (27 bytes)  inline (hot)
```

Value classes benefit from `InlineTypePassFieldsAsArgs=true` which passes value fields in registers across method boundaries. This makes inlining extremely effective — even 4-deep call chains are fully scalarised. To defeat this in a benchmark, you would need:

- Much larger methods (exceed `MaxInlineSize`/`FreqInlineSize` thresholds)
- Polymorphic call sites (virtual/interface dispatch)
- Methods in separate compilation units loaded by different classloaders
- Native/JNI boundaries

### Why `flatReadTyped` doesn't reduce allocations

The allocation happens at the `aaload` bytecode level — the flat array element must be copied from flat storage into a heap-buffered oop before it can be used as a Java reference. Whether the target is `volatile Object sink` or `LargeVP typedSink` doesn't matter: the JVM must materialise the oop either way.

C2 confirms: `flatReadTyped` has `Scalar=12, NotScalar=12` — identical to `largeFlatNRRead`. The typed sink doesn't provide an escape analysis advantage because the value must still be buffered.

### Why `largeRegRead` is always zero

A non-flat `LargeVP[]` stores compressed oop references to existing heap objects. `aaload` just returns the oop — no copying, no allocation, no event. This is consistent across all profiling modes including interpreter-only.

## How to verify an array is flat

| Method | What to check |
|--------|---------------|
| `ValueClass.isFlatArray(arr)` | Runtime: `true` = flat |
| `Unsafe.getObjectSize(arr)` | Flat: `(size-16)/N ≥ payload_bytes`; Non-flat: `(size-16)/N = 4` (compressed oop) |
| `-XX:+PrintInlineLayout` | Check `NULLABLE_ATOMIC_FLAT` (for regular arrays) or `NULL_FREE_ATOMIC_FLAT` (for null-restricted) |
| `-XX:+PrintFlatArrayLayout` | Lists all flat array klasses created at runtime |
| Compare with `-XX:-UseArrayFlattening` | If allocation pattern changes → flattening was active |

## Diagnostic flags reference

All require `--enable-preview` for flattening defaults to be active.

| Flag | Category | What it reveals |
|------|----------|-----------------|
| `-XX:+PrintInlineLayout` | diagnostic | Per-class flat layout sizes for each kind |
| `-XX:+PrintFlatArrayLayout` | diagnostic | Lists all flat array klasses with element size and layout kind |
| `-XX:+PrintEscapeAnalysis` | C2 develop¹ | `Scalar` (eliminated) vs `NotScalar` (kept) per Allocate node |
| `-XX:+PrintEliminateAllocations` | C2 develop¹ | `++++ Eliminated: NNN Allocate` confirmations |
| `-XX:+PrintCompilation` | product | Method compilation tier and OSR info |
| `-Xlog:jit+inlining=debug` | UL | JIT inlining decisions for each call site |
| `-XX:+UseArrayFlattening` | diagnostic | Enable/disable array flattening |
| `-XX:+UseNullFreeAtomicValueFlattening` | experimental | Null-free atomic flat arrays |
| `-XX:+UseNullableAtomicValueFlattening` | diagnostic | Nullable atomic flat arrays |
| `-XX:FlatArrayElementMaxOops` | diagnostic | Max oops per flat element (default: 4) |
| `-XX:InlineTypePassFieldsAsArgs` | pd diagnostic | Scalarise value types in method calls |
| `-XX:InlineTypeReturnedAsFields` | pd diagnostic | Scalarise value types in returns |

¹ Requires fastdebug JDK build.

## Command lines

### Compile

```bash
javac --enable-preview --source 28 \
    --add-exports java.base/jdk.internal.value=ALL-UNNAMED \
    --add-exports java.base/jdk.internal.misc=ALL-UNNAMED \
    FlatAllocReproducer.java
```

### Run with JFR

```bash
java --enable-preview -cp . \
  --add-opens java.base/jdk.internal.value=ALL-UNNAMED \
  --add-opens java.base/jdk.internal.misc=ALL-UNNAMED \
  -XX:StartFlightRecording="jdk.ObjectAllocationInNewTLAB#enabled=true,jdk.ObjectAllocationOutsideTLAB#enabled=true,filename=profile.jfr,dumponexit=true" \
  FlatAllocReproducer
```

### Run with async-profiler

```bash
java --enable-preview -cp . \
  --add-opens java.base/jdk.internal.value=ALL-UNNAMED \
  --add-opens java.base/jdk.internal.misc=ALL-UNNAMED \
  -agentpath:/path/to/libasyncProfiler.so=start,event=alloc,file=profile.jfr \
  FlatAllocReproducer
```

### Inspect results

```bash
# By class
jfr print --events jdk.ObjectAllocationInNewTLAB profile.jfr \
  | grep 'objectClass = ' | sed 's/.*objectClass = //' | sort | uniq -c | sort -rn

# By scenario
for s in smallFlatWrite smallFlatRead largeFlatNRWrite largeFlatNRRead \
         largeRegWrite largeRegRead flatWriteNoEscape flatWriteEscaping \
         flatReadTyped boxedAllocations identityBaseline; do
    c=$(jfr print --events jdk.ObjectAllocationInNewTLAB,jdk.ObjectAllocationOutsideTLAB \
        profile.jfr | grep -c "$s" || true)
    printf "  %-25s %s\n" "$s" "$c"
done
```

### Fastdebug diagnostics

```bash
JAVA_DBG=~/src/jdk/build/fast-linux-aarch64/jdk/bin/java

# Layout
$JAVA_DBG --enable-preview -cp . \
  --add-opens java.base/jdk.internal.value=ALL-UNNAMED \
  --add-opens java.base/jdk.internal.misc=ALL-UNNAMED \
  -XX:+UnlockDiagnosticVMOptions -XX:+UnlockExperimentalVMOptions \
  -XX:+PrintInlineLayout -XX:+PrintFlatArrayLayout \
  FlatAllocReproducer

# C2 escape analysis
$JAVA_DBG --enable-preview -cp . \
  --add-opens java.base/jdk.internal.value=ALL-UNNAMED \
  --add-opens java.base/jdk.internal.misc=ALL-UNNAMED \
  -XX:+UnlockDiagnosticVMOptions -XX:+UnlockExperimentalVMOptions \
  -XX:+PrintEscapeAnalysis -XX:+PrintEliminateAllocations -XX:+PrintCompilation \
  -Xlog:jit+inlining=debug:file=inlining.log:tags,level \
  FlatAllocReproducer

# Interpreter-only with max events
$JAVA_DBG --enable-preview -cp . -Xint \
  --add-opens java.base/jdk.internal.value=ALL-UNNAMED \
  --add-opens java.base/jdk.internal.misc=ALL-UNNAMED \
  -XX:+UnlockDiagnosticVMOptions -XX:TLABSize=4k -XX:-ResizeTLAB \
  -XX:StartFlightRecording="jdk.ObjectAllocationInNewTLAB#enabled=true,jdk.ObjectAllocationOutsideTLAB#enabled=true,filename=xint.jfr,dumponexit=true" \
  FlatAllocReproducer
```

## Epsilon GC heap analysis

The script `run_heap_analysis.sh` runs each scenario in isolation with Epsilon GC (no garbage collection) and a 48 MB heap. Every heap allocation persists, and a heap dump is captured either on OOME or via a forced `new byte[Integer.MAX_VALUE]` at the end. The dump is analysed with `jol-cli heapdump-stats`.

**Note:** JFR alloc events are always zero under Epsilon GC because it uses a single bump-pointer allocator with no TLAB refills. The heap dump object count is the ground truth.

### Observed results (2M iterations, 48 MB heap)

```
SCENARIO               OOME?  EA:S/NS    SmallVP#    LargeVP#    IdPt#
────────────────────── ────── ────────── ──────────  ──────────  ──────
smallFlatWrite         no     2/0        111,616     0           0
smallFlatRead          yes    18/18      1,871,042   0           0
largeFlatNRWrite       no     3/0        0           111,617     0
largeFlatNRRead        yes    21/20      0           1,249,685   0
largeRegWrite          yes    16/14      0           1,246,968   0
largeRegRead           no     0/0        0           0           0
flatWriteNoEscape      no     3/0        0           111,617     0
flatWriteEscaping      no     4/0        0           111,617     0
flatReadTyped          yes    21/20      0           1,247,822   0
boxedAllocations       yes    12/10      0           1,247,179   0
identityBaseline       yes    0/0        0           0           1,870,583
```

### Key findings from heap analysis

1. **`largeRegRead`: 0 objects, no OOME.** Reading from a non-flat array returns existing oops — literally zero heap impact.

2. **Flat write scenarios (`smallFlatWrite`, `largeFlatNRWrite`, `flatWriteNoEscape`, `flatWriteEscaping`): ~111k objects, no OOME.** The ~111k objects come from JVM warmup (interpreter + C1/C3 tiers) before C2 compiles with escape analysis. Once C2 kicks in (`Scalar>0, NotScalar=0`), the hot loop stops allocating entirely.

3. **`flatWriteEscaping` has the SAME heap footprint (~111k) as `flatWriteNoEscape`.** C2 fully inlines the 4-method chain and scalarises all allocations. The method call depth has no effect.

4. **Flat read scenarios (`smallFlatRead`, `largeFlatNRRead`, `flatReadTyped`): OOME with ~1.2–1.9M objects.** Every read from a flat array allocates a heap buffer that accumulates without GC. Using a typed non-volatile sink (`flatReadTyped`) does not reduce this.

5. **`largeRegWrite` and `boxedAllocations`: OOME with ~1.2M objects.** Every iteration creates a heap object that persists.

6. **The ~111k warmup objects provide a useful baseline** for estimating how many allocations happen before C2 optimises. This count depends on compilation thresholds and could change with `-XX:CompileThreshold` or tiered compilation settings.

## Diagnostic output files

The script `run_flat_alloc_tests.sh` saves profiling diagnostics to `flat_diag_output/`:

```
flat_diag_output/
├── layout_output.log       – PrintInlineLayout + PrintFlatArrayLayout + runtime array props
├── escape_analysis.log     – C2 escape analysis, allocation elimination, PrintCompilation
├── jit_inlining.log        – JIT inlining decisions for every call site
├── flat_jfr_builtin.jfr    – JFR from JIT run
├── flat_jfr_xint.jfr       – JFR from interpreter-only run (4k TLABs)
├── flat_ap_patched.jfr     – async-profiler default alloc JFR
└── flat_ap_tlab.jfr        – async-profiler tlab mode JFR
```

The script `run_heap_analysis.sh` saves Epsilon GC heap analysis to `heap_analysis/`:

```
heap_analysis/
├── <scenario>.hprof        – Heap dump (Epsilon GC, every allocation persists)
├── <scenario>.log          – Scenario stdout/stderr
├── <scenario>.jfr          – JFR recording (alloc events will be 0 under Epsilon)
├── <scenario>_ea.log       – C2 escape analysis output
└── <scenario>_jol.txt      – JOL heapdump-stats output
```
