# Building OpenJDK on macOS with Nix (without Xcode)

A complete guide to building OpenJDK on macOS using Nix, without requiring a full Xcode installation.

## Quick Start

```bash
# 1. Enter the nix shell (auto-generates stubs in ~/Library/Caches/openjdk-build-stubs/)
nix-shell

# 2. Navigate to jdk directory
cd jdk

# 3. Configure OpenJDK
bash configure --with-boot-jdk=$BOOT_JDK_HOME --enable-headless-only \
  METAL=/bin/echo METALLIB=/bin/echo \
  MIG=$OPENJDK_STUB_DIR/stub-mig.sh SETFILE=$OPENJDK_STUB_DIR/stub-setfile.sh

# 4. Build
bash -c 'unset SOURCE_DATE_EPOCH && make images'

# 5. Test
build/macosx-aarch64-server-release/jdk/bin/java --version
```

**Result:** Build completes successfully with exit code 0!

---

## Directory Structure

```
openjdk/
├── shell.nix           # Nix environment (generates stubs in cache)
├── build.md            # This file
└── jdk/                # OpenJDK source (no modifications)
    ├── configure       # Original, unmodified
    ├── make/           # Original, unmodified
    └── ...

~/Library/Caches/openjdk-build-stubs/
├── stub-mig.sh         # Auto-generated when entering nix-shell
└── stub-setfile.sh     # Auto-generated when entering nix-shell
```

---

## The Problem

Building OpenJDK on macOS typically requires full Xcode installation, which provides several macOS-specific build tools. However, these tools have large dependencies and aren't available in nixpkgs. The challenge was to build OpenJDK using only Nix packages.

---

## Solution Development Process

### Challenge 1: Missing Metal Compiler

**Problem:** OpenJDK's configure script checks for the Metal shader compiler (`metal`) and MetalLib tool (`metallib`), which are part of Xcode.

**Error encountered:**
```
configure: error: XCode tool 'metal' neither found in path nor with xcrun
```

**Solution:**
- Metal is only needed for GUI rendering with Metal API
- We build with `--enable-headless-only` flag, which doesn't need Metal
- Override Metal tools with dummy stubs: `METAL=/bin/echo METALLIB=/bin/echo`

**Why this works:** The configure script accepts the override and never actually invokes these tools since headless mode doesn't compile Metal shaders.

---

### Challenge 2: Missing MIG Tool

**Problem:** The Mach Interface Generator (`mig`) is needed to generate IPC stubs for the jdk.hotspot.agent module on macOS. This tool is part of Xcode.

**Error encountered:**
```
warning: unhandled Platform key FamilyDisplayName
error: tool 'mig' not found
```

**Initial approach:** Tried to exclude jdk.hotspot.agent module, but this wasn't straightforward with the build system.

**Solution:** Created `stub-mig.sh` that generates minimal C implementations:
- Parses mig command-line arguments (-server, -user, -header)
- Generates stub C files with the required `mach_exc_server()` function
- The stub implementation returns FALSE (not actually used in headless builds)

**Code generated:**
```c
boolean_t mach_exc_server(mach_msg_header_t *InHeadP, mach_msg_header_t *OutHeadP) {
    /* This is a stub - not actually used in headless JDK build */
    return FALSE;
}
```

**Why this works:** The serviceability agent (SA) features that need mig aren't used in typical JDK operation, so stub implementations are sufficient for a successful build.

---

### Challenge 3: Missing SetFile Tool

**Problem:** After solving Metal and MIG, the build failed at the final packaging step when trying to set macOS bundle attributes.

**Error encountered:**
```
error: tool 'SetFile' not found
make[3]: *** [MacBundles.gmk:101: _jdk_bundle_attribute_set] Error 1
```

**Solution:** Created `stub-setfile.sh` that simply exits with success:
```bash
#!/bin/bash
# SetFile sets Finder attributes on macOS, which are not essential for JDK functionality
exit 0
```

**Why this works:** SetFile only sets the "Bundle" Finder attribute (purely cosmetic metadata). The JDK functions perfectly without these attributes.

---

### Challenge 4: JAR Date Validation Error

**Problem:** Nix sets `SOURCE_DATE_EPOCH=315532800` (1980-01-01 00:00:00) for reproducible builds, but Java's jar tool validates dates must be >= 1980-01-01 00:00:02.

