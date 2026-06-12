#!/bin/bash
# Option A: Cross-compile JDK for riscv64 using Fedora cross-compiler + Debian sysroot
# Step 4: Build both release and fastdebug JDKs

set -euo pipefail

JDK_SRC="${JDK_SRC:-$HOME/jdk}"
JOBS="${JOBS:-$(nproc)}"

SYSROOT="${SYSROOT:-/opt/riscv64-sysroot}"

cd "${JDK_SRC}"

for variant in release fastdebug; do
    CONF="linux-riscv64-server-${variant}"
    echo "=== Building JDK for riscv64 (${variant}) ==="
    echo "Source:  ${JDK_SRC}"
    echo "Jobs:    ${JOBS}"
    echo ""

    # For fastdebug: statically link capstone into hsdis so the library
    # works on the target without needing libcapstone.so installed
    SPEC="${JDK_SRC}/build/${CONF}/spec.gmk"
    if [ "$variant" = "fastdebug" ] && grep -q 'HSDIS_LIBS.*-lcapstone' "$SPEC" 2>/dev/null; then
        CAPSTONE_A="${SYSROOT}/usr/lib/riscv64-linux-gnu/libcapstone.a"
        if [ -f "$CAPSTONE_A" ]; then
            echo "Patching spec.gmk to statically link capstone into hsdis..."
            sed -i "s|^HSDIS_LIBS := -lcapstone|HSDIS_LIBS := ${CAPSTONE_A}|" "$SPEC"
        fi
    fi

    make CONF="${CONF}" images JOBS="${JOBS}" "$@"

    JDK_IMAGE="${JDK_SRC}/build/${CONF}/images/jdk"
    echo ""
    echo "=== Build complete (${variant}) ==="
    file "${JDK_IMAGE}/bin/java"
    echo ""
done

echo "Both builds complete. Next step: run 05-package.sh"
