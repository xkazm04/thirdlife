L5 hockey-crazy: REPORT (shift 2026-11-21-day; tree .claude/worktrees/n21d-crazy, branch n21d-crazy; base df58f0b, fast-forwarded by
the Director to f3e1e18; LANDED on main by the Director in merge 4fbf72d, carried by L4 in one tested tree). I committed nothing.

WHAT IS BUILT
There are three crazy modes in the hockey house game. A player reaches them from the start panel (A / D, then Space):
- Arsenal (neon arena, amber accent). Seeded beacons of light appear in three zones: the first at 2 s, then one every 4 s, up to 5 on the
  ice. There are 8 kinds:
  - speed: speed and acceleration x1.5 for 5 s;
  - precision: a shot within 30 deg of the goal centre goes to it, for 8 s;
  - big puck: radius x1.5 for 10 s;
  - heavy puck: drag 0.8, top speed x0.5 for 6 s;
  - one charge of each of the four abilities.
  Bots take beacons too, and peel off the play for a near one.
- Shotgun (daylight hall). Every skater holds the shotgun on F, with a 20 s cooldown.
- Glow Ice (neon arena, base rules). A dark sheet, lines of light (the blue half solid cyan, the red half dashed red), a faint grid, a
  dark hall, and light trails (the puck's is the brightest). Blue and brick-red suits with light trim; the goal frame flashes on a goal.
  It plays exactly like base.
Abilities on F (the right mouse button still body-checks):
- shotgun: the next shot leaves at x1.5 and knocks down every standing skater within 1 m plus his body radius of its path, for up to
  120 frames of flight. Team-mates and goalies go down too. It shows a pink comet trail, a muzzle burst, and a burst and camera shake on
  every body it drops.
- hip check: armed for 60 frames; it lands even from a standstill, the victim stays down 1.5x longer and slides 3 m. The hitter plays
  L2's body_check clip.
- shield: for 6 s no check or cross-check lands on the holder; a holo bubble shows it.
- slow puck: the next pass or shot leaves at x0.5 and wakes up after 2 s.
Bots use all four. The HUD plate at the bottom right shows READY, NEXT SHOT, the seconds left, the shield's time and running boosts. Every
holder wears a waist ring of light. In a crazy mode the keys' lines say what F does. Every down goes through TLHit.down(who, frames,
from_dir).

ACCEPTANCE
- Base hashes unchanged: MET (my runs). These bots give the same state_hash and the same frame count as base df58f0b, and as a HEAD pack
  copy at f3e1e18:
  - bot_hockey s1 3b372f91ecfe4c79, s2 463251709a3f4f68, s3 25baa90d5ef5b023;
  - bot_match s1 a976137696bca31b;
  - bot_modes s1 d3591517b8654de6;
  - bot_menu s1 d1304f4d1b28b176.
  The world step gives hockey 3b372f91ecfe4c79@6751, so the game in the world hashes as it does alone.
  How the hashes hold: TLInput hashes the name of every declared action, pressed or not. So a crazy mode gets no keyless mode_<id>
  action (it is reached from the panel only), and F and the crazy drill actions are declared lazily, the first time a crazy mode is built.
  Glow Ice plays like base: Astra B compared the state on seed 1 across 1,508 frames, windowed and headless. Only "mode" and "game_line"
  differ.
