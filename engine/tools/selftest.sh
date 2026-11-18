#!/bin/bash
# Kernel self-test: every verb on the good example pack and each deliberately bad pack; checks the exit code and the
# report of every case. One PASS/FAIL line per case; exit code 0 only when every case passed.
#   tl.sh selftest [name-filter]      (for example: tl.sh selftest watchdog)
# No case reads the wall clock. Reports are kept in $TL_SELFTEST_DIR (default: a temporary directory).
HERE="$(cd "$(dirname "$0")" && pwd)"
TL="$HERE/tl.sh"
EX="$HERE/../kernel/examples"
OUT="${TL_SELFTEST_DIR:-${TMPDIR:-${TEMP:-/tmp}}/tl_selftest_$$}"
mkdir -p "$OUT"
FILTER="$1"
pass=0; fail=0

report_of() { echo "$OUT/$1.json"; }

# check <name> <expected exit> <verb and args...> [-- <ERE the report must match>...]
check() {
  local name="$1" want="$2"; shift 2
  if [ -n "$FILTER" ] && [[ "$name" != *"$FILTER"* ]]; then return; fi
  local args=() pats=() in_pats=0
  for a in "$@"; do
    if [ "$a" = "--" ]; then in_pats=1; elif [ $in_pats -eq 1 ]; then pats+=("$a"); else args+=("$a"); fi
  done
  local rep; rep="$(report_of "$name")"; rm -f "$rep"
  local last; last="$(TL_QUIET=1 bash "$TL" "${args[@]}" "--report=$rep")"; local got=$?
  local why=""
  [ "$got" != "$want" ] && why="exit code $got, expected $want"
  if [ ! -s "$rep" ]; then
    why="${why:+$why; }no report file"
  else
    [ "$(tr -d '\r\n' < "$rep")" != "$(echo "$last" | tr -d '\r\n')" ] && why="${why:+$why; }the last stdout line is not the report"
    grep -q '"schema":"tl.verify/1"' "$rep" || why="${why:+$why; }schema missing"
    local agree=0
    case "$got" in
      0) grep -q '"ok":true,"outcome":"passed"' "$rep" && agree=1;;
      1) grep -q '"ok":false,"outcome":"failed"' "$rep" && agree=1;;
      2) grep -q '"ok":false,"outcome":"not_run"' "$rep" && agree=1;;
      3) grep -q '"ok":false,"outcome":"watchdog"' "$rep" && agree=1;;
    esac
    [ $agree -eq 0 ] && why="${why:+$why; }outcome does not agree with exit code $got"
    for p in "${pats[@]}"; do
      grep -Eq -- "$p" "$rep" || why="${why:+$why; }report lacks /$p/"
    done
  fi
  verdict "$name" "$why"
}

verdict() {
  if [ -n "$FILTER" ] && [[ "$1" != *"$FILTER"* ]]; then return; fi
  if [ -z "$2" ]; then echo "PASS $1${3:+  ($3)}"; pass=$((pass+1)); else echo "FAIL $1: $2"; fail=$((fail+1)); fi
}

field() { grep -o "\"$2\":\"[^\"]*\"" "$(report_of "$1")" 2>/dev/null | head -1 | cut -d'"' -f4; }
number() { grep -o "\"$2\":[-0-9.e]*" "$(report_of "$1")" 2>/dev/null | head -1 | cut -d: -f2; }

# ---------------------------------------------------------------- the good pack: all five verbs
check min.lint 0 lint "--pack=$EX/pack_min" -- '"id":"lint.fence","ok":true' '"bypasses":\[\]' '"gdscript_lines":\{"scripts":[0-9]+'
check min.smoke 0 smoke "--pack=$EX/pack_min" --seed=1 --frames=3600 -- '"id":"smoke.no_script_errors","ok":true,"detail":"0 errors in 3600 frames"' '"state_hash":"[0-9a-f]{64}"'
check min.smoke_again 0 smoke "--pack=$EX/pack_min" --seed=1 --frames=3600
check min.smoke_seed2 0 smoke "--pack=$EX/pack_min" --seed=2 --frames=3600
if [ -z "$FILTER" ] || [[ "min.determinism" == *"$FILTER"* ]]; then
  h1="$(field min.smoke state_hash)"; h2="$(field min.smoke_again state_hash)"; h3="$(field min.smoke_seed2 state_hash)"
  why=""
  [ -z "$h1" ] && why="no state_hash"
  [ "$h1" != "$h2" ] && why="same seed gave different hashes ($h1 / $h2)"
  [ "$h1" = "$h3" ] && why="${why:+$why; }a different seed gave the same hash"
  verdict min.determinism "$why" "seed 1: ${h1:0:16} twice; seed 2: ${h3:0:16}"
fi
check min.invariants 0 invariants "--pack=$EX/pack_min" -- '"id":"invariants.determinism","ok":true' '"id":"invariants.bot_deterministic","ok":true' '"id":"invariants.below_ground","ok":true' '"id":"invariants.frame_budget","ok":true' '"id":"invariants.entity_budget","ok":true'
check min.bot 0 bot "--pack=$EX/pack_min" --test=tests/bot_roll.gd -- '"id":"bot.completed","ok":true' '"id":"bot.ok","ok":true' '"bot":\{"test":"tests/bot_roll.gd","done":true,"frames":[0-9]+,'
PNG="$OUT/min_hero.png"; command -v cygpath >/dev/null 2>&1 && PNG="$(cygpath -m "$PNG")"
check min.capture 0 capture "--pack=$EX/pack_min" --cam=hero --frame=120 "--out=$PNG" --res=1280x720 -- '"id":"capture.written","ok":true' '"capture":\{"cam":"hero","frame":120,' '"width":1280,"height":720'
if [ -z "$FILTER" ] || [[ "min.capture_file" == *"$FILTER"* ]]; then
  why=""; [ -s "$PNG" ] || why="no image at $PNG"
  [ -z "$why" ] && [ "$(head -c 4 "$PNG" | tail -c 3)" != "PNG" ] && why="not a PNG file"
  verdict min.capture_file "$why" "$(wc -c < "$PNG" 2>/dev/null | tr -d ' ') bytes"
fi
check min.res_path 0 lint --pack=res://kernel/examples/pack_min
check min.res_path_smoke 0 smoke --pack=res://kernel/examples/pack_min --frames=120

# ---------------------------------------------------------------- V0 / V1
check bad.schema 1 lint "--pack=$EX/bad_schema" -- '"id":"lint.schema","ok":false' '"kind":"schema","file":"pack.json","line":9,"message":"unknown key .author.'
check bad.schema_smoke 2 smoke "--pack=$EX/bad_schema" -- '"kind":"schema"'
check bad.layout 1 lint "--pack=$EX/bad_layout" -- '"id":"lint.layout","ok":false' '"kind":"layout","file":"stray.md"' '"kind":"layout","file":"tests/missing.gd"' '"kind":"layout","file":"data/notes.txt"'
check bad.fence 1 lint "--pack=$EX/bad_fence" -- '"id":"lint.fence","ok":false' '"kind":"fence","file":"scripts/fence.gd","line":1,"message":".class_name. is outside the fence'
if [ -z "$FILTER" ] || [[ "bad.fence_each_line" == *"$FILTER"* ]]; then
  want="$( (echo 1; awk '/^# FENCE BEGIN/{f=1;next}/^# FENCE END/{f=0}f{print NR}' "$EX/bad_fence/scripts/fence.gd") | sort -n | tr '\n' ' ')"
  got="$(grep -o '"kind":"fence","file":"scripts/fence.gd","line":[0-9]*' "$(report_of bad.fence)" | grep -o '[0-9]*$' | sort -n | tr '\n' ' ')"
  why=""; [ "$want" != "$got" ] && why="fence lines reported [$got] expected [$want]"
  verdict bad.fence_each_line "$why" "$(echo $want | wc -w | tr -d ' ') fenced patterns, each reported once with its line; comments and strings ignored"
fi
check bad.capability 1 lint "--pack=$EX/bad_capability" -- '"id":"lint.capabilities","ok":false' '"kind":"capability","file":"scripts/main.gd","line":6'
check bad.capability_run 1 smoke "--pack=$EX/bad_capability" --frames=10 -- '"kind":"script_error","file":"scripts/main.gd","line":6,"message":"TLBodies needs the capability .physics.'
check bad.bypass 0 lint "--pack=$EX/bad_bypass" -- '"primitive":"TLRules","file":"scripts/main.gd","line":4' '"file":"scripts/main.gd","line":10,"pattern":"RigidBody3D.new\(\)"' '"line":16,"pattern":"Area3D.new\(\)"' '"line":21,"pattern":"apply_impulse"'
check bad.bypass_kit_part 0 lint "--pack=$EX/bad_bypass" -- '"kit_parts_added":1,'
# look and geometry made by hand (WP5b): materials and lights are `style` bypasses in scripts/, gen/ and tests/; meshes
# are `kit` bypasses in scripts/ and tests/; a generator's geometry stays in kit_parts_added and is not counted twice
check bad.bypass_look 0 lint "--pack=$EX/bad_bypass" -- '"primitive":"style","file":"scripts/main.gd","line":29,"pattern":"StandardMaterial3D.new\(\)"' '"primitive":"style","file":"scripts/main.gd","line":30,"pattern":"DirectionalLight3D.new\(\)"' '"primitive":"kit","file":"scripts/main.gd","line":31,"pattern":"BoxMesh.new\(\)"' '"primitive":"kit","file":"scripts/main.gd","line":32,"pattern":"MeshInstance3D.new\(\)"' '"primitive":"style","file":"gen/part.gd","line":9,"pattern":"ShaderMaterial.new\(\)"' '"kit_parts_added":1,'
if [ -z "$FILTER" ] || [[ "bad.bypass_gen_not_double_counted" == *"$FILTER"* ]]; then
  why=""; grep -q '"primitive":"kit","file":"gen/' "$(report_of bad.bypass_look)" 2>/dev/null && why="geometry in gen/ was also listed as a kit bypass"
  [ -s "$(report_of bad.bypass_look)" ] || why="no bad.bypass_look report"
  verdict bad.bypass_gen_not_double_counted "$why" "gen/part.gd: ArrayMesh and MeshInstance3D only in kit_parts_added"
fi
check bad.size 1 lint "--pack=$EX/bad_size" -- '"id":"lint.size","ok":false' '"kind":"size","file":"scripts/big.gd","line":601'
check bad.nondeterminism_lint 1 lint "--pack=$EX/bad_nondeterminism" -- '"kind":"fence","file":"scripts/main.gd","line":8,"message":".randf\(. is outside the fence'
for p in assets filetype reflection classes tree alias load; do
  check "bad.reach_$p" 1 lint "--pack=$EX/bad_reach_$p" -- '"id":"lint.fence","ok":false'
done

