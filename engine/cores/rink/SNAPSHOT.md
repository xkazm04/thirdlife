# Rink core snapshot: the per-frame interface (v1.2, 23 Nov 21:00)

**Status: built (v1.4, 25 Nov: additions only; no earlier name changed).** v1.4 adds the effect system's side of the frame:
`Pickups`, `EffectEvents` and `Boosts` (lane H2; "The effect system's read-outs" below). v1.3 (24 Nov) v1.3 adds `PassTargetHeld` / `PassTargetFacing` (K5)
and the playtester's advice `set_advisor` / `advise` (K3); `restart()` now starts a seated playtester's memory again (below). v1.2 adds `set_bot_mode("off")`, `CameraYawDeg`,
the "no pixel" rule, the raw shape's precision rule and the HUD's `Controls` fields (K5). v1.1 adds `set_raw_input`, `set_bot_mode`, `restart`,
`last_human_input`, the snapshot's `Controls`, and the enum tables below; the per-skater dictionary is unchanged. Draft v0 went out at 17:02 for lanes K2 (figure) and K3 (shell); at 17:41 the class below exists
and runs (engine/tools/selftest.d/800-rink-core.sh). The field names are thirdjam's own, read from its source by
`native/tools/gen_fields.py` at build time (the snapshot code is generated from the same list, so the table and the
class cannot disagree). A change will be announced in K1's STANDUP.md.

