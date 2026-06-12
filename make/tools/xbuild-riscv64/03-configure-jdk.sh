#!/bin/bash
# Option A: Cross-compile JDK for riscv64 using Fedora cross-compiler + Debian sysroot
# Step 3: Configure the JDK build for riscv64 cross-compilation
#
# Configures both a release and a fastdebug build. The release build is used
# as the compile JDK (faster jtreg test compilation) and the fastdebug build
# is used to run the tests (required for IR verification).

set -euo pipefail

JDK_SRC="${JDK_SRC:-$HOME/jdk}"
SYSROOT="${SYSROOT:-/opt/riscv64-sysroot}"

cd "${JDK_SRC}"

# Debian multiarch paths
RISCV_LIB="${SYSROOT}/usr/lib/riscv64-linux-gnu"
RISCV_INC="${SYSROOT}/usr/include"

CAPSTONE_PREFIX="${CAPSTONE_PREFIX:-/opt/riscv64-capstone}"

configure_jdk() {
    local debug_level="$1"
    shift

    # Enable hsdis with capstone for fastdebug builds
    local hsdis_flags=()
    if [ "$debug_level" = "fastdebug" ] && [ -d "$CAPSTONE_PREFIX/include/capstone" ]; then
        hsdis_flags=(
            --with-hsdis=capstone
            --with-capstone="$CAPSTONE_PREFIX"
            --enable-hsdis-bundling
        )
    fi

    echo "=== Configuring JDK cross-build for riscv64 (${debug_level}) ==="
    echo "Source:  ${JDK_SRC}"
    echo "Sysroot: ${SYSROOT}"
    if [ ${#hsdis_flags[@]} -gt 0 ]; then
        echo "hsdis:   capstone (bundled)"
    fi
    echo ""

    bash configure \
        --openjdk-target=riscv64-linux-gnu \
        --with-sysroot="${SYSROOT}" \
        --with-toolchain-path=/usr/bin \
        --with-freetype=bundled \
        --with-alsa="${SYSROOT}/usr" \
        --with-alsa-lib="${RISCV_LIB}" \
        --with-alsa-include="${RISCV_INC}" \
        --with-cups="${SYSROOT}/usr" \
        --with-cups-include="${RISCV_INC}" \
        --with-fontconfig="${SYSROOT}/usr" \
        --with-fontconfig-include="${RISCV_INC}" \
        --with-x="${SYSROOT}/usr" \
        --with-extra-cflags="-B${RISCV_LIB}" \
        --with-extra-cxxflags="-B${RISCV_LIB}" \
        --with-extra-ldflags="-B${RISCV_LIB} -L${RISCV_LIB} -Wl,-rpath-link,${RISCV_LIB}" \
        --disable-warnings-as-errors \
        --with-debug-level="${debug_level}" \
        --with-jvm-variants=server \
        "${hsdis_flags[@]}" \
        "$@"

    echo ""
    echo "=== Configuration complete (${debug_level}) ==="
    echo ""
}

configure_jdk release "$@"
configure_jdk fastdebug "$@"

echo "Both configurations ready. Next step: run 04-build-jdk.sh"
