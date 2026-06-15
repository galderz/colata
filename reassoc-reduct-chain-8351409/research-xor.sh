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
TRACE_LOOPS_ARGS=true CLASS=TestXorByte make run 2>&1 | grep -c "Unroll"
TRACE_LOOPS_ARGS=true CLASS=TestXorShort make run 2>&1 | grep -c "Unroll"

# Step 6: Compare Generated Assembly — The Smoking Gun
echo "=== PATCH ASM ==="
rm -f asm_patch*.log || true
ASM_ARGS=true CLASS=TestXorByte make run 2>&1 > asm_patch_byte.log
ASM_ARGS=true CLASS=TestXorShort make run 2>&1 > asm_patch_short.log

echo "=== PATCH Byte: moves ==="
sed -n '/Compiled method (c2).*%/,/Compiled method/p' asm_patch_byte.log | \
    grep -c 'movd[lq]'

echo "=== PATCH Short: moves ==="
sed -n '/Compiled method (c2).*%/,/Compiled method/p' asm_patch_short.log | \
    grep -c 'movd[lq]'

echo "=== PATCH BYTE: XOR placement ==="
sed -n '/Compiled method (c2).*%/,/Compiled method/p' asm_patch_byte.txt | \
    grep -n 'xorl.*# int'

echo "=== PATCH SHORT: XOR placement ==="
sed -n '/Compiled method (c2).*%/,/Compiled method/p' asm_patch_short.txt | \
    grep -n 'xorl.*# int'

# Step 8: Observe the Peephole lea Conversions
echo "=== PATCH Byte: peephole ==="
PEEPHOLE_ARGS=true CLASS=TestXorByte make run 2>&1 | grep "peephole" | sort | uniq -c | sort -rn
echo "=== PATCH Short: peephole ==="
PEEPHOLE_ARGS=true CLASS=TestXorShort make run 2>&1 > grep "peephole" | sort | uniq -c | sort -rn

echo "=== BASE RUN ==="
BRANCH=topic.reassoc-reduct-chain.all-add.base make checkout
CLASS=TestXorByte make run
CLASS=TestXorShort make run

echo "=== BASE ASM ==="
rm -f asm_base*.log || true
ASM_ARGS=true CLASS=TestXorByte make run 2>&1 > asm_base_byte.log
ASM_ARGS=true CLASS=TestXorShort make run 2>&1 > asm_base_short.log

echo "=== BASE Byte: moves ==="
sed -n '/Compiled method (c2).*%/,/Compiled method/p' asm_base_byte.log | \
    grep -c 'movd[lq]'

echo "=== BASE Short: moves ==="
sed -n '/Compiled method (c2).*%/,/Compiled method/p' asm_base_short.log | \
    grep -c 'movd[lq]'

echo "=== PATCH BYTE: XOR placement ==="
sed -n '/Compiled method (c2).*%/,/Compiled method/p' asm_base_byte.txt | \
    grep -n 'xorl.*# int'

echo "=== PATCH SHORT: XOR placement ==="
sed -n '/Compiled method (c2).*%/,/Compiled method/p' asm_base_short.txt | \
    grep -n 'xorl.*# int'

# Step 7: The Root Cause — Scaled Addressing Modes
# Count scaled vs unscaled array loads in the C2 OSR compilation
echo "=== BASE BYTE: scaled loads ==="
sed -n '/Compiled method (c2).*%/,/Compiled method/p' asm_base_byte.txt | \
    grep 'movsbl' | grep -c '<< #'

echo "=== BASE BYTE: unscaled loads ==="
sed -n '/Compiled method (c2).*%/,/Compiled method/p' asm_base_byte.txt | \
    grep 'movsbl' | grep -vc '<< #'

echo "=== BASE SHORT: scaled loads ==="
sed -n '/Compiled method (c2).*%/,/Compiled method/p' asm_base_short.txt | \
    grep 'movswl' | grep -c '<< #'

echo "=== BASE SHORT: unscaled loads ==="
sed -n '/Compiled method (c2).*%/,/Compiled method/p' asm_base_short.txt | \
    grep 'movswl' | grep -vc '<< #'


