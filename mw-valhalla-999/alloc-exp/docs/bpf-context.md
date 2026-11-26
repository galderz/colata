# BPF work: context and tasks (handoff document)

This document lets someone (a person or an agent) continue the BPF part of this experiment on a
machine where BPF works: bare metal or a VM, **not** an unprivileged container. It assumes nothing
beyond this directory (`alloc-exp/`) and a JDK built from `openjdk/jdk` at commit
`4f33273115381cd7697082fcb1bb2642dae19043`.

## 1. Goal

Count, exactly, the Java heap allocations made by **C2-compiled code** for **value objects**
(JEP 401, `--enable-preview`, where `java.lang.Integer` is a value class) that do not exist without
preview. The typical cause:
- C2 scalarizes a value (keeps it in registers),
- then has to create a heap copy at an escape point,
- while the identity world would just pass the existing reference.

BPF's role is the HotSpot-side view: which runtime entry point performed each allocation (C2, C1,
interpreter, shared value-type stubs, deoptimization), which class it was, and which C2-compiled
method it came from. All of that comes with exact counts and without the JVM having to walk any
stacks.

The Java-side view (stacks, bytecodes, extra-vs-moved classification) is already done with JFR and
async-profiler; see `README.md` sections 2–3. BPF complements it; it does not replace it.

## 2. What is already established (verified in the container)

Scenario program: `src/ValueAllocs.java`. Exact `Integer` counts per mode come from
`scripts/histogram.sh` (Epsilon GC plus a class histogram at exit, 50M loop iterations):

| scenario | identity | preview | meaning |
|---|---|---|---|
| `fresh` | 50,000,293 | 50,000,318 | same objects; C2 materializes them at the `aastore` instead of at the `new` |
| `cached-call` | 293 | ~49,994,000 | **extra**: cached boxes passed through non-inlined `id(Integer)` (scalarized calling convention) get re-materialized |
| `flat-field` | 293 | 50,000,318 | **extra**: `Integer` field flattened into the holder; reading it back and letting it escape needs a new heap copy |

The probe logic was verified with a gdb stand-in (`scripts/probe-gdb.sh`, `probe/alloc_ctx_gdb.py`):
same probe point, same struct offsets, same output format. It used 300 × 1000 iterations because
gdb is slow. Expected shape (`target/probe-gdb/*.txt`):

| run | `C2 OptoRuntime::new_instance_C` | other notable contexts |
|---|---|---|
| `cached-call identity` | 0 `Integer` | ~4k interpreter start-up allocations |
| `cached-call preview` | 190,000 `Integer`, all in `ValueAllocs.cachedCall()` | ~103k `ANY store_value_type_fields_to_buf` (interpreter caller, warm-up) |
| `flat-field preview` | 190,000 `Integer`, all in `ValueAllocs.flatFieldLoad()` | ~62k `INT read_flat_field`, ~48k `C1 Runtime1::new_instance` |
| `fresh preview` | 190,000 `Integer`, all in `ValueAllocs.fresh()` | ~104k `ANY store_value_type_fields_to_buf` |

With the BPF defaults (5 × 1,000,000 iterations), expect about 5M C2 `Integer` allocations in the
preview runs, and a much smaller interpreter/C1 share than the gdb runs show.

## 3. Current status of BPF

**Update:** running in an isx VM instance (route 3 below) fixed the BPF issues; the probes work
there. What remains is to run the probes, record their output and fill in the README (step 6).
See `docs/SESSION-CONTEXT.md`, "BPF fill-in". The history below explains the original crash; T2/T3
are only needed if bpftrace fails again.


- `scripts/probe-bpf.sh` and `probe/alloc_ctx.bt.in` were written in a container where BPF is
  blocked, so they have been syntax-checked only.
- **First attempt outside the container:**
  `sudo ... scripts/probe-bpf.sh cached-call identity` failed with
  ```
  scripts/probe-bpf.sh: line 24: 107812 Segmentation fault         (core dumped) bpftrace -q -o "$RAW" "$BT" -c "$CMD"
  ```
  The crashing process is **bpftrace itself**, not the JVM: the shell reports the failure of the
  `bpftrace` command line. (A JVM crash would print a HotSpot error banner and leave
  `hs_err_pid*.log` in the current directory.)
- Unknown so far: kernel version, bpftrace version, distro, and at which point it crashed (while
  attaching, during the run, or while printing maps at exit). Task T2 collects this.

## 4. Environment requirements

