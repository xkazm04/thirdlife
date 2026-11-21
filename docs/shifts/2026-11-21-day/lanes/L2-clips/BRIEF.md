# L2 fight-clips: the moves every action game needs, on the biped rig

Read `docs/shifts/2026-11-21-day/COMMON.md` first: the owner's words, the laws, your column (`engine/rigs/**`), and
selftest block 660-669. Then read the spark note `.spark/Spark/ideas/game-quality-bar.md` (main checkout): digest A
("The rig has no fight clips") and digest B (the feel numbers).

- **Worktree:** `C:/Users/kazda/kiro/third-life/.claude/worktrees/n21d-clips`, branch `n21d-clips`, base main `df58f0b`.
- **Route:** Opus solo. Time box: landable by 14:30, because L4 hockey waits on `body_check`, `cross_check` and
  `stick_yaw`. Polish after that.
- **Standups:** in `lanes/L2-clips/STANDUP.md`. When you are landable, also send the Director a message.

## Why
`engine/rigs/tl_rig_biped.gd:55-73` has idle, walk, run, skate, skate_stop, shoot, pass, cheer, fall, carry, work, jump,
land, slide, slope_slide and air. It has no strike, block, roll, dodge, check or taunt. Last night's colosseum games
borrowed the hockey `shoot` clip for a strike, `slide` for a roll, `cheer` for an enemy's tell, and `fly` for a lion's
pounce; one game's strike had no clip at all.

The owner: "For arena there are no skill/playstyle design, reactivity on hits, movement roll". On hockey (15 Nov): the
cross-check must be "the player animation should reflect the crosscheck movement and that should be all".

## Work
1. **New biped clips, authored the way the existing clips are authored** (`engine/rigs/biped/*`, the moves file).
   Frame counts are at 60 Hz. Treat them as targets to measure and to tune by eye, not as truths.
   - `strike`: a light one-handed swing or punch. Anticipation about 3 frames (a visible pull-back), active about 3,
     recovery about 10, with follow-through.
   - `strike_heavy`: a two-handed overhead or wide swing. Anticipation about 10 frames: a big readable wind-up, the body
     coils. Active about 4, recovery about 16.
   - `block`: a guard raised in front (forearm or shield arm up, a braced stance). It holds like `fall` until another
     `play`.
   - `roll`: a forward roll or low dive about 24 frames long, tucked. The figure goes low, then comes back up. The clip
     only animates; the pack moves the body.
   - `dodge`: a quick side step about 14 frames long, with a lean.
   - `body_check`: a shoulder drive with a lowered stance, the hip turned in, and an arm tucked.
   - `cross_check`: both hands on the stick, pushed forward chest-high. It must read as a hockey cross-check at game
     scale: hands apart, stick horizontal.
   - `taunt`: a cocky pose (chest out, a beckon), not `cheer`.
2. **`stick_yaw`** (radians, a rig property; 0 = today's pose). It turns the stick hand and blade sideways, so the
   blade can follow the cursor in hockey. Document its range. The hockey pack sets it every frame, so it must be cheap.
3. Each clip's frame timings (anticipation, active, recovery, and the frame where control may return) go into
   `engine/rigs/RIGS.md` as a table. Builders and the Designer use these numbers.
4. **A "move lab"** (`engine/rigs/review/`, as `review.gd` does today):
   - a stills sheet of each clip at its key frames, at game scale, under crisp;
   - a 10-20 s clip of all of them.
   - Tune by looking: produce, judge, tune, at least 3 rounds, and keep the sheets. Readability at game scale is the
     bar.
   - Also look at a hockey figure with a stick doing `cross_check` and `body_check`.
5. Selftest block 660: every new clip exists, has its declared length, and ends in a pose (or loops) as RIGS.md says.
   `stick_yaw` 0 is identical to before.

## Acceptance
- **No existing hash moves:** the new clips are unused until a pack plays them, and `stick_yaw` defaults to the old
  pose. Proof:
  - `node devx/bin/tl.mjs check --tier full --only kit.selftest,world,packs,seeds` with counts equal to main;
  - block 660 PASS;
  - the fast gate.
- The move-lab sheet and clip are in your lane folder, plus the hockey stick sheet.
- RIGS.md has the timing table.
- The kernel API is untouched (clips are rig data; `stick_yaw` is a rig property).

## Out of scope
- Falls, hit reactions and get-ups: the L3 arms own those.
- Any pack (L4 and L5 play your clips).
