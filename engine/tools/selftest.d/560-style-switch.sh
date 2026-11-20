# TL_STYLE chooses the style file (unset/crisp = style_crisp.json since 20 Nov, classic = style.json).
if [ -z "$FILTER" ] || [[ "style.switch" == *"$FILTER"* ]]; then
  sw_godot="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
  sw_engine="$(cd "$HERE/.." && pwd)"
  command -v cygpath >/dev/null 2>&1 && sw_engine="$(cygpath -m "$sw_engine")"
  sw_error=""
  sw_default="$(env -u TL_STYLE MSYS_NO_PATHCONV=1 "$sw_godot" --headless --path "$sw_engine" --script res://kernel/world/walks/style_switch_case.gd 2>&1 | tr -d '\r' | grep -a '^STYLE_SWITCH' | head -1)"
  sw_classic="$(TL_STYLE=classic MSYS_NO_PATHCONV=1 "$sw_godot" --headless --path "$sw_engine" --script res://kernel/world/walks/style_switch_case.gd 2>&1 | tr -d '\r' | grep -a '^STYLE_SWITCH' | head -1)"
  [ "$sw_default" = "STYLE_SWITCH path=res://style/style_crisp.json name=golden errors=0" ] || sw_error="default: '${sw_default:-no line}'"
  [ "$sw_classic" = "STYLE_SWITCH path=res://style/style.json name=golden errors=0" ] || sw_error="${sw_error:+$sw_error; }classic: '${sw_classic:-no line}'"
  verdict style.switch "$sw_error" "unset -> style_crisp.json, TL_STYLE=classic -> style.json (golden)"
fi
