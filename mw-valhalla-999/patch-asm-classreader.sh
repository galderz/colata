#!/usr/bin/env bash
#
# patch-asm-classreader.sh — Patch ASM's ClassReader to accept JDK 28
# class files (major version 72).
#
# Background:
#   ASM 9.10.1 (used by Quarkus for bytecode transformation at build time)
#   only supports class file major versions up to 71 (JDK 27).  JDK 28
#   (Valhalla) produces class files with major version 72, causing Quarkus's
#   ClassTransformingBuildStep to fail with:
#
#     java.lang.IllegalArgumentException: Unsupported class file major version 72
#       at org.objectweb.asm.ClassReader.<init>(ClassReader.java:200)
#
#   This script patches the ClassReader class in all cached ASM jars by
#   changing the max-version check from 71 to 72 (a single-byte change).
#
# Usage:
#   ./patch-asm-classreader.sh
#
# What it does:
#   1. Finds all asm-*.jar files in the local Maven repository.
#   2. Detects whether each jar needs patching by extracting ClassReader.class
#      and inspecting the version-check bytecode.
#   3. Applies a single-byte binary patch: changes "bipush 71" (0x10 0x47)
#      to "bipush 72" (0x10 0x48) in the constructor's version check.
#   4. Updates each jar in-place.
#
# The script is idempotent — it detects whether a jar is already patched
# and skips it.
#
# Technical detail:
#   In ClassReader.<init>([BIZ), the version check reads:
#
#     bipush 71        ; max supported class file major version
#     if_icmple <ok>   ; if classVersion <= 71, continue
#     new IllegalArgumentException
#     ...
#     athrow
#
#   The byte sequence is: 0x10 0x47 0xA4 (bipush 71, if_icmple)
#   We change the 0x47 (71) to 0x48 (72) to accept JDK 28 class files.

set -euo pipefail

# ── Locate ASM jars ─────────────────────────────────────────────────────────

M2_REPO="${HOME}/.m2/repository"
if [[ ! -d "$M2_REPO" ]]; then
    echo "ERROR: Maven local repository not found at $M2_REPO" >&2
    exit 1
fi

mapfile -t ASM_JARS < <(
    find "$M2_REPO/org/ow2/asm" -name "asm-*.jar" \
         ! -name "*-sources.jar" ! -name "*-javadoc.jar" 2>/dev/null
)

if [[ ${#ASM_JARS[@]} -eq 0 ]]; then
    echo "    No ASM jars found in Maven repository. Nothing to patch."
    exit 0
fi

# ── Detection ────────────────────────────────────────────────────────────────
# Check the ClassReader.class for the byte sequence: bipush 71 if_icmple
# (0x10 0x47 0xA4).  If found, the jar needs patching.  If the sequence is
# 0x10 0x48 0xA4 (bipush 72), it's already patched.

needs_patch() {
    local jar="$1"
    local class_bytes
    class_bytes=$(unzip -p "$jar" org/objectweb/asm/ClassReader.class 2>/dev/null | od -An -tx1 -v | tr -d ' \n')
    if [[ -z "$class_bytes" ]]; then
        return 1  # class not present in jar
    fi
    # Look for bipush-71 if_icmple: 10 47 a4
    if echo "$class_bytes" | grep -q "1047a4"; then
        return 0  # needs patching
    else
        return 1  # already patched or different version
    fi
}

# ── Check if any work is needed ──────────────────────────────────────────────

ANY_NEED_PATCH=false
for jar in "${ASM_JARS[@]}"; do
    if needs_patch "$jar"; then
        ANY_NEED_PATCH=true
        break
    fi
done

if [[ "$ANY_NEED_PATCH" == false ]]; then
    echo "    All ASM jars already patched (or max version >= 72). Nothing to do."
    exit 0
fi

# ── Patch each jar ──────────────────────────────────────────────────────────

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

PATCHED_COUNT=0
SKIPPED_COUNT=0

for jar in "${ASM_JARS[@]}"; do
    if needs_patch "$jar"; then
        echo "    Patching: $jar"

        # Extract ClassReader.class
        mkdir -p "$WORK_DIR/extract"
        (cd "$WORK_DIR/extract" && jar xf "$jar" org/objectweb/asm/ClassReader.class 2>/dev/null)

        CLASS_FILE="$WORK_DIR/extract/org/objectweb/asm/ClassReader.class"
        if [[ ! -f "$CLASS_FILE" ]]; then
            echo "    WARNING: ClassReader.class not found in $jar, skipping"
            SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
            continue
        fi

        # Apply the binary patch: bipush 71 → bipush 72
        python3 -c "
import sys
data = open('$CLASS_FILE', 'rb').read()
# bipush 71 if_icmple = 0x10 0x47 0xa4
pattern = bytes([0x10, 71, 0xa4])
idx = data.find(pattern)
if idx < 0:
    print('ERROR: byte pattern not found', file=sys.stderr)
    sys.exit(1)
patched = data[:idx+1] + bytes([72]) + data[idx+2:]
# Verify only one occurrence
if patched.find(pattern) >= 0:
    print('WARNING: multiple occurrences of pattern found', file=sys.stderr)
open('$CLASS_FILE', 'wb').write(patched)
"

        # Update the jar in-place
        (cd "$WORK_DIR/extract" && jar uf "$jar" org/objectweb/asm/ClassReader.class)

        # Clean up extracted files for next iteration
        rm -rf "$WORK_DIR/extract"

        PATCHED_COUNT=$((PATCHED_COUNT + 1))
    else
        echo "    Already patched: $(basename "$jar")"
        SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
    fi
done

echo
echo "    Done. Patched: $PATCHED_COUNT, Already patched: $SKIPPED_COUNT"
