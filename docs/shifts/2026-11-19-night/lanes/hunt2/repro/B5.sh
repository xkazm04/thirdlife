# bash docs/shifts/2026-11-19-night/lanes/hunt2/repro/B5.sh
set -eu
here=$(cd "$(dirname "$0")" && pwd)
tmp=$(mktemp -d "$here/B5.XXXXXX")
trap 'rmdir "$tmp"' EXIT
rc=0
out=$(TL_SELFTEST_DIR="$tmp" timeout 180 bash engine/tools/tl.sh seeds hunt2_nonexistent_case) || rc=$?
[[ "$out" == *"seeds: 0 passed, 0 failed"* ]] || { echo "$out" >&2; exit 2; }
if ((rc == 0)); then
  echo "REPRO B5: FAIL 0 cases selected, 0 completed, tl.sh seeds exited 0"
  exit 1
fi
if ((rc != 2)); then
  echo "REPRO B5: FAIL expected exit 2, got $rc"
  exit 1
fi
echo "REPRO B5: PASS"
