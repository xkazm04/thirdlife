# Diorama day (20 Nov 2026), surfaces and nature, lane dio-fable (engine/kernel/world/draw/dio_case.gd, headless).
# A missing DIO line is a FAIL.
#   dio.tex            the six material textures (style/dio/tex/*.res) load without an import step, 1024 px, mipmaps
#   dio.tex_classic    TL_STYLE=classic: no `detail.tex`, no `detail.nature`, no texture registered, felt nature off
#   dio.nature         a kit pine, bush, rock and broadleaf drawn as felt and clay: recipe untouched, inside its reach,
#                      within a triangle budget, the same twice
#   dio.mesa           a mesa as slabs of clay: closed around, as high as asked, no wider than its foot
#   dio.rails          the road's rail row under the diorama: `detail.road_rails` named, no collider, every ninth span
#                      open, the same twice; the turned posts and round rails inside the bars' reach, the same twice
#   dio.rails_classic  TL_STYLE=classic: no `detail.road_rails`, no felt nature (landscape.gd builds no row)
#   dio.strew          a strew (pebbles, grit, tufts) sorted into pieces of ground for a far limit: nothing lost, the same twice
dio_names="dio.tex dio.tex_classic dio.nature dio.mesa dio.rails dio.rails_classic dio.strew"
dio_wanted=0
for dio_n in $dio_names; do if [ -z "$FILTER" ] || [[ "$dio_n" == *"$FILTER"* ]]; then dio_wanted=1; fi; done
if [ "$dio_wanted" = 1 ]; then
  dio_godot="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
  dio_engine="$(cd "$HERE/.." && pwd)"
  command -v cygpath >/dev/null 2>&1 && dio_engine="$(cygpath -m "$dio_engine")"
  dio_out="$(env -u TL_STYLE MSYS_NO_PATHCONV=1 timeout 120 "$dio_godot" --headless --path "$dio_engine" --script res://kernel/world/draw/dio_case.gd 2>&1 | tr -d '\015' | grep -a '^DIO \|SCRIPT ERROR')"
  dio_cls="$(TL_STYLE=classic MSYS_NO_PATHCONV=1 timeout 120 "$dio_godot" --headless --path "$dio_engine" --script res://kernel/world/draw/dio_case.gd -- --classic 2>&1 | tr -d '\015' | grep -a '^DIO tex \|^DIO rails \|SCRIPT ERROR')"
  dio_case() {   # name, the case's word in the DIO line, the output to read
    local line why=""
    line="$(echo "$3" | grep -a "^DIO $2 " | head -1)"
    if [ -z "$line" ]; then why="no DIO $2 line (${3:0:160})"
    elif [[ "$line" != "DIO $2 ok "* ]]; then why="${line#DIO $2 }"
    elif echo "$3" | grep -aq 'SCRIPT ERROR'; then why="script error: $(echo "$3" | grep -a 'SCRIPT ERROR' | head -1)"; fi
    verdict "$1" "$why" "${line#DIO $2 ok }"
  }
  dio_case dio.tex tex "$dio_out"
  dio_case dio.tex_classic tex "$dio_cls"
  dio_case dio.nature nature "$dio_out"
  dio_case dio.mesa mesa "$dio_out"
  dio_case dio.rails rails "$dio_out"
  dio_case dio.rails_classic rails "$dio_cls"
  dio_case dio.strew strew "$dio_out"
fi
