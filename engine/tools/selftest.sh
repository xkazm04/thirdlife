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
check bad.bypass 0 lint "--pack=$EX/bad_bypass" -- '"primitive":"TLRules","file":"scripts/main.gd","line":4' '"file":"scripts/main.gd","line":10,"pattern":"RigidBody3D.new\(\)"' '"line":16,"pattern":"Area3D.new\(\)"' '"line":21,"pattern":"apply_impulse"' '"line":24,"pattern":"_input handler"'
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

echo "selftest: $pass passed, $fail failed (reports in $OUT)"
[ $fail -eq 0 ]
