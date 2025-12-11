#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./collect-failed-jtrs.sh [SRC_ROOT] [OUT_DIR]
#
# Defaults:
#   SRC_ROOT = build/fast-linux-x86_64/test-support
#   OUT_DIR  = failed-jtrs-<timestamp>

SRC_ROOT=${1}
OUT_DIR=${2:-"failed-jtrs-$(date +%Y%m%d-%H%M%S)"}

if [[ ! -d "$SRC_ROOT" ]]; then
  echo "Source root '$SRC_ROOT' does not exist" >&2
  exit 1
fi

mkdir -p "$OUT_DIR"

echo "Scanning for failed/error .jtr files under: $SRC_ROOT"

# Walk all .jtr files, check for result: Failed/Error, copy into OUT_DIR
# while preserving relative path structure.
while IFS= read -r -d '' jtr; do
  if grep -qE '^result: (Failed|Error)' "$jtr"; then
    # Compute path relative to SRC_ROOT
    rel=${jtr#"$SRC_ROOT"/}
    dest="$OUT_DIR/$rel"

    mkdir -p "$(dirname "$dest")"
    cp "$jtr" "$dest"
  fi
done < <(find "$SRC_ROOT" -name '*.jtr' -print0)

echo "Copied failing/error .jtr files into '$OUT_DIR'"

# Zip them up
ZIP_NAME="$OUT_DIR.zip"
zip -r "$ZIP_NAME" "$OUT_DIR" >/dev/null
echo "Created zip: $ZIP_NAME"
