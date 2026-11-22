N2 duel-reference: report of the extended night (22 Nov 2026, LOOP.md rounds 1-12, 01:00 to 05:41), branch n22-duel
====================================================================================================================

What this is: engine/packs/duel (the duel house game, game.duel) and its card engine/cards/duel.json. It starts from
the state of 21:30 / 00:53 (REPORT.md beside this file, landed as a6fc8ad). Twelve loop rounds followed. Each round:
- named one gap against Souls / For Honor and the plays-twice checklist;
- built it inside the pack;
- showed it in a window clip on the play camera, through the newcomer or regular hand;
- ran the gates (lint, smoke, all 49 duel units, the selftest block duel., the fast tier);
- was landed on main by the Director.
My `date` was about 12 minutes behind the Director's clock until about 04:30; the times here are mine.

NOBODY HAS PLAYED IT BY HAND. Every figure below comes from a scripted TLHand: newcomer, regular, sharp or perfect.
A person's hand is the bar, and the scripted newcomer does not read on-screen cues.

Play it: node devx/bin/tl.mjs play duel. V cycles the camera, R restarts, ENTER after a won match takes the next
rival.

ROUNDS (commit on main; the clip to watch is in clips/)
------
 1  83aefce   Gap: the first minute taught nothing; a newcomer met the Wall with a key card.
              Built: the Wall teaches block, parry and bash by play (lessons.gd: a held blow, a cue read first, then he
              stands open), and a parry glint 16 frames before every rival light or heavy lands.
              Newcomer vs the Wall, first 60 s, 8 seeds: hits taken 43 -> 13, punishes 0 -> 6.
              Watch: r1_after.mp4
 2  816983e   Gap: your head covered his wind-up, and the thin blades did not read.
              Built: the two-shot play camera, broader blades, trails by class.
              Watch: r2_after.mp4
 3  816983e   Gap: the rivals' signature moments were never seen.
              Built: the Wall ROARS into phase 2 (banner, horn, a named pattern); the Dancer squares up out of her roll
              into a dashing roll-cut.
              Watch: r3_after_wall_quake.mp4, r3_after_dancer_roll_cut.mp4
 4  3004e58   Gap: a lost round said nothing about why.
              Built: every hit is filed under a cause, and the card ends on WHAT BEAT YOU and its answer. pilot.gd
              returns N4's tofu metrics. E1 adopted (play_clip, kernelApi 1.14): 27 bot hashes are identical across the
              swap.
              Watch: r4_after.mp4, r4_card.png
 5  563bf48   Gap: the round-ending blow landed like any other.
              Built: a 20-frame freeze, a low KO camera beside the fallen fighter, dust, the crowd.
              Watch: r5_after_ko.mp4
 6  c30db3e   Gap: one bare ring at one pace, and the rival flat (N4: pressure_waves 1 on the Wall).
              Built: each rival's arena (banners in his colours, towers / masts / trees, a round-1 intro shot), a
              stand-in drum per rival, TIME and BEST on the card, and a push-then-breathe rhythm.
              pressure_waves on the Wall, regular hand, seed 1: 1 -> 4.
              Watch: r6_after_duelist.mp4
 7  efa2537   Gap: the pack drew its own trails, and every cue sat at the bottom of the screen.
              Built: API 1.15 adopted: TLHit.swing_trail; a tag over the rival's head (HEAVY gold, BASH orange,
              UNBLOCKABLE red, OPEN blue in the Wall's breath); coloured banners on a plate.
              Watch: r7_wall_newcomer.mp4, r7_tags_wall_quake.mp4
 8  4f442a1   Gap: the card named one cause worth 40 of 100 health.
              Built: chip and bash are filed as causes; the card names the top three out of your health; a one-time
              RALLY cue. pilot.gd returns `moments` (contact kind -> frames) for the editor's house strip.
              Watch: r8_after.mp4, r8_card.png
 9  f4a6d13   Gap: the rivals were the player recoloured (slop id recoloured_rivals).
              Built: helm and pauldrons, a plumed hat and cape, a hood (gen/arms.gd on the head and back sockets; the
              socket axes were found with a probe). The camera no longer rises over the stands into the banners.
              Watch: r9_gear_sheet.jpg, r9_after_dancer.mp4