- Linux x86_64 with uprobes (`CONFIG_UPROBE_EVENTS`) and BTF (`/sys/kernel/btf/vmlinux`); root.
- `bpftrace` (any recent version; newer is better), `gdb`, `python3`.
- The JDK: `images/jdk` from the build, plus `libjvm.debuginfo`. A default Linux build keeps it in
  `<build>/support/modules_libs/java.base/server/`; see `README.md` "JDK build configuration".
  Point the scripts at the JDK with `JAVA_HOME_EXP=<build>/images/jdk`, and at the debuginfo with
  `LIBJVM_DEBUGINFO=...` if it is not found automatically.
- The probes use x86_64 register conventions and stack layouts (see section 5).

### Where to run it when the work lives in an isx container (instance `valhalla`, template `tpl-mw-valhalla`)

Even root inside an isx container cannot use BPF, tracefs or uprobe `perf_event_open`. Three
routes work; details in `docs/incus-spawn-feature-request.md`.

1. **Host-side bpftrace against the container's JVM.** The host shares the kernel and sees the
   container's processes.
   - Attach with `bpftrace -p <host pid>`.
   - The uprobe path is `/proc/<host pid>/root/<path inside the container>/libjvm.so`.
   - Replace `cpid` with the host pid.
   - The perf map is in the container's `/tmp`, named after the container-side pid
     (`NSpid` in `/proc/<host pid>/status`).
2. **`isx branch <name> --from valhalla --kvm`, then a nested VM inside the branch.**
   - The copy-on-write branch keeps all state (JDK build, alloc-exp).
   - Inside the branch, `virtme-ng` boots a VM that shares the branch's root filesystem, and
     bpftrace runs in that VM.
3. **A `type: vm` template** (e.g. `tpl-mw-valhalla-vm`, `parent: tpl-mw-valhalla`).
   - The isx VM kernel has BPF + uprobes but no BTF; this probe does not need BTF.
   - State must be copied in, or rebuilt: alloc-exp, plus the JDK `images/jdk` and `libjvm.debuginfo`.

### Chosen route: a `type: vm` template (route 3), step by step

These run on the **host**, except where a step says "inside". Instance and template names are
suggestions.

1. Define and build the VM template. The whole chain is rebuilt from definitions as a VM, which
   takes a while:
   ```bash
   cat > ~/.config/incus-spawn/images/mw-valhalla-vm.yaml <<'YAML'
   name: tpl-mw-valhalla-vm
   description: tpl-mw-valhalla as a VM (own kernel, so bpftrace/uprobes work)
   parent: tpl-mw-valhalla
   type: vm
   packages:
     - bpftrace
     - gdb
   YAML
   isx build tpl-mw-valhalla-vm
   isx branch valhalla-vm --from tpl-mw-valhalla-vm --memory 16GB
   ```
   Give it ≥ 12 GB: the scenarios run with `-Xmx6g`, and bpftrace plus gdb (`offsets.sh` loads a
   941 MB debuginfo) need room too. The VM default is a quarter of host RAM, between 4 and 16 GB.
2. Copy the work from the container instance `valhalla` (sizes on the reference build):
   | what | path in `valhalla` | size |
   |---|---|---|
   | this directory without `target/` | `/home/agentuser/src/colata/mw-valhalla-999/alloc-exp` | < 1 MB |
   | JDK image | `/home/agentuser/src/jdk/build/release-linux-x86_64/images/jdk` | ~470 MB |
   | libjvm debug info | `/home/agentuser/src/jdk/build/release-linux-x86_64/support/modules_libs/java.base/server/libjvm.debuginfo` | ~940 MB |
   ```bash
   mkdir -p /tmp/xfer && cd /tmp/xfer
   incus file pull -r valhalla/home/agentuser/src/colata/mw-valhalla-999/alloc-exp .
   rm -rf alloc-exp/target alloc-exp/build
   incus file pull -r valhalla/home/agentuser/src/jdk/build/release-linux-x86_64/images/jdk .
   incus file pull valhalla/home/agentuser/src/jdk/build/release-linux-x86_64/support/modules_libs/java.base/server/libjvm.debuginfo .
   incus exec valhalla-vm -- mkdir -p /home/agentuser/xfer
   incus file push -r alloc-exp jdk libjvm.debuginfo valhalla-vm/home/agentuser/xfer/
   incus exec valhalla-vm -- chown -R agentuser: /home/agentuser/xfer
   ```
   - isx may keep instances in an Incus project; if `incus file pull valhalla/...` reports "not
     found", add `--project <p>` (see `incus list --all-projects`).
   - Instead of copying the JDK you can rebuild it inside the VM: `~/src/jdk` exists from the
     template; check out commit 4f33273 and use the configure line in `README.md`
     "JDK build configuration".
