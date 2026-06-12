#!/bin/bash
# Option A: Cross-compile JDK for riscv64 using Fedora cross-compiler + Debian sysroot
# Step 5: Package both JDKs and test materials for transfer to riscv64 board
#
# Packages:
#   - jdk-riscv64-release.tar.gz   : release JDK (used as -compilejdk for faster compilation)
#   - jdk-riscv64-fastdebug.tar.gz : fastdebug JDK (used as -jdk for IR verification, with hsdis)
#   - riscv64-test-bundle.tar.gz   : test files + runner script

set -euo pipefail

JDK_SRC="${JDK_SRC:-$HOME/jdk}"
OUTPUT_DIR="${OUTPUT_DIR:-$(pwd)/target}"

echo "=== Packaging JDKs and test materials for riscv64 ==="

mkdir -p "${OUTPUT_DIR}"

# 1. Package both JDK images
for variant in release fastdebug; do
    BUILD_DIR="${JDK_SRC}/build/linux-riscv64-server-${variant}"
    JDK_IMAGE="${BUILD_DIR}/images/jdk"

    if [ ! -d "${JDK_IMAGE}" ]; then
        echo "ERROR: ${variant} JDK image not found at ${JDK_IMAGE}"
        echo "       Run 04-build-jdk.sh first."
        exit 1
    fi

    echo "Packaging ${variant} JDK image..."
    (cd "${BUILD_DIR}/images" && tar czf "${OUTPUT_DIR}/jdk-riscv64-${variant}.tar.gz" --transform "s|^jdk|jdk-${variant}|" jdk/)
    echo "  Created: ${OUTPUT_DIR}/jdk-riscv64-${variant}.tar.gz ($(du -sh "${OUTPUT_DIR}/jdk-riscv64-${variant}.tar.gz" | cut -f1))"
done

# 2. Package the specific IR test we want to run
#    jtreg needs the full directory structure from TEST.ROOT downward
echo "Packaging IR test files..."
TEST_DIR=$(mktemp -d)
JTREG_ROOT="${TEST_DIR}/test/hotspot/jtreg"
mkdir -p "${JTREG_ROOT}"

# Copy TEST.ROOT (jtreg needs this to locate the test root)
cp "${JDK_SRC}/test/hotspot/jtreg/TEST.ROOT" "${JTREG_ROOT}/"
# Ship empty group files — the originals reference directories not in this bundle,
# causing jtreg to fail validation. We run specific test files, not groups.
touch "${JTREG_ROOT}/TEST.groups"
touch "${JTREG_ROOT}/TEST.quick-groups"

# Copy the involution test and its companion .jasm file
mkdir -p "${JTREG_ROOT}/compiler/c2/gvn"
cp -a "${JDK_SRC}/test/hotspot/jtreg/compiler/c2/gvn/InvolutionIdentityTests.java" "${JTREG_ROOT}/compiler/c2/gvn/"
cp -a "${JDK_SRC}/test/hotspot/jtreg/compiler/c2/gvn/ReverseBytesConstantsHelper.jasm" "${JTREG_ROOT}/compiler/c2/gvn/"

# Copy the IR framework and generator libraries (@library /)
mkdir -p "${JTREG_ROOT}/compiler/lib"
cp -a "${JDK_SRC}/test/hotspot/jtreg/compiler/lib/"* "${JTREG_ROOT}/compiler/lib/"

# Copy the test library (@library /test/lib)
mkdir -p "${TEST_DIR}/test/lib"
cp -a "${JDK_SRC}/test/lib/jdk" "${TEST_DIR}/test/lib/"
cp -a "${JDK_SRC}/test/lib/jtreg" "${TEST_DIR}/test/lib/"

# 3. Create the test runner script
cat > "${TEST_DIR}/run-ir-tests.sh" << 'TESTSCRIPT'
#!/bin/bash
# Run the InvolutionIdentityTests IR test on riscv64
#
# Uses two JDKs:
#   - fastdebug JDK (-jdk): runs the test VM with PrintIdeal/PrintOptoAssembly for IR verification
#   - release JDK (-compilejdk): compiles test sources (much faster than fastdebug)
#
# Automatically downloads jtreg if not found.
#
# Usage: ./run-ir-tests.sh [fastdebug-jdk] [release-jdk]
#   If only one argument is given, it is used for both -jdk and -compilejdk.

set -euo pipefail

FASTDEBUG_JDK="${1:-./jdk-fastdebug}"
RELEASE_JDK="${2:-./jdk-release}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Fall back: if release dir doesn't exist, use fastdebug for both
if [ ! -d "$RELEASE_JDK" ]; then
    echo "NOTE: Release JDK not found at $RELEASE_JDK, using fastdebug JDK for compilation too."
    RELEASE_JDK="$FASTDEBUG_JDK"
fi

JAVA="${FASTDEBUG_JDK}/bin/java"
if [ ! -x "$JAVA" ]; then
    echo "ERROR: fastdebug JDK not found at $FASTDEBUG_JDK"
    echo "Usage: $0 [fastdebug-jdk] [release-jdk]"
    exit 1
fi

echo "=== JDK versions ==="
echo "--- fastdebug (test) JDK ---"
"$FASTDEBUG_JDK/bin/java" -version
echo ""
echo "--- release (compile) JDK ---"
"$RELEASE_JDK/bin/java" -version
echo ""

