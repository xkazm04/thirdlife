# Falls: three routes, one lab (L3, day of 21 Nov 2026)

The owner asked for "failing physics and animations" and "reactivity on hits", and chose to have three routes tried in
parallel by GPT 6.2 Astra. He picks by eye. **No arm lands today.** Each arm's work is uncommitted in its worktree
(`.claude/worktrees/n21d-falls-a`, `-b`, `-c`) and its round-1 state is kept in `<tree>/.tl/r1/`.

## Watch first
- `falls-side-by-side.mp4`: the same 12.5 s lab, 2x2: base (main today) | A, B | C.
- `falls-hockey-side-by-side.mp4`: the real hockey game's `bot_check`, the head-on and the side knockdown at 8 m/s, in
  the broadcast camera, 2x2 the same way (13.2 s).
- One arm alone: `arm-a.mp4`, `arm-b.mp4`, `arm-c.mp4` (lab), `arm-a-hockey.mp4`, ... (hockey), `base-*.mp4`.
- `falls-sheet.jpg`: ten key frames per row (base, A, B, C): front tap, front solid, front fall +8 f, lying, get-up,
  side fall +8 f, side lying, behind fall +8 f, behind lying, hockey check +34 f.

All clips were rendered in a window (d3d12, the movie writer at a fixed 60 fps, 1280x720, crisp style) and judged by
the Director frame by frame (contact strips of every 2nd-4th frame around every hit).

## The lab (`engine/kernel/examples/ex_hit_lab`, selftest block 670)
A red attacker with a stick hits a standing blue victim from the FRONT, the SIDE (his right) and BEHIND at 0.3 and 0.7
(`TLHit.react`) and 1.2 (`TLHit.down(victim, 40, from_dir)`), each big hit followed by the get-up; then the hockey body
check on ice with the pack's numbers (closing 7.98 m/s, down 32 f). The camera is side-on: every fall AWAY from the blow
goes to the right of the picture. It plays itself (750 frames); the bot reports, per hit, how far the head socket moved
away from / toward the blow and where it lies 30 frames after a big hit. The state holds a digest of the victims' five
sockets every frame, so a drawn pose that differs between two runs changes the hash.
It is a pack, not `engine/rigs/review/hit_lab.*` as the brief said: a scene in `engine/rigs/` that calls TLBiped/TLHit
breaks the `module-walls` rule (rigs reference nothing outside themselves).

## Per hit (metres of head travel; flinch = away / toward; big hit = where the head lies, + = away from the blow)
| hit | base | A authored | B clips + spring | C ragdoll |
|---|---|---|---|---|
| front 0.3 | 0.00 / 0.03 | 0.22 / 0.03 | 0.18 / 0.10 | 0.11 / 0.03 |
| front 0.7 | 0.04 / 0.00 | 0.51 / 0.00 | 0.41 / 0.02 | 0.32 / 0.00 |
| front 1.2 | lies **-1.11** (toward him) | lies 1.44 | lies 1.37 | lies 1.66 |
| side 0.3 | 0.00 / 0.00 | 0.22 / 0.00 | 0.16 / 0.08 | 0.12 / 0.00 |
| side 0.7 | 0.24 / 0.00 | 0.60 / 0.00 | 0.39 / 0.01 | 0.38 / 0.00 |
| side 1.2 | lies 0.00 | lies 1.29 | lies 1.31 | lies 1.51 |
| behind 0.3 | 0.00 / 0.01 | 0.22 / 0.01 | 0.18 / 0.10 | 0.11 / 0.01 |
| behind 0.7 | 0.05 / 0.00 | 0.50 / 0.00 | 0.41 / 0.02 | 0.32 / 0.00 |
| behind 1.2 | lies 1.11 | lies 1.32 | lies 1.33 | lies 1.64 |
| hockey check 1.2 | lies **-0.41** | lies 1.91 | lies 1.34 | lies 1.61 |
| lowest head while down (front) | 0.64 | 0.50 | 0.46 | 0.23 |

