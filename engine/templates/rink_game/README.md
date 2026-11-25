# rink_game: the base a rink game starts from

This is a working game, not a sketch. It is thirdjam's whole match (5 v 5 hockey, its bots, its camera, its HUD, its
figures) on the rink core (`engine/cores/rink`), in the hall thirdjam plays in. It is lane K3's hokej
(`engine/packs/hokej`) with the thirdjam parity proofs left out.

A game made from it is **a cartridge on the core plus a skin**. You change data, play it, and change data again. You do
not write a simulation.

## What a game is here

| Part | File | What it decides |
|---|---|---|
| the cartridge | `data/<cut>.cartridge.json` (schema `tj.cartridge/1`, thirdjam's) | everything that plays: the rink's size and corners, the goals, the teams (how many a side, roles, **colours**), speeds, contact, the puck, shots and passes, the rules (first to N, timer, penalties), the bots, pickups and abilities, zones, obstacles. Thirdjam's twelve modes in `engine/cores/rink/native/content/Cartridges/modes/` are worked examples, with `MODES.md` beside them. The schema and the catalog are lane E2's `engine/cores/rink/CARTRIDGE.md`. |
| the rules sidecar (optional) | `data/<cut>.rules.json` (schema `tl.rink.rules/1`) beside the cartridge | rules the cartridge schema cannot say. With it, `ctx.cores.open` opens the rule-patched core (`RinkCoreThirdlife`); without it, thirdjam's core byte for byte. |
| the match | `data/match.json` | `cartridge`: which cut plays (a file in `data/`). `difficulty`: the bots' level until HOME picks one (rookie, pro, all_star). |
| the skin | `data/skin.json` (schema `tl.rink.skin/1`; unknown keys are errors) | every word that belongs to the game: the title and tagline, HOME's lines, the team **names**, the level row's words, and which commentary and bark banks play (`builtin`, `off`, or a file in `data/`). See `scripts/hud/skin.gd` for each key and its default. |
| the banks | `data/hud_barks.json`, or a bank file of your own in `data/` | the skaters' barks (`{"lines": [[id, situation, speaker, tone, text], ...]}`) and the commentator's lines (`{"lines": [[id, event, kind, team, priority, cooldown_frames, text, duration_frames], ...]}`, the rows of `scripts/hud/commentary_lines.gd`). |

**What the cartridge puts on the rink is drawn from it** (`scripts/rink_toys.gd`, lane E1b): every `game.rink.zones` kind as
a tinted patch with its own mark (fast ice orange with speed streaks, slow ice blue with slush dots, a bumper zone magenta
with a rubber curb, no-shoot a red cross-hatch, boost-only green with a plus; `visible: false` is not painted), every
`game.rink.obstacles` kind standing (box, pillar, magenta bumper bollard, goal shield), pickups as turning beacons by kind
(the core's snapshot `Pickups`, RinkCore 1.4: one stands the frame it lands and shrinks away the frame it is taken), and a held ability on the HUD ("F: SHOTGUN  READY" above the radar). Nobody places
them by hand: change the cartridge, and the drawing follows.

**Colours have one source, the cartridge's `game.teams[].colour_hex`.** It colours the figures, the HUD's rings, the
score plates, the bark plates, the markers, the radar and the debug stand-ins. The skin names the teams in words only.
Where thirdjam's banks say "blue" and "orange", the commentator says the skin's `team_names`, as written ("the Glare
Foxes", never "glare foxes"). A plural name reads in the plural ("Sharks shoot!", "for the Gulls"; `team_plural` in the
skin, else guessed from the name). A bare colour word that is not its team's colour ("Blue" on a red team) is said as the
colour the person sees ("Red").

## What a builder may change

- **Yes:**
  - `data/*.cartridge.json` (yours, a new name), `data/*.rules.json`, `data/match.json`, `data/skin.json`.
  - New bank files in `data/`.
  - `pack.json` (`id`, `title`, the test list).
  - New tests in `tests/`.
- **Only with a reason the data cannot carry:** `scripts/**` and `gen/tj_rink.gd`. Every line there is a port of thirdjam
  that the data drives: a change there leaves the base, and the base's tests stop speaking for it.
- **Never:** `assets/hud/*.png`. These are thirdjam's UI kit: the ring and dial, plates, segments, header bar, goal banner
  and menu backdrop. A builder cannot make assets. They ship with the base: copy the whole folder.
- **Never:** `contracts/*`, the kernel, the core.

## How a game is made from it

1. Copy this folder to the game's place (for example `engine/packs/<name>/`): every file, `assets/` too.
2. In `pack.json`, set a new `id` (`game.<name>`) and a new `title` (80 characters at most).
3. Put the cartridge in `data/`: start from `hockey.regular.cartridge.json` or one of thirdjam's modes. Name it in
   `data/match.json` `cartridge`. Delete the regular cartridge if the game does not use it.
4. Write `data/skin.json`: its title, tagline, team names, level words and banks.
5. Run the tests (below). Play it in a window: `bash engine/tools/tl.sh capture --pack=<dir> --cam=follow
   --frame=1100 --hud=on --test=tests/bot_first_match.gd --out=<abs.png>`, or run it as a dungeon.

## Its tests

From the repository root (Git Bash):

```
bash engine/tools/tl.sh lint       --pack=<dir>
bash engine/tools/tl.sh smoke      --pack=<dir>
bash engine/tools/tl.sh invariants --pack=<dir>                                # determinism, the frame budget, the first test twice
bash engine/tools/tl.sh bot        --pack=<dir> --test=tests/bot_first_match.gd  # ROOKIE from HOME, a whole match to the end card
bash engine/tools/tl.sh bot        --pack=<dir> --test=tests/bot_match_hand.gd   # a whole match through the keys and mouse
bash engine/tools/tl.sh bot        --pack=<dir> --test=tests/bot_skin.gd         # the skin reads clean, its banks load, colours from the cartridge
bash engine/tools/tl.sh bot        --pack=<dir> --test=tests/bot_toys.gd         # every zone and obstacle of the cartridge is drawn, and its pickups as the core has them
```

`bot_first_match` passes when the match ends (by goals or by the cartridge's timer) inside 10 minutes and the end card is
held.

**A game's own hint line has a slot** (`scripts/hud/hint.gd`, lane H2b): a game's script says
`ctx.root.set_meta(&"rink_hint", "F: BUBBLE  Green spots reload it")` on every frame it should show ("" = none), and the
base draws it on a dark plate above the controls panel, never over the commentator's caption. Do not add a TLHud label
of your own at the bottom: the caption lives there.

**A skin's own commentary lines need no voice**: the commentator says a line with no recorded voice as text only (the
caption shows it; `rink_audio.gd` records a "voice_none" row), never an error.

## Known limits of the base

- **A finished game keeps the base it was made with** until it is moved: My games' "Newest base" (`foreman rebase <job>`)
  copies this base again under it, keeping its cartridge, rules, skin, match and own files, verifies it and promotes a new
  version. A game whose packages changed one of the base's scripts is refused (the move would lose that change).

- **The hall.** Thirdjam's barn is built for a 90 x 45 rink. A smaller cartridge rink resizes only the ice, the boards
  and the kick plate. The barn, its stands, its benches and its penalty boxes stay where they are: on a 60 x 30 rink the
  benches stand out on the floor behind the boards.
- **The rink core** plays thirdjam's sport: skaters, sticks, a puck, two goals. Another body, another ball or a new
  mechanic is not a cartridge: it is new engine code in the core (C++, hours of work and a new build), and the person
  decides whether to pay that. Never order it: offer the nearest data-only way first (zones, effects, pickups, abilities
  and the rules sidecar already do a lot), and name the engine-code version as the costlier choice, with its hours.
- **Front-end words not yet in the skin.** The front end's other words (MATCH card, end card, panel verbs) are
  thirdjam's. A MODES row on HOME is not ported: the cut is `data/match.json`'s.
- **The faces of the sport.** The skaters' figure and the puck are thirdjam's (engine/rigs/skater; the pack's own drawing
  of the puck).

## The same code as hokej

`scripts/**`, `gen/**`, `assets/**` and the carried tests are byte-for-byte hokej's. Selftest `rink.template` checks this.
A fix to the base goes into both, or into hokej first and is copied here.

## The code, explained (moved from the scripts, lane H2e)

The base keeps room under the lint budget of 6,000 lines of game GDScript (scripts/, gen/): its long explanations
stand here, word for word as they stood in the code. A code line `## ... [base README: <file> §<k>]` points to its
section (the same in hokej, whose shared files are these bytes); each section names the code line it stood above.
It is for people reading the code, not for the Designer: the Foreman quotes this README into a job's design and plan
context only up to this heading (foreman/src/coreroute.ts readmeForDesign).

### gen/tj_rink.gd

**§1** (above `const Z_PAINT: float = 0.006      # RinkActor.cpp:604: markings 0.6 cm over the ice`)

```text
thirdjam's regular rink as ARinkActor::Build makes it (S/JamGame/Private/RinkActor.cpp:434-886, measures RinkActor.h:59-70,
thirdjam HEAD 8dc713c6), from the cartridge's game.rink (90 x 45 m, corners 3.75 m, goals 4 x 0.61 m), drawn kit-style
(TLMesh, palette keys): the outline (ARinkActor::Outline, 12 segments a corner), the boards with their kick plate, the
markings, and the goals as thirdjam's arena meshes are made (tools/blender/arena/arena.py goal_build, the 4 x 0.61 variant
RinkActor picks). The ice sheet alone is the kit's `rink` part (no boards, glass, markings or goals of its own), lowered
0.05 m so its top is thirdjam's z = 0. Round 2 (the Director, 23 Nov): a plain dark hall round it in place of sky and
grass (no art: walls, a ceiling). Visual only: the gym's skater is plain data. Every measure that differs is in
docs/shifts/2026-11-24-night/lanes/K3-shell/RINK.md.
```

**§2** (above `static func build(parent: Node3D, rink: Dictionary, hall: Dictionary, arena_marks: Dictionary = {}) -> Node3D:`)

```text
Builds the rink under `parent` (a Node3D in Godot coordinates: rink x -> x, rink y -> z, up -> y).
`arena_marks` (K3 round 9): empty without thirdjam's hall; with it (lane K6's arena, ctx.cores.part("rink", "arena")) the
arena draws the ice, the boards and the kick plate as the clay tier dresses them, and its ice paints the centre line, the
blue lines, the goal lines and the 9 m centre circle (style/shaders/hall_ice.gdshader: RinkActor's markings sections 0
and 1). Then this draws only RinkActor's sections 2 and 3, "the marks B's painted ice does not carry" (RinkActor.cpp:
614-618), in thirdjam's own colours: {"red": section 2's colour, "pale": section 3's} (linear, arena.json's Markings
materials, RinkActor.cpp:650-659), and the goals (the arena leaves them to the pack by default).
```

**§3** (above `static func _boards(mk: TLMesh, line: Array) -> void:`)

```text
The boards (RinkActor.cpp:470-500, RinkActor.h:60-67): 1.2 m high, 0.2 m thick outward from the outline; the kick plate
0.25 m high standing 2 cm proud of the inner face, yellow (RinkActor.cpp:550, LoadConstructionMat(0.85, 0.72, 0.12)).
```

**§4** (above `static func _paint(key: Variant) -> Array:`)

```text
A strip of half width hw between two points on the ice (FMeshBuf::Strip: the width argument is the half width).
A paint `key` is a palette key, or a Color: thirdjam's own colour on the palette's white (the toon shader multiplies the
palette colour by the vertex colour).
```

**§5** (above `static func _at(side: float, gl: float, x: float, o: float, z: float) -> Vector3:`)

```text
A goal as thirdjam's arena mesh makes it (tools/blender/arena/arena.py goal_build, lines 559-633, G at 521-530): the
posts' inner faces at +-w/2 and the crossbar's underside at h (the sim's goal volume), posts and crossbar 16 cm, the
bottom bars, back posts, back bar and braces 11 cm, depth 1.5 m (UJamSim::NetDepth), the back frame min(0.9, 0.6 h);
the net of 3 cm cords in 25 cm cells. Its frame: x along the goal line -> rink y, `out` (into the net) -> rink x * side.
```

**§6** (above `static func _hall(node: Node3D, L: float, W: float, hall: Dictionary) -> void:`)

```text
The hall (round 2, the Director's word: no art): a dark box round the rink, its floor, four walls and a ceiling, from
data/gym.json "hall". It is not thirdjam's arena (stair step 5); it takes the sky and the grass out of the picture.
```

**§7** (above `static func standin_figure(parent: Node3D, key: Variant = "car_blue", nm: String = "Skater") -> Array:`)

```text
The 1.64 m stand-in skater (until lane K2's figure): a capsule with a facing mark (a chest plate on its +x side) built
facing +x, and a separate unit stick bar along +x (the caller scales and turns it). Not the engine's walking figure.
`key`: a palette key, or the team's Color (the cartridge's colour_hex, on the palette's white: lane E1).
```

**§8** (above `const PUCK_H: float = 0.08                 # AJamPuck::InitPuck: 0.08 m tall (HalfHeightM 0.04)`)

```text
thirdjam's puck (K3 round 10), as AJamPuck::InitPuck makes it (S/JamCore/Private/JamPawns.cpp:865-916): the engine's
unit cylinder scaled to 2r x 2r x 0.08 m (game.puck.radius_m 0.12; colour_hex #111111: the palette's black), its node at
the puck's bottom (the cylinder from y = 0 to 8 cm; thirdjam centres it 4 cm up). And its kit, R-0016's SM_PuckDisc
(/JamAssets/Props, exported by lane K6: hk-arena .tl/arena-export/meshes/SM_PuckDisc.glb), which AJamPuck::PlaceDiscOnIce
keeps 0.4 cm over the ice under the puck whatever its height (:1019-1025): section 0 a low dome 42 cm across and 2.7 cm
high (its profile read from the export: radius 0.21 m at 0.2 cm, 0.18 at 1.1, 0.15 at 1.8, 0.12 at 2.3, 0.06 at 2.6, the
top 2.7 cm) in MI_Trim_PuckHalo (M_Trim, Emissive 18, TeamColour linear (0.75, 1.0, 0.15): a glowing lime that the
camera's tone curve shows near white); drawn here in the palette's `neon_lime` (an emissive key, emit 2.2).
DEVIATIONS: section 1, the beacon skirt (MI_Fx_PuckBeacon: additive, unlit, fading out from 15 m), is not drawn (no
additive surface in the palette); the halo's strength is the palette's emit 2.2, not Emissive 18 under thirdjam's
exposure; the trail (NS_puck_trail) is not drawn.
Returns the puck node; its disc is a sibling node, `puck.get_meta(&"disc")`, which the caller places on the ice.
```

### scripts/cam.gd

**§1** (above `class Spring:`)

```text
thirdjam's follow camera, ported line by line (K3 shell, campaign night 23-24 Nov 2026). Not tuned, not improved.
Source: thirdjam HEAD 8dc713c6, S = Game/Source. `cpp:N` = S/JamGame/Private/CameraFollow.cpp line N,
`h:N` = S/JamGame/Public/CameraFollow.h line N. Everything is in thirdjam's own units and frame: rink metres,
x along the rink, y across (the Godot mapping is the caller's: Vector3(x, height, y)), yaw and pitch in degrees
(yaw 0 = +x, turning towards +y; pitch < 0 looks down). One call of `step` = one simulation frame (h:254-264).

What is ported: StepThirdPerson (cpp:266-599) as the shipped game runs it (StepSimFrame cpp:1210-1253 with the
console variables' defaults cpp:39-78: Boards 1, RigYaw 1, KeepHuman 0.31, CornerLift 3, KeepYaw 0, Bound 0), with
FJamSpring (cpp:80-100), FJamCameraFilter (cpp:102-125), the boards' inset (cpp:181-233), FarNetLeadDeg (cpp:250-264),
RayToBoards (cpp:601-611), BoardsViewTarget (cpp:613-668), FrameFraction (cpp:978-985).
Not ported (DEVIATIONS in the lane report): KeepHumanInFrame (cpp:670-873) and the A186 bound (cpp:406-490): with
the boards view on, StepThirdPerson zeroes KeepHuman and CornerLift itself (cpp:269-275) and jam.camera.Bound is 0,
so neither runs in the shipped game; `settings()` refuses a setting that would turn one on. The punch and the kick
(cpp:1257-1287) belong to stair step 3 (contact). Box follow (cpp:1231-1249) needs penalties: not in the gym.
```

**§2** (above `static func settings(cart_cam: Dictionary) -> Dictionary:`)

```text
FJamCameraSettings (h:19-252) as the shipped game's StepSimFrame fills `Live` (cpp:1210-1230). The cartridge's
game.camera supplies distance, height, look-ahead, lag, fov (FromCartridge cpp:21-34); absent keys keep the
FJamCameraConfig defaults (S/JamCore/Public/JamCartridge.h:650-661).
```

**§3** (above `func step(frame: Dictionary) -> Dictionary:`)

```text
One simulation frame of StepThirdPerson (cpp:266-599). `frame`: {"pos": Vector2 (the human, rink metres),
"yaw": degrees (FMath::RadiansToDegrees(S.Yaw), HokejGameMode.cpp:1563), "rink": {"L","W","R"},
"net": Vector2 (GetFarNetWorldCm / 100, HUDFeed.cpp:8-12)}. Returns the pose {"pos", "height", "pitch", "yaw"}.
```

### scripts/hud/ability.gd

**§1** (above `const ABILITY_SLOT_W := 440.0`)

```text
Lane A84 (R-0041 point 3) and A188 in thirdjam: "F: SHOTGUN  READY" on a dark plate above the radar, right-aligned with
it, 440 wide (AbilitySlotW, HUDWidget.cpp:43), the cooldown fill along its foot; yellow while armed or a shield runs, paper
when ready, grey while it cools down. The feed is AHokejGameMode's (HokejGameMode.cpp:1590-1613): the kind held (the
slot's), or the one still armed, or a running shield; its state ON n.ns / NEXT SHOT|HIT|PASS / ARMED / ns / READY, and
"  xN" charges. Hidden while the human holds nothing.
```

**§2** (above `static func ability_feed(hu: Dictionary, abilities_: Array, now: int, names_: Dictionary = {}) -> Dictionary:`)

```text
The plate's words and fill for the human `hu` at `now`: {} when he holds nothing, else {text, ready01, live}.
`names_` (lane H2d): the skin's ability_names: the plate says the game's own word for the kind (G1's "F: CANNON"), else the core's id.
```

### scripts/hud/barks.gd

**§1** (above `const R := preload("rules.gd")`)

```text
thirdjam's barks (lane K5, round 4; HEAD 8dc713c6, `jam.Barks` -1 = the cartridge's game.barks, here enabled at "normal";
`jam.hud.BarkLane` 1): a skater's short line in a bubble. The picker (FJamBarkPicker, BarkSystem.cpp:182-328) over the
1,340 lines of the bank (data/hud_barks.json = BarkData.inl = Content/Barks/barks.json); the triggers (UJamBarkSystem,
BarkSystem.cpp:418-505): a goal, the human's check landed, the human knocked down, a faceoff, the end, a near miss (a shot
then a board hit by the net within 45 frames), a steal (the puck changes team), a stall (5 s untouched, slow). The lane
(UJamBarkWidget, BarkWidget.cpp:18-38, 240-370): one bubble a side, the newest of a team whose speaker is in the frame and
within 24 m, standing in the scoreboard's row (bottom at y 84) 262 units beside the centre, never over a figure, the puck or
the human's box, never while a HUD line of words stands; held 150 frames, faded over 90; cleared by a pause. One look
(HUDOneLook.cpp:241-251): the panel at 0.9, a 4-unit corner, the team's edge 2 wide, Bold 18 in the text colour.
Its stream is its own (seeded from the match's seed): presentation only, never in the state hash.
```

**§2** (above `func paint(lay, snap: Dictionary, vw: float, vh: float, now: int, paused: bool, line_up: bool, keep: Rect2, team_col: Ar`)

```text
The lane (Layout, BarkWidget.cpp:240-370). `line_up`: a HUD line of words stands this frame; `keep`: the human's box.
Returns what it drew: [[team, text], ...].
```

### scripts/hud/captions.gd

**§1** (above `const R := preload("rules.gd")`)

```text
thirdjam's commentator, its words only (lane K5, round 2; the voice is lane K6's). The booth's picker
(FJamCommentaryPicker, CommentarySystem.cpp:115-597; constants CommentarySystem.h:29-45) over the 415 lines of thirdjam's three
banks (commentary_lines.gd, generated), fed by the sim's frame events and the game mode's `period` and `win` / `lose`; the
caption strip (UpdateCommentary HUDWidget.cpp:1467-1525; one look HUDOneLook.cpp:80-81): OL plate(0.72) padding 16 / 6, Regular 18
TextDim, docked bottom centre 24 over the edge, held for the line's length then faded over 30 frames, gone under a pause.
Its stream is its own RandomNumberGenerator seeded from the match's seed (thirdjam salts it with the wall clock: not
deterministic there): presentation only, never the sim's generator, never in the state hash. The cartridge has no
game.commentary: enabled at "normal" (cooldown scale 1, least priority 1).
```

**§2** (above `func _init(game: Dictionary, seed_value: int, rows: Variant = null, names: Array = [], plural: Array = []) -> void:`)

```text
`rows`: the bank of lines (null = thirdjam's three banks, commentary_lines.gd); `names`: the skin's team names ([] = the bank's);
`plural`: the skin's team_plural ([] = guessed). Lane E1b: said as the person sees them (skin.gd teams_of).
```

**§3** (above `func step(snap: Dictionary, extra: Array) -> Dictionary:`)

```text
One sim frame of the booth (HandleBusEvent + HandleSimFrame, cpp:756-808): the frame's events, the held pass, the game
mode's events (`extra`: [[name, kind], ...]), then Resolve. Returns the line started or {}.
```

### scripts/hud/cards.gd

**§1** (above `const R := preload("rules.gd")`)

```text
The take and the MATCH card (thirdjam HEAD 8dc713c6). The take is AHokejGameMode's, not the sim's period: ComputeTake =
clamp(1 + the lead's score, 1, score_to_win) in first_to (HokejGameMode.cpp:372-383), updated only on a Playing frame
(cpp:1679) and forced at a match's build and restart (cpp:560, 815); a change broadcasts `period` (cpp:385-397), on which
the controller opens the MATCH card for TakeCardFrames 150 (DirectorsCallController.cpp:96-100, 168-191; .h:31).
The card (UJamDirectorsCallHudWidget, DirectorsCallWidget.cpp:597-613, 639-737; one look HUDOneLook.cpp:204-232):
"MATCH 1" over "PERIOD n   -   FACEOFF   -   <LEVEL>", centred at y 190 under the scoreboard; it goes on the first frame
after a faceoff countdown it has seen (jam.hud.CardAtDrop 1), never on the end card.
```

### scripts/hud/charge.gd

**§1** (above `const R := preload("rules.gd")`)

```text
Two of lane A213's wave-2 pieces (HEAD 8dc713c6), presentation only:
  - the pass's target ring (UpdateChargeLook, HUDChargeLook.cpp:37-112): while he holds the pass with the puck, a ring
    under the mate it would go to, in his team's colour, CarrierRingRadiusM x 1.15, z -1; when his pass count grows the
    ring goes under the mate it was aimed at (the last held target, else the tap's) and stays while that pass flies
    (Puck.PassFrames > 0, PassBy = him), at most 45 frames. Never under a skater in the box (lane A224). The held shot's
    line is off at HEAD (jam.hud.ShotLine 0, HUDChargeLook.cpp:26).
  - the teaching pulse (UpdateTeach, HUDTeach.cpp:42-98): the pass (he carries, the mate a full pass along his facing
    would go to stands 6 to 30 m off, ahead) and the check (no puck, an opposing carrier within 2.6 m inside 60 degrees
    of his facing), each at most 3 times a session, 90 frames, 900 apart, never after he did it; not while counting
    down, not while down, not in the draw's first 60 frames. With the panel (jam.hud.ControlsPanel 1) there is no pill:
    the panel lights the row it teaches (HUDTeach.cpp:99-106, HUDControlsPanel.cpp:318-331).
The targets come from the core's glue (SNAPSHOT.md v1.2 Controls). DEVIATION (round 5): thirdjam asks
UJamSim::HumanPassTarget (JamSim.cpp:3213: the mate in pass.aim.cone_deg 25 of the stick at the held power; for the
teach, of the facing at the full power); the snapshot carries BestPass (JamSim.h:903: the bots' pick, no cone). Both
reads take `PassTargetHeld` / `PassTargetFacing` first (the two HumanPassTarget calls, asked of lane K1) and fall back
to `PassTarget` until they land.
```

**§2** (above `func teach(snap: Dictionary, phase: String, me: int, f: int, counting: bool, down: bool, last_drop: int, pressed_hit: bo`)

```text
The teaching pulse this sim frame: 0 the pass, 1 the check, -1 none (HUDTeach.cpp:48-89). `pressed_hit`: the step's
own check or lift (JamControls::LastHumanButtons, cpp:60).
```

### scripts/hud/flow.gd

**§1** (above `const R := preload("rules.gd")`)

```text
thirdjam's match flow on the screen (lane K5, round 2), HEAD 8dc713c6, every cvar at its default:
  the GOAL banner   HUDGoalBanner.cpp:30-252: device B's T_UI_Banner_Goal (exported, assets/hud/) stretched into
                    760 x 176 at (0.5 W, 0.30 H) (0.205 H when the scorer stands under that band), tinted lerp(white, the
                    scoring side's colour, 0.25); in over 12 frames, out over 12, gone 6 before the pause ends; a punch
                    1.25 -> 1 in, 1 -> 0.96 out; only when a score grew; on the match-ending goal it plays in the end card's wait;
  the end card      HUDWidget.cpp:446-497, 772-799, 952-982; HUDEndWait.cpp; HUDEndStats.cpp; HUDOneLook.cpp:123-181:
                    after 1.9 s, a panel 704 wide at (0.5 W, 0.4 H): YOU WIN / BEATEN / NO WINNER, YOU  a : b  THEM, the
                    stats table, the team rule, the key caps R / VIEW REMATCH, ESC / START MENU;
  IN THE BOX n      HUDWidget.cpp:578-586, 836-845 (jam.cam.BoxFollowsPlay 1).
Presentation only. Time is the HUD's own frame count where the sim stands still (the end phase).
```

### scripts/hud/front.gd

**§1** (above `const R := preload("rules.gd")`)

```text
thirdjam's front end, the path a first-time player takes to the puck (UJamMenuWidget, MenuWidget.cpp:683-967, 1266-1452,
2138-2150, 2378-2433; MenuFlow.cpp:387-425; grid MenuWidget.h:66-105), drawn before the match's frame 0 while the kernel's
frame holds the pack paused (1.24). Two screens:
  LANDING  the backdrop (device B's T_UI_MenuBackdrop) under the scrim; HOKEJ (Black 176 tracked 120, shadow 0 / 6), the team
           rule 480 x 6, HOCKEY WITH THE WHISTLE TAKEN OUT. (Bold 24 tracked 160), PRESS ENTER (Black 28 tracked 200,
           breathing 0.55 to 1 every 1.6 s), OR A, OR A CLICK; footer ENTER / A START, CLICK START. Enter or a click: HOME.
  HOME     the header (T_UI_HeaderBar 80 high: HOKEJ, the rule, HOME, LEVEL and its chip), the team rule 8 under it, the left
           column 640 wide at x 96: PLAY NOW (Black 48) with "ONE MATCH, <LEVEL>.  ENTER / A, OR CLICK.", the level row
           ROOKIE / PRO / ALL-STAR (the lit one on T_UI_Segment_Lit), the level's line; the right column 704 wide: ONE
           MATCH and its words, YOUR STICK; footer ENTER / A PLAY, LEFT / RIGHT LEVEL, UP / DOWN MOVE, ESC / B TITLE.
           Left / Right step the level, Enter plays, Esc goes back to the title.
SEASON, MODES, PLAY WITH A FRIEND, CONTROLS, SETTINGS, CREDITS and QUIT are not ported (HUD.md lists them).
```

### scripts/hud/hint.gd

**§1** (above `const R := preload("rules.gd")`)

```text
The pack's hint slot (lane H2b, 25 Nov): one line a game's own script asks the base to show, never over the commentator's caption (G1's own bottom label covered it):
    ctx.root.set_meta(&"rink_hint", "F: BUBBLE  Green spots reload it")    # every frame it should show; "" = none (screen.gd hands it to hud.gd as ui "pack_hint")
The slot: a dark plate left-aligned with the controls panel just above the room the panel keeps (rules.gd PANEL_RESERVE_H); it stays put, and moves up past the caption's two places at their widest and the caption drawn this frame.
```

### scripts/hud/hud.gd

**§1** (above `const R := preload("rules.gd")`)

```text
thirdjam's match HUD on our screen (lane K5, round 1: the in-play set). UJamHudWidget::RefreshFromFrame (HUDWidget.cpp:895-1084) as HEAD 8dc713c6 ships it, every console variable at its default, in the one look (jam.hud.OneLook 1, HUDOneLook.cpp):
the score plates, the rings on the ice (yours, the carrier's, yours doubled while you carry, the loose puck's), the YOU chevron and tag, the far-net and own-net badges with their distances, the off-screen puck arrow, the edge-slot rule,
the controls panel, the radar, the faceoff dial and its hint. Positions in layout units (1920 x 1080 at 16:9, as Slate's DPI curve).
Presentation only: it reads the snapshot and the buttons and writes nothing back. One call a frame: `frame(snap, ui)` after the camera has stepped (main.gd). The rules are rules.gd's.
```

**§2** (above `if f != booth_frame:`)

```text
the booth: once a sim frame (the end phase holds its frame: its events are not heard twice); the game mode's events
`period` (UpdateTake's broadcast, HokejGameMode.cpp:385-397: at the build, a restart and every take change) and `win` / `lose`
```

**§3** (above `var hint_up: bool = b_count and faceoffs_this_session <= R.FACEOFF_HINT_COUNT and not R.faceoff_cue_hidden_in_box(int(hu`)

```text
================================================================ the commentator's caption (cpp:713-722, 1467-1525); the one-line rule:
the faceoff hint wins over it (HUDOneLine.cpp)
```

**§4** (above `func _rings(snap: Dictionary, phase: String, me: int, hu: Dictionary, carrier: int, counting: bool, hbox: Rect2, f: int,`)

```text
---------------------------------------------------------------- the rings (UpdateYours cpp:1601-1706, UpdateCarrierCues cpp:1895-1932,
UpdatePossession HUDPossession.cpp:84-210): each ring as [Rect2, Color]
```

**§5** (above `var grace: bool = carrier >= 0 and bool((snap.get("Controls", {}) as Dictionary).get("CarrierInTakeGrace", false))`)

```text
the take grace (UpdateCarrierCues): the carrier's ring closes from 1.5 x unless the grace was won by his own hit
(cpp:1904-1908: UJamSim::InTakeGrace, the core's Controls.CarrierInTakeGrace, which includes the frame the puck is won in;
on that frame TakeGraceLeft is still 0 and the ring stands at the full count)
```

**§6** (above `func _ring(r: Rect2, c: Color) -> void:`)

```text
T_UI_Ring (the film leader's ring, an AI-made texture we do not have): drawn here as its parts read on thirdjam's stills
(h43-02-faceoff-stands.png): a chalk ring with an ink edge, the home blue and away orange arcs inside it, four ticks.
The ground ring: T_UI_RingPlain (exported from thirdjam's project, 512 px) stretched into the ellipse's box and tinted (MakeGroundRing cpp:351-361); without the picture, the band drawn to its measure.
Lane H2b: none in the top view (the overview straight down: the rings are the follow camera's, E1b's stills drew yours as a large ellipse off the figure).
```

### scripts/hud/kit.gd

**§1** (above `const R := preload("rules.gd")`)

```text
thirdjam's front-end makers (FJamMenuLook, MenuWidget.cpp:224-351), drawn on a TLHudLayer with device B's kit as
exported to assets/hud/ (each a box brush at half its pixels, margins 0.2 / 0.35: KitOr, MenuWidget.cpp:229-240):
the item (a kit button plate, the 8-unit focus bar, the label), the panel (the team rule over the kit panel), the team
rule, the key hints (FillHints). Shared by the pause card and the menu.
```

**§2** (above `func hints(at: Vector2, pairs: Array, align: float = 0.0) -> void:`)

```text
FillHints (MenuWidget.cpp:334-351): key caps (white @ 0.14, padding 8 / 3, Black 14 tracked 40) and the action (Bold 14
tracked 60, dim), 32 units between pairs. `at` is the row's left (align 0) or centre (align 0.5), its vertical middle.
```

### scripts/hud/markers.gd

**§1** (above `const R := preload("rules.gd")`)

```text
thirdjam's distance badges (UpdateMarker cpp:1724-1805, UpdateOwnMarker cpp:1952-2000, ApplyOwnLabelRule HUDOneLine.cpp:32-59,
UpdatePuckMarker cpp:1306-1368), the edge-slot rule (ResolveEdgeSlots cpp:1374-1465) and the label plates
(UpdateLabelPlates cpp:1284-1304, one look HUDOneLook.cpp:95-98). Groups are dictionaries; build() places, paint() draws.
```

**§2** (above `func _measure_group(g: Dictionary, delta: Vector2) -> Array:`)

```text
[box, anchor position, active]: the parts that show (puck: arrow 16 and its text 12 a char x 26; far: diamond 12, arrow 12, text 12 x 26;
own: diamond 8, arrow 10, text 10 x 22).
```

### scripts/hud/panel.gd

**§1** (above `const R := preload("rules.gd")`)

```text
thirdjam's controls panel (lane A222; HUDControlsPanel.cpp, HEAD 8dc713c6): bottom left on the safe margin, all match,
while play runs. The front end's panel (FJamMenuLook::MakePanel): the two team colours along its top edge (3 units),
the panel fill at 0.78 with the 4-unit corner and the hairline edge; a head (a dot in his team's colour, WITH THE PUCK /
WITHOUT THE PUCK), the possession half (fading in over 6 frames when it swaps), a hairline, the always half. A row: a
light keycap (84 x 22 at least, the key in Black 14 tracked 40, ink) and the verb (Bold 16 tracked 60). A lit row
(its button down) takes the menu's focus: the away orange cap and white type. The teaching pulse (HUDTeach.cpp, `teach`
0 = the pass, 1 = the check; cpp:318-331) lights its row: the take-yellow keycap, ink type, the word in yellow.
```

### scripts/hud/pausecard.gd

**§1** (above `const R := preload("rules.gd")`)

```text
thirdjam's pause card (UJamDirectorsCallWidget, DirectorsCallWidget.cpp:170-232, 373-382, 506-530, 772-792; HEAD 8dc713c6)
on the kernel's frame pause (1.24: ctx.own_pause, TLHud.on_paused, ctx.input.menu_keys, ctx.resume, ctx.leave_game).
The scrim (black 0.62) and a panel 808 wide (padding 32 / 24): PAUSED (Black 40 tracked 120), "PERIOD n   -   PRO (YOUR
LEVEL)" (Bold 14 tracked 60, dim), the items at 22 (RESUME, CHANGE A RULE, RESTART, CONTROLS, QUIT TO MENU), the two
mouse buttons by possession (Bold 18 tracked 60, line height 1.25), EVERY KEY, AND TO REBIND IT: CONTROLS, the team rule,
the key hints ESC / START RESUME, ENTER / A SELECT, R / VIEW RESTART. Up / Down move, Enter selects, Esc resumes; QUIT
TO MENU asks LEAVE THE MATCH? first (NO, KEEP PLAYING has the focus).
```

### scripts/hud/rules.gd

**§1** (above `const INK := Color("#0e1014")`)

```text
thirdjam's HUD rules, pure (no camera, no node): the constants and the show rules of UJamHudWidget as HEAD 8dc713c6
ships them, ported line by line. "h:" = Game/Source/JamGame/Public/HUDWidget.h, "cpp:" = Private/HUDWidget.cpp, other
files named. Every console variable is at its shipped default (the value written beside it); nothing here is tuned.
The headless tests (tests/bot_hud_rules.gd) call these on recorded snapshots.

---- the look (FJamUiStyle, MenuStyle.h:28-39; FJamMenuLook, MenuWidget.cpp:71-80). sRGB.
```

**§2** (above `static func scaled(r: Rect2, k: float) -> Rect2:`)

```text
jam.hud.SwellAtHit 0: a grace won by the carrier's own hit keeps the ring's size (h:462).
A ring's box grown about its centre by k.
```

**§3** (above `const KEYCAP := {"Shoot": "LMB", "CrossCheck": "LMB", "Pass": "RMB", "Check": "RMB", "Poke": "SPACE", "Deke": "WHEEL", "`)

```text
---------------------------------------------------------------- the controls panel's rows (HUDControlsPanel.cpp:140-183)
The default bindings' first keys (InputMapping.cpp:98-120 through KeyName cpp:608-627 and FirstName HUDControlsPanel.cpp:49-54).
```

**§4** (above `static func panel_swap_step(st: Dictionary, with: bool, press: bool, frame: int, hold: int = PANEL_HOLD_FRAMES) -> bool:`)

```text
FControlsPanelSwap::Step (HUDControlsPanel.cpp:87-104): the half shown. state: {shown, last_swap, loss_start, last_frame}.
True on the frame the half swaps.
```

**§5** (above `static func teach_step(st: Dictionary, due: bool, did: bool, frame: int) -> bool:`)

```text
One sim frame of a kind's rule (TeachStep, h:604-616): true while its pulse shows this frame. `st` is FTeachState
{shows, done, shown_at, last_end}; `due`: the moment applies; `did`: he did the thing this frame. Pure.
```

### scripts/hud/screen.gd

**§1** (above `const Hud := preload("hud.gd")`)

```text
The seam between the shell (main.gd, lane K3) and the screen (lane K5): ONE call a drawn frame,
  screen = Screen.frame_of(screen, ctx, snap, human, last_in, last_raw)
made in main.gd's _draw() in match mode. It makes the pack's TLHud and its painter layer on the first call, reads what the
HUD's rules need from the buttons (UpdateControlsPanel's gathering, HUDControlsPanel.cpp:339-411) and hands the frame to
hud.gd. Presentation only.
```

**§2** (above `static func start_level(ctx, core) -> String:`)

```text
Called by the shell on frame 0 before the core's first step (main.gd _pack_tick): the level HOME chose, as the record holds
it, set on the core and the match made again on the same seed (PLAY NOW opens the cut at that level, MenuWidget.cpp:2138-2150).
Returns the level id applied, or "" (none chosen: data/match.json's level stands).
```

**§3** (above `static func applied_level(ctx, fallback: String) -> String:`)

```text
The level the shell applied this run (start_level's meta), else `fallback` (data/match.json's): the one the MATCH card shows,
in a bot, a replay and a played run alike.
```

**§4** (above `static func frame_of(screen, ctx, snap: Dictionary, human, last_in: Dictionary, last_raw: Dictionary, head = null):`)

```text
`head`: the human figure's head socket in the world this frame (K3's match_view.head_world(HumanIndex)), or null: the
chevron and the YOU tag anchor to it (HumanHeadWorld source 2, HUDWidget.cpp:1089-1131); without it they look for a figure
with sockets themselves, else stand on the stand-in's top.
```

**§5** (above `func paused_tick(_frame: int) -> void:`)

```text
One drawn frame while the kernel's frame holds the pack paused (TLHud.on_paused): the front end before the match, else
thirdjam's pause card over the HUD as it stood (its clocks still). Keys: ctx.input.menu_keys().
```

**§6** (above `func head_world(ctx, snap: Dictionary, given = null):`)

```text
HumanHeadWorld (HUDWidget.cpp:1089-1131, jam.hud.MarkerAnchor 1): the figure's head_socket, lifted YouMarkerHeadLiftCm (-18 cm)
along the head's own axis (the "head" bone to the socket); null without a figure that has sockets (the stand-in: its bounds).
The figure is looked for every 60 frames (a mesh may arrive later), as thirdjam looks again at a bounds answer.
```

**§7** (above `static func ui_of(snap: Dictionary, _human, last_in: Dictionary, last_raw: Dictionary) -> Dictionary:`)

```text
What the buttons say this frame (UpdateControlsPanel's gathering, HUDControlsPanel.cpp:339-411), read from the core's glue:
possession as the buttons read it (JamControls::HasPuckForButtons, computed in the glue: the snapshot's
Controls.ButtonsWithPuck, SNAPSHOT.md v1.2; absent = false), the verbs the last step resolved (the FJamInput the human
got, `last_in` = rink.last_human_input()), the keys down (`last_raw.Down`, Unreal key names) and the cross-check's hold
(Controls.CrossHoldSteps). `_human` is unused (the shell has no button resolver of its own since the raw glue).
```

### scripts/hud/skin.gd

**§1** (above `const SCHEMA: String = "tl.rink.skin/1"`)

```text
The game's skin (lane E1, 24-25 Nov): every word and bank of the screen that belongs to one game and not to the base,
read from data/skin.json (required; schema tl.rink.skin/1; unknown keys are errors, a key left out keeps the default below, which
is hokej's: thirdjam's own words). The pitch, the rules, the teams and their COLOURS are the cartridge's (the one source
of truth: game.teams[].colour_hex colours the figures, the HUD rings, plates, barks and markers); the skin names the
teams in words only. data/match.json picks the cartridge (`cartridge`) and the level (`difficulty`).

  schema       "tl.rink.skin/1"
  title        the game's name on the title and on HOME's header ("HOKEJ")
  tagline      the line under the title ("HOCKEY WITH THE WHISTLE TAKEN OUT.")
  about        HOME's ONE MATCH lines, a list of strings
  team_names   [team 0, team 1] in words ("Blue", "Orange"): the commentator's lines say these where thirdjam's bank says
               blue / orange, as written (capitals as the skin has them, at the start of a line and inside it). A colour word
               that is not its team's colour in the cartridge ("Blue" on a red team: the base's words left in a user's
               skin) is said as the team's own colour word ("Red"): a line never names a colour the person does not see.
  team_plural  [bool, bool] (lane E1b, optional): the name is a plural ("Sharks") and the lines say "Sharks shoot!", "for
               the Sharks". Absent: guessed from the name (its last word ends in a single s: "Glare Foxes", "Gulls").
  levels       [[label, line] x 3]: the level row's words for rookie, pro, all_star, and the line under the row
  commentary   "builtin" (thirdjam's three commentary banks, scripts/hud/commentary_lines.gd), "off", or a file in data/
               ({"lines": [[id, event, kind, team, priority, cooldown_frames, text, duration_frames], ...]})
  ability_names  (H2d, optional) the game's word for each trick of game.abilities by the core's kind ({"shotgun": "cannon"}: "F: CANNON  READY"); a kind left out keeps the core's id
  barks        a file in data/ with the skaters' barks ({"lines": [[id, situation, speaker, tone, text], ...]}: hokej's is
               hud_barks.json, thirdjam's bank) or "off"
```

**§2** (above `static func of(ctx) -> Dictionary:`)

```text
The skin of the pack (data/skin.json), validated: the problems (unknown key, wrong type or shape) are pushed as errors (a run
with them is not clean) and the default stands for that key. A bank file that is not in data/ is read_json's error.
```

**§3** (above `static func teams_of(s: Dictionary, game: Dictionary) -> Array:`)

```text
The teams as the person meets them: [[name 0, name 1], [plural 0, plural 1]]. The skin's names as written; a bare colour
word that is not its team's colour in the cartridge (game.teams[].colour_hex) becomes that colour's word ("Blue" on a
red team reads "Red"; E5 job 1 heard "It's in, for blue!" when red scored).
```

**§4** (above `static func team_words(text: String, names: Array, plural: Array = [false, false]) -> String:`)

```text
A line of thirdjam's bank in this skin's team words. thirdjam's "Blue" / "blue" / "Orange" / "orange" (a team: not "the
blue line") become the team names as written. A plural name ([plural 0, plural 1]) takes "the" inside a sentence ("for
the Sharks"), the verb after it in the plural ("Sharks shoot!", "the Gulls are a skater short") and "themselves" for
"itself". With thirdjam's own names (Blue, Orange, singular) the line is unchanged.
```

**§5** (above `static func _plural_verb(w: String) -> String:`)

```text
The plural of a verb in the third person singular ("shoots" shoot, "finishes" finish, "is" are, "has" have); any other
word as it stands ("on", "to", "playing").
```

### scripts/human_input.gd

**§1** (above `const KEYS: Dictionary = {`)

```text
The human's devices, read for the core (K3 round 5). The rules that turn them into FJamInput (thirdjam's ReadHumanInput,
ApplyButtons, FJamButtonResolver, the aim anchor, the S lock, signals 1-4, R) live in the core's glue
(engine/cores/rink/GAMEMODE.md, RinkCore human mode "raw"); this script only reads the keys, the mouse buttons, the wheel
and the cursor into the raw shape RinkCore.set_raw_input takes: Down / Pressed as Unreal key names (FJamBindings::Defaults,
InputMapping.cpp:98-120; the signal keys One..Four, SignalSystem.cpp:46), Axis, CursorOnIce, CursorPx, CursorHitM,
CameraYaw. MouseDeltaPx and StickAxis stay absent (the cursor is always shown; no gamepad).

Unreal key name -> the pack's action and the Godot key or mouse button that is that key.
```

**§2** (above `static func raw(input, cam_yaw: float, cursor_ok: bool, cursor_px: Vector2, cursor_hit: Vector2) -> Dictionary:`)

```text
This frame's devices in RinkCore's raw shape. cam_yaw: the camera's yaw of the last sim frame, radians in rink
coordinates (ReadHumanInput reads the camera, HokejGameMode.cpp:943-946).
```

### scripts/main.gd

**§1** (above `const Cam := preload("cam.gd")`)

```text
Hokej: thirdjam's whole match in our engine (K3 shell, round 3; docs/design/DIRECTIONS.md). The simulation and the bots
are thirdjam's own C++ (lane K1's RinkCore, `ctx.cores.open("rink")`, engine/cores/rink/SNAPSHOT.md): the regular cartridge,
5 v 5, first to 3, at the level of data/match.json. This pack keeps the keys and the drawing: thirdjam's camera (cam.gd,
equal to thirdjam's rendered camera within 0.54 cm, round 2), the devices for the core's raw glue (human_input.gd), and
thirdjam's figure through thirdjam's pawn for every skater (match_view.gd: lane K2's TLRigSkater and skater_pawn).
The order inside a frame is AHokejGameMode's (StepOnce, HokejGameMode.cpp:1636-1712): the human's input is read through
the camera of the last sim frame (ReadHumanInput cpp:937), the sim steps, the figures take the frame (ApplySimFrame), then
the camera steps once on it (PushPresentation -> StepSimFrame, CameraFollow.cpp:1183). The engine's physics interpolation
draws camera and figures between the 60 Hz frames (TickComponent cpp:1319-1337, ApplyRender JamPawns.cpp:824-846).
Two proof modes, chosen by a key-less action pressed on frame 0 (a bot's): `gym` (one skater on empty ice under the
other nine parked: the control rules' tests), `replay` (thirdjam's own logged path through our camera, round 2).
```

**§2** (above `var hall_goals: bool = not marks.is_empty() and absf(float(rk["length_m"]) - 90.0) < 0.01 and absf(float(rk["width_m"]) `)

```text
E5 (25 Nov): the hall's own goals stand where a 90 x 45 rink has its goal lines. On any other rink (a user's 50 m
pond) they stood outside the boards while the core scored at +-(L/2 - 4): the rink's own goals are drawn there.
```

**§3** (above `Human.declare(ctx.input)`)

```text
JamControls::ButtonContext's numbers (InputMapping.cpp:474-486): UJamSim::CarrierReachM = max(shot.reach_m, SkaterRadius 0.4 +
stick.reach_m 1.2 (FJamStickConfig default)) + 0.05 (JamSim.cpp:862-869); FJamPassConfig defaults SaucerHalfFrames 8,
PowerFullFrames 30 (JamCartridge.h:356, 363): the regular cartridge has no game.pass
```

**§4** (above `const TOP_FOV: float = 60.0`)

```text
The "top" view (the Foreman's critic and a person's overview): straight down on the rink, high enough that the whole
sheet and its boards fit the picture with a 6 % margin (the view's vertical angle 60 degrees, the window's aspect), and
its near plane 4 m over the ice. E5 (25 Nov) put it 70 m up with the near plane at 50 m: above thirdjam's roof it was
black, and at 20 m and below the hall's trusses, lamps and clock still crossed the rink. Now everything higher than
4 m (roof, trusses, the clock, the goal lamps) is cut away; the boards (1.2 m), the glass and the figures stay.
```

**§5** (above `func _arena_marks() -> Dictionary:`)

```text
With thirdjam's hall: the colours of RinkActor's markings sections 2 and 3 (arena.json rink_surfaces.Markings: its four
materials, sections 0-3; RinkActor.cpp:650-659), for the marks the hall's ice does not paint (gen/tj_rink.gd). Empty
without the hall (the pack's own rink and palette).
```

**§6** (above `mode = "gym"`)

```text
the gym (the control rules' tests): the same core, the other nine parked (RinkCore.set_bot_mode, SNAPSHOT.md v1.1),
and the opening faceoff stepped through here so the hand starts on open ice at the drop (a test stand, not a match)
```

**§7** (above `const LIGHT_SETTLE: int = 3`)

```text
AHokejGameMode::TickLightHold (HokejGameMode.cpp:632-678): the picture is held black until the light rig has been
visible LightHoldSettleTicks (3) ticks, then fades in over jam.screen.FadeSeconds 0.35 s (HokejGameMode.h:250-262). Our
hall's light is there from the first frame: black on frames 0-2, then 21 frames of linear fade (PlayerCameraManager::
StartCameraFade 1 -> 0). Presentation only: the sim steps on (the faceoff countdown runs under it), the hash cannot move.
```

**§8** (above `func _replay_tick() -> void:`)

```text
The proof mode of round 2: one row of thirdjam's JAMCAM log a tick (one StepSimFrame there, its hit-stop frames already
absent): the human's PosM and YawDeg set from the row, then our camera steps. Nothing simulates.
```

**§9** (above `func _draw_figures() -> bool:`)

```text
The figures and the puck of this sim frame (the match: the show, the pawns, the puck; HokejGameMode.cpp:1664-1707).
True when a hit-stop holds the presentation frame.
```

### scripts/match_view.gd

**§1** (above `const DT: float = 1.0 / 60.0`)

```text
The match drawn from the core's snapshot (K3 rounds 6 and 8): every skater is thirdjam's own figure (engine/rigs/skater,
TLRigSkater, lane K2) driven by thirdjam's pawn (ctx.cores.view_script("rink", "skater_pawn"): AJamSkater::ApplySimFrame
and ApplyRender, JamPawns.cpp:464-746 and :824-843), one pawn a skater fed its snapshot dictionary each frame, as
AHokejGameMode::StepOnce does (HokejGameMode.cpp:1680-1694). What the game mode does around the pawns for the eye is lane
K2's show object (ctx.cores.view_script("rink", "skater_show"), K3 round 8; GAMEMODE.md rows 20 and 23), the one owner of
that logic: thirdjam's hit-stop picks and routing (HitStopRoute, HitStopPick, HitStopFramesFor, AJamPuck's hold) and the
carrier the screen shows (FJamPuckShow: the carried puck on the blade's socket, the play calls by name).
data/view.json `figures: false` draws the round-3 STAND-INS instead (debugging): a 1.64 m capsule a skater with a facing
mark and a stick bar to the sim's blade.
Interpolation between the 60 Hz frames: the pawn is placed once a sim frame (ApplyRender at alpha 1) and the engine's
physics interpolation draws it between frames, as ApplyRender lerps PrevPos -> Pos (JamPawns.cpp:824-846). A jump the sim
does not move through (a faceoff's reset: PrevPos = Pos there) is not drawn as a slide: the node's interpolation is reset.
```

**§2** (above `func _init(root: Node3D, rink_gen, snap: Dictionary, puck_radius: float, cart: Dictionary, pawn_script: GDScript, show_s`)

```text
`cart`: the cartridge (teams and their colours; the numbers the show reads). `pawn_script`, `show_script`, `hits_script`:
ctx.cores.view_script("rink", "skater_pawn"), ("rink", "skater_show") and ("rink", "hit_read").
```

**§3** (above `var slot: int = int(slot_in_team.get(team, 0))`)

```text
AHokejGameMode's spawn (one AJamSkater a sim skater, its visual a child) and AJamSkater::InitSkater (JamPawns.cpp:395-400):
the team's colour (game.teams[].colour_hex, linear as FLinearColor) and the jersey's number (JerseyNumberFor,
HokejGameMode.cpp:439-444, by the skater's slot in its team in sim order)
```

**§4** (above `const BUS_EVENTS: Array = ["knockdown", "check", "lift", "deke"]`)

```text
The bus events a figure hears (AHokejGameMode::DeliverEvents, HokejGameMode.cpp:1664, before the hit-stop and the pawns),
as K2's verb gym delivers them: OnBusEvent(name, its Who is this figure's skater, where in world centimetres, ...). All
four are ported in the figure since K2's round 4 (contact).
```

**§5** (above `func draw(snap: Dictionary) -> bool:`)

```text
One sim frame of the match, in thirdjam's order (HokejGameMode.cpp:1664-1707; skater_show.gd's header): the bus, the
show's step (HitStopRoute, then FJamPuckShow::StepSim), every pawn's ApplySimFrame, the show's after_pawns (the wind-up
takes, the puck's hold count), the hit read (AJamHitRead::StepSim, cpp:1706: the whiffs, the re-time of a check), every
pawn's ApplyRender, the show's Render (the puck where it is drawn: the shown carrier's blade socket, or the sim's place,
held through a hit-stop; cpp:1736), every figure's look at that puck and its tick, and a carried puck taking its
socket's place again after the tick (AJamPuck::Tick, JamPawns.cpp:959-977), as K2's verb_gym.gd does. Returns whether
the presentation frame is held (the camera and HUD do not step: HokejGameMode.cpp:1710).
```

**§6** (above `const MARKER_LIFT_M: float = -0.18`)

```text
Where skater i's figure has its head for the HUD's marker (UJamHudWidget::HumanHeadWorld, HUDWidget.cpp:1089-1121): the
figure's head_socket, come back along the head's own axis (head bone -> socket) by jam.hud.MarkerLiftCm -18 (HUDWidget.h:322;
the world's up without a head bone). World space (Godot), as drawn this sim frame. Null with the stand-ins (the HUD keeps
its own rule).
```

**§7** (above `func draw_skater(i: int, s: Dictionary, frame: int = 0) -> void:`)

```text
One skater alone (the proof modes: the gym's skater on empty ice, the replay's logged skater): no puck to look at, no
show (no hits, no puck drawn).
```

**§8** (above `func _look_and_tick(i: int, puck_at: Vector3) -> void:`)

```text
The look's puck in the figure's own frame, from where the pawn stands drawn ([LookTick]'s PuckRef: thirdjam's figure reads
the puck actor, placed by FJamPuckShow::Render this frame), then the figure's tick (its animation's one update a frame;
thirdjam ticks it a rendered frame, ours a sim frame: DT 1/60, the law of physics frames). As verb_gym.gd.
```

### scripts/rink_toys.gd

**§1** (above `const ZONE_Y: float = 0.008                 # RinkActor.cpp:698 ZH 0.8 cm`)

```text
The cartridge's toys on the ice (lane E1b, 25 Nov): everything a cartridge can put on the rink besides the rink itself, drawn from the cartridge and the core's snapshot,
never placed by hand. A user's "slow and fast patches and bumpers in the corners" is a game only when a person SEES them (E5 job 2: the core played them on plain ice).
  zones      game.rink.zones[] (slow_ice, fast_ice, bumper, no_shoot, boost_only; rect or circle; `visible` false = not painted): ARinkActor::Build's zone decals (S/JamGame/Private/RinkActor.cpp:668-840, thirdjam HEAD 8dc713c6): a
             flat fill 0.8 cm over the ice (over the markings at 0.6) and a 25 cm rim, the kind's tint x (0.5 + 0.5 x strength), the rim x 1.35; and lane A69's clay ring (cpp:722-780: a ring 6 cm high, 12 cm wide on the outline).
             Ours on the felt ice: the fill is the tint laid over the ice's own white (a tinted patch, the markings under it hidden as thirdjam's decal hides them), the ring stands proud so the edge reads from the game camera, and
             each kind carries its own mark so it reads without its colour: fast ice streaks along the rink, slow ice slush dots, a bumper zone a rubber curb, no-shoot a red cross-hatch, boost-only a plus.
  obstacles  game.rink.obstacles[] (box, pillar, bumper, goal_shield): RinkActor.cpp:1154-1240: boxes and pillars 1.2 m tall in the boards' colour, a goal shield a pale wall `size` wide and 0.3 m deep across the rink, a bumper
             lane A64's rubber bollard (a magenta body, dark base and top bands 3 cm proud, a dark lid with a magenta boss).
  pickups    game.pickups[] on the ice (UJamEffectSystem::GetPickups): the snapshot's `Pickups` list ([{Id, Kind, Pos}], FJamPickupOnIce; RinkCore 1.4, SNAPSHOT.md "The effect system's read-outs"), drawn the frame a pickup lands
             and taken away the frame it is taken. A core without the list (before 1.4): the bus instead, a `pickup_spawn` event (EffectEvents or Events) puts one at its Where, a `pickup_take` takes the one there.
             AJamPickupActor's beacon (S/JamCore/Effects/JamPickupActor.cpp:315-420, JamPickupActor.h:40-80): a turning shape by kind (speed a cone, precision a diamond, heavy_puck a puck, big_puck a ball, reverse_other a cube,
             a custom effect a star) 1.25 m up on a pedestal of light, a ground ring of 1.1 m, the kind's colour (JamEffects::KindColour, JamEffectTypes.cpp:77-87); lowered to 0.35 when a skater or the puck is within
             1.6 m (BeaconHeightFor). A taken pickup shrinks away over 18 frames where it lay.
Presentation only: it reads the cartridge and the snapshot and steps nothing; the match hash cannot move. Colours are thirdjam's linear values on the palette's white (the toon shader multiplies the palette colour by the vertex colour), so the pack makes no material of its own (TLMesh, palette keys).
```

**§2** (above `var fill: Color = ICE.lerp(tint, 0.7 + 0.3 * clampf(s, 0.0, 1.0))`)

```text
the tint over the ice's white, deeper for a stronger zone; the rim darker than the fill (thirdjam's rim is x 1.35 brighter,
cpp:823: on our lit felt ice a brighter rim melts into the white, a darker one draws the edge)
```

**§3** (above `func _kind_mark(mk: TLMesh, kind: String, c: Vector2, circle: bool, hx: float, hy: float, r: float, col: Color) -> void:`)

```text
Each kind's own mark inside the patch (ours: thirdjam's B looks MI_Zone_<kind> carry patterns we do not have), so a
patch reads by its shape as well as its colour. Laid out on a fixed grid: no randomness.
```

**§4** (above `var band: float = 0.14`)

```text
lane A64: a rubber bollard: dark base band (0-14 cm) and top band (106-120 cm) 3 cm proud, a dark lid with a
magenta boss (r x 0.62, 2 cm high), the magenta body between
```

**§5** (above `func frame(snap: Dictionary) -> void:`)

```text
---------------------------------------------------------------- pickups (AJamPickupActor::Sync, cpp:214-247)
One sim frame: the bus's pickup events, then the beacons turned, raised or lowered (ApplyBeacon, cpp:402-420).
```

