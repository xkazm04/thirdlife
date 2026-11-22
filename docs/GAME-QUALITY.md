# Game quality: designing a game we could sell (v2, 22 Nov 2026)

This handbook is read by the Designer (concept and design doc), the design review (producer and marketer), the Planner,
the builders and the capture critic. The Foreman pastes its sections into prompts by heading, so each section stands
alone. Every rule here is checkable: a reviewer can point at a line of the design doc, a number, or a motion strip and
say yes or no. Numbers are frames at 60 Hz. A figure from a source says so; a figure without one is a house number.

v2 folds in the research of 21 Nov (`docs/research/`): what made games last (R1-R14, section 8), the anti-patterns
(section 9), the 30-item plays-twice checklist with who can judge each item (section 10), the genre templates every
design copies its core from (section 11) and the tofu stage that kills a core verb which is not fun (section 12). The
owner's ruling behind it: "there are hundreds of duel games (souls like, for honor duels) with well known game design
paths we can mimic". **Copy the proven core; be new only in the hook.**

## 1. Design practice

Design the game before building it, as a studio that has to sell it would.

- **Pillars: three, and each rules something out.** A pillar that excludes nothing is a slogan. Write each as a pair:
  - "Every hit is an exchange" / rules out one-hit knock-downs and hits that only shove.
  - "Skill is in the feet" / rules out speed stats, auto-aim and auto-face.
  - "Failure is fun to watch" / rules out stiff deaths and a fade-to-menu on a loss.
- **Loops at 3 s, 30 s and 3 min, with context that keeps changing.** Griesemer (Halo): not "30 seconds of fun" repeated,
  but a 3-second loop inside a 30-second loop inside a 3-minute loop that is always different. Name what changes the
  context: a new rival type, a hazard, a shrinking arena, a score state. At least three context changers.
- **Verbs with frame data.** Every verb lists input, anticipation, active and recovery frames, and what cancels it. At
  least one verb is defensive (block, dodge, roll, parry, a catch). A game with only an attack is not a fight.
- **Skill floor and ceiling.** One button does something useful on day one; deeper techniques are revealed in order. In
  TowerFall the dodge first avoids arrows, then players find it catches arrows (a parry), then that a dodge can be
  cancelled; Thorson kept the cancel because it added expressive movement. Name three ceiling techniques, in order.
- **Risk and reward windows.** A strong move leaves the user open (long recovery, a whiff that can be punished). Every
  verb's recovery is a window for the other side. A safe best move is a design bug.
- **Playstyles: two or three that play differently.** A grappler who closes and throws, a runner who baits and punishes,
  a guard who reads and counters. They differ in verbs and positioning, never only in numbers (+10 % damage is not a style).
- **Difficulty comes from design.** Harder rivals are more aggressive, hide their tells better, chain patterns, take better
  positions, and team up. Never faster stats, never hidden help (rubber-banding the player, aim assist that plays for him).
  Super Mega Baseball's Ego sets difficulty per skill (pitching, batting, fielding, running), not one speed knob.
- **The first minute teaches by playing.** World 1-1: the first enemy is one that can only walk at you, so the first thing
  the player learns is to jump on it. No menu, no text wall: the arena opens on the first exchange.
- **One-page design doc.** Librande (GDC 2010): a design that fits one page is read; a long one is not. The design doc is
  one page: pillars, verbs with frames, playstyles, loops, skill ladder, feel sheet, three clip moments, first minute,
  fail state, what is out of scope.
- **Animation is part of the design.** Every verb names its clip; a verb without a clip is not designed. A sim rule and the
  figure's reaction are designed together: "a side hit at strength 0.7 tips him away from the blow for 14 f" is one line,
  not a physics line and an art line written by different people.

## 2. Feel numbers at 60 Hz

Each line is a check. The engine call is named where one exists.

- **Hit-stop on attacker and victim together.** Both freeze on the frame a hit lands (Sakurai; SmashWiki: the attacker on
  the hit frame, the victim on the first frame of his flinch). 3-8 f light to medium, scaled by the hit's force, cap
  about 20 (Melee's formula floor(damage/3 + 3) gives 4 f for 3 %, 8 f for 15 %; its cap is 20). Engine: there is no global
  time freeze; the pack holds both actors still (velocity and clip) for N frames, counted in physics frames.
- **The victim vibrates, decaying.** During hit-stop the victim shakes side to side and the shake fades. Visual only: offset
  the victim's visual node, never the body (`TLVfx.squash` is the same rule: visual nodes only).
- **Knockback = base + growth x damage taken, less for mass.** Smash: knockback grows with the victim's damage so far and the
  hit's damage, scaled by the move's growth, plus a base; weight divides it. Engine: `TLBiped.shove(impulse)` adds
  impulse / `body_mass`, so a heavier fighter already travels less; the pack computes the impulse from the rule.
- **A hit reaction every time.** A flinch pose within 4 f (Sakurai: Smash takes four frames from the first flinch into the
  hurt pose); a stumble for solid hits; a knock-down only for big ones, so most hits are an exchange. Engine:
  `TLHit.react(victim, attacker.global_position - victim.global_position, strength)` (about 0.3 a tap, 0.7 solid, 1.2+ big)
  and `TLHit.down(victim, frames, from_dir)` for a floor. Never call `stumble` or `down` directly for a hit.
- **A whiff reads as a whiff.** A miss plays its full recovery, makes its own sound (`TLAudio.play`), and fires no burst. The
  missed fighter is open; the other side can see it.
- **Dodge and roll i-frames from frame 1, with a tell.** About 14-26 f invulnerable. Elden Ring's light or medium roll is
  about 13-14 i-frames at 30 fps (about 26-28 at 60 Hz, per its wikis); a short side step sits at the low end. The figure
  must show it (the `roll` or `dodge` clip), and recovery after it is punishable.
- **Enemy telegraph at least 20 f, hitbox active 2-4 f, a punish window after.** A person's simple visual reaction is 12-15 f
  (API.md, the hands); a telegraph under 20 f cannot be read, only memorised. The tell is the rival's own body (a wind-up
  clip), not a HUD marker.
