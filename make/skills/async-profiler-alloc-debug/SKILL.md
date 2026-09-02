---
name: async-profiler-alloc-debug
description: Debug async-profiler allocation profiling issues. Use when async-profiler alloc events are missing, show unexpected counts, or do not match JDK built-in JFR. Covers engine selection, JVMTI capabilities, value class support, and tlab vs default mode differences.
---

# async-profiler Allocation Debugging

Debug allocation profiling issues with async-profiler: missing events, engine selection, JVMTI capability gaps, and comparison with JDK built-in JFR.

## When to use

- async-profiler `alloc` event shows zero or unexpectedly low samples for certain classes
- Allocation counts don't match JDK built-in JFR
- Value class (JEP 401) allocations are not visible
- Need to understand which allocation engine async-profiler is using
- Flat array scenarios show unexpected allocation event patterns

## Allocation engines

async-profiler has two allocation profiling engines:

| Engine | Mode flag | Mechanism | JDK requirement |
|--------|-----------|-----------|-----------------|
| `ObjectSampler` | (default) | JVMTI `SampledObjectAlloc` callback | JDK 11+ (`can_generate_sampled_object_alloc_events`) |
| `AllocTracer` | `tlab` | Breakpoint trap on `AllocTracer::send_allocation_in_new_tlab` / `send_allocation_outside_tlab` in libjvm | JDK 7+ (needs debug symbols) |

**Selection logic** (in `Profiler::selectAllocEngine`):
1. If `tlab` flag is set → `AllocTracer` (breakpoint engine)
2. Else if `can_generate_sampled_object_alloc_events` is available → `ObjectSampler` (JVMTI)
3. Else if OpenJ9 → `J9ObjectSampler`
4. Else → `AllocTracer` (fallback)

On JDK 11+, the default is always `ObjectSampler`.

## Debugging workflow

### Step 1: Verify with JDK built-in JFR

Always start by checking if the JDK itself sees the allocations:

```bash
java --enable-preview -cp $CLASSPATH \
  -XX:StartFlightRecording="jdk.ObjectAllocationInNewTLAB#enabled=true,jdk.ObjectAllocationOutsideTLAB#enabled=true,filename=builtin.jfr,dumponexit=true" \
  YourMainClass

jfr print --events jdk.ObjectAllocationInNewTLAB builtin.jfr \
  | grep 'objectClass = ' | sed 's/.*objectClass = //' | sort | uniq -c | sort -rn
```

If built-in JFR shows the allocations but async-profiler doesn't → the issue is in async-profiler's engine or JVMTI setup.

### Step 2: Compare default vs tlab mode

```bash
# Default mode (ObjectSampler / JVMTI):
java --enable-preview -cp $CLASSPATH \
  -agentpath:/path/to/libasyncProfiler.so=start,event=alloc,file=default.jfr \
  YourMainClass

# tlab mode (AllocTracer / breakpoint):
java --enable-preview -cp $CLASSPATH \
  -agentpath:/path/to/libasyncProfiler.so=start,event=alloc,tlab,file=tlab.jfr \
  YourMainClass
```

Compare results:

```bash
for f in default.jfr tlab.jfr; do
    echo "=== $f ==="
    jfr print --events jdk.ObjectAllocationInNewTLAB "$f" \
      | grep 'objectClass = ' | sed 's/.*objectClass = //' | sort | uniq -c | sort -rn | head -10
done
```

If `tlab` mode shows allocations that default mode misses → the issue is in JVMTI event delivery, not the allocation itself.

### Step 3: Check for JVMTI capability issues

Common capability gaps:

| Missing capability | Symptom | Affected classes |
|-------------------|---------|------------------|
| `can_support_value_objects` | Zero samples for value/inline classes | All value classes (JEP 401) |
| `can_generate_sampled_object_alloc_events` | ObjectSampler won't start | All classes |

**Value class fix**: async-profiler needs to request `can_support_value_objects`. The JVM checks this in `jvmtiExport.cpp`:

```cpp
const bool is_inline = object->is_inline();
if (is_inline && !JvmtiExport::can_support_value_objects()) {
    return;  // silently drops the event
}
```

**Workaround**: Use `tlab` mode — the breakpoint engine doesn't depend on JVMTI capabilities.

### Step 4: Check if allocations actually happen

Some scenarios produce zero events because no heap allocation occurs:

