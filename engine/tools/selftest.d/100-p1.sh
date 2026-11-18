# Run a pack with an endless loop alone and beside healthy packs.
# Check the processor-time watchdog and the healthy packs' hashes.

# ---------------------------------------------------------------- P1: limits that count processor time
# A real endless loop is stopped by the process time it used (about a quarter second of it), not by the wall clock: the
# report says how much processor time and how much wall time. (Cases bad.watchdog and bad.setup_loop above stay as they were.)
check p1.runaway_cpu 3 smoke "--pack=$EX/bad_watchdog" --frames=600 -- '"reason":|tick_timeout' 'of processor time \(it used [0-9]+ ms in [0-9]+ ms of wall time; runaway script\)'
# A world with one runaway pack and healthy ones runs to its end: the runaway is tripped, marked, left out, and every
# healthy pack hashes as it does alone (the world's guard and supervisor, host/guard.gd and host.gd).
if [ -z "$FILTER" ] || [[ "p1.world_runaway" == *"$FILTER"* ]]; then
  hx() { grep '"kind":"pack"' | sed -E 's/.*"state_hash":"([0-9a-f]{16}).*/\1/' | tr '\n' ' '; }
  solo=""
  for p in pack_min ex_bounce ex_wall; do solo="$solo$(bash "$HERE/world.sh" run --packs=$p --frames=300 | hx)"; done
  out="$(bash "$HERE/world.sh" run --packs=pack_min,bad_watchdog,ex_bounce,ex_wall --frames=300 2>&1)"; code=$?
  got="$(echo "$out" | grep '"kind":"pack"' | grep -v '"tripped":true' | sed -E 's/.*"state_hash":"([0-9a-f]{16}).*/\1/' | tr '\n' ' ')"
  why=""
  [ -n "$solo" ] && [ "$got" = "$solo" ] || why="healthy hashes in the world [$got] differ from alone [$solo]"
  echo "$out" | grep -q '"kind":"event","e":"pack_tripped"' || why="${why:+$why; }no pack_tripped event"
  echo "$out" | grep '"kind":"world"' | grep -Eq '"trips":\[\{"reason":"tick_timeout".*"restarts":1' || why="${why:+$why; }the world line has no trip record"
  echo "$out" | grep -q '"tripped":true' || why="${why:+$why; }the runaway pack is not marked tripped"
  [ "$code" = 1 ] || why="${why:+$why; }exit code $code, expected 1 (a pack failed)"
  verdict p1.world_runaway "$why" "pack_min, a runaway, ex_bounce, ex_wall: the runaway tripped at its tick 20, the three others ended with their solo hashes ($got)"
fi