Source of truth: thirdjam HEAD 8dc713c6, `Game/Source/JamCore/Public/JamSim.h` (line numbers below are that file's).
The proof build compiles the older t5 tree (15 Nov) first; the snapshot shape is HEAD's (what ships).

## Units and frame of reference (thirdjam's)

- Time: one `step()` = one sim frame, `UJamSim::DT = 1/60` s (JamSim.h:492). Timers and `*Frame` fields count frames.
- Space: metres, 2D rink plane. `Pos.x` = along the rink (length, goals at `x = +-length/2`), `Pos.y` = across
  (thirdjam calls it "rink z", JamSim.h:31). Origin = centre ice (JamSim.cpp:887 `Hx = Config.Rink.LengthM * 0.5`).
  The puck alone has height: `Z` (metres above the ice) and `VZ`.
- Yaw: radians in the rink plane, `Forward() = (cos Yaw, sin Yaw)` (JamSim.h:407).
- Godot mapping (K3 decides; suggestion): `Vector3(Pos.x, height, Pos.y)` with one rink metre = one Godot metre;
  thirdjam's UE pawns use centimetres (x100), which is presentation only.
- Team 0 skaters first, then team 1 (`Index` 0..N-1 in game.teams order, JamEventBus.h FJamEventPayload::Who).

## GDScript surface (built)

```gdscript
var core: RefCounted = ClassDB.instantiate("RinkCore")   # a kernel entry for packs is round 4 (not built yet)
var err: String = core.load_cartridge(json_text)    # thirdjam cartridge JSON (hockey.regular.cartridge.json); "" = ok
# or core.set_content_dir(dir) + core.load_cartridge_file("hockey.regular")   (<dir>/Cartridges/<name>.cartridge.json)
core.set_difficulty("pro")                         # rookie | pro | all_star (DifficultyProfile.h); "" = the cartridge's own
core.set_human_mode("input")                       # input (default: set_human_input drives the human's skater) | playerbot
                                                   # | "playtester:<novice|regular|good>[:sprint]" (v1.2: thirdjam's playtester on the human,
                                                   #   seated as its tournament's -player=<kind> [-playersprint]: the same match to the hash;
                                                   #   last_human_input() is its decision each frame) | raw (below)
                                                   # (thirdjam's FJamPlayerBot plays him) | idle | brain (no human; bots only)
core.reset(seed)                                   # the tournament's setup + RunMatch's: FJamSimAdapter (sim + rules, zones,
                                                   # effects) Reset, FJamBrain with the resolved difficulty (JamBotMatch.cpp)
core.set_human_input({"Move": Vector2(1, 0), "bSprint": true, ...})   # FJamInput, keys below; absent key = false / zero
# v1.1: human mode "raw" takes the person's devices and applies thirdjam's game-mode rules (GAMEMODE.md): two-role buttons by
# possession, held keys dead across a change of possession, saucer and brace hold times, camera-relative move, stick aim,
# team signals 1-4, R to restart. This is what the shell should use; "input" stays for scripted FJamInput.
core.set_human_mode("raw")
core.set_raw_input({"Down": PackedStringArray(["LeftMouseButton", "LeftShift"]), "Pressed": PackedStringArray(["LeftMouseButton"]),
	"Axis": Vector2(0, 1), "CameraYaw": cam_yaw, "CursorOnIce": true, "CursorPx": px, "CursorHitM": ice_xy, "MouseDeltaPx": Vector2.ZERO,
	"StickAxis": Vector2.ZERO})                    # Unreal key names (InputMapping.cpp:98-120); held keys in Down, new presses in Pressed
core.set_bot_mode("off")                           # brain (default) | parked (the other nine get no input and stand: bodies on the ice)
                                                   # | off (v1.2: the other nine sit in the penalty box: no body, no contact; the gym)
core.restart()                                     # AHokejGameMode::RestartMatch: same cartridge and seed, a new match
core.last_human_input()                            # the FJamInput the human's skater got on the last step (thirdjam's names)
core.set_advisor("playtester:regular:sprint")      # v1.3 (K3): thirdjam's playtester ADVISES the human's seat, from the next reset
                                                   #   (or from now, memory empty, when set mid-match); "" = off; false = a bad spec
var adv: Dictionary = core.advise()                # v1.3: what it would press on this frame (last_human_input's shape), NOT applied;
                                                   #   {} with no advisor, no human seat or a finished match. Ask before step().
core.step()                                        # one frame (false once the match is over): RunMatch's frame
var s: Dictionary = core.snapshot()                # the frame just stepped (about 0.3 ms for all of it)
var h: int = core.state_hash()                     # FJamSimAdapter::StateHash = UJamSim::StateHash (thirdjam's FNV)
core.state_hash_hex(); core.get_frame(); core.is_over(); core.get_score()   # [team0, team1]
RinkCore.run_tournament(content_dir, "-cartridge=... -seeds=1-10 -trace=1")  # static: thirdjam's commandlet, its log lines
```

`set_human_input` holds until replaced; edge buttons (`bShoot`, `bPass`, `bCheck`, `bPoke`, `bLift`, `bDeke`, `bSpin`,
`bAbility`) are consumed by the next `step()` (thirdjam: "pressed on this frame"). Level buttons (`bShootHeld`,
`bPassHeld`, `bSprint`, `bBrake`, `bCrossHold`) are sent every frame they are held. `Move` and `Stick` are clamped by
the sim, not by us (humans to length 1, JamSim.h:31-34).

## snapshot() shape

```
{
  "Frame": int,            # UJamSim::GetFrame (JamSim.h:698)
  "Phase": int,            # EJamSimPhase (JamSim.h:110): 0 Playing, 1 GoalPause, 2 Over, 3 Faceoff
  "Score": [int, int],     # GetScore(0), GetScore(1) (JamSim.h:700)
  "Winner": int,           # GetWinner (-1 none) (JamSim.h:702)
  "Period": int,           # GetPeriod, 1-based (JamSim.h:672)
  "TimerLeft": int,        # GetTimerFrames: frames left in timer mode (JamSim.h:924)
  "PauseFrames": int,      # GetPauseFrames (JamSim.h:706)
  "FaceoffCountdown": int, # GetFaceoffCountdown (JamSim.h:708)
  "FaceoffDot": Vector2,   # GetFaceoffDot (JamSim.h:710)
  "HumanIndex": int,       # GetHumanIndex (JamSim.h:703)
  "Carrier": int,          # UJamSim::CarrierIndex() (-1 = loose) (JamSim.h:849)
  "Skaters": [ {<FJamSkaterState fields>, "IsDown", "IsStumbling", "InBox", "CanAct", "IsSpinning", "SpinVisualYawDeg"} ... ],
  "Puck": {<FJamPuckState fields>},
  "Events": [ {<FJamSimEvent fields>} ... ],  # GetFrameEvents (JamSim.h:693): this frame's only
  "Pickups": [ {"Id", "PickupIndex", "Kind", "Pos", "SpawnFrame"} ... ],   # v1.4: UJamEffectSystem::GetPickups, on the ice now
  "EffectEvents": [ {<FJamSimEvent fields>} ... ],   # v1.4: UJamEffectSystem::GetFrameEvents: this frame's effect events
  "Boosts": [String, ...],  # v1.4: UJamEffectSystem::GetBoostKindFor per skater ("" = none), skater order
  "Controls": {"PassHoldSteps", "CrossHoldSteps",                 # v1.1: the human's two-role buttons (InputMapping.h:101-108; the HUD badge's fill)
               "IntentKind", "IntentTarget", "IntentIssuedFrame", "IntentFrames",   # the team signal (SignalIntent.h); IntentKind 0 = none
               # v1.2 (K5's HUD), the human's this frame:
               "ButtonsWithPuck",   # bool: thirdjam's two-role rule says "with the puck" (InputMapping.cpp:432-442 HasPuckForButtons:
                                    #   he carries, or the puck is loose and last touched by his team: our pass in flight)
               "ButtonsCarrying",   # bool: he is the carrier (InputMapping.cpp:478)
               "ButtonsInReach",    # bool: the puck within his carrier reach (InputMapping.cpp:479-480, UJamSim::CarrierReachM)
               "PassTarget", "PassTargetAim",   # the mate a flat pass pressed now goes to (-1 none) and its aim point (JamSim.h:903 BestPass)
               "SaucerTarget",      # the same for a saucer
               # v1.3 (K5, D5-1): thirdjam's HUD query UJamSim::HumanPassTarget (the mate inside game.pass.aim.cone_deg of a direction,
               # seen from the puck: PickReceiverInCone; -1 none, then the aim lies along the direction at the pass's reach):
               "PassTargetHeld", "PassTargetHeldAim",       # along the stick (BladePos - Pos) at the hold so far (max(1, PassChargeFrames)):
                                    #   the pass meter's target (HUDPassMeter.cpp:62-67 draws it only while PassChargeFrames > 0)
               "PassTargetFacing", "PassTargetFacingAim",   # along his facing (Yaw) at a full hold (game.pass.power_full_frames):
                                    #   the teach pulse's "a mate is open" (HUDTeach.cpp:55-67 adds 6-30 m and ahead within 0.7)
               "TakeOwner",         # the skater who has carried since the puck last changed hands (-1 nobody, -2 a placed puck; JamSim.h:885-887)
               "CarrierInTakeGrace"}  # bool: the carrier is inside his take grace (JamSim.h:879-884 InTakeGrace)
}
```

Value types: `FVector2D` -> `Vector2` (single precision; the hash is taken natively from the doubles), `double`/`float`
-> `float`, `int32`/`int64` -> `int`, `bool` -> `bool`, `FName` -> `String` (`""` for NAME_None), `FString` -> `String`.
Derived helpers per skater, from JamSim.h:407-416: `IsDown` (KnockFrames > 0), `IsStumbling` (StumbleFrames > 0),
`InBox` (PenaltyFrames > 0), `CanAct`, `IsSpinning`, `SpinVisualYawDeg` (the figure's extra yaw in a spin; the sim's Yaw stays).

### What the figure needs most (K2), all in the tables below
Pose and motion: `Pos`, `Vel`, `Yaw`, `YawRate`, `PrevPos`, `PrevYaw` (interpolate with the render alpha, as
AHokejGameMode::Tick does), `BladePos` (the stick blade on the ice, rink metres), `bStickAimed`, `bHasPuck`,
`bSprinting`, `Stamina`, `bBraking`, `bReverseBraking`, `KnockFrames`/`KnockDir` (down), `StumbleFrames`,
`SpinFrames`/`SpinLength`/`SpinDir`, `DekeFrames`/`DekeSide`, `SweepFrames`/`SweepSide`, `ChargeFrames` (shot wind-up),
`PassChargeFrames`, `CheckWindupLeft`, `LiftWindupLeft`, `CrossHoldFrames`/`bCrossBraced`, `WindupFrames`,
`PenaltyFrames` (in the box), the one-frame triggers `b*ThisFrame` (shot, pass, check, poke, lift, deke, spin, sweep,
bump, board hit, recoil, ability). Puck: `Pos`, `Z`, `Vel`, `VZ`, `LastTouch`.

## The effect system's read-outs (v1.4, lane H2)

thirdjam's effect system (UJamEffectSystem, Effects/JamEffectSystem.h) runs beside the sim: FJamSimAdapter::Step steps it right
after UJamSim::Step and the zones. It keeps its pickups and its events to itself (AJamPickupActor and the bus read them in the
Unreal game), so before v1.4 a cartridge's `game.pickups` played unseen. Three read-outs, present on every frame of a loaded
match (empty lists when the cartridge has no effects or pickups; the regular cartridge's are empty):

| Key | What | Source |
|---|---|---|
| `Pickups` | the pickups on the ice now, in the system's order: `Id` (int, unique in the match, from 1), `PickupIndex` (int, into the cartridge's `game.pickups`), `Kind` (String: speed, precision, heavy_puck, big_puck, reverse_other or an effect id), `Pos` (Vector2, rink metres), `SpawnFrame` (int) | GetPickups, FJamPickupOnIce (JamEffectTypes.h:147-156) |
| `EffectEvents` | this frame's `pickup_spawn`, `pickup_take`, `effect_start`, `effect_end` (Events' shape: Name, Who, Where, Strength, Kind, Frame, Text, Dir, Outcome). A pickup_take's `Where` is the pickup's own `Pos`, its `Who` the taker | GetFrameEvents (JamEffectSystem.h:61) |
| `Boosts` | per skater (skater order), the kind of the newest effect covering him (a boost's glow, IJamSkaterVisual::SetBoost); `""` = none | GetBoostKindFor (JamEffectSystem.cpp:373) |

A pickup appears in `Pickups` on the frame its `pickup_spawn` is in `EffectEvents`, and is gone on the frame of its
`pickup_take`. These are read-outs: nothing is stepped, nothing enters `state_hash()` (every hokej bot hashes as before, lane H2's
report). The sim's `Events` are unchanged (the effect events are NOT appended to them: a pack that listens to Events hears what it
heard before).

