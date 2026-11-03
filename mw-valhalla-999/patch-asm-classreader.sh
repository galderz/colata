#!/usr/bin/env bash
#
# patch-asm-classreader.sh -- Patch ASM's ClassReader to accept JDK 28
# class files (major version 72), including with --enable-preview.
#
# Background:
#   ASM libraries used by Quarkus for bytecode transformation at build time
#   may not support JDK 28 (Valhalla) class files.  There are two cases:
#
#   Case A -- ASM <= 9.10.x (max version < 72):
#     Only supports class file major versions up to 71 (JDK 27).  JDK 28
#     produces major version 72, causing:
#       java.lang.IllegalArgumentException: Unsupported class file major version 72
#     Fix: change "bipush 71" to "bipush 72" in the version check.
#     Byte sequence: 0x10 0x47 0xA4 -> 0x10 0x48 0xA4
#
#   Case B -- ASM >= 9.11 (supports major 72 but rejects preview features):
#     Has a two-part check: (1) major > 72 -> reject, (2) major == 72 AND
#     minor != 0 -> reject.  When --enable-preview is used, the compiler
#     sets minor version to 65535 (0xFFFF), causing:
#       java.lang.IllegalArgumentException: Unsupported class file version 72.65535
#     Fix: change "ifeq" (0x99) to "ifle" (0x9E) in the minor version check.
#     Since readShort() returns a signed short, 0xFFFF becomes -1, so ifle
#     accepts both 0 (non-preview) and -1 (preview).
#
# Usage:
#   ./patch-asm-classreader.sh
#
# The script is idempotent -- it detects whether a jar is already patched
# and skips it.

set -euo pipefail
#set -x

# -- Locate ASM jars ----------------------------------------------------------

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

# -- Detection -----------------------------------------------------------------
#
# Case A: bipush 71 if_icmple (0x10 0x47 0xA4) -- needs major version bump
# Case B: two-part check in ASM >= 9.11 with preview minor-version rejection
#         Pattern: iload_4 bipush_72 if_icmpne ... readShort ifeq
#         Hex:     15 04 10 48 a0 XX XX 2a 1c 07 60 b6 XX XX 99

get_class_bytes() {
    local jar="$1"
    unzip -p "$jar" org/objectweb/asm/ClassReader.class 2>/dev/null \
        | od -An -tx1 -v | tr -d ' \n'
}

needs_patch_major() {
    local class_bytes="$1"
    echo "$class_bytes" | grep -q "1047a4"
}

needs_patch_preview() {
    local class_bytes="$1"
    # Check for the two-part version check (ASM >= 9.11):
    # bipush 72 if_icmpgt present AND minor-version ifeq not yet patched
    if echo "$class_bytes" | grep -qP '1048a3'; then
        # Has the bipush-72/if_icmpgt check.  Now look for the unpatched
        # minor-version ifeq (0x99) in the specific pattern:
        # iload_4 bipush_XX if_icmpne XX XX aload_0 iload_2 iconst_4 iadd
        # invokevirtual(readShort) ifeq
        # = 15 04 10 XX a0 XX XX 2a 1c 07 60 b6 XX XX 99
        if echo "$class_bytes" | grep -qP '150410..a0....2a1c0760b6....99'; then
            return 0  # needs preview patch
        fi
    fi
    return 1
}

needs_patch() {
    local jar="$1"
    local class_bytes
    class_bytes=$(get_class_bytes "$jar")
    if [[ -z "$class_bytes" ]]; then
        return 1  # class not present in jar
    fi
    if needs_patch_major "$class_bytes" || needs_patch_preview "$class_bytes"; then
        return 0
    fi
    return 1
}

# -- Check if any work is needed -----------------------------------------------

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

# -- Patch each jar ------------------------------------------------------------

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

        # Apply binary patches as needed
        python3 -c "
import sys, re

data = open('$CLASS_FILE', 'rb').read()
patched = data
changes = 0

# Case A: bipush 71 if_icmple -> bipush 72 if_icmple
pattern_a = bytes([0x10, 71, 0xa4])
idx = patched.find(pattern_a)
if idx >= 0:
    print('      Case A: bipush 71 -> 72 (major version bump)')
    patched = patched[:idx+1] + bytes([72]) + patched[idx+2:]
    changes += 1

# Case B: preview minor-version check -- ifeq -> ifle
# Pattern: iload_4 bipush_XX if_icmpne XX XX aload_0 iload_2 iconst_4 iadd
#          invokevirtual(readShort) ifeq
# Hex:     15 04 10 XX a0 XX XX 2a 1c 07 60 b6 XX XX 99
pattern_b = re.compile(
    rb'\x15\x04\x10.\xa0..\x2a\x1c\x07\x60\xb6..\x99'
)
m = pattern_b.search(patched)
if m:
    ifeq_offset = m.start() + 14  # offset of the 0x99 (ifeq) byte
    if patched[ifeq_offset] == 0x99:
        print('      Case B: ifeq -> ifle (accept preview minor version 65535)')
        patched = patched[:ifeq_offset] + bytes([0x9e]) + patched[ifeq_offset+1:]
        changes += 1

if changes == 0:
    print('WARNING: no applicable patches found', file=sys.stderr)
    sys.exit(1)

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
