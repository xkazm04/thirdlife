# L4 dungeons-menu (night of 21 Nov): the main menu and dungeons (engine/boot/boot.gd, menu.gd, dungeons.json,
# engine/kernel/dungeon/). dungeon.list: the tl.dungeons/1 list (unknown keys are errors) and its packs resolve;
# dungeon.bypass: every old flag path and unattended instrument goes past the menu as before; dungeon.hash_alone:
# `-- --dungeon=<pack> --frames=N` hashes as `worker --mode=play --frames=N` of the same pack and seed (hockey, parkour, paddle),
# and --look=diorama is installed and the default look is back after;
# dungeon.trips: menu -> World -> menu -> dungeon -> menu three times: no growth past the tolerance, same hashes each time;
# dungeon.watchdog (L4b): a runaway step ends to a card with its Leave.
dg_cases="dungeon.list dungeon.bypass dungeon.refused dungeon.hash_alone dungeon.trips dungeon.watchdog"
dg_any=0
for dg_c in $dg_cases; do if [ -z "$FILTER" ] || [[ "$dg_c" == *"$FILTER"* ]]; then dg_any=1; fi; done
if [ "$dg_any" = 1 ]; then
  dg_g="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
  dg_e="$(cd "$HERE/.." && pwd)"
  dg_o="$OUT/dungeon"
  mkdir -p "$dg_o"
  if command -v cygpath >/dev/null 2>&1; then dg_e="$(cygpath -m "$dg_e")"; dg_o="$(cygpath -m "$dg_o")"; dg_g="$(cygpath -m "$dg_g")"; fi
  dg_run() { MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL='*' timeout 600 "$dg_g" --headless --fixed-fps 60 --path "$dg_e" "$@"; }
  dg_hash() { grep -o '"state_hash":"[0-9a-f]*"' "$1" 2>/dev/null | head -1 | sed 's/.*:"//; s/"//'; }
fi

# ---------------------------------------------------------------------------------------------- the list and the decision
if [ -z "$FILTER" ] || [[ "dungeon.list" == *"$FILTER"* ]] || [[ "dungeon.bypass" == *"$FILTER"* ]]; then
  cat > "$dg_o/probe.gd" <<'GDSCRIPT'
extends SceneTree

const List = preload("res://kernel/dungeon/dungeons.gd")
const Boot = preload("res://boot/hub.gd")

func _initialize() -> void:
	run.call_deferred()

func write(path: String, text: String) -> String:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()
	return path

