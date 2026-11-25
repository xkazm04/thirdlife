# Hockey campaign, lane K6 round 3 (24 Nov 2026): thirdjam's arena answering the game (engine/cores/rink/arena/rink_react.gd;
# headless: cores/rink/arena/review/react_case.gd). core.rink.react.curves: thirdjam's own pure-curve tests and the crowd's
# measured cheer. .caps: Build's stanchion walk is the baked caps' places and yaws. .goal: the lamps, the net, the caps
# and the crowd on a goal's frame and at rest by 120. .tj: thirdjam's own played match's goal and board events give every
# reaction its log wrote (the cap, tilt, hop, distance, the rattled piece and roll, the scored end).

if [ -z "$FILTER" ] || [[ "core.rink.react.curves core.rink.react.caps core.rink.react.goal core.rink.react.tj" == *"$FILTER"* ]]; then
  re_godot="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
  re_engine="$(cd "$HERE/.." && pwd)"; command -v cygpath >/dev/null 2>&1 && re_engine="$(cygpath -m "$re_engine")"
  re_out="$(MSYS_NO_PATHCONV=1 timeout 300 "$re_godot" --headless --fixed-fps 60 --path "$re_engine" \
    --script res://cores/rink/arena/review/react_case.gd 2>&1 | tr -d '\015' | grep -a '^REACT \|SCRIPT ERROR')"
  for re_case in curves caps goal tj; do
    if [ -z "$FILTER" ] || [[ "core.rink.react.$re_case" == *"$FILTER"* ]]; then
      re_line="$(echo "$re_out" | grep -a "^REACT $re_case " | head -1)"
      why=""
      if [ -z "$re_line" ]; then why="no REACT $re_case line (${re_out:0:160})"
      elif echo "$re_out" | grep -aq 'SCRIPT ERROR'; then why="script error: $(echo "$re_out" | grep -a 'SCRIPT ERROR' | head -1)"
      elif [[ "$re_line" != "REACT $re_case ok=true"* ]]; then why="${re_line:0:300}"; fi
      verdict "core.rink.react.$re_case" "$why" "${re_line#REACT $re_case ok=true }"
    fi
  done
fi
