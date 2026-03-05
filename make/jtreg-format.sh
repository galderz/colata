#!/usr/bin/env bash
set -euo pipefail

# ---- 1) Download google-java-format jar once (cache in TMPDIR) ----
GJF_VERSION="1.32.0"
GJF_JAR="google-java-format-${GJF_VERSION}-all-deps.jar"
GJF_URL="https://github.com/google/google-java-format/releases/download/v${GJF_VERSION}/${GJF_JAR}"

TMPROOT="${TMPDIR:-/tmp}"
CACHE_DIR="${TMPROOT%/}/google-java-format-cache"
mkdir -p "$CACHE_DIR"

JAR_PATH="${CACHE_DIR%/}/${GJF_JAR}"

if [[ ! -f "$JAR_PATH" ]]; then
  echo "Downloading ${GJF_URL} -> ${JAR_PATH}" >&2
  # Try curl, fall back to wget
  if command -v curl >/dev/null 2>&1; then
    curl -fL --retry 5 --retry-delay 1 -o "$JAR_PATH" "$GJF_URL"
  elif command -v wget >/dev/null 2>&1; then
    wget -O "$JAR_PATH" "$GJF_URL"
  else
    echo "Error: need curl or wget to download ${GJF_URL}" >&2
    exit 1
  fi
else
  echo "Using cached jar: ${JAR_PATH}" >&2
fi

# ---- 2) Locate compile-framework-sources-* folder and format *.java recursively ----

ROOT="$1"
JAVA="$2"
if [[ ! -d "$ROOT" ]]; then
  echo "Error: not a directory: $ROOT" >&2
  exit 2
fi

# Find the first directory under ROOT whose basename starts with compile-framework-sources-
# (If you want "all matches", change -print -quit handling.)
TARGET_DIR="$(
  find "$ROOT" -type d -name 'compile-framework-sources-*' -print -quit 2>/dev/null || true
)"

if [[ -z "$TARGET_DIR" ]]; then
  echo "No directory matching compile-framework-sources-* found under: $ROOT" >&2
  exit 0
fi

echo "Found target directory: $TARGET_DIR" >&2

# Format files in-place with google-java-format.
# Use -print0 to safely handle spaces/newlines in file names.
found_any=0
while IFS= read -r -d '' java_file; do
  found_any=1
  $JAVA -jar "$JAR_PATH" -r "$java_file"
done < <(find "$TARGET_DIR" -type f -name '*.java' -print0)

if [[ "$found_any" -eq 0 ]]; then
  echo "No .java files found under: $TARGET_DIR" >&2
  exit 0
fi

# Finally print contents of each java file (after formatting).
while IFS= read -r -d '' java_file; do
  echo "===== FILE: $java_file ====="
  cat "$java_file"
  echo
done < <(find "$TARGET_DIR" -type f -name '*.java' -print0)
