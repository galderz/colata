#!/bin/bash
set -euo pipefail

BINUTILS_VERSION=2.38
CACHE_DIR="${HSDIS_CACHE_DIR:-$HOME/Library/Caches/jdk17-build-stubs}"

usage() {
  echo "Usage: $0 <jdk-source-tree>"
  echo ""
  echo "Builds and installs the hsdis disassembler plugin for JDK 17."
  echo "Requires: cc, make, zlib headers (-lz)."
  echo ""
  echo "Environment variables:"
  echo "  HSDIS_CACHE_DIR  Where to cache binutils source and build (default: ~/Library/Caches/jdk17-build-stubs)"
  exit 1
}

if [ $# -ne 1 ]; then
  usage
fi

JDK_SRC="$(cd "$1" && pwd)"
HSDIS_SRC="$JDK_SRC/src/utils/hsdis"

if [ ! -f "$HSDIS_SRC/hsdis.c" ]; then
  echo "Error: $HSDIS_SRC/hsdis.c not found. Is '$1' a JDK source tree?" >&2
  exit 1
fi

CPU=$(uname -m)
case "$CPU" in
  arm64)  ARCH=aarch64 ;;
  x86_64) ARCH=amd64 ;;
  *)      ARCH="$CPU" ;;
esac

BUILD_CONFIG=$(ls "$JDK_SRC/build/" 2>/dev/null | head -1)
if [ -z "$BUILD_CONFIG" ]; then
  echo "Error: no build configuration found in $JDK_SRC/build/. Build the JDK first." >&2
  exit 1
fi

JDK_SERVER_DIR="$JDK_SRC/build/$BUILD_CONFIG/images/jdk/lib/server"
if [ ! -f "$JDK_SERVER_DIR/libjvm.dylib" ] && [ ! -f "$JDK_SERVER_DIR/libjvm.so" ]; then
  echo "Error: libjvm not found in $JDK_SERVER_DIR. Run 'make images' first." >&2
  exit 1
fi

BINUTILS_SRC="$CACHE_DIR/binutils-$BINUTILS_VERSION"
BINUTILS_BUILD="$CACHE_DIR/binutils-build"
HSDIS_OUT="$HSDIS_SRC/build/macosx-$ARCH"

OS=$(uname -s)
case "$OS" in
  Darwin) LIB_EXT=.dylib ;;
  *)      LIB_EXT=.so ;;
esac

HSDIS_LIB="hsdis-$ARCH$LIB_EXT"

mkdir -p "$CACHE_DIR"

if [ ! -d "$BINUTILS_SRC" ]; then
  echo "Downloading binutils $BINUTILS_VERSION..."
  curl -L "https://ftp.gnu.org/gnu/binutils/binutils-${BINUTILS_VERSION}.tar.gz" \
    | tar xz -C "$CACHE_DIR"
  touch "$BINUTILS_SRC/bfd/doc/bfd.info"
fi

if [ ! -f "$BINUTILS_BUILD/opcodes/libopcodes.a" ]; then
  echo "Building binutils $BINUTILS_VERSION..."
  rm -rf "$BINUTILS_BUILD"
  mkdir -p "$BINUTILS_BUILD"

  CONFIGURE_ARGS="--disable-nls --with-system-zlib"
  if [ "$ARCH" = "aarch64" ]; then
    CONFIGURE_ARGS="$CONFIGURE_ARGS --enable-targets=aarch64-darwin"
  fi

  (cd "$BINUTILS_BUILD" && \
    CC=cc CFLAGS="-m64 -fPIC -O" \
    "$BINUTILS_SRC/configure" $CONFIGURE_ARGS)

  make -C "$BINUTILS_BUILD" -j"$(sysctl -n hw.ncpu 2>/dev/null || nproc)" \
    all-opcodes all-bfd all-libiberty
fi

echo "Compiling hsdis..."
mkdir -p "$HSDIS_OUT"

cc -o "$HSDIS_OUT/$HSDIS_LIB" \
  -m64 -fPIC -O \
  -I"$BINUTILS_SRC/include" \
  -I"$BINUTILS_BUILD/bfd" \
  -I"$BINUTILS_SRC/bfd" \
  -DLIBARCH_"$ARCH" -DLIBARCH=\""$ARCH"\" -DLIB_EXT=\""$LIB_EXT"\" \
  -shared \
  "$HSDIS_SRC/hsdis.c" \
  "$BINUTILS_BUILD/bfd/.libs/libbfd.a" \
  "$BINUTILS_BUILD/opcodes/libopcodes.a" \
  "$BINUTILS_BUILD/libiberty/libiberty.a" \
  -lz

echo "Installing $HSDIS_LIB into $JDK_SERVER_DIR/"
cp "$HSDIS_OUT/$HSDIS_LIB" "$JDK_SERVER_DIR/"

echo ""
echo "Done. Test with:"
echo "  $JDK_SRC/build/$BUILD_CONFIG/images/jdk/bin/java -XX:+UnlockDiagnosticVMOptions -XX:+PrintAssembly -version"