# ---------------------------------------------------------------- V2
check bad.script_error 1 smoke "--pack=$EX/bad_script_error" --frames=120 -- '"id":"smoke.no_script_errors","ok":false' '"kind":"script_error","file":"scripts/main.gd","line":17'
check bad.parse_error 1 smoke "--pack=$EX/bad_parse_error" --frames=120 -- '"id":"smoke.loads","ok":false' '"kind":"script_error","file":"scripts/main.gd","line":6,"message":"Parse Error'
check bad.watchdog 3 smoke "--pack=$EX/bad_watchdog" --frames=600 -- '"id":"smoke.watchdog","ok":false' '"kind":"watchdog"' 'tick_timeout'
check bad.watchdog_bot 3 bot "--pack=$EX/bad_watchdog" --frames=600 -- '"kind":"watchdog"'
check bad.error_storm 3 smoke "--pack=$EX/bad_error_storm" --frames=600 -- '"id":"smoke.watchdog","ok":false' 'script_errors' '"kind":"script_error","file":"scripts/main.gd","line":16'
check bad.setup_loop 3 smoke "--pack=$EX/bad_setup_loop" --frames=600 -- '"kind":"watchdog"' '_pack_setup did not return'
check bad.bot_never_done 1 bot "--pack=$EX/bad_bot" --frames=300 -- '"id":"bot.completed","ok":false' 'frame_budget'

# ---------------------------------------------------------------- V3
check bad.nondeterminism 1 invariants "--pack=$EX/bad_nondeterminism" --frames=300 -- '"id":"invariants.determinism","ok":false' '"kind":"determinism"'
# idle runs agree, bot runs do not: only the bot replay of `invariants` can see it (WP5)
check bad.bot_nondeterminism 1 invariants "--pack=$EX/bad_bot_nondeterminism" --frames=300 -- '"id":"invariants.determinism","ok":true' '"id":"invariants.bot_deterministic","ok":false' '"kind":"determinism","file":"tests/bot.gd"'
# the located re-run (kernel/host/diverge.gd): a determinism failure names the exact frame and the first part that differs
check diverge.late_frame 1 invariants "--pack=$EX/bad_late_nondeterminism" --frames=900 -- '"id":"invariants.determinism","ok":false,"detail":"[^"]*first difference at frame 437[:"]'
check diverge.late_part 1 invariants "--pack=$EX/bad_late_nondeterminism" --frames=900 -- '"id":"invariants.determinism","ok":false,"detail":"[^"]*first difference at frame [0-9]+: body World.Crate'
check diverge.bot_state_key 1 invariants "--pack=$EX/bad_late_nondeterminism" --frames=300 -- '"id":"invariants.determinism","ok":true' '"id":"invariants.bot_deterministic","ok":false,"detail":"[^"]*first difference at frame 200: [^"]*_pack_state.flips'
check diverge.frame_zero 1 invariants "--pack=$EX/bad_nondeterminism" --frames=300 -- '"id":"invariants.determinism","ok":false,"detail":"[^"]*first difference at frame 0: [^"]*body World.'
check bad.budget 1 invariants "--pack=$EX/bad_budget" --frames=600 -- '"id":"invariants.below_ground","ok":false' '"kind":"budget"'

# ---------------------------------------------------------------- could not run
check norun.missing_pack 2 smoke "--pack=$EX/no_such_pack" -- '"kind":"load"'
check norun.bad_verb 2 dance "--pack=$EX/pack_min" -- '"kind":"engine"'
check norun.bad_option 2 smoke "--pack=$EX/pack_min" --speed=9 -- 'unknown option --speed'

# ---------------------------------------------------------------- kernel examples: laws and primitives, by bot
# each example is linted (no fence hit, no bypass) and played by its own bot; the bot decides ok from measured numbers
for ex in slide bounce shuffle wall walker car; do
  check "ex.$ex.lint" 0 lint "--pack=$EX/ex_$ex" -- '"bypasses":\[\]'
done
check ex.slide.bot 0 bot "--pack=$EX/ex_slide" --frames=3000 -- '"rubber_on_ice_friction_measured":0\.1[0-9]*,"rubber_on_ice_friction_law":0\.1,' '"wood_on_asphalt_friction_law":0\.5,'
check ex.bounce.bot 0 bot "--pack=$EX/ex_bounce" --frames=3000 -- '"rubber_on_ice_restitution_law":0\.3,' '"spawned":[0-9]+'
check ex.shuffle.bot 0 bot "--pack=$EX/ex_shuffle" --frames=3000 -- '"gate_passes":2,'
check ex.wall.bot 0 bot "--pack=$EX/ex_wall" --frames=3000 -- '"pieces":18,'
check ex.walker.bot 0 bot "--pack=$EX/ex_walker" --frames=3000 -- '"walk_speed":2\.[23]'
check ex.car.bot 0 bot "--pack=$EX/ex_car" --frames=5400 -- '"grip_law_ice":0\.1,'
check ex.car.invariants 0 invariants "--pack=$EX/ex_car" --frames=1200 -- '"id":"invariants.determinism","ok":true'
check ex.wall.invariants 0 invariants "--pack=$EX/ex_wall" --frames=900 -- '"id":"invariants.determinism","ok":true'
check ex.walker.invariants 0 invariants "--pack=$EX/ex_walker" --frames=900 -- '"id":"invariants.determinism","ok":true'
check ex.bounce.invariants 0 invariants "--pack=$EX/ex_bounce" --frames=900 -- '"id":"invariants.determinism","ok":true'
check ex.shuffle.invariants 0 invariants "--pack=$EX/ex_shuffle" --frames=600 -- '"id":"invariants.determinism","ok":true'
check ex.slide.invariants 0 invariants "--pack=$EX/ex_slide" --frames=600 -- '"id":"invariants.determinism","ok":true'

# ---------------------------------------------------------------- kit and rigs under the kernel (WP4)
# one pack, one bot run; each line below is one claim the bot measured (kernel/examples/ex_kit)
check kit.lint 0 lint "--pack=$EX/ex_kit" -- '"bypasses":\[\]'
check kit.bot 0 bot "--pack=$EX/ex_kit" --frames=3000 -- '"id":"bot.ok","ok":true'
kit_claim() {  # kit_claim <case name> <ERE the kit.bot report must match> <note>
  if [ -n "$FILTER" ] && [[ "$1" != *"$FILTER"* ]] && [[ "kit.bot" != *"$FILTER"* ]]; then return; fi
  local why=""; grep -Eq -- "$2" "$(report_of kit.bot)" 2>/dev/null || why="the kit.bot report lacks /$2/"
  FILTER="" verdict "$1" "$why" "$3"
}
kit_claim kit.ball_on_ice_slides_by_law '"kit_ice_ok":true.*"ice_friction_measured":0\.1[0-9]*,"ice_friction_law":0\.1,' "a TLKit ball on a TLKit ice patch: friction $(number kit.bot ice_friction_measured), law 0.1"
kit_claim kit.wall_and_crate_break '"kit_fracture_ok":true.*"wall_pieces":16,' "barrier_wall into $(number kit.bot wall_pieces) pieces, crate into $(number kit.bot crate_pieces), settled and baked"
kit_claim rig.biped_walks_and_skates '"rig_biped_ok":true.*"walk_speed":2\.[23]' "TLRigs biped: walk $(number kit.bot walk_speed) m/s, leg swing $(number kit.bot leg_swing), skate $(number kit.bot skate_speed) m/s"
kit_claim rig.vehicle_drives '"rig_vehicle_ok":true' "TLRigs vehicle: top $(number kit.bot car_top_speed) m/s, wheel yaw $(number kit.bot steer_wheel_yaw) rad when steering right"
kit_claim standin.fallback_still_works '"standin_fallback_ok":true' "stand-in rigs given by hand: walk $(number kit.bot standin_walk_speed) m/s, car $(number kit.bot standin_car_top_speed) m/s"
check kit.invariants 0 invariants "--pack=$EX/ex_kit" --frames=1200 -- '"id":"invariants.determinism","ok":true' '"id":"invariants.below_ground","ok":true'

