# Arcade hockey: puck control, speed balance, team AI (research of 21 Nov 2026)

For the owner's ruling of 21 Nov: hockey is "unplayable through inbalancing of puck stickiness, players speed, ability AI to
decide what to do, when to pass and shoot." Sources inline; studios publish little, so much is from interviews, reviews and
community reverse-engineering. **Every number in section 5 is a starting estimate to tune with bots, not a shipped figure.**

## 0. Bottom line
1. **Possession is a state, not a physics result.** Arcade games attach the puck to the carrier in code and use physics only
   for a loose puck; Rocket League adds its own designed impulse on every hit "to make it more predictable and fun"
   ([smish.dev](https://www.smish.dev/rocket_league/ball_simulation_3)).
2. **Looseness comes from what the carrier does, not chance.** Sensible Soccer lets the ball drift on a sharp turn at
   speed: losing it is the player's own readable mistake.
3. **A slow puck was a feature** in NHL '94 ("something specifically delicious about the slowness of the puck"); "you want
   to make it feel good, not look good" ([THN oral history](https://thehockeynews.com/news/all-access/the-making-of-nhl-94-an-oral-history)).
4. **The AI decides a few times a second from scored options with fresh information** (Football Manager every 0.25 s,
   [FM21](https://www.footballmanager.com/news/match-engine-ai-fm21)); difficulty = reaction and decision speed
   ([Google Research Football](https://arxiv.org/pdf/1907.11180)).

Turnovers must have readable causes (a poke from the front, a check, an intercepted lane, a carrier who turned too hard, a
bobbled hard pass). "Random" = the player cannot name the cause; "glued" = no cause ever fires.

## 1. What the games did (short)
- **NHL '94:** invincible goalie; the one-timer (shoot as the pass arrives) is the signature payoff; distinct player types.
- **EA NHL:** puck speed decides whether a poke works; players hate ghost pokes, the puck bouncing back after a poke, and
  instant re-steals. A short delay before a defender owns a poked puck is the community fix.
- **FIFA / EA FC:** first touch = a trapping error that grows with the incoming ball's speed; close control costs speed.
- **Rocket League:** ball top speed ~2.6x the car's; designed impulse on hits; 3v3 rotation (first man challenges, second
  supports, third covers; roles re-sorted by distance) ([Ginx](https://www.ginx.tv/en/rocket-league-standard-guide-when-to-challenge-3v3-rotations-and-roles)).
- **Mario Strikers:** only a player without the ball can steal; hitting someone without the ball has a cost.
- **Blades of Steel:** one button pass/shoot, smooth control switching, a "get the pass" call.
- **NHL Hitz:** 3v3, big hits, on fire after three goals; criticised for thin depth.
- **Buckland's Simple Soccer** (Programming Game AI by Example, ch. 4; port [github.com/luiskarlos/soccer](https://github.com/luiskarlos/soccer)):
  state machines per player, team role pointers (controlling, supporting, receiving), a support-spot grid scored by pass
  safety, shot chance and distance; `canShoot`, `isPassSafe`, `findPass`. A poor `canShoot` makes a team "always or never
  shoot".
- **Utility AI** (Mark & Dill, GDC 2010/2012): each option's score = product of response-curved considerations + hard vetoes.
- **RoboCup SPAR:** off-ball players repelled by others, attracted to ball and goal, kept near home: open passing lanes.
- **Difficulty without cheating:** reaction delay + aim noise + decision noise; never read state the player cannot see;
  rubber-banding, if any, only through the AI's choices (NBA Jam's hidden tuning is the warning).

## 5. Implementable spec (60 Hz frames; rink 60 x 30 m)
### 5.1 Puck carry
States `LOOSE` (physics), `CARRIED(owner)`, `PASS_IN_FLIGHT(target)`, `SHOT_IN_FLIGHT` (swept collision: 0.5 m/frame at 30 m/s).
- **Carry:** spring to an anchor 0.75 m ahead on the stick side (k 400, critically damped); dangle = clamp(speed/v_max x
  turn_rate/6 rad/s, 0, 1) x 0.5 m outward. Dangle over 0.45 m for 6+ frames (sprint + hard turn only) -> LOOSE with the
  skater's velocity. Poke from the carrier's back half x0.4 (shielding).
  *Our figure is 4.4 m tall: scale the 0.75 m anchor to the drawn blade, as L4 scaled 1.2 m to 1.98 m.*
- **Pickup** (LOOSE): radius 0.9 m from the anchor, cone +-70 deg; relative speed <9 m/s clean; 9-14 bobble (velocity -60 %,
  no pickup for 10 f); >14 deflects.
- **Pass reception:** the intended receiver gets 1.3 m and +-100 deg, plus an 18-frame soft magnet within 2 m. One-timer if
  shoot is pressed from 8 f before to 6 f after arrival: +20 % speed, 4-frame release.
- **Poke:** reach 1.7 m, cone +-35 deg, active f6-12 of 24, cooldown 40. p = 0.65 x angle (front 1.0, side 0.7, behind 0.4)
  x timing (0.6 if the carrier changed direction in the last 10 f). Success frees the puck at 4-6 m/s along the poke + 30 %
  of the carrier's velocity. A missed poke halves the poker's turn rate for 15 f.
- **Body check** (keep the current wind-up model and its rate, owner 21 Nov): the puck always comes loose above the stumble
  threshold.
- **Anti ping-pong:** after any change of possession, the previous owner and every opponent within 2 m cannot steal for 30 f,
  and the new owner cannot be poked for 12 f.
- **Vetoes:** no possession while down; no pickup for 6 f after your own pass or shot.

### 5.2 Speed table
| Quantity | Value |
|---|---|
| Skater cruise / sprint | 8.5 / 10.5 m/s; stamina 3.0 s, regen 25 %/s after 30 f |
| Carrier | 0.88 x (7.5 / 9.2 m/s) |
| Acceleration 0 -> cruise | 0.55 s (~15 m/s2); carrier 12 m/s2 |
| Turn rate | 4.5 rad/s at speed; carrier 3.8; sprint 3.0 |
| Hockey stop | 25 m/s2 |
| Pass tap / hard | 16 / 22 m/s (ice friction ~0.9 m/s2, estimate) |
| Wrist / charged / one-timer | 26 / 30-34 / ~32 m/s |
| Goalie lateral push | 4.0 m/s; reaction 8-14 f by difficulty |
Checks: pass speed ~1.9-2.6x cruise (passing beats skating); a one-timer after a 6 m lateral pass beats a 4 m/s goalie.
*Scale these to our rink and figures with bots; the RATIOS are the point.*

### 5.3 AI decisions
- Re-decide every 15 f (staggered); interrupt on events (possession change, a pass toward me, a loose puck within 3 m, a hit);
  +0.15 commitment bonus to the current action.
- Perception lag `react` 18/12/7/5 f (easy..brutal); aim sigma 6/4/2.5/1.5 deg; score noise +-0.08/0.05/0.03/0.02.
- Inputs (0..1): `xg` (distance 4->22 m, angle 0->70 deg, lane block, goalie offset bonus), `lane_safe(t)` (Buckland: can any
  opponent reach the pass segment before the puck, with reaction), `open(t)`, `gain(t)` (t's xg minus mine + 0.3 forward
  progress), `pressure`, `space_ahead`, `poss_time`.
- Carrier: SHOOT = 1.6 xg + 0.2 one-timer - 0.3 pressure(1 - xg), veto xg < 0.08; PASS(t) = 1.2 lane_safe open (0.5 + gain)
  + 0.25 pressure, veto lane_safe < 0.35; CARRY = 0.9 space_ahead (1 - pressure) + 0.15 - 0.2 poss_time; PROTECT = 0.6
  pressure (1 - max lane_safe); DUMP = 0.5 own_half pressure (1 - max lane_safe).
- Off puck: SUPPORT (best support spot), DRIVE_NET (far post for a one-timer). Defence: PRESSURE (first man), BLOCK the most
  dangerous lane (second), GUARD the slot (third), CONTEST a loose puck.

### 5.4 Positioning (3 skaters + goalie)
Roles re-sorted every decision tick by time-to-puck (0.3 s hysteresis). Attack: F1 carrier/chaser; F2 support spot on a
1.5 m grid 6-14 m from the carrier, S = 0.35 lane_safe + 0.30 xg + 0.20 dist_ideal (peak 9 m) - 0.15 crowding, re-sampled
every 30 f; F3 high safety, goal-side of the deepest opponent, >= 8 m behind the puck. Defence: D1 pressures from the inside,
pokes only inside 1.7 m with p >= 0.45; D2 stands on the carrier-to-best-receiver segment; D3 guards the slot 4-7 m out.
No two teammates within 4 m unless contesting; boards repel supporters within 1.5 m. Goalie on the puck-to-net line, depth
1-2 m, lateral cap 4 m/s, re-targets after his reaction delay; saves decided by whether his body covers the path. AI
teammates never take the puck from the human; F2 "calls" (icon/voice) when lane_safe x open > 0.6.

### 5.5 Five bot metrics (quote per hand and difficulty, over N seeds)
1. Possession length: median 4-10 s (>15 s glued, <2 s random).
2. Passes per possession 1.5-3; completion 70-85 %.
3. Shots per minute per team 1.5-3; >= 40 % from the slot or as one-timers.
4. Turnovers per minute by cause (poke, check, intercept, self-loss, bobble): no cause > 45 %; self-loss < 15 %; bobble < 15 %.
5. Offensive-zone share 35-55 % evenly matched; zone-entry success 50-70 %; goals per game 3-7 combined.
