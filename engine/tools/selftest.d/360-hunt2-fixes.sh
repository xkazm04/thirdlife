# Lane hunt2 (night of 19 Nov): the defects of bug hunt round 2 fixed in kernel/api, packs, seeds and boot, each checked against
# the fixed code (docs/shifts/2026-11-19-night/lanes/hunt2/findings.txt). One headless Godot run of the case script below
# (written to $OUT), plus two seed-bot runs on copies (C1); each Godot case needs its own HUNT2CASE line, the run its trailer `HUNT2END <n>` and exit 0: a missing line,
# a missing trailer or a stopped Godot is a FAIL (docs/GATE-HONESTY.md; finding A1 of the same hunt).

hunt2_cases="ball_holder_freed chase_slow_travel chase_pull_scaled nitro_crumb nitro_full_tank goal_over_net goal_in_net goal_offset_pack hockey_helpers_freed hockey_venue_freed hockey_bench_freed boot_editor_games parkour_retry_pressing hand_double_tap laws_material_copy input_at_reserved drive_time_hud parkour_offset_pack wall_origin_at_break"
hunt2_any=""
for hunt2_c in $hunt2_cases; do
  if [ -z "$FILTER" ] || [[ "hunt2.$hunt2_c" == *"$FILTER"* ]]; then hunt2_any=1; fi
done
if [ -n "$hunt2_any" ]; then
  hunt2_gd="$OUT/hunt2_case.gd"
  cat > "$hunt2_gd" <<'HUNT2_GD'
extends SceneTree
## hunt2 cases: one line `HUNT2CASE hunt2.<name> ok|FAIL <detail>` per case, then `HUNT2END <cases>`.
const Pack = preload("res://kernel/world/pack.gd")
const Boot = preload("res://boot/boot.gd")
const Space = preload("res://kernel/world/terrain/world_space.gd")
var said := 0


func _initialize() -> void:
	run.call_deferred()


func say(name: String, ok: bool, detail: String) -> void:
	said += 1
	print("HUNT2CASE hunt2.%s %s %s" % [name, "ok" if ok else "FAIL", detail])


func load_pack(dir: String, at := Vector3.ZERO) -> Node:
	var pack: Node = Pack.new()
	root.add_child(pack)
	var o := {"own_space": false, "scenery": "plot"}
	if at != Vector3.ZERO:
		o["at"] = at
	if not pack.load_pack(dir, o):
		push_error("hunt2: %s does not load: %s" % [dir, pack.load_errors])
		pack.free()
		return null
	return pack


func run() -> void:
	await ball_holder_freed()
	chase_slow_travel()
	chase_pull_scaled()
	await nitro()
	await goals()
	await hockey_freed()
	boot_editor_games()
	await parkour_retry_pressing()
	hand_double_tap()
	laws_material_copy()
	input_at_reserved()
	drive_time_hud()
	await parkour_offset_pack()
	await wall_origin_at_break()
	print("HUNT2END %d" % said)
	quit()


# A6: a held ball whose holder is freed falls (it was frozen in the air for good).
func ball_holder_freed() -> void:
	var hand := Node3D.new()
	root.add_child(hand)
	hand.position.y = 10.0
	var ball := TLBall.create({"position": hand.position})
	root.add_child(ball)
	ball.hold(hand)
	for i in 3:
		await physics_frame
	var start := ball.position.y
	hand.free()
	for i in 30:
		await physics_frame
	var drop := start - ball.position.y
	say("ball_holder_freed", ball.holder() == null and not ball.freeze and drop > 0.5,
		"holder freed: frozen %s, dropped %.2f m in 30 ticks (wanted unfrozen, > 0.5 m)" % [ball.freeze, drop])
	ball.free()


# A4: use_velocity stays behind slow travel (0.6 m/s) and at rest, as behind fast travel; snap() still takes the facing.
func chase_slow_travel() -> void:
	var r := []
	for step: float in [0.05, 0.01]:
		var target := Node3D.new()
		root.add_child(target)
		var cam := TLChaseCam.new()
		root.add_child(cam)
		cam.setup(target, {"use_velocity": true, "stiffness": 1.0, "follow": 1.0})
		for i in 120:
			target.position.x += step
			cam._physics_process(1.0 / 60)
		for i in 30:                      # at rest: the travel heading is kept
			cam._physics_process(1.0 / 60)
		r.append(target.position.x - cam.position.x)
		cam.snap()                         # Q19: a snap is behind the facing (-z), the travel forgotten
		r.append(cam.position.z - target.position.z)
		cam.free()
		target.free()
	var ok: bool = absf(r[0] - 7.0) < 0.05 and absf(r[2] - 7.0) < 0.05 and absf(r[1] - 7.0) < 0.05 and absf(r[3] - 7.0) < 0.05
	say("chase_slow_travel", ok, "behind the travel at 3.0 / 0.6 m/s then 30 ticks at rest: %.2f / %.2f m; after snap() behind the facing %.2f / %.2f m (wanted 7.00)" % [r[0], r[2], r[1], r[3]])


