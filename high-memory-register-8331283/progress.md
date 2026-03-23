# Investigation: JDK-8331283 — Excessive C2 Compiler Arena Memory Usage

## Summary

Bisected the OpenJDK `jdk` repository to identify which commit fixed the excessive memory usage described in [JDK-8331283](https://bugs.openjdk.org/browse/JDK-8331283). The issue caused the C2 compiler to consume ~1.1GB of arena memory when compiling `TestFindNode::test` with stress flags enabled.

## Fix Commit

**`7d4c3fd0915`** — [8331295: C2: Do not clone address computations that are indirect memory input to at least one load/store](https://github.com/openjdk/jdk/commit/7d4c3fd0915cfa8b279f42494625ec6afda338af)

- **Author:** Daniel Lundén (co-authored by Roberto Castañeda Lozano)
- **Date:** 2024-11-20
- **Reviewers:** thartmann, chagedorn
- **Key change:** Modified `src/hotspot/cpu/aarch64/aarch64.ad` to prevent C2 from cloning address computations that serve as indirect memory inputs to loads/stores. This eliminated the exponential node growth during instruction selection.
- **Both `75420e9314c` and `7d4c3fd0915` are included in JDK 25** (`origin/jdk25` branch).

## Observed Arena Usage

| Commit | Description | Arena Usage (TestFindNode::test) | Verdict |
|--------|-------------|----------------------------------|---------|
| `ad78b7fa67b` | 8331185: Enable compiler memory limits in debug builds | ~1.14 GB (`1215474640`) | BAD |
| `75420e9314c` | 8334431: C2 SuperWord: fix performance regression (parent of fix) | ~296 MB (`296630328`) | BAD |
| `7d4c3fd0915` | 8331295: C2: Do not clone address computations... (the fix) | ~32 MB (`32679824`) | GOOD |

## How to Reproduce

### Prerequisites

All tools are installed locally under `./tools/` (no global installs):

- **Boot JDKs:** `tools/jdk-22.jdk`, `tools/jdk-23.0.1.jdk`, `tools/jdk-24.jdk`
- **jtreg:** `tools/jtreg75/jtreg` (v7.5.1+1) and `tools/jtreg` (v7.3.1)
- **autoconf/m4:** `tools/local/bin/` (built from source)
- **JDK source:** cloned into `./jdk/`

### Build and Test Steps

For each commit, the process is:

```bash
cd jdk
git checkout <COMMIT>
```

#### 1. Patch SpinPause (required for clang 17+ on macOS/aarch64)

At commits before `743c821289a`, the `SpinPause()` function in `src/hotspot/os_cpu/bsd_aarch64/os_bsd_aarch64.cpp` uses inline assembly with a computed branch table that triggers a CFI error with clang 17+. Replace the function body with:

```c
int SpinPause() {
    switch (VM_Version::spin_wait_desc().inst()) {
    case SpinWait::NONE:  break;
    case SpinWait::NOP:   asm volatile("nop" : : : "memory"); break;
    case SpinWait::ISB:   asm volatile("isb" : : : "memory"); break;
    case SpinWait::YIELD: asm volatile("yield" : : : "memory"); break;
    default: break;
    }
    return 1;
}
```

#### 2. Configure and Build

Select the appropriate boot JDK based on the source version:

| Source Version | Required Boot JDK |
|---------------|-------------------|
| JDK 23 (commit `ad78b7fa67b`) | JDK 22 |
| JDK 24 (commits `75420e9314c`, `7d4c3fd0915`) | JDK 23 |
| JDK 25+ | JDK 24 |

```bash
export PATH="$(pwd)/../tools/local/bin:$PATH"

bash configure \
    --with-boot-jdk=../tools/<appropriate-jdk>/Contents/Home \
    --with-debug-level=fastdebug \
    --disable-warnings-as-errors

make images CONF=macosx-aarch64-server-fastdebug
```

#### 3. Run the Test

```bash
export JDK_HOME="$(pwd)/build/macosx-aarch64-server-fastdebug/images/jdk"
export JTREG_HOME="$(pwd)/../tools/jtreg75/jtreg"

export ADD_OPTIONS='-XX:+UnlockDiagnosticVMOptions -XX:-TieredCompilation -XX:+StressArrayCopyMacroNode -XX:+StressLCM -XX:+StressGCM -XX:+StressIGVN -XX:+StressCCP -XX:+StressMacroExpansion -XX:+StressMethodHandleLinkerInlining -XX:+StressCompiledExceptionHandlers -XX:CompileCommand=memlimit,*.*,1G~crash -XX:CompileCommand=memstat,*::*,print'

"$JTREG_HOME/bin/jtreg" \
    -jdk:"$JDK_HOME" \
    "-vmoptions:${ADD_OPTIONS}" \
    test/hotspot/jtreg/compiler/c2/TestFindNode.java
```

#### 4. Check Results

```bash
grep "Arena usage.*TestFindNode::test" JTwork/compiler/c2/TestFindNode.jtr
```

**Expected output format varies by commit:**

At `ad78b7fa67b` (JDK 23 era):
```
c2 Arena usage compiler/c2/TestFindNode::test(()V): 1215474640 [na 36601184 ra 1165089792] (232048->1215706688->2981800)
```

At `75420e9314c` and `7d4c3fd0915` (JDK 24 era):
```
c2 Arena usage compiler/c2/TestFindNode::test(()V): 32679824 [other 6791216 ra 13400512 node 12488096] (32679824->1702136)
```

The key number is the first large integer after the method signature — this is the total arena usage in bytes.

## Bisect Script

The automated bisect script is at `bisect.sh`. It handles:
- SpinPause patching for clang compatibility
- Boot JDK selection (tries JDK 22, 23, 24 in order)
- jtreg version selection (tries 7.5.1 first, falls back to 7.3.1)
- Multiple arena output format parsing
- 100MB threshold to classify commits as BAD (>100MB) or GOOD (<=100MB)
- Working tree cleanup via trap to allow `git bisect` to checkout next commit
