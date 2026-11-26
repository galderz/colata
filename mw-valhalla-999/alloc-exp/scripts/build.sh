#!/usr/bin/env bash
# Compile the scenarios and (if missing) build async-profiler against $JAVA_HOME.
set -euo pipefail
source "$(dirname "$0")/env.sh"
"$JAVA" -version 2>&1 | head -1
rm -rf "$CLASSES" && mkdir -p "$CLASSES"
"$JAVA_HOME/bin/javac" -Xlint:-preview -d "$CLASSES" "$EXP_DIR/src/ValueAllocs.java" 2>&1 | grep -v "^Note:" || true
echo "compiled -> $CLASSES"
# async-profiler is only needed by record-ap.sh. It needs a JDK with the JNI/JVMTI headers and javac,
# and the resulting library works with any JDK. An exploded build dir (build/<conf>/jdk) has no
# include/jvmti.h, so fall back to another JDK then (override with AP_JAVA_HOME).
if [[ ! -f "$ASPROF_LIB" && -d "$ASYNC_PROFILER_HOME" ]]; then
  AP_JAVA_HOME="${AP_JAVA_HOME:-}"
  if [[ -z "$AP_JAVA_HOME" ]]; then
    for c in "$JAVA_HOME" /usr/lib/jvm/java-latest-openjdk /usr/lib/jvm/java /usr/lib/jvm/*; do
      [[ -f "$c/include/jvmti.h" && -x "$c/bin/javac" ]] && AP_JAVA_HOME="$c" && break
    done
  fi
  [[ -n "$AP_JAVA_HOME" ]] || { echo "no JDK with include/jvmti.h found for async-profiler; set AP_JAVA_HOME" >&2; exit 1; }
  [[ "$AP_JAVA_HOME" == "$JAVA_HOME" ]] || echo "building async-profiler with $AP_JAVA_HOME ($JAVA_HOME has no include/jvmti.h)"
  (cd "$ASYNC_PROFILER_HOME" && make -j"$(nproc)" JAVA_HOME="$AP_JAVA_HOME" >/dev/null)
fi
if [[ -f "$ASPROF_LIB" ]]; then echo "async-profiler -> $ASPROF_LIB"
else echo "async-profiler not found at $ASYNC_PROFILER_HOME (only needed by record-ap.sh)"; fi