func run() -> void:
	var dir: String = OS.get_cmdline_user_args()[0]
	# the list
	var r: Dictionary = List.read()
	var ok: bool = bool(r["ok"]) and (r["dungeons"] as Array).size() >= 3
	var packs: Array = (r["dungeons"] as Array).map(func(d: Dictionary) -> String: return str(d["pack"]))
	ok = ok and packs.has("packs/hockey") and packs.has("packs/parkour") and packs.any(func(p: String) -> bool: return p.begins_with("seeds/"))
	var hockey_look: String = ""
	var unresolved: Array = []
	for d: Dictionary in r["dungeons"]:
		if str(d["pack"]) == "packs/hockey":
			hockey_look = str(d.get("look", ""))
		if str(List.resolve(str(d["pack"]), "")).is_empty():
			unresolved.append(d["pack"])
	ok = ok and hockey_look == "crisp" and unresolved.is_empty()
	var bad: Dictionary = {
		"unknown_top": '{"schema":"tl.dungeons/1","dungeons":[],"extra":1}',
		"unknown_entry": '{"schema":"tl.dungeons/1","dungeons":[{"pack":"packs/hockey","title":"H","icon":"x"}]}',
		"no_title": '{"schema":"tl.dungeons/1","dungeons":[{"pack":"packs/hockey"}]}',
		"null_look": '{"schema":"tl.dungeons/1","dungeons":[{"pack":"packs/hockey","title":"H","look":null}]}',
		"bad_look": '{"schema":"tl.dungeons/1","dungeons":[{"pack":"packs/hockey","title":"H","look":"neon"}]}',
		"abs_pack": '{"schema":"tl.dungeons/1","dungeons":[{"pack":"C:/x/packs/hockey","title":"H"}]}',
		"up_pack": '{"schema":"tl.dungeons/1","dungeons":[{"pack":"../packs/hockey","title":"H"}]}',
		"twice": '{"schema":"tl.dungeons/1","dungeons":[{"pack":"packs/hockey","title":"H"},{"pack":"packs/hockey","title":"I"}]}',
		"schema": '{"schema":"tl.dungeons/' + '2","dungeons":[]}',
		"not_list": '{"schema":"tl.dungeons/1","dungeons":{}}'}
	var accepted: Array = []
	for k: String in bad:
		if bool(List.read(write(dir + "/bad_" + k + ".json", bad[k]))["ok"]):
			accepted.append(k)
	ok = ok and accepted.is_empty()
	var good: Dictionary = List.read(write(dir + "/good.json", '{"schema":"tl.dungeons/1","dungeons":[{"pack":"seeds/seed_drive","title":"D","look":"classic"},{"pack":"packs/parkour","title":"P"}]}'))
	ok = ok and bool(good["ok"]) and not (good["dungeons"][1] as Dictionary).has("look")
	ok = ok and List.look_path("crisp") == "res://style/style_crisp.json" and List.look_path("classic") == "res://style/style.json" and List.look_path("") == ""
	var la: PackedStringArray = List.launch_args("C:/job/pack")
	ok = ok and la.has("res://boot/boot.tscn") and la[la.size() - 1] == "--dungeon=C:/job/pack" and la[la.size() - 2] == "--"
	print("DUNGEON_LIST ok=", ok, " listed=", packs, " unresolved=", unresolved, " bad_accepted=", accepted, " launch=", la)
	# the decision: the menu only for a person's start with nothing else asked
	var env_all: Array = ["TL_EXE_CAPTURE", "TL_EXE_CAPTURE_AT", "TL_EXE_QUIT_AT", "TL_EXE_KEYS", "TL_EXE_WARM", "TL_EXE_TRACE", "TL_EXE_FRAMES"]
	var wrong: Array = []
	if not Boot.menu_decision({}, {}, false): wrong.append("no arguments")
	if Boot.menu_decision({}, {}, true): wrong.append("headless")
	for k: String in ["record", "input", "site-job", "games", "edits", "ticks", "out", "anything"]:
		if Boot.menu_decision({k: "x"}, {}, false): wrong.append("--" + k)
	for k: String in env_all:
		if Boot.menu_decision({}, {k: "1"}, false): wrong.append(k)
	if not Boot.menu_decision({"menu": "true"}, {"TL_EXE_KEYS": "1"}, false): wrong.append("--menu")
	if not Boot.menu_decision({}, {"TL_EXE_MENU": "1", "TL_EXE_CAPTURE": "x"}, false): wrong.append("TL_EXE_MENU=1")
	print("DUNGEON_BYPASS ok=", wrong.is_empty(), " cases=", 2 + 8 + env_all.size() + 2, " wrong=", wrong)
	quit(0)
