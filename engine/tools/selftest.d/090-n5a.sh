# Exercise tier transitions, the world budget and save/load recovery.
# Check the hashes and restart behavior on a visitor tour.

# ---------------------------------------------------------------- N5a: the world's clock (kernel/world/TIERS.md)
# the proof: three seeds, each stage, sideline and backdrop and back; every pack hashes as it does alone for the same
# number of its own ticks, and the world log replays to the same hashes
if [ -z "$FILTER" ] || [[ "world.walk_proof" == *"$FILTER"* ]]; then
  out="$(bash "$HERE/world.sh" proof proof --tiers-all 2>&1)"
  why=""; echo "$out" | grep -q '^PASS world.proof' || why="$(echo "$out" | grep -E 'DIFFERENT|NO HASH|never|FAIL|rror' | head -3 | tr '\n' ' ')"
  verdict world.walk_proof "$why" "walk = alone = replay: $(echo "$out" | grep -E '^[abc] \| ' | awk -F' [|] ' '{printf "%s %s ticks %s; ", $2, $3, $5}')"
fi
# a world too heavy for its budget: the farthest sideline packs are demoted first, then the whole world slows, and
# every pack keeps getting ticks (cost model: no clock is read)
if [ -z "$FILTER" ] || [[ "world.walk_valve" == *"$FILTER"* ]]; then
  out="$(bash "$HERE/world.sh" walk heavy 2>&1)"
  why=""
  echo "$out" | grep -q 'valve demotions 4, speed 800 (lowest 800) per mille, slice 4' || why="the valve did not end at 4 demotions, speed 800, slice 4"
  [ "$(echo "$out" | grep 'why:valve' | head -1 | grep -c 'plot:n4')" = 1 ] || why="${why:+$why; }the farthest sideline pack (n4) was not demoted first"
  [ "$(echo "$out" | grep -c '^pack ')" = 7 ] || why="${why:+$why; }expected 7 packs"
  starved="$(echo "$out" | grep '^pack ' | sed -E 's/.*: ticks ([0-9]+) of.*longest wait ([0-9]+),.*/\1 \2/' | awk '$1 < 200 || $2 > 6' | wc -l | tr -d ' ')"
  [ "$starved" = 0 ] || why="${why:+$why; }$starved pack(s) got fewer than 200 ticks or waited more than 6 world ticks"
  echo "$out" | grep -Eq 'gate leaks 0, .*script errors 0, engine errors 0' || why="${why:+$why; }leaks or errors"
  verdict world.walk_valve "$why" "4 demotions farthest first, then speed 800 per mille; all 7 packs kept ticking, longest wait 6 world ticks"
fi
# a walk along two boundaries (the line between two plots that touch; the 100 m sideline line of a third): no flapping
if [ -z "$FILTER" ] || [[ "world.walk_boundary" == *"$FILTER"* ]]; then
  out="$(bash "$HERE/world.sh" walk boundary 2>&1)"
  ch="$(echo "$out" | grep '^pack ' | sed -E 's/^pack ([a-z]+) .*changes ([0-9]+),.*/\1:\2/' | tr '\n' ' ')"
  why=""; [ "$ch" = "a:0 b:0 c:1 " ] || why="tier changes [$ch], expected a:0 b:0 c:1"
  verdict world.walk_boundary "$why" "2400 ticks of zigzag along the lines: tier changes $ch"