**Error encountered:**
```
date 1980-01-01T00:00:00Z is not within the valid range 1980-01-01T00:00:02Z to 2099-12-31T23:59:59Z
```

**Solution:** Unset `SOURCE_DATE_EPOCH` before building:
```bash
bash -c 'unset SOURCE_DATE_EPOCH && make images'
```

**Why this works:** Removes the problematic environment variable that Nix sets. The 2-second difference is a jar format limitation.

---

### Challenge 5: File Permission Changes

**Problem:** Running `./configure` would make the configure script executable, modifying git status.

**Solution:** Use `bash configure` instead of `./configure`

**Why this works:** Explicitly invoking bash avoids needing execute permissions on the script file.

---

### Design Decision: Where to Store Stubs

**Evolution:**
1. **Initially:** Stubs created manually in project directory → cluttered workspace
2. **Second iteration:** Stubs in jdk/ directory → polluted OpenJDK source tree
3. **Third iteration:** Stubs in parent directory → still part of working tree
4. **Final solution:** Stubs in `~/Library/Caches/openjdk-build-stubs/` → clean separation

**Why cache directory:**
- Keeps project directory clean
- Follows macOS conventions for generated/temporary files
- Persistent across shell sessions (no regeneration needed)
- Easy to clean up (`rm -rf ~/Library/Caches/openjdk-build-stubs`)
- No git noise or accidental commits

---

## Final Solution Architecture

### shell.nix Structure

The `shell.nix` file:

1. **Provides dependencies** via nixpkgs:
   - `autoconf` - GNU autoconf for configure script
   - `gnumake` - GNU Make build system
   - `temurin-bin-25` - Boot JDK (required to build newer JDK)

2. **Sets environment variables:**
   - `BOOT_JDK_HOME` - Points to temurin-bin-25 installation
   - `OPENJDK_STUB_DIR` - Points to `~/Library/Caches/openjdk-build-stubs/`

3. **Generates stub scripts** in shellHook:
   - Creates cache directory if needed
   - Generates `stub-mig.sh` with full C code generation
   - Generates `stub-setfile.sh` as a no-op
   - Makes both scripts executable

### Build Configuration

The configure command uses several workarounds:

```bash
bash configure \
  --with-boot-jdk=$BOOT_JDK_HOME \           # Use Nix-provided JDK 25
  --enable-headless-only \                    # Skip GUI dependencies
  METAL=/bin/echo \                           # Stub Metal compiler
  METALLIB=/bin/echo \                        # Stub MetalLib tool
  MIG=$OPENJDK_STUB_DIR/stub-mig.sh \        # Custom MIG implementation
  SETFILE=$OPENJDK_STUB_DIR/stub-setfile.sh  # Stub SetFile tool
```

---

## Key Principles

### ✅ No Source Modifications
- Zero changes to OpenJDK source code
- Clean git status in jdk/ directory
- Development-friendly for contributing to OpenJDK

### ✅ No Permission Changes
- Use `bash configure` instead of `./configure`
- Avoids modifying file permissions

### ✅ External Workarounds Only
- All solutions are configure-time overrides
- Stub scripts are external to the project
- Could easily switch to real tools if available

### ✅ Minimal Invasiveness
- Stubs stored in standard cache location
- Auto-generated on nix-shell entry
- Clean project directory

---

## Detailed Build Steps

### Prerequisites

- Nix package manager installed
- Git (for cloning OpenJDK)
- macOS (tested on macOS 14+ with Apple Silicon)

### Step-by-Step Instructions

1. **Clone this repository** (if not already done):
   ```bash
   git clone https://github.com/openjdk/jdk.git
   ```

2. **Enter Nix shell:**
   ```bash
   nix-shell
   ```

   This will:
   - Install required dependencies (autoconf, gnumake, temurin-bin-25)
   - Set `BOOT_JDK_HOME` to the boot JDK location
   - Create stub scripts in `~/Library/Caches/openjdk-build-stubs/`
   - Set `OPENJDK_STUB_DIR` environment variable

3. **Navigate to OpenJDK source:**
   ```bash
   cd jdk
   ```

