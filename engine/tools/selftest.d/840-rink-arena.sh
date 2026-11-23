# Hockey campaign, lane K6 (24 Nov 2026): thirdjam's hall in our engine (engine/cores/rink/arena, headless:
# cores/rink/arena/review/arena_case.gd). core.rink.arena.pieces: the baked scene holds every group of the table with
# its instances and triangles. .places: the pieces stand where thirdjam's SOURCE puts them (RinkActor.h / .cpp and
# ASSETS.md numbers: benches, boxes, table, goal lights, 73 caps on the board top, 56 stand pieces, 664 fans, the four
# key spots and the eight side lamps). .materials: every thirdjam material a piece wears is one this port knows, and
# the glass stays hidden as on thirdjam's clay tier. .rink: the ice, the boards, the kick plate and the cap round
# thirdjam's outline. .light: the rig handed to the style (18 spots, 4 with shadows, EV100 4.2).

if [ -z "$FILTER" ] || [[ "core.rink.arena.pieces core.rink.arena.places core.rink.arena.materials core.rink.arena.rink core.rink.arena.light" == *"$FILTER"* ]]; then
  ar_godot="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
  ar_engine="$(cd "$HERE/.." && pwd)"; command -v cygpath >/dev/null 2>&1 && ar_engine="$(cygpath -m "$ar_engine")"
  ar_out="$(MSYS_NO_PATHCONV=1 timeout 300 "$ar_godot" --headless --fixed-fps 60 --path "$ar_engine" \
    --script res://cores/rink/arena/review/arena_case.gd 2>&1 | tr -d '\015' | grep -a '^ARENA \|SCRIPT ERROR')"
  for ar_case in pieces places materials rink light; do
    if [ -z "$FILTER" ] || [[ "core.rink.arena.$ar_case" == *"$FILTER"* ]]; then
      ar_line="$(echo "$ar_out" | grep -a "^ARENA $ar_case " | head -1)"
      why=""
      if [ -z "$ar_line" ]; then why="no ARENA $ar_case line (${ar_out:0:160})"
      elif echo "$ar_out" | grep -aq 'SCRIPT ERROR'; then why="script error: $(echo "$ar_out" | grep -a 'SCRIPT ERROR' | head -1)"
      elif [[ "$ar_line" != "ARENA $ar_case ok=true"* ]]; then why="${ar_line:0:300}"; fi
      verdict "core.rink.arena.$ar_case" "$why" "${ar_line#ARENA $ar_case ok=true }"
    fi
  done
fi