GDSCRIPT
  dg_run --script "$dg_o/probe.gd" -- "$dg_o" > "$dg_o/probe.log" 2>&1
  dg_err=""; grep -aEq 'SCRIPT ERROR|^ERROR:' "$dg_o/probe.log" && dg_err="script errors (see $dg_o/probe.log)"
  dg_l="$(grep -a '^DUNGEON_LIST' "$dg_o/probe.log" | tr -d '\r')"
  dg_b="$(grep -a '^DUNGEON_BYPASS' "$dg_o/probe.log" | tr -d '\r')"
  why=""; [[ "$dg_l" == "DUNGEON_LIST ok=true"* ]] || why="${dg_l:-no answer} $dg_err"
  verdict dungeon.list "$why" "${dg_l#DUNGEON_LIST ok=true }"
  # the decision, then the real runs of the old paths that end without a window: tag, the village headless, check
  why=""; [[ "$dg_b" == "DUNGEON_BYPASS ok=true"* ]] || why="${dg_b:-no answer} $dg_err"
  if [ -z "$FILTER" ] || [[ "dungeon.bypass" == *"$FILTER"* ]]; then
    dg_run res://boot/boot.tscn -- tag > "$dg_o/tag.log" 2>&1; dg_c1=$?
    grep -aq '^\[boot\] build: dev' "$dg_o/tag.log" && [ $dg_c1 -eq 0 ] || why="${why:+$why; }tag: exit $dg_c1 or no build line"
    dg_run res://boot/boot.tscn > "$dg_o/nowin.log" 2>&1; dg_c2=$?
    { [ $dg_c2 -eq 2 ] && grep -aq 'the village needs a window' "$dg_o/nowin.log"; } || why="${why:+$why; }headless with no arguments: exit $dg_c2, not the village's refusal (exit 2)"
    dg_run res://boot/boot.tscn -- --record=C:/nowhere/x.json > "$dg_o/rec.log" 2>&1; dg_c3=$?
    { [ $dg_c3 -eq 2 ] && grep -aq 'the village needs a window' "$dg_o/rec.log"; } || why="${why:+$why; }headless --record: exit $dg_c3, not the village's refusal"
    dg_run res://boot/boot.tscn -- check "--out=$dg_o/check.jsonl" --ticks=120 > "$dg_o/check.log" 2>&1; dg_c4=$?
    { [ $dg_c4 -eq 0 ] && grep -aq '"kind":"pack"' "$dg_o/check.jsonl" && ! grep -aq '"kind":"census"' "$dg_o/check.log"; } || why="${why:+$why; }check --ticks=120: exit $dg_c4 or no pack line or a menu was shown"
  fi
  verdict dungeon.bypass "$why" "${dg_b#DUNGEON_BYPASS ok=true }; tag, headless village refusal, --record, check: as before"
fi

# ---------------------------------------------------------------------------------------------- refusals
if [ -z "$FILTER" ] || [[ "dungeon.refused" == *"$FILTER"* ]]; then
  why=""
  dg_run res://boot/boot.tscn -- "--dungeon=$dg_e/packs/hockey" > "$dg_o/r1.log" 2>&1; dg_c=$?
  { [ $dg_c -eq 2 ] && grep -aq 'counted run: give --frames' "$dg_o/r1.log"; } || why="headless --dungeon without --frames: exit $dg_c, wanted 2"
  dg_run res://boot/boot.tscn -- "--dungeon=$dg_o/no_such_pack" --frames=10 > "$dg_o/r2.log" 2>&1; dg_c=$?
  { [ $dg_c -eq 2 ] && grep -aq 'no pack folder' "$dg_o/r2.log"; } || why="${why:+$why; }a missing folder: exit $dg_c, wanted 2"
  dg_run res://boot/boot.tscn -- "--dungeon=$dg_e/kernel/examples/bad_fence" --frames=10 > "$dg_o/r3.log" 2>&1; dg_c=$?
  { [ $dg_c -eq 2 ] && grep -aq 'does not pass lint' "$dg_o/r3.log"; } || why="${why:+$why; }a pack outside the fence: exit $dg_c, wanted 2"
  dg_run res://boot/boot.tscn -- "--dungeon=$dg_e/kernel/examples/bad_script_error" --frames=120 > "$dg_o/r4.log" 2>&1; dg_c=$?
  [ $dg_c -eq 1 ] || why="${why:+$why; }a pack with a script error: exit $dg_c, wanted 1"
  verdict dungeon.refused "$why" "no --frames headless 2, missing 2, lint 2, script error 1"
fi

