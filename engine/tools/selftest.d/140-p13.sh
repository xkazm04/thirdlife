# Check that the kit scoreboard follows its score source.
# Compare the six compact village plots with their solo runs.

# --- P13 ---
# A kit scoreboard bound to a score source (TLKitSite.bind_scoreboard) shows the real score in a run with no world,
# and follows it (kernel/world/draw/p13_score_case.gd, headless).
if [ -z "$FILTER" ] || [[ "kit.score_bound" == *"$FILTER"* ]]; then
  G13="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
  E13="$(cd "$HERE/.." && pwd)"; command -v cygpath >/dev/null 2>&1 && E13="$(cygpath -m "$E13")"
  out="$(MSYS_NO_PATHCONV=1 "$G13" --headless --path "$E13" --script res://kernel/world/draw/p13_score_case.gd 2>&1 | tr -d '\015' | grep '^P13CASE')"      # P14: was a literal line break in tr (it joined every line, so the grep never matched)
  why=""; [[ "$out" == "P13CASE ok"* ]] || why="${out:-no P13CASE line}"
  verdict kit.score_bound "$why" "${out#P13CASE ok }"
fi
# The compact village (walks/compact_village.json) is a valid walk: six games, every one hashes as it does alone.
if [ -z "$FILTER" ] || [[ "world.compact" == *"$FILTER"* ]]; then
  out="$(bash "$HERE/world.sh" proof compact_village 2>&1)"
  why=""; echo "$out" | grep -q '^PASS world.proof' || why="$(echo "$out" | grep -E 'DIFFERENT|NO HASH|FAIL|rror' | head -3 | tr '
' ' ')"
  verdict world.compact "$why" "six games of the compact village: walk = alone = replay"
fi

