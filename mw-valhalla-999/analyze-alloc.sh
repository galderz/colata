#!/usr/bin/env bash
set -euo pipefail

JAVA_HOME="${JAVA_HOME:-$HOME/src/jdk-mw-valhalla/build/release-darwin-arm64/jdk}"
JFR_CMD="$JAVA_HOME/bin/jfr"

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Analyze JVM allocation rates from GC logs and JFR recordings.

Options:
  --gc-log <path>       Path to GC log file (required)
  --jfr <path>          Path to JFR recording file (optional)
  --java-home <path>    JAVA_HOME for jfr tool (default: \$JAVA_HOME)
  --steady-start <sec>  Uptime (seconds) to begin steady-state window (default: auto-detect)
  --steady-end <sec>    Uptime (seconds) to end steady-state window (default: end of log)
  --classes <list>      Comma-separated fully qualified class names for focused analysis
                        (requires --jfr with allocation events; supports inner classes with \$)
  -h, --help            Show this help

Example:
  $(basename "$0") --gc-log gc.log --jfr recording.jfr
  $(basename "$0") --gc-log gc.log --jfr recording.jfr \\
    --classes 'org.hibernate.engine.spi.EntityKey,org.acme.dto.StoreDTO'
EOF
    exit 0
}

GC_LOG=""
JFR_FILE=""
STEADY_START=""
STEADY_END=""
FOCUS_CLASSES=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --gc-log) GC_LOG="$2"; shift 2 ;;
        --jfr) JFR_FILE="$2"; shift 2 ;;
        --java-home) JAVA_HOME="$2"; JFR_CMD="$JAVA_HOME/bin/jfr"; shift 2 ;;
        --steady-start) STEADY_START="$2"; shift 2 ;;
        --steady-end) STEADY_END="$2"; shift 2 ;;
        --classes) FOCUS_CLASSES="$2"; shift 2 ;;
        -h|--help) usage ;;
        *) echo "Unknown option: $1"; usage ;;
    esac
done

if [[ -z "$GC_LOG" ]]; then
    echo "Error: --gc-log is required"
    exit 1
fi

if [[ ! -f "$GC_LOG" ]]; then
    echo "Error: GC log file not found: $GC_LOG"
    exit 1
fi

SEP="$(printf '=%.0s' {1..78})"
SEP2="$(printf -- '-%.0s' {1..78})"

echo "$SEP"
echo "  JVM Allocation Rate Analysis"
echo "$SEP"
echo ""

# ─── Section 1: GC Configuration ───────────────────────────────────────────────

echo "## GC Configuration"
echo ""
gc_type=$(grep -m1 'Using G1\|Using ZGC\|Using Shenandoah\|Using Serial\|Using Parallel' "$GC_LOG" | sed 's/.*Using /Using /' | sed 's/\s*$//' || true)
heap_init=$(grep -m1 'Heap Initial Capacity' "$GC_LOG" | sed 's/.*Heap Initial Capacity: //' || true)
heap_max=$(grep -m1 'Heap Max Capacity' "$GC_LOG" | sed 's/.*Heap Max Capacity: //' || true)
region_size=$(grep -m1 'Heap Region Size' "$GC_LOG" | sed 's/.*Heap Region Size: //' || true)
cpus_total=$(grep -m1 'CPUs:' "$GC_LOG" | sed 's/.*CPUs: //' || true)
gc_workers=$(grep -m1 'Parallel Workers' "$GC_LOG" | sed 's/.*Parallel Workers: //' || true)
jdk_version=$(grep -m1 'Version:' "$GC_LOG" | sed 's/.*Version: //' || true)

printf "  %-24s %s\n" "GC Collector:" "${gc_type:-unknown}"
printf "  %-24s %s\n" "JDK Version:" "${jdk_version:-unknown}"
printf "  %-24s %s\n" "Heap (initial/max):" "${heap_init:-?} / ${heap_max:-?}"
printf "  %-24s %s\n" "Region Size:" "${region_size:-unknown}"
printf "  %-24s %s\n" "CPUs:" "${cpus_total:-unknown}"
printf "  %-24s %s\n" "GC Workers:" "${gc_workers:-unknown}"
echo ""

# ─── Section 2: Extract all Young GC events ────────────────────────────────────

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

# Parse Young GC summary lines: uptime, before_mb, after_mb, pause_ms
grep '\[gc ' "$GC_LOG" | grep 'Pause Young' | \
    sed -n 's/.*\[\([0-9]*\.[0-9]*\)s\].*Pause Young.*) \([0-9]*\)M->\([0-9]*\)M([0-9]*M) \([0-9]*\.[0-9]*\)ms/\1 \2 \3 \4/p' \
    > "$TMPDIR/young_gc.txt"

total_young_gc=$(wc -l < "$TMPDIR/young_gc.txt" | tr -d ' ')

# Parse Eden region counts per GC
grep '\[gc,heap' "$GC_LOG" | grep 'Eden regions' | \
    sed -n 's/.*\[\([0-9]*\.[0-9]*\)s\].*Eden regions: \([0-9]*\)->0(\([0-9]*\))/\1 \2 \3/p' \
    > "$TMPDIR/eden.txt"

# Parse Survivor region counts
grep '\[gc,heap' "$GC_LOG" | grep 'Survivor regions' | \
    sed -n 's/.*\[\([0-9]*\.[0-9]*\)s\].*Survivor regions: \([0-9]*\)->\([0-9]*\)(\([0-9]*\))/\1 \2 \3 \4/p' \
    > "$TMPDIR/survivor.txt"

# Parse Old region counts
grep '\[gc,heap' "$GC_LOG" | grep 'Old regions' | \
    sed -n 's/.*\[\([0-9]*\.[0-9]*\)s\].*Old regions: \([0-9]*\)->\([0-9]*\)/\1 \2 \3/p' \
    > "$TMPDIR/old.txt"

