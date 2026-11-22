# Duel: the ring and three rivals (`game.duel`)

One fighter against a ladder of rivals in a walled ring, best of 3 rounds. The rules are the proven ones of Dark Souls,
Sekiro and For Honor, taken from `docs/research/DUEL-PLAYBOOK.md` section 6, and every contact changes BOTH fighters.
Hand-built on the night of 22 Nov 2026 (lane N2) as the reference duel the editor copies: its recipe card is
`engine/cards/duel.json`.

```
node devx/bin/tl.mjs play duel          # or: bash engine/tools/tl.sh play --pack=engine/packs/duel
```

## How to play (what a newcomer learns in the first 30 s)

| Key | Does |
|---|---|
| W A S D | walk; you always face the rival (lock-on): W closes in, S backs off, A / D circle |
| LMB or J | light: fast (18-frame wind-up), press again as it ends for a chain of 3 (12-frame wind-ups) |
| RMB or K | heavy: slow (32), armoured from frame 12, hurts. HOLD it: at frame 20 it flashes red and becomes the charged heavy, which no guard stops |
| SPACE or L | hold: block (front 120 degrees). TAP it just before a blow lands: PARRY. A tap that meets nothing leaves you open for 20 frames |
| SHIFT | roll (with W / S or no direction: away) or dodge (with A / D, a side step). Both pass through blows in their first frames |
| E | bash with the shoulder: breaks a guard, splats a rival against the wall. Any attack already swinging beats it |
| Q | taunt (the crowd likes it; a hit during it gives the hitter a star) |
| V | camera: the two-shot (behind your right shoulder, 50 degrees off the line between you, pulled back by the gap: both of you and his wind-up stay on screen), side, wide |
| R / ENTER | restart the match / after a win, the next rival |

The first round shows the keys and a cue line at the moments that matter: "You blocked his HEAVY: LIGHT now!",
"Shoulder dip = BASH coming", "RED = UNBLOCKABLE: roll, or hit him first", "He is BROKEN: a HEAVY now is a finisher".

## The first minute (round 1 against the Wall; `scripts/lessons.gd`, `data/lessons.json`)
The Wall teaches by play, as For Honor's first duel and Sekiro's sparring partner do: a cue line goes up 75 frames
before each blow, the blow comes with a held wind-up, and after the right answer he stands open for the punish.
1. a slow heavy: "HOLD SPACE to block it" -> blocked, he bounces off -> "hit him NOW";
2. a slow light with the glint: "TAP SPACE as it lands: PARRY" -> "a HEAVY cannot miss";
3. he walks in behind his shield: "E: your shoulder breaks a guard" -> "Strike!".
A missed lesson is shown once more; after the third (or 50 s) he fights for real. Every rival's light and heavy flash
a glint on the weapon 16 frames before they land (the moment a person reacting to it presses block in time to parry).

## A loss has a name (`data/causes.json`)
Every hit you take is filed under a cause from your state and his move: his lights, his heavies, the red unblockable,
his bash, swinging into his swing, a punished miss, a parry tapped too early, hits after a broken guard, the end of
your roll. A lost round ends on the biggest one by damage and its answer, on screen through the next round's intro:
"WHAT BEAT YOU: his quick lights (6 hits, 50 damage) / Keep your guard up close in (hold SPACE) and tap SPACE on the
glint to parry." (plays-twice items 13 and 22). `_pack_state` carries `causes` and `loss_causes`.

## Each rival's place, beat and rhythm (`data/arenas.json`, `scripts/arena.gd`, `rivals.json` rhythm)
- **Arena**: kit parts outside the ring wall, built when the match's rival is chosen. A near ring of 16 low banners in
  his colours (10.3 m, seen over his shoulder in play), then his far parts seen in the intro shot: the Wall's watch
  towers and boulders, the Duelist's tall red and gold flags and masts (their shadows lattice his floor), the Dancer's
  trees and pink and violet flags. The champion rungs (3-5) add six tall gold flags.
- **Intro**: round 1 of every match opens on a slow shot of him from your side, his arena behind him, under his name
  and his line.
