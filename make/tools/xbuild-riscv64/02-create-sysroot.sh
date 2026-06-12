#!/bin/bash
# Option A: Cross-compile JDK for riscv64 using Fedora cross-compiler + Debian sysroot
# Step 2: Create a riscv64 sysroot from Debian packages
#
# This downloads riscv64 development libraries from Debian and extracts them
# into a sysroot directory that the cross-compiler can use.

set -euo pipefail

SYSROOT="${SYSROOT:-/opt/riscv64-sysroot}"
DEBIAN_MIRROR="${DEBIAN_MIRROR:-https://deb.debian.org/debian}"
DEBIAN_RELEASE="${DEBIAN_RELEASE:-trixie}"
TMPDIR_DEBS=$(mktemp -d)

echo "=== Creating riscv64 sysroot at ${SYSROOT} ==="
echo "Using Debian ${DEBIAN_RELEASE} from ${DEBIAN_MIRROR}"

sudo mkdir -p "${SYSROOT}"

# Cache the package index
PACKAGES_FILE="${TMPDIR_DEBS}/Packages"
echo "Downloading package index..."
curl -sL "${DEBIAN_MIRROR}/dists/${DEBIAN_RELEASE}/main/binary-riscv64/Packages.gz" | zcat > "${PACKAGES_FILE}"

