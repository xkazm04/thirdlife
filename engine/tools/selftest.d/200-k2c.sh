# Capture a HUD both on and off, compare the images and reject an invalid option.
# needs: OUTW from 110-p7.sh.

# --- K2c ---
# capture --hud=on keeps the pack's HUD in the still (default off: the world alone); a wrong value is refused.
if [ -z "$FILTER" ] || [[ "k2.capture_hud" == *"$FILTER"* ]]; then
  KH_ON="$OUTW/k2_hud_on.png"; KH_OFF="$OUTW/k2_hud_off.png"; rm -f "$KH_ON" "$KH_OFF"
  check k2.capture_hud_on 0 capture "--pack=$EX/ex_down" --cam=near --frame=165 --test=tests/bot_down.gd --hud=on "--out=$KH_ON" --res=1280x720 -- '"id":"capture.written","ok":true'
  check k2.capture_hud_off 0 capture "--pack=$EX/ex_down" --cam=near --frame=165 --test=tests/bot_down.gd "--out=$KH_OFF" --res=1280x720 -- '"id":"capture.written","ok":true'
  check k2.capture_hud_bad 2 capture "--pack=$EX/ex_down" --cam=near --hud=yes "--out=$OUTW/k2_hud_bad.png" -- '--hud is on or off'
  why=""; [ -s "$KH_ON" ] && [ -s "$KH_OFF" ] || why="a still is missing"
  cmp -s "$KH_ON" "$KH_OFF" && why="${why:+$why; }the stills with and without the HUD are the same file"
  verdict k2.capture_hud_differs "$why" "with the HUD $(wc -c < "$KH_ON" 2>/dev/null | tr -d ' ') bytes, without $(wc -c < "$KH_OFF" 2>/dev/null | tr -d ' ') bytes"
fi

