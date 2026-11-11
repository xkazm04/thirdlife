# P2 the kernel's physics hot path: builder report and Director verification

Brief `briefs/BRIEF-P2-HOTPATH.md`. Builder wall time 10:25 to 12:09 on 2026-11-11 (104 min; harness: 306,041 subagent tokens, 167 tool uses). Work done in the worktree `.claude/worktrees/core-p2` (branch `core-p2-hotpath`).

The builder cannot write report files; the text below is its final message, saved unchanged by the Director.
The Director's own verification is the last section.

---

## Builder report (verbatim)

**Status:** the 300-body target is met. The 600-body target is met only in quiet minutes. Hashes did not change. The full gate did not finish, so none of the three gate commands (`tl.sh selftest`, `tl.sh seeds`, `k.sh selftest`) has a result from me.

Time spent: 10:25 to about 12:09, roughly 104 minutes. The machine was at 100 % CPU for much of it. I stopped my own full-gate run at 12:08, still inside `kernel.selftest` (about 17 minutes in). I started it at 11:50 on the final files. No Godot process of mine is left running.

## What was built
The per-body `_physics_process` on `TLContact` is gone. Each pack now has one `TLContact.Tracker` node. It is an inner class of `engine/kernel/api/tl_contact.gd` and a child of the pack's `TLPack` node. It runs at process priority 100, as the contact nodes did, and walks every tracked body in one loop, in the order the bodies entered the tree. The public API is untouched: `TLBodies.make`, `TLBodies.contact`, `TLBall`, `TLVehicle` and the `hit` signal work as before. A `TLTracker` node now appears under `TLPack`.

- **Shared per pass:** one ray query object, one physics-space fetch, and one `pair` table lookup.
- **Surface from signals:** the surface a body touches now comes from the engine's `body_entered` and `body_exited` signals, not from `get_colliding_bodies()` every tick.
- **Ray casts:** a body casts its ray again only after it has moved 15 % of its reach (estimated from its speed). A puck at 30 m/s still casts every tick.
- **Resting-body shortcut:** a body that is awake but unchanged returns after two engine reads.
- **Fallback:** a contact made outside any pack call still ticks itself with the same step.

## Profile (item 1)
600 awake bodies, `w_pile`, seed 600, 400 frames, taken in quiet minutes:

| Part | ms per tick |
|---|---|
| Floor with no trackers (bodies made with `track = false`): Jolt, scene-tree sync, the pack's kicks | 0.87 (0.86, 0.87, 1.10) |
| Bodies tracked, per-tick pass switched off (contact monitoring plus the once-set material) | 1.72 to 1.77, so about +0.9 |
| Old per-body scripts, measured by instrumenting the old file | about 4.5 of a 6.8 ms iteration |
| Of which contact scan (`get_colliding_bodies` and material lookups) | 3.52 µs per call, about 2.1 ms |
| Of which ray, pair and material block | 3.26 µs per call, about 1.96 ms |
| Body-ticks that cast a ray | 226,117 of 240,000 |
| New tracker pass | 0.74 to 0.80 (casts 45,886 of about 224,000 awake body-ticks) |

Signals and `TLLaws` lookups were inside the script figures and are not split out.

Almost every ray was wasted: a box resting on boxes touches no tagged surface, so it kept casting down at another tracked body and ignoring the hit.

Added bench pack `engine/kernel/world/packs/w_pile_x`: the seed's hundred-thousands digit picks a profiling mode.

## The numbers (item 4)
Old and new were run interleaved in one sitting, as old and new engine copies. The table is the best of three of `iter_ms_p50_all_ticked`. It was taken on the second-step code; the final code is a little faster.

| Case | Old | New |
|---|---|---|
| 50 awake bodies | 0.41 | 0.29 |
| 150 | 1.20 | 0.62 |
| 300 | 2.38 | 1.26 |
| 600 | 5.62 | 2.64 |
| 10 asleep packs | 0.18 | 0.19 |
| 30 asleep packs | 0.54 | 0.63 |
| 60 asleep packs | 1.33 | 1.61 |
| `seed_wall` bot, ms per tick | 0.375 | 0.392 |
| `seed_drive` | 0.579 | 0.537 |
| `seed_paddle` | 0.257 | 0.211 |

- **Quiet minutes at 600:** I read 2.37, 2.41 and 2.54 ms on the second-step code (old about 5.0 to 5.8 then).
- **Final code at 600:** it measured 3.1 to 3.6 ms in one sitting at 100 % CPU, against 6.3 to 7.2 ms for the old code in the same sitting. I did not get a quiet-machine figure for the final code.
- **Under load:** every figure is load-affected. At 300 and above, Jolt's worker threads collapse when the CPUs are oversubscribed: the same 300-body pile read 59 to 268 ms in one bad minute, and those readings were thrown away.
- **Asleep packs:** about 10 to 20 % dearer than before. The old per-node early return was cheaper than two reads per sleeping body in a script loop.
- **Tour world tick:** not measured.