download_and_extract() {
    local pkg="$1"
    local filename
    filename=$(awk -v pkg="$pkg" '
        /^Package: / { found = ($2 == pkg) }
        found && /^Filename: / { print $2; exit }
    ' "${PACKAGES_FILE}")

    if [ -z "$filename" ]; then
        echo "WARNING: Package ${pkg} not found in Debian ${DEBIAN_RELEASE} riscv64"
        return 1
    fi

    local url="${DEBIAN_MIRROR}/${filename}"
    local deb_file="${TMPDIR_DEBS}/${pkg}.deb"

    echo "  Downloading ${pkg}..."
    curl -sL "${url}" -o "${deb_file}"
    # Extract .deb without dpkg-deb (not available on Fedora)
    # .deb files are ar archives containing data.tar.{xz,zst,gz}
    local extract_dir="${TMPDIR_DEBS}/extract_${pkg}"
    mkdir -p "${extract_dir}"
    cd "${extract_dir}"
    ar x "${deb_file}"
    local data_tar
    data_tar=$(ls data.tar.* 2>/dev/null | head -1)
    if [ -z "$data_tar" ]; then
        echo "    WARNING: No data.tar.* found in ${pkg}"
        cd - > /dev/null
        rm -rf "${extract_dir}"
        return 1
    fi
    sudo tar xf "${data_tar}" -C "${SYSROOT}"
    cd - > /dev/null
    rm -rf "${extract_dir}" "${deb_file}"
}

# Packages needed for JDK cross-compilation
PACKAGES=(
    # C library and kernel headers
    libc6
    libc6-dev
    linux-libc-dev

    # ALSA (required even for headless)
    libasound2t64
    libasound2-dev

    # CUPS (printing)
    libcups2t64
    libcups2-dev
    libcupsimage2t64
    libcupsimage2-dev

    # Fontconfig
    libfontconfig1
    libfontconfig-dev

    # FreeType
    libfreetype6
    libfreetype-dev

    # X11 libraries
    libx11-6
    libx11-dev
    libxext6
    libxext-dev
    libxrender1
    libxrender-dev
    libxrandr2
    libxrandr-dev
    libxt6t64
    libxt-dev
    libxtst6
    libxtst-dev
    libxi6
    libxi-dev

    # zlib
    zlib1g
    zlib1g-dev

    # libpng (for FreeType)
    libpng16-16t64
    libpng-dev

    # Additional X11 deps
    x11proto-dev
    libxau6
    libxau-dev
    libxdmcp6
    libxdmcp-dev
    libxcb1
    libxcb1-dev
    libxfixes3
    libxfixes-dev
    libsm6
    libsm-dev
    libice6
    libice-dev

    # Additional deps
    libuuid1
    uuid-dev
    libexpat1
    libexpat1-dev
    libbrotli1
    libbrotli-dev
    libbz2-1.0
    libbz2-dev

    # GCC runtime libraries
    libatomic1
    libgcc-s1

    # C++ standard library (runtime and dev)
    libstdc++6
    libstdc++-14-dev

    # Capstone disassembly framework (for hsdis)
    libcapstone5
    libcapstone-dev
)

echo "Downloading and extracting ${#PACKAGES[@]} packages..."
FAILED=()
for pkg in "${PACKAGES[@]}"; do
    if ! download_and_extract "$pkg"; then
        FAILED+=("$pkg")
    fi
done

if [ ${#FAILED[@]} -gt 0 ]; then
    echo ""
    echo "WARNING: Failed to find these packages: ${FAILED[*]}"
    echo "The build may still work if they are not strictly required."
fi

# Create directory structure expected by Fedora cross-linker
# Debian uses /usr/lib/riscv64-linux-gnu/ (multiarch), but the linker
# scripts reference /lib/riscv64-linux-gnu/ with absolute paths
echo ""
echo "Creating compatibility directory structure..."
sudo mkdir -p "${SYSROOT}/lib"
sudo ln -sfn ../usr/lib/riscv64-linux-gnu "${SYSROOT}/lib/riscv64-linux-gnu"
sudo ln -sf ../usr/lib/riscv64-linux-gnu/ld-linux-riscv64-lp64d.so.1 "${SYSROOT}/lib/ld-linux-riscv64-lp64d.so.1"

# Create libatomic.so symlink (needed for linking)
sudo ln -sf libatomic.so.1 "${SYSROOT}/usr/lib/riscv64-linux-gnu/libatomic.so" 2>/dev/null || true

# Fix the GCC cross-compiler's limits.h to chain to the system limits.h
# The Fedora bare cross-compiler (--without-headers) ships a stripped limits.h
# that doesn't include syslimits.h, so system limits like IOV_MAX are missing
GCC_INC_DIR="/usr/lib/gcc/riscv64-linux-gnu/16/include"
NATIVE_GCC_INC="/usr/lib/gcc/x86_64-redhat-linux/16/include"
if [ -f "$NATIVE_GCC_INC/limits.h" ] && [ -f "$GCC_INC_DIR/limits.h" ]; then
    if ! grep -q 'syslimits' "$GCC_INC_DIR/limits.h"; then
        echo "Fixing cross-compiler limits.h to chain to system limits.h..."
        sudo cp "$NATIVE_GCC_INC/limits.h" "$GCC_INC_DIR/limits.h"
    fi
fi

# Create symlinks in sysroot for Debian multiarch arch-specific includes
# (bits/, sys/, gnu/, asm/ etc. that glibc puts under /usr/include/<arch>/)
echo "Creating multiarch include symlinks..."
ARCH_INC="${SYSROOT}/usr/include/riscv64-linux-gnu"
if [ -d "$ARCH_INC" ]; then
    for item in $(ls "$ARCH_INC/"); do
        target="${SYSROOT}/usr/include/$item"
        if [ ! -e "$target" ]; then
            sudo ln -sfn "riscv64-linux-gnu/$item" "$target"
        fi
    done
fi

# GCC 16 expects libatomic_asneeded - create linker scripts for it
GCC_LIB_DIR="/usr/lib/gcc/riscv64-linux-gnu/16/lib64/lp64d"
if [ -d "$GCC_LIB_DIR" ]; then
    echo "Creating libatomic_asneeded linker scripts..."
    sudo bash -c "echo 'GROUP ( AS_NEEDED ( -latomic ) )' > ${GCC_LIB_DIR}/libatomic_asneeded.so"
    sudo bash -c "echo 'GROUP ( AS_NEEDED ( -latomic ) )' > ${GCC_LIB_DIR}/libatomic_asneeded.a"
fi

# Set up C++ standard library headers for the cross-compiler
# The Fedora cross-compiler is bare (--with-newlib) and lacks C++ headers
# We use the native GCC 16 C++ headers (platform-independent) with
# arch-specific bits from x86_64 (close enough for JDK's needs)
echo "Setting up C++ standard library headers for cross-compiler..."
CROSS_CXX_INC="/usr/riscv64-linux-gnu/include/c++"
sudo mkdir -p "${CROSS_CXX_INC}"
sudo ln -sfn /usr/include/c++/16 "${CROSS_CXX_INC}/16"

# Create arch-specific directory with multilib support
sudo mkdir -p "${CROSS_CXX_INC}/16/riscv64-linux-gnu"
sudo cp -a /usr/include/c++/16/x86_64-redhat-linux/* "${CROSS_CXX_INC}/16/riscv64-linux-gnu/"

# GCC multilib path: the compiler searches .../riscv64-linux-gnu/lib64/lp64d/
sudo mkdir -p "${CROSS_CXX_INC}/16/riscv64-linux-gnu/lib64/lp64d"
for d in bits 32 ext; do
    sudo ln -sf "../../$d" "${CROSS_CXX_INC}/16/riscv64-linux-gnu/lib64/lp64d/$d"
done

# Create libstdc++.so symlink for linking
sudo ln -sf libstdc++.so.6 "${SYSROOT}/usr/lib/riscv64-linux-gnu/libstdc++.so" 2>/dev/null || true

# Set up Capstone prefix directory for hsdis
# JDK configure expects --with-capstone=<prefix> with include/capstone/ and lib/
CAPSTONE_PREFIX="/opt/riscv64-capstone"
if [ -d "${SYSROOT}/usr/include/capstone" ]; then
    echo "Setting up Capstone prefix at ${CAPSTONE_PREFIX}..."
    sudo mkdir -p "${CAPSTONE_PREFIX}/include" "${CAPSTONE_PREFIX}/lib"
    sudo ln -sfn "${SYSROOT}/usr/include/capstone" "${CAPSTONE_PREFIX}/include/capstone"
    for f in libcapstone.a libcapstone.so libcapstone.so.*; do
        src="${SYSROOT}/usr/lib/riscv64-linux-gnu/${f}"
        if [ -e "$src" ]; then
            sudo ln -sfn "$src" "${CAPSTONE_PREFIX}/lib/$(basename $f)"
        fi
    done
fi

# Fix absolute symlinks to be relative within the sysroot
echo ""
echo "Fixing absolute symlinks..."
sudo find "${SYSROOT}" -type l | while read -r link; do
    target=$(readlink "$link")
    if [[ "$target" == /* ]]; then
        # Convert absolute symlink to relative within sysroot
        local_target="${SYSROOT}${target}"
        if [ -e "$local_target" ]; then
            link_dir=$(dirname "$link")
            rel_target=$(realpath --relative-to="$link_dir" "$local_target")
            sudo ln -sf "$rel_target" "$link"
        fi
    fi
done

echo ""
echo "=== Sysroot created at ${SYSROOT} ==="
echo "Contents:"
du -sh "${SYSROOT}"
echo ""
echo "Key directories:"
ls -la "${SYSROOT}/usr/include/" 2>/dev/null | head -10 || echo "  (no /usr/include)"
echo "..."
ls -la "${SYSROOT}/usr/lib/" 2>/dev/null | head -10 || echo "  (no /usr/lib)"

# Cleanup
rm -rf "${TMPDIR_DEBS}"
