# Game quality: designing a game we could sell

This handbook is read by the Designer (concept and design doc), the design review (producer and marketer), the Planner,
the builders and the capture critic. The Foreman pastes its sections into prompts by heading, so each section stands
alone. Every rule here is checkable: a reviewer can point at a line of the design doc, a number, or a motion strip and
say yes or no. Numbers are frames at 60 Hz. A figure from a source says so; a figure without one is a house number.

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
- **Input to visible response at most 6 f.** The first frame of the clip or the step shows within 6 f of the press.
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
  five pitches with likelihoods and picks a less typical one that still fits the words.
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

## 7. Rules by role

Designer:
1. Write the concept as five pitches with likelihoods; choose a less typical one that still fits the words, and say why.
2. Name 2-3 reference games and the exact mechanic borrowed from each; write the line "<anchor genre> where <hook>".
3. Write three pillars, each with what it rules out.
4. List 2-5 verbs, each with input, anticipation, active and recovery frames, cancel, and its own clip id; one defensive.
5. Write 2-3 playstyles that differ in verbs and positioning, and a skill ladder: floor plus three ceiling techniques in order.
6. Fill the feel sheet with numbers from section 2: hit-stop range, knockback, reaction by strength, whiff, i-frames,
   telegraph, shake, camera.
7. Make difficulty from aggression, tells, patterns and positioning; no speed, damage or health stats; no hidden help.
8. Name three clip moments, the first minute (it opens on an exchange), the fail state, and what is out of scope; check the
   design against every slop-list id.

Planner:
9. The first package lands the core verb exchange with its whole feel sheet on greybox, before any art or content.
10. Every package's `serves` names the clip moment it serves; a needed clip the rig lacks is a question, not a package.

Builder:
11. Hit-stop on attacker and victim together, in the sheet's range, scaled by force, counted in physics frames.
12. Every hit calls `TLHit.react(victim, from_dir, strength)` or, for a big hit only, `TLHit.down(victim, frames, from_dir)`.
13. A miss plays its recovery and its own sound, with no burst and no shake.
14. Defensive verbs are invulnerable from frame 1 for their sheet frames, and show it in their clip.
15. Rival attacks show a wind-up of at least 20 f in the body, are active 2-4 f, and leave a punish window.
16. Input to the first visible frame of the response is at most 6 f; shake only on meaningful hits, decaying.
17. The camera is never behind scenery and keeps both fighters in frame; fighters never overlap (colliding capsules,
    `body_scale`).
18. Each verb plays its own clip (check `rig.call("clips")`); never borrow a clip made for another action: ask instead.

Critic:
19. Judge the motion strips (12 frames, 5 apart, a 4x3 tile) before the stills.
20. For each hit in a strip, name the frames that show anticipation, impact (hit-stop) and the victim's reaction.
21. For each whiff, check it reads as a miss; for each dodge or block, check the body shows it.
22. Any slop-list item seen is a fail; name its id and the strip frame.
23. Judge each named clip moment by the GIF test: would these 3 seconds make someone want to play?
24. Compare with the previous version, say which is better and why, and keep the better one.

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
