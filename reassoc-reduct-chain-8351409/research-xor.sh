#!/usr/bin/env bash

set -ex

echo "=== PATCH RUN ==="
BRANCH=topic.reassoc-reduct-chain.all-add make checkout
CLASS=TestXorByte make run
CLASS=TestXorShort make run

# Step 3: Confirm the IR (Ideal Graph) Is Structurally Identical
echo "=== PATCH IDEAL ==="
IDEAL_ARGS=true CLASS=TestXorByte make run 2>&1 | grep -c "LShiftI\|RShiftI\|XorI\|MulI\|AddI"
IDEAL_ARGS=true CLASS=TestXorShort make run 2>&1 | grep -c "LShiftI\|RShiftI\|XorI\|MulI\|AddI"

# Step 4: Confirm Unrolling Is the Same
echo "=== PATCH UNROLL ==="
TRACE_LOOP_ARGS=true CLASS=TestXorByte make run 2>&1 | grep -c "Unroll"
TRACE_LOOP_ARGS=true CLASS=TestXorShort make run 2>&1 | grep -c "Unroll"

# Step 6: Compare Generated Assembly — The Smoking Gun
# Create output directory for assemblies
mkdir -p target
echo "=== PATCH ASM ==="
ASM_ARGS=true CLASS=TestXorByte make run 2>&1 > target/asm_patch_byte.txt
ASM_ARGS=true CLASS=TestXorShort make run 2>&1 > target/asm_patch_short.txt

echo "=== PATCH Byte: moves ==="
sed -n '/Compiled method (c2).*%/,/Compiled method/p' target/asm_patch_byte.txt | \
    grep -c 'movd[lq]'

echo "=== PATCH Short: moves ==="
sed -n '/Compiled method (c2).*%/,/Compiled method/p' target/asm_patch_short.txt | \
    grep -c 'movd[lq]'

echo "=== PATCH BYTE: XOR placement ==="
sed -n '/Compiled method (c2).*%/,/Compiled method/p' target/asm_patch_byte.txt | \
    grep -n 'xorl.*# int'

echo "=== PATCH SHORT: XOR placement ==="
sed -n '/Compiled method (c2).*%/,/Compiled method/p' target/asm_patch_short.txt | \
    grep -n 'xorl.*# int'

# Step 8: Observe the Peephole lea Conversions
echo "=== PATCH Byte: peephole ==="
PEEPHOLE_ARGS=true CLASS=TestXorByte make run 2>&1 | grep "peephole" | sort | uniq -c | sort -rn
echo "=== PATCH Short: peephole ==="
PEEPHOLE_ARGS=true CLASS=TestXorShort make run 2>&1 | grep "peephole" | sort | uniq -c | sort -rn

echo "=== BASE RUN ==="
BRANCH=topic.reassoc-reduct-chain.all-add.base make checkout
CLASS=TestXorByte make run
CLASS=TestXorShort make run

echo "=== BASE ASM ==="
ASM_ARGS=true CLASS=TestXorByte make run 2>&1 > target/asm_base_byte.txt
ASM_ARGS=true CLASS=TestXorShort make run 2>&1 > target/asm_base_short.txt

echo "=== BASE Byte: moves ==="
sed -n '/Compiled method (c2).*%/,/Compiled method/p' target/asm_base_byte.txt | \
    grep -c 'movd[lq]'

echo "=== BASE Short: moves ==="
sed -n '/Compiled method (c2).*%/,/Compiled method/p' target/asm_base_short.txt | \
    grep -c 'movd[lq]'

echo "=== PATCH BYTE: XOR placement ==="
sed -n '/Compiled method (c2).*%/,/Compiled method/p' target/asm_patch_byte.txt | \
    grep -n 'xorl.*# int'

echo "=== PATCH SHORT: XOR placement ==="
sed -n '/Compiled method (c2).*%/,/Compiled method/p' target/asm_patch_short.txt | \
    grep -n 'xorl.*# int'

# Step 7: The Root Cause — Scaled Addressing Modes
# Count scaled vs unscaled array loads in the C2 OSR compilation
echo "=== BASE BYTE: scaled loads ==="
sed -n '/Compiled method (c2).*%/,/Compiled method/p' target/asm_base_byte.txt | \
    grep 'movsbl' | grep -c '<< #'

echo "=== BASE BYTE: unscaled loads ==="
sed -n '/Compiled method (c2).*%/,/Compiled method/p' target/asm_base_byte.txt | \
    grep 'movsbl' | grep -vc '<< #'

echo "=== BASE SHORT: scaled loads ==="
sed -n '/Compiled method (c2).*%/,/Compiled method/p' target/asm_base_short.txt | \
    grep 'movswl' | grep -c '<< #'

echo "=== BASE SHORT: unscaled loads ==="
sed -n '/Compiled method (c2).*%/,/Compiled method/p' target/asm_base_short.txt | \
    grep 'movswl' | grep -vc '<< #'


