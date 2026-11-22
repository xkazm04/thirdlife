# E6 (day of 22 Nov, lane D2): a game in a world plays as it does alone when a body touches several static shapes.
# A world moves every body of a pack from the viewport's default space into the pack's own space (world/pack.gd
# adopt); the lone worker leaves it where it entered. Moved and unmoved spaces once listed (and solved) the same bodies
# in another order, so hockey's r2a hashed differently in a world from frame 2050 on.
#   e6.space_order    one scene built twice (default space; a real pack holder's adopt()): same query order at frame 3
#   e6.space_contact  four movers sliding along walls, posts and floor at once: bit-equal transforms at frame 360
#   e6.body_order     hockey in a world (own space) and alone: TL_BODY_ORDER lists the same colliders in the same order
e6_cases="e6.space_order e6.space_contact e6.body_order"
if [ -z "$FILTER" ] || [[ "$e6_cases" == *"$FILTER"* ]]; then
  e6_g="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
  e6_engine="$(cd "$HERE/.." && pwd)"
  command -v cygpath >/dev/null 2>&1 && e6_engine="$(cygpath -am "$e6_engine")"
  if [ -z "$FILTER" ] || [[ "e6.space_order e6.space_contact" == *"$FILTER"* ]]; then
    # exit 0 or 1 is a run that completed (1: a case failed, its line says which); anything else is a stopped run
    e6_out="$(MSYS_NO_PATHCONV=1 timeout 300 "$e6_g" --headless --path "$e6_engine" --script res://kernel/runner/e6_space_case.gd 2>&1 | tr -d '\015'; echo "E6RC ${PIPESTATUS[0]}")"
    e6_rc="$(echo "$e6_out" | sed -n 's/^E6RC //p' | tail -1)"
    for e6_c in order contact; do
      e6_l="$(echo "$e6_out" | grep -m1 "^E6SPACE $e6_c ")"
      why=""; [[ "$e6_l" == "E6SPACE $e6_c ok"* ]] || why="${e6_l:-no E6SPACE $e6_c line (the run stopped: $(echo "$e6_out" | grep -m1 'SCRIPT ERROR' | cut -c1-120))}"
      if [ "$e6_rc" != 0 ] && [ "$e6_rc" != 1 ]; then why="the case run stopped (Godot exit ${e6_rc:-unknown}) ${e6_l:+after: $e6_l}"; fi
      e6_note="${e6_l#E6SPACE $e6_c ok}"; e6_note="${e6_note#:}"; e6_note="${e6_note# }"
      verdict "e6.space_$e6_c" "$why" "$e6_note"
    done
  fi
  if [ -z "$FILTER" ] || [[ "e6.body_order" == *"$FILTER"* ]]; then
    e6_dir="$OUT/e6_order"; rm -rf "$e6_dir"; mkdir -p "$e6_dir"
    e6_d="$e6_dir"; command -v cygpath >/dev/null 2>&1 && e6_d="$(cygpath -am "$e6_dir")"
    e6_pack="$e6_engine/packs/hockey"
    TL_BODY_ORDER="$e6_d/world" timeout 300 bash "$HERE/world.sh" run "--packs=$e6_pack" --mode=bot --frames=10 >"$e6_dir/world.log" 2>&1; e6_wrc=$?
    TL_BODY_ORDER="$e6_d/alone" TL_QUIET=1 timeout 300 bash "$TL" bot "--pack=$e6_pack" --test=tests/bot_hockey.gd --seed=1 --frames=10 >"$e6_dir/alone.log" 2>&1; e6_arc=$?
    e6_w="$(ls "$e6_dir"/world.* 2>/dev/null | grep -v '\.log$' | head -1)"
    why=""
    if [ -z "$e6_w" ] || [ ! -s "$e6_dir/alone" ]; then
      why="no body order written (world exit $e6_wrc, alone exit $e6_arc): a stopped run"
    else
      e6_nw="$(head -1 "$e6_w" | tr -d '\r')"; e6_na="$(head -1 "$e6_dir/alone" | tr -d '\r')"
      [ "$e6_nw" != "$e6_na" ] && why="collider counts differ: world $e6_nw, alone $e6_na"
      [ "${e6_na#n=}" -gt 0 ] 2>/dev/null || why="${why:+$why; }no collider listed ($e6_na)"
      if ! cmp -s "$e6_w" "$e6_dir/alone"; then
        why="${why:+$why; }body order differs at frame 3 in $(diff "$e6_w" "$e6_dir/alone" | grep -c '^[<>]') lines ($e6_dir)"
      fi
    fi
    verdict e6.body_order "$why" "hockey ${e6_na:-?} colliders, world = alone at frame 3"
  fi
fi
