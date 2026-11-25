H1 critic and checks (editor hardening), day run 25 Nov 2026. Tree .claude/worktrees/d25-hard-a (branch d25-hard-a, from main 39d3f7b). Opus.

OUTCOME AGAINST THE ACCEPTANCE

1. The critic judges captures as a person sees them, HUD on: MET.
   - Every capture the critic or a person judges is now filmed with --hud=on when the engine's runner can keep the HUD
     (capture --hud in engine/kernel/runner/verbs.json, K2; it can). That covers milestone stills and strips (quality.ts
     filmLook), the house game's contact strip (houseStrips), `foreman critique` (cli_critique.ts) and the promotion pictures
     after a change (foreman.ts captureSet).
   - Each capture's label says "HUD ON: as a person sees the game ..."; a runner that cannot keep the HUD gets no flag and
     the label says exactly what is hidden ("HUD OFF: this capture hides the pack's whole HUD layer (score, clock, rings and
     arrows under players, hints, banners, radar) ... do not judge the HUD from it").
   - prompts/critic.md: never call a ring, score, clock or hint missing from a HUD OFF capture.
   - Real-shaped pair, hokej (a rink game), follow camera, frame 600, bot_match_hand, 1280x720, d3d12:
     lanes/H1-critic/h1_hud_on_vs_off_hokej_f600.jpg (left HUD on: 00 PERIOD 1 FIRST TO 3 00, the off-screen arrows 42 m and
     6 m, the controls card, the radar; right HUD off, the capture verb's default and what E5e's critic judged: none of it).
     Raw PNGs: .tl/h1/hud/.
   - Tests: "H1 1" (a job's critic run: every capture request carries --hud=on, the critic prompt's lines say HUD ON) and
     "H1 1b" (no --hud in the runner: no flag, HUD OFF label).

