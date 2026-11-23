# thirdjam's game mode: what is play and what is presentation

thirdjam's simulation (JamCore) is compiled whole into the core. Its game mode (`JamGame/Private/HokejGameMode.cpp`,
`InputMapping.cpp`, `SignalSystem.cpp`; the pawns in `JamCore/Private/JamPawns.cpp`) also makes rules that change what
the simulation is given or when it steps. Every such rule is ported into the core's glue
(`native/glue/rink_gamemode.{h,cpp}`, reached through `RinkCore`), so the shell (lane K3) keeps only keys-to-raw-input
and drawing. Line numbers are thirdjam HEAD 8dc713c6.

The shell's whole job for play: each physics frame, read the devices into `set_raw_input({...})` (Unreal key names, the
move axis, the pad stick, the cursor's pixel and ice point, mouse motion, the camera's yaw), then `step()`. The core
does the rest.

## The split

| # | Rule | thirdjam file:line | Lives in ours | How |
|---|---|---|---|---|
| 1 | Bots' inputs come from the brain every frame; the human's from his devices | HokejGameMode.cpp:1316-1487 (GatherInputs) | core | `RinkCore.step()` (JamBotMatch RunMatch's frame) |
| 2 | Two-role buttons: LMB / RT shoot with the puck, cross-check without; RMB / RB pass with it, check without; the key's verb is fixed at its first step by that frame's possession | InputMapping.cpp:98-120 (defaults), 341-424 (FJamButtonResolver::Step), 488-503 (ApplyButtons); HokejGameMode.cpp:961 | **core glue** | `FButtonResolver`, `FHumanControls::Read` |
| 3 | "With the puck" = carrying it, or a loose puck last touched by his own team (our pass in flight: the one-timer's early press is a shot) | InputMapping.cpp:432-442 (HasPuckForButtons; jam.ctrl.OurPuckShoots 1) | **core glue** | `HasPuckForButtons` |
| 4 | A key held across a change of possession goes dead until released (a held shot / pass when the puck stops being ours, its level held up while the puck is still in reach; a held cross-check's brace when he takes the puck; a check when the puck becomes ours) | InputMapping.cpp:369-397, 474-486 (jam.ctrl.HeldAcrossChange 1) | **core glue** | `FButtonResolver::Step` |
| 5 | The saucer needs the pass held 13 frames (level starts 13 - half_frames late; at once under pass.power); the brace needs the cross-check held 13 frames | InputMapping.cpp:458-486 (SaucerHoldFrames 13, BraceHoldFrames 13) | **core glue** | `ButtonContext` |
| 6 | A tap released before the step still counts once | InputMapping.cpp:320-333, 400-402 | **core glue** | `Pressed` list in `set_raw_input` |
| 7 | `bCrossHold` only while not carrying | InputMapping.cpp:501 | **core glue** | `FHumanControls::Read` |
| 8 | Move is camera-relative (stick up = away from the camera); a pull back is read in the camera frame of the moment it began, so S is one direction until released | HokejGameMode.cpp:937-958 (lane A93) | **core glue** | `Read`; the shell sends `CameraYaw` (else the skater's yaw, as thirdjam without a camera) |
| 9 | Move axis per axis clamped to [-1, 1] (a diagonal is longer than 1; the sim clamps the human to 1) | InputMapping.cpp:950-953 | **core glue** | `Read` |
| 10 | Stick aim: pad right stick first; else the cursor's ice point (hysteresis 0.7 m in / 0.5 m out, magnitude 0.5 + 0.5 x clamp((d - 0.5) / 2.5)), anchored while the pixel is still and the skater stands (< 0.3 m/s); else the hidden-cursor mouse delta (clamped 200 px, 100 px = one reach x mouse_sensitivity) | HokejGameMode.cpp:966-990, 741-767; InputMapping.cpp:971-977, FJamAimAnchor::Step | **core glue** | `Read`, `FAimAnchor`; the shell sends `CursorPx`, `CursorHitM`, `CursorOnIce`, `MouseDeltaPx`, `StickAxis` |
| 11 | Sprint (LShift / LT) and brake (LCtrl / L3) are held levels | HokejGameMode.cpp:962-963 | **core glue** | `Read` (bindings) |
| 12 | Poke (Space / A), deke (wheel / Y), spin (E / B), ability (F / R3) are edges latched on the press, spent by the next step | HokejGameMode.cpp:992-996; InputMapping.cpp:979-1032 | **core glue** | `Read` from `Pressed` |
| 13 | Team signals 1-4 / D-pad (defend, space, pass, praise): only while Playing; a second within 60 frames ignored; target = nearest bot teammate (praise, pass); honoured 300 frames (pass 180); the brain reads kind, target, frames left | SignalSystem.cpp:46-48, 264-325; SignalSystem.h:24; SignalIntent.h (DefaultFrames); HokejGameMode.cpp:1320-1331 (1325-1329) | **core glue** | `StepSignals`, `ApplyIntent`; snapshot `Controls.Intent*` |
| 14 | Restart (R / View): rules and zones reset, UJamSim::Restart (same seed), effects restart, brain reset | HokejGameMode.cpp:789-818 | **core glue** | `RinkCore.restart()`; R in raw mode |
| 15 | Faceoff countdown, goal pause, the drop, periods, the end | JamSim.cpp (Phase, StepFaceoff, ScoreGoal, UpdatePeriod) | core (thirdjam's own) | unchanged |
| 16 | The rule, zone and effect systems around the sim, in the game mode's order (score mirror, Step, zones, effects) | HokejGameMode.cpp:1636-1646; JamSimAdapter.h:28-50 | core (thirdjam's own) | FJamSimAdapter |
| 17 | Pickups and slow ice / no-shoot zones in the brain's world | HokejGameMode.cpp:1334-1362 (pickups 1336, slow ice and no-shoot 1345) | core (thirdjam's own) | FJamSimAdapter::View + BuildWorld |
| 18 | One sim step per 1/60 s; at most MaxStepsPerFrame per rendered frame, a backlog dropped | HokejGameMode.cpp:1718-1731 | shell | the shell calls `step()` once per physics frame (Godot's fixed 60 Hz) |
| 19 | Pause: the world pauses, the game mode does not tick, the sim does not step | HokejGameMode.cpp:730; InputMapping.cpp:945 | shell | do not call `step()` while paused |
| 20 | Hit-stop: the figures, the puck and the camera hold 1-6 frames on a hit | HokejGameMode.cpp:1753-1775 ("presentation only: the sim steps on"); JamPawns.cpp:147-232 (HitStopFrames, HitStopFramesFor, HitStopPick, BeginHitStop) | **K2's pawn** (and K3's camera) | gates nothing: input is read and the sim steps every frame through it (StepOnce never checks it; Tick only holds the camera's alpha, 1748-1750). Owner: the figure lane, picked from the snapshot's `Events` and `ContactOutcome` / `ContactRatio` / `ContactBy` as JamPawns.cpp does |
| 21 | Goalie stance send (crease skater, hold 4 frames against flicker) | HokejGameMode.cpp:1378-1426 (SendGoalieStance) | shell | brain output `bGoalie` / `GoalieSide` is drawn; never read back by the sim |
| 22 | Render interpolation between the last two sim frames (alpha) | HokejGameMode.cpp:1733; JamPawns.cpp:824-846 | shell | `PrevPos` / `PrevYaw` in the snapshot |
| 23 | The shown carrier and puck (socket, blend at a change of hands) | HokejGameMode.cpp:1666 (FJamPuckShow, PuckRead.h:27 "presentation only") | **K2's pawn** | gates nothing: the sim's `Carrier` and `Puck.Pos` are the truth the rules use; the shown carrier only decides where the puck is drawn |
| 24 | HUD, badge text (what LMB / RMB do now), barks, the light hold, stills, JAM* log lines, drills (jam.ctrl.Drill), the season | HokejGameMode.cpp (DeliverEvents 1488, PushPresentation 1548, TickLightHold 632, drills 1046-1315, 1828-2256) | shell | presentation, or test-only drills |
| 25 | The scripted human (jam.ScriptHuman) | HokejGameMode.cpp:821-930 | not ported | a PIE proof hand; our hands are the playtester / FJamPlayerBot (`set_human_mode`) |

## Added for the gym (not thirdjam)

- `set_bot_mode("parked")`: the other skaters get an empty input every frame (one human skating on the match's ice). A test
  stand for the figure lane; never used by the game. Deviation listed in K1's report.

## Not ported, and why

- Rebinding (FJamBindings::Rebind / FromSaved, the profile's saved table): the defaults are ported; a rebinding screen
  is the shell's, and it would hand the core a table (not built yet: the core reads the defaults only).
- The console-variable switches of the rules above (jam.ctrl.*): the shipped defaults are compiled in.
- Online seats (SeatGuest, the lobby): out of scope for the campaign.
