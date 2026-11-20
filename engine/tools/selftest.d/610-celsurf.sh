# Crisp cel (day of 20 Nov 2026), surfaces (engine/kernel/world/draw/cel_case.gd, headless). A missing CEL line is a FAIL.
#   celsurf.classic_files  toon.gdshader, water.gdshader and style.json are byte for byte the files of the day's base
#   celsurf.model          TL_STYLE=crisp names the cel model and cel water, and style_crisp.json has no errors
#   celsurf.model_classic  TL_STYLE=classic names neither and has no key of the cel model
#   celsurf.pic_key        the picture cache key carries the baked land paints under crisp, nothing under classic
#   celsurf.pic_key_classic  (today's key byte-equal)
#   celsurf.palette        style_crisp.json keeps the palette keys of style.json, same names, same order
#   celsurf.globals        every shader global the cel shaders declare is one TLStyle registers; the eight land paints exist
#   celsurf.rails          road_rails.gd: rails on both sides, no collision object, a gap at a spur's mouth, nothing without the key
#   celsurf.paint          the land painted by numbers: grass to road is grass, then earth; never rock on level ground
# The three constants are sha256 of the files on d20-cel (d966639), line ends as LF. A change to one of them moves
# today's look on purpose: take the new value from the FAIL line, and say in the report why classic moved.
cel_names="celsurf.classic_files celsurf.model celsurf.model_classic celsurf.pic_key celsurf.pic_key_classic celsurf.palette celsurf.globals celsurf.paint celsurf.rails"
cel_wanted=0
for cel_n in $cel_names; do if [ -z "$FILTER" ] || [[ "$cel_n" == *"$FILTER"* ]]; then cel_wanted=1; fi; done
if [ "$cel_wanted" = 1 ]; then
  cel_godot="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
  cel_engine="$(cd "$HERE/.." && pwd)"
  command -v cygpath >/dev/null 2>&1 && cel_engine="$(cygpath -m "$cel_engine")"
  cel_toon="1230e177a4710b974d81dee9696b721ecce61ba810c522a74dd7943b5ff6ea78"
  cel_water="1697d92db4fc42326708e97a88529eaec1d697a2905e48042e9dfcbed1c6ce9b"
  cel_style="0d1349989f3a932ca18c9f2608e410894c538bb78a5573b658337fba8520cf55"
  cel_out="$(TL_STYLE=crisp MSYS_NO_PATHCONV=1 timeout 120 "$cel_godot" --headless --path "$cel_engine" --script res://kernel/world/draw/cel_case.gd -- "--toon=$cel_toon" "--water=$cel_water" "--style=$cel_style" 2>&1 | tr -d '\015' | grep -a '^CEL \|SCRIPT ERROR')"
  cel_cls="$(TL_STYLE=classic MSYS_NO_PATHCONV=1 timeout 120 "$cel_godot" --headless --path "$cel_engine" --script res://kernel/world/draw/cel_case.gd -- --classic 2>&1 | tr -d '\015' | grep -a '^CEL model \|^CEL pic_key \|SCRIPT ERROR')"
  cel_case() {   # name, the case's word in the CEL line, the output to read
    local line why=""
    line="$(echo "$3" | grep -a "^CEL $2 " | head -1)"
    if [ -z "$line" ]; then why="no CEL $2 line (${3:0:160})"
    elif [[ "$line" != "CEL $2 ok "* ]]; then why="${line#CEL $2 }"
    elif echo "$3" | grep -aq 'SCRIPT ERROR'; then why="script error: $(echo "$3" | grep -a 'SCRIPT ERROR' | head -1)"; fi
    verdict "$1" "$why" "${line#CEL $2 ok }"
  }
  cel_case celsurf.classic_files classic_files "$cel_out"
  cel_case celsurf.model model "$cel_out"
  cel_case celsurf.model_classic model "$cel_cls"
  cel_case celsurf.pic_key pic_key "$cel_out"
  cel_case celsurf.pic_key_classic pic_key "$cel_cls"
  cel_case celsurf.palette palette "$cel_out"
  cel_case celsurf.globals globals "$cel_out"
  cel_case celsurf.paint paint "$cel_out"
  cel_case celsurf.rails rails "$cel_out"
fi