- **Player anticipation 2-5 f light, 8-10 f heavy.** The heavy wind-up is the price of its power (`strike`, `strike_heavy`).
- **Visible feedback within 3 f, the full pose by 6 f.** Something the player sees answers the press within 3 frames
  (the step, the first frame of the clip, a flash on the weapon); the verb's pose is readable by frame 6 (checklist item
  1, section 10). The tofu bot reports it as `feedback_f` (section 12).
- **Camera shake on meaningful hits only, decaying.** `ctx.cameras.shake(amount, frames)`: about 0.05 a tap, 0.3 a crash.
  A light hit does not shake; a knock-down does. Sakurai: the screen shakes when the move is especially powerful.
- **The camera is never behind scenery and keeps both fighters in frame.** The camera API cannot fade occluders, so place
  it: a raised orbit (`ctx.cameras.orbit`, pitch 30-60 degrees) or a chase camera with `avoid_space` (it never enters a
  body), and cut or lower the scenery on the camera side (a low wall, no pillar between lens and ring). Frame a pivot the
  pack keeps between the fighters (`ctx.cameras.frame(pivot, fill)`); check with `ctx.cameras.subject_px` (0.08 small,
  0.2 clear). Off-screen attackers get an edge arrow (God of War 2018: red for a melee attack from that side); the pack
  draws it on its `TLHud`.
- **Bodies never overlap.** Fighters keep their biped capsules colliding (two bipeds settle about 0.01 m apart; one step of
  overlap is the most the kernel allows). Scale the capsule with the figure (`body_scale`, K2); a figure drawn 2x on a 1x
  capsule is a blob. Bots spread out with `TLSteer.separate`.

## 3. Marketability

- **The line: "<anchor genre> where <hook>".** The anchor is a game a buyer knows; the hook is the one thing that is new.
  "A gladiator brawler where the crowd throws you the weapons." If the hook needs two sentences it is not a hook.
- **The GIF test.** Would a 3-second loop make someone want to play? Landfall on TABS: "When seeing a gif or a video of the
  game, you instantly get a taste of what playing the game will be like", and "physics and destruction seems inherently
  satisfying to see". Design the moment that loops.
- **Capsule first.** Before the build, write the store capsule: title, one line, the one image. If the image is a figure
  standing on a plane, the game is not designed yet.
- **Three clip moments.** Name the three moments a viewer would clip (a counter that sends a rival into the wall, a
  last-second dodge, a pile-up). Each is built, filmed, and judged by the critic.
- **Would anyone play twice?** Name what is different on the second run: a new playstyle, a rival who reads you, a ladder,
  a score to beat. "Nothing" is a fail.

## 4. Lessons from arcade sports and brawlers

- **NBA Jam**: three baskets in a row put a player "on fire" (unlimited turbo, better shooting) until the other side
  scores. Borrow: a streak state the whole screen can see, which the rival can end.
- **NHL Hitz**: open-ice checks are big, loud and part of the play, and the hit player is soon back in it. Borrow: big
  hits with a fast get-up, so a hit is a moment, not a removal.
- **Mutant League**: the field and the rules are hazards, and violence is part of how you win. Borrow: a hazard that
  rewards the player who uses it on purpose.
- **Rocket League**: boost is a resource on the field that serves speed, jumps and recovery; it pays more the better you
  play. Borrow: one resource whose value scales with skill, never a flat speed bonus.
- **Windjammers 2**: Dotemu added a drop shot because players hung back and refused to come forward. Borrow: one verb
  that breaks a passive strategy and forces an exchange.
- **Super Mega Baseball**: Ego difficulty is set per skill (pitching, batting, fielding, running). Borrow: difficulty per
  verb, chosen by the player, never one hidden speed number.
- **For Honor / Absolver**: guard and attack in directions (top, left, right) that must be matched; Absolver chains moves
  through stances. Borrow: a defensive verb that is a read, not a button held forever.
- **Gang Beasts / TABS**: floppy, physical figures; losing balance and being thrown look funny. Borrow: the appealing
  reaction: a failure that is fun to watch, so losing a round is a clip, not a punishment.

## 5. Where LLM-made games fail, and what fixes it

- **Runnable is not faithful.** Spec2Game (2026, 14 models): the best model scored 99.26 on executability but 58.43 on
  specification realization; rules and mechanisms (45.65) and goal and termination (44.05) score worst, dynamic feedback
  fidelity lowest of all (32.10). A detailed spec raised the mean overall score from 50.59 to 68.62 (+18 points).
  Ours: the design doc is detailed and numeric (verbs with frames, a feel sheet), and every builder gets the feel sheet.
- **Mechanics without a game.** GameCraft-Bench (Godot, 2026; the best agent 41.46 %): agents often implement recognisable
  mechanics but struggle to deliver complete games with sufficient content, functional visual feedback and coherent
  presentation. Ours: the first package assembles the core exchange with its whole feel sheet; the critic looks at frames.
- **Stills miss what is wrong.** GlitchBench (CVPR 2024): the best model found about 43 % of game glitches from frames. A
  hit-stop, a shake, a roll or a whiff cannot be seen in a still at all. Ours: the critic judges motion strips.
