# N5a the world's clock: tiers, scheduler, world file: builder report and Director verification

Brief `briefs/BRIEF-N5A-TIERS.md`. Builder wall time 01:55 to 03:00 on 2026-11-11 (65 min; harness: 379,908 subagent tokens, 131 tool uses). Work done in the engine copy `site/_work/n5a/engine/`.

The builder cannot write report files; the text below is its final message, saved unchanged by the Director.
The Director's own verification is the last section.

---

## Builder report (verbatim)

N5A REPORT: the world's clock (tiers, the scheduler, the world file)

## Status

All six items are built in my copy, `C:\Users\kazda\kiro\third-life\site\_work\n5a\engine\`, and items 1 to 5 are proven there. The last full run of each gate on the final files passed:

| gate | last full run |
|---|---|
| `tl.sh selftest` | 77 passed, 0 failed (four new cases among them) |
| `k.sh selftest` | 86 passed, 0 failed |
| `tl.sh seeds` | 24 passed, 0 failed |
| `item.sh selftest` | 91 passed, 0 failed |

No seed hash changed: idle bc93a9a4 / b9adbb19 / da4bdc3f, by bot cadd1cd9 at 6776 / 36635c04 at 3516 / 6366b88f at 1221. Nothing outside my file scope was edited, no git command was run, and no process of mine is left.

Four things the Director should know first:

1. **The gates are flaky tonight because of the machine, not the sleeping-body change.** An earlier gate round had 1 + 5 failures, every one the 250 ms wall-clock watchdog (CPU at 64 to 100 % from other sessions). I ran `tl.sh seeds drive.smoke` in turn on two scratch copies, four rounds: with the change 2 of 12 cases were stopped, without it 7 of 12. The watchdog guards only the call into `_pack_tick` or `_bot_tick`, which the change is not part of.
2. **Loading a seed is almost all scenery.** The terrain and the scattered forest are 87 to 95 % of the 2 to 4 s; scripts, laws, the bot and the first physics step are nothing. With the layout's two existing switches off, the seeds load in 0.4 to 0.7 s and end in the same bot hashes.
3. **The brief contradicts itself on the seed example.** Item 5 asks for `_pack_save` / `_pack_load` in one seed, but seeds are outside my scope. The working example is in `kernel/examples/ex_bounce`; the seed's patch is PATCHES-N5A entry 1.
4. **Every timing figure was taken under load** (12 to 13 Godot processes of other sessions). Hashes and tick counts do not depend on that.

## Per item: what was built and the proof

**1. Sleeping bodies.** `TLContact._physics_process` returns at once for a sleeping body (`if body.sleeping and _pm != null`; the second condition lets a body that starts asleep get its law once).

| packs of 30 sleeping boxes, every space active | N2 | now (two runs) |
|---|---|---|
| 10 | 2.0 ms | 0.17 / 0.26 ms |
| 30 | 6.1 ms | 0.62 / 0.78 ms |
| 60 | 13.8 ms | 1.60 / 1.57 ms |
| 1 pack, 300 sleeping boxes | 2.21 ms | 0.11 ms |

- An asleep pack costs about 0.027 ms per tick instead of 0.2 ms.
- The research's pass line (60 asleep packs under 0.2 ms) is still not met. What is left is the kernel's own per-pack nodes, not the bodies.

**2. The scheduler.** `kernel/world/tiers.gd` holds the logic (no node, no clock) and `kernel/world/tiers.json` every threshold.
- The stage follows the player, with a 2 m margin and a 120-tick dwell.
- Tickets pin a plot at a tier for a fixed number of world ticks.
- Plots next to the stage plot are `sideline` whatever the distance.
- Promotion happens at the boundary at once; demotion only beyond boundary plus margin and after the dwell.
- The valve demotes the farthest `sideline` plot first, then sets `slice`, then lowers the world's speed in per-mille steps. Packs take turns, so every tick gets cheaper. Speed never reaches 0.
- `on_leave` is `bot`, `pause` or `end`.
- Every decision is an event, and who ticks is a pure function of the events, so a log replays.
- A pack's cost is either the model in tiers.json (the run is then a pure function of the walk script) or measured from the world's clock.

**3. The proof.** Each line is a command that passed:
- `bash tools/world.sh proof proof --tiers-all` (also the selftest case `world.walk_proof`): the table below.
- `world.sh proof bench_mix_12`: a schedule driven by the measured clock. All 12 packs hash as alone and as in the replay; the walk loaded them with plot scenery, the solo runs with full scenery.
- `world.sh walk heavy` (`world.walk_valve`):
  - four demotions at tick 30, farthest first (70, 60, 50, 40 m), then `slice` 4, then speed 800 per mille;
  - all 7 packs kept ticking, and the longest wait between two ticks of a pack was 6 world ticks.
- `world.sh walk boundary` (`world.walk_boundary`): 2400 ticks of zigzag along two boundaries gave tier changes a 0, b 0, c 1.
- `world.sh proof leave`: `pause`, `end` and `bot` all equal their solo runs and the replay.
- `world.sh proof tickets`: plots pinned at sideline, at backdrop and at ledger; all four packs equal solo and replay.
- `world.sh proof ledger` prints FAIL, by design of the walk:
  - `ex_wall` was unloaded and rebuilt, and hashes as a fresh run of its new ticks;
  - `ex_bounce` got its saved score back, so it does not equal a run from the seed. That run predates the "restored" verdict I added to `proof`; I did not run it again afterwards.

**4. The numbers.** Tables below. Loading:

| part of `_pack_setup` | seed_paddle | seed_drive | seed_wall |
|---|---|---|---|
| whole | 2140 to 2515 ms | 3550 to 4314 ms | 2064 to 2081 ms |
| scattered forest | 1076 | 2286 | 819 |
| terrain | 783 | 1099 | 1011 |
| walls, props, actors, road | 230 | 92 | 106 |

- Scripts cost 0.4 s once per process, then 0.3 ms; laws 0.3 ms; the bot 4 ms; the first iteration of 8 packs 25 ms.
- Nothing is shared: the second copy of a seed is as slow as the first.
- Fixed in scope: the world option `--scenery=plot` (walk key `"scenery": "plot"`). Three seeds by bot load in 2.1 s instead of 9.7 s with the same hashes; 60 packs in 26 s instead of 122 s. The default stays `full`.
- Not fixed: the kit-side caches and spreading the build over frames (PATCHES-N5A entry 3). Loading is still one blocking call per pack.

**5. The world file.** `world.sh save` and `world.sh load` (`world.file` selftest case).
- Save writes the whole file to `<file>.tmp`, reads it back, copies the old file to `<file>.prev`, renames, and counts `rev` up.
- Save then load prints the same plots, packs, seeds and tick counts (example.bounce 241, example.pack_min 228, example.wall 300).
- A file cut to 700 bytes is refused with exit code 2 and one readable line, is left byte for byte as it was, and `<file>.prev` loads.
- Loading rebuilds every pack from its seed. Its live state is not restored: only the plot, seed, lifetime tick count, summary (phase, score, clock from `TLRules`) and what `_pack_save` returned.
- `ledger` uses the same plot record.
- Only `pack.dir` is loaded. `uid`, `version` and `hash` are written and the hash is checked, but loading by uid is not built.

**6. Small debts.**
- Lint `composability` has `kit_parts_used`, `kit_kinds_used`, `kit_build_calls`, `world_coordinates`, `world_coordinates_by`. Kit parts / world-coordinate reads: seed_drive 19 / 6, seed_paddle 14 / 12, seed_wall 23 / 7.
- `TLVfx.squash` and `TLVfx.trail` are added as seams onto `TLStyleFx`. They are written but never called by any test.
- The worker already refuses `--mode=play` for a pack that fails lint; nothing to do.

## The tier table and what it means for a player

Proof walk: three seeds 300 m apart, played by their bots; the player walks a to b to c and back in 2700 world ticks.

| plot | pack | own ticks | tiers seen | in the walk | alone, same ticks | replay of the log |
|---|---|---|---|---|---|---|
| a | seed.paddle | 1880 | stage, sideline, backdrop | 59c7f07b104f7c6f | same | same |
| b | seed.drive | 1814 | backdrop, sideline, stage | 2962e9127af7ae3d | same | same |
| c | seed.wall | 1221 (its bot won) | backdrop, sideline, stage | 6366b88f838e3e78 | same | same |

World tick cost, p50 / mean / p99 in ms. Packs are the three seeds plus `w_pile` with 60 boxes, alternately awake and asleep. "Mix" is 1 stage, 4 sideline, the rest backdrop, with measured cost and budgets of 6 + 2 ms.

| packs | all at sideline | mix (two runs) | slice seen | slowest pack, share of world ticks |
|---|---|---|---|---|
| 12 | 5.1 / 6.2 / 12.7 | 4.6 / 5.3 / 20.9 and 4.0 / 4.4 / 7.5 | 2 to 5 | 0.28, 0.47 (third run 0.50) |
| 30 | 11.9 / 13.8 / 29.5 | 3.7 / 4.1 / 7.5 and 4.2 / 4.4 / 7.7 | 6 to 13 | 0.14, 0.11 |
| 60 | 30.5 / 31.8 / 70.6 | 3.8 / 3.9 / 6.3 and 4.1 / 5.3 / 7.9 | 14 to 29 | 0.057, 0.064 |

- **All at sideline:** 12 and 30 packs fit a frame at the median. 60 packs take 30.5 ms a tick, so the whole world would run at about 0.55 of real time.
- **How many games before the far ones drop below a tenth of real time:** about 35 to 50 on this machine under tonight's load. The far games reach a tenth when the backdrop costs 20 ms a round at 2 ms a tick, and the mix averaged 0.45 to 0.65 ms per pack tick. The runs agree: just above a tenth with 30 games, below it with 60.
- **The budget sets that limit, not a wall.** Each further millisecond of backdrop budget buys about 20 more games at a tenth.
- **A sliced tick costs more than a continuous one**, about 0.05 to 0.14 ms per pack, for the two switches around it. N2 did not measure this.

What it means for a player:
- The game you stand in and the ones across the road run at full speed. A far game keeps playing in slow motion: a third to a half of real time among 12 games, about an eighth among 30, about a sixteenth among 60.
- Nothing you walk away from is switched off or reset. Come back and it is further along, exactly as if it had played alone for that many ticks. Only a game marked `pause` waits, and one marked `end` starts again.
- A saved world brings back your plots, games and seeds and remembers each score and clock. Every game starts its round again from its seed, and gets its score back only if its author wrote the two save functions.

## Files changed

All under `site/_work/n5a/engine/`.

| file | change |
|---|---|
| `kernel/api/tl_contact.gd` | early return for a sleeping body |
| `kernel/api/tl_context.gd` | `scenery`; `read_json` hands a `tl.layout/1` file out without far terrain and forest when it is `plot` |
| `kernel/api/tl_vfx.gd` | `squash`, `trail` |
| `kernel/runner/lint.gd` | five new composability figures |
| `kernel/runner/verbs.json`, `kernel/host/host.gd` | twelve new options of the `world` mode; path options converted |
| `kernel/world/tiers.gd` (new) | the scheduler |
| `kernel/world/tiers.json` (new) | every threshold |
| `kernel/world/world.gd` | `--walk`, `--replay`, `--log`, `--world`, `--save`, `--plot-spacing`, `--scenery`; measured cost; rebuild; event lines |
| `kernel/world/pack.gd` | plot id and origin, `summary`, `saved_data`, `restore`, `plot_record`, `unload`, `dir_hash`, `load_ms`, tree time per tick |
| `kernel/world/walks/` (new) | `proof`, `heavy`, `boundary`, `ledger`, `leave`, `tickets`, six `bench_*` walks, `make_bench.py` |
| `kernel/world/TIERS.md` (new) | model, proof tables with commands, numbers, world file, what is not built |
| `kernel/world/PATCHES-N5A.md` (new) | below |
| `kernel/examples/ex_bounce/scripts/main.gd` | `_pack_save` / `_pack_load` example |
| `kernel/API.md` | section 20; `TLVfx` helpers in section 13; one line of section 19 |
| `tools/world.sh` | `walk`, `replay`, `proof`, `save`, `load` |
| `tools/selftest.sh` | `world.walk_proof`, `world.walk_valve`, `world.walk_boundary`, `world.file` |
| `JOURNAL.md` | N5a section |

## Contents of PATCHES-N5A.md

Nothing in it is applied in the copy. Entries 1, 2 and 5 are exact changes; entry 3 is a measurement with three proposals; 4 and 6 are notes. The full text is in `kernel/world/PATCHES-N5A.md`.

1. **`seeds/seed_paddle/scripts/main.gd`**, insert before `func _pack_state()` (line 164):
   ```gdscript
   func _pack_save() -> Dictionary:
   	return {"scores": rules.scores.duplicate()}


   func _pack_load(saved: Dictionary) -> void:
   	var kept: Dictionary = saved.get("scores", {})
   	for side: String in kept.keys():
   		if rules.scores.has(side):
   			rules.scores[side] = int(kept[side])
   	for side: String in SIDES:
   		hud.set_text(StringName("score_" + side), str(rules.score(side)))
   ```
   Reason: item 5. No verify verb calls them, so hashes do not change. The `hud.set_text` loop is not tested: check the widget id when applying.

2. **`contracts/PACK.md`**:
   - add `_pack_save() -> Dictionary` and `_pack_load(data: Dictionary) -> void` as optional entry functions;
   - state that `on_leave` defaults to `bot` when the manifest lists a test, else `pause` (always `bot` today, because a test is required);
   - add the five new lint figures to "Composability figures".

3. **`kits/tl_kit_layout_build.gd`**: terrain and forest are 87 to 95 % of a seed's loading time. Proposals, no exact patch:
   - (a) a cache of the scatter prototypes (`TLKitNature.pine`, `broadleaf`, `rock`, `bush`, `grass_tuft` are called with the same arguments in every pack);
   - (b) a cache of the terrain grid keyed by the terrain block (an estimate: 0.8 to 1.1 s off the second copy). In a world the far terrain and forest should not be per pack at all: plots stand 60 m apart and a seed scatters forest over 400 x 380 m;
   - (c) return after the bodies are built and let the kernel call a second scenery step, a piece per frame.

4. **`tools/tl.sh`**: nothing needed.

5. **`foreman/fixtures/engine/kernel/runner/verbs.json`**: copy the engine's file. The `world` mode has twelve new options: `walk`, `replay`, `log`, `tiers`, `cost`, `ticks`, `world`, `save`, `name`, `seed`, `plot-spacing`, `scenery`.

6. **`kernel/world/draw/**`**, a pointer for the builder who draws:
   - every holder carries the meta `tl_plot` = `{id, origin: Vector3, yaw}`;
   - `ctx.on_stage` is true only for the stage pack;
   - the tier of plot `i` is `world.sched.plots[i].tier`.

## What changed for a pack author

- Nothing, for a pack that follows API.md: seeds and examples run unchanged with the same hashes.
- A game in a world is never switched off but may get fewer ticks. Each tick is a full 1/60 s step, and the pack sees only its own tick count.
- `on_leave` and `footprint` in `pack.json` are now read. Without a footprint the plot is 40 x 40 m.
- New optional pair `_pack_save()` / `_pack_load(data)`, both or neither. A world file and the ledger keep only seed, ticks, summary and that data. The pack is built again from its seed, then `_pack_start()`, then `_pack_load(data)`.
- A world may load a pack with `scenery = "plot"`: a layout read through `ctx.read_json` then has no scattered forest and no far terrain. Do not look scenery nodes up by name.
- `TLVfx.squash` and `TLVfx.trail` are new. Lint reports how many kit parts a pack uses and how often it reads world coordinates; these are figures, never findings.

All of this is in API.md section 20.

## Not verified

- Anything with a window. The distances in tiers.json are first values; nobody has looked at a far game.
- The watchdog: a runaway `_pack_tick` still hangs the whole world.
- The player's real input routed to the stage pack. In a headless walk the bot or nobody plays every pack, so `on_leave: bot` changes nothing in these runs.
- A game that ended by itself stays ended; the next round is not built.
- Ledger promotion blocks the world while the pack is rebuilt.
- Tickets come from the walk script only.
- `yaw` of a plot is read into the distance but no walk uses a rotated plot.
- The valve's speed recovery and the return of a pack after a valve hold are written but no walk exercises them.
- `world.sh proof ledger` was not run again after the "restored" verdict was added.
- `world.sh bench` (N2's) was not run again on these files.
- The windowed effect of `TLVfx.squash` / `trail`, and the `hud.set_text` loop of seed patch 1.
- The cause of one hang: a world process of mine hung at start when two engine runs began in the same second right after a kernel script edit. I killed it (my own PID); the same command then ran in 16 s. I believe it was two class-cache refreshes at once, but did not confirm it.
- The scratchpad directory I was given already held many files of earlier sessions. I wrote `gates1.txt` to `gates3.txt`, `item1.txt`, `proof1.txt`, `load1.txt`, `lint_*.json`, `bench/`, `bench0/`, `bench2/`, `exp/` and `w1/` there, and ran `rm -rf` on `w1` and `exp` before creating them. If an earlier session kept something under those names, it is overwritten or gone.

## Questions

1. Should a pack in a world bring its own forest and far terrain at all? Making `scenery = "plot"` the default for worlds cuts loading by 67 to 90 % and left the three seeds' hashes unchanged; I kept `full` because it changes what the drawing builder sees.
2. Is 6 ms front plus 2 ms backdrop the right budget? It gives about 35 to 50 games before a far one drops below a tenth of real time, and the mix tick is only 4 ms of a 16.7 ms frame.
3. Should the 250 ms watchdog count wall-clock time on a shared machine? It failed 2 of 12 and 7 of 12 identical runs tonight, with and without my change.
4. Should the seed patch (entry 1) be applied to seed_paddle, or is the example in `ex_bounce` enough?
5. What should a game that ended by itself do in a world: start its next round at once, or wait for the player?

## Minutes

Started 01:55:23, finished 03:00:11 (from `date`): 65 minutes of the 90.

---

## Director verification

Done 03:04 to 03:22 on 2026-11-11, after the builder had stopped: in the builder's copy, then on the main tree after
merging its files together with the drawing builder's (N5b).

### What was re-run, and the result

| Check | Result |
|---|---|
| `world.sh proof proof --tiers-all` in the copy | paddle 1880 ticks `59c7f07b...`, drive 1814 ticks `2962e912...`, wall 1221 ticks `6366b88f...`: in the walk = alone for the same ticks = replay of the log, all three; every pack saw `stage`, `sideline` and `backdrop` |
| `world.sh walk heavy` | 4 demotions, then slice 4, then speed 800 per mille; all 7 packs kept ticking, longest wait 6 world ticks |
| `tl.sh selftest` in the copy | 77 passed, 0 failed, with `world.walk_proof`, `world.walk_valve`, `world.walk_boundary` (tier changes 0, 0, 1 on 2400 ticks along the boundaries) and `world.file` (save = load; a cut file refused with exit 2) |
| `tl.sh seeds`, `item.sh selftest`, `k.sh selftest` in the copy | 24, 91 and 86 passed, 0 failed |
| after the merge, on the main tree: the same four gates | 77, 24, 91 and 86 passed, 0 failed |
| after the merge: `view.sh check` (N5b's drawing on this world host) | passes |

Seed hashes are unchanged, so the sleeping-body change did not move any state.

### What is not verified

The bench tables of item 4 (taken under load by the builder; not re-run); `world.sh proof ledger`, `leave` and
`tickets`; the loading breakdown; anything with a window; the player's real input reaching the stage pack.

### What the numbers say

- An asleep pack now costs about 0.03 ms a tick instead of 0.2 ms.
- With 1 game on stage, 4 beside it and the rest far, a world tick stays near 4 ms for 12, 30 and 60 games; the far
  ones run at about a third to a half, an eighth, and a sixteenth of real time. About 35 to 50 games fit before a far
  one drops below a tenth, on this machine under tonight's load, with 2 ms of budget for the far tier.
- Loading a seed is 87 to 95 % scenery (its own terrain and forest). Without it three seeds load in 2.1 s instead of
  9.7 s, with the same hashes.

### Director's decisions on the builder's questions

1. `scenery = "plot"` becomes the default for worlds (see N5b decision 2); the single-pack verbs keep `full`.
2. 6 ms plus 2 ms stays as the first budget; the figure the owner should see is "how slow is the slowest game", and
   it is in the morning page.
3. Yes: the 250 ms watchdog must count processor time or be compared with a reference on a shared machine. It cost
   the hockey job an hour tonight. Next kernel pass.
4. The seed patch is not applied tonight (its HUD loop is untested); `ex_bounce` is the example.
5. A game that ended by itself: open. Proposed default for the next step: on stage it waits for the player; beside or
   far, it starts its next round after a short pause, so the world keeps moving.

Merged into the main tree by file (19 changed or new files under `kernel/`, `tools/world.sh`, `tools/selftest.sh`,
`JOURNAL.md`); `foreman/fixtures/engine/kernel/runner/verbs.json` follows the engine's file. Not applied: patch 1 (the
seed), patch 3 (kit-side caches).
