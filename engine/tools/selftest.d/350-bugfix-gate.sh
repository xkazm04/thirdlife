# Gate honesty regressions from the bugfix-37 night (18 Nov 2026): a stopped run, an empty filter and a stale report
# are never a pass (docs/GATE-HONESTY.md). Each case runs the real runner on a provoked failure and wants it refused.
# needs: nothing from earlier blocks.

# The cases below run selftest.sh again, nested; a nested run never runs them again (no recursion, whatever its filter).
if [ -z "${TL_BUGFIX_NESTED:-}" ]; then
export TL_BUGFIX_NESTED=1

# D1: a `world.sh same` child that stops before its first hash makes world.same FAIL, not PASS.
if [ -z "$FILTER" ] || [[ "gate.world_same_stopped" == *"$FILTER"* ]]; then
  gs_dir="$OUT/gate.world_same_stopped"; mkdir -p "$gs_dir"
  gs_out="$(BASH_ENV="$HERE/selftest.d/_bugfix_stop_world.sh" TL_SELFTEST_DIR="$gs_dir" bash "$HERE/selftest.sh" world.same 2>&1)"; gs_code=$?
  why=""
  [ "$gs_code" -eq 1 ] || why="nested selftest exited $gs_code, expected 1"
  echo "$gs_out" | grep -q '^FAIL world.same: .*exited 143' || why="${why:+$why; }no 'FAIL world.same ... exited 143' line"
  echo "$gs_out" | grep -q '^PASS world.same' && why="${why:+$why; }PASS world.same printed for a stopped child"
  verdict gate.world_same_stopped "$why" "world.sh same stopped before its first hash: FAIL world.same, exit $gs_code"
fi

# D8: a selftest filter that selects no case exits 2 (could not run), never 0.
if [ -z "$FILTER" ] || [[ "gate.empty_filter" == *"$FILTER"* ]]; then
  ef_out="$(TL_SELFTEST_DIR="$OUT/gate.empty_filter" bash "$HERE/selftest.sh" walk.jmup 2>&1)"; ef_code=$?
  why=""; [ "$ef_code" -eq 2 ] || why="selftest.sh walk.jmup exited $ef_code, expected 2"
  echo "$ef_out" | grep -q '^selftest: no case matches' || why="${why:+$why; }no 'no case matches' line"
  verdict gate.empty_filter "$why" "selftest.sh walk.jmup: 0 cases, exit $ef_code"
fi

# D8: walk_case.gd takes the printed name (walk.ledge) and exits 2 when its filter selects no case.
if [ -z "$FILTER" ] || [[ "gate.walk_case_filter" == *"$FILTER"* ]]; then
  GW="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
  EW="$(cd "$HERE/.." && pwd)"; command -v cygpath >/dev/null 2>&1 && EW="$(cygpath -m "$EW")"
  # Godot's own exit status, read outside a pipe (PIPESTATUS does not leave a command substitution).
  MSYS_NO_PATHCONV=1 "$GW" --headless --path "$EW" --script res://kernel/world/walks/walk_case.gd -- walk.no_such_case > "$OUT/gate.walk_case_none.txt" 2>&1; wf_none_code=$?
  MSYS_NO_PATHCONV=1 "$GW" --headless --path "$EW" --script res://kernel/world/walks/walk_case.gd -- walk.ledge > "$OUT/gate.walk_case_one.txt" 2>&1; wf_one_code=$?
  wf_none="$(tr -d '\015' < "$OUT/gate.walk_case_none.txt" | grep '^WALKCASE')"
  wf_one="$(tr -d '\015' < "$OUT/gate.walk_case_one.txt" | grep '^WALKCASE')"
  why=""
  [ "$wf_none_code" -eq 2 ] || why="filter walk.no_such_case exited $wf_none_code, expected 2"
  echo "$wf_none" | grep -q '^WALKCASE done 0 0' || why="${why:+$why; }no 'WALKCASE done 0 0' for the empty filter"
  [ "$wf_one_code" -eq 0 ] || why="${why:+$why; }filter walk.ledge exited $wf_one_code, expected 0"
  echo "$wf_one" | grep -q '^WALKCASE done 1 1' || why="${why:+$why; }filter walk.ledge did not run exactly its one case"
  verdict gate.walk_case_filter "$why" "walk_case.gd -- walk.ledge runs 1 case (exit $wf_one_code); -- walk.no_such_case runs 0 (exit $wf_none_code)"
fi

# Q22: a kit claim selected alone measures in this run; a kit.bot.json left from an earlier run is not read.
if [ -z "$FILTER" ] || [[ "gate.stale_kit_claim" == *"$FILTER"* ]]; then
  sk_dir="$OUT/gate.stale_kit_claim"; mkdir -p "$sk_dir"
  echo '{"rig_vehicle_ok":true,"car_top_speed":99,"steer_wheel_yaw":0.25}' > "$sk_dir/kit.bot.json"
  sk_out="$(TL_SELFTEST_DIR="$sk_dir" bash "$HERE/selftest.sh" rig.vehicle_drives 2>&1)"; sk_code=$?
  why=""
  [ "$sk_code" -eq 0 ] || why="selftest.sh rig.vehicle_drives exited $sk_code"
  echo "$sk_out" | grep -q '^PASS kit.bot' || why="${why:+$why; }kit.bot did not run for the selected claim"
  echo "$sk_out" | grep -q 'top 99 m/s' && why="${why:+$why; }the stale 99 m/s figure was read"
  verdict gate.stale_kit_claim "$why" "$(echo "$sk_out" | grep '^PASS rig.vehicle_drives' | sed 's/^PASS rig.vehicle_drives *//')"
fi

# D1, the same class: the bare world verdicts (walk proof, compact village, world alone) FAIL when their child stops.
for gs_case in world.walk_proof:proof world.compact:proof p11.world_alone:alone; do
  gs_name="gate.stopped_$(echo "${gs_case%%:*}" | tr . _)"
  if [ -n "$FILTER" ] && [[ "$gs_name" != *"$FILTER"* ]]; then continue; fi
  gs_dir="$OUT/$gs_name"; mkdir -p "$gs_dir"
  gs_out="$(TL_BUGFIX_STOP="${gs_case#*:}" BASH_ENV="$HERE/selftest.d/_bugfix_stop_world.sh" TL_SELFTEST_DIR="$gs_dir" \
    bash "$HERE/selftest.sh" "${gs_case%%:*}" 2>&1)"; gs_code=$?
  why=""
  [ "$gs_code" -eq 1 ] || why="nested selftest exited $gs_code, expected 1"
  echo "$gs_out" | grep -q "^FAIL ${gs_case%%:*}: " || why="${why:+$why; }no 'FAIL ${gs_case%%:*}' line"
  verdict "$gs_name" "$why" "world.sh ${gs_case#*:} stopped before its verdict: FAIL ${gs_case%%:*}, exit $gs_code"
done

export -n TL_BUGFIX_NESTED; unset TL_BUGFIX_NESTED
fi
