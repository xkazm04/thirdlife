# Hockey campaign, lane K7 (23-24 Nov 2026): the skater's look (engine/rigs/skater/look, style/tl_style_felt.gd,
# style/shaders/body_felt.gdshader). Headless (look_case.gd): look.skater.numbers (the ten skaters of a match reach the
# jersey and the patch as tens and ones, the crest follows the team), look.skater.instances (every number the look
# carries is thirdjam's material instance's), look.skater.shader (every key is a uniform of the new shader),
# look.skater.variants (felt and cel on one figure; the baked mesh untouched). In a window, under the test-window lock:
# look.skater.render (the shader compiles; the number's ink is on the back patch, more of it for 88 than for 11; the
# crest is on the chest). look.skater.shaders_kept: the working tree changes no tracked shader or style file but the
# look's own two (body_felt, body_contact) and, since round 3, lane K6's hall_ice (the lines marked K7 there: the key
# lights' shadows; agreed with the Director).

lk_names="look.skater.numbers look.skater.instances look.skater.shader look.skater.variants"
lk_wanted=0
for lk_n in $lk_names; do if [ -z "$FILTER" ] || [[ "$lk_n" == *"$FILTER"* ]]; then lk_wanted=1; fi; done
if [ "$lk_wanted" = 1 ]; then
  lk_godot="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
  lk_engine="$(cd "$HERE/.." && pwd)"; command -v cygpath >/dev/null 2>&1 && lk_engine="$(cygpath -m "$lk_engine")"
  lk_out="$(MSYS_NO_PATHCONV=1 timeout 300 "$lk_godot" --headless --fixed-fps 60 --path "$lk_engine" \
    --script res://rigs/skater/look/look_case.gd 2>&1 | tr -d '\015' | grep -a '^LOOK \|SCRIPT ERROR')"
  for lk_case in numbers instances shader variants; do
    lk_line="$(echo "$lk_out" | grep -a "^LOOK $lk_case " | head -1)"
    why=""
    if [ -z "$lk_line" ]; then why="no LOOK $lk_case line (${lk_out:0:160})"
    elif echo "$lk_out" | grep -aq 'SCRIPT ERROR'; then why="script error: $(echo "$lk_out" | grep -a 'SCRIPT ERROR' | head -1)"
    elif [[ "$lk_line" != "LOOK $lk_case ok=true"* ]]; then why="${lk_line:0:300}"; fi
    verdict "look.skater.$lk_case" "$why" "${lk_line#LOOK $lk_case ok=true }"
  done
fi

if [ -z "$FILTER" ] || [[ "look.skater.render" == *"$FILTER"* ]]; then
  lk_log="$OUT/skater-look-render.log"
  lk_why=""
  (cd "$HERE/../.." && MSYS_NO_PATHCONV=1 node --input-type=module - <<'NODE'
import { spawnSync } from "node:child_process";
import { withWindowLock } from "./devx/lib/perf/scenarios.mjs";
const draw = () => spawnSync(process.env.TL_GODOT || "C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe",
  ["--windowed", "--position", process.env.TL_WINDOW_POS || "0,1440", "--resolution", "1280x720", "--fixed-fps", "60",
   "--audio-driver", "Dummy", "--path", "engine", "res://tools/skater/look/look_gym.tscn", "--quit-after", "600", "--", "--mode=check", "--look=felt"],
  { stdio:"inherit", timeout:120000 });
const result = process.env.TL_WINDOW_LOCK === "off" ? draw() : withWindowLock(draw);
process.exitCode = result.status ?? 1;
NODE
  ) > "$lk_log" 2>&1 || lk_why="exit $?"
  lk_line="$(grep -a '^LOOK render ok=true' "$lk_log" | tr -d '\015' | head -1)"
  if [ -z "$lk_line" ] || grep -aEq 'SCRIPT ERROR|SHADER ERROR|^ERROR:' "$lk_log"; then lk_why="see $lk_log ($(grep -a '^LOOK render' "$lk_log" | tr -d '\015' | head -1))"; fi
  verdict look.skater.render "$lk_why" "${lk_line#LOOK render ok=true }"
fi

# look.skater.shadow (round 3, in a window): under the hall's four key lights a skater's shadow falls on the ice where the
# nearest key's geometry puts it; look.skater.shadow_red: with the keys off the same check fails (the case shown red).
for lk_s in shadow shadow_red; do
  if [ -z "$FILTER" ] || [[ "look.skater.$lk_s" == *"$FILTER"* ]]; then
    lk_log="$OUT/skater-look-$lk_s.log"
    lk_extra=""; [ "$lk_s" = shadow_red ] && lk_extra="--keys=0"
    (cd "$HERE/../.." && LK_EXTRA="$lk_extra" MSYS_NO_PATHCONV=1 node --input-type=module - <<'NODE'
import { spawnSync } from "node:child_process";
import { withWindowLock } from "./devx/lib/perf/scenarios.mjs";
const extra = process.env.LK_EXTRA ? [process.env.LK_EXTRA] : [];
const draw = () => spawnSync(process.env.TL_GODOT || "C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe",
  ["--windowed", "--position", process.env.TL_WINDOW_POS || "0,1440", "--resolution", "1280x720", "--fixed-fps", "60",
   "--audio-driver", "Dummy", "--path", "engine", "res://cores/rink/arena/review/figure_view.tscn", "--quit-after", "900", "--", "--check=shadow", ...extra],
  { stdio:"inherit", timeout:180000 });
const result = process.env.TL_WINDOW_LOCK === "off" ? draw() : withWindowLock(draw);
process.exitCode = 0;
NODE
    ) > "$lk_log" 2>&1
    lk_line="$(grep -a '^LOOK shadow ' "$lk_log" | tr -d '\015' | head -1)"
    why=""
    if [ -z "$lk_line" ]; then why="no LOOK shadow line (see $lk_log)"
    elif grep -aEq 'SCRIPT ERROR|SHADER ERROR' "$lk_log"; then why="script or shader error (see $lk_log)"
    elif [ "$lk_s" = shadow ] && [[ "$lk_line" != "LOOK shadow ok=true"* ]]; then why="${lk_line:0:200}"
    elif [ "$lk_s" = shadow_red ] && [[ "$lk_line" != "LOOK shadow ok=false keys=0"* ]]; then why="with the keys off the check must fail: ${lk_line:0:200}"; fi
    verdict "look.skater.$lk_s" "$why" "${lk_line#LOOK shadow }"
  fi
done

if [ -z "$FILTER" ] || [[ "look.skater.shaders_kept" == *"$FILTER"* ]]; then
  lk_changed="$(cd "$HERE/../.." && git diff --name-only HEAD -- engine/style/shaders engine/style/style.json engine/style/style_crisp.json engine/style/style_diorama.json engine/style/style_overcast.json ':(exclude)engine/style/shaders/body_felt.gdshader' ':(exclude)engine/style/shaders/body_contact.gdshader' ':(exclude)engine/style/shaders/hall_ice.gdshader' 2>&1 | tr '\n' ' ')"
  why=""
  [ -n "$lk_changed" ] && why="changed against HEAD: $lk_changed"
  [ -f "$HERE/../style/shaders/body_felt.gdshader" ] || why="style/shaders/body_felt.gdshader is missing"
  verdict look.skater.shaders_kept "$why" "no tracked shader or style file but the look's own differs from HEAD"
fi
