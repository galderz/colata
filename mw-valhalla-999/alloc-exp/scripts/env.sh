# Common settings, sourced by every script. Override any variable from the environment.
EXP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export JAVA_HOME="${JAVA_HOME_EXP:-$HOME/src/jdk/build/release-linux-x86_64/images/jdk}"
JAVA="$JAVA_HOME/bin/java"
ASYNC_PROFILER_HOME="${ASYNC_PROFILER_HOME:-$HOME/src/async-profiler}"
ASPROF_LIB="$ASYNC_PROFILER_HOME/build/lib/libasyncProfiler.so"
CLASSES="$EXP_DIR/build/classes"
TARGET="$EXP_DIR/target"

# JVM flags shared by every scenario run:
#  - Epsilon GC: nothing is ever freed, so a final class histogram == cumulative allocations
#  - id() must stay a real call so that the value crosses a (scalarized) calling convention
COMMON_FLAGS=(
  -XX:+UnlockExperimentalVMOptions -XX:+UseEpsilonGC -Xmx6g
  -XX:CompileCommand=quiet -XX:CompileCommand=dontinline,ValueAllocs::id
)

SCENARIOS=(fresh cached-call flat-field)
MODES=(identity preview)

# mode -> extra JVM flags
mode_flags() {
  case "$1" in
    identity) ;;                       # Integer is an identity class
    preview)  echo "--enable-preview" ;; # Integer is a value class (JEP 401)
    *) echo "unknown mode '$1' (identity|preview)" >&2; exit 1 ;;
  esac
}

# libjvm debug info (needed by offsets.sh and probe-gdb.sh). A JDK build keeps it in support/.
LIBJVM="$JAVA_HOME/lib/server/libjvm.so"
LIBJVM_DEBUGINFO="${LIBJVM_DEBUGINFO:-}"
if [[ -z "$LIBJVM_DEBUGINFO" ]]; then
  for c in "$JAVA_HOME/lib/server/libjvm.debuginfo" "$JAVA_HOME/../../support/modules_libs/java.base/server/libjvm.debuginfo"; do
    [[ -f "$c" ]] && LIBJVM_DEBUGINFO="$(realpath "$c")" && break
  done
fi
# --with-native-debug-symbols=internal: the DWARF is inside libjvm.so itself
if [[ -z "$LIBJVM_DEBUGINFO" ]] && readelf -S "$LIBJVM" 2>/dev/null | grep -q '\.debug_info'; then
  LIBJVM_DEBUGINFO="$(realpath "$LIBJVM")"
fi
