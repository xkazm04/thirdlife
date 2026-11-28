# Verdict: juice day and night, 27-28 Nov 2026 (08:10 -> 07:45)

**Page:** https://claude.ai/artifact/GcRPV1K9kDyK84PDLeKBjB

**The owner (27 Nov ~08:00, away 24 h):** "keep the effort from last night, for decision questions try to create spikes
and evaluate both, I will get into this tomorrow and evaluate together"

## In one paragraph
The five questions from the juice night became A/B spikes, and both arms of each were built, measured the same way and
kept for you to play. Nothing was decided for you. Beside them, four editor lanes fixed about 45 things the juice lanes met in
Create, every one proven on a copy of the job that showed it and landed on main. Then six more lanes used the fixed editor
as a person would:
- they sent the hand-built juice back to Create as one sentence each (robots now matches the hand version by eye);
- they gave all six games a second crazy ability (red shells, harpoon, alley-oop, magnet yank, catapult volley, MEGA);
- they played the newest version of every game as a newcomer and fixed the worst thing a newcomer missed in the first
  minute.

Your Dungeons list has **86 rows**, 60 of them new today. All 86 ran 600 frames in this morning's exe (6906574) with 0
script and 0 engine errors.

## Gates on main (6906574e; every later commit is docs)
- **Fast tier:** 5/5 PASS.
- **Full tier:**
  - all of these PASS: arch, assets, cards, devx 230/230, typecheck, foreman 531 pass of 537 (6 skipped, 0 fail), kit 122/122, seeds 39/39, item 91/91, ui 219/219, world 9/9;
  - kernel.selftest and packs failed only on wall-clock limits under the gate's own load, so both were re-read alone.
