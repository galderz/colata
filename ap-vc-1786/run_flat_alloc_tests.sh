#!/usr/bin/env bash
#
# Comprehensive test: allocation events & flattening diagnostics for value classes.
#
# Sections:
#   A) Flag defaults & layout diagnostics
#   B) C2 escape analysis & allocation elimination
#   C) JDK built-in JFR
#   D) Patched async-profiler (default alloc mode)
#   E) Patched async-profiler (tlab mode)
#   F) Interpreter-only (tiny TLABs, maximum events)
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

JAVA_DBG="$HOME/src/jdk/build/fast-linux-aarch64/jdk/bin/java"
JAVAC_DBG="$HOME/src/jdk/build/fast-linux-aarch64/jdk/bin/javac"
JFR_DBG="$HOME/src/jdk/build/fast-linux-aarch64/jdk/bin/jfr"
AP_PATCHED="$HOME/src/async-profiler/build/lib/libasyncProfiler.so"

DIAG="-XX:+UnlockDiagnosticVMOptions -XX:+UnlockExperimentalVMOptions"
OPENS="--add-opens java.base/jdk.internal.value=ALL-UNNAMED --add-opens java.base/jdk.internal.misc=ALL-UNNAMED"
JAVA_OPTS="--enable-preview -cp . $OPENS"
SCENARIOS="smallFlatWrite smallFlatRead largeFlatNRWrite largeFlatNRRead largeRegWrite largeRegRead flatWriteNoEscape flatWriteEscaping flatReadTyped boxedAllocations identityBaseline"
OUTDIR="$SCRIPT_DIR/flat_diag_output"

rm -rf "$OUTDIR"
mkdir -p "$OUTDIR"

# ── helpers ──────────────────────────────────────────────────────────────
separator() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  $1"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

summarise_jfr() {
    local jfr_file="$1"
    echo "  Allocation samples by class:"
    for evt in jdk.ObjectAllocationInNewTLAB jdk.ObjectAllocationOutsideTLAB; do
        $JFR_DBG print --events "$evt" "$jfr_file" 2>/dev/null \
            | grep 'objectClass = ' \
            | sed 's/.*objectClass = //' \
            | sort | uniq -c | sort -rn
    done | sort -rn | head -20 || true
    echo ""
    echo "  Allocations by scenario (stack-based):"
    for scenario in $SCENARIOS; do
        local count
        count=$($JFR_DBG print --events jdk.ObjectAllocationInNewTLAB,jdk.ObjectAllocationOutsideTLAB \
                  "$jfr_file" 2>/dev/null | grep -c "$scenario" || true)
        printf "    %-25s %s samples\n" "$scenario" "$count"
    done
    echo ""
}

# ── compile ──────────────────────────────────────────────────────────────
echo "Compiling FlatAllocReproducer.java …"
$JAVAC_DBG --enable-preview --source 28 \
    --add-exports java.base/jdk.internal.value=ALL-UNNAMED \
    --add-exports java.base/jdk.internal.misc=ALL-UNNAMED \
    FlatAllocReproducer.java 2>/dev/null

# ══════════════════════════════════════════════════════════════════════════
separator "A) Flag defaults & layout diagnostics"
# ══════════════════════════════════════════════════════════════════════════

echo "  --enable-preview flag defaults:"
$JAVA_DBG --enable-preview $DIAG -XX:+PrintFlagsFinal -version 2>&1 \
    | grep -E "UseArrayFlat|UseFieldFlat|NullFree|NullableAtomic|NullableNon" | sed 's/^/    /' | grep -v "^Picked"
echo ""

echo "  Flags: PrintInlineLayout, PrintFlatArrayLayout"
$JAVA_DBG $JAVA_OPTS $DIAG \
    -XX:+PrintInlineLayout -XX:+PrintFlatArrayLayout \
    FlatAllocReproducer > "$OUTDIR/layout_output.log" 2>&1 || true

echo ""
echo "  ── SmallVP layout (1 int → nullable flat OK) ──"
grep -A 22 'FlatAllocReproducer\$SmallVP' "$OUTDIR/layout_output.log" | head -22
echo ""
echo "  ── LargeVP layout (2 ints → nullable flat NOT OK) ──"
grep -A 22 'FlatAllocReproducer\$LargeVP' "$OUTDIR/layout_output.log" | head -22
echo ""
echo "  ── Flat arrays created ──"
grep -A 4 "Flat Type Array" "$OUTDIR/layout_output.log" || echo "  (none)"
echo ""
echo "  ── Array properties (runtime) ──"
grep -E "isFlatArray|flat=|shallow=" "$OUTDIR/layout_output.log" | head -10
echo ""

