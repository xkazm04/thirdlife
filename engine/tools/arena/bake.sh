#!/bin/bash
# The arena's bake, end to end (lane K6). Step 1 needs Unreal 5.9 with a GPU and a copy of the thirdjam project whose
# .uproject enables PythonScriptPlugin, EditorScriptingUtilities and GLTFExporter and whose Content/Python/init_unreal.py
# runs $TL_REF_SCRIPT (see export_arena.py); steps 2 and 3 need Python 3 with numpy and Godot.
#   bake.sh <thirdjam copy>/Game/ThirdJam.uproject <work folder> [shots.json]      all three steps
#   bake.sh - <work folder>                                                        steps 2 and 3 on an export already made
# Writes engine/cores/rink/arena/arena.scn and arena.json. One Unreal process, closed when its list is done.
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"; E="$(cd "$HERE/../.." && pwd)"
command -v cygpath >/dev/null 2>&1 && { HERE="$(cygpath -m "$HERE")"; E="$(cygpath -m "$E")"; }
G="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
UE="${TL_UNREAL:-C:/Program Files/Epic Games/UE_5.9/Engine/Binaries/Win64/UnrealEditor.exe}"
PROJECT="$1"; WORK="$2"; SHOTS="$3"
[ -n "$WORK" ] || { echo "usage: bake.sh <uproject | -> <work folder> [shots.json]"; exit 2; }
mkdir -p "$WORK"
if [ "$PROJECT" != "-" ]; then
  export TL_REF_SCRIPT="$HERE/export_arena.py" TL_ARENA_OUT="$WORK"
  [ -n "$SHOTS" ] && export TL_ARENA_SHOTS="$SHOTS"
  MSYS_NO_PATHCONV=1 timeout 1200 "$UE" "$PROJECT" /Game/Maps/Rink -unattended -nosplash -nosound -Multiprocess -cut=hockey.regular "-abslog=$WORK/editor.log" > /dev/null 2>&1 || true
  grep -q "TLARENA_END actors=[1-9]" "$WORK/export.log" || { echo "FAIL the export did not end (see $WORK/export.log, $WORK/editor.log)"; exit 1; }
fi
python "$HERE/arena_prep.py" "$WORK" "$WORK/arena_src.json" | head -1
MSYS_NO_PATHCONV=1 timeout 300 "$G" --headless --path "$E" -s res://tools/arena/build_arena.gd -- "--src=$WORK/arena_src.json" 2>&1 | grep "tl.arena.build/1"