# ─── Section 3: Auto-detect steady state ───────────────────────────────────────

# Steady state = region where GC interval coefficient of variation < 0.15
# Uses a sliding window of 20 GCs

if [[ -z "$STEADY_START" ]]; then
    STEADY_START=$(awk '
    NR > 1 { dt = $1 - prev; dts[NR] = dt; uptimes[NR] = $1 }
    { prev = $1 }
    END {
        w = 20
        best_cv = 999; best_start = 0
        for (i = 2; i <= NR - w; i++) {
            sum = 0; sum2 = 0
            for (j = i; j < i + w; j++) {
                sum += dts[j]; sum2 += dts[j] * dts[j]
            }
            mean = sum / w
            var = sum2 / w - mean * mean
            if (var < 0) var = 0
            sd = sqrt(var)
            cv = (mean > 0) ? sd / mean : 999
            if (cv < best_cv && mean < 2) { best_cv = cv; best_start = uptimes[i] }
        }
        printf "%.1f\n", best_start
    }' "$TMPDIR/young_gc.txt")
fi

if [[ -z "$STEADY_END" ]]; then
    STEADY_END=$(tail -1 "$TMPDIR/young_gc.txt" | awk '{print $1}')
fi

echo "## Load Phases"
echo ""

first_uptime=$(head -1 "$TMPDIR/young_gc.txt" | awk '{print $1}')
last_uptime=$(tail -1 "$TMPDIR/young_gc.txt" | awk '{print $1}')

printf "  %-24s %.1fs - %.1fs\n" "Full GC log span:" "$first_uptime" "$last_uptime"
printf "  %-24s %.1fs - %.1fs\n" "Steady-state window:" "$STEADY_START" "$STEADY_END"
printf "  %-24s %d\n" "Total Young GC count:" "$total_young_gc"

steady_gc_count=$(awk -v s="$STEADY_START" -v e="$STEADY_END" '$1 >= s && $1 <= e' "$TMPDIR/young_gc.txt" | wc -l | tr -d ' ')
printf "  %-24s %d\n" "Steady-state GC count:" "$steady_gc_count"
echo ""

# ─── Section 4: Global Allocation Rate ─────────────────────────────────────────

echo "## Global Allocation Rate (Steady State)"
echo ""

# Region size in MB (parse from config, default 1)
region_mb=$(echo "${region_size:-1M}" | sed 's/M//')

awk -v s="$STEADY_START" -v e="$STEADY_END" -v rmb="$region_mb" '
BEGIN { n=0; prev_t=0 }
$1 >= s && $1 <= e {
    if (prev_t > 0) {
        dt = $1 - prev_t
        alloc_mb = ($2 - $3)
        rate = alloc_mb / dt
        rates[n] = rate
        dts[n] = dt
        pauses[n] = $4
        allocs[n] = alloc_mb
        n++
    }
    prev_t = $1
}
END {
    if (n == 0) { print "  No data in steady-state window"; exit }

    sum_rate=0; sum_dt=0; sum_pause=0; sum_alloc=0
    min_rate=999999; max_rate=0
    min_pause=999999; max_pause=0
    for (i=0; i<n; i++) {
        sum_rate += rates[i]
        sum_dt += dts[i]
        sum_pause += pauses[i]
        sum_alloc += allocs[i]
        if (rates[i] < min_rate) min_rate = rates[i]
        if (rates[i] > max_rate) max_rate = rates[i]
        if (pauses[i] < min_pause) min_pause = pauses[i]
        if (pauses[i] > max_pause) max_pause = pauses[i]
    }
    avg_rate = sum_rate / n
    avg_dt = sum_dt / n
    avg_pause = sum_pause / n
    total_alloc_gb = sum_alloc / 1024

    # p50/p99 for rate (sort)
    for (i=0; i<n-1; i++)
        for (j=i+1; j<n; j++)
            if (rates[i] > rates[j]) { t=rates[i]; rates[i]=rates[j]; rates[j]=t }
    p50_rate = rates[int(n*0.50)]
    p99_rate = rates[int(n*0.99)]

    # p50/p99 for pause
    for (i=0; i<n-1; i++)
        for (j=i+1; j<n; j++)
            if (pauses[i] > pauses[j]) { t=pauses[i]; pauses[i]=pauses[j]; pauses[j]=t }
    p50_pause = pauses[int(n*0.50)]
    p99_pause = pauses[int(n*0.99)]

    printf "  %-32s %.0f MB/s\n",  "Avg allocation rate:", avg_rate
    printf "  %-32s %.0f MB/s\n",  "p50 allocation rate:", p50_rate
    printf "  %-32s %.0f MB/s\n",  "p99 allocation rate:", p99_rate
    printf "  %-32s %.0f - %.0f MB/s\n", "Range:", min_rate, max_rate
    printf "  %-32s %.1f GB\n",    "Total allocated (steady):", total_alloc_gb
    printf "\n"
    printf "  %-32s %.0f ms\n",    "Avg GC interval:", avg_dt * 1000
    printf "  %-32s %.1f GCs/sec\n", "GC frequency:", 1.0 / avg_dt
    printf "\n"
    printf "  %-32s %.2f ms\n",    "Avg pause time:", avg_pause
    printf "  %-32s %.2f ms\n",    "p50 pause time:", p50_pause
    printf "  %-32s %.2f ms\n",    "p99 pause time:", p99_pause
    printf "  %-32s %.2f - %.2f ms\n", "Pause range:", min_pause, max_pause
    printf "\n"
    printf "  %-32s %.2f%%\n",     "GC overhead:", (sum_pause / (sum_dt * 1000)) * 100
}
' "$TMPDIR/young_gc.txt"

echo ""

# ─── Section 5: Eden / Survivor / Old Gen Analysis ─────────────────────────────

echo "## Heap Region Analysis (Steady State)"
echo ""

awk -v s="$STEADY_START" -v e="$STEADY_END" -v rmb="$region_mb" '
$1 >= s && $1 <= e {
    sum += $2; n++
    if (n==1) { first=$2; min_e=$2; max_e=$2 }
    last=$2
    if ($2 < min_e) min_e=$2
    if ($2 > max_e) max_e=$2
}
END {
    if (n==0) exit
    printf "  Eden regions filled per GC:      %d (avg), range %d-%d\n", sum/n, min_e, max_e
    printf "  Eden allocation per GC:           %d MB (avg)\n", (sum/n)*rmb
}' "$TMPDIR/eden.txt"

awk -v s="$STEADY_START" -v e="$STEADY_END" -v rmb="$region_mb" '
$1 >= s && $1 <= e {
    sum_after += $3; n++
    if (n==1) { min_s=$3; max_s=$3 }
    if ($3 < min_s) min_s=$3
    if ($3 > max_s) max_s=$3
}
END {
    if (n==0) exit
    printf "  Survivor regions after GC:        %d (avg), range %d-%d\n", sum_after/n, min_s, max_s
    printf "  Survivor occupancy:               %d MB (avg)\n", (sum_after/n)*rmb
}' "$TMPDIR/survivor.txt"

awk -v s="$STEADY_START" -v e="$STEADY_END" -v rmb="$region_mb" '
$1 >= s && $1 <= e {
    n++
    if (n==1) { first=$3 }
    last=$3
}
END {
    if (n==0) exit
    growth = last - first
    printf "  Old gen regions:                  %d -> %d (growth: %d regions = %d MB)\n", first, last, growth, growth*rmb
}' "$TMPDIR/old.txt"

echo ""

# ─── Section 6: Promotion Rate ─────────────────────────────────────────────────

echo "## Promotion Rate"
echo ""

awk -v s="$STEADY_START" -v e="$STEADY_END" -v rmb="$region_mb" '
$1 >= s && $1 <= e {
    n++
    if (n==1) { first_old=$3; first_t=$1 }
    last_old=$3; last_t=$1
}
END {
    if (n==0) exit
    growth = last_old - first_old
    dt = last_t - first_t
    if (dt > 0) {
        rate_mb_s = (growth * rmb) / dt
        printf "  Old gen growth:                   %d MB over %.0fs\n", growth*rmb, dt
        printf "  Promotion rate:                   %.2f MB/s\n", rate_mb_s
    } else {
        printf "  Old gen growth:                   %d MB\n", growth*rmb
    }
}' "$TMPDIR/old.txt"

echo ""

# ─── Section 7: Allocation Rate Over Time (bucketed) ───────────────────────────

echo "## Allocation Rate Over Time (10-second buckets)"
echo ""
printf "  %-14s %-14s %-14s %-10s\n" "Uptime (s)" "Rate (MB/s)" "GC Count" "Avg Pause"
echo "  $SEP2"

awk '
NR > 1 {
    dt = $1 - prev_t
    alloc = prev_before - prev_after
    rate = (dt > 0) ? alloc / dt : 0
    print prev_t, rate, $4, dt
}
{ prev_t = $1; prev_before = $2; prev_after = $3 }
' "$TMPDIR/young_gc.txt" | awk '
{
    bucket = int($1 / 10) * 10
    sum_rate[bucket] += $2
    count[bucket]++
    sum_pause[bucket] += $3
    if (!(bucket in first)) first[bucket] = 1
}
END {
    for (b in sum_rate) {
        avg_rate = sum_rate[b] / count[b]
        avg_pause = sum_pause[b] / count[b]
        printf "  %-14s %-14.0f %-14d %.2f ms\n", b"-"b+10, avg_rate, count[b], avg_pause
    }
}' | sort -t' ' -k1 -n

echo ""

# ─── Section 8: Concurrent Mark Cycles ─────────────────────────────────────────

conc_cycles=$(grep -c 'Concurrent Mark Cycle$' "$GC_LOG" 2>/dev/null || echo 0)
echo "## Concurrent Mark Cycles: $conc_cycles"
echo ""

if [[ "$conc_cycles" -gt 0 ]]; then
    grep 'Concurrent Mark Cycle' "$GC_LOG" | grep -v 'Concurrent Mark Cycle$' | \
        sed -n 's/.*\[\([0-9]*\.[0-9]*\)s\].*Concurrent Mark Cycle \(.*\)/  uptime=\1s  duration=\2/p' \
        || true
    echo ""
fi

# ─── Section 9: JFR Analysis ──────────────────────────────────────────────────

if [[ -n "$JFR_FILE" && -f "$JFR_FILE" ]]; then
    echo "$SEP"
    echo "  JFR Recording Analysis"
    echo "$SEP"
    echo ""

    # Summary
    echo "## Recording Summary"
    echo ""
    "$JFR_CMD" summary "$JFR_FILE" 2>&1 | grep -E '^\s*(Start|Duration|Chunks|Event Type|=)' | awk 'NR<=20'
    echo ""

    # Check for allocation events
    alloc_tlab=$("$JFR_CMD" summary "$JFR_FILE" 2>&1 | grep 'ObjectAllocationInNewTLAB' | awk '{print $2}')
    alloc_outside=$("$JFR_CMD" summary "$JFR_FILE" 2>&1 | grep 'ObjectAllocationOutsideTLAB' | awk '{print $2}')
    alloc_sample=$("$JFR_CMD" summary "$JFR_FILE" 2>&1 | grep 'ObjectAllocationSample' | awk '{print $2}')

    if [[ "${alloc_tlab:-0}" -gt 0 || "${alloc_outside:-0}" -gt 0 || "${alloc_sample:-0}" -gt 0 ]]; then
        echo "## Per-Type Allocation (JFR)"
        echo ""

        if [[ "${alloc_tlab:-0}" -gt 0 ]]; then
            echo "### TLAB Allocations (top 20 by count)"
            echo ""
            "$JFR_CMD" print --events jdk.ObjectAllocationInNewTLAB "$JFR_FILE" 2>&1 | \
                grep 'objectClass' | sed 's/.*objectClass = //;s/ (classLoader.*//' | sort | uniq -c | sort -rn | awk 'NR<=20 {printf "  %6d  %s\n", $1, $2}'
            echo ""

            echo "### TLAB Allocations (top 20 by total allocationSize)"
            echo ""
            "$JFR_CMD" print --events jdk.ObjectAllocationInNewTLAB --stack-depth 5 "$JFR_FILE" 2>&1 | \
                python3 -c "
import sys, collections, re

def parse_size(val):
    val = val.strip()
    m = re.match(r'([\d.]+)\s*(bytes|kB|MB|GB)', val)
    if not m:
        m2 = re.match(r'(\d+)', val)
        return int(m2.group(1)) if m2 else 0
    num = float(m.group(1))
    unit = m.group(2)
    if unit == 'kB': num *= 1024
    elif unit == 'MB': num *= 1024 * 1024
    elif unit == 'GB': num *= 1024 * 1024 * 1024
    return int(num)

VALUE_CLASSES = {
    'java.lang.Integer','java.lang.Long','java.lang.Float','java.lang.Double',
    'java.lang.Byte','java.lang.Short','java.lang.Character','java.lang.Boolean',
    'java.util.Optional','java.util.OptionalInt','java.util.OptionalLong','java.util.OptionalDouble',
    'java.time.LocalDate','java.time.LocalTime','java.time.LocalDateTime',
    'java.time.ZonedDateTime','java.time.Duration',
}

totals = collections.Counter()
counts = collections.Counter()
categories = collections.Counter()
cat_counts = collections.Counter()
sites = collections.Counter()
site_bytes = collections.Counter()

cur_cls = ''
cur_size = 0
cur_top_frame = ''
in_event = False
in_stack = False
frame_idx = 0

for line in sys.stdin:
    stripped = line.strip()

    if stripped.startswith('jdk.Object') and stripped.endswith('{'):
        if in_event and cur_cls:
            totals[cur_cls] += cur_size
            counts[cur_cls] += 1
            # categorize
            cls = cur_cls
            if cls.startswith('org.hibernate'): cat = 'Hibernate ORM'
            elif cls.startswith('org.acme'): cat = 'Application'
            elif cls in VALUE_CLASSES: cat = 'JDK Value Classes'
            elif 'HashMap' in cls: cat = 'HashMap'
            elif 'ConcurrentHashMap' in cls: cat = 'ConcurrentHashMap'
            elif cls.startswith('java.util.stream'): cat = 'Stream API'
            elif cls.startswith('java.math'): cat = 'BigInteger/BigDecimal'
            elif cls.startswith('org.postgresql'): cat = 'PostgreSQL JDBC'
            elif cls.startswith('io.netty') or cls.startswith('io.vertx'): cat = 'Netty/Vert.x'
            elif cls.startswith('com.fasterxml'): cat = 'Jackson'
            elif cls.startswith('io.quarkus') or cls.startswith('io.smallrye'): cat = 'Quarkus/SmallRye'
            elif cls.startswith('io.opentelemetry'): cat = 'OpenTelemetry'
            elif cls in ('byte[]','byte[][]','int[]','long[]','java.lang.String','java.lang.String[]'): cat = 'byte[]/String/prim'
            elif cls.endswith('[]'): cat = 'Object arrays'
            elif cls.startswith('java.'): cat = 'JDK other'
            else: cat = 'Other'
            categories[cat] += cur_size
            cat_counts[cat] += 1
            if cls in VALUE_CLASSES:
                short = cls.rsplit('.', 1)[-1]
                categories[f'  -> {short}'] += cur_size
                cat_counts[f'  -> {short}'] += 1
            # site
            key = f'{cur_cls} <- {cur_top_frame}' if cur_top_frame else f'{cur_cls} <- (no stack)'
            sites[key] += 1
            site_bytes[key] += cur_size
        in_event = True
        cur_cls = ''
        cur_size = 0
        cur_top_frame = ''
        in_stack = False
        frame_idx = 0
        continue

    if not in_event:
        continue

    if stripped == '}':
        if cur_cls:
            totals[cur_cls] += cur_size
            counts[cur_cls] += 1
            cls = cur_cls
            if cls.startswith('org.hibernate'): cat = 'Hibernate ORM'
            elif cls.startswith('org.acme'): cat = 'Application'
            elif cls in VALUE_CLASSES: cat = 'JDK Value Classes'
            elif 'HashMap' in cls: cat = 'HashMap'
            elif 'ConcurrentHashMap' in cls: cat = 'ConcurrentHashMap'
            elif cls.startswith('java.util.stream'): cat = 'Stream API'
            elif cls.startswith('java.math'): cat = 'BigInteger/BigDecimal'
            elif cls.startswith('org.postgresql'): cat = 'PostgreSQL JDBC'
            elif cls.startswith('io.netty') or cls.startswith('io.vertx'): cat = 'Netty/Vert.x'
            elif cls.startswith('com.fasterxml'): cat = 'Jackson'
            elif cls.startswith('io.quarkus') or cls.startswith('io.smallrye'): cat = 'Quarkus/SmallRye'
            elif cls.startswith('io.opentelemetry'): cat = 'OpenTelemetry'
            elif cls in ('byte[]','byte[][]','int[]','long[]','java.lang.String','java.lang.String[]'): cat = 'byte[]/String/prim'
            elif cls.endswith('[]'): cat = 'Object arrays'
            elif cls.startswith('java.'): cat = 'JDK other'
            else: cat = 'Other'
            categories[cat] += cur_size
            cat_counts[cat] += 1
            if cls in VALUE_CLASSES:
                short = cls.rsplit('.', 1)[-1]
                categories[f'  -> {short}'] += cur_size
                cat_counts[f'  -> {short}'] += 1
            key = f'{cur_cls} <- {cur_top_frame}' if cur_top_frame else f'{cur_cls} <- (no stack)'
            sites[key] += 1
            site_bytes[key] += cur_size
        in_event = False
        in_stack = False
        continue

    if in_stack:
        if stripped == ']':
            in_stack = False
        elif frame_idx == 0 and stripped != '...':
            cur_top_frame = stripped
            frame_idx += 1
        continue

    if stripped.startswith('objectClass = '):
        val = stripped[len('objectClass = '):]
        cur_cls = re.sub(r'\s*\(classLoader.*', '', val)
    elif stripped.startswith('allocationSize = ') or stripped.startswith('weight = '):
        eq = stripped.index('= ') + 2
        cur_size = parse_size(stripped[eq:])
    elif stripped.startswith('stackTrace = ['):
        in_stack = True

# --- Output ---
grand = sum(totals.values())
cumul = 0
print(f'  {\"Bytes\":>10}  {\"Obj sz\":>7}  {\"% tot\":>6}  {\"Cum%\":>5}  {\"Events\":>6}  Class')
print(f'  ' + '-'*80)
for cls, total in totals.most_common(20):
    avg = total // counts[cls]
    pct = total / grand * 100 if grand > 0 else 0
    cumul += pct
    print(f'  {total:10d}  {avg:7d}  {pct:5.1f}%  {cumul:4.1f}%  {counts[cls]:6d}  {cls}')
print()

print('### Allocation by Category')
print()
cat_grand = sum(c for k, c in categories.items() if not k.startswith('  -> '))
for cat, total in categories.most_common():
    kb = total / 1024
    pct = total / cat_grand * 100 if cat_grand > 0 else 0
    print(f'  {cat:<25} {kb:8.1f} KB  {pct:5.1f}%  ({cat_counts[cat]:5d} events)')
print()

print('### Top Allocation Sites (type <- method)')
print()
print(f'  {\"Events\":>6} {\"Bytes\":>9} {\"ObjSz\":>6}  Type <- Method')
print(f'  ' + '-'*90)
for key, count in sites.most_common(30):
    avg = site_bytes[key] // count
    print(f'  {count:6d} {site_bytes[key]:9d} {avg:6d}  {key}')
" 2>/dev/null || echo "  (python3 not available for TLAB analysis)"
            echo ""
        fi

        if [[ "${alloc_outside:-0}" -gt 0 ]]; then
            echo "### Outside-TLAB Allocations (top 20)"
            echo ""
            "$JFR_CMD" print --events jdk.ObjectAllocationOutsideTLAB "$JFR_FILE" 2>&1 | \
                grep 'objectClass' | sed 's/.*objectClass = //;s/ (classLoader.*//' | sort | uniq -c | sort -rn | awk 'NR<=20 {printf "  %6d  %s\n", $1, $2}'
            echo ""
        fi

        if [[ "${alloc_sample:-0}" -gt 0 ]]; then
            echo "### Sampled Allocations (top 20 by count) [jdk.ObjectAllocationSample]"
            echo ""
            "$JFR_CMD" print --events jdk.ObjectAllocationSample "$JFR_FILE" 2>&1 | \
                grep 'objectClass' | sed 's/.*objectClass = //;s/ (classLoader.*//' | sort | uniq -c | sort -rn | awk 'NR<=20 {printf "  %6d  %s\n", $1, $2}'
            echo ""

            echo "### Sampled Allocations (top 20 by total weight) [jdk.ObjectAllocationSample]"
            echo ""
            "$JFR_CMD" print --events jdk.ObjectAllocationSample --stack-depth 5 "$JFR_FILE" 2>&1 | \
                python3 -c "
import sys, collections, re

def parse_size(val):
    val = val.strip()
    m = re.match(r'([\d.]+)\s*(bytes|kB|MB|GB)', val)
    if not m:
        m2 = re.match(r'(\d+)', val)
        return int(m2.group(1)) if m2 else 0
    num = float(m.group(1))
    unit = m.group(2)
    if unit == 'kB': num *= 1024
    elif unit == 'MB': num *= 1024 * 1024
    elif unit == 'GB': num *= 1024 * 1024 * 1024
    return int(num)

VALUE_CLASSES = {
    'java.lang.Integer','java.lang.Long','java.lang.Float','java.lang.Double',
    'java.lang.Byte','java.lang.Short','java.lang.Character','java.lang.Boolean',
    'java.util.Optional','java.util.OptionalInt','java.util.OptionalLong','java.util.OptionalDouble',
    'java.time.LocalDate','java.time.LocalTime','java.time.LocalDateTime',
    'java.time.ZonedDateTime','java.time.Duration',
}

totals = collections.Counter()
counts = collections.Counter()
categories = collections.Counter()
cat_counts = collections.Counter()
sites = collections.Counter()
site_bytes = collections.Counter()

cur_cls = ''
cur_size = 0
cur_top_frame = ''
in_event = False
in_stack = False
frame_idx = 0

for line in sys.stdin:
    stripped = line.strip()

    if stripped.startswith('jdk.Object') and stripped.endswith('{'):
        if in_event and cur_cls:
            totals[cur_cls] += cur_size
            counts[cur_cls] += 1
            cls = cur_cls
            if cls.startswith('org.hibernate'): cat = 'Hibernate ORM'
            elif cls.startswith('org.acme'): cat = 'Application'
            elif cls in VALUE_CLASSES: cat = 'JDK Value Classes'
            elif 'HashMap' in cls: cat = 'HashMap'
            elif 'ConcurrentHashMap' in cls: cat = 'ConcurrentHashMap'
            elif cls.startswith('java.util.stream'): cat = 'Stream API'
            elif cls.startswith('java.math'): cat = 'BigInteger/BigDecimal'
            elif cls.startswith('org.postgresql'): cat = 'PostgreSQL JDBC'
            elif cls.startswith('io.netty') or cls.startswith('io.vertx'): cat = 'Netty/Vert.x'
            elif cls.startswith('com.fasterxml'): cat = 'Jackson'
            elif cls.startswith('io.quarkus') or cls.startswith('io.smallrye'): cat = 'Quarkus/SmallRye'
            elif cls.startswith('io.opentelemetry'): cat = 'OpenTelemetry'
            elif cls in ('byte[]','byte[][]','int[]','long[]','java.lang.String','java.lang.String[]'): cat = 'byte[]/String/prim'
            elif cls.endswith('[]'): cat = 'Object arrays'
            elif cls.startswith('java.'): cat = 'JDK other'
            else: cat = 'Other'
            categories[cat] += cur_size
            cat_counts[cat] += 1
            if cls in VALUE_CLASSES:
                short = cls.rsplit('.', 1)[-1]
                categories[f'  -> {short}'] += cur_size
                cat_counts[f'  -> {short}'] += 1
            key = f'{cur_cls} <- {cur_top_frame}' if cur_top_frame else f'{cur_cls} <- (no stack)'
            sites[key] += 1
            site_bytes[key] += cur_size
        in_event = True
        cur_cls = ''
        cur_size = 0
        cur_top_frame = ''
        in_stack = False
        frame_idx = 0
        continue

    if not in_event:
        continue

    if stripped == '}':
        if cur_cls:
            totals[cur_cls] += cur_size
            counts[cur_cls] += 1
            cls = cur_cls
            if cls.startswith('org.hibernate'): cat = 'Hibernate ORM'
            elif cls.startswith('org.acme'): cat = 'Application'
            elif cls in VALUE_CLASSES: cat = 'JDK Value Classes'
            elif 'HashMap' in cls: cat = 'HashMap'
            elif 'ConcurrentHashMap' in cls: cat = 'ConcurrentHashMap'
            elif cls.startswith('java.util.stream'): cat = 'Stream API'
            elif cls.startswith('java.math'): cat = 'BigInteger/BigDecimal'
            elif cls.startswith('org.postgresql'): cat = 'PostgreSQL JDBC'
            elif cls.startswith('io.netty') or cls.startswith('io.vertx'): cat = 'Netty/Vert.x'
            elif cls.startswith('com.fasterxml'): cat = 'Jackson'
            elif cls.startswith('io.quarkus') or cls.startswith('io.smallrye'): cat = 'Quarkus/SmallRye'
            elif cls.startswith('io.opentelemetry'): cat = 'OpenTelemetry'
            elif cls in ('byte[]','byte[][]','int[]','long[]','java.lang.String','java.lang.String[]'): cat = 'byte[]/String/prim'
            elif cls.endswith('[]'): cat = 'Object arrays'
            elif cls.startswith('java.'): cat = 'JDK other'
            else: cat = 'Other'
            categories[cat] += cur_size
            cat_counts[cat] += 1
            if cls in VALUE_CLASSES:
                short = cls.rsplit('.', 1)[-1]
                categories[f'  -> {short}'] += cur_size
                cat_counts[f'  -> {short}'] += 1
            key = f'{cur_cls} <- {cur_top_frame}' if cur_top_frame else f'{cur_cls} <- (no stack)'
            sites[key] += 1
            site_bytes[key] += cur_size
        in_event = False
        in_stack = False
        continue

    if in_stack:
        if stripped == ']':
            in_stack = False
        elif frame_idx == 0 and stripped != '...':
            cur_top_frame = stripped
            frame_idx += 1
        continue

    if stripped.startswith('objectClass = '):
        val = stripped[len('objectClass = '):]
        cur_cls = re.sub(r'\s*\(classLoader.*', '', val)
    elif stripped.startswith('allocationSize = ') or stripped.startswith('weight = '):
        eq = stripped.index('= ') + 2
        cur_size = parse_size(stripped[eq:])
    elif stripped.startswith('stackTrace = ['):
        in_stack = True

# --- Output ---
grand = sum(totals.values())
cumul = 0
print(f'  {\"Bytes\":>10}  {\"Obj sz\":>7}  {\"% tot\":>6}  {\"Cum%\":>5}  {\"Events\":>6}  Class')
print(f'  ' + '-'*80)
for cls, total in totals.most_common(20):
    avg = total // counts[cls]
    pct = total / grand * 100 if grand > 0 else 0
    cumul += pct
    print(f'  {total:10d}  {avg:7d}  {pct:5.1f}%  {cumul:4.1f}%  {counts[cls]:6d}  {cls}')
print()

print('### Allocation by Category [jdk.ObjectAllocationSample]')
print()
cat_grand = sum(c for k, c in categories.items() if not k.startswith('  -> '))
for cat, total in categories.most_common():
    kb = total / 1024
    pct = total / cat_grand * 100 if cat_grand > 0 else 0
    print(f'  {cat:<25} {kb:8.1f} KB  {pct:5.1f}%  ({cat_counts[cat]:5d} events)')
print()

print('### Top Allocation Sites (type <- method) [jdk.ObjectAllocationSample]')
print()
print(f'  {\"Events\":>6} {\"Bytes\":>9} {\"ObjSz\":>6}  Type <- Method')
print(f'  ' + '-'*90)
for key, count in sites.most_common(30):
    avg = site_bytes[key] // count
    print(f'  {count:6d} {site_bytes[key]:9d} {avg:6d}  {key}')
" 2>/dev/null || echo "  (python3 not available for sample analysis)"
            echo ""
        fi


    else
        echo "## Per-Type Allocation (JFR)"
        echo ""
        echo "  No allocation events recorded (ObjectAllocationInNewTLAB=0, ObjectAllocationOutsideTLAB=0, ObjectAllocationSample=0)."
        echo "  To capture per-type allocation data, record with allocation profiling enabled:"
        echo "    -XX:StartFlightRecording=settings=profile  (includes alloc events)"
        echo "  Or use async-profiler: asprof -e alloc -d 30 -f alloc.html <pid>"
        echo ""
    fi

    # GCHeapSummary from JFR
    gc_heap_count=$("$JFR_CMD" summary "$JFR_FILE" 2>&1 | grep 'GCHeapSummary' | awk '{print $2}')
    if [[ "${gc_heap_count:-0}" -gt 0 ]]; then
        echo "## GC Heap Summary (from JFR)"
        echo ""
        "$JFR_CMD" print --events jdk.GCHeapSummary "$JFR_FILE" 2>&1 | \
            grep -E 'startTime|heapUsed|committedSize' | \
            paste - - - | \
            sed 's/startTime = //' | sed 's/committedSize = /committed=/' | sed 's/heapUsed = /used=/' | \
            awk '{printf "  %s  %s  %s\n", $1, $3, $5}'
        echo ""
    fi

    # CPU hot methods from ExecutionSample
    exec_count=$("$JFR_CMD" summary "$JFR_FILE" 2>&1 | grep 'ExecutionSample' | awk '{print $2}')
    if [[ "${exec_count:-0}" -gt 0 ]]; then
        echo "## CPU Hot Methods (top 30, leaf frame)"
        echo ""
        "$JFR_CMD" print --events jdk.ExecutionSample --stack-depth 1 "$JFR_FILE" 2>&1 | \
            grep -E '^\s+\S+\.\S+\(' | sed 's/^\s*//' | \
            sort | uniq -c | sort -rn | awk -v total="$exec_count" 'NR<=30 {pct=$1/total*100; printf "  %5d (%5.1f%%)  %s\n", $1, pct, substr($0, index($0,$2))}'
        echo ""

        echo "## CPU Hot Methods (top 30, all frames)"
        echo ""
        "$JFR_CMD" print --events jdk.ExecutionSample --stack-depth 10 "$JFR_FILE" 2>&1 | \
            grep -oE '\S+\.\S+\(' | \
            sort | uniq -c | sort -rn | awk -v total="$exec_count" 'NR<=30 {pct=$1/total*100; printf "  %5d (%5.1f%%)  %s\n", $1, pct, substr($0, index($0,$2))}'
        echo ""
    fi

    # CPU load
    cpu_count=$("$JFR_CMD" summary "$JFR_FILE" 2>&1 | grep ' jdk\.CPULoad ' | awk '{print $2}')
    if [[ "${cpu_count:-0}" -gt 0 ]]; then
        echo "## CPU Load (from JFR)"
        echo ""
        "$JFR_CMD" print --events jdk.CPULoad "$JFR_FILE" 2>&1 | \
            grep -E 'jvmUser|jvmSystem|machineTotal' | \
            sed 's/.*= //' | \
            paste - - - | \
            awk '{printf "  jvmUser=%-10s jvmSystem=%-10s machineTotal=%s\n", $1, $2, $3}'
        echo ""
    fi
fi

# ─── Section 10: Focused Class Analysis ──────────────────────────────────────

if [[ -n "$FOCUS_CLASSES" && -n "$JFR_FILE" && -f "$JFR_FILE" ]]; then
    echo "$SEP"
    echo "  Focused Class Analysis"
    echo "$SEP"
    echo ""

    # Determine which allocation events are available
    ALLOC_EVENTS=""
    if [[ "${alloc_tlab:-0}" -gt 0 ]]; then
        ALLOC_EVENTS="jdk.ObjectAllocationInNewTLAB"
    fi
    if [[ "${alloc_outside:-0}" -gt 0 ]]; then
        ALLOC_EVENTS="${ALLOC_EVENTS:+$ALLOC_EVENTS,}jdk.ObjectAllocationOutsideTLAB"
    fi
    if [[ "${alloc_sample:-0}" -gt 0 ]]; then
        ALLOC_EVENTS="${ALLOC_EVENTS:+$ALLOC_EVENTS,}jdk.ObjectAllocationSample"
    fi

    if [[ -z "$ALLOC_EVENTS" ]]; then
        echo "  No allocation events available for focused analysis."
        echo ""
    else

    # Use subshell to isolate pipefail: jfr may OOM on very large recordings
    # with deep stacks but still produces usable partial output on stdout.
    ( set +o pipefail
    "$JFR_CMD" print --events "$ALLOC_EVENTS" --stack-depth 64 "$JFR_FILE" 2>/dev/null | \
        python3 -c "
import sys, collections, re

# -- Parse focus classes --
focus_input = '''${FOCUS_CLASSES}'''
focus_dots = [c.strip() for c in focus_input.split(',') if c.strip()]
# In text mode, objectClass uses dots (e.g. org.hibernate.engine.spi.EntityKey)
focus_set = set(focus_dots)

def parse_size(val):
    '''Parse a size string like 528.0 kB or 1024 bytes into integer bytes.'''
    val = val.strip()
    m = re.match(r'([\d.]+)\s*(bytes|kB|MB|GB)', val)
    if not m:
        m2 = re.match(r'(\d+)', val)
        return int(m2.group(1)) if m2 else 0
    num = float(m.group(1))
    unit = m.group(2)
    if unit == 'kB': num *= 1024
    elif unit == 'MB': num *= 1024 * 1024
    elif unit == 'GB': num *= 1024 * 1024 * 1024
    return int(num)

class Event:
    __slots__ = ('event_type', 'start_time', 'object_class', 'size', 'thread', 'frames')
    def __init__(self):
        self.event_type = ''
        self.start_time = ''
        self.object_class = ''
        self.size = 0
        self.thread = ''
        self.frames = []

# Totals across all events (for percentage calculations)
total_events = 0
total_bytes = 0
type_counts = collections.Counter()

class FocusData:
    def __init__(self):
        self.count = 0
        self.sizes = []
        self.threads = collections.Counter()
        self.timestamps = []
        self.sites = collections.OrderedDict()
        self.source_types = collections.Counter()

focus_data = {c: FocusData() for c in focus_dots}

current = None
in_stack = False
frames_buf = []

def finish_event(ev):
    global total_events, total_bytes
    total_events += 1
    total_bytes += ev.size
    type_counts[ev.event_type] += 1
    if ev.object_class in focus_data:
        fd = focus_data[ev.object_class]
        fd.count += 1
        fd.sizes.append(ev.size)
        fd.threads[ev.thread] += 1
        fd.timestamps.append(ev.start_time)
        fd.source_types[ev.event_type] += 1
        key = ' | '.join(ev.frames) if ev.frames else '(no stack)'
        if key not in fd.sites:
            fd.sites[key] = {'count': 0, 'bytes': 0, 'frames': list(ev.frames)}
        fd.sites[key]['count'] += 1
        fd.sites[key]['bytes'] += ev.size

for line in sys.stdin:
    line = line.rstrip('\n')
    stripped = line.strip()

    # Start of new event block
    if stripped.startswith('jdk.Object') and stripped.endswith('{'):
        if current is not None:
            current.frames = list(frames_buf)
            finish_event(current)
        current = Event()
        current.event_type = stripped.rstrip(' {')
        in_stack = False
        frames_buf = []
        continue

    if current is None:
        continue

    # End of event block
    if stripped == '}':
        current.frames = list(frames_buf)
        finish_event(current)
        current = None
        in_stack = False
        frames_buf = []
        continue

    if in_stack:
        if stripped == ']':
            in_stack = False
        elif stripped != '...':
            frames_buf.append(stripped)
        continue

    if stripped.startswith('startTime = '):
        current.start_time = stripped[len('startTime = '):]
    elif stripped.startswith('objectClass = '):
        val = stripped[len('objectClass = '):]
        val = re.sub(r'\s*\(classLoader.*', '', val)
        current.object_class = val
    elif stripped.startswith('weight = '):
        current.size = parse_size(stripped[len('weight = '):])
    elif stripped.startswith('allocationSize = '):
        current.size = parse_size(stripped[len('allocationSize = '):])
    elif stripped.startswith('eventThread = '):
        m = re.match(r'eventThread = \"(.+?)\"', stripped)
        current.thread = m.group(1) if m else '(unknown)'
    elif stripped.startswith('stackTrace = ['):
        in_stack = True

# Flush last event
if current is not None:
    current.frames = list(frames_buf)
    finish_event(current)

# -- Output results --
print(f'  Event sources: {dict(type_counts)}')
print()

for target in sorted(focus_data.keys()):
    fd = focus_data[target]
    print(f'## {target}')
    print()

    if fd.count == 0:
        print(f'  No allocation events found for this type.')
        print()
        continue

    for src, cnt in fd.source_types.most_common():
        print(f'  Source: {src} => {cnt} events')

    count = fd.count
    total_sz = sum(fd.sizes)
    min_sz = min(fd.sizes)
    max_sz = max(fd.sizes)
    avg_sz = total_sz // count
    pct_of_events = count / total_events * 100 if total_events > 0 else 0
    pct_of_bytes = total_sz / total_bytes * 100 if total_bytes > 0 else 0

    print(f'  Allocation events:        {count} ({pct_of_events:.1f}% of all {total_events} sampled events)')
    print(f'  Total weight/allocSize:   {total_sz:,} bytes ({pct_of_bytes:.1f}% of all sampled bytes)')
    print(f'  Object size:              {avg_sz} bytes (min={min_sz}, max={max_sz})')
    print()

    # Threads
    print(f'  Allocating threads:       {len(fd.threads)} distinct')
    for tname, tcount in fd.threads.most_common(10):
        pct = tcount / count * 100
        print(f'    {tcount:6d} ({pct:5.1f}%)  {tname}')
    if len(fd.threads) > 10:
        rest = sum(c for _, c in fd.threads.most_common()[10:])
        print(f'    {rest:6d}          ... and {len(fd.threads) - 10} more threads')
    print()

    # Temporal distribution
    timestamps = fd.timestamps
    if timestamps:
        print(f'  Time range:               {timestamps[0]} -> {timestamps[-1]}')
        second_buckets = collections.Counter()
        for ts in timestamps:
            m = re.search(r'(\d{2}:\d{2}:\d{2})', ts)
            if m:
                second_buckets[m.group(1)] += 1
        if second_buckets:
            sorted_secs = sorted(second_buckets.keys())
            counts_per_sec = [second_buckets[s] for s in sorted_secs]
            avg_per_sec = sum(counts_per_sec) / len(counts_per_sec) if counts_per_sec else 0
            max_per_sec = max(counts_per_sec) if counts_per_sec else 0
            min_per_sec = min(counts_per_sec) if counts_per_sec else 0
            print(f'  Alloc rate (per second):   avg={avg_per_sec:.1f}, min={min_per_sec}, max={max_per_sec}')
            print(f'  Per-second distribution:')
            for s in sorted_secs:
                bar = '#' * min(second_buckets[s], 200)
                print(f'    {s}  {second_buckets[s]:4d}  {bar}')
        print()

    # Allocation sites
    sorted_sites = sorted(fd.sites.values(), key=lambda s: s['count'], reverse=True)
    print(f'  Allocation sites:         {len(sorted_sites)} distinct call paths')
    print()

    for i, site in enumerate(sorted_sites[:10]):
        site_pct = site['count'] / count * 100
        print(f'  Site #{i+1}: {site[\"count\"]} events ({site_pct:.1f}%), {site[\"bytes\"]:,} bytes')
        for j, frame in enumerate(site['frames']):
            indent = '    -> ' if j == 0 else '       '
            print(f'{indent}{frame}')
        print()
    if len(sorted_sites) > 10:
        print(f'  ... and {len(sorted_sites) - 10} more sites')
        print()

    print()
"
    ) || echo "  (python3 required for focused class analysis)"

    fi  # end ALLOC_EVENTS non-empty check
fi

echo "$SEP"
echo "  Analysis complete."
echo "$SEP"
