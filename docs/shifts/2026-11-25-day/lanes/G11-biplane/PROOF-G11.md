# G11 proof: Biplane duel from scratch through Create (evening of 25 Nov 2026)

Tree `.claude/worktrees/d25-biplane` (branch d25-biplane, main 8f7cbbf: every editor fix of the day, H1-H1j and
H2-H2e). Jobs root `.tl/jobs/`. Every step went through `engine/ui/foreman_run.mjs` in the order of
`engine/ui/foreman_door.gd` (Create's door: new; react... redesign / approve, plan, run; quality / phase; change) with
the flags of `engine/ui/flags/real.json` (claude-cli, sonnet, subscription max). My own door, waiters and film script
live in `.tl/bin/`; door logs in `.tl/jobs/_ui_logs/`. No code edited. Times are local (CET; the job log is UTC).

Targets: `docs/shifts/2026-11-24-night/concepts/biplane_duel_concept.jpg` and `..._screenshot.jpg`: an orange biplane
with cream wingtips and a goggled pilot in a white scarf; a blue biplane with a yellow tail ahead; orange tracers and
white smoke trails; pear orchards, striped vineyards, a river with a stone bridge, farmhouses and cypresses on rolling
Tuscan hills; HUD 02 | 00:48 | 01, an ENERGY bar, W THROTTLE, a crosshair. (The target screenshot wrongly shows my
plane facing the camera; a chase view sees the tail.) hokej is the right third of each `*_vs_target_hokej.jpg` (E5's
strip, row 3, col 4); the left third is the target screenshot.

How I look: there is no keyboard here, so "play" is the pack's own hands (`tests/bot_hand_*.gd`) and its bot,
headless for the figures, then the same bot filmed in a window with each camera the pack declares: 16 frames one
second apart from frame 240 (`--strip=16x60`, HUD on) and a still at frame 1500 (`.tl/bin/film.sh`).

## 0. The sentence and the cards (20:51 to ...)

Typed in Create (Standard, not "Build straight through"):
> biplane duel: two biplanes dogfight over rolling hills with pear orchards, vineyards and a river; loops, stalls,
> energy fights and tracer fire; my orange biplane against a blue-and-yellow rival

- **Design: 9 min** (concept 2 calls, designer 2, review 2, both "revise": hook 0.65/0.72, fit 0.40/0.45), about
  318k tokens in. Candidate 1 of 5 (0.85), template **`duel`** (Dark Souls / Sekiro / For Honor duel rules "flown as
  biplanes"): parry a long burst by flicking the wings, a posture bar, a ladder of three rivals.
- The camera it chose: **side-on, one vertical flight plane** (a 2D dogfight seen from the side, 96 m x 42 m sky).
- Pitch: "My orange biplane duels blue-and-yellow rivals above orchards: loop, stall, parry, fire."
- Estimate on the pitch screen: 9 parts, about 9 hours, 7M tokens.
- 7 cards: Orange Biplane, Win The Tail, Speed Is Life, Flick And Answer (parry), Blue-Yellow Trio, Vineyard Thermals,
  Side-On Sky.
- As a person, looking at my picture:
  - kept the plane ("an orange biplane with cream wingtips and a round engine cowl, a pilot in leather helmet,
    goggles and a white scarf; the rival is blue with a yellow tail");
  - kept Win The Tail ("getting on his tail is the whole game; loops and stall turns to get behind him");
  - kept Speed Is Life ("W is the throttle and an ENERGY bar sits bottom left; diving makes me fast, climbing slows
    me");
  - **defence -> Roll Or Bleed** ("no parrying bullets with my wings; I get out of his fire by flying: a barrel roll,
    a loop, a stall turn, a dive");
  - **rivals -> One Nemesis** ("one blue-and-yellow rival plane against me, a good pilot, no ladder of three");
  - kept the thermals ("keep it small");
  - **camera -> Behind The Tail** ("like my picture: full 3D, behind and a little above my plane's tail, I see the
    rival ahead of me, the orchards, vineyards and the river with a stone bridge below; a crosshair in the middle;
    score 02 00:48 01 at the top").
- Since the side-on plane was the spine of the whole design, I pressed **Redesign** rather than Build it.
- **Redesign: 12.8 min** (21:01 to 21:14; concept 2, designer 3, review 2, both "revise": fit 0.48/0.52), about
  341k tokens in. Every card choice and note arrived:
  - pitch "My orange biplane out-flies one blue-and-yellow rival above orchards: loop, stall, roll, fire.";
  - a round harvest valley **in full 3D** (300 m across, ceiling 80 m), a river under a stone bridge, pear orchards to
    the north, striped vineyard terraces to the south, houses between, a dry-stone ring wall;
  - the camera 12 m behind and 3.4 m above my tail, fov 55, a crosshair mid-screen; HUD 02 00:48 01 at the top, ENERGY
    bottom left; W throttle, arrows are the stick, Space fires, Shift rolls;
  - one rival (Celeste Vesper, swept blue wings, yellow tail), no parry: a late close roll makes the chaser overshoot.
  - What stayed from the `duel` template: composure and a finisher, a charged red shot, a different defence style per
    round (absorb, counter, dance), AI tiers by series wins, 22-frame tells. Not what I asked, but not against it.
  - It added a "threat swing": the camera swings to a side view when the rival winds up behind me. I left it, to see.
- Estimate: 8 parts, about 8 hours, 9M tokens. **Build it** at 21:15.
- Build it waited 23 min for room (21:15 to 21:38: CPU 84-99 % on the shared machine, the top user a stray
  `find / -name blast_floor_32_pair.png` running since 16:15, not mine).

## 1. Plan and phase 1, the tofu (21:38 to ...)

- Plan 3.4 min: **no card** (no recipe card fits a dogfight), 4 packages in 3 phases:
  - tofu: `core` (kinematic flight, bursts, roll, stall, Vesper's brain, the tail and side cameras; "start from
    seed_paddle's layout") and `first_flight` (the threat swing, the SHIFT lesson, the scripted first 30 seconds);
  - nemesis: `rival_season` (three flying styles, memory, the series, warm air);
  - harvest: `harvest_look` (the valley, dressed planes, sound).
- So every behaviour a dogfight needs (flight model, energy, guns, AI) sits in one first package, written from
  nothing: there is no flight kit part, no plane mesh, no card and no seed for flying.
- core r1 (4.5 min, 835k in) and r2 (4.3 min) were refused by the tofu gate (r1: feedback_f 6 > 3, skill_spread 0,
  skill_variants 1, lead_change_share 0; r2: lead_change_share 0, pressure_waves 1). The builder's r2 note said it
  plainly: "Vesper did not damage the player in the logged runs ... The 'flat circles' kill line currently comes true."
  r3 (4.8 min, 1.38M in) met every bound (lead_change_share 0.5, skill_variants 3) and merged at 21:57, 19 min after
  Build. Frame p50 0.40 ms: two planes are cheap. first_flight r1 (5.8 min) merged at 22:05 first time.
- The core's own note lists about 20 things it did not build, honestly: tracers not drawn (hits land on the active
  frame), one rival style, no warm air, a text HUD, "the venue is flat boxes and hill spheres". None of this reaches
  the person in Create; it sits in the job log.
- **Blockout critic NOT ok** (22:10), and it is right; I looked at its captures (the job's `captures/blockout-*-bot_tofu-strip-f3970.png`): "nobody visibly shoots or gets hit: no capture shows a
  tracer, muzzle flash, torn fabric, smoke or flinch, so the roll dodges nothing"; the rival is lost from the tail
  view ("VESPER >>" text only); the threat swing whips the view so it is hard to tell which plane I am; the hint is
  printed over the ENERGY number. Revise -> core r4. It judged the contact against the house **duel** (sword
  fighters) and told the builder not to add a parry, which is right for my choice.

**What I saw at phase 1, in the job's own captures** (no window of mine yet):
- An orange biplane from behind, square boxy wings with cream tips, a pilot head; a blue biplane with a yellow tail.
  A flat green valley with dark tree clumps, a blue river strip and a stone bridge, purple-pink mountains and peach
  cartoon clouds on a violet sky. It reads as a toy biplane. The orange plane loops (the tail strip shows it go
  vertical and over).
- The HUD is typed text: "00 00:49 00 / rounds 0 - 0", "HULL ##########", "ENERGY ------|---- 0 EXHAUSTED". ENERGY sits
  at 0 EXHAUSTED most of the strip.
- In the tail view the rival is almost never on screen: I fly alone and a text arrow points at her.
- No tracer, no hit, no smoke. A SHIFT ring and a PERFECT ROLL banner happen with nothing to dodge.
- core r4 (critic revise 1, 4.0 min, 1.02M in) merged: red tracer bars, white spark lines, painted HUD bars, a red
  nose on Vesper. The Foreman said what it was: "the look changed, the play did not" (the bots play frame for frame as
  before). To draw the tracers the builder hand-made meshes and materials (bypasses 0 -> 4), since "TLVfx bursts did
  not read in the last captures and draw nothing headless"; the Foreman let it pass.
- Critic NOT ok again -> core r5 (5.3 min, 1.66M in: camera shake on a rolled burst, wobble through hit-stop) was
  **thrown away by the tofu bound** lead_change_share 0.25 < 0.3 (G5's defect, unchanged). The builder's note: Vesper
  "started only 17 attacks in about 14,000 frames ... A newcomer would likely feel a passive rival", and shorter
  attack intervals that would fix it cost the bot its perfect roll, so it kept the long ones.
- **Paused: quality at 22:37**, 59 min after Build (G5: 37 min, G2: 89 min). 8.1M tokens in (6.5M cache reads),
  386k out, weighted 2.65M.

**What I saw at the hold** (my window, `tests/bot_tofu.gd`, the only hand the pack has; `stills/p1_strip_tail.jpg`,
`p1_strip_side.jpg`, `p1_vs_target_hokej.jpg`):
- In the tail view the blue plane is now ahead of me in the first eight seconds, small, with my tracers and bits
  flying off it. That is the first moment that looks like the picture's idea.
- Then "They loop behind you. Fly on." and the two planes close up into a tangle: in the last four tail tiles and the
  last four side tiles the blue plane sits right on top of my plane, wings through wings, while a "<< VESPER" arrow
  points away from where she is.
- The clock stands at 01:15 for all 16 seconds (the lesson holds the round). The score line is "00 01:15 00" with
  pips over the digits. ENERGY is a green bar; my bars sit in a small dark box.
- The valley: flat green discs, purple slabs, tan cubes, a blue ribbon river with a stone bridge, pine clumps, a
  violet sky with peach clouds. Toy-like, not the harvest hills.
- The sharp bot: 39 hits landed, 3 perfect rolls, 3 rounds in 16,000 frames; frame p50 0.45 ms.
- Would I play again? Not yet: I cannot read the fight. Either she is far ahead or inside my plane.

Gap to the target, three lines:
1. The fight: no chase. She does not turn onto my tail, shoot and make me break; the planes fly in formation and
   pass through each other.
2. The view: the rival is lost or on top of me; the arrow points the wrong way; the clock does not run.
3. The place and planes: boxy toy planes over discs and slabs, not pear orchards, vineyards and a river valley.

On Create's quality card I pressed **Change it** (22:44):
> The two planes fly side by side and end up inside each other. I want a real chase: she turns hard to get behind me
> and fires a burst every few seconds, so I have to loop, roll or dive away; when I roll late she flies past and ends
> up in front of my nose where I can shoot her tail. The planes must never pass through each other, keep at least a
> plane length apart. And let the clock run from the start.

- The Planner routed it to core in 4 s. core r6 (5.3 min, 1.82M in) did what I asked in its own words: planes kept
  6.5 m apart, the clock runs from frame 1, Vesper breaks away inside 13 m, drops in behind when abeam, attacks every
  100 frames instead of 140, fires when late. **The tofu gate refused it** (skill_spread 0.238 < 0.25).
- core r7 (4.4 min) merged by adding a weave the bound needed: "Vesper alternates full left and right turn every 40
  frames ... when the player is behind her", and wrote: "The player's change request ... was not re-checked this
  round. The new weave ... affect[s] the chase, so a person should judge it again."
- 13 min for the change. Phase tofu done at 22:57, job paused for my verdict.

**What I saw after the change** (`stills/p1b_strip_tail.jpg`, `p1b_strip_side.jpg`; the sharp bot: 42 hits, 2
perfect rolls, 4 rounds in 11,091 frames; frame p50 0.55 ms):
- The clock runs (01:11, 01:10, ... 00:56).
- The side view keeps a gap: the planes pass close but no longer sit inside each other; tracers and bits fly.
- The first 8 seconds are the same scripted lesson (her ahead, my tracers rip her).
- In the tail view, once she loops behind, her blue wings fill the lower frame in front of my plane: the chase
  camera still lets the rival cover me.
- Would I play again? Closer: I can see an exchange now. But I cannot yet tell who is winning the turn fight.

## 2. Phase 2, the nemesis (23:21 to 23:47)

- I passed the tofu phase at 23:21. rival_season r1 (5.0 min, 1.05M in) was refused by the tofu gate (its own note:
  with its files lead_change_share fell to 0 and idle_max_f rose to 136); r2 (5.7 min, 1.31M in) merged at 23:34:
  three styles by round (barn door, fencer, dancer), warm air, the series, an end card. Its note lists what is
  approximate: "When long overdue, [Vesper fires] up to 110 degrees off line ... may look wild to a person", "Round 2
  pressure is still weak".
- The greybox critic NOT ok, and right again: the tail view "looks almost straight down at my plane ... no horizon",
  the rival is lost, "the orange and blue wings cross and the planes merge" at frame 2836, the round pips sit over
  the clock digits, "large rings of white balls ... look like debug markers". core r8 (3.2 min) merged a camera that
  switches to a level three-quarter view in steep loops and close fights, and moved the pips. Phase done at 23:47.

**What I saw** (`stills/p2_strip_tail.jpg`, `p2_strip_side.jpg`; sharp bot: 49 hits, 1 perfect roll, 4 rounds):
- The tail view now cuts to a framed three-quarter view when she closes in: in the last four tail tiles both planes
  are in the frame at once, big and apart, with a tracer between them. That is the first frame that reads as a
  dogfight to me.
- The cut is abrupt: from behind my tail to a view from the side and back within seconds (camera turn p90 134 deg/s,
  max 362; move p90 63 m/s, was 34.5). Whether a person can still steer through it, only a hand on the keys can say.
- Frame p50 0.95 ms (was 0.45), one tick of 17.5 ms.
- Would I play again? I would try a round now. I still cannot tell whether I am winning a turn.

## 3. Phase 3, the harvest valley, and v0.1.0 (23:53 to 00:14)

- harvest_look r1 (5.1 min, 1.17M in) merged first time: planes with wheels, struts, wires, roundels, a scarf; red
  barns, orange field patches, stone ring wall, more trees. It too hand-made meshes ("no kit part covers airframe
  detail").
- The art_pass critic NOT ok: the planes still "drift into each other and merge with no crunch" (frames 2821-2836),
  the perfect roll has no payoff, the crosshair floats, "the 'river' under the stone bridge reads as a grey asphalt
  road". Its revise, core r9 (4.9 min, 1.08M in), did exactly what my first change and the critic both asked:
  "Planes are now held at least 12 m apart ... the higher one lifts and the lower dips". **The Foreman threw it away
  for the tofu bound** (lead_change_share 0 < 0.3) and paused the phase on the old core.
- I passed the phase; the final verification (lint, smoke, invariants, 4 bots) passed and **v0.1.0 was promoted at
  00:14**: 3 h 23 min from the sentence (G2: 3 h 18 min; G4: nothing after 8 h; G5: 2 h 2 min to its last phase).
  16.5M tokens in (14.0M cache reads), 547k out, weighted 4.51M; 13 builder rounds, 4 critic verdicts, 1 hold.
- **Added to the menu** as Create's Add to menu does (`Dungeons.add_user(<promoted/game.biplane_duel_two_biplanes>,
  "Biplane duel", <job>)`), into this tree's own list `.tl/g11-menu/dungeons.user.json`, read back ok.

**What I saw in v0.1.0** (`stills/v010_strip_tail.jpg`, `v010_strip_side.jpg`, `v010_vs_target_hokej.jpg`,
`v010_artpass_side_vs_target_hokej.jpg`; sharp bot 49 hits, 1 perfect roll, 4 rounds; bot_season: one series won
1:0, the fencer attacked 25 times and the dancer 21, warm air once; frame p50 1.09 ms, 264 bodies):
- The play is frame for frame phase 2's: the same scripted 8 seconds, then close turns cut to a three-quarter view.
  Three critic revises on the fight (r5, r9 and the greybox one that merged only a camera) never changed how the
  planes fly at each other after my change.
- The look moved: the planes have wheels, roundels and struts; on the art_pass side capture a smoking blue biplane
  with yellow tail and a banked orange one, both clearly biplanes. The valley: red barns, orange and striped patches,
  a stone ring wall, pines. But the river is a grey road, there are no pear trees I can see, and the sky is violet
  with pink mountains, not blue over Tuscan hills.
- Next to hokej: hokej has bodies that read at a glance and a HUD that tells the score; here the HUD is
  "00 00:50 00" with dots and two small dark boxes.
- Would I play again? Once, to try a loop. Not twice yet: the fight has no moment I want to see again.

Gap to the target, three lines:
1. The fight: no tail chase I can read. She does not sit behind me shooting and I do not get onto her tail; close
   passes still cut the camera to the side.
2. The HUD: "00 00:50 00" with dots, no 02 00:48 01 board, no big ENERGY bar, no W THROTTLE.
3. The place: violet sky, grey-road river, no pear orchards or vine rows, no blue sky over Tuscan hills.

## Does today's editor do better than it did for G2, G4 and G5?

Better, where the day's fixes reached:
- **It got to a playable v0.1.0.** G4 got nothing after 8 hours (the card's hand check failed the first promotion);
  this job has no card, so no hand check stood in the way, and it promoted in 3 h 23 min.
- **The cards and the redesign carried my words.** Every choice and note reached the redesigned brief (full 3D,
  chase camera, one rival, no parry, the HUD of my picture), and the plan contract repeats them. G5 saw the same.
- **The pitch shows the cost** (9 parts, 9 hours, 7M tokens; then 8 parts, 8 hours, 9M), H1b's fix.
- **The change box moves what I name, fast.** Change 1 at the quality card was routed in 4 s and merged in 13 min:
  the clock runs, the planes keep a gap in the side view, she breaks away and attacks more often.
- **The critic judged this game by its own design**, not hockey: it named the house duel's parry and said "do not add
  it", and its notes on what I see were right every time (no tracer, rival lost, planes merging, the river a road).

Not better: the defects G2 and G5 named are still here.
- **Critic revises on behaviour are thrown away by the tofu bound** (lead_change_share >= 0.3): core r5 (camera shake,
  wobble) and core r9 (planes held 12 m apart, the very thing I asked for in change 1) were both lost; the phase
  paused on the older core each time. G5 lost r8, r9 and r10 the same way. The bound also shaped the rival: r7 added a
  left-right weave every 40 frames, and r5 kept her attacking rarely, because faster attacks cost the bot its
  perfect roll.
- **What the builder knows does not reach the person.** Every round's note is honest ("Vesper did not damage the
  player in the logged runs", "the 'flat circles' kill line currently comes true", "a person should judge it
  again"), and none of it is on Create's screen.
- **No kit for flying.** No flight card, no plane part, no tracer effect a pack can use: the builders hand-made
  meshes and materials twice (core fx.gd, harvest.gd), and the Foreman let the bypasses pass because the builder
  said why.

## 4. Change round 2 (behaviour: the tail chase) -> v0.1.1 (00:18 to 01:10)

Typed in the change box:
> After the first seconds the fight goes nowhere: she never sits on my tail shooting, and I never get onto hers. Make
> it a real tail chase like old dogfights: whoever is behind wins. She climbs and turns to get behind me and stays
> there firing short bursts until I shake her with a loop, a stall turn or a hard dive; when I get behind her she
> jinks and climbs to escape, and I can follow her and shoot. Keep the view behind my tail, with her in front of me
> when I chase; when she is behind me show an arrow at the screen edge on the side where she really is, instead of
> cutting to a side view.

At 00:50 the Director reported that v0.1.0 in the owner's exe shows one engine error in 600 frames ('Condition
"p.d == 0" is true. Returning: Point2()', a Camera3D unproject of a point on the camera plane). While the round ran I
added a second change through the change box (it went into the running Foreman's inbox, as Create's box does):
> Part of the tail chase: the marker that points at her must never project a point behind the camera ... When she is
> behind me, show the edge arrow from her direction instead of projecting her.

- **Time 52 min** (00:18 to 01:10), **path full**, **6.1M tokens in** (job total 22.7M in, 623k out, weighted 5.71M).
- The Planner chose core both times, in 3-4 s.
- core r10 (5.7 min, 1.69M in) was refused by the tofu gate (lead_change_share 0). Its note says what it did and did
  not: she "now works round behind you, holds about 18 m back and fires, and jinks and climbs when you are behind
  her"; "**Rounds 2 and 3 use the season package's own brain, which I could not change**"; "**The chase is not
  proven** ... I do not believe she reliably sits on your tail and hits yet"; "Vesper now turns faster than you: x1.4
  while working round ... against the 'same speeds for both planes' rule"; "Camera and arrow: I made no changes ...
  that part is **not done**". It also changed the test pilot's behaviour.
- core r11 (4.1 min) merged by giving her more turn while firing (x1.38): "This breaks 'Vesper uses my verbs,
  frames, speeds'". The brief's own pillar rules out "difficulty from extra speed".
- The merged core broke first_flight's bot; first_flight r2 was refused by the tofu gate, r3 merged (its note: "When
  the lesson ends, both hulls go back to 100 ... a person should decide whether to keep this").
- core r12 (the marker, 4.6 min, 1.07M in) merged first time: the crosshair is no longer a `TLHud.add_tag` widget but
  drawn from camera space and hidden when behind or level with the camera; a drawn edge arrow points to her.
- What the person is told: "what changed in v0.1.1 (since v0.1.0): asked ...", and the files.

**What I saw in v0.1.1** (`stills/v011_strip_tail.jpg`, `v011_strip_side.jpg`, `v011_vs_target_hokej.jpg`):
- The first 13 seconds are the same lesson. In the last four tail tiles she is now above and ahead of me, then
  diving over my nose, her blue wings big in the frame: a pass, not a tail chase. The camera still cuts to the far
  three-quarter view at 01:01 and 01:00 (the part the builder did not do).
- The bots moved: the sharp bot now lands 25 hits (was 49) and makes 6 perfect rolls (was 1) in 3 rounds; in the
  series bot she attacks 38 times as the fencer and 55 as the dancer (was 25 and 21). She is more aggressive, which
  I asked for, and she out-turns me, which I did not.
- My window captures saw 0 engine errors in v0.1.0 and v0.1.1 alike (with a bot flying); the exe repro is the
  Director's (600 frames, no bot), so whether the error is gone needs that same check on v0.1.1.
- Frame p50 1.29 ms (v0.1.0: 1.09).
- Would I play again? I would try a round to see her come at me. I still could not say who is winning the turn.

Gap to the target, three lines:
1. The fight: more attacks, but still passes and cuts, not one plane sitting on the other's tail; she wins by
   turning faster, not by flying better.
2. The view and HUD: the three-quarter cut stays; the score is "00 01:11 00" with dots; no ENERGY bar or W THROTTLE
   like my picture.
3. The place: violet sky, grey-road river, no pear orchards or vine rows.

## Where it stands after round 1 of the lane (v0.1.0 + 2 change rounds)

| version | what changed | time | tokens in | the person's verdict |
|---|---|---|---|---|
| (hold) | quality card change 1: a chase, no passing through, clock runs | 13 min | ~2.8M | clock runs, planes keep a gap in the side view |
| v0.1.0 | sentence -> 4 packages, 3 phases, 13 rounds, 4 critic verdicts, 1 hold | 3 h 23 min | 16.5M | a toy dogfight with no moment worth replaying |
| v0.1.1 | change 2: the tail chase + the marker never behind the camera | 52 min | 6.1M | she attacks more and out-turns me; still no tail chase I can read |

Where it stops converging, so far:
1. **The tofu bound decides behaviour.** Five of this job's core rounds were refused for lead_change_share or
   skill_spread (r1, r2, r6, r10) or thrown away after merge-worthy work (r5, r9). The builders answer the bound by
   weaving (r7), by attacking less (r5), by making her turn faster (r11). What I asked for comes out bent toward the
   bot's figures.
2. **One change, one package.** "The tail chase" lives in core (round 1 brain), the season package (rounds 2 and 3
   brain) and the camera; the core builder did the first and said the rest is "not done", and the job promoted
   anyway. Create told me only the files.
3. **No kit for flight.** Planes, tracers and smoke are hand-made by each builder; the valley's river comes out as a
   grey road and the orchards as dots.
