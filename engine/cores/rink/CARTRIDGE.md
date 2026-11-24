# The rink cartridge: what a user's rink game IS

A rink game in Third Life is **a cartridge on the rink core, plus a skin**. The core is thirdjam's own simulation, compiled
unchanged (`native/thirdjam`, the proofs in `SNAPSHOT.md`). The cartridge is one JSON file in thirdjam's `tj.cartridge/1` format:
the rink, the skaters, the stick, the puck, the shot, the pass, the contact, the rules, the teams, the bots, the toys, the look
and the camera. Everything a designer changes to make a new rink game, and everything an iteration ("make it faster", "a bigger
rink", "rocket skates") changes, is a change to this file. Code is only for what no key can say (the end of this page).

This page is for a designer (a person, or the Foreman's planner) and a builder:
1. the files and how a pack opens them;
2. how to check one before anybody plays it;
3. every key in player words (what a person feels when it moves), its range, which keys go together;
4. thirdjam's twelve modes as worked examples (exactly what each changes);
5. thirdjam's own sentence-to-cartridge cache: words a person said, and the keys they moved;
6. what a cartridge cannot do.

Parts 4 and 5, and the full key table, are generated from thirdjam's files by `schema/catalog.py` (never typed by hand:
`python -I engine/cores/rink/schema/catalog.py --check` says whether this page is current).

## 1. The files

| file | what it is |
|---|---|
| `data/<name>.cartridge.json` in a pack | the game: a `tj.cartridge/1` cartridge. `ctx.cores.open("rink", "<name>.cartridge.json")` loads it (kernel API section 24) |
| `data/<name>.rules.json` beside it (optional) | `tl.rink.rules/1`: switches the thirdjam schema has no key for (today one: `net_carry_wall`, a held puck cannot cross the goal line), and a bot-skill tune per level. Its presence opens the thirdlife core (`RinkCoreThirdlife`) instead of thirdjam's (`SNAPSHOT.md`, "Two cores") |
| `engine/cores/rink/schema/` | thirdjam's schema and limits (`cartridge.schema.json`, `game.schema.json`, `limits.json`) extracted from the C++ loader's embedded copy by `extract.py` (proved: the .inl regenerated from the files equals the original to the byte, and the files equal thirdjam 8dc713c6 `schema/`), and thirdjam's own validator `validate.mjs` + `strict-json.mjs`, copied byte for byte |
| `native/content/Cartridges/` | every cartridge thirdjam ships: `hockey.regular` (the game), the modes in `modes/`, test cuts |

The envelope: `schema` ("tj.cartridge/1"), `id` (kebab-case), `title` (up to 60 characters), `seed`, `theme` (palette, mood
words), `tunables` (named knobs with min / max / default) and `values` (the knobs' chosen values), `rules`, `entities`, `ai`, and
`game` (everything below). A `values` key must be a declared tunable; most of a game's change lives in `game`.

**The laws that bite**: unknown keys are errors everywhere (a misspelt key is refused, never ignored); absent = omit the key
(`null` is refused with "omit the key instead of writing null"; an absent key takes the loader's default); durations are
physics frames at 60 a second (`*_frames`; a key ending in `_seconds` or `_ms` is refused); the JSON is parsed strictly
(duplicate keys, trailing commas and comments are refused); the whole file at most 24,000 bytes.

## 2. Checking a cartridge before anybody plays it

1. **Valid?** `foreman/src/cartridge.ts` `validateCartridgeText(text)` (or `node engine/cores/rink/schema/validate.mjs <file>`):
   thirdjam's validator, the same verdict as the core's C++ loader on all 106 cases of the parity corpus (every shipped
   cartridge, 56 broken and harmless copies of regular and Pond, 12 rules files; `foreman/src/test/cartridge.test.ts`).
   Each error is a sentence that starts with the JSON pointer of the fault ("at /game/skater/speed: 33 is above the maximum
   16."), so a model can repair its own output. `validateRulesText` checks a sidecar the way the core's reader does.
2. **A change, not a new file**: `applyChanges(cartridge, {"game.skater.speed": 13, "game.rink.length_m": 60})` applies a
   change set (key path -> value; `null` removes a key) to a copy, says what moved ("game.skater.speed: 11 -> 13") and
   validates the result. An iteration sends this, never a rewritten cartridge.
3. **What will a person meet?** `bash engine/tools/rink.sh check-cartridge <file> [--rules <file>]` plays it headless in the lab
   (about 15 s): thirdjam's regular playtester with sprint (a scripted hand; 10 seeds at each of rookie, pro, all_star) and
   K8's planning hand (2 seeds a level), against thirdjam's bots. It says, per level: who wins, goals a match, match length,
   how long a carry lasts, how much of play the puck is loose, knockdowns, shots, completed passes, skating speed, how often
   the puck changes hands, how often the hand touches the puck, goals walked in; then warnings in words (unwinnable at
   rookie, trivial at all_star, no goals, a goal flood, and any figure beyond a quarter past the range thirdjam's own
   21 cartridges span, `lab/check_cartridge.bands.json`). A `tl.rink.check/1` JSON line is last, for the Foreman. A scripted hand
   measures the game, not the person: every figure names its hand.

Measured (24 Nov, 10 seeds a level, the playtester; the planning hand in brackets):

| cartridge | rookie wins | pro wins | all_star wins | goals a match (pro) | match (pro) | warnings |
|---|---|---|---|---|---|---|
| hockey.regular | 10/10 (2/2) | 7/10 (1/2) | 6/10 (2/2) | 4.3 | 2.9 min | none |
| Pond | 9/10 (2/2) | 5/10 (2/2) | 5/10 (2/2) | 11.3 | 3.8 min | none (11 goals walked in a level: the open net of a 6 m goal) |
| "broken feel": regular with speed 16, accel 36, turn 12, puck 60 m/s, frictionless ice, boards at 1 | 10/10 | 4/10 | 3/10 | 3.9 | 1.5 min | mean skating speed 15 m/s at every level, top 29.9 m/s: above anything thirdjam ships (6.2..10.3, 13..26.2) |

The broken cartridge is VALID (every key in range): only the measured check catches that it would feel wrong.

## 3. The keys in player words

Ranges are the schema's (the full table with every key is in part 7). "Goes with" names the keys that change together in
thirdjam's own modes; lessons in brackets come from thirdjam's MODES.md measurements.

### The rink: how much room, how the boards and the ice answer
| key | a person feels | range (regular) | goes with |
|---|---|---|---|
| `rink.length_m`, `width_m` | room: a long rink is legs and breakaways (Marathon 140 x 70), a small one is traffic, hits and quick shots (Bruisers, Shotgun 56 x 28) | 40..160 x 20..80 (90 x 45) | `corner_radius_m` (scale it with the rink), team sizes (small rink + five a side = a crowd), `rules.timer_frames` (long rink, longer match) |
| `rink.corner_radius_m` | round corners carry the puck round the back; square ones trap it | 0..15 (3.75) | the rink's size |
| `rink.board_restitution` | live boards: the puck and the bodies come back off them (Cage 0.95, Pinball 1) | 0..1 (0.4) | `contact.board_bonus` (hits into the boards) |
| `rink.ice_friction` | slippery ice: the puck runs on and on; 0 never slows | 0..0.1 (0.015) | `puck.drag` (both slow the puck) |
| `rink.goal_width_m`, `goal_height_m` | an easy or a hard net: a 6 m net is a shooting gallery (Pond's 11 goals a match) | 2..10, 0.3..1.5 (4) | `skater.goalie.*` (the keeper's reach) |
| `rink.obstacles[]` | pillars, boxes, bumpers on the ice: a pinball table or a maze | up to 12 | `board_restitution` |
| `rink.zones[]` | patches of slow or fast ice, bumpers, no-shoot areas, boost-only places | slow_ice, fast_ice, bumper, no_shoot, boost_only | `pickups[].zone` (Arsenal: boosts only at the centre) |

### Skating: how the body moves under the person's hands
| key | a person feels | range (regular) | goes with |
|---|---|---|---|
| `skater.speed` | top speed: fast is exciting and hard to steer; the first thing "faster" moves | 3..16 (11) | `accel`, `turn_rate` (faster needs a sharper turn or it slides past everything), `rink` size |
| `skater.accel` | how quickly he gets going: snappy or heavy | 4..40 (12) | `speed`, `mass` |
| `skater.turn_rate` | how sharply he turns | 1..12 (5) | `lateral_grip` |
| `skater.lateral_grip` | how much he slides sideways in a turn: low = drifting on ice | 0.5..12 (3) | `turn_rate` |
| `skater.mass` | heavy bodies: hits hurt more, he is harder to knock down (Bruisers 130) | 40..160 (80) | `check_speed_min`, `contact.*` |
| `skater.glide_drag`, `brake_decel` | coasting and stopping: how far he glides with no input, how hard the stop bites | 0..1, 1..30 (0.147, 6) | |
| `skater.sprint.*` | the sprint bar: a burst of speed that empties and refills (Marathon 0.4 bonus, 240 / 480 frames) | | `speed`, the rink's length |
| `skater.carry_speed_mult` | the carrier is slower than free skaters: below 1 makes passing pay, because the puck moves faster than legs (Power Play 0.65) | (0.92) | `pass.*`, team sizes |
| `skater.breakaway.*`, `burst.*`, `spin.*` | the extra moves: a breakaway bonus, a burst off the mark, the spin move | | |

### The stick and the puck: holding it, losing it, taking it
| key | a person feels | goes with |
|---|---|---|
| `stick.reach_m` | how far his stick reaches: long = easy takes and pokes | `stick.lift_range_m`, `poke_window_frames` |
| `stick.take_grace_frames` | a puck just won cannot be taken back at once: 0 = fair game the moment it is won (Sudden Death), more = calmer possession (Outnumbered 90) | `contact.release_grace_frames` |
| `stick.reception_m` | how easily a pass is received: a bigger catch for a passing game (Pond, Power Play 3) | `skater.pass_speed`, `pass_lead_frames` |
| `stick.pickup.*`, `deke.*`, `sweep.*` | the hand's touch: picking up loose pucks, the deke's fake, the sweep that shields | |
| `puck.max_speed`, `puck.drag` | how fast the puck can go and how quickly it dies: fast and dragless = pinball | `rink.ice_friction`, `shot.speed` |
| `puck.radius_m`, `gravity_mps2`, `ice_restitution` | a bigger, floatier or bouncier puck | |

### Shooting and passing: what the buttons do with the puck
| key | a person feels | goes with |
|---|---|---|
| `shot.speed` | how hard a shot flies: fast shots score from far (Sniper 26, Pinball 30) | `charge_frames_max`, `charge_speed_bonus` (a held shot) |
| `shot.charge_frames_max`, `charge_speed_bonus` | holding the shot charges it: a wind-up worth waiting for | `shot.lift.*` |
| `shot.aim_cone_deg` | aim help: a wide cone forgives a loose aim | |
| `shot.lift.*` | lifting the puck over sticks and the keeper | `rink.goal_height_m`, `skater.goalie.block_height_m` |
| `shot.one_timer.*` | shooting a pass straight away: a window and a bonus | team sizes (needs mates), `pass.*` |
| `skater.goalie.*` | the keeper: his reach, his block height, how well he reads a shot (Sniper: reach 0.9, block 0.15) | the goal's size |
| `skater.pass_speed`, `pass_lead_frames` | how fast a pass travels and how far ahead of the mate it is aimed (a 10 m/s pass falls under the 6 m/s a reception needs after 8 m: Pond took `pass_speed` out) | `stick.reception_m` |
| `pass.power.*`, `pass.saucer.*`, `pass.aim.cone_deg` | a held pass goes further; the saucer lifts over sticks; the cone picks the mate | |

### Contact: hits, falls, the rough side
| key | a person feels | goes with |
|---|---|---|
| `skater.check_enabled` | whether the check button works at all: off = nobody gets hit (Pond) | everything below |
| `skater.check_speed_min` | how fast he must arrive for a check to knock a man down: low = hits fell people easily (Fog of War 1, Bruisers 1.5) | `mass`, `contact.momentum` |
| `skater.knockdown_frames` | how long a downed man stays down (Blind Side 240 = four seconds out of play) | `contact.down_frames_*` |
| `contact.board_bonus` | hits into the boards count extra (Cage 2) | `rink.board_restitution` |
| `contact.release_grace_frames` | after a hit, how long before the next can land (Cage 45, Bruisers 60) | |
| `contact.check_reach_m` | the check turns onto the nearest man within this reach: easier to land (Cage, Bruisers 2) | |
| `contact.cross_hold`, `*_windup_frames`, `momentum`, `*_stability` | the held cross-check, wind-ups, the momentum law (speed and mass decide who falls) | |

### Rules, teams, bots
| key | a person feels | goes with |
|---|---|---|
| `rules.mode`, `score_to_win`, `timer_frames` | first to N goals, or a clock: first to 1 = every goal ends it (Sudden Death); a timer = a set length | `variants.*` |
| `rules.penalties`, `penalty_frames` | the whistle: fouls send a man to the box (only Glow Ice has it) | `stick.foul_grace_frames` |
| `rules.variants.*` | sudden death, the last goal counts double, a mercy rule, periods, the rink shrinking with each goal | |
| `rules.hooks[]` | small rules on events: on a goal / a check / every N frames, do: add score, set a parameter, spawn, show text | |
| `teams[]` | who plays: the number of skaters a side (any count; 5 v 5 is the regular game; three a side passes rarely: 0.2 to 0.8 a minute against 2.8 at five), roles (player, chaser, support, back), spawns, jersey colours | rink size, `ai.*` |
| `ai.difficulty`, `speed_scale`, `react_frames`, `body_check`, `hold_radius_m`, `sprint`, `yield_margin_m` | how the bots play: their level, speed, lateness, how much they hit, whether they leave the person's puck alone, whether mates give the puck back | the level ladder (rookie / pro / all_star) |

### Toys and presentation
| key | a person feels |
|---|---|
| `pickups[]` | boosts that appear on the ice (speed, precision, ...): how often, how long, how strong, where |
| `abilities[]` | a trick on F: shotgun (a blast that clears the lane), hip_check, shield, slow_puck; from the start or from a pickup, with charges and a cooldown |
| `effects[]` | timed changes to stats (speed, precision, heavy or big puck, reversed controls) given by pickups, zones or hooks |
| `look.*`, `camera.*`, `barks.*`, `commentary.*` | the arena's tier (day, night, the grid of light, clay), fog, wet ice, the camera's distance and height, how much the players and the commentator talk |

## 4. Worked examples: thirdjam's modes

Each mode is hockey.regular with only these keys changed (generated from the files; the measured reasons are in
`native/content/Cartridges/modes/MODES.md`). Read them as recipes: Pond = a bigger net, a slippery small rink, no hits and a
passing game; Bruisers = a small rink, heavy bodies and easy knockdowns; Sudden Death = first to one against the meanest bots.

<!-- generated:modes -->
| mode | its words (game.meta.pitch) | keys changed from hockey.regular |
|---|---|---|
| Arsenal | Grab a boost, get a trick on F. | `game.abilities` (a list of 4); `game.look.tier` "l3_neon"; `game.look.trim_colour_hex` "#A3FF3D"; `game.pickups` (a list of 2); `game.rink.zones` (a list of 1) |
| Bruisers | Five a side, heavy bodies. Hit everything. | `game.ai.body_check` 1; `game.ai.hold_radius_m` 1; `game.contact.check_reach_m` 2; `game.contact.release_grace_frames` 60; `game.rink.corner_radius_m` 3; `game.rink.length_m` 56; `game.rink.width_m` 28; `game.rules.score_to_win` 2; `game.skater.accel` 9; `game.skater.check_speed_min` 1.5; `game.skater.knockdown_frames` 150; `game.skater.mass` 130; `game.skater.speed` 10; `game.teams` 5 v 5 |
| Cage | Tight box, eight bodies. The boards hit back. | `game.ai.body_check` 0.85; `game.contact.board_bonus` 2; `game.contact.check_reach_m` 2; `game.contact.release_grace_frames` 45; `game.look.tier` "l3_neon"; `game.look.trim_colour_hex` "#FF2D6F"; `game.rink.board_restitution` 0.95; `game.rink.corner_radius_m` 2; `game.rink.length_m` 60; `game.rink.obstacles` (a list of 4); `game.rink.width_m` 28; `game.rules.mode` "timer"; `game.rules.score_to_win` absent; `game.rules.timer_frames` 10800; `game.skater.check_speed_min` 2; `game.skater.knockdown_frames` 75; `game.skater.speed` 12; `game.stick.lift_range_m` 0.5; `game.stick.poke_window_frames` 2; `game.stick.reach_m` 0.6; `game.teams` 4 v 4 |
| Fog of War | Late bots in the fog. Slip by, then hit. | `game.ai.react_frames` 4; `game.ai.speed_scale` 1.1; `game.look.fog_density` 0.04; `game.look.tier` "l2_night"; `game.skater.check_speed_min` 1; `game.teams` 3 v 3 |
| Glow Ice | Dark ice drawn in light. Boost, but skate clean. | `game.ai.body_check` 1; `game.look.tier` "l3_neon"; `game.pickups` (a list of 1); `game.rules.penalties` true; `game.rules.penalty_frames` 600; `game.rules.score_to_win` 4; `game.skater.check_speed_min` 3; `game.skater.knockdown_frames` 150; `game.stick.foul_grace_frames` 0 |
| Marathon | Three on three on endless ice. Bring your legs. | `game.ai.hold_radius_m` 1.0; `game.ai.sprint` 0.25; `game.look.tier` "l3_neon"; `game.look.trim_colour_hex` "#22E5FF"; `game.rink.corner_radius_m` 5.83; `game.rink.length_m` 140; `game.rink.width_m` 70; `game.rules.mode` "timer"; `game.rules.score_to_win` absent; `game.rules.timer_frames` 21600; `game.skater.carry_speed_mult` 0.8; `game.skater.speed` 10; `game.skater.sprint.bonus` 0.4; `game.skater.sprint.drain_frames` 240; `game.skater.sprint.refill_frames` 480; `game.teams` 3 v 3 |
| Outnumbered | Three on five. Keep the puck, take the heat. | `game.abilities` (a list of 1); `game.ai.hold_radius_m` 2; `game.ai.sprint` 0.75; `game.look.tier` "l1_day"; `game.rink.corner_radius_m` 3.5; `game.rink.length_m` 70; `game.rink.width_m` 35; `game.stick.take_grace_frames` 90; `game.teams` 3 v 5 |
| Pond | Pond hockey. Pass, skate, nobody gets hit. | `game.ai.yield_margin_m` 0; `game.look.tier` "l1_day"; `game.rink.board_restitution` 0.6; `game.rink.corner_radius_m` 3; `game.rink.goal_width_m` 6; `game.rink.ice_friction` 0.005; `game.rink.length_m` 60; `game.rink.width_m` 30; `game.rules.mode` "timer"; `game.rules.score_to_win` absent; `game.rules.timer_frames` 10800; `game.skater.check_enabled` false; `game.skater.pass_lead_frames` 20; `game.stick.reception_m` 3; `game.teams` 5 v 5 |
| Power Play | Five on three. Move it, fire it, repeat. | `game.ai.yield_margin_m` 0; `game.rink.corner_radius_m` 3; `game.rink.length_m` 60; `game.rink.width_m` 30; `game.rules.mode` "timer"; `game.rules.score_to_win` absent; `game.rules.timer_frames` 14400; `game.shot.one_timer.cone_bonus_deg` 14; `game.shot.one_timer.window_frames` 20; `game.skater.carry_speed_mult` 0.65; `game.skater.pass_lead_frames` 20; `game.stick.reception_m` 3; `game.teams` 5 v 3 |
| Shotgun | Tight ice, ten bodies. F clears the lane. | `game.abilities` (a list of 1); `game.rink.board_restitution` 0.9; `game.rink.corner_radius_m` 3; `game.rink.length_m` 56; `game.rink.width_m` 28; `game.skater.check_speed_min` 2; `game.teams` 5 v 5 |
| Sniper | Big net, low guard. Lift it, bury it. | `game.ai.hold_radius_m` 1; `game.rink.goal_height_m` 1.22; `game.shot.charge_frames_max` 40; `game.shot.charge_speed_bonus` 12; `game.shot.lift.full_m` 1.1; `game.shot.lift.half_frames` 10; `game.shot.lift.half_m` 0.7; `game.shot.lift.tap_m` 0.1; `game.shot.speed` 26; `game.skater.goalie.block_height_m` 0.15; `game.skater.goalie.reach_m` 0.9; `game.teams` 5 v 4 |
| Sudden Death | One goal ends it. The meanest bots alive. | `game.ai.difficulty` "all_star"; `game.ai.hold_radius_m` 2.5; `game.rink.corner_radius_m` 5; `game.rink.length_m` 120; `game.rink.width_m` 60; `game.rules.score_to_win` 1; `game.stick.take_grace_frames` 0; `game.teams` 5 v 5 |
| Blind Side (parked) | Juke the back. Do not get blindsided. | `game.ai.body_check` 1; `game.ai.react_frames` 4; `game.look.tier` "l2_night"; `game.rules.penalties` true; `game.skater.check_speed_min` 2; `game.skater.goalie.block_height_m` 0.4; `game.skater.goalie.reach_m` 0.5; `game.skater.knockdown_frames` 240; `game.stick.deke.commit_frames` 60; `game.stick.deke.offset_m` 2; `game.stick.foul_grace_frames` 30; `game.teams` 3 v 3 |
| Pinball (parked) | Bumpers everywhere. The puck never slows. | `game.look.tier` "l3_neon"; `game.puck.drag` 0; `game.puck.ice_restitution` 0.8; `game.puck.max_speed` 50; `game.rink.board_restitution` 1; `game.rink.ice_friction` 0.005; `game.rink.obstacles` (a list of 8); `game.rules.penalties` true; `game.shot.speed` 30; `game.teams` 3 v 3 |
<!-- /generated:modes -->

## 5. Words to keys: thirdjam's own sentence-to-cartridge cache

`native/content/Designer/cached-cuts.json`: sentences a person typed, the cut thirdjam's designer (claude CLI) made from
hockey.regular, and whether it passed on the first try. The precedent for a model writing cartridges; the shape of an
iteration (a few keys move, nothing else).

<!-- generated:cuts -->
| the person said | thirdjam's cut | keys moved (the tunable `values` and `game` keys) |
|---|---|---|
| "make it faster" | Fast Cut (first_try) | `values.skater_speed` 14.5 |
| "make it slower and easier to follow" | Slow Motion Cut (first_try) | `values.puck_max_speed` 22; `values.shot_speed` 14; `values.skater_speed` 8; `game.rules.hooks` (a list of 1); `game.rules.mode` "timer"; `game.rules.score_to_win` absent; `game.rules.timer_frames` 14400 |
| "a calm version for my kid" | Family Cut (first_try) | `values.ai_red_skill` 0.6; `values.ai_speed_scale` 0.8; `values.puck_max_speed` 22; `values.shot_speed` 14; `values.skater_speed` 8; `game.ai.difficulty` "rookie"; `game.barks.intensity` "quiet" |
| "make it chaotic with pinball boards" | Pinball Cut (repaired) | `values.board_restitution` 0.95; `values.puck_max_speed` 42; `game.rink.board_restitution` 0.95; `game.rink.obstacles` (a list of 4) |
| "twice the rink, half the friction" | Big Glass Cut (first_try) | `values.ice_friction` 0.0075; `game.rink.ice_friction` 0.0075; `game.rink.length_m` 160; `game.rink.width_m` 80 |
| "a tiny cramped rink" | Shoebox Cut (first_try) | `game.rink.corner_radius_m` 3; `game.rink.length_m` 50; `game.rink.width_m` 26 |
| "a wide open rink with room to breathe" | Open Ice Cut (first_try) | `game.rink.length_m` 120; `game.rink.width_m` 60 |
| "ice like glass" | Glass Ice Cut (first_try) | `values.ice_friction` 0.002; `game.rink.ice_friction` 0.002 |
| "sticky slow ice like carpet" | Carpet Cut (first_try) | `game.effects` (a list of 1); `game.rink.zones` (a list of 1) |
| "add power-ups to grab on the ice" | Power-Up Cut (first_try) | `game.pickups` (a list of 2); `game.rules.hooks` (a list of 0) |
| "lots of speed boosts" | Turbo Cut (first_try) | `game.effects` (a list of 0); `game.pickups` (a list of 2) |
| "pickups that make the puck giant" | Giant Puck Cut (first_try) | `game.effects` (a list of 1); `game.pickups` (a list of 1) |
| "a neon party" | Neon Cut (repaired) | `values.board_restitution` 0.6; `values.puck_max_speed` 34; `game.barks.intensity` "loud"; `game.look.tier` "l3_neon"; `game.rink.board_restitution` 0.6; `game.rink.zones` (a list of 1); `game.rules.hooks` (a list of 1) |
| "a bright daytime game" | Matinee Cut (first_try) | `game.look.tier` "l1_day" |
| "make it easier to score" | Easy Scoring Cut (first_try) | `values.ai_red_skill` 0.6; `values.shot_speed` 24; `game.rink.goal_width_m` 6 |
| "make the bots really hard" | All-Star Cut (first_try) | `game.ai.difficulty` "all_star" |
| "rookie opponents so I can learn" | Rookie Cut (first_try) | `game.ai.difficulty` "rookie" |
| "a one minute sprint" | One Minute Cut (first_try) | `values.skater_speed` 13; `game.rules.mode` "timer"; `game.rules.timer_frames` 3600 |
| "a long match, first to nine" | Marathon Cut (first_try) | `game.rules.hooks` (a list of 1); `game.rules.mode` "timer"; `game.rules.score_to_win` absent; `game.rules.timer_frames` 18000 |
| "sudden death, first goal wins" | Sudden Death Cut (first_try) | `game.rules.score_to_win` 1; `game.rules.variants.sudden_death` true |
| "pillars in the way" | Pillar Cut (first_try) | `game.rink.obstacles` (a list of 4) |
| "a maze of boxes on the ice" | Maze Cut (first_try) | `game.rink.obstacles` (a list of 11); `game.rules.hooks` (a list of 1); `game.rules.mode` "timer"; `game.rules.score_to_win` absent; `game.rules.timer_frames` 14400 |
| "rocket shots" | Rocket Cut (first_try) | `values.puck_max_speed` 40; `values.shot_speed` 32 |
| "bigger goals and more scoring" | Big Net Cut (first_try) | `values.shot_speed` 22; `game.rink.goal_width_m` 5.5 |
| "tiny goals for a defensive battle" | Lockdown Cut (first_try) | `game.rink.goal_width_m` 2.5 |
| "a cozy winter pond game" | Pond Cut (repaired) | `values.ai_red_skill` 0.4; `values.ai_speed_scale` 0.7; `values.board_restitution` 0.6; `values.goal_pause_frames` 240; `values.ice_friction` 0.005; `values.puck_max_speed` 22; `values.shot_speed` 14; `values.skater_speed` 8; `values.skater_turn_rate` 3.5; `game.ai.difficulty` "rookie"; `game.barks.intensity` "quiet"; `game.rink.board_restitution` 0.6; `game.rink.ice_friction` 0.005; `game.rink.zones` (a list of 1) |
| "a sunset championship final" | Final Cut (repaired) | `game.rules.score_to_win` 5 |
| "a retro arcade look" | Arcade Cut (repaired) | `game.look.tier` "l3_neon" |
| "boards that bounce like rubber" | Rubber Boards Cut (first_try) | `values.board_restitution` 0.9; `game.rink.board_restitution` 0.9 |
| "a spooky midnight match" | Midnight Cut (repaired) | nothing |
| "carry it in, no shots from far out" | Carry It In Cut (first_try) | `game.rink.zones` (a list of 2) |
| "help whoever is losing" | Comeback Cut (first_try) | `game.rules.hooks` (a list of 1) |
| "a two metre shield in front of each net and a four minute clock" | Shield Cut (first_try) | `game.rink.obstacles` (a list of 2); `game.rules.mode` "timer"; `game.rules.timer_frames` 14400 |
| "one-timers that always find the net" | One-Timer Night (first_try) | `game.shot.one_timer.cone_bonus_deg` 20; `game.shot.one_timer.window_frames` 30 |
| "give breakaways a burst" | Breakaway Cut (first_try) | `game.skater.breakaway.frames` 120; `game.skater.breakaway.speed_bonus` 0.4 |
| "let me deke the last man" | Deke Cut (first_try) | `game.stick.deke.commit_frames` 30; `game.stick.deke.offset_m` 1.4 |
<!-- /generated:cuts -->

## 6. What a cartridge cannot do (code, not keys)

- **A new verb** (a kick, a dive, a throw): the buttons are thirdjam's (shoot, pass, check, poke, lift, deke, spin, sprint,
  brake, ability). A new one is C++ in the core, i.e. a patch in `native/patches-thirdlife` and a rebuild.
- **A new rule the schema has no key for** (the puck cannot be carried over the goal line, offside): a switch in a thirdlife
  patch plus a key in the `.rules.json` sidecar (how `net_carry_wall` was made). `rules.offside` is fixed false.
- **A ball sport** (football, basketball, a bouncing ball): the core is a stick sport on ice; a ball, a kick or a bounce off the
  floor is new simulation, not a cartridge.
- **A new figure or body** (robots, animals): the skaters are thirdjam's skater rig (`TLRigSkater`); a new figure is rig work.
- **A different arena**: the hall is a baked 90 x 45 barn (`rink_arena.gd`); only the ice surfaces follow the cartridge's
  rink size. A very large or small rink plays right but sits in the same hall.
- **New words, colours and sounds of a game** (title, team names, commentary, HUD colours): those are the skin (the rink-game
  base, lane E1), not the cartridge.
- **More than the limits**: 12 obstacles, 24 tunables, 24 rules, the ranges in `limits.json`; a file of at most 24,000 bytes.

## 7. Every key (generated)

<!-- generated:keys -->
The envelope (cartridge.schema.json):

| key | type | what it is |
|---|---|---|
| `schema` |  |  |
| `id` |  |  |
| `title` | string |  |
| `seed` | integer | The one source of randomness for a run. 32-bit unsigned. |
| `theme` | object |  |
| `tunables` | array | The knobs the Designer may turn. Declared by the host; the Designer never edits this list. |
| `values` | object | Chosen value per tunable key. A key left out means the tunable's default applies. |
| `rules` | array |  |
| `entities` | array |  |
| `ai` | array |  |

The game (game.schema.json), 260 keys; `[]` = each element of a list; "regular" = hockey.regular's value (empty: absent, the loader's default applies):

| key | range | thirdjam's meaning | regular |
|---|---|---|---|
| `game.rink.length_m` | number 40..160 | Rink length along x in metres (the nets are at the two ends). | 90 |
| `game.rink.width_m` | number 20..80 | Rink width along z in metres. | 45 |
| `game.rink.corner_radius_m` | number 0..15 | Radius of the rounded corners in metres; at most half the width. | 3.75 |
| `game.rink.board_restitution` | number 0..1 | How much speed the boards give back: 0 dead, 1 perfect bounce. | 0.4 |
| `game.rink.ice_friction` | number 0..0.1 | Glide friction coefficient of the ice; 0.015 is real ice, 0 never slows down. | 0.015 |
| `game.rink.goal_width_m` | number 2..10 | Width of each net opening in metres. | 4 |
| `game.rink.goal_height_m` | number 0.3..1.5 | Height of each net opening in metres (crossbar). 0.61 is the half-height net of a game without goalies (R-0033); 1.22 is a real net. A lifted puck over it is no goal. |  |
| `game.rink.obstacles` | list (max 12) | Static obstacles standing on the ice. |  |
| `game.rink.obstacles[].kind` | box \\| pillar \\| bumper \\| goal_shield | box is a square block, pillar is a round post, bumper is a round post that throws the puck back faster than it came (restitution 1.6), goal_shield is a thin wall size metres wide standing where it is placed (put it in front of a net) |  |
| `game.rink.obstacles[].x` | number -80..80 | Centre along the rink length in metres, 0 is the middle. |  |
| `game.rink.obstacles[].z` | number -40..40 | Centre across the rink in metres, 0 is the middle. |  |
| `game.rink.obstacles[].size` | number 0.5..10 | Side of the box or diameter of the pillar in metres. |  |
| `game.rink.zones` | list (max 8) | Painted areas of the ice that change play inside them (C-0005). Leave the key out for none. The centre must be inside the rink. |  |
| `game.rink.zones[].id` | see cartridge.schema.json#/$defs/kebab_id |  |  |
| `game.rink.zones[].shape` | rect \\| circle | rect needs w and d, circle needs r |  |
| `game.rink.zones[].x` | number -80..80 | Centre along the rink length in metres, 0 is the middle. |  |
| `game.rink.zones[].z` | number -40..40 | Centre across the rink in metres, 0 is the middle. |  |
| `game.rink.zones[].w` | number 1..160 | Width of a rect zone along the rink length, in metres. |  |
| `game.rink.zones[].d` | number 1..80 | Depth of a rect zone across the rink, in metres. |  |
| `game.rink.zones[].r` | number 0.5..40 | Radius of a circle zone in metres. |  |
| `game.rink.zones[].kind` | slow_ice \\| fast_ice \\| bumper \\| no_shoot \\| boost_only | slow_ice slows skaters and the puck inside, fast_ice speeds them up, bumper throws the puck back from its edge, no_shoot blocks shots taken inside, boost_only is where pickups may spawn |  |
| `game.rink.zones[].strength` | number 0..1 | How strong the zone is: 0 does nothing, 1 is the full effect (slow_ice at 1 halves speed, fast_ice at 1 adds half). Absent = 0.5. |  |
| `game.rink.zones[].visible` | boolean | Whether the zone is painted on the ice. Absent = true. |  |
| `game.skater.speed` | number 3..16 | Top skating speed in metres per second. | 11 |
| `game.skater.accel` | number 4..40 | Acceleration in metres per second squared. | 12 |
| `game.skater.turn_rate` | number 1..12 | Turn speed in radians per second. | 5 |
| `game.skater.lateral_grip` | number 0.5..12 | How quickly sideways sliding is killed; low slides more. | 3 |
| `game.skater.mass` | number 40..160 | Skater mass in kilograms; matters for checks. | 80 |
| `game.skater.glide_drag` | number 0..1 | Slowdown while gliding with no input, metres per second squared. | 0.147 |
| `game.skater.brake_decel` | number 1..30 | Slowdown while braking, metres per second squared. | 6 |
| `game.skater.check_enabled` | boolean | Whether the check button works (raw play). | true |
| `game.skater.check_speed_min` | number 1..12 | Closing speed in metres per second above which a check knocks the target down. |  |
| `game.skater.knockdown_frames` | integer 15..300 | How long a knocked-down skater stays down, in physics frames. |  |
| `game.skater.visual` | toy \\| humanoid_b1 \\| generated_b2 \\| toy_skeletal | Which skater figure is drawn: humanoid_b1 (default since R-0030: device B's rebuilt scripted figure, the bake-off winner), toy_skeletal (the Blender toy figure as a skeletal mesh, lane A26), toy (the code-built figure), humanoid_b1 or generated_b2. Gameplay is identical. The Designer may not change it. |  |
| `game.skater.pass_speed` | number 5..30 | Puck speed of a pass (E / X) in metres per second; a pass is a lead pass to the best teammate. |  |
| `game.skater.pass_lead_frames` | integer 0..60 | How far ahead of the receiver a pass is aimed, in physics frames of the receiver's motion. |  |
| `game.skater.carry_speed_mult` | number 0.6..1 | Lane A82 (R-0041 point 6): the puck carrier's top speed and acceleration as a fraction of a free skater's, bots and the human alike; the carrier's sprint is skater.sprint.carry_bonus (lane A93). Leave the key out for 0.92; 1 = the carrier skates as freely as before. |  |
| `game.skater.charge_dies_on_loss` | boolean | Lane A203 (track K1, the Director's ruling on lane A199's ASK): the charge dies with the puck. true = a skater who stops being the carrier (somebody else touched the puck he carried) loses his held shot's and pass's charges, and a button held then charges nothing until it is let go and pressed again, so a puck stripped but still in his reach is not shot or passed by the release of a press made before the strip; bots and the human alike. Leave the key out for true (the Director, 14 Nov 17:01); false = the neutral value (the game before the lane: the release fires whenever the puck is in reach). |  |
| `game.skater.free_speed_mult` | number 1..1.5 | Lane A185 (R-0064 point 2): a skater without the puck, bots and the human alike, has this much more top speed and acceleration (it reaches the higher top in the same time), in a glide and in a sprint; the puck carrier skates as without it, so it is that much slower against everyone. Leave the key out for 1.15; 1 = the neutral value (the game before the lane). |  |
| `game.skater.reverse_brake_decel` | number 0..40 | Lane A93 (R-0045 law 3): braking by reversing. Move input against the velocity (more than 120 degrees from it: W then S) stops the skater at this many metres per second squared until it is still; then the input accelerates the other way. Leave the key out for 26 (lane A121: 8 m/s to still in 19 frames, 11 m/s in 26; 20 before, the neutral value of that lane); 0 = off (only the brake button brakes, at brake_decel). |  |
| `game.skater.burst.frames` | integer 0..60 | How long the burst lasts after a stop or a cut, in physics frames; 0 turns the burst off. |  |
| `game.skater.burst.accel_mult` | number 1..3 | Acceleration multiplier while the burst runs; 1 = no burst. |  |
| `game.skater.burst.own_stop` | boolean | Lane A121 (track F2; docs/VISION.md law 3): the first step is earned. true or absent = being slower than 2 m/s arms the burst only after a stop of the skater's own (it braked on the way down, by reversing or with the brake button); a skater that merely stands (a waiting defender, the faceoff, a skater getting up) starts at the normal acceleration. A sharp cut arms the burst under either value. false = the neutral value (the game before the lane): any skater slower than 2 m/s has the burst. |  |
| `game.skater.burst.rest_frames` | integer 0..120 | Lane A128 (track F2, evolution 3): the standing start. A skater that has been slower than 1 m/s for this many physics frames in a row (after a faceoff, after getting up, after a full stop) and is not pushing has earned its first step: its burst is armed while it stands and runs burst.frames from its first push (a gentle push spends it as a hard one does). A charge already under way never has it. Leave the key out for 6; 0 = the neutral value (the game before the lane: only a stop or a cut of the skater's own arms the burst). |  |
| `game.skater.burst.rest_kept_mps` | number 0..8 | Lane A147 (track F2, evolution 4): the first step a skater earned by standing is not lost to what is not its own doing. While it does not push and is slower than this speed (m/s), a rested skater keeps its rest and its armed burst (a bump or a shove that moves it); a skater lying on the ice or held by a stumble counts its rest whatever it slides at, so it gets up with its first step; and turning on the spot is not the push-off (the burst begins with the first frame of thrust). Leave the key out for 3; 0 = the neutral value (lane A128's rule: the rest is lost at 1 m/s and a pivot spends the burst). |  |
| `game.skater.breakaway.speed_bonus` | number 0..1 | Fraction added to top speed and acceleration during the burst; 0 turns the burst off. Leave the key out for 0.3 (lane A194: 0.92 x 1.3 = 1.196 of the base, over a free skater's 1.15; 0.2 = the value before that lane). |  |
| `game.skater.breakaway.frames` | integer 0..300 | How long the burst lasts, in physics frames. |  |
| `game.skater.sprint.bonus` | number 0..1 | Fraction added to top speed and acceleration while sprinting; 0 turns the sprint off. |  |
| `game.skater.sprint.drain_frames` | integer 30..1800 | Physics frames of sprint from a full stamina bar to empty. |  |
| `game.skater.sprint.refill_frames` | integer 30..3600 | Physics frames at rest from empty to full. |  |
| `game.skater.sprint.carry_bonus` | number 0..1 | Lane A93 (R-0045 law 4): the fraction the puck carrier's sprint adds on top of carry_speed_mult (0.08: 0.92 x 1.08 of a free skater's speed); the carrier's bar drains as anyone's. The sim keeps it under a free skater's sprint (carry_speed_mult x (1 + carry_bonus) is capped at 0.97 x (1 + bonus)), so a sprinting defender always catches a sprinting carrier. 0 = the carrier cannot sprint. |  |
| `game.skater.goalie.reach_m` | number 0..3 | How far from the crease skater a low shot is saved, in metres; 0 turns the save by height off (the body and the blade still stop pucks). |  |
| `game.skater.goalie.block_height_m` | number 0..2 | A shot at or above this height passes the crease skater, in metres. |  |
| `game.skater.goalie.read_mps` | number 0..10 | Lane A207 (track P1): the crease skater reads a long shot: past a quarter second of the shot's flight his save reach and his block height grow by this many metres a second. Default 2.5; 0 = reach_m whatever the flight (the game before). |  |
| `game.skater.goalie.read_max_m` | number 0..3 | Lane A207: the most the read adds to reach_m and to block_height_m, in metres. Default 1.0. |  |
| `game.skater.spin.frames` | integer 0..120 | Frames of the full turn; 0 turns the spin off. |  |
| `game.skater.spin.cooldown_frames` | integer 0..600 | Frames after a spin before the next one. |  |
| `game.skater.spin.speed_mult` | number 0.2..1 | Top speed while spinning, as a fraction of the skater's. |  |
| `game.skater.spin.stamina_cost` | number 0..1 | Share of the sprint bar a spin takes. |  |
| `game.skater.spin.exposed_frames` | integer 0..120 | Lane A128 (track F2, evolution 3): the price of the spin. For the last this many physics frames of a spin the body has come round and is no longer between: neither the body nor a sweep shields the carried puck from a stick, so a poke or a lift in reach takes it (a puck just won keeps its take grace). A spin begun too early ends in front of the defender. Leave the key out for 5; 0 = the neutral value (the game before the lane: the whole spin shields). |  |
| `game.stick.reach_m` | number 0.6..1.6 | How far the blade reaches from the skater's edge at full aim, in metres; the carried puck sits at the blade (lane A51, R-0034). |  |
| `game.stick.carry_reach_mult` | number 0.5..1 | Lane A93 (R-0045 law 4): the puck's distance by pace. A carrier that is not sprinting holds its blade, and the puck on it, at this fraction of the full distance from its body (0.75: 1.2 m of 1.6 m at full aim); a sprinting carrier's puck rides at the full distance, where a stick takes it more easily. Leave the key out for 0.75; 1 = always at the full distance. |  |
| `game.stick.body_shield` | boolean | Lane A102 (track F2, docs/VISION.md law 3): puck protection with the body, no button. While the carrier's body is between a defender's stick and the puck (the defender within 2 m, the puck on the far side of the carrier's body, the carrier turned more than 60 degrees away from the defender), that defender's poke or stick lift does not take the puck; a carrier that faces the defender shields nothing, and a body check is never shielded. true or absent = on; false = the neutral value (the game before the lane). |  |
| `game.stick.passive_take` | boolean | Lane A102 (R-0048): false or absent = a carried puck is not taken by an unpressed blade or by a body's touch: it leaves its carrier only by a shot, a pass, a poke, a lift, a check or stumble that loosens it, or the carrier's own release. true = the neutral value (the game before the lane): an aimed opposing blade within 0.6 m deflects a carried puck moving faster than 6 m/s and any body's touch takes it. A teammate never takes a carried puck by touch under either value. |  |
| `game.stick.take_grace_frames` | integer 0..120 | Lane A121 (track F2; R-0049 point 2): the take grace. A skater that has just won the puck (by a poke, a lift, a loose puck, a pass or the draw: the puck came to it from somebody else) cannot be poked or stick-lifted for this many physics frames; a body check still loosens the puck, and a poke that runs out on it costs the poker no stumble. Leave the key out for 30 (half a second); 0 = off, the neutral value (the game before the lane). |  |
| `game.stick.poke_assist_deg` | number 0..180 | Lane A152 (track F2; R-0059 point 4): the poke reaches. Inside the open poke window of the skater a person steers, a puck an opponent carries is taken when it is within the stick's full reach of the poker's body (as far as a perfectly aimed blade takes from, never further) and within this many degrees of the direction the blade is aimed in; the body between, the sweep's shield, the spin and the take grace refuse it as before. Bots keep the blade rule (the blade itself within 0.35 m of the puck). Leave the key out for the default in DEFAULTS.md; 0 = off, the neutral value (the game before the lane: the blade rule for everybody). |  |
| `game.stick.miss_recovery_frames` | integer 0..90 | Lane A152 (track F2; R-0059 point 4): a miss costs a recovery, not a fall. A poke of the skater a person steers whose window runs out next to an opposing carrier locks its stick for this many physics frames: no poke, no stick lift and no body check, while it skates and steers as it likes. Leave the key out for the default in DEFAULTS.md; 0 = the neutral value (the game before the lane): the miss costs stumble_frames without control instead. A bot's miss stays the stumble (the carrier's sweep and stop earn it); a poke the take grace refused costs neither; with stumble_frames 0 a miss costs nothing at all. |  |
| `game.stick.stop_grace_frames` | integer 0..120 | Lane A163 (track F2 evolution 6): the stop tucks the puck. On the frame the reverse brake of a carrier a person steers begins (input against a velocity of 6 m/s or more), its puck gets the take grace for this many physics frames: no poke and no stick lift takes it; a body check still loosens it, and a sprinting carrier has to stop first. Needs take_grace_frames above 0. Leave the key out for the default in DEFAULTS.md; 0 = off, the neutral value (the game before the lane). |  |
| `game.stick.poke_window_frames` | integer 2..30 | Frames after a poke press during which the blade reaching the puck takes it cleanly. |  |
| `game.stick.lift_range_m` | number 0.5..2.5 | Distance beyond the two bodies within which a stick lift strips the carrier, in metres. |  |
| `game.stick.lift_cone_deg` | number 10..180 | The cone of the stick lift and of the cross-check's shove, in degrees off the attacker's facing: a carrier farther off than this is neither lifted nor shoved (the swing is a miss), bots and the human alike (B-to-A-0037, lane A95). 180 = no cone (before A95). |  |
| `game.stick.stumble_frames` | integer 0..90 | Frames of lost control after a poke timed wrong next to a carrier; 0 removes the penalty. |  |
| `game.stick.mouse_sensitivity` | number 0.1..5 | Mouse aim scale: 1 means 100 pixels move the blade one full reach. |  |
| `game.stick.foul_grace_frames` | integer 0..120 | A check on a skater that carried the puck within this many frames is not a foul for hitting a player without the puck. |  |
| `game.stick.reception_m` | number 0..3 | Lane A46: a teammate's pass that reaches the body within this radius (metres) at 6-14 m/s is seated on the blade with a 4-frame settle; faster passes bounce off the body unless the blade meets them. 0 = only the blade receives. |  |
| `game.stick.faceoff.centre_gap_m` | number 0..6 | Both centres stand at the dot this far apart, facing, each on his own side (default 1.8); 0 = where the formation puts them. |  |
| `game.stick.faceoff.winner_shield_frames` | integer 0..300 | The skater who wins the draw cannot be felled for this many physics frames: a hit that would fell him is a bump (default 90); 0 = off. |  |
| `game.stick.faceoff.no_hit_frames` | integer 0..300 | For this many physics frames after the drop nobody's body check or stick lift is pressed inside no_hit_m of the dot: the press is refused (default 45); 0 = off. |  |
| `game.stick.faceoff.no_hit_m` | number 0..30 | The radius around the dot of no_hit_frames, in metres (default 6). |  |
| `game.stick.pickup.arc_m` | number 0..2 | The arc's radius from the skater's centre, in metres (default 1.5; the carry reach is 1.65); 0 = no arc: only a puck over 6 m/s at the blade's 0.6 m disc, as before. |  |
| `game.stick.pickup.arc_deg` | number 0..180 | The arc's half-angle either side of the blade's direction and of the body's facing, in degrees (default 60); the blade's own 0.6 m disc always counts. |  |
| `game.stick.pickup.pass_arc_m` | number 0..2 | Lane A207 (wave 2c): an opponent takes a pass in flight only with his blade: within this many metres of the blade point (default 1.0), never in its first 6 frames; his body still blocks it. 0 = the loose puck's arc against a pass too (the game before). |  |
| `game.stick.pickup.pass_arc_deg` | number 0..180 | Lane A207 (wave 2c): ... and inside this many degrees of his stick's line from his body (default 60). |  |
| `game.stick.pickup.body` | boolean | true or absent = the body stops a loose puck and it is his (default); false = the body pushes it as before (the neutral value). |  |
| `game.stick.pickup.block_carried` | boolean | With body: true or absent = another skater's carried puck is pushed out of a body it meets (no pass-through; its carrier keeps it while it stays in his reach, R-0048); false = it passes through other bodies as before. |  |
| `game.stick.pickup.body_catch_mps` | number 0..80 | With body: the body seats a loose puck (it stops at him and is his) only when it meets him slower than this, relative and into the body, in metres a second; faster it bounces off him as a loose rebound. The stick arc is not limited by it. |  |
| `game.stick.pickup.ring_m` | number 0..2 | Lane A218 (R-0069 point 2): for the human, a loose puck that comes within this many metres of his centre (the ring drawn under him, default 1.1) is his on that frame, whatever his stick points at, at any speed he skates, while he holds a button; his own pass or shot once it no longer leaves him (slower than 6 m/s against him, closing on him, or 20 frames after it left). Not a puck riding with a carrier, over the blades, in the draw, another's pass in flight, or a hard shot (the sting). 0 = the neutral value (the game before). |  |
| `game.stick.pickup.sting_mps` | number 0..80 | An opposing puck faster than this against the skater (blade or body; a teammate's pass on the blade is always caught) rings off him as a loose rebound, in metres a second (default 18). |  |
| `game.stick.deke.offset_m` | number 0..2 | How far the puck moves to the side on a deke, in metres; 0 turns the deke off. |  |
| `game.stick.deke.commit_frames` | integer 0..60 | Frames the crease back stays committed to the puck's old side after a deke. |  |
| `game.stick.sweep.min_deg_per_frame` | number 1..45 | How many degrees the aim must turn in one frame to count as a sweep. |  |
| `game.stick.sweep.shield_frames` | integer 0..60 | Frames after a sweep in which a poke or a lift misses, from either side of the body; 0 turns the shield off. |  |
| `game.stick.sweep.bot_react_frames` | integer 0..30 | Frames late a defending bot reads the puck on the carrier (its poke aims there); leave it out for the difficulty profile: rookie 14, pro 8, all_star 5. |  |
| `game.stick.sweep.sprint_shield_mult` | number 0..1 | Lane A93 (R-0045 law 4): a sprinting carrier's sweep shield lasts this fraction of shield_frames (0.5: 6 of 12 frames); 1 = the sprint does not weaken the shield, 0 = no shield while sprinting. |  |
| `game.puck.net.own_wall` | boolean | true or absent = nobody scores on himself with his own play: a puck carried, or last played (carried, then shot, passed or cleared), by the defending side does not enter that side's net (the mouth is a wall for it); an opponent's puck that touches a defender on the way still scores. |  |
| `game.puck.net.mouth_only` | boolean | true or absent = a goal is a puck that crossed the goal mouth (between the posts, from the front) on its path; a puck moved into the net's box any other way is put back where it was. |  |
| `game.puck.radius_m` | number 0.06..0.4 | Puck radius in metres; large pucks made the player lose, readability comes from colour. | 0.12 |
| `game.puck.max_speed` | number 10..60 | Puck speed cap in metres per second. | 30 |
| `game.puck.drag` | number 0..2 | Puck slowdown per second, 0 means none. | 0.5 |
| `game.puck.colour_hex` | string text (pattern) | Puck colour; a colour must be written as #RRGGBB, six hexadecimal digits | "#111111" |
| `game.puck.carry_assist` | number 0..1 | How strongly a carried puck is pulled to the stick while the skater turns gently; 0 is the raw bumping puck, 1 glues it. |  |
| `game.puck.count` | integer 1..3 | Number of pucks on the ice. |  |
| `game.puck.gravity_mps2` | number 0..30 | R-0035 (lane A52): gravity on a lifted puck in metres per second squared; 9.81 is Earth, 0 keeps a lifted puck in the air. |  |
| `game.puck.ice_restitution` | number 0..1 | R-0035 (lane A52): how much of its vertical speed a puck keeps when it lands on the ice; a hop under 2 cm dies. |  |
| `game.shot.reach_m` | number 0.5..4 | How far from the skater the puck can be hit, in metres. | 1.5 |
| `game.shot.speed` | number 5..40 | Puck speed after a shot in metres per second. | 18 |
| `game.shot.cooldown_frames` | integer 6..120 | Frames before the next shot is possible. | 24 |
| `game.shot.aim_cone_deg` | number 1..45 | Half-angle of the auto-aim cone in degrees; leave the key out for no aim help. | 8 |
| `game.shot.charge_frames_max` | integer 0..120 | Holding shoot this many frames gives the full charge bonus; 0 turns charging off. |  |
| `game.shot.charge_speed_bonus` | number 0..20 | Extra puck speed in metres per second at full charge. |  |
| `game.shot.tap_frames` | integer 0..30 | R-0044 (lane A91): a hold of shoot of this many frames or fewer is a tap: charge 0, no speed bonus, the tap's height (lift.tap_m: on the ice by default). A human's click is 2 to 4 frames long. Default 4; 0 makes every held frame charge. |  |
| `game.shot.speed_scale` | number 0.25..4 | Lane A207 (track P1): multiplies the shot's speed (speed and the charge bonus) and the puck's speed cap (puck.max_speed) alike. Default 2 (a tap 36, a full charge 52 m/s on the regular cut); 1 = the game before the lane. |  |
| `game.shot.fade_m` | number 0..200 | Lane A207 (wave 2b): the shot's added speed (what speed_scale put on top) fades with the distance the puck travels, e^(-x / fade_m): the full 2x for the first 8 m, then about 1.5x by 12 m and 1.0x by 30 m at 6. Default 6; 0 = no fade. |  |
| `game.shot.deflect` | boolean | Whether a shot that hits a skater near its stick deflects (70 percent of its speed) instead of stopping dead. |  |
| `game.shot.one_timer.window_frames` | integer 0..60 | Frames after a received pass during which a shot is a one-timer; 0 turns one-timers off. |  |
| `game.shot.one_timer.cone_bonus_deg` | number 0..30 | Extra half-angle of aim help, in degrees, added to aim_cone_deg for a one-timer. |  |
| `game.shot.lift.tap_m` | number 0..0.5 | Height over the goal line of a tap shot, in metres. Default 0 (R-0042): a charge-0 shot flies flat on the ice the whole way, so a stick between the shooter and the net can deflect it. |  |
| `game.shot.lift.half_m` | number 0..1.5 | Height over the goal line of a shot held half_frames, in metres. |  |
| `game.shot.lift.full_m` | number 0..2 | Height over the goal line of a full charge, in metres. Default 0.47 (R-0044, measured): the top shelf under the 0.61 bar, whose ring starts at 0.51 and catches a long falling shot from 0.48 up. |  |
| `game.shot.lift.half_frames` | integer 0..120 | Frames of hold that reach half_m; 0 or at least charge_frames_max makes the lift linear from tap_m to full_m. |  |
| `game.pass.saucer.half_frames` | integer 0..60 | Frames the pass must be held, with the puck in reach, for the saucer; a shorter hold is a flat pass. 0 = off. |  |
| `game.pass.saucer.lift_m` | number 0..1 | The saucer's apex height over the ice, in metres (a blade is cleared from 0.2 m); 0 = off. |  |
| `game.pass.power.full_frames` | integer 0..120 | Frames of hold for the full pass. Default 30 (half a second); 0 = off. |  |
| `game.pass.power.reach_share` | number 0.05..1 | The share of the rink's length a full pass covers. Default 0.3333 (30 m on the 90 m rink). |  |
| `game.pass.power.arrive_mps` | number 1..20 | The speed a full pass still has at that distance, and the speed a bot's pass arrives at. Default 8 m/s (the sim's substeps lose a little against the closed form: 8 keeps a full pass over 6 m/s at 30 m). |  |
| `game.pass.aim.cone_deg` | number 0..90 | The half-angle in degrees. Default 25; 0 = the sim's best open mate whatever the stick points at (the game before the lane). |  |
| `game.pass.catch_m` | number 0..3 | Lane A207 (track P1): a pass in flight is seated on a team-mate's blade passing within this many metres of it at more than 1 m/s. Default 1.2; 0 = the game before the lane (the 0.6 m blade disc over 6 m/s). |  |
| `game.pass.clear_own_body` | boolean | Lane A207 (track P1): the passer's or shooter's own body does not stop the puck he just released while his cooldown runs. Default true; false = the game before the lane. |  |
| `game.contact.momentum` | boolean | false = the neutral value: the check rule before lane A92 (a pressed check lands when the checker's own speed along the contact passes skater.check_speed_min and always knocks down for skater.knockdown_frames; the cross-check is the lift only); true or absent = contact by momentum (impulse against stability, three outcomes). |  |
| `game.contact.carrier_can_hit` | boolean | true = the neutral value: a skater carrying the puck may body-check as before lane A92; false or absent = the carrier's check press is refused (read-out bCheckRefused). |  |
| `game.contact.lunge_mps` | number 0..6 | Speed a pressed body check adds to the closing speed along the contact line, in m/s; the checker gives half of it away. |  |
| `game.contact.thrust_mps` | number 0..10 | Speed a cross-check (the lift at an opposing carrier in range) adds to the closing speed, in m/s; 0 = the cross-check has no body hit (the lift only). |  |
| `game.contact.cross_reach_m` | number 0..1.5 | The gap between the two bodies, in metres, inside which the lift at a carrier is a cross-check (the stick's shaft at arm's length: the thrust lands); farther out, up to stick.lift_range_m, it is the stick lift only. stick.lift_range_m or more = every lift in range shoves. |  |
| `game.contact.stability_mps` | number 1..30 | The stability of a skater of the reference mass that moves slowly, sees the hit and is not braced, as the closing speed (m/s) of an equal-mass hit that puts it down at down_ratio 1. |  |
| `game.contact.stand_speed_mps` | number 0..5 | Under this speed a skater stands braced (stand_brace); above it the stability falls with the speed (speed_stability). |  |
| `game.contact.stand_brace` | number 1..3 | Stability factor of a standing skater against a hit it can see; a cross-check inside its front arc ignores it; 1 = no brace. |  |
| `game.contact.speed_stability` | number 0.3..1 | Stability factor at skater.speed; linear from 1 at stand_speed_mps; 1 = pace costs nothing. |  |
| `game.contact.sprint_stability` | number 0.3..1 | Stability factor while sprinting; 1 = the sprint costs nothing. |  |
| `game.contact.spin_stability` | number 0.3..1 | Stability factor during a spin or with a full shot wind-up; 1 = no cost. |  |
| `game.contact.unseen_stability` | number 0.3..1 | Stability factor against a hit from behind the victim's facing (the push runs along its facing); such a hit also finds a standing skater unbraced; 1 = no cost. |  |
| `game.contact.bump_ratio` | number 0..1 | Impulse over stability under this is a bump: both keep their feet and their control. |  |
| `game.contact.loose_ratio` | number 0..3 | A stumble at this ratio or more knocks the carried puck loose. |  |
| `game.contact.down_ratio` | number 0.2..5 | At this ratio or more the victim goes down; between bump_ratio and it the victim stumbles (half its speed, stagger_frames without control). |  |
| `game.contact.down_full_ratio` | number 1..10 | The ratio at which the knockdown lasts down_frames_max; linear from down_frames_min at down_ratio. |  |
| `game.contact.down_frames_min` | integer 15..300 | Frames down at down_ratio, at skater.knockdown_frames 90 (the frames scale with skater.knockdown_frames / 90). |  |
| `game.contact.down_frames_max` | integer 15..300 | Frames down at down_full_ratio and above, at skater.knockdown_frames 90; never under down_frames_min. |  |
| `game.contact.stagger_frames` | integer 0..60 | Frames a stumbling skater glides without thrust, steering or stick. |  |
| `game.contact.board_bonus` | number 1..2 | The boards are a body: the impulse of a hit that pushes a victim standing within 1.5 m of the boards into them counts this much higher (the full bonus inside 60 degrees of straight in, none along the boards), and the victim's board read-out fires. 1 = the neutral value: no bonus, no read-out. |  |
| `game.contact.release_grace_frames` | integer 0..300 | The release grace (R-0049 point 1): for this many frames after a knockdown ends, a hit on the released skater is a bump at most (no stumble, no knockdown; the attacker pays as for any bump) and the brain starts no check on it. Part of the momentum model (contact.momentum true). 0 = the neutral value: no grace. |  |
| `game.contact.check_reach_m` | number 0..3 | The check finds its man: while a human skater's check window is open (12 frames) its velocity is turned onto the collision course with the nearest standing opponent whose body is within this many metres of its own and inside 60 degrees of where it is going or facing. The speed is kept and none is added (the hit's strength stays the contact law's), the position is untouched; a bot aims its own check. Part of the momentum model (contact.momentum true). 0 = the neutral value: the press goes where the skater was going. |  |
| `game.contact.downed_radius_m` | number 0..2 | Nobody stands in a man who is down (B-to-A-0041 point 2): with this above 0 a downed skater's body has this radius for every skater on its feet (roots kept 0.4 m + this apart, never less than the two 0.4 m body circles): the skater on its feet alone gives way (eased out at 6 m/s at most), the speed it had into the body turns along it (it goes round), and the downed skater is neither moved nor given any speed. The puck sees the same body as before; two downed skaters and the hit that fells a skater collide as before. 0 = the neutral value: a downed skater is an ordinary body (others stop 0.8 m from its root, push it along the ice and bounce off it). |  |
| `game.contact.check_cooldown_frames` | integer 0..120 | A check press has a cooldown (R-0060 point 4): for this many frames after a check press that opened a window, the same skater's next check press is dropped (no window, no cue), so a mashed button holds no window open: at the human's 12-frame window a button mashed without pause has one open 12 frames in every this-many. Bots and the human alike (the brain spaces its own presses 30 frames apart). 0 = the neutral value: every press opens a window. |  |
| `game.contact.check_cooldown_restart` | boolean | A mashed button lands nothing: true = a check press inside the cooldown (check_cooldown_frames) starts the cooldown again from that press, so a button pressed faster than the cooldown opens one window and no other until the hand has rested a whole cooldown; a press made after the cooldown never notices. Read only with check_cooldown_frames above 0. false = the neutral value: a dropped press costs nothing more. |  |
| `game.contact.board_slam_frames` | integer 0..120 | The board slam as a play. Earned: a hit that fells its victim while the victim's centre is within 1 m of the boards and the attacker closes on it along the boards' normal at 4 m/s or more (driven into the wall, not along it). Paid: this many frames down on top (at skater.knockdown_frames 90; they scale with it), the victim's board read-out and the board event. 0 = the neutral value: no slam exists. |  |
| `game.contact.take_shield_frames` | integer 0..60 | A hit inside a carry's first frames is capped at a stumble (REVIEW-3 item 2): for this many frames after a skater wins the puck (it comes to it from somebody else; not a placed puck), a hit that would fell it is a stumble: it keeps its feet, loses half its speed, its control for the stumble and the puck; the attacker pays as for any stumble; an armed hip check keeps its rule. Part of the momentum model (contact.momentum true). 0 = the neutral value: the hit lands as the contact law says. |  |
| `game.contact.take_shield_human_side` | boolean | true = the take shield (take_shield_frames) only for skaters of a side that has a human on it; a bot of the other side that wins the puck is felled as before. false = the neutral value: every skater. Read only with take_shield_frames above 0. |  |
| `game.contact.take_shield_stagger_max` | integer 0..90 | The capped hit's stumble scales with the hit: from stagger_frames at down_ratio to this many frames at down_full_ratio (the line the frames down follow), so a bigger hit still costs more. 0 (or not above stagger_frames) = the neutral value: the flat cap, every capped hit is stagger_frames. Read only with take_shield_frames above 0. |  |
| `game.contact.lunge_frames` | integer 0..30 | The lunge as a motion: a check press that opens a window commits the body for this many frames: lunge_step_mps is added along its facing at once, it turns at a quarter of its turn rate and cannot brake by reversing. A lunge that ends in a body ends there; one that runs out on nobody costs twice lunge_step_mps of speed (the miss). Part of the momentum model (contact.momentum true). 0 = the neutral value: a press moves nothing. |  |
| `game.contact.lunge_step_mps` | number 0..4 | The lunge's forward step in m/s, added to the velocity along the facing when a lunge starts (lunge_frames above 0). It is real closing speed in the hit, so the impulse's own lunge_mps is reduced by it while the lunge runs (at lunge_step_mps = lunge_mps a head-on hit is the hit it was). 0 = the neutral value. |  |
| `game.contact.cross_hold` | boolean | The held cross-check (R-0064 points 1 and 5): the cross-check button held 10 frames or more without the puck braces the skater (stick across the body): the first opponent his body meets while braced takes the cross-check by the momentum he brings (closing speed plus thrust_mps, the pressed cross-check's own line; not into a back); then the brace is spent until the button is released. A tap is the pressed cross-check as before. Its prices: no poke, no lift, no pass reception and no sprint while braced, top speed x 0.9 and turning x 0.7, and a braced skater hit by a man closing faster than he skates himself stands at 0.75 of his stability. Part of the momentum model (contact.momentum true). false = the neutral value: the held button does nothing. |  |
| `game.contact.check_windup_frames` | integer 0..12 | The body check's wind-up (R-0064 point 5): a pressed check opens its window this many frames after the press, so the figure's take has a beat the eye catches before the contact; the cooldown and the figure's call stay on the press, a press inside the wind-up is the same press, a skater that loses its feet or gets the puck in it loses the press. 0 = the neutral value: the window opens on the press's frame. |  |
| `game.contact.cross_windup_frames` | integer 0..12 | The cross-check's wind-up (R-0064 point 5): a pressed cross-check (the stick lift's swing: its shove, its strip and its miss) lands this many frames after the press, on the positions of that frame; the swing's cooldown and the figure's call stay on the press. 0 = the neutral value: the swing lands on the press's frame. |  |
| `game.contact.bot_check_windup_frames` | integer 0..12 | The bots' own body-check wind-up (lane A200, track F1, evolution 11): the same rule as check_windup_frames for every skater the game does not seat as a human (both sides' bots; the online guest is a human), so the bots' wind-up can be longer than the human's, whose own press must not feel late. Absent = 8 (ships on: 133 ms, a beat the eye reads). The neutral value is the shared check_windup_frames (set it equal to it). |  |
| `game.contact.bot_cross_windup_frames` | integer 0..12 | The bots' own cross-check wind-up (lane A200, track F1, evolution 11): the same rule as cross_windup_frames for every skater the game does not seat as a human (both sides' bots; the online guest is a human): the pressed cross-check's shove lands this many frames after the press. Absent = 12 (ships on). The neutral value is the shared cross_windup_frames (set it equal to it). |  |
| `game.contact.check_pull_m` | number 0..2 | The hit he aims lands (lane A209, track F1, the night): while a human skater's pressed body check winds up (contact.check_windup_frames), his root is drawn toward the man he pressed at (the nearest opponent on his feet inside 60 degrees of his facing, his going or his stick's aim) so the two bodies meet as the wind-up ends: what his own closing will not cover is spread over the wind-up's frames, at most this many metres in all; a meeting inside his wind-up is the hit. His pressed cross-check's man is drawn to arm's length (half of contact.cross_reach_m) the same way, so its shove reaches from this much farther. His speed is never changed by the pull: the hit's size stays his momentum's (a standing shove is a bump, a full-speed hit a knockdown). Bots aim their own. Part of the momentum model (contact.momentum true). 0 = the neutral value: the press goes where the skater was going. |  |
| `game.contact.cross_any_man` | boolean | The cross-check is a hit on any man in front (lane A209, track F1, the night): a human skater's pressed cross-check shoves the nearest opponent on his feet inside the lift's cone and the stick's reach (stick.lift_range_m) whether or not he has the puck, by the shove's own momentum rule (closing speed plus contact.thrust_mps against his stability: mostly a stumble, a knockdown at speed); a back stays a back. The strip of the puck stays the carrier's. Bots keep the carrier-only shove. false = the neutral value: the shove only on a carrier (or one who carried within stick.foul_grace_frames). |  |
| `game.contact.cross_back_human` | boolean | The human's cross-check takes a carrier's back (lane A215, track F1, the night; the Director's ruling of 15 Nov 02:39): a human skater's pressed cross-check (a tap: the button is up when it lands, so a hold never strips with it) that meets the back of a man who has the puck, or had it within stick.foul_grace_frames, when its wind-up ends or inside contact.cross_live_frames, is a shove: he stumbles, never more, and the puck comes off his blade as a stick lift that works leaves it. Where rules.penalties is on, the from-behind foul is called as for any hit from behind. Bots keep the law: their cross-check from behind is the stick lift. Part of the momentum model (contact.momentum true). Absent = true (ships on). false = the neutral value: a cross-check from behind at a carrier is the stick lift for everyone. |  |
| `game.contact.cross_live_frames` | integer 0..30 | The cross-check's stick stays live (lane A215, track F1, the night): a pressed cross-check whose shove finds nobody inside its reach and cone on the frame its wind-up ends (contact.cross_windup_frames) stays live this many frames more: each frame the man it was aimed at is tried first, then every other opponent nearest first, by the same tests with the stick's reach (stick.lift_range_m) for the shaft's (on his feet, not shielded, inside the cone, not into a back with the puck); the first who passes takes the shove and the miss is declared only when the window closes. Every skater, bots and the human. Part of the momentum model (contact.momentum true). Absent = 10 (ships on). 0 = the neutral value: the shove is tried on that single frame. |  |
| `game.rules.mode` | first_to \\| timer | first_to ends at score_to_win goals, timer ends when timer_frames run out | "first_to" |
| `game.rules.score_to_win` | integer 1..9 | Goals needed to win; required when mode is first_to. | 3 |
| `game.rules.timer_frames` | integer 600..28800 | Match length in physics frames (60 per second); required when mode is timer. |  |
| `game.rules.goal_pause_frames` | integer 30..600 | Frames of pause after a goal before the faceoff. | 120 |
| `game.rules.offside` | = false | Offside is not implemented; only false is allowed. | false |
| `game.rules.penalties` | boolean | Hard fouls (R-0013): a check from behind or on a skater without the puck sends the checker to the box for penalty_frames (absent = 300) and gives a free faceoff at the checker's end. Absent = true. | false |
| `game.rules.hooks` | list (max 8) | Rule hooks (C-0005): when a trigger fires and the conditions hold, the actions run in order in the same frame. Evaluated in id order. Leave the key out for none. |  |
| `game.rules.hooks[].id` | see cartridge.schema.json#/$defs/kebab_id |  |  |
| `game.rules.hooks[].when` | on_goal \\| on_period_start \\| on_period_end \\| on_check \\| on_knockdown \\| on_pickup_take \\| on_faceoff \\| on_frame \\| on_score_reached | the trigger; on_frame needs every_frames, on_score_reached needs score.at_least |  |
| `game.rules.hooks[].every_frames` | integer 60..18000 | on_frame only: the hook fires every this many physics frames (60 per second). |  |
| `game.rules.hooks[].after_frame` | integer 0..18000 | The hook is armed from this physics frame on; before it, the trigger is ignored. A hook that ends the match must wait at least until frame 600 (10 seconds). Absent = 0. |  |
| `game.rules.hooks[].team` | scoring \\| conceding \\| any | Which team, relative to the event: scoring is the team the event is about (the scorer, the checker, the taker), conceding is the other one, any is both or neither. The team the actions apply to unless an action names its own. Absent = scoring. |  |
| `game.rules.hooks[].score.at_least` | integer 0..20 | The team's score is at least this. |  |
| `game.rules.hooks[].score.at_most` | integer 0..20 | The team's score is at most this. |  |
| `game.rules.hooks[].score.lead_at_least` | integer 1..20 | The team leads by at least this many goals. |  |
| `game.rules.hooks[].then` | list (min 1, max 4) | The actions, run in order. |  |
| `game.rules.hooks[].then[].do` | add_score \\| set_score_multiplier \\| end_period \\| end_match \\| shrink_rink \\| grow_rink \\| set_param \\| spawn_pickup \\| swap_nets \\| announce \\| apply_modifier | add_score needs value (whole goals), set_score_multiplier needs value (1 to 5), shrink_rink and grow_rink need value (the fraction, 0.05 to 0.5), set_param needs param and value, spawn_pickup needs kind, apply_modifier needs kind and frames, announce needs text |  |
| `game.rules.hooks[].then[].team` | scoring \\| conceding \\| any | Which team, relative to the event: scoring is the team the event is about (the scorer, the checker, the taker), conceding is the other one, any is both or neither. |  |
| `game.rules.hooks[].then[].value` | number -20..20 | The number the action uses; see do. |  |
| `game.rules.hooks[].then[].param` | see cartridge.schema.json#/$defs/snake_key |  |  |
| `game.rules.hooks[].then[].kind` | string text up to 32 | a kind must be lowercase letters and digits separated by single underscores or hyphens, starting with a letter: a pickup kind (speed, precision, heavy_puck, big_puck, reverse_other), an effect id, or a modifier kind |  |
| `game.rules.hooks[].then[].frames` | integer 1..3600 | How long an applied modifier lasts, in physics frames (60 per second). |  |
| `game.rules.hooks[].then[].text` | string text up to 60 | What the scoreboard says (announce). |  |
| `game.rules.variants.sudden_death` | boolean | The next goal after frame 600 (10 seconds) wins the match. |  |
| `game.rules.variants.last_goal_double` | boolean | The goal that wins a first_to match counts double. |  |
| `game.rules.variants.mercy_goals` | integer 2..9 | A lead of this many goals ends the match. |  |
| `game.rules.variants.period_count` | integer 1..3 | How many periods (TAKEs) the match has; a timer match is split evenly, a first_to match ends a period every minute. |  |
| `game.rules.variants.shrink_per_goal` | number 0.02..0.3 | The rink shrinks by this fraction after every goal (0.1 is 10 percent), rebuilt at the next faceoff, never below the smallest rink. |  |
| `game.rules.penalty_frames` | integer 60..600 | Lane A72 (R-0037, ask A8): how long a hard foul sits in the box, in frames (60 per second). Absent = 300 (5 s). Read only when penalties is true. |  |
| `game.teams` | list (min 2, max 2) | Exactly two teams. Exactly one skater across both teams has the role player. |  |
| `game.teams[].id` | see cartridge.schema.json#/$defs/kebab_id |  |  |
| `game.teams[].colour_hex` | string text (pattern) | Jersey colour; a colour must be written as #RRGGBB, six hexadecimal digits |  |
| `game.teams[].skaters` | list (min 2, max 5) |  |  |
| `game.teams[].skaters[].role` | player \\| chaser \\| support \\| back | player is the human, the others are bot roles |  |
| `game.teams[].skaters[].spawn` | array list of number, max 2 | [x, z] in metres from the rink centre; must be inside the rink. |  |
| `game.ai.difficulty` | string rookie \\| pro \\| all_star | How hard the bots play: rookie (easier: slower reactions, wider shots, more room for the human), pro (the default), all_star (harder: faster reactions, sharp shots, they read the puck). Absent = pro. The numbers below, when present, override the level's profile. | "pro" |
| `game.ai.yield_margin_m` | number 0..6 | Blue-side bots yield the puck when the human is this much nearer, in metres. |  |
| `game.ai.yield_radius_m` | number 0..40 | Yield only applies within this distance of the puck, in metres. |  |
| `game.ai.hold_radius_m` | number 0..15 | Opposing non-back bots hold when the human is within this distance of the puck, in metres. |  |
| `game.ai.speed_scale` | number 0.3..1.5 | Bot speed as a fraction of skater.speed. |  |
| `game.ai.red_skill` | number 0..1 | Skill of the opposing bots: 0 clumsy, 1 sharp. |  |
| `game.ai.react_frames` | integer 0..60 | Lane A72 (R-0037, ask A4): the opposing bots' reaction delay in frames (their steering is applied this many frames late; shots stay live; the back reacts at once). Absent = the level's profile (0 at every level today). |  |
| `game.ai.body_check` | number 0..1 | Lane A72 (R-0037, ask A5): the share of the chances an opposing bot closes with a body check: 0 never, 1 every chance. A chance is the level's rule (the opposing carrier within reach, from the front or the side, never from behind) at the closing speed the sim lands a check on (skater.check_speed_min) instead of the level's fixed 5 m/s; at rookie, which never checks, any share above 0 turns that rule on. Absent = the level's rule (rookie never, pro and all_star at 5 m/s). |  |
| `game.ai.sprint` | number 0..1 | Lane A72 (R-0037, ask A2): the share of the time a bot sprints (skater.sprint) while it chases the puck from more than 6 m away without carrying it; a seeded coin per bot and two-second window; the sprint drains and refills the same stamina bar as the human's. Both sides' bots. Absent = 0 (bots never sprint). |  |
| `game.pickups` | list (max 8) | Pickups that spawn on the ice (boost play). kind is a built-in (speed, precision, heavy_puck, big_puck, reverse_other) or the id of an effect in game.effects. Leave the key out for none. |  |
| `game.pickups[].kind` | string text (pattern) | a pickup kind is a built-in (speed, precision, heavy_puck, big_puck, reverse_other) or the kebab-case id of an effect declared in game.effects |  |
| `game.pickups[].spawn_every_frames` | integer 120..7200 | Frames between spawns of this pickup. |  |
| `game.pickups[].duration_frames` | integer 1..3600 | Frames the effect lasts; at least 1. |  |
| `game.pickups[].magnitude` | number 0.1..4 | Strength of the effect: for a built-in kind the multiplier itself (1 is no change; absent = 1.5 speed, 2 precision, 2 heavy_puck, 1.5 big_puck; ignored by reverse_other); for a custom effect it scales the effect's deviation from neutral (absent = 1 = as written). |  |
| `game.pickups[].zone` | string text up to 48 | Spawn only inside this rink.zones zone (absent = anywhere on the ice). |  |
| `game.pickups[].max_on_ice` | integer 1..4 | How many of this pickup may lie on the ice at once (absent = 1); spawning pauses at the cap. |  |
| `game.abilities` | list (max 4) | Lane A84 (R-0041 point 3): the human's special ability, used with F (gamepad D-pad down). A mode entry is held from the first drop and comes back after its cooldown; pickup entries are the pool a boost take grants from (one at random, held until its charges are spent; nothing is granted while one is held). At most one mode entry. Bots never hold one. Leave the key out for none (the default game). |  |
| `game.abilities[].kind` | string shotgun \\| hip_check \\| shield \\| slow_puck | shotgun: the next shot leaves at magnitude x speed and knocks down every skater within 1 m of its path. hip_check: the next check lands from a standstill, knocks down magnitude x as long and pushes 3 m. shield: for duration_frames checks and lifts on the holder fail (the body still bumps). slow_puck: the next pass or shot travels at magnitude x its speed for duration_frames, then wakes up. |  |
| `game.abilities[].trigger` | string mode \\| pickup | mode: held from the drop. pickup: one of the pickup entries is granted when the human takes a boost pickup (needs game.pickups). |  |
| `game.abilities[].charges` | integer 1..9 | Uses before the ability is gone. Absent: unlimited for a mode entry, 1 for a pickup entry. |  |
| `game.abilities[].cooldown_frames` | integer 60..3600 | Frames after a use before the next one. Absent = 1200 (20 s). |  |
| `game.abilities[].duration_frames` | integer 1..600 | shield and slow_puck: how long it lasts. Absent = 360 (shield, 6 s) or 120 (slow_puck, 2 s); ignored by shotgun and hip_check. |  |
| `game.abilities[].magnitude` | number 0.1..4 | The kind's strength. Absent = 1.5 shotgun (shot speed multiplier), 1.5 hip_check (knockdown frames multiplier), 0.5 slow_puck (the puck's speed share); ignored by shield. |  |
| `game.effects` | list (max 12) | Composable effects (C-0005, lane A14): each one is a timed set of stat modifiers applied to a target when its trigger fires. The five built-in pickup kinds (speed, precision, heavy_puck, big_puck, reverse_other) are shipped effect definitions (Game/Content/Designer/builtin-effects.json) and need not be declared here; a pickup may name either a built-in or an effect id from this list. Leave the key out for none. |  |
| `game.effects[].id` | string text up to 48 | Unique kebab-case id (never one of the built-in kinds); pickups and events refer to it. |  |
| `game.effects[].kind` | speed \\| precision \\| heavy_puck \\| big_puck \\| reverse_other \\| custom | Visual family the toy look and the HUD read: one of the five built-in looks, or custom (absent = custom). |  |
| `game.effects[].target` | self \\| own_team \\| other_team \\| everyone \\| puck \\| rink | Who the modifiers apply to, seen from the skater who triggered the effect (self = that skater; for a trigger without a skater, self and own_team mean everyone). |  |
| `game.effects[].duration_frames` | integer 60..7200 | How long the effect lasts in physics frames (1 s to 2 min); a pickup's own duration_frames wins when it spawned the effect. |  |
| `game.effects[].stats` | list (min 1, max 4) | The stat changes, composed as base * product(multiply) + sum(add), clamped to the stat's schema range. |  |
| `game.effects[].stats[].stat` | skater_speed \\| skater_accel \\| skater_turn_rate \\| skater_grip \\| skater_mass \\| shot_speed \\| shot_aim_cone_deg \\| shot_reach \\| check_speed_min \\| knockdown_frames \\| puck_drag \\| puck_max_speed \\| puck_radius \\| ice_friction \\| board_restitution | Which stat (snake_case of EJamStat): a known stat only; the Designer may not invent one. |  |
| `game.effects[].stats[].multiply` | number 0.25..4 | Multiplier; absent = 1 (no change). 0.25 to 4. |  |
| `game.effects[].stats[].add` | number -300..300 | Added after the multipliers, in the stat's own unit; absent = 0. Must stay within the stat's range width (validate.mjs checks per stat). |  |
| `game.effects[].trigger` | pickup \\| goal_for \\| goal_against \\| check_landed \\| check_received \\| period_start \\| zone_enter \\| zone_exit \\| director | What starts the effect: pickup (a pickup that names this id is taken), goal_for / goal_against (seen from the scoring team: self = the scorer), check_landed / check_received, period_start (every TAKE), zone_enter / zone_exit (a rink.zones zone; see zone), director (a Director's Call or Designer cut applied live). |  |
| `game.effects[].zone` | string text up to 48 | zone_enter / zone_exit only: restrict the trigger to this rink.zones id (absent = any zone). Proposed by lane A14, not yet in C-0005. |  |
| `game.effects[].stack` | refresh \\| extend \\| ignore | When the same effect hits the same target while active: refresh restarts the timer (default), extend adds the duration (capped at 7200), ignore keeps the running one. |  |
| `game.effects[].icon` | bolt \\| crosshair \\| weight \\| circle \\| swirl \\| snail \\| shield \\| star \\| flame \\| snowflake \\| magnet \\| anchor | HUD glyph name; absent = the kind's default (bolt, crosshair, weight, circle, swirl; star for custom). |  |
| `game.barks.enabled` | boolean | Whether the skaters talk at all. Absent = true. | true |
| `game.barks.intensity` | quiet \\| normal \\| loud | quiet: rare, no mockery, double cooldowns; normal: the default mix; loud: mostly mockery, half the cooldowns. Absent = normal. | "normal" |
| `game.commentary.enabled` | boolean | Whether the commentator speaks at all. Absent = true. |  |
| `game.commentary.intensity` | quiet \\| normal \\| loud | quiet: only the big calls (priority 3 and up), double cooldowns; normal: the bank's own priorities and cooldowns; loud: half the cooldowns. One line at a time and at most one every 2.5 s in every case. Absent = normal. |  |
| `game.look.tier` | l1_day \\| l2_night \\| l3_neon \\| p3_clay \\| p4_broadcast | light and art tier of the arena; p3_clay is the clay-figure look (B-to-A-0018), p4_broadcast the broadcast look (B-to-A-0025) | "p3_clay" |
| `game.look.trim_emissive` | number 0..100 | Emissive strength of the board trim strips. Absent = the tier's default: l1_day 30, l2_night 30, l3_neon 30, p3_clay 12 (bright clay ice reads 30 as a thin gold line), p4_broadcast 30. The far-net beacon stays at 40. |  |
| `game.look.trim_colour_hex` | string text (pattern) | Colour of the emissive board trim; a colour must be written as #RRGGBB, six hexadecimal digits | "#38BDF8" |
| `game.look.fog_density` | number 0..0.1 | Fog density; 0 is none, L2 ships with none. | 0 |
| `game.look.wet_ice` | boolean | Wet reflective ice (neon tier). | false |
| `game.camera.mode` | third_person \\| arena | third_person follows the player skater; arena is a fixed camera over the rink | "third_person" |
| `game.camera.distance_m` | number 2..20 | Camera distance behind the skater in metres. | 6 |
| `game.camera.height_m` | number 1..15 | Camera height above the ice in metres. | 3.5 |
| `game.camera.look_ahead_m` | number 0..20 | How far ahead of the skater the camera aims, in metres. | 5 |
| `game.camera.lag_frames` | integer 0..30 | Follow lag in physics frames. | 4 |
| `game.camera.fov_deg` | number 40..110 | Horizontal field of view in degrees. | 70 |
| `game.camera.boards_margin_m` | number 0..5 | The chase camera never crosses the boards' inner face minus this margin, in metres, on any side (corner arcs included). |  |
| `game.camera.end_height_m` | number 1..15 | Height in metres the chase camera lifts to when the boards take its whole arm; it rises in proportion to the arm lost and looks along the rink at an end board. Default 3 since lane A49 (was 5). |  |
| `game.camera.far_net_bias` | number 0..1 | How much of the angle to the far net the framing leads by when the skater heads for it (0 = none, 1 = aim at the net). Default 0.2 since lane A49 (was 0.5); the human never leaves the frame's middle third. |  |
| `game.camera.radar` | boolean | Show the mini-rink radar in the HUD. | true |
| `game.meta.pitch` | string text up to 48 | One sentence on the card under the name: what the mode is for, in the player's words. 48 characters keep it to two lines at six cards a row. |  |
| `game.meta.facts` | array list of string, max 3 | Up to three short lines on the card, each a fact that differs from the Regular Cut ("first goal wins"). At six cards a row a line holds about 18 characters at 1080p and 720p; 20 is the hard cap. |  |
<!-- /generated:keys -->