- **Beat**: a stand-in drum (TLAudio presets: no music in the kernel, engine need E5): the Wall a slow thud, the
  Duelist a tighter knock, the Dancer a quick wood tap; louder accents; faster while he pushes, when a fighter is low or
  he roars, and on the champion rungs; silent while a hit-stop holds.
- **Rhythm** (checklist item 12, the rival brings waves): a push (strings at about half his pace, less standing open),
  then a breath: the Wall backs off behind his shield and only weathers what you do (no counter, no punish: bash him);
  the Duelist and the Dancer back off on their feet, circling with a feint step in, their ripostes and punishes kept. The Wall and the Dancer open the breath with a taunt you can punish.
- **Time on the card**: a match ends on its fight time, and a won match shows the best against this rival in the
  session (BEST!).

## The blow that ends a round (`tuning.json` "ko")
The round-ending blow holds the longest hit-stop the kernel allows (20 frames), then the camera cuts low beside the
fallen fighter with the winner over him: dust as he meets the sand, the crowd's roar, the winner's cheer; the play
camera comes back with the next round (plays-twice items 19 and 28).

## What you see
- Top left / right: health, stamina and posture bars for you and the rival, with EXHAUSTED, RALLY, BROKEN and stars.
- Top: round, rounds won (filled pips), the round clock, the rival's name, the crowd meter.
- Centre: PARRY!, CLASH!, GUARD BREAK!, WALL SPLAT!, COUNTER!, FINISHER!, K.O.
- Every contact freezes both fighters for 3 to 14 frames (the hit-stop), then each shows his own reaction: a flinch, a
  stagger, a block slid back, a heavy bounced off a guard, a parried attacker flung open, a body slammed on the wall.

## The rules (all counted in physics frames at 60 Hz; the numbers are data)

**Moves** (`data/moves.json`). Wind-up / active / recovery:

| Move | Frames | Damage | Stamina | Notes |
|---|---|---|---|---|
| light | 18 (chain 12) / 4 / 16 | 9 (chained 7) | 12 (10) | chain of 3 (the Dancer 4) from the last 4 recovery frames |
| heavy | 32 / 5 / 28 | 20 | 22 | hyper armour frames 12-37; feint until f20 (block cancels, bash feints into a bash) |
| charged | 54 / 6 / 36 | 30 | 30 | the heavy held past f20: red flash, unblockable, parryable (PARRIED 60) |
| bash | 14 / 6 / 24 | 4 | 15 | unblockable, unparryable, loses to any active attack and to a roll |
| block | up in 4 | | blocking costs the blow's stamina damage | front 120 degrees; chip 10 % (never kills) |
| parry | frames 2-13 of a block press | | +10 on success, 8 on a whiff | a re-tap within 30 f shrinks the window by 4; a tap holds the window to its end |
| roll / dodge | 36 (i-frames 4-21) / 22 (3-10) | | 20 / 12 | roll travels 3.2 m, dodge 1.4 m sideways |

**Contacts** (`data/contacts.json`, the interaction matrix in `scripts/contact.gd`):

| Contact | Hit-stop | Defender | Attacker | Advantage |
|---|---|---|---|---|
| light hits | 5 | flinch 18, 0.25 m | recovery 16 | +2 |
| heavy hits | 9 | stagger 40, 0.6 m | recovery 28 | +12 |
| light blocked | 3 | blockstun 14, 0.35 m | recoils 0.15 m | -2, safe |
| heavy blocked | 6 | blockstun 18, 0.35 m | rebounds 40, 0.2 m | -22: a light is guaranteed |
| light parried | 10 | 8 | PARRIED 52 | +44: a heavy is guaranteed |
| heavy parried | 10 | 8 | PARRIED 36 | +28: a light |
| bash | 6 | GUARDBROKEN 30, 1.0 m | 10 | +20; exhausted defender: knockdown |
| bash, wall within 1.2 m behind | 12 | WALLSPLAT 60 | 10 | +50 |
| counter-bash (both bash within 8 f) | 6 | both rebound 20, 0.6 m apart | | 0 |
| clash (same class, or a swing 5 frames from its own) | 8 | both rebound 20 (heavy 30), 0.45 m | | 0 |
| heavy against light | 9 | the light is hit | heavy goes on | |
| hit in a wind-up, roll end, tell or taunt | +2 | counter-hit: stun +10, damage x1.25 | | |
| hit in i-frames | 0 | nothing | full whiff recovery | |
| knocked into the wall in a stun | 8 | WALLSPLAT 40 | | |

