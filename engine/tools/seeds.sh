#!/bin/bash
# Runs the verify verbs on every seed pack: lint, smoke (seed 1 twice and seed 2), invariants, bot.
# One PASS/FAIL line per case; exit code 0 only when every case passed.
#   seeds.sh [name-filter]         for example: seeds.sh paddle
#   seeds.sh sheet                 re-capture both cameras of every seed at two frames with the bot playing and
#                                  rebuild seeds/captures/seeds_sheet.png (windowed, Direct3D 12)
HERE="$(cd "$(dirname "$0")" && pwd)"
TL="$HERE/tl.sh"
SEEDS="$HERE/../seeds"
OUT="${TL_SELFTEST_DIR:-${TMPDIR:-${TEMP:-/tmp}}/tl_seeds_$$}"
mkdir -p "$OUT"
pass=0; fail=0

# pack : bot : captures as cam:frame ...
PACKS=(
  "seed_paddle:tests/bot_win.gd:court:400 court:2400 baseline:520 baseline:2000"
  "seed_drive:tests/bot_laps.gd:chase:110 chase:1560 overview:420 overview:1500"
  "seed_wall:tests/bot_knock.gd:player:200 player:700 yard:330 yard:900"
)

if [ "$1" = "sheet" ]; then
  CAP="$SEEDS/captures"; mkdir -p "$CAP"
  command -v cygpath >/dev/null 2>&1 && CAP="$(cygpath -m "$CAP")"
  files=()
  for row in "${PACKS[@]}"; do
    pack="${row%%:*}"; rest="${row#*:}"; bot="${rest%%:*}"; shots="${rest#*:}"
    for shot in $shots; do
      cam="${shot%%:*}"; frame="${shot##*:}"
      png="$CAP/${pack#seed_}_${cam}_f${frame}.png"
      TL_QUIET=1 bash "$TL" capture "--pack=$SEEDS/$pack" "--cam=$cam" "--frame=$frame" "--test=$bot" "--out=$png" | grep -o '"id":"capture.written","ok":[a-z]*'
      files+=("$png")
    done
  done
  # 4 columns (two frames of camera one, two of camera two) x 3 rows (paddle, drive, wall), each image at quarter size
  inputs=(); for f in "${files[@]}"; do inputs+=(-i "$f"); done
  ffmpeg -y -loglevel error "${inputs[@]}" -filter_complex \
    "[0]scale=640:360[a0];[1]scale=640:360[a1];[2]scale=640:360[a2];[3]scale=640:360[a3];[4]scale=640:360[a4];[5]scale=640:360[a5];[6]scale=640:360[a6];[7]scale=640:360[a7];[8]scale=640:360[a8];[9]scale=640:360[a9];[10]scale=640:360[a10];[11]scale=640:360[a11];[a0][a1][a2][a3]hstack=4[r0];[a4][a5][a6][a7]hstack=4[r1];[a8][a9][a10][a11]hstack=4[r2];[r0][r1][r2]vstack=3,format=rgb24" \
    "$CAP/seeds_sheet.png" && ls -la "$CAP/seeds_sheet.png"
  exit $?
fi

FILTER="$1"
field() { grep -o "\"$2\":\"[^\"]*\"" "$OUT/$1.json" 2>/dev/null | head -1 | cut -d'"' -f4; }

# run <case name> <ERE the report must match> <verb and args...>: exit code 0 and the pattern
run() {
  local name="$1" pat="$2"; shift 2
  if [ -n "$FILTER" ] && [[ "$name" != *"$FILTER"* ]]; then return; fi
  TL_QUIET=1 bash "$TL" "$@" "--report=$OUT/$name.json" >/dev/null; local got=$?
  local why=""
  [ "$got" != "0" ] && why="exit code $got"
  grep -Eq -- "$pat" "$OUT/$name.json" 2>/dev/null || why="${why:+$why; }report lacks /$pat/"
  note="$3"
  if [ -z "$why" ]; then echo "PASS $name  $(grep -o '"summary":"[^"]*"' "$OUT/$name.json" | head -1 | cut -d'"' -f4)"; pass=$((pass+1))
  else echo "FAIL $name: $why  $(grep -o '"errors":\[[^]]*' "$OUT/$name.json" | cut -c1-300)"; fail=$((fail+1)); fi
}

for row in "${PACKS[@]}"; do
  pack="${row%%:*}"; rest="${row#*:}"; bot="${rest%%:*}"
  id="${pack/_/.}"
  run "$id.lint" '"id":"lint.fence","ok":true.*"bypasses":\[\]' lint "--pack=$SEEDS/$pack"
  run "$id.smoke" '"id":"smoke.no_script_errors","ok":true' smoke "--pack=$SEEDS/$pack" --seed=1
  run "$id.smoke_again" '"outcome":"passed"' smoke "--pack=$SEEDS/$pack" --seed=1
  run "$id.smoke_seed2" '"outcome":"passed"' smoke "--pack=$SEEDS/$pack" --seed=2
  if [ -z "$FILTER" ] || [[ "$id.hash" == *"$FILTER"* ]]; then
    h1="$(field "$id.smoke" state_hash)"; h2="$(field "$id.smoke_again" state_hash)"; h3="$(field "$id.smoke_seed2" state_hash)"
    why=""; [ -z "$h1" ] && why="no state_hash"
    [ "$h1" != "$h2" ] && why="same seed gave different hashes ($h1 / $h2)"
    [ "$h1" = "$h3" ] && why="${why:+$why; }seed 2 gave the same hash as seed 1"
    if [ -z "$why" ]; then echo "PASS $id.hash  seed 1: ${h1:0:16} twice; seed 2: ${h3:0:16}"; pass=$((pass+1)); else echo "FAIL $id.hash: $why"; fail=$((fail+1)); fi
  fi
  run "$id.invariants" '"id":"invariants.determinism","ok":true' invariants "--pack=$SEEDS/$pack"
  run "$id.bot" '"id":"bot.ok","ok":true' bot "--pack=$SEEDS/$pack" "--test=$bot"
  run "$id.bot_seed2" '"id":"bot.ok","ok":true' bot "--pack=$SEEDS/$pack" "--test=$bot" --seed=2
done
echo "seeds: $pass passed, $fail failed (reports in $OUT)"
[ $fail -eq 0 ]
