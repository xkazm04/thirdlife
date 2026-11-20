# Diorama night (20 Nov 2026), character pillar: the toy figure of the diorama style and the classic figure under it.
# Headless Godot, ticks only (engine/rigs/review/figure_case.gd, kernel/world/moves_pose_case.gd, kernel/runner/biped_grip_case.gd).
#   figure.toy       the diorama style gives the toy: the rails (height 2.0, radius 0.3, 12000 triangles, the 29 bones by name, every
#                    clip and socket name), two runs equal, the bun moves and comes to rest, stretch and squash settle at 1
#   figure.classic   TL_STYLE=classic gives today's figure: 29 bones, 10296 triangles, no feel layer, scale 1 throughout
#   figure.grip      the toy's hands meet what they grab: the wrists within 0.10 m of the ledge's edge and 0.12 m of the bar
#                    (the palm is 0.075 m from the wrist; the classic figure's poses leave 0.30 and 0.27 m), for the village
#                    visitor and for a pack's TLBiped
#   figure.clay      the clay shader keeps the toon shader's contract with the world: the instance uniforms the draw layer
#                    sets (tl_plot, tl_clip, tl_body) and the body tag of the ink pass (ROUGHNESS = 0.5); the style file
#                    asks for the toy; the classic style file does not

fg_godot="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
fg_engine="$(cd "$HERE/.." && pwd)"; command -v cygpath >/dev/null 2>&1 && fg_engine="$(cygpath -m "$fg_engine")"

fg_case() {   # fg_case <case name> <style: diorama|classic> <expect>
  if [ -z "$FILTER" ] || [[ "$1" == *"$FILTER"* ]]; then
    fg_out="$(MSYS_NO_PATHCONV=1 TL_STYLE="$2" timeout 180 "$fg_godot" --headless --fixed-fps 60 --path "$fg_engine" \
      --script res://rigs/review/figure_case.gd -- "--expect=$3" 2>&1 | tr -d '\015' | grep -a '^FIGURE\|SCRIPT ERROR')"
    fg_line="$(echo "$fg_out" | grep -a '^FIGURE ' | head -1)"
    why=""
    if [ -z "$fg_line" ]; then why="no FIGURE line (${fg_out:0:160})"
    elif echo "$fg_out" | grep -aq 'SCRIPT ERROR'; then why="script error: $(echo "$fg_out" | grep -a 'SCRIPT ERROR' | head -1)"
    elif [[ "$fg_line" != "FIGURE ok=true "* ]]; then why="$fg_line"; fi
    verdict "$1" "$why" "${fg_line#FIGURE ok=true }"
  fi
}
fg_case figure.toy diorama toy
fg_case figure.classic classic classic

if [ -z "$FILTER" ] || [[ "figure.grip" == *"$FILTER"* ]]; then
  why=""; seen=""
  for fg_c in "MOVESPOSE:res://kernel/world/moves_pose_case.gd:hands_to_edge_m:0.10:hands_to_bar_max_m:0.12" \
              "BIPEDGRIP:res://kernel/runner/biped_grip_case.gd:hands_to_lip_m:0.10:hands_to_bar_m:0.12"; do
    IFS=: read -r fg_tag fg_res1 fg_res2 fg_k1 fg_l1 fg_k2 fg_l2 <<< "$fg_c"
    fg_line="$(MSYS_NO_PATHCONV=1 TL_STYLE=diorama timeout 180 "$fg_godot" --headless --fixed-fps 60 --path "$fg_engine" \
      --script "$fg_res1:$fg_res2" 2>&1 | tr -d '\015' | grep -a "^$fg_tag " | head -1)"
    fg_a="$(echo "$fg_line" | grep -o "$fg_k1=[0-9.]*" | cut -d= -f2)"; fg_b="$(echo "$fg_line" | grep -o "$fg_k2=[0-9.]*" | cut -d= -f2)"
    if [ -z "$fg_a" ] || [ -z "$fg_b" ]; then why="${why:+$why; }$fg_tag: no figures (${fg_line:0:100})"
    elif [[ "$fg_line" != "$fg_tag ok=true "* ]]; then why="${why:+$why; }$fg_tag not ok"
    elif ! awk -v a="$fg_a" -v la="$fg_l1" -v b="$fg_b" -v lb="$fg_l2" 'BEGIN { exit !(a <= la && b <= lb) }'; then
      why="${why:+$why; }$fg_tag: wrists $fg_a m from the edge (limit $fg_l1), $fg_b m from the bar (limit $fg_l2)"; fi
    seen="${seen:+$seen; }$fg_tag edge $fg_a m, bar $fg_b m"
  done
  verdict figure.grip "$why" "wrist to the line: $seen"
fi

if [ -z "$FILTER" ] || [[ "figure.clay" == *"$FILTER"* ]]; then
  why=""
  fg_sh="$HERE/../style/shaders/body_clay.gdshader"
  for fg_need in "instance uniform vec4 tl_plot" "instance uniform vec4 tl_clip" "instance uniform vec2 tl_body" "ROUGHNESS = 0.5;" "uniform sampler2D pal_lut"; do
    grep -qF "$fg_need" "$fg_sh" || why="${why:+$why; }body_clay.gdshader lacks '$fg_need'"
  done
  grep -q '"_figure"' "$HERE/../style/style_diorama.json" && grep -q '"variant": "toy"' "$HERE/../style/style_diorama.json" || why="${why:+$why; }style_diorama.json does not ask for the toy figure (_figure.variant)"
  grep -q '_figure' "$HERE/../style/style.json" && why="${why:+$why; }style.json (classic) has a _figure section"
  verdict figure.clay "$why" "tl_plot, tl_clip, tl_body, the ink body tag, the palette lookup; the diorama style asks for the toy, the classic one does not"
fi