if [ -z "$FILTER" ] || [[ "ex.numbers" == *"$FILTER"* ]]; then
  echo "     ex.kit: $(grep -o '"summary":"[^"]*"' "$(report_of kit.bot)" 2>/dev/null | head -1 | cut -d'"' -f4)"
  for ex in slide bounce shuffle wall walker car; do
    echo "     ex.$ex: $(grep -o '"summary":"[^"]*"' "$(report_of ex.$ex.bot)" 2>/dev/null | head -1 | cut -d'"' -f4)"
  done
fi

# ---------------------------------------------------------------- N2: the one list of verbs, and the world host
# kernel/runner/verbs.json (tl.verbs/1) must name exactly the verbs and options of host.gd's OPTIONS table, and its
# "modes" exactly those of MODE_OPTIONS. Both sides are read as text here: no engine run.
sort_opts() {  # "verb:b,a" lines -> options sorted, lines sorted
  while IFS=: read -r v o; do echo "$v:$(echo "$o" | tr ',' '\n' | sort | tr '\n' ',' | sed 's/,$//')"; done | sort
}
table_of() {  # table_of <const name>: "verb:opt,opt,..." lines from the table in host.gd
  sed -n "/^const $1: Dictionary = {/,/^}/p" "$HERE/../kernel/host/host.gd" | sed -E 's/#.*$//' \
    | grep -o '"[a-z-]*": \[[^]]*\]' | sed -E 's/"([a-z-]*)": \[(.*)\]/\1:\2/; s/[" ]//g' | sort_opts
}
json_of() {   # json_of <verbs|modes>: the same lines from verbs.json (verbs at four spaces, options at eight)
  sed -n "/^  \"$1\": {/,/^  }/p" "$HERE/../kernel/runner/verbs.json" | tr -d '\r' \
    | grep -E '^    "[a-z-]+": \{|^        "[a-z-]+": \{' | sed -E 's/^        "([a-z-]+)".*/O \1/; s/^    "([a-z-]+)".*/V \1/' \
    | { v=""; o=""; while read -r k n; do if [ "$k" = V ]; then [ -n "$v" ] && echo "$v:$o"; v="$n"; o=""; else o="${o:+$o,}$n"; fi; done; [ -n "$v" ] && echo "$v:$o"; } | sort_opts
}
if [ -z "$FILTER" ] || [[ "verbs.json_matches_host" == *"$FILTER"* ]]; then
  why=""
  a="$(table_of OPTIONS)"; b="$(json_of verbs)"
  [ -z "$a" ] && why="could not read OPTIONS from host.gd"
  [ "$a" != "$b" ] && why="${why:+$why; }verbs differ: host.gd [$(echo $a)] verbs.json [$(echo $b)]"
  c="$(table_of MODE_OPTIONS)"; d="$(json_of modes)"
  [ -z "$c" ] && why="${why:+$why; }could not read MODE_OPTIONS from host.gd"
  [ "$c" != "$d" ] && why="${why:+$why; }modes differ: host.gd [$(echo $c)] verbs.json [$(echo $d)]"
  grep -q '"schema": "tl.verbs/1"' "$HERE/../kernel/runner/verbs.json" || why="${why:+$why; }verbs.json is not tl.verbs/1"
  verdict verbs.json_matches_host "$why" "$(echo "$a" | wc -l | tr -d ' ') verbs and $(echo "$c" | wc -l | tr -d ' ') world modes, the same options on both sides"
fi
# several packs in one process: every pack hashes together as it does alone (tools/world.sh same)
if [ -z "$FILTER" ] || [[ "world.same" == *"$FILTER"* ]]; then
  out="$(bash "$HERE/world.sh" same --packs=pack_min,ex_bounce,ex_wall,ex_wall --frames=600 2>&1)"
  why=""; echo "$out" | grep -q '^PASS world.same' || why="$(echo "$out" | grep -E 'DIFFERENT|NO HASH|FAIL|not every' | head -3 | tr '\n' ' ')"
  verdict world.same "$why" "pack_min, ex_bounce and two ex_wall in one process: 4 hashes equal to the solo runs, three times"
fi
# a pack that gets one world tick in 8, and one paused for 100 ticks, end in the state of the uninterrupted run
if [ -z "$FILTER" ] || [[ "world.sliced_and_paused" == *"$FILTER"* ]]; then
  hx() { grep '"kind":"pack"' | sed -E 's/.*"state_hash":"([0-9a-f]{16}).*/\1/' | tr '\n' ' '; }
  h0="$(bash "$HERE/world.sh" run --packs=ex_wall,ex_bounce --mode=bot --frames=3000 | hx)"
  o1="$(bash "$HERE/world.sh" run --packs=ex_wall,ex_bounce --mode=bot --frames=3000 --every=8,3 '--pause=1:100:100')"
  h1="$(echo "$o1" | hx)"
  why=""; [ -z "$h0" ] && why="no hashes"
  [ "$h0" != "$h1" ] && why="continuous [$h0] sliced and paused [$h1]"
  [ "$(echo "$h1" | wc -w)" -ne 2 ] && why="${why:+$why; }expected two hashes, got [$h1]"
  echo "$o1" | grep '"kind":"world"' | grep -q '"gate_leaks":0,"wrong_pack_calls":0' || why="${why:+$why; }a pack script ran on a tick its pack did not get"
  verdict world.sliced_and_paused "$why" "ex_wall on 1 world tick in 8, ex_bounce on 1 in 3 with a 100-tick pause: $h1"
fi

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

# ---------------------------------------------------------------- P7: the simulation contract
# (kernel API version, the input record tl.input/1, replay, the pointer through ctx.input, keys and the panel, the fence)
SEEDS_DIR="$HERE/../seeds"
OUTW="$OUT"; command -v cygpath >/dev/null 2>&1 && OUTW="$(cygpath -m "$OUT")"
p7_on() { [ -z "$FILTER" ] || [[ "$1" == *"$FILTER"* ]] || [[ "p7" == "$FILTER" ]]; }
# p7_pack <name> [sed expression for pack.json]: a copy of pack_min under $OUT
p7_pack() { rm -rf "$OUT/$1"; cp -r "$EX/pack_min" "$OUT/$1"; [ -n "$2" ] && sed -i -E 's/"kernelApi": "[0-9.]+"/"kernelApi": "0.1"/' "$OUT/$1/pack.json" && sed -i "$2" "$OUT/$1/pack.json"; return 0; }
# p7_play <name> <pack dir> <frames> <devices json text> [record file]: a scripted interactive session without a window
p7_play() {
  echo "$4" > "$OUT/$1.devices.json"; rm -f "$OUT/$1.result.json"
  bash "$TL" play "--pack=$2" --headless "--frames=$3" "--devices=$OUTW/$1.devices.json" "--result=$OUTW/$1.result.json" ${5:+"--record=$5"} >/dev/null 2>&1
}
p7_res() { grep -o "\"$2\":\"\\?[^,\"}]*" "$OUT/$1.result.json" 2>/dev/null | head -1 | sed -E 's/^"[a-z_]+":"?//'; }

# API version: a pack runs when its major equals the kernel's and its minor is not greater; "0.1" is the old name of 1.0.
# P14: the kernel's version is read from the manifest code (kernel/runner/manifest.gd KERNEL_API), not held as text here.
KAPI="$(grep -oE 'KERNEL_API: String = "[0-9]+\.[0-9]+"' "$HERE/../kernel/runner/manifest.gd" | grep -oE '[0-9]+\.[0-9]+')"
KMAJ="${KAPI%%.*}"; KMIN="${KAPI#*.}"; KNEXT="$KMAJ.$((KMIN + 1))"
if p7_on p7.api; then
  p7_pack p7_api01 "s/x/x/"; p7_pack p7_api10 's#"kernelApi": "0.1"#"kernelApi": "1.0"#'; p7_pack p7_api20 's#"kernelApi": "0.1"#"kernelApi": "2.0"#'; p7_pack p7_apinext "s#\"kernelApi\": \"0.1\"#\"kernelApi\": \"$KNEXT\"#"
  check p7.api_1_0_lint 0 lint "--pack=$OUT/p7_api10" -- "\"kernelApi\":\"$KAPI\"" '"id":"lint.schema","ok":true'
  check p7.api_1_0_runs 0 smoke "--pack=$OUT/p7_api10" --frames=120 -- '"id":"smoke.loads","ok":true'
  check p7.api_0_1_is_1_0 0 smoke "--pack=$OUT/p7_api01" --frames=120 -- "\"kernelApi\":\"$KAPI\"" '"id":"smoke.loads","ok":true'
  check p7.api_2_0_refused 1 lint "--pack=$OUT/p7_api20" -- "kernelApi '2.0' cannot run on this kernel, which offers API $KAPI: the pack was built for major version 2 and this kernel is major version $KMAJ"
  check p7.api_2_0_not_run 2 smoke "--pack=$OUT/p7_api20" --frames=120 -- 'the manifest is not valid'
  check p7.api_next_refused 1 lint "--pack=$OUT/p7_apinext" -- "kernelApi '$KNEXT' cannot run on this kernel, which offers API $KAPI: the pack needs minor version $((KMIN + 1)) and this kernel has $KMIN"
fi

# a bot's run saved as a record replays to the bot's hash, and the replay's own record is the same file
if p7_on p7.record; then
  REC="$OUTW/p7_paddle.input.json"; REC2="$OUTW/p7_paddle.again.json"; rm -f "$REC" "$REC2"
  check p7.record_bot 0 bot "--pack=$SEEDS_DIR/seed_paddle" "--record=$REC" -- '"id":"record.written","ok":true' '"id":"bot.ok","ok":true'
  check p7.record_replay 0 replay "--pack=$SEEDS_DIR/seed_paddle" "--input=$REC" "--record=$REC2" -- '"verb":"replay","level":"V2"' '"id":"replay.complete","ok":true' '"id":"record.written","ok":true'
  why=""; hb="$(field p7.record_bot state_hash)"; hr="$(field p7.record_replay state_hash)"
  [ -n "$hb" ] && [ "$hb" = "$hr" ] || why="the bot's hash ($hb) is not the replay's ($hr)"
  cmp -s "$REC" "$REC2" || why="${why:+$why; }the replay's own record differs from the record it was fed"
  grep -q '^{"schema":"tl.input/1","pack":"seed.paddle","seed":1,"mode":"bot","max_frames":36000,"length":[0-9]*,"end":"tick","frames":\[' "$REC" || why="${why:+$why; }the record's head is not tl.input/1"
  verdict p7.record_same_hash "$why" "seed_paddle: bot ${hb:0:16} = replay ${hr:0:16}; $(grep -c '^\[' "$REC") frames with input of $(number p7.record_replay frames)"
  check p7.record_wrong_pack 2 replay "--pack=$EX/pack_min" "--input=$REC" -- "the input record is of pack 'seed.paddle', this pack is 'example.pack_min'"
  echo '{"schema":"tl.input/1","pack":"example.pack_min","seed":1,"mode":"bot","max_frames":600,"length":10,"end":"step","frames":[],"note":"x"}' > "$OUT/p7_bad.input.json"
  check p7.record_unknown_key 2 replay "--pack=$EX/pack_min" "--input=$OUTW/p7_bad.input.json" -- "unknown key 'note'"
  check p7.record_needs_input 2 replay "--pack=$EX/pack_min" -- '--input=<file> is required'
fi

# the mouse is input like any other: a session with a right-button drag and the wheel on the wall seed (whose walker
# moves relative to the orbit camera) is recorded, replays to its own hash, and differs from the same keys without the mouse
if p7_on p7.mouse; then
  drag=""; for f in $(seq 40 69); do drag="$drag[$f,\"drag\",6,1.5],"; done
  keys_a='[20,"key","W",1],'; keys_b='[120,"key","Space",1],[124,"key","Space",0],[200,"key","D",1],[260,"key","D",0],[300,"key","W",0]'
  MREC="$OUTW/p7_mouse.input.json"; rm -f "$MREC"
  p7_play p7_mouse "$SEEDS_DIR/seed_wall" 600 "[$keys_a$drag[90,\"wheel\",1,0],[91,\"wheel\",1,0],$keys_b]" "$MREC"
  p7_play p7_nomouse "$SEEDS_DIR/seed_wall" 600 "[$keys_a$keys_b]"
  check p7.mouse_replay 0 replay "--pack=$SEEDS_DIR/seed_wall" "--input=$MREC" -- '"id":"replay.complete","ok":true'
  why=""; hm="$(p7_res p7_mouse state_hash)"; hn="$(p7_res p7_nomouse state_hash)"; hr="$(field p7.mouse_replay state_hash)"
  [ -n "$hm" ] && [ "$hm" = "$hr" ] || why="the session's hash ($hm) is not its replay's ($hr)"
  [ -n "$hn" ] && [ "$hm" != "$hn" ] || why="${why:+$why; }the mouse changed nothing ($hm with, $hn without)"
  [ "$(grep -c '"tl.look_x",6\]' "$MREC")" = 30 ] && grep -q '\[90,"tl.zoom",1\]' "$MREC" || why="${why:+$why; }the record lacks the 30 drag frames or the wheel"
  verdict p7.mouse_same_hash "$why" "seed_wall, 600 frames: session ${hm:0:16} = replay ${hr:0:16}; without the mouse ${hn:0:16}"
fi

# engine/ui/PATCHES.md entry 1: a text field that has focus takes the keyboard (Space is down from frame 10 to 79, the
# field has focus from 30 to 59); entry 2: Esc does not end the game while the designer panel is open
if p7_on p7.keys; then
  KREC="$OUTW/p7_keys.input.json"; rm -f "$KREC"
  p7_play p7_keys "$EX/pack_min" 120 '[[10,"key","Space",1],[30,"field",1],[60,"field",0],[80,"key","Space",0]]' "$KREC"
  got="$(grep -o '\[[0-9]*,"nudge",1\]' "$KREC" 2>/dev/null | grep -o '^\[[0-9]*' | tr -d '[' | tr '\n' ' ')"
  want="$( (seq 10 29; seq 60 79) | tr '\n' ' ')"
  why=""; [ "$got" = "$want" ] || why="the game saw the key in frames [$got], expected 10..29 and 60..79"
  verdict p7.keys_field_takes_keyboard "$why" "pack_min: Space held 70 frames, 30 of them typed into a field: the game got 40"
  p7_play p7_esc "$EX/pack_min" 200 '[[10,"panel",1],[20,"key","Escape",1],[25,"key","Escape",0],[40,"panel",0],[50,"key","Escape",1]]'
  ran="$(p7_res p7_esc frames_run)"
  why=""; [ "$ran" = 51 ] || why="the run ended after ${ran:-no} frames, expected 51 (Esc at 20 with the panel open is not for the game; Esc at 50 ends it)"
  verdict p7.keys_esc_panel_open "$why" "pack_min: Esc with the panel open at frame 20 went on, Esc at frame 50 ended the run"
  # a session that ends because the window is closed still writes its record
  CREC="$OUTW/p7_close.input.json"; rm -f "$CREC"
  p7_play p7_close "$EX/pack_min" 200 '[[10,"key","Space",1],[30,"close",0,0]]' "$CREC"
  why=""; grep -q '"length":30,"end":"step","frames":\[' "$CREC" 2>/dev/null || why="no record of 30 frames after the window was closed at frame 30 ($(head -c 120 "$CREC" 2>/dev/null))"
  [ "$(grep -o '"nudge",1\]' "$CREC" 2>/dev/null | wc -l | tr -d ' ')" = 20 ] || why="${why:+$why; }the record does not hold the 20 frames of the key"
  verdict p7.keys_window_closed_keeps_record "$why" "pack_min: closed at frame 30, the record has 30 frames and the key's 20"
fi

# the fence follows the seam: device reads past ctx.input, clocks that are not the tick count, another pack's nodes
if p7_on p7.fence; then
  p7_pack p7_fence
  printf '%s\n' 'extends Node' 'var t = Timer.new()' 'func _process(_d: float) -> void:' '	pass' 'func _unhandled_key_input(_e) -> void:' '	pass' \
    'func f(ctx, n: Node3D) -> void:' '	var a = InputEventKey.new()' '	set_process_input(true)' '	var m = n.get_global_mouse_position()' '	var b = Button.new()' \
    '	ctx.input.accept_devices = true' '	var dt = get_process_delta_time()' '	var tw = create_tween()' '	var w = n.get_world_3d()' '	var h = ctx.holder' \
    '	ctx.input._feed([])' '	var c = TLContext.current' '	var g = n.get_nodes_in_group("x")' '	var ok = ball.holder()' > "$OUT/p7_fence/scripts/seam.gd"
  check p7.fence_seam 1 lint "--pack=$OUT/p7_fence" -- '"id":"lint.fence","ok":false' \
    '"file":"scripts/seam.gd","line":2,"message":".Timer. is outside the fence' '"line":3,"message":"._process. is outside the fence' '"line":5,"message":"._gui_input handler. is outside' \
    '"line":8,"message":".InputEvent\*. is outside' '"line":9,"message":".set_process_input. is outside' '"line":10,"message":".mouse position. is outside' '"line":11,"message":".a control that takes clicks or keys. is outside' \
    '"line":12,"message":".accept_devices. is outside' '"line":13,"message":".get_process_delta_time. is outside' '"line":14,"message":".Tween/AnimationPlayer. is outside' '"line":15,"message":".get_world_3d\(\). is outside' \
    '"line":16,"message":"..holder. is outside' '"line":17,"message":".a private member of the kernel. is outside' '"line":18,"message":".TLContext.current. is outside' '"line":19,"message":".get_nodes_in_group. is outside'
  if p7_on p7.fence_holder_call; then
    why=""; grep -q '"line":20,' "$(report_of p7.fence_seam)" && why="ball.holder() (a TLBall method) was taken for ctx.holder"
    verdict p7.fence_holder_call "$why" "a call of TLBall.holder() is not the kernel's holder node"
  fi
  # a pack script's own event handler is switched off by the kernel: it sees no device event (lint counts it as a bypass)
  p7_pack p7_handler
  # P11: the handler is a fence error now and `play` refuses the pack, so the net behind the fence is proven in a
  # smoke run (no lint): the pack itself sends a device event at its tick 10 and says at 20 whether its handler is on
  printf '%s\n' '' 'var _p11_n: int = 0' 'func _unhandled_input(_event) -> void:' '	push_error("a pack handler saw a device event")' \
    'func _physics_process(_d: float) -> void:' '	_p11_n += 1' '	if _p11_n == 10:' '		var ev = InputEventMouseMotion.new()' '		ev.relative = Vector2(5, 5)' \
    '		Input.parse_input_event(ev)' '	if _p11_n == 20 and is_processing_unhandled_input():' '		push_error("the handler is still switched on")' >> "$OUT/p7_handler/scripts/main.gd"
  check p7.fence_handler_switched_off 0 smoke "--pack=$OUT/p7_handler" --frames=60 -- '"id":"smoke.no_script_errors","ok":true'
fi

# ---------------------------------------------------------------- P5: loading is not simulation
# One plot's pack is replaced by a freshly loaded copy of the same directory inside a running world, after a value in
# its data/ changed (the walk's `edits` copies a file at a world tick: a scripted "the designer saved a tuned value";
# its `reload` event follows). The reloaded game is the CHANGED pack alone for its own ticks, it is not the unchanged
# one, and the two other games hash as in a run that nobody disturbed.
if [ -z "$FILTER" ] || [[ "world.reload" == *"$FILTER"* ]]; then
  WR="$OUT/world_reload"; rm -rf "$WR"; mkdir -p "$WR"
  command -v cygpath >/dev/null 2>&1 && WR="$(cygpath -m "$WR")"
  cp -r "$EX/ex_slide" "$WR/slide"
  sed 's/"start_speed": *[0-9.]*/"start_speed": 4.5/' "$EX/ex_slide/data/slide.json" > "$WR/tuned.json"
  walk_of() {   # walk_of <file> <events and edits, or nothing>
    printf '{"schema":"tl.walk/1","name":"reload","ticks":600,"mode":"smoke","plots":[{"id":"a","pack":"%s","origin":[0,0,0],"seed":1},{"id":"b","pack":"pack_min","origin":[60,0,0],"seed":1},{"id":"c","pack":"ex_wall","origin":[-60,0,0],"seed":1}],"player":[[0,[0,0,0]]]%s}\n' "$WR/slide" "$2" > "$1"
  }
  walk_of "$WR/quiet.json" ""
  walk_of "$WR/reload.json" ",\"events\":[{\"t\":300,\"e\":\"reload\",\"plot\":\"a\"}],\"edits\":[[299,\"$WR/slide/data/slide.json\",\"$WR/tuned.json\"]]"
  hp() { grep '"kind":"pack"' | grep "\"plot\":\"$1\"" | sed -E 's/.*"frames":([0-9]+).*"state_hash":"([0-9a-f]{16}).*/\1 \2/'; }
  q="$(TL_JSON=1 bash "$HERE/world.sh" walk "$WR/quiet.json" 2>&1)"
  r="$(TL_JSON=1 bash "$HERE/world.sh" walk "$WR/reload.json" "--log=$WR/log.json" 2>&1)"
  rp="$(TL_JSON=1 bash "$HERE/world.sh" replay "$WR/log.json" 2>&1)"
  af="$(echo "$r" | hp a | cut -d' ' -f1)"; ah="$(echo "$r" | hp a | cut -d' ' -f2)"
  hx() { grep '"kind":"pack"' | sed -E 's/.*"state_hash":"([0-9a-f]{16}).*/\1/' | tr '\n' ' '; }
  tuned="$(bash "$HERE/world.sh" run "--packs=$WR/slide" --frames="${af:-0}" | hx)"
  plain="$(bash "$HERE/world.sh" run "--packs=$EX/ex_slide" --frames="${af:-0}" | hx)"
  why=""
  echo "$r" | grep -q '"e":"reload","plot":"a"' || why="no reload event"
  echo "$r" | grep -q '"t":300,"e":"built","plot":"a"' || why="${why:+$why; }the reloaded pack did not arrive at tick 300"
  grep -q '4.5' "$WR/slide/data/slide.json" || why="${why:+$why; }the data file was not changed at tick 299"
  [ -n "$ah" ] && [ "$ah " = "$tuned" ] || why="${why:+$why; }the reloaded game [$af ticks $ah] is not the changed pack alone [$tuned]"
  [ "$tuned" != "$plain" ] || why="${why:+$why; }the changed value has no effect on the hash: the case proves nothing"
  [ -n "$(echo "$q" | hp b)" ] && [ "$(echo "$q" | hp b)" = "$(echo "$r" | hp b)" ] && [ "$(echo "$q" | hp c)" = "$(echo "$r" | hp c)" ] || why="${why:+$why; }the other games differ from the undisturbed run: b [$(echo "$q" | hp b)] [$(echo "$r" | hp b)], c [$(echo "$q" | hp c)] [$(echo "$r" | hp c)]"
  [ "$(echo "$r" | hp a)" = "$(echo "$rp" | hp a)" ] && [ "$(echo "$r" | hp b)" = "$(echo "$rp" | hp b)" ] || why="${why:+$why; }the log does not replay to the same"
  verdict world.reload "$why" "ex_slide reloaded at tick 300 with start_speed 4.5: $af ticks, $ah = the changed pack alone, not $plain; pack_min and ex_wall as undisturbed ($(echo "$r" | hp b | cut -d' ' -f2) $(echo "$r" | hp c | cut -d' ' -f2)); the log replays"
fi
# S (engine-world-next): the construction site (kernel/world/site.gd). A lot with a `job` shows that job's own log;
# the replay at a fixed rate is the same on two runs; a failed job says so; a lot whose log is missing stays a plain
# lot with a warning; a live site picks up lines appended while the world runs (the walk's `edits` instrument copies
# the longer log in at tick 100); the promoted game arrives on the lot through the build queue and hashes in the
# world as it does alone (and the log replays). Fixtures: kernel/world/site/fixtures/.
if [ -z "$FILTER" ] || [[ "site." == *"$FILTER"* ]] || [[ "$FILTER" == site.* ]]; then
  GS="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
  ES="$(cd "$HERE/.." && pwd)"; command -v cygpath >/dev/null 2>&1 && ES="$(cygpath -m "$ES")"
  SD="$OUT/site"; rm -rf "$SD"; mkdir -p "$SD"; command -v cygpath >/dev/null 2>&1 && SD="$(cygpath -m "$SD")"
  site_run() {   # site_run <walk file> [options]: the [site] report line and the exit code line of a headless world
    MSYS_NO_PATHCONV=1 "$GS" --headless --fixed-fps 60 --path "$ES" res://kernel/host/host.tscn -- world "--walk=$1" "${@:2}" 2>&1 | tr -d '\015' | grep -E '^\[site\]|^\[tl\] world done|SCRIPT ERROR'
    echo "exit ${PIPESTATUS[0]}"
  }
  lot_of() { grep '^\[site\] {' | grep -o "{\"lot\":$1,[^]]*][^}]*}[^}]*}" | sed -E 's/"read_ms":[0-9.]+//'; }
  FX="$ES/kernel/world/site/fixtures"
  r1="$(site_run "$FX/site_arrive.json" --ticks=300)"
  r2="$(site_run "$FX/site_arrive.json" --ticks=300)"
  if [ -z "$FILTER" ] || [[ "site.replay_same" == *"$FILTER"* ]]; then
    a="$(echo "$r1" | lot_of 0)"; b="$(echo "$r2" | lot_of 0)"; why=""
    [ -n "$a" ] || why="no [site] report for lot 0"
    [ "$a" = "$b" ] || why="${why:+$why; }two runs differ: [$a] [$b]"
    echo "$a" | grep -q '"events":15,' || why="${why:+$why; }not 15 events at tick 300 with one event per 20 ticks: $a"
    echo "$a" | grep -q '"stage":"building"' || why="${why:+$why; }not the building stage"
    echo "$r1" | grep -q '^exit 0' || why="${why:+$why; }the world did not end with exit 0"
    verdict site.replay_same "$why" "$(echo "$a" | grep -oE '"stage":"[a-z]+","title":"[^"]*","built":[0-9]+,"total":[0-9]+' ) at tick 300, twice"
  fi
  if [ -z "$FILTER" ] || [[ "site.failed" == *"$FILTER"* ]]; then
    a="$(echo "$r1" | lot_of 1)"; why=""
    echo "$a" | grep -q '"stage":"failed"' || why="the failed job is not shown failed: $a"
    echo "$a" | grep -q '"tower_core:failed"' || why="${why:+$why; }its failed package is not shown failed"
    echo "$a" | grep -q '"tower_look:blocked"' || why="${why:+$why; }its blocked package is not shown blocked"
    verdict site.failed "$why" "$(echo "$a" | grep -oE '"stage":"[a-z]+"|"packages":\[[^]]*\]' | tr '\n' ' ')"
  fi
  if [ -z "$FILTER" ] || [[ "site.missing_log" == *"$FILTER"* ]]; then
    printf '{"schema":"tl.walk/1","name":"site_missing","visitor":true,"ticks":120,"mode":"bot","plots":[{"id":"a","pack":"pack_min","origin":[0,0,0],"seed":1}],"landscape":{"lots":[{"at":[60,0],"radius":16,"job":"%s/no_such_job"}]},"player":[[0,[0,0,30]]]}\n' "$SD" > "$SD/missing.json"
    m="$(site_run "$SD/missing.json")"; why=""
    echo "$m" | grep -q '^\[site\] warning: lot 0: no job log' || why="no warning for the missing log"
    echo "$m" | grep -q '^exit 0' || why="${why:+$why; }the world did not end with exit 0: $(echo "$m" | tail -2 | tr '\n' ' ')"
    echo "$m" | grep -q '"lot":0' && why="${why:+$why; }a site was made for a lot without a log"
    verdict site.missing_log "$why" "$(echo "$m" | grep -m1 '^\[site\] warning' | cut -c1-90)...; the lot stays plain, the world runs"
  fi
  if [ -z "$FILTER" ] || [[ "site.live" == *"$FILTER"* ]]; then
    cp -r "$FX/arrive" "$SD/live"
    cp "$SD/live/job.jsonl" "$SD/live_full.jsonl"
    head -n 6 "$FX/arrive/job.jsonl" > "$SD/live/job.jsonl"
    printf '{"schema":"tl.walk/1","name":"site_live","visitor":true,"ticks":400,"mode":"bot","plots":[{"id":"a","pack":"pack_min","origin":[-60,0,0],"seed":1}],"landscape":{"lots":[{"at":[40,0],"radius":22,"h":0,"job":"%s/live"}]},"player":[[0,[40,0,30]]],"edits":[[100,"%s/live/job.jsonl","%s/live_full.jsonl"]]}\n' "$SD" "$SD" "$SD" > "$SD/live.json"
    l="$(site_run "$SD/live.json")"; a="$(echo "$l" | lot_of 0)"; why=""
    echo "$a" | grep -q '"mode":"live"' || why="the site is not live: $a"
    echo "$a" | grep -q '"events":21,' || why="${why:+$why; }the appended lines were not read (21 events wanted): $a"
    echo "$a" | grep -q '"stage_ticks":{"bays":0,"promoted":120}' || why="${why:+$why; }not 6 events at the start and all of them at tick 120 (the first look after the copy at 100): $a"
    echo "$a" | grep -q '"arrived":"example.bounce@0.1.0","arrived_at":120' || why="${why:+$why; }the promoted game did not arrive at tick 120"
    echo "$l" | grep -q '^exit 0' || why="${why:+$why; }the world did not end with exit 0"
    verdict site.live "$why" "6 events, the log grew to 21 at tick 100, read at tick 120, the game arrived; $(echo "$l" | grep -oE '"reads":[0-9]+,"read_ms":[0-9.]+' | head -1)"
  fi
  # S4: a live promotion refits the lot. A job of 6 lines on a lot of radius 30 grows to its promotion at tick 100
  # (read at 120); the game (a copy of ex_bounce, no footprint declared) is built and measured: 25.0 m from the
  # plot's centre, so the lot becomes 25 m (`radius_before` 30, `radius` 25 in the site's report line).
  if [ -z "$FILTER" ] || [[ "site.refit" == *"$FILTER"* ]]; then
    rm -rf "$SD/refit"; cp -r "$FX/arrive" "$SD/refit"; cp "$SD/refit/job.jsonl" "$SD/refit_full.jsonl"
    head -n 6 "$SD/refit_full.jsonl" > "$SD/refit/job.jsonl"
    printf '{"schema":"tl.walk/1","name":"site_refit","visitor":true,"ticks":400,"mode":"bot","plots":[{"id":"a","pack":"pack_min","origin":[-60,0,0],"seed":1}],"landscape":{"lots":[{"at":[40,0],"radius":30,"h":0,"job":"%s/refit"}]},"player":[[0,[40,0,40]]],"edits":[[100,"%s/refit/job.jsonl","%s/refit_full.jsonl"]]}\n' "$SD" "$SD" "$SD" > "$SD/refit.json"
    rm -rf "$SD/refit_cache"
    rf="$(TL_CACHE_DIR="$SD/refit_cache" site_run "$SD/refit.json")"; a="$(echo "$rf" | lot_of 0)"; why=""
    echo "$a" | grep -q '"arrived":"example.bounce@0.1.0","arrived_at":120' || why="the promoted game did not arrive at tick 120: $a"
    echo "$a" | grep -q '"radius":25.0,' || why="${why:+$why; }the lot was not refitted to 25 m: $(echo "$a" | grep -o '"radius":[0-9.]*')"
    echo "$a" | grep -q '"radius_before":30.0' || why="${why:+$why; }no radius before (30 wanted)"
    echo "$a" | grep -q '"measured_m":25.0' || why="${why:+$why; }the game was not measured at 25.0 m: $(echo "$a" | grep -o '"measured_m":[0-9.]*')"
    echo "$a" | grep -q '"fit":"walk radius: nothing promoted yet"' && why="${why:+$why; }the fit still says nothing was promoted"
    echo "$rf" | grep -q '^exit 0' || why="${why:+$why; }the world did not end with exit 0"
    verdict site.refit "$why" "lot 30 m -> $(echo "$a" | grep -o '"radius":[0-9.]*' | cut -d: -f2) m after the live arrival at tick 120; $(echo "$a" | grep -oE '"measured_m":[0-9.]+|"measure_ms":[0-9.]+' | tr '\n' ' ')"
  fi
  # S5: one ring per site. The extent measured in site.refit is kept in the world's cache (site_extent.json, by the
  # promoted pack's content); the next world on the same cache starts the lot (its pad, bank and ring) at 25 m.
  if [ -z "$FILTER" ] || [[ "site.ring" == *"$FILTER"* ]]; then
    why=""
    [ -s "$SD/refit_cache/site_extent.json" ] || why="site.refit left no site_extent.json in its cache (run site.refit first)"
    rg="$(TL_CACHE_DIR="$SD/refit_cache" site_run "$SD/refit.json")"; a="$(echo "$rg" | lot_of 0)"
    echo "$a" | grep -q '"radius":25.0,' || why="${why:+$why; }the second world did not start the lot at 25 m: $(echo "$a" | grep -o '"radius":[0-9.]*')"
    echo "$a" | grep -q '"radius_before":30' && why="${why:+$why; }the lot started at 30 m and was refitted again (it should start at its size)"
    echo "$a" | grep -q 'measured 25.0 m before (cache' || why="${why:+$why; }the fit does not name the cache: $(echo "$a" | grep -o '"fit":"[^"]*"')"
    echo "$rg" | grep -q '^exit 0' || why="${why:+$why; }the world did not end with exit 0"
    verdict site.ring "$why" "second world on the same cache: $(echo "$a" | grep -oE '"radius":[0-9.]+|"fit":"[^"]*"' | tr '\n' ' ')"
  fi
  if [ -z "$FILTER" ] || [[ "site.arrival" == *"$FILTER"* ]]; then
    out="$(bash "$HERE/world.sh" tour "$FX/site_arrive.json" --headless 2>&1)"
    why=""; echo "$out" | grep -q '^PASS world.tour' || why="$(echo "$out" | grep -E 'DIFFERENT|NO HASH|FAIL|rror' | head -3 | tr '\n' ' ')"
    echo "$out" | grep -Eq '^site_0 \| example\.bounce \| [1-9][0-9]* \| .* \| same$' || why="${why:+$why; }the arrived game has no row 'same' in the proof"
    echo "$out" | grep -q 'tick 380   e:built  plot:site_0' || why="${why:+$why; }the game did not arrive at tick 380"
    verdict site.arrival "$why" "the promoted game arrives at tick 380 and hashes as alone and as the replay: $(echo "$out" | grep '^site_0 |' | awk -F' [|] ' '{printf "%s ticks %s", $3, $5}')"
  fi
  # A change that was not made (JOB.md 2026-11-17, foreman/src/unmade.ts): pack/ goes back to the last promotion and
  # `merge` events with `files: []` and `removed` follow just before the job's state. A package whose files all go
  # (cups, added by the change) is not built any more; core keeps the files of the promotion; the game stays.
  if [ -z "$FILTER" ] || [[ "site.unmade" == *"$FILTER"* ]]; then
    printf '{"schema":"tl.walk/1","name":"site_unmade","visitor":true,"ticks":200,"mode":"bot","plots":[{"id":"a","pack":"pack_min","origin":[-60,0,0],"seed":1}],"landscape":{"lots":[{"at":[40,0],"radius":16,"h":0,"job":"%s","replay":{"ticks_per_event":5}}]},"player":[[0,[40,0,30]]]}\n' "$FX/unmade" > "$SD/unmade.json"
    u="$(site_run "$SD/unmade.json")"; a="$(echo "$u" | lot_of 0)"; why=""
    echo "$a" | grep -q '"events":33,"events_in_file":33,' || why="the log was not read to its end (33 events): $a"
    echo "$a" | grep -q '"built":1,"total":2' || why="${why:+$why; }not 1 of 2 built after the restore: $a"
    echo "$a" | grep -q '"core:promoted+merged","cups:failed"\]' || why="${why:+$why; }core is not built or cups is shown built: $a"
    echo "$a" | grep -q '"stage":"promoted"' || why="${why:+$why; }the promoted game does not stay"
    echo "$a" | grep -q '"log_error"' && why="${why:+$why; }the restore's merge events broke the reading"
    echo "$u" | grep -q '^exit 0' || why="${why:+$why; }the world did not end with exit 0"
    verdict site.unmade "$why" "after the restore: $(echo "$a" | grep -oE '"built":[0-9]+,"total":[0-9]+|"packages":\[[^]]*\]' | tr '\n' ' ')"
  fi
  # S2, S3: the exe's village follows a job that is running (`-- check --site-job=<abs dir>`, engine/boot/boot.gd).
  # The job starts with 3 lines and grows by world ticks, not by the clock: `--edits` (a test instrument: the walk's
  # `edits`, kernel/world/jobs.gd) copies a longer prefix of the fixture's log over the job's job.jsonl at ticks 100,
  # 200, 300 and 400. The live site looks at the file every 60 ticks, so it must see bays at 0, building at 240 (the
  # first merge) and the promotion at 420, and the game arrives then: the same ticks on three runs.
  if [ -z "$FILTER" ] || [[ "site.follow_exe" == *"$FILTER"* ]]; then
    fruns=""; why=""
    for run in 1 2 3; do
      rm -rf "$SD/follow"; cp -r "$FX/arrive" "$SD/follow"; cp "$SD/follow/job.jsonl" "$SD/follow_21.jsonl"
      for n in 3 6 11 16; do head -n $n "$SD/follow_21.jsonl" > "$SD/follow_$n.jsonl"; done
      cp "$SD/follow_3.jsonl" "$SD/follow/job.jsonl"
      printf '[[100,"%s/follow/job.jsonl","%s/follow_6.jsonl"],[200,"%s/follow/job.jsonl","%s/follow_11.jsonl"],[300,"%s/follow/job.jsonl","%s/follow_16.jsonl"],[400,"%s/follow/job.jsonl","%s/follow_21.jsonl"]]\n' "$SD" "$SD" "$SD" "$SD" "$SD" "$SD" "$SD" "$SD" > "$SD/follow_edits.json"
      f="$(MSYS_NO_PATHCONV=1 "$GS" --headless --fixed-fps 60 --path "$ES" res://boot/boot.tscn -- check "--out=$SD/fcheck.jsonl" "--site-job=$SD/follow" "--edits=$SD/follow_edits.json" --ticks=600 2>&1 | tr -d '\015' | grep -E '^\[site\]|^\[boot\]|SCRIPT ERROR')"
      a="$(echo "$f" | lot_of 0)"
      echo "$f" | grep -q '^\[boot\] lot 0 follows the job .*follow live' || why="${why:+$why; }run $run: the check did not take --site-job"
      echo "$a" | grep -q '"mode":"live"' || why="${why:+$why; }run $run: the site is not live"
      echo "$a" | grep -q '"events":21,' || why="${why:+$why; }run $run: not all 21 lines read: $a"
      echo "$a" | grep -q '"stage_ticks":{"bays":0,"building":240,"promoted":420}' || why="${why:+$why; }run $run: stage ticks $(echo "$a" | grep -o '"stage_ticks":{[^}]*}'), wanted bays 0, building 240, promoted 420"
      echo "$a" | grep -q '"arrived":"example.bounce@0.1.0","arrived_at":420' || why="${why:+$why; }run $run: the game did not arrive at tick 420"
      grep -q '"plot":"site_0"' "$SD/fcheck.jsonl" 2>/dev/null || why="${why:+$why; }run $run: no line for the site's plot"
      fruns="$fruns$(echo "$a" | grep -o '"stage_ticks":{[^}]*}' | sed 's/"stage_ticks"://'); "
    done
    verdict site.follow_exe "$why" "three runs, the log grown by ticks 100 to 400: $fruns"
  fi
  # S2: the scaffold is solid (a window: the visitor's space exists only with the landscape). Probes at world ticks
  # (walk `visitor_probe` entries with `t`): while the site builds, the gate lets the visitor in and the middle bay
  # stops him (`stopped_by` site 0); after the game arrived (tick 380) the same walk is not stopped by the site.
  if [ -z "$FILTER" ] || [[ "site.solid" == *"$FILTER"* ]]; then
    so="$(bash "$HERE/world.sh" tour "$FX/site_solid.json" "--out-dir=$SD/solid" --pictures-only 2>&1)"
    pr() { echo "$so" | grep "name:$1 " | grep -oE 'ok:[a-z]+|stopped_by:[a-z0-9 ]+  ticks|end:\[[^]]*\]' | sed 's/  ticks//' | tr '\n' ' '; }
    why=""
    echo "$so" | grep -q 'name:site_gate_while_building .*ok:true' || why="the gate did not let him in while the site builds: $(pr site_gate_while_building)"
    echo "$so" | grep -q 'name:site_bay_while_building .*ok:true.*stopped_by:site 0 ' || why="${why:+$why; }the bay did not stop him while the site builds: $(pr site_bay_while_building)"
    echo "$so" | grep -q 'name:site_bay_after_arrival .*ok:true.*stopped_by:none' || why="${why:+$why; }the bay's collider was still there after the arrival: $(pr site_bay_after_arrival)"
    echo "$so" | grep -q 'e:built  plot:site_0' || why="${why:+$why; }the game did not arrive"
    echo "$so" | grep -q '^DONE world.tour' || why="${why:+$why; }the window run failed: $(echo "$so" | grep -E 'FAIL|ERROR' | head -2 | tr '\n' ' ')"
    verdict site.solid "$why" "gate: $(pr site_gate_while_building); bay while building: $(pr site_bay_while_building); after arrival: $(pr site_bay_after_arrival)"
  fi
fi
# The build queue with its worker thread, without a window (walks/queue.json: `load.mode` wait): three seeds are
# prepared on the worker (scripts, layouts built ahead by the kit), one per tick, waited for. Every pack hashes as
# it does alone for the same number of its own ticks, and the log (with its `built` events) replays to the same.
if [ -z "$FILTER" ] || [[ "world.queue" == *"$FILTER"* ]]; then
  out="$(bash "$HERE/world.sh" proof queue 2>&1)"
  why=""; echo "$out" | grep -q '^PASS world.proof' || why="$(echo "$out" | grep -E 'DIFFERENT|NO HASH|FAIL|rror' | head -3 | tr '\n' ' ')"
  [ "$(echo "$out" | grep -c 'e:built')" = 3 ] || why="${why:+$why; }expected 3 built events, got $(echo "$out" | grep -c 'e:built')"
  verdict world.queue "$why" "3 seeds built by the worker, arrived at ticks $(echo "$out" | grep 'e:built' | sed -E 's/^tick ([0-9]+).*plot:([a-z]+).*/\2 \1/' | tr '\n' ' '); walk = alone = replay"
fi

# --- P11 ---
# The world joins the contract: a pack in a world hashes as the runner hashes it alone; a pack script's event handler
# is off in a world too; an _input handler is a fence error; the visitor's walk is an input record that replays.
p11_on() { [ -z "$FILTER" ] || [[ "$1" == *"$FILTER"* ]] || [[ "p11" == "$FILTER" ]]; }
if p11_on p11.world_alone; then
  out="$(bash "$HERE/world.sh" alone --packs=seed_paddle,ex_kit,ex_walker --mode=bot --frames=6000 2>&1)"
  why=""; echo "$out" | grep -q '^PASS world.alone' || why="$(echo "$out" | grep -E 'DIFFERENT|FAIL|exit' | head -3 | tr '\n' ' ')"
  verdict p11.world_alone "$why" "$(echo "$out" | grep ' | bot | ' | cut -d'|' -f1,3,4 | tr -s ' ' | tr '\n' ';')"
fi
if p11_on p11.world_handler_off; then
  rm -rf "$OUT/p11_wh"; cp -r "$EX/pack_min" "$OUT/p11_wh"
  # the handler would push an error for every device event; the pack itself sends one at its tick 10 and reports at 20
  # whether the kernel left the handler on. (A fixture: this pack would fail lint; a world does not lint.)
  printf '%s\n' '' 'var _p11_n: int = 0' 'func _unhandled_input(_event) -> void:' '	push_error("a pack handler saw a device event")' \
    'func _physics_process(_d: float) -> void:' '	_p11_n += 1' '	if _p11_n == 10:' '		var ev = InputEventMouseMotion.new()' '		ev.relative = Vector2(5, 5)' \
    '		Input.parse_input_event(ev)' '	if _p11_n == 20 and is_processing_unhandled_input():' '		push_error("the handler is still switched on")' >> "$OUT/p11_wh/scripts/main.gd"
  # the engine's own lines (TL_RAW): the world's error count does not attribute every error (two packs: 0 although both fired)
  out="$(TL_RAW=1 bash "$HERE/world.sh" run "--packs=$OUTW/p11_wh,seed_wall" --frames=60 2>&1)"
  why=""; echo "$out" | grep -q '"kind":"world"' || why="the world did not finish"
  echo "$out" | grep -q 'world done: packs=2 ticks=60' || why="${why:+$why; }the world did not run 60 ticks"
  echo "$out" | grep -qE 'a pack handler saw a device event|the handler is still switched on' && why="${why:+$why; }the pack's handler was on or ran in a world: $(echo "$out" | grep -oE 'a pack handler saw a device event|the handler is still switched on' | sort -u | tr '\n' ';')"
  verdict p11.world_handler_off "$why" "a pack's _unhandled_input in a world: switched off at ready, got no device event"
fi
if p11_on p11.input_handler_fence; then
  rm -rf "$OUT/p11_bb"; cp -r "$EX/bad_bypass" "$OUT/p11_bb"
  printf '%s\n' '' '' 'func _input(_event: InputEvent) -> void:' '	score += 1' >> "$OUT/p11_bb/scripts/main.gd"
  n="$(wc -l < "$OUT/p11_bb/scripts/main.gd" | tr -d ' ')"; n=$((n - 1))
  check p11.input_handler_fence 1 lint "--pack=$OUT/p11_bb" -- '"id":"lint.fence","ok":false' "\"file\":\"scripts/main.gd\",\"line\":$n,\"message\":\"._input handler. is outside"
fi

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

# --- P12 ---
P12G="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
P12E="$(cd "$HERE/.." && pwd)"
command -v cygpath >/dev/null 2>&1 && { P12E="$(cygpath -m "$P12E")"; P12G="$(cygpath -m "$P12G")"; }
# A pack's preparation on the build queue's worker does not hang on the frame rate: seed_wall prepared while the
# main thread holds 250 ms frames (a throttled window) takes about as long as with free frames (before P12: 20
# frames, 5 s, because TLMesh.merge asked the renderer for its arrays and each ask waited for the next frame).
if [ -z "$FILTER" ] || [[ "world.prepare_capped" == *"$FILTER"* ]]; then
  p12probe() { MSYS_NO_PATHCONV=1 "$P12G" --headless --path "$P12E" -s res://kernel/world/jobs_probe.gd -- "$P12E/seeds/seed_wall" "$1" 2>/dev/null | tr -d '\r' | grep '^PROBE'; }
  free="$(p12probe 0)"; capped="$(p12probe 250)"
  fms="$(echo "$free" | sed -nE 's/.*prepare_ms=([0-9.]+).*/\1/p' | cut -d. -f1)"; cms="$(echo "$capped" | sed -nE 's/.*prepare_ms=([0-9.]+).*/\1/p' | cut -d. -f1)"
  cfr="$(echo "$capped" | sed -nE 's/.*frames=([0-9]+).*/\1/p')"
  why=""
  [ -z "$fms" ] || [ -z "$cms" ] && why="no probe line: '$free' '$capped'"
  [ -z "$why" ] && [ "$cfr" -gt 8 ] && why="the capped preparation took $cfr frames of 250 ms ($cms ms; free frames: $fms ms)"
  verdict world.prepare_capped "$why" "seed_wall prepared in $fms ms with free frames, $cms ms ($cfr frames) with 250 ms frames"
fi
# A game that is needed is there: in queue mode (a window's mode) the plot on stage at tick 0 cannot be prepared
# yet; it jumps the queue and is built at once (counted in `forced`), and on the walk's last tick every game still
# wanted is built. The walk, each pack alone and the replay of the log hash the same.
if [ -z "$FILTER" ] || [[ "world.needed_now" == *"$FILTER"* ]]; then
  WN="$OUT/world_needed"; rm -rf "$WN"; mkdir -p "$WN"
  command -v cygpath >/dev/null 2>&1 && WN="$(cygpath -m "$WN")"
  sed 's/"mode": "wait"/"mode": "queue"/' "$HERE/../kernel/world/walks/queue.json" > "$WN/needed.json"
  out="$(bash "$HERE/world.sh" proof "$WN/needed.json" 2>&1)"
  js="$(TL_JSON=1 bash "$HERE/world.sh" walk "$WN/needed.json" 2>&1 | grep '"kind":"world"')"
  why=""; echo "$out" | grep -q '^PASS world.proof' || why="$(echo "$out" | grep -E 'DIFFERENT|NO HASH|FAIL|rror' | head -3 | tr '\n' ' ')"
  echo "$js" | grep -q '"forced_list":\[\["a",0,' || why="${why:+$why; }plot a (on stage at tick 0) was not built at once: $(echo "$js" | grep -oE '"forced_list":[^}]*' | head -c 200)"
  echo "$js" | grep -q '"never_built":0' || why="${why:+$why; }a wanted game was never built"
  verdict world.needed_now "$why" "forced $(echo "$js" | grep -oE '"forced_list":\[[^}]*\]\]' | head -c 160); walk = alone = replay"
fi
# A changed script is seen by a reload (PATCHES-P5 2b): ex_slide's main.gd is replaced at tick 299 by one that
# starts the blocks 1.5 times faster, and the pack is reloaded at tick 300. Its hash at the end is the changed
# pack alone, not the old one; the other games are as in the undisturbed run.
if [ -z "$FILTER" ] || [[ "world.reload_script" == *"$FILTER"* ]]; then
  WS="$OUT/world_reload_script"; rm -rf "$WS"; mkdir -p "$WS"
  command -v cygpath >/dev/null 2>&1 && WS="$(cygpath -m "$WS")"
  cp -r "$EX/ex_slide" "$WS/slide"
  sed 's/start_speed = float(data\["start_speed"\])/start_speed = float(data["start_speed"]) * 1.5/' "$EX/ex_slide/scripts/main.gd" > "$WS/main_changed.gd"
  wsw() { printf '{"schema":"tl.walk/1","name":"reload_script","ticks":600,"mode":"smoke","plots":[{"id":"a","pack":"%s","origin":[0,0,0],"seed":1},{"id":"b","pack":"pack_min","origin":[60,0,0],"seed":1}],"player":[[0,[0,0,0]]]%s}\n' "$WS/slide" "$2" > "$1"; }
  wsw "$WS/quiet.json" ""
  wsw "$WS/reload.json" ",\"events\":[{\"t\":300,\"e\":\"reload\",\"plot\":\"a\"}],\"edits\":[[299,\"$WS/slide/scripts/main.gd\",\"$WS/main_changed.gd\"]]"
  hp2() { grep '"kind":"pack"' | grep "\"plot\":\"$1\"" | sed -E 's/.*"frames":([0-9]+).*"state_hash":"([0-9a-f]{16}).*/\1 \2/'; }
  q="$(TL_JSON=1 bash "$HERE/world.sh" walk "$WS/quiet.json" 2>&1)"
  r="$(TL_JSON=1 bash "$HERE/world.sh" walk "$WS/reload.json" 2>&1)"
  af="$(echo "$r" | hp2 a | cut -d' ' -f1)"; ah="$(echo "$r" | hp2 a | cut -d' ' -f2)"
  hx2() { grep '"kind":"pack"' | sed -E 's/.*"state_hash":"([0-9a-f]{16}).*/\1/' | tr -d '\n'; }
  changed="$(bash "$HERE/world.sh" run "--packs=$WS/slide" --frames="${af:-0}" | hx2)"
  plain="$(bash "$HERE/world.sh" run "--packs=$EX/ex_slide" --frames="${af:-0}" | hx2)"
  why=""
  grep -q '\* 1.5' "$WS/main_changed.gd" || why="the changed script was not made (sed found nothing)"
  grep -q '\* 1.5' "$WS/slide/scripts/main.gd" || why="${why:+$why; }main.gd was not replaced at tick 299"
  echo "$r" | grep -q '"t":300,"e":"built","plot":"a"' || why="${why:+$why; }the reloaded pack did not arrive at tick 300"
  [ -n "$ah" ] && [ "$ah" = "$changed" ] || why="${why:+$why; }the reloaded game [$af ticks $ah] is not the changed pack alone [$changed] (old script: $plain)"
  [ "$changed" != "$plain" ] || why="${why:+$why; }the changed script has no effect on the hash: the case proves nothing"
  [ -n "$(echo "$q" | hp2 b)" ] && [ "$(echo "$q" | hp2 b)" = "$(echo "$r" | hp2 b)" ] || why="${why:+$why; }pack_min differs from the undisturbed run"
  verdict world.reload_script "$why" "ex_slide's main.gd changed at tick 299, reloaded at 300: $af ticks, $ah = the changed pack alone, not $plain"
fi

# --- P14c ---
# The tools' log filters drop carriage returns with tr. When an editor turned `tr -d '<CR>'` into a quoted line break,
# view.sh deleted every newline of the window's log and `view.sh check` found no hash at all. No quoted line break
# may follow `tr -d` in any tool; the escape `'\r'` is the safe spelling.
if [ -z "$FILTER" ] || [[ "world.tools_tr_filter" == *"$FILTER"* ]]; then
  bad_tr="$(grep -n "tr -d [\"']\$" "$HERE"/*.sh 2>/dev/null | tr '\n' ' ')"
  verdict world.tools_tr_filter "${bad_tr:+a quoted line break after tr -d: $bad_tr}" "no tool deletes newlines from a log by a mangled tr -d"
fi

# --- K1 ---
# The aim (ctx.input.declare_aim): ex_pointer's stick follows the point its bot sets round a square, holds its heading
# with the aim on the figure or taken away; without a bot the aim is invalid on every frame (the pack raises an error
# in a smoke run if it is ever valid); a bot run recorded and replayed gives the bot's hash (the aim is in the record).
if [ -z "$FILTER" ] || [[ "k1.pointer" == *"$FILTER"* ]]; then
  KREC="$OUTW/k1_pointer.input.json"; rm -f "$KREC"
  check k1.pointer_lint 0 lint "--pack=$EX/ex_pointer" -- '"id":"lint.fence","ok":true' '"bypasses":\[\]'
  check k1.pointer_smoke 0 smoke "--pack=$EX/ex_pointer" --seed=1 --frames=600 -- '"id":"smoke.no_script_errors","ok":true,"detail":"0 errors in 600 frames"'
  check k1.pointer_bot 0 bot "--pack=$EX/ex_pointer" "--record=$KREC" -- '"id":"bot.ok","ok":true' '"follow_frames":\[5,10,10,10\]' '"dead_frames":30,'
  check k1.pointer_replay 0 replay "--pack=$EX/ex_pointer" "--input=$KREC" -- '"id":"replay.complete","ok":true'
  check k1.pointer_invariants 0 invariants "--pack=$EX/ex_pointer" --frames=600 -- '"id":"invariants.determinism","ok":true' '"id":"invariants.bot_deterministic","ok":true'
  why=""; hb="$(field k1.pointer_bot state_hash)"; hr="$(field k1.pointer_replay state_hash)"
  [ -n "$hb" ] && [ "$hb" = "$hr" ] || why="the bot's hash ($hb) is not the replay's ($hr)"
  grep -q '"aim@x",' "$KREC" 2>/dev/null || why="${why:+$why; }the record holds no aim"
  verdict k1.pointer_replay_hash "$why" "ex_pointer: bot ${hb:0:16} = replay ${hr:0:16}; $(grep -o '"aim",1' "$KREC" 2>/dev/null | wc -l | tr -d ' ') frames with a valid aim"
fi

# --- K2a ---
# A held ball is never a moving floor: ex_held's skater rides a held ball its carrier shakes at up to 18.6 m/s and
# skates off it; his speed stays within his own skate_speed + 1 (before the cure: 15.0 m/s, the hockey pack saw 47).
if [ -z "$FILTER" ] || [[ "k2.held" == *"$FILTER"* ]]; then
  check k2.held_lint 0 lint "--pack=$EX/ex_held" -- '"id":"lint.fence","ok":true' '"bypasses":\[\]'
  check k2.held_bot 0 bot "--pack=$EX/ex_held" -- '"id":"bot.ok","ok":true' '"ball_peak":18\.[0-9]+'
fi

# --- K2b ---
# TLBiped down / shove / stumble and the body sized with the rig (ex_down): frames down, move ignored, signals, the
# shove, the stumble, two 2.2-scaled figures with body_scale never closer than their bodies; deterministic.
if [ -z "$FILTER" ] || [[ "k2.down" == *"$FILTER"* ]]; then
  check k2.down_lint 0 lint "--pack=$EX/ex_down" -- '"id":"lint.fence","ok":true' '"bypasses":\[\]'
  check k2.down_smoke 0 smoke "--pack=$EX/ex_down" --frames=600 -- '"id":"smoke.no_script_errors","ok":true'
  check k2.down_bot 0 bot "--pack=$EX/ex_down" -- '"id":"bot.ok","ok":true' '"down_frames":113,' '"least_sized":1\.3[0-9]*,'
  check k2.down_invariants 0 invariants "--pack=$EX/ex_down" --frames=600 -- '"id":"invariants.bot_deterministic","ok":true'
fi

# --- K2c ---
# capture --hud=on keeps the pack's HUD in the still (default off: the world alone); a wrong value is refused.
if [ -z "$FILTER" ] || [[ "k2.capture_hud" == *"$FILTER"* ]]; then
  KH_ON="$OUTW/k2_hud_on.png"; KH_OFF="$OUTW/k2_hud_off.png"; rm -f "$KH_ON" "$KH_OFF"
  check k2.capture_hud_on 0 capture "--pack=$EX/ex_down" --cam=near --frame=165 --test=tests/bot_down.gd --hud=on "--out=$KH_ON" --res=1280x720 -- '"id":"capture.written","ok":true'
  check k2.capture_hud_off 0 capture "--pack=$EX/ex_down" --cam=near --frame=165 --test=tests/bot_down.gd "--out=$KH_OFF" --res=1280x720 -- '"id":"capture.written","ok":true'
  check k2.capture_hud_bad 2 capture "--pack=$EX/ex_down" --cam=near --hud=yes "--out=$OUTW/k2_hud_bad.png" -- '--hud is on or off'
  why=""; [ -s "$KH_ON" ] && [ -s "$KH_OFF" ] || why="a still is missing"
  cmp -s "$KH_ON" "$KH_OFF" && why="${why:+$why; }the stills with and without the HUD are the same file"
  verdict k2.capture_hud_differs "$why" "with the HUD $(wc -c < "$KH_ON" 2>/dev/null | tr -d ' ') bytes, without $(wc -c < "$KH_OFF" 2>/dev/null | tr -d ' ') bytes"
fi

# --- K2d ---
# A mouse button as a declared action key: ex_down declares "knock" on K and the left button. In a scripted session
# without a window the left button held frames 90..95 reaches the game as "knock" in exactly those frames (recorded
# like a key), the right button (not declared) does not, and the K key still does.
if [ -z "$FILTER" ] || [[ "k2.button" == *"$FILTER"* ]]; then
  BREC="$OUTW/k2_button.input.json"; rm -f "$BREC"
  p7_play k2_button "$EX/ex_down" 200 '[[90,"button","left",1],[96,"button","left",0],[120,"button","right",1],[126,"button","right",0],[150,"key","K",1],[153,"key","K",0]]' "$BREC"
  got="$(grep -o '\[[0-9]*,"knock",1\]' "$BREC" 2>/dev/null | grep -o '^\[[0-9]*' | tr -d '[' | tr '\n' ' ')"
  want="$( (seq 90 95; seq 150 152) | tr '\n' ' ')"
  why=""; [ "$got" = "$want" ] || why="the game saw knock in frames [$got], expected 90..95 (left button) and 150..152 (K)"
  verdict k2.button_is_a_key "$why" "ex_down: knock from the left button in 6 frames, not from the right button, from K in 3"
fi

# --- K3 ---
# A ball is never a floor, held or loose, whatever the body's size: ex_held_big's still skater (body_scale 2.2, a 0.66 m
# capsule) has a held puck moved under the rim of his body and then shot from under him at 25 m/s; he stays where he
# stood (the kernel of K2, which knew only held balls, let the loose puck carry him 61 m).
if [ -z "$FILTER" ] || [[ "k3.held_big" == *"$FILTER"* ]]; then
  check k3.held_big_lint 0 lint "--pack=$EX/ex_held_big" -- '"id":"lint.fence","ok":true' '"bypasses":\[\]'
  check k3.held_big_bot 0 bot "--pack=$EX/ex_held_big" -- '"id":"bot.ok","ok":true' '"moved":0(\.0[0-9]*)?,' '"puck_peak":2[0-9](\.[0-9])?'
fi

# --- K4 ---
# A person's hand aims: ex_pointer's bot through TLHand "perfect" gives ex_pointer's own bot hash; ex_pointer_hand's bot
# puts the aim on a jumping, sliding target through each profile: perfect hits all 20, and the hits fall from perfect to
# newcomer (seed 1: 20, 20, 11, 4) while the hand's aim reaction and the taps a lapse swallowed are counted.
if [ -z "$FILTER" ] || [[ "k4.hand_aim" == *"$FILTER"* ]]; then
  check k4.hand_aim_square_plain 0 bot "--pack=$EX/ex_pointer" --test=tests/bot_square.gd -- '"id":"bot.ok","ok":true'
  check k4.hand_aim_square_hand 0 bot "--pack=$EX/ex_pointer" --test=tests/bot_square_hand.gd -- '"id":"bot.ok","ok":true'
  why=""; h1="$(field k4.hand_aim_square_plain state_hash)"; h2="$(field k4.hand_aim_square_hand state_hash)"
  [ -n "$h1" ] && [ "$h1" = "$h2" ] || why="the perfect hand changed ex_pointer's bot hash ($h1 / $h2)"
  verdict k4.hand_aim_perfect_same_hash "$why" "ex_pointer: ${h1:0:16} with and without the perfect hand"
  check k4.hand_aim_lint 0 lint "--pack=$EX/ex_pointer_hand" -- '"id":"lint.fence","ok":true' '"bypasses":\[\]'
  for p in perfect sharp regular newcomer; do
    t="bot_aim"; [ "$p" != perfect ] && t="bot_aim_$p"
    check "k4.hand_aim_$p" 0 bot "--pack=$EX/ex_pointer_hand" "--test=tests/$t.gd" -- '"id":"bot.ok","ok":true' "\"profile\":\"$p\""
  done
  why=""; prev=99
  for p in perfect sharp regular newcomer; do
    h="$(grep -o '"hits":[0-9]*' "$(report_of "k4.hand_aim_$p")" 2>/dev/null | head -1 | cut -d: -f2)"
    [ -n "$h" ] && [ "$h" -le "$prev" ] || why="${why:+$why; }hits do not fall from perfect to newcomer ($p: ${h:-none} after $prev)"
    prev="${h:-0}"
  done
  verdict k4.hand_aim_profiles_fall "$why" "hits of 20 on seed 1, perfect to newcomer"
fi

# --- K5 ---
# TLHud plates, aligned lines, a bottom label that grows upwards (ex_hud): the bot reads the texts; two stills with
# the HUD (frame 20: the note has one line; frame 170: four) are written and differ.
if [ -z "$FILTER" ] || [[ "k5.hud" == *"$FILTER"* ]]; then
  check k5.hud_lint 0 lint "--pack=$EX/ex_hud" -- '"id":"lint.fence","ok":true' '"bypasses":\[\]'
  check k5.hud_bot 0 bot "--pack=$EX/ex_hud" -- '"id":"bot.ok","ok":true' '"note_lines":4'
  K5A="$OUTW/k5_hud_f20.png"; K5B="$OUTW/k5_hud_f170.png"; rm -f "$K5A" "$K5B"
  check k5.hud_still_short 0 capture "--pack=$EX/ex_hud" --cam=play --frame=20 --hud=on "--out=$K5A" --res=1280x720 -- '"id":"capture.written","ok":true'
  check k5.hud_still_grown 0 capture "--pack=$EX/ex_hud" --cam=play --frame=170 --hud=on "--out=$K5B" --res=1280x720 -- '"id":"capture.written","ok":true'
  why=""; [ -s "$K5A" ] && [ -s "$K5B" ] || why="a still is missing"
  cmp -s "$K5A" "$K5B" && why="${why:+$why; }the stills of one line and of four lines are the same file"
  verdict k5.hud_stills_differ "$why" "one line $(wc -c < "$K5A" 2>/dev/null | tr -d ' ') bytes, four lines $(wc -c < "$K5B" 2>/dev/null | tr -d ' ') bytes"
fi

# --- K6 ---
# The ball-under-the-feet test asks the pack's own physics space: in a world (a space per pack) ex_held and ex_held_big
# hash as they do alone. Before the cure the query saw an empty space there and a held or shot puck carried the skater.
if [ -z "$FILTER" ] || [[ "k6.world_ball_floor" == *"$FILTER"* ]]; then
  out="$(bash "$HERE/world.sh" alone "--packs=$EX/ex_held_big,$EX/ex_held" --mode=bot --frames=2000 2>&1)"
  why=""; echo "$out" | grep -q '^PASS world.alone' || why="a pack hashes differently in a world: $(echo "$out" | grep -E 'DIFFERENT|FAIL' | head -3 | tr '\n' ' ')"
  [ "$(echo "$out" | grep -c '| same$')" = 2 ] || why="${why:+$why; }not both packs reported same"
  verdict k6.world_ball_floor "$why" "ex_held_big and ex_held: world = alone"
fi

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

# --- walker-feel (lane M, 18 Nov 2026) ---
# The visitor's body with weight (terrain/world_space.gd `drive()`) and the chase camera's `avoid_space`, on ground
# built for each case, headless (kernel/world/walks/walk_case.gd): idle on a bank, jump, ledge, steep bank, pace, run
# slide, the camera along a hill. One verdict per case; a case missing from the output is a FAIL.
if [ -z "$FILTER" ] || [[ "walk.idle_bank walk.jump walk.ledge walk.steep walk.pace walk.slide walk.camera walk.canopy" == *"$FILTER"* ]]; then
  GW="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
  EW="$(cd "$HERE/.." && pwd)"; command -v cygpath >/dev/null 2>&1 && EW="$(cygpath -m "$EW")"
  wout="$(MSYS_NO_PATHCONV=1 "$GW" --headless --path "$EW" --script res://kernel/world/walks/walk_case.gd 2>&1 | tr -d '\015' | grep '^WALKCASE')"
  for wc in walk.idle_bank walk.jump walk.ledge walk.steep walk.pace walk.slide walk.camera walk.canopy; do
    if [ -n "$FILTER" ] && [[ "$wc" != *"$FILTER"* ]]; then continue; fi
    wl="$(echo "$wout" | grep "^WALKCASE $wc ")"
    why=""; [[ "$wl" == "WALKCASE $wc ok "* ]] || why="${wl:-no WALKCASE line for $wc}"
    verdict "$wc" "$why" "${wl#WALKCASE $wc ok }"
  done
fi

# --- walker-feel T (18 Nov): the ground stops blinking ---
# The world's ground is cut open only under a pack whose own ground covers its plot (ex_car's boxes: no hole, so no
# sky pit), and a plot that draws nothing yet keeps its hole shut (kernel/world/walks/ground_case.gd, headless).
if [ -z "$FILTER" ] || [[ "ground.no_sky_pit" == *"$FILTER"* ]]; then
  GG="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
  EG="$(cd "$HERE/.." && pwd)"; command -v cygpath >/dev/null 2>&1 && EG="$(cygpath -m "$EG")"
  out="$(MSYS_NO_PATHCONV=1 "$GG" --headless --path "$EG" --script res://kernel/world/walks/ground_case.gd 2>&1 | tr -d '\015' | grep '^GROUNDCASE')"
  why=""; [[ "$out" == "GROUNDCASE ok"* ]] || why="${out:-no GROUNDCASE line}"
  verdict ground.no_sky_pit "$why" "${out#GROUNDCASE ok }"
fi

# ---------------------------------------------------------------- walker-feel, lane L: the biped's feet and moves (rig.)
# The feet stand where they are put: six sole points; a point on the floor two frames running may not move (engine/rigs/
# review/review.gd, 400 frames, headless). Mean under 0.2 m/s at a jog, a sprint, a sidestep and backward (18 Nov: 0.06 to
# 0.10; the gait before it: 0.9 to 9.2), with a foot on the floor in at least 100 frames (a run that printed nothing fails).
if [ -z "$FILTER" ] || [[ "rig.feet_plant" == *"$FILTER"* ]] || [[ "rig.moves" == *"$FILTER"* ]]; then
  if [ -z "$FILTER" ] || [[ "rig.feet_plant" == *"$FILTER"* ]]; then
    why=""; seen=""
    for c in "4.5:0" "9.0:0" "4.5:90" "4.5:180" "1.4:0"; do
      line="$(RIG_ARGS="--dir=${c#*:}" bash "$HERE/look.sh" slip "${c%%:*}" walk 2>&1 | tr -d '' | grep -a 'contact\|SCRIPT ERROR' | head -1)"
      mean="$(echo "$line" | grep -o 'mean_ms=[0-9.]*' | cut -d= -f2)"; onf="$(echo "$line" | grep -o ' on_floor=[0-9]*' | cut -d= -f2)"
      if [ -z "$mean" ] || [ -z "$onf" ]; then why="${why:+$why; }$c: no contact line (${line:0:80})"
      elif [ "$onf" -lt 100 ]; then why="${why:+$why; }$c: a foot on the floor in only $onf frames"
      elif ! awk -v m="$mean" 'BEGIN { exit !(m < 0.2) }'; then why="${why:+$why; }$c: soles slide $mean m/s (limit 0.2)"; fi
      seen="${seen:+$seen, }${c%%:*} m/s dir ${c#*:} = $mean"
    done
    verdict rig.feet_plant "$why" "sole slide, mean m/s: $seen"
  fi
  if [ -z "$FILTER" ] || [[ "rig.moves" == *"$FILTER"* ]]; then
    why=""
    for mv in jump land slide slope_slide air; do
      grep -q "add_clip(\"$mv\"" "$HERE/../rigs/tl_rig_biped.gd" || why="${why:+$why; }tl_rig_biped.gd adds no clip $mv"
    done
    # a jump at a run: off the floor, the air pose, the landing; no script error, and the feet are planted again after it
    line="$(RIG_ARGS="--jump-at=90 --jump-v=8.5" bash "$HERE/look.sh" slip 4.5 walk 2>&1 | tr -d '' | grep -a 'contact\|SCRIPT ERROR' | head -1)"
    mean="$(echo "$line" | grep -o 'mean_ms=[0-9.]*' | cut -d= -f2)"
    if [ -z "$mean" ]; then why="${why:+$why; }jump run: no contact line (${line:0:80})"
    elif ! awk -v m="$mean" 'BEGIN { exit !(m < 0.6) }'; then why="${why:+$why; }jump run: soles slide $mean m/s (limit 0.6)"; fi
    verdict rig.moves "$why" "clips jump, land, slide, slope_slide, air; a run with a jump: sole slide $mean m/s"
  fi
fi

echo "selftest: $pass passed, $fail failed (reports in $OUT)"
[ $fail -eq 0 ]