10  d32f691   Gap: the Director's look notes, and at the ring wall the camera looked down on the Duelist's hat, where
              his tells cannot be read.
              Built: a head-sized helm; the Dancer's headband and ponytail; at the wall the camera swings to the inside
              shoulder.
              Watch: r10_before_duelist.mp4 vs r10_after_duelist.mp4
11  764d38f   Gap: the cliff after the Wall. The newcomer loses 5 of 6 to the Duelist, 100 -> 18 health in 14 s, and
              nobody tells him why.
              Built: the Duelist's first round teaches his tap, his first blade (block, then strike in the gap: the
              newcomer's top loss cause) and his thrust, with 0.4 damage while it runs; a one-time red cue the first
              time a trade costs you.
              Watch: r11_after_duelist_lessons.mp4
12  2c9e4a7   Gap: the Dancer taught nothing, and every line called her "he".
              Built: her first round teaches her spin heavy and her first cut; show.say reads she / her for her.
              Watch: r12_after_dancer_lessons.mp4, r12_card.png

Gates on the last landed tree (round 12):
- duel units 49/49; invariants: the same hash on both runs (9aa07fa3bb7f85a3); frame p99 1.64 ms (budget 4); 514
  nodes and 71 bodies.
- selftest duel. 8/8.
- Fast tier: arch, assets, cards and devx.test (229/229) PASS; foreman.typecheck NOT RUN (no node_modules in this
  worktree).
- The Director's fast tier on every merged tree: 5/5.

THREE CLIPS TO WATCH FIRST
--------------------------
r11_after_duelist_lessons.mp4 (a new rival teaches himself), r10_after_duelist.mp4 (a real exchange at the wall,
tags and splats), r8_card.png (a loss that explains itself).

LADDER (tl ladder --pack engine/packs/duel --seeds 8 on the final tree 9d06a97, 05:38-05:41)
------
Wins of 8; each seed is one best-of-3 match; 8 seeds give about +-30 points. The 21:30 figures are in brackets.

| rival                | newcomer | regular | sharp | perfect |
|----------------------|----------|---------|-------|---------|
| The Wall (rung 1)    | 4 (5)    | 6 (8)   | 8 (8) | 8 (8)   |
| The Duelist (rung 2) | 1 (2)    | 8 (5)   | 8 (8) | 8 (8)   |
| The Dancer (rung 3)  | 0 (0)    | 8 (4)   | 8 (8) | 8 (8)   |
| Champion (Duelist)   | 0 (0)    | 1 (1)   | 8 (5) | 8 (8)   |
| Champion, round 13   | 0        | 4       | 5     | 8       |

What moved, and why:
- The Duelist and Dancer regular cells went up through rounds 11-12. Their lesson rounds take 0.4 damage, so round 1
  is near-certain for any hand that punishes. Round 1 is now usually the newcomer's too (0.75 and 0.63 rounds won a
  match); the matches are still lost.
- The champion's sharp cell 5 -> 8 most likely comes from round 6's breathe windows; I did not measure that cell in
  round 6. Round 13 (the last row, 8 seeds, all four hands) restores his ceiling: the champion tier breathes 0.4 as
  long (rivals.json tiers.champion.breathe_k), sharp 5 of 8, perfect 8 of 8; his punishes are kept and he still comes
  in waves (pressure_waves 3-7 on 6 runs). His regular cell moved 1 -> 4, inside the noise and still under sharp.
- The regular hand is no longer ordered Wall < Duelist < Dancer.
- The newcomer is unchanged within the noise.

