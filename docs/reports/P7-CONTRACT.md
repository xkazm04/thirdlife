# P7 the simulation contract: builder report and Director verification

Brief `briefs/BRIEF-P7-CONTRACT.md`. Builder wall time 13:22 to 15:02 on 2026-11-11 (100 min; harness: 476,729 subagent tokens, 195 tool uses). Work done in the worktree `.claude/worktrees/core-p7` (branch `core-p7-contract`).

The builder cannot write report files; the text below is its final message, saved unchanged by the Director.
The Director's own verification is the last section.

---

## Builder report (verbatim)

P7 REPORT: the simulation contract (API v1, recorded input, a hash that covers everything)
Builder, worktree C:\Users\kazda\kiro\third-life\.claude\worktrees\core-p7, branch core-p7-contract. Start 13:22:38, end 15:02 (2026-11-11).

## STATUS

Items 1 to 5 are built and proven; item 6 (the visitor's keys) is not built. `node devx/bin/tl.mjs check --tier full` exits 0 on the final files.

Four things the Director should know first:

1. **After merging the other packages, `tl arch` will fail on rule `api-v1` if any of them added a public member.** Run `node devx/bin/tl.mjs arch --index --freeze` once to freeze the merged surface as 1.0. After tonight an addition is 1.1 and a change is 2.0.
2. **Input values are now rounded to 0.001 when they are latched.** I decided this, not the brief. A float written as decimal text did not read back as the same double through Godot's JSON reader, so the first record failed its read-back check. The cost is that bots steering with analogue values play a slightly different game (table below). All bots still pass. See question 1.
3. **The world's own hash (`engine/kernel/world/pack.gd`, not my file) does not cover the generator and the input yet.** The world proofs compare world with world and pass. The patch is section 1 of the patches file and has not been run.
4. **Two bugs of mine were caught by the proofs and fixed.**
   - The first new hash sorted action names as StringNames, which sort by memory address. Hockey smoke gave a different hash in 1 run of 3, then 1 of 30. Names are now sorted as text; 30 of 30 runs agree.
   - I moved `host._intify` and `world_supervisor.gd` calls it. The third full gate failed `p1.world_runaway`. It is back as a one-line delegate.

## PER ITEM

### 1. API v1, written down by a machine
- `docs/generated/API-V1.json` (schema `tl.api/1`, version 1.0, 41 classes, 581 members) lists every public class of `kernel/api`, kit, rigs and style: what it extends, methods with full signatures, signals, properties, constants.
- `devx/lib/arch/apicontract.mjs` holds rule `api-v1`:
  - A member removed or changed under the same major fails, and the finding names it.
  - An addition without a new minor fails. A method that only gains defaulted parameters at its end counts as an addition.
  - A version may not go back, and the baseline can never hold an API break.
- `tl arch --index` regenerates the file and refuses to write over a break. `--freeze` writes regardless. `--root <dir>` judges another tree.
- `KERNEL_API` is `"1.0"` in `engine/kernel/runner/manifest.gd`.
- Proof:
  - `node devx/bin/tl.mjs arch --broken-demo <empty dir>` copies the API sources, removes the parameter of `TLBall.shoot`, and prints `FAIL api-v1 ... method TLBall.shoot changed: it was func shoot(impulse: Vector3) -> void, it is func shoot() -> void`.
  - `node devx/bin/tl.mjs arch` on the real tree: 9 rules PASS.
  - `arch --index` twice: "unchanged" both times.
  - `node --test devx/test/arch.test.mjs`: 22 pass, 3 of them new.

### 2. Input is a record
- `TLInput._sample()` is the record: every value that is not zero is kept as `[frame, action, value]`.
- The pointer is three kernel actions, `tl.look_x`, `tl.look_y`, `tl.zoom`, filled in `TLInput._unhandled_input`. `TLOrbitCam` reads them in its physics frame; its own mouse handler is gone.
- New file `engine/kernel/runner/session.gd` reads and writes `tl.input/1`, with a read-back check on write. It also holds the `replay` verb and a scripted device tool for tests.
- The record has eight keys, four more than the brief's: `{schema, pack, seed, mode, max_frames, length, end, frames}`. `length` and `end` are needed so a replay stops on the same tick; `mode` and `max_frames` restore what `ctx` told the pack.
- Commands:
  - `tl.sh bot --record=<file>`
  - `tl.sh play --record=<file>`
  - `tl.sh replay --pack=<dir> --input=<file> [--record=<file>]`
  - Scripted session for tests: `tl.sh play --headless --frames=N --devices=<file>`
- Proof, bots recorded and replayed (each hash is the same for the bot and its replay):

  | pack and bot | hash |
  |---|---|
  | seed_paddle | dff1a390470352e7 |
  | seed_drive | b912bc471e4967a9 |
  | seed_wall | cb75fb26a1e80254 |
  | hockey bot_hockey | 7326d67aeb26ad7a |
  | hockey bot_hockey_ai | de74f3a77315f9a5 |

  For paddle, `replay --record` writes the same file byte for byte.
- Proof, mouse on the wall seed (600 frames: 30 frames of right-button drag, two wheel notches, W, Space, D):
  - Session a9e62096879b5a5a, its replay a9e62096879b5a5a.
  - The same keys without the mouse: 23133b05cc1e3bef.
  - The same device script in a real window gave the same record byte for byte and the same hash.
- A session that ends by closing the window also writes its record (case `p7.keys_window_closed_keeps_record`).
- Record size: 704 KB for the 17,719-frame hockey bot.

### 3. The hash covers what can differ
`engine/kernel/host/statehash.gd` now hashes bodies, `_pack_state()`, the generator's seed and state, and every action's value now and one frame ago. The worker's `--result` file also gets `hash_parts`.

Old against new, 12 packs, smoke and every bot. Every new hash was the same in three runs, plus a fourth after the last code change; all 100 exits were 0.

| pack | run | old hash | old frames | new hash | new frames |
|---|---|---|---|---|---|
| seed_paddle | smoke | bc93a9a4c892f2ab | 3600 | ee4d8b45a7f2ac02 | 3600 |
| seed_paddle | bot_win | cadd1cd9fffac7b1 | 6776 | dff1a390470352e7 | 4486 |
| seed_drive | smoke | b9adbb1967e36108 | 3600 | 2bbdfd7421e95241 | 3600 |
| seed_drive | bot_laps | 36635c049bc6acd8 | 3516 | b912bc471e4967a9 | 3517 |
| seed_wall | smoke | da4bdc3f65cc07ae | 3600 | 89e54c51968a58ce | 3600 |
| seed_wall | bot_knock | 6366b88f838e3e78 | 1221 | cb75fb26a1e80254 | 1221 |
| pack_min | smoke | d52a03b0100e853d | 3600 | d8d8ca923cd99b3a | 3600 |
| pack_min | bot_roll | 7dd11b8ebac690df | 228 | 5e6e16bb661ee81a | 228 |
| ex_bounce | smoke | 7bb3aefa5eae9953 | 3600 | 10a38accecfe67b3 | 3600 |
| ex_bounce | bot_bounce | d27b4ef860ebf000 | 241 | 545cd7c35ab2a361 | 241 |
| ex_car | smoke | 821d717d7cfa076f | 3600 | 7a615c6f063b123a | 3600 |
| ex_car | bot_slalom | 9f4e65dac63e77ce | 1872 | 3a459d0fe25e7853 | 1872 |
| hockey | smoke | b0ddd31f0f70beeb | 3600 | eed5cf0dec85f89e | 3600 |
| hockey | bot_hockey | 5af10fbc23df0d76 | 4888 | 7326d67aeb26ad7a | 8130 |
| hockey | bot_hockey_ai | 1912695680c27469 | 14236 | de74f3a77315f9a5 | 17719 |
| ex_kit | smoke | 4bfce59850052569 | 3600 | 65ba8cd2be8cf317 | 3600 |
| ex_kit | bot_kit | 34b19960cc4c5308 | 332 | 6b270cedbf59690d | 332 |
| ex_shuffle | smoke | 6a12c3a7f92fca16 | 3600 | 1fabfac41f368673 | 3600 |
| ex_shuffle | bot_shuffle | 68538f831a7dbbce | 254 | 40aafd89ecafea90 | 254 |
| ex_slide | smoke | 85bd1392b620f2fc | 3600 | 25af8145484d8262 | 3600 |
| ex_slide | bot_slide | 85bd1392b620f2fc | 671 | 25af8145484d8262 | 671 |
| ex_walker | smoke | fe8a061c8d2492c4 | 3600 | c96f2ea3f95bdf55 | 3600 |
| ex_walker | bot_walk | 8d1831dc62dfe91a | 371 | f1c7b53757c34040 | 371 |
| ex_wall | smoke | b88565b3236c14d1 | 3600 | 632ede958ec1b872 | 3600 |
| ex_wall | bot_wall | 477b7e7bd2bc7679 | 454 | a5d0e53800b3acd3 | 454 |

- For hockey smoke the `bodies_and_state` part of the new hash is b0ddd31f0f70beeb, the old hash: the idle run's physics did not move, only the coverage changed.
- Frame counts moved for paddle, drive and both hockey bots because of the 0.001 rounding.

### 4. The fence follows the seam
- 16 new rows in `engine/kernel/runner/lint.gd`, in three groups:
  - Device reads past `ctx.input`: `InputEvent*` subclasses, `_gui_input` / `_unhandled_key_input` / `_shortcut_input` handlers, `set_process_input`, mouse positions, `Button.new()` and other clickable controls, `accept_devices`.
  - Other clocks: `func _process(`, `Timer`, `create_tween` / `Tween` / `AnimationPlayer`, `get_process_delta_time`.
  - Other packs and the kernel's side: `get_world_3d`, `.holder` as a property, `_` members of `ctx` / `ctx.input` / `ctx.cameras`, `TLContext.current`, `get_nodes_in_group`.
- **The brief's premise was wrong on one point.** A pack with `func _input(event)` does not fail lint: `bad_bypass` passes with exit 0, as PACK.md says. I left it a counted bypass and closed it at run time: the worker switches a pack script's event handlers off when the node is ready. Control: with that line removed, `p7.fence_handler_switched_off` fails (the handler ran 3 times).
- Proof: lint passes on all 3 seeds, 8 examples, both hockey copies, marble run, paddle court and `w_pile`. `w_pile_x` fails on `get_parent(`, an older rule, not one of mine.

### 5. Keys and the panel
- Entry 1: `TLInput.keys_taken()`. Space was held for frames 10 to 79 with a text field focused for 30 to 59; the record has the key in 10..29 and 60..79 only.
- Entry 2: Esc with a visible `TLDesigner` layer at frame 20 did not end the run; Esc at 50 ended it (51 frames).

### 6. Visitor's keys: not built
The keys are read in `engine/kernel/world/draw/view.gd`, another builder's file; `visitor.gd` reads none. Proposal in patches section 3.

### Cost
- One `_sample()` before P7 against now, same process, best of 7 × 100,000, on a busy machine: no action 0.37 → 0.55 µs, two actions 1.45 → 1.49, six 4.30 → 4.81.
- My first version cost 4.2 µs for a pack with no action. I changed it so the pointer is sampled only while it is alive.
- `tl perf` in the gate said "machine BUSY: measured but NOT judged", so there is no ledger line.

## ACCEPTANCE CHECKS

1. **`tl arch` fails on a broken v1 signature and names it; passes on the real tree; description stable.** Yes (item 1 commands).
2. **A recorded session replays to the same hash.** Yes: paddle dff1a390470352e7, wall with mouse a9e62096879b5a5a. Run `bash engine/tools/selftest.sh p7.record` and `p7.mouse`.
3. **kernelApi 1.0 runs, 2.0 is refused readably, 0.1 handled.** Yes. `bash engine/tools/selftest.sh p7.api` (6 cases).
   - 2.0 message: `kernelApi '2.0' cannot run on this kernel, which offers API 1.0: the pack was built for major version 2 and this kernel is major version 1 ...`
   - **0.1 packs are accepted by a stated rule, not migrated**: "0.1" is read as "1.0" (`LEGACY_API` in manifest.gd). Reports now say `"kernelApi":"1.0"`.
4. **Hash table, gates, world proofs.** Table above. `world.same`, `world.proof` (case `world.walk_proof`) and `world.tour` passed standalone at 13:51 and again inside the final `kernel.selftest`.
5. **`check --tier full` green.** Yes, exit 0 at 15:01:
   - arch 9 rules, devx.test 126, foreman.test 158, kernel.selftest 101 cases (20 new, 12.2 minutes), kit.selftest 87, seeds 24.
   - perf: not judged (machine busy).
   - item.selftest and ui.selftest: skipped; they need `site/` of the main checkout.
6. **Proposed contract text.** Below.

Hockey through all verbs: lint 0, smoke ×4, invariants 0, capture 0 (picture looked at: rink, six skaters, scoreboards), both bots, both replays.

## FILES CHANGED

Engine:
- `engine/kernel/api/tl_input.gd`: the latch is the record; pointer actions; `STEP`; `keys_taken()`; record, feed and hash hooks.
- `engine/kernel/api/tl_orbit_cam.gd`: mouse handler removed; reads the pointer actions.
- `engine/kernel/api/PATCHES-P7.md`: new.
- `engine/kernel/runner/session.gd` (+ `.uid`): new. `tl.input/1`, replay verb, device script.
- `engine/kernel/runner/worker.gd`: session hooks, replay mode, handler switch-off, window close, `hash_parts`; 610 → 596 lines.
- `engine/kernel/runner/manifest.gd`: `KERNEL_API` 1.0, the version rule and its reason text.
- `engine/kernel/runner/lint.gd`: 16 fence rows; exactly 600 lines, the budget.
- `engine/kernel/runner/verbs.json`: verb `replay`, option `record` on `bot`.
- `engine/kernel/host/statehash.gd`: generator and input in the hash; origin argument; `canon` / `plain`.
- `engine/kernel/host/host.gd`: `replay`, `--record`; 610 → 605 lines.
- `engine/tools/tl.sh`: `replay`, play options, path arguments.
- `engine/tools/selftest.sh`: 20 cases `p7.*`.
- `engine/kernel/API.md`: version 1.0, sections 8, 12, 16, new section 22.
- `engine/JOURNAL.md`: P7 section.

Devx and docs:
- `devx/lib/arch/apicontract.mjs`: new.
- `devx/lib/arch/apiindex.mjs`: signals and properties.
- `devx/lib/arch/checkers.mjs`, `core.mjs`, `devx/arch.rules.json`: the rule.
- `devx/arch.baseline.json`: four findings held (below); `host.gd` held at 605 (was 610); `worker.gd` off the list.
- `devx/lib/commands/arch.mjs`: `--root`, `--freeze`, `--broken-demo`.
- `devx/lib/commands/play.mjs`: passes `--record` and `--seed` through.
- `devx/lib/gate/godot-step.mjs`: script step timeout 15 → 30 minutes.
- `devx/test/arch.test.mjs`: 3 tests.
- `devx/templates/pack/pack.json`: kernelApi 1.0.
- `docs/generated/API-INDEX.md`, `docs/generated/API-V1.json`: regenerated.

Not changed: `tl_context.gd`, `visitor.gd`.

## PROPOSED CONTRACT TEXT

### contracts/PACK.md
Title: "Pack contract (kernelApi 1.0)". Manifest row:

> `kernelApi` | string, `major.minor`, `"1.0"` today | yes | the kernel API the pack was built against. The pack runs when its major equals the kernel's and its minor is not greater. `"0.1"` is the name this surface had before it was frozen and is read as `"1.0"`. Anything else is a schema error that says which side is ahead.

New section:

> ## Amendments of 2026-11-11 (core run, P7): the simulation contract
> A game reaches the engine through the kernel API and its recorded input, nothing else.
>
> **API version.** `docs/generated/API-V1.json` (`tl.api/1`: `{schema, version, note, classes: {<Class>: {file, extends, consts[], signals[], props[], funcs[]}}}`) is generated from the sources and is the contract of the version in `engine/kernel/runner/manifest.gd`. Removing or changing a listed member needs a new major. Adding one needs a new minor; a method that gains parameters with defaults at its end is an addition. Names starting with `_` are not part of it. `tl arch` rule `api-v1` enforces this and names the member.
>
> **Input record `tl.input/1`.** `{"schema", "pack", "seed", "mode", "max_frames", "length", "end", "frames": [[frame, "action", value], ...]}`. All eight keys are required; unknown keys are errors. `frames` has one entry per action whose value was not zero in a frame, in frame order. `length` is the frames ticked. `end` is `"step"` (stopped after the last frame's physics step) or `"tick"` (stopped inside the last frame: a bot that was done). `mode` and `max_frames` are what `ctx` told the pack.
>
> **Input values** are multiples of 0.001, rounded when latched. The pointer is three kernel actions declared in every pack: `tl.look_x`, `tl.look_y` (pixels of a right-button drag in the frame) and `tl.zoom` (wheel notches, + is out).
>
> **State hash** covers every physics body under the pack, `_pack_state()`, the seeded generator (seed and state) and the input state (every action's value in this frame and the one before).
>
> **Fence, added.** Refused: `InputEvent*` subclasses, `_gui_input` / `_unhandled_key_input` / `_shortcut_input` handlers, `set_process_input`, mouse positions, controls that take clicks or keys, `accept_devices`; `func _process(`, `Timer`, `create_tween` / `Tween` / `AnimationPlayer`, `get_process_delta_time`; `get_world_3d`, `ctx.holder`, `get_nodes_in_group`, `TLContext.current`, any `_` member of `ctx`, `ctx.input` or `ctx.cameras`. `Timer.new()` was a counted bypass and is now refused. An `_input` / `_unhandled_input` handler is still a counted bypass and never runs: the kernel switches it off.

Also change line 97, "`kernelApi` stays `0.1`", to "was 0.1 then; 1.0 since P7".

### contracts/RUNNER.md
Title and report example: kernelApi 1.0. Verb table:

> `bot`: add `--record=<file.json>` (writes the run's input as `tl.input/1`).
> `replay` | V2 | `--input=<file.json>` (required), `--record=<file.json>` | runs a recorded session again: the record's seed, length, mode and samples; no bot is loaded and no device is read. Fails on any script error or watchdog trip, or when the run does not reach the record's length.

Check ids added: `replay.complete`, `record.written`. And:

> `play` (not a verify verb) takes `--record=<file.json>`; the record is written when the session ends by Esc or by closing the window. For tests: `--headless --frames=N --devices=<file> --result=<file>`, where the devices file is a list of `[frame, kind, a, b]` with kinds key, drag, wheel, field, panel, close.
> The hash changed once on 2026-11-11 (P7). Hashes from before are not comparable.

Once this text is in, run `node devx/bin/tl.mjs arch --update-baseline`. The four held findings (`tl.input/1`, `doc-verb:replay`, `doc-opt:input`, `doc-opt:record`) then drop out.

## PATCHES FILE

Full exact text is in `engine/kernel/api/PATCHES-P7.md` in the worktree. None of it is applied or run. By section:

1. **`engine/kernel/world/pack.gd`, the world's hash.** Delete `_q`, `_put_v3`, `_hash_node` and replace `state_hash()` with:
   ```gdscript
   func state_hash() -> String:
   	var tail: String = str(WorkerScript.call("_canon", entry.call("_pack_state"))) if entry != null and entry.has_method("_pack_state") else ""
   	return (load("res://kernel/host/statehash.gd") as GDScript).call("hash", pack_node, tail, ctx.rng, ctx.input, ctx.origin)
   ```
   Every world hash changes once. A pack alone at the origin then hashes as `tl.sh smoke` does.
2. **`pack.gd` or `world.gd`, handlers in a world.** A `node_added` handler that switches a pack script's event handlers off at ready, as the worker does (scripts of the pack by path, once per node). The worker's version is verified; this one is not.
3. **`engine/kernel/world/draw/view.gd`, the visitor's keys (proposal, not exact text).** Give the world one `TLInput` with actions forward, back, left, right, run, enter, leave; sample it once per world tick; let `_live_input()` read `strength()`. Its record is the walk and can be fed back or written as a `tl.walk/1` script.
4. **`_input` handler as a fence error.** Three places change together: move the row from `BYPASS` to `FENCE` in lint.gd and widen `InputEvent\w+` to `\w*`; delete line 24 of `bad_bypass/scripts/main.gd`; adjust selftest case `bad.bypass` and add the handler to `bad_fence`.
5. **`foreman/`.**
   - `foreman/src/manifest.ts` line 12: `KERNEL_API = "0.1"` → `"1.0"`.
   - `foreman/src/test/engine.test.ts` line 90: expects `"0.1"` → `"1.0"`. It is green today only because it runs against `site/_engine_snapshot3`.
   - `foreman/src/testing/fake-runner-core.ts` line 113: `"0.1"` → `"1.0"`.
6. **Seeds, examples, bench packs.** `"kernelApi": "0.1"` → `"1.0"` is optional. `engine/tools/item.sh` line 303 still passes (0.2 is refused: major 0 is not 1).
7. **`contracts/`.** As described above.
8. **`engine/ui/PATCHES.md`.** Entries 1 and 2 are applied; its header "None of these is applied" is stale for them. Entry 3 is not applied.
9. **After the merge.** `arch --index --freeze` once, as in STATUS point 1. Look at any "was removed" or "changed" finding before freezing.

## WHAT CHANGED FOR A PACK AUTHOR
- Write `"kernelApi": "1.0"`; 0.1 still runs.
- `ctx.input` values are multiples of 0.001: `press(&"left", 0.4567)` reads back as 0.457.
- The mouse is `ctx.input` too: `TLInput.LOOK_X`, `LOOK_Y`, `ZOOM`. An orbit camera turns with them by itself. A bot injects with `press(TLInput.LOOK_X, 12.0)`.
- A session can be recorded and replayed.
- New lint errors: see the fence list. An `_input` handler in a pack never runs.
- `tl.sh play` no longer ends on Esc while the designer panel is open, and typed keys do not reach the game.
- Every state hash is new.

## WHAT I DID NOT VERIFY
- `item.selftest` and `ui.selftest` (skipped in a worktree). By hand I checked what my lint rows could touch: each fenced line of the five `bad_reach` packs is reported once, `play` refuses a failing pack, and marble and paddle court pass lint.
- A real person at keyboard and mouse. Devices were scripted through the engine's input path, in a real window for the wall session only. The close button was not clicked by hand.
- Patches 1 and 2 for the world.
- World hashes before P7 on this tree were not taken. In the tour, walker and kit equal their pre-P7 worker bot hashes; the others cannot be attributed.
- A judged perf run (machine busy all session).
- The Foreman against the live engine (`engine.test.ts` with `TL_ENGINE_DIR`).
- Records longer than 17,719 frames.
- `capture` on the 8 examples other than `pack_min`.

## FINDINGS
- `kernel.selftest` took 12 to 13 minutes under tonight's load; the step's wall-clock limit was 15. I raised it to 30. No case failed on timing.
- Docs that quote hashes (`kernel/world/*.md`, `docs/reports`) are stale.

## QUESTIONS
1. Keep the 0.001 rounding of input? It makes a record exact in any reader and input cheap to send, but it moved bot results. Reversing it is one line in `_sample()`, and then the record needs an exact float encoding.
2. Should `func _input` in a pack become a lint error (patch 4)? It changes PACK.md's bypass list and one example.
3. `Timer` is now refused although PACK.md lists `Timer.new()` as a counted bypass. Is that acceptable?
4. Is `replay` at level V2 right, and are the four extra record keys acceptable?
5. Apply patch 1 at the merge? It changes every world hash once.
6. How long should "0.1" stay an alias of 1.0?

## TIME
13:22:38 to 15:02, about 100 minutes of the 110.

---

## Director verification

Done 15:04 to 15:15 on 2026-11-11 in the builder's worktree. The command runs were made by a Sonnet subagent and
read by the Director (the owner's rule of this day for routine runs).

### What was re-run, and the result

| Check | Result |
|---|---|
| `node devx/bin/tl.mjs arch` | 9 rules PASS, among them `api-v1` (41 classes, 581 members) |
| `arch --broken-demo <empty dir>` | fails as it should and names the member: "method TLBall.shoot changed: it was `func shoot(impulse: Vector3) -> void`, it is `func shoot() -> void`" |
| `arch --index`, twice | "unchanged" both times for both generated files |
| `bash engine/tools/selftest.sh p7.` | 20 passed, 0 failed |
| hockey 0.1.1, `smoke` five times in a row | the same hash five times (`eed5cf0dec85f89e`); both bots give the builder's hashes |
| the three seeds, `smoke` and `bot` | all six hashes are the builder's |
| paddle: bot recorded, then replayed with a second record | both runs `dff1a390470352e7`; the two record files are identical byte for byte (43 kB) |
| hockey: `bot_hockey` recorded and replayed | both runs `7326d67aeb26ad7a`; records identical (309 kB) |
| a copy of the paddle seed with `kernelApi` 2.0, `lint` | refused, exit 1: "kernelApi '2.0' cannot run on this kernel, which offers API 1.0: the pack was built for major version 2 and this kernel is major version 1" |
| `bash engine/tools/world.sh tour tour --headless` | PASS |
| `node devx/bin/tl.mjs check --tier fast` | PASS (devx tests 126) |

Two small findings of the re-run: `arch --index` prints "unchanged" and still rewrites both files (their times
move); and `tl.sh` takes the pack as `--pack=<dir>`, not as a bare argument.

### What this settles

- The kernel API has a version that a machine holds: 41 classes and 581 members are written down, a removed or
  changed member fails the gate by name, an addition needs a new minor version. From tonight a game built against
  1.0 either runs or is refused with a sentence that says which side is ahead.
- Input is a record. A session, keys and mouse, can be written to a file and played again to the same hash. This is
  the piece replays, bug reports from players and a second player's keys all need.
- The hash covers what can differ: bodies, the pack's own state, the seeded generator and the input. Every hash in
  the repository changed once; the table in the builder's report is the new reference.
- The fence follows the seam: 16 more ways round the kernel are refused at lint, and a pack's own event handler is
  switched off at run time.

### What is not verified

A person at keyboard and mouse. The world's own hash still comes from older code and does not cover the generator
and the input (the builder's patch 1, not run). Nothing was judged on a quiet machine. The Foreman against this
engine.

### Director's decisions on the builder's questions

1. Input values stay rounded to 0.001. A record must read back exactly in any reader, and a thousandth of a stick's
   travel is below what a hand does. The moved bot results are accepted with the one-time change of every hash.
2. Yes: `func _input` in a pack becomes a lint error. A handler that is silently switched off is a trap for a
   builder. Done in round 3 (P11) with the example and the contract text.
3. Yes: `Timer` is refused. Time is physics frames.
4. `replay` at V2 and the eight keys of the record are accepted.
5. The world's hash moves to the contract's hash in round 3 (P11), with the stronger proof it makes possible: a pack
   in a world hashes as the runner hashes it alone.
6. "0.1" stays an alias of 1.0 until API version 2; packs and the Foreman write 1.0 from round 3 on.

The proposed texts for `contracts/PACK.md` and `contracts/RUNNER.md` are accepted and go in with the round's merge;
the merged API surface is frozen as 1.0 there (`arch --index --freeze`), after the Director has read every "removed"
or "changed" finding.
