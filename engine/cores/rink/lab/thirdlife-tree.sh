#!/usr/bin/env bash
# Third Life rink core, LAB (lane K8 "balance"): the thirdlife source tree.
# Copies native/thirdjam (thirdjam's files, byte for byte, never edited) to .tl/rink-thirdlife/src/thirdjam and applies every
# native/patches-thirdlife/*.patch in name order. A patch that does not apply cleanly is a FAIL (exit 1): nothing is built from a half-patched tree.
# The copy is remade only when thirdjam's files or the patches changed (a stamp of their hashes), so SCons rebuilds what a patch touched.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
NATIVE="$ROOT/engine/cores/rink/native"
OUT="$ROOT/.tl/rink-thirdlife"
PATCHES="$NATIVE/patches-thirdlife"
ls "$PATCHES"/*.patch >/dev/null 2>&1 || { echo "NOT RUN  thirdlife tree: no patches in $PATCHES"; exit 2; }
stamp="$( { find "$NATIVE/thirdjam" -type f | sort | xargs sha1sum; sha1sum "$PATCHES"/*.patch; } | sha1sum | cut -d' ' -f1)"
if [ -f "$OUT/stamp" ] && [ "$(cat "$OUT/stamp")" = "$stamp" ] && [ -d "$OUT/src/thirdjam" ]; then
  echo "PASS  thirdlife tree: up to date ($(ls "$PATCHES"/*.patch | wc -l) patches)"; exit 0
fi
rm -rf "$OUT/src" && mkdir -p "$OUT/src"
cp -r "$NATIVE/thirdjam" "$OUT/src/thirdjam"
n=0
for p in "$PATCHES"/*.patch; do
  if ! patch -p1 -s --no-backup-if-mismatch -d "$OUT/src" < "$p" > "$OUT/patch.log" 2>&1; then
    echo "FAIL  thirdlife tree: $(basename "$p") does not apply: $(head -3 "$OUT/patch.log" | tr '\n' ' ')"; rm -f "$OUT/stamp"; exit 1
  fi
  n=$((n + 1))
done
echo "$stamp" > "$OUT/stamp"
echo "PASS  thirdlife tree: $n patches applied to a copy of native/thirdjam ($(diff -rq "$NATIVE/thirdjam" "$OUT/src/thirdjam" | wc -l) files differ)"
