# L3 falls: three Astra arms, one hit lab, the owner picks by eye

Read `docs/shifts/2026-11-21-day/COMMON.md` first: the owner's words, the laws, the Codex call, and your column (the
ARM trees only). Then read the spark note `.spark/Spark/ideas/game-quality-bar.md` (main checkout): digests A, B and C,
and the brief's L3 package.

- **You are the Opus director.** Astra builds; you set the arms up, brief them, verify every claim, and make the
  comparison.
- **Worktrees:**
  - yours: `C:/Users/kazda/kiro/third-life/.claude/worktrees/n21d-falls` (branch `n21d-falls`);
  - arms: `n21d-falls-a`, `n21d-falls-b`, `n21d-falls-c` (branches of the same names).
  - All are based on main `df58f0b`.
- **Time box:** until 18:30. No arm lands today: the owner picks at the verdict.
- **Standups:** in `lanes/L3-falls/STANDUP.md` in YOUR tree, with one line per arm when it moves.

## The owner's words on falls
- "failing physics and animations" (today).
- "physics and animation around collisions (check, board hit, knockdown, get-up ...; sim rule and figure reaction
  together)" (13 Nov).
- "reactivity on hits" (today, for the arena).
- When asked to choose authored clips, clips plus a physics blend, or an active ragdoll, he answered: "Orchestrate Astra
  agents in parallel today to experiment with all three".

## Today
- `TLBiped.down()` plays one forward `fall` clip whatever the direction. A head-on hit drops the victim TOWARD the hitter.
- There is no get-up clip; it blends back over 24 frames.
- There is no hit-reaction clip, and no ragdoll or PhysicalBone code anywhere.
- The stumble is a side lean of the locomotion pose.

Thirdjam's version (clone path in COMMON.md; `JamGame/Private/SkeletalSkaterVisual.cpp:26-28,100-125,215-245`):
- 19 authored sequences, including `knocked_down` (40 f) and `get_up` (20 f);
- a backward fall for front hits, faster for harder hits;
- an 88-degree tip for side and behind hits over 14 frames;
- a lean for standing hits.

## The shared spec (every arm builds the same surface)
- `TLHit.react(who, from_dir, strength)`:
  - `from_dir` points from the victim toward the blow; `strength` is 0.3 a tap, 0.7 solid, 1.2 and up big.
  - A flinch away from the blow, scaled by strength, readable at game scale. At 0.4 and up it is also a short loss of
    control, as `stumble` is.
- `TLHit.down(who, frames, from_dir)`: falls AWAY from the blow (backward for a front hit, sideways for a side hit,
  forward for a hit from behind), lies there, then a get-up you can see. `TLBiped.down` semantics hold: the timings,
  `downed` and `got_up`, and down while down.
- **The hit lab:** `engine/rigs/review/hit_lab.tscn` and `.gd`. YOU build it first, in your tree, and copy it into the
  three arm trees.
  - Two figures under crisp. Hits from the front, side and behind at strengths 0.3, 0.7 and 1.2: `react` for the small
    ones, `down` for the big ones. Each is followed by the get-up.
  - Then the same hockey body check the pack does, with the stick figure.
  - One scripted 10-14 s run, the same in every arm, recorded with the movie writer to a clip.
- **Measures, per arm:**
  - determinism: the same lab twice gives the same hash, and a hockey bot twice gives the same hash;
  - world = alone (`node devx/bin/tl.mjs check --tier full --only world,packs`);
  - frame cost: hockey `invariants` p50, labelled busy or quiet, and A/B against main;
  - the kernel suite blocks it touches.

## The three arms (one Astra run each; you write each arm's brief file)
- **A, authored:**
  - New rig clips: `hit_front`, `hit_back`, `hit_left`, `hit_right` (flinches); `fall_back`, `fall_front`, `fall_side`;
    `get_up_back`, `get_up_front`.
  - `TLHit` picks the clip by `from_dir` in the victim's frame.
  - Deterministic by construction.
- **B, clips plus a physics blend:**
  - A's clips, plus a short physical wobble on the hit bone and its children.
  - It can be a spring on the bone's rotation driven by the impulse (deterministic, no physics engine), or Godot
    `PhysicalBone3D`, if it can be made deterministic and cheap.
  - The blend goes 0 -> 1 -> 0 over about 12 frames.
- **C, active ragdoll:**
  - Physical bones (`PhysicalBone3D` / `PhysicalBoneSimulator3D`) driven toward the animated pose with motors or
    springs. On a big hit the motors let go and the figure really falls, then recovers.
  - Prove or disprove determinism and world = alone honestly. A ragdoll that breaks the hash law is NOT eligible, but
    its clip still goes to the owner, labelled as such.
- In every arm, `engine/kernel/api/tl_biped.gd` sits at the 600-line cap: split it, never grow it.
- Every arm's selftest is in block 670 (`670-falls.sh`, in its own tree).

## Deliverables
- `lanes/L3-falls/`:
  - `arm-a.mp4`, `arm-b.mp4`, `arm-c.mp4` (the lab run, each 10-14 s);
  - `arm-*-hockey.mp4` (the check);
  - one side-by-side sheet `falls-sheet.jpg`;
  - `COMPARE.md`, a table per arm: determinism, world = alone, frame cost, the kernel suite, Astra tokens, and an
    eligibility verdict.
- Each arm's tree is left with its work uncommitted. The Director commits each to its branch for the owner's pick.

## Acceptance
Three arms built and measured, or an arm cut with what was learned. The clips are judged by you in a window, not only
headless.
