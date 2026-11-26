# Session context: restoring this work in a new session

Read this first when continuing the work, e.g. in the isx VM where BPF works. Then read
`README.md` (what to run, expected results), `docs/DETAILS.md` (how things work) and
`docs/bpf-context.md` (BPF background and tasks).

## 1. The original request

As a HotSpot C2 engineer, explore how to get more information out of allocations caused by C2:

1. Verify whether JFR and async-profiler can tell which HotSpot layer (e.g. C2) caused an allocation.
2. If not, consider BPF (or similar tracing) to attribute allocations to C2.
3. Explore whether tracing can tell if allocations relate to value objects (JEP 401). Value
   objects can avoid allocations (flattening, scalarization), but can also cause extra ones when
   they must become heap objects again.

Motivating data: a Hibernate/Quarkus workload on the JDK at commit
`4f33273115381cd7697082fcb1bb2642dae19043`, with Epsilon GC, analyzed from a heap dump on OOM with
JOL. With `--enable-preview`, `java.lang.Integer` instances jump to 233,241 (not in the top 30
without preview), because `Integer` becomes a value class.

The user later clarified the target: find value objects that **C2-compiled code** instantiates as
full heap objects where, without value classes, there would be no object. Ignore interpreter/C1
noise.

## 2. Findings so far

- **JDK JFR**
  - Allocation events (`ObjectAllocationSample`, `...InNewTLAB`, `...OutsideTLAB`) carry class,
    size or weight, and a Java-only stack (`jfr/metadata/metadata.xml`).
  - Frame types are Interpreted / JIT compiled / Inlined / Native, so C1 and C2 are not
    distinguished (`jfrStackFrame.hpp`).
  - No HotSpot C++ frames are recorded.
- **async-profiler (commit 55f7f0e)**
  - With `cstack=vmx` (= `vm` + `features=mixed`), allocation stacks have C1 vs C2 frame types and
    the HotSpot frames that allocated, e.g. `new_instance_blob (C2 runtime) -> OptoRuntime::new_instance_C`.
  - The default `cstack=vm` gives Java frames only, without tiers.
  - So the premise "neither tool provides it" is only half true.
- **Telling "materialized" value objects apart**
  - C2 scalarizes value objects (`ValueTypeNode`, `src/hotspot/share/opto/valuetypenode.cpp`) and
    allocates a heap copy (`ValueTypeNode::buffer`) at the escape point.
  - The allocation's debug info is the escaping bytecode (`aastore`, `putfield`, `invoke*`, ...), not
    a `new`.
  - So the allocating frame's bci + bytecode + value-class check identifies materialization.
- **Extra vs moved objects** needs an identity baseline: compare per (class, C2 compilation unit).
  Example: `fresh` moves the allocation from `Integer.valueOf@23 new` to `fresh()@aastore`, no
  extra objects; `cached-call` and `flat-field` add ~1 object per iteration.
