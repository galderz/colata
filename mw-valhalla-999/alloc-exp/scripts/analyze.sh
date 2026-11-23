#!/usr/bin/env bash
# Analyze a JFR recording (JDK JFR or async-profiler) with tools/AllocAnalyzer.java.
# Usage: analyze.sh <recording.jfr> [AllocAnalyzer options...]
#   - adds --cp build/classes so application bytecodes can be decoded
#   - adds --preview / --no-preview from the file name (*-preview.jfr / *-identity.jfr) unless given
#   - for *-preview.jfr, adds --baseline <same dir>/<scenario>-identity.jfr when it exists
# Example: analyze.sh target/ap/cached-call-preview.jfr --top 3
set -euo pipefail
source "$(dirname "$0")/env.sh"
REC="$1"; shift
ARGS=(--cp "$CLASSES")
if [[ " $* " != *" --preview "* && " $* " != *" --no-preview "* ]]; then
  case "$REC" in
    *-preview.jfr)  ARGS+=(--preview) ;;
    *-identity.jfr) ARGS+=(--no-preview) ;;
  esac
fi
if [[ "$REC" == *-preview.jfr && " $* " != *" --baseline "* ]]; then
  BASE="${REC%-preview.jfr}-identity.jfr"
  [[ -f "$BASE" ]] && ARGS+=(--baseline "$BASE")
fi
exec "$JAVA" "$EXP_DIR/tools/AllocAnalyzer.java" "${ARGS[@]}" "$@" "$REC"