3. Inside `valhalla-vm`, as `agentuser`:
   ```bash
   cd ~/xfer/alloc-exp
   export JAVA_HOME_EXP=~/xfer/jdk LIBJVM_DEBUGINFO=~/xfer/libjvm.debuginfo
   sudo bpftrace -e 'BEGIN { printf("bpf ok\n"); exit(); }'   # T1
   scripts/build.sh && scripts/offsets.sh
   sudo JAVA_HOME_EXP="$JAVA_HOME_EXP" LIBJVM_DEBUGINFO="$LIBJVM_DEBUGINFO" scripts/bpf-smoke.sh   # T2
   ```
   Then continue with T3/T4 in section 6.
   - Keep `libjvm.debuginfo` in `~/xfer/`, **not** next to `jdk/lib/server/libjvm.so`. That rules
     out bpftrace parsing the 940 MB DWARF through the debuglink (crash hypothesis in T3, step 1).
   - The VM kernel has no BTF; bpftrace may warn about it. The probe does not use kernel types.
4. To bring results back: `incus file pull -r valhalla-vm/home/agentuser/xfer/alloc-exp/target .`
   on the host, or commit them from inside the VM.

## 5. How the probe works (precise)

Files:
- `probe/alloc_ctx.bt.in`: bpftrace template. `@LIBJVM@` and the offset placeholders are filled in
  by `scripts/probe-bpf.sh`, which writes `target/probe-bpf/alloc_ctx.bt`.
- `scripts/offsets.sh`: reads the struct offsets from the debuginfo with gdb (~80 s). Output goes to
  `target/offsets.env`, which is cached while it is newer than `libjvm.so`.
- `probe/probe-report.py`: turns the raw map dump into a report and resolves C2 return pcs with the
  perf map.

