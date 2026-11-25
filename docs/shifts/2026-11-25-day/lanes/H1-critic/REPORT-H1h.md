H1h (round 8 of lane H1, editor hardening), day run 25 Nov 2026. Tree .claude/worktrees/d25-hard-a, from main 67e6e1e.
Opus. G1's rounds 5-6 (PROOF-G1.md), your two answers to H1g, and G5's three findings (PROOF-G5.md, added as items
6-8). Every item has a test that fails on main 67e6e1e and passes now. Real jobs were read in place, read only; what
the tests need is copied into foreman/fixtures/h1h/.

My tree is behind main (main has G5's docs, 3874e38). No file of mine is in that commit.

1. The named-figure check compares like with like and says which way: MET.
   - check_cartridge.mjs adds a level figure, play_minutes: live play without the pauses after goals (the lab's
     play_frames / 3600). coreroute.ts maps it to pro_play_minutes.
   - rinkjudge.ts askedFigureMiss reads a person's minutes as minutes of play, so it compares them with
     pro_play_minutes when the check has them, and says which minutes it read:
     - with play minutes: "they last 4.1 minutes of play at pro now (5.2 with the pauses after goals), longer than
       you asked"
     - without them: "they last 2.1 minutes at pro now, pauses after goals included, shorter than you asked"
   - The verdict now reads "the change goes past what you asked", "falls short" or "misses" (when it is both ways), and
     goals say "more" or "fewer".
   - G1 v0.1.10 (3.9 minutes with pauses, 3.0 minutes of play): no miss, since 3.0 is the three minutes asked for.
   - Test: H1h 1.
   - Moved expectation (named in the test): h1d_hardening.test.ts H1d 6, three places. Its words now name the minutes
     ("pauses after goals included, shorter than you asked").

2. The game's text goes to the skin's owner: MET.
   - coreowner.ts skinSplit: the sentences of a change that set the game's text (title, tagline, subtitle, slogan,
     commentary, announcer, team names, rename) go to the package that owns data/skin.json. A sentence that sets a text
     after a colon takes the sentences after it, so the new line's own full stops stay with it.
     - In a mixed change, the skin's sentences become a change request of the Foreman's for the skin's owner, and the
       routed package is asked only the rest. skintext.ts lets the log's fold keep that package's change list to the
       rest.
     - In an all-skin change, the whole change goes to the skin's owner.
   - foreman.ts: 2 lines (2005 of 2005).
   - G1's real words for v0.1.11: "Take the black boxes ... Show the F hint ..." stays with harbour, and "Change the
     line under the title to: Grab a trick at the green spots. F uses it." goes to skin. "the commentator's line" in
     the hint sentence is about where the hint is drawn, so it is not moved.
   - Test: H1h 2. A unit case on G1's words, plus a Foreman run in which court owns the skin: "Make the rival twice as
     fast. Change the title to: Paddle Kings." sends the title to court, which writes it, and paddle_ai is asked only
     for the speed.

3. The quality card waits while the Foreman lets go (your answer): MET (a product change).
   - create.gd: `settling` now also covers a job paused on a quality hold whose Foreman still holds the job.
   - create_pause.gd shows no quality card while settling. The page says building, as it does for Pass.
   - stage_pauses.gd: the stage's own Foreman-alive wait from H1g is removed, because the page itself waits now. One
     approach.
   - Test: block 864 (create.settle.wait, create.settle.card; ui/create/create_settle_case.gd + .uid). A lock held by a
     live process means no Fix it / It's fine / Change it; once the lock is gone, the card shows its three answers.
     create.settle.wait FAILs with main's create.gd and create_pause.gd (settling false, FixIt true).

