# Compare lifecycle diagnostics for a deliberately bad pack alone and in a world.
# Check which module owns the shared lifecycle and run its headless case.

# --- life: one pack lifecycle (kernel/runner/pack_life.gd) ---
# The lone worker and a world's holder drive one core, so a deliberately bad pack (examples/bad_life) is reported alike:
# a _bot_result without a summary fails the bot, a crate below y = -50 is counted with its path, a script attached after
# add_child is named. Alone first (the runner's verdict), then the same pack in a world (its plot line).
life_on() { [ -z "$FILTER" ] || [[ "$1" == *"$FILTER"* ]]; }
LBR='_bot_result\(\) did not return \{ok: bool, summary: String\}'
LIDLE='scripts/main.gd on node .World/Late. never runs \(_physics_process is off\): call set_script before add_child'
check life.alone_bot_result 1 bot "--pack=$EX/bad_life" -- '"id":"bot.ok","ok":false' "\"result\":\\{\"ok\":false,\"summary\":\"$LBR\"\\}"
check life.alone_idle_script 0 smoke "--pack=$EX/bad_life" --frames=60 -- "\"id\":\"smoke.loads\",\"ok\":true,\"detail\":\"pack loaded; WARNING: $LIDLE"
check life.alone_below 1 invariants "--pack=$EX/bad_life" --frames=300 -- '"id":"invariants.below_ground","ok":false'
if life_on life.world_bot_result || life_on life.world_below || life_on life.world_idle_script; then
  lw="$(bash "$HERE/world.sh" run --packs=bad_life --mode=bot --frames=600 2>&1 | grep '"kind":"pack"')"
fi
if life_on life.world_bot_result; then
  why=""; echo "$lw" | grep -Eq "\"bot\":\\{[^}]*\"result\":\\{\"ok\":false,\"summary\":\"$LBR\"\\}" || why="the plot line's bot result is not the runner's failed verdict: $(echo "$lw" | grep -o '"bot":{[^}]*}' | head -1)"
  verdict life.world_bot_result "$why" "a summary-less _bot_result fails the bot in a world as alone"
fi
if life_on life.world_below; then
  why=""; echo "$lw" | grep -Eq '"below_count":[1-9][0-9]*' || why="no below_count > 0 on the plot line"
  echo "$lw" | grep -Eq '"below":\{"node":"World/[^"]+","frame":[0-9]+' || why="${why:+$why; }no body path below ground on the plot line"
  verdict life.world_below "$why" "$(echo "$lw" | grep -o '"below":{[^}]*}' | head -1)"
fi
if life_on life.world_idle_script; then
  why=""; echo "$lw" | grep -Eq "\"warnings\":\\[\"$LIDLE" || why="the plot line does not name the idle script"
  verdict life.world_idle_script "$why" "set_script after add_child is named in a world as alone"
fi
if life_on life.one_owner; then
  K="$HERE/../kernel"; why=""
  for s in 'TLContext.new()' '"_pack_setup"' '"_bot_tick"' '"_bot_result"' '_census_node'; do
    for f in runner/worker.gd world/pack.gd; do
      n="$(grep -cF -- "$s" "$K/$f")"; [ "$n" != 0 ] && why="${why:+$why; }$f has $s $n times"
    done
    grep -qF -- "$s" "$K/runner/pack_life.gd" 2>/dev/null || why="${why:+$why; }runner/pack_life.gd lacks $s"
  done
  verdict life.one_owner "$why" "context, setup, bot calls and census live only in runner/pack_life.gd"
fi
if life_on life.case; then
  GL="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
  EL="$(cd "$HERE/.." && pwd)"; command -v cygpath >/dev/null 2>&1 && EL="$(cygpath -m "$EL")"
  out="$(MSYS_NO_PATHCONV=1 "$GL" --headless --path "$EL" --script res://kernel/runner/life_case.gd 2>&1 | tr -d '\015' | grep '^LIFECASE')"
  why=""; [[ "$out" == "LIFECASE ok"* ]] || why="${out:-no LIFECASE line}"
  verdict life.case "$why" "${out#LIFECASE ok }"
fi

