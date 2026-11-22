# E1 (lane N1, loop round 1, night of 22 Nov 2026): TLBiped.play_clip on a frame timeline, set_clip_speed, and their
# meeting with hit-stop and the kernel's reactions (engine/kernel/feel/clip_clock_case.gd, headless). Cases
# clock.map, clock.same, clock.speed, clock.bad; the "bad" case prints one expected push_error.

if [ -z "$FILTER" ] || [[ "clock.map clock.same clock.speed clock.bad" == *"$FILTER"* ]]; then
  ck_godot="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
  ck_engine="$(cd "$HERE/.." && pwd)"; command -v cygpath >/dev/null 2>&1 && ck_engine="$(cygpath -m "$ck_engine")"
  ck_out="$(MSYS_NO_PATHCONV=1 timeout 300 "$ck_godot" --headless --fixed-fps 60 --path "$ck_engine" \
    --script res://kernel/feel/clip_clock_case.gd 2>&1 | tr -d '\015' | grep -a '^CLOCK \|SCRIPT ERROR')"
  for ck_case in map same speed bad; do
    if [ -z "$FILTER" ] || [[ "clock.$ck_case" == *"$FILTER"* ]]; then
      ck_line="$(echo "$ck_out" | grep -a "^CLOCK $ck_case " | head -1)"
      why=""
      if [ -z "$ck_line" ]; then why="no CLOCK $ck_case line (${ck_out:0:160})"
      elif echo "$ck_out" | grep -aq 'SCRIPT ERROR'; then why="script error: $(echo "$ck_out" | grep -a 'SCRIPT ERROR' | head -1)"
      elif [[ "$ck_line" != "CLOCK $ck_case ok=true"* ]]; then why="${ck_line:0:300}"; fi
      verdict "clock.$ck_case" "$why" "${ck_line#CLOCK $ck_case ok=true }"
    fi
  done
fi
