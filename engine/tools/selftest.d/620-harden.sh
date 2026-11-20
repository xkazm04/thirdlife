# Night of 21 Nov 2026, lane L1 (crisp-harden): crisp cel's rails, gate signs, bushes and kit parts are solid for the
# visitor, and every way through stays open (kernel/world/terrain/harden_case.gd, headless, one Godot run for all nine;
# the exe's village of boot/village.json built under the crisp look; frames, not wall clock).
#   harden.rails_block  he walks into the drawn road rails from the road at every place they run unbroken: stopped
#   harden.rails_village the same in the compact village of walks/wf_feel.json, every start on the land (a solid bush on
#                       the road's edge was a block he stood on and walked over the rails from)
#   harden.rail_gaps    every open span (one in nine) between drawn rails: he walks through
#   harden.gate_sign    every gate marker (sign and flag) of a plot or lot: stopped
#   harden.site_sign    a construction site's sign (site/draw.gd): its two posts stop him; he walks under its board
#   harden.site_fence   B2: a site being built is fenced along its footprint square (turned or not): stopped from
#                       behind, in through the gate along the path
#   harden.bush_block   bushes he cannot step over: never in the middle third of one
#   harden.kit_parts    kit parts copied into his space as a game's colliders: fences, sign, marshal post, watch tower and
#                       bush stop him; he walks between a scoreboard's legs and over still pond water
#   harden.spawn_clear  the spawn and the gate of every plot (where Q puts him): on the land, his capsule touches nothing
#                       (a control box at the spawn must be found)
HARDEN_CASES="harden.rails_block harden.rails_village harden.rail_gaps harden.gate_sign harden.site_sign harden.site_fence harden.bush_block harden.kit_parts harden.spawn_clear"
if [ -z "$FILTER" ] || [[ "$HARDEN_CASES" == *"$FILTER"* ]]; then
  GH="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
  EH="$(cd "$HERE/.." && pwd)"; command -v cygpath >/dev/null 2>&1 && EH="$(cygpath -m "$EH")"
  # the Godot run's own exit status is read (PIPESTATUS): anything but 0 is a stopped run and every case of it FAILs
  hd_out="$(MSYS_NO_PATHCONV=1 timeout 600 "$GH" --headless --path "$EH" --script res://kernel/world/terrain/harden_case.gd 2>&1 | tr -d '\015'; echo "HARDENRC ${PIPESTATUS[0]}")"
  hd_rc="$(echo "$hd_out" | sed -n 's/^HARDENRC //p' | tail -1)"
  for hc in $HARDEN_CASES; do
    if [ -n "$FILTER" ] && [[ "$hc" != *"$FILTER"* ]]; then continue; fi
    hl="$(echo "$hd_out" | grep -m1 "^HARDEN $hc ")"
    why=""; [[ "$hl" == "HARDEN $hc ok"* ]] || why="${hl:-no HARDEN $hc line (the run stopped: $(echo "$hd_out" | grep -m1 'SCRIPT ERROR' | cut -c1-120))}"
    if [ "$hd_rc" != 0 ]; then why="the case run stopped (Godot exit ${hd_rc:-unknown}) ${hl:+after: $hl}"; fi
    verdict "$hc" "$why" "${hl#HARDEN $hc ok }"
  done
fi
