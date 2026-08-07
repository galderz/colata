#!/usr/bin/env bash
#
# patch-bnd-stackmap.sh — Patch the bnd OSGi plugin to handle Valhalla
# preview stack map frame types (JDK 28+).
#
# Background:
#   bnd's class-file parser (StackMapTableAttribute.java) treats frame types
#   128–246 as "RESERVED" and throws an IOException when encountered.  JDK 28
#   with --enable-preview (Valhalla value types) emits frame type 246, causing
#   the Gradle :jar task to fail with:
#
#     error: Invalid class file org/hibernate/engine/spi/EntityKey.class
#            (Unrecognized stack map frame type 246)
#     > Bundle hibernate-core-…jar has errors
#
#   This script patches the StackMapTableAttribute class in all cached bnd
#   jars so that reserved/unknown frame types are skipped gracefully instead
#   of causing a build failure.
#
# Usage:
#   ./patch-bnd-stackmap.sh [JAVA_HOME]
#
#   JAVA_HOME defaults to $JAVA_25_HOME or $JAVA_HOME.  Any JDK >= 17 works
#   for compiling the patch; this does NOT need to be the Valhalla JDK.
#
# What it does:
#   1. Finds all biz.aQute.bnd.util-*.jar files in the Gradle cache.
#   2. Extracts the embedded StackMapTableAttribute.java source.
#   3. Applies a one-line sed patch: replaces the IOException throw for
#      reserved frame types with a graceful no-op SameFrame fallback.
#   4. Compiles the patched source and updates each jar in-place.
#   5. Deletes Gradle's instrumented-jar transform cache so it regenerates
#      from the patched originals on the next build.
#
# The script is idempotent — it detects whether a jar is already patched
# (by checking for the "Unrecognized stack map frame type" string literal
# in the class constant pool) and skips it.
#
# After patching, any running Gradle daemon must be restarted
# (./gradlew --stop) because it caches loaded classes in memory.

set -euo pipefail

# ── Resolve Java home ────────────────────────────────────────────────────────

PATCH_JAVA_HOME="${1:-${JAVA_25_HOME:-${JAVA_HOME:-}}}"
if [[ -z "$PATCH_JAVA_HOME" ]]; then
    echo "ERROR: No JDK found. Pass JAVA_HOME as argument, or set JAVA_25_HOME / JAVA_HOME." >&2
    exit 1
fi
JAVAC="$PATCH_JAVA_HOME/bin/javac"
JAR_TOOL="$PATCH_JAVA_HOME/bin/jar"
if [[ ! -x "$JAVAC" || ! -x "$JAR_TOOL" ]]; then
    echo "ERROR: javac or jar not found in $PATCH_JAVA_HOME/bin" >&2
    exit 1
fi

# ── Locate original bnd util jars ────────────────────────────────────────────
# We only look for the original (non-instrumented) jars under modules-2/.
# Gradle's instrumented copies in the transforms/ cache are derived from these
# and will be regenerated automatically after we patch the originals and clear
# the transform cache.

GRADLE_CACHE="$HOME/.gradle/caches"
if [[ ! -d "$GRADLE_CACHE" ]]; then
    echo "ERROR: Gradle cache not found at $GRADLE_CACHE" >&2
    exit 1
fi

mapfile -t BND_JARS < <(
    find "$GRADLE_CACHE/modules-2" -name "biz.aQute.bnd.util-*.jar" 2>/dev/null
)

