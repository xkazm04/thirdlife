# Duel combat playbook: 1v1 melee for Third Life arenas

Research of 21 Nov 2026, for the owner's ruling of the same evening: "Arena mutual reaction on attacks and collision is
almost non-existing, we don't need to reinvent wheel, there are hundreds of duel games (souls like, for honor duels) with
well known game design paths we can mimic." Sources are linked inline. **(CM)** marks a community-measured figure. FromSoftware
wiki frames are at 30 fps and double at 60. **Rec.** marks our own choice for the 60 Hz kernel, with no source behind it.

## 1. The proven models in one line each
- **Dark Souls / Elden Ring:** stamina gates everything; poise/stance decides who flinches; light strings and heavy
  chargeable attacks; roll i-frames (ER light/medium 14 at 30 fps, heavy 13; heavier load = fewer i-frames, longer
  recovery); parry opens a critical; Guard Counter after a block
  ([Bandai Namco](https://www.bandainamcoent.com/news/elden-ring-introduction-part-4-combat-guide),
  [ER wiki Stance](https://eldenring.wiki.gg/wiki/Stance), [I-Frame](https://eldenring.wiki.gg/wiki/I-Frame)) (CM).
- **Sekiro:** posture instead of stamina. A deflect in the last 12 frames before a hit loads the ATTACKER's posture; mashing
  shrinks the window (to 4, then 0); a full posture bar opens a deathblow; each perilous (unblockable) attack has ONE named
  answer (sweep: jump; thrust: deflect/Mikiri; grab: dodge)
  ([Fextralife Deflection](https://sekiroshadowsdietwice.wiki.fextralife.com/Deflection),
  [Activision](https://support.activision.com/sekiro/articles/sekiro-shadows-die-twice-game-mechanics)) (CM).
- **For Honor:** guard by direction; parry a heavy -> a light is guaranteed, parry a light -> a heavy (the harder parry pays
  more); guard break, counter-GB, wall splat, ledge kill; feints; bash = unblockable but interruptible; chip 18 % on block;
  out of stamina = slower attacks and knockdown on a throw
  ([Ubisoft S5](https://www.ubisoft.com/en-us/game/for-honor/news-updates/1ZO1qG5mqCaURiMFVgwlJl/season-5-core-fight-update),
  [terminology](https://www.ubisoft.com/en-us/game/for-honor/news-updates/6XEM2qUiwcokp753uCzgkz/for-honor-terminology-guide)).
- **Absolver:** an archetype is defined by its DEFENCE: Forsaken parries, Windfall avoids, Kahlt absorbs.
- **Mordhau / Chivalry 2:** chamber (answer an attack with the same attack), drag/accel timing, riposte; "whoever lands first
  interrupts".
- **Smash:** grab beats shield, shield beats attack, attack beats grab; hit-stop freezes BOTH fighters, stronger = longer,
  capped; clank: two attacks within 9 % both rebound for equal frames ([SmashWiki](https://www.ssbwiki.com/Hitlag),
  [Priority](https://www.ssbwiki.com/Priority)).
- **Punch-Out:** tells as puzzles; hitting during a tell earns a star; a whiffed or blocked attack COSTS the attacker.
- **Nidhogg / Bushido Blade:** one-hit stakes, heights and stances; honour rules as game rules.

## 2. Mutual reaction: every contact changes BOTH fighters
| Contact | Attacker | Defender |
|---|---|---|
| Hit | freezes in hit-stop with the defender, then recovery | freezes, then hitstun/stagger by poise tier + knockback |
| Block | shorter hit-stop (x0.67); on a heavy a recoil that leaves him minus | blockstun + pushback, stamina/posture drained, chip |
| Parry / deflect | weapon knocked away, long stun, posture damage, punish guaranteed against him | short recovery, the initiative |
| Guard break / bash | short recovery, chooses throw or strike | guard opened, shoved; wall = splat, out of stamina = knockdown |
| Clash | both rebound equal frames if close in strength; else the stronger continues | same |
| Whiff | full recovery, stamina spent, regen paused | free whiff punish in range |
| Hit on rolling target | in i-frames: nothing; in roll recovery: counter-hit | |
| Wall impact | free follow-up | wall-splat stagger |

**Bodies never overlap:** a capsule pushbox per fighter; every physics frame push both apart by half the penetration (fixed
order, deterministic); a fighter in hitstun/blockstun cannot push back; the body check is the only intentional shove.
**Frame advantage** = the gap between the two fighters' "can act again" frames; a move is punishable on block when the
attacker is minus by more than the defender's fastest startup.

## 3. The triangle and neutral
Guard beats attack; grab/bash beats guard; attack beats grab/bash. Parry beats attack but a whiffed parry is punishable.
Roll beats attack and bash but loses to a delayed attack. A heavy beats a light trade through armour, but a blocked heavy
loses to a light. It stays healthy because every option costs stamina/posture, every defence has a whiff cost, and reaction
limits apply: a single known stimulus takes ~16 frames, so moves faster than that must be READ
([Infil](https://ki.infil.net/reaction.html)). Neutral = spacing at threat range and whiff punishing; anti-runaway: a
retreating fighter slows and drains stamina.

## 4. Enemy AI
An attack has opening pose, signal, active (2-4 f), end pose, return; signal + attack >= 340 ms; the RETURN is the punish
window and its length is the difficulty lever ([DS3 anatomy](https://www.gamedeveloper.com/game-platforms/anatomy-of-an-enemy-attack-in-dark-souls-3)).
Delayed attacks keep the same delay every time. Later phases add density, not randomness. React only to VISIBLE state
(an animation start), after a reaction delay (~230 ms in pro fighting AI). Defence success rate is the difficulty dial.
Never repeat the same string three times.

## 5. Stakes
Ladder of rivals, then the same rivals remixed with new patterns (Punch-Out Title Defense); best of 3 rounds of 60-75 s;
walls that splat and ledges that kill reward space control; a crowd meter fed by parries, splats and punished taunts.

## 6. Implementable spec (Rec., 60 Hz, all in physics frames)
### 6.1 Resources
- **HP 100**: light 9, chained light 7, heavy 20, charged 30, bash 4, finisher 30; chip on block 10 % (never kills).
- **Stamina 100**: light 12, chained 10, heavy 22, charged 30, bash 15, roll 20, dodge 12, whiffed parry 8, good parry +10.
  Blocking costs the attack's stamina damage (light 10, heavy 24). Regen 0.6/f after 20 f (attack), 24 (dodge), 30 (blocked);
  0.2/f while blocking. **EXHAUSTED at 0 until 40:** windups x1.25, roll recovery +12, a blocked hit = GUARDBROKEN 40, a
  bash = KNOCKDOWN, a parry attempt disarms.
- **Posture 100** (fills): block light +10, heavy +22; parried light +20, heavy +30; hit light +6, heavy +14; clash +12 each.
  Regen 0.25/f after 45 f without posture damage, halved under 50 % HP. At 100: **BROKEN 90 f**, a heavy = finisher.
- **Poise tiers:** poise damage (light 10, heavy 30, charged 45) minus poise (Wall 40, Duelist 20, Dancer 10; +40 during
  heavy frames 12-37): <=0 absorb, 1-15 flinch (18 f), 16-35 stagger (40 f + 0.6 m), >35 knockdown (45 + 30 getup).

### 6.2 Moves (windup / active / recovery on whiff) on our clips
| Move (clip) | Windup | Active | Recovery | Notes |
|---|---|---|---|---|
| Light (`strike`) | 18 | 4 | 16 | chain windup 12 (below the reaction floor: must be read) |
| Heavy (`strike_heavy`) | 32 | 5 | 28 | hyper armour 12-37; feint until f20 (6 stamina) |
| Charged heavy | 54 | 6 | 36 | red flash at f20, unblockable |
| Bash (`body_check`) | 14 | 6 | 24 | unblockable, not parryable; loses to any active hit and to a roll |
| Block (`block`) | 4 up | held | 6 down | front 120 deg |
| Parry (`block` tap) | - | f2-13 | 20 if no contact | re-tap within 30 f shrinks the window by 4 (Sekiro) |
| Roll (`roll`) | - | i-frames 4-21 | 22-36 vulnerable | |
| Dodge (`dodge`) | - | i-frames 3-10 | 11-22 | also beats a bash |
| Taunt (`taunt`) | - | - | 60 | crowd +; hit during it gives the hitter a star |
| Getup | - | i-frames 1-20 | 21-30 | |

### 6.3 Contact results (hit-stop on BOTH, then counters)
| Contact | Hit-stop | Defender | Attacker | Advantage |
|---|---|---|---|---|
| Light hits | 5 | tier (flinch 18) + 0.25 m | recovery 16 | +2 |
| Heavy hits | 9 | tier (stagger 40) + 0.6 m | 28 | +12 |
| Light blocked | 3 | blockstun 14, pushed 0.35 m | 16, recoils 0.15 m | -2 safe |
| Heavy blocked | 6 | blockstun 18, pushed 0.5 m | recoil bounce: 40 | -22, light guaranteed |
| Light parried | 10 | 8 | PARRIED 52, weapon knocked away | +44 |
| Heavy parried | 10 | 8 | PARRIED 36 | +28 |
| Bash lands | 6 | GUARDBROKEN 30, pushed 1.0 m | 10 | +20 (counter-bash within 8 f: both pushed 0.6 m) |
| Bash with a wall within 1.2 m behind | 12 | WALLSPLAT 60 | 10 | +50 |
| Clash, same class | 8 | REBOUND 20 (heavy-heavy 30) | same | 0 |
| Clash heavy vs light | 9 | the light takes the hit | heavy continues | |
| Hit in windup / roll recovery | +2 | COUNTER-HIT: hitstun +10, damage +25 % | normal | |
| Hit in i-frames | 0 | nothing ("whiff") | full whiff recovery | |
| Knocked into a wall in hitstun | 8 | WALLSPLAT 40 | | |

### 6.4 State machine
`IDLE/MOVE -> WINDUP -> ACTIVE -> RECOVERY -> IDLE`, plus `BLOCK`, `PARRY_WINDOW`, `ROLL`, `DODGE`, `TAUNT`, `HITSTOP`
(frozen sub-state), `HITSTUN`, `BLOCKSTUN`, `PARRIED`, `GUARDBROKEN`, `REBOUND`, `STAGGER`, `WALLSPLAT`, `KNOCKDOWN -> GETUP`,
`BROKEN`; `EXHAUSTED` is a flag. 8-frame input buffer; actions only from IDLE, the last 4 f of RECOVERY, BLOCK, and the ends
of BLOCKSTUN/GETUP. Every transition by frame counters; same seed + inputs = same `state_hash`.

### 6.5 Interaction matrix (attacker ACTIVE x defender state)
| Attacker / Defender | Idle | Windup | Active | Recovery | Block | Parry | i-frames | Roll recovery | Stun | Down |
|---|---|---|---|---|---|---|---|---|---|---|
| Light | hit | counter-hit (absorbed by armour) | clash | hit | blocked -2 | parried +44 | whiff | counter-hit | hit | none |
| Heavy | hit | counter-hit | clash/wins vs light | hit | blocked -22 | parried +28 | whiff | counter-hit | hit | none |
| Charged | hit + knockdown | hit | wins | hit | unblockable: hit | parried, PARRIED 60 | whiff | counter-hit | hit | none |
| Bash | guardbroken | loses to an attack active first | loses | guardbroken | guardbroken (wall: splat) | guardbroken | whiff -24 | guardbroken | shove | none |

### 6.6 AI (seeded generator only)
States SPACING (circle at threat range +0.3 m), PRESS, DEFEND, PUNISH, RESET (back off under 30 stamina or after being
parried). Perceive only visible states, after `react_frames`. Defend with `defend_p`; parry only a move seen N times this
round. Remember the player's last 8 responses; with `read_p` pick the ender that beats the commonest (bash vs block, delayed
heavy vs roll). Never the same string 3 times. Every string ends in a return window.

| Tier | react_frames | defend_p | read_p | return window |
|---|---|---|---|---|
| Rung 1 | 30 | 0.30 | 0.10 | 36 |
| Rung 2 | 22 | 0.45 | 0.30 | 28 |
| Rung 3 | 18 | 0.60 | 0.50 | 22 |
| Champion | 15 (>= 14) | 0.70 | 0.65 | 18 |

### 6.7 Three rivals
1. **THE WALL** (absorb; shield brute): poise 40, HP 120, blocks at x0.7 stamina. Light (20), armoured heavy, shield bash
   (tell: shoulder dip at f4), guard counter after a block, taunt after 2 blocked hits. DEFEND 0.6, rarely parries, always
   takes the guaranteed light after the player's blocked heavy. Weak to bash and stamina pressure. Phase 2 (<50 % HP): a
   3-hit heavy string with one fixed 18 f delay.
2. **THE DUELIST** (parry master): poise 20, HP 100, parry window 14. 3-light chain, thrust heavy (28), feint into bash,
   riposte after its own parry. Parries the 3rd hit of a string, blocks the first two, punishes every whiff, pokes at max
   range. Weak to delayed/feinted heavies and bashes; a whiffed parry recovers 20 f. Tell: taps its blade 24 f before a
   riposte string (hit it then for a star).
3. **THE DANCER** (avoid; dual blades): poise 10, HP 85, roll 30 f (i-frames 3-18), dodge 8 stamina. Dash light (2.5 m,
   16), roll-attack light, 4-hit flurry (12 f chains), delayed spin heavy (always a 30 f hold), taunt after a flurry. PRESS
   0.6; rolls through the player's heavy windup with read_p; rolls away under 40 stamina. Weak: any heavy staggers it;
   punish roll recovery f19-30; the flurry ender is -20 on block.

**Acceptance:** a bot must show BOTH fighters' state change on every contact type of 6.3; a round where a contact left one
fighter's state unchanged is a failure.
