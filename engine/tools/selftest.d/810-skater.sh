# Hockey campaign, lane K2 (23 Nov 2026): thirdjam's skater in our engine (engine/rigs/skater, headless:
# rigs/skater/review/skater_case.gd). rig.skater.body: the baked body is thirdjam's (24 bones, nine slots, 12,040
# triangles, 1.637 m). rig.skater.clips: all 202 clips with their keys, keyed at 60 a second. rig.skater.ref: posed from a
# clip at a key the figure stands where thirdjam's own stands in the Unreal editor (27 poses, nine points each, 0.5 mm).
# rig.skater.play: one key a tick, the loop wraps, a one-shot holds, two runs agree.

if [ -z "$FILTER" ] || [[ "rig.skater.body rig.skater.clips rig.skater.ref rig.skater.play" == *"$FILTER"* ]]; then
  sk_godot="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
  sk_engine="$(cd "$HERE/.." && pwd)"; command -v cygpath >/dev/null 2>&1 && sk_engine="$(cygpath -m "$sk_engine")"
  sk_out="$(MSYS_NO_PATHCONV=1 timeout 300 "$sk_godot" --headless --fixed-fps 60 --path "$sk_engine" \
    --script res://rigs/skater/review/skater_case.gd 2>&1 | tr -d '\015' | grep -a '^SKATER \|SCRIPT ERROR')"
  for sk_case in body clips ref play; do
    if [ -z "$FILTER" ] || [[ "rig.skater.$sk_case" == *"$FILTER"* ]]; then
      sk_line="$(echo "$sk_out" | grep -a "^SKATER $sk_case " | head -1)"
      why=""
      if [ -z "$sk_line" ]; then why="no SKATER $sk_case line (${sk_out:0:160})"
      elif echo "$sk_out" | grep -aq 'SCRIPT ERROR'; then why="script error: $(echo "$sk_out" | grep -a 'SCRIPT ERROR' | head -1)"
      elif [[ "$sk_line" != "SKATER $sk_case ok=true"* ]]; then why="${sk_line:0:300}"; fi
      verdict "rig.skater.$sk_case" "$why" "${sk_line#SKATER $sk_case ok=true }"
    fi
  done
fi