# A10: avoid_pull is in metres under a scaled parent.
func chase_pull_scaled() -> void:
	var r := []
	for k: float in [1.0, 2.0]:
		var sp: Object = Space.new()
		sp.add_box(Transform3D(Basis.IDENTITY, Vector3(0, 1, 5) / k), Vector3(20, 20, 4) / k)
		var parent := Node3D.new()
		root.add_child(parent)
		parent.rotation.y = deg_to_rad(31)
		parent.scale = Vector3.ONE * k
		var target := Node3D.new()
		parent.add_child(target)
		var cam := TLChaseCam.new()
		parent.add_child(cam)
		cam.setup(target, {"distance": 7.0, "height": 1.0, "look_height": 1.0, "avoid_space": sp.space, "avoid_min": 0.0, "avoid_margin": 0.3})
		var moved: float = 7.0 - cam.global_position.distance_to(target.global_position + Vector3.UP)
		r.append([cam.avoid_pull, moved])
		parent.free()
		sp.free_all()
	var ok: bool = r[0][1] > 1.0 and r[1][1] > 1.0 and absf(r[0][0] - r[0][1]) < 0.03 and absf(r[1][0] - r[1][1]) < 0.03
	say("chase_pull_scaled", ok, "avoid_pull vs metres moved in: scale 1 %.2f / %.2f, scale 2 %.2f / %.2f" % [r[0][0], r[0][1], r[1][0], r[1][1]])


# A9: Seed Drive's empty tank gives no boost however Shift is tapped; a full tank still burns nitro_frames ticks.
func nitro() -> void:
	var pack: Node = load_pack("res://seeds/seed_drive")
	if pack == null:
		return
	var car: TLVehicle = pack.entry.car
	var crumbs := 0
	pack.ctx.input.press(&"gas")
	for tick in 60:
		if tick % 2 == 1:
			pack.ctx.input.press(&"nitro")
		else:
			pack.ctx.input.release(&"nitro")
		pack.tick(tick)
		await physics_frame
		crumbs += int(car.nitro_active)
	say("nitro_crumb", crumbs == 0 and int(pack.entry.pad_visits) == 0, "empty tank, Shift tapped 30 times: %d boost ticks (wanted 0)" % crumbs)
	car.nitro_charge = 1.0
	pack.ctx.input.press(&"nitro")
	var burned := 0
	for tick in range(60, 60 + car.nitro_frames + 30):
		pack.tick(tick)
		await physics_frame
		burned += int(car.nitro_active)
	say("nitro_full_tank", burned == car.nitro_frames, "full tank, Shift held: %d boost ticks (wanted nitro_frames %d)" % [burned, car.nitro_frames])
	pack.free()


# A7: a puck over the net is no goal; a puck high in the net is, also when a world puts the pack away from the origin.
func goal_case(at: Vector3, above_ice: float) -> int:
	var pack: Node = load_pack("res://packs/hockey", at)
	if pack == null:
		return -1
	pack.tick(0)
	var game = pack.entry
	var trigger := game.arena.get_node("goal_trigger_red") as Node3D
	var p: Vector3 = trigger.global_position
	(game.puck as TLBall).place(Vector3(p.x, at.y + 0.05 + above_ice, p.z))
	var before: int = game.rules.score("blue")
	pack.tick(1)
	var scored: int = game.rules.score("blue") - before
	pack.free()
	return scored


func goals() -> void:
	var over := goal_case(Vector3.ZERO, 1.75)
	say("goal_over_net", over == 0, "puck 1.75 m above the ice behind the goal line (the crossbar is at 1.5 m): %d goals (wanted 0)" % over)
	var high := goal_case(Vector3.ZERO, 1.0)
	say("goal_in_net", high == 1, "puck 1.0 m above the ice inside the net: %d goals (wanted 1)" % high)
	var away := goal_case(Vector3(300, 2, -40), 0.3)
	say("goal_offset_pack", away == 1, "pack at (300, 2, -40), puck 0.3 m up inside the net: %d goals (wanted 1)" % away)
	await physics_frame


