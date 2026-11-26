# alloc-exp: which allocations does C2 add because of value classes?

With `--enable-preview` (JEP 401), `java.lang.Integer` becomes a value class. C2 can then keep an
`Integer` in registers, but sometimes has to create a heap copy of it, an object that would not
exist without preview. This directory has small scenarios plus scripts that record, classify and
count such allocations. Each step below shows the command and the output it produced, so you can
compare your own run. Internals are in [`docs/DETAILS.md`](docs/DETAILS.md).

## Requirements

- A JDK built from `openjdk/jdk` at commit `4f33273115381cd7697082fcb1bb2642dae19043`. Default
  location: `~/src/jdk/build/release-linux-x86_64/images/jdk`; elsewhere, set `JAVA_HOME_EXP=<jdk>`.
- For the async-profiler step: a checkout at `~/src/async-profiler` (or `ASYNC_PROFILER_HOME`);
  `scripts/build.sh` builds it. It needs a JDK with `include/jvmti.h`; if `JAVA_HOME_EXP` has none
  (e.g. an exploded `build/<conf>/jdk` directory), it uses another JDK from `/usr/lib/jvm`, or
  `AP_JAVA_HOME`.
- For the probe steps: `gdb`, and `libjvm.debuginfo` (found automatically in a JDK build tree, or
  set `LIBJVM_DEBUGINFO`). The BPF probe also needs `bpftrace` and root on a machine where BPF works:
  a VM or bare metal, **not** an unprivileged container.

All output goes to `target/`. Re-runs give slightly different numbers (JIT timing), but the same
picture.

## The scenarios

Each scenario stores `Integer`s into an `Object[]` in a hot loop (50 × 1,000,000 iterations).
Every scenario runs twice: `identity` (no flags) and `preview` (`--enable-preview`).

| scenario | what the loop does | does preview add objects? |
|---|---|---|
| `fresh` | `sink[i] = Integer.valueOf(i + 1000)`, a new box every time | **no**: same number of objects, only the allocation point moves |
| `cached-call` | `sink[i] = id(Integer.valueOf(i & 63))`, cached boxes through a non-inlined method | **yes**: the value crosses the call in registers, so the caller must make a new heap copy |
| `flat-field` | stores cached boxes in an `Integer` field, reads them back into `sink` | **yes**: the field is flattened, so reading it back needs a new heap copy |

## Quick start

```bash
scripts/run-all.sh          # build, count, record and analyze everything (~3 min)
scripts/run-probes-gdb.sh   # optional: per-HotSpot-entry-point counts with gdb (~10 min)
```

Or step by step, as below.

## Step 1: build

```bash
scripts/build.sh
```
```
openjdk version "28-internal" 2027-03-23
compiled -> .../alloc-exp/build/classes
async-profiler -> .../async-profiler/build/lib/libasyncProfiler.so
```

## Step 2: exact object counts (ground truth)

```bash
scripts/histogram.sh        # -> target/histogram.txt
```
The JVM runs with Epsilon GC (never frees memory) and prints a class histogram at exit, so the
counts are all `Integer`s ever allocated:
```
scenario     mode         Integer objs   Integer bytes
fresh        identity       50,000,293     800,004,688
fresh        preview        50,000,318     800,005,088
cached-call  identity              293           4,688
cached-call  preview        49,993,876     799,902,016
flat-field   identity              293           4,688
flat-field   preview        50,000,318     800,005,088
```
`cached-call` and `flat-field` go from ~300 to ~50 million objects with preview.

## Step 3: record where the allocations happen

```bash
scripts/record-jfr.sh <scenario> <identity|preview> exact     # JDK JFR, one event per allocation
scripts/record-jfr.sh <scenario> <identity|preview> sampled   # JDK JFR, sampled, cheaper
scripts/record-ap.sh  <scenario> <identity|preview>           # async-profiler, Java + HotSpot frames
```
Example: `scripts/record-jfr.sh cached-call preview exact` writes
`target/jfr-exact/cached-call-preview.jfr`. `run-all.sh` records every combination.

- `exact` runs with `-XX:-UseTLAB`, so every allocation is recorded (3 × 1M iterations by default).
- The JFR runs use `-XX:-TieredCompilation`, because JFR cannot tell C1 frames from C2 frames.
- async-profiler (`cstack=vmx`) labels C1 and C2 frames itself and also records the HotSpot frames
  that did the allocation.

## Step 4: analyze a recording