**Resources** (`data/tuning.json`). Stamina 100, regen 0.6/f after 20 (attack), 24 (roll), 30 (blocked) frames, 0.2/f
while blocking; at 0 EXHAUSTED until 40: wind-ups x1.25, roll +12 frames, a blocked hit breaks the guard (40), a bash
floors. Posture fills (block light 10, heavy 22; parried light 20, heavy 30; hit 6 / 14; clash 12), drains 0.25/f after
45 quiet frames (half under 50 % health); at 100 BROKEN 90 frames, where a heavy is a 30-damage finisher. Poise tiers:
poise damage (light 22, heavy 42, charged 70) minus the defender's poise (you 10, Wall 20, Duelist 10, Dancer 8; +40 in
heavy armour frames): 0 or less absorbed, up to 15 a flinch, up to 35 a stagger, more a knockdown (45 + a 30-frame get-up
with i-frames 1-20). **Rally**: under 35 % health a fighter's stamina comes back half as fast again (shown on the HUD,
both sides).

**Rounds and ladder.** Best of 3 rounds (`rules.score_to_win` 2), each up to 70 s; KO or, at time, the larger health
share. Rivals: 0 the Wall, 1 the Duelist, 2 the Dancer; 3-5 the same three at the champion tier (param `rival`).

## The rivals (`data/rivals.json`, `scripts/brain.gd`)

| Rival | Defence | Tier (react / defend / read / return) | Hp, poise | Tell | Weak to |
|---|---|---|---|---|---|
| THE WALL | absorbs: walks behind his shield, guard counter after a block, taunts after 2 blocked hits; phase 2 under 50 %: he ROARS (a banner, a horn, a cue that names the pattern) and opens with 3 heavies, the second always 18 frames late | rung 1: 30 / 0.30 / 0.10 / 36 | 110, 20 | the shoulder dip of his bash | bash, stamina pressure, the light after his blocked heavy |
| THE DUELIST | parries: the third hit of a chain (read), heavies he has seen twice; ripostes with a heavy; feints into a bash | rung 2: 22 / 0.45 / 0.30 / 28 | 100, 10 | taps his blade 24 frames before his string: hit him then for a star | delayed or feinted attacks (his parry whiffs), bashes |
| THE DANCER | avoids: rolls and dodges, rolls through heavies, side-steps the next hit of a chain (read); dash lights, the roll-cut (she rolls in, squares up out of the roll and cuts with a dashing light), 4-hit flurry (her blades: light 11, chained 9), a spin heavy always held 30 frames | rung 3: 18 / 0.60 / 0.50 / 22 | 85, 8 | the long spin coil | any heavy staggers her; the end of her roll |

The mind sees only the player's animation, `react` frames late; it answers a share `defend` of the player's attacks in
its archetype's way; a light (18 frames) is faster than its reaction, so a chain is READ (the Duelist times a parry for
the third hit, the others raise their guard); with share `read` a string's last move is swapped for the counter to the
player's commonest answer of the last 8 (block -> bash, parry -> feint into bash, roll -> delayed heavy). It never plays
the same string three times running and stands open for `return` frames after each. It presses the same door as the
player (the buffer, the block hold, the walk intent): it cannot do anything a person could not.

