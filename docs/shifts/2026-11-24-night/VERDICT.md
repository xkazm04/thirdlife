# Verdict: the night of 24-25 Nov 2026 (hockey campaign, then the editor path)

**Your words, 24 Nov ~23:20:** "alhough the hockey feel like thirdjam, we will need to use rest of this night to achieve
game like this can be built by user from the editor, our engine and prompt process should be capable and user should
have path even through more iterations to get there".

**In one paragraph.** A person can now type a sentence in Create and get a hokej-class game: it starts from a working
base (hokej made into the template `rink_game`), the Foreman writes thirdjam's cartridge for it (rink, teams, speeds,
rules, zones), a measured check plays it headless and refuses gross defects before the person sees it, and a change in
words ("make it faster") is a cartridge diff, not a rebuild. Real paid jobs proved it and also broke it: the second
real game's first change turned it back into plain HOKEJ (fixed and landed, E3f), and the reviewer spent most of the
first game's 140 minutes failing the base's own camera (now sent to the person at once). Everything is on branch
`hokej` (worktree hk-int); nothing reached main except documents: main waits for your word.

## Lanes

### E1 base: hokej made reusable (Opus) — landed (E1 75d1fcb, E1b c360c70)
- `engine/templates/rink_game/` = hokej's shared files byte for byte (selftest 851 `rink.template`); all game words,
  colours and banks in `data/skin.json`; the base draws the cartridge's zones and obstacles, team names as the skin
  says them, a top view that fits the rink and cuts at 4 m, an ability slot.
