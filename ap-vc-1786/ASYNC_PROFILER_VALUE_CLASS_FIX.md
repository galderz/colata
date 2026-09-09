# async-profiler misses value class (JEP 401) allocations

## Overview

async-profiler's `alloc` event completely misses value class allocations in its default mode (JVMTI `SampledObjectAlloc`). The JVM requires the `can_support_value_objects` JVMTI capability to fire these events for inline/value objects, and async-profiler does not request it.

## Environment

| Component | Version / Path |
|-----------|---------------|
| JDK (release) | `~/src/jdk/build/release-linux-aarch64/images/jdk` — OpenJDK 28-internal |
| JDK (fastdebug) | `~/src/jdk/build/fast-linux-aarch64/jdk` — OpenJDK 28-internal fastdebug |
| async-profiler (release) | v4.5 — `~/async-profiler-4.5-linux-arm64/` |
| async-profiler (source) | `~/src/async-profiler/` (latest main, commit `bb8f047`) |
| Architecture | `aarch64` (linux) |

## Reproducer

**File: `AllocReproducer.java`**

```java
public class AllocReproducer {

    static class IdentityPoint {
        final int x, y;
        IdentityPoint(int x, int y) { this.x = x; this.y = y; }
    }

    static value class ValuePoint {
        int x;
        int y;
        public ValuePoint(int x, int y) { this.x = x; this.y = y; }
    }

    static volatile Object sink;

    static void allocateIdentity(int count) {
        for (int i = 0; i < count; i++) {
            sink = new IdentityPoint(i, i + 1);
        }
    }

    static void allocateValue(int count) {
        for (int i = 0; i < count; i++) {
            sink = new ValuePoint(i, i + 1);
        }
    }

    public static void main(String[] args) throws Exception {
        final int ITERATIONS = 50_000_000;
        allocateIdentity(1_000_000);
        allocateValue(1_000_000);
        for (int round = 0; round < 5; round++) {
            System.out.println("Round " + round);
            allocateIdentity(ITERATIONS);
            allocateValue(ITERATIONS);
        }
        System.out.println("Done.");
    }
}
```

**Compile:**

```bash
javac --enable-preview --source 28 AllocReproducer.java
```

## Observed behaviour

### async-profiler v4.5 (default mode) — ❌ BROKEN

```bash
java --enable-preview -cp . \
  -agentpath:$HOME/async-profiler-4.5-linux-arm64/lib/libasyncProfiler.so=start,event=alloc,file=alloc_profile.jfr \
  AllocReproducer
```

```bash
jfr print --events jdk.ObjectAllocationInNewTLAB alloc_profile.jfr \
  | grep 'objectClass = ' | sed 's/.*objectClass = //' | sort | uniq -c | sort -rn
```

**Output:**

```
   7665 AllocReproducer$IdentityPoint (classLoader = null)
```

Only `IdentityPoint` — **zero `ValuePoint` samples**.

### JDK built-in JFR — ✅ WORKS

```bash
java --enable-preview -cp . \
  -XX:StartFlightRecording="jdk.ObjectAllocationInNewTLAB#enabled=true,jdk.ObjectAllocationOutsideTLAB#enabled=true,filename=builtin_jfr.jfr,dumponexit=true" \
  AllocReproducer
```

**Output:**

```
   4805 AllocReproducer$ValuePoint (classLoader = app)
   3062 AllocReproducer$IdentityPoint (classLoader = app)
```

Both classes present — built-in JFR correctly captures value class allocations.

### async-profiler v4.5 (`tlab` mode) — ✅ WORKS

```bash
java --enable-preview -cp . \
  -agentpath:$HOME/async-profiler-4.5-linux-arm64/lib/libasyncProfiler.so=start,event=alloc,tlab,file=alloc_tlab.jfr \
  AllocReproducer
```

**Output:**

```
   2915 AllocReproducer$ValuePoint (classLoader = null)
   2566 AllocReproducer$IdentityPoint (classLoader = null)
```

The `tlab` mode (breakpoint-trap engine) works fine — confirming the issue is specific to the JVMTI `SampledObjectAlloc` path.

## Root cause

async-profiler's default allocation engine on JDK 11+ is `ObjectSampler`, which uses the JVMTI `SampledObjectAlloc` callback. In the JDK source (`src/hotspot/share/prims/jvmtiExport.cpp`), the JVM guards value object events with a capability check:

