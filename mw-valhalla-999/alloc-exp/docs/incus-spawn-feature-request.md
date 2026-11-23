# Feature request (incus-spawn / isx): allow BPF tracing (bpftrace, uprobes) for an instance

## Problem

Instances are unprivileged LXC containers. Inside one, `sudo bpftrace` fails right away:

```
$ sudo bpftrace -e 'BEGIN { exit(); }'
ERROR: Failed to open kernel function info: Error reading events from /sys/kernel/tracing/available_events (Permission denied)
$ cat /proc/self/uid_map
         0    1000000       1000
      1000       1000          1
```

Root in the container is host uid 1000000, inside a user namespace. `cap_bpf`, `cap_perfmon` and
`cap_sys_admin` are in the bounding set, but the kernel checks them against the *initial* user
namespace for tracing. That covers `perf_event_open` for uprobes/kprobes, tracing BPF program
types and tracefs access. No setting *inside* the container can fix this.

Use case: JVM/HotSpot work needs uprobes on `libjvm.so` (for example, attributing heap allocations
to the C2 compiler, see `~/src/colata/mw-valhalla-999/alloc-exp`). It can also use the USDT probes of a `--enable-dtrace` JDK
build, `perf`, and async-profiler's perf-events modes (`event=cpu` with kernel stacks), which hit
the same restriction.

## Proposed options (in order of preference)

Options 2–4 below are new. Option 1 records what isx already supports and the gaps in it.

### 1. VM instances: already supported; what is missing

What isx already has (checked against https://github.com/Sanne/incus-spawn `docs/` and source):
- **`type: vm` templates.** `isx build <tpl> --type vm` or `type: vm` in a definition gives VM
  instances with isx's own kernel (7.3.5, `appliance/kernel/isx.config` + `vm.config`).
- **That kernel can run uprobe-based bpftrace.** It has `CONFIG_BPF_SYSCALL=y`,
  `CONFIG_UPROBE_EVENTS=y`, `CONFIG_KPROBE_EVENTS=y`, `CONFIG_FTRACE=y` (tracefs) and
  `CONFIG_PERF_EVENTS=y`. `CONFIG_BPF_EVENTS` has no prompt and defaults to `y`, so `allnoconfig`
  keeps it.
- **`--kvm` branches.** A container branch with `/dev/kvm` can boot nested VMs.
- **`perf_event_paranoid=-1`.** `isx init` sets it on the host. That helps perf inside containers,
  but not BPF and not uprobes.

What is missing:
- **No way to turn an existing container instance into a VM.**
  - `isx branch --from <instance>` is a copy-on-write clone of the same type.
  - `docs/SANDBOXES.md` mentions `isx branch --vm`, but `docs/CLI.md` has no such option.
  - A VM template whose parent is a container is rebuilt from definitions, so an instance's work
    (checkouts, builds) does not carry over.
  - Request: `isx branch <name> --from <container-instance> --type vm`, which builds or reuses the VM
    variant of the template and copies the instance's home directory (or chosen paths) into the
    new VM. Alternatively, `isx copy-files <from> <to> <path>` between instances.
- **No BTF in the VM kernel** (`CONFIG_DEBUG_INFO=n`, hence no `CONFIG_DEBUG_INFO_BTF`). Uprobe
  scripts that only read user memory (like `probe/alloc_ctx.bt.in`) do not need BTF. bpftrace
  features that use kernel types (kfuncs, `struct task_struct` access, `kptr` helpers) do, and tools
  such as `bcc` CO-RE tools need it too.
  - Request: `CONFIG_DEBUG_INFO_BTF=y` in `vm.config`. It needs `CONFIG_DEBUG_INFO` and pahole at
    build time, and makes vmlinux larger; the BTF itself is a few MB.
- **Docs.** `docs/SANDBOXES.md` lists "install `bpftrace` and write a probe" as something an isx
  agent can do. In a container instance that fails: tracefs, `bpf()` for tracing programs and
  uprobe `perf_event_open` all need host-level capabilities (verified: even root inside gets
  `EACCES` from `perf_event_open` with the `uprobe` PMU). The docs should say this needs
  `type: vm`, or host-side tracing.

### 2. Host-side tracing helper: `isx trace <instance> [-p PID] -- <bpftrace args>`

The instance stays unprivileged; bpftrace runs on the host as root, scoped to the instance.

- Rewrite `uprobe:/path/in/instance/libjvm.so:sym` to `uprobe:/proc/<host-pid>/root/path/...:sym`.
  bpftrace resolves symbols through `/proc/PID/root`.
- Map a PID inside the instance to the host PID (from `NSpid` in `/proc/<pid>/status`, or
  `incus info`). Add a filter on the instance's cgroup so that only its processes are traced:
  `cgroup == cgroupid("/sys/fs/cgroup/lxc.payload.<name>")`.
- Write the output back into the instance, e.g. `incus file push`, or a shared directory.
- Costs: needs host root (or a narrowly-scoped sudo rule for this helper). Scripts that use
  `-c CMD` must instead attach to an already-running process (`-p`), or the helper must start the
  command inside the instance and then attach.

### 3. Opt-in privileged containers (`security.privileged=true`)

Example: `isx spawn --privileged-tracing`.

- Root in the container is host root, so bpftrace works as-is once tracefs is reachable
  (`/sys/kernel/tracing` is mounted by default in privileged containers).
- **Not recommended as a default.** Isolation is largely gone: tracing BPF can observe the
  whole host, including other instances and the credential-injecting proxy. That conflicts with
  the threat model of the TLS proxy (credentials must never be visible inside instances).
  Acceptable only for single-user hosts with no credentials configured, behind an explicit flag.

### 4. (Future) BPF token delegation

Linux 6.9+ can delegate selected BPF commands, program types and attach types to a user
namespace through a bpffs instance mounted with `delegate_*` options. Recent Incus/LXD releases
are adding configuration for this. Check the installed Incus version for `security.bpffs.*` /
delegation keys before relying on it. Today it is **not sufficient** for this use case:
uprobes are still attached through `perf_event_open`/tracefs, which need host-level
`CAP_PERFMON`, and bpftrace does not use BPF tokens yet. It is worth tracking, because it is the
only option that would keep instances unprivileged and still allow in-instance tracing.

## Acceptance test

Inside a spawned instance (option 1 or 3), or through the helper (option 2):

```
sudo bpftrace -e 'BEGIN { printf("ok\n"); exit(); }'
cd ~/src/colata/mw-valhalla-999/alloc-exp && sudo -E scripts/probe-bpf.sh cached-call preview
```

The second command should print the same kind of report as `target/probe-gdb/cached-call-preview.txt`.