4. The stray characters in templates.ts: MET.
   - What they were: three backspace characters (0x08) in the arcade_sport house rule "the puck and your skater readable
     at a glance". Its regex meant word boundaries (\b): `(puck|it)[^.]{0,60}\b(rim|outline|larger|...)\b|\b(rim|
     outline)[^.]{0,30}puck`. A heredoc had turned each \b into a real backspace (the same gotcha that bit me in H1g).
   - Effect: a literal backspace in a JavaScript regex matches only a backspace, so two of its three alternatives never
     matched. Only "ring under" or "green ring" passed. A brief that drew the puck bigger with a hot rim or outline but
     named no ring was told it lacked a readable puck.
   - The characters came in with commit 7f26ba2 (the arcade sport's readable puck). They are replaced with \b, and no
     backspace is left in foreman/src.
   - Test: H1h 4 (no backspace in the source, and "drawn bigger than life with a hot outline" passes the rule).

5. Dusk cannot be asked for (G1 round 6): CAUSE FOUND; NOT BUILT (it needs data the tree does not have).
   - The cause: Godot never reads the cartridge's `game.look.tier`.
     - The tier (l1_day, l2_night, l3_neon, p3_clay, p4_broadcast) is read only by native thirdjam (JamCartridge.h;
       Tier defaults to "l2_night").
     - The base (templates/rink_game/scripts/main.gd `_pack_tick` frame 0) lights the hall with
       `arena.light(ctx.root)`, which is RinkArena.light in cores/rink/arena/rink_arena.gd.
     - RinkArena.light reads one rig from cores/rink/arena/arena.json: its 18 spot lights, its post volume
       (PPV_P3_Clay), its sky and its light_sum. These are the p3_clay tier's, exported from thirdjam (lane K6/K7). The
       file has no other tier's rig. It does hold the night ice material (MID_MI_Ice_Night_0, "NightWet" 0.3) and the
       barn's night glass, but no night lights or post.
     - So any tier lights the ice as the clay hall's day, and a pack may not make lights.
   - The smallest fix, inside the core and base rules:
     a) export thirdjam's l2_night rig (its lights, its PPV_L2_Night settings, its sky, its light_sum) into
        arena.json as a second rig, keyed by tier;
     b) RinkArena.light(anchor, tier) picks the rig for the tier, falling back to p3_clay, with table() reading a rig
        by tier;
     c) the base passes the cartridge's tier: `arena.light(ctx.root, str(cartridge game.look.tier))`.
     Parts (b) and (c) are about 15 lines in the core's arena part and the base. Part (a) needs the thirdjam UE
     project's night assets, read the way lane K6 read the clay ones. I did not build it: inventing night numbers would
     break the core's "ported, not tuned" rule. It needs K6's export tool, or the UE data, from whoever holds it.

6. A person's card choice or answer lifts a plan bound: MET.
   - New module boundlift.ts. A plan tofu row is lifted, so not judged at acceptance (tofugate.ts) or at the
     milestone look (quality.ts tofuLook and decideLook), by either of these:
     a) a person's answer that drops a target or bound and names the metric's words. A letter answer ("C. ...") reads
        the question's option (C) too.
     b) a card choice whose alternative or note says the ball is never held ("Never Held", "rolls free", "never
        carry"). This lifts the possession rows.
   - When a lifted row would have failed, the Foreman writes one note a round before the merge: "[foreman] plan bound
     lifted, not judged: possession_median_f (the plan's bound: >= 240 and <= 600), on your answer to core's question
     (event 216): "C. Keep the ball fully loose ..."".
   - Test: H1h 6, with G5's real plan, card (event 14), question and answer (events 214, 216) and core r9's bot report
     (s241: possession_median_f 30):
     - with neither, the round is thrown away, as on main;
     - with the answer only, it passes, with the note;
     - with the card only, it passes, with the note ("on your card "Never Held" (a ball nobody holds: "... never
       carry it")").
   - Limit: (b) is one table (a loose ball lifts possession). Other card-to-bound pairs need their own line as real
     jobs show them.

7. A passed phase closes its milestone's critic loop: MET.
   - The cause: quality_state.ts qualityNext. After the person passed the show phase (G5 event 196), the greybox
     milestone still had revise round 1 open (sent at 184; the round itself was thrown away by the tofu bound before
     the phase paused). The loop then filmed and judged greybox again (208) and sent round 2 (209). It did the same after
     the pier pass (280, then 293).
   - The fix: a phase_reviewed "pass" after a milestone's last look or revise round closes that milestone.
   - Test: H1h 7, with G5's real events to 207 as a fixture. qualityNext gives "closed" now; before the pass it gives
     "look round 1", as on main.

8. Every result segment counts in the ledger, and the builder's note is kept: MET.
   - claude-cli.ts normalize sums the usage of every `result` event. Each segment's usage is its own: G5 core r8's two
     segments had 30,340 and 365 output tokens, and the cost is cumulative. The text is every segment's text in order,
     so the first segment's report and its DEVIATIONS reach the job log as the builder's note.
   - Test: H1h 8, with G5 core r8's real result events as a recorded envelope (fixtures/h1h/g5-core-r8-results.ndjson).
     Tokens out are 30,705; tokens in are the sum of both segments; the text starts with the first segment's report
     ("I made hits show much more in both bodies ... DEVIATIONS ...").

GATES (each after room.sh; logs in .tl/h1h/)
- foreman npm test: 430 tests, 423 pass, 0 fail, 0 cancelled, 7 skipped (the same 7). 430 = main's 424 + the 6 H1h tests.
- node devx/bin/tl.mjs check --tier fast: PASS. arch 12/12, assets 4/4, cards 3/3, devx.test 229/229, typecheck clean.
- bash engine/tools/selftest.sh create.: 25 passed, 0 failed (23 + block 864's two). create.pause.path PASS with the page's own wait.
- Not run: --tier full, world and k.sh. No kernel, kit, rig, style, seed or runner file changed (the rink lab's check script, the
  Create page and the Foreman only).
- Before-runs:
  - all six H1h npm tests FAIL on main 67e6e1e (a scratch copy with the new tests, the fixtures, the new module
    boundlift.ts and a shim for skinSplit);
  - block 864's create.settle.wait FAILs with main's create.gd and create_pause.gd.

CHANGED FILES (round 8)
- New:
  - foreman/src/boundlift.ts
  - foreman/src/skintext.ts
  - foreman/src/test/h1h_hardening.test.ts (6 tests)
  - foreman/fixtures/h1h/: G5's plan, events, core r9 bot report, events to 207, core r8 result envelope
  - engine/ui/create/create_settle_case.gd (+ .uid)
  - engine/tools/selftest.d/864-create-settle.sh
- Changed:
  - foreman/src/:
    - rinkjudge.ts
    - coreroute.ts (one word)
    - coreowner.ts
    - foreman.ts (2 lines; 2005 of 2005)
    - joblog.ts (one line; 600 of 600)
    - tofugate.ts
    - quality.ts
    - quality_state.ts
    - builder/claude-cli.ts
    - templates.ts (the three \b)
  - engine/cores/rink/lab/check_cartridge.mjs (play_minutes)
  - engine/ui/create/create.gd and create_pause.gd (the card waits)
  - engine/ui/create/stage_pauses.gd (the stage's own wait removed)
- Moved test (named in it): foreman/src/test/h1d_hardening.test.ts (H1d 6's words).
- lanes/H1-critic: STANDUP.md, REPORT.txt

QUESTIONS FOR THE DIRECTOR
- Dusk (item 5) needs thirdjam's l2_night rig exported into arena.json. Who holds K6's export, or the UE night assets?
  Once the data is in, parts (b) and (c) are mine to build.
- Bound lifting by card (item 6b) is one table today (a loose ball lifts possession). Should the card text name the
  bounds it lifts, so the Designer writes the lift instead of the Foreman guessing from words?

NEXT THREE
1. Dusk (b) and (c), once the night rig is in arena.json.
2. A card field for the bounds a choice lifts (if you want it).
3. The clock that a timer game does not show (G1 finding 20): the base's header has nothing for a timer.
