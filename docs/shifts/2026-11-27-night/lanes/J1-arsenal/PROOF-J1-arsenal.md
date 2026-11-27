# J1-arsenal proof: Arsenal hockey gets a meteor slapshot (27 Nov 2026, night)

Tree `.claude/worktrees/d25-arsenal` (branch n27-arsenal, main b1ee0b1d). Job
`.tl/jobs/three-against-three-hockey-20261125-1` (v0.1.21, the menu's "Arsenal hockey"). Times are local.

## Juice sheet (written 05:11, before the first sentence)

One ability. What the rink core already has decides the shape: the core's `shotgun` trick ("the next shot leaves at
magnitude x speed and knocks down every skater within 1 m of its path", CARTRIDGE.md:476) is the knockdown, in the
C++ simulation, so the hit is real and the bots' bodies answer it. The charged shot (`shot.charge_frames_max`,
`charge_speed_bonus`) is the wind-up. The fire, the boom and the shaking glass are drawing on top of the sim.

### The meteor slapshot (key F, then shoot)

- **Key:** F lights the stick (the meteor is armed), then the shot button: hold to wind up, release to fire.
- **Wind-up (anticipation):** while armed the blade burns (an orange flame on the stick, embers). Holding shoot charges
  for up to 45 frames: a glow ring grows round the skater, the flame grows and goes white-hot. The charge is the
  core's own (ChargeFrames); a winding-up carrier stands at 0.6 of his stability (`contact.spin_stability`), so a
  rival's check floors him: the wind-up is a risk.