- **`-XX:-UseTLAB`** forces every allocation through the runtime (`macro.cpp`, "Force slow-path
  allocation", applied after escape analysis). JFR `ObjectAllocationOutsideTLAB` then gives exact
  per-site counts cheaply, and probes see every allocation.
- **`store_value_type_fields_to_buf`** is shared:
  - When a C2 caller needs a heap object for a scalarized return value, it allocates inline (TLAB
    fast path plus pack handler, `macro.cpp` around line 2889) and falls back to this stub.
  - The interpreter and C1 also call it.
  - In the scenarios it came from the interpreter (verified: the stub's return pc,
    `last_Java_sp[17]`, points into `Interpreter`).
- **Probe internals** (verified with gdb on the reference build):
  - The C2 runtime stub frame (`new_instance_blob`) is 2 words, so the nmethod return pc is
    `last_Java_sp[1]`.
  - The `store_value_type_fields_to_buf_blob` frame is 18 words.
  - Offsets: `KLASS_NAME=24 SYMBOL_LENGTH=4 SYMBOL_BODY=6 THREAD_LAST_JAVA_SP=1128`.
- **Hibernate histogram, preview only.** Lambda instances (`AbstractEntityPersister$$Lambda`,
  `SessionImpl$$Lambda`, ...) also appear. They are identity objects, which hints at
  escape-analysis or inlining differences under preview, not value-object materialization. Not
  investigated yet.
- **Idea, not implemented:** route C2 buffer allocations (`AllocateNode` with a `ValueType` input,
  or a sticky flag, since that input is sometimes cleared) to a separate slow-path stub, e.g.
  `new_value_buffer_C`. Profilers and uprobes would then name them directly.

## 3. Environments

- **isx container `valhalla`** (template `tpl-mw-valhalla`, Fedora 45, kernel 7.1). Everything
  except BPF was done here.
  - Unprivileged LXC: tracefs, `bpf()` for tracing and uprobe `perf_event_open` are refused even
    for root.
  - `/dev/kvm` is absent.
  - The clock jumps between tool calls, so `sleep`-based polling looks erratic; judge progress by
    files.
- **isx VM instance** (template with `type: vm`, see `docs/bpf-context.md` "Chosen route"). BPF
  works there. The first attempt on a host had crashed bpftrace (SIGSEGV); the VM fixed the BPF
  issues. **Still to record:** bpftrace and kernel versions, and whether anything else was
  changed to make it work.
- Paths in the container:
  - this directory: `~/src/colata/mw-valhalla-999/alloc-exp` (untracked in the colata repo);
  - JDK: `~/src/jdk/build/release-linux-x86_64/images/jdk`;
  - debuginfo: `.../support/modules_libs/java.base/server/libjvm.debuginfo`;
  - async-profiler: `~/src/async-profiler`.
- In the VM, as transferred, the scripts take `JAVA_HOME_EXP` and `LIBJVM_DEBUGINFO`; all other
  paths are relative to this directory.
- JDK configure line and the debug-symbol defaults: `docs/DETAILS.md`, "JDK build configuration".

## 4. State of the work

- **Done and reproducible:** scenarios, ground-truth histogram, JFR (sampled/exact) and
  async-profiler recordings, analyzer with classification and baseline diff, gdb probe, BPF probe
  scripts, BPF smoke-test script, feature request, docs. `scripts/run-all.sh` plus
  `scripts/run-probes-gdb.sh` regenerate everything except BPF into `target/`.
- **README** was rewritten for users: each invocation with its output. Step 6 (BPF) has a
  placeholder (`<!-- BPF-RESULTS ... -->`).
- **`target/`** holds the outputs from the last full run in the container.

## 5. BPF fill-in (to do in the VM)

1. Set up as in `docs/bpf-context.md` "Chosen route", step 3:
   ```bash
   cd <alloc-exp>
   export JAVA_HOME_EXP=<jdk> LIBJVM_DEBUGINFO=<libjvm.debuginfo>
   scripts/build.sh && scripts/offsets.sh       # offsets must be 24/4/6/1128 for the same JDK build
   ```
2. Record the environment and what made BPF work, in `docs/bpf-context.md` section 3:
   ```bash
   { uname -r; head -2 /etc/os-release; bpftrace --version; "$JAVA_HOME_EXP/bin/java" -version 2>&1; } > target/probe-bpf-env.txt
   ```
   Ask the user what, if anything, was changed besides moving to the VM.
3. Run the probes. Each preview run is 5 × 1M iterations and should take well under a minute;
   use short timeouts and check the output files:
   ```bash
   sudo JAVA_HOME_EXP="$JAVA_HOME_EXP" LIBJVM_DEBUGINFO="$LIBJVM_DEBUGINFO" scripts/run-probes-bpf.sh
   ```
4. Check against the expectations (`docs/bpf-context.md` T4):
   - `cached-call identity`: no `java.lang.Integer` lines.
   - Each preview run: ≈ 5M `C2  OptoRuntime::new_instance_C` `java.lang.Integer`, resolved to
     `cachedCall()` / `flatFieldLoad()` / `fresh()`.
   - Cross-check totals with `scripts/histogram.sh 5`. Its counts include interpreter and C1
     allocations, so compare the sum over all contexts.
   - Compare the noise share with the gdb runs (README step 5). It should be much smaller at full
     size.
5. Fill in the docs:
   - **README step 6:** replace the `<!-- BPF-RESULTS ... -->` block and the "to be filled in" line
     with the real `target/probe-bpf/cached-call-preview.txt` and a four-row table, as in step 5.
     Add the run time per probe.
   - **`docs/DETAILS.md`** "Outside a container": replace the remaining "results to be added"
     wording, and note any bpftrace-version caveats.
   - **`docs/bpf-context.md`:** mark T1/T2/T4 as done, with versions.
   - If `probe/alloc_ctx.bt.in` needed changes, keep the raw output format (section 5 of
     `bpf-context.md`) so that `probe-report.py` and the gdb probe stay compatible.
6. Optional next steps:
   - T5 in `bpf-context.md`: attribute the shared `ANY` stubs to a tier with the 18-word frame.
   - Apply the JFR/async-profiler flow to the real Hibernate workload (`docs/DETAILS.md` section 5).
   - Investigate the lambda increase.
   - Prototype the separate buffer-allocation stub.

## 6. User preferences and conventions

- Every output in this directory must be reproducible by a script, with the README showing the
  invocation and the expected result. The README is for users; internals go in `docs/`.
- Readable output: one frame per line.
- Output directory: `target/`.
- Use short tool timeouts (about 1–2 min). Run long jobs in the background with `nohup` and poll.
  Never wait 15 minutes on a hung command.
- Local commits are fine; don't push or open PRs unless asked. Ask when something is ambiguous.

## 7. Gotchas learned

- Compile `ValueAllocs` **without** `--enable-preview` (it only uses the reflective preview API
  `Class.isValue()`). A preview-version class file would refuse to run in identity mode.
- Preview variants of JDK classes live in `META-INF/preview` inside `lib/modules`. A jrt filesystem
  shows them only when opened with `Map.of("previewMode", "true")`.
- The JVM's in-process class histogram (JMX) allocates hundreds of thousands of objects. With
  `-XX:-UseTLAB` under gdb that is a huge slowdown, so the probes pass `-Dhistogram=false`.
- `scripts/offsets.sh` takes ~80 s (gdb loading 940 MB of DWARF) and is cached in
  `target/offsets.env`.
- The gdb stand-in finds the entry point by unwinding up to 6 native frames.
  `InterpreterRuntime::read_flat_field` sits 4 frames above `InstanceKlass::allocate_instance`.
- `pkill -f <pattern>` can kill the invoking shell when the pattern appears in its own command line.
- JDK JFR "Native" frames are Java native methods. In async-profiler JFR, "Native"/"C++" frames are
  C functions, with the library name as class.
- async-profiler JFR has no `jdk.JVMInformation` event, so the analyzer needs `--preview` /
  `--no-preview` (derived from the file name by `analyze.sh`).