# --- Ensure jtreg is available ---
JTREG_VERSION="8.2.1+1"
JTREG_URL="https://builds.shipilev.net/jtreg/jtreg-${JTREG_VERSION}.zip"
JTREG_DIR="${JTREG_HOME:-${SCRIPT_DIR}/jtreg}"

if [ ! -x "${JTREG_DIR}/bin/jtreg" ]; then
    echo "=== Downloading jtreg ${JTREG_VERSION} ==="
    JTREG_ZIP="${SCRIPT_DIR}/jtreg-${JTREG_VERSION}.zip"
    if [ ! -f "$JTREG_ZIP" ]; then
        echo "Downloading from ${JTREG_URL}..."
        curl -fSL -o "$JTREG_ZIP" "$JTREG_URL"
    fi
    echo "Extracting to ${JTREG_DIR}..."
    unzip -qo "$JTREG_ZIP" -d "${SCRIPT_DIR}"
    if [ ! -x "${JTREG_DIR}/bin/jtreg" ]; then
        echo "ERROR: jtreg not found after extraction at ${JTREG_DIR}/bin/jtreg"
        exit 1
    fi
    echo "jtreg installed at ${JTREG_DIR}"
    echo ""
fi

TEST_FILE="${SCRIPT_DIR}/test/hotspot/jtreg/compiler/c2/gvn/InvolutionIdentityTests.java"
if [ ! -f "$TEST_FILE" ]; then
    echo "ERROR: Test file not found at $TEST_FILE"
    exit 1
fi

# --- Verify hsdis / disassembly ---
echo "=== Verifying disassembly (hsdis) ==="
HSDIS_LIB="${FASTDEBUG_JDK}/lib/hsdis-riscv64.so"
if [ -f "$HSDIS_LIB" ]; then
    echo "Found hsdis library: $HSDIS_LIB"
else
    echo "WARNING: hsdis library not found at $HSDIS_LIB"
    echo "         Disassembly will not be available."
fi

# Quick smoke test: compile a tiny class and try PrintAssembly
TMPDIR_DISASM=$(mktemp -d)
cat > "${TMPDIR_DISASM}/DisasmTest.java" << 'JAVAEOF'
public class DisasmTest {
    public static int add(int a, int b) { return a + b; }
    public static void main(String[] args) {
        for (int i = 0; i < 20000; i++) add(i, i + 1);
    }
}
JAVAEOF
"$RELEASE_JDK/bin/javac" "${TMPDIR_DISASM}/DisasmTest.java" -d "${TMPDIR_DISASM}"
DISASM_OUTPUT=$("$JAVA" \
    -XX:+UnlockDiagnosticVMOptions \
    -XX:+PrintAssembly \
    -XX:PrintAssemblyOptions=force \
    -cp "${TMPDIR_DISASM}" DisasmTest 2>&1 | head -200)
rm -rf "${TMPDIR_DISASM}"

if echo "$DISASM_OUTPUT" | grep -q "addi\|add\t\|Decoding compiled method"; then
    echo "Disassembly is working (Capstone hsdis producing riscv64 output)."
else
    echo "WARNING: Disassembly does not appear to be working."
    echo "First 10 lines of output:"
    echo "$DISASM_OUTPUT" | head -10
fi
echo ""

# --- Run IR tests ---
echo "=== Running IR tests with jtreg ==="
echo "  test JDK (fastdebug): $FASTDEBUG_JDK"
echo "  compile JDK (release): $RELEASE_JDK"
echo ""

echo "--- Test with -XX:+UseZbb ---"
"${JTREG_DIR}/bin/jtreg" \
    -jdk:"$FASTDEBUG_JDK" \
    -compilejdk:"$RELEASE_JDK" \
    -vmoptions:"-XX:+UnlockDiagnosticVMOptions -XX:+UseZbb" \
    -verbose:all -DVerbose=true \
    "$TEST_FILE" \
    2>&1 || true

echo ""
echo "--- Test with -XX:-UseZbb ---"
"${JTREG_DIR}/bin/jtreg" \
    -jdk:"$FASTDEBUG_JDK" \
    -compilejdk:"$RELEASE_JDK" \
    -vmoptions:"-XX:+UnlockDiagnosticVMOptions -XX:-UseZbb" \
    -verbose:all -DVerbose=true \
    "$TEST_FILE" \
    2>&1 || true

echo ""
echo "=== Done ==="
TESTSCRIPT
chmod +x "${TEST_DIR}/run-ir-tests.sh"

# 4. Create test bundle
echo "Creating test bundle..."
(cd "${TEST_DIR}" && tar czf "${OUTPUT_DIR}/riscv64-test-bundle.tar.gz" .)
rm -rf "${TEST_DIR}"
echo "  Created: ${OUTPUT_DIR}/riscv64-test-bundle.tar.gz"

echo ""
echo "=== Packaging complete ==="
echo ""
echo "Files in ${OUTPUT_DIR}:"
ls -lh "${OUTPUT_DIR}/"
echo ""
echo "To deploy to riscv64 board:"
echo "  1. Copy all three tarballs to the board"
echo "  2. Extract:"
echo "       tar xzf jdk-riscv64-fastdebug.tar.gz"
echo "       tar xzf jdk-riscv64-release.tar.gz"
echo "       tar xzf riscv64-test-bundle.tar.gz"
echo "  3. Run: ./run-ir-tests.sh ./jdk-fastdebug ./jdk-release"
