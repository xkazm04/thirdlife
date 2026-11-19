# bash docs/shifts/2026-11-19-night/lanes/hunt2/repro/A1.sh
# A child supplies one case row, then terminates itself before the suite trailer.
set -eu
lane=$(cd "$(dirname "$0")" && pwd)
tmp=$(mktemp -d "$lane/A1.XXXXXX")
trap 'rm -f "$tmp/child" "$tmp/status"; rmdir "$tmp/out" "$tmp"' EXIT
cat > "$tmp/child" <<'CHILD'
#!/usr/bin/env bash
echo 'CAMCASE cam.wall_start ok fixture'
echo "$BASHPID" > "$A1_MARK"
kill -TERM "$BASHPID"
CHILD
chmod +x "$tmp/child"
rc=0
out=$(A1_MARK="$tmp/status" TL_GODOT="$tmp/child" TL_SELFTEST_DIR="$tmp/out" bash engine/tools/selftest.sh cam.wall_start 2>&1) || rc=$?
test -s "$tmp/status"
if [[ $rc == 0 && $out == *"PASS cam.wall_start"* ]]; then
  echo 'REPRO A1: FAIL child terminated by signal 15 after 1 case and 0 trailers; selftest exited 0'
  exit 1
fi
if [[ $rc == 0 || $out != *"FAIL cam.wall_start"* ]]; then echo "$out" >&2; exit 2; fi
echo 'REPRO A1: PASS'
