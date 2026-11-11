# N5a: the world's clock: tiers, the scheduler, the world file

You are the builder for the **kernel** of Third Life, a single-player sandbox on Godot 4.7.2 (Jolt, 60 Hz fixed tick)
in which an LLM builds small games ("packs"). Earlier tonight builder N2 proved that several packs can live in one
process, each in its own physics space at its own origin, and that a pack which is switched off for a while, or given
one world tick in N, plays exactly the same game, later. The owner has ruled: **every game in the world stays alive,
and a far game runs in slow motion** (fewer ticks, unchanged step). You build the part that decides how many ticks
each game gets, and the file that remembers a world.

## Read first
1. `docs\reports\N2-MANY.md` (the builder's report and the Director's verification), then in the engine
   `kernel\world\BENCH.md`, `kernel\world\world.gd`, `kernel\world\pack.gd`, `kernel\API.md` section 19.
2. `reports\Living world layering for Third Life.md`: only the sections "Recommended layering model" and "Thresholds
   the spike should measure". It was written before N2's measurements; where N2 measured, N2 is right.
3. The last section of `contracts\PACK.md` (`on_leave`, `footprint`), `docs\SHARING.md` section 4 (where a world is
   saved).

## Where you work
**Your own copy of the engine: `C:\Users\kazda\kiro\third-life\site\_work\n5a\engine\`** (a copy of the main tree
with N1, N2 and N4 merged). `TL_GODOT=C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe`.
Yours: `kernel/**` **except** `kernel/world/draw/**` (another builder draws the world there tonight) and
`kernel/share/**`; `tools/world.sh`, `tools/selftest.sh`; `JOURNAL.md`. For anything else (style, kits, rigs, seeds,
`tools/tl.sh`) write the exact patch and its reason to `kernel/world/PATCHES-N5A.md`. Everything you build is
headless; drawing is not yours.

## The model (wire values in `code`)
- Tiers: `stage` (the player is inside the plot: every world tick, player input), `sideline` (near, or next to the
  stage pack: every world tick, its bot or its idle play), `backdrop` (far: one pack tick per `slice` world ticks,
  round-robin under a millisecond budget), `ledger` (not in memory: a small summary only).
- A pack only ever sees its own tick count. Slicing is N2's switch-off mechanism, used on a schedule.
- Rules: packs next to the stage pack run at `sideline` whatever the distance; every boundary has a margin and a
  minimum dwell so a pack does not flap; a ticket pins a pack at a tier for a fixed number of world ticks; when the
  measured cost of `stage` plus `sideline` exceeds the budget the farthest `sideline` pack is demoted first, then the
  whole world slows (every pack gets fewer ticks, equally); **no pack is ever switched off for good**.
- Every tier change and slice assignment is an event at a tick boundary in a world log, so a world run can be replayed.
- A pack declares what happens when the player walks out of its plot: `on_leave` = `bot` (its first bot takes the
  player's side), `pause` (it holds until the player returns) or `end`; default `bot` when the pack has a bot, else
  `pause`.

## The work, in this order
1. **Sleeping bodies must be cheap.** N2 measured 0.2 ms per asleep pack per tick, all of it the kernel's own
   per-body script (`TLContact._physics_process`), and tried a three-line early return for a sleeping body that cut
   300 asleep boxes from 2.21 ms to 0.16 ms with 11 hashes unchanged. Apply it, run every gate, and report the new
   asleep figure. If a hash changes, find out why before keeping it.
2. **The scheduler.** A world given its packs, their plots (`origin`, `footprint`) and the player's position decides
   each pack's tier every world tick, with the rules above, and ticks accordingly. The player's position comes from a
   script of `(world tick, position)` pairs in headless runs, so a run is reproducible. Thresholds are data
   (`kernel/world/tiers.json`: distances, margins, dwell, budgets, slice limits), not constants.
3. **The proof.** For a walk that takes every seed through `stage`, `sideline`, `backdrop` and back: each pack's final
   state hash equals the hash of the same pack played alone for the same number of its own ticks with the same inputs;
   the world log replays to the same hashes; the budget valve engages in a world that is too heavy and never drops a
   pack; no tier flaps on a walk along a boundary.
4. **The numbers.** With the three seeds and N2's `w_pile`, for worlds of 12, 30 and 60 packs: world tick cost with
   everything at `sideline`, with a realistic mix (1 stage, 4 sideline, the rest backdrop), and the slowest pack's
   speed as a share of real time in each. State how many games a world can hold before the far ones drop below a
   tenth of real time on this machine. Say which figures were taken under load.
   Also: N2 found that loading one seed pack blocks for about 3 s (65 s for 20). Measure where that time goes
   (script loading, kit mesh building, laws, the first physics step) and what can be shared between packs or
   spread over frames; fix what is cheap to fix and report the rest.
5. **The world file.** `tl.world/1`: `{schema, name, rev, device, seed, plots: [{id, origin: [x, y, z], yaw,
   footprint, pack: {dir | uid, version, hash}, seed, ticks, summary}], player: {plot, position}}`. `world.sh save`
   and `world.sh load`: written whole to a temporary file and renamed, `rev` counted up. On load a pack is rebuilt from
   its seed; say plainly that its live state is not restored. If a pack offers `_pack_save()` and `_pack_load(data)`
   use them, and add both to one seed as the example. `ledger` uses the same path: unload keeps `ticks` and `summary`
   (score, clock, phase from `TLRules` when the pack declares rules).
6. **Small debts from tonight's reports**, if time remains: lint reports the number of kit parts a pack uses, in
   `composability` (the Foreman wants it); lint counts uses of `global_position`, `global_transform`, `to_global(`,
   `look_at(` in pack scripts as a figure (a pack that reads world coordinates breaks when it is not at the origin);
   `TLVfx` gets `squash` and `trail` seams onto the style's helpers; the worker refuses `--mode=play` for a pack that
   fails lint (`kernel/share/PATCHES.md` entry 4).

## Acceptance (the Director will run these in your copy)
- `bash tools/tl.sh selftest`, `bash tools/k.sh selftest`, `bash tools/tl.sh seeds`, `bash tools/item.sh selftest`
  pass; seed hashes unchanged or each change explained and stable over three runs.
- `bash tools/world.sh walk <script>` prints the tier log and one hash per pack; the proof of item 3 is a selftest
  case and its table is in `kernel/world/TIERS.md` with the commands.
- `world.sh save` then `world.sh load` gives a world whose packs, plots, seeds and tick counts match; a truncated
  world file is refused with a readable error and the previous file is intact.
- `kernel/world/TIERS.md` holds the numbers of item 4 and, in three lines, what they mean for a player.

## How to work
Small verified steps; journal each in `JOURNAL.md` under an "N5a" heading. Headless only. Kill every process you
start; never kill others (a real job, other builders and other sessions run Godot here tonight: re-run a wall-clock
figure before you believe it, and say which were taken under load). No git. No network. Never read, use or print any
`ANTHROPIC_KEY_*` variable. Your measurement outranks any document, this brief included: where a premise is wrong, say
so with the evidence.

## Final message (your report, as text)
Status; per item what you built and the proof; the tier table and what it means for a player; the list of files
changed with a line each; the contents of `PATCHES-N5A.md`; what changed for a pack author; what you did not verify;
questions; minutes spent from real timestamps (`date`).

## Time-box
Until the list is done or **90 minutes after your start** (run `date` first and often). Items 1 to 3 proven are worth
more than the rest. Leave the last ten minutes for the gates and the report. A usage limit can cut you off without
warning: keep the journal current.
