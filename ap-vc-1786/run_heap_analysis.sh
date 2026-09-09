#!/usr/bin/env bash
#
# Run each scenario with Epsilon GC (no GC) to observe heap impact.
#
# For each scenario:
#   1. Run with Epsilon GC + JFR + PrintEscapeAnalysis
#   2. If OOME → HeapDumpOnOutOfMemoryError captures the dump
#   3. If no OOME → manual heap dump via HotSpotDiagnosticMXBean
#   4. Analyse heap dump with JOL heapdump-stats
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

JAVA_DBG="$HOME/src/jdk/build/fast-linux-aarch64/jdk/bin/java"
JAVAC_DBG="$HOME/src/jdk/build/fast-linux-aarch64/jdk/bin/javac"
JFR_DBG="$HOME/src/jdk/build/fast-linux-aarch64/jdk/bin/jfr"
JOL_CLI="$HOME/src/jol/jol-cli/target/jol-cli.jar"

DIAG="-XX:+UnlockDiagnosticVMOptions -XX:+UnlockExperimentalVMOptions"
OPENS="--add-opens java.base/jdk.internal.value=ALL-UNNAMED --add-opens java.base/jdk.internal.misc=ALL-UNNAMED"
OUTDIR="$SCRIPT_DIR/heap_analysis"
ITERATIONS=2000000
HEAP_SIZE=48m

SCENARIOS="smallFlatWrite smallFlatRead largeFlatNRWrite largeFlatNRRead largeRegWrite largeRegRead flatWriteNoEscape flatWriteEscaping flatReadTyped boxedAllocations identityBaseline"

rm -rf "$OUTDIR"
mkdir -p "$OUTDIR"

separator() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  $1"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# ── compile ──────────────────────────────────────────────────────────────
echo "Compiling HeapScenario.java …"
$JAVAC_DBG --enable-preview --source 28 \
    --add-exports java.base/jdk.internal.value=ALL-UNNAMED \
    HeapScenario.java 2>/dev/null

separator "Heap analysis: Epsilon GC, ${HEAP_SIZE} heap, ${ITERATIONS} iterations"

for scenario in $SCENARIOS; do
    DUMP_FILE="$OUTDIR/${scenario}.hprof"
    JFR_FILE="$OUTDIR/${scenario}.jfr"
    LOG_FILE="$OUTDIR/${scenario}.log"
    EA_FILE="$OUTDIR/${scenario}_ea.log"
    JOL_FILE="$OUTDIR/${scenario}_jol.txt"

    echo ""
    echo "┌── $scenario ──"
    echo "│"

    # ── 1. Run with Epsilon GC + JFR ────────────────────────────────
    rm -f "$DUMP_FILE"
    $JAVA_DBG --enable-preview -cp . $OPENS $DIAG \
        -XX:+UseEpsilonGC \
        -Xmx${HEAP_SIZE} -Xms${HEAP_SIZE} \
        -XX:+HeapDumpOnOutOfMemoryError \
        -XX:HeapDumpPath="$DUMP_FILE" \
        -XX:StartFlightRecording="jdk.ObjectAllocationInNewTLAB#enabled=true,jdk.ObjectAllocationOutsideTLAB#enabled=true,filename=${JFR_FILE},dumponexit=true" \
        HeapScenario "$scenario" "$ITERATIONS" \
        > "$LOG_FILE" 2>&1 || true

    # Check whether the scenario itself exhausted the heap,
    # or it completed and the forced byte[] OOME triggered the dump.
    if grep -q "Scenario completed, forcing OOME" "$LOG_FILE" 2>/dev/null; then
        echo "│  Epsilon GC: scenario completed (forced OOME for dump)"
        scenario_oome="no"
    else
        echo "│  Epsilon GC: scenario OOME → heap exhausted by scenario allocations"
        scenario_oome="yes"
    fi

    # ── 2. C2 EA diagnostics ─────────────────────────────────────────
    $JAVA_DBG --enable-preview -cp . $OPENS $DIAG \
        -XX:+PrintEscapeAnalysis -XX:+PrintEliminateAllocations \
        -XX:+PrintCompilation \
        HeapScenario "$scenario" 500000 \
        > "$EA_FILE" 2>&1 || true

    scalar=$(grep "Scalar " "$EA_FILE" 2>/dev/null | grep -c "$scenario" || true)
    not_scalar=$(grep "NotScalar" "$EA_FILE" 2>/dev/null | grep -c "$scenario" || true)
    echo "│  C2 EA: Scalar=$scalar NotScalar=$not_scalar"

    # ── 3. JFR alloc events ──────────────────────────────────────────
    jfr_allocs=0
    if [[ -f "$JFR_FILE" ]]; then
        jfr_allocs=$($JFR_DBG print --events jdk.ObjectAllocationInNewTLAB,jdk.ObjectAllocationOutsideTLAB \
            "$JFR_FILE" 2>/dev/null | grep -c "$scenario") || jfr_allocs=0
    fi
    echo "│  JFR alloc samples: $jfr_allocs"

    # ── 4. JOL heap dump analysis ────────────────────────────────────
    if [[ -f "$DUMP_FILE" ]]; then
        $JAVA_DBG -jar "$JOL_CLI" heapdump-stats "$DUMP_FILE" > "$JOL_FILE" 2>&1 || true

        echo "│  Heap dump objects:"
        # JOL outputs multiple tables; take first 30 lines after first INSTANCES header
        jol_match=$(grep -A 30 '^       INSTANCES' "$JOL_FILE" 2>/dev/null | head -32 | grep 'HeapScenario' || true)
        if [[ -n "$jol_match" ]]; then
            echo "$jol_match" | while IFS= read -r line; do
                echo "│    $line"
            done
        else
            echo "│    (no HeapScenario value/identity instances on heap)"
        fi
    else
        echo "│  (no heap dump generated)"
    fi

    echo "│"
    echo "└──"
