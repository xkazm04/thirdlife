# N-newcomer proof: a newcomer's first minute in robots, shield wall and Arsenal (juice day, 27 Nov 2026, 19:30-21:30)

Tree `C:/Users/kazda/kiro/third-life/.claude/worktrees/d27-newc` (branch d27-newcomer, main 48a7e24b). Job copies (plain
`cp -r` at 19:31 from `d25-biplane/.tl/jobs/`, every original's last `job_state` was `done`; originals untouched) in
`C:/Users/kazda/kiro/third-life/.claude/worktrees/d27-newc/.tl/jobs/`:
- `robot-soccer-3-v-20261125-1` (newest v0.1.11, last seq 1785);
- `shield-wall-3-v-20261125-1-jb` (newest v0.1.16, last seq 1462);
- `three-against-three-hockey-20261125-1` (newest v0.1.30, last seq 1410).

Each sentence went through the Create door: `engine/ui/foreman_run.mjs` + `foreman change <job copy> "<sentence>"`
with the `change` flags of `engine/ui/flags/real.json` (claude-cli, Sonnet builders, real and paid). Word for word:
`SENTENCES.md`. Times are the machine's local clock (the job logs print UTC, one hour behind). No foreman/, engine/ or
contracts/ edits; no selftests.

## Verdict

In all three games a newcomer did not meet the newest crazy ability in his first minute, or met it and did not
understand it. Each time the cause was the screen, not the ability: a key nobody names (robots' Q), a key that looks
broken (shield's frozen "G 10"), or a screen that says the wrong thing (Arsenal's HOME still describes the old bubble,
and MEGA starts with no reason given). One sentence per game fixed the worst thing on the first try. Every package
merged in its first round: no refusal, no bend, no question. A second sentence then fixed the next thing in shield
(a Q press lost while busy) and Arsenal (the new HOME lines ran off the card). Robots needed none.

| Game | Newcomer's worst thing (first minute) | Sentence -> version (time, calls, tokens in / out) | Newcomer after (headless, his first minute) | Menu pick |
|---|---|---|---|---|
| Robot soccer | Q never shown; rivals YOINK! the ball off him with "Yanked: pass before the blue ring closes" | 1 -> **v0.1.12** (34 min, 2, 1.04M / 8.2k) | sees "Hold Q, let go: YANK IT" 21-27 s in, 2 Q tries, 1 yank caught (seeds 1, 2); v0.1.11: 0 | **v0.1.12** |
| Shield wall | "G 10" small, grey, never counts (round 1 lock until the Q call); nothing teaches the answer to the gulls' red circles | 1 -> v0.1.17 (18 min, 2, 1.27M / 9.6k); 2 (Q lost while busy) -> **v0.1.18** (27 min, 3, 1.61M / 10.9k) | his own volley 1 a minute (v0.1.16: 0); "RED CIRCLE" hint at the gulls' first volley; Q taps while busy: 6 of 6 start a call (v0.1.17: 3 of 6) | **v0.1.18** |
| Arsenal hockey | HOME says "F pops your bubble" (F is the meteor); YOU ARE MEGA! 10 s in with no reason | 1 -> v0.1.31 (21 min, 4, 2.23M / 22.3k); 2 (HOME lines cut off) -> **v0.1.32** (11 min, 2, 0.70M / 5.1k) | "YOUR CHECK MADE YOU MEGA: BUMP THEM FLAT" 1-3 times, "HIS CHECK MADE HIM MEGA: KEEP AWAY" 0-2 times in his first minute | **v0.1.32** |

Total editor spend on this lane: 13 model calls (builders and Planner turns as `builder_run` events, `.tl/n/cost.py`),
6.85M tokens in (6.27M of them cache reads), 56.1k out, over 5 promotions.

**For the owner to play** (pack paths for the Director's menu rows):
- `C:/Users/kazda/kiro/third-life/.claude/worktrees/d27-newc/.tl/jobs/robot-soccer-3-v-20261125-1/promoted/game.robot_soccer_3_v@0.1.12`
  - "Robot soccer v0.1.12: the magnet taught (made in Create, juice day)" (keys: hold Q and let go = yank; F hammer)
- `C:/Users/kazda/kiro/third-life/.claude/worktrees/d27-newc/.tl/jobs/shield-wall-3-v-20261125-1-jb/promoted/game.shield_wall_3_v@0.1.18`
  - "Shield wall v0.1.18: the catapult taught (made in Create, juice day)" (keys: Q call first, then G volley; RMB or
    Space shield, overhead under the stones)
- `C:/Users/kazda/kiro/third-life/.claude/worktrees/d27-newc/.tl/jobs/three-against-three-hockey-20261125-1/promoted/game.three_against_three_hockey@0.1.32`
  - "Arsenal hockey v0.1.32: meteor and MEGA told true (made in Create, juice day)" (keys: F meteor then hold LMB;
    RMB body check = MEGA)
- In-between versions (shield v0.1.17, Arsenal v0.1.31) are in the same `promoted/` folders and need no rows. The
  version numbers 0.1.12 / 0.1.17-0.1.18 / 0.1.31-0.1.32 exist only in my job copies; the pack ids are the existing
  rows' ids.

Nobody has played these with real keys. Every figure is from scripted hands, every "sees" line from film and stills I
looked at.

## How the newcomer played (method; instruments copied into `tools/` as `.txt`)

- **The exe, open loop (J2nd's method).** `C:/Users/kazda/kiro/third-life/dist/ThirdLife/ThirdLife.exe` (build cafb68d,
  19:02 today) with `-- --dungeon=<promoted pack> --seed=1`, a window at 0,1440, `--write-movie` at 60 fps, the repo's
  window lock (`tools/execlip.sh.txt`). The keys come from `TL_EXE_KEYS`, made by `tools/keys.mjs.txt` (seeded, open
  loop): only keys the screen has shown him (read from each pack's hint code, then checked on the film), pressed late,
  in uneven bursts, some missed. The exact streams are saved beside each run (`.tl/n/r/*.keys.txt`).
  - Limits, said plainly: `TL_EXE_KEYS` has keys and mouse moves but **no mouse buttons**. Shield's lesson says "RIGHT
    MOUSE" / "LEFT MOUSE": he presses Space and J, the pack's own keys for the same actions. Arsenal shoots and checks
    only with the mouse buttons, so in the exe he skates, moves the cursor, presses F and never shoots or checks.
    An open-loop stream does not react to the screen: in robots it never left the scripted opening (it never tackled
    the carrier or scored).
- **The engine in a window, closed loop** (`tools/clipw.sh.txt`: this tree's engine, `host.tscn` worker, a test's hand
  pressing the pack's actions through `ctx.input`, movie writer, the same window lock). This is the newcomer who reacts
  to the screen, with the mouse buttons. It is not the exe; the pack and the Godot build are the same (4.7.2, d3d12).
- **The newcomer hands** (FILM COPIES ONLY, under `.tl/n/film/`; not pack tests):
  - `n_robot.gd`: the pack's own newcomer hand (`tests/ai_support/play.gd`, TLHand "newcomer"), plus F (hold 40-90
    frames, let go, every 5-8 s) once the opening is over and the hint says SMASH, plus Q only when the hint line names
    Q (60-150 frames late, 3 in 10 missed). Counts every hammer and magnet event by side.
  - `n_shield.gd`: a newcomer captain through TLHand "newcomer": the lesson's shield and bash, a late cut when his rival
    is open, Q 60-150 frames after "Q: captain's call" shows, G when a hint line names G, and one lit key of the key
    row every 5-9 s whether or not it is the moment. Counts the volley's published state, the words, the hints.
  - `n_hockey.gd`: a newcomer's first match at ROOKIE through the key and mouse mapping (after the pack's
    `bot_match_hand.gd`), slower (re-decides every 30 frames, the pack's hand 12), cursor up to 3 m off, 3 in 10 shots
    never taken, checks a carrier half the time; F 60-150 frames after an "F: METEOR" line, and lit and carrying he holds
    shoot 30-60 frames wherever he is. Counts the core's events by side and the hint plate.
  - `n_shield_q.gd`: the shield newcomer, but his Q is tapped on a timer while the call bar is ready, not at a free
    moment; for each tap, his state and whether a call started within 600 frames.
- Every headless run: 3600 frames, 0 script errors, 0 engine errors (`smoke.no_script_errors` /
  `smoke.no_engine_errors`), hash read twice on seed 1.

## Robot soccer (magnet yank on Q, sledgehammer on F)

### v0.1.11: the newcomer's first minute
- **Exe, open loop** (`clips/n_robot_v0111_exe_newcomer_opening.mp4`, 28 s; `stills/robot_v0111_exe_40-62s_sheet.jpg`):
  the match opens in a scripted lesson: a blue robot carries the ball, the hint says **Space: slide**. His stream never
  tackles him, so for the whole 80 s the hint stays "Space: slide", the opening never ends, and he meets neither the
  hammer cue nor the magnet. (The open loop's limit; the closed loop below gets out.)
- **Window, closed loop** (`clips/n_robot_v0111_window_yanked_no_q.mp4`, 26 s from 22 s; stills
  `stills/robot_v0111_window_yoink_sheet.jpg`, `stills/robot_v0111_window_no_q_meter_30s.jpg`):
  - his side scores and the opening ends at 24 s; "Hold F, let go: SMASH" comes up and he swings;
  - at 31 s and 42 s a blue robot's beam rips the ball off him: **YOINK!** big in yellow, and the hint line says
    "Yanked: pass before the blue ring closes";
  - a thin blue bar floats over his robot with no letter on it. **Nothing on the screen ever says Q.** He reads the
    magnet as the rivals' weapon.
- **Headless, the newcomer hand** (seeds 1 and 2, 0 errors; seed 1 **df762275 twice**, seed 2 ab38c2ef): the opening
  ends at frame 1418 / 1110; then rivals beam 9-12 times in his first minute and yank the ball 7-8 times (twice off
  him in seed 1); **his Q tries: 0** (the hints he saw: Space: slide, Hold Space: shoot, Hold A or D, Hold F let go:
  SMASH, Yanked: pass before the blue ring closes).

### Sentence 1 (19:52:29) -> v0.1.12 (promoted 20:26:55, 34 min) **<- the robots pick**
- Planner (4 s) named core ("Core owns the files this change touches ... the hint line ... the blue meter"); core r24
  merged on its first round (`data/tuning.json`, `scripts/view/magnet_look.gd`, `scripts/view/show.gd`).
  **Cost: 2 model calls, 1.04M tokens in (0.96M cache reads), 8.2k out.**
- What it made, in the builder's words: a big Q (Label3D, 120) beside the meter, dim while charging, yellow and pulsing
  when full; after the hammer's cue, "Hold Q, let go: YANK IT" while the meter is full and the ball is loose or a
  rival's within reach, until his first yank; the loss answer "YANKED! Hold Q to yank it back" (hint line and end card).
- The card also said "balance moved by your change: built as you asked; matches now run longer (the Foreman's test
  needed about 1.1 times the frames it planned)". **This is false for this change** (editor finding 1): the pack's own
  newcomer hand plays v0.1.11 and v0.1.12 to the same hash (970837d6, 3600 frames, seed 1); the change is drawing only.
  The tofu bot was already over its frames before (J2b's finding 2).
- Hands over 20 seeds (the Foreman's final checks, read from `reports/final-hand-*-s18[3-7]*.json`): **newcomer 15 of
  20, perfect 20 of 20** (v0.1.11: the same, 15 and 20, J2b). The pack's newcomer hand never presses Q, so this says
  only that nothing else moved.
- v0.1.12 = my film copy `robot12c` (`diff -rq`: only `pack.json`'s tests list and my test).
- **Headless, the newcomer hand that reads the hint line** (0 errors; seed 1 **a111e01c twice**, seed 2 797c0626): "Hold
  Q, let go: YANK IT" shows at frame 1620 / 1276 (27 s / 21 s); **he tries Q twice and yanks a loose ball once, caught,
  in each seed** (v0.1.11: 0 tries).
- **Window** (`clips/n_robot_v0112_window_q_cue_yank.mp4`, 22 s from 22 s; `stills/robot_v0112_window_q_cue_yank_sheet.jpg`,
  `stills/robot_v0112_window_q_lit_hint_28s.jpg`): a yellow **Q** sits beside the blue meter over his robot and the hint
  line reads **Hold Q, let go: YANK IT**; at 30 s his own beam pulls the ball up in a high arc with a blue trail into his
  feet, then "Tap Space: pass". The magnet is his now. Still small: the hint line is plain white text at the bottom,
  the same size as every hint.
- Not done: no exe run of v0.1.12 (the open-loop stream never leaves the opening, so it would show the same 80 s as
  v0.1.11); the window run above is the evidence.

## Shield wall (charge F, slam C, call Q, catapult volley G)

### v0.1.16: the newcomer's first minute
- **Exe, open loop** (`clips/n_shield_v0116_exe_newcomer_g10_frozen.mp4`, 30 s from 14 s; stills
  `stills/shield_v0116_exe_g10_frozen_44s.jpg`, `stills/shield_v0116_exe_20-38s_sheet.jpg`):
  - the lesson reads well: "Hold RIGHT MOUSE: shield up", then "Now bash: keep holding, click LEFT MOUSE", then "He is
    wide open: let go and click LEFT MOUSE", then "Q: captain's call" with CAPTAIN'S CALL READY at the top left;
  - the key row shows RMB BLOCK, LMB BASH, Q CALL, F READY, C READY. The catapult is **not in it**: "G 10" sits small,
    grey, alone at the right edge, and **never counts down** for the whole minute (round 1 keeps the volley locked
    until the crew's first captain's call, and nothing says so);
  - his three Q presses in 65 s started no call (see the probe below), so he never got the catapult; the longship sits
    on the sea at the right, doing nothing for him;
  - the screen is busy: HEALTH/STAMINA plates of both captains, YOU, HIT FROM BEHIND/SIDE and the hint line all over
    the fight in the middle of the screen.
- **Window, closed loop** (`clips/n_shield_v0116_window_gulls_volley_no_answer.mp4`, 14 s; `stills/shield_v0116_window_gulls_volley_sheet.jpg`):
  once he calls (Q), "G READY" appears small at the right; the gulls' red discs land under him, KABOOM!, men flung;
  no line tells him what to do under the red circle.
- **Headless, the newcomer hand** (0 errors; seed 1 **833d92d5 twice**, seed 2 3739ddcd): lesson over at frame 334 /
  636; he calls once; **his crew's volleys 0, the gulls' 1-2**; men thrown 1, turtled 0; KABOOM! 0-1. (Without a Q
  press, a first run of the same hand saw no volley at all in round 1, for either side.)

### Sentence 1 (20:02:03) -> v0.1.17 (promoted 20:20:27, 18 min)
- Planner (4 s) named volley; volley r5 merged first round (`data/volley.json`, `scripts/volley/mod.gd`,
  `scripts/volley/show.gd`). **Cost: 2 model calls, 1.27M tokens in (1.17M cache reads), 9.6k out.**
- Built, in its words: the cooldown counts from the first live frame of the round for both crews (the lock itself
  stays: no volley before the first call and the lesson's end); G is a sixth key in the row ("G READY / READY
  CATAPULT", dim with "after your Q call" while locked, the seconds while cooling); "G: call the catapult on them" once;
  "RED CIRCLE: step out, or hold RIGHT MOUSE over your head" when the gulls' circles land under him.
- v0.1.17 = my film copy `shield17c` (`diff -rq`: only `pack.json`'s tests list and my test).
- **Headless, the newcomer** (0 errors; seed 1 **95f4c26d twice**, seed 2 08e7ec9c): "G: call the catapult on them" at
  frame 601 / 806, "RED CIRCLE" at the gulls' first volley (780 / 986); **his own volley 1 in his first minute in each
  seed (v0.1.16: 0)**; gulls 2-3; turtled 1 (TURTLE! seen), escaped 1-2.
- **Window** (`clips/n_shield_v0117_window_g_key_red_circle_turtle.mp4`, 22 s; `stills/shield_v0117_window_red_circle_hint.jpg`,
  `stills/shield_v0117_window_g_red_circle_turtle_sheet.jpg`, `stills/shield_v0117_window_loose_kaboom_sheet.jpg`): an
  orange **G READY / READY CATAPULT** key at the end of the key row; the gulls' red discs land under him with **RED
  CIRCLE: step out, or hold RIGHT MOUSE over your head** across the screen; he holds the shield and **TURTLE!** comes up
  twice in gold; later his own **LOOSE!** and **KABOOM!**. The catapult is a thing he can find and answer now.
- **Exe** (`clips/n_shield_v0117_exe_newcomer_g_key.mp4`, 25 s; `stills/shield_v0117_exe_key_row_sheet.jpg`): G sits in
  the key row, dim, with "after your Q call"; but the open-loop stream's three Q presses again started no call.

### Why Q failed (a probe, `n_shield_q.gd`: Q tapped on a timer while the call bar reads ready)
- v0.1.17, seeds 1-3, 0 errors: **3 of 6 taps lost** (in WINDUP once, in HITSTOP twice: nothing heard, nothing said);
  the 3 taps in BLOCK started a call 1 frame later. A newcomer is hit a lot, so his Q lands in a busy moment often.
  (A first version of my probe held Q down after its first press, so its later "nothing" lines were void; I found it,
  fixed it to tap, and reran. Only the rerun is quoted.)

### Sentence 2 (20:42:04) -> v0.1.18 (promoted 21:09:23, 27 min) **<- the shield pick**
- The Planner named rally; rally r4 handed the Q key's label to core ("outside my scope"), core r23 made it; both
  first round. **Cost: 3 model calls, 1.61M tokens in (1.46M cache reads), 10.9k out.**
- Built, in their words: a press while busy is kept up to 600 frames and the horn blows on the first free frame; "CALL
  WHEN UP" on the Q key and the call label; "CALL NOT READY" (with a beep) when the bar is not full. **Deviation, said
  on the card:** a press while knocked down (KNOCKDOWN, GETUP, WALLSPLAT) is not kept: the hint says "CALL: STAND UP
  FIRST" instead (I asked to keep it then too).
- v0.1.18 = my film copy `shield18c` (`diff -rq`: only `pack.json`'s tests list and my tests).
- **The probe on v0.1.18**, seeds 1-3, 0 errors: **6 of 6 taps start a call**; the three busy ones (WINDUP once,
  HITSTOP twice) 24-26 frames later. Hashes 7d9a4179 / 7d8b42c3 / 9eb2e9d2 (v0.1.17 with the same probe: 62a64277 /
  4e0d92f2 / 7ba58c28).
- **Headless, the newcomer** (0 errors; seed 1 **b0341c1a twice**, seed 2 08e7ec9c, the same as v0.1.17's seed 2 because
  his one tap there came at a free moment): "CALL WHEN UP" shows once (frame 2366, seed 1); his own volley 1, gulls 2-3,
  turtled 1-2.
- **Window** (`clips/n_shield_v0118_window_newcomer.mp4`, 20 s from 30 s; `stills/shield_v0118_window_call_when_up.jpg`,
  `stills/shield_v0118_window_call_when_up_sheet.jpg`): 56 s on the clock, he is bracing in a scrum (BRACED!, OPEN: HIT
  NOW) when he presses Q: **CALL WHEN UP** comes up on the hint line and the Q key lights; a moment later the horn's
  sparks burst and the CAPTAIN'S CALL bar drains (the call went off), then the gulls' volley lands with the RED CIRCLE
  line. Small miss: the Q key's own label still reads "CALL" in that frame (core r23 shows "CALL WHEN UP" on the key only
  while the call label says so); the hint line says it.

## Arsenal hockey (meteor on F, MEGA from a landed body check)

### v0.1.30: the newcomer's first minute
- **Exe** (`clips/n_ars_v0130_exe_home_bubble_text_mega.mp4`, 28 s; stills `stills/ars_v0130_exe_home_bubble_text.jpg`,
  `stills/ars_v0130_exe_flattened_14s.jpg`):
  - the first thing he reads, HOME's ONE MATCH card, says **"F pops your bubble: checks bounce off, pokes do not."**
    and "First to five goals wins." Both are old: F is the METEOR now, and the match is three minutes on the clock;
  - (a first exe run pressed Enter once and sat on HOME for 80 s: PLAY NOW needs a second Enter. The second run pressed
    it twice.) In the match an orange arrow at the edge says **MEGA! 22 m**, a rival grows, and **FLATTENED!** comes up
    over him: nothing has told him why a rival is a giant. (He cannot shoot or check here: the exe has no mouse
    buttons.)
- **Window, closed loop** (`clips/n_ars_v0130_window_you_are_mega_no_reason.mp4`, 22 s; stills
  `stills/ars_v0130_window_meteor_hint_4s.jpg`, `stills/ars_v0130_window_you_are_mega_12s.jpg`):
  - the meteor is taught well: "F: METEOR  Light your stick, then hold shoot to wind up" on the hint plate and "F:
    METEOR READY" at the right; he lights it and his METEOR! shot scores at about 18 s;
  - 10 s in his check lands and **YOU ARE MEGA!** fills the top of the screen, his skater doubles in size: nothing says
    his check did it, and the panel only says "RMB CHECK".
- **Headless, the newcomer hand** (0 errors; seed 1 **49bb62e9 twice**, seed 2 1960c6ba): he fires the meteor 3 times
  (`ability:me` 3, both seeds); MEGA starts on him 0-1 times and on rivals 2-3 times; knockdowns of him 1-3; score 1:3 and 1:2.

### Sentence 1 (20:11:23) -> v0.1.31 (promoted 20:32:05, 21 min)
- Planner (5 s) named harbour; harbour r23 made the MEGA lines and handed two parts on, and T's routing sent them right:
  the HOME text to skin (r3: data only), the panel row back to harbour (r24: "the files it names are the base's"), which
  drew its own copy of the panel. All merged first round. **Cost: 4 model calls, 2.23M tokens in (2.04M cache reads),
  22.3k out.**
- skin r3 also changed "First to five goals wins." to "Three minutes on the clock, most goals wins." (on the card; the
  cartridge has a 3-minute clock and no score to win: the old line was false). harbour r24 said plainly that the base's
  HOME "YOUR STICK" line and the pause card still read "RMB CHECK" (base scripts no package changes).
- Sim unchanged: the pack's own first-match hand plays v0.1.30 and v0.1.31 to the same hash (28c8f9f9, 3600 frames).
- **Headless, the newcomer** (0 errors; seed 1 **fa9b55c3 twice**, seed 2 df84bf3c): "YOUR CHECK MADE YOU MEGA: BUMP THEM
  FLAT" 3 times (seed 1) / 2 times (seed 2), "HIS CHECK MADE HIM MEGA: KEEP AWAY" 0 / 2 times in his first minute.
  (His hash moved because my hand reads the left hint plate: while a MEGA line holds it, he does not see "METEOR LIT"
  there and lights or fires less: seed 1 F presses 7 -> 2. The game still shows "F: METEOR NEXT SHOT" on the right
  plate, so a person would see it; this is my instrument, not the game.)
- **Window** (`clips/n_ars_v0131_window_your_check_made_you_mega.mp4`, 22 s; `stills/ars_v0131_window_your_check_mega_hint_panel.jpg`,
  `stills/ars_v0131_window_mega_sheet.jpg`): YOU ARE MEGA! with **YOUR CHECK MADE YOU MEGA: BUMP THEM FLAT** on the hint
  plate and **RMB CHECK: GO MEGA** in the controls panel. It says why now. The plate is small (one line of condensed
  type at the lower left).
- **Exe** (`clips/n_ars_v0131_exe_home_truth_mega_lines.mp4`, 28 s; `stills/ars_v0131_exe_home_text_overflows.jpg`,
  `stills/ars_v0131_exe_first_40s_sheet.jpg`, `stills/ars_v0131_exe_meteor_hint_13s.jpg`): HOME tells the truth, but the
  two new lines run past the card's right edge ("...your shot floors everyone." and "...bump them" stick out, "flat." is
  cut off). In the match: "HIS CHECK MADE HIM MEGA: KEEP AWAY" while an orange MEGA! arrow points at the giant.

### Sentence 2 (20:52:05) -> v0.1.32 (promoted 21:03:21, 11 min) **<- the Arsenal pick**
- The Planner named harbour; harbour r25 merged first round (`data/tuning.json`, `scripts/main.gd`). **Cost: 2 model calls,
  0.70M tokens in (0.64M cache reads), 5.1k out.** It put the card's lines in its own `harbour.about_lines` and draws them
  over the skin's `about` list, which is now never shown (editor finding 3).
- **Exe** (`clips/n_ars_v0132_exe_home_card_fits.mp4`, 24 s; `stills/ars_v0132_exe_home_text_fits.jpg`): every line fits
  in the card: "F: METEOR. Light your stick, hold shoot: / your shot floors everyone." and "Land a body check (RMB): you
  go MEGA, / twice the size. Bump them flat."
- **Headless**: the newcomer plays v0.1.32 exactly as v0.1.31 (**fa9b55c3 twice**, seed 2 df84bf3c); the pack hand
  28c8f9f9 on all three versions. Not re-filmed in the window: the match is v0.1.31's, byte for byte in play.
- No final hand checks for shield or Arsenal: their reports hold no `final-hand-*` files (their cards ask none).

## Editor findings (for the Director and the T lanes)
1. **A drawing-only change is told "balance moved by your change".** Robots v0.1.12's card says "matches now run longer
   (the Foreman's test needed about 1.1 times the frames it planned)". The change only draws (the pack's newcomer hand
   hashes 970837d6 on v0.1.11 and v0.1.12); the tofu bot was over its frames before. Evidence: robots copy event 1828;
   `.tl/n/r/robot11_packnew.json`, `robot12c_packnew.json`.
2. **A builder narrows an ask and the card says so only in its notes.** Shield v0.1.18: I asked to keep Q pressed while
   down; rally keeps it only while busy, and drops it when knocked down ("CALL: STAND UP FIRST"). Said in the deviation
   note, not as "part of your change was NOT made". Evidence: shield copy event 1513.
3. **Two packages now own one text.** Arsenal v0.1.32: harbour draws its own `about_lines` over skin's `about`, so the
   skin's text is dead data that a later change can edit to no effect. The request ("make every line fit") belonged to
   skin's data; harbour did not hand it on. Evidence: Arsenal copy event 1496.
4. (Good news, recorded) Every one of the 5 sentences was routed to the right package by the Planner in 4-5 s, every
   NOT DONE hand-off reached its owner (robots none; shield rally -> core; Arsenal harbour -> skin and back to harbour),
   and every round merged first time.

## Newcomer-instrument findings (for the T lanes / the newcomer bar)
- **The pack hands never meet the newest ability.** Robots' `bot_hand_newcomer.gd` never presses Q; shield and Arsenal
  have no newcomer hand on their cards at all. So the card's newcomer figure (robots 15 of 20) says nothing about
  whether a newcomer finds the crazy ability. Only a hand that reads the screen does.
- `TL_EXE_KEYS` cannot press mouse buttons; two of these three games teach with the mouse.

---

# Round 2 (Director, 22:05): karts, biplane, court, and the shield clutter (22:10-)

Tree unchanged: main from 48a7e24b, foreman not rebuilt (the Director did not merge main here). Job copies (plain
`cp -r` at 22:10; every original's last `job_state` was `done`; originals untouched), in
`C:/Users/kazda/kiro/third-life/.claude/worktrees/d27-newc/.tl/jobs/`:
- `bumper-kart-football-3-20261125-1` from `d25-kart/.tl/jobs/j2nd/` (newest v0.1.11, last seq 1793);
- `biplane-duel-two-biplanes-20261125-1` from `d25-court/.tl/t2e/jobs/` (newest v0.1.9, last seq 1063);
- `half-court-3-v-20261125-1` from `d25-kart/.tl/jobs/j2nd3/` (newest v0.1.9, last seq 2180).
Shield went on in my own copy (v0.1.18 -> v0.1.19). Same method as round 1: the exe in a window with a told-keys-only
open-loop stream (`tools/keys.mjs.txt`, games `kart`, `plane`, `court` added), the engine in a window with a closed-loop
newcomer, headless newcomer hands. The newcomer hands this round: J2nd's `j2n_shell.gd` (karts) and `j2n_harpoon.gd`
(biplane, TLHand "newcomer") as J2nd wrote them, so the figures compare with J2nd's; `n_kart.gd` (j2n_shell plus a log
of the big shell word and whose shell it was); `n_court.gd` (the pack's newcomer hand plus J2nd's C press, which he only
makes once a hint line has named C; it reads the game's hint line and, from v0.1.10, the lesson's own line).

## Round 2 verdict (00:33)

Again the worst thing in each newcomer's first minute was what the screen said or hid, and one sentence fixed it on its
first round each time; biplane and court took their one follow-up. 6 sentences, 6 promotions, 16 model calls, 9.41M tokens
in (8.62M cache reads), 77.2k out.

| Game | Worst thing (first minute) | Versions | Newcomer after | Pick |
|---|---|---|---|---|
| Shield wall | hint line, HEALTH/STAMINA plates and head tags all over the fight | -> v0.1.19 (22 min) | middle clear; plays as v0.1.18 | **v0.1.19** |
| Karts | SHELLED! big for every hit on the deck: was it me? | -> v0.1.12 (34 min) | YOU'RE SHELLED! by Mint 2 / GOT HIM! / small tags; hands 16/20, 19/20 | **v0.1.12** |
| Biplane | the harpoon pass happens below and behind him and ends after 15 s: 0 hooks | -> v0.1.10 (32 min), follow-up -> v0.1.11 (29 min) | 1 hook in his first minute (was 0); in the exe Vesper sits above his nose under Q NOW!, the blind stream hooks her | **v0.1.11** |
| Court | C is never named | -> v0.1.10 (54 min), follow-up -> v0.1.11 (40 min) | big yellow C: ALLEY-OOP over the open mate, on the hint line 2-3 times; hands 17/20, 20/20; one bottom line, the commentary on a strip under the score | **v0.1.11** |

Pack paths and titles: REPORT.txt "MENU (round 2)". Court v0.1.10/v0.1.11 carry an unasked play change from a stale
package workspace (finding 5), and a faint ghost of the old commentary line remains at the top left of court v0.1.11.

## Shield wall: the clutter (sentence 22:11:12 -> v0.1.19, promoted 22:33:23, 22 min) **<- the new shield pick**
- What the newcomer saw (v0.1.16-v0.1.18, round 1's films: `stills/shield_v0116_exe_20-38s_sheet.jpg`,
  `stills/shield_v0118_window_call_when_up.jpg`): the hint line floats in the middle of the screen across the fighters;
  big HEALTH ||||| / STAMINA ||||| text plates for his captain (left) and the locked rival (right) sit over the quay;
  YOU, OPEN: HIT NOW and HIT FROM BEHIND/SIDE stack over the heads.
- The Planner named core; core r24 merged first round (`scripts/show.gd`, `data/tuning.json`). **Cost: 2 model calls,
  0.86M tokens in (0.79M cache reads), 7.6k out.** In its words: the hint is drawn on a dark strip above the key row;
  health and stamina are slim bars in the top corners (mine left, the locked rival right) with the name small above; the
  head tags are one short word, "OPEN!" or "FLANK!", else a tiny health mark; it no longer shows "YOU" over my man ("this
  differs from the contract's health+stamina large for controlled and its lock", said on the card).
- Drawing only: the newcomer hand plays v0.1.19 exactly as v0.1.18 (seed 1 **b0341c1a twice**, seed 2 08e7ec9c; 0 errors).
- **Window** (`clips/r2_shield_v0119_window_clear_middle.mp4`, 22 s; `stills/r2_shield_v0119_window_red_circle_strip.jpg`,
  `stills/r2_shield_v0119_window_10-17s_sheet.jpg`, `stills/r2_shield_v0119_window_call_when_up_40s.jpg`): the same
  0:56 moment as round 1's v0.1.18 still: the middle of the screen is the fight now; "CALL WHEN UP" and "RED CIRCLE: step
  out, or hold RIGHT MOUSE over your head" sit on a dark strip just above the key row; OPEN! is one short word over the
  rival. The corner bars are thin and small; the names over them are tiny.
- **Exe** (`clips/r2_shield_v0119_exe_newcomer.mp4`, 25 s; `stills/r2_shield_v0119_exe_g_ready_strip_20s.jpg`): the same
  open-loop stream as round 1, and this time his first Q press (made while busy) is kept by v0.1.18's change: the call
  goes off and **G READY / READY: CATAPULT** lights in the key row 20 s in (v0.1.16 and v0.1.17 with the same stream:
  never in the minute).

## Bumper-kart football (red shell on F, jump on Q)

### v0.1.11: the newcomer's first minute
- **Exe** (`clips/r2_kart_v0111_exe_newcomer.mp4`, 28 s; `stills/r2_kart_v0111_exe_f_hint_shell_held.jpg`,
  `stills/r2_kart_v0111_exe_shelled_whom.jpg`): J2nd's fix holds: rainbow boxes on the deck from GO!, the hint line
  stages "Drive through a rainbow box" -> "F fires a red shell" -> "Q jumps over one", and a held shell reads as a red
  disc over his tub. But at 2:43 **SHELLED!** fills the middle of the screen while four karts scrum round the ball:
  whose hit was it?
- **Window, closed loop** (`clips/r2_kart_v0111_window_shelled_whom.mp4`, 24 s; `stills/r2_kart_v0111_window_0-28s_sheet.jpg`):
  the same: SHELLED! big for every hit; after the first goal the hint line goes back to "W drive, SHIFT boost, SPACE
  bump its side" for the rest of the minute.
- **Headless** (`n_kart.gd`; seed 1 **08fe071f twice**, J2nd's hash for v0.1.11; seed 2 3a106ab0; 0 errors): 1-2 boxes,
  1 shell fired, shelled once; the big word came up 3 times in his first minute (seed 1): after his own shell's hit
  (frame 628), mint_2's hit on him (1161), and a hit by mint_2 and red_2 on others (2275). The same word each time.
- Read in the pack (`scripts/items/items.gd`): `shelled_text` is set on every hit, whoever fired and whoever was hit.

### Sentence (22:28:34) -> v0.1.12 (promoted 23:02:16, 34 min) **<- the karts pick**
- The Planner named items; items r5 merged first round (`data/items.json`, `scripts/items/items.gd`). The Foreman also
  sent "the rivals' part" to teams r8, which changed nothing ("needs no work in my files"). **Cost: 3 model calls,
  1.85M tokens in (1.70M cache reads), 12.0k out.**
- Built: **YOU'RE SHELLED!** big and red with "by <kart>" under it only when he is hit; **GOT HIM!** in red when his own
  shell hits; any other hit only a small red SHELLED! tag over that kart for 60 frames.
- v0.1.12 = my film copy `kart12c` (`diff -rq`: only `pack.json`'s tests list and my test). Drawing only: seed 1
  **08fe071f twice** (= v0.1.11), seed 2 3a106ab0; the big words in seed 1: GOT HIM! (628), YOU'RE SHELLED! (1161); the
  third hit is a tag. Hands over 20 seeds (the Foreman's final checks): **newcomer 16 of 20, perfect 19 of 20** (v0.1.11:
  16 and 19, J2nd).
- **Window** (`clips/r2_kart_v0112_window_got_him_youre_shelled.mp4`, 24 s; `stills/r2_kart_v0112_window_got_him.jpg`,
  `stills/r2_kart_v0112_window_youre_shelled_by_mint2.jpg`, `stills/r2_kart_v0112_window_got_him_shelled_sheet.jpg`):
  GOT HIM! in red over the far end when his shell lands; at 2:48 **YOU'RE SHELLED!** with "by Mint 2" over his own
  flipped tub.
- **Exe** (`clips/r2_kart_v0112_exe_newcomer.mp4`, 28 s; `stills/r2_kart_v0112_exe_same_hit_small_tag.jpg`): the very
  same 2:43 scrum as v0.1.11's still (same stream, same seed): the big SHELLED! is gone, a small red SHELLED! tag hangs
  over the kart that was hit. He can tell now.

## Biplane duel (harpoon on Q, roll on Shift)

### v0.1.9 (T2's copy): the newcomer's first minute
- **Exe** (`clips/r2_plane_v019_exe_harpoon_pass_below.mp4`, 28 s; `stills/r2_plane_v019_exe_q_hint_vesper_below.jpg`,
  `stills/r2_plane_v019_exe_0-28s_sheet.jpg`): "ARROWS fly, hold W", then the lesson's harpoon pass: "Q: harpoon her
  while she sits in front of your nose" for 15 s, while Vesper is a small blue VESPER arrow at the bottom edge, below and
  behind him; then the lesson moves on to "Follow them" without a hook.
- **Window, closed loop** (`clips/r2_plane_v019_window_no_hook_fly_on.mp4`, 28 s; `stills/r2_plane_v019_window_0-28s_sheet.jpg`,
  `stills/r2_plane_v019_window_fly_on_38s.jpg`): no hook either; "Harpoon: get Vesper in front of your nose, inside
  60 m" names no key; **"They loop behind you. Fly on."** stays on the screen for about 25 s and tells him nothing to do.
- **Headless** (`j2n_harpoon.gd`; seed 1 **c38ee476 twice**, seed 2 efb0aacf; 0 errors): 1-3 harpoon tries, **0 hooks**
  in his first minute; Vesper fires 0-1.
- Read in the pack (`scripts/first/first.gd`): the pass (`cross`) ends at `cross_max_f` 900 frames whether he hooked
  her or not.

### Sentence 1 (22:33:06) -> v0.1.10 (promoted 23:05:14, 32 min)
- The Planner named first_flight; first_flight r5 merged first round and handed its new numbers to core (r31, `data/tuning.json`
  `lesson` keys, "nothing plays differently"). **Cost: 3 model calls, 2.01M tokens in (1.84M cache reads), 17.9k out.**
- Built: the pass waits until one hook or 40 s; Vesper level at his height on his nose line, 32 m ahead, at 0.85 of his
  speed; a red ring and "Q NOW!"; a miss reloads at once in the pass; the loop line now reads "Vesper loops to get
  behind you: keep flying level". The card: "balance moved by your change: ... the share of test rounds where the lead
  changes hands: now 0, was 1", not judged.
- v0.1.10 = my film copy `plane10c` (`diff -rq`: only `pack.json`'s tests list and my test).
- **Headless** (seed 1 **e3af709a twice**, seed 2 06229c8e; 0 errors): **he hooks Vesper once in his first minute in
  each seed** (v0.1.9: 0), 3-4 tries.
- **Window** (`clips/r2_plane_v0110_window_hooked_in_lesson.mp4`, 26 s; `stills/r2_plane_v0110_window_hooked_sheet.jpg`,
  `stills/r2_plane_v0110_window_5s.jpg`): **HOOKED!** about 5 s in, "HOOKED! Now stay on her tail", then the new loop line.
  Caveat: this closed-loop pilot hooks her at about frame 300, the frame the pass begins, right after "She rolled off your
  harpoon" (the same in v0.1.11's window run, `clips/r2_plane_v0111_window_newcomer.mp4`,
  `stills/r2_plane_v0111_window_hooked_sheet.jpg`), so the window runs show the hook, not the pass's picture; the exe
  runs show the pass.
- **Exe** (`clips/r2_plane_v0110_exe_q_now_hidden.mp4`, 28 s; `stills/r2_plane_v0110_exe_q_now_vesper_behind_my_plane.jpg`,
  `stills/r2_plane_v0110_exe_17-35s_sheet.jpg`): "Q: harpoon Vesper, straight ahead of your nose" and **Q NOW!** with
  the red ring come up again and again, but from the chase camera she sits right behind his own fuselage: the ring is
  drawn on his plane and only a scrap of blue wing shows. The open-loop stream got no hook in the minute. Two hint lines
  also alternate in the pass ("Q: harpoon Vesper..." and "Harpoon: get Vesper in front of your nose, inside 60 m").

### Sentence 2 (23:18:11): Vesper above the nose line, one hint at a time
-> v0.1.11 (promoted 23:47:36, 29 min) **<- the biplane pick**
- The Planner named core; core r32 lifted her from `main` (`_lesson_lift`, `harpoon.lesson_up` 4.5 m) and said the pass
  itself lives in first_flight's script; first_flight r6 then placed her there directly (4.5 m above my nose line, 2.5 m
  to the right) and said the one-hint part was already done by core (the "Harpoon: get Vesper..." line is hidden in the
  pass). Both merged first round. **Cost: 3 model calls, 1.69M tokens in (1.53M cache reads), 12.9k out.** The card:
  "balance moved: ways of the core move that work: now 2, was 3", not judged.
- v0.1.11 = my film copy `plane11c` (`diff -rq`: only `pack.json`'s tests list and my test).
- **Headless** (seed 1 **4df31017 twice**, seed 2 eb7b3fba; 0 errors): he hooks her once in his first minute in each seed,
  3 tries (as v0.1.10).
- **Exe** (`clips/r2_plane_v0111_exe_q_now_visible_hooked.mp4`, 26 s; `stills/r2_plane_v0111_exe_q_now_above_nose.jpg`,
  `stills/r2_plane_v0111_exe_q_now_hooked_sheet.jpg`): Vesper's blue biplane now sits just above his nose in the upper
  middle of the screen with **Q NOW!** and the red ring on her, clearly apart from his own plane; one hint line ("Q:
  harpoon Vesper, straight ahead of your nose"). Even the blind open-loop stream **hooks her about 18 s in**: HOOKED!
  big and red, "HOOKED! Now stay on her tail". (v0.1.10 with the same stream: no hook in the minute.)

## Half-court 3 v 3 (alley-oop on C)

### v0.1.9: the newcomer's first minute
- **Exe** (`clips/r2_court_v019_exe_no_c.mp4`, 28 s; `stills/r2_court_v019_exe_0-28s_sheet.jpg`) and **window, closed
  loop** (`clips/r2_court_v019_window_no_c.mp4`, 28 s; `stills/r2_court_v019_window_0-28s_sheet.jpg`,
  `stills/r2_court_v019_window_ball_no_c_hint.jpg`): the hint line flips between "HOLD E ON THE CHALK" and "SPACE: SWAT AS
  THEY RISE" (in the first seconds it is drawn twice, a blurred copy under the first); **C is never named**; no cue over
  an open mate.
- **Headless** (`n_court.gd`, which presses C only once a hint names it; seed 1 **64240fb0 twice**, seed 2 51928ae2; 0
  script errors; every run's only error is the pack hand's own "not done within 3600 frames", it plays whole matches):
  the hint lines he saw in seed 1, 19 of them: chalk, swat, "SPACE: JUMP TO STEAL IT" once, "CLEAR IT PAST THE ARC";
  never C. The rivals throw and land an alley-oop in his first minute; he throws none.

### Sentence (22:43:01) -> v0.1.10 (promoted 23:37:23, 54 min) **<- the court pick**
- The Planner named bodies_first_minute; r5 merged first round (`data/clips.json`, `scripts/bodies/mod.gd`,
  `scripts/bodies/poses.gd`, `scripts/teach/mod.gd`); its note about where the cue's numbers live went on to
  court_exchange r21 as "the rest of your change", which copied them into `data/tuning.json` and made `scripts/main.gd`
  keep one hint line at a time. **Cost: 3 model calls, 1.56M tokens in (1.41M cache reads), 14.9k out.**
- Built: "C: ALLEY-OOP" at 64 pt in strong yellow over the open mate whenever he holds the ball and a mate is open, a
  pulsing ring at that mate's feet and a glow ball over his hand, every match; "C: ALLEY-OOP" on the hint line up to 3
  times a match once a mate newly opens.
- **Hands over 20 seeds** (the Foreman's final checks): **newcomer 17 of 20, perfect 20 of 20** (v0.1.9: newcomer 17 of
  20).
- v0.1.10 = my film copy `court10c` (`diff -rq`: only `pack.json`'s tests list and my test).
- **Headless** (seed 1 **181bc670 twice**, seed 2 3c3c439a): "C: ALLEY-OOP" reaches his hint line 2-3 times in his first
  minute (frames 699, 903, 2051 in seed 1; first at frame 218 in seed 2). **Play moved, unasked:** the pack's own newcomer hand (which
  never reads the screen) hashes 64240fb0 on v0.1.9 and 181bc670 on v0.1.10. The cause I found: bodies_first_minute
  merged `scripts/bodies/poses.gd` and `mod.gd` from its own workspace, which lacks v0.1.9's pose cache (`pose_step_f` /
  `resync_f` from `data/crews.json` are no longer read). The card does not mention it (editor finding 5 below).
- **Window** (`clips/r2_court_v0110_window_c_alley_oop_cue.mp4`, 22 s; `stills/r2_court_v0110_window_c_cue_11s.jpg`,
  `stills/r2_court_v0110_window_c_cue_sheet.jpg`): 11 s in, with the ball, **C: ALLEY-OOP** in big yellow letters
  stands over his open mate at the right wing, a yellow ring at the mate's feet and a big yellow glow over his hand;
  readable from the play camera. Two hint lines are drawn stacked for a moment ("C: ALLEY-OOP" over "HOLD E ON THE
  CHALK").
- **Exe** (`clips/r2_court_v0110_exe_newcomer_off_ball.mp4`, 28 s from 30 s; `stills/r2_court_v0110_exe_30-58s_sheet.jpg`,
  `stills/r2_court_v0110_exe_overlapping_labels_54s.jpg`): the open-loop stream is off the ball the whole minute, so the
  cue never comes up for him (it needs him holding the ball with a mate open); the rivals' STOLEN! and ALLEY-OOP! read
  big. At 0:53 the top-left commentary line ("YOUR MAN NOW - MOSS: ...") is drawn over another line, the letters pile
  into each other, and the score is gone while it shows.

### Sentence 2 (23:45:55) -> v0.1.11 (promoted 00:26:04, 40 min) **<- the court pick**
- The Planner named court_exchange; r22 merged first round (`data/tuning.json`, `scripts/main.gd`). **Cost: 2 model
  calls, 1.44M tokens in (1.35M cache reads), 11.9k out.** Built, in its words: one bottom "hint" label for everything
  (the lesson's own label kept empty); the crews module's "matchup" line drawn by `main` on a new dark strip centred under
  the score (the old label "kept but drawn invisible").
- Drawing only: seed 1 **181bc670 twice** (= v0.1.10), seed 2 3c3c439a. Hands over 20 seeds: **newcomer 17 of 20,
  perfect 20 of 20**. v0.1.11 = my film copy `court11c` (`diff -rq`: only `pack.json`'s tests list and my test).
- **Window** (`clips/r2_court_v0111_window_one_line.mp4`, 22 s; `stills/r2_court_v0111_window_one_bottom_line_11s.jpg`):
  the same 0:11 moment as v0.1.10: one bottom line, "C: ALLEY-OOP", under the big cue over the open mate; no stack.
- **Exe** (`clips/r2_court_v0111_exe_commentary_strip.mp4`, 28 s from 30 s; `stills/r2_court_v0111_exe_commentary_strip_54s.jpg`):
  the same 0:53 moment: the score CREW 5 - 7 QUARRY stays, and "YOUR MAN NOW - MOSS: SHOOT OVER MOSS" reads on a dark
  strip right under it. **Not fully fixed:** a faint ghost of the old top-left line still shows behind the score's left
  end (the "invisible" label is not fully transparent in that frame). My one follow-up is spent; this is for the next
  pass.
- Both window runs (v0.1.9 and v0.1.10) printed one SCRIPT ERROR at exit from the kernel runner's watchdog thread
  (`res://kernel/runner/worker.gd:387`, "Cannot call method 'lock' on a null value"), not from the pack; every headless
  run: 0 script errors.

## Round 2 editor findings (for the Director and the T lanes; evidence in the copies' job logs)
5. **A package merged whole files from a stale workspace and undid a later change.** Court v0.1.10: bodies_first_minute
   r5 merged `scripts/bodies/poses.gd` and `mod.gd` from its workspace; that workspace still held the alley-oop cue from
   the failed change of 17:39 (J2nd finding 10), which no promoted version had, and its `poses.gd` predates v0.1.9's
   (my reading of the diff). Result: v0.1.9's pose cache (`crews.json` `anim.pose_step_f`, `resync_f`) is gone
   and play moved: the pack's own newcomer hand hashes 64240fb0 on v0.1.9 and 181bc670 on v0.1.10 (3600 frames, seed 1).
   Its note even says the cue "still shows ... as before" though no promoted version had it. The card says nothing of
   the play change. Evidence: court copy events 2188, 2198; `.tl/n/r/court9_packnew.json`, `court10c_packnew.json`.
   (Main has T2's "refused changes leave nothing behind"; this tree is from 48a7e24b, so this may already be fixed.)
6. **A "the rest of your change" hop for a note.** Court: bodies_first_minute's remark about where the cue numbers live
   went to court_exchange r21 as an unmade part, and court_exchange copied the numbers into `data/tuning.json`, so the cue
   now has two homes (event 2200). Karts: "the rivals' part" went to teams r8, which changed nothing (event 1804; the
   same shape as J2b's finding 1).
7. **Two packages steer one thing.** Biplane v0.1.11: core r32 lifted Vesper from `main` (`_lesson_lift`) while the pass
   lives in first_flight's script; first_flight r6 then placed her itself and left core's lift in, "does nothing and can
   stay" (events 1148, 1169).
8. The kernel runner's watchdog thread printed a SCRIPT ERROR at exit in two windowed court runs
   (`res://kernel/runner/worker.gd:387`, `_wd_mutex` null), not in headless runs. Kernel, not pack.