# ══════════════════════════════════════════════════════════════════════════
separator "B) C2 escape analysis & allocation elimination"
# ══════════════════════════════════════════════════════════════════════════
echo "  Flags: PrintEscapeAnalysis, PrintEliminateAllocations, PrintCompilation"
echo ""

$JAVA_DBG $JAVA_OPTS $DIAG \
    -XX:+PrintEscapeAnalysis -XX:+PrintEliminateAllocations \
    -XX:+PrintCompilation \
    -Xlog:jit+inlining=debug:file="$OUTDIR/jit_inlining.log":tags,level \
    FlatAllocReproducer > "$OUTDIR/escape_analysis.log" 2>&1 || true

echo "  Per-method C2 decisions:"
echo ""
for method in $SCENARIOS; do
    scalar=$(grep "Scalar " "$OUTDIR/escape_analysis.log" | grep -c "$method" || true)
    not_scalar=$(grep "NotScalar" "$OUTDIR/escape_analysis.log" | grep -c "$method" || true)
    eliminated=$(grep -B20 "Eliminated" "$OUTDIR/escape_analysis.log" | grep -c "$method" || true)
    compilations=$(grep "FlatAllocReproducer::${method}" "$OUTDIR/escape_analysis.log" | grep -c "%" || true)
    regular_comp=$(grep "FlatAllocReproducer::${method}" "$OUTDIR/escape_analysis.log" | grep -cv "%" 2>/dev/null || true)

    printf "    %-25s " "$method"
    if [[ $scalar -gt 0 || $not_scalar -gt 0 ]]; then
        printf "Scalar=%-3d NotScalar=%-3d " "$scalar" "$not_scalar"
    else
        printf "no alloc nodes in C2 IR    "
    fi
    printf "(OSR=%d, regular=%d)\n" "$compilations" "$regular_comp"
done
echo ""

echo "  Allocation elimination detail (unique sites):"
grep -E "Scalar |NotScalar|Eliminated" "$OUTDIR/escape_analysis.log" | \
    sed 's/.*jvms: /    /' | sort -u | head -40
echo ""

# ══════════════════════════════════════════════════════════════════════════
separator "C) JDK built-in JFR"
# ══════════════════════════════════════════════════════════════════════════
echo "  Running with JDK Flight Recorder …"
$JAVA_DBG $JAVA_OPTS $DIAG \
    -XX:StartFlightRecording="jdk.ObjectAllocationInNewTLAB#enabled=true,jdk.ObjectAllocationOutsideTLAB#enabled=true,filename=$OUTDIR/flat_jfr_builtin.jfr,dumponexit=true" \
    FlatAllocReproducer 2>&1 | grep -E "Steady|Done|flat=|isFlatArray|Array prop|^$" || true
echo ""
summarise_jfr "$OUTDIR/flat_jfr_builtin.jfr"

# ══════════════════════════════════════════════════════════════════════════
separator "D) Patched async-profiler – default alloc (JVMTI SampledObjectAlloc)"
# ══════════════════════════════════════════════════════════════════════════
if [[ -f "$AP_PATCHED" ]]; then
    echo "  Running …"
    $JAVA_DBG $JAVA_OPTS $DIAG \
        -agentpath:"${AP_PATCHED}=start,event=alloc,file=$OUTDIR/flat_ap_patched.jfr" \
        FlatAllocReproducer 2>&1 | grep -E "Steady|Done|flat=|isFlatArray|^$" || true
    echo ""
    summarise_jfr "$OUTDIR/flat_ap_patched.jfr"
else
    echo "  SKIPPED – $AP_PATCHED not found"
fi

# ══════════════════════════════════════════════════════════════════════════
separator "E) Patched async-profiler – tlab mode (breakpoint trap)"
# ══════════════════════════════════════════════════════════════════════════
if [[ -f "$AP_PATCHED" ]]; then
    echo "  Running …"
    $JAVA_DBG $JAVA_OPTS $DIAG \
        -agentpath:"${AP_PATCHED}=start,event=alloc,tlab,file=$OUTDIR/flat_ap_tlab.jfr" \
        FlatAllocReproducer 2>&1 | grep -E "Steady|Done|flat=|isFlatArray|^$" || true
    echo ""
    summarise_jfr "$OUTDIR/flat_ap_tlab.jfr"