- **Uncapped kernel suite, alone:**
  - 810 pass, 2 fail (after building the rink lab in the gate tree, which made rink.playtester_seat and rink.cartridge pass);
  - the 2 failures, `base.lines_undeclared` and `base.lines_own_6001`, were already failing on main before the shift (the Home session's notes, 27 Nov morning).
- **Hockey `invariants.many_budget`:**
  - main read 1.124 ms and then 1.422 ms against the 1.0 ms budget;
  - pre-shift main 8be26d61 read 1.348 ms on the same quiet machine, so the failure is inherited.
- **Perf `--quiet-only`:** 6/6 PASS.
- **Exe:** `export.sh check` PASS (the same games and 4 dungeons hash as the editor binary, the village shows, W and Esc work, Create starts an idea).

## For your eye (20 min)
1. Start `C:/Users/kazda/kiro/third-life/dist/PLAY-LATEST.cmd` (the exe built from main this morning; the tag is in the
   window's corner). Go to **Dungeons**. Newest first, 5 a page, A / D turn pages.
2. Play the **newcomer picks**, the best Create version of each game tonight:
   - **Robot soccer v0.1.12:** F sledgehammer, hold Q and let go to yank the ball.
   - **Shield wall v0.1.19:** F charge, C slam, Q call, G catapult, Space shield over your head.
   - **Arsenal hockey v0.1.32:** F meteor; land a body check (right mouse) to go MEGA.
   - **Bumper-kart football v0.1.12:** Q jump, F red shell, E whirl.
   - **Biplane duel v0.1.11:** Q harpoon, Shift roll out of her ring.
   - **Half-court v0.1.11:** C with the ball for the alley-oop.
3. Then the spike rows, to answer the five questions (titles start "spike 1A", "spike 1B" and so on).

## The five spikes (your decisions)

### Ask 1: should a new move tell the bots to use it by default? (S1-bots)
- **A (on by default):** 1 sentence reached "bots use it and answer it" on karts, half-court and shield wall, after two
  fixes (a rate a person sees; "off balance" is play).
- **B (as now):** 3 sentences on karts and shield; on half-court not reached in 2.
  - Re-run on the fixed editor (with lane T's rivals routing): B still needed 2 on shield and failed in 2 on half-court.
  - The first sentence about a new move names no bots, so routing has nothing to route, and "the rivals" never reaches
    your own teammates.
- **The cost of A:** the bots shift difficulty without being asked (a balance note the person reads).
- Branches `d27-sp-bots` (A) and `d27-sp-bots-b`. Menu rows "spike 1A ..." / "spike 1B ..." / "spike 1A2 ..." / "1B2 ...".
- **Lane's pick: A.**

### Ask 2: a juice pass for every new ability? (S2-juice)
- **The shared pass** (`foreman/prompts/juice_pass.md`): a growing tell, exaggeration, hit-stop, a camera kick and
  follow, an impact word mid-screen, particles, a slow beat on the biggest moment.
- **A runs it on every new move; B only when "Make it juicy" is picked in Create.** The card and the follow-up button were
  built and filmed.
- **Results:**
  - **Round 2:** A's hammer from J2's plain sentence matched the hand version: hit robots fly 4.6-5.3 m (hand 3.7-5.4), BONK!/KA-BONK!!, the camera rises with you.
  - **B's run came out thin.** The Foreman's new juice check missed it (it read only the builder's last answer); fixed. With the fixed check, B got the extra round and the flight, but still no word and no visible hammer.
  - **Across five pass runs:** 2 complete, 1 complete only after the check, 1 partial, 1 thin.
- **The difference between A and B is builder variance; only the default differs.** Telling them apart by output would
  take 21-36 runs per arm.
- Branches `d27-sp-juice` (A), `d27-sp-juice-b` (B), both with the check fix A4/B4. Menu rows "spike 2A/2B ...".
- **Lane's pick: A, on the default.**

### Ask 3: clean the old bends, or leave them? (S35-packs)
- **Biplane:** Create cannot clean it. The measure freeze puts the old pilot back, so v0.1.5 equals v0.1.4. Create now
  says so ("Not applied"; lane T item 9), and the bend changes nothing in play (13 of 20 both ways).
- **Karts:** cleaned in one sentence (v0.1.8). The reversal rule fired once in 5 seeds; the score moved from about 3-0 to
  2-1.
- **Lane's pick:** leave the biplane (fix Create instead, done); karts either way.

### Ask 4: a C++ lane for the rink core's bots? (S4-core)
- **A (a C++ core patch, `0005-bot-abilities-dive.patch`):**
  - rival bots fire the meteor 1-3 times a minute and dive to stop it (3 of 10 of yours);
  - all switches off is still thirdjam: lab parity 600/600, all 14 hokej tests the same;
  - the native build works here in 1 m 39 s.
- **B (no C++):** drawn only. The "meteor" fells nobody, and the dives stop nothing.
- **Can Create drive A's switches?** Not yet:
  - lane T's scope fix let the cartridge write the rules file;
  - but a quick cartridge edit still promoted without a builder (fixed: item 29), and A's switches are not on main.
- **Found later (J2b):** Arsenal's MEGA reaches the core's bots WITHOUT C++, through a `check_landed` effect, and rival giants come 1-4 times a minute. Some abilities need no core change at all.
- **To play A:** `C:/Users/kazda/kiro/third-life/.claude/worktrees/d25-arsenal/.tl/s4/exe/ThirdLife/ThirdLife.exe -- --dungeon=C:/Users/kazda/kiro/third-life/.claude/worktrees/d25-arsenal/.tl/s4/hand_a`
  (main's exe cannot load A's core). B is in the menu ("spike 4B").
- **Lane's pick: A.**

### Ask 5: shield wall's `bot_call` (S35-packs)
- Create's v0.1.7 never failed it; the hand pack fails it on 2 seeds of 5.
- **5A (accept):** the builder made the call breakable and rewrote the test, and the Foreman allowed it.
- **5B (bots hold their big moves while their captain's call charges):** about 14 lines; the case is gone in Create's
  version; by hand the call always comes on time.
- **Lane's pick: 5B.**

## The editor (lanes T, T2, T3): about 45 items, all landed on main
Each item has a test that fails before and passes after, and most were proven on a copy of the job that showed them.
- **Routing:**
  - the rivals' words reach every bot package;
  - a NOT DONE reaches the file's owner (one hop) and returns to the sender when the receiver can't make it;
  - a quick cartridge edit that leaves the ask unmade goes to a builder;
  - on a core, play rules go to the cartridge first;
  - a fix in another package's file goes to that package.
- **Honesty:**
  - a new attack must land in the bot run, counted honestly (J19's rush: 0 of 15 at night, 9 of 14 now);
  - "Not applied" when a frozen measure undid an ask;
  - every package's change, a changed test and "nothing changed" are on the card;
  - a drawing-only change is not told "balance moved";
  - a builder's narrowing shows as "not made";
  - the "how often" guard: an unmoved rate goes back.
- **Fairness:**
  - only a real fairness ask counts as one;
  - a failed one no longer colors the next change;
  - a fairness round sees every seed's result;
  - one change boundary for all of it.
- **Waste:**
  - no duplicate rounds;
  - a run that never started is re-run, never judged;
  - longer matches get one rule;
  - the Foreman answers questions about its own test.
- **Screen:** impact words mid-screen, YOU ARE / NAME IS, kept inside the screen edges.
- **Contract:** `contracts/JOB.md` has two new sections: "juice day" and "juice night".
- **Evidence:**
  - main's foreman `npm test`: 537 tests, 530 pass, 0 fail, 7 skipped (460/453 at the start of the day, with the Home session's M6 in between);
  - fast tier 5/5; `create.` 29/0; `rink.` 49/0.

## The games: hand juice back, second abilities, newcomers
| Game | Juice back as a sentence (JB-back) | Second ability (J2nd, J2b) | Newcomer's first minute fixed (J2nd, N) |
|---|---|---|---|
| Robot soccer | v0.1.9: on a par with the hand version by eye (flights 3.5-5.0 m vs hand 3.7-5.4) | magnet yank v0.1.11 | v0.1.12: Q shown, "YANKED! Hold Q" |
| Shield wall | v0.1.13: charges match the hand (11 vs 10 a min); braces 2.7 vs 4.8 | catapult volley v0.1.16 | v0.1.18 G and red circles taught; v0.1.19 a clear screen |
| Arsenal hockey | v0.1.27: meteor, net of cords, glass that wobbles; the bots can't use it (C++) | MEGA from a big hit v0.1.29-30, bots too | v0.1.32: HOME text true, MEGA explained |
| Bumper-kart football | - | red shells v0.1.10 | v0.1.11 boxes from GO!; v0.1.12 who got shelled |
| Biplane duel | - | harpoon whip v0.1.8 | v0.1.9-0.1.11: the harpoon taught in the lesson |
| Half-court | - | alley-oop v0.1.8 | v0.1.9 fairer (17 of 20); v0.1.11 the alley-oop cue on screen |

- **What it shows:** a person composes a crazy idea in one sentence, and the editor builds it, the bots included, in
  15-75 min.
- **What it still needs:** a follow-up sentence for juice the first one did not name, and a newcomer pass, because
  every game hid its newest move from a first-timer behind the screen (a lesson, a stale text, a missing key name).

## Asks (answer in chat)
1. **Ask 1 (bots by default):** A or B?
2. **Ask 2 (the juice pass):** A (always, "keep it plain" to skip) or B (the "Make it juicy" choice)?
3. **Ask 3 (old bends):** leave biplane's pilot (Create now says why it can't change), and karts: v0.1.7 or v0.1.8?
4. **Ask 4 (C++):** take patch 0005 (A) into the core? With which default numbers (at the lane's, a regular hand loses
   8 of 10)? Or is the no-C++ route enough for now (MEGA's `check_landed` way)?
5. **Ask 5 (bot_call):** 5A (accept) or 5B (hold)?
6. **A new attack must land:** at least once (as now), or a share of its uses, with a minimum number of uses?
7. **Frozen measures:** may a person restore a frozen test ("put it back as in v0.1.3")?
8. **Kit parts:** should a beam, a ring and a catapult become kit parts? Builders hand-build them today, and the
   hand-mesh check counts places, not meshes.
9. **Arsenal's glass:** stand there all the time, or appear only for a meteor goal?
10. **`TL_EXE_KEYS` mouse buttons** (the exe's scripted keys cannot click; `engine/boot`, the Home session's scope):
    worth adding so newcomer passes can play mouse moves?
11. **A `foreman revert <job> --to <version>`** (written up by T3; S2 and JB both needed it): build it?

## Not done, and why
- **`foreman revert`:** written up, not built.
- **Arsenal's meteor for the bots:** needs patch 0005 (ask 4).
- **Shield braces:** 2.7 a minute against the hand's 4.8.
- **Half-court play changed unasked in v0.1.10:** an old animation copy was restored. N's tree was older than T2's
  workspace fix, which likely covers it.

## Machine and process
- **Lane T hung twice** (15:34-19:20 and 19:23-21:20, one blocking tool call each). The Director stopped it, landed its
  round 5 itself (after splitting an over-budget test file), and moved its queue to T2 and T3. Their briefs forbid
  blocking calls; neither hung.
- **Disk fell twice:** to 9 GB around 16:30 (gtai raw AVIs, about 80 GB) and to 18 GB around 23:15 (gtai raw frame dumps,
  about 29 GB).
  - Both times the gtai sessions cleaned their own after the Director's messages.
  - The Director freed about 12 GB of this shift's own capture folders.
  - Left for you: `%TEMP%/claude/46f132430c565ee6` (25 GB, a gravitone-gcloud session).
  - A small leak of ours: `devx/test/gate-honesty.test.mjs` leaves a `tl_hon_*` repo per run (5260 since 25 Nov, 1.8 MB).
- **Main was pushed during the day under the push rule:** the Home session said yes for its docs-only commits, and its
  M6 landing is its own.
- At most 5 agents at once; the Opus route all day, no Codex.

## Next shift
- Your answers to the asks, then land the chosen spike arms on main.
- A newcomer-pass test the Foreman can run (does a newcomer meet the new move in 60 s?), from N's key-stream tools.
- The juice check's list grows to the impact word and the tell; a NOT DONE about a move's own visible object goes back
  to its builder.
- `foreman revert`.
