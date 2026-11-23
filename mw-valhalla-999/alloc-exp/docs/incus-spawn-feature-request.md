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

### 1. VM-backed instances (`incus launch --vm`), opt-in per template or instance

Example: `isx spawn --vm tpl-mw-valhalla` or a `vm: true` template setting.

- The instance has its own kernel, so passwordless `sudo` gives full BPF/perf/tracefs access.
  Nothing on the host is exposed.
- Copy-on-write still works: Incus VMs use block volumes on zfs/btrfs/lvm-thin, with snapshot
  and clone the same as for containers.
- Costs: slower start (seconds), memory reserved per VM, and the guest needs the
  `incus-agent` so that `incus exec`/file push work. The host-side TLS proxy and CA injection
  must work for the VM's network the same way they do for containers.
- The guest kernel must have BTF (`/sys/kernel/btf/vmlinux`) and `CONFIG_UPROBES`. Stock
  Fedora/Ubuntu cloud images have both.

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
