# Render under the same test-window lock as the tours.
if [ -z "$FILTER" ] || [[ "style.cel.frame" == *"$FILTER"* ]]; then
  cel_log="$OUT/cel-frame.log"
  cel_why=""
  (cd "$HERE/../.." && MSYS_NO_PATHCONV=1 TL_STYLE=crisp node --input-type=module - <<'NODE'
import { spawnSync } from "node:child_process";
import { withWindowLock } from "./devx/lib/perf/scenarios.mjs";
const draw = () => spawnSync(process.env.TL_GODOT || "C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe",
  ["--windowed", "--position", process.env.TL_WINDOW_POS || "0,1440", "--resolution", "960x540", "--fixed-fps", "60",
   "--audio-driver", "Dummy", "--path", "engine", "--script", "res://style/cel/frame_case.gd", "--quit-after", "180"],
  { stdio:"inherit", timeout:120000 });
const result = process.env.TL_WINDOW_LOCK === "off" ? draw() : withWindowLock(draw);
process.exitCode = result.status ?? 1;
NODE
  ) > "$cel_log" 2>&1 || cel_why="exit $?"
  cel_line="$(grep -a '^CEL_FRAME ok=true' "$cel_log")"
  if [ -z "$cel_line" ] || grep -aEq 'SCRIPT ERROR|SHADER ERROR|^ERROR:' "$cel_log"; then cel_why="see $cel_log"; fi
  verdict style.cel.frame "$cel_why" "$(grep -aE '^CEL_(LIGHT|SUN|SKY|BANDS|FILL|CONTOURS|MOTION)' "$cel_log" | tr -d '\r' | tr '\n' ' ')"
fi
