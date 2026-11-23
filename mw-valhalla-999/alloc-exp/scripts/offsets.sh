#!/usr/bin/env bash
# Print the HotSpot struct offsets the probes need, for the libjvm.so in $JAVA_HOME
# (they change between builds/configurations). Output: KEY=VALUE lines, also saved to target/offsets.env
set -euo pipefail
source "$(dirname "$0")/env.sh"
[[ -f "$LIBJVM_DEBUGINFO" ]] || { echo "libjvm.debuginfo not found; set LIBJVM_DEBUGINFO" >&2; exit 1; }
mkdir -p "$TARGET"
gdb -q -batch -nx \
  -ex 'printf "KLASS_NAME=%d\n", &((Klass*)0)->_name' \
  -ex 'printf "SYMBOL_LENGTH=%d\n", &((Symbol*)0)->_length' \
  -ex 'printf "SYMBOL_BODY=%d\n", &((Symbol*)0)->_body' \
  -ex 'printf "THREAD_LAST_JAVA_SP=%d\n", &((JavaThread*)0)->_anchor._last_Java_sp' \
  "$LIBJVM_DEBUGINFO" 2>/dev/null | grep -E '^[A-Z_]+=' | tee "$TARGET/offsets.env"
