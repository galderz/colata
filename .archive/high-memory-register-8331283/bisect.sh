#!/bin/bash
set -o pipefail

TOOLS_DIR="/Users/g/tmp/high-memory-register/2003/claude/tools"
JDK_DIR="/Users/g/tmp/high-memory-register/2003/claude/jdk"
export PATH="$TOOLS_DIR/local/bin:$PATH"

cd "$JDK_DIR"

# Always restore working tree on exit so git bisect can checkout next commit
cleanup() {
    cd "$JDK_DIR"
    git checkout -f -- . 2>/dev/null || true
}
trap cleanup EXIT

# Fix SpinPause CFI issue for newer clang - detect any version with inline asm branch table
SPIN_FILE="src/hotspot/os_cpu/bsd_aarch64/os_bsd_aarch64.cpp"
if [ -f "$SPIN_FILE" ] && grep -q '"  br   %\[d\]' "$SPIN_FILE" 2>/dev/null; then
    sed -i '' '/int SpinPause() {/,/^  }/c\
  int SpinPause() {\
    switch (VM_Version::spin_wait_desc().inst()) {\
    case SpinWait::NONE:\
      break;\
    case SpinWait::NOP:\
      asm volatile("nop" : : : "memory");\
      break;\
    case SpinWait::ISB:\
      asm volatile("isb" : : : "memory");\
      break;\
    case SpinWait::YIELD:\
      asm volatile("yield" : : : "memory");\
      break;\
    default:\
      break;\
    }\
    return 1;\
  }' "$SPIN_FILE"
    echo "Applied SpinPause patch"
fi

echo "=== Commit: $(git log --oneline -1) ==="

# Try configure and build with different boot JDKs
BUILT=false
for boot_jdk in "$TOOLS_DIR/jdk-22.jdk/Contents/Home" "$TOOLS_DIR/jdk-23.0.1.jdk/Contents/Home" "$TOOLS_DIR/jdk-24.jdk/Contents/Home"; do
    if [ ! -d "$boot_jdk" ]; then
        continue
    fi
    echo "Trying boot JDK: $boot_jdk"
    rm -rf build/macosx-aarch64-server-fastdebug
    bash configure --with-boot-jdk="$boot_jdk" --with-debug-level=fastdebug --disable-warnings-as-errors 2>&1 | tail -3
    if [ $? -ne 0 ]; then
        echo "Configure failed with $boot_jdk"
        continue
    fi

    make images CONF=macosx-aarch64-server-fastdebug 2>&1 | tail -10
    if [ $? -eq 0 ]; then
        BUILT=true
        break
    fi
    echo "Build failed with $boot_jdk, trying next..."
done

if [ "$BUILT" = false ]; then
    echo "Build failed with all boot JDKs, skipping"
    exit 125
fi

JDK_HOME="$JDK_DIR/build/macosx-aarch64-server-fastdebug/images/jdk"

# Check if test file exists
TEST_FILE="$JDK_DIR/test/hotspot/jtreg/compiler/c2/TestFindNode.java"
if [ ! -f "$TEST_FILE" ]; then
    echo "Test file not found, skipping"
    exit 125
fi

# Clean jtreg work dir
rm -rf "$JDK_DIR/JTwork" "$JDK_DIR/JTreport"

# Run the test - try with newer jtreg first, fall back to older
ADD_OPTIONS='-XX:+UnlockDiagnosticVMOptions -XX:-TieredCompilation -XX:+StressArrayCopyMacroNode -XX:+StressLCM -XX:+StressGCM -XX:+StressIGVN -XX:+StressCCP -XX:+StressMacroExpansion -XX:+StressMethodHandleLinkerInlining -XX:+StressCompiledExceptionHandlers -XX:CompileCommand=memlimit,*.*,1G~crash -XX:CompileCommand=memstat,*::*,print'

JTREG_RAN=false
for jtreg_dir in "$TOOLS_DIR/jtreg75/jtreg" "$TOOLS_DIR/jtreg"; do
    if [ -d "$jtreg_dir/bin" ]; then
        echo "Trying jtreg: $jtreg_dir"
        "$jtreg_dir/bin/jtreg" -jdk:"$JDK_HOME" "-vmoptions:${ADD_OPTIONS}" "$TEST_FILE" 2>&1 | tail -5
        if [ -f "$JDK_DIR/JTwork/compiler/c2/TestFindNode.jtr" ]; then
            JTREG_RAN=true
            break
        fi
        rm -rf "$JDK_DIR/JTwork" "$JDK_DIR/JTreport"
    fi
done

if [ "$JTREG_RAN" = false ]; then
    echo "jtreg failed to produce results, skipping"
    exit 125
fi

# Extract memory usage - handle multiple format variants
JTR_FILE="$JDK_DIR/JTwork/compiler/c2/TestFindNode.jtr"

# Get all lines with Arena usage for TestFindNode::test
ARENA_LINES=$(grep "Arena usage.*TestFindNode::test" "$JTR_FILE" || true)
echo "--- Arena usage lines ---"
echo "$ARENA_LINES"
echo "---"

if [ -z "$ARENA_LINES" ]; then
    echo "No Arena usage lines found, skipping"
    exit 125
fi

# Extract the usage number. Try multiple patterns:
# Pattern: "Total Usage: NUMBER"
USAGE=$(echo "$ARENA_LINES" | grep -o 'Total Usage: [0-9]*' | grep -o '[0-9]*' | sort -n | tail -1)

# If not found, try pattern after method signature: ": NUMBER"
if [ -z "$USAGE" ]; then
    USAGE=$(echo "$ARENA_LINES" | grep -o 'TestFindNode::test([^)]*): [0-9]*' | grep -o '[0-9]*$' | sort -n | tail -1)
fi

# Last resort: take the largest number from arena lines
if [ -z "$USAGE" ]; then
    USAGE=$(echo "$ARENA_LINES" | grep -oE '[0-9]{6,}' | sort -n | tail -1)
fi

echo "TestFindNode::test Usage: $USAGE"

if [ -z "$USAGE" ]; then
    echo "Could not extract memory usage, skipping"
    exit 125
fi

# Threshold: 100MB (100000000). If usage > 100MB, it's "bad" (old behavior)
if [ "$USAGE" -gt 100000000 ]; then
    echo "HIGH memory usage ($USAGE > 100MB) -> BAD"
    exit 1
else
    echo "LOW memory usage ($USAGE <= 100MB) -> GOOD"
    exit 0
fi