- **Mode collapse.** Aligned models give the typical answer (Verbalized Sampling, 2025: typicality bias in preference data).
  Asking for five candidates with probabilities raised creative diversity about 1.6-2.1x. Ours: the concept step writes
  five pitches with likelihoods and picks a less typical HOOK that still fits the words. The core loop is not where
  the boldness goes: v1 of this pipeline swapped a proven duel for an invented system and got a generic brawler.
- **Invented cores.** A core loop made up from scratch has none of the tuning thousands of shipped games gave the proven
  ones (the reaction floor, the whiff cost, the punish window). Ours: the concept names ONE genre template (section 11)
  per core loop and the design copies its rules and frame tables word for word; only the hook is new.
- **Defaults nobody chose.** The model's first idea is the genre average. Ours: the slop list (section 6) names the defaults
  to avoid, and the concept names 2-3 reference games and the exact mechanic borrowed from each.
- **One shot is worse than a revised one.** Self-Refine (2023): generate, critique, revise gave about 20 % absolute better
  results on average. Recursive Game Creator (2026): Designer, Builder, Player and Reviewer roles over rounds, the
  Reviewer keeping the stronger version. Ours: a producer review with one revise of the design; a critic NOT ok revises up
  to two rounds, keeps the better version, then holds the job for the owner.

## 6. The slop list

- **`one_attack_button`** The fight has one attack and nothing else. Why: there is no decision, so there is no game. Check: the design lists one offensive verb and no defensive one; the strip shows the same swing every time. Instead: 2-5 verbs with frame data, a light and a heavy with different risk, and at least one defensive verb.
- **`recoloured_rivals`** Rivals are the player's body with another colour. Why: no rival reads as a character, nothing to learn or fear. Check: every fighter in a strip has the same silhouette and the same clips. Instead: each rival type has its own build, a signature verb and tell, and a behaviour the player can learn.
- **`borrowed_clips`** A verb plays a clip made for something else (`shoot` as a strike, `slide` as a roll, `cheer` as a tell). Why: the body says one thing and the rule another; the hit has no anticipation. Check: each verb's clip id against `rig.call("clips")` and the verb list. Instead: the verb's own clip (`strike`, `roll`, `block`...); when none exists, ask for one, never borrow.
- **`hit_without_reaction`** A hit lands and the victim's body does not answer (or only squashes or slides). Why: the player cannot feel or read the hit. Check: the strip frames after contact show no flinch, stumble or fall facing away from the blow. Instead: `TLHit.react` with the blow's direction and strength on every hit, hit-stop on both, a decaying vibration.
- **`camera_behind_scenery`** A wall, pillar or stand sits between the lens and the fighters. Why: a game the player cannot see is not playable. Check: any strip frame where a fighter is hidden or `subject_px` is under 0.08. Instead: raise or place the camera, cut or lower scenery on the camera side, frame a pivot between the fighters.
- **`hud_only_twist`** The twist of the game lives only in the HUD (a label, a timer, a number). Why: nothing in the world changes, so nothing plays differently and nothing clips. Check: hide the HUD; the twist is gone from the strip. Instead: the twist changes bodies, space or rules in the world (a hazard, a weapon, a shrinking ring).
- **`skill_removing_autoaim`** Auto-face, a wide arc or aim assist decides who is hit. Why: positioning and timing stop mattering; skill has no ceiling. Check: the design's attack arc over about 60 degrees, or the attacker turning to face without input. Instead: the player aims with his feet and facing; a narrow active area, a reward for the angle.
- **`every_hit_floors`** Every hit is a knock-down. Why: no exchange, no combo, no comeback; the fight is a coin flip of who swings first. Check: count downs against hits in a bot run; more than about one in four is suspect. Instead: react by strength (flinch, stumble), a knock-down only for big or punishing hits, a fast get-up.
- **`fighters_overlap`** Two figures stand inside each other and read as one blob. Why: the player cannot tell who is where or who hit whom. Check: any strip frame with two bodies merged. Instead: colliding capsules scaled with the figure (`body_scale`), spacing in the AI (`TLSteer.separate`), knockback that opens distance.
- **`placeholder_in_clip_moment`** One of the three clip moments is played by a greybox, a stand-in clip or a default effect. Why: the moment that sells the game looks like a test. Check: the strip of each named clip moment. Instead: the clip moments get the real clip, the real hit-stop and reaction, the effect and the sound first.
- **`speed_stat_difficulty`** Harder means the rivals are faster or hit harder. Why: the player loses to numbers, not to a better opponent; nothing to learn. Check: the difficulty table changes only speed, damage or health. Instead: aggression, shorter or hidden tells, patterns, teamwork, better positions; per-verb difficulty.
- **`no_defensive_verb`** The player cannot block, dodge, roll or parry. Why: every exchange is a trade; the player's only answer is to hit first. Check: no verb has `defensive: true`. Instead: one defensive verb with i-frames or a guard, a tell, and a punishable recovery.
- **`juice_on_everything`** Shake, sparks and flashes fire on every contact. Why: nothing stands out, so the big hit no longer reads; the screen is noise. Check: shake or bursts on light hits and whiffs in the strip. Instead: scale effects by force; shake only for big hits; a whiff gets no burst.
- **`menu_first_minute`** The first minute is menus, text or a tutorial wall. Why: the player meets the game as homework and the GIF is a menu. Check: the first 60 s of the run show no exchange. Instead: open on the first exchange; teach by a rival who can only do the first verb (World 1-1).
- **`generic_brawler`** The core loop is invented instead of copied: no state machine, no frame table, no punish window, moves that only differ in damage. Why: the owner's word for it is slop; a brawler with no proven core has nothing to learn. Check: the design names no genre template (section 11), or its verbs carry no template `move`, or their frames differ from the template's table. Instead: copy the template's state machine, frame table and contact results; spend the novelty on the hook.
- **`one_sided_contact`** A contact changes only one body: the defender flinches and the attacker swings on as if nothing happened (a blocked heavy with no recoil, a parry with no stun on the attacker, a clash where nobody rebounds). Why: "arena mutual reaction on attacks and collision is almost non-existing" (the owner, 21 Nov). Check: a strip of a block, a parry or a clash where the attacker's body does not change. Instead: the mutual-reaction table (section 11; DUEL-PLAYBOOK sections 2 and 6.3): every contact changes BOTH fighters, with hit-stop on both.
- **`oatmeal_variety`** Variety that is only numbers: ten rivals that are one rival with other health, rounds that are only more of the same (anti-pattern 3, "10,000 bowls of oatmeal"). Why: the main risk of an LLM pipeline; the second round feels like the first. Check: rivals or rounds that differ only in a stat, a colour or a count. Instead: each rival differs in its DEFENCE and its habit (absorb, parry, avoid), each round in its context (checklist items 20 and 21).
- **`passive_ai`** An opponent stands, waits or wanders for seconds (anti-pattern 4). Why: there is no pressure and nothing to read. Check: the tofu bot's `idle_max_f` over 120, or a strip where a rival does nothing for 2 s. Instead: every opponent acts within 2 s (spacing, pressing, feinting and resetting count as acts); pressure comes in waves (checklist items 9 and 12).