# A8, A14, B1: unloading hockey after a mode switch frees both helpers, the rink and the benched skaters kept out of the tree.
func hockey_freed() -> void:
	var pack: Node = load_pack("res://packs/hockey")
	if pack == null:
		return
	pack.tick(0)
	var game = pack.entry
	var refs := [weakref(game.api), weakref(game.hits)]
	var old_venue: WeakRef = weakref(game.venues[game.venue_key])
	pack.ctx.input.tap(&"mode_big_ice")
	pack.tick(1)
	var switched: bool = game.mode_id == "big_ice"
	refs.append_array([weakref(game.api), weakref(game.hits)])
	var bench: Array = []                  # B1: skaters the smaller roster of big ice left out of the tree
	for sk: Node in game.pool.values():
		if not sk.is_inside_tree():
			bench.append(weakref(sk))
	game = null
	pack.unload()
	pack.free()
	await physics_frame
	var live := 0
	for r: WeakRef in refs:
		live += int(r.get_ref() != null)
	say("hockey_helpers_freed", switched and live == 0, "mode switched %s; helpers alive after unload: %d of 4 (wanted 0)" % [switched, live])
	var kept: Object = old_venue.get_ref()
	say("hockey_venue_freed", switched and kept == null, "the first rink after a switch to big ice and an unload: %s (wanted freed)" % ("alive" if kept != null else "freed"))
	if kept != null:
		kept.free()
	var benched := 0
	for r: WeakRef in bench:
		benched += int(r.get_ref() != null)
	say("hockey_bench_freed", switched and bench.size() > 0 and benched == 0, "benched skaters alive after unload: %d of %d (wanted 0 of at least 1)" % [benched, bench.size()])
	for r: WeakRef in bench:
		if r.get_ref() != null:
			r.get_ref().free()


# A2: the editor binary without --games finds every village game, also one whose export name is not its folder's name.
func boot_editor_games() -> void:
	var boot: Node = Boot.new()
	var village: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://boot/village.json"))
	var missing: Array = []
	for plot: Dictionary in village["plots"]:
		if str(boot._pack_dir(str(plot["pack"]))).is_empty():
			missing.append(str(plot["pack"]))
	var n: int = village["plots"].size()
	boot.free()
	say("boot_editor_games", missing.is_empty() and n >= 8, "%d of %d village plots resolve in the editor binary; missing %s" % [n - missing.size(), n, missing])


# A15: running into the beam with forward held stops the runner there; one tap of C sends him to the landing checkpoint.
func parkour_retry_pressing() -> void:
	var pack: Node = load_pack("res://packs/parkour")
	if pack == null:
		return
	var game = pack.entry
	var runner: TLBiped = game.runner
	var venue = game.venue
	var tick := 0
	pack.tick(tick)
	tick += 1
	game.rules.pass_checkpoint("runner", 0)
	game.rules.pass_checkpoint("runner", 1)
	game.spawn_at = venue.point(venue.checkpoints[1], venue.DECK_Y + 0.04)
	runner.place(venue.point(venue.bar - 2.0, venue.DECK_Y + 0.04), -PI / 2)
	pack.ctx.input.press(&"forward")
	for i in 90:
		pack.tick(tick)
		tick += 1
		await physics_frame
	var at_beam: float = venue.bar - (runner.position.x - venue.START_X)
	pack.ctx.input.tap(&"slide")
	pack.tick(tick)
	await physics_frame
	var back: float = venue.bar - (runner.position.x - venue.START_X)
	var ok: bool = at_beam < 0.6 and back > 3.5 and int(game.rules.next_checkpoint["runner"]) == 2 and game.falls == 0
	say("parkour_retry_pressing", ok, "forward held into the beam: stopped %.2f m short; one C tap: %.2f m short of the beam, falls %d (wanted > 3.5 m, 0 falls)" % [at_beam, back, game.falls])
	pack.free()


# B10: two taps in a row through the regular hand are two presses the game sees (a lengthened first press swallowed the second).
func hand_double_tap() -> void:
	var ctx := TLContext.new()
	ctx.seed = 1
	ctx.input = TLInput.new()
	ctx.input.declare(&"shoot")
	var hand := TLHand.create(ctx, "regular", {"lapses_per_minute": 0.0})
	var edges := 0
	for frame in 3200:
		ctx.frame = frame
		if frame % 100 < 2:
			hand.tap(&"shoot")
		hand.tick()
		ctx.input._sample()
		edges += int(ctx.input.just_pressed(&"shoot"))
	var st: Dictionary = hand.stats()
	ctx.input.free()
	say("hand_double_tap", int(st["taps"]) == 64 and edges == 64, "regular hand, 32 pairs of taps: %d taps, %d presses, %d edges the game saw (wanted 64)" % [st["taps"], st["presses"], edges])


