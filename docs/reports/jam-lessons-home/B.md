# Lane B status (B1: a person's hand)
SEEN 01:13 started; baseline seed_paddle bot runs for seeds 1..10 before any edit
SEEN 01:19 TLHand written (engine/kernel/api/tl_hand.gd); seed_paddle bot ported; regular seed 1 = lost 0:5 in 2831 frames (perfect: won 5:0 in 4485); running the 10-seed table
SEEN 01:23 perfect port: seeds 1..10 identical result and state_hash to the pre-port baseline (status/runs/base_*.json vs a_bot_win_*.json). Hand v1: regular won 1 of 10, newcomer 0 of 10; one hash twice per seed for both.
SEEN 01:23 trace (newcomer, seed 8, temp copy): on a reversal the old key is held late while the new key is pressed: both of A and D down for 12..20 frames, the paddle stands still. A person does not hold opposite keys: fix = the new key of an opposite pair goes down only after the old one is up. v1 table superseded.
SEEN 01:28 hand v2 (opposite keys never both down; a turn lets go late by overshoot, not release_late + overshoot): regular won 1/10, newcomer 0/10, one hash twice per seed. Ablations on a temp copy (not in repo), regular profile: keys only (no delay) won 10/10 5:0; keys + reaction 8..13 only won 0/10; full regular hand with centre-of-paddle aim won 1/10. So the analog axis was not the crutch; the reaction delay is, because the bot's servo (error*4, re-decided every frame) is a closed loop on its own paddle and a delayed bang-bang loop oscillates.
SEEN 01:28 premise check: the brief's model delays every intent change by the reaction. A person reacts late to the world (a serve, a reversal) but stops a movement they started by feed-forward (released early or late by a little, not a full reaction later). v3: presses and turns take the reaction; a stop takes only release_late (sticks still apply). Both tables reported.