else
    echo "  SKIPPED – $AP_PATCHED not found"
fi

# ══════════════════════════════════════════════════════════════════════════
separator "F) Interpreter-only (no JIT, tiny TLAB → max TLAB events)"
# ══════════════════════════════════════════════════════════════════════════
echo "  Flags: -Xint -XX:TLABSize=4k -XX:-ResizeTLAB"
echo ""
$JAVA_DBG $JAVA_OPTS $DIAG -Xint \
    -XX:TLABSize=4k -XX:-ResizeTLAB \
    -XX:StartFlightRecording="jdk.ObjectAllocationInNewTLAB#enabled=true,jdk.ObjectAllocationOutsideTLAB#enabled=true,filename=$OUTDIR/flat_jfr_xint.jfr,dumponexit=true" \
    FlatAllocReproducer 2>&1 | grep -E "Steady|Done|flat=|isFlatArray|^$" || true
echo ""
summarise_jfr "$OUTDIR/flat_jfr_xint.jfr"

# ══════════════════════════════════════════════════════════════════════════
separator "ANALYSIS"
# ══════════════════════════════════════════════════════════════════════════
cat <<'EOF'

  IMPORTANT: flattening flags default to TRUE only with --enable-preview.

  Array classification:
    small[]    = new SmallVP[N]                      → FLAT (nullable, NULLABLE_ATOMIC_FLAT)
    largeNR[]  = newNullRestrictedAtomicArray(LargeVP)→ FLAT (null-free, NULL_FREE_ATOMIC_FLAT)
    largeReg[] = new LargeVP[N]                      → NOT FLAT (nullable, no NULLABLE_ATOMIC_FLAT)

  Why new LargeVP[N] is NOT flat:
    LargeVP payload = 8 bytes (2 ints) + 1 null marker = 9 bytes
    round_up_power_of_2(9) = 16 > MAX_ATOMIC_OP_SIZE (8)
    → NULLABLE_ATOMIC_FLAT is not available

  Why new SmallVP[N] IS flat:
    SmallVP payload = 4 bytes (1 int) + 1 null marker = 5 bytes
    round_up_power_of_2(5) = 8 ≤ MAX_ATOMIC_OP_SIZE (8)
    → NULLABLE_ATOMIC_FLAT layout: 8/8

  Expected results per scenario:

  #   Scenario              Array   Flat?  Alloc events?  Why
  ──  ────────────────────  ──────  ─────  ─────────────  ─────────────────────────────
  1   smallFlatWrite        small   YES    FEW/NONE       C2 scalarises new; aastore
                                                          copies fields inline.
  2   smallFlatRead         small   YES    YES            aaload buffers flat→heap.
  3   largeFlatNRWrite      lrgNR   YES    FEW/NONE       C2 scalarises new; aastore
                                                          copies fields inline.
  4   largeFlatNRRead       lrgNR   YES    YES            aaload buffers flat→heap.
  5   largeRegWrite         lrgReg  NO     YES            new allocates on heap,
                                                          aastore stores compressed oop.
  6   largeRegRead          lrgReg  NO     NONE           Returns existing heap oop.
  7   flatWriteNoEscape     lrgNR   YES    FEW/NONE       Same as #3 (baseline).
  8   flatWriteEscaping     lrgNR   YES    YES            Value crosses method boundaries
                                                          (createValue→processAndStore→
                                                          doStore→add); harder to scalarise.
  9   flatReadTyped         lrgNR   YES    FEW/NONE       Read into non-volatile LargeVP
                                                          field; C2 can scalarise.
  10  boxedAllocations      —       —      YES            value → Object forces boxing.
  11  identityBaseline      —       —      YES            Identity class always heap.

EOF

echo "  Diagnostic output saved to: $OUTDIR/"
echo "    layout_output.log       – PrintInlineLayout + PrintFlatArrayLayout + array props"
echo "    escape_analysis.log     – C2 escape analysis & allocation elimination"
echo "    jit_inlining.log        – JIT inlining decisions"
echo "    flat_jfr_builtin.jfr    – JFR from JIT run"
echo "    flat_jfr_xint.jfr       – JFR from interpreter-only run"
echo "    flat_ap_patched.jfr     – async-profiler (default alloc) JFR"
echo "    flat_ap_tlab.jfr        – async-profiler (tlab mode) JFR"
echo ""
echo "Done."