- Evidence: hokej's 14 bots unchanged hashes; stills `lanes/E1-base/e1b_*.jpg`.
- Open: pickups are not drawn (the core's snapshot does not report them: a C++ addition); in the top view the human's
  ring is drawn off the figure.

### E2 cartridge (Opus, K1's agent) — landed (4c24154, E2b 812bc04)
- Readable schema and limits from thirdjam's C++, `engine/cores/rink/CARTRIDGE.md` in player words, the Foreman's
  validator (`cartridge.ts`) agreeing with the C++ on 112 of 112 cases, `rink.sh check-cartridge` (the lab plays a
  cartridge headless and prints one `tl.rink.check/1` line).

### E3 route (Opus) — landed (E3 268e3b6, b 585d130, c 0499f33, d 991d73e, e 7750a94, f d1c2f59, g 7c19ceb)
- The Foreman's core route: template `rink_sport`, card `rink_core`, the base copied without a builder, CARTRIDGE:/SKIN:
  brief lines, a cartridge round before any code, the measured check with gross defects (goals outside thirdjam's band,
  a match that never ends, the idle hand or skating alone winning), a faithful concept for a plain sentence, the
  person's drops honoured by the critic, absent-team questions asked back.
- E3f (after the real proof): a change on a core game never goes to the base (play words to the cartridge's owner,
  words-only to the skin's), a re-opened package merges only changed bytes so the fast path holds, critic reasons only
  the base can fix go straight to the person's quality card, goals a minute judged, no-op changes asked back with the
  figures, a "what changed in v0.1.n" note on every later version.
- E3g (after real job 3): a pack declares its base in pack.json and lint counts only its own game lines (the base
  alone was 5943 of the 6000, so no script package fitted; contract wording in PACK.md + pack.schema.json, 17c60a1); a
  person's "no" to a builder's question reaches the critic; the Designer's retries hear every failing check and fix the
  exact ones without the model (all six real failed attempts would now pass first time); a sentence naming its own
  twist gets no other.
- Evidence (Director, merged tree 17c60a1): foreman `npm test` 372 tests, 365 pass, 0 fail, 7 skipped; fast 5/5;
  k.sh selftest 120/0; lint blocks 30/0, 11/0, base.lines 6/0; packs 4/4 (146 verb runs).

### E4 iterate (Opus) — landed (E4 12570cd, b 67037b3, c 67b1349)
- Create: a change box on the done screen, My games (a job can be reopened later), Add to menu (`user://dungeons.user.json`),
  the question card with chips, the quality card (Fix it / It's fine, go on / Change it), "Yes, let it", the measured
  figures beside hokej's at a phase pause, a run clock that counts the current run. Fast data-only change path:
  7 runner calls.
- Evidence: `ui.sh selftest` 219/0, `selftest.sh create.` 11/11; stills `lanes/E4-iterate/stills-e4c/`.

### E5 proof: real Create jobs (Opus, real adapter = Sonnet via claude-cli, paid) — landed (8272069, E5b 9a9126f, E5c 4d6b5ad, E5d ad65586)
- Job 1 "3 against 3 hockey on a small pond rink": v0.1.2, 140 min (89 in critic loops on the base's camera); faithful
  concept; "make it faster" = one cartridge diff (accel 12 -> 16, 8.2 -> 10.4 m/s) but took the full path (13 min: the
  merge listed unchanged files; fixed in E3f).
- Job 2 pirate Sharks v Gulls: the gross check refused a cartridge where skating alone wins (6/16) before the person saw
  it; v0.1.0 in 45 min; "make the goals bigger" went to the base and turned it into plain HOKEJ
  (`lanes/E5-proof/e5b/b_j2_v010_vs_v011.jpg`; fixed in E3f).
- Job 3 "hockey where the ice has slow and fast patches and bumpers in the corners" (E5c): the design failed twice in
  Create on the check not knowing the base's own skin keys (fixed, aad3d6f); the third start built exactly the lanes,
  slush circles and corner bumpers (`e5c/c_top_hokej_vs_job3.jpg`), then stopped at 40 min: the base already fills
  5943 of lint's 6000 script lines, so the job's own script package could not fit (E3g).
- The change path on the real adapter (E5d, ad65586): pond job 1 reopened as My games does; "make the rink bigger"
  -> v0.1.3 in 202 s, "make the goals bigger" -> v0.1.4 in 179 s; both the fast path (9 runner calls), both taken by
  the cartridge package, skin and match byte-equal, a "what changed" note each; looked: the ice bigger, the net wider,
  still the Otters v the Pike (`e5d/d_top_v012_vs_v013.jpg`, `e5d/d_net_v013_vs_v014.jpg`). Before E3f the same kind
  of change took 13 min or wiped the game.
- Seen: "bigger rink" also narrowed the goals unasked (the note says so); an old job keeps the base it was built with
  (its top view still has E1b's trusses): there is no base-upgrade path for a finished game.

### K8 balance (Fable) — landed (round 2 5fe872b, 3a 90ca5ed, 3b f85a082)
- Eight experiments kept (no walk-in goals, no take without a key, knockdowns 40-90 frames, the speed law, take shield
  30 frames, rookie no longer lost to the idle hand, all-star at the human pace, pro presses), five rejected; the
  200-seed matrix: the shot, the charged shot, the stop, the sprint and the body check matter; six verbs show no worth
  alone. Details: `lanes/K8-balance/OWNER.md`.

### G1 gate fixes (Opus) — landed (7d56b49)
- hokej tripped the shared world at frame 9071: not a game hitch (that frame costs 3.8 ms) but the hand bot's 4.3 MB
  result counted inside a 250 ms frame; the world now guards a bot's run end under 10 s as a lone run does (kernel
  `host/guard.gd`). Proved both ways at 89d3b85 and 67b1349. The look gym moved out of rigs/ (no wall clock in rigs).
- Evidence (Director, merged tree): `k.sh selftest` 120/0 refs PASS; world 9/9; uncapped kernel suite 565/0 (1920 s).

## Gates on hokej 17c60a1 (Director, 25 Nov morning)
- `tl check --tier fast` PASS 5/5; foreman `npm test` 372 / 365 pass / 0 fail / 7 skipped; `npm run build` clean.
- `k.sh selftest` 120/0 (refs PASS); `tl check --only world` PASS 9/9 (at 7d56b49); `tl check --only packs` PASS 4/4.
- Uncapped kernel suite 565 passed, 0 failed (1920 s, at 7d56b49; E3g after it touched lint only, whose blocks pass).
- Exe: `export.sh` built 17c60a1; `export.sh check` PASS (same hashes as the editor for every game and 4 dungeons,
  village, W/Esc, Create to the pitch with the fake adapter, nothing left running).
- NOT RUN: perf (the machine was never quiet), the full tier as one run (its kernel step would stop at 1800 s; read
  from the uncapped suite instead).

## For your eye (about 15 minutes)
1. `C:/Users/kazda/kiro/third-life/.claude/worktrees/hk-int/dist/PLAY-LATEST.cmd` (build 17c60a1).
2. Menu -> the three games made by real Create jobs tonight (your list, `dungeons.user.json`): **Pond hockey
   v0.1.0** then **v0.1.4** (after "make it faster", "the orange team is too strong", "make the rink bigger", "make
   the goals bigger"), and **Pirate hockey v0.1.0**. Play each one match. Is a game a person made from a sentence
   worth playing next to hokej?
3. Create -> type a sentence of your own (a rink game: "hockey where ..."), Build it, answer its cards, then on the done
   screen type one change. This uses the real model (Sonnet, about 2-5 M tokens a job, 45-60 min to v0.1.0; a change
   about 3 min).

## Asks
1. **Land hokej on main?** (a) yes, all of it; (b) the editor path only after you play a made game; (c) hold.
2. **JOB.md wording** for the core route (base copied, cartridge round, measured check, change on a core never to the
   base, growth): the Director drafts it on your word.
3. **The slow start of every job** (3.4 min: two measured checks of the house cartridges before the base's lint):
   (a) split + cache them next (about 30 s); (b) later.
4. **hokej's hand bot dumps a 4.3 MB raw trace** (452 ms at the end of a run): (a) shrink it (changes K3's proof
   tools); (b) leave it.
5. **A finished game keeps the base it was built with** (pond still shows the trusses fixed in the base since):
   (a) give My games a "move to the newest base" step; (b) not yet.
6. Carried from earlier tonight: the K8 planning-hand refit (it runs about 10 points strong); all-star easier than
   thirdjam's; whether the one-line `hub.gd` / `menu.gd` edits for Add to menu stand.

## Route scoreboard
- Opus did all the engineering lanes (E1-E4, E3b-g, G1) and the real proofs (E5-E5e); Fable only K8 (balance design by
  judgment). The real proofs found every blocking defect the unit tests missed (a change wiping the game, the base
  filling the line budget, the design check refusing the base's own key): run a real job after every route change.
- Cost of the real jobs (Sonnet via claude-cli; E5's first run in its own report): E5b 17.9 M in (14.1 M cached), E5c 5.0 M,
  E5d about 45 k, E5e PENDING.

## Next shift
1. Your verdict on a made game (above). 2. The slow job start (split + cache the measured checks). 3. JOB.md for the
core route, then hokej on main. 4. Robot soccer (your plan from 23 Nov) only after a made hockey game passes your hand.