- **Exaggeration, in numbers:**
  - shot speed x 2.0 (the core's magnitude): a full charge leaves at about 2 x (18 + 10) x the speed scale, near the
    puck's cap; a normal shot is 18 + charge;
  - a puck 3 times its size drawn as a fireball with a 6 m fire trail and smoke;
  - every skater within 1 m of its path goes down (the core), mates, rivals and the keeper alike.
- **Impact:** a white flash and a blast ring at the stick on release, 4 frames of hit-stop, a camera kick; each skater
  it fells gets a burst of sparks and fire and a word ("FLOORED!"); a boom. If it scores: the net bulges back, the
  glass round the rink shakes, a fire burst in the goal mouth. If it hits the boards: the glass shakes there.
- **The bots with it and against it:** the rink core says "Bots never hold one" (CARTRIDGE.md:475), and it has no
  dive verb (a new verb is C++, CARTRIDGE.md:221). So a bot's meteor and a bot's dive are not data. Through data the
  bots answer the wind-up: they body-check every chance (`ai.body_check` 1, already), and the wind-up makes the shooter
  easy to floor. Asked of the editor anyway, as a person would, to see what it says.
- **Counterplay and cost:** it comes back 12 s (720 frames) after a use; a charged wind-up is a target for checks; the
  meteor floors your own mates in its way too; it replaces the bubble and the green-spot tricks (the core grants no
  pickup trick while a mode trick is held).
- **Reference:** NHL Hitz (on fire, the puck leaves a trail), Mutant League Hockey (shots that floor bodies), Blades of
  Steel (the slapshot wind-up).

**The sentence a person types** (Create's change box, 800 characters):
> Give me a meteor slapshot on F, instead of the bubble and the green-spot tricks. Press F to light my stick on fire,
> then hold shoot to wind it up: the longer I hold, the harder it flies, and while I wind up I am easy to knock over.
> Released, the puck flies twice as fast as a normal shot, trails fire and smoke, and knocks down every skater it
> passes, rivals, mates and the keeper alike, with a flash, a boom, a short freeze and a camera kick. When it goes in,
> the net bulges and the glass shakes. It comes back 12 seconds after I use it. The rival bots should try a meteor of
> their own from distance, and dive in front of mine to block it.

## Editor round 1: the meteor sentence (05:12:01 to 05:23:43, 11.7 min)

Sent exactly as written above (640 characters; the box takes 800 since b1ee0b1d), through `engine/ui/foreman_run.mjs`
with the `change` flags of `engine/ui/flags/real.json` (claude-cli, sonnet).

- **Path:** full (one builder round on the drawing package `harbour`, its verification, the promotion pictures).
- **Tokens:** 0.77M in (0.71M cache reads), 7.6k out: the Planner 3.9k, the harbour builder 768k (1.7 min).
- **The Planner named `harbour`** (event 1008): "the harbour package owns those power-ups along with the main game
  script, the tuning data, the bot test and the drawing code". The power-ups are the cartridge's.
- **The builder's note** (event 1012), in its words:
  - "RULE: not done ... It needs `data/harbour.cartridge.json`, which is outside my scope. The owner of that file needs
    to make `game.abilities` one `shotgun` entry with trigger `mode` ... and `cooldown_frames` 720, and remove the two
    pickup trick entries." Right, and exact.
  - "RULE: not done, and the cartridge has no key for it ... winding up longer for a harder shot, being easier to knock
    over while winding up". **Wrong:** `shot.charge_frames_max` / `charge_speed_bonus` (CARTRIDGE.md:109-110) and
    `contact.spin_stability` ("during a spin or with a full shot wind-up", :394) are exactly those keys.
  - "The rival bots trying a meteor from distance and diving in front of yours are bot decisions inside the core."
    Right (CARTRIDGE.md:475 "Bots never hold one"; a dive is a new verb, C++, :221).
  - "The net bulge and glass shake ... are drawn as a flash at the puck plus a 0.3 m camera kick. The net and the glass
    belong to the base's arena, so they do not move."
- **What changed** (v0.1.22, `data/tuning.json`, `scripts/harbour_toys.gd`, +25 lines): while a cannon shot (the
  green-spot `shotgun` pickup, x1.5) flies, `nitro_flame` and smoke puffs every 3 frames behind the puck; an orange
  flame puff at the skater while it is armed; on a knockdown in its flight a white flash, the "break" sound and a
  0.15 m kick; on a goal right after it a bigger flash and a 0.3 m kick. The cartridge is byte-equal to v0.1.21's: F is
  still one bubble, the meteor is still a 1-in-3 green-spot pickup, no cooldown, no charge.
- **Outcome:** the job ended **done** and promoted v0.1.22 (event 1042). The what-changed note quotes the three "RULE:
  not done" lines (event 1039), so the person is told; but the one part the editor could make in two minutes, the
  cartridge, was never handed to its owner.

```
blocked-editor: a play change (the meteor on F in place of the bubble, a 12 s cooldown) went to the drawing package; its
builder named the cartridge edit word for word and the job promoted v0.1.22 without it, the request not carried to the
cartridge's owner | evidence: job events 1008, 1012, 1039-1042
blocked-editor: the builder told the person "the cartridge has no key" for a harder shot by holding and for being easier
to knock over while winding up; the cartridge has both (shot.charge_frames_max / charge_speed_bonus; contact.spin_stability)
| evidence: job event 1012; engine/cores/rink/CARTRIDGE.md:109-110, :394
```

Core finding (not the editor's fault): **the rink core cannot give a bot an ability or a dive.** `game.abilities` is
the human's only ("Bots never hold one"), and every bot decision is thirdjam's C++ brain. A bot's meteor and a bot's
dive to block need a core patch (`native/patches-thirdlife`, a rebuild); this lane never touches engine/cores.

## By hand: `.tl/juice/arsenal_hand/` (v0.1.22, from the job's v0.1.21, built 05:13 to 05:25 in parallel)

Built with the TL* API and the cartridge's own keys only; nothing in engine/, foreman/ or contracts/ changed.

**The rules (data/harbour.cartridge.json):**
- `game.abilities` = one entry: `shotgun`, `trigger` mode, `magnitude` 2.0, `cooldown_frames` 720. The bubble and the
  three green-spot tricks are gone (a mode trick blocks every pickup trick in the core). The green spots still hand out
  their speed and aim boosts.
- `shot.charge_frames_max` 45, `shot.charge_speed_bonus` 10: holding shoot is a wind-up worth waiting for.
- `contact.spin_stability` 0.6: a skater winding up a full shot stands at 0.6 of his stability, so the rivals' checks
  (`ai.body_check` 1, as before) floor him: the wind-up is the price.
- The skin's `ability_names` {"shotgun": "meteor"}: the base's F plate says "F: METEOR READY". New tagline and HOME lines.

**The drawing (scripts/meteor.gd, 370 lines, presentation only; hooked after harbour.tick in scripts/main.gd):**
- armed: an orange `nitro_flame` on the blade and sparks every 5 frames; the blade fire grows x2.8 with the charge;
- winding up: a ring of orange and gold petals round the skater, 0.7 m growing to 2.3 m with the charge, pulsing at full;
- release: a white-hot flash, a spark fan, smoke, "break" + "nitro" sounds, a 0.35 m camera kick (12 f), METEOR! over
  the shooter;
- flight: a fireball (0.32 m, a white core) on the puck, a style ribbon trail, sparks streaming back every frame and smoke
  every 2;
- each skater it floors (the core's knockdown, cause shotgun): a burst of fire, debris and smoke, a metal clang, a
  0.25 m kick, FLOORED! over him;
- a goal: the net bag (a frame of cords inside the goal) springs out to 1.9 x its depth and back over 1.5 s, the glass
  panes within 16 m rattle, a fire burst and confetti in the mouth, the horn, a 0.55 m kick (26 f);
- the boards: the panes within 7 m rattle, sparks, a glass sound;
- the hint slot: "F: METEOR  Lights your stick. Hold shoot to wind up", "STICK ON FIRE ...", "WINDING UP 73%",
  "METEOR BACK IN 9".
- 66 glass panes on the boards' straight runs (the harbour hides the hall's own glass); the old cannon beads hidden.

**Tests:** `tests/bot_meteor.gd` (new): bot_match_hand's scripted hand, plus F when the meteor is ready and it carries
within 30 m of the net, then a full 46-frame wind-up from up to 26 m. `tests/bot_harbour.gd` left the manifest: it drills
the bubble and its pickups, which this version removes on purpose (it fails "the bubble is still on the cartridge's
timer ... green spots hand out no pair of bubbles"); a behaviour change, named.

## Editor round 2: the rules, in the cartridge's words (05:25:51 to 05:35:25, 9.6 min)

What a person does after reading round 1's note: say it again as rules. My words (465 characters):
> Nothing changed in the match. Change the rules of the match in the game's own settings, not the drawing: F holds one
> trick, the shotgun shot at twice the speed (magnitude 2), and it comes back 12 seconds after each use. It replaces the
> bubble and the three green-spot tricks. Let a held shot charge: full after 45 frames, with 10 m/s more speed at full
> charge. A skater winding up a shot stands at 0.6 of his stability, so a check knocks him over while he winds up.

- **Path:** the cartridge's. The Planner named `cartridge` (event 1046). The quick diff was refused twice by the
  validator (it kept `charges: 1` on a mode entry) and went to one builder round (2.9 min); then the data-only checks
  (lint, smoke, the measured check, one promotion picture).
- **Tokens:** 0.58M in (0.50M cache reads), 7.2k out.
- **What changed** (v0.1.23, `data/harbour.cartridge.json` only): `game.abilities` = `[{shotgun, mode, magnitude 2,
  cooldown_frames 720}]`; `shot.charge_frames_max` 45, `charge_speed_bonus` 10; `contact.spin_stability` 0.6. **Byte
  for byte the rules of my by-hand cartridge.** The builder's note is right and useful: spin_stability also weakens a
  spinning skater; `tests/bot_harbour.gd` (another package's) still drills the bubble and will report it missing; the
  bubble's hint and tagline text are now wrong and belong to other packages; it could not run `check-cartridge`.
- **Not asked first:** the note says "removed: 2 shields ... why: not said", although my sentence said why ("It
  replaces the bubble ..."). No question before the removal (the guard asks only on the diff path).
- **Outcome:** v0.1.23 promoted, done (event 1072). With round 1's drawing (flame puffs behind a flying shotgun shot, a
  flash and a 0.15 m kick on each knockdown in its flight), the editor's game now has a real meteor: F, a wind-up, a
  shot that floors everyone in its path. Still the bubble's words on screen ("F: BUBBLE ..."), no net bulge, no glass,
  no wind-up drawing, and a meteor can be lit at a faceoff and fired at the drop.

So: **the editor made the meteor's rules (round 2) and a thin drawing of it (round 1); the net, the glass, the heat ring,
the fireball, the words and the faceoff gate are by hand.** Two sentences, 21.3 minutes, 1.35M tokens in.

### What the first film showed, and the faceoff gate (05:35)

The first clip (`stills/pregate_sheet_f60-160.jpg`, `pregate_sheet_f800-920.jpg`, 8 frames a tile) had both meteors
**off the faceoff**: the hand lit F at the drop, the drop tap became a meteor, it floored the rival centre and the keeper
and scored from centre ice, twice. Seen by a person: a free goal off every draw, no wind-up, nothing to read. A player
would find that in a minute. So the pack now holds F back during a faceoff and for 60 frames after the drop
(`scripts/main.gd` `_meteor_gate`: the person's own F key filtered out of the raw input; the hint says "F: METEOR lights
a second after the drop"). The core's lab cannot see this gate (it plays the cartridge without the pack), so the lab
figures below are the cartridge without it.

## Proof of the meteor, by hand (as a person meets it)

**Clip** `clips/hand_meteor.mp4` (19.3 s, window 1920x1080, d3d12, seed 1, `tests/bot_meteor.gd`, frames 300 to 1460;
filmed 06:04 with the fireball lifted). `clips/hand_meteor_take1.mp4` is the same run at 05:39 with the sunk fireball.
- `stills/hand3_sheet_f1340-1400.jpg` (4 frames a tile, the final take), `hand3_f1376.jpg`, `hand3_f408.jpg`: STICK ON
  FIRE with sparks at the blade; WINDING UP 7%, 16%, 24% as the gold-and-orange heat ring swells round him; the
  release flash; a whole orange ball in the air over the puck with a white flame tail that runs to the net; METEOR!
  over him, GOAL with sparks over the net. This is the take that reads: you can follow the fire from stick to net.
**Stills I looked at:**
- `stills/hand2_sheet_f1300-1420.jpg` (8 frames a tile) and `hand_f1316.jpg`, `hand_f1362.jpg`, `hand_f1372.jpg`,
  `hand_f1380.jpg`: F at 30 m: "STICK ON FIRE  Hold shoot to wind up, let go to fire" and sparks off the blade while he
  carries in; "WINDING UP 16%" with the gold-and-orange heat ring under him; the release is a white-hot flash round the
  whole figure, METEOR! over him, the commentator "That one was loaded."; an orange ball with a fire tail goes to the net
  in under half a second and the GOAL banner comes up with sparks over the net; "METEOR BACK IN 11", "F: METEOR 11s".
  It reads at a glance: you see it lit, you see it charge, you see it go. The fireball in this take sat half sunk in the
  ice (an orange dome): lifted to sit on the puck after this film.
- `stills/hand2_sheet_f330-450.jpg`, `hand_f404.jpg`, `hand_f412.jpg`: a meteor fired across the ice into the side
  boards: the rival in front and one of my own mates go down in a spray of fire and smoke, both FLOORED!, and the fire
  trail runs along the boards. Felt: the best moment of it, a pile of bodies and a streak; the mate on the ice is the
  meteor's own price.
- The net bag and the glass rattle exist and run (counts below), but the follow camera is 20-30 m from the far net, and
  in these takes a bulge or a pane that moves 12 cm is not something I could see. They need a closer camera or bigger
  numbers to read.

**Headless, 3600 frames, `tests/bot_meteor.gd` (the scripted hand; bots never hold it):**

| seed | meteors fired | skaters floored (rivals / mates / keeper) | meteor goals | board hits | hand downed while lit | script errors | run hash / core hash |
|---|---|---|---|---|---|---|---|
| 1 | 3 | 3 (2 / 1 / 0) | 1 | 3 | 0 | 0 | 097fcaa8... / 8a2b5987... (twice) |
| 2 | 5 | 2 (1 / 1 / 1) | 1 | 7 | 0 | 0 | |
| 3 | 2 | 0 | 2 | 0 | 0 | 0 | |

- **Uses per minute:** the hand 2 to 5 (cooldown 12 s); **the bots 0** (the core gives them no ability).
- **Determinism:** seed 1 twice gave the same run hash (097fcaa8, after the last drawing change; c651f4fb before it with
  the same core hash 8a2b5987: the run hash covers the drawing's bodies, the sim is untouched by it) and before the gate
  b7b4b1a3 twice.
- **The pack's other bots:** smoke 3600 f passed; bot_first_match, bot_skin, bot_toys ok; bot_header and bot_hint are
  not in the manifest (as in v0.1.21); bot_harbour taken out (the bubble drill, see above).

**Lab (the core's playtester, the cartridge alone, no faceoff gate; 40 seeds; a scripted hand measures the game, not a
person):**

| level | wins with F / without F / bare rink | goals for:against with F | F a match | knockdowns a match, with / without F |
|---|---|---|---|---|
| pro | 39 / 23 / 28 | 12.7 : 5.7 | 14.8 | 34.2 / 20.8 |
| all_star | 40 / 37 / 30 | 14.9 : 4.3 | 15.0 | 29.7 / 16.5 |

A 20-second cooldown changes little (pro 37 / 23, 10.3 a match). The meteor decides matches: with this playtester it
wins 16 more of 40 at pro. That is the crazy the night asked for, and it is too strong for a fair match; the gate
removes the cheapest of it (the drop), and the wind-up price (stability 0.6) was never paid by the scripted hand in 3
minutes (downed while lit 0 of 10 lightings).

## The editor's meteor (v0.1.23), as a person meets it

Filmed from a copy of the promoted pack (`.tl/j1-raw/editor_v0123`) with one test added to its manifest,
`tests/bot_meteor_blind.gd` (the same hand; it cannot read the meteor's state, since v0.1.23 has no read-out, so it presses F
every 4 s at most while carrying near the net). Seed 1, 3600 headless frames: 0 script errors, run hash b812a58d; the
harbour's marks count 4 cannon shots and 7 skaters flattened in the minute (two of the shots are off a faceoff drop).

- **Clip** `clips/editor_v0123_meteor.mp4` (19.5 s, frames 960 to 2130).
- **Stills I looked at:** `stills/editor_sheet_f2000-2120.jpg`, `editor_sheet_f60-180.jpg` (8 frames a tile).
  "CANNON LOADED - SHOOT" in the hint, "F: SHOTGUN  NEXT SHOT" on the plate: two names for one trick, neither of them
  meteor. A small flame puffs at the skater's feet while it is loaded; the old orange bead ring appears round the puck;
  the shot leaves with no flash at the stick, a white flash on the keeper as he goes down, the GOAL banner. The keeper
  lies flat after it (the core's knockdown, the same as by hand).
- **How it feels:** a strong shot with a cannon's name. It does what the meteor does in the match (the same rules), and
  the screen says little of it: no wind-up to see, no fire to follow, no word on the fallen, no net or glass. A person
  would learn F is a big shot; not that it is a meteor.

## Verdict: what came from the editor, what by hand

| part of the meteor | editor | by hand | notes |
|---|---|---|---|
| F lights a shot that floors every skater in its path, x2 speed, back after 12 s, replaces the bubble | **v0.1.23** (round 2, the cartridge, 9.6 min) | the same keys | round 1 sent it to the drawing package, which could not make it |
| a held shot charges (45 f, +10 m/s) | **v0.1.23** | the same keys | round 1's builder said "no key"; there is one |
| easier to floor while winding up (stability 0.6) | **v0.1.23** | the same key | the scripted hand never paid it (downed while lit 0) |
| fire behind the flying shot, a flash and a kick on each knockdown | v0.1.22 (thin: puffs every 3 frames, a white flash) | fireball, ribbon trail, sparks and flame every frame, smoke, FLOORED! words, metal clang | |
| burning blade, heat ring growing with the charge, hint lines | no | **by hand** | |
| release blast, boom, METEOR! | no | **by hand** | |
| net bulge, glass that shakes | no ("the net and the glass belong to the base's arena") | **by hand** (own net bag, 66 own panes) | exist and run; too small to see at the follow camera's distance |
| one name on screen | no (CANNON in the hint, SHOTGUN on the plate) | **by hand** (METEOR everywhere, skin ability_names) | |
| no meteor off a faceoff drop | no | **by hand** (`_meteor_gate`, F held back 60 f after the drop) | found by looking at the first film |
| bots light their own meteor; bots dive to block | **cannot** | **cannot** | rink core: "Bots never hold one"; a dive is a new C++ verb. A core patch, not a pack |

**How it feels to a person (by hand):** the best of it is the read: the stick catches fire, the ring swells while you
hold, the flash and the word tell you it went, and you see bodies drop in a line. It is a cannon in this game more than
a tactic: with 12 s between them a player will spend every one, and the lab says it wins most matches. The net and the
glass are not yet felt.

**Best pack:** `.tl/juice/arsenal_hand` (v0.1.22 by hand, over the job's v0.1.21). The editor's best is
`promoted/game.three_against_three_hockey@0.1.23` (same rules, thin drawing, two names for the trick).

## Next three things this lane would do
1. Make the net and the glass read: a goal camera beat (a 20-frame cut to the net) or a bulge of 1 m and panes that
   flex 40 cm; send it as a sentence to the drawing package first.
2. A core patch for the bots (Director's call, not a pack): a bot `shotgun` from distance at the regular level and a
   block reaction (a skater who sees the lit stick steps into the lane or away), so the game answers the meteor.
3. Balance with a person: 20 s cooldown plus a minimum charge before it fires (a tap is not a meteor), measured
   through `TLHand` regular and newcomer, not only the perfect playtester.
