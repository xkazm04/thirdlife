#!/bin/bash
# Lane walker (bugfix-37 D14): runs hop_probe.gd.txt (hopping into a steep bank; a steep V channel).
#   bash docs/reports/bugfix-37/walker/hop_probe.sh        the code in the tree
#   bash docs/reports/bugfix-37/walker/hop_probe.sh old    the HEAD copy of the body (old/*.gd.txt, the unfixed code)
# The scripts are kept as .gd.txt (report convention); they are copied to a temp dir as .gd and run from there.
G="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
HERE="$(cd "$(dirname "$0")" && pwd)"
W="$(cd "$HERE/../../../.." && pwd)"
T="$(mktemp -d)"
mkdir -p "$T/old"
cp "$HERE/hop_probe.gd.txt" "$T/hop_probe.gd"
cp "$HERE/old/world_body.gd.txt" "$T/old/world_body.gd"
cp "$HERE/old/world_space.gd.txt" "$T/old/world_space.gd"
command -v cygpath >/dev/null 2>&1 && { W="$(cygpath -m "$W")"; T="$(cygpath -m "$T")"; }
HOP_OLD="$([ "$1" = "old" ] && echo 1 || echo 0)" MSYS_NO_PATHCONV=1 timeout 200 "$G" --headless --path "$W/engine" --script "$T/hop_probe.gd" 2>&1 | tr -d '\015' | grep -E "^HOP|ERROR"
rm -rf "$T"
