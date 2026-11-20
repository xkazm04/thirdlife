# Night of 20 Nov 2026: verdict (the toy-diorama duel)

**Page:** https://claude.ai/artifact/PDGjcWgSg1XN6NyujhjKyq

**In one line:** all six arms finished and kept every rule. The combined build (frame Astra + surfaces Fable + character
Fable) is the nearest the game has come to board 4, at +27 % GPU and no added cost per new game. Nothing landed on
main; your call is a) adopt diorama or b) evolve crisp cel.

## For your eye (10 minutes)
1. **Play the combined build:** `dist/arms/combined/ThirdLife/PLAY-DIORAMA.cmd`.
   - Walk the village road to the parkour yard. Enter the yard (E).
   - Summon the wings and fly over the bluff.
   - Look at hockey from the arena camera.
   - Today's look is one switch away: `PLAY-CLASSIC.cmd` beside it (`TL_STYLE=classic`).
2. **Watch the combined clip** (28 s, the same route as character-fable's): `lanes/combined/clip.mp4` on branch
   `diorama-combined`, or on the page.
3. **Compare the arms** on the page, the same shots side by side. Each arm's own exe is in `dist/arms/<pillar>-<arm>/`.
4. **Watch the figure's feel** in `clip-feel.mp4` (character-fable, 16 s: idle, run, jump, stop). Nobody has judged
   motion by watching video yet: both character arms judged from frame strips.

## Branches (all pushed; nothing on main)

| Branch | Commit | What |
|---|---|---|
| `diorama-base` | 781d32b | main 6e060d2 + the `TL_STYLE` switch (diorama default, classic exact) + the briefs |
| `diorama-frame-astra` | e0c9a9f | frame, GPT 6.2 Astra (Opus operator), 2 rounds kept |
| `diorama-frame-fable` | 3a89777 | frame, Fable 5.2 |
| `diorama-surfaces-astra` | e61a534 | surfaces, Astra, 2 rounds kept |
| `diorama-surfaces-fable` | efcf1b9 | surfaces, Fable |
| `diorama-character-astra` | 5ce876c | character, Astra, 3 rounds |
| `diorama-character-fable` | 4d0023a | character, Fable |
| `diorama-combined` | 9a749e2 | base + frame-astra + surfaces-fable + character-fable (code 5609241) |

## The rules, across all six arms
- **No pack, seed, contract or `style.json` file changed:** checked by the Director on every arm's status.
- **The v1 API was kept:** `tl arch` PASS 12/12 in every arm.
- **Classic stays exact:** each arm compared classic before and after on the same shots.
  - Frame-astra: 13 bit-exact shots, 0/255.
  - Frame-fable: 16/24 bit-identical, the rest on moving figures.
  - Surfaces-astra: 9/16; the diff masks checked by eye show only moving objects.
  - Surfaces-fable: 11/16, and toon minus its diorama branches is byte-identical.
  - Character-astra: 21/34.
  - Character-fable: sheet max diff 0.
  - The remainder differs as base differs from base.
- **No state hash moved:** world 8/8 and all pack hashes equal `diorama-base` in every arm and in the combined build.

## Frame (light, sky, atmosphere, camera): **leader Astra**

| | Astra (frame-astra) | Fable (frame-fable) |
|---|---|---|
| Built | cotton-wool sky (27 cloud groups), low warm sun 23°, soft wide shadows, contact shade instead of ink, warm/cool grade, tilt-shift lens (focus on the figure; off in flight and the hockey arena) | painted-board sky with lit cloud clumps, orange sun with a size, contact and corner shade instead of ink, grade with `green_keep`, tilt-shift lens with a play rule |
| Seam in today's clouds | gone: centre jump 40-54 % of rows -> 3-13 % | gone: 6.6x -> 0.12x |
| Gates | fast PASS; style. 7/7; world 8/8, kit 95/95, 56 hashes = base; packs: only hockey's wall-clock budget under load (A/B equal); kernel stopped at 1800 s 84/85 (0 failed) | fast PASS; style. 7/7; world, packs, kit PASS; kernel alone 329/0 |
| GPU (busy) | +25 % | +47 %, plus two unexplained 3.2-3.3 ms readings |
| Exe | `dist/arms/frame-astra` | `dist/arms/frame-fable` |

- **Why Astra:** its sky is the board's (big cotton clouds, sun glow), its rink is clean and it costs less.
  - Fable's long raking shadows break into hard toon steps without its five-value toon patch, and its rink is tinted violet.
- **Still not diorama:**
  - the clouds are on the dome, with no parallax in flight;
  - hockey skater shadows nearly vanish (178k -> 36.5k px), which is cleaner but flatter;
  - the road cameras show the figure small.

## Surfaces (the world's materials): **leader Fable**

| | Astra (surfaces-astra) | Fable (surfaces-fable) |
|---|---|---|
| Built | `detail.handmade`: felt grass and crowns, painted wood grain, ochre earth with grit, resin river, display-only stones and rolled mesa layers | `toon.model = diorama`: clay with thumb dents, felt with flocking, wood boards and grain, cast blocks, painted metal, rolled mesa slabs, soft box edges (UV2), round lumps, chips, resin river reading its bed |
| Measured | grass saturation 0.83 (board 0.85); walking ground band 3.7x the frame change of classic | crawl on par with classic; nothing boils on a still camera |
| Gates | fast PASS; world, packs, kit PASS; style. 3/3, block 580, blend.pigment; full tier not run | fast PASS; world, packs, kit PASS (packs failed 3/7 on hockey's budget, base 5/8); style. 3/3, surf. 5/5; kernel alone 330/0 |
| GPU (busy) | +8 to +12 % | +3 % |
| Exe | `dist/arms/surfaces-astra` | `dist/arms/surfaces-fable` (also PLAY-SURFACES-PREVIEW with ink off) |

- **Why Fable:** it reads as handmade material (clay ground with pebbles, wood grain, layered mesas, felt) and is
  measured calm in motion. Astra's ground glows orange as grit noise, with a shimmer risk.
- **Still not diorama:**
  - silhouettes are still low-poly (prism mesas, 7-sided pine tiers);
  - fingerprints show only within 3 m;
  - land beyond 70 m is flat tone;
  - the river has no foam.

## Character (the toy figure and its motion): **leader Fable** (even by eye; the rules decide)

| | Astra (character-astra) | Fable (character-fable) |
|---|---|---|
| Built | painted clay toy, code-built on the 29 bones: jacket with collar and snaps, jeans, curls, satchel. Idle glance and pocket brush, chest roll, knee drive, hair and collar settle, hands meet bar, ledge and stick | clay toy, code-built on the same skeleton: round head, rolled collar, buttons, mittens, cuffs, two buns. Bun spring, squash and stretch, idle sway, hands solved onto ledges and bars (0.30 -> 0.075 m) |
| Rails | 2.0/0.3, 29 bones, names kept, at most 11,788 tris | 2.0/0.3, 29 bones, names kept, at most 10,920 tris |
| Files | changes `tl_biped.gd` and `visitor.gd` (kernel); loads the style on a worker thread | touches no kernel file |
| Gates | fast PASS; world, packs, kit PASS; rig. 14, moves. 14, flight. 13, wings 2, style. 3, character. 1; kernel stopped 258/259 (0 failed) | fast PASS; world, kit PASS (packs flips on the budget); figure. 4, rig. 14, moves. 14, flight. 13, wings 2, style. 3; kernel stopped 97/98 (0 failed) |
| GPU (busy) | +1 % | about equal |
| Exe | `dist/arms/character-astra` | `dist/arms/character-fable` |

- **Why Fable:**
  - From behind, Astra's sculpted figure is closest to the board; from the front, Fable's clay finish is strongest; at play distance they read alike.
  - Fable kept the kernel untouched and caught its own hash slip (`example.kit` reads a leg bone).
- **Still not diorama:**
  - the board's toy is 2.4 heads tall with short legs; both arms are about 3, because the skeleton is a rail;
  - the collar and cuffs are rigid;
  - skaters have the look but not the feel.

## The combined build (`diorama-combined` 9a749e2, exe `dist/arms/combined/ThirdLife`)
- **Merge:** the three leaders merged without textual conflicts.
  - **One seam:** `tl_style.gd` reached 611 lines against its 600 budget. Each arm alone was under it. Two blocks moved to `style/dio/style_dio.gd` unchanged (5609241).
  - **PIC_VERSION 1601:** the picture cache holds geometry, which is surfaces-fable's.
- **Gates (Director's runs):**
  - fast PASS 5/5;
  - world 8/8 (all hashes = base), packs 48/48, kit 95/95;
  - style. 7, rig. 14, figure. 4, surf. 5, flight. 13, wings 2;
  - moves. 13/14 in the batch (a nested record exited 127), PASS alone;
  - **the whole kernel suite alone: 338 passed, 0 failed**;
  - export.check PASS.
- **Perf on the quiet machine** (tour6, alternating pairs):

  | | GPU | frame p50 |
  |---|---|---|
  | classic | 1.232 / 1.235 ms | 2.45 ms |
  | combined | 1.568 / 1.558 ms | 2.57 ms |

  **+27 % GPU**, not a doubling.
- **By eye:** the nearest to board 4 of anything tonight. Sunset and cotton clouds, felt grass, clay road with pebbles,
  layered mesas, no ink, clay figure.
- **Cost per new game:** unchanged. A game names palette keys, places kit parts and calls `TLBiped.create`; the look
  arrives without a line.

## Route scoreboard (feeds the skill's route table)

| Pillar | Astra alone (Opus operator passing only measurements) | Fable 5.2 directly | Leader |
|---|---|---|---|
| Frame | sky and light nearest the board; cheaper | strong light, needed a patch in another pillar; costlier | **Astra** |
| Surfaces | strong colour, noisy grit; slow (round 1 ran 2 h 25 min re-running gates itself) | the richest material model, calm, cheap | **Fable** |
| Character | the best back view; touched the kernel | even look, cleaner footprint | **Fable** (by the rules) |

- **Lessons for the route table:**
  - **Engine look work judged by eye is a real duel:** each model won a pillar on the look. Astra did best where the work is one striking image (sky, light); Fable did best where the work is a system of many parts held to rules (materials, a rigged figure).
  - **Fable reached a frozen, gated tree faster** (frame-fable froze at 02:04).
  - **Astra needed its operator's time checks** to stop re-running suites.
  - **Pair planning with one builder** would have cost half the machine, but the duel showed both models at their best.

## Cost
- **Agents:** 6 arms and 1 Director.
  - Opus operators: frame 298k, surfaces 396k, character 368k tokens.
  - Fable builders: frame 733k, surfaces 920k, character 124k (the last segment only).
- **Astra (Codex):** the last cumulative count per session was frame 1.08 M, surfaces 0.71 M and character 1.40 M. The stopped rounds printed none, so the total is at least 3.2 M, about 1.5x a directed lane's plan per arm.
- **Machine:** at most 32 Godot processes. The shared window lock (one at a time) was the night's bottleneck: 10-20 min a capture, and 97 min for one queued kernel run.

## Your decision
- **a) Adopt diorama.** Land `diorama-combined` on main as the default look, with classic one switch away (as on the branch).
  - **First:** your hand on the exe.
  - **Then the next shift:**
    1. a soft contact shade under platforms and props (frame with surfaces);
    2. a squat toy skeleton (2.4 heads) with a retuned gait, a second skeleton behind the style;
    3. felt and clay silhouettes (fuzzy rims, rolled mesa lips, river foam);
    4. clouds with parallax in flight;
    5. hockey readability under the low sun.
  - **Cost:** +27 % GPU; zero per new game.
- **b) Evolve crisp cel.** Keep today's look as the default and carry over the parts that are not diorama-specific, each behind keys in `style.json` and landed one by one:
  - the seamless sky;
  - soft box edges and round lumps (surfaces-fable's UV2);
  - the contact shade;
  - the tilt-shift lens's play rule;
  - the figure's feel layer (bun spring, squash, grip IK).

  Diorama stays on its branches for later.
- **Either way, for the next day shift:**
  - fix `flight_review` still mode (no wings since 8cae88f);
  - make the COMMON tour use `--load=block`;
  - consider a second window-lock class for pictures-only tours;
  - decide whether hockey's wall-clock budget may decide a gate on a loaded machine.

## Asks (answer in chat)
1. **a) adopt diorama** or **b) evolve crisp cel**?
2. The leaders (frame Astra, surfaces Fable, character Fable): agree, or swap a pillar?
3. A squat toy skeleton for the diorama figure: wanted?
4. The hockey arena under the diorama sun has almost no skater shadows: readable enough, or bring them back?
5. Tooling: a second window lock for pictures-only captures? Hockey's frame budget treated like perf (NOT RUN when busy)?