```bash
# Run with tiny TLABs in interpreter-only mode for maximum sensitivity:
java --enable-preview -cp $CLASSPATH -Xint \
  -XX:+UnlockDiagnosticVMOptions -XX:TLABSize=4k -XX:-ResizeTLAB \
  -XX:StartFlightRecording="jdk.ObjectAllocationInNewTLAB#enabled=true,jdk.ObjectAllocationOutsideTLAB#enabled=true,filename=max_events.jfr,dumponexit=true" \
  YourMainClass
```

If still zero events → the JVM is not allocating (e.g., reading from a non-flat value class array returns existing heap oops).

Verify with GC:

```bash
java --enable-preview -cp $CLASSPATH -Xint -Xmx8m -verbose:gc YourMainClass
# Zero GC = zero heap allocations
```

### Step 5: Check C2 allocation elimination

If allocations appear in interpreter mode but disappear with the JIT:

```bash
# With fastdebug JDK:
java --enable-preview -cp $CLASSPATH \
  -XX:+UnlockDiagnosticVMOptions -XX:+UnlockExperimentalVMOptions \
  -XX:+PrintEscapeAnalysis -XX:+PrintEliminateAllocations \
  -XX:+PrintCompilation \
  -Xlog:jit+inlining=debug:file=inlining.log:tags,level \
  YourMainClass 2>&1 | grep -E 'YourMethod|Scalar|NotScalar|Eliminated'
```

- `Scalar` → allocation eliminated by escape analysis
- `NotScalar` → allocation kept on heap (will produce events)
- No output for a method → zero Allocate nodes (fully scalarised)

Check the inlining log to see if methods were inlined:

```bash
grep "YourMethod" inlining.log
```

Value classes benefit from `InlineTypePassFieldsAsArgs=true` which makes C2 very aggressive at inlining — even 4-deep call chains can be fully scalarised.

### Step 6: Check array flattening state

```bash
# Check if flattening flags are active (require --enable-preview):
java --enable-preview -XX:+UnlockDiagnosticVMOptions -XX:+UnlockExperimentalVMOptions \
  -XX:+PrintFlagsFinal -version 2>&1 | grep -E "UseArrayFlat|NullFree|Nullable"

# Check value class layout and which flat layouts are available:
java --enable-preview -cp $CLASSPATH \
  -XX:+UnlockDiagnosticVMOptions -XX:+PrintInlineLayout -XX:+PrintFlatArrayLayout \
  YourMainClass
```

Look for `NULLABLE_ATOMIC_FLAT: -/-` (not available for `new VC[N]`) vs `8/8` (available). Whether `new VC[N]` is flat depends on `round_up_power_of_2(payload + null_marker) ≤ 8`.

At runtime, verify with:

```java
import jdk.internal.value.ValueClass;
ValueClass.isFlatArray(arr)  // true = flat
```

## Known issues

### 1. Value class allocations invisible (async-profiler ≤ 4.5)

**Symptom**: Zero `alloc` samples for all value classes. Identity classes work fine.

**Cause**: async-profiler doesn't request `can_support_value_objects` JVMTI capability.

**Fix**: In `src/vmEntry.cpp`, after the main `AddCapabilities` call:

```cpp
// Request value object support if available (JDK 28+ / Valhalla).
jvmtiCapabilities value_caps = {0};
// can_support_value_objects is bit 45 (0-indexed) in jvmtiCapabilities
((unsigned int*)&value_caps)[1] |= (1u << 13);
_jvmti->AddCapabilities(&value_caps);
```

**Workaround**: Use `tlab` mode: `event=alloc,tlab`

### 2. Flat vs non-flat arrays have opposite allocation patterns

**Symptom**: Allocation events appear in unexpected places for value class arrays.

Flat arrays (where `ValueClass.isFlatArray()` returns `true`) and non-flat arrays have opposite behaviour:

| | Flat array | Non-flat array |
|---|---|---|
| **Write** (`aastore`) | Few/no events (C2 scalarises `new`, copies fields inline) | Events fire (`new` creates heap object, stored as oop) |
| **Read** (`aaload`) | Events fire (inline data buffered to heap) | Zero events (returns existing heap oop) |

Whether `new ValueClass[N]` is flat depends on value class size:
- `round_up_power_of_2(payload + null_marker) ≤ MAX_ATOMIC_OP_SIZE (8)` → flat
- Otherwise → not flat; use `ValueClass.newNullRestrictedAtomicArray()` for flattening

**Reading into a typed non-volatile field does NOT reduce flat-read allocations.** The buffering happens at `aaload` time regardless of the sink type.