Mechanism:
1. The JVM runs with **`-XX:-UseTLAB`**. C2 then never expands the inline allocation fast path
   (`src/hotspot/share/opto/macro.cpp`, "Force slow-path allocation"; it happens after escape
   analysis, so it doesn't change which allocations exist). C1 and the interpreter also take the
   runtime path. Every Java instance allocation therefore reaches
   `InstanceKlass::allocate_instance(JavaThread*)` (`_ZN13InstanceKlass17allocate_instanceEP10JavaThread`),
   with `this` = `Klass*` in `rdi` (`arg0`) and `JavaThread*` in `rsi` (`arg1`).
2. Each runtime entry point gets a uprobe that sets a per-thread context string, and a uretprobe
   that clears it:

   | symbol | context label | reached from |
   |---|---|---|
   | `_ZN11OptoRuntime14new_instance_CEP5KlassP10JavaThread` | `C2  OptoRuntime::new_instance_C` | C2 code only |
   | `_ZN11OptoRuntime20load_unknown_value_CEP16flatArrayOopDesciP10JavaThread` | `C2  OptoRuntime::load_unknown_value_C` | C2 only |
   | `_ZN8Runtime112new_instanceEP10JavaThreadP5Klass` | `C1  Runtime1::new_instance` | C1 only |
   | `_ZN18InterpreterRuntime4_newEP10JavaThreadP12ConstantPooli` | `INT InterpreterRuntime::_new` | interpreter |
   | `_ZN18InterpreterRuntime15read_flat_fieldEP10JavaThreadP7oopDescP18ResolvedFieldEntry` | `INT InterpreterRuntime::read_flat_field` | interpreter |
   | `_ZN18InterpreterRuntime15flat_array_loadEP10JavaThreadP12arrayOopDesci` | `INT InterpreterRuntime::flat_array_load` | interpreter |
   | `_ZN13SharedRuntime30store_value_type_fields_to_bufEP10JavaThreadl` | `ANY SharedRuntime::store_value_type_fields_to_buf` | interpreter, C1 or C2 |
   | `_ZN13SharedRuntime20allocate_value_typesEP10JavaThreadP6Methodb` | `ANY SharedRuntime::allocate_value_types` | adapters (any tier) |
   | `_ZN14Deoptimization15realloc_objectsEP10JavaThreadP5frameP11RegisterMapP13GrowableArrayIP10ScopeValueES1_` | `C2  Deoptimization::realloc_objects` | C2 deopt |
   | `_ZN14Deoptimization25realloc_value_type_resultEP10ValueKlassRK11RegisterMapR13GrowableArrayI6HandleEP10JavaThread` | `C2  Deoptimization::realloc_value_type_result` | C2 deopt |

   Verify that these symbols exist in another build with
   `nm <libjvm.so> | grep -E 'new_instance_C|allocate_instanceEP10JavaThread'`. Release builds keep
   `.symtab`; the symbols are local (`t`).
3. At `allocate_instance` the probe reads the class name:
   `Symbol* = *(Klass* + KLASS_NAME)`, length = `*(u2*)(Symbol* + SYMBOL_LENGTH)`, bytes at
   `Symbol* + SYMBOL_BODY`. It counts `@alloc[context, class]`.
4. For the C2 context it also reads the return pc into the calling nmethod:
   `pc = *(*(JavaThread* + THREAD_LAST_JAVA_SP) + 8)`.
   - `_last_Java_sp` points at the C2 runtime stub frame (`new_instance_blob`), whose frame size
     is 2 words on x86_64. This was verified with gdb: `CodeCache::find_blob(sp[-1])->_frame_size == 2`
     and `sp[1]` lies in an nmethod.
   - The pc is resolved against `/tmp/perf-<pid>.map` (`-XX:+DumpPerfMapAtExit`).
5. Offsets for the reference build: `KLASS_NAME=24 SYMBOL_LENGTH=4 SYMBOL_BODY=6 THREAD_LAST_JAVA_SP=1128`.
6. The JVM is started through `bpftrace -c`, and every probe filters on `pid == cpid`. Uprobes attach
   by file path, so without the filter every JVM using that `libjvm.so` would be traced.

Raw output format (also produced by the gdb stand-in; parsed by `probe-report.py`):
```
@alloc[<context>, <class/with/slashes>]: <count>
@c2_site[<class>, <decimal pc>]: <count>
cpid=<pid>
```

## 6. Tasks

### T1: sanity check (expected: prints `bpf ok`)
```bash
sudo bpftrace -e 'BEGIN { printf("bpf ok\n"); exit(); }'
cd alloc-exp
export JAVA_HOME_EXP=<build>/images/jdk
scripts/build.sh
scripts/offsets.sh            # as the normal user; ~1.5 min
```

### T2: find what crashes bpftrace: `scripts/bpf-smoke.sh`
```bash
sudo JAVA_HOME_EXP="$JAVA_HOME_EXP" scripts/bpf-smoke.sh
```
The script runs eight steps, each adding one feature of the full probe, against a small workload
(2 × 200k iterations, `cached-call`, preview, `-XX:-UseTLAB`):

| step | adds |
|---|---|
| 0 | `BEGIN` only |
| 1 | one uprobe on `libjvm.so` by mangled name |
| 2 | `/pid == cpid/` filter with `-c` |
| 3 | user-memory reads (`Klass*` → `Symbol*`), fixed-size `str()` |
| 4 | variable-length `str()` (length read from user memory) |
| 5 | uprobe + uretprobe context pair, string-valued per-thread map, string comparison |
| 6 | return-pc read through `JavaThread::_anchor` |
| 7 | the full generated `alloc_ctx.bt` |

Output: `target/probe-bpf/smoke/` (`summary.txt`, `bpftrace-info.txt`, and per step `.bt`, `.out`,
`.err`). For a step that segfaults, it re-runs bpftrace under gdb and saves the backtrace to
`step<N>.gdb.txt`. For a symbolized backtrace, install bpftrace debug symbols first (Fedora:
`sudo dnf debuginfo-install bpftrace`; Debian/Ubuntu: the `bpftrace-dbgsym` package).
`coredumpctl gdb bpftrace` also works for the crash already on record.

Acceptance: you know the first failing step and have a backtrace.

### T3: fix or work around the crash

Hypotheses, by the step that fails first:

| first failing step | likely cause | workaround to try in `probe/alloc_ctx.bt.in` / scripts |
|---|---|---|
| 0 | broken bpftrace install or kernel feature mismatch | different bpftrace version (distro package vs the static release binary from github.com/bpftrace/bpftrace/releases) |
| 1 | symbol or debug-info parsing of the large C++ `libjvm.so` (bpftrace may parse DWARF/BTF for uprobe argument types if it finds debug info through `.gnu_debuglink`, e.g. when `libjvm.debuginfo` sits next to `libjvm.so` or is installed system-wide) | attach by address instead of name: `uprobe:<lib>:0x<offset>` with the offset from `nm`; make sure no `libjvm.debuginfo` is beside the probed `libjvm.so` (`offsets.sh` can read it from elsewhere via `LIBJVM_DEBUGINFO`); newer bpftrace |
| 2 | `-c` handling with a long command line | start the JVM separately and use `bpftrace -p <pid>`, replacing `cpid` with the pid (the JVM then needs to wait before allocating; e.g. add a `Thread.sleep` or attach early during start-up) |
| 3 | user-pointer reads in uprobe context | explicit `uptr(...)` around the pointers, e.g. `*uptr((uint64 *)(arg0 + 24))` |
| 4 | variable-length `str()` with a runtime length | fixed `str($sym + 6, 64)` and let `probe-report.py` trim (class names in this experiment are < 64 bytes) |
| 5 | string values in a per-thread map, string `==`, or uretprobe | replace context strings with integer ids (`@ctx[tid] = 1`) and map ids to labels in `probe-report.py`; if the uretprobe is the problem, drop it and set the context at entry only (each entry overwrites the previous one) |
| 6 | nested user-pointer read | split into two statements with intermediate variables |
| 7 only | number of probes or map sizes | run with half of the contexts, then bisect |

Keep changes in `probe/alloc_ctx.bt.in` (and `probe-report.py` if the output format changes). The
raw format must stay as in section 5 so that the gdb and BPF reports stay comparable.

Acceptance: `sudo JAVA_HOME_EXP=... scripts/probe-bpf.sh cached-call identity` completes and prints
a report.

### T4: full probe runs
```bash
for sm in "cached-call identity" "cached-call preview" "flat-field preview" "fresh preview"; do
  sudo JAVA_HOME_EXP="$JAVA_HOME_EXP" scripts/probe-bpf.sh $sm
done
```
Acceptance (5 × 1M iterations):
- `cached-call identity`: no `java.lang.Integer` lines.
- Each preview run: ≈ 5M `C2  OptoRuntime::new_instance_C` `java.lang.Integer`, resolved to
  `cachedCall()` / `flatFieldLoad()` / `fresh()` respectively.
- Cross-check against `scripts/histogram.sh 5`, or `ITERS=5`: the total `Integer` count from all
  contexts should match the histogram within a few thousand.
- Note the runtime: uprobe overhead is about 3 hits per allocation.

### T5 (optional): attribute the `ANY` contexts to a tier

`store_value_type_fields_to_buf` and `allocate_value_types` are shared stubs. To tell whether the
caller is the interpreter, C1 or C2, read the return pc of the stub frame and resolve it with the
perf map:
- For `store_value_type_fields_to_buf_blob` the frame size is **18 words** on the reference build,
  so the caller pc is `*(_last_Java_sp + 17*8)`. Verified with gdb: it pointed into `Interpreter`.
- Re-check the frame size on other builds with gdb:
  `p ((CodeBlob*)CodeCache::find_blob((void*)((long*)<last_Java_sp>)[-1]))->_frame_size`.
- The perf map has one entry per nmethod (no tier) and an `Interpreter` entry. With
  `-XX:-TieredCompilation`, every nmethod is C2.

### T6 (optional): the real workload
- Same probe on the Hibernate/Quarkus workload: start it with `-XX:-UseTLAB`, attach with
  `bpftrace -p`, and expect a large slowdown.
- Prefer the JFR/async-profiler flow from `README.md` section 5 for stacks.

## 7. Fallbacks if bpftrace cannot be made to work

- **perf with uprobes (no BPF programs).** Gives entry-point counts and, with the fetch arguments,
  raw `Klass*` values. It cannot follow pointers to class names, so use it to count per entry point:
  ```bash
  LIB=<build>/images/jdk/lib/server/libjvm.so
  sudo perf probe -x $LIB --add 'alloc=_ZN13InstanceKlass17allocate_instanceEP10JavaThread'
  sudo perf probe -x $LIB --add 'c2new=_ZN11OptoRuntime14new_instance_CEP5KlassP10JavaThread'
  sudo perf stat -e 'probe_libjvm:*' -- <java command line from probe-bpf.sh>
  sudo perf probe -d 'probe_libjvm:*'
  ```
- **bcc (Python).** Same logic as `alloc_ctx.bt.in`, written with `BPF(text=...)` and
  `attach_uprobe/attach_uretprobe(name=LIB, sym=...)`.
- **No BPF at all.** `scripts/probe-gdb.sh` gives the same report, slowly (about 300k allocations in
  2.5 min).

## 8. What to send back

```bash
{ uname -r; cat /etc/os-release | head -2; bpftrace --version; "$JAVA_HOME_EXP/bin/java" -version 2>&1; cat target/offsets.env; } > target/probe-bpf/env.txt
tar czf probe-bpf.tgz target/probe-bpf
```
Plus the terminal output of any failing command; bpftrace errors are not written to files.
