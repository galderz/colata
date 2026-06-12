# Cross-compile OpenJDK for riscv64

Cross-compile OpenJDK for RISC-V 64-bit on an x86_64 host using:
- **Build system**: Fedora x86_64 with Fedora's pre-built `gcc-riscv64-linux-gnu` cross-compiler
- **Sysroot**: Debian trixie riscv64 packages (target libraries and headers)
- **Disassembler**: Capstone (statically linked into hsdis for the fastdebug build)

This was developed to cross-compile the JDK from the
[openjdk/jdk#26823](https://github.com/openjdk/jdk/pull/26823) branch and run
its IR tests (`InvolutionIdentityTests`) on a riscv64 board, with both
`-XX:+UseZbb` and `-XX:-UseZbb`.

## Prerequisites

- Fedora x86_64 system with `sudo` access
- JDK 26+ installed as Boot JDK (used to bootstrap the build)
- Internet access (to download Debian packages for the sysroot)
- ~10GB free disk space (sysroot + two JDK builds)

## Scripts

Run in order:

| Script | Description |
|--------|-------------|
| `01-install-toolchain.sh` | Install `gcc-riscv64-linux-gnu`, `gcc-c++-riscv64-linux-gnu`, and `binutils-riscv64-linux-gnu` from Fedora repos |
| `02-create-sysroot.sh` | Download ~56 Debian trixie riscv64 packages, create sysroot at `/opt/riscv64-sysroot`, set up C++ headers, fix cross-compiler issues, install Capstone for hsdis |
| `03-configure-jdk.sh` | Configure both **release** and **fastdebug** builds (fastdebug includes hsdis with Capstone) |
| `04-build-jdk.sh` | Build both JDK variants; patches `spec.gmk` to statically link Capstone into hsdis |
| `05-package.sh` | Package both JDKs and test materials into tarballs under `target/` |

## Output (in `target/`)

| File | Size | Description |
|------|------|-------------|
| `jdk-riscv64-release.tar.gz` | ~206MB | Release JDK — used as jtreg `-compilejdk` (faster test compilation) |
| `jdk-riscv64-fastdebug.tar.gz` | ~1.4GB | Fastdebug JDK — used as jtreg `-jdk` (enables IR verification via `PrintIdeal`/`PrintOptoAssembly`, includes bundled hsdis) |
| `riscv64-test-bundle.tar.gz` | ~544KB | Test files + `run-ir-tests.sh` runner script |

The tarballs extract to `jdk-release/` and `jdk-fastdebug/` respectively, so
they can be extracted in the same directory without colliding.

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `JDK_SRC` | `$HOME/jdk` | Path to the OpenJDK source tree |
| `SYSROOT` | `/opt/riscv64-sysroot` | Path to the riscv64 sysroot |
| `CAPSTONE_PREFIX` | `/opt/riscv64-capstone` | Path to the Capstone prefix directory for hsdis |
| `JOBS` | `$(nproc)` | Number of parallel build jobs |
| `OUTPUT_DIR` | `./target` | Where to write packaged tarballs |

## Quick Start

```bash
./01-install-toolchain.sh
./02-create-sysroot.sh
./03-configure-jdk.sh
./04-build-jdk.sh
./05-package.sh
```

## Deploying to the riscv64 Board

```bash
# Extract all three tarballs
tar xzf jdk-riscv64-fastdebug.tar.gz
tar xzf jdk-riscv64-release.tar.gz
tar xzf riscv64-test-bundle.tar.gz

# Run tests (downloads jtreg automatically if not already present)
./run-ir-tests.sh ./jdk-fastdebug ./jdk-release
```

### What the test runner does

1. **Downloads jtreg** 8.2.1+1 from `builds.shipilev.net` if not already present
2. **Verifies hsdis disassembly** — compiles a tiny class and runs it with
   `-XX:+PrintAssembly` to confirm Capstone is producing riscv64 output
   (including compressed RVC instructions)
3. **Runs `InvolutionIdentityTests`** with `-XX:+UnlockDiagnosticVMOptions -XX:+UseZbb`
4. **Runs `InvolutionIdentityTests`** with `-XX:+UnlockDiagnosticVMOptions -XX:-UseZbb`

Both runs use `-verbose:all -DVerbose=true` so all test actions, IR checks, and
any skipped validations are fully visible in the output.

The fastdebug JDK is passed as `-jdk` (runs the test VM with debug features
needed for IR verification) and the release JDK as `-compilejdk` (compiles test
sources much faster than fastdebug).

## JDK Patch

The file `hsdis-riscv64-capstone.patch` adds riscv64 Capstone support to
`make/Hsdis.gmk`. This is the **only JDK source change** required. It adds
`CS_ARCH_RISCV` and `CS_MODE_RISCV64|CS_MODE_RISCVC` (the latter enables
decoding of compressed 16-bit RVC instructions alongside standard 32-bit ones).

This patch is expected to be merged upstream shortly, at which point it can be
removed from this directory.

Apply manually before running `03-configure-jdk.sh`:

```bash
cd ~/jdk
git apply /path/to/hsdis-riscv64-capstone.patch
```

## Workarounds for Fedora's Bare Cross-Compiler

Fedora's `gcc-riscv64-linux-gnu` is built with `--with-newlib --without-headers`,
making it a bare cross-compiler without system headers or C++ standard library.
The `02-create-sysroot.sh` script applies several workarounds (all external to
the JDK source tree):

1. **Missing `limits.h` chain**: The cross-compiler's `limits.h` doesn't include
   `syslimits.h`, so system limits like `IOV_MAX` are undefined. Fixed by copying
   the native GCC's `limits.h` (which has the `#include "syslimits.h"` directive).

2. **Missing C++ standard library headers**: The cross-compiler has no libstdc++
   headers. Fixed by symlinking the native GCC 16 C++ headers into the
   cross-compiler's include path (`/usr/riscv64-linux-gnu/include/c++/16`),
   including the arch-specific `bits/c++config.h` directory with multilib support.

3. **Missing `libatomic_asneeded`**: GCC 16 links `-latomic_asneeded` by default,
   but the cross-compiler package doesn't ship this library. Fixed by creating
   linker script stubs (`GROUP ( AS_NEEDED ( -latomic ) )`) in the GCC lib directory.

4. **Debian multiarch layout**: Debian places arch-specific headers and libraries
   under `/usr/include/riscv64-linux-gnu/` and `/usr/lib/riscv64-linux-gnu/`
   respectively. Symlinks (e.g., `bits/` → `riscv64-linux-gnu/bits/`) and
   `-B`/`-L` flags in the configure step bridge the gap.

5. **Capstone static linking**: The `04-build-jdk.sh` script patches the generated
   `spec.gmk` to replace `-lcapstone` with the full path to `libcapstone.a`,
   ensuring the hsdis library is self-contained and works on the target board
   without needing `libcapstone.so` installed.
