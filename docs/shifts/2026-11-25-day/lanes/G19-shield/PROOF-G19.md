# G19 proof: Shield wall from scratch through Create (evening of 25 Nov 2026)

Tree `.claude/worktrees/d25-shield` (branch d25-shield, main 8f7cbbf: every editor fix of the day, H1-H1j, H2-H2e).
Jobs root `.tl/jobs/`. Every step went through `engine/ui/foreman_run.mjs` in the order of `engine/ui/foreman_door.gd`
(Create's door: new; react... approve, plan, run; quality / phase; change) with the flags of `engine/ui/flags/real.json`
(claude-cli, sonnet, subscription max). Logs in `.tl/jobs/_ui_logs/`, helpers in `.tl/bin/`. No code edited. Times
are local (CET; the job log is UTC, one hour behind).

Targets: `docs/shifts/2026-11-24-night/concepts/shield_wall_screenshot.jpg` (followed) and `..._concept.jpg`: three
stocky sailors in blue quilted jackets and flat caps (the captain with two cream tassels), blue shields with a white
wave, against three in mustard-gold with sun shields; a pale stone harbour court with blue side lines and a white arc,
a wooden sea gate with spray at the far end, boats, a canvas awning, barrels and crates; a score 2 | 00:48 | 1;
RMB BLOCK / LMB BASH / Q CALL; a teal ring under my captain. hokej is the middle third of each `*_vs_target_hokej.jpg`
(E5's strip, row 3, col 4); the left third is the target screenshot, the right third is mine.

How I look: there is no keyboard here, so "play" is the pack's own player bot (`tests/bot_player.gd`, the captain's
part as the pack wrote it) and its tofu bot (`tests/bot_tofu.gd`), headless for the figures, then the same bot filmed
in a window with the follow camera `play`: 16 frames one second apart (`--strip=16x60`, HUD on) and a still at frame
1500. Script: `.tl/bin/film.sh`.

## 0. The sentence and the cards (20:52 to 21:03)

Typed in Create (Standard, not "Build straight through"):
> shield wall: 3 v 3 team melee with shields on a sunny stone harbour court by the sea: block, bash, flank, and a
> captain's call that rallies your crew

- **Design: 9.7 min** (concept 1 call, designer 3 calls, review 2: "revise" (fit 0.45), then "ok" (fit 0.69)), about
  270k tokens in. Candidate 1 of 4 (0.82), template `duel` (For Honor and Dark Souls melee, three a side, on the
  DUEL-PLAYBOOK core: the house duel pack is the reference, as the brief says it should be).
- Pitch: "I captain a shield crew: block, bash, flank, and sound the horn that turns the brawl."
- Create's pitch shows the estimate: 8 parts, 600 min, 6 M tokens.
- **7 cards**: You Are Captain (two AI mates), Shield Answers (block, parry tap, bash), Soft Backs (rear 120 degrees
  ignore block: the flank), Captain's Horn (the call: charges on blocks, mates roar and charge, rivals near fall),
  The Salt Gulls (Bram the wall, Sable the duelist, Pip the dancer), Harbour Court (16 x 12 m, parapets, splat on
  stone), Shoulder View. A serious design: frame tables, a 30-second opening, kill lines.
- As a person, looking at my picture, I kept all seven, with notes:
  - captain: "three stocky sailors in blue quilted jackets and flat blue caps, my captain has two cream tassels on
    his cap, our shields are blue with a white wave";
  - shield: "keep it simple like my picture: hold right mouse to raise the shield, left mouse bashes, Q is the
    captain's call";
  - horn: "call it the captain's call; when I call, my two mates rally to me and charge together";
  - rivals: "one rival crew of three in mustard-gold quilted jackets and caps with a sun painted on their shields,
    built like mine; keep their different habits";
  - court: "like my picture: pale paving stones with blue side lines and a white centre circle, a big wooden sea gate
    at the far end with spray coming through, boats moored on the left, a canvas awning, barrels and crates";
  - camera: "behind and above my captain, centred, looking down the court to the sea gate, so I see all six fighters
    at once; steady, no swinging".
  Build it.

## 1. Plan and phase 1, the tofu (21:03 to 21:39)

- Plan 3.4 min (113k in): 4 packages in 4 phases: core (tofu: the captain against Bram, "copy and edit
  ref/packs/duel"), crew (3 v 3), rally (the captain's call and the match arc), harbour (the look). My decisions
  arrived in the contracts: "hold right mouse raises shield, left mouse bashes"; "CAMERA (player's decision, overrides
  shoulder view): behind and above captain, centred, yaw fixed"; blue against mustard-gold.
- core r1 (4.9 min) and r2 (3.4 min) were refused by the tofu gate (skill_spread 0.20, skill_variants 2, idle 124 f,
  pressure_waves 1, lead_change_share 0, close_rounds 0). r3 merged (the gate yields after two rounds). The builder's
  answer to the bound: "after the captain's shield stops a blow, Bram's next string is replaced by a single charged
  heavy with probability 0.8".
- The blockout critic is now judged against the **house duel**, not the house hockey: it listed 3 missing duel contact
  rows and waived 118 as the duel's own play. G5's "49 hockey rows for bumper karts" is gone (H1's fix holds here).
- Its notes are what a person sees: the bodies fuse into one clump at contact, nobody is pushed back, sparks land on
  the floor, the shield is held beside the head, not between the captain and Bram, HUD labels sit on the bodies. Two
  revise rounds (core r4, r5) merged; r5 also changed `tests/bot_tofu.gd`, the builder's own measure.
- **Paused: quality at 21:39**, 36 min after Build and 47 min after the sentence (G5: 50, G2: 89). 6.6M tokens in
  (5.4M cache reads), 242k out, weighted 2.0M.

**What I saw at the hold** (`stills/p1_tofu_strip.jpg`, `p1_vs_target_hokej.jpg`; the player bot, 2,219 frames:
blocks 6, bashes 3, damage 30; frame p50 0.85 ms):
- A blue captain with a white round shield and a short blade against a mustard Bram with a plank shield and a hammer,
  on a pale tiled court inside low walls with red caps, crates outside, an orange ground and a sunset-pink sky. The
  camera is high behind me and steady (yaw 0 deg/s, as I asked); no sea is in view.
- At contact the two bodies press into one another and overlap; I cannot tell a block from a hit. The captain is
  floored three times and loses round 1 at 77 s, 98 -> 0, while Bram stays at 107: I never see why.
- "Gulls take the round" is printed over the stamina rows; "107 | 100" floats over Bram with no labels; "YOU" floats
  between us.
- The tofu bot (3 rounds): close rounds 2, lead changes 0.5, 7 contact kinds, verbs block 32, light 26, heavy 11,
  bash 5. The figures say a duel; the film says two statues touching.
- Would I play again? No: I lose and cannot see why, and the bash I asked for does nothing visible.

Gap to the target, three lines:
1. Contact: the target is two shields slammed together, each body answering; here the bodies overlap and freeze.
2. The crews: one blue and one mustard figure, toy kids with brown hair, no caps, tassels, waves or suns.
3. The place: a sunset box with an orange ground; the target is a sunny stone quay, a sea gate, boats and an awning.

On Create's quality card I pressed **Change it** (behaviour first):
> When Bram's hammer hits my raised shield I want a loud clang and him bouncing back a step, and when I bash, he gets
> shoved back two steps and staggers with his shield flung wide open so I can hit him. Right now we just press into
> each other and our bodies overlap, and I lose without seeing why. Keep the two of us apart at contact.

- The machine had no room from 21:58 to 22:22 (CPU 72-100 %; a foreign `find.exe / -name ...` had run since 16:15),
  so the change started 24 min after I wrote it. The Planner routed it to core in 3 s.
- core r6 (7.8 min, 2.6M in, 36k out) merged on the first try. The builder's note says exactly what it did: the
  minimum centre distance 0.9 -> 1.4 m, a blocked heavy bounces the attacker 0.8 m, a bash pushes 1.6 m and opens the
  guard 45 frames, the clang layers metal and stone over the wood thud, new reason hints ("Red rim: that blow goes
  through a shield. Parry it or SHIFT away"; "OPEN: HIT NOW"). It also says what it did not do (the new values are
  not declared as params) and what to check by ear (a parry uses the same metal sound). **Create shows none of this
  note to the person** (blocked-editor line). Phase tofu done at 22:31.

**What I saw after the change** (`stills/p1b_tofu_strip.jpg`, `p1b_bash_f860_3f.jpg`: the bash at frame 860, three
frames a tile, HUD off):
- The bash now reads: my captain drives Bram into the wall, his plank shield swings out wide, he splats against the
  parapet, a gap opens between us and "OPEN: HIT NOW" comes up. Bram loses health for the first time (107 -> 91).
- Between bashes the two still stand chest to chest at the clinch, and I still lose round 1 at 76 s (68 -> 0).
- The reason hints are right, but they are printed over the stamina rows, two lines on top of each other.
- Would I play again? Once more, for the bash; I still do not know why I keep falling.

This first change moved exactly what I named, in 9 minutes of building.

## 2. Phase 2, crews: 3 v 3 (22:44 to 22:52)

- Passed phase tofu at 22:44. **crew** (Oda and Finn with me; Sable and Pip with Bram) merged r1 in 7 min (1.8M in).
  Frame p50 1.90 ms with six bipeds: H2c's solo budget for a game made in Create holds, so G4's stop on the 1.0 ms
  "one of many" budget does not come back.
- The builder's note is honest and a person should read it, but Create does not show it: "mate hits do only 15 %
  damage ... Finn's flank cut now looks right but barely hurts; a person should judge this"; "from the captain's third
  light in a row, damage is x0.2 ... nothing on screen or in the body explains it"; "mates may look passive"; "the
  captain was taken down repeatedly ... it may be too hard for a newcomer".

**What I saw** (`stills/p2_crews_strip.jpg` follow camera, `p2_crews_side_strip.jpg` side camera; `tests/bot_crew.gd`,
4,770 frames, frame p50 1.69 ms):
- Six figures, three blue and three mustard, but all six are the same brown-haired toy kid; only the jacket tells the
  crews apart. A "100 | 100" pair floats over every head, six of them at once, plus "YOU", "HIT FROM BEHIND/SIDE" and
  "OPEN: HIT NOW" labels.
- The follow camera keeps the whole fight in view. The side camera shows a quay, sea, red flags and a crane at sunset.
- The fight is a moving scrum in the middle of the court. "Hit from behind: shields only guard the front" appears
  as a hint, so the flank exists, but on film it is text, not a body thrown off its feet.
- My captain goes from 100 to 5 health in 15 s; the crew bot round ends with no winner named.
- Would I play again? Not yet: I cannot find myself in the clump and I die without seeing who hit me.

Gap to the target, three lines:
1. Readability: six identical toy kids under a forest of numbers; the target has two crews you read at a glance.
2. Contact in the crowd: a scrum with labels; the target shows shields meeting and a flanker running round.
3. The look: unchanged since phase 1 (sunset box, toy kids, no caps, sun or wave shields).

## 3. Phase 3, the captain's call (23:19 to 23:40)

- Passed phase crews at 23:19 (10 min waiting for room). **rally** (charge, the call, the surge, the match arc) merged
  r1 in 7.7 min (1.9M in). The greybox critic said NOT ok for the same things I saw (HUD lines over each other, a
  number pair over every head, health drops with no body answer) and sent core r7: it merged in 6 min (HUD reworked,
  bigger parry and blocked-heavy sparks, a parry bounce). Phase call done at 23:40.

**What I saw** (`stills/p3_call_strip.jpg`, `tests/bot_call.gd`, 5,401 frames, p50 1.80 ms: first call at frame 479,
2 rivals floored, 2 charges together, 4 mate hits, 2 later calls):
- The HUD is readable now: "CAPTAIN'S CALL |||||| READY" in gold at the top left, the score and clock on their own
  line, the hints in a band above the panels, small tick bars over heads instead of number pairs.
- The call shows: a ring of gold dashes bursts around my captain, a rival goes down, my mates close in.
- "Q: captain's call" stays on screen for the whole round, even when the meter is empty.
- Still six identical toy kids in a scrum; the flank is still a line of text more than a body knocked off its feet.
- Would I play again? Perhaps once, to blow the call; the brawl around it still does not read.

## 4. Phase 4, the harbour, and v0.1.0 (23:42 to 00:08)

- Passed phase call at 23:42. **harbour** (the look) merged r1 in 5 min (1.2M in). The art_pass critic said NOT ok
  (the camera hides the exchange, downed bodies lie through the wall, a hit without a reaction) and sent core r8
  (lean angles up, the weapon flung on a hit, a shock ring), merged. Phase harbour done 00:03.
- I passed it; final verification (lint, smoke, invariants, five bots) and **v0.1.0 promoted at 00:08: 3 h 16 min
  from the sentence** (G2: 3 h 18 min; G4 and G5 had not reached a version at this point), of which about 50 min
  were waits for room on the shared machine. 11 rounds, 4 critic verdicts, 1 quality hold, 0 builder questions,
  0 thrown-away rounds after r2. Ledger: **17.0M tokens in (14.9M cache reads), 430k out, weighted 4.0M.**

**v0.1.0 as I saw it** (`stills/p4_harbour_strip.jpg`, `p4_vs_target_hokej.jpg` (follow camera at frame 1500, which
caught a pulled-back moment), `p4_side_vs_target_hokej.jpg`; `tests/bot_call.gd`, 5,401 frames, frame p50 2.0 ms):
- The biggest step toward the target: a pale tiled court standing in a blue harbour, blue side lines, a white centre
  circle, a wooden sea gate at the far end, a blue-and-white striped awning, crates and barrels along the walls,
  boats moored to the left. The sailors wear caps; my crew's shields are blue with a white zigzag wave.
- The six are still the same toy kid (only jacket and cap differ), with big blue blocks on their backs; the sky is a
  sunset, not noon; the follow camera is high above, so the fighters are small.
- The fight is still a scrum in the middle; when health drops, the hit body mostly does not answer, and the flank is
  a hint line ("Hit from behind: shields only guard the front") more than a body knocked down.
- Would I play again? Once, for the harbour and the call. Not twice: I still cannot read who hit whom.

Gap to the target, three lines:
1. Contact in the crowd: health falls with no body answer; the target shows shields meeting and a flanker running in.
2. The fighters: identical toy kids with blocks on their backs; the target has stocky quilted sailors, a tasselled
   captain, gold sun shields.
3. The light and the view: sunset, high and far; the target is bright noon, low behind the captain.

## 5. Change round 1 (behaviour: every hit shows in a body) -> v0.1.1

Typed in the change box at 00:12:
> Every hit has to show in the body that takes it. A blow from behind should throw the fighter forward onto his face,
> a hit from the side should spin him half round and make him stumble, and a blocked blow should knock both fighters
> a step apart. Right now health bars drop while the bodies just stand there, and in the crowd I cannot tell who hit
> whom.

- Started 00:16 (room), routed to core in 4 s. core r9 (4.4 min) was refused by the tofu gate (skill_spread 1.0,
  close_rounds 0). core r10 (6.1 min) merged; to get a close round it **added a rule nobody asked for**: "last_stand_k
  = 2.5: hit damage is multiplied by 1 + 2.5 x (how many more fighters the other side has standing) ... nothing new on
  screen announces it" (blocked-editor line).
- The final verify tripped the 250 ms tick watchdog twice on the busy machine (256 ms, 254 of it processor time);
  both passed on the Foreman's own retry. **v0.1.1 promoted 00:41: 25 min, about 3.2M tokens in.**
- On promotion the job carries "[foreman] what changed in v0.1.1 ... what you will see, in the builder's words" with
  the first three lines of the builder's note ("Backstab now always knocks the victim down ... A person should judge
  whether too many hits floor") and "(and 15 more in its note)". So a version does tell the person something; the
  hidden comeback rule is in the 15 not shown.

**v0.1.1 as I saw it** (`stills/v011_strip_play.jpg`, `v011_strip_side.jpg`, `v011_vs_target_hokej.jpg`;
`tests/bot_call.gd`, 5,401 frames, p50 1.94 ms):
- Hits now show: on the side strip two fighters are thrown flat in a puff of dust in one second, a mustard Gull goes
  down on his face after a blow from behind, bodies stumble apart. I can tell that something happened, and to whom.
- So many go down that the court is often half bodies on the floor; my captain still goes from 100 to 1 health in
  about 15 s while Bram stays near full.
- Would I play again? Yes, once more: the knockdowns are fun to watch. But I die too fast to play my own part.

Gap to the target, three lines:
1. The fight's shape: a heap around my captain; the target is pairs squared up shield to shield, a flanker running.
2. The fighters: identical toy kids with blocks on their backs, not stocky quilted sailors.
3. Light and view: sunset and a high camera, not noon and low behind the captain.

## 6. Change round 2 (behaviour: pairs, not a heap) -> v0.1.2

Typed in the change box at 00:48:
> Make it a fair fight between two crews. Each rival squares up to one of us, shield to shield a step or two apart,
> and fights his own man; they take turns and never all three gang up on my captain. My two mates stay near me and
> fight their own rival, and one of them runs round behind a rival only when that rival is busy with me or I have
> just bashed him open. Right now everyone piles onto my captain and I am down in fifteen seconds.

- The Planner routed it to **crew** (the AI's own package, `scripts/crew/mind.gd`) in 4 s: the right owner.
- crew r2 (7.5 min, 1.4M in) merged on its first try: fixed pairs (Bram on the captain, Sable on Oda, Pip on Finn),
  rivals take turns with a 30-frame gap, a third rival stands off 4.2 m, Finn flanks for at most 150 frames on my bash
  or when my rival is busy with me, mates stay within 3.8 m, a fighter standing still raises his shield. The builder
  again names what a person should judge ("rival hits on AI mates do 30 % damage, so the side fights last"; "25
  backstabs in the bot run, the 'who hit me from behind' kill line still needs a hand test").
- **v0.1.2 promoted 01:01: 18 min, about 1.6M tokens in.**

**v0.1.2 as I saw it** (`stills/v012_strip_play.jpg`, `v012_strip_side.jpg`, `v012_vs_target_hokej.jpg`;
`tests/bot_call.gd`, p50 2.05 ms):
- The fight now has a shape: three pairs side by side along the court, blue facing mustard, a flanker slipping round
  now and then. My captain keeps 88 of 100 health over the same 15 s where he used to fall to 1.
- Bodies still go down with dust when hit from behind, but no longer in a heap on top of me.
- The six still look the same (toy kids with blocks on their backs), so the pairs read by jacket colour only.
- Would I play again? Yes: for the first time it looks like two crews fighting, and I last long enough to bash and call.

Gap to the target, three lines:
1. The fighters: toy kids with blue/yellow blocks on their backs; the target's are stocky quilted sailors, a captain
   with two cream tassels, gold shields with a sun.
2. Light: a sunset; the target is bright noon on warm stone.
3. The view: a high camera far behind; the target is low behind the captain, with a teal ring under him.

## 7. Change round 3 (the look: the sailors and the noon light) -> v0.1.3

Typed in the change box at 01:05:
> Make the fighters look like my picture: stocky sailors in puffy quilted jackets with a brown belt, baggy trousers
> tucked into boots, flat round caps; my crew in deep blue with blue shields and a white wave, the rivals in mustard
> gold with gold shields painted with a dark sun. My captain wears two cream tassels hanging from his cap. Take away
> the big blocks on their backs. And make it bright noon with warm pale stone, not a sunset.

- Routed to **harbour** (the look) in 6 s. harbour r2 (4.7 min, 2.0M in) merged first try. Its note: "the contract
  said no lights or environments, but the change request wins: `TLStyleHall.apply(ctx.root, noon)` moves the style's
  sun overhead"; "the sky and colour grade are still the golden-hour ones ... if it still reads as sunset, that needs a
  further change"; jackets ride the skeleton through `BoneAttachment3D`, "which the kernel API document doesn't
  describe" (a question for the Director: is that a bypass of the TL* rule?).
- **v0.1.3 promoted 01:16: 13 min, about 2.1M tokens in.**

**v0.1.3 as I saw it** (`stills/v013_strip_play.jpg`, `v013_vs_target_hokej.jpg`, `v013_side_vs_target_hokej.jpg`,
`v013_side_crop.jpg`):
- Closer: quilted bands on the jackets, brown belts, boots, round caps; blue crew against mustard; gold plank shields;
  the blocks on the backs are gone; the paving is bright pale stone under a high sun.
- Still the toy kid underneath: round baby faces and brown hair, slim, not stocky; the captain's "tassels" are two
  small sticks; I cannot see a sun on the gold shields or a wave on ours from the play camera. The sky behind is still
  a purple-orange sunset on the side camera, as the builder warned.
- Behaviour is unchanged from v0.1.2 (bot_call figures identical: first call 349, 2 floored, 5 mate hits), as it
  should be for a look change.
- Would I play again? Yes, as v0.1.2; it is nicer to look at.

Gap to the target, three lines:
1. The view: a high, far camera; the target is low behind my captain with a teal ring under him, looking at the gate.
2. The sky and HUD: sunset sky; text HUD; the target has a blue sky, a 2 | 00:48 | 1 score plate and RMB/LMB/Q keys.
3. The bodies: toy kids in quilted jackets, not stocky sailors with big shields.

## 8. Change round 4 (the view and the screen) -> v0.1.4

Typed in the change box at 01:22 (one sentence that spans three packages, as a person writes it):
> Make the view and the screen like my picture. The camera sits low behind my captain, about head height and a few
> steps back, looking down the court to the sea gate, so my captain is big at the bottom and I see the others in
> front of him; a glowing teal ring under my captain's feet. At the top a small score plate: blue score, the clock,
> gold score. Bottom left three key buttons: RMB BLOCK, LMB BASH, Q CALL. Show the Q captain's call hint only when the
> call is ready. And a clear blue noon sky instead of the sunset.

- No room until 01:33. The Planner saw it "spans several packages (camera, HUD, captain ring, sky)" and sent it all to
  **core** "as the root".
- core r11 (2.7 min) did the camera (2.5 m high, 4.4 m back), the score plate, the three keys, the teal ring and a blue
  sky made of hand-built panels ("the kit and style layer offer a pack no way to change the sky"). **The tofu gate
  refused it**: skill_spread 1, lead_change_share 0, close_rounds 0. A view change moved the 1 v 1 balance figures
  (the controls are camera-relative, so a new camera changes how the bots walk), and a person's camera request
  became a balance problem.
- core r12 (6.3 min) answered the bound by making the game harder: "Gull blows on the controlled captain now do 2.0
  times damage"; "new comeback rule not in the contract: a crew behind on rounds deals extra damage"; "the game is
  clearly harder for a person than before ... which the slop list warns against". It was then **refused by the kit
  gate** for the score plate I had asked for ("hand-rolled score or clock (primitive: TLRules)").
- core r13 (2.9 min) merged (the plate kept, the clock still the pack's own countdown). Then the dependency cascade:
  crew's and rally's bots failed on the new core, so **crew r3** divided the mates' damage by core's new multipliers
  ("for mates the two cancel out") and **rally r2** retuned the call. Packages now correct each other's numbers.
- **v0.1.4 promoted 02:12: 39 min (11 of them waiting for room), about 4.7M tokens in.**

**v0.1.4 as I saw it** (`stills/v014_strip_play.jpg`, `v014_vs_target_hokej.jpg`, `v014_side_vs_target_hokej.jpg`;
`tests/bot_call.gd` p50 2.1 ms; `tests/bot_crew.gd` on v0.1.2 and v0.1.4, same seed: the match is over in 5,534
frames instead of 9,532):
- The frame of my picture at last: low behind my captain, big at the bottom, a teal ring at his feet, a small
  blue | clock | gold plate at the top, RMB / LMB / Q keys at the bottom left (Q lights up when the call is ready),
  a blue sky with the lighthouse, and the gold shields now show a dark sun.
- But I see only my own fight: my mates and their rivals are mostly out of frame (the builder said so). The sea gate
  is out of view behind the cranes. "Q: captain's call" still floats in mid-screen when the call is empty, and the
  captain's health panel now sits on the left over the fighters.
- And the fight is harsher again: my captain drops 100 -> 60 in about 4 s and to 58 over 15 s (v0.1.2: 88 over the
  same 15 s). The view change undid part of my round 2.
- Would I play again? I would look at it again; I would rather play v0.1.3, where I last and see all six.

Gap to the target, three lines:
1. The fight: harsher than I asked in round 2, and my mates are out of the frame; the target shows all six.
2. The bodies: toy kids in quilted jackets; the target's are stocky, with big round shields held in front.
3. The place in view: cranes and towers behind the fight; the target looks at the wooden sea gate with spray.

**Added to the menu**: v0.1.3 (a fair fight, all six in view, the sailors' look), the way Create's "Add to menu" does
it: `Dungeons.add_user(<promoted/game.shield_wall_3_v@0.1.3>, "Shield wall", <job>)` into this tree's own list
`.tl/g19-menu/dungeons.user.json`, read back ok. v0.1.4 is the closest to the picture but plays harsher.

## 9. The answer: can a person reach hokej's quality from scratch through the editor alone?

**Not yet; but today's editor does clearly better than it did for G2, G4 and G5.**

Better than for G2 / G4 / G5, with evidence:
- **It reached a version, fast**: v0.1.0 in 3 h 16 min from the sentence (about 50 min of it waiting for room on the
  shared machine), with 0 builder questions and no round thrown away after phase 1. G4 had no version at this point
  of its day; G5 was paused at its last phase after 2 h; G2 took 3 h 18 min.
- **The critic judges by the right house game**: the duel, not the hockey; 3 duel rows asked, 118 waived. Its notes
  matched my eye every time (bodies fused, HUD over HUD, a hit with no body answer). G5's "49 hockey rows for bumper
  karts" did not come back.
- **Six bipeds fit the budget**: p50 1.7 to 2.1 ms; H2c's solo budget holds where G4 stopped.
- **The change box converges on what a person can name in one package**: rounds 1 to 3 each moved exactly what I
  named, in 13 to 25 min, through the right owner (core for hit reactions, crew for the AI, harbour for the look). The
  bash shove, bodies thrown by back hits, fair pairs, quilted sailors: each is visible on film.
- **A version now says what changed in the builder's words** (the first three lines of its note).

Where it stops converging, and why:
1. **The tofu bound pulls the game away from the person's words.** The 1 v 1 balance bounds are checked on every
   core change, a camera change included. To pass them the builders added rules no one asked for and no one can see:
   Bram swaps strings for a charged heavy at p 0.8 (phase 1), a hidden comeback multiplier that "nothing on screen
   announces" (round 1), Gulls hitting my captain 2x (round 4). Round 4 undid part of round 2. G5 met the same bound;
   today it costs fairness rather than whole rounds.
2. **One sentence that spans packages goes to one package, then cascades.** Round 4 went to core; core built the sky
   from hand-made panels because the kit gives a pack no sky, was refused once by the kit gate for the score plate I
   asked for, and its new damage numbers broke crew and rally, which then corrected core's numbers.
3. **Gates refuse what the person asked for, and the person cannot see why**: the score plate as a "hand-rolled score
   or clock". The per-round notes (the hidden rules, "a person should judge this") never reach Create; only a
   version's first three lines do.
4. **The bodies.** Every round dressed the same toy kid; no change made the sailors stocky or the shields big and
   round, because the body is the engine's figure. hokej's skaters were built and tuned by hand.
5. **No hand.** All my "play" is the pack's own bots. No figure or film here says how it feels on a mouse: whether a
   parry tap is learnable, whether the call is worth saving, whether the captain dies too fast for a person.

| version | what changed | time | tokens in | the person's verdict |
|---|---|---|---|---|
| v0.1.0 | sentence -> 4 packages, 4 phases, 4 critic verdicts, 1 hold with my change (the bash) | 3 h 16 min | 17.0M | a harbour and a call; an unreadable scrum |
| v0.1.1 | hits throw bodies down, back hits floor | 25 min | 3.1M | I see who was hit; I die in 15 s |
| v0.1.2 | pairs, turns, mates flank on my bash | 18 min | 1.4M | two crews fighting; I last; would replay |
| v0.1.3 | quilted sailors, caps, gold shields, noon | 13 min | 2.0M | nicer, the same good fight (in the menu) |
| v0.1.4 | low camera, ring, score plate, keys, blue sky | 39 min | 4.7M | the picture's frame; harsher, mates out of view |

Cost of the whole game: 5 h 20 min from the sentence (20:52) to v0.1.4 (02:12); 28.3M tokens in (25.1M of them cache
reads), 594k out, weighted 6.3M; 20 rounds, 4 critic verdicts, 0 builder questions.

Would I play v0.1.3 again? Yes, a few rounds: two crews in pairs, knockdowns from behind, a bash that opens a man, a
call that floors one. It is not hokej: hokej's bodies are its own, its bots make hockey decisions, its look is whole,
and its feel was tuned by a hand. Here the pieces a person names arrive; the balance under them is set by bounds and
bots, and it drifts when the person asks for something else.
