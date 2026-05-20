# Building JDK 17 in a Nix Shell on macOS (Apple Silicon)

## Nix Shell Setup

Created `shell.nix` with dependencies: `autoconf`, `gnumake`, `temurin-bin-17`, `zlib`.

The shell hook sets up:
- `SOURCE_DATE_EPOCH=315532802` — Nix's default value (315532800) breaks jar date validation which requires >= 1980-01-01 00:00:02.
- `BOOT_JDK_HOME` — points to `temurin-bin-17` (JDK 17 accepts boot JDK versions 16 or 17, per `jdk/make/conf/version-numbers.conf`).
- `SYSROOT` — detected via `xcrun --show-sdk-path`; needed because Nix provides its own SDK rather than using the system Xcode one.
- Stub scripts for `mig` and `SetFile` — `/usr/bin/mig` exists on the system but fails inside the Nix shell because Nix overrides `PATH` and `mig` can't find its sub-tools. The stub-mig script generates minimal `mach_exc` interface files directly. The stub-setfile script is a no-op (SetFile sets cosmetic Finder attributes).

## Configure

```
bash configure \
  --with-boot-jdk=$BOOT_JDK_HOME \
  --with-sysroot=$SYSROOT \
  --disable-warnings-as-errors \
  METAL=/usr/bin/true METALLIB=/usr/bin/true \
  MIG=$OPENJDK_STUB_DIR/stub-mig.sh \
  SETFILE=$OPENJDK_STUB_DIR/stub-setfile.sh
```

Flags beyond what `plan.md` specified and why they were needed:

