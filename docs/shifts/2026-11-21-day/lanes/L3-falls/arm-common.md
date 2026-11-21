# Falls arm brief: the part every arm shares (L3, day of 21 Nov 2026)

You are one of three parallel experiments on how a figure in Third Life takes a hit. The owner asked for "failing physics
and animations" and "reactivity on hits", and he will pick one of the three routes **by eye** tonight, from a clip of
the same scripted lab in every arm. Your arm's own route is in the second half of this file. You work alone in this git
worktree (the current directory). **Read-only git is fine; do not commit, do not push, do not create branches.**

## Read first (all of it)
1. `CLAUDE.md` (repo laws), `docs/shifts/2026-11-21-day/COMMON.md` (the day's laws; ignore its lane table except L3).
2. `engine/kernel/api/tl_hit.gd` (the stub you replace) and `engine/kernel/api/tl_biped.gd` (the K2 section: `down`,
   `stumble`, `shove`, `_step_down`, `_rig_has`, `_rig_param`).
3. `engine/rigs/RIGS.md` (how a clip is a pose function of time; bones; `play`, `set_param`, `tick`), then
   `engine/rigs/tl_rig_biped.gd`, `engine/rigs/tl_rig_node.gd`, `engine/rigs/biped/tl_rig_biped_moves.gd` (the `fall_down`
   clip), `engine/rigs/biped/clay_rig.gd` and `engine/rigs/biped/cel_rig.gd`. **The look that is judged is "crisp": the
   default style, whose biped is `cel_rig.gd` (extends `clay_rig.gd`, extends `TLRigBiped`).** Make sure what you build
   shows on that figure, and does not break the classic `TLRigBiped` (`TL_STYLE=classic`).
4. `engine/kernel/API.md` section 6 (TLBiped, TLHit) and section 14.
5. The lab: `engine/kernel/examples/ex_hit_lab/` (pack.json, scripts/main.gd, tests/bot_lab.gd) and its selftest block
   `engine/tools/selftest.d/670-falls.sh`.
6. Reference, read-only: thirdjam (the owner's own hockey game, Unreal):
   `C:/Users/kazda/AppData/Local/Temp/claude/0251139bc1345a0c/73d79642-7e1a-48cb-be9d-365e23bb89ae/scratchpad/ref/thirdjam`,
   `Game/Source/JamGame/Private/SkeletalSkaterVisual.cpp` lines 20-30, 100-125, 215-260 (19 authored sequences incl.
   `knocked_down` 40 f and `get_up` 20 f; a backward fall for front hits, faster for harder hits; an 88-degree tip toward
   the push for side and behind hits over 14 frames; a 14-degree lean for a hit taken standing, 3 frames in, 9 out).

## The shared spec (every arm builds this surface; the signatures never change)
- `TLHit.react(who: TLBiped, from_dir: Vector3, strength: float)`. `from_dir` points FROM the victim TOWARD the blow
  (world space, length ignored, zero = unknown). `strength`: about 0.3 a tap, 0.7 solid, 1.2 and up big.
  - A flinch AWAY from the blow, scaled by strength, readable at game scale (the hockey camera is far away and the
    figures are scaled 2.2 there: a flinch that is only visible in close-up does not count). The pose should be reached
    within about 4 frames of the hit and recover over roughly 12-24 frames.
  - From 0.4 up it is also a short loss of control, as `TLBiped.stumble` is (the current stub: `stumble(8 + 10 *
    strength, lean)`; keep that control effect and its frame count unless you have a reason, and say it).
  - It is an upper-body reaction where possible, so a skating or running figure keeps its legs going.
- `TLHit.down(who: TLBiped, frames: int, from_dir := Vector3.ZERO)`: he falls AWAY from the blow: backward for a hit
  from the front, sideways (away) for a hit from the side, forward for a hit from behind; lies there; then a get-up you
  can SEE (today he just blends back up over 24 frames). A harder/faster hit may fall faster.
- `TLBiped.down(frames)` keeps everything it promises today: he lies `frames` frames, then rises over `get_up_frames`
  (24 by default); `move`/`brake`/`jump` are ignored all that time; `downed` fires when he goes down from standing,
  `got_up` when he stands again; `down` while down keeps the longer time; while rising he goes down again. The
  example `ex_down` must still report `"down_frames":113` (selftest `k2.down_bot`). **The get-up must fit inside the
  rise window** (`get_up_frames`, whatever a pack sets it to): scale the clip to the window rather than changing it.
- **`TLBiped.down(frames)` with no direction** (every existing pack calls it that way, e.g. the hockey pack right after a
  `shove`): infer the blow from his horizontal velocity at that moment (a shove has just been added to it): above about
  0.5 m/s he falls along his velocity (the blow came from the opposite side); slower than that, the old forward fall.
  This makes the hockey game's existing checks directional without touching the pack.
- Visual only, unless your arm's route says otherwise: the capsule, positions, velocities, timings and signals are the
  simulation, and the state hash of every existing pack must stay exactly what it is today. What the rig draws is not
  in the hash.

## The lab (the yardstick: do NOT edit `engine/kernel/examples/ex_hit_lab/**` or the shared cases in 670-falls.sh)
- One scripted 12.5 s run (750 frames): an attacker (red, with a stick) hits a standing victim (blue) from the FRONT,
  the SIDE (his right) and BEHIND, at 0.3 and 0.7 (`TLHit.react`) and 1.2 (`TLHit.down(victim, 40, from_dir)`), each big
  hit followed by the get-up; then the hockey body check on ice (two skaters with sticks, the pack's numbers, from the
  victim's right, `TLHit.down` with the direction). The camera "lab" is side-on: every fall away from the blow goes to
  the RIGHT of the picture.
- It measures, per hit, how far the victim's head (the rig socket `head`, relative to his body, from the frame before
  the hit) went away from / toward the blow, its lowest height, and where it lies 30 frames after the hit (`lie_away`).
  Today: the front big hit lies 1.11 m TOWARD the attacker (he falls forward into him), the side one 0.00, taps move the
  head 0.00-0.03 m.
- `bash engine/tools/selftest.sh falls.` runs the shared cases: `falls.lab_spec` is RED on the base on purpose; your
  route must make it green (every big hit lies >= 0.4 m away from the blow, every tap flinches >= 0.04 m away and more
  away than toward, every 0.7 flinch is larger than the 0.3 one from the same side, the check lies >= 0.3 m away).
  `falls.lab_invariants` (the lab twice, same state hash; the state holds a digest of the victims' sockets every frame,
  so a pose that differs between two runs fails it) must stay green.
- Headless run with the numbers: `TL_QUIET=1 bash engine/tools/tl.sh bot --pack=engine/kernel/examples/ex_hit_lab --frames=900`.
- **See it**: `bash .tl/rec_lab.sh . .tl/clips/lab-<n>.mp4` records the run in a window with the movie writer (about a
  minute; a window opens on the second screen; that is fine). Then make a contact sheet you can look at:
  `ffmpeg -y -loglevel error -i .tl/clips/lab-<n>.mp4 -vf "select='not(mod(n\,10))',scale=480:270,tile=6x5" -frames:v 1 .tl/clips/sheet-<n>.jpg`
  and LOOK at it (and at single frames around each hit: frames 40, 80, 120-190, 210, 250, 290-360, 380, 420, 460-530,
  600-700). Judge as the owner will: does a front hit send him backward? Is the get-up a real get-up (hands or knee to
  the floor, pushing up) or a slide? Is a tap visible? Does anything pop, sink into the floor, or stretch?

## Where you may write (anything else: put it in your report as a request)
- `engine/kernel/api/tl_hit.gd`.
- `engine/kernel/api/tl_biped.gd`: it sits at the 600-line cap. Split it, never grow it: move code (for example the
  K2 down / stumble section) into a new helper file such as `engine/kernel/api/tl_biped_hit.gd` (NO `class_name`; load
  it with `const _X = preload("res://kernel/api/<file>.gd")` as tl_biped.gd already does for `_Walker`). No `.gd` file
  you touch may end over 600 lines (`node devx/bin/tl.mjs arch` checks it).
- `engine/rigs/biped/**` (new files welcome), and `engine/rigs/tl_rig_biped.gd` only as little as needed (it is at 597
  lines: stay at or under 600), `engine/rigs/RIGS.md` (document your clips and params; the part below
  `<!-- generated below -->` is regenerated with `bash engine/tools/k.sh docs`).
- `engine/kernel/API.md`: append a short paragraph at the END of section 6 titled "Falls arm <X> (21 Nov, experiment)".
- `engine/tools/selftest.d/671-falls-<arm>.sh` (and up to 679) for your own cases; do not change 670-falls.sh.
- After adding any `.gd` file run `"$G" --headless --path engine --import` once (G = the Godot console exe below) so its
  `.gd.uid` exists (`tl arch` fails on a `.gd` without its `.uid`).

## Laws (they bind you; a broken one disqualifies the arm)
- **No public API change.** Do not change or remove any public member of a kernel class (`docs/generated/API-V1.json`
  lists them; `node devx/bin/tl.mjs arch` rule `api-v1` checks). Add only members whose names start with `_` on kernel
  classes, and no new `class_name` anywhere (kernel or rigs). `KERNEL_API` stays "1.12".
- **kit, rigs and style reference nothing outside themselves**: no `TLBiped`, `TLHit`, `TLContext` or `res://kernel/...`
  in `engine/rigs/**` (`tl arch` rule `module-walls`). The kernel talks to the rig only through duck-typed calls
  (`rig.play(&"clip", blend)`, `rig.set_param(&"name", value)`, `rig.has_method(&"x")` then `rig.call(...)`), and must
  still work with a rig that has none of your clips (the kernel's stand-in capsule: `TLStandinRig`, see `_rig_has`).
  A new runtime param of the biped rig must be declared where the rig declares `lean` (see `TLRigs.spec("biped")`),
  or be a new rig method the kernel finds with `has_method`.
- **Time is physics frames** (60 Hz): count frames, never read a clock. **Determinism**: same pack + seed + frames =
  same state hash; no `randf`/`randi` (only the kernel's seeded generator); iterate in a fixed order.
- A rig is posed only through `tick(frame)`; everything is a function of the ticks (RIGS.md: "the same calls give the
  same pose on every run").
- **Never kill a process you did not start**; other sessions use this machine. Prefer `--headless`.
- The Godot console exe: `C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe` (the
  scripts in `engine/tools/` find it by themselves). Windows 11, Git Bash.

## Verify what your change needs (the Director re-runs every gate and re-grades every claim)
- `bash engine/tools/selftest.sh falls.` (all green), `bash engine/tools/selftest.sh k2.` (all green: down, shove,
  stumble semantics unchanged).
- `bash engine/tools/k.sh selftest` (every rig and clip twice with equal hashes, budgets): green.
- `node devx/bin/tl.mjs check --tier fast`: arch, assets, cards, devx.test PASS. Run it after every round of changes,
  not only at the end. (`foreman.typecheck` says NOT RUN in this worktree because foreman's node_modules are not
  installed here; you do not touch foreman, so that one line is expected. Do not install anything.)
- The hockey pack must stay byte-identical in behaviour: `TL_QUIET=1 bash engine/tools/tl.sh bot --pack=engine/packs/hockey --test=tests/bot_check.gd`
  gives the same `state_hash` before and after your change (run it once on the untouched tree first and note the hash).
- Record the lab clip and look at it (above). Record the hockey check too:
  `bash .tl/rec_lab.sh . .tl/clips/hockey-<n>.mp4 "$PWD/engine/packs/hockey" tests/bot_check.gd 900`.

## Report (write it to `.tl/arm-report.txt` when you stop, and print it as your last message)
- What you built and why it looks the way it does (one paragraph), the clips/params/files.
- The lab's per-hit numbers (the bot summary line), the selftest and gate PASS/FAIL lines with counts, the hockey
  `bot_check` hash before/after.
- What you saw in your own clip, honestly, including what still looks wrong.
- Anything you needed outside your files.
Stop when the route is done and green, or by 17:30 local time at a clean point, whichever comes first. Budget: about
800 k tokens. Do not gold-plate: a clear, good-looking, deterministic result beats a large one.
