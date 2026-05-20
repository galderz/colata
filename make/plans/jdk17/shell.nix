{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  buildInputs = with pkgs; [
    autoconf
    gnumake
    temurin-bin-17
    zlib
  ];

  shellHook = ''
    export SOURCE_DATE_EPOCH=315532802
    export BOOT_JDK_HOME="${pkgs.temurin-bin-17}"
    export SYSROOT="$(xcrun --show-sdk-path)"

    STUB_DIR="$HOME/Library/Caches/jdk17-build-stubs"
    mkdir -p "$STUB_DIR"

    cat > "$STUB_DIR/stub-mig.sh" << 'STUB_MIG_EOF'
#!/bin/bash
SERVER_FILE=""
USER_FILE=""
HEADER_FILE=""

while [[ $# -gt 0 ]]; do
  case $1 in
    -server) SERVER_FILE="$2"; shift 2 ;;
    -user) USER_FILE="$2"; shift 2 ;;
    -header) HEADER_FILE="$2"; shift 2 ;;
    *) shift ;;
  esac
done

if [ -n "$HEADER_FILE" ]; then
  cat > "$HEADER_FILE" << 'EOF'
#ifndef _mach_exc_server_
#define _mach_exc_server_
#include <mach/mach.h>
#include <mach/message.h>
#ifdef __cplusplus
extern "C" {
#endif
extern boolean_t mach_exc_server(mach_msg_header_t *InHeadP, mach_msg_header_t *OutHeadP);
#ifdef __cplusplus
}
#endif
#endif
EOF
fi

if [ -n "$SERVER_FILE" ]; then
  cat > "$SERVER_FILE" << 'EOF'
#include <mach/mach.h>
#include <mach/message.h>
boolean_t mach_exc_server(mach_msg_header_t *InHeadP, mach_msg_header_t *OutHeadP) {
    return FALSE;
}
EOF
fi

if [ -n "$USER_FILE" ]; then
  cat > "$USER_FILE" << 'EOF'
#include <mach/mach.h>
EOF
fi

exit 0
STUB_MIG_EOF
    chmod +x "$STUB_DIR/stub-mig.sh"

    cat > "$STUB_DIR/stub-setfile.sh" << 'STUB_SETFILE_EOF'
#!/bin/bash
exit 0
STUB_SETFILE_EOF
    chmod +x "$STUB_DIR/stub-setfile.sh"

    export OPENJDK_STUB_DIR="$STUB_DIR"

    echo ""
    echo "JDK 17 build environment ready!"
    echo "BOOT_JDK_HOME set to: $BOOT_JDK_HOME"
    echo "SYSROOT set to: $SYSROOT"
    echo ""
    echo "To build (release):"
    echo "  cd jdk"
    echo "  bash configure --with-boot-jdk=\$BOOT_JDK_HOME --with-sysroot=\$SYSROOT --disable-warnings-as-errors METAL=/usr/bin/true METALLIB=/usr/bin/true MIG=\$OPENJDK_STUB_DIR/stub-mig.sh SETFILE=\$OPENJDK_STUB_DIR/stub-setfile.sh"
    echo "  make images"
    echo ""
    echo "To build (fastdebug):"
    echo "  cd jdk"
    echo "  bash configure --with-boot-jdk=\$BOOT_JDK_HOME --with-build-jdk=\$BOOT_JDK_HOME --with-sysroot=\$SYSROOT --with-debug-level=fastdebug --disable-warnings-as-errors METAL=/usr/bin/true METALLIB=/usr/bin/true MIG=\$OPENJDK_STUB_DIR/stub-mig.sh SETFILE=\$OPENJDK_STUB_DIR/stub-setfile.sh"
    echo "  make images"
    echo "  Note: --with-build-jdk uses the boot JDK for build tools, working around a C1 assertion"
    echo "  failure (c1_LIR.hpp:416) caused by clang miscompiling the LIR_Opr pointer-as-bitfield pattern."
    echo ""
    echo "To build hsdis (disassembler plugin):"
    echo "  # Download and build binutils 2.38 (must be <= 2.38 for JDK 17 API compatibility):"
    echo "  BINUTILS_SRC=\$HOME/Library/Caches/jdk17-build-stubs/binutils-2.38"
    echo "  BINUTILS_BUILD=\$HOME/Library/Caches/jdk17-build-stubs/binutils-build"
    echo "  curl -L https://ftp.gnu.org/gnu/binutils/binutils-2.38.tar.gz | tar xz -C \$HOME/Library/Caches/jdk17-build-stubs/"
    echo "  touch \$BINUTILS_SRC/bfd/doc/bfd.info"
    echo "  mkdir -p \$BINUTILS_BUILD && cd \$BINUTILS_BUILD"
    echo "  CC=cc CFLAGS='-m64 -fPIC -O' \$BINUTILS_SRC/configure --disable-nls --enable-targets=aarch64-darwin --with-system-zlib"
    echo "  make -j\$(sysctl -n hw.ncpu) all-opcodes all-bfd all-libiberty"
    echo ""
    echo "  # Compile hsdis:"
    echo "  cd jdk/src/utils/hsdis && mkdir -p build/macosx-aarch64"
    echo "  cc -o build/macosx-aarch64/hsdis-aarch64.dylib -m64 -fPIC -O \\"
    echo "    -I\$BINUTILS_SRC/include -I\$BINUTILS_BUILD/bfd -I\$BINUTILS_SRC/bfd \\"
    echo "    -DLIBARCH_aarch64 -DLIBARCH=\\\"aarch64\\\" -DLIB_EXT=\\\".dylib\\\" \\"
    echo "    -shared hsdis.c \\"
    echo "    \$BINUTILS_BUILD/bfd/.libs/libbfd.a \$BINUTILS_BUILD/opcodes/libopcodes.a \$BINUTILS_BUILD/libiberty/libiberty.a -lz"
    echo ""
    echo "  # Install into JDK:"
    echo "  cp build/macosx-aarch64/hsdis-aarch64.dylib ../../build/macosx-aarch64-server-release/images/jdk/lib/server/"
    echo ""
    echo "  # Test: java -XX:+UnlockDiagnosticVMOptions -XX:+PrintAssembly -version"
  '';
}
