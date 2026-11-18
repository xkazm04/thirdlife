#!/bin/bash
# Lane walker: runs the six hunter repros for D6, D7, D14, D19, D20 against the code in this worktree.
#   bash docs/reports/bugfix-37/walker/run_repros.sh   (from the worktree root)
G="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
W="$(cd "$(dirname "$0")/../../../.." && pwd)"
command -v cygpath >/dev/null 2>&1 && W="$(cygpath -m "$W")"
R="$W/docs/reports/bugfix-37"
for s in hunt-Q/repro/b_steep_rest.gd hunt-R/repro/r2_slope_pit.gd hunt-Q/repro/a_stage_pose.gd hunt-R/repro/r4_clip_after_stage.gd hunt-R/repro/r8_slide_at_edge.gd hunt-R/repro/r9_jump_buffer.gd; do
  echo "== $s"
  MSYS_NO_PATHCONV=1 timeout 200 "$G" --headless --path "$W/engine" --script "$R/$s" 2>&1 | tr -d '\015' | grep -E "REPRO|^R[0-9]|before stage|ERROR|SCRIPT ERROR" | head -12
done
