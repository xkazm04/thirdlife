# Day of 20 Nov: verdict (crisp cel vs toy diorama)

Stopped at 19:20 at the owner's word ("you can stop and provide final report"). All four arms had finished (READY, last standup line `done`) by 18:58.
Nothing landed on main; both looks are on branches, pushed.

## Play
| Look | Exe | Build |
|---|---|---|
| Toy diorama | `dist/day/dio/ThirdLife/PLAY-DIORAMA.cmd` | `d20-dio` c41885a (final) |
| Crisp cel | `dist/day/cel/ThirdLife/PLAY-CRISP.cmd` (or `dist/day/cel/PLAY-LATEST.cmd`) | `d20-cel` 4ca822a (final) |
| Today's look | `PLAY-CLASSIC.cmd` in either folder | |

## Crisp cel (team cel: Astra frame + figure, Fable surfaces)
- **Built:**
  - a violet-to-peach sky with flat cream clouds and lavender undersides;
  - a 40-degree warm sun;
  - plum road shadows (117,73,71 against board 124,79,74) and olive grass shadows (81,107,36 against 80,106,35), with cut edges;
  - a new cel figure with hair, collar, cuffs and boots, in three jacket bands, framed at about 37 % of the frame height as on the board;
  - in the exe, 4x MSAA + SMAA with distant-only history AA;
  - surfaces: rails along the road, an olive meadow with dark tufts, dark grass under trees, mauve bluffs with cream beds, a flat blue river with streaks along the flow, round cloud shadows, toothed pines.
- **Evidence (final merge 4ca822a):**
  - fast PASS;
  - world,packs,kit PASS under the default style, under `TL_STYLE=crisp` and under `TL_STYLE=classic` (world 8/8, packs 48/48, kit 95/95, base hashes);
  - selftests style 10, rig 14, character 2, cel 4, celsurf 9 (0 fail);
  - export PASS.
  - Classic: 18/18 reproducible shots at 0/255 (arm proofs).
- **Cost:** about 1.1x classic GPU (tour6 1.36 against 1.23 ms, busy machine).
- **Not run:**
  - the export check of the final exe (stopped);
  - the final shot set.
- **Short of board 2:**
  - no camera gives the board's composition (river beside the road);
  - the thinnest grass still flickers in a slow pan;
  - the hair reads as two lumps;
  - the mesas are not stepped;
  - thin shadows keep a slight sawtooth.

## Toy diorama (team dio: Astra frame + figure, Fable surfaces)
- **Built:**
  - sharpness first: 16x anisotropy and horizon resolve; tour sharpness, joined tree -> final, far 233 -> 614, mid 225 -> 714, near 204 -> 711;
  - a warm raking key light; a print-style grade matched to the board's luma (07 lower half 59/134/182 against board 59/133/181; red clipping 24-26 % -> 4-5 %);
  - a clean sky with cotton clouds;
  - the clay figure with fingerprint ridges and chipped paint;
  - surfaces: felt meadow dyed by relief and sun, felt tufts, grit and pebbles, felt-ball bushes, felt-wood rails along the road, warm grained dowel scaffolds, brushed cream edges, a resin river that mirrors its banks.
- **Evidence (final merge c41885a):**
  - fast PASS;
  - world,packs,kit PASS under the default (diorama) style and under `TL_STYLE=diorama`;
  - each arm's own selftests on its own tree green (style 12, rig 14, flight 13, character 1, dio 7, surf 5);
  - export PASS.
  - Classic: 16/16 + 6/6 at 0/255 (arm proofs).
- **Open:**
  - **Classic hashes on the merged tree are NOT verified.** The classic world,packs run broke at process level (world exit 0xC0000142 before any row; parkour bots failed) at 19:15, just before the run was stopped. It is a broken run, not a verdict either way, and must be re-run on a quiet machine before anything lands.
  - Selftests and the export check of the merged tree were not run.
- **Cost:** about 1.8-2.1x classic GPU (busy machine), after the cuts: shadow map capped at 4096, strews in pieces with far limits. Without those cuts it read 2.2-2.5x. Switch-off keys exist per pass.
- **Short of board 4:**
  - the backlit river bank is 115 against 133;
  - the sun direction is a compromise (the board's sun is low on the left);
  - the lit meadow is a bit bright in 01;
  - the parkour house frame and ladders are still pale bars.

## For your eye
In both games, walk the village road from the start toward the yard and the river (W, mouse), then summon wings and fly over the bluff. Then press `PLAY-CLASSIC.cmd` for today's look at the same places.

## Asks (answer in chat)
1. **D3, which look?** a) the toy diorama; b) crisp cel; c) neither yet.
2. **Road fences have no collision in both looks; you walk through them.** a) add colliders (a new body in every world run, needs hash proofs); b) keep them as decoration.
3. **Cel only:** the gate sign stands in front of the yard fence. a) do the same in every style, which changes classic; b) crisp only.

## Route scoreboard (today)
- **Astra** (an Opus operator passing measurements) led the frame: sky, grade, light, AA.
  - Both Astra arms ran about 3.2 M tokens each, against a 2-2.5 M plan.
  - Measured feedback (luma spread, clipping) steered it best.
- **Fable** built the surfaces as rule-bound systems and gated its own work cleanly. Both Fable arms finished early, and used the spare time on cost and edge fixes.
- **Caught late:** the integration gates ran one style only. A cel figure stance moved example.kit's hash under crisp unseen through integration 2. cel-astra caught it and fixed it. Lesson added to the skill log.
