# The invariants' budget class (K3 round 7): the one-of-many frame budget (p50 1.0 ms) holds a pack placed in the village;
# a dungeon with no village plot is a game alone in its world, held to the solo budgets (p50 8.0 ms, check invariants.solo_budget;
# p99 8 ms, check invariants.solo_frame_budget, round 9).
#   budget.class   invariants.gd budget_class on the engine's boot files (hokej solo; parkour, hockey, ex_walker many) and on
#                  a fixture with each case alone (dungeon only, dungeon and plot, plot only, neither)
if [ -z "$FILTER" ] || [[ "budget.class" == *"$FILTER"* ]]; then
  bc_g="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
  bc_engine="$(cd "$HERE/.." && pwd)"
  command -v cygpath >/dev/null 2>&1 && bc_engine="$(cygpath -am "$bc_engine")"
  bc_scratch="$OUT/budget_class"; mkdir -p "$bc_scratch"
  command -v cygpath >/dev/null 2>&1 && bc_scratch="$(cygpath -am "$bc_scratch")"
  bc_out="$(MSYS_NO_PATHCONV=1 timeout 120 "$bc_g" --headless --path "$bc_engine" --script res://kernel/host/budget_class_test.gd -- "--scratch=$bc_scratch" 2>&1 | tr -d '\015')"
  bc_l="$(echo "$bc_out" | grep -m1 '^PASS  budget class\|^FAIL  budget class')"
  why=""
  [[ "$bc_l" == "PASS  budget class"* ]] || why="${bc_l:-no verdict line (a stopped run)}"
  grep -q '"invariants.solo_budget"' "$HERE/../kernel/host/invariants.gd" || why="${why:+$why; }invariants.gd has no invariants.solo_budget check"
  grep -q '"invariants.solo_frame_budget"' "$HERE/../kernel/host/invariants.gd" || why="${why:+$why; }invariants.gd has no invariants.solo_frame_budget check"
  verdict budget.class "$why" "$(echo "$bc_l" | cut -c7-)"
fi