| Flag | Reason |
|------|--------|
| `--with-sysroot` | Nix sandboxes the SDK; configure fails with "No xcodebuild tool and no system framework headers found" without it. |
| `--disable-warnings-as-errors` | Clang 21.x produces warnings on JDK 17 code (misleading indentation, implicit int-float conversion). |
| `METAL=/usr/bin/true METALLIB=/usr/bin/true` | JDK 17 unconditionally checks for Metal tools on macOS even though they're only needed for non-headless GUI rendering. |
| `MIG=.../stub-mig.sh` | Real `/usr/bin/mig` breaks inside Nix shell (can't find sub-tools due to PATH override). |
| `SETFILE=.../stub-setfile.sh` | Same PATH issue; SetFile only sets cosmetic Finder attributes so a no-op stub is fine. |

**Note:** `--enable-headless-only` was tried but doesn't work on macOS. JDK 17 never builds `libawt_headless` on macOS (see `make/modules/java.desktop/lib/Awt2dLibraries.gmk`: "Mac and Windows only use the native AWT lib, do not build libawt_headless"), but `libjawt` links against it when headless-only is enabled, causing `No rule to make target 'libawt_headless.dylib'`.

## Build

```
make images
```

Build succeeds. The built JDK is at:
```
jdk/build/macosx-aarch64-server-release/images/jdk/bin/java
```

## hsdis (Disassembler Plugin)

JDK 17 does **not** support the modern hsdis configure options (`--enable-hsdis-bundling`, `--with-capstone`, `--with-hsdis`) — those were added in JDK 19+. In JDK 17, hsdis is a standalone project under `src/utils/hsdis/` that builds against GNU binutils.

### Binutils version constraint

Must use binutils **<= 2.38**. Binutils 2.39+ changed `init_disassemble_info` from 3 to 4 arguments (added `fprintf_styled_func`), which JDK 17's `hsdis.c` doesn't handle.

### Build issues and solutions

1. **Binutils bundled zlib vs macOS headers:** Binutils' internal zlib defines `#define fdopen(fd,mode) NULL` which conflicts with macOS `stdio.h`'s `fdopen` declaration when compiled with modern clang. Fix: build binutils separately with `--with-system-zlib` (requires `zlib` in nix shell).

2. **Missing `makeinfo`:** Binutils configure complains about missing `makeinfo`. Fix: `touch $BINUTILS_SRC/bfd/doc/bfd.info`.

3. **hsdis Makefile hardcodes `CC=gcc`:** Nix shell has clang, not gcc. Fix: pass `CC=cc` or compile hsdis directly instead of using its Makefile.

4. **Library paths:** The hsdis Makefile expects binutils to be built in-tree but our separate build puts `libbfd.a` in `.libs/` subdirectory. Fix: compile hsdis directly with explicit library paths.

### Working hsdis build commands

```bash
# 1. Download binutils 2.38
BINUTILS_SRC=$HOME/Library/Caches/jdk17-build-stubs/binutils-2.38
curl -L https://ftp.gnu.org/gnu/binutils/binutils-2.38.tar.gz | tar xz -C $HOME/Library/Caches/jdk17-build-stubs/
touch $BINUTILS_SRC/bfd/doc/bfd.info

# 2. Build binutils libraries
BINUTILS_BUILD=$HOME/Library/Caches/jdk17-build-stubs/binutils-build
mkdir -p $BINUTILS_BUILD && cd $BINUTILS_BUILD
CC=cc CFLAGS='-m64 -fPIC -O' $BINUTILS_SRC/configure \
  --disable-nls --enable-targets=aarch64-darwin --with-system-zlib
make -j$(sysctl -n hw.ncpu) all-opcodes all-bfd all-libiberty

# 3. Compile hsdis
cd jdk/src/utils/hsdis && mkdir -p build/macosx-aarch64
cc -o build/macosx-aarch64/hsdis-aarch64.dylib -m64 -fPIC -O \
  -I$BINUTILS_SRC/include -I$BINUTILS_BUILD/bfd -I$BINUTILS_SRC/bfd \
  -DLIBARCH_aarch64 -DLIBARCH=\"aarch64\" -DLIB_EXT=\".dylib\" \
  -shared hsdis.c \
  $BINUTILS_BUILD/bfd/.libs/libbfd.a \
  $BINUTILS_BUILD/opcodes/libopcodes.a \
  $BINUTILS_BUILD/libiberty/libiberty.a -lz

# 4. Install
cp build/macosx-aarch64/hsdis-aarch64.dylib \
  ../../build/macosx-aarch64-server-release/images/jdk/lib/server/
```

### Verification

```
java -XX:+UnlockDiagnosticVMOptions -XX:+PrintAssembly -version
```

Produces full aarch64 disassembly (`ldr`, `cmp`, `b.eq`, `nop`, etc.).

## Fastdebug Build

Configured with `--with-debug-level=fastdebug` (all other flags same as release). The build fails during "Optimizing the exploded image" when the freshly-built fastdebug JVM runs `build.tools.jigsaw.AddPackagesAttribute`.

### Error

```
Internal Error (c1_LIR.hpp:416), pid=90199, tid=28931
assert(is_single_cpu() && !is_virtual()) failed: type check
```

Stack trace: `FrameMap::initialize()` → `Compiler::init_c1_runtime()` on the C1 CompilerThread.

### Root Cause

The crash is a clang miscompilation of the C1 `LIR_OprDesc` assertion code, not a logic bug in the JDK source. Disassembly of `FrameMap::initialize()` shows that clang generates **unconditional** calls to `report_vm_error` for the `cpu_regnr()` assertion at `c1_LIR.hpp:416` — there are no conditional branches to skip the assertion when it passes. The assertion logically should pass (the operand is `single_cpu(29)` which satisfies `is_single_cpu() && !is_virtual()`), but clang appears to exploit undefined behavior in the `LIR_Opr` pointer-as-bitfield encoding pattern (casting arbitrary integers to `LIR_OprDesc*` pointers via `(LIR_Opr)(intptr_t)(...)`) to conclude the assertion always fails.

The JDK-8287396 fix (already backported to this JDK 17) partially addressed related issues by fixing `data()` return type and `non_data_bits` calculation, but didn't fix this specific miscompilation.

The crash only manifests because the build system uses the **freshly-built fastdebug JVM** (which has assertions enabled) to run build tools during `make images`. The `BUILD_JDK` variable in `spec.gmk` defaults to `$(JDK_OUTPUTDIR)` — the newly-built JDK.

### Workarounds

**Option 1 (recommended): Use `--with-build-jdk=$BOOT_JDK_HOME` at configure time**

This tells the build system to use the boot JDK (release-mode temurin-bin-17, no assertions) for running build tools instead of the newly-built fastdebug JDK. The output fastdebug JDK is unaffected.

```
bash configure \
  --with-boot-jdk=$BOOT_JDK_HOME \
  --with-build-jdk=$BOOT_JDK_HOME \
  --with-sysroot=$SYSROOT \
  --with-debug-level=fastdebug \
  --disable-warnings-as-errors \
  METAL=/usr/bin/true METALLIB=/usr/bin/true \
  MIG=$OPENJDK_STUB_DIR/stub-mig.sh \
  SETFILE=$OPENJDK_STUB_DIR/stub-setfile.sh
make images
```

**Option 2: Disable C1 for build tools via make variable**

```
make images BUILD_JAVA_FLAGS="-Xms64M -Xmx1600M -XX:-TieredCompilation"
```

This disables tiered compilation (C1) so the fastdebug JVM never initializes `FrameMap`, avoiding the assertion entirely. The JVM uses interpreter + C2 only for build tools.