B's "toward" on taps (0.08-0.10) is the spring's swing back, not a flinch toward the blow.

## Per arm
Every figure below was re-run by the Director on the arm's final (round 2) tree; Astra's own numbers are not quoted
as evidence except where marked "Astra".

| | base (main + lab) | A authored | B clips + spring | C active ragdoll |
|---|---|---|---|---|
| How | one forward `fall` clip | 4 flinch, 4 fall, 2 get-up pose clips, chosen by `from_dir` in his frame; floor fit of soles, hands, stick | A-style clips + a damped spring on the hit bone and its chain (12 ticks), landing bounce | 12 Jolt bodies per figure, motors toward the pose; private Jolt space per struck figure with a copied floor plane |
| Shared spec `falls.lab_spec` | FAIL (red by design: front fall toward the hitter) | PASS | PASS | PASS |
| Lab determinism (bot twice, socket digest in the hash) | a6b31cf5 = a6b31cf5 | 0065d638 = 0065d638 | fec99b42 = fec99b42 | c5d1d4fb = c5d1d4fb |
| Hockey sim unchanged: `bot_check` hash | 5f1900dc | 5f1900dc (= base) | 5f1900dc (= base) | 5f1900dc (= base) |
| Hockey sim unchanged: `bot_hockey` hash (invariants) | 3b372f91 | 3b372f91 (= base) | 3b372f91 (= base) | 3b372f91 (= base); round 1 moved it to 450d9612 (bodies in the game's space), fixed in round 2 |
| World = alone (`check --tier full --only world,packs`) | world 8/8 | world 8/8 | world 8/8 | world 8/8 |
| packs | 60/61 verb runs | 60/61 | 60/61 | 60/61 |
| ...the one FAIL in every tree | hockey `many_budget` p50 1.368 ms | 1.036 ms | 1.091 ms | 1.158 ms |
| Frame cost, hockey invariants p50, interleaved A/B | 1.063 ms (median of 6; 0.99-1.18) | 1.122 ms (1.02-1.26); paired vs base +0.04 | 1.145 ms (1.06-1.20); paired vs base +0.09 | 1.122 ms (1.02-1.20); paired vs base +0.06 |
| Extra cost per reacting figure (Astra's paired bench, busy) | - | none measured (pose clips) | +0.050 ms/tick for 12 springing skaters | +0.32 ms/frame for ONE active fall among 12 figures |
| Kernel blocks that run a biped (k2 k3 k6 k8 ex rig moves hockeyfun falls p11 hunt2 dungeon) | 115/116 (the FAIL is `falls.lab_spec`, red by design) | 117/118 first run (FAIL `k2.down_invariants` = ex_down `many_budget` p50 1.071 ms, wall clock under load); re-run alone 4/4 PASS | 122/122 | 120/120 |
| Rig selftest `k.sh selftest` (every clip twice equal) | 95/95 | 107/107 (12 new clips) | 105/105 (10 new clips) | 95/95 |
| Fast tier | arch 12/12, assets 4/4, cards 3/3, devx 229/229 | same | same | same |
| tl_biped.gd lines (cap 600) | 600 | 562 | 567 | 569 |
| Public API change | - | none (private `_size_hit` rig method) | none (private `_hit_impulse`, `_start_get_up`) | none (private `_hit_reaction`, `_hit_rise`) |
| Astra tokens (session total, 2 rounds) | - | 517 k | 457 k | 678 k |

Frame cost: hockey `invariants` run 6 times per tree, interleaved base, A, B, C in each round (15:23-15:42), CPU 43-93 %
and 2-14 other Godot processes: **BUSY**. Every arm's median is 0.04-0.09 ms above the base, inside a per-round spread of
-0.14..+0.21 ms, and the base always ran first in a round, so the order is not controlled: **not distinguishable from
the base on this machine; a quiet A/B is still owed.** Every run of every tree gave the base's bot hash 3b372f91.

`foreman.typecheck` is NOT RUN in every worktree (no foreman node_modules there); no arm touches foreman.
The `many_budget` line is wall clock on a machine running 6 lanes (9-36 Godot processes, CPU 60-100 %): BUSY, not
evidence either way; it fails on the untouched base too.

## What the Director saw (by eye, frame by frame)
- **Base (main today):** a tap shows nothing; the front big hit drops him forward INTO the attacker; the side hit
  drops him forward too (across the blow); he blends back up over 24 frames without touching the floor.
- **A, authored clips:** the richest front fall of the three: the knees give, the seat lands first, he rolls onto his
  back, sits up, brings a knee under and stands. Side (round 2): thrown onto hip and shoulder and left sprawled (an
  arm past the head, legs apart), up through hands and a knee. Behind: pitches forward, both hands reach the floor,
  prone, pushes up through a kneel. Taps snap the chest and head (0.22 m) in 3-4 frames while the legs keep walking.
  Weak: a pose is a pose, so every front fall is the same fall; the get-up is fast (24 frames, the kernel's window).
- **B, clips + spring:** falls like A's but plainer (the front one goes over like a board). Round 2 made the physical
  layer visible in the lab: a tap is a jolt that rings once (head out 0.18 m, back 0.10 m), the hands lag a frame, and
  head and gloves bounce once on landing; the side get-up now goes through a hand and then hands and a knee. At the
  hockey camera the wobble cannot be seen.
- **C, active ragdoll:** the falls are really physical: a stiff topple, limbs that flop on landing, the lowest lie of
  the three (head 0.23 m off the floor), and by construction no two falls the same. Taps are the smallest (0.11 m: the
  motors only soften). Weak: in the side fall the neck bends to an odd angle for a few frames; the hips rise quickly out
  of the kneel; the get-up blends from the physical pose back to the animation inside the same 24 frames.
- **Hockey, broadcast camera (all three):** the victim visibly goes horizontal and away from the hitter instead of
  forward into him (base), but the figure is small and partly under the hitter; at this distance A, B and C read about
  the same. The difference between the routes is a lab-camera (close, arena-fight) difference.

## Eligibility
The rule of the day: an arm is eligible only if determinism, world = alone and frame time hold.

| Arm | Determinism | World = alone | Existing games unchanged | Frame time | Verdict |
|---|---|---|---|---|---|
| A authored | holds (lab twice; hockey bots = base) | 8/8 | yes (both hockey hashes = base) | not distinguishable from base (busy); no per-hit cost by construction | **ELIGIBLE** |
| B clips + spring | holds | 8/8 | yes | not distinguishable from base (busy); spring +0.05 ms/tick for 12 springing figures (Astra bench) | **ELIGIBLE** |
| C active ragdoll | holds (round 2; Jolt, private space per figure, stepped once per rig tick) | 8/8 | yes in round 2 (round 1 moved the hockey match hash: NOT eligible then) | p50 not distinguishable (busy), but a measured **+0.32 ms per frame for each figure in an active fall** (Astra bench, 6/6 paired runs positive): three skaters down at once is about a third of hockey's 1.0 ms budget | **ELIGIBLE with a cost caveat**: quiet p99 during a pile-up must be measured before it lands in hockey |

Notes for the pick:
- A and B look alike in a still; B's difference is motion (the tap rings, the landing bounces). Play
  `falls-side-by-side.mp4` at full size around 0:00.6-0:01 (front tap) and 0:02-0:03 (front fall).
- C is the only one where the fall is not the same twice and the body really lands; it is also the only one with an
  odd pose (the neck in the side fall) and a real per-hit cost.
- All three fix the base's worst problem (a front hit dropped the victim forward into the hitter), and all three keep
  every existing game's state hash.
- Choosing A or B leaves the other's clips reusable (B builds on the same clip idea); C's motors could later drive A's
  clips as targets.