```cpp
// jvmtiExport.cpp, line 3014-3016
const bool is_inline = object->is_inline();
if (is_inline && !JvmtiExport::can_support_value_objects()) {
    return;  // ← value class allocations silently dropped!
}
```

And per-environment:

```cpp
// line 3025-3026
if (ets->is_enabled(JVMTI_EVENT_SAMPLED_OBJECT_ALLOC) &&
    (!is_inline || env->get_capabilities()->can_support_value_objects != 0)) {
```

async-profiler never requests `can_support_value_objects`. In `src/vmEntry.cpp`:

```cpp
// Only these capabilities are requested:
capabilities.can_generate_all_class_hook_events = 1;
capabilities.can_retransform_classes = 1;
// ... etc — no can_support_value_objects
```

## Fix

**File: `src/vmEntry.cpp` in async-profiler source**

```diff
     capabilities.can_tag_objects = 1;
     _jvmti->AddCapabilities(&capabilities);

+    // Request value object support if available (JDK 28+ / Valhalla).
+    // This is needed so that SampledObjectAlloc events are fired for value class instances.
+    // AddCapabilities silently ignores unsupported capabilities on older JDKs.
+    jvmtiCapabilities value_caps = {0};
+    // can_support_value_objects is bit 45 (0-indexed) in jvmtiCapabilities
+    ((unsigned int*)&value_caps)[1] |= (1u << 13);
+    _jvmti->AddCapabilities(&value_caps);
+
     jvmtiEventCallbacks callbacks = {0};
```

The bit-manipulation approach avoids depending on the Valhalla-specific `jvmti.h` header field (`can_support_value_objects`), which doesn't exist in standard JDK headers. `AddCapabilities` silently ignores unsupported capabilities on older JDKs.

**Build the fix:**

```bash
cd ~/src/async-profiler
# Edit src/vmEntry.cpp as shown above
make  # On macOS this just works; on this Linux env:
make CXXFLAGS="-O2 -std=c++11 -U_FORTIFY_SOURCE -Wl,-z,defs -Wl,--exclude-libs,ALL"
```

## Verification

```bash
java --enable-preview -cp . \
  -agentpath:$HOME/src/async-profiler/build/lib/libasyncProfiler.so=start,event=alloc,file=alloc_fixed.jfr \
  AllocReproducer
```

**Output (FIXED):**

```
  11587 AllocReproducer$ValuePoint (classLoader = null)
   7545 AllocReproducer$IdentityPoint (classLoader = null)
```

Both classes now appear.

### Summary table

| Profiling mode | Before fix | After fix |
|----------------|-----------|-----------|
| async-profiler default (`ObjectSampler`) | Identity: 7665, **Value: 0** ❌ | Identity: 7545, **Value: 11587** ✅ |
| async-profiler `tlab` (`AllocTracer`) | Identity: 2566, Value: 2915 ✅ | (unchanged, already worked) |
| JDK built-in JFR | Identity: 3062, Value: 4805 ✅ | (unchanged, already worked) |

## Command lines

### Compile

```bash
javac --enable-preview --source 28 AllocReproducer.java
```

### Profile with async-profiler

```bash
# Default mode (shows the bug on unpatched):
java --enable-preview -cp . \
  -agentpath:/path/to/libasyncProfiler.so=start,event=alloc,file=profile.jfr \
  AllocReproducer

# tlab mode (always works):
java --enable-preview -cp . \
  -agentpath:/path/to/libasyncProfiler.so=start,event=alloc,tlab,file=profile.jfr \
  AllocReproducer
```

### Profile with JDK built-in JFR

```bash
java --enable-preview -cp . \
  -XX:StartFlightRecording="jdk.ObjectAllocationInNewTLAB#enabled=true,jdk.ObjectAllocationOutsideTLAB#enabled=true,filename=profile.jfr,dumponexit=true" \
  AllocReproducer
```

### Inspect JFR results

```bash
jfr print --events jdk.ObjectAllocationInNewTLAB profile.jfr \
  | grep 'objectClass = ' | sed 's/.*objectClass = //' | sort | uniq -c | sort -rn
```

### Build async-profiler from source

```bash
cd ~/src/async-profiler
export JAVA_HOME=~/src/jdk/build/release-linux-aarch64/images/jdk  # or /usr/libexec/java_home on macOS
make  # auto-detects OS; produces build/lib/libasyncProfiler.{so,dylib}
```
