#!/bin/bash
# Third Life item tool (docs/SHARING.md; what was built: kernel/share/SHARE.md). An item is a folder with a card.
#
#   item.sh card   <dir> [--lint=<report>] [--bot=<report>] [--smoke=<report>] [--invariants=<report>] [--job=<job dir>]
#                        [--kind=game|venue|look|tuning|kit|world] [--title=] [--summary=] [--description=] [--tags=a,b]
#                        [--handle=] [--name=] [--licence=] [--version=] [--human-code=true|false]
#                                      writes <dir>/item.json; a second run keeps the uid and the creation time
#   item.sh pack   <dir> --out=<file.tlitem>      the same folder always gives the same bytes; makes the card if absent
#   item.sh pack   <dir> --library=<dir>          writes <library>/<uid>-<version>.tlitem, never over other bytes
#   item.sh unpack <file.tlitem> --to=<dir>       the archive is hostile input; nothing is written unless all holds
#   item.sh check  <dir or file.tlitem>           validates the card, recomputes hash and tier, reports each mismatch
#   item.sh tier   <dir or file.tlitem>           the computed tier (data or code) and what makes it code
#   item.sh selftest [name-filter]                one PASS/FAIL line per case
#
# Exit code: 0 done, 1 refused (the item is wrong), 2 could not run. Lines of the tool start with "[item]".
# Env: TL_GODOT (Godot console exe), TL_ENGINE_DIR (this engine/ directory), TL_ITEM_SELFTEST_DIR (keep selftest files).
G="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
E="${TL_ENGINE_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
HERE="$(cd "$(dirname "$0")" && pwd)"
if command -v cygpath >/dev/null 2>&1; then
  E="$(cygpath -m "$E")"
  G="$(cygpath -m "$G")"
fi

