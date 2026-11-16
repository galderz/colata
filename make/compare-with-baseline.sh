#!/usr/bin/env bash
# compare-with-baseline.sh
#
# Extracts failed/errored tests from a hotspot_compiler test run on the
# patched branch, re-runs them against the merge-base commit (baseline),
# and reports tests that fail or error only on the patch.
#
# Usage:
#   ./compare-with-baseline.sh [OPTIONS]
#
# Options:
#   --repo-dir DIR       JDK source tree (default: $JDK_HOME, then $HOME/src/jdk)
#   --conf CONF          Build configuration name (default: fast-linux-x86_64)
#   --test-suite SUITE   jtreg test suite label used in build dirs
#                        (default: jtreg_test_hotspot_jtreg_hotspot_compiler)
#   --jobs N             Parallel jobs for make (default: nproc)
#   --keep-worktree      Do not delete the baseline worktree on exit
#
# The script can be run from any working directory. The JDK repo is located via
# --repo-dir, the JDK_HOME env var (same convention as colata Makefiles), or
# the default fallback $HOME/src/jdk.

set -euo pipefail

# ── defaults ──────────────────────────────────────────────────────────────────
# JDK_HOME follows the same convention as colata's OpenJDK.gmk; fall back to
# the conventional clone location used in this environment.
REPO_DIR="${JDK_HOME:-$HOME/src/jdk}"
CONF="${CONF:-fast-linux-x86_64}"
SUITE_LABEL="jtreg_test_hotspot_jtreg_hotspot_compiler"
JOBS="${JOBS:-$(nproc)}"
KEEP_WORKTREE=0

# ── argument parsing ──────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case $1 in
    --repo-dir)    REPO_DIR="$2";       shift 2 ;;
    --conf)        CONF="$2";           shift 2 ;;
    --test-suite)  SUITE_LABEL="$2";    shift 2 ;;
    --jobs)        JOBS="$2";           shift 2 ;;
    --keep-worktree) KEEP_WORKTREE=1;   shift   ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

# Resolve to an absolute path. Tilde-expand first (cd suppresses ~ inside
# double quotes, e.g. when JDK_HOME is stored as ~/src/jdk in the environment).
REPO_DIR="${REPO_DIR/#\~/$HOME}"
REPO_DIR="$(cd "$REPO_DIR" && pwd)"
BUILD_DIR="$REPO_DIR/build/$CONF"
SUMMARY_FILE="$BUILD_DIR/test-results/$SUITE_LABEL/text/summary.txt"
JTREG_JAR="$(grep 'JT_HOME' "$BUILD_DIR/spec.gmk" | head -1 | sed 's/.*:= //')/lib/jtreg.jar"
BOOT_JDK="$(grep 'JTREG_JDK' "$BUILD_DIR/spec.gmk" | head -1 | sed 's/.*:= //')"
BASELINE_CONF="baseline-linux-x86_64"
WORKTREE_DIR="$(mktemp -d -t jdk-baseline-XXXX)"
BASELINE_BUILD="$WORKTREE_DIR/build/$BASELINE_CONF"
BASELINE_RESULTS="$WORKTREE_DIR/build/$BASELINE_CONF/test-results/$SUITE_LABEL"
BASELINE_SUPPORT="$WORKTREE_DIR/build/$BASELINE_CONF/test-support/$SUITE_LABEL"

# ── colours ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'; BOLD='\033[1m'; NC='\033[0m'

# ── cleanup trap ──────────────────────────────────────────────────────────────
cleanup() {
  if [[ $KEEP_WORKTREE -eq 0 ]]; then
    echo -e "\n${BOLD}Cleaning up baseline worktree …${NC}"
    git -C "$REPO_DIR" worktree remove --force "$WORKTREE_DIR" 2>/dev/null || true
    rm -rf "$WORKTREE_DIR"
  else
    echo -e "\n${BOLD}Baseline worktree kept at: $WORKTREE_DIR${NC}"
  fi
}
trap cleanup EXIT

# ── step 1: extract failing/erroring tests from the patched run ───────────────
echo -e "${BOLD}=== Step 1: Extracting failures and errors from patched run ===${NC}"

if [[ ! -f "$SUMMARY_FILE" ]]; then
  echo -e "${RED}ERROR: summary file not found: $SUMMARY_FILE${NC}" >&2
  echo "Run the tests first with: CONF=$CONF TEST=\"$SUITE_LABEL\" make test" >&2
  exit 1
fi

