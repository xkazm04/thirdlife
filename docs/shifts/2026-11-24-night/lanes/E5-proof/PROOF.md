# E5 proof: real Foreman jobs through Create's path (night of 24-25 Nov 2026)

Tree `.claude/worktrees/hk-proof`, branch `hk-proof`, at hokej 585d130. Jobs root `.tl/proof-jobs/` (never site/).
Every step went through `engine/ui/foreman_run.mjs` with the exact command order of `engine/ui/foreman_door.gd` and the
flags of `engine/ui/flags/real.json` (claude-cli, sonnet, --max-packages 4, --round-limit 4, --parallel 2,
tokens_per_hour 4000000). Billing: subscription (claude.ai max), so the token figures are what the ledger counts,
not money. Times are wall clock on this machine. The stills are JPG beside this file (raw PNGs in the tree's `.tl/e5-raw/`, not landed).

How I looked: `tl.sh capture --cam=follow --hud=on --test=tests/bot_match_hand.gd --strip=16x60` (16 frames, one a
second, frames 240..1140: about 20 s of the match) and one full still at frame 1800, in a window; both bots headless
(`tl.sh bot`); the measured check `rink.sh check-cartridge` (thirdjam's playtester, 10 seeds a level) on the game's
cartridge beside hokej's. hokej's own figures, the bar:

| hokej (data/hockey.thirdlife.cartridge.json + rules) | wins of 10 | goals for:against | minutes | shots | speed m/s | knockdowns |
|---|---|---|---|---|---|---|
| rookie | 10 | 3 : 0.2 | 1.3 | 8.4 | 9.2 | 5.9 |
| pro | 7 | 2.3 : 2.2 | 4.1 | 28.6 | 9.6 | 24.9 |
| all_star | 6 | 2.3 : 2.0 | 2.5 | 20.4 | 9.8 | 12.2 |

hokej in 20 s: `hokej_strip.jpg`; one still: the left half of `compare_hokej_j1.jpg`.

## Job 1: "3 against 3 hockey on a small pond rink" (job against-3-hockey-20261125-3): DONE, v0.1.2

**It took three starts.** Both first starts stopped on route defects, which I fixed before going on:
- `-1` (01:07, 6 min, 290k tokens in): the Designer was refused three times. The brief check did not know
  `game.effects`, `game.rules.hooks` or `game.contact.*_windup_frames`, although CARTRIDGE.md lists them. The cause:
  the envelope schema's `"game": {"$ref": "game.schema.json"}` was never followed. Fixed in coreroute.ts.
- `-2` (01:16, 22 min, 1.49M in): the route chose the core and the base copied in 70 s. Then the cartridge
  builder (r1, 3.7 min) blocked on a question no person can answer, for two reasons:
  - the base's `tests/bot_match_hand.gd` aims at a net fixed at x = 41, so it never shoots on a 56 m rink;
  - the Planner put `invariants` in the cartridge's acceptance, and the base itself fails it (frame p50 3.5 ms
    against "one of many" 1 ms, p99 4.07 against 4).

  Both fixed: the base bot reads the net from the cartridge, and the core route drops invariants. I discarded the
  job.

**Design** (00:38 to 00:50 UTC, 7 generate calls, 9.9 min: concept, designer x4, review x2): the concept step chose
candidate 4 of 5, likelihood 0.08: "every goal you score drafts you to the team you beat". That is a game nobody who
typed this sentence asked for. As a person on the pitch screen I used what Create offers: I dropped `switch`, `count`,
`hunters` and `crew` (with the note "I just want plain three against three pond hockey, no changing teams"), kept
`pond` and `camera`, and pressed Build. The Planner obeyed the reactions ("PLAYER DECISIONS: plain 3 v 3 pond hockey.
Do NOT build team switching ...").

**Route: the core.** The plan (card.rink_core, 1.7 min):
| package | scope | built by |
|---|---|---|
| base | the whole template, 40 files | the Foreman: copied and verified in 72 s, no tokens |
| pond_cartridge | data/pond.cartridge.json, data/match.json, its own tests/bot_pond_hand.gd + bot_pond_returns.gd | builder, 4.9 min, 1.23M in / 21.7k out |
| goal_beat | a small presentation script + main.gd hook | builder, 4.4 min, 1.40M in / 24.5k out |
| pond_skin | skin.json, pond_commentary.json, pond_barks.json (phase 2) | builder, 3.8 min, 1.49M in / 28.3k out |

**The cartridge diff against the base** (35 keys):
- rink 90 x 45 -> 50 x 26; goal 4 -> 4.5 m; boards 0.4 -> 0.6; ice friction 0.015 -> 0.008;
- 3 v 3 with new spawns; team 0 RED #D83A34, team 1 BLUE #2F6BDE (the player is red now);
- rules first_to 3 -> timer 14400 frames; goal pause 120 -> 180;
- skater speed 11 -> 9; reception 2.5; one-timer window 20; ai.yield_margin 0; bot check wind-up 12; look l1_day;
- the base's `tunables` list was rewritten and shortened (5 entries instead of 9).

**Phase 1** (run 00:52:56, paused 01:07:28 = 14.5 min). I looked (`j1_phase1_strip.jpg`, `j1_phase1_still.jpg`).
- It is hokej: the same felt figures, puck, sticks, HUD, rings, radar, commentary and barn, on a small rink.
- The nets stand outside the boards. The hall's own nets stay where a 90 m rink has its goal lines, while the core
  scores at +-21 m. You cannot see where to shoot.
- The commentary says "It's in, for blue!" when red scores (the words key off the team index, not the colour).
- Bots: bot_first_match 23:2 at rookie; the hand 23:1.
- The Foreman ran **no** measured check at this pause: the planner put pond_skin, which is in phase 2, in the greybox
  milestone, so the milestone's look waited for phase 2. I ran it by hand: OK with warnings, "a goal flood at every
  level (29 to 34 a match)" and shots above anything thirdjam ships. Pro: wins 9/10, 20.6 : 12.3, speed 7.6 m/s.
- Verdict as a person: PASS. It plays like the hockey; too many goals.

**Phase 2** (01:12 to 01:27): the skin merged in 3.8 min. Then the greybox look ran for the first time:
- The critic said NOT ok twice. Its reasons: the top camera is solid black, the nets are off the ice, and "no jersey
  change, crossing skaters or antlered Moose". So it judged the aspects the person had dropped.
- It named **base** as the cause both times. A revise round on the base re-copies the same files (no builder) and
  failed lint both times, because the later packages' tests were missing. Then the job went to `paused: quality`.
- **Create has no screen for that**: it shows "Paused: quality" and a Continue button that runs `resume`, which does
  nothing on a quality hold. A person is stuck there.
- I typed what `foreman status` says (`foreman quality <job> accept`, then resume): phase 2 done. Its strip
  (`j1_phase2_strip.jpg`) shows the skin: "Poked away by the Red Toques!", "My toes are frozen already", MATCH 1 / ROOKIE.
- PASS: final verification, then 0.1.0 promoted at 01:33:57, 41 min after Build.

**Change 1, "make it faster"** (exactly Create's change box: `foreman change <job> "make it faster"` + flags.change):
- Owner question 3.8 s (4k tokens in): pond_cartridge.
- **The cartridge diff route, for real**: one generate call (5.9 s, 11.2k in / 0.5k out):
  `game.skater.speed 9 -> 12; accel 12 -> 16; turn_rate 5 -> 6.5; shot.speed 18 -> 22; puck.max_speed 30 -> 36` (+ the
  matching `values.*`), "You'll skate faster, get going quicker and turn sharper".
- **No builder ran.**
- Measured before and after, pro: speed 7.6 -> 9.2 m/s, goals a match 32.9 -> **52.3**, shots 94.8 -> 111.3.
- 0.1.1 promoted 14.5 min after the request. 50 s of that was the diff and the two checks; the rest was the
  re-verification of every dependant (13 bot runs) and the promotion's four window captures (about 4.5 min).
- `j1_v011_strip.jpg`: visibly quicker. Still the nets beyond the boards.

**Change 2, "the orange team is too strong"**:
- Owner question: pond_cartridge.
- Diff: `values.ai_red_skill: absent -> 0.6` ("The orange team, your opponents, will play less sharply").
- But there is no orange team in this game (the opponents are blue), and the player's side already won 10 of 10 at
  every level. The route did not notice either.
- Measured pro: goals 52.3 -> 33.6, wins 10 -> 10. 0.1.2 in 14.8 min, no builder.

**The result, v0.1.2** (`j1_v012_strip.jpg`, `j1_v012_still.jpg`, `compare_hokej_j1.jpg` = hokej left, job 1 right):
- bot_first_match 17:7 at rookie; the hand 17:6.
- Measured: thirdjam's playtester wins 10/10 at every level, "trivial at all_star", goals 33 to 37 a match, shots 90
  to 95, mean speed 9.3 to 9.8 m/s (hokej 9.2 to 9.8).

**Cost** (`tl ledger`, TL_SITE_DIR=.tl/proof-jobs): wall 85 min, run 71 min; 5.18M tokens in (3.82M cache reads),
199k out, weighted 1.94M.
- The three builders: 4.12M in.
- Designer + review + concept: 615k.
- critic + compare: 272k.
- **The two changes together: 34k in, no builder.**
- The two discarded starts: 1.78M in.

**Verdict, as a player.** Yes, it plays like the hockey: it is hokej's match, figures and HUD on a smaller rink. You
are red now, and the skin's words read right.
- "make it faster" shows. You feel it, and the measured speed went up 20 %.
- "the orange team is too strong" changed the opponents' sharpness, but no team is orange, and the game was already
  too easy.
- The real problem is a goal every 10 seconds (33 a match against hokej's 2 to 5). No round of this job measured it
  as wrong: the measured check calls it a warning, and nothing in the route acts on a warning.
- The nets stand outside the boards (fixed in the base after this job's plan; job 1 still has them).

## Job 2: "hockey where the ice has slow and fast patches and bumpers in the corners" (hockey-where-ice-has-20261125-1): STOPPED at phase 1

**Design** (6.3 min, 5 generate calls): "I strand chasers in slush, blast away on glare ice, and self-pass off
bumpers". That is what was asked. The cartridge lines:
- 2 fast_ice lanes (60 x 7 m) and 4 slow_ice patches;
- 4 bumpers at (+-39, +-15);
- 3 v 3, no free-skater speed bonus, no bot sprint.

Approved as it was. **Route: the core.**
- Plan (1.6 min): base, cartridge, skin (phase 1, greybox) and coach (phase 2, tuned). No invariants anywhere (the fix
  works).
- Base copied in 70 s. cartridge 2.4 min (1.29M in) and skin 1.5 min (403k in) were built in parallel. The diff:
  rink.zones x6, rink.obstacles x4, the AI keys, look l1_day.

**The measured check ran at the look, as designed**: OK. Pro: wins 5/10, 4.5 goals, 1.0 min, speed 8.7 m/s,
passes 0.3 (house: 7/10, 4.5, 4.1 min, 9.6). So the core plays the patches and the bumpers.

**What a person sees** (`j2_phase1_strip.jpg`, `j2_phase1_still.jpg`): plain pale ice. No patch, no lane, no bumper.
The base draws neither zones nor obstacles:
- nothing in gen/tj_rink.gd, scripts/ or cores/rink/arena reads `rink.zones` or `rink.obstacles`;
- thirdjam draws them with its Unreal actors.

The rest was right: the skin ("welcome to the rink: glare foxes against slush hounds"), the nets on the ice (90 m
rink), the match.
- The critic saw it exactly: "no fast ice, no slow ice and no readable corner bumper anywhere, so the whole twist is
  missing".
- It then sent the revise rounds to **skin** twice and **cartridge** once. None of them owns a drawing file: 3 rounds,
  about 1.2M tokens, no visible change.
- The cartridge builder then asked (event 118): "Can the zone and bumper drawing and the top-camera fix go to a
  package that owns `gen/tj_rink.gd` and `scripts/main.gd`, or can those two files be added to this package's scope?"
  The job paused waiting for answers.
- **Create shows "Paused: the builder asks a question" with no answer box.**

**Why I stopped it** (the brief: anything larger than a lane fix, stop and report):
- Drawing every zone kind, obstacle and pickup is a presentation feature of the base (E1/K6 scope), not a fix.
- No change round can make this game show its twist.

Stopped with `foreman cancel` (Create's discard) after 26 min: 3.52M in (2.53M cache reads), 119k out, weighted 1.36M.
"make the rink bigger" was not run.

**Verdict, as a player**: "it's just hockey; where are the patches and the bumpers?" The names are right, the rest is
hokej. The game the sentence asked for is in the simulation but invisible.

## Job 3 (my choice): "pirate hockey, the Sharks against the Gulls in teal and gold, first goal wins" (pirate-hockey-sharks-against-20261125-1): STOPPED at phase 1

I chose it to test the skin (names, colours, words) and a rule variant (sudden death: `score_to_win` 1). The change I
meant to send afterwards was "make the goals bigger".

**Design** (9 min, 6 generate calls): "Grab the powder keg, arm one cannon shot, and sink the Gulls first". On top of
what I asked, it added:
- a pickup (the keg), a boost_only zone and a shotgun ability on F;
- hooks that announce the keg.

That is candidate 2 of 5, likelihood 0.15. Pickups and zones are not drawn (job 2). So as a person I dropped `keg`,
`thief` and `fuse` (note: "no powder keg or cannon: just pirate hockey, Sharks in teal against Gulls in gold, first
goal wins"), kept `sudden`, `gulls`, `crew` and `view`, and pressed Build.

**Route: the core.** The plan (1.1 min) is the smallest possible: base, cartridge (phase 1), skin (phase 2).
- Base copied in 49 s.
- The cartridge builder (2.2 min, 474k in) wrote exactly the asked game (17 keys):
  - Sharks #0FB5AE against Gulls #F2B51D;
  - `game.rules.score_to_win` 3 -> 1;
  - charge 40 frames / +8, one-timer 20 / 14 degrees;
  - bot check wind-ups 12; ai.body_check 0.5;
  - carry 0.92 / free 1.15, take grace 30, l1_day.
- I filmed its workspace (`j3_cartridge_ws_strip.jpg`): teal against gold, "FIRST TO 1" on the scoreboard. It reads
  right. The commentary still says "blue against orange" because the skin is phase 2.

**Why it stopped.** The cartridge's acceptance has the base's PLAYER CHECK, `tests/bot_match_hand.gd`, whose ok needs
a released shot. In a first-goal-wins match the hand's side scored a carried-in goal before the hand's first shot
(score 1:0 over, carried 751 frames, 0 shots), so the check failed. The builder then asked (event 40):

> "How should `tests/bot_match_hand.gd` handle a one-goal match? I suggest its owner changes the pass condition so
> that a match reaching the end card with the hand carrying the puck passes even if it ends before the hand shoots"

The job paused, waiting for an answer that Create cannot take (no answer box).
- I fixed the base bot: ok = carried AND (shot OR his side scored). With the fix, this job's own cartridge passes
  (score 1:0, carried 751), and the regular base keeps core hash ab881a00fb9af8ef.
- But the job's ref/ and workspace hold the old bot, and a re-start would have been a 6th Designer run, over budget.
  So I stopped it with `foreman cancel`.
- 16 min; 1.35M in (691k cache reads), 94k out, weighted 817k. The change was not run.

**Verdict, as a player**: what was built in 2 minutes is the right game (teal Sharks, gold Gulls, first to 1). It would
have played, but the route stopped it on a test that did not know a one-goal match.

## All jobs: cost (`TL_SITE_DIR=.tl/proof-jobs node devx/bin/tl.mjs ledger`)

| job | outcome | wall | run | in | out | cache reads | weighted |
|---|---|---|---|---|---|---|---|
| job 1, first start (-1) | designer refused, discarded | 6 min (then idle) | - | 290k | 47k | 9k | 329k |
| job 1, second start (-2) | blocked, discarded | 22 min | 12 min | 1.49M | 88k | 840k | 826k |
| job 1 (-3) | done, v0.1.2 | 85 min | 71 min | 5.18M | 199k | 3.82M | 1.94M |
| job 2 | stopped at phase 1 | 26 min | 18 min | 3.52M | 119k | 2.53M | 1.36M |
| job 3 | stopped at phase 1 | 16 min | 6 min | 1.35M | 94k | 691k | 817k |
| total | | 181 min | 107 min | 11.8M | 546k | 7.9M | 5.27M |

## The exe and the menu (for the owner)

- Exported from this tree: `bash engine/tools/export.sh` built in 103 s
  (`dist/ThirdLife/ThirdLife.exe`, tag `585d130 2026-11-25 03:30`; my edits were uncommitted).
- `bash engine/tools/export.sh check`: **PASS**:
  - the same games and 4 dungeons hash the same as in the editor binary;
  - the village shows; W and Esc work;
  - Create's GO on the fake adapter reaches the pitch;
  - nothing is left running.
- Added to the menu through Create's Add-to-menu path: the three calls `create_build.gd add_to_menu()` makes
  (`JobModel.read_job`, `Model.play_dir`, `Dungeons.add_user`), run headless by a small script with the exe's list as
  TL_USER_DUNGEONS.
- The person's list is now `%APPDATA%\ThirdLife\dungeons.user.json`, one row:
  - title "3 against 3 hockey on a small pond rink";
  - pack `<this tree>/.tl/proof-jobs/against-3-hockey-20261125-3/promoted/game.against_3_hockey@0.1.2`.
- The exe plays it: `ThirdLife.exe --headless -- --dungeon=<that pack> --frames=600` runs 600 frames, exit 0.
- Jobs 2 and 3 have no promotion, so they are not in the menu.

Steps for the owner:
1. Double-click `C:\Users\kazda\kiro\third-life\.claude\worktrees\hk-proof\dist\PLAY-LATEST.cmd` (or
   `dist\ThirdLife\ThirdLife.exe`).
2. Main menu, **Dungeons**: the last row is "3 against 3 hockey on a small pond rink", marked "made by you in Create".
   Play it: v0.1.2 (faster, the opponents a little softer). Its earlier versions are beside it in the job's
   `promoted/` folder (0.1.0, @0.1.1).
3. To see the jobs in Create's **My games** (and change the game again from its change box), start the exe with the
   jobs root set: in Git Bash
   `TL_CREATE_JOBS=C:/Users/kazda/kiro/third-life/.claude/worktrees/hk-proof/.tl/proof-jobs ./dist/ThirdLife/ThirdLife.exe`.
   Without that, Create uses `<this tree>/site`.
4. To take it out of the menu: Create, My games, the game, then "In the menu" (or delete the file above). The row
   points into this worktree: it stops working when the tree is removed.

## What I changed on the way (every edit; `npm test` after)

All in the tree, uncommitted (the Director lands). Gates:
- `npm test` (foreman): 349 tests, 342 pass, 0 fail, 7 skipped (the base was 348 / 341 / 7; +1 new test). The two
  test files touched: core_route 15/15, revisepair 9/9.
- `node devx/bin/tl.mjs check --tier fast`: PASS 5/5 (arch 12/12, assets 4/4, cards 3/3, devx.test 229/229,
  foreman.typecheck).

The Foreman (the core route):
1. `foreman/src/coreroute.ts` `schemaPaths`: follows a `$ref` that names a sibling schema file. The envelope's
   `"game": {"$ref": "game.schema.json"}` was never read, so every `game.*` key that only the schema knows was refused
   in the Designer's CARTRIDGE lines (job 1's first start: 3 refusals, then failed). `knownCartridgePaths` passes the
   schema dir.
   Test: core_route "a core brief names ..." now also asserts game.effects, game.rules.hooks and
   game.contact.(bot_)check_windup_frames are known.
2. `foreman/src/coreroute.ts` `normalizeCorePlan`: drops `invariants` from every package of a core plan. The base
   (thirdjam's whole match) fails its frame budgets by itself: p50 3.5 ms against 1 ms "one of many", p99 4.07
   against 4. The cartridge builder blocked on it (job 1's second start).
   Test: core_route "a cartridge-first plan ..." asserts it.
3. `foreman/src/foreman.ts` final verification (3 lines): no `invariants` on a core job, for the same reason. Without
   this, every core game would fail at its promotion.
4. `foreman/src/quality.ts` `sendBack`: a critic revise round never goes to the base package. The base is a copy, so
   a round on it re-copied the same files and failed lint. It went to the milestone's built packages instead, with a
   Foreman note. In job 1 the critic named the base twice: 2 useless rounds, then a quality hold.
   Test: revisepair "E5: a critic's revise round never goes to the base package".

The base the route copies (`engine/templates/rink_game`, E1's; hokej itself untouched):
5. `tests/bot_match_hand.gd`:
   - the net's x from the game's cartridge (`length_m/2 - 4`; it was a fixed 41, so the hand never shot on any rink
     shorter than 90 m);
   - ok = carried AND (shot OR his side scored), so a one-goal match carried in passes.
   - The regular base keeps core hash ab881a00fb9af8ef (9071 frames, 3:1, 27 shots: the same as before).
6. `scripts/main.gd`:
   - The hall's own goals are used only on a 90 x 45 rink. On any other size the rink's own goals are drawn at
     +-(L/2 - 4) with the cartridge's goal width. Before, a user's 50 m pond showed its nets outside the boards
     (`j1_v011_strip.jpg`); with the fix the net stands on the goal line (`netfix_pond.jpg`, same cartridge).
   - The "top" camera gets a near plane of 50 m. It sat 70 m up, above thirdjam's roof, and rendered solid black, and
     the critic blamed the base in every look; with the fix the whole rink shows from above (`topcam_fix_pond.jpg`).
   - lint PASS; bot_first_match keeps core hash 6f45bf07503f05b8.

Not edited: contracts/*, hokej, Create (engine/ui), the prompts. The Create gaps are below.

## Defects found and not fixed (with their log lines)

1. **The base draws no zones, obstacles or pickups** (job 2, stopped).
   - The core plays `rink.zones`, `rink.obstacles` and `pickups` (measured: pro wins 5/10, 1.0 min, carry 2 s), but
     nothing in the base renders them. A user's "slow and fast patches and bumpers" game looks like plain hockey.
   - Events 104 (the critic: "no fast ice, no slow ice and no readable corner bumper anywhere, so the whole twist is
     missing") and 118 (cartridge: "Can the zone and bumper drawing and the top-camera fix go to a package that owns
     `gen/tj_rink.gd` and `scripts/main.gd` ...").
   - CARTRIDGE.md and the Designer both advertise these keys, and the Designer reaches for them in 2 of 3 jobs.
   - Needs a presentation lane (E1/K6): draw every zone kind, obstacle and pickup from the cartridge. Until then, the
     Designer's prompt should not offer them.
2. **Create cannot answer three of the Foreman's pauses**.
   - A builder's question (`paused: waiting for answers`, jobs 1-2, 2, 3): Create shows "Paused: the builder asks a
     question", with no text and no answer box.
   - A quality hold (`paused: quality`, job 1): Create shows "Paused: quality" and a Continue button that runs
     `resume`, which leaves the hold as it is.
   - A person is stuck forever at each. `foreman_door.gd` has `answer()`; nothing has `quality accept|retry`.
3. **The concept step picks a low-likelihood twist on a plain sentence**: 0.08 ("each goal drafts you to the team you
   beat"), 0.15 (black ice), 0.15 (powder keg), 0.18.
   - concept.md says "usually that is NOT the most likely one". For "3 against 3 hockey on a small pond rink" the
     person got a different game and had to drop four aspects.
   - For the owner's goal ("a game like this", hokej, built from the editor), the obvious candidate should win on a
     core route in Standard. A direction question for the Director/owner; prompt not touched.
4. **The critic judges dropped aspects** (job 1, event 98 and after). Its checklist and clip moments come from the
   brief, not the reactions: "no jersey change, crossing skaters or antlered Moose" after the person dropped all of
   them.
5. **No measured check at a phase pause when the milestone is open** (job 1). The Planner put pond_skin (phase 2) in
   the greybox milestone, so the look, the critic and `rink.sh check-cartridge` ran only after phase 2. The person
   passed phase 1 with no figures. Either the core route makes each phase's packages a milestone, or the core check
   runs at `phase_done`.
6. **The core check's warnings never act** (job 1).
   - "A goal flood at every level (29 to 37 a match)", "trivial at all_star" and "shots above anything thirdjam ships"
     are ok with warnings. Nothing sends them back, and the cartridge diff of "make it faster" raised pro goals from
     32.9 to 52.3 and still reported "after: ok".
   - The person sees a goal every 10 s; hokej has 2 to 5 a match.
7. **A change that names something the game does not have goes through** (job 1, "the orange team is too strong").
   - There is no orange team (the opponents are blue), and the player's side already won 10/10.
   - The diff lowered `values.ai_red_skill` and said "The orange team, your opponents".
   - The diff prompt could be given the team colours/names and the before figures, so it can say "your side already
     wins every match".
8. **Commentary keys off the team index, not the skin's colours** (job 1 phase 1): "It's in, for blue!" when red
   scored. Team 0 had been recoloured red in the cartridge; the skin's team_names fix it when there is a skin.
9. **The cartridge builders cannot run `rink.sh check-cartridge`** (their shell allows only the four verifier
   commands; every cartridge note says so). The Foreman runs it at the look, so this costs nothing but the builder
   tunes blind.
10. **Time of a change round**: about 15 min even with no builder (job 1: 50 s for the diff and its two checks, then
    13 bot re-verifications and 4 promotion captures, about 4.5 min of captures). For "a playable build in minutes",
    the dependants' re-verification of a data-only diff is the place to save.
11. **Stale class cache in a fresh tree**: hokej would not load here (`gen/tj_rink.gd` parse error, `style_cel.gd:76`)
    until `tl.sh import`. A Foreman job in such a tree would fail its first lint/smoke for no reason of its own.

## In one paragraph

The path works end to end with the real model:
- a sentence becomes a game on the rink core, started from the base in about a minute with no builder;
- the cartridge, skin and a small script come from 2 to 5 minute builders;
- a person's words become a cartridge diff in one 6-second call with no builder, measured before and after, and
  promoted as a new version.

Job 1 is that, and it plays like hokej because it is hokej's match. What a player meets:
- the Designer's habit of inventing a twist;
- three pauses Create cannot answer;
- a base that draws none of the cartridge's zones, obstacles or pickups (job 2's whole game);
- a hand check that did not know small rinks or one-goal matches (fixed);
- nets outside the boards (fixed);
- a black top camera that burned the critic's rounds (fixed);
- a goal flood nobody acts on.
