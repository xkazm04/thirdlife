# E5c: patches and bumpers on E1b's base (25 Nov 2026, hk-proof at hokej d1c2f59)

Jobs root `.tl/proof-jobs-c/`. Every step went through `engine/ui/foreman_run.mjs` in Create's order, with real.json's
flags (claude-cli, sonnet), answering as Create's cards do. Times are local (UTC+1). The stills are in `e5c/`; I
looked at all of them. The raw captures under .tl/ are deleted.

**Result: STOPPED by the 40-minute rule. Phase 1 was not reached, so no version was promoted and neither change
("make the rink bigger", "make the goals bigger") was run.** The questions about the versions (time, path, runner
calls, owner, the what-changed note, skin and match cmp) have no answer from this round.

## What happened, in order

| local | min | step |
|---|---|---|
| 08:32 | 0 | start 1 (`foreman new`). The Designer failed after 3 attempts, each on a different small check: a playstyle line of 14 words (limit 12); "75 widths" instead of "body widths"; `SKIN: level ...`. 6.3 min, 292k tokens in. |
| 08:39 | 7 | start 2 (a person presses GO again). Failed after 3 attempts again: `SKIN: team_plural` (attempt 1), WORLD units (2), `SKIN: level words` (3). 9 min, 596k in. |
| 08:48 | 16 | **The defect, fixed because it blocked the job outright** (`foreman/src/coreroute.ts`). |
| 08:49 | 17 | start 3. Designed in 6 min: patches and bumpers as asked (details below). Built as it was. |
| 08:56-09:02 | 24-30 | plan 2.1 min (base, cartridge, banks, skin; phase 1 = base, cartridge, banks). The base copied 43 files; **its first lint took 3.4 min**. |
| 09:02-09:09 | 30-37 | cartridge builder 3.4 min, then verification, merged. |
| 09:09-09:12 | 37-40 | banks builder (a script package) blocked: "The pack is at 6228 of 6000 script lines ... May the limit be raised, or may a package remove comments or code from the base HUD files?" |
| 09:13 | 41 | Answered as a person on the question card: "No. Leave the base alone and skip the bank-shot extras; the patches and the bumpers are what I asked for." Then resume. |
| 09:13-09:20 | 41-48 | banks r1 again (5 min): built nothing of the double-goal extras, as answered; merged. |
| 09:20-09:27 | 48-55 | greybox look: 16 captures in about 6 min, then the critic said NOT ok and named **banks** (a built package, so a revise round, correctly no hold). banks r2 started. |
| 09:28 | 56 | **Stopped.** Phase 1 was not reached within 40 min of the first start (39 min after start 3). My own Foreman tree was ended, then `foreman cancel`. |

**The blocking defect and the fix:**
- The Foreman's SKIN check knew only the keys present in the base's `data/skin.json`. E1b's optional `team_plural`,
  documented in the base README the Designer reads, is not one of them.
- The README calls `levels` "the level row's words", and the Designer writes `SKIN: level words = ...`.
- The fix: `skinFields` also takes the keys the base's `scripts/hud/skin.gd` declares (its TYPES), and "level" is
  accepted for `levels`.
- One assertion in core_route.test.ts. `npm test`: 365 tests, 358 pass, 0 fail, 7 skipped. core_route 16/16.

**Start 3's design** (candidate 2 of 5, likelihood 0.2: the sentence asks for a twist, so the concept may choose freely):
- rink 60 x 30, corner radius 3;
- **4 bumpers, size 5, at (+-27.3, +-12.3)**;
- **fast_ice lanes at z +-8, 34 x 4 m; slow_ice circles at x +-14, radius 3.5**;
- goal 5 m; boards 0.6; 4 v 4, navy #14233C against yellow #F2C200; a 3-minute timer; no aim help.
- On top: "banked goals count double" (stars, arrows, a hot puck).
- Skin: "Bank Shark Pond", Sharks against Walruses.

The cartridge builder made exactly those zones and obstacles (2 files merged).