ENGINE NEEDS (ENGINE-NEEDS.md)
------------
- E1 clip timing (TLBiped.play_clip): ADOPTED round 4 (1.14). rig.clip_t is no longer written anywhere in the pack.
- E2 swing weight: ADOPTED. N1 re-posed strike / strike_heavy (round 1); TLHit.swing_trail adopted in round 7 (1.15).
- E3 HUD colour (TLHud.set_color): ADOPTED round 7.
- E4 tags over a body (TLHud.add_tag): ADOPTED round 7.
- E5 music with a tempo the game pushes (TLAudio.music / set_tempo): OPEN. The beat is a stand-in drum from the hit
  presets.
- Found tonight, for RIGS.md (a doc ask, not a need): the biped's head and back sockets are not Y-up. They are +X
  right, +Y back and +Z down, so gear on them is built Y-up and turned -90 degrees about X. RIGS.md lists the sockets
  without their axes.

SOULS / FOR HONOR READ, NOW AGAINST 21:30
-----------------------------------------
At 21:30: "partly". The mutual reactions, the guard / parry / punish loop and the splat read; light against heavy read
only by the wind-up and the banner. The toy figures and the thin blades limited it, and all four fighters were the
same figure recoloured.

Now, read from the clips only:

Closer:
- Each rival is a character by silhouette and arena: the knight in a bucket helm among towers; the duellist in a plumed
  hat and cape among red and gold flags; the dancer with a ponytail among trees and pink flags.
- His intent is on the screen: HEAVY / BASH / UNBLOCKABLE ride over his head, the glint comes before the parry moment,
  the wind-ups read by the body (N1's re-pose and kernel trails by weight).
- He comes in waves, and the Wall's breath is a real opening.
- A new rival shows his signature before he fights for real (Sekiro's sparring, For Honor's first duels).
- A loss explains itself in one line of causes and an answer.
- The killing blow is a moment worth a clip.

Still short of the reference:
- The fighting is one move set re-dressed. The three rivals differ in AI, timing and gear, not in their animations: no
  rival-specific strikes, no directional guard, no feints the player can do.
- The bodies are toys: contact reads by freeze, flinch and fall, not by weight or blade on armour.
- The sound is synthesised beeps.
- The difficulty curve is uneven: a newcomer cliff at the Duelist; easy regular-hand wins after the lesson rounds.

My honest word: a readable, teachable duel with distinct opponents, a good vertical slice of the For Honor loop at
toy scale. It is not yet a game that sells itself by its feel. Nobody has played it.

ASKS (for the owner)
----
1. The Duelist cliff. The newcomer hand wins 4 of 8 against the Wall and 1 of 8 against the Duelist. The Director
   kept his numbers for your hand. Rounds 11-12 added lessons; whether the cliff is right is a feel call: play the Wall,
   then the Duelist.
2. The lesson rounds now make round 1 an easy win for any hand that punishes (0.4 damage). Keep them easy (a sparring
   round), or let the lesson end at full damage?
3. The champion's ceiling: answered in round 13 (a per-tier breath, sharp 8 -> 5 of 8). Open: whether his regular cell
   (1 -> 4) is right by hand.
4. rig.clip_t / E-rows: the clip_t question of 21:30 is closed by E1 (play_clip). Open: E5 music, and the socket axes
   in RIGS.md.
5. The stand-in drum: does it help or grate? It lives in data/arenas.json (each arena's beat block); removing the block turns it off.

NEXT THREE
----------
1. A person plays 10 minutes: the Wall, then the Duelist. Read where they lose and whether the cues are read; tune the
   cliff and the lesson damage from that.
2. Give each rival one signature animation of his own: the Wall's two-handed overhead, the Duelist's lunge, the
   Dancer's spin. Today they share one move set. A rig ask to N1.
3. Real music per arena (E5). (The per-tier breath was done in round 13.)