```bash
scripts/analyze.sh target/jfr-exact/cached-call-preview.jfr    # -> stdout
scripts/analyze-all.sh                                         # -> target/analysis/<recorder>/<scenario>-<mode>.txt
```
For a `*-preview.jfr`, `analyze.sh` automatically compares against the matching
`*-identity.jfr`. The report has three parts.

**Allocations by category.** C2 allocations are classified; interpreter and C1 allocations are
listed but ignored:
```
  category                                                       events   est. bytes   share
  C2 value object: MATERIALIZED at `aastore`                    2960064      45.2 MB   82.3%
  Interpreter (ignored)                                          183091       6.1 MB   11.1%
  C2 identity object                                              66113       3.3 MB    6.0%
  Native method                                                    5476     374.9 KB    0.7%
```
"MATERIALIZED at `aastore`" means C2 had the value in registers and created a heap copy at the
`aastore` where it escapes. In exact recordings, `events` is the number of objects.

**Top stacks, one frame per line.** `>` marks the allocating frame, followed by the bytecode at its bci:
```
#1  82.3% of all  events=2960064  est.bytes=45.2 MB
    class     : java.lang.Integer  [value class]
    category  : C2 value object: MATERIALIZED at `aastore`
    comp.unit : ValueAllocs.cachedCall()  [C2]
    stack     :
      > [JIT compiled] ValueAllocs.cachedCall()                         bci=27   line=60   aastore
        [Interpreted]  ValueAllocs.main(String[])                       bci=190  line=90   invokestatic
```
async-profiler recordings (`target/analysis/ap/cached-call-preview.txt`) also show the HotSpot
path that allocated:
```
    runtime   : new_instance_blob (C2 runtime) -> OptoRuntime::new_instance_C
        [C++]          libjvm.so`OptoRuntime::new_instance_C
        [Native]       new_instance_blob (C2 runtime)
      > [JIT compiled] ValueAllocs.cachedCall()                         bci=27   line=60   aastore
```
For comparison, without preview the same `fresh` objects are allocated at the `new` inside the
inlined `Integer.valueOf` (`target/analysis/ap/fresh-identity.txt`):
```
      > [Inlined]      java.lang.Integer.valueOf(int)                   bci=23   line=1027 new
        [Inlined]      ValueAllocs.box(int)                             bci=1    line=42   invokestatic
        [JIT compiled] ValueAllocs.fresh()                              bci=14   line=47   invokestatic
```

**Extra allocations vs the identity run.** This is the answer to "which objects exist only because
of value classes", per allocated class and C2-compiled method:
```
fresh:        java.lang.Integer  ValueAllocs.fresh()          base.events 2956992  events 2955968  extra -1024
cached-call:  java.lang.Integer  ValueAllocs.cachedCall()     base.events       0  events 2960064  extra +2960064
flat-field:   java.lang.Integer  ValueAllocs.flatFieldLoad()  base.events       0  events 2958016  extra +2958016
```
(Condensed from `target/analysis/jfr-exact/<scenario>-preview.txt`.)

You can also run the analyzer directly, e.g. on your own recordings:
```bash
java tools/AllocAnalyzer.java --cp <app classes/jars> --preview \
     --baseline <identity>.jfr <preview>.jfr [--top N] [--class java.lang.Integer]
```

## Step 5: counts per HotSpot entry point, with gdb (works anywhere)

```bash
scripts/probe-gdb.sh cached-call preview      # -> target/probe-gdb/cached-call-preview.txt (~2.5 min)
scripts/run-probes-gdb.sh                     # four runs (~10 min)
```
The JVM runs with `-XX:-UseTLAB`, and a breakpoint on HotSpot's instance allocator records which
runtime entry point made each allocation. C2-made allocations are resolved to the compiled method.
gdb is slow, so runs are small (300 × 1000 iterations):
```
Instance allocations by HotSpot entry point (exact counts)
  C2  OptoRuntime::new_instance_C                        190000   63.8%
  ANY SharedRuntime::store_value_type_fields_to_buf       103850   34.8%
  INT InterpreterRuntime::_new                             3954    1.3%
...
C2 allocation sites (OptoRuntime::new_instance_C) resolved to compiled methods
  java.lang.Integer              190000  in  void ValueAllocs.cachedCall()