# Lines look like:
#   compiler/foo/Bar.java#id0   Failed. ...
#   compiler/foo/Bar.java       Error. ...
mapfile -t PATCH_BAD < <(
  grep -E '\s+(Failed|Error)\.' "$SUMMARY_FILE" \
    | awk '{print $1}' \
    | sort -u
)

if [[ ${#PATCH_BAD[@]} -eq 0 ]]; then
  echo -e "${GREEN}No failures or errors found in the patched run. Nothing to do.${NC}"
  exit 0
fi

echo "Found ${#PATCH_BAD[@]} failing/erroring test(s) in the patched run:"
for t in "${PATCH_BAD[@]}"; do
  echo "  $t"
done

# ── step 2: find the merge base ───────────────────────────────────────────────
echo -e "\n${BOLD}=== Step 2: Finding merge base with master ===${NC}"
MERGE_BASE=$(git -C "$REPO_DIR" merge-base HEAD master)
PATCH_SHA=$(git -C "$REPO_DIR" rev-parse --short HEAD)
BASE_SHA=$(git -C "$REPO_DIR" rev-parse --short "$MERGE_BASE")
echo "Patched HEAD : $PATCH_SHA"
echo "Merge base   : $BASE_SHA  ($MERGE_BASE)"

# ── step 3: create a worktree at the merge base ───────────────────────────────
echo -e "\n${BOLD}=== Step 3: Creating baseline worktree at $WORKTREE_DIR ===${NC}"
git -C "$REPO_DIR" worktree add --detach "$WORKTREE_DIR" "$MERGE_BASE"

# ── step 4: configure baseline build ─────────────────────────────────────────
echo -e "\n${BOLD}=== Step 4: Configuring baseline build ===${NC}"

# Replay the same configure flags, only override --with-conf-name.
# Any --with-X=value where the value contains '/' but is not absolute is a
# relative path recorded when configure was run from $REPO_DIR; convert those
# to absolute paths so they resolve correctly inside the worktree.
ORIG_CONF_FLAGS=$(
  grep '^CONFIGURE_COMMAND_LINE' "$BUILD_DIR/spec.gmk" \
    | sed 's/CONFIGURE_COMMAND_LINE := //'
)
BASELINE_CONF_FLAGS=$(
  echo "$ORIG_CONF_FLAGS" \
    | sed "s/--with-conf-name=[^ ]*/--with-conf-name=$BASELINE_CONF/" \
    | sed -E "s|(--[a-zA-Z-]+=)([^/ ][^ ]*/[^ ]*)|\1$REPO_DIR/\2|g" 
)

(cd "$WORKTREE_DIR" && bash configure $BASELINE_CONF_FLAGS)

# ── step 5: build the baseline JDK images ─────────────────────────────────────
echo -e "\n${BOLD}=== Step 5: Building baseline JDK images (make JOBS=$JOBS images) ===${NC}"
make -C "$WORKTREE_DIR" CONF="$BASELINE_CONF" JOBS="$JOBS" images

# Also build native test libraries needed by hotspot_compiler tests
echo -e "\n${BOLD}=== Step 5b: Building baseline test image (make JOBS=$JOBS test-image) ===${NC}"
make -C "$WORKTREE_DIR" CONF="$BASELINE_CONF" JOBS="$JOBS" test-image

# ── step 6: run failing tests against baseline ────────────────────────────────
echo -e "\n${BOLD}=== Step 6: Running ${#PATCH_BAD[@]} test(s) against baseline ===${NC}"
mkdir -p "$BASELINE_RESULTS/text" "$BASELINE_SUPPORT"

# Build the list of test paths: prefix each with the jtreg test dir
TEST_ARGS=()
for t in "${PATCH_BAD[@]}"; do
  TEST_ARGS+=("test/hotspot/jtreg/$t")
done

JAVATMP="$BASELINE_BUILD/support/javatmp"
mkdir -p "$JAVATMP"

set +e   # jtreg exits non-zero when tests fail; we handle that ourselves
"$BOOT_JDK/bin/java" \
  -Xms64M -Xmx2048M \
  -Duser.language=en -Duser.country=US \
  -Xlog:all=off:stdout -Xlog:all=warning:stderr \
  -Djava.io.tmpdir="$JAVATMP" \
  -Dprogram=jtreg \
  -jar "$JTREG_JAR" \
  -agentvm \
  -verbose:fail,error,summary \
  -retain:fail,error \
  -concurrency:"$JOBS" \
  -vmoption:-XX:MaxRAMPercentage=1.5625 \
  -vmoption:-Dtest.boot.jdk="$BOOT_JDK" \
  -vmoption:-Djava.io.tmpdir="$BASELINE_SUPPORT/tmp" \
  -ignore:quiet \
  -automatic \
  -nativepath:"$BASELINE_BUILD/images/test/hotspot/jtreg/native" \
  -exclude:"$WORKTREE_DIR/test/hotspot/jtreg/ProblemList.txt" \
  -timeoutFactor:4 \
  -testjdk:"$BASELINE_BUILD/images/jdk" \
  -dir:"$WORKTREE_DIR" \
  -reportDir:"$BASELINE_RESULTS" \
  -workDir:"$BASELINE_SUPPORT" \
  -report:files \
  "${TEST_ARGS[@]}"
JTREG_EXIT=$?
set -e

echo "jtreg exited with code $JTREG_EXIT"

# ── step 7: parse baseline results ───────────────────────────────────────────
echo -e "\n${BOLD}=== Step 7: Comparing results ===${NC}"

BASELINE_SUMMARY="$BASELINE_RESULTS/text/summary.txt"
if [[ ! -f "$BASELINE_SUMMARY" ]]; then
  echo -e "${RED}ERROR: baseline summary not found at $BASELINE_SUMMARY${NC}" >&2
  exit 1
fi

mapfile -t BASE_BAD < <(
  grep -E '\s+(Failed|Error)\.' "$BASELINE_SUMMARY" \
    | awk '{print $1}' \
    | sort -u
)

# Tests that are bad in both runs
mapfile -t BOTH_BAD < <(
  comm -12 \
    <(printf '%s\n' "${PATCH_BAD[@]}" | sort) \
    <(printf '%s\n' "${BASE_BAD[@]}"  | sort)
)

# Tests that are bad only in the patched run → regression candidates
mapfile -t PATCH_ONLY < <(
  comm -23 \
    <(printf '%s\n' "${PATCH_BAD[@]}" | sort) \
    <(printf '%s\n' "${BASE_BAD[@]}"  | sort)
)

# ── report ────────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║                     COMPARISON REPORT                       ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "Patched HEAD : ${BOLD}$PATCH_SHA${NC}"
echo -e "Merge base   : ${BOLD}$BASE_SHA${NC}"
echo ""

if [[ ${#PATCH_ONLY[@]} -gt 0 ]]; then
  echo -e "${RED}${BOLD}⚠  REGRESSIONS — fail/error only on the patched branch (${#PATCH_ONLY[@]}):${NC}"
  for t in "${PATCH_ONLY[@]}"; do
    # Print the original failure line from patch summary for context
    detail=$(grep -E "^$t\s" "$SUMMARY_FILE" | sed 's/^[^ ]*[[:space:]]*/  /' || true)
    echo -e "  ${RED}✗ $t${NC}"
    [[ -n "$detail" ]] && echo -e "    ${detail# }"
  done
  echo ""
else
  echo -e "${GREEN}${BOLD}✓  No regressions: every failure also occurs at the merge base.${NC}"
  echo ""
fi

if [[ ${#BOTH_BAD[@]} -gt 0 ]]; then
  echo -e "${YELLOW}${BOLD}↔  Fail/error in BOTH patch and baseline (pre-existing, ${#BOTH_BAD[@]}):${NC}"
  for t in "${BOTH_BAD[@]}"; do
    echo "  $t"
  done
  echo ""
fi

# Tests that passed in patch but were checked (shouldn't happen but be safe)
mapfile -t BASE_ONLY < <(
  comm -13 \
    <(printf '%s\n' "${PATCH_BAD[@]}" | sort) \
    <(printf '%s\n' "${BASE_BAD[@]}"  | sort)
)
if [[ ${#BASE_ONLY[@]} -gt 0 ]]; then
  echo -e "${GREEN}${BOLD}✓  Fail/error only at baseline, now fixed in patch (${#BASE_ONLY[@]}):${NC}"
  for t in "${BASE_ONLY[@]}"; do
    echo "  $t"
  done
  echo ""
fi

# Summary line
echo -e "${BOLD}Summary: ${#PATCH_BAD[@]} tested | ${RED}${#PATCH_ONLY[@]} regressions${NC}${BOLD} | ${YELLOW}${#BOTH_BAD[@]} pre-existing${NC}${BOLD} | ${GREEN}${#BASE_ONLY[@]} fixed${NC}"
echo ""

# Exit with non-zero if regressions found
[[ ${#PATCH_ONLY[@]} -eq 0 ]]
