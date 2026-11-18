# Check HUD text and compare captures before and after the bottom label grows.
# needs: OUTW from 110-p7.sh.

# --- K5 ---
# TLHud plates, aligned lines, a bottom label that grows upwards (ex_hud): the bot reads the texts; two stills with
# the HUD (frame 20: the note has one line; frame 170: four) are written and differ.
if [ -z "$FILTER" ] || [[ "k5.hud" == *"$FILTER"* ]]; then
  check k5.hud_lint 0 lint "--pack=$EX/ex_hud" -- '"id":"lint.fence","ok":true' '"bypasses":\[\]'
  check k5.hud_bot 0 bot "--pack=$EX/ex_hud" -- '"id":"bot.ok","ok":true' '"note_lines":4'
  K5A="$OUTW/k5_hud_f20.png"; K5B="$OUTW/k5_hud_f170.png"; rm -f "$K5A" "$K5B"
  check k5.hud_still_short 0 capture "--pack=$EX/ex_hud" --cam=play --frame=20 --hud=on "--out=$K5A" --res=1280x720 -- '"id":"capture.written","ok":true'
  check k5.hud_still_grown 0 capture "--pack=$EX/ex_hud" --cam=play --frame=170 --hud=on "--out=$K5B" --res=1280x720 -- '"id":"capture.written","ok":true'
  why=""; [ -s "$K5A" ] && [ -s "$K5B" ] || why="a still is missing"
  cmp -s "$K5A" "$K5B" && why="${why:+$why; }the stills of one line and of four lines are the same file"
  verdict k5.hud_stills_differ "$why" "one line $(wc -c < "$K5A" 2>/dev/null | tr -d ' ') bytes, four lines $(wc -c < "$K5B" 2>/dev/null | tr -d ' ') bytes"
fi