## 7. Rules by role

Designer:
1. Name ONE genre template per core loop (section 11) and what is copied from it. The core loop is the template's, word
   for word: its state machine, its frame table, its contact results, its rival archetypes.
2. Write the concept as five pitches with likelihoods; choose a less typical HOOK that still fits the words, and say why.
   The boldness is in the hook and the twist, never in replacing the proven core.
3. Name 2-3 reference games and the exact mechanic borrowed from each; write the line "<anchor genre> where <hook>".
4. Write three pillars, each with what it rules out.
5. List 2-5 verbs, each with input, anticipation, active and recovery frames, cancel, and its own clip id; one defensive.
   A verb copied from the template names its `move` and carries the template's frames exactly.
6. Write 2-3 playstyles that differ in verbs and positioning, and a skill ladder: floor plus three ceiling techniques in order.
7. Fill the feel sheet with numbers from section 2 and the template: hit-stop range, knockback, reaction by strength,
   whiff, i-frames, telegraph, shake, camera.
8. Make difficulty from aggression, tells, patterns and positioning (the template's AI tiers); no speed, damage or health
   stats; no hidden help. Rivals differ in their defence and habit (the template's archetypes), never only in numbers.
9. Name three clip moments, the first minute (it opens on an exchange), the fail state, and what is out of scope; check the
   design against every slop-list id and every checklist item of section 10 that can be answered on paper.

Planner:
10. The first phase is the tofu stage (section 12): the core verb exchange on flat shapes (milestone `blockout`) with
    its whole feel sheet, and one bot that reports the tofu metrics. Nothing else is built before it passes.
11. The root contract carries the line `TOFU CHECK: tests/<bot>.gd reports metrics ...` (section 12), and every
    package's contract carries the template rules its verbs need, copied, not paraphrased.
12. Every package's `serves` names the clip moment it serves; a needed clip the rig lacks is a question, not a package.

Builder:
13. Hit-stop on attacker and victim together, in the sheet's range, scaled by force, counted in physics frames.
14. Every hit calls `TLHit.react(victim, from_dir, strength)` or, for a big hit only, `TLHit.down(victim, frames, from_dir)`.
15. Every contact changes BOTH bodies (the template's contact table): a blocked heavy recoils the attacker, a parry
    stuns him, a clash rebounds both.
16. A miss plays its recovery and its own sound, with no burst and no shake.
17. Defensive verbs are invulnerable from frame 1 for their sheet frames, and show it in their clip.
18. Rival attacks show a wind-up of at least 20 f in the body (12 f for a chained follow-up that must be read), are
    active 2-4 f, and leave a punish window.
19. Visible feedback within 3 f of the press, the full pose by 6 f; shake only on meaningful hits, decaying.
20. The camera is never behind scenery and keeps both fighters in frame; fighters never overlap (colliding capsules,
    `body_scale`).
21. Each verb plays its own clip (check `rig.call("clips")`); never borrow a clip made for another action: ask instead.
22. The tofu bot measures; it does not pass by construction. Each metric of section 12 is counted from what happened in
    the frames it played, never written as a constant.

Critic:
23. Judge the motion strips (12 frames, 5 apart, a 4x3 tile) before the stills.
24. For each hit in a strip, name the frames that show anticipation, impact (hit-stop) and the victim's reaction; for a
    block, a parry or a clash, the frames that show the ATTACKER's body answering too.
25. For each whiff, check it reads as a miss; for each dodge or block, check the body shows it.
26. Any slop-list item seen is a fail; name its id and the strip frame.
27. Judge, by number, the [C] items of the checklist (section 10) that the frames can show.
28. Judge each named clip moment by the GIF test: would these 3 seconds make someone want to play?
29. Compare with the previous version, say which is better and why, and keep the better one.
30. End the notes with the line `[H] items not judged: a person must play it`, followed by the numbers of the [H]
    items (section 10). No capture passes an [H] item.

## 8. What made games last: R1-R14

From `docs/research/WHAT-MADE-GAMES-POPULAR.md` (Pong to Balatro). Almost none of it is graphics: one verb that is fun
with nothing around it, few rules that interact, cause and effect shown at once, opponents with personalities and
tells, a comeback in the rules, rounds short enough to restart on impulse, one hook nobody else has. Each principle
names where this pipeline checks it.

- **R1 The core verb is fun in an empty room.** Splatoon was tofu blocks; Mario 64 stalled until turning felt right.
  Checked by the tofu stage (section 12) before any content exists.
- **R2 Cause and effect are readable and immediate.** "If the AI didn't say it, it didn't happen" (F.E.A.R. callouts).
  Feedback within 3 f (checklist 1), a loss with a nameable cause (13), state at a glance (26).
- **R3 Low floor, high ceiling.** One button does something on day one; three ceiling techniques (section 1). Ladder:
  checklist 6-8.
- **R4 Opponents are fair and learnable:** personalities, tells, pressure in waves (Left 4 Dead's Director: build-up,
  peak, relax). Checklist 9-12, 14; the template's archetypes (section 11).
- **R5 Few rules, many interactions.** Three rules or objects that combine into outcomes nobody scripted (checklist 17).
- **R6 Risk/reward and a comeback are part of the rules.** A strong move leaves you open; a losing side has a way back
  that is a visible rule (Smash percent, Counter-Strike's loss bonus). Checklist 15-16.
- **R7 It works socially and as a show.** Clips, rivalry, a crowd. Checklist 28-29; the GIF test (section 3).
- **R8 Short sessions, "one more go".** Rounds of 30 s to 5 min, restart within 2 s (checklist 18, 30).
- **R9 Progress makes failure productive.** A loss gives knowledge, an unlock or a laugh (checklist 22).
- **R10 Onboarding by play, not text.** World 1-1: the first threat is safe (checklist 5; section 1 first minute).
- **R11 Strong feedback (juice) and forgiving controls.** Hit-stop, shake, burst, sound, number pop; coyote time and an
  input buffer (checklist 24-25; section 2). This is presentation, not fidelity.
- **R12 A distinct hook you can say in one line.** "<anchor> where <hook>" (section 3; checklist 27).
- **R13 Variety of context around a stable core** (kishotenketsu: introduce, develop, twist, test). The core stays the
  template's; the context changes (section 1 loops; checklist 20-21).
- **R14 Decisions, not only execution.** Sid Meier's "series of interesting decisions": a risk/reward choice at least
  every 30 s (checklist 16).

## 9. Anti-patterns

Each is a way a competent game fails. The one in bold is the main risk of an LLM pipeline like ours.

1. **A feature list with no core** (Anthem): systems around a verb that was never fun alone. Ours: the tofu stage.
2. **No identity** (Concord): nothing a stranger remembers. Ours: the hook (section 3), the slop id `recoloured_rivals`.
3. **Variety that is only numbers: "10,000 bowls of oatmeal"** (No Man's Sky). Procedural or generated variety that
   changes stats, colours and counts while the play stays the same. **The main risk for us**: a model fills a list
   with plausible variants at no cost. Ours: rivals differ in their defence and habit, rounds in their context; the
   slop id `oatmeal_variety`.
4. **Passive AI** (Aliens: Colonial Marines: enemies "wander around and forget you're there"). Ours: `idle_max_f`
   (section 12), the slop id `passive_ai`.
5. **AI that cheats where you can see it** (visible rubber-banding). Ours: checklist 14; difficulty from design
   (section 1).
6. **Mushy controls** (Rocket League at 30 fps). Ours: feedback within 3 f, 60 Hz, an input buffer.
7. **Stakes framed as punishment** (WoW's rest penalty, accepted once reframed as a bonus). Ours: checklist 23.
8. **Unreadable goals or state** (Halo 3 testers wandered until objectives flashed). Ours: checklist 4 and 26.
9. **No stakes and no end.** Ours: rounds that end, a ladder, a score to beat (section 1).

How professionals test fun: prototype the verb ugly and kill freely (Splatoon came from about 70 ideas; Supercell
celebrates kills). A prototype asks "is it fun?", a vertical slice asks "can we build it to final quality?". **Our
pipeline used to jump to the slice**; the tofu stage is the prototype. Metrics show where, feel shows why; the real test
is whether someone plays it without us.

## 10. The plays-twice checklist

A small generated game a real person plays twice. Verify: **[B]** a bot metric, **[C]** a capture or a log, **[H]** a
person's playtest. No bot result and no capture can mark an [H] item PASS: the owner's hand is the bar. "Who" names
the step of this pipeline that judges the item: the design review on paper, the tofu bot (section 12), the capture
critic, the card's hand checks (`tl ladder`), or a person.

| # | Criterion | Verify | Who |
|---|---|---|---|
| 1 | The core verb gives visible feedback within 3 frames, at a steady 60 Hz | [B] | tofu bot `feedback_f` |
| 2 | With no opponent or goal, a newcomer keeps using the verb for >= 30 s | [H]; [B] proxy: >= 2 outcome dimensions | person; tofu `skill_spread` is the proxy |
| 3 | The verb has an analogue skill dimension (different inputs, measurably different results) | [B] | tofu bot `skill_spread` |
| 4 | The rules fit in one sentence shown in the first 5 s | [C]; [H] | critic (HUD line), person |
| 5 | The first 30 s teach with a safe first threat, not a text wall | [C]; [B] newcomer survives >= 90 % | critic, hand checks |
| 6 | Win rate rises with skill: newcomer < regular < sharp < perfect, gaps >= 15 points | [B] ladder | hand checks, `tl ladder` |
| 7 | The newcomer wins sometimes (10-20 %+) | [B] | hand checks |
| 8 | The perfect hand keeps a ceiling (score still rising across levels) | [B] | `tl ladder` |
| 9 | Every opponent acts: none idle > 2 s | [B] | tofu bot `idle_max_f` |
| 10 | >= 2 opponent archetypes with distinct documented rules | [B] | design review (the template's archetypes) |
| 11 | Each dangerous opponent action has a tell >= 12 frames before it lands | [C] | tofu bot `tell_min_f`; critic on strips |
| 12 | Pressure in waves: >= 2 peaks and troughs per match | [B] | tofu bot `pressure_waves` |
| 13 | Most losses have a visible, nameable cause | [C]; [H] | critic, person |
| 14 | No hidden cheating: AI within player limits; any catch-up is a visible rule | [B] | design review; builder rule |
| 15 | A comeback rule; leads change hands in >= 30 % of close matches | [B] | tofu bot `lead_change_share` |
| 16 | >= 1 risk/reward choice per 30 s | [B] | design review |
| 17 | >= 3 rules or objects that interact into unscripted outcomes | [B] | design review |
| 18 | Rounds of 30 s to 5 min; restart <= 2 s with one button | [B] | design review; bot frames |
| 19 | The ending has drama (share of rounds decided in the final 10 %) | [B] | later bots |
| 20 | Each round differs in context while the core stays | [B] | design review (`design.context`) |
| 21 | Variation is perceptual, not only numeric | [C]; [H] | critic, person |
| 22 | Failure gives something: progress, unlock, knowledge or a laugh | [C]; [B] | design review, critic |
| 23 | Stakes framed as a bonus, not a penalty | [C] | design review |
| 24 | Juice on every hit or score: >= 3 of hit pause, shake, particle, sound, number pop | [C] | critic on strips |
| 25 | Forgiveness windows: coyote time, input buffer, generous hitboxes | [B] | design (the template's buffer) |
| 26 | State readable at a glance: score, threat, goal | [C]; [H] | critic, person |
| 27 | One-line hook absent from the genre baseline | [C] | design review (`hook`) |
| 28 | A 10-s clip of the best moment is understandable to a non-player | [C]; [H] | critic (GIF test), person |
| 29 | Rivalry: 2-player or beat-my-score/ghost | [C] | design review |
| 30 | Voluntary replay: offered "stop or play again", a tester plays again | **[H] only** | the owner |

The [C] items a capture critic can judge from frames: 4, 5, 11, 13, 21, 22, 24, 26, 28. The [H] items no machine can
pass: 2, 4, 13, 21, 26, 28, 30. The critic ends its notes with `[H] items not judged: a person must play it` and their
numbers (section 7, rule 30).

## 11. Genre templates: copy a proven design

The owner, 21 Nov: "there are hundreds of duel games (souls like, for honor duels) with well known game design paths we
can mimic". Every core loop of a design copies ONE proven template. The concept step names it (`concept.template`:
`id`, `reference`, `copies`); the design step copies its rules and frame tables word for word (a verb taken from the
template names its `move` and carries the template's frames exactly); the Planner and the builders read the template's
research excerpt, pasted by the Foreman from `docs/research/`, the relevant one only. The hook and the twist are where
the game is new; the template is where it is right.

**Each template has a house game** (the owner, 22 Nov 00:55: duel and hockey "high quality standalone games to set
example and engine needs for all future games coming from editor"). The house game is the reference implementation of
the template on this kernel: `engine/packs/duel` (`game.duel`) for the duel, `engine/packs/hockey` for the arcade sport.
Every job's reference copy holds it (`ref/packs/<pack>/`). The design step and the Planner read its README rules; the
builders read its files; the Foreman checks a copied move against the house game's own frame table
(`engine/packs/duel/data/moves.json`), not the research's. **Where the two differ, the house game wins**: its numbers
were measured on this kernel.

- **`duel`: a melee duel** (one against one, or one at a time; fists, swords, shields, a gladiator, a knight, a boxer).
  Reference: Dark Souls / Sekiro / For Honor, as `docs/research/DUEL-PLAYBOOK.md`. Copied, never paraphrased:
  - the state machine (6.4): `IDLE/MOVE -> WINDUP -> ACTIVE -> RECOVERY`, plus `BLOCK`, `PARRY_WINDOW`, `ROLL`, `DODGE`,
    `HITSTOP`, `HITSTUN`, `BLOCKSTUN`, `PARRIED`, `GUARDBROKEN`, `REBOUND`, `STAGGER`, `WALLSPLAT`, `KNOCKDOWN -> GETUP`,
    `BROKEN`, with an 8-frame input buffer;
  - the move table (6.2) and the contact results (6.3), hit-stop on both: every contact changes BOTH fighters (section 2
    of the playbook);
  - the interaction matrix (6.5) and the triangle (guard beats attack, bash beats guard, attack beats bash);
  - the resources (6.1: HP, stamina, posture, poise tiers) and the AI tiers (6.6);
  - three rival archetypes defined by their DEFENCE (6.7): THE WALL absorbs, THE DUELIST parries, THE DANCER avoids.
  The move frames the Foreman checks (windup = `anticipation_f`, then `active_f`, `recovery_f` on a whiff):

  | `move` | anticipation_f | active_f | recovery_f | clip |
  |---|---|---|---|---|
  | `light` | 18 | 4 | 16 | `strike` |
  | `heavy` | 32 | 5 | 28 | `strike_heavy` |
  | `charged` | 54 | 6 | 36 | `strike_heavy` |
  | `bash` | 14 | 6 | 24 | `body_check` |
  | `block` | 4 | (held) | 6 | `block` |
  | `parry` | 1 | 12 | 20 | `block` (a tap) |
  | `roll` | 3 | 18 | 15 | `roll` |
  | `dodge` | 2 | 8 | 12 | `dodge` |
  | `taunt` | 0 | 0 | 60 | `taunt` |

  The duel's tofu bot also reports `contact_types` (>= 3 of the 6.3 rows met) and `one_sided_contacts` (0: a contact
  that left one fighter's state unchanged fails the playbook's own acceptance).
- **`arcade_sport`: an arcade team sport with a ball or puck** (hockey, football, basketball, any "get the thing into
  the goal"). Reference: NHL '94 / Rocket League / Buckland's Simple Soccer, as `docs/research/HOCKEY-ARCADE.md`.
  Copied: possession as a state (`LOOSE`, `CARRIED(owner)`, `PASS_IN_FLIGHT`, `SHOT_IN_FLIGHT`) with readable loss
  causes (5.1); the speed RATIOS of the speed table (5.2: passing beats skating, the carrier is slower); the utility AI
  for shoot / pass / carry with hard vetoes and a re-decision every 15 f (5.3); the roles re-sorted by time to the ball
  (5.4); the anti ping-pong rule. Its tofu bot also reports `possession_median_f` (240 to 600: 4-10 s; over 900 is
  glued, under 120 random).
- **`own`: any other genre** names its own proven reference: a real released game (or a family of them) and the exact
  mechanics copied, with their numbers where the source has them (a racer copies Mario Kart's item roulette by
  position and its mini-turbo; a platformer copies Celeste's coyote time of 5 f and its jump buffer). A template whose
  `copies` are moods ("the feel of Dark Souls") is not a template.

**The duel house game against DUEL-PLAYBOOK** (read 22 Nov 01:20 from `engine/packs/duel`, README "What changed from
the playbook"). The move frames above are the same in both (the Foreman compares them: `houseFrameDiff`, none). The
house game changed, and its numbers win:
- poise damage light 22, heavy 42, charged 70 and poise you 10, Wall 20, Duelist 10, Dancer 8 (the playbook's light 10
  minus Duelist 20 absorbed every light, against its own contact table); the Wall has 110 health, not 120;
- the parry is the first frames of a block press (Sekiro's deflect: press = window f2-13, hold = block), one button;
- a clash also when one swing is active and the other at most 5 frames from its own active frame;
- a blocked heavy pushes 0.35 m and 0.2 m (playbook 0.5 and 0.3) and the light lunges 0.5 m, so the guaranteed light
  reaches; a pushbox of 0.45 m per duellist at scale 1;
- lock-on: each fighter always faces his rival (the pack turns the body, `turn_rate` 0), so the guard holds while
  circling; a design whose facing follows the walk breaks the 120-degree block;
- the rig's fight clips are stretched over the rules' frames by a [move frame, clip frame] map, so an 18-frame wind-up
  reads on a short clip;
- rally (under 35 % health, stamina back half as fast again) as the visible comeback rule, and a crowd meter;
- the camera over the shoulder, offset to the side, looking between the two (back 4.6 m, up 2.6 m, side 2.6 m), over a
  ring wall of 1.25 m that is low enough to see over, the stands behind it.

When a recipe card exists for the template (the duel card `card.duel`, written by the duel lane), it is the default card
for the job; the Planner takes it unless one of its `NOT when` lines matches.

## 12. The tofu stage

The strongest single change the research suggests: build the core verb with flat shapes, and kill it unless it is fun
in an empty room. Our first phase is the tofu stage.

- **What is built.** The first phase holds the root package (and at most the package it needs to stand on): the core
  verb exchange on flat shapes (milestone `blockout`: kit primitives, no art), the template's verbs and contact results
  with their whole feel sheet, one rival that answers, the camera of the feel sheet, the rule that decides a round, and
  one bot: the tofu bot. No art, no HUD beyond one hint line, no second rival, no twist.
- **The line in the root contract** (the plan is refused without it when the brief has a design doc):
  `TOFU CHECK: tests/<bot>.gd reports metrics feedback_f, skill_spread, skill_variants, idle_max_f, tell_min_f, tells,
  pressure_waves, lead_change_share, close_rounds`. The bot is registered by the root package and run in its acceptance.
- **The metrics.** The tofu bot's `_bot_result()` returns a `metrics` object beside `ok` and `summary` (PACK.md allows
  any numbers in the result; the runner reports it as `bot.result.metrics`). Every value is counted from the frames the
  bot played, never written as a constant. A metric that is absent is not measured, and not measured is a fail.

  | Metric | Item | Passes when | How the bot counts it |
  |---|---|---|---|
  | `feedback_f` | 1 | <= 3 | over every press of the core verb the bot made: the most frames from the press to the first frame the player's body or weapon visibly changed (a clip started, a step, a flash) |
  | `skill_spread` | 3 | 0.25 to 0.95 | the bot plays the CORE verb with different inputs (timing, spacing, charge, angle; a different move is not a variant), each at least 5 times; (best mean outcome - worst mean outcome) / best mean outcome, the outcome being damage, knockback or frame advantage. 1.0 means a variant that never works (the crazy colosseum proof of 22 Nov counted a bash as a variant of its light and reported 1.0): that is another verb, not skill |
  | `skill_variants` | 3 | >= 3 | how many variants of the core verb `skill_spread` compared, each tried at least 5 times |
  | `idle_max_f` | 9 | <= 120 | the longest run of frames any opponent spent with no action (not moving with intent, not attacking, not defending) |
  | `tell_min_f` | 11 | >= 12 | over every dangerous opponent action that started: the fewest frames from the first frame of its tell pose to its first active frame |
  | `tells` | 11 | >= 3 | how many dangerous opponent actions `tell_min_f` counted |
  | `pressure_waves` | 12 | >= 2 | opponent attacks started per 60-frame window; a peak is a window with at least 2 attacks and twice the lowest window since the last trough, a trough a window at or below half the last peak; the count of peak-then-trough pairs |
  | `lead_change_share` | 15 | >= 0.30 | the bot plays at least 3 rounds; a round is close when the loser ends within 25 % of the winner's health or one point; the share of close rounds in which the lead changed hands at least once |
  | `close_rounds` | 15 | >= 1 | how many close rounds `lead_change_share` is over |

  Template metrics join them (section 11): the duel's `contact_types` (>= 3) and `one_sided_contacts` (0); the arcade
  sport's `possession_median_f` (240 to 600). The bot also names `hand`: the `TLHand` profile it played the player's
  side through; every figure is quoted with it.
- **The hold.** When the `blockout` milestone's packages are merged, the Foreman reads the newest report of the tofu bot
  and judges the metrics with the critic's look, exactly like the quality loop: NOT ok sends the root package a revise
  round with the failed rows (at most 2 rounds), the critic keeps the better version, and still NOT ok holds the job
  (`job_state paused`, reason `quality`) until the owner answers `foreman quality <job> accept|retry`. Nothing of the
  second phase is started while the tofu stage is held.
- **And a person.** The metrics are the floor, not the bar: after the tofu phase the player plays it in an empty room
  (the phase pause) and says pass or hold. Checklist item 2 ([H]) is judged there.

## Sources

1. Masahiro Sakurai, hit-stop episodes of "Masahiro Sakurai on Creating Games" (YouTube, 2022). Coverage:
   https://www.gonintendo.com/contents/13581-sakurai-s-latest-game-dev-video-features-8-hit-stop-techniques
2. Masahiro Sakurai, Famitsu column vol. 490 on hitstop (2015), translated by Source Gaming:
   https://sourcegaming.info/2015/11/11/thoughts-on-hitstop-sakurais-famitsu-column-vol-490-1/
3. SmashWiki, "Hitlag" (formula by game, caps, who freezes): https://www.ssbwiki.com/Hitlag
4. SmashWiki, "Knockback" (formula with base, growth, damage, weight): https://www.ssbwiki.com/Knockback
5. Elden Ring wiki, "Invincibility Frames": https://eldenring.wiki.gg/wiki/I-Frame ; Fextralife, "Equip Load":
   https://eldenring.wiki.fextralife.com/Equip+Load (Dark Souls 3's about 13 at 30 fps is player measurement only.)
6. Jaime Griesemer, "Half-Minute Halo: An Interview with Jaime Griesemer", Engadget (2011):
   https://www.engadget.com/2011-07-14-half-minute-halo-an-interview-with-jaime-griesemer.html
7. "The magic of TowerFall: depth, simplicity, community", Game Developer (Thorson on dodge, catch, cancel):
   https://www.gamedeveloper.com/design/the-magic-of-i-towerfall-i-depth-simplicity-community
8. Stone Librande, "One-Page Designs", GDC 2010: https://www.gdcvault.com/play/1012356
9. Shigeru Miyamoto and Takashi Tezuka on World 1-1 (Eurogamer video, 2015); coverage, Game Developer:
   https://gamedeveloper.com/design/how-miyamoto-built-i-super-mario-bros-i-legendary-world-1-1
10. God of War (2018) off-screen attack indicators, Digital Trends combat guide:
    https://www.digitaltrends.com/gaming/god-of-war-combat-guide/
11. Simon Carless, "How TABS creator Landfall got discovery right", Game Developer (2022):
    https://www.gamedeveloper.com/game-platforms/how-i-tabs-i-creator-landfall-got-discovery-right-
12. NBA Jam (1993), "on fire": https://en.wikipedia.org/wiki/NBA_Jam_(1993_video_game)
13. Super Mega Baseball Ego per skill: https://www.ea.com/able/resources/super-mega-baseball/super-mega-baseball-4 ;
    PC Gamer, Super Mega Baseball 2 review: https://pcgamer.com/super-mega-baseball-2-review
14. For Honor Wiki, "Stance": https://forhonor.fandom.com/wiki/Stance
15. Stephane Perez (Dotemu) on Windjammers 2 and the drop shot, Siliconera:
    https://www.siliconera.com/windjammers-2-interview-dotemus-stephane-perez-on-making-a-faithful-sequel/
16. Cai et al., "Spec2Game: Can LLMs Generate Complete Playable Games from Detailed Specifications?" (2026):
    https://arxiv.org/abs/2610.04253
17. Luo et al., "GameCraft-Bench: Can Agents Build Playable Games End-to-End in a Real Game Engine?" (2026):
    https://arxiv.org/abs/2606.17861
18. Taesiri, Feng, Nguyen, Bezemer, "GlitchBench: Can Large Multimodal Models Detect Video Game Glitches?" (CVPR 2024):
    https://arxiv.org/abs/2312.05291
19. Zhang et al., "Verbalized Sampling: How to Mitigate Mode Collapse and Unlock LLM Diversity" (2025):
    https://arxiv.org/abs/2510.01171
20. Madaan et al., "Self-Refine: Iterative Refinement with Self-Feedback" (NeurIPS 2023): https://arxiv.org/abs/2303.17651
21. Chen, Wu, Jia, Liu, "Recursive Game Creator: An Agentic Product-Level Experience-Oriented Game Harness" (2026):
    https://arxiv.org/abs/2610.08621
22. Described from the games, no page verified: NHL Hitz, Mutant League, Rocket League, Absolver, Gang Beasts.
23. House numbers: reaction times of the hands (`engine/kernel/API.md`, `TLHand`), the hit and camera calls
    (`engine/kernel/API.md`). Telegraph, active, anticipation and input-response frames are house numbers.
24. The research of 21 Nov, with its own sources inline: `docs/research/WHAT-MADE-GAMES-POPULAR.md` (R1-R14, the
    anti-patterns, the checklist, the tofu stage), `docs/research/DUEL-PLAYBOOK.md` (the duel template),
    `docs/research/HOCKEY-ARCADE.md` (the arcade-sport template).