4. **Configure the build:**
   ```bash
   bash configure --with-boot-jdk=$BOOT_JDK_HOME --enable-headless-only \
     METAL=/bin/echo METALLIB=/bin/echo \
     MIG=$OPENJDK_STUB_DIR/stub-mig.sh SETFILE=$OPENJDK_STUB_DIR/stub-setfile.sh
   ```

   Configuration will complete with warnings about ignored environment variables (normal).

5. **Build OpenJDK:**
   ```bash
   bash -c 'unset SOURCE_DATE_EPOCH && make images'
   ```

   The build will:
   - Compile all Java and native code
   - Create JDK image
   - Generate CDS archives
   - Complete successfully with exit code 0

6. **Verify the build:**
   ```bash
   build/macosx-aarch64-server-release/jdk/bin/java --version
   ```

   Expected output:
   ```
   openjdk 27-internal 2026-09-15
   OpenJDK Runtime Environment (build 27-internal-adhoc.g.jdk)
   OpenJDK 64-Bit Server VM (build 27-internal-adhoc.g.jdk, mixed mode)
   ```

7. **Test with a Java program:**
   ```bash
   cat > Hello.java << 'EOF'
   public class Hello {
       public static void main(String[] args) {
           System.out.println("Hello from custom OpenJDK build!");
       }
   }
   EOF

   build/macosx-aarch64-server-release/jdk/bin/javac Hello.java
   build/macosx-aarch64-server-release/jdk/bin/java Hello
   rm Hello.java Hello.class
   ```

---

## Build Output

The built JDK will be located at:
```
jdk/build/macosx-aarch64-server-release/jdk/
```

This is a complete, functional JDK installation that can:
- Compile Java programs (`javac`)
- Run Java applications (`java`)
- Create JAR files (`jar`)
- Use all standard JDK tools

---

## Limitations

### Serviceability Agent (SA) Features
The jdk.hotspot.agent module's mig-dependent features won't work properly since we use stub implementations. This affects:
- Low-level debugging capabilities
- Some heap analysis tools

These are advanced features rarely needed for typical Java development.

### macOS Bundle Attributes
The JDK won't have macOS Finder bundle attributes set (since SetFile is stubbed). This is purely cosmetic and doesn't affect functionality.

### Headless Only
This build doesn't include GUI support. For GUI applications, you would need:
- Full Xcode installation (provides Metal tools)
- Regular configure without `--enable-headless-only`

---

## Troubleshooting

### Configure fails with "command not found"
**Solution:** Make sure you're in the nix-shell and `OPENJDK_STUB_DIR` is set:
```bash
echo $OPENJDK_STUB_DIR  # Should show: /Users/yourname/Library/Caches/openjdk-build-stubs
```

### Build fails with "mach_exc_server undefined"
**Solution:** The stub-mig.sh wasn't used or failed. Verify it exists and is executable:
```bash
ls -la $OPENJDK_STUB_DIR/stub-mig.sh
```

### Date validation error in jar creation
**Solution:** Make sure you unset SOURCE_DATE_EPOCH:
```bash
bash -c 'unset SOURCE_DATE_EPOCH && make images'
```

### Permission denied on configure
**Solution:** Use `bash configure` instead of `./configure`

---

## Rebuilding

To rebuild after making changes:

```bash
# In nix-shell, from jdk/ directory:
make clean                                    # Clean previous build
bash -c 'unset SOURCE_DATE_EPOCH && make images'  # Rebuild
```

To reconfigure (after git pull or configure changes):

```bash
# Reconfigure first
bash configure --with-boot-jdk=$BOOT_JDK_HOME --enable-headless-only \
  METAL=/bin/echo METALLIB=/bin/echo \
  MIG=$OPENJDK_STUB_DIR/stub-mig.sh SETFILE=$OPENJDK_STUB_DIR/stub-setfile.sh

# Then build
bash -c 'unset SOURCE_DATE_EPOCH && make clean && make images'
```

---

## Cleanup

To clean up the stub scripts:

```bash
rm -rf ~/Library/Caches/openjdk-build-stubs
```

They will be regenerated next time you enter `nix-shell`.

---

## Advanced: Understanding the Stubs

### stub-mig.sh Implementation

The MIG stub generates three types of files:

1. **Header file** (`mach_exc.h`):
   - Declares `mach_exc_server()` function
   - Provides C/C++ compatibility
   - Includes necessary mach headers

2. **Server file** (`mach_excServer.c`):
   - Implements `mach_exc_server()` function
   - Returns FALSE (indicates no exception handling)
   - Sufficient for linking but not for actual SA functionality