## The raw shape's rules (v1.2)

- Every raw value is single precision. Vector2 components are float already; `CameraYaw` is rounded to float on the way in.
  So a recorded stream is a complete, exact description of a hand: write each number with at least 9 significant digits
  (or exactly, as K3's x 2^50 integers) and the replay gives the same doubles to the bit. (Before v1.2 the yaw was used as a
  double; a stream that went through Godot's JSON parser came back one double ulp away and the match parted from the pack's
  at frame 1,294: K3's finding, fixed; K3's comparison is now 9,071 of 9,071 frames.)
- `CameraYawDeg` (optional, wins over `CameraYaw`): thirdjam's own form, the camera's yaw in degrees, turned into radians in
  double (HokejGameMode.cpp:943-946).
- No pixel: omit `CursorPx`, or give any negative coordinate (a bot's aim, `(-1, -1)`). Without a pixel the aim is never
  anchored (FJamAimAnchor anchors a still pixel only): the blade follows `CursorHitM` every step. With a pixel the A191 anchor
  works as in thirdjam (a still pixel and a standing skater keep the blade's point).

## Two cores, one shape: RinkCore and RinkCoreThirdlife (round 5)

- `RinkCore` (rink_core.dll) is thirdjam byte for byte. `RinkCoreThirdlife` (rink_core_thirdlife.dll, built by
  `bash engine/tools/rink.sh build thirdlife` when `native/patches-thirdlife/*.patch` exist) is the same source compiled from a
  copy of thirdjam with lane K8's patches applied (`native/tools/thirdlife_tree.py`). Every method and snapshot field above is
  the same in both. The kernel picks one by the cartridge (a `<name>.rules.json` beside it: kernel API 1.27).
- Patch 0005 (bots with abilities, the dive; CARTRIDGE.md section 1) adds to the thirdlife core only: skater fields
  `TlWindupLeft` (a bot's meteor wind-up, frames left), `TlDiveFrames` (a dive lying across a shot's lane, frames left),
  `TlDives`, `TlDiveBlocks` (counters), and two events: `dive` (Who the diver, Where him, Strength the miss / 4 m, Kind
  shotgun | shot, Dir the dive) and `dive_block` (Who the diver, Where the puck, Strength the shot's speed / max, Kind
  shotgun | shot). With its switches off the fields stay 0 and nothing is emitted.
- `load_rules(json) -> String` (after `load_cartridge`, before `reset`): the sidecar `tl.rink.rules/1` ("rules": switches set
  through the patches' own `TlSetRule`; "levels": a thirdjam tune string per level, applied by `ApplyDifficultyTune` on top of
  the level's profile at each `reset`). "" = loaded, else the error. The plain core refuses any rule.
  `rules_applied() -> String`: the switches set ("net_carry_wall=1"). A new `load_cartridge` clears the rules.
- Proof that the patches with their switches off are thirdjam: the 60 tournament matches (10 seeds x 3 levels x playerbot /
  playtester, a TRACE line every frame) print 588,119 of 588,119 lines identical to the plain build, and the 60 closing hashes
  equal `head-baseline.jsonl`; inside Godot a whole match hashes the same on every frame (selftest `rink.variant`).
- The state hash of the thirdlife core with a switch ON differs from frame 1 (the patches hash their own state while a switch
  is on): a thirdlife replay is checked against thirdlife, never against regular.

## The playtester's advice (v1.3, for K3's pack bot)

- The advisor is a second `FJamPlaytester` seated as the seat is (rink_playtester.h: RunPlaytestMatch's setup with no
  JAM_PLAYTESTER_* variable, the same seed). It thinks ONCE A FRAME on the world the seat would see (`View` + the active signal
  intent): on `advise()`, or inside `step()` when the frame was not asked. Asking twice on a frame answers the same.
- What must persist between calls is the playtester's own memory, all of it inside the advisor (thirdjam AI/JamPlaytester.h):
  `Tick` and `PlayFrames` (its clocks: the lapse clock, the aim-noise window), `Ring[]` / `BrakeRing[]` (the reaction delay: it
  acts on what it saw ReactionFrames ago), `MoveOut` (the stick ramp), `bHolding` / `HoldFrames` / `SaucerHold` (a shot or a
  saucer being held), `LastPassFrame` / `LastCheckFrame` / `LastDekeFrame` / `LastCutFrame` / `CutUntil` / `CutDir` (its
  cooldowns), `BraceTarget`, the stop-mark and dodge state, `Act`, and its `Seed` (its noise is a hash of seed and frame: no
  RNG stream). None of it is in the snapshot; the core keeps it. So: set the advisor before `reset`, and let `step()` run every
  frame; an advisor set mid-match, or a match the pack skips frames of, starts with an empty memory.
- Proof (selftest `rink.advice`, tools/rink_advice.gd): with the playtester seated and an advisor of the same spec, the advice
  equals what the seat sent on 12,206 of 12,206 frames (seed 1, regular + sprint; also good seed 2: 5,700/5,700, novice seed 3:
  10,630/10,630), and the seated match still ends on thirdjam's playtester hash 973d6c043707b703.
- Not bit-exact through a Dictionary: `Move` and `Stick` come back as `Vector2` (single precision). A core driven by its own
  advice through `set_human_input` plays a valid, different match (seed 1: its state hash parts from the seated match's at frame
  160, final 0:3 against 3:2); every frame's advice is still the playtester's decision on THAT core's state. A pack bot pressing it
  through the real keys rounds further (digital keys, the stick through the cursor): it stays in the pack's own match, deciding
  as thirdjam's playtester does, but is not the tournament's playtester to the hash.
- `restart()` (v1.3) starts the seat's and the advisor's memory again (RunPlaytestMatch makes one playtester a match); before, a
  seated playtester carried its memory into the restarted match.

## The skating gym: one human on empty-ish ice (for K2)

**v1.2: use `core.set_bot_mode("off")`**: the other nine sit in thirdjam's penalty box (JamSim.cpp:1349-1357 "no input, no
contact"; drawn at `BoxPos`, `InBox` true: hide them) and the sheet is empty. Measured: the human skates 43.9 m, the others move
0.000 m. `parked` stays as it was (standing bodies), described below.

`core.set_bot_mode("parked")` after `reset(seed)`: the nine others get an empty FJamInput every frame and stand where the
opening faceoff put them (the human is skater 0, the team-0 centre at the dot). thirdjam has no gym cartridge, and a cartridge
with one skater is not a thirdjam game; parked bots keep the cartridge whole (rink, puck, rules). The opening faceoff still
counts down (`Phase` 3, `FaceoffCountdown`) and drops the puck; skate away from the dot. This is a test stand, not a thirdjam
mode (listed as a deviation). Bots stand, so a skater that runs into one meets a body.
Explained (v1.2): the opposing centre stands at the dot in front of the human; a human skating along +x carries him ~40 m
by body contact (thirdjam's contact law at work, not a drift). With `off` there is no body to meet.

## Enum values

| Field | Values | Source |
|---|---|---|
| `Phase` (snapshot) | 0 Playing, 1 GoalPause, 2 Over, 3 Faceoff | JamSim.h:110-116 `EJamSimPhase` |
| `ContactOutcome` | 0 none, 1 bump, 2 stumble, 3 down | JamSim.h:717-720 `UJamSim::ContactNone/Bump/Stumble/Down`; JamSim.h:289-293 |
| `StickHitResult` | 0 none, 1 a clean poke took the puck from him, 2 a lift took it | JamSim.h:287-288 |
| `PokeResult` | 0 none, 1 clean, -1 missed (one frame) | JamSim.h:270-272 |
| `DrawResult` | 0 none, 1 won, -1 lost (one frame) | JamSim.h:270-273 |
| `DekeSide` | +1 towards +y (rink z), -1 towards -y, 0 none | JamSim.h:225-227 |
| `SweepSide` | sign of Cross(Forward, blade - body): +1 / -1, 0 none | JamSim.h:230-234 |
| `SpinDir` | +1 = the sim's yaw sense (to the right), -1 the other way | JamSim.h:235-240 |
| `Role` | "player", "chaser", "support", "back" | JamSim.h:126-127 |
| `Team` | 0 (defends -x, skaters first), 1 | JamSim.h:125; JamAICore.h world comment |
| `Stamina` | ticks: full = drain_frames x refill_frames (UJamSim::StaminaFull()); a sprinting frame takes refill_frames, a resting frame gives drain_frames back; -1 = unset, read as full (JamSim.cpp:1277, 1606) | JamSim.h:148-150 |
| Event `Name` | shot, board, goal, faceoff, check, knockdown, pickup_spawn, pickup_take, win, lose, directors_call, period, bark, signal, announce, pass, effect_start, effect_end, zone_enter, zone_exit, poke, lift, foul, shot_blocked, save, post, breakaway, carry, period_end, clock, season_take, deke, ability, possess | JamEventBus.h:12-55 (each line says its Who / Where / Strength / Kind) |
| Event `Kind` (examples) | faceoff: drop / won / lost; poke, lift: clean / miss; foul: foul_from_behind / foul_no_puck; shot: one_timer; deke: left / right; possess: body / none | JamEventBus.h comments |
| `Controls.IntentKind` | 0 none, 1 defend, 2 space, 3 pass, 4 praise | SignalIntent.h `EJamTeamIntent` |

## Fields (generated from thirdjam HEAD JamSim.h)

### FJamInput (15 fields)

| key | thirdjam type | line | thirdjam's comment (abridged) |
|---|---|---|---|
| `Move` | FVector2D | 34 | Desired direction on the ice in rink coordinates (X = rink x, Y = rink z). Its length scales top speed and thrust: humans are clamped to 1, bots to 1.5 (the ... |
| `bShoot` | bool | 38 | Shoot pressed on this frame (edge, not hold): a tap shot at shot.speed, if reach, facing and cooldown allow it. Bots and scripts use it. |
| `bShootHeld` | bool | 43 | C-0005 charged shot: shoot held (level). While held with the puck in reach the charge grows to shot.charge_frames_max; the shot fires on release at shot.spee... |
| `bPass` | bool | 47 | C-0005 pass (E / X) pressed on this frame (edge): a lead pass at skater.pass_speed to the best open teammate ahead of the puck. |
| `bPassHeld` | bool | 53 | Lane A77 (R-0036): pass held (level). While held with the puck in reach the pass charges to game.pass.saucer.half_frames; the pass fires on the release: held... |
| `bCheck` | bool | 57 | Check pressed on this frame (edge). Opens a 6-frame check window; only lands when game.skater.check_enabled. |
| `bBrake` | bool | 61 | Brake held (skate stop). Optional; no default key binds it in M0. |
| `Stick` | FVector2D | 66 | R-0013 stick aim: where the blade is held, as an offset direction from the skater in rink coordinates; /Stick/ <= 1 is the fraction of game.stick.reach_m. Ze... |
| `bPoke` | bool | 71 | Poke check pressed this frame (edge): the blade takes the puck cleanly if it reaches it inside poke_window_frames; a poke next to an opposing carrier that mi... |
| `bLift` | bool | 75 | Stick lift pressed this frame (edge): strips an opposing carrier within lift_range_m. |
| `bDeke` | bool | 81 | R-0029 point 4 (lane A39) deke pressed this frame (edge): the carried puck moves game.stick.deke.offset_m to the blade side within 6 frames and the crease ba... |
| `bSprint` | bool | 86 | Lane A49 sprint held (level): +game.skater.sprint.bonus top speed and thrust while the skater moves and its stamina lasts (drain_frames of sprint, refill_fra... |
| `bSpin` | bool | 92 | Lane A51 (R-0034): the spin move pressed this frame (edge): E / gamepad B. game.skater.spin: a full turn over spin.frames, the puck on the far side of the bo... |
| `bAbility` | bool | 97 | Lane A84 (R-0041 point 3): the held ability used this frame (edge): F / gamepad D-pad down. Does nothing unless the skater holds one of game.abilities[] (a m... |
| `bCrossHold` | bool | 105 | Lane A184 (track F1, evolution 9; R-0064 points 1 and 5): the cross-check held (level): true on every frame the cross-check button is held while the skater d... |

### FJamSkaterState (154 fields)

| key | thirdjam type | line | thirdjam's comment (abridged) |
|---|---|---|---|
| `Index` | int32 | 124 |  |
| `Team` | int32 | 125 |  |
| `Role` | FName | 127 | "player" / "chaser" / "support" / "back" |
| `bHuman` | bool | 128 |  |
| `Pos` | FVector2D | 130 |  |
| `Vel` | FVector2D | 131 |  |
| `Yaw` | double | 133 | Facing angle in radians in the rink plane: atan2(z, x). 0 faces +x. Equals the Unreal yaw (in radians). |
| `YawRate` | double | 135 | Yaw change over the last frame in rad/s (sim sign: + = towards +z = Unreal yaw right). |
| `PrevPos` | FVector2D | 138 | Previous frame, for render interpolation. |
| `PrevYaw` | double | 139 |  |
| `SpawnPos` | FVector2D | 141 |  |
| `SpawnYaw` | double | 142 |  |
| `ShotReadyFrame` | int64 | 145 | First frame a shot is allowed again (cooldown). |
| `CheckWindow` | int32 | 147 | Frames left of the check window (set to 6 when check is pressed; 12 for the human, lane A49's calibration). |
| `Stamina` | int32 | 150 | Lane A49 sprint stamina in ticks: full = drain_frames * refill_frames; a sprinting frame takes refill_frames, a resting frame gives drain_frames back. Starts... |
| `bSprinting` | bool | 152 | Read-out: the sprint applied this frame (lane A93: the carrier's too; the contact's stability reads it). |
| `bBraking` | bool | 155 | Lane A93 (R-0045 law 3) read-outs, never hashed: a brake took speed off this frame at more than 1 m/s: Ctrl / L-stick click (brake_decel) or the move input a... |
| `bReverseBraking` | bool | 156 |  |
| `BurstLeft` | int32 | 160 | Lane A93 (R-0045 law 3): frames left of the first-step burst (acceleration x skater.burst.accel_mult). Full while the speed is under BurstSlowSpeed and on th... |
| `bBurstEarned` | bool | 163 | Lane A121 (track F2; game.skater.burst.own_stop): this skater braked on its way down (the reverse brake or the brake button took speed off it) and has not be... |
| `RestFrames` | int32 | 166 | Lane A128 (track F2 evolution 3; game.skater.burst.rest_frames): frames in a row this skater has been slower than BurstRestSpeed, up to rest_frames; at rest_... |
| `SpinRecoverLeft` | int32 | 169 | Lane A128: frames left of the recovery after a spin that ran its length (FJamSkaterConfig::SpinRecoveryFrames, code only and 0: a measured candidate for the ... |
| `TakeGraceLeft` | int32 | 173 | Lane A121 (R-0049 point 2; game.stick.take_grace_frames): frames left in which this skater's carried puck cannot be poked or lifted: it has just won the puck... |
| `MoveHist (not in the snapshot: C array)` | FVector2D | 176 | The move input's direction over the last BurstCutFrames frames (unit, or zero for a frame without input), a ring written at MoveHistAt. Burst only. Lane A110... |
| `MoveHistAt` | int32 | 177 |  |
| `CarrySprintFrames` | int32 | 179 | Match statistics (not hashed): frames this skater sprinted while carrying the puck; reverse brakes started. |
| `ReverseBrakes` | int32 | 180 |  |
| `KnockFrames` | int32 | 182 | Frames left knocked down; 0 = standing. |
| `KnockDir` | FVector2D | 184 | Direction of the fall (rink x, z), unit; valid while KnockFrames > 0. |
| `BladePos` | FVector2D | 187 | R-0013 stick. The blade on the ice (rink metres) this frame, from the stick aim. |
| `PokeWindow` | int32 | 189 | Frames left of the poke window (set to stick.poke_window_frames on a poke press). |
| `bStickAimed` | bool | 191 | True on a frame with stick input (/Stick/ > 0.05): only an aimed stick deflects a shot; a blade held by default receives passes but blocks nothing. |
| `bPokeArmed` | bool | 193 | True while the open poke window was armed next to an opposing carrier (a miss then stumbles). |
| `StumbleFrames` | int32 | 195 | Frames of lost control after a mistimed poke; 0 = in control. |
| `StickLockLeft` | int32 | 197 | Lane A152 (game.stick.miss_recovery_frames): frames left of the recovery after a missed poke: no poke, lift or check while above 0. Hashed while above 0. |
| `PenaltyFrames` | int32 | 199 | Frames left in the penalty box; 0 = on the ice. |
| `PokeReadyFrame` | int64 | 201 | First frame a poke / lift is allowed again. |
| `LiftReadyFrame` | int64 | 202 |  |
| `bCentre` | bool | 204 | Takes the draw at the current faceoff. |
| `DrawFrame` | int64 | 206 | The draw: -1 no input yet, -2 moved early (loses), otherwise the frame of this centre's first stick input after the drop. |
| `ChargeFrames` | int32 | 210 | C-0005 charge: frames shoot has been held with the puck in reach (0..shot.charge_frames_max); the visual winds up on it. Lane A203: -1 = a press the loss of ... |
| `LastShotCharge` | float | 212 | Charge 0..1 of the shot that left this frame (0 for a tap or a pass); PlayShoot(Charge) takes it. |
| `DeflectCooldown` | int32 | 214 | Frames before this skater may deflect again (one deflection per contact). |
| `Passes` | int32 | 215 |  |
| `PassReceivedFrame` | int64 | 219 | R-0029 point 4 (lane A39): the three payoffs. The frame a teammate's pass landed on this blade (-1 none); a shot within shot.one_timer.window_frames of it is... |
| `BreakawayFrames` | int32 | 221 | Frames left of the breakaway burst (top speed and accel x (1 + speed_bonus)); the burst fires once per possession (bBreakawayUsed resets when the puck change... |
| `bBreakawayUsed` | bool | 222 |  |
| `CarryFrames` | int32 | 224 | Consecutive frames as the carrier (counted only while the burst is on): the burst needs BreakawayCarryFrames of carry, so a touch-and-shoot never bursts. |
| `DekeFrames` | int32 | 226 | Frames left of the deke (the puck moves over the first DekeMoveFrames, the crease back stays committed for all of them); DekeSide +1 = towards +z, -1 = towar... |
| `DekeSide` | int32 | 227 |  |
| `DekeReadyFrame` | int64 | 229 | First frame a deke is allowed again (a second tap inside DekeLockoutFrames does nothing). |
| `SweepFrames` | int32 | 233 | Lane A51 (R-0034) stick handling. The sweep: frames left of the shield after the blade crossed fast with the puck (0 = none) and the side the puck left as th... |
| `SweepSide` | int32 | 234 |  |
| `SpinFrames` | int32 | 238 | The spin (game.skater.spin): frames left (0 = none), the whole length, the turn direction (+1 = the sim's yaw sense, to the right), the first frame a spin is... |
| `SpinLength` | int32 | 239 |  |
| `SpinDir` | int32 | 240 |  |
| `SpinReadyFrame` | int64 | 241 |  |
| `Sweeps` | int32 | 243 | Match statistics of the stick handling (not hashed, like Dekes). |
| `Spins` | int32 | 244 |  |
| `PassChargeFrames` | int32 | 246 | Lane A77 (R-0036): frames pass has been held with the puck in reach (0..pass.saucer.half_frames); saucers passed; the pass that left this frame was a saucer. |
| `Saucers` | int32 | 247 |  |
| `bSaucerThisFrame` | bool | 248 |  |
| `SettleFrames` | int32 | 250 | Lane A46: frames left of the settle after a body reception (the carry assist holds the puck on the blade; 0 = none). Hashed only while it runs. |
| `PassesReceived` | int32 | 252 | Match statistics of the payoffs; PassesReceived (lane A46) counts teammates' passes seated on this skater's blade (blade or body reception). |
| `OneTimers` | int32 | 253 |  |
| `Breakaways` | int32 | 254 |  |
| `Dekes` | int32 | 255 |  |
| `bShotThisFrame` | bool | 258 | One-frame flags for the visual (set during the step that just ran). |
| `bPassThisFrame` | bool | 259 |  |
| `bCheckThisFrame` | bool | 260 |  |
| `bPokeThisFrame` | bool | 261 |  |
| `bLiftThisFrame` | bool | 262 |  |
| `bOneTimerThisFrame` | bool | 264 | R-0029 point 4 (lane A39) one-frame flags for the visual: the shot that left was a one-timer, the burst fired, a deke started. |
| `bBreakawayThisFrame` | bool | 265 |  |
| `bDekeThisFrame` | bool | 266 |  |
| `bSweepThisFrame` | bool | 268 | Lane A51 (R-0034) one-frame flags: a sweep started (the blade crossed fast with the puck), a spin started. |
| `bSpinThisFrame` | bool | 269 |  |
| `PokeResult` | int32 | 272 | C-0001 v3 one-frame results for the visual: a poke resolved (1 clean, -1 missed), the draw resolved (1 won, -1 lost), a foul was called on this skater, the s... |
| `DrawResult` | int32 | 273 |  |
| `bFoulThisFrame` | bool | 274 |  |
| `LastPassStrength` | float | 275 |  |
| `bAtFaceoff` | bool | 276 |  |
| `bBumpThisFrame` | bool | 279 | Lane A45 (C-0001 v4, R-0031 point 1): read-outs for the visual's PlayHitReaction / PlayBoardHit / SetBoardPin / PlayStickHit. Never hashed, never read by the... |
| `BumpDir` | FVector2D | 280 |  |
| `LastBumpFrame` | int64 | 281 |  |
| `bBoardHitThisFrame` | bool | 283 | The skater `board` event (A33) fired for this skater this frame; BoardFrames = consecutive frames touching the boards (within BoardContactEpsM of them). |
| `BoardFrames` | int32 | 284 |  |
| `bBoardPinned` | bool | 286 | BoardFrames >= BoardPinFrames (10) with a standing opponent within BoardPinRangeM (1.2 m, centre to centre); false while down or in the box. |
| `StickHitResult` | int32 | 288 | This carrier lost the puck to an opponent's stick this frame: 1 a clean poke (ResolvePokes), 2 a lift (TryLift); 0 otherwise. |
| `ContactOutcome` | int32 | 293 | Lane A92 (R-0045 law 1) read-outs, never hashed, never read by the sim. ContactOutcome: the hit this skater took this frame from a pressed check or a cross-c... |
| `ContactRatio` | float | 294 |  |
| `bContactCross` | bool | 295 | that hit was a cross-check (the lift's body part), not a body check |
| `bCheckRefused` | bool | 296 |  |
| `bRecoilThisFrame` | bool | 297 |  |
| `ContactBumps` | int32 | 298 |  |
| `ContactStumbles` | int32 | 299 |  |
| `ContactDowns` | int32 | 300 |  |
| `ContactRecoils` | int32 | 301 |  |
| `ChecksRefused` | int32 | 302 |  |
| `ContactBy` | int32 | 307 | Lane A101 (track F1) read-outs, never hashed, never read by the sim. ContactBy: the skater whose hit ContactOutcome reports (-1 with none): the hit-stop, the... |
| `bContactBoard` | bool | 308 |  |
| `ContactBoardHits` | int32 | 309 |  |
| `LastContactBoardFrame` | int64 | 310 | the frame of the last such hit: its echo on the boards is not a second board hit |
| `GraceFrames` | int32 | 317 | Lane A113 (track F1, R-0049 point 1): the release grace. GraceFrames: frames left in which a hit on this skater is a bump at most; set to game.contact.releas... |
| `bContactGrace` | bool | 318 |  |
| `ContactGraced` | int32 | 319 |  |
| `ChecksSoft` | int32 | 320 |  |
| `ChecksGraced` | int32 | 321 |  |
| `ChecksMissed` | int32 | 322 |  |
| `LateFrames` | int32 | 327 | Lane A151 (track F1, evolution 5): the late press (contact.LatePressFrames; with 0 none of these is ever written). LateFrames: frames left in which this HUMA... |
| `LateWho` | int32 | 328 |  |
| `LateDir` | FVector2D | 329 |  |
| `LateVelSelf` | FVector2D | 330 |  |
| `LateVelOther` | FVector2D | 331 |  |
| `ChecksLate` | int32 | 332 |  |
| `DownedPushFrames` | int32 | 335 | Lane A157 (track F1, evolution 6) read-out, never hashed, never read by the sim: frames in which the push-out around a downed skater (game.contact.downed_rad... |
| `CheckReadyFrame` | int64 | 340 | Lane A157 (track F1, evolution 6): the check's cooldown and the lunge. RULE STATE, hashed in StateHash() while not 0 (so the keys' neutral values hash as bef... |
| `LungeLeft` | int32 | 341 |  |
| `ChecksCooling` | int32 | 342 |  |
| `LungesMissed` | int32 | 343 |  |
| `bContactSlam` | bool | 347 | Lane A165 (track F1, evolution 7) read-outs, never hashed, never read by the sim. bContactSlam: the hit ContactOutcome reports this frame was a board slam (g... |
| `ContactSlams` | int32 | 348 |  |
| `TakeShieldLeft` | int32 | 354 | Lane A177 (track F1, evolution 8): the take shield (game.contact.take_shield_frames). RULE STATE, hashed in StateHash() while not 0 (so the key's neutral val... |
| `bContactShield` | bool | 355 |  |
| `ContactShielded` | int32 | 356 |  |
| `CrossHoldFrames` | int32 | 365 | Lane A184 (track F1, evolution 9): the held cross-check (game.contact.cross_hold) and the wind-ups (game.contact.check_windup_frames, cross_windup_frames). R... |
| `bCrossBraced` | bool | 366 |  |
| `bCrossSpent` | bool | 367 |  |
| `CheckWindupLeft` | int32 | 368 |  |
| `LiftWindupLeft` | int32 | 369 |  |
| `CrossTarget` | int32 | 372 | Lane A192: since evolution 10 LiftWindupLeft counts down to the cross-check's deferred SHOVE (the strip is the press's): CrossTarget, the man it lands on; bC... |
| `CrossLiveLeft` | int32 | 375 | Lane A215 (game.contact.cross_live_frames): frames left of the pressed cross-check's live window after its wind-up (the shove not yet landed; CrossTarget is ... |
| `CheckBufferLeft` | int32 | 377 | Lane A209 wave 3: RULE STATE, hashed when not 0: frames left of a buffered check press / cross-check press (UJamSim::StepPressBuffer). |
| `LiftBufferLeft` | int32 | 378 |  |
| `bCrossTargetStickOnly` | bool | 379 |  |
| `CrossBraceFrames` | int32 | 380 |  |
| `CrossBraceHits` | int32 | 381 |  |
| `bCrossBraceHit` | bool | 382 |  |
| `CrossBraceTaken` | int32 | 383 | lane A192 read-out: braced hits taken (the HUD's contact line), read by no rule |
| `WindupFrames` | int32 | 384 |  |
| `LastCarryFrame` | int64 | 386 | R-0029 point 3: the last frame this skater carried the puck (-1000 = never); a check within game.stick.foul_grace_frames of it is not a foul_no_puck. |
| `bTouchingPuck` | bool | 387 |  |
| `bHasPuck` | bool | 389 | Last toucher of the puck and the puck within shot reach. |
| `Shots` | int32 | 392 | Match statistics (tests and tournaments read them). |
| `Touches` | int32 | 393 |  |
| `Goals` | int32 | 394 |  |
| `DistanceM` | double | 395 |  |
| `AbilitySlot` | int32 | 399 | Lane A84 (R-0041 point 3): the held ability. AbilitySlot indexes game.abilities[] (-1 = none held); AbilityCharges left (-1 = unlimited); usable from Ability... |
| `AbilityCharges` | int32 | 400 |  |
| `AbilityReadyFrame` | int64 | 401 |  |
| `AbilityArmed` | FName | 402 |  |
| `ShieldFrames` | int32 | 403 |  |
| `AbilitiesUsed` | int32 | 404 |  |
| `bAbilityThisFrame` | bool | 405 |  |

### FJamPuckState (19 fields)

| key | thirdjam type | line | thirdjam's comment (abridged) |
|---|---|---|---|
| `Pos` | FVector2D | 423 |  |
| `Vel` | FVector2D | 424 |  |
| `PrevPos` | FVector2D | 425 |  |
| `Z` | double | 429 | R-0035 (lane A52): the puck's height above the ice (metres, the puck's centre line; 0 = on the ice) and its vertical speed (m/s, + = up). A shot's release li... |
| `VZ` | double | 430 |  |
| `PrevZ` | double | 431 |  |
| `LastTouch` | int32 | 433 | Skater index that touched or shot it last, -1 after a faceoff. |
| `LastPlayedBy` | int32 | 436 | Lane A208 (game.puck.net.own_wall): the last skater who CARRIED the puck (then shot, passed or cleared it: a stick's deliberate play); a touch, a deflection ... |
| `PathM` | double | 438 | Total distance travelled this match. |
| `ShotgunFrames` | int32 | 441 | Lane A84: a shotgun shot in flight (frames left, the shooter, its speed multiplier) and a slow puck (frames left, the passer or shooter, the speed share). Ze... |
| `ShotgunBy` | int32 | 442 |  |
| `ShotgunMul` | double | 443 |  |
| `SlowFrames` | int32 | 444 |  |
| `SlowBy` | int32 | 445 |  |
| `SlowMul` | double | 446 |  |
| `PassFrames` | int32 | 449 | Lane A207 (track P1): a pass in flight: frames left (0 = none) and the passer. Set by TryPass only while game.pass.catch_m is on; any touch by another skater... |
| `PassBy` | int32 | 450 |  |
| `PassTo` | int32 | 453 | Lane A207 (wave 2): the man the pass was aimed at (-1: along the stick, any mate). Another team-mate lets the pass fly by while it is faster than DeflectMinS... |
| `ShotExcess` | double | 456 | Lane A207 (wave 2b, game.shot.fade_m): the shot's added speed still on the puck (m/s; 0 = none). Set by TryShoot, faded with the distance travelled (StepShot... |

### FJamSimEvent (9 fields)

| key | thirdjam type | line | thirdjam's comment (abridged) |
|---|---|---|---|
| `Name` | FName | 464 |  |
| `Who` | int32 | 465 |  |
| `Where` | FVector2D | 467 | Rink metres (x, z). |
| `Strength` | float | 468 |  |
| `Kind` | FName | 469 |  |
| `Frame` | int64 | 470 |  |
| `Text` | FString | 472 | Side channel for "announce" (C-0005): the rule's text for the scoreboard line. Empty for every other event. |
| `Dir` | FVector2D | 475 | Lane A47 (B-to-A-0029): the contact normal (checker towards victim) for check and knockdown, the board normal into the rink for board; zero otherwise. Rink a... |
| `Outcome` | FName | 477 | Lane A143 (B-answer-0024 ask b): what a landed `check` did to the victim: `stumble` or `down`; NAME_None for every other event. A read-out, not hashed. |
