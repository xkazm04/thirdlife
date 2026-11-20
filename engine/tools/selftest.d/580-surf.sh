# Diorama night (20 Nov 2026), surfaces (engine/kernel/world/draw/surf_case.gd, headless). A missing SURF line is a FAIL.
#   surf.classic_source  toon.gdshader without its TL_DIORAMA branches is byte for byte the shader of diorama-base
#   surf.model           TL_STYLE unset names the diorama model and resin water; TL_STYLE=classic names neither
#   surf.edges           a TLMesh box writes the place on each face into UV2, a cylinder side its round normal; content_hash as without UV2
#   surf.keys            gloss, fuzz, chip, clay and felt are accepted; an unknown material key or class is still an error
# The two constants were taken on diorama-base (781d32b): sha256 of engine/style/shaders/toon.gdshader, and
# TLMesh.content_hash of the three solids surf_case.gd builds. A change to the classic branches of the shader moves
# the first on purpose: take the new value from the FAIL line, and say in the report why classic moved.
surf_names="surf.classic_source surf.model surf.model_classic surf.edges surf.keys"
surf_wanted=0
for surf_n in $surf_names; do if [ -z "$FILTER" ] || [[ "$surf_n" == *"$FILTER"* ]]; then surf_wanted=1; fi; done
if [ "$surf_wanted" = 1 ]; then
  surf_godot="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
  surf_engine="$(cd "$HERE/.." && pwd)"
  command -v cygpath >/dev/null 2>&1 && surf_engine="$(cygpath -m "$surf_engine")"
  surf_sha="e3aad816ec7178361b08bf8da2a419fd7f8fe719eef8852aa70d476420f8c20f"
  surf_box="c1a5ae1f297fb32f498f84cbeed5126cddc30809"
  surf_out="$(env -u TL_STYLE MSYS_NO_PATHCONV=1 timeout 120 "$surf_godot" --headless --path "$surf_engine" --script res://kernel/world/draw/surf_case.gd -- "--sha=$surf_sha" "--box=$surf_box" 2>&1 | tr -d '\015' | grep -a '^SURF \|SCRIPT ERROR')"
  surf_cls="$(TL_STYLE=classic MSYS_NO_PATHCONV=1 timeout 120 "$surf_godot" --headless --path "$surf_engine" --script res://kernel/world/draw/surf_case.gd -- --classic 2>&1 | tr -d '\015' | grep -a '^SURF model \|SCRIPT ERROR')"
  surf_case() {   # name, the case's word in the SURF line, the output to read
    local line why=""
    line="$(echo "$3" | grep -a "^SURF $2 " | head -1)"
    if [ -z "$line" ]; then why="no SURF $2 line (${3:0:160})"
    elif [[ "$line" != "SURF $2 ok "* ]]; then why="${line#SURF $2 }"
    elif echo "$3" | grep -aq 'SCRIPT ERROR'; then why="script error: $(echo "$3" | grep -a 'SCRIPT ERROR' | head -1)"; fi
    verdict "$1" "$why" "${line#SURF $2 ok }"
  }
  surf_case surf.classic_source classic_source "$surf_out"
  surf_case surf.model model "$surf_out"
  surf_case surf.model_classic model "$surf_cls"
  surf_case surf.edges edges "$surf_out"
  surf_case surf.keys keys "$surf_out"
fi
