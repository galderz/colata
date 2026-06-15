#!/usr/bin/env bash

set -ex

# Create output directory for log files
mkdir -p target

echo "=== PATCH RUN ==="
BRANCH=topic.reassoc-reduct-chain.all-add make checkout
CLASS=TestXorByte make run
CLASS=TestXorShort make run

# Step 3: Confirm the IR (Ideal Graph) Is Structurally Identical
#echo "=== PATCH IDEAL ==="
#IDEAL_ARGS=true CLASS=TestXorByte make run 2>&1 | grep -c "LShiftI\|RShiftI\|XorI\|MulI\|AddI"
#IDEAL_ARGS=true CLASS=TestXorShort make run 2>&1 | grep -c "LShiftI\|RShiftI\|XorI\|MulI\|AddI"

# Step 4: Confirm Unrolling Is the Same
#echo "=== PATCH UNROLL ==="
#TRACE_LOOP_ARGS=true CLASS=TestXorByte make run 2>&1 | grep -c "Unroll"
#TRACE_LOOP_ARGS=true CLASS=TestXorShort make run 2>&1 | grep -c "Unroll"

# Step 6: Compare Generated Assembly — The Smoking Gun
ASM_ARGS=true CLASS=TestXorByte make run 2>&1 > target/asm_patch_byte.txt
ASM_ARGS=true CLASS=TestXorShort make run 2>&1 > target/asm_patch_short.txt
PEEPHOLE_ARGS=true CLASS=TestXorByte make run 2>&1 > target/peep_patch_byte.txt
PEEPHOLE_ARGS=true CLASS=TestXorShort make run 2>&1 > target/peep_patch_short.txt

echo "=== BASE RUN ==="
BRANCH=topic.reassoc-reduct-chain.all-add.base make checkout
CLASS=TestXorByte make run
CLASS=TestXorShort make run

echo "=== BASE ASM ==="
ASM_ARGS=true CLASS=TestXorByte make run 2>&1 > target/asm_base_byte.txt
ASM_ARGS=true CLASS=TestXorShort make run 2>&1 > target/asm_base_short.txt
PEEPHOLE_ARGS=true CLASS=TestXorByte make run 2>&1 > target/peep_patch_byte.txt
PEEPHOLE_ARGS=true CLASS=TestXorShort make run 2>&1 > target/peep_patch_short.txt

echo "=== PATCH Byte: moves ==="
sed -n '/Compiled method (c2).*%/,/Compiled method/p' target/asm_patch_byte.txt | \
    grep -c 'movd[lq]'

echo "=== PATCH Short: moves ==="
sed -n '/Compiled method (c2).*%/,/Compiled method/p' target/asm_patch_short.txt | \
    grep -c 'movd[lq]'

echo "=== BASE Byte: moves ==="
sed -n '/Compiled method (c2).*%/,/Compiled method/p' target/asm_base_byte.txt | \
    grep -c 'movd[lq]'

echo "=== BASE Short: moves ==="
sed -n '/Compiled method (c2).*%/,/Compiled method/p' target/asm_base_short.txt | \
    grep -c 'movd[lq]'

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

# Step 8: Observe the Peephole lea Conversions
echo "=== PATCH BYTE: peephole ==="
grep "peephole" target/peep_patch_byte.txt | sort | uniq -c | sort -rn
echo "=== PATCH SHORT: peephole ==="
grep "peephole" target/peep_patch_short.txt | sort | uniq -c | sort -rn
echo "=== BASE BYTE: peephole ==="
grep "peephole" target/peep_base_byte.txt | sort | uniq -c | sort -rn
echo "=== BASE SHORT: peephole ==="
grep "peephole" target/peep_base_short.txt | sort | uniq -c | sort -rn

# Step 9: Observe the XOR Chain Structure in Assembly
echo "=== PATCH SHORT: XOR placement ==="
sed -n '/Compiled method (c2).*%/,/Compiled method/p' target/asm_patch_short.txt | \
    grep -n 'xorl.*# int'

echo "=== PATCH BYTE: XOR placement ==="
sed -n '/Compiled method (c2).*%/,/Compiled method/p' target/asm_patch_byte.txt | \
    grep -n 'xorl.*# int'

echo "=== BASE SHORT: XOR placement ==="
sed -n '/Compiled method (c2).*%/,/Compiled method/p' target/asm_base_short.txt | \
    grep -n 'xorl.*# int'

echo "=== BASE BYTE: XOR placement ==="
sed -n '/Compiled method (c2).*%/,/Compiled method/p' target/asm_base_byte.txt | \
    grep -n 'xorl.*# int'