# ---------------------------------------------------------------------------------------------- the dungeon hashes as alone
if [ -z "$FILTER" ] || [[ "dungeon.hash_alone" == *"$FILTER"* ]] || [[ "dungeon.trips" == *"$FILTER"* ]]; then
  why=""; dg_note=""
  for dg_p in packs/hockey:1200:1 packs/hockey:600:7 packs/parkour:900:1 seeds/seed_paddle:900:3; do
    IFS=: read -r dg_pk dg_n dg_s <<< "$dg_p"
    dg_t="$(basename "$dg_pk")_${dg_n}_$dg_s"
    dg_run res://kernel/host/host.tscn -- worker --mode=play "--pack=$dg_e/$dg_pk" "--frames=$dg_n" "--seed=$dg_s" "--result=$dg_o/alone_$dg_t.json" > "$dg_o/alone_$dg_t.log" 2>&1
    dg_run res://boot/boot.tscn -- "--dungeon=$dg_e/$dg_pk" "--frames=$dg_n" "--seed=$dg_s" "--out=$dg_o/dungeon_$dg_t.json" > "$dg_o/dungeon_$dg_t.log" 2>&1; dg_c=$?
    dg_a="$(dg_hash "$dg_o/alone_$dg_t.json")"; dg_d="$(dg_hash "$dg_o/dungeon_$dg_t.json")"
    dg_fr="$(grep -o '"frames":[0-9]*' "$dg_o/dungeon_$dg_t.json" 2>/dev/null | head -1 | sed 's/.*://')"
    if [ $dg_c -ne 0 ] || [ -z "$dg_a" ] || [ "$dg_a" != "$dg_d" ] || [ "$dg_fr" != "$dg_n" ]; then
      why="${why:+$why; }$dg_t: alone ${dg_a:0:16}, dungeon ${dg_d:0:16} (exit $dg_c, $dg_fr frames)"
    else dg_note="$dg_note $dg_t=${dg_a:0:12}"; fi
  done
  # a dungeon's own look is installed and the default is back when it is left
  dg_run res://boot/boot.tscn -- "--dungeon=$dg_e/seeds/seed_paddle" --look=diorama --frames=60 "--out=$dg_o/look.json" > "$dg_o/look.log" 2>&1
  grep -q '"look":"res://style/style_diorama.json"' "$dg_o/look.json" 2>/dev/null && grep -q '"look_after":"res://style/style_crisp.json"' "$dg_o/look.json" || why="${why:+$why; }--look=diorama: not installed or the default not back ($(cat "$dg_o/look.json" 2>/dev/null | head -c 300))"
  dg_alone_hockey="$(dg_hash "$dg_o/alone_hockey_600_1.json")"
  if [ -z "$FILTER" ] || [[ "dungeon.hash_alone" == *"$FILTER"* ]]; then verdict dungeon.hash_alone "$why" "${dg_note# }"; fi
fi

# ---------------------------------------------------------------------------------------------- three round trips
if [ -z "$FILTER" ] || [[ "dungeon.trips" == *"$FILTER"* ]]; then
  # the trips open the FIRST dungeon of boot/dungeons.json (hokej since 23 Nov): its own alone hash is the one to hold
  dg_first="$(node -e 'const d=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")); console.log(d.dungeons[0].pack)' "$dg_e/boot/dungeons.json")"
  if [ "$dg_first" != "packs/hockey" ] || [ -z "$dg_alone_hockey" ]; then
    dg_run res://kernel/host/host.tscn -- worker --mode=play "--pack=$dg_e/$dg_first" --frames=600 --seed=1 "--result=$dg_o/alone_first_600_1.json" > /dev/null 2>&1
    dg_alone_hockey="$(dg_hash "$dg_o/alone_first_600_1.json")"
  fi
  dg_run res://boot/boot.tscn -- trips "--out=$dg_o/trips.jsonl" --trips=3 --ticks=600 --frames=600 > "$dg_o/trips.log" 2>&1; dg_c=$?
  # tolerance, from the third menu (after one whole round trip: the caches of the first world and dungeon are made)
  # to the last: nodes and resources 0, objects 16, static memory 2 MB
  why="$(node -e '
    const fs = require("fs"); const [file, log, alone] = process.argv.slice(1);
    let rows = []; try { rows = fs.readFileSync(file, "utf8").split("\n").filter(l => l.startsWith("{")).map(l => JSON.parse(l)); } catch (e) { console.log("no trips file"); process.exit(0); }
    const menus = rows.filter(r => r.kind === "census" && r.at === "menu"), ds = rows.filter(r => r.kind === "dungeon"), ws = rows.filter(r => r.kind === "world");
    const bad = [];
    if (menus.length !== 7) bad.push(`${menus.length} menus, wanted 7`);
    if (ds.length !== 3 || ws.length !== 3) bad.push(`${ws.length} worlds and ${ds.length} dungeons, wanted 3 and 3`);
    for (const d of ds) if (d.state_hash !== alone || d.frames !== 600 || d.script_errors || d.engine_errors) bad.push(`dungeon ${String(d.state_hash).slice(0, 12)} (${d.frames} frames, ${d.script_errors} script errors) is not the alone hash ${String(alone).slice(0, 12)}`);
    for (const w of ws) if (w.bad || w.ticks !== 600) bad.push(`world ${w.n}: bad=${w.bad} ticks=${w.ticks}`);
    if (menus.length >= 7) { const a = menus[2], z = menus[6];
      if (z.nodes - a.nodes > 0) bad.push(`nodes grew ${a.nodes} -> ${z.nodes}`);
      if (z.resources - a.resources > 0) bad.push(`resources grew ${a.resources} -> ${z.resources}`);
      if (z.objects - a.objects > 16) bad.push(`objects grew ${a.objects} -> ${z.objects}`);
      if (z.static_mb - a.static_mb > 2) bad.push(`static memory grew ${a.static_mb} -> ${z.static_mb} MB`);
      if (z.orphans > 0) bad.push(`${z.orphans} orphan nodes`); }
    // the worlds of the three trips hash alike (a dungeon between them changes nothing)
    const txt = fs.readFileSync(log, "utf8").split("\n"); const runs = []; let cur = [];
    for (const l of txt) { if (l.startsWith("{") && l.includes("\"kind\":\"pack\"")) { const p = JSON.parse(l); cur.push(p.plot + "=" + p.state_hash); } if (l.startsWith("[tl] world done")) { runs.push(cur.join(",")); cur = []; } }
    if (runs.length !== 3 || runs.some(r => r !== runs[0]) || !runs[0]) bad.push(`the three worlds do not hash alike (${runs.length} worlds)`);
    console.log(bad.join("; "));
  ' "$dg_o/trips.jsonl" "$dg_o/trips.log" "$dg_alone_hockey")"
  [ $dg_c -eq 0 ] || why="exit $dg_c${why:+; $why}"
  dg_m="$(grep -a '"at":"menu","n":[37]' "$dg_o/trips.log" | sed 's/.*"nodes":\([0-9]*\),"objects":\([0-9]*\),"resources":\([0-9]*\).*"static_mb":\([0-9.]*\).*/\1 nodes \2 objects \3 resources \4 MB/' | tr '\n' ';')"
  verdict dungeon.trips "$why" "3 round trips; menu 3 and 7: ${dg_m}; dungeon hash = alone ${dg_alone_hockey:0:12} each time; worlds alike"