**Non-flat array reads always show zero events** — even in interpreter mode — because they return existing heap oops.

**Important**: Flattening flags default to `true` ONLY with `--enable-preview`. Without it, nothing is flat.

### 3. C2 scalarises value allocations very aggressively

**Symptom**: Flat-write allocation events that appear in interpreter mode disappear with JIT.

Value classes benefit from `InlineTypePassFieldsAsArgs=true` which passes fields in registers across method boundaries. Even a 4-deep call chain (`createValue` → `processAndStore` → `doStore` → `Container.add`) can be fully inlined and scalarised, producing zero allocation events.

Check with `-XX:+PrintEscapeAnalysis` and `-Xlog:jit+inlining=debug` on a fastdebug build to confirm.

### 4. Epsilon GC reveals true heap impact (but produces zero JFR/AP events)

When using Epsilon GC for heap analysis, both JFR and async-profiler `alloc` events will show **zero samples** because Epsilon uses a single bump-pointer allocator with no TLAB refills. The heap dump object count from `jol-cli heapdump-stats` is the ground truth.

Typical Epsilon GC results for 2M iterations, 48 MB heap:
- **Flat writes** (scalarised by C2): ~111k objects, no OOME — only warmup allocations before C2 kicks in
- **Flat reads** (buffering): ~1.2M+ objects, OOME — every read allocates a heap buffer
- **Non-flat reads**: 0 objects, no OOME — returns existing oops
- **Non-flat writes / boxing**: ~1.2M+ objects, OOME — every write allocates

### 5. Sampling interval affects visibility

The default sampling interval for `ObjectSampler` is 512KB. Small allocations may be undersampled.

```bash
# Lower the interval (bytes) for more samples (slower):
-agentpath:libasyncProfiler.so=start,event=alloc,alloc=4096,file=out.jfr
```

## Inspecting JFR output

```bash
# Class summary
jfr print --events jdk.ObjectAllocationInNewTLAB profile.jfr \
  | grep 'objectClass = ' | sed 's/.*objectClass = //' | sort | uniq -c | sort -rn

# Per-method attribution (stack-based)
for s in myWriteMethod myReadMethod; do
    c=$(jfr print --events jdk.ObjectAllocationInNewTLAB,jdk.ObjectAllocationOutsideTLAB profile.jfr \
        | grep -c "$s" || true)
    printf "  %-25s %s samples\n" "$s" "$c"
done

# Full event summary
jfr summary profile.jfr

# Full stack traces for a specific class
jfr print --events jdk.ObjectAllocationInNewTLAB --stack-depth 20 profile.jfr \
  | awk '/^jdk.Object/{block=""} {block=block"\n"$0} /^}/{if(block ~ /YourClass/) print block}'
```

## Building async-profiler from source

```bash
git clone https://github.com/async-profiler/async-profiler.git
cd async-profiler
export JAVA_HOME=/path/to/jdk
make  # produces build/lib/libasyncProfiler.{so,dylib}
```

On Linux without static libstdc++:

```bash
make CXXFLAGS="-O2 -std=c++11 -U_FORTIFY_SOURCE -Wl,-z,defs -Wl,--exclude-libs,ALL"
```

## Source code references

| File | What |
|------|------|
| `src/objectSampler.cpp` | JVMTI `SampledObjectAlloc` callback handler |
| `src/allocTracer.cpp` | Breakpoint-based allocation tracer (tlab mode) |
| `src/vmEntry.cpp` | JVMTI capability requests and agent initialization |
| `src/profiler.cpp` → `selectAllocEngine()` | Engine selection logic |
| JDK `src/hotspot/share/prims/jvmtiExport.cpp` → `post_sampled_object_alloc()` | Where `can_support_value_objects` is checked |
| JDK `src/hotspot/share/gc/shared/memAllocator.cpp` → `notify_allocation_jfr_sampler()` | Where `send_allocation_in_new_tlab` is called |
| JDK `src/hotspot/share/gc/shared/allocTracer.cpp` | JFR allocation event emission |
| JDK `src/hotspot/share/classfile/fieldLayoutBuilder.cpp` | Where nullable/null-free flat layout sizes are computed and `MAX_ATOMIC_OP_SIZE` is checked |
| JDK `src/hotspot/share/oops/objArrayKlass.cpp` | Array flattening decision: `has_nullable_atomic_layout()` → flat; else → ref array |
