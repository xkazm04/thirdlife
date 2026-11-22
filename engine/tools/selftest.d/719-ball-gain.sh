# H1 (lane N1, loop round 3, night of 22 Nov 2026): TLBall.set_max_gain / set_velocity (engine/kernel/feel/ball_gain_case.gd,
# headless, run twice). ball.gain_cut: a 60 kg block slid at 24 m/s into a resting puck sends it at 28.8 m/s without the
# limit and never past max(last speed, 10) + 4 a frame with it; ball.gain_declared: shoot_at / set_velocity / release / shoot
# are never cut, a raw linear_velocity write is; ball.gain_off: set_max_gain(0) is the old ball; ball.gain_same: two
# processes give the same capped speeds.

if [ -z "$FILTER" ] || [[ "ball.gain_cut ball.gain_declared ball.gain_off ball.gain_same" == *"$FILTER"* ]]; then
  bg_godot="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
  bg_engine="$(cd "$HERE/.." && pwd)"; command -v cygpath >/dev/null 2>&1 && bg_engine="$(cygpath -m "$bg_engine")"
  bg_run() { MSYS_NO_PATHCONV=1 timeout 300 "$bg_godot" --headless --fixed-fps 60 --path "$bg_engine" \
    --script res://kernel/feel/ball_gain_case.gd 2>&1 | tr -d '\015' | grep -a '^GAIN \|SCRIPT ERROR'; }
  bg_out="$(bg_run)"
  bg_out2="$(bg_run)"
  for bg_case in cut declared off; do
    if [ -z "$FILTER" ] || [[ "ball.gain_$bg_case" == *"$FILTER"* ]]; then
      bg_line="$(echo "$bg_out" | grep -a "^GAIN $bg_case " | head -1)"
      why=""
      if [ -z "$bg_line" ]; then why="no GAIN $bg_case line (${bg_out:0:160})"
      elif echo "$bg_out" | grep -aq 'SCRIPT ERROR'; then why="script error: $(echo "$bg_out" | grep -a 'SCRIPT ERROR' | head -1)"
      elif [[ "$bg_line" != "GAIN $bg_case ok=true"* ]]; then why="${bg_line:0:300}"; fi
      verdict "ball.gain_$bg_case" "$why" "${bg_line#GAIN $bg_case ok=true }"
    fi
  done
  if [ -z "$FILTER" ] || [[ "ball.gain_same" == *"$FILTER"* ]]; then
    bg_s1="$(echo "$bg_out" | grep -a '^GAIN seq ' | head -1)"; bg_s2="$(echo "$bg_out2" | grep -a '^GAIN seq ' | head -1)"
    why=""
    if [ -z "$bg_s1" ] || [ -z "$bg_s2" ]; then why="no GAIN seq line"
    elif [ "$bg_s1" != "$bg_s2" ]; then why="two processes differ: $bg_s1 / $bg_s2"; fi
    verdict ball.gain_same "$why" "${bg_s1#GAIN seq } in both processes"
  fi
fi