## Files
| File | What |
|---|---|
| `scripts/main.gd` | the venue, the fighters, input, rounds, ladder, drills, `_pack_state` |
| `scripts/fighter.gd` | the state machine of one fighter (6.4), resources, moving the body, the rig clocks |
| `scripts/contact.gd` | the interaction matrix (6.5) and the contact results (6.3); the contact log |
| `scripts/brain.gd` | the rival's mind (6.6) |
| `scripts/feel.gd` | THE feel-kit adapter: hit-stop, the six contact reactions, knockdown, pushbox, occluder fade, rig clocks |
| `scripts/show.gd` | HUD, banners, cues, effects, sound, shake, the three cameras |
| `gen/arms.gd` | the weapons (sword, rapier, mace, shield, blades), kit-style meshes on the hand sockets |
| `tests/bot_contact_<drill>.gd` | one bot per contact type (data/drills.json): passes when BOTH fighters changed |
| `tests/bot_ladder_<rival>_<hand>.gd` | one best-of-3 match through a TLHand (`tests/support/pilot.gd`); `tl ladder --pack engine/packs/duel` |

## What changed from the playbook, and why
- **Poise numbers.** The playbook's poise damage (light 10, heavy 30) minus its poise (Duelist 20, Dancer 10) absorbs
  every light, which contradicts its own contact table (a light hit flinches 18). Poise damage is light 22, heavy 42,
  charged 70 and poise you 10, Wall 20, Duelist 10, Dancer 8: a light flinches everyone, any heavy staggers, a charged
  heavy floors, the Wall's armour (+40) absorbs a light and trades with a heavy.
- **The parry is the first frames of a block press** (Sekiro's deflect): press = parry window f2-13, hold = block. A tap
  keeps the window open to its end; a tap that met nothing is the 20-frame whiff. One button, as the brief asks.
- **Clash leniency.** Two swings of the same class clash when one is active and the other is at most 5 frames from its
  own active frame (exact overlaps of 4-frame windows were too rare to be a readable event).
- **Rally** (a visible comeback rule, plays-twice item 15) and a **crowd meter** (section 5, drawing only) were added.
- **The i-frame evade changes neither fighter**, as the playbook says ("nothing"); it is logged and is the one contact the
  both-change rule does not cover. A knock into the wall changes the attacker only by the hit-stop (the playbook leaves
  his column empty).
- **Pushbox** 0.45 m per duellist at scale 1 (N1's measurement: the big-headed figures overlap heads at 0.32).
- **The blocked heavy's pushes are 0.35 m and 0.2 m** (playbook 0.5 and 0.3) and the light steps in 0.5 m: with the
  kernel's real pushes the two fighters ended 2.46 m apart and the guaranteed light fell short of its 2.05 m reach.
- **A guard held on from a stun or a move is not a parry**: only a fresh press opens the window (and only a fresh tap can
  whiff).
- **KO**: the loser lies 100 frames and rises during the round's end, so the next round starts standing.

## Numbers measured (21 Nov, on the kernel's feel kit, API 1.13: `tl ladder --pack engine/packs/duel --seeds 8`)

Wins of 8 (one best-of-3 match per seed) through the pilot (`tests/support/pilot.gd`) and a TLHand. A bot measures the
game, not the player: a person's hand is the bar, and nobody has played it yet.

| Rival | newcomer | regular | sharp | perfect |
|---|---|---|---|---|
| THE WALL (rung 1) | 5 (63 %) | 8 (100 %) | 8 | 8 |
| THE DUELIST (rung 2) | 2 (25 %) | 5 (63 %) | 8 | 8 |
| THE DANCER (rung 3) | 0 | 4 (50 %) | 8 | 8 |
| the Duelist at the CHAMPION tier (rung 4) | 0 | 1 (13 %) | 5 (63 %) | 8 |

8 seeds give intervals of about +-30 points. Newcomer < regular < sharp <= perfect for every rival, the rungs get
harder in order for the newcomer and the regular hand, the newcomer wins often against the first rival (a safe first
threat) and never against the champion, and the champion keeps a ceiling under the perfect hand. Hand checks (card.duel,
20 seeds, the Wall): idle 0 of 20 (every round a KO), perfect 20 of 20. The lane report has the plays-twice items and
the clips: `docs/shifts/2026-11-22-night/lanes/N2-duel/REPORT.txt`.