**Measured at the greybox look** (`reports/core-greybox-s82.json`): ok.
- rookie 10/10, pro 6/10, all_star 7/10;
- pro: 11.4 goals in 3.8 min (about 3 a minute; hokej 4.2 in 3.1, 1.35 a minute), shots 52.4, knockdowns 30.1;
- idle 1/16, skating alone 0/16.
- The new goals-a-minute check did not fire at about 3 a minute.

## What I saw (E1b's base): the patches and bumpers ARE drawn

- `c_phase1_top.jpg` and `c_top_hokej_vs_job3.jpg` (hokej left, job 3 right): the top view is clean now, the whole
  rink and no roof. The job-3 side shows:
  - two orange fast lanes with speed dashes;
  - two blue slush circles with white dots;
  - four pink-topped drums in the corners;
  - the nets on the goal lines of the 60 m rink.

  The drums overlap the corner boards, which the critic also saw.
- `c_phase1_strip.jpg` (follow camera, 20 s):
  - the lanes, the slush circles and the bumper drums read clearly from behind the player;
  - #7 rides an orange lane (tile 10);
  - knockdowns ("This is not hockey, this is a wrecking yard");
  - the commentary uses the cartridge's team words ("Blue against Gold").

  The navy team reads almost black. **As a player: this is the game the sentence asked for**, before its skin.
- The rink-bigger and goals-bigger stills could not be taken (no change ran).

## The critic and the hold (the question asked)
- The one critic verdict named **banks**, a built package, so the new rule correctly sent a revise round rather than
  the quality card. No critic reason named the base, core or camera this time, so the "card at once" path was not
  exercised.
- Critic loop time before the stop: about 8 min (the look's captures 6 min, the verdict 0.7 min, banks r2 started).
  Job 1 of E5b spent 89 min.
- The critic judged against the brief's double-goal promise ("no star, arrow marker, red hot puck, THUNK ... DOUBLE"),
  which the person had refused in a question answer, not by dropping an aspect. The answer to a builder's question
  does not reach the critic's rubric the way a dropped aspect does.

## Cost (`TL_SITE_DIR=.tl/proof-jobs-c node devx/bin/tl.mjs ledger`)
- Start 1 (failed): 292k in, 50k out, weighted 334k.
- Start 2 (failed): 596k in, 74k out, weighted 396k.
- Start 3 (cancelled): 4.09M in (3.19M cache reads), 124k out, weighted 1.35M:
  - cartridge 1.25M in;
  - banks r1 twice 2.30M in;
  - design and plan 0.5M in;
  - critic 48k in.
- Total 4.98M in, 248k out, weighted 2.08M; 56 min.

## Defects for the Director
1. **(fixed here, it blocked the job)** The SKIN check refused E1b's `team_plural` and the README's "level words". The
   Designer's 3 attempts are also thin: each run failed on a different small check (word counts, "body widths"), so
   two runs failed outright.
2. **The base leaves no room for a script.** It is 5943 of lint's 6000 script lines (scripts + gen), so any script
   package (here `banks`) overflows. Its builder asks the person whether the limit may be raised or the base trimmed:
   a question a player cannot judge. Either the base's lines must not count against the game's budget, or the limit
   needs room above the base.
3. **The first lint of a fresh job workspace takes 3-3.5 min** (all 5 jobs of E5b/E5c), before any builder starts.
   That is about 8 % of a 40-minute window every job pays.
4. **A refused promise is still judged.** The person's "no" to a builder's question does not reach the critic; only
   dropped aspects do. The look said NOT ok for stars and DOUBLE banners the person declined.
5. **The concept can still add a twist to a sentence that names its own** ("where the ice has patches and bumpers"):
   double-goal bank shots with stars came on top. TWIST_WORDS lets "where the" choose freely; the person then has to
   refuse it later (here in a question, which then fed defect 4).
6. **Bumpers overlap the corner boards** (top view): the drums sit across the boards' rounded corners.

landable E5c