# C3: TLLaws.material() is a copy: editing what it returns changes no law (another context's, in a world).
func laws_material_copy() -> void:
	var before: float = float(TLLaws.material("rubber")["friction"])
	var row: Dictionary = TLLaws.material("rubber")
	row["friction"] = 0.03125
	var after: float = float(TLLaws.material("rubber")["friction"])
	say("laws_material_copy", is_equal_approx(before, after) and not is_equal_approx(after, 0.03125), "rubber friction %.5f, after editing a returned row %.5f (wanted unchanged)" % [before, after])


# C2: '@' names an aim's record entries ("aim@x"); a plain action or an aim with it is refused, so a replay cannot fold two inputs.
func input_at_reserved() -> void:
	var ctx := TLContext.new()
	ctx.input = TLInput.new()
	var prev = TLContext.enter(ctx)
	ctx.input.declare_aim(&"aim")
	ctx.input.declare(&"aim@x")
	ctx.input.declare(&"shoot")
	var names: PackedStringArray = ctx.input.declared()
	TLContext.leave(prev)
	ctx.input.free()
	say("input_at_reserved", not names.has("aim@x") and names.has("shoot"), "declared after declare(aim@x), declare(shoot): %s (wanted shoot only)" % [names])


# C5: Seed Drive out of time says so (the rules name the only side the winner on time: the HUD said THREE LAPS DONE).
func drive_time_hud() -> void:
	var pack: Node = load_pack("res://seeds/seed_drive")
	if pack == null:
		return
	pack.tick(0)
	pack.entry.rules.finish("car", "time")
	var hint: String = pack.entry.hud.text_of(&"hint")
	pack.free()
	say("drive_time_hud", hint.begins_with("OUT OF TIME"), "rules finished (car, time): HUD '%s' (wanted OUT OF TIME)" % hint)


# C7: Timber Run in a world that puts it 100 m away stands on its start deck (it was placed off the course and fell 5 times).
func parkour_run(at: Vector3) -> Array:
	var pack: Node = load_pack("res://packs/parkour", at)
	if pack == null:
		return [999.0, 999]
	for f in 120:
		await physics_frame
		pack.tick(f)
	var st: Dictionary = pack.ctx.pack_state()
	pack.free()
	return [float(st["station"]), int(st["falls"])]


func parkour_offset_pack() -> void:
	var here: Array = await parkour_run(Vector3.ZERO)
	var away: Array = await parkour_run(Vector3(100, 0, 0))
	var ok: bool = absf(here[0]) < 0.1 and here[1] == 0 and absf(away[0]) < 0.1 and away[1] == 0
	say("parkour_offset_pack", ok, "120 idle ticks at the origin / 100 m away: station %.2f / %.2f m, falls %d / %d (wanted 0)" % [here[0], away[0], here[1], away[1]])


# C10: Seed Wall measures a piece's travel from where it sat in the wall (it read the place after a physics step had moved it).
var hunt2_wall_origin := {}


func hunt2_remember(_by: Node, fracture: TLFracture) -> void:
	for piece: RigidBody3D in fracture.pieces:
		hunt2_wall_origin[piece] = piece.global_position


func wall_origin_at_break() -> void:
	var p: Node = Pack.new()
	root.add_child(p)
	if not p.load_pack("res://seeds/seed_wall", {"seed": 1, "mode": "bot", "scenery": "plot", "own_space": true, "test": "tests/bot_knock.gd", "frames": 3601}):
		p.free()
		return
	var game = p.entry
	for block: Dictionary in game.blocks:
		(block["fracture"] as TLFracture).broke.connect(hunt2_remember.bind(block["fracture"]))
	var shown := {}
	var disagree := 0
	for f in 3601:
		await physics_frame
		var live: bool = game.rules.is_running()
		for piece: RigidBody3D in hunt2_wall_origin:
			if live and piece.global_position.distance_to(hunt2_wall_origin[piece]) > float(game.tune["wall"]["down_distance"]):
				shown[piece] = true
		p.tick(f)
		if live and shown.size() != game.down.size():
			disagree += 1
		if p.finished:
			break
	var by_score: bool = p.finished and game.rules.reason == "score"
	var pieces: int = hunt2_wall_origin.size()
	p.unload()
	p.free()
	say("wall_origin_at_break", by_score and pieces > 0 and disagree == 0, "bot_knock seed 1: %d pieces, ended by score %s, ticks where the score and the pieces past 0.6 m from the wall disagree: %d (wanted 0)" % [pieces, by_score, disagree])
