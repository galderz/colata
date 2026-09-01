---
name: c2-x86-address-matching
description: >
  Debugging and understanding HotSpot C2 x86 address operand matching in the matcher/ADLC pipeline.
  Use when investigating how AddP nodes get matched to x86 memory operands (indIndex, indPosIndexOffset,
  indPosIndexScaleOffset, etc.), when ConvI2L or LShiftL folding into address expressions behaves
  unexpectedly, or when clone_shift/clone_conv in pd_clone_address_expressions causes regressions.
  Covers normal array access vs Unsafe access address structures, operand selection, and
  the clone-based address subsumption mechanism. Related to JDK-8387146.
---

# C2 x86 Address Operand Matching

## Overview

The C2 compiler's matcher translates ideal graph nodes into machine-specific instructions.
For memory operations (loads/stores), the matcher selects x86 **memory operands** that encode
the addressing mode (`[base + index + displacement]`, `[base + index*scale + displacement]`, etc.).

The key file is `src/hotspot/cpu/x86/x86.ad`, specifically:
- **`pd_clone_address_expressions`** — decides whether to clone sub-expressions (shifts, conversions) so they can be folded into complex address operands
- **`clone_shift`** — clones `LShiftL` nodes (with optional inner `ConvI2L`)
- **`clone_conv`** — clones bare `ConvI2L` nodes (added by JDK-8387146)

## x86 Memory Operands

The available operands are defined in `src/hotspot/cpu/x86/x86.ad`. Key operands for understanding
address matching:

| Operand | Pattern | Takes ConvI2L? | Has Const Offset? |
|---------|---------|----------------|-------------------|
| `indirect` | `reg` | No | No |
| `indOffset32` | `AddP(reg, imm32)` | No | Yes |
| `indIndex` | `AddP(reg, rRegL)` | No (takes long reg) | No |
| `indIndexOffset` | `AddP(AddP(reg, rRegL), imm32)` | No (takes long reg) | Yes |
| `indPosIndexOffset` | `AddP(AddP(reg, ConvI2L(rRegI)), imm32)` | **Yes** | Yes |
| `indIndexScale` | `AddP(reg, LShiftL(rRegL, scale))` | No | No |
| `indPosIndexScale` | `AddP(reg, LShiftL(ConvI2L(rRegI), scale))` | **Yes** | No |
| `indIndexScaleOffset` | `AddP(AddP(reg, LShiftL(rRegL, scale)), imm32)` | No | Yes |
| `indPosIndexScaleOffset` | `AddP(AddP(reg, LShiftL(ConvI2L(rRegI), scale)), imm32)` | **Yes** | Yes |

**Important:** There is **no `indPosIndex`** operand matching `AddP(reg, ConvI2L(rRegI))` —
i.e., a flat AddP with a ConvI2L offset and no constant displacement.

### Why this matters

When `clone_conv` clones a `ConvI2L` node, the clone is only useful if the resulting address
tree matches an `indPos*` operand that folds the ConvI2L (using `rRegI` instead of `rRegL`).
If no such operand matches the tree shape, the cloned ConvI2L becomes a standalone
`convI2L_reg_reg` instruction — adding code with no benefit.

## AddP Node Structures

### Normal Array Access: `b[i]`

For `byte[] b` accessed as `b[i]`, the ideal graph produces a **nested AddP** structure:

```
AddP(base, AddP(base, base, ConvI2L(i)), array_header_offset)
```

This matches `indPosIndexOffset`: `[base + i + header_offset]`.
The ConvI2L is folded — no `convI2L_reg_reg` instruction is emitted.

### Normal Array Access: `short[i]` / `char[i]`

For `short[]` or `char[]`, element scaling introduces a `LShiftL`:

```
AddP(base, AddP(base, base, LShiftL(ConvI2L(i), 1)), array_header_offset)
```

This matches `indPosIndexScaleOffset`: `[base + i*2 + header_offset]`.

### Unsafe Access: `Unsafe.getByte(obj, (long) offset)`

For Unsafe byte access, the ideal graph produces a **flat AddP**:

```
AddP(base, base, ConvI2L(offset))
```

There is **no nested AddP** and **no constant displacement**. Since no `indPosIndex` operand
exists, this can only match `indIndex(reg, rRegL)`. Cloning the ConvI2L here is pointless —
it cannot be folded.

## pd_clone_address_expressions Flow

The method has two main paths:

### Path 1: Constant offset (`off->is_Con()`)

```
AddP(base, adr, const_off)
```

If `adr` is itself an `AddP` (nested), it looks at the inner AddP's offset and tries to
`clone_shift` or `clone_conv` it. This is the path for normal array access.

### Path 2: Non-constant offset (`else if`)

```
AddP(base, base, shift_or_conv)
```

The offset itself is a shift or ConvI2L. `clone_shift` or `clone_conv` is called directly
on the offset. This is the path for Unsafe access with a ConvI2L offset.

**Regression risk:** Cloning ConvI2L on Path 2 for flat AddP nodes (no nested AddP, no const
displacement) produces extra `convI2L_reg_reg` instructions with no matching benefit.

