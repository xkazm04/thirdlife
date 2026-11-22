# One headless scene exercises the active pack camera, widget lifecycle and palette lookup.
hud_cases=(color_direct color_palette color_bad color_theme color_reset tag_front tag_offscreen tag_behind tag_view tag_offstage tag_freed tag_remove)
hud_selected=()
for hud_case in "${hud_cases[@]}"; do
  [[ "hud.$hud_case" == *"$FILTER"* ]] && hud_selected+=("$hud_case")
done
if [ "${#hud_selected[@]}" -gt 0 ]; then
  hud_engine="$(cd "$HERE/.." && pwd)"
  command -v cygpath >/dev/null 2>&1 && hud_engine="$(cygpath -m "$hud_engine")"
  hud_godot="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
  hud_log="$OUT/hud-tag.log"
  MSYS_NO_PATHCONV=1 timeout 60 "$hud_godot" --headless --fixed-fps 60 --path "$hud_engine" \
    --script res://kernel/feel/hud_case.gd > "$hud_log" 2>&1
  hud_rc=$?
  for hud_case in "${hud_selected[@]}"; do
    why=""
    if [ "$hud_rc" -ne 0 ] || ! grep -q "^HUD $hud_case PASS" "$hud_log"; then why="see $hud_log"; fi
    if [ "$(grep -Ec '^(ERROR:|SCRIPT ERROR:)' "$hud_log")" != 1 ] ||
       ! grep -q "^ERROR: TLHud.set_color: unknown palette key 'r4_missing_ink'" "$hud_log"; then
      why="expected only the bad palette key error; see $hud_log"
    fi
    verdict "hud.$hud_case" "$why"
  done
fi
