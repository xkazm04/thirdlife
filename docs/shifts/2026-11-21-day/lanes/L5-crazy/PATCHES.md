# L5 hockey-crazy: PATCHES for L4 and the Director

Everything below is applied in the n21d-crazy tree and gated there. Files in L5's own column (scripts/{abilities,boosts,modes,look}.gd,
scripts/fx/neon.gd, data/boosts.json, data/modes/{arsenal,shotgun,glow}.json, gen/{crazy,neon}_hook.gd, tests/crazy_*.gd) land as they are.
The hunks here touch L4's files (main.gd, state.gd, hits.gd, tuning.json, pack.json, README.md) or engine/style (approved append-only).
PATCHES-A.md and PATCHES-B.md are the builders' detailed notes; THIS file is the exact list.

## What the hooks promise (so L4 can keep them through its rewrite)
- `crazy` (scripts/abilities.gd) is inert unless the mode file names "pickups" or "abilities": every hook returns at once, nothing is declared,
  nothing enters _pack_state. Base, outnumbered, sudden_death, pond, big_ice hash exactly as at df58f0b (bot_hockey s1-3, bot_match s1,
  bot_modes s1, bot_menu s1: equal).
- Where each hook must sit in _pack_tick: `crazy.pre(self)` in the live branch BEFORE keeper.save and api.update_possession (a shotgun downs
  bodies on its path before anybody's reach or a goalie's catch); `crazy.post(self)` AFTER api.apply_speeds and BEFORE main drains api.events
  (it reads this frame's ["shot"/"pass", id] to change the released puck, and multiplies skate_speed after the base speeds are set);
  `crazy.faceoff(self)` in _faceoff after api.reset/hits.reset; `crazy.build(self, m)` last in _build (needs g.hud, g.api, g.hits);
  `crazy.use_key(self)` guards the check key in player_input (F with an ability ready uses it; the right button still checks).
- Input hash rule (found today): TLInput hashes every declared action NAME, pressed or not. So a crazy mode (modes.gd is_crazy: pickups,
  abilities or neon) gets no mode_<id> action; it is reached from the start panel; `ability` (F) and the crazy drill actions are declared lazily
  when a crazy mode is first built. Any new action L4 declares at setup moves every hockey hash: say so in L4's report.
- hits.gd: `immune` (id -> true while a shield runs: no check or cross-check targets him; he still checks) and `immune_blocks` (counts attempts
  that passed over a shielded man). If L4's contact model replaces target()/try_check()/try_cross(), every path that picks a victim must skip
  `immune` ids and count `immune_blocks` the same way (tests/crazy_shield.gd measures it).
- Downs from L5 go through TLHit.down(who, frames, from_dir) (shotgun: from_dir toward the shooter; hip check: toward the hitter).
- main.gd's pool: on neon each figure has a second, prewarmed rig with neon colours (look.neon_colors): `skin` ":neon" is chosen only windowed
  (headless never builds or picks it, so no hash or body changes); both are prewarmed at windowed load so a panel start into a neon mode stays
  under the runner's 250 ms tick limit (it went over at 252-261 ms before).
- How to film a crazy mode: copy the pack under .tl/, set tuning.json "mode" to 5/6/7 in the copy, run a bot with the autopilot
  (bot_hockey_ai) through `--write-movie` (engine/tools/look.sh clip's recipe). No clip-only bot is in pack.json.

## engine/packs/hockey/scripts/main.gd (L4's file: 590 lines after, cap 600)
```diff
diff --git a/engine/packs/hockey/scripts/main.gd b/engine/packs/hockey/scripts/main.gd
index 4db321c..e44119f 100644
--- a/engine/packs/hockey/scripts/main.gd
+++ b/engine/packs/hockey/scripts/main.gd
@@ -37,6 +37,7 @@ var fun = null                         # L5: scripts/fun/fun.gd (hit-stop, shake
 var keeper = null                      # L5: scripts/keeper.gd (the goalies)
 var intro = null                       # L5: scripts/intro.gd (the first minute: a drill before the first match)
 var state_lib = null                   # scripts/state.gd (_pack_state)
+var crazy = null                       # L5 crazy (21 Nov day): scripts/abilities.gd (F abilities, owns scripts/boosts.gd: pickups); off unless the mode names them
 var skaters: Dictionary = {}           # id -> TLBiped
 var order: Array = []                  # ids in roster order
 var teams: Dictionary = {}
@@ -82,6 +83,7 @@ func _pack_setup(c) -> void:
 	fun = ctx.load_script("scripts/fun/fun.gd").new()
 	intro = ctx.load_script("scripts/intro.gd").new()
 	state_lib = ctx.load_script("scripts/state.gd").new()
+	crazy = ctx.load_script("scripts/abilities.gd").new()
 	look.cfg = base_tune["look"]
 	ai_base = ctx.read_json("ai.json")
 	drills = ctx.read_json("drills.json")
@@ -118,6 +120,7 @@ func _pack_setup(c) -> void:
 	mode_id = str(list[pick]) if modes.has(str(list[pick])) else "base"
 
 	menu_lib.setup(self)
+	crazy.setup_pack(self)                 # L5 crazy: the ability key (F) and the crazy drills' keyless actions
 	for a: Array in [[&"up", KEY_W], [&"down", KEY_S], [&"left", KEY_A], [&"right", KEY_D], [&"poke", KEY_E], [&"sprint", KEY_SHIFT],
 			[&"dial", KEY_T], [&"restart", KEY_R], [&"view", KEY_V], [&"skip", KEY_ENTER]]:
 		ctx.input.declare(a[0], [a[1]])
@@ -134,7 +137,8 @@ func _pack_setup(c) -> void:
 	for d: Dictionary in drills["drills"]:
 		ctx.input.declare(StringName("drill_" + str(d["id"])), [])
 	for mid: String in base_tune["modes"]:
-		ctx.input.declare(StringName("mode_" + mid), [])
+		if not modes_lib.is_crazy(modes.get(mid, {})):     # L5 crazy: a declared action is in the input hash; crazy modes come from the panel
+			ctx.input.declare(StringName("mode_" + mid), [])
 	for lid: String in base_tune["levels"]:
 		ctx.input.declare(StringName("level_" + lid), [])
 	if ctx.root.has_meta(&"hockey_ai"):
@@ -143,7 +147,7 @@ func _pack_setup(c) -> void:
 	if ctx.root.has_meta(&"hockey_fx"):
 		fx = ctx.load_script(str(ctx.root.get_meta(&"hockey_fx"))).new()
 		fx.setup(ctx, env)
-	_build(mode_id)
+	_build(mode_id, not ctx.headless)  # L5 crazy: warm both uniforms during windowed loading
 
 
 ## hunt2 A14, B1: the venues, the dress and the benched skaters kept out of the tree go with the pack, never left behind.
@@ -155,7 +159,7 @@ func _notification(what: int) -> void:
 
 
 ## Builds the match of a mode from nothing: venue, puck, skaters, goal volumes, rules, HUD, the helpers.
-func _build(mid: String) -> void:
+func _build(mid: String, warm_kits: bool = false) -> void:
 	# a rebuild runs inside one tick (a mode change, R): only what changed is made again, so it stays far under the runner's 250 ms tick limit (the whole arena rebuilt in a tick took 254 ms of processor time)
 	if arena != null:
 		ctx.root.remove_child(arena)
@@ -237,23 +241,26 @@ func _build(mid: String) -> void:
 			ctx.root.remove_child(old)       # every pooled skater lives directly under ctx.root
 
 	var opts: Dictionary = (tune["skater"] as Dictionary).duplicate()
+	var skin := ":neon" if not ctx.headless and m.has("neon") and bool(m["neon"].get("trim", true)) else ""  # L5 crazy
+	var skins: Array = ["", ":neon"] if warm_kits else [skin]
 	for entry: Dictionary in (tune["roster"] as Array) + keeper.entries(self, m):
 		var id: String = str(entry["id"])
 		var team: String = str(entry["team"])
 		var sp: Array = entry["spawn"]
 		var at := Vector3(float(sp[0]), 0.1, float(sp[1]))
 		var pid: String = id + ":" + team
-		if not pool.has(pid):
-			var o: Dictionary = opts.duplicate()
-			var kit: String = "car_blue" if team == "blue" else "car_red"
-			o.merge({"mode": "skate", "position": at, "facing": _face_yaw(team), "name": "skater_" + id, "rig_params": {"colors": entry.get("colors", {"top": kit, "trim": kit, "legs": kit})}})
-			o["body_scale"] = float(entry.get("scale", opts["body_scale"]))
-			var made: TLBiped = TLBiped.create(o)
-			if made.rig != null:
-				var bs: float = float(o["body_scale"])
-				made.rig.scale = Vector3(bs, bs, bs)      # H7: the body is the figure's size too (create option body_scale)
-			pool[pid] = made
-		var sk: TLBiped = pool[pid]
+		for suffix: String in skins:
+			if not pool.has(pid + suffix):
+				var o: Dictionary = opts.duplicate()
+				var kit: String = "car_blue" if team == "blue" else "car_red"
+				var colors: Dictionary = look.neon_colors(team, str(entry["role"])) if suffix == ":neon" else entry.get("colors", {"top": kit, "trim": kit, "legs": kit})
+				o.merge({"mode": "skate", "position": at, "facing": _face_yaw(team), "name": "skater_" + id, "rig_params": {"colors": colors}})
+				o["body_scale"] = float(entry.get("scale", opts["body_scale"]))
+				var made: TLBiped = TLBiped.create(o)
+				if made.rig != null:
+					made.rig.scale = Vector3.ONE * float(o["body_scale"])      # H7: the body is the figure's size too
+				pool[pid + suffix] = made
+		var sk: TLBiped = pool[pid + skin]
 		ctx.root.add_child(sk)
 		sk.skate_accel = float(opts["skate_accel"])
 		sk.skate_turn_rate = float(opts["skate_turn_rate"])
@@ -310,6 +317,7 @@ func _build(mid: String) -> void:
 		brain.override(m.get("ai", {}))
 		brain.red_over = (levels[level_id]["ai"] as Dictionary).duplicate() if levels.has(level_id) else {}
 	dial_lib.apply(self)
+	crazy.build(self, m)                   # L5 crazy: pickups and abilities of this mode (none: off, nothing changes)
 
 
 func _v3(a: Array) -> Vector3:
@@ -366,8 +374,8 @@ func player_input() -> void:
 		api.try_pass("b0")
 	if ctx.input.just_pressed(&"poke"):
 		api.try_poke("b0")
-	if ctx.input.just_pressed(&"check"):
-		hits.try_check("b0")
+	if ctx.input.just_pressed(&"check") and not crazy.use_key(self):
+		hits.try_check("b0")              # L5 crazy: F with an ability ready uses it instead (the right button still checks)
 	if ctx.input.just_pressed(&"cross"):
 		hits.try_cross("b0")
 
@@ -406,7 +414,7 @@ func _pack_tick(frame: int) -> void:
 	if intro.tick(self, frame):
 		return
 	for mid: String in modes:
-		if ctx.input.just_pressed(StringName("mode_" + mid)):
+		if not modes_lib.is_crazy(modes[mid]) and ctx.input.just_pressed(StringName("mode_" + mid)):
 			_build(mid)
 			_start_match()
 			_flush_events(frame)
@@ -457,6 +465,7 @@ func _pack_tick(frame: int) -> void:
 	env["frozen"] = stopped
 
 	if not stopped:
+		crazy.pre(self)                    # L5 crazy: pickups taken, the shotgun's path downs (before any reach or catch)
 		if drill_id == "" or keeper.in_drill:
 			keeper.save(self)                 # L5: a goalie's catch or poke check comes before anybody's reach
 		api.update_possession()
@@ -480,6 +489,7 @@ func _pack_tick(frame: int) -> void:
 			if drill_id == "" and (id != "b0" or autopilot) and not keeper.is_goalie(id):
 				(skaters[id] as TLBiped).brake(hits.is_down(id))
 	api.apply_speeds()
+	crazy.post(self)                       # L5 crazy: boosts on speeds, this frame's shots (shotgun, slow puck, precision), the bots' F, crazy drills
 	for e: Array in api.events:
 		if str(e[0]) == "shot" or str(e[0]) == "one_timer":
 			_event(str(e[0]), (skaters[str(e[1])] as Node3D).global_position, str(teams[str(e[1])]))
@@ -546,6 +556,7 @@ func _hold_all() -> void:
 func _faceoff() -> void:
 	api.reset()
 	hits.reset()
+	crazy.faceoff(self)                    # L5 crazy: puck effects end at a face-off
 	var j: float = float(tune["faceoff_jitter"])
 	puck.place(Vector3(ctx.rng.randf_range(-j, j), 0.07, ctx.rng.randf_range(-j, j)))
 	for id: String in order:
```

## state.gd, hits.gd, data/tuning.json, pack.json (L4 files; JSON edited by text)
```diff
diff --git a/engine/packs/hockey/data/tuning.json b/engine/packs/hockey/data/tuning.json
index ff4b353..5a639eb 100644
--- a/engine/packs/hockey/data/tuning.json
+++ b/engine/packs/hockey/data/tuning.json
@@ -30,6 +30,6 @@
   "menu": {"auto_start_frames":600},
   "intro": {"ring":[-6,2],"ring_r":1.6,"return_frames":20,"done_frames":100,"lost_frames":150,"lines":{"skate":"[ W A S D ]   skate to the ring","take":"the puck in your ring is yours","pass":"[ Q ]   pass it back to LEO","back":"LEO passes again","shoot":"[ CLICK ]   shoot into the net","done":"GOAL!   now the match","skip":"Enter: skip"}},
   "mode": 0,
-  "modes": ["base","outnumbered","sudden_death","pond","big_ice"],
+  "modes": ["base","outnumbered","sudden_death","pond","big_ice","arsenal","shotgun","glow"],
   "dial": {"names":["skate","shot","grip","sharpness"],"labels":["Skate speed","Shot speed","Ice grip","Bot sharpness"],"per_step":[0.08,0.1,0.25,0.05],"min":-3,"max":3}
 }
diff --git a/engine/packs/hockey/pack.json b/engine/packs/hockey/pack.json
index ec758d9..757d8c1 100644
--- a/engine/packs/hockey/pack.json
+++ b/engine/packs/hockey/pack.json
@@ -61,7 +61,13 @@
     "tests/bot_goalie.gd",
     "tests/bot_intro.gd",
     "tests/bot_fun.gd",
-    "tests/bot_intro_skip.gd"
+    "tests/bot_intro_skip.gd",
+    "tests/crazy_shotgun.gd",
+    "tests/crazy_hipcheck.gd",
+    "tests/crazy_shield.gd",
+    "tests/crazy_slowpuck.gd",
+    "tests/crazy_pickups.gd",
+    "tests/crazy_modes.gd"
   ],
   "cameras": [
     "arena",
@@ -136,9 +142,9 @@
       "file": "data/tuning.json",
       "path": "mode",
       "min": 0,
-      "max": 4,
+      "max": 7,
       "step": 1,
-      "label": "Mode: 0 base 1 3v5 2 sudden 3 pond 4 big"
+      "label": "Mode: 0-4 classic, 5-7 crazy"
     },
     {
       "name": "level",
diff --git a/engine/packs/hockey/scripts/hits.gd b/engine/packs/hockey/scripts/hits.gd
index a8cb669..0f7d6a8 100644
--- a/engine/packs/hockey/scripts/hits.gd
+++ b/engine/packs/hockey/scripts/hits.gd
@@ -29,6 +29,9 @@ var events: Array = []                ## [kind, hitter, victim] since main drain
 var _now: int = 0
 var shield: Dictionary = {}           ## L5: goalie id -> team: nobody checks him, he checks nobody
 var enabled: bool = true              ## H3: a mode without checks (pond): F and C do nothing
+var immune: Dictionary = {}           ## L5 crazy: id -> true while his shield runs: no check or cross-check lands on him (he still checks)
+var immune_blocks: Dictionary = {}    ## L5 crazy: shielded victim -> actual checks or crosses that passed him over
+var _immune_target: String = ""       ## L5 crazy: nearest shield in the last target query
 
 
 func setup(tune: Dictionary, a, sk: Dictionary, tm: Dictionary, ord: Array) -> void:
@@ -87,11 +90,18 @@ func target(id: String, reach: float, cone_deg: float, stick: bool = false) -> S
 	var f: Vector3 = api.stick_of(id) if stick else api.fwd_of(id)
 	var best: String = ""
 	var best_d: float = reach
+	_immune_target = ""                # L5 crazy
+	var immune_d: float = reach
 	for oid: String in order:
 		if str(teams[oid]) == str(teams[id]) or is_down(oid) or shield.has(oid):
 			continue
 		var to: Vector3 = api.pos_of(oid) - me
 		var d: float = to.length()
+		if immune.has(oid):            # L5 crazy: record candidates here, count only when somebody attempts a check
+			if d <= immune_d and (d < 0.05 or f.dot(to.normalized()) >= cos(deg_to_rad(cone_deg))):
+				immune_d = d
+				_immune_target = oid
+			continue
 		if d <= best_d and (d < 0.05 or f.dot(to.normalized()) >= cos(deg_to_rad(cone_deg))):
 			best = oid
 			best_d = d
@@ -132,6 +142,8 @@ func try_check(id: String) -> String:
 		return ""
 	tries[id] = int(tries[id]) + 1
 	var v: String = target(id, _f("check_reach"), _f("check_cone_deg"))
+	if _immune_target != "":           # L5 crazy
+		immune_blocks[_immune_target] = int(immune_blocks.get(_immune_target, 0)) + 1
 	if v == "":
 		ready_at[id] = _now + int(_f("whiff_cooldown_frames"))
 		return ""
@@ -175,6 +187,8 @@ func try_cross(id: String) -> bool:
 		return false
 	tries[id] = int(tries[id]) + 1
 	var v: String = target(id, _f("cross_reach"), _f("cross_cone_deg"), true)
+	if _immune_target != "":           # L5 crazy
+		immune_blocks[_immune_target] = int(immune_blocks.get(_immune_target, 0)) + 1
 	ready_at[id] = _now + int(_f("cross_cooldown_frames"))
 	if v == "":
 		return false
diff --git a/engine/packs/hockey/scripts/state.gd b/engine/packs/hockey/scripts/state.gd
index a52188f..8001b0f 100644
--- a/engine/packs/hockey/scripts/state.gd
+++ b/engine/packs/hockey/scripts/state.gd
@@ -63,6 +63,8 @@ func state(g) -> Dictionary:
 		s["stick"] = _p2(g.api.stick_dir["b0"])       # H4: only while the aim is valid (absent: as before H4)
 	if not g.keeper.ids.is_empty():
 		s["saves"] = g.keeper.saves.duplicate()      # L5: the goalies' saves by the side that made them
+	if g.crazy != null and g.crazy.on:
+		s["crazy"] = g.crazy.state()                 # L5 crazy: only in a mode with pickups or abilities
 	var fs: Dictionary = g.fun.state()
 	if not fs.is_empty():
 		s["fun"] = fs
```

## README.md: the "Crazy modes" section (append after "How to play"; plain ASCII)
```markdown
## Crazy modes (L5, 21 Nov)

Three modes on the start panel (A / D, then Space) turn the house game into an arcade game. They are reached only from the panel (no
keyless mode_<id> action: a declared action is in the input hash, and the base game must hash as before). F is the ability key in them;
the right mouse button still body-checks.

- **Arsenal** (neon arena, amber accent): beacons of light appear in three zones (first after 2 s, then every 4 s, up to 5 on the ice; seeded).
  Skate over one (0.5 m plus your body radius) to take it; bots take them too and peel off for a near one. Effects: speed (skate speed and
  acceleration x1.5, 5 s), precision (a shot within 30 degrees of the goal centre goes to it, 8 s), big puck (radius x1.5, 10 s), heavy puck
  (drag 0.8, top speed x0.5, 6 s). Ability beacons give one charge of: shotgun, hip check, shield or slow puck.
- **Shotgun** (daylight hall): every skater holds the shotgun; F loads it, the next shot leaves at x1.5 and knocks down every standing skater
  within 1 m (plus his body radius) of its path for up to 2 s of flight, team-mates and goalies too. It comes back after 20 s.
- **Glow Ice** (neon arena, the base rules): a dark sheet with lines of light, the blue half solid cyan and the red half dashed red, a faint grid,
  light trails behind skaters and the puck (the puck's the brightest), blue and brick-red suits with light trim. Plays exactly like base
  (seed 1: the same state, frame by frame, but for "mode" and "game_line").

| Ability (F) | What it does | Numbers (data/boosts.json) |
|---|---|---|
| Shotgun | the next shot x1.5, downs everybody on its path | 90 frames down, path 1.0 m + body radius, 120 frames of flight, ends under 6 m/s |
| Hip check | armed 60 frames; lands on the first opponent in reach even from a standstill | down 60 x 1.5 frames, the victim slides 3 m |
| Shield | 6 s in which no check or cross-check lands on you (a bubble shows it) | 360 frames |
| Slow puck | the next pass or shot leaves at half speed and wakes up after 2 s | x0.5 for 120 frames |

Abilities have a 20 s cooldown (1200 frames); the plate at the bottom right says READY, NEXT SHOT, the seconds left, or the shield's time.
Tests: tests/crazy_shotgun.gd (two defenders on the line go down, a plain shot downs nobody), crazy_hipcheck.gd (3.0 +- 0.5 m, 1.5x down),
crazy_shield.gd (the check is blocked, the shield ends at 360 frames), crazy_slowpuck.gd (half speed, wakes at 120), crazy_pickups.gd (spawn,
take, effects, expiry), crazy_modes.gd (Arsenal and Shotgun to the end with bots, abilities used, pickups taken). Each held on seeds 1 to 20.
```

## engine/style (approved by the Director 12:00: append-only, no existing key or default changed)
Three glow keys appended to the palette of all four style files (same order, after pond_ice) with a mat entry each. A mesh stores the palette
COLUMN index, so existing indices and every kit mesh hash are unchanged.
```diff
diff --git a/engine/style/style.json b/engine/style/style.json
index c8a697c..21f93e8 100644
--- a/engine/style/style.json
+++ b/engine/style/style.json
@@ -232,7 +232,10 @@
   "flag_b": "#3a78d8",
   "fall_a": "#bfe4f2",
   "fall_b": "#f6fbff",
-  "pond_ice": "#cfe6f2"
+  "pond_ice": "#cfe6f2",
+  "neon_pink": "#ff3fa4",
+  "neon_lime": "#a3ff3d",
+  "neon_violet": "#9b6bff"
  },
  "mat": {
   "window": {
@@ -435,7 +438,10 @@
    "metal": 0.5,
    "mottle": 0.1,
    "no_hatch": 1.0
-  }
+  },
+  "neon_pink": {"emit": 2.4, "no_hatch": 1.0, "mottle": 0.0},
+  "neon_lime": {"emit": 2.2, "no_hatch": 1.0, "mottle": 0.0},
+  "neon_violet": {"emit": 2.4, "no_hatch": 1.0, "mottle": 0.0}
  },
  "detail": {
   "k": 1.0,
diff --git a/engine/style/style_crisp.json b/engine/style/style_crisp.json
index a3f129a..c1e6a3c 100644
--- a/engine/style/style_crisp.json
+++ b/engine/style/style_crisp.json
@@ -271,7 +271,10 @@
   "flag_b": "#3a78d8",
   "fall_a": "#bfe4f2",
   "fall_b": "#f6fbff",
-  "pond_ice": "#cfe6f2"
+  "pond_ice": "#cfe6f2",
+  "neon_pink": "#ff3fa4",
+  "neon_lime": "#a3ff3d",
+  "neon_violet": "#9b6bff"
  },
  "mat": {
   "window": {
@@ -489,7 +492,10 @@
   },
   "trunk": {
    "sway": -1.0
-  }
+  },
+  "neon_pink": {"emit": 2.4, "no_hatch": 1.0, "mottle": 0.0},
+  "neon_lime": {"emit": 2.2, "no_hatch": 1.0, "mottle": 0.0},
+  "neon_violet": {"emit": 2.4, "no_hatch": 1.0, "mottle": 0.0}
  },
  "detail": {
   "k": 1.0,
diff --git a/engine/style/style_diorama.json b/engine/style/style_diorama.json
index 1e5d182..cd54434 100644
--- a/engine/style/style_diorama.json
+++ b/engine/style/style_diorama.json
@@ -231,7 +231,10 @@
   "flag_b": "#3a78d8",
   "fall_a": "#bfe4f2",
   "fall_b": "#f6fbff",
-  "pond_ice": "#cfe6f2"
+  "pond_ice": "#cfe6f2",
+  "neon_pink": "#ff3fa4",
+  "neon_lime": "#a3ff3d",
+  "neon_violet": "#9b6bff"
  },
  "mat": {
   "window": {
@@ -550,7 +553,10 @@
   },
   "goal_red": {
    "gloss": 0.7
-  }
+  },
+  "neon_pink": {"emit": 2.4, "no_hatch": 1.0, "mottle": 0.0},
+  "neon_lime": {"emit": 2.2, "no_hatch": 1.0, "mottle": 0.0},
+  "neon_violet": {"emit": 2.4, "no_hatch": 1.0, "mottle": 0.0}
  },
  "detail": {
   "k": 1.0,
diff --git a/engine/style/style_overcast.json b/engine/style/style_overcast.json
index 3ab9b05..7adc725 100644
--- a/engine/style/style_overcast.json
+++ b/engine/style/style_overcast.json
@@ -223,7 +223,10 @@
   "flag_b": "#3a78d8",
   "fall_a": "#c4d6de",
   "fall_b": "#eef2f4",
-  "pond_ice": "#d5e2e8"
+  "pond_ice": "#d5e2e8",
+  "neon_pink": "#ff3fa4",
+  "neon_lime": "#a3ff3d",
+  "neon_violet": "#9b6bff"
  },
  "mat": {
   "window": {
@@ -426,7 +429,10 @@
    "metal": 0.5,
    "mottle": 0.1,
    "no_hatch": 1.0
-  }
+  },
+  "neon_pink": {"emit": 2.4, "no_hatch": 1.0, "mottle": 0.0},
+  "neon_lime": {"emit": 2.2, "no_hatch": 1.0, "mottle": 0.0},
+  "neon_violet": {"emit": 2.4, "no_hatch": 1.0, "mottle": 0.0}
  },
  "detail": {
   "k": 1.0,
```
