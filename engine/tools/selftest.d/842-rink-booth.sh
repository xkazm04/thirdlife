# Hockey campaign, lane K6 round 3 (24 Nov 2026): thirdjam's commentator's voice and the barks' sound (engine/cores/rink/audio,
# kernel TLSound.stop_voice; headless: cores/rink/audio/review/booth_case.gd). core.rink.booth.voices: a voice for every line
# of the booth's bank. .match: a match of the bare core through the pack's own HUD (one picker): every line the caption
# starts is said on its frame with its own file, every bark said plays MS_bark, a line cut by a bark at the human fades;
# two runs agree. .duck: the music ducks to 0.45 under a line over 12 frames and comes back. .pause: under the tree's
# pause the loop and the line hold their place and go on at resume.

if [ -z "$FILTER" ] || [[ "core.rink.booth.voices core.rink.booth.match core.rink.booth.duck core.rink.booth.pause" == *"$FILTER"* ]]; then
  bo_godot="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
  bo_engine="$(cd "$HERE/.." && pwd)"; command -v cygpath >/dev/null 2>&1 && bo_engine="$(cygpath -m "$bo_engine")"
  bo_out="$(MSYS_NO_PATHCONV=1 timeout 600 "$bo_godot" --headless --fixed-fps 60 --path "$bo_engine" \
    --script res://cores/rink/audio/review/booth_case.gd 2>&1 | tr -d '\015' | grep -a '^BOOTH \|SCRIPT ERROR')"
  for bo_case in voices match duck pause; do
    if [ -z "$FILTER" ] || [[ "core.rink.booth.$bo_case" == *"$FILTER"* ]]; then
      bo_line="$(echo "$bo_out" | grep -a "^BOOTH $bo_case " | head -1)"
      why=""
      if [ -z "$bo_line" ]; then why="no BOOTH $bo_case line (${bo_out:0:160})"
      elif echo "$bo_out" | grep -aq 'SCRIPT ERROR'; then why="script error: $(echo "$bo_out" | grep -a 'SCRIPT ERROR' | head -1)"
      elif [[ "$bo_line" != "BOOTH $bo_case ok=true"* ]]; then why="${bo_line:0:300}"; fi
      verdict "core.rink.booth.$bo_case" "$why" "${bo_line#BOOTH $bo_case ok=true }"
    fi
  done
fi