## Determinism (item 3)
Packs: 3 seeds, 8 examples, and the hockey pack at `site\ice-hockey-three-against-20261111-1\promoted\game.ice_hockey_three_against@0.1.1` with both its bots. For each I compared the smoke hash and the bot hash, old against new. I took old hashes from a copy of the engine with the original `tl_contact.gd`, and ran the new engine three times.

**No hash changed, and the three new runs equal each other.**

| Pack | smoke | bot |
|---|---|---|
| seed_wall | da4bdc3f65cc07ae | 6366b88f838e3e78 |
| seed_drive | b9adbb1967e36108 | 36635c049bc6acd8 |
| seed_paddle | bc93a9a4c892f2ab | cadd1cd9fffac7b1 |
| ex_bounce | 7bb3aefa5eae9953 | d27b4ef860ebf000 |
| ex_car | 821d717d7cfa076f | 9f4e65dac63e77ce |
| ex_kit | 66abfb9b4ab87f0d | 16db2bf1a53a1798 |
| ex_shuffle | 6a12c3a7f92fca16 | 68538f831a7dbbce |
| ex_slide | 85bd1392b620f2fc | 85bd1392b620f2fc |
| ex_wall | b88565b3236c14d1 | 477b7e7bd2bc7679 |
| pack_min | d52a03b0100e853d | 7dd11b8ebac690df |
| hockey (`bot_hockey.gd`) | b0ddd31f0f70beeb | 5af10fbc23df0d76 |
| hockey (`bot_hockey_ai.gd`) | b0ddd31f0f70beeb | 1912695680c27469 |

- **Walker:** `ex_walker` smoke and bot hashes were taken as well and are equal old and new; I did not copy them into the table.
- **Pile hashes:** `w_pile` seeds 600, 300, 150 and 50 are equal old and new.
- **Player's bot:** the hockey bots finish and pass on the new engine.
- **`invariants`:** I ran it only on the second-step code, for 11 packs. Determinism and `bot_deterministic` hold. `ex_car` and `ex_wall` fail `below_ground` at the default 3600 frames, and they fail the same way on the old engine; the selftest runs them at 1200 and 900 frames.
- **Not rerun:** `invariants` on the final code, and hockey `invariants` (it hit a time limit under load).

**One change withdrawn.** I skipped the whole pass while every body of a pack was asleep. It cut 60 asleep packs from 1.5 to 0.5 ms, but the hockey hashes moved (smoke b0ddd31f0f70beeb to 6e86f1425f8a6c6e, bot 5af10fbc23df0d76 to 821b6e7ddd2def64). The engine emits `sleeping_state_changed` after the step, so a body woken in `_pack_tick` was not stepped on its first frame and its stored velocity was stale. Without the skip the hockey hashes are the old ones again.

## Acceptance
- **600 bodies at most 2.5 ms:** met only in quiet minutes (2.37 to 2.54 on the second-step code); 2.6 to 2.9 in the interleaved sitting, and the final code read 3.1 to 3.6 in a sitting at 100 % CPU.
- **300 bodies at most 1.3 ms:** met (1.16 to 1.26).
- **Hockey pack:** it passes lint, smoke and both bots on the new engine. I did not rerun `invariants` for it.
- **Hash table:** old and new equal, each new hash stable three times.
- **`tl.sh selftest`, `tl.sh seeds`, `k.sh selftest`:** no result from me. A first chain of the three was killed on purpose when I changed the code under it. The second ran as part of `check --tier full` and was stopped at 12:08. Please run them, or `node devx/bin/tl.mjs check --tier full`.
- **`check --tier fast --changed`:** the `arch` step failed on a stale API index; after I regenerated it, `arch` passes. `cards` passes. I did not rerun the fast check on the final files.

## Why the target is only borderline
At 600 bodies the floor of Jolt plus the scene tree is 0.87 ms. Contact monitoring (needed for the `hit` signal and the surface) costs about 0.9 ms more. That leaves about 0.75 ms for the pass. A pack with audio or damage cannot switch monitoring off, because it needs hits from every body.

## Native extension (item 5)
Not started.
- **Toolchain present:** scons, cargo and rustc, and Visual Studio 2022 directories.
- **Missing:** gcc, clang and cmake on the path, and the godot-cpp sources; there is no network.
- **What it would buy:** the pass at about 0.1 to 0.2 ms instead of 0.75, so 600 bodies would reach about 1.9 ms, but contact monitoring (+0.9 ms) would stay.
- **What it would cost:** a build step per platform, and the export has to ship a library.

