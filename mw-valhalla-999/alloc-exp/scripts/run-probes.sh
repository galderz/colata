#!/usr/bin/env bash
# Run the allocation probes for the scenarios shown in the README: the BPF probe (README step 6)
# when bpftrace can attach uprobes here, otherwise the gdb stand-in (README step 5).
# BPF needs bpftrace and root (already root, or sudo without a password prompt); in an unprivileged
# container the uprobe attach fails, which the check below detects.
# Usage: [PROBES=auto|bpf|gdb|none] scripts/run-probes.sh      (default: auto)
# Output: target/probe-bpf/*.txt or target/probe-gdb/*.txt
set -euo pipefail
cd "$(dirname "$0")"
source ./env.sh
PROBES="${PROBES:-auto}"
case "$PROBES" in auto|bpf|gdb|none) ;; *) echo "PROBES must be auto, bpf, gdb or none" >&2; exit 1 ;; esac
[[ "$PROBES" == none ]] && { echo "probes skipped (PROBES=none)"; exit 0; }

# Both probes need the struct offsets, which offsets.sh reads from the debuginfo with gdb.
if ! command -v gdb >/dev/null || [[ -z "$LIBJVM_DEBUGINFO" ]]; then
  echo "probes skipped: they need gdb and libjvm.debuginfo (set LIBJVM_DEBUGINFO)" >&2
  [[ "$PROBES" == auto ]] && exit 0 || exit 1
fi

if [[ $EUID -eq 0 ]]; then SUDO=(); else SUDO=(sudo -n); fi

# Prints why BPF cannot be used, and fails, unless bpftrace can attach a uprobe to libjvm.so as root.
bpf_unavailable_reason() {
  local bt out
  bt=$(command -v bpftrace) || { echo "bpftrace not installed"; return 1; }
  [[ $EUID -eq 0 ]] || sudo -n true 2>/dev/null || { echo "no root (sudo needs a password)"; return 1; }
  # BEGIN fires only after every probe is attached, so "bpf-ok" proves the uprobe attach worked.
  out=$(timeout 120 "${SUDO[@]}" "$bt" -e "uprobe:$(realpath "$LIBJVM"):_ZN13InstanceKlass17allocate_instanceEP10JavaThread { exit(); }
    BEGIN { printf(\"bpf-ok\n\"); exit(); }" 2>&1) || true
  grep -q bpf-ok <<<"$out" || { echo "bpftrace cannot attach a uprobe here: $(grep -v '^$' <<<"$out" | tail -1)"; return 1; }
}

run_bpf() {
  # offsets as the normal user (cached), so that the root run does not regenerate them
  [[ "$TARGET/offsets.env" -nt "$LIBJVM" ]] || ./offsets.sh >/dev/null
  "${SUDO[@]}" env JAVA_HOME_EXP="$JAVA_HOME" LIBJVM_DEBUGINFO="$LIBJVM_DEBUGINFO" "$PWD/run-probes-bpf.sh"
}

MODE="$PROBES"
if [[ "$PROBES" != gdb ]]; then
  if reason=$(bpf_unavailable_reason); then
    MODE=bpf
  elif [[ "$PROBES" == bpf ]]; then
    echo "BPF probe unavailable: $reason" >&2; exit 1
  else
    echo "BPF probe unavailable ($reason); falling back to the gdb probe (~5-10 min)"
    MODE=gdb
  fi
fi

if [[ "$MODE" == bpf ]]; then
  echo "### probes: BPF -> $TARGET/probe-bpf"
  if run_bpf; then exit 0; fi
  [[ "$PROBES" == bpf ]] && exit 1
  echo "BPF probe run failed; falling back to the gdb probe (~5-10 min)"
fi
echo "### probes: gdb -> $TARGET/probe-gdb"
./run-probes-gdb.sh