FOR K (the pointer aim; the seam is one method in engine/kernel/api/tl_hand.gd)
- `TLHand.set_aim(action: StringName, point: Vector3)`, named after your `ctx.input.set_aim` (read in jl-kernel's tl_input.gd at 01:25, not run).
  Today: under `perfect` it calls `ctx.input.set_aim(action, point)` when `ctx.input.has_method(&"set_aim")` (through `.call`, because
  this tree's TLInput has no such method yet); under any other profile it only stores `_aim = [action, point]` and does nothing.
- When yours lands: replace the `.call` with a direct `_ctx.input.set_aim(action, point)`; then, for a person's profile, in `tick()`:
  per aim action keep {from, to, start, lag, miss}; a new target farther than `aim_miss` from the last one draws `lag` from
  `params["aim_lag"]` (sharp 4..8, regular 8..16, newcomer 14..26 frames) and a miss offset (angle `_rng.randf() * TAU`, radius
  `_rng.randf() * params["aim_miss"]`: 0.15 / 0.3 / 0.6 m) from the hand's own generator; the pointed point moves linearly from where it
  was to target + miss over `lag` frames and is sent with `ctx.input.set_aim` every frame; it never rests exactly on the target.
  A `clear_aim` intent on the hand passing through to `ctx.input.clear_aim` is the second member you would add.
- `perfect` must keep calling exactly what the bot asked, on the same frame (that is what keeps old bots' hashes).

FOR H (the hockey pack's bot adopting the hand: tests/bot_hockey.gd, read in jl-hockey at 01:25)
1. Members: `var hand_profile: String = "perfect"` and `var hand: TLHand`; in `_bot_setup`: `hand = TLHand.create(ctx, hand_profile)`.
2. `ctx.input.set_axis(&"left", &"right", dir.x)` + `ctx.input.set_axis(&"up", &"down", dir.y)` become
   `hand.steer(&"left", &"right", &"up", &"down", dir)` (under `perfect` it makes exactly those two calls in that order).
3. The frozen / over branch: `hand.steer(&"left", &"right", &"up", &"down", Vector2.ZERO)` then `hand.tick()` before the `return`
   (not `release_all`, which would also release shoot and change the perfect hash).
4. `ctx.input.tap(&"shoot")` becomes `hand.tap(&"shoot")`; pass on Q and the ability on F the same; a sprint hold is
   `hand.press(&"sprint")` / `hand.release(&"sprint")`, said every frame as a wish (the hand sees changes, not calls).
5. The last line of `_bot_tick`, and every early return: `hand.tick()`.
6. Prove the port: the perfect bot's `state_hash` and result before and after, seeds 1..3 (they must be equal).
7. `tests/bot_hockey_regular.gd` and `tests/bot_hockey_newcomer.gd`: `extends "bot_hockey.gd"` and `func _init(): hand_profile = "regular"`;
   register them in pack.json `tests` after the first bot (invariants runs the first one).
8. In `_bot_result()`: when `not hand.is_perfect()`, ok = played to the end + `hand.stats()["decisions"] > 0`; win or lose is a number in
   the result, not the verdict; put `"hand": hand.stats()` in the result.
9. Every measured rate the jam quoted (loose pucks taken, shots on goal, the aggression ladder's win share) is read through `regular`
   and `newcomer` and quoted as "level N: regular won a/10, newcomer b/10"; a perfect-hand number is labelled perfect.
10. Once K's aim lands, the stick follows `hand.set_aim(&"stick", point)` (a no-op for person profiles until FOR K is filled in).

SEEN 01:34 hand v3 (feed-forward stops): perfect 10/10 won, regular 2/10, newcomer 1/10; regular and newcomer one hash twice per seed (a3 = b3). Attribution on a temp copy (same 10 seeds): keys only 10/10, + reaction 10/10, + taps 10/10, + sticks and lapses 10/10, + late release and overshoot 5/10, everything 2/10, everything with centre-of-paddle aim 5/10.

READY 01:37 package B1, branch spark-jam/hand (no git run by me)
Files (all in the worktree):
- engine/kernel/api/tl_hand.gd (+ tl_hand.gd.uid made by Godot's import)  NEW class TLHand
- engine/seeds/seed_paddle/tests/bot_win.gd  ported onto TLHand (profile perfect); a person-hand branch in _bot_result
- engine/seeds/seed_paddle/tests/bot_win_regular.gd, bot_win_newcomer.gd  NEW (extends "bot_win.gd", sets the profile)
- engine/seeds/seed_paddle/pack.json  "tests" gained the two files (after bot_win.gd, so invariants still runs bot_win). Outside the
  literal file list of my start message (the runner only runs tests named in the manifest); say if you want them elsewhere.
- devx/templates/bot/bot_hand.gd NEW; devx/lib/commands/new.mjs: --hand <profile> (profiles read from tl_hand.gd's PROFILES)
- engine/seeds/README.md: section 7 "A bot is not a person" + one pointer line in section 5
- engine/kernel/API.md: section 15 subsection "TLHand" + one pointer line in section 8
- status/B.md, status/runs/* (raw tl.verify/1 reports, scripts that made them)

Kernel members added (api-v1 wants 1.2; yours to settle): class TLHand extends RefCounted;
  consts PROFILES, ON, OFF; vars profile: String, params: Dictionary;
  static create(ctx: TLContext, profile_name: String = "regular", overrides: Dictionary = {}) -> TLHand; static profiles() -> PackedStringArray;
  is_perfect() -> bool; press(action: StringName, value: float = 1.0); release(action: StringName); tap(action: StringName, frames: int = 1);
  set_axis(negative: StringName, positive: StringName, value: float); steer(left, right, up, down: StringName, direction: Vector2);
  release_all(); set_aim(action: StringName, point: Vector3); tick(); stats() -> Dictionary.

Acceptance:
- perfect port same result and state_hash: MET. seeds 1..10 before (status/runs/base_N.json) and after (a3_bot_win_N.json) identical:
  1 dff1a390470352e7 5:0/4486f, 2 07171eb432cdc37f 5:0/4322, 3 014aacdc67adf866 5:0/6805, 4 4ac0091deef4bc79 5:0/2450, 5 ce5d53f0006a3e9e 5:0/1296,
  6 19ab1a278faf50de 5:0/5267, 7 2e9c50d9e64b82ea 5:0/7629, 8 f5bbe9c1cd7a7b29 5:0/8007, 9 2ceb47b305aa2d53 5:0/6685, 10 af88ecb72dd80a19 5:0/8396.
  Re-checked seed 1 after the last edit (typed ctx): dff1a390470352e7.
- regular and newcomer deterministic + 10-seed table: MET. Two runs per seed (a3, b3), 20 of 20 hash pairs equal. Table in engine/seeds/README.md
  section 7 and status/runs/table.md: perfect won 10/10, regular 2/10, newcomer 1/10.
- draws only from a kernel-seeded generator; invariants.bot_deterministic true: MET with a stated deviation. The hand has its own
  RandomNumberGenerator seeded from ctx.seed + profile + stream, NOT ctx.rng, so the game's serves are the same under every hand (drawing
  from ctx.rng would change the serves and mix two effects in the table). No randf(). invariants on seed_paddle: all 10 checks ok.
- tl new bot --hand regular on a temp pack lints and runs: MET. Temp pack from `tl new pack` in %TEMP%\b_hand_pack_final: lint passed, bypasses [];
  bot passed twice, hash edbd4be2d237eab5 both; `--hand bogus` exits 2 naming the profiles.
- tl check --tier fast --changed green: NOT MET as a whole. assets PASS, cards PASS; arch FAIL only on api-index-fresh + api-v1 (the new class);
  devx.test 123 pass / 3 fail, the three are the real-tree arch tests (api-v1 test file, "real tree: green", "gate step: green real-tree run"),
  same cause; foreman.typecheck could not run (foreman/node_modules missing in the worktree).
- tl arch green except the API version rule: NOT MET literally: api-v1 and api-index-fresh fail, both from the new class; the other 7 rules pass.
  Regenerating docs/generated/API-INDEX.md and setting KERNEL_API 1.2 are not my files.

Premise I changed (brief: reaction delay on every intent): measured, a full reaction on every stop turned the bot's per-frame servo into a
delayed on/off loop (regular won 1/10, v2). v3 delays starts and turns by the reaction and stops by release_late only. v2 numbers kept in
status/runs/a2_*, b2_*. The table also measures the bot's policy (edge aim): with centre aim the regular hand wins 5/10.
Not seen / not run: sharp profile on the paddle; any capture (nothing visual changed); the hockey pack; K's set_aim (only read);
selftest.sh (p7.record_bot uses bot_win; its hash is unchanged, not run). seeds.sh run twice at 01:38: no FAIL line in either run.
