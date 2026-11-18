# Send stage keys to games with different declared actions and check when the visitor leaves.
# needs: OUTW from 110-p7.sh.

# --- K8 ---
# On stage a key the game declared is the game's: a scripted visitor (a test window) stands in a plot, E at 60, Q at 200,
# Esc at 300. Hockey declares Q (its pass): Q reaches the game (its record has "pass") and he stays on stage; Esc leaves at
# 300. The kit court does not use Q: Q leaves at 200 as before.
if [ -z "$FILTER" ] || [[ "k8.stage_keys" == *"$FILTER"* ]]; then
  WK="$HERE/../kernel/world/walks"; K8D="$OUTW/k8"; rm -rf "$K8D"; mkdir -p "$K8D"
  command -v cygpath >/dev/null 2>&1 && WK="$(cygpath -m "$WK")"
  ho="$(bash "$HERE/world.sh" visit-test "$WK/k8_stage_hockey.json" "--devices=$WK/k8_stage.devices.json" "--record=$K8D/rec.json" --cost=model --load=block 2>&1)"
  ko="$(bash "$HERE/world.sh" visit-test "$WK/k8_stage_kit.json" "--devices=$WK/k8_stage.devices.json" --cost=model --load=block 2>&1)"
  why=""
  echo "$ho" | grep -q '"kind":"visit_path","tick":240,[^}]*"stage":0,"mark":"after_q"' || why="hockey: not on stage after Q"
  echo "$ho" | grep -q '"kind":"visit_left","tick":300,' || why="${why:+$why; }hockey: Esc did not leave at 300"
  [ "$(grep -o '"pass",1\]' "$K8D/rec.hockey.1.json" 2>/dev/null | wc -l | tr -d ' ')" -ge 1 ] || why="${why:+$why; }hockey: the game did not get Q as its pass"
  echo "$ko" | grep -q '"kind":"visit_left","tick":200,' || why="${why:+$why; }kit court: Q did not leave at 200"
  verdict k8.stage_keys "$why" "hockey: Q is the game's pass ($(grep -o '"pass",1\]' "$K8D/rec.hockey.1.json" 2>/dev/null | wc -l | tr -d ' ') frames), Esc leaves; kit court: Q leaves"
fi

