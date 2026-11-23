# Campaign night of 23-24 Nov 2026: plan (hockey as a 1:1 port of thirdjam; stair steps 0-1)

**The owner, 23 Nov ~16:20** (verbatim in `docs/design/DIRECTIONS.md`): the behaviour pass is "the same garbage as
before ... not even close to thirdjam"; ten directions, executed until the Director thinks the game is perfect, as long
as it takes; "the pictures will not uncover core problem which is the gameplay itself in speed and balancing of skill
mechanisms". No handshake: the scope is his message and DIRECTIONS.md.

## What the scouts found (17:00-17:20)
- thirdjam: a chase camera 6 m behind and 3.5 m above a 1.64 m skater, FOV 70, on 90 x 45 m, 5 v 5 without goalies,
  first to 3; the figure is a 12k-triangle skinned mesh with the stick skinned in and 202 clips (the team's own);
  the sim and the bots are about 12,000 lines of portable C++ (the bots pure C++); 432 automation tests; a tournament
  commandlet with a per-frame trace and human-like playtester hands (novice, regular, good).
- ours: a pack may place a free camera and run its own motion; the figure is the engine's walking figure scaled to
  4.4 m with a rigid stick on one hand (why it flies and sinks); no imported skinned figure, no pack mouse capture, no
  minimap or bar widget, no crowd; a pack is capped at 6,000 lines (hockey is at 5,985).

## Decisions (Director)
- The simulation and bots are thirdjam's own C++ compiled into the engine (a GDExtension), not re-typed: the same source
  gives the same game, proven by equal traces against the Unreal build. Fallback only if the toolchain blocks it.
- The figure is thirdjam's own mesh and clips exported from Unreal and driven through the same interface.
- The game core is an engine module (`engine/cores/rink/`); the game is a thin pack `engine/packs/hokej` (a cartridge):
  direction 10. The old `engine/packs/hockey` is untouched until the owner passes the new game.
- Campaign branch `hokej` (integration tree `hk-int`); nothing lands on main but documents until the owner's word.

## Lanes (started ~17:40)
| Lane | Tree / branch | Model | What | First landable |
|---|---|---|---|---|
| K1 core | hk-core | Opus | thirdjam's sim + bots compiled into the engine, trace-equal to the Unreal build, `SNAPSHOT.md` | spike 90 min |
| K2 figure | hk-figure | Fable | thirdjam's skater exported, imported, driven like `IJamSkaterVisual`, defects as tests | export 2 h |
| K3 shell | hk-shell | Opus | the gym: rink, chase camera, key and mouse mapping, one skater, side by side with thirdjam | round 1 |
| K4 reference | (after K1) | Opus | tempo map, mechanic matrix by ablation, hand ladder, on the native core | held: RAM 15 GB free |

## Standups
Lanes report by message when landable; a timer standup every hour at :23 as a fallback.

## Landing rule
Lanes land on branch `hokej` when verified by the Director (fast tier on the merged tree, the lane's own proof re-run
or re-looked-at: the Director looks at the frames himself). main gets documents only.