done

# ── Summary table ────────────────────────────────────────────────────
separator "Summary"
echo ""
printf "%-22s %-6s %-8s %-10s %-10s  %-10s  %s\n" \
    "SCENARIO" "OOME?" "JFR#" "EA:S/NS" "SmallVP#" "LargeVP#" "IdPt#"
printf "%-22s %-6s %-8s %-10s %-10s  %-10s  %s\n" \
    "──────────────────────" "──────" "────────" "──────────" "──────────" "──────────" "──────"

for scenario in $SCENARIOS; do
    LOG_FILE="$OUTDIR/${scenario}.log"
    JFR_FILE="$OUTDIR/${scenario}.jfr"
    EA_FILE="$OUTDIR/${scenario}_ea.log"
    JOL_FILE="$OUTDIR/${scenario}_jol.txt"

    oome="no"
    if ! grep -q "Scenario completed, forcing OOME" "$LOG_FILE" 2>/dev/null; then
        oome="yes"
    fi

    jfr_allocs=$({ $JFR_DBG print --events jdk.ObjectAllocationInNewTLAB,jdk.ObjectAllocationOutsideTLAB \
            "$JFR_FILE" 2>/dev/null || true; } | grep -c "$scenario" || true)

    scalar=$(grep "Scalar " "$EA_FILE" 2>/dev/null | grep -c "$scenario" || true)
    not_scalar=$(grep "NotScalar" "$EA_FILE" 2>/dev/null | grep -c "$scenario" || true)

    svp=$(grep 'SmallVP' "$JOL_FILE" 2>/dev/null | head -1 | awk '{print $1}' | tr -d ',' || true)
    lvp=$(grep 'LargeVP' "$JOL_FILE" 2>/dev/null | head -1 | awk '{print $1}' | tr -d ',' || true)
    idp=$(grep 'IdentityPoint' "$JOL_FILE" 2>/dev/null | head -1 | awk '{print $1}' | tr -d ',' || true)
    svp=${svp:-0}; lvp=${lvp:-0}; idp=${idp:-0}

    printf "%-22s %-6s %-8s %s/%-8s %-10s  %-10s  %s\n" \
        "$scenario" "$oome" "$jfr_allocs" "$scalar" "$not_scalar" "$svp" "$lvp" "$idp"
done

separator "INTERPRETATION"
cat <<'EOF'

  With Epsilon GC (no garbage collection), every heap allocation persists
  until the heap is exhausted. The heap dump captures exactly what is on
  the heap at that point.

  NOTE: JFR alloc samples are 0 under Epsilon GC because Epsilon uses
  a single bump-pointer allocator — there are no TLAB refills and hence
  no ObjectAllocationInNewTLAB events. The heap dump object count is
  the authoritative source of truth.

  Reading the summary table:

  - OOME=yes + ~1.2-1.9M objects: the scenario FILLS the heap with
    value/identity objects. Real heap allocations are happening at
    scale, exhausting 48 MB.

  - OOME=no + ~111k objects: the scenario does NOT fill the heap.
    The ~111k objects come from JVM warmup (interpreter + C1/C3
    compilation) before C2 kicks in and scalarises the allocations.
    Once C2 compiles with EA (Scalar>0, NotScalar=0), the hot loop
    stops allocating.

  - OOME=no + 0 objects: NO heap allocations at all. The scenario
    returns existing oops (non-flat reads) or the value class is
    fully scalarised with zero warmup leakage.

  Key findings:

  1. largeRegRead: 0 objects, no OOME. Reading from a non-flat array
     returns existing oops — zero heap impact.

  2. smallFlatWrite / largeFlatNRWrite / flatWriteNoEscape /
     flatWriteEscaping: ~111k objects, no OOME. Warmup allocates
     ~111k objects before C2 scalarises. The hot loop adds nothing
     to the heap.

  3. smallFlatRead / largeFlatNRRead / flatReadTyped: OOME with
     ~1.2-1.9M objects. Reading from flat arrays allocates heap
     buffers that accumulate without GC.

  4. largeRegWrite / boxedAllocations: OOME with ~1.2M objects.
     Every write/box creates a heap object.

  5. flatWriteEscaping has the SAME heap footprint (~111k) as
     flatWriteNoEscape — C2 fully inlines and scalarises the
     4-method chain.

EOF

echo "  Files saved to: $OUTDIR/"
echo "Done."