3. **User file** (`mach_excUser.c`):
   - Empty stub (not used by the build)

### stub-setfile.sh Implementation

Simply exits with success code 0. The real SetFile tool would:
- Set the "Bundle" bit on .app directories
- Mark them as special to the Finder
- Purely cosmetic for JDK distribution

Since we're building for development/testing, these attributes aren't needed.

---

## Why This Approach is Better

Compared to other approaches:

### vs. Installing Full Xcode
- **Pros:** Smaller download (Nix packages ~500MB vs Xcode ~15GB)
- **Pros:** Reproducible builds via Nix
- **Pros:** No Apple Developer account needed
- **Cons:** Missing some advanced SA features

### vs. Patching OpenJDK Source
- **Pros:** No source modifications (clean git status)
- **Pros:** Easy to update to new OpenJDK versions
- **Pros:** Can contribute patches upstream without conflicts
- **Cons:** Slightly more complex configure command

### vs. Using Homebrew
- **Pros:** Nix provides better reproducibility
- **Pros:** Isolated environment doesn't affect system
- **Pros:** Declarative dependencies in shell.nix
- **Cons:** Requires learning Nix

---

## Contributing

If you improve this build process:

1. Test thoroughly on clean checkout
2. Verify git status remains clean in jdk/
3. Update this documentation
4. Share your improvements!

---

## References

- OpenJDK Build Documentation: https://openjdk.org/groups/build/doc/building.html
- Nix Package Manager: https://nixos.org/
- macOS Developer Tools: https://developer.apple.com/xcode/

---

## License

This build configuration (shell.nix and documentation) is provided as-is for building OpenJDK.
OpenJDK itself is licensed under GPLv2 with Classpath Exception.

---

## Using jtreg for Testing (Optional)

jtreg (Java Regression Test Harness) is the test framework used by OpenJDK. It's optional but useful for running the OpenJDK test suite.

### Option 1: Download Pre-built jtreg

Download a pre-built jtreg from the official source:

```bash
# Download jtreg (check https://ci.adoptium.net or builds from Oracle/Adop

tium)
# Example using a community build:
cd ~/Downloads
wget https://ci.adoptium.net/view/Dependencies/job/dependency_pipeline/lastSuccessfulBuild/artifact/jtreg/jtreg-7.4+1.tar.gz
tar xzf jtreg-7.4+1.tar.gz
export JTREG_HOME=~/Downloads/jtreg
```

### Option 2: Build jtreg from Source

If you want to build jtreg yourself:

```bash
git clone https://github.com/openjdk/jtreg.git
cd jtreg
# Requires JDK 11+ and Ant
bash make/build.sh --jdk /path/to/jdk
# jtreg will be in build/images/jtreg/
export JTREG_HOME=$(pwd)/build/images/jtreg
```

### Using jtreg with this Build

Once you have jtreg, use it in two ways:

**Method 1: Set environment variable before entering nix-shell**
```bash
export JTREG_HOME=/path/to/jtreg
nix-shell
# The shell will detect JTREG_HOME
```

**Method 2: Pass as parameter to nix-shell**
```bash
nix-shell --argstr jtreg /path/to/jtreg
```

**Method 3: Set during configure**
```bash
cd jdk
bash configure --with-boot-jdk=$BOOT_JDK_HOME --with-jtreg=/path/to/jtreg \
  --enable-headless-only METAL=/bin/echo METALLIB=/bin/echo \
  MIG=$OPENJDK_STUB_DIR/stub-mig.sh SETFILE=$OPENJDK_STUB_DIR/stub-setfile.sh
```

### Running Tests

After building with jtreg configured:

```bash
# Run all tier1 tests (quick smoke tests)
make test-tier1

# Run specific test
make test TEST="jdk/java/lang/String"

# Run with jtreg directly
$JTREG_HOME/bin/jtreg -jdk:build/macosx-aarch64-server-release/jdk \
  test/jdk/java/lang/String
```

---

## About jtreg.nix

The `jtreg.nix` file is provided as a starting point for building jtreg with Nix, but due to jtreg's build-time network dependencies, it's currently easier to use a pre-built jtreg distribution.

If you improve `jtreg.nix` to successfully build jtreg in a Nix environment, contributions are welcome!

