# E5d: the change path after E3f, on a reopened game (25 Nov 2026, hk-proof at aad3d6f, foreman rebuilt)

**Both changes worked: fast path, the cartridge took them, the skin and match stayed byte-equal, and each showed on
screen. 202 s and 179 s.**

The setup:
- I reopened job 1 of E5b (`.tl/proof-jobs-b/against-3-hockey-20261125-1`, the pond game, done at v0.1.2) as My games
  does: read the done job, then the change box.
- I sent two changes exactly as Create sends them: `foreman change <job> "<words>"` with real.json's change flags
  (claude-cli, sonnet), through `engine/ui/foreman_run.mjs`.
- The whole round took about 14 min of the 40. No code changed. Stills in `e5d/`; I looked at all of them. The raw
  captures under .tl/ are deleted.

| | v0.1.3: "make the rink bigger" | v0.1.4: "make the goals bigger" |
|---|---|---|
| time (request to promotion) | **202 s** (08:31:37 to 08:34:59 UTC) | **179 s** (08:35:11 to 08:38:10 UTC) |
| path | **fast** ("[foreman] data-only change (data/black_ice.cartridge.json): the pack tests, the re-verification of skin, trials and the milestone's re-look are skipped"; final = lint + smoke + ONE picture) | **fast** (the same notes) |
| runner calls | 9: lint 3, smoke 3, bot 2 (the round's acceptance), capture 1 | 9: lint 3, smoke 3, bot 2, capture 1 |
| model calls | 3 generate, 29k tokens in: the owner question (3.1 s), the diff twice (5.4 s, 6.7 s) | 2 generate, 16k in: the owner question, the diff (3.4 s) |
| package | **cartridge** (not the base): "The rink size is a play-space rule defined by the game's data files, and the cartridge package owns ..." | **cartridge**: "Goal size is part of the play space and rules defined in the cartridge's data files ..." |
| merged | 1 file: data/black_ice.cartridge.json | 1 file: data/black_ice.cartridge.json |
| what-changed note | "[foreman] what changed in v0.1.3 (since v0.1.2): asked "make the rink bigger"; game.rink.length_m: 46 -> 72; game.rink.width_m: 24 -> 36; game.rink.corner_radius_m: 3.75 -> 5.9; game.rink.goal_width_m: 4 -> 3.2; files: data/black_ice.cartridge.json" | "[foreman] what changed in v0.1.4 (since v0.1.3): asked "make the goals bigger"; game.rink.goal_width_m: 3.2 -> 4.8; files: data/black_ice.cartridge.json" |
| cmp data/skin.json, data/match.json against the previous version | **byte-equal, both** | **byte-equal, both** |
| other files that differ (diff -rq) | only the cartridge and pack.json (the version) | only the cartridge and pack.json |
| cartridge keys | length_m 46 -> 72, width_m 24 -> 36, corner_radius_m 3.75 -> 5.9, **goal_width_m 4 -> 3.2 (not asked)** | goal_width_m 3.2 -> 4.8 |
| measured before | **FAILED** (v0.1.2 under E3f's goals-a-minute check: pro 6 goals in 0.8 min); skating alone 8/16 | ok: pro 5.2 goals, 1.1 min, speed 11.2 |
| measured after | ok: pro 5.2 goals, 1.1 min, speed 11.2 m/s; warnings: trivial at all_star, mean speed 11.4-11.8 above thirdjam's 6.2-10.3; skating alone 9/16, not judged (planning hand NOT VALID) | ok: pro 6.2 goals, 1.3 min, speed 10.9; the same speed warnings; skating alone 5/16, not judged |

## What I saw
- **`d_top_v012_vs_v013.jpg`** (top camera, the same height and lens; v0.1.2 left, v0.1.3 right): the rink is clearly
  bigger. The left ice spans about a third of the frame width, the right about half, and the circles sit farther
  apart.
  - This job's base was copied before E1b, so its top view still looks through the roof trusses (E1b's clean top view
    is not in this job).
- **`d_net_v013_vs_v014.jpg`** (the same crop of the right net, magnified): the net is visibly wider in v0.1.4 (3.2 ->
  4.8 m), and the crease and posts are drawn at the new width.
- **`d_follow_v012_vs_v013.jpg`** and **`d_follow_v013_vs_v014.jpg`** (follow camera): still the blue Otters against
  the orange Pike in their own colours, first to 5. The skin's words are on screen: "Just you and the keeper!",
  "Otters beat the keeper!". v0.1.4's still is a goal into the wide net.
- As a player: both changes show. The rink feels bigger and the goals are bigger, and it is still my game.

## Notes for the Director
1. **The rink change also narrowed the goals** (4 -> 3.2, "so goals don't pile up"). Nobody asked for that, and it
   made the next "make the goals bigger" partly an undo: the net result is 4 -> 4.8. The what-changed note does say
   so. A person reading only the box's words would not expect it.
2. **The game's speed is now above anything thirdjam ships** (mean 11.4-11.8 m/s after "make it faster" in E5b). That
   is a warning only, and "trivial at all_star" also stays a warning.
3. Change 1 made two diff calls (5.4 s and 6.7 s); the first answer was presumably refused and asked again. It cost
   about 7 s more.
4. The fast path holds on the real adapter: 9 runner calls and about 3 min, against E5b's 777 s and 395 s for the same
   kind of change.

landable E5d
