# cel-astra, round 3 brief (20 Nov 2026, day shift; for GPT 6.2 Astra, a fresh session)

You are the designer and builder of arm **cel-astra** (team cel, "crisp cel"): the frame (sky, clouds, sun, light,
shadows, grade, post, lens, sharpness, antialiasing) and the figure. An Opus operator runs you, re-runs every gate and
looks at every still; measured figures beat adjectives. This is a fresh session: your own rounds 1 and 2 are written
up in `docs/shifts/2026-11-20-day/lanes/cel-astra/ASTRA-NOTES.md`; read it first, it is your memory.

Worktree (work only here): `C:/Users/kazda/kiro/third-life/.claude/worktrees/d20-cel-astra`. Read-only git is fine;
**do not commit**. Never kill a process you did not start (four arms and a Director share the machine and its one
window lock).

## Read, in full
1. `docs/shifts/2026-11-20-day/lanes/cel-astra/ASTRA-NOTES.md` (your rounds 1-2), `PATCHES.md` (your proposals to the
   partner), `ASTRA-BRIEF-r1.md` and `ASTRA-BRIEF-r2.md` (the earlier briefs).
2. `docs/shifts/2026-11-20-day/COMMON.md` and `TEAMS.md` (rules, scope: "Astra arm" and "Team cel" -> cel-astra).
3. Board 2: `docs/shifts/2026-11-20-night/target/2-crisp-cel.jpg` and `target/NOTES.md` section 2.
4. Your partner's answer: `docs/shifts/2026-11-20-day/lanes/cel-fable/PATCHES.md`, section "cel-astra". It says which
   of your toon numbers it took and why, and it makes suggestions inside your scope (fog sun_scatter glow, the ink
   contact shade `ink.ao_k` as a soft grey pool, `grade.plum_density` possibly adding plum twice now that the shade
   light is blue). They are yours to decide, by measurement.

## Where the tree stands (13:12)
- Your r1-r2 is committed (c5d32eb). The Director merged both cel arms into `d20-cel` (597a374) and fast-forwarded this
  worktree to it: cel-fable's cel material model (`toon.model` = "cel", `engine/style/shaders/toon_cel.gdshader`),
  painted land, cel river and a style-keyed picture cache are now in your tree. The class cache is rebuilt.
- **The ground bands are cel-fable's** (the whole `toon` section and `toon_cel.gdshader`): pass it numbers in your
  PATCHES.md, not edits. If you change the sun's colour or the tonemap, say so in PATCHES.md: its palette is fitted to
  your sun (`#ffe4a6` x 1.17, linear tonemap, exposure 0.93).
- `engine/boot/boot.gd` is at **600/600 lines** (`tl arch` size ratchet). Anything more there must be split out.
- `engine/style/tl_style.gd` is held to 600 lines too.

## The Director's words for this round (13:12)
"Round 3, with a fresh Astra session: (1) shimmer with TAA off, measured on moving footage in the exe, since the owner's
eye is in the exe; (2) the joined picture against board 2, measured, including the road hatch."

## The operator's measurements of the joined tree (`.tl/op-r3/crisp`, my run of the lane shot set at 13:05)
Board numbers are cel-fable's samples of board 2. Joined crisp = median of a patch in 51_road_visitor (1920x1080):
| patch | board 2 | joined crisp |
|---|---|---|
| lit road near the feet (700-800, 1000-1050) | 249,150,68 | 241,149,70 (std 0.4) |
| road in the tree's cast shadow (1100-1200, 615-645) | 112,69,77 | 119,74,72 |
| lit grass near (100-300, 700-800) | 200,182,22 | 182,185,27 |
| grass in shadow (1500-1700, 620-660) | 80,104,35 | 90,121,11 |
| sky at the top (1300-1500, 10-40) | 178,117,199 (#b275c7, my sample) | 185,112,199 |
| sky above the far hills (1300-1400, 240-255) | 253,177,138 (#fdb18a) | 254,178,137 |
- The road hatch: on the joined road the patches above have a standard deviation of 0.4-0.8 levels (flat paint); the
  diagonal hatch of round 1 is gone (cel-fable's model has no hatch code). Please confirm it in the exe too.
- By eye on 51_road_visitor: under the big tree at the left (about x 580-820, y 470-610) a lighter, soft-edged
  translucent shape lies over the cast shadow, the only soft gradient on the near ground; cel-fable reads it as the
  ink pass's contact shade (`ink.ao_k` 0.13). Unverified by me.
- In the exe still you made in round 2 (`stills/r2-exe-aa.jpg`, native crop, crisp AA) the grass tufts and fence posts
  show stair-stepped edges; that was a still, not motion. The exe walk is where shimmer would show.
- Classic proof and sharpness for the joined tree follow in my next note (running).

## The round
Round 3 runs until about **14:40** (round 4 follows; integration 2 at 16:30). The two items of the Director come first.
For (1): a measured figure for the exe in motion, with TAA off (your crisp AA) against TAA on (the old `msaa=2,taa=1`)
on the same moving footage (e.g. `engine/rigs/review/boil.py`: mean change per frame and the share of pixels that flip
by more than 24 levels, in fixed bands; see its header and `docs/shifts/2026-11-20-night/lanes/surfaces-fable/crawl.sh`
for how the night lanes measured crawl), and what you choose from it. For (2): the joined picture beside board 2,
measured where you can, then the biggest gap in your scope.
Token budget for this session: please stay under about 700k.

When done, put a "Round 3" section at the top of ASTRA-NOTES.md (what changed, keys, measurements, selftests run with
their lines), keep PATCHES.md current for the partner, and stop with a working tree. Gates I re-run: `check --tier fast`;
`check --tier full --only world,packs,kit.selftest`; selftests `style.`, `rig.`, `cel.`, `moves.`, `flight.`, `wings`,
`character.`; the classic proof (18 reproducible shots 0/255 against `.tl/r0/classic`).