fi

# ---------------------------------------------------------------------------------------------- L4b: the watchdog
# A runaway step (kernel/dungeon/fixtures/runaway: an endless loop at frame 60) is stopped by the dungeon's watchdog (the
# worker's processor-time rule, kernel/dungeon/watch.gd), which starts the card process on its record; that process
# shows the card and its Leave (pressed here by TL_EXE_KEYS) ends it (exit code 3) and writes --out. The case reads
# the card's text and its button from --out; it asserts no time.
if [ -z "$FILTER" ] || [[ "dungeon.watchdog" == *"$FILTER"* ]]; then
  why=""
  rm -f "$dg_o/trip.json"
  TL_EXE_KEYS="30:+Enter;32:-Enter" dg_run res://boot/boot.tscn -- "--dungeon=$dg_e/kernel/dungeon/fixtures/runaway" --frames=600 "--out=$dg_o/trip.json" > "$dg_o/trip.log" 2>&1
  for dg_i in $(seq 1 120); do [ -s "$dg_o/trip.json" ] && break; sleep 1; done
  grep -q '"why":"tripped"' "$dg_o/trip.json" 2>/dev/null || why="no card process result in $dg_o/trip.json (see $dg_o/trip.log)"
  grep -q '"reason":"tick_timeout","phase":"_pack_tick","frame":60' "$dg_o/trip.json" 2>/dev/null || why="${why:+$why; }the record does not name the runaway step of frame 60"
  grep -q '"card":{"kind":"tripped","text":"Runaway fixture: an endless step was stopped by the watchdog[^"]*","button":"Back to Create","pressed":true}' "$dg_o/trip.json" 2>/dev/null \
    || why="${why:+$why; }the card's text or its button is not in $dg_o/trip.json"
  grep -q '"state_hash"' "$dg_o/trip.json" 2>/dev/null && why="${why:+$why; }a stopped dungeon reported a hash"
  verdict dungeon.watchdog "$why" "endless step at frame 60 -> watchdog record -> card 'was stopped by the watchdog' -> Back to Create pressed (the card process wrote --out)"
fi
