#!/bin/bash
# Option A: Cross-compile JDK for riscv64 using Fedora cross-compiler + Debian sysroot
# Step 1: Install the cross-compilation toolchain from Fedora repos

set -euo pipefail

echo "=== Installing riscv64 cross-compilation toolchain ==="
sudo dnf install -y \
    gcc-riscv64-linux-gnu \
    gcc-c++-riscv64-linux-gnu \
    binutils-riscv64-linux-gnu

echo ""
echo "=== Verifying toolchain ==="
riscv64-linux-gnu-gcc --version
echo ""
echo "Toolchain installed successfully."