# /c/path or a relative path -> C:/path (res:// is left alone)
fix_path() {
  local v="$1"
  case "$v" in
    res://*) ;;
    *) if command -v cygpath >/dev/null 2>&1; then
         case "$v" in /*|[A-Za-z]:*) v="$(cygpath -m "$v")";; *) v="$(cygpath -m "$PWD/$v")";; esac
       else
         case "$v" in /*) ;; *) v="$PWD/$v";; esac
       fi;;
  esac
  echo "$v"
}

run_tool() {
  local cmd="$1"; shift
  local args=() first=1
  for a in "$@"; do
    case "$a" in
      --lint=*|--bot=*|--smoke=*|--invariants=*|--job=*|--out=*|--to=*|--library=*)
        args+=("${a%%=*}=$(fix_path "${a#*=}")");;
      --*) args+=("$a");;
      *) if [ $first -eq 1 ] && [ "$cmd" != "forge" ]; then args+=("$(fix_path "$a")"); else args+=("$a"); fi; first=0;;
    esac
  done
  MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL='*' "$G" --headless --path "$E" res://kernel/share/item_tool.tscn -- "$cmd" "${args[@]}" 2>&1 \
    | grep -E '^\[item\]|SCRIPT ERROR|Parse Error|^ERROR|^   at:'
  return "${PIPESTATUS[0]}"
}

case "$1" in
  ""|help|-h|--help)
    sed -n '2,18p' "$0"; exit 2;;
  card|pack|unpack|check|tier|forge|zipreader)
    run_tool "$@"; exit $?;;
  selftest)
    shift;;
  *)
    echo "[item] ERROR unknown command '$1' (card, pack, unpack, check, tier, selftest)"; exit 2;;
esac

# ---------------------------------------------------------------------------------------------------- selftest
# Every case works on copies in a temporary folder; the engine's seeds and examples are only read.
FILTER="$1"
ME="$HERE/item.sh"
TL="$HERE/tl.sh"
OUT="${TL_ITEM_SELFTEST_DIR:-${TMPDIR:-${TEMP:-/tmp}}/tl_item_selftest_$$}"
rm -rf "$OUT"; mkdir -p "$OUT"
pass=0; fail=0
verdict() {
  if [ -n "$FILTER" ] && [[ "$1" != *"$FILTER"* ]]; then return; fi
  if [ -z "$2" ]; then echo "PASS $1${3:+  ($3)}"; pass=$((pass+1)); else echo "FAIL $1: $2"; fail=$((fail+1)); fi
}
# run <name> <expected exit> <ERE the output must match, or ""> <item.sh args...>; leaves the output in $LAST
run() {
  local name="$1" want="$2" pat="$3"; shift 3
  LAST="$(bash "$ME" "$@" 2>&1)"; local got=$?
  local why=""
  [ "$got" != "$want" ] && why="exit code $got, expected $want"
  if [ -n "$pat" ] && ! echo "$LAST" | grep -Eq -- "$pat"; then why="${why:+$why; }output lacks /$pat/"; fi
  echo "$LAST" | grep -Eq 'SCRIPT ERROR|Parse Error' && why="${why:+$why; }the tool itself raised a script error"
  [ -n "$why" ] && why="$why  [$(echo "$LAST" | tail -n 2 | tr '\n' ' ' | cut -c1-240)]"
  verdict "$name" "$why" "$(echo "$LAST" | grep -E 'ERROR|MISMATCH|refused' | head -1 | cut -c8-150)"
}
sha() { sha256sum "$1" 2>/dev/null | cut -d' ' -f1; }
value() { echo "$LAST" | grep -o "$1=[^ ]*" | head -1 | cut -d= -f2; }

SEED="$OUT/seed_paddle"; cp -r "$E/seeds/seed_paddle" "$SEED"

# ---- the card
run card.seed_created 0 'card: created item.json  uid=[0-9A-HJKMNP-TV-Z]{26} kind=game tier=code version=0\.1\.0' card "$SEED"
UID1="$(value uid)"; HASH1="$(echo "$LAST" | grep -o 'content.hash=sha256:[0-9a-f]*' | cut -d= -f2)"
run card.seed_second_run_keeps_uid 0 "card: refreshed item.json  uid=$UID1 " card "$SEED"
w=""; for k in schema uid kind tier title summary description tags version created updated author licence engine capabilities footprint requires provenance verify content preview; do
  grep -q "^  \"$k\": " "$SEED/item.json" || w="$w $k"; done
verdict card.every_key_present "${w:+missing top-level key(s):$w}" "21 top-level keys"
w=""; grep -q '"capabilities": \["ai", "ball", "camera", "input", "kit", "physics", "rules", "ui"\]' "$SEED/item.json" || w="capabilities are not the sorted copy of pack.json: $(grep '"capabilities"' "$SEED/item.json")"
verdict card.capabilities_sorted_from_pack "$w"
w=""; grep -q '"human_code": null' "$SEED/item.json" && grep -q '"sentence": ""' "$SEED/item.json" && grep -q '"lint": null' "$SEED/item.json" || w="unknown values are not empty or null"
verdict card.unknown_stays_empty "$w" "no report and no job given: provenance and verify are empty"
run card.check_folder 0 "check: ok  folder  uid=$UID1 kind=game tier=code" check "$SEED"

# ---- the card from real evidence: a lint report, a bot report, a job's log (the second marble job, read-only)
JOB="$E/../site/marble-run-three-marbles-20261110-2"                       # engine/ in the main tree
[ -d "$JOB" ] || JOB="$E/../../../marble-run-three-marbles-20261110-2"   # a working copy under site/_work/<name>/engine
if [ -d "$JOB/promoted/game.marble_run_three_marbles" ]; then
  MAR="$OUT/marble"; cp -r "$JOB/promoted/game.marble_run_three_marbles" "$MAR"
  LR="$(ls "$JOB"/reports/*pack-lint*.json | grep -v verdict | tail -1)"; BR="$(ls "$JOB"/reports/*-bot-*.json | grep -v verdict | tail -1)"
  run card.from_job 0 'card: created item.json  uid=.* kind=game tier=code' card "$MAR" "--lint=$LR" "--bot=$BR" "--job=$JOB"
  w=""
  grep -q '"sentence": "A marble run: three marbles' "$MAR/item.json" || w="no sentence from the job's log"
  grep -q '"job": "marble-run-three-marbles-20261110-2"' "$MAR/item.json" || w="${w:+$w; }no job name"
  grep -q '"built_by": "foreman"' "$MAR/item.json" || w="${w:+$w; }built_by"
  grep -q '"models": \["claude-sonnet-5-5"\]' "$MAR/item.json" || w="${w:+$w; }models"
  grep -Eq '"lint": true' "$MAR/item.json" && grep -Eq '"bot": true' "$MAR/item.json" && grep -Eq '"smoke": null' "$MAR/item.json" || w="${w:+$w; }verify.verbs"
  grep -Eq '"bot_state_hash": "cc031fae[0-9a-f]{56}"' "$MAR/item.json" || w="${w:+$w; }bot_state_hash"
  grep -Eq '"bypasses": [0-9]+' "$MAR/item.json" && grep -Eq '"script_lines": [0-9]+' "$MAR/item.json" || w="${w:+$w; }bypasses or script_lines"
  verdict card.from_job_fields "$w" "sentence, job, models, lint and bot results, bot hash, bypasses, script lines"
  w=""; grep -Eiq '[A-Za-z]:[\\/]|/users/|@[a-z0-9-]+\.[a-z]' "$MAR/item.json" && w="a path or an address got into the card"
  verdict card.no_path_or_address "$w"
  run card.report_of_another_pack 1 'the report is about game.marble_run_three_marbles' card "$SEED" "--lint=$LR"
else
  verdict card.from_job "the job folder $JOB is not there"
fi

# a job log whose sentence holds a machine path: the sentence stays empty, the card is still made
FJ="$OUT/fake_job"; mkdir -p "$FJ"; cp -r "$E/seeds/seed_paddle" "$OUT/seed_leak"
printf '%s\n' '{"v":1,"seq":1,"type":"job_created","job":"paddle-test-1","sentence":"Make it like the one in C:/games/mine/paddle"}' '{"v":1,"seq":2,"type":"builder_run","model":"model-b"}' '{"v":1,"seq":3,"type":"builder_run","model":"model-a"}' > "$FJ/job.jsonl"
run card.job_sentence_with_a_path 0 'note: provenance.sentence left empty: the job.s log sentence holds a machine path' card "$OUT/seed_leak" "--job=$FJ"
w=""; grep -q '"sentence": ""' "$OUT/seed_leak/item.json" && grep -q '"job": "paddle-test-1"' "$OUT/seed_leak/item.json" && grep -q '"models": \["model-a", "model-b"\]' "$OUT/seed_leak/item.json" || w="sentence not emptied, or job or sorted models missing"
verdict card.job_sentence_with_a_path_fields "$w" "sentence empty, job and sorted models kept"

# ---- the validator
BAD="$OUT/bad_card"; cp -r "$SEED" "$BAD"
sed -i 's/"handle": "player"/"handle": "someone@example.org"/' "$BAD/item.json"
run validate.address_refused 1 'author.handle holds an e-mail address' check "$BAD"
cp "$SEED/item.json" "$BAD/item.json"; sed -i 's#"description": ""#"description": "built in C:/games/mine"#' "$BAD/item.json"
run validate.machine_path_refused 1 'description holds a machine path' check "$BAD"
cp "$SEED/item.json" "$BAD/item.json"; sed -i '/"licence"/d' "$BAD/item.json"
run validate.missing_key_refused 1 "key 'licence' is missing" check "$BAD"
cp "$SEED/item.json" "$BAD/item.json"; sed -i 's/"schema": "tl.item\/1",/"schema": "tl.item\/1",\n  "signature": "x",/' "$BAD/item.json"
run validate.signature_reserved 1 "'signature' is reserved" check "$BAD"
cp "$SEED/item.json" "$BAD/item.json"; sed -i 's/"uid": "[^"]*"/"uid": "short"/' "$BAD/item.json"
run validate.uid_shape 1 "uid: 'short' does not match" check "$BAD"
cp "$SEED/item.json" "$BAD/item.json"; sed -i 's/"capabilities": \["ai", "ball"/"capabilities": ["ball", "ai"/' "$BAD/item.json"
run validate.capabilities_unsorted 1 'capabilities must be sorted' check "$BAD"
cp "$SEED/item.json" "$BAD/item.json"; sed -i 's/"capabilities": \["ai", /"capabilities": [/' "$BAD/item.json"
run check.capability_grant_differs 1 'MISMATCH capabilities: the card says' check "$BAD"

# ---- the tier is computed
VEN="$OUT/venue"; mkdir -p "$VEN"; cp "$E/kits_lab/layouts/main.json" "$VEN/layout.json"
run tier.layout_only_is_data 0 'tier: data  files=1 ' tier "$VEN"
run tier.venue_card 0 'card: created item.json  uid=.* kind=venue tier=data' card "$VEN" "--title=Main yard"
run tier.venue_check 0 'check: ok  folder .* kind=venue tier=data' check "$VEN"
run tier.seed_is_code 0 'tier: code ' tier "$E/seeds/seed_paddle"
cp -r "$SEED" "$OUT/lie"; sed -i 's/"tier": "code"/"tier": "data"/' "$OUT/lie/item.json"
run tier.card_says_data_on_a_seed 1 "MISMATCH tier: the card says 'data', the contents are 'code'" check "$OUT/lie"
run tier.lying_card_not_packed 1 'pack: refused' pack "$OUT/lie" "--out=$OUT/lie.tlitem"
cp -r "$VEN" "$OUT/venue_script"; printf 'extends Node\n' > "$OUT/venue_script/hook.gd"
run tier.venue_with_a_script 1 "MISMATCH tier: the card says 'data', the contents are 'code' \(hook.gd: a GDScript file\)" check "$OUT/venue_script"
cp -r "$VEN" "$OUT/venue_scene"; printf '[gd_scene format=3]\n' > "$OUT/venue_scene/thing.tscn"
run tier.scene_is_code 0 'code: thing.tscn: not an inert file type \(.tscn\)' tier "$OUT/venue_scene"
cp -r "$VEN" "$OUT/venue_shader"; printf 'shader_type spatial;\n' > "$OUT/venue_shader/glow.gdshader"
run tier.shader_is_code 0 'code: glow.gdshader: not an inert file type' tier "$OUT/venue_shader"
cp -r "$VEN" "$OUT/venue_fake"; printf 'extends Node\n' > "$OUT/venue_fake/picture.png"
run tier.script_named_png_is_code 0 'code: picture.png: named .png but not a PNG picture' tier "$OUT/venue_fake"
cp -r "$VEN" "$OUT/venue_edit"; echo ' ' >> "$OUT/venue_edit/layout.json"
run check.content_changed 1 'MISMATCH content.hash: the card says' check "$OUT/venue_edit"

# ---- the package
run pack.seed_first 0 'pack: wrote a.tlitem ' pack "$SEED" "--out=$OUT/a.tlitem"
sleep 3   # a different second on the clock: a timestamp in the archive would show
run pack.seed_second 0 'pack: wrote b.tlitem ' pack "$SEED" "--out=$OUT/b.tlitem"
A="$(sha "$OUT/a.tlitem")"; B="$(sha "$OUT/b.tlitem")"; w=""
[ -n "$A" ] && [ "$A" = "$B" ] || w="two packings differ: $A / $B"
verdict pack.same_bytes_twice "$w" "sha256 $A twice, $(wc -c < "$OUT/a.tlitem" | tr -d ' ') bytes"
cp -r "$E/seeds/seed_paddle" "$OUT/fresh"
run pack.makes_the_card_once 0 'pack: the folder had no card; created item.json' pack "$OUT/fresh" "--out=$OUT/f1.tlitem"
run pack.then_reuses_it 0 'pack: wrote f2.tlitem ' pack "$OUT/fresh" "--out=$OUT/f2.tlitem"
w=""; [ "$(sha "$OUT/f1.tlitem")" = "$(sha "$OUT/f2.tlitem")" ] || w="the second packing of a folder that had no card differs"
verdict pack.no_card_same_bytes_twice "$w"
run pack.zip_is_standard 0 'zipreader: [0-9]+ entries, same order and same bytes' zipreader "$OUT/a.tlitem"
w=""; [ "$(head -c 4 "$OUT/a.tlitem" | od -An -tx1 | tr -d ' \n')" = "504b0304" ] || w="not a zip"
verdict pack.zip_signature "$w"
run check.archive 0 "check: ok  archive  uid=$UID1 kind=game tier=code" check "$OUT/a.tlitem"
w=""; echo "$LAST" | grep -q "content.hash=$HASH1" || w="the archive's content hash is not the folder's ($HASH1)"
verdict check.archive_hash_is_folder_hash "$w" "$HASH1"
run unpack.seed 0 'unpack: wrote [0-9]+ files  tier=code kind=game' unpack "$OUT/a.tlitem" "--to=$OUT/unpacked"
run unpack.then_check 0 "check: ok  folder  uid=$UID1" check "$OUT/unpacked"
w=""; diff -r "$SEED" "$OUT/unpacked" >/dev/null 2>&1 || w="the unpacked folder differs from the packed one"
verdict unpack.same_files "$w"
if [ -z "$FILTER" ] || [[ "unpack.lints" == *"$FILTER"* ]]; then
  TL_QUIET=1 bash "$TL" lint "--pack=$OUT/unpacked" "--report=$OUT/unpacked_lint.json" >/dev/null 2>&1; got=$?
  w=""; [ $got -eq 0 ] || w="tl.sh lint on the unpacked pack: exit $got"
  verdict unpack.lints "$w" "tl.sh lint passes on the unpacked pack, item.json at its root"
fi
run unpack.never_overwrites 1 'the target folder is not empty' unpack "$OUT/a.tlitem" "--to=$OUT/unpacked"
run pack.venue 0 'pack: wrote v.tlitem .* tier=data' pack "$VEN" "--out=$OUT/v.tlitem"
run unpack.venue 0 'unpack: wrote 2 files  tier=data kind=venue' unpack "$OUT/v.tlitem" "--to=$OUT/venue_unpacked"

# ---- the library: <library>/<uid>-<version>.tlitem, never rewritten
run library.first 0 "pack: wrote $UID1-0.1.0.tlitem " pack "$SEED" "--library=$OUT/library"
run library.same_again 0 'already in the library with the same bytes; nothing written' pack "$SEED" "--library=$OUT/library"
cp -r "$SEED" "$OUT/seed_changed"; echo '# a change' >> "$OUT/seed_changed/scripts/main.gd"
run library.changed_card 0 'card: refreshed item.json' card "$OUT/seed_changed"
run library.never_rewritten 1 'a library file is never rewritten' pack "$OUT/seed_changed" "--library=$OUT/library"

# ---- hostile archives
hostile() {  # hostile <kind> <ERE of the refusal>
  if [ -n "$FILTER" ] && [[ "hostile.$1" != *"$FILTER"* ]]; then return; fi
  bash "$ME" forge "$1" "--out=$OUT/h_$1.tlitem" >/dev/null 2>&1
  run "hostile.$1" 1 "$2" unpack "$OUT/h_$1.tlitem" "--to=$OUT/h_$1"
  local w=""; [ -e "$OUT/h_$1" ] && w="a refused archive left files behind"; [ -e "$OUT/evil.txt" ] && w="a file landed outside the target"
  [ -n "$w" ] && verdict "hostile.$1.nothing_written" "$w"
}
hostile dotdot "'\.\.' segment \(no path may leave the item\)"
hostile absolute 'absolute path'
hostile drive "drive or scheme in path"
hostile backslash 'backslash in path'
hostile duplicate 'the same path twice'
hostile unsorted 'entries are not sorted'
hostile sidecar 'sidecars are never part of an item'
hostile trailing 'no end record in the last 22 bytes'
hostile clock 'the timestamp is not the fixed one|local header disagrees'
hostile bomb 'one file may have at most|more than [0-9]+ bytes'
head -c 300 "$OUT/a.tlitem" > "$OUT/h_cut.tlitem"
run hostile.truncated 1 'no end record' unpack "$OUT/h_cut.tlitem" "--to=$OUT/h_cut"
head -c 9000000 /dev/zero > "$OUT/h_big.tlitem"
run hostile.over_8_mb 1 'the archive has 9000000 bytes; the limit is 8000000' check "$OUT/h_big.tlitem"
BIGP="$OUT/venue_bigthumb"; cp -r "$VEN" "$BIGP"; mkdir -p "$BIGP/preview"
{ printf '\x89PNG\r\n\x1a\n'; head -c 1100000 /dev/zero; } > "$BIGP/preview/thumb.png"
run limit.thumbnail_over_1_mb 1 'preview/thumb.png: [0-9]+ bytes; a preview picture stays under 1000000' card "$BIGP"
BIGS="$OUT/seed_bigscript"; cp -r "$E/seeds/seed_paddle" "$BIGS"; for i in $(seq 1 700); do echo "# line $i"; done >> "$BIGS/scripts/main.gd"
run limit.script_over_600_lines 1 'scripts/main.gd: [0-9]+ lines; one script may have at most 600' card "$BIGS"

# ---- the fence: each closed hole has a bad pack that lint now refuses, and play lints first
EX="$E/kernel/examples"
fence() {  # fence <pack> <ERE the lint report must match>
  if [ -n "$FILTER" ] && [[ "fence.$1" != *"$FILTER"* ]]; then return; fi
  local rep="$OUT/lint_$1.json"
  TL_QUIET=1 bash "$TL" lint "--pack=$EX/$1" "--report=$rep" >/dev/null 2>&1; local got=$?
  local w=""; [ $got -eq 1 ] || w="lint exit $got, expected 1"
  grep -Eq -- "$2" "$rep" 2>/dev/null || w="${w:+$w; }the report lacks /$2/"
  verdict "fence.$1" "$w" "$(grep -o '"kind":"fence"' "$rep" 2>/dev/null | wc -l | tr -d ' ') fence findings"
}
fence bad_reach_assets '"kind":"fence","file":"assets/hidden.gd","line":[0-9]+,"message":".OS\.. is outside the fence'
fence bad_reach_filetype '"kind":"fence","file":"assets/part.tscn","message":"a file of this type can carry code'
fence bad_reach_reflection '"file":"scripts/main.gd","line":[0-9]+,"message":".call\(. is outside the fence'
fence bad_reach_classes '"message":".ResourceLoader. is outside the fence'
fence bad_reach_tree '"message":".get_tree\(\). is outside the fence'
fence bad_reach_alias '"message":".OS\.. is outside the fence'
fence bad_reach_load 'load\( of the relative path .kernel/runner/worker.gd.'
if [ -z "$FILTER" ] || [[ "fence.line_break" == *"$FILTER"* ]]; then
  n="$(grep -n 'var wrapped = load' "$EX/bad_reach_load/scripts/main.gd" | cut -d: -f1)"
  w=""; grep -q "\"file\":\"scripts/main.gd\",\"line\":$n,\"message\":\"load( of 'res://kernel/runner/worker.gd'" "$OUT/lint_bad_reach_load.json" 2>/dev/null || w="load( broken over two lines (line $n) was not reported"
  verdict fence.line_break "$w" "a call split with a backslash line break is still seen (line $n)"
fi
if [ -z "$FILTER" ] || [[ "fence.each_line" == *"$FILTER"* ]]; then
  for p in bad_reach_reflection bad_reach_classes bad_reach_tree bad_reach_alias bad_reach_load; do
    # the lines of the block, plus the one line outside it that starts a call broken over two lines (bad_reach_load)
    want="$( (awk '/^# FENCE BEGIN/{f=1;next}/^# FENCE END/{f=0}f{print NR}' "$EX/$p/scripts/main.gd"; grep -n 'var wrapped = ' "$EX/$p/scripts/main.gd" | cut -d: -f1) | sort -n | tr '\n' ' ')"
    got="$(grep -o '"kind":"fence","file":"scripts/main.gd","line":[0-9]*' "$OUT/lint_$p.json" 2>/dev/null | grep -o '[0-9]*$' | sort -n | tr '\n' ' ')"
    w=""; [ "$want" = "$got" ] || w="fence lines reported [$got] expected [$want]"
    verdict "fence.each_line.$p" "$w" "$(echo $want | wc -w | tr -d ' ') lines, each reported once"
  done
fi
if [ -z "$FILTER" ] || [[ "fence.play_lints_first" == *"$FILTER"* ]]; then
  out="$(bash "$TL" play "--pack=$EX/bad_reach_assets" 2>&1)"; got=$?
  w=""; [ $got -eq 1 ] || w="play exit $got, expected 1"
  echo "$out" | grep -q 'play refused' || w="${w:+$w; }no refusal line"
  echo "$out" | grep -q 'worker start' && w="${w:+$w; }the worker was started all the same"
  verdict fence.play_lints_first "$w" "tl.sh play refuses a pack that fails lint; no window is opened"
fi
if [ -z "$FILTER" ] || [[ "fence.good_packs_still_pass" == *"$FILTER"* ]]; then
  w=""
  for p in "$E/seeds/seed_paddle" "$E/seeds/seed_drive" "$E/seeds/seed_wall" "$EX/pack_min" "$EX/ex_kit"; do
    TL_QUIET=1 bash "$TL" lint "--pack=$p" "--report=$OUT/good.json" >/dev/null 2>&1 || w="${w:+$w; }$(basename "$p") fails lint"
  done
  verdict fence.good_packs_still_pass "$w" "three seeds, pack_min, ex_kit"
fi

# ---- optional manifest fields (contracts/PACK.md, amendments of 2026-11-11)
if [ -z "$FILTER" ] || [[ "manifest" == *"$FILTER"* ]]; then
  manifest_case() {  # manifest_case <name> <expected lint exit> <ERE or ""> <sed expression on pack.json>
    local d="$OUT/m_$1"; cp -r "$E/kernel/examples/pack_min" "$d"; sed -i "$4" "$d/pack.json"
    TL_QUIET=1 bash "$TL" lint "--pack=$d" "--report=$OUT/m_$1.json" >/dev/null 2>&1; local got=$?
    local w=""; [ $got -eq "$2" ] || w="lint exit $got, expected $2"
    if [ -n "$3" ]; then grep -Eq -- "$3" "$OUT/m_$1.json" 2>/dev/null || w="${w:+$w; }the report lacks /$3/"; fi
    verdict "manifest.$1" "$w" "$(grep -o '"kind":"schema","file":"pack.json"[^}]*' "$OUT/m_$1.json" 2>/dev/null | head -1 | sed 's/.*"message":"//' | cut -c1-110)"
  }
  manifest_case all_five_fields 0 '"id":"lint.schema","ok":true' 's#"entry"#"footprint": {"size_m": [40, 30], "height_m": 12}, "params": [{"name": "speed", "file": "data/tuning.json", "path": "ball.speed", "min": 1, "max": 9, "step": 0.5, "label": "Ball speed"}], "on_leave": "pause", "subject": "Ball", "moments": [{"name": "start", "frame": 60}, {"name": "goal", "event": "goal"}], "entry"#'
  manifest_case footprint_shape 1 "footprint.size_m" 's#"entry"#"footprint": {"size_m": [40], "height_m": 12}, "entry"#'
  manifest_case footprint_unknown_key 1 "footprint: unknown key" 's#"entry"#"footprint": {"size_m": [40, 30], "height_m": 12, "depth": 1}, "entry"#'
  manifest_case params_outside_data 1 "params\[0\].file" 's#"entry"#"params": [{"name": "speed", "file": "scripts/main.gd", "path": "a", "min": 1, "max": 9, "step": 1, "label": "x"}], "entry"#'
  manifest_case params_min_above_max 1 "params\[0\]: min" 's#"entry"#"params": [{"name": "speed", "file": "data/tuning.json", "path": "a", "min": 9, "max": 1, "step": 1, "label": "x"}], "entry"#'
  manifest_case on_leave_word 1 "on_leave" 's#"entry"#"on_leave": "explode", "entry"#'
  manifest_case subject_shape 1 "subject" 's#"entry"#"subject": "../Host", "entry"#'
  manifest_case moments_frame_and_event 1 "moments\[0\]" 's#"entry"#"moments": [{"name": "a", "frame": 1, "event": "x"}], "entry"#'
  manifest_case kernel_api_patch_level 1 "kernelApi" 's#"kernelApi": "0.1"#"kernelApi": "0.2"#'
  manifest_case params_file_missing 1 "listed in .params. but the file does not exist" 's#"entry"#"params": [{"name": "speed", "file": "data/nothing.json", "path": "a", "min": 1, "max": 9, "step": 1, "label": "x"}], "entry"#'
  manifest_case still_unknown_key 1 "unknown key .colour." 's#"entry"#"colour": "red", "entry"#'
fi

echo "item selftest: $pass passed, $fail failed (files in $OUT)"
[ $fail -eq 0 ]