## Debugging: Adding Logging

### Logging in pd_clone_address_expressions

Add behind a `UseNewCode2` (or similar develop flag) to trace which path is taken and what
gets cloned. Insert at the top of `pd_clone_address_expressions` in `src/hotspot/cpu/x86/x86.ad`:

```cpp
// At the start of pd_clone_address_expressions, after getting off:
if (UseNewCode2) {
  tty->print("[pd_clone_addr] AddP(%d): base=%s(%d) adr=%s(%d) off=%s(%d)",
             m->_idx,
             m->in(AddPNode::Base)->Name(), m->in(AddPNode::Base)->_idx,
             m->in(AddPNode::Address)->Name(), m->in(AddPNode::Address)->_idx,
             off->Name(), off->_idx);
  tty->print(" off->is_Con=%d", off->is_Con());
  // Print users of this AddP
  tty->print(" users=[");
  for (DUIterator_Fast imax, i = m->fast_outs(imax); i < imax; i++) {
    Node* use = m->fast_out(i);
    tty->print("%s(%d) ", use->Name(), use->_idx);
  }
  tty->print_cr("]");
}
```

Add inside the nested AddP branch (Path 1):

```cpp
if (UseNewCode2) {
  tty->print_cr("[pd_clone_addr]   PATH=nested_addp, inner_off=%s(%d) outcnt=%d",
                 shift_or_conv->Name(), shift_or_conv->_idx, shift_or_conv->outcnt());
}
```

Add inside the simple const offset branch:

```cpp
if (UseNewCode2) {
  tty->print_cr("[pd_clone_addr]   PATH=simple_const_off");
}
```

Add inside the else-if branch (Path 2):

```cpp
if (UseNewCode2) {
  tty->print_cr("[pd_clone_addr]   PATH=non_const_off_cloned (shift or conv)");
}
```

Add at the end (no match):

```cpp
if (UseNewCode2) {
  tty->print_cr("[pd_clone_addr]   PATH=no_match, returning false");
}
```

### Running with logging

Build with fastdebug, then:

```bash
# Normal array access — should show PATH=nested_addp with clone
java -XX:CompileCommand=PrintIdealPhase,ClassName::method,MATCHING \
     -XX:+UseNewCode2 ClassName

# Unsafe access — will show PATH=non_const_off_cloned
java --add-opens java.base/jdk.internal.misc=ALL-UNNAMED \
     -XX:CompileCommand=PrintIdealPhase,ClassName::method,MATCHING \
     -XX:+UseNewCode2 ClassName
```

### Checking convI2L counts after matching

Use `-XX:CompileCommand=PrintIdealPhase,...,MATCHING` and grep for `convI2L_reg_reg`:

```bash
java -XX:CompileCommand=PrintIdealPhase,Test::method,MATCHING Test 2>&1 \
  | grep convI2L_reg_reg
```

Fewer `convI2L_reg_reg` nodes means the ConvI2L was successfully folded into address operands.
More nodes (especially after cloning) means the cloning was counterproductive.

### Using the IR test framework

The `IRNode.X86_SCONV_I2L` constant (added by JDK-8387146) matches `convI2L_reg_reg` in the
MATCHING phase:

```java
@IR(counts = {IRNode.X86_SCONV_I2L, "= 0"},
    applyIfPlatform = {"x64", "true"},
    phase = CompilePhase.MATCHING)
```

## Key Lessons from JDK-8387146

1. **Cloning is only beneficial when the clone can be folded.** If no operand exists to subsume
   the cloned node, it becomes a standalone instruction — a regression.

2. **Normal array access vs Unsafe access produce different AddP structures.** Normal array
   access has nested AddP with a constant header offset. Unsafe access may produce flat AddP
   nodes with no constant displacement.

3. **The `else if` branch in `pd_clone_address_expressions` (Path 2) is risky for `clone_conv`.**
   It handles flat `AddP(base, base, ConvI2L)` where no `indPosIndex` operand exists.
   `clone_shift` is safe there because `indPosIndexScale` exists for `AddP(reg, LShiftL(ConvI2L, scale))`.

4. **AArch64 has its own `pd_clone_address_expressions`** in `src/hotspot/cpu/aarch64/aarch64.ad`
   with different operand definitions. Fixes must be validated per-architecture.

5. **Shared ConvI2L nodes are the symptom.** When a ConvI2L has multiple AddP users, cloning
   it (one copy per user) is only correct if each copy gets folded. Otherwise you multiply
   standalone instructions.

## Reference Files

- `src/hotspot/cpu/x86/x86.ad` — operand definitions, `pd_clone_address_expressions`, `clone_shift`, `clone_conv`
- `src/hotspot/cpu/aarch64/aarch64.ad` — AArch64 equivalent (has native ConvI2L cloning support)
- `src/hotspot/share/opto/matcher.cpp` — shared matcher logic, `find_shared`, `is_visited`
- `test/hotspot/jtreg/compiler/lib/ir_framework/IRNode.java` — IR test node constants
- `test/hotspot/jtreg/compiler/c2/TestArrayAddressing.java` — test for JDK-8387146