fi
# the world file: save, load (packs, plots, seeds and tick counts match), a file cut short is refused and left alone
if [ -z "$FILTER" ] || [[ "world.file" == *"$FILTER"* ]]; then
  WF="$OUT/world_file"; rm -rf "$WF"; mkdir -p "$WF"
  s1="$(bash "$HERE/world.sh" save "$WF/world.json" --packs=ex_bounce,pack_min,ex_wall --mode=bot --frames=300 --plot-spacing=60 --name=selftest 2>&1)"
  l1="$(bash "$HERE/world.sh" load "$WF/world.json" 2>&1)"
  s2="$(bash "$HERE/world.sh" load "$WF/world.json" --frames=50 "--save=$WF/world.json" 2>&1)"
  why=""
  [ "$(echo "$s1" | grep -c '^plot ')" = 3 ] || why="save did not print 3 plots: $(echo "$s1" | head -2 | tr '\n' ' ')"
  [ "$s1" = "$l1" ] || why="${why:+$why; }load differs from save"
  grep -q '"rev": 2' "$WF/world.json" 2>/dev/null || why="${why:+$why; }the second save is not rev 2"
  grep -q '"rev": 1' "$WF/world.json.prev" 2>/dev/null || why="${why:+$why; }the revision before was not kept"
  echo "$s2" | grep -q 'plot p2: .* ticks 350' || why="${why:+$why; }50 more ticks did not add up to 350"
  grep -q '"scores"' "$WF/world.json" 2>/dev/null || why="${why:+$why; }ex_bounce's _pack_save data is not in the file"
  head -c 600 "$WF/world.json" > "$WF/cut.json"; cp "$WF/cut.json" "$WF/world.json"
  l2="$(bash "$HERE/world.sh" load "$WF/world.json" 2>&1)"; code=$?
  [ $code -eq 2 ] || why="${why:+$why; }a file cut short gave exit code $code, expected 2"
  echo "$l2" | grep -q 'cut short' || why="${why:+$why; }no readable error for the cut file"
  cmp -s "$WF/cut.json" "$WF/world.json" || why="${why:+$why; }the cut file was changed"
  l3="$(bash "$HERE/world.sh" load "$WF/world.json.prev" 2>&1)"
  [ "$l3" = "$s1" ] || why="${why:+$why; }the revision before does not load to the saved world"
  verdict world.file "$why" "save = load ($(echo "$s1" | sed -E 's/^plot ([a-z0-9]+): pack ([a-z_.]+) .* ticks ([0-9]+)/\2 \3/' | tr '\n' ',' | sed 's/,$//')); rev 2 keeps rev 1; a cut file is refused with exit 2"
fi
# N7: one world you can walk through, in its headless form. Six games on plots; the visitor walks past two, enters the
# track, leaves, walks on, enters the wall yard, leaves. Every pack's hash in the tour = the same pack alone for the same
# number of its own ticks = the replay of the world log. A game that ended stays over: the owner paused the automatic
# next round on 2026-11-11 (tiers.json ships restart_pause_ticks 0).
if [ -z "$FILTER" ] || [[ "world.tour" == *"$FILTER"* ]]; then
  out="$(bash "$HERE/world.sh" tour tour --headless 2>&1)"
  why=""; echo "$out" | grep -q '^PASS world.tour' || why="$(echo "$out" | grep -E 'DIFFERENT|NO HASH|FAIL|rror|no game' | head -3 | tr '\n' ' ')"
  echo "$out" | grep -q 'e:tier  plot:drive  from:sideline  to:stage  why:enter' || why="${why:+$why; }the track was not entered from the sideline"
  echo "$out" | grep -q 'e:tier  plot:wall  from:stage  to:sideline  why:leave' || why="${why:+$why; }the wall yard was not left"
  echo "$out" | grep -q 'why:next_round' && why="${why:+$why; }a game started a next round although restart_pause_ticks ships as 0"
  echo "$out" | grep -Eq 'gate leaks 0, wrong-pack calls 0, .*script errors 0, engine errors 0' || why="${why:+$why; }gate leaks or errors: $(echo "$out" | grep '^world ' | sed -E 's/.*(gate leaks.*)/\1/')"
  verdict world.tour "$why" "6 games, 2 entered and left, no next round; tour = alone = replay: $(echo "$out" | grep -E '^[a-z]+ \| ' | grep -v '^plot | pack' | awk -F' [|] ' '{printf "%s %s ticks %s; ", $1, $3, $5}')"
fi
# The paused next-round path, kept under test: the same tour with restart_pause_ticks 180 in its own tiers. It is the
# only case that rebuilds a pack inside a running world (the half-tick bug N7 found and fixed lives there).
if [ -z "$FILTER" ] || [[ "world.next_round" == *"$FILTER"* ]]; then
  out="$(bash "$HERE/world.sh" tour tour_next_round --headless 2>&1)"
  why=""; echo "$out" | grep -q '^PASS world.tour' || why="$(echo "$out" | grep -E 'DIFFERENT|NO HASH|FAIL|rror|no game' | head -3 | tr '\n' ' ')"
  echo "$out" | grep -q 'e:restart  plot:walker  why:next_round' || why="${why:+$why; }the walker room did not start a next round"
  echo "$out" | grep -Eq 'gate leaks 0, wrong-pack calls 0, .*script errors 0, engine errors 0' || why="${why:+$why; }gate leaks or errors"
  verdict world.next_round "$why" "$(echo "$out" | grep -c 'why:next_round') next rounds, each pack rebuilt from its seed; tour = alone = replay"
fi