if [[ ${#BND_JARS[@]} -eq 0 ]]; then
    echo "    No bnd util jars found in Gradle cache. Nothing to patch."
    exit 0
fi

# ── Detection ────────────────────────────────────────────────────────────────
# An unpatched StackMapTableAttribute has the string literal
# "Unrecognized stack map frame type" in its constant pool.  Our patch
# removes this throw, so the string disappears from the compiled class.

needs_patch() {
    local jar="$1"
    if unzip -p "$jar" aQute/bnd/classfile/StackMapTableAttribute.class 2>/dev/null \
       | strings 2>/dev/null \
       | grep -q "Unrecognized stack map frame type"; then
        return 0  # needs patching
    else
        return 1  # already patched or class not present
    fi
}

# ── Check if any work is needed ──────────────────────────────────────────────

ANY_NEED_PATCH=false
for jar in "${BND_JARS[@]}"; do
    if needs_patch "$jar"; then
        ANY_NEED_PATCH=true
        break
    fi
done

if [[ "$ANY_NEED_PATCH" == false ]]; then
    echo "    All bnd util jars already patched. Nothing to do."
    exit 0
fi

# ── Build the patched class (once) ──────────────────────────────────────────

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

# Pick the first jar that needs patching as the compilation classpath
# (it has the original source embedded).
COMPILE_JAR=""
for j in "${BND_JARS[@]}"; do
    if needs_patch "$j"; then
        COMPILE_JAR="$j"
        break
    fi
done

# Extract the original source from the jar's OSGI-OPT directory.
ORIGINAL_SRC="$WORK_DIR/StackMapTableAttribute.original.java"
if ! unzip -p "$COMPILE_JAR" OSGI-OPT/src/aQute/bnd/classfile/StackMapTableAttribute.java \
     > "$ORIGINAL_SRC" 2>/dev/null || [[ ! -s "$ORIGINAL_SRC" ]]; then
    echo "ERROR: Could not extract StackMapTableAttribute.java source from $COMPILE_JAR" >&2
    exit 1
fi

# Apply the patch: replace the IOException throw with a graceful fallback.
PATCHED_SRC="$WORK_DIR/StackMapTableAttribute.java"
sed 's/throw new IOException("Unrecognized stack map frame type " + frame_type);/entries[i] = new SameFrame(frame_type); \/\/ Patched: skip unknown Valhalla frame types/' \
    "$ORIGINAL_SRC" > "$PATCHED_SRC"

# Verify the sed actually changed something.
if diff -q "$ORIGINAL_SRC" "$PATCHED_SRC" > /dev/null 2>&1; then
    echo "WARNING: Source patch had no effect — source format may have changed." >&2
    echo "         The IOException-throwing line was not found in:" >&2
    echo "         $COMPILE_JAR" >&2
    exit 1
fi

echo "    Compiling patched StackMapTableAttribute..."
"$JAVAC" -cp "$COMPILE_JAR" -d "$WORK_DIR/classes" "$PATCHED_SRC"

# ── Patch each jar ──────────────────────────────────────────────────────────

PATCHED_COUNT=0
SKIPPED_COUNT=0

for jar in "${BND_JARS[@]}"; do
    if needs_patch "$jar"; then
        echo "    Patching: $jar"
        (cd "$WORK_DIR/classes" && "$JAR_TOOL" uf "$jar" aQute/bnd/classfile/StackMapTableAttribute*.class)
        PATCHED_COUNT=$((PATCHED_COUNT + 1))
    else
        echo "    Already patched: $(basename "$jar")"
        SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
    fi
done

# ── Clear Gradle's instrumented-jar transform cache ─────────────────────────
# Gradle caches instrumented copies of dependency jars under
# caches/<version>/transforms/.  These are derived from the originals we just
# patched, so we delete them to force regeneration on the next build.

CLEARED_TRANSFORMS=0
while IFS= read -r transform_jar; do
    transform_dir="$(dirname "$transform_jar")"
    # Walk up to the transform hash directory (…/transforms/<hash>/…)
    while [[ "$(basename "$(dirname "$transform_dir")")" != "transforms" && "$transform_dir" != "/" ]]; do
        transform_dir="$(dirname "$transform_dir")"
    done
    if [[ "$(basename "$(dirname "$transform_dir")")" == "transforms" && -d "$transform_dir" ]]; then
        echo "    Clearing transform cache: $transform_dir"
        rm -rf "$transform_dir"
        CLEARED_TRANSFORMS=$((CLEARED_TRANSFORMS + 1))
    fi
done < <(find "$GRADLE_CACHE" -path "*/transforms/*/instrumented-biz.aQute.bnd.util-*.jar" 2>/dev/null)

echo
echo "    Done. Patched: $PATCHED_COUNT, Skipped: $SKIPPED_COUNT, Transforms cleared: $CLEARED_TRANSFORMS"

if [[ $PATCHED_COUNT -gt 0 ]]; then
    echo
    echo "    IMPORTANT: Restart any running Gradle daemons so they pick up"
    echo "    the patched classes:"
    echo
    echo "      ./gradlew --stop"
    echo
fi