HUNT2_GD
  hunt2_g="${TL_GODOT:-C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
  hunt2_e="$(cd "$HERE/.." && pwd)"; hunt2_s="$hunt2_gd"
  if command -v cygpath >/dev/null 2>&1; then hunt2_e="$(cygpath -m "$hunt2_e")"; hunt2_s="$(cygpath -m "$hunt2_gd")"; fi
  hunt2_rc=0
  hunt2_out="$(MSYS_NO_PATHCONV=1 timeout 300 "$hunt2_g" --headless --fixed-fps 60 --path "$hunt2_e" --script "$hunt2_s" 2>&1)" || hunt2_rc=$?
  hunt2_out="$(echo "$hunt2_out" | tr -d '\015')"
  hunt2_errs="$(echo "$hunt2_out" | grep -a 'SCRIPT ERROR' | head -1)"
  hunt2_total="$(echo "$hunt2_out" | grep -a '^HUNT2END ' | tail -1 | cut -d' ' -f2)"
  hunt2_n=0
  for hunt2_c in $hunt2_cases; do hunt2_n=$((hunt2_n+1)); done
  for hunt2_c in $hunt2_cases; do
    line="$(echo "$hunt2_out" | grep -a "^HUNT2CASE hunt2.$hunt2_c " | head -1)"
    why=""
    if [ "$hunt2_rc" != 0 ]; then why="the case run stopped (Godot exit $hunt2_rc) ${line:+after: ${line#HUNT2CASE }}"
    elif [ "$hunt2_total" != "$hunt2_n" ]; then why="trailer HUNT2END ${hunt2_total:-missing}, wanted $hunt2_n cases (${hunt2_out:0:160})"
    elif [ -n "$hunt2_errs" ]; then why="script error: $hunt2_errs"
    elif [ -z "$line" ]; then why="no HUNT2CASE hunt2.$hunt2_c line"
    elif [[ "$line" != "HUNT2CASE hunt2.$hunt2_c ok "* ]]; then why="${line#HUNT2CASE hunt2.$hunt2_c }"; fi
    verdict "hunt2.$hunt2_c" "$why" "${line#HUNT2CASE hunt2.$hunt2_c ok }"
  done
fi

# C1: a seed's bot reads the win target from its rules (the seed guides invite changing it): paddle first to 1, drive 4 laps.
for hunt2_t in "paddle score_to_win 1 bot_win" "drive laps_to_win 4 bot_laps"; do
  read -r hunt2_n1 hunt2_k hunt2_v hunt2_b <<< "$hunt2_t"
  if [ -z "$FILTER" ] || [[ "hunt2.seed_target_$hunt2_n1" == *"$FILTER"* ]]; then
    hunt2_p="$OUT/hunt2_seed_$hunt2_n1"; rm -rf "$hunt2_p"; cp -r "$HERE/../seeds/seed_$hunt2_n1" "$hunt2_p"
    sed -i "s/\"$hunt2_k\": *[0-9]*/\"$hunt2_k\": $hunt2_v/" "$hunt2_p/data/rules.json"
    why=""
    grep -q "\"$hunt2_k\": $hunt2_v" "$hunt2_p/data/rules.json" || why="could not set $hunt2_k to $hunt2_v in the copy"
    if [ -z "$why" ]; then
      hunt2_rc=0
      TL_QUIET=1 timeout 300 bash "$TL" bot --pack="$hunt2_p" --test=tests/$hunt2_b.gd --seed=1 --frames=12000 --report="$OUT/hunt2_seed_$hunt2_n1.json" >/dev/null 2>&1 || hunt2_rc=$?
      hunt2_sum="$(grep -o '"summary":"[^"]*' "$OUT/hunt2_seed_$hunt2_n1.json" 2>/dev/null | tail -1 | cut -d'"' -f4)"
      [ "$hunt2_rc" = 0 ] || why="bot exit $hunt2_rc with $hunt2_k = $hunt2_v: ${hunt2_sum:-no report}"
    fi
    verdict "hunt2.seed_target_$hunt2_n1" "$why" "$hunt2_k = $hunt2_v in a copy: ${hunt2_sum:0:100}"
    rm -rf "$hunt2_p"
  fi
done
