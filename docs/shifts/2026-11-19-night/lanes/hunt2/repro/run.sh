# bash docs/shifts/2026-11-19-night/lanes/hunt2/repro/run.sh A3
# Run one GDScript case in an isolated directory.
set -eu
dir=$(cd "$(dirname "$0")" && pwd)
id=${1:?supply the repro ID}
tmp=$(mktemp -d "$dir/$id.XXXXXX")
trap 'rm -f "$tmp/case.gd" "$tmp/godot.log" "$tmp/output" "$tmp/pack.json"; rmdir "$tmp"' EXIT
cp "$dir/$id.gd.txt" "$tmp/case.gd"
G=${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}
rc=0
MSYS_NO_PATHCONV=1 timeout 180 "$G" --headless --fixed-fps 60 --path "$(cygpath -am engine)" --log-file "$(cygpath -am "$tmp/godot.log")" --script "$(cygpath -am "$tmp/case.gd")" >"$tmp/output" 2>&1 || rc=$?
tr -d '\r' <"$tmp/output"
line=$(tr -d '\r' <"$tmp/output" | tail -1)
if grep -aEq '^(SCRIPT ERROR|ERROR):' "$tmp/output"; then exit 2; fi
if [[ $rc == 0 && "$line" == "REPRO $id: PASS" ]]; then exit 0; fi
if [[ $rc == 1 && "$line" == "REPRO $id: FAIL "* ]]; then exit 1; fi
echo "Incomplete $id run (Godot exit $rc, missing or inconsistent final verdict)" >&2
exit 2
