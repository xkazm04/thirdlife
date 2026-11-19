# bash docs/shifts/2026-11-19-night/lanes/hunt2/repro/B6.sh
set -eu
# Give the real tl.sh import branch an isolated, nonexistent executable.
here=$(cd "$(dirname "$0")" && pwd)
rc=0
out=$(TL_GODOT="$here/B6-no-such-godot.exe" timeout 180 bash engine/tools/tl.sh import 2>&1) || rc=$?
if ((rc == 0)); then
  echo "REPRO B6: FAIL 0 Godot processes started, import exited 0"
  exit 1
fi
if ((rc != 2)); then
  echo "REPRO B6: FAIL expected exit 2, got $rc"
  exit 1
fi
echo "REPRO B6: PASS"