## Files changed
All under `C:\Users\kazda\kiro\third-life\.claude\worktrees\core-p2`:
- `engine\kernel\api\tl_contact.gd`: rewritten as described above.
- `engine\kernel\api\tl_laws.gd`: added `TLLaws.pair_cached`, a shared read-only answer for kernel loops; `pair()` is unchanged.
- `engine\kernel\API.md`: section 4 now describes how contacts are ticked, with the new costs; section 19's priority note is updated.
- `engine\kernel\api\PATCHES-P2.md`: new, see below.
- `engine\kernel\world\packs\w_pile_x\` (`pack.json`, `scripts\main.gd`, `tests\bot_wait.gd` and their `.uid` files): new profiling bench pack.
- `engine\JOURNAL.md`: a "P2" section.
- `docs\generated\API-INDEX.md`: regenerated with `node devx/bin/tl.mjs arch --index`. This is outside my scope; it is a generated file and may conflict with other builders' regeneration.

## Patches file (`engine\kernel\api\PATCHES-P2.md`)
Nothing is needed for P2 to work, and nothing is applied.
- **Optional, `pack.gd` and `worker.gd`:** call the tracker's pass explicitly inside `tick()`, so the order is written in code and not implied by priority 100. This would also put the pass inside the `TLContext.current` bracket, which `TLContact` already tolerates.
- **Cosmetic:** `entities_max` is one higher because of the `TLTracker` node.
- **`TLVehicle`:** it makes its contact with `TLContact.new()` and is picked up by the tracker unchanged.

## Proposed contract text
For `contracts/PACK.md` or the kernel notes: "A pack's tracked dynamic bodies are updated by one kernel pass per tick, at process priority 100, in the order the bodies entered the tree. Do not rely on a per-body `TLContact` `_physics_process`. A body that needs no pair overrides and no hit signals should be made with `track = false`."

## What changed for a pack author
Nothing is required. `track = false` is now clearly worth using for moving scenery. A ray-based first-touch update for a slow body can come up to about 15 % of its reach later than before. Fast bodies are exact.

## Not verified
- Final-code `invariants`, and the three gate commands.
- Any quiet-machine figure for the final code at 600 bodies.
- Tour world tick before and after.
- Behaviour if a touched body is freed without the engine sending `body_exited`: a stale surface could remain. I believe the engine does send it.
- A kinematic or untracked surface moving under a nearly stationary box is now noticed by contact, not by look-ahead.
- Windowed and live paths; I ran everything headless.

## Questions
- Is asleep-pack cost worth a safe fix? The only safe way is for every kernel wake path (`TLBodies.push`, `drive`, `TLBall.shoot`, `place`, `release`) to tell the tracker. Direct pack calls such as `apply_impulse` still could not.
- Should the explicit `tick()` call in patch 1 be adopted for visible ordering?

---

## Director verification

Done 12:09 to 12:25 on 2026-11-11 in the builder's worktree, after the builder had stopped. Two other builders were
still running the engine.

### What was re-run, and the result

| Check | Result |
|---|---|
| one pack of 600 awake bodies, old engine (main) and new, interleaved, three runs each, iteration median | old 5.69, 6.28, 8.52 ms; new 3.16, 2.85, 2.85 ms |
| 300 awake bodies, the same way | old 3.14, 2.37, 2.37 ms; new 1.32, 1.30, 1.36 ms |
| `bash engine/tools/tl.sh selftest` (the builder could not finish it) | 79 passed, 0 failed |
| `bash engine/tools/tl.sh seeds` | 24 passed, 0 failed |
| `bash engine/tools/k.sh selftest` | 86 passed, 0 failed |
| the hockey pack 0.1.1 on the new engine: lint, smoke, invariants, bot | all pass; smoke `b0ddd31f...`, bot `5af10fbc...` (blue wins, 4,888 frames): last night's hashes; one hash three times |

### What this means

- The package is about twice as fast, not three times: the 300-body target (1.3 ms) is met at the edge, the 600-body
  target (2.5 ms) is missed by 0.35 to 0.65 ms on a machine that was still busy. A quiet figure comes from the ledger
  on the merged tree.
- No hash moved. The owner had allowed every hash to change once; none had to.
- What is left at 600 bodies is the physics engine and the scene tree (0.87 ms) plus contact monitoring (about 0.9 ms),
  which the `hit` signal and surface laws need. The script pass is 0.75 ms. A native extension would save about 0.6 ms
  of it and bring a build step and a library to ship; not worth starting before the export exists.
- Asleep packs cost 10 to 20 percent more than before. The safe fix (kernel wake paths tell the tracker) is small and
  goes to round 2 with the loading package, which owns the pack's tick.

### On a quiet machine (the merged tree, 13:19)

The ledger's first two quiet runs of `pile600` (600 awake bodies) give a median tick of 2.45 and 2.44 ms. The same scenario on the
engine before this package gave 4.52 and 4.54 ms (recorded as busy). The 2.5 ms target is met.

### What is not verified

The tour's world tick before and after; `invariants` on every example with the final code (the selftest covers the
examples at their own frame counts and passes); the stale-surface case when a touched body is freed.

### Director's decisions on the builder's questions

1. The asleep-pack fix through the kernel's wake paths: yes, in round 2.
2. The explicit tracker call inside the pack's tick (the order written in code, not implied by a priority): yes, in
   round 2, with the same package.

The proposed contract sentence (one kernel pass per tick in tree order; `track = false` for moving scenery) is accepted.
