#!/usr/bin/env bash
# Compile the scenarios and (if missing) build async-profiler against $JAVA_HOME.
set -euo pipefail
source "$(dirname "$0")/env.sh"
"$JAVA" -version 2>&1 | head -1
rm -rf "$CLASSES" && mkdir -p "$CLASSES"
"$JAVA_HOME/bin/javac" -Xlint:-preview -d "$CLASSES" "$EXP_DIR/src/ValueAllocs.java" 2>&1 | grep -v "^Note:" || true
echo "compiled -> $CLASSES"
if [[ ! -f "$ASPROF_LIB" ]]; then
  (cd "$ASYNC_PROFILER_HOME" && make -j"$(nproc)" >/dev/null)
fi
echo "async-profiler -> $ASPROF_LIB"