```

| run | C2 `Integer` allocations | main noise (interpreter, C1, shared stubs) |
|---|---|---|
| `cached-call identity` | none | ~4k interpreter start-up allocations |
| `cached-call preview` | 190,000 in `cachedCall()` | ~104k `store_value_type_fields_to_buf`, from the interpreter |
| `flat-field preview` | 190,000 in `flatFieldLoad()` | ~62k interpreter flat-field reads, ~48k C1 |
| `fresh preview` | 190,000 in `fresh()` | ~104k `store_value_type_fields_to_buf` |

The probe shows *where in HotSpot* objects are made; whether they are extra comes from step 4.

## Step 6: the same counts with BPF (needs a VM or bare metal)

```bash
sudo scripts/probe-bpf.sh cached-call preview   # -> target/probe-bpf/cached-call-preview.txt
sudo scripts/run-probes-bpf.sh                  # four runs
```
Under `sudo`, default paths are relative to the invoking user's home. For a JDK elsewhere, pass
it through: `sudo JAVA_HOME_EXP=<jdk> scripts/probe-bpf.sh ...`.

Same report as step 5, with bpftrace uprobes instead of gdb, so it runs at full size
(5 × 1,000,000 iterations). A preview run takes ~15 s (~0.5 s without the probe, so roughly 3 µs
per allocation), the identity run ~2.5 s; `run-probes-bpf.sh` finishes in about 50 s.
`target/probe-bpf/cached-call-preview.txt`:
```
Instance allocations by HotSpot entry point (exact counts)
  C2  OptoRuntime::new_instance_C                       4832029   96.7%
  ANY SharedRuntime::store_value_type_fields_to_buf       158664    3.2%
  INT InterpreterRuntime::_new                             3912    0.1%
  VM  other runtime path                                    191    0.0%
  INT InterpreterRuntime::flat_array_load                     6    0.0%
  C1  Runtime1::new_instance                                  4    0.0%

Top (entry point, class)
  C2  OptoRuntime::new_instance_C                  java.lang.Integer                         4832029
  ANY SharedRuntime::store_value_type_fields_to_buf java.lang.Integer                          158664
  INT InterpreterRuntime::_new                     ValueAllocs$Holder                           1024
...
C2 allocation sites (OptoRuntime::new_instance_C) resolved to compiled methods
  java.lang.Integer             4832029  in  void ValueAllocs.cachedCall()
```

| run | C2 `Integer` allocations | main noise (interpreter, C1, shared stubs) |
|---|---|---|
| `cached-call identity` | none | ~4k interpreter start-up allocations (7 of them `Integer`) |
| `cached-call preview` | 4,832,029 in `cachedCall()` | ~159k `store_value_type_fields_to_buf` |
| `flat-field preview` | 4,832,046 in `flatFieldLoad()` | ~104k C1 and ~64k interpreter flat-field reads of `Integer` |
| `fresh preview` | 4,832,037 in `fresh()` | ~161k `store_value_type_fields_to_buf` |

At full size, C2 makes ~97% of all instance allocations in the preview runs (gdb, step 5: ~64%).
The `Integer` totals over all entry points match `scripts/histogram.sh 5` (which overwrites
`target/histogram.txt`): 5,000,014 vs 5,000,318 for `flat-field` and `fresh`. The ~300
difference is the `Integer`s mapped in from the CDS archive, which the histogram counts but which
are never allocated. For `cached-call` it is 4,990,707 vs 4,993,921; that count varies by a few
thousand between runs (JIT timing).

The JDK must be an `images/jdk` with its CDS archive (`lib/server/classes*.jsa`). An exploded
`build/<conf>/jdk` has no archive, and start-up then adds ~45k allocations (~270 of them
`Integer`) to every run.

If bpftrace fails, `scripts/bpf-smoke.sh` runs step-by-step checks; see
[`docs/bpf-context.md`](docs/bpf-context.md).

## Files

| path | what |
|---|---|
| `src/ValueAllocs.java` | the scenarios |
| `tools/AllocAnalyzer.java` | JFR analyzer (classification, readable stacks, baseline diff) |
| `scripts/` | everything you run; each script starts with a usage comment |
| `probe/` | bpftrace template, gdb equivalent, probe report |
| `docs/DETAILS.md` | how everything works, analyzer options, JDK build configuration |
| `docs/bpf-context.md` | BPF background, troubleshooting and task list |
| `docs/SESSION-CONTEXT.md` | context for continuing this work in a new session |
| `docs/incus-spawn-feature-request.md` | BPF in isx instances: what exists and what is missing |