2. The kit gate stops counting cartridge zones as kit parts: MET.
   - conduct.ts countKitUse skips a core's data: data/<name>.cartridge.json and data/<name>.rules.json, and any data JSON
     whose schema is tj.cartridge/* or tl.rink.rules/* (isCoreData). Layout data "kind" entries and TLKit./TLRigs. calls
     still count. The kit-regression message says so.
   - Tests: "H1 2" (unit: E5e's slush cartridge with its 8 zones and 4 bumpers counts 0; dropping a zone changes nothing),
     and "H1 4"/"H1 4b" end to end. On main the E5e figure reproduces exactly on the fake adapter: "KIT REGRESSION: kit parts
     used fell from 14 to 13" and a second builder round; on this tree no kit regression and no builder round.

3. The slow job start: MET with the cache; cold first run measured honestly (see figures).
   - engine/cores/rink/lab/check_cartridge.mjs: the idle and skate_only defect cells are split into --defect-groups contiguous
     seed ranges (default 4, capped at 4); every lab run goes through a pool of --jobs processes (default 4, the long
     skate_only groups first). Before, the check started 8 lab processes at once; now at most 4 (a quarter of this 16-thread
     machine).
   - The lab's raw lines are cached in <repo>/.tl/check-cartridge-cache/<sha256>.json, keyed by the cartridge bytes, the
     rules bytes, the lab exe bytes, the content dir bytes and every run's arguments. Only a check whose every run exited 0
     is kept. A hit says "read from the cache" and adds "cached": true to the tl.rink.check/1 line (absent otherwise).
     --no-cache skips it; TL_RINK_CHECK_CACHE moves it; --make-bands never uses it.
   - Measured on the real lab, as coregate runs it (--defects --json-only), house = hokej hockey.thirdlife + rules
     (rinklab-thirdlife.exe), base = templates/rink_game hockey.regular (rinklab.exe):
       house: before (HEAD's script) 107.7 s; after, cold 56.1 s; after, cached 0.14 s
       base:  before 26.6 s;                  after, cold 29.9 s; after, cached 0.13 s
       the base round's two checks: about 134 s before; about 86 s on a cold cache; about 0.3 s cached, in every job after
       the first on the machine (the house check and an untouched base cartridge are the same in every job).
     The JSON lines are byte-equal to the before run with `seconds` (and `cached`) removed, for both cartridges, cold and
     cached. The machine was at 90-100 % CPU from other sessions during the measurement (room.sh had passed at 60 %), so the
     wall times are under load; the cold base check is slower than before because it now runs 4 processes, not 8.
     Raw: .tl/h1/check/ (times.log, cpu.log, the six outputs).
   - Target "a base round under 40 s": met from the second job on (cached, 0.3 s); NOT met by a first job on a cold cache
     (about 86 s at 4 processes). With --jobs 8 the cold check would be shorter but would load the machine as before.
   - Tests: "H1 3" (a stand-in lab, foreman/fixtures/h1/fake-rinklab.mjs: groups 1-4, 5-8, 9-12, 13-16 for both defect
     cells, at most 4 processes at once, more than 1 side by side, the JSON line byte-equal to one process playing all 16
     seeds, never more than 4 groups) and "H1 3b" (a second check plays no match and says cached; another cartridge or
     another lab exe plays again; --no-cache plays).

4. A change that removes something unasked: MET for the cartridge diff path; named (not asked) on a builder's path.
   - foreman/src/removal.ts: what a change removed = list entries gone between the cartridge before and after (by id; lists
     without ids, like obstacles, by kind, so bigger bumpers are not bumpers removed).
   - coregate.ts cartridgeChange: a valid, measured diff that removes something the person's words did not ask to remove
     (remove, drop, delete, take out, without, fewer, less, instead of, replace...) pauses with a question card on the
     owner: "To add lane-middle I must remove spot-nw, spot-ne: OK? (spot-nw (game.rink.zones), spot-ne (game.rink.zones);
     the change's reason: ...) Answer OK to make it as it is, or say what to keep and it is tried again without removing it."
     The diff waits beside the round (reports/<id>-r<round>-removal.json). OK (ok, yes, sure, it's fine...) makes it as it
     is with no new model call; any other answer is a new try with the answer; a try that still removes is asked again
     (foreman.ts runPackage returns when diffRound left an open question, instead of falling to the builder).
   - The what-changed note keeps its one line and adds one line per removal: "removed: spot-nw (game.rink.zones); why: <the
     diff's reason> (the person agreed to the removal: "OK")". A builder's round that removed list entries is found by
     comparing the last promoted cartridge with pack/ and named "why: not said (a builder's round; its DEVIATIONS may say)".
   - Tests: "H1 4" (E5e's real change on the fake adapter: question, nothing merged, OK, made, no kit regression, no builder
     round, two removed lines), "H1 4b" (a no keeps every spot; words that ask for it are made at once and still named),
     "H1 4d" (a no whose retry still drops spot-nw is asked again, then made on ok), "H1 4c" (pure parts).

Every H1 test fails on main 39d3f7b (run in a scratch copy of HEAD with the new test file and removal.ts beside it): 8 of 8
failed there for behavioural reasons (no --hud, HUD OFF unsaid, count 15 not 3, lab "not built"/no TL_RINKLAB_EXE, no
question, no removed line, KIT REGRESSION 14 -> 13). 4d was added after that run; it depends on the same question path.

GATES
- foreman npm test (after room.sh): 381 tests, 374 pass, 0 fail, 7 skipped, 0 cancelled (295 s). 381 = main's 372 + the 9
  H1 tests (all 9 pass). The 7 skips are the ones main has: 5 "real engine" tests (TL_GODOT unset) and 2 that need real job
  dirs in site/. Log: .tl/h1/npm-test.log.
- node devx/bin/tl.mjs check --tier fast (after room.sh): PASS, exit 0:
    PASS arch [12/12]; PASS assets [4/4]; PASS cards [3/3]; PASS devx.test [229/229]; PASS foreman.typecheck (tsc clean).
  Log: .tl/h1/check-fast.log.
- --tier full not run: no kernel, kit, rig, style or seed file changed (engine/ changes are the rink lab's check script).
- Godot: the two hokej captures (exit 0 each, capture.written ok, d3d12).

CHANGED FILES
- engine/cores/rink/lab/check_cartridge.mjs (split, pool, cache, TL_RINKLAB_EXE seam)
- foreman/src/quality.ts (hudOn, hudArgs, hudLabel; filmLook and houseStrips film HUD on)
- foreman/src/cli_critique.ts (same for foreman critique)
- foreman/src/foreman.ts (+3 lines: HUD on the look and promotion captures; removals into the what-changed note; stop when
  a diff asked again) 1993 lines, under its 2005 baseline
- foreman/src/conduct.ts (isCoreData, countKitUse)
- foreman/src/coregate.ts (the removal question, makeDiff, the yes path in diffRound)
- foreman/src/fastchange.ts (whatChangedNote removal lines)
- foreman/src/removal.ts (new)
- foreman/prompts/critic.md (three lines on HUD ON / HUD OFF)
- foreman/src/test/h1_hardening.test.ts (new, 9 tests)
- foreman/fixtures/h1/slush.v011.cartridge.json (E5e's promoted v0.1.1 cartridge, from .tl/proof-games/patches_v011),
  foreman/fixtures/h1/fake-rinklab.mjs (new)
- docs/shifts/2026-11-25-day/lanes/H1-critic/ (STANDUP.md, REPORT.txt, h1_hud_on_vs_off_hokej_f600.jpg)

BEHAVIOUR CHANGES
- Critic and promotion captures now show the HUD. Their bytes differ from before; a job resumed across this change
  compares a HUD-on capture with a HUD-off one in its first identical-capture check (identicalToPrevious) once.
- The measured check starts at most 4 lab processes (was 8) and reads a cache; a stale cache is impossible by key unless
  something the lab reads lives outside the cartridge, the rules, the exe and the content dir.
- A cartridge diff that removes unasked now pauses the job for the person (a new card where there was none).
- No existing test expectation was moved.

FOR THE OWNER TO LOOK AT
- h1_hud_on_vs_off_hokej_f600.jpg: what the critic sees now (left) and saw before (right).
- The question card: start a core job, ask "make the bumpers bigger and add a fast lane through the middle" on a game with
  8 zones; Create's answer box shows "To add lane-middle I must remove ...: OK?".

QUESTIONS FOR THE DIRECTOR
- The cold check at 4 processes is 56 s for the house cartridge; --jobs 6 would be about 40 s at 37 % of the machine. Keep 4?
- contracts: tl.rink.check/1 has no schema file; the new `cached` key is documented only in check_cartridge.mjs. Should it
  be named in a contract?
- The what-changed first line still carries the diff's whole JSON values and is cut at 1000 characters (E5e's zones fill
  it). A compact list form (+ lane-middle, - spot-nw) would read better; not done here.

NEXT THREE
1. Compact list changes in the what-changed line (zones 8 -> 7: + lane-middle, - spot-nw, - spot-ne).
2. Ask before a builder's round removes list entries too (today it is only named after the fact).
3. Warm the check cache at install or after a lab build (house + base), so a machine's first job also starts in seconds.