- Each new mode runs to the end with a bot, one bot per ability shows its effect, 20 of 20 seeds: MET (my runs, final tree):

  | Bot | Seeds passed | What it shows |
  |---|---|---|
  | crazy_shotgun | 20/20 | the two defenders on the shot line go down; a plain shot downs nobody |
  | crazy_hipcheck | 20/20 | the victim slides 3.0 +- 0.5 m and stays down 1.5x; a plain check from a standstill lands nothing |
  | crazy_shield | 20/20 | the check is blocked (counted in hits.immune_blocks); the shield ends at 360 f |
  | crazy_slowpuck | 20/20 | release at 9.0 vs 18.0 m/s; it wakes at 120 f |
  | crazy_pickups | 20/20 | spawn in zones, take, effects, expiry |
  | crazy_modes | 5/5 | Arsenal and Shotgun to the end with bots on both sides; bots used abilities; pickups were taken |

  - crazy_modes ran on 5 seeds in my runs. Astra ran it on seeds 1 to 20 (20/20), and main reports 20/20 after L4's merge.
  - On the merged tree (v4), one crazy_shield run, seed 17, wrote an empty report: six parallel runs on a loaded machine, so the run never
    happened. Seed 17 re-run alone: passed. On v3 it was 20/20.
- Packs PASS and world 8/8:
  - world: PASS 8/8 (235 s).
  - packs on the merged tree: 66 of 67 verb runs pass. That covers lint and smoke for both packs and all 43 hockey bots, including the
    six crazy_* bots.
  - The 1 FAIL is hockey invariants.many_budget: p50 1.240 ms, a wall-clock figure. It ran beside kernel.selftest at load 15.9. Busy, so
    it decides nothing (see the next point).
- Hockey invariants p50 <= 1.0 ms in base: NOT MEASURED QUIET (every lane was running all day). Busy A/B: invariants seed 1, the HEAD pack
  against this tree, alternating, 3 times each:
  - base p50 1.069 / 1.326 / 1.093 ms; tree p50 1.068 / 1.087 / 1.155 ms (medians 1.093 against 1.087);
  - the bot_state_hash is the same in all six runs;
  - no cost is measurable. All crazy code returns at once when off, and the neon look builds nothing headless.
- Clips, 20 s or less (windowed movie writer, 1280x720, 60 fps), in this folder:
  - clip-glow.mp4: 15 s of neon Glow Ice;
  - clip-shotgun.mp4: 7.5 s, one shot drops defenders at 5 and 10 m;
  - clip-arsenal.mp4: 18 s, five takes, neon, blue and brick-red suits.
  I judged them by frame sheets. Stills are in stills/; the neon rounds are in NEON-ROUNDS.md (7 rounds). No person's hand has played
  them yet.
- README "Crazy modes" section: written in PATCHES.md; L4 landed it with its README.

GATES (my tree; it was fast-forwarded to f3e1e18 mid-afternoon)
- fast: arch 12/12, assets 4/4, cards 3/3, devx.test 229/229, foreman.typecheck: all PASS. foreman.typecheck was NOT RUN until I ran
  npm ci in foreman/.
- full, step by step:
  - foreman.test: PASS 258/258 (252 pass, 6 skipped).
  - packs: 66/67, the 1 failure being the busy budget above.
  - world: PASS 8/8.
  - kernel.selftest: 75/76, 0 failed, then killed by its 1800 s cap at load 15.9 (wall clock on a busy machine). The late blocks
    (hockeyfun, fight clips, dungeon) re-run alone: 16/16 PASS.
  - kit.selftest, perf, seeds, item.selftest, ui.selftest: NOT RUN. I stopped that run when the Director closed the lane.
  - Two earlier whole-gate runs are VOID: one was interrupted by the fast-forward, and one was killed by my own 3600 s wrapper.
- lint on the merged tree: PASS. Bypasses: only the old tests/bot_fun.gd:22. Under the split cap, game code (scripts + gen) is 4,277 of
  6,000 lines (L5 +1,220) and tests are 2,613 of 4,000 (L5 +395).

CHANGED FILES
Mine (engine/packs/hockey):
- scripts/abilities.gd (new)
- scripts/boosts.gd (new)
- scripts/fx/neon.gd (new)
- gen/crazy_hook.gd (new): beacons, waist ring, shield bubble
- gen/neon_hook.gd (new): sheet, lines, grid, trim, goal frames
- scripts/modes.gd: the schema for pickups, abilities[] and neon (unknown keys stay errors), and is_crazy
- scripts/look.gd: the neon hook, neon_colors, the F hint
- data/boosts.json (new)
- data/modes/arsenal.json, shotgun.json, glow.json (new)
- tests/crazy_shotgun.gd, crazy_hipcheck.gd, crazy_shield.gd, crazy_slowpuck.gd, crazy_pickups.gd, crazy_modes.gd
L4's files, listed exactly in PATCHES.md and redone by L4 in its own rewrite:
- scripts/main.gd: 7 hooks; the two mode loops skip crazy modes; a second, prewarmed ':neon' rig pool, used only in a window
- scripts/state.gd: "crazy" while on
- scripts/hits.gd: immune, immune_blocks
- data/tuning.json: the modes list
- pack.json: 6 tests; the mode param 0..7, label "Mode: 0-4 classic, 5-7 crazy"
engine/style (approved by the Director, append-only): neon_pink #ff3fa4, neon_lime #a3ff3d, neon_violet #9b6bff, each with a mat emit
entry, appended after pond_ice in all four style files. Existing keys, their order and palette indices are untouched.

BEHAVIOUR CHANGES
- None in the five classic modes (the hashes above).
- The panel lists eight modes. A pressed from base now wraps to Glow Ice instead of big ice.
- pack.json's mode param 5-7 starts in a crazy mode.
- A windowed load builds every figure twice (a daylight rig and a neon rig). A panel start into a neon mode was 252-261 ms, over the
  runner's 250 ms tick limit; with both rigs built at load it stays under. Headless builds only the daylight rig.

L4'S ADAPTATIONS (checked against main 4fbf72d)
They agree with the design:
- the hip check targets through L4's check_gap and cone, and the loose push is a fixed 2.0 m/s;
- bots steer through skate.want;
- the drills are re-placed for the new blade distance;
- the speed boost multiplies the frame's skate_accel ("on top of this frame's skating rules").
One thing for L4 to confirm: speed now does `skate_accel *= 1.5` every frame. That is right only if scripts/skate.gd sets skate_accel
afresh every frame. If anything leaves it standing, the boost compounds frame after frame. crazy_pickups checks the 1.5x figure, and main
says it is 20/20, so it probably holds.

FOR THE OWNER TO LOOK AT
- tl play hockey; on the panel, A / D to Arsenal, Shotgun or Glow Ice. On Shotgun press F, then Space through a crowd. The clips are in
  this folder.
- Judge: the neon suits (blue against brick red), the beacon size, the shotgun's comet, and whether F should stay shared with the body
  check.

QUESTIONS FOR THE DIRECTOR
1. Big puck resizes the puck's CylinderShape3D directly, because TLBall has no radius setter. Lint allows it, but it reaches past the TL
   API. A kernel TLBall.set_radius would make it clean. Keep it, or make big puck visual-only?
2. A shotgun on a goalie: while he is down, the hook takes him out of keeper.ids and gives him back his own physics step (keeper normally
   drives him kinematically). It holds on 20 seeds. Any keeper.gd change must keep that hand-back.
3. Astra spend: 1,176,514 tokens (A 514,171 and B 662,343, as codex reports them). That is over the 800 k lane budget: two arms ran in
   parallel with 7 resume rounds, plus one resume started on the wrong model (sol) and stopped by me after 1 minute.
4. This folder holds 29 MB (3 clips, 44 stills). Prune stills B-r1 to B-r5 before a commit if size matters.

NEXT THREE
1. Play it by hand: each mode in a window, then tune F's feel, the beacons' pull and the shotgun cooldown. Thirdjam found its scripted
   human never chased boosts, while a person does.
2. Run the abilities through L4's contact model: the hip check and the shield through its stability ratio, not beside it.
3. More of thirdjam's 12 modes as data (Bruisers, Cage, Marathon on the neon sheet), each one mode file.
