# Third Life: shift state

The campaign memory for `/shift` (`.claude/skills/shift/SKILL.md`). Read in full at the start of every shift; the wrap
writes it back. Newest shift-log entry last.

## Now
- Focus (owner, 18 Nov): make the game playable and fun before measuring anything. The walking figure, camera and terrain
  immersion, the parkour course, and the minigame editor as the backbone of player-made games. Hockey decisions and win
  measurement are deferred; the construction process comes later. Since 19 Nov 22:35: the engine's look (art-engine-duo).
- Next 3: (1) the owner plays `dist/arms/combined/ThirdLife/PLAY-DIORAMA.cmd` (and PLAY-CLASSIC) and answers the diorama
  asks D1-D5 (page https://claude.ai/artifact/PDGjcWgSg1XN6NyujhjKyq): a) adopt diorama or b) evolve crisp cel;
  (2) still open from 19 Nov evening: W6/H4/H5 on exe `79af060`; (3) day-shift findings: flight_review still mode draws no
  wings since 8cae88f; COMMON tours need `--load=block`; the off-origin `--at` hash, the picture-cache proof, the site's
  round fence (B2), editor E4 after his tests.

## Open owner verdicts
Asks from the evening of 19 Nov: W6 summon key; H4 HUD look; H5 PACK.md hud.json convention.
Asks from the day of 19 Nov: E4 Designer call vs scorer (editor, owner tests first). The rest answered 19:00.
Night of 20 Nov, D2 answered 10:10: the owner prefers the Astra character (Opus + Astra) over Fable; a combine with character-astra follows D1. D1, D3-D5 open.
Asks from the night of 19 Nov, by ID (details in VERDICT.md):
- E3 village too full by the road for 45 m venues.
- P2 newcomer retry bot in the gate.
- W2 camera sideways swing near crowns, or stay behind; W3 slope jumps (D14/A11);
  W4 slide hand to the floor (Q31); W5 the three bugfix-37 camera rules.
- H1 hockey C4/C6 (deferred topic); H2 should `place()` take pack coordinates; H3 the hockey frame budget under load.

## Backlog (accepted by the owner, not yet scheduled)
- Editor placement intelligence (E1): the LLM/editor proposes position, pathing and fit on the map. The map updates as the
  requirements change in the builder. Constructions blend into the terrain, with no circular ring that does not match it.
- Contract additions (E2, approved): CARDS.md `interview` and `footprint`; JOB.md `job_created.answers`,
  `job_created.lot` and `change_requested.decision`. Then the village reads the lot from the job.
- Parkour: harder, multi-stage obstacle challenges in the style of TV ninja runs (P1).
- Site Boss modelled in Blender (approved concept, second to Pip; Opus solo).
- Pip as a character with a role (concept: the photo-finish judge; the parkour finish is a natural home).
- A second real Foreman job through the hand checks; the construction process (deferred by the owner).
- ex_car asphalt look (held back 18 Nov: looked worse than grass).

## Decisions
- 2026-11-19 08:20 (owner, morning after the night of 19 Nov):
  - E1: "it is right direction, but needs more care for LLM to pick positioning, pathing in the map, good fit in the map.
    As player develops the requirements in the builder, the map representation should change with it. All constructions
    do have circle around incompatible with terrain around, the transition is not seamless".
  - E2: approve all the contract additions: CARDS.md `interview` and `footprint`; JOB.md `job_created.answers`,
    `job_created.lot` and `change_requested.decision`.
  - P1: "Continue with improvements to create more sophisticated challenges (like TV ninja runs)". The C retry stays for
    now; the course grows into harder, multi-stage obstacle runs.
  - W1: A/D keeps facing the direction (today's default); `TL_AD_KEYS` stays as an option.
  - Still open: E3, P2, W2-W5, H1-H3.
- 2026-11-18: Astra trial routes (memory `project-astra-trial-results`): Opus directing Astra for code/review/tools; Astra
  alone for concept art and look by eye; Opus alone for Blender.
- 2026-11-18: losing trial arms removed on the owner's word; D's and E's parkour code was uncommitted and went with them
  (reports and stills kept in `.spark/Spark/briefs/astra-trial/results/`). Lesson: archive an arm's diff before removing it.
- 2026-11-18 20:40: night of 19 Nov handshake: lanes parkour polish, walker & terrain residue, bug hunt round 2, and the
  minigame editor UI/UX (owner's words in its brief); 3 lanes at once, mixed models; land + push by 08:00; verdict page
  with short videos.

- 2026-11-19 19:00: owner on the day verdict: (0) Astra spend over plan is fine: spend what quality needs. (1) Flight
  "looks great"; remove the wings by default: a key binding and a 'magical' animation summon or dismiss them. (2) Parkour
  "looks great"; next: customize the HUD in the world creator and improve the UI from the user's view; the LLM should
  escape mediocre styling on the first try. (3) Blend accepted for now (B1-B3 closed as built). (4) Editor: opinions after
  more tests, deferred (E4 open). F1/F2/P3/P4 answered by (1) and (2). Points 1-2 run now as an evening shift; the night
  scope is set again from the owner's directions.

- 2026-11-19 23:15: art-engine night (spark art-engine-duo): four style boards (storybook, crisp cel, modern 3D, toy
  diorama); owner chose 4 (toy diorama) as tonight's target: "if 4 superior we will discuss whether to replace current
  theming; if we struggle we stay and chase 2 as natural evolution". Duel per pillar (Astra arm vs Fable arm), 3 pillars
  (frame, surfaces, character), branches only, character on a free route with fixed rails.

## Shift log

### 2026-11-19 night: plan
Handshake 18 Nov 20:40: lanes parkour (Astra alone), walker (Opus directing Astra), editor (Opus + Astra mockups); hunt2
queued after the first landing. Start 00:03, standups hourly at :47, verdict 07:12, land + push by 08:00, verdict page with
clips. Plan: `docs/shifts/2026-11-19-night/PLAN.md`. Before the shift: `bugfix-37` (one Opus builder, the 37 hunt defects)
lands on main.
- 21:25 pre-shift: bugfix-37 landed (main `120208a`): 35 of 37 fixed, Q24 partly, Q31 deferred to the owner; full gate on
  main 14/14 green (kernel.selftest 219, +39), windowed tour PASS. Owner asks from it: slope jump (D14), camera near
  crowns (D5, three choices), slide hand (Q31); see `docs/reports/bugfix-37/REPORT.md` "For the owner".
- 00:08 launched parkour, walker, editor from c8b88fc (agents recorded in PLAN.md); hunt2 waits for the first landing.
- 00:55 parkour landed (merge `9ea78b0`, Astra alone 16 min, 183 k tokens); hunt2 launched from it.
- 00:47 merged tree after parkour: fast, kit 91/91, packs 34/34, world 8/8, headless tour PASS.
- 00:57 standup: parkour landed; walker, editor, hunt2 on track (editor near done); 37 GB free.
- 01:35 editor landed (merge `eac9e92`; fast 5/5, ui.selftest 116, item 91); re-dispatched: change a decision from the game sheet + Astra-alone look pass (worktree n19-editor2).
- 01:57 standup: walker, editor round 2 and hunt2 on track; walker's crest ink costs some bluff crawl (owner ask); 35 GB free.
- 02:20 editor round 2 landed (`c9fe14f`; ui.selftest 123, fast 5/5): change-a-decision + Astra-alone look pass; round 3 dispatched (lost click, village map as home).
- 02:45 hunt2 landed (`30cfbed`; 18 fixes, kernel.selftest 240): main full gate green except packs (hockey many_budget 1.07 ms under load 13; A/B vs pre-merge shows load, not a regression) and perf NOT RUN; both re-run at the verdict. 03:06 hunt2 round 2 dispatched (B8, A1, C9, B11, C8).
- 02:57 standup: walker nearly done (gate green but perf); editor round 3 found the lost click's mechanism; hunt2 round 2 fixed B8.
- 03:28 walker landed (`58a80d1`; crowns 0/0, V wedge, pad swap, ink coverage, crest ink, A/D behind TL_AD_KEYS; 2.04 M Astra tokens); blocks renumbered 400-430; full gate on main running. 03:31 walker round 2 dispatched (hunt2's B2, B4 highs, then walker-scope mediums/lows).
- 03:33 main full gate after walker: all PASS (kernel.selftest 250, packs 34/34, world 8/8) except perf NOT RUN (busy).
- 03:50 hunt2 round 2 (`376dc23`: B8, A1, C9, B11, C8) and editor round 3 (`d47f14b`: village board home; lost click = drive artefact, fixed) landed; fast 5/5 (devx 226), seeds 39, ui 125, hunt2. 36, gate. 7, windowed tour PASS. hunt2 and editor finished (editor's next item, the lot in the 3D village, needs walker's site.gd: after walker round 2). Live: walker round 2.
- 04:05 walker round 2 landed (`7b8c2bf`: hunt2 B2/B4 highs + B7, B3, B9, A13, H1, A5, B12; its gate one run green incl. perf, kernel.selftest 259); main full gate running. Editor round 4 dispatched: the chosen lot into the 3D village (claims site code now walker is done).
- 03:57 standup: three lanes finished and landed; editor round 4 on track; main full gate running.
- 04:40 editor round 4 landed (`16534db`: the chosen lot in the 3D village; the workbench now knows the river); every lane landed. 04:46 short last rounds (until 06:15) to fill idle capacity within the agreed scope: walker 3 (bluff crawl back, slide-entry dip, crown swing behind a flag), parkour 2 (D's cabin, pines, newcomer retry, road blend).
- 05:00 standup: walker round 3 landed; parkour round 2 done (review); then the verdict early.

### 2026-11-19 night: wrap (05:50)
Landed and pushed: main `d6f3659`, exe `d6f3659 2026-11-19 05:29` (export check PASS). The final gate is green on every step
(kernel.selftest 277, ui 128, packs 35/35, world 8/8; perf PASS on a quiet machine). 12 landings: parkour x2, walker x3,
editor x4, hunt2 x2 (plus bugfix-37 before the shift). About 4.1 M Astra tokens. Verdict: `docs/shifts/2026-11-19-night/VERDICT.md`;
page https://claude.ai/artifact/5aAsbgDdYF1FRv3HC2H9YD. Leftover worktrees for the morning cleanup: at-d3-c, n19-hunt2,
n19-hunt2b (held open), n19-walker (Filename too long), n19-walker2, n19-walker3, n19-parkour2, n19-editor4.

### 2026-11-19 day: plan
The owner is away most of the day: "Continue with all tracks during this day ... add one track to allow character fly".
Lanes: editor (E2 in code, then E1 placement), blend (lots without circles), parkour (TV-ninja-style stages), and
flight (mechanical wings, 5 x run). The Director took the design decisions; they are listed in each brief for the owner
to overturn. Contracts for E2 were written first (`cf73f58`). Land and push by 18:00; verdict at 17:15. Plan:
`docs/shifts/2026-11-19-day/PLAN.md`.
- 08:40 day lanes launched: editor, blend, parkour, flight (from `1b3e055`).
- 10:20 parkour landed (`9bb3986`: three stages, 12 checkpoints, per-hand ladders); flight landed (`83c39b7`: wings, 5x cruise, API 1.9) plus the export fix for the wings (`ebeeb2b`). 10:36 round 2: flight builds the walker moves the ninja course needs (ledge grab + mantle, hang bar; API 1.10; Director decision) and dust; parkour checks the newcomer losses, then a stage on the new moves.
- 10:10 standup: all four lanes on track; editor grounds the Designer's lot choice in measured candidates; blend's rings gone.
- 10:45 main full gate after parkour+flight: all PASS (kernel.selftest 288, kit 92, world 8/8) except packs (hockey many_budget 1.225 ms at 99 % load) and perf NOT RUN; A/B main vs pre-flight 9bb3986, 4 alternating runs: 0.857 vs 0.856 ms = load, not flight. Both re-run at the verdict.
- 11:05 standup: flight's moves ready (mid-round landing requested so parkour can build on them); editor and blend on track.
- 11:40 editor landed (`5f50416`: E2 in code, placement grounded in measured places, fences rule) and blend landed (`a68ef16`: no circles, pads follow footprints, seed_drive bowl fixed); CARDS.md takes the editor's three interview extensions (`de68deb`). 11:45 round 2 for both (site fence, pad height, place cost; slope shading, walk as a person). Main full gate running.
- 12:03 main full gate after editor+blend: all PASS (perf PASS quiet, packs 44/44, world 8/8, ui 160) EXCEPT kernel.selftest 284/291: the flight collide case's fixed trunk found no tree after blend moved the seeded scatter (trunk=-inf), taking its process's 6 other cases down. Fixture assumption, not flight behaviour; the flight lane fixes it (find a trunk, split cases) in its landing. Main is red on these until then.
- 12:15 standup: flight moves landed (`a6937c3`), parkour unblocked (d19-parkour3); a missed landable line cost parkour ~70 min (lesson); main still red on the flight fixture until its fix lands.
- 13:00 editor round 2 landed (`0a18c59`: no site circle, pads at land height, Designer only for place words, place-call tokens in the ledger); JOB.md names --place-calls (`858712d`). Editor round 3 dispatched (walk as a person; the turn: site parts now, world_space/runner after flight lands).
- 13:20 standup: flight fix + dust landed on main (`75acca5`; main's flight fixture red fixed); parkour stage 4 Skyline under verification; editor and blend round 2-3 on track. Lessons: landable needs a notification; no copying main files into lane trees.
- 13:35 flight round 2 finished (all on main); round 3 dispatched in a fresh tree (camera ignores bars, soft swing end, pack grip case). The night verdict page (artifact 5aAsbgDd...) no longer exists for this account; VERDICT.md in docs/shifts/2026-11-19-night/ remains the record.
- 13:55 parkour round 3 landed (`cdcf469`: stage 4 Skyline on the new moves; packs 47/47, world 8/8). Findings: ledge 3.05 m float -> flight round 3; `world.sh alone --at=<off-origin>` changes every game's hash (seed_paddle, hockey, parkour) -> next hunt / owner. Parkour round 4: newcomer losses on Skyline, swing framing.
- 14:30 flight round 3 merged (`011e8e2`) then REVERTED (`aeb201e`): it broke 11 parkour Skyline bots on main; its tree predated Skyline, so its gates never saw a pack using ledge+bar. Main packs green after the revert (one hockey-budget flake on the first rerun). Redo in d19-flight4 from main with Skyline. Lesson: re-cut a lane's tree from main before its last round when another lane's merged work depends on its API.
- 14:05 standup: all lanes on track; flight redoing round 3 on top of Skyline; blend quiet for an hour (watch).
- 14:35 flight redo landed (`ce0dd63`): ledge 3.05 m, cameras ignore bars, pack grip case; soft swing for the village walker only (pack swing unchanged, Skyline hashes identical). Main: packs 47/47, world 8/8, moves. 14/14. Flight lane finished for the day.
- 14:50 blend round 2 landed (`0503123`: no facets, terrain-painted wear, car lot as main; checks 512-513). Blend lane finished. Main full gate running.
- 15:10 main full gate green (kernel.selftest 310/310, packs 47/47, world 8/8; perf NOT RUN busy). Merged editor round 3 (yawed construction, auto pad, titles) and parkour round 4 (runway recovery bug a person could hit, Skyline camera): `a6f8941`, foreman 223, packs 48/48, ui 166, world 8/8. Parkour finished. Editor round 4 (the arrived game's turn) until 16:15.
- 15:10 standup: three lanes finished; editor round 4 the only live lane.
- 16:05 standup: editor round 4 reports landable (arrived game turns with the yaw, 8 world hashes identical); reviewing once its final gate lines arrive; other lanes finished.
- 16:18 editor round 4 landed (`e66ca0b`): the arrived game turns with the yaw; merged-tree world 8/8 same hashes, packs 48/48, site. 23/23, ui 166. All lanes finished.
- 17:07 standup: all four lanes finished and landed; full gate started early on a quiet machine for the verdict.

### 2026-11-19 day: wrap (17:40)
All four lanes landed (14 landings, 1 revert): flight `83c39b7`..`ce0dd63` (wings, 5x, API 1.9-1.10 moves), parkour
`9bb3986`..`a6f8941` (four stages, Skyline), blend `a68ef16` `0503123` (no circles, no facets), editor `5f50416`..`e66ca0b`
(E2 in code, placement, the turned game). Main `d59f072`: full gate PASS on every step (kernel 317, perf 2/2 quiet, world 8/8,
packs 48/48); exe d59f072 PASS check; pushed. Verdict: `docs/shifts/2026-11-19-day/VERDICT.md`, page
https://claude.ai/artifact/9bQ6cjKuVXGF8Hw9UGYFHu. About 6.0 M Astra tokens as printed (plan 2-3 M). Claims released, timers deleted.

### 2026-11-19 evening: plan
The owner's points 1-2 of the day verdict, before the night. Lanes: wings (summon and dismiss them by magic, none
worn by default) and hud (a HUD customized in the world creator, styled beyond the first try); both Astra alone for the
look, with an Opus operator. Land and push by 23:30. Plan: `docs/shifts/2026-11-19-evening/PLAN.md`.
- 19:10 evening lanes launched: wings, hud (from `2950f03`).
- 21:08 wings landed (`a6c44ac`: summoned by a sigil, none worn; flight 14/14, moves 15/15, world 8/8, packs 48/48). hud on track (round 2 done, final full tier running).
- 21:09 standup: hud on track (final full tier running; index staleness is the Director's to regenerate); landable due by 22:45.
- 21:34 hud landed (`1e254ab`: Split Ticket HUD + HUD workshop, API 1.11; hashes identical). Both evening lanes landed; full gate on main running for the verdict.

### 2026-11-19 evening: wrap (22:05)
Both lanes landed: wings `a6c44ac` (summoned by a sigil, none worn) and hud `1e254ab` (Split Ticket HUD + workshop, API 1.11),
index and API line `dc87d48`. Main `79af060`: full gate PASS on every step (kernel 324, perf 2/2, world 8/8, packs 48/48); exe 79af060 check PASS;
pushed. Verdict `docs/shifts/2026-11-19-evening/VERDICT.md`, page https://claude.ai/artifact/3UcBXULfNK4stpPdhQhByc.
Astra ~0.85 M tokens. Route held: Astra alone for both looks; operators passed back only measurements.

### 2026-11-20 night: plan
The toy-diorama duel: three pillars (frame, surfaces, character), each built by an Astra arm and a Fable arm on
branches from `diorama-base` (TL_STYLE switch, classic one switch away). Branches only; combine at 06:00; verdict 07:15.
Plan: `docs/shifts/2026-11-20-night/PLAN.md`; boards https://claude.ai/artifact/MaR63DYediCSyJdiZ7cn65.
- 23:30 six arms launched (3 Astra via Opus operators, 3 Fable 5.2).
- 01:03 standup: all six arms on track; early leaders by eye: frame Astra, surfaces Fable, character Fable (the Astra figure's missing wings were a capture artefact, corrected 01:10).
- 02:03 standup: five arms on track, surfaces-astra at risk on time (Astra r1 2 h 25 min, no stills; time check sent); leaders by eye: frame Fable by a nose (light; Astra best sky), surfaces Fable clearly, character Fable by a nose; packs many_budget fails on load for base too.
- 03:03 standup: six arms on track; surfaces-astra classic proof accepted (moving objects only); leaders by eye: frame Fable by a nose, surfaces Fable clearly, character even (Astra r2 closed the gap from behind); window lock is the bottleneck.
- 04:03 standup: all six arms finishing on frozen trees (Astra r3 stopped in frame and surfaces; r2 delivered); leaders by eye: frame even (Astra sky, Fable light), surfaces Fable clearly, character even; character-fable ring banding fixed (v4).
- 05:03 standup: frame-astra and surfaces-astra done (r2); four arms finishing on frozen trees; kernel.selftest hits the 1800 s limit under load in every arm (0 failed): it runs alone at the combine; leaders: frame even, surfaces close, character even.
- 06:15 combine: six arms done and pushed; leaders frame Astra, surfaces Fable, character Fable merged into diorama-combined without conflicts; tl_style.gd size seam fixed (5609241); fast PASS; world/packs and selftests running.
- 06:55 combined build verified: fast PASS; world 8/8, packs 48/48, kit 95/95 (hashes = base); style. 7, rig. 14, figure. 4, surf. 5, flight. 13, wings 2; moves. 13/14 in the batch (nested record exit 127), PASS alone; kernel.selftest alone 338/0; export.check PASS (5609241); quiet perf GPU 1.23 -> 1.56 ms (+27 %).

### 2026-11-20 night: wrap (07:50)
- Done: six arms done, none cut; all pushed (frame-astra e0c9a9f, frame-fable 3a89777, surfaces-astra e61a534,
  surfaces-fable efcf1b9, character-astra 5ce876c, character-fable 4d0023a); `diorama-combined` 9a749e2 (frame Astra +
  surfaces Fable + character Fable), exe `dist/arms/combined/ThirdLife`. Nothing on main but the shift docs.
- Evidence: VERDICT.md; page https://claude.ai/artifact/PDGjcWgSg1XN6NyujhjKyq; lane reports and sheets in `lanes/`.
- Route scoreboard: Astra led frame (one striking image: sky, light); Fable led surfaces (a material system) and character
  (even by eye, cleaner footprint). Cost: Astra at least 3.2 M tokens; Opus operators 1.06 M; Fable 1.78 M.
- Open: the owner's D1-D5; the next shift follows D1.

### 2026-11-20 day: plan (crisp cel vs toy diorama, two teams)
The owner played the combined diorama (10:10). Their verdict: it looks better at first sight, but it is blurry and its
fidelity is far below the concept. Today's look has the potential to evolve. So: one day of two teams, each with Astra
on the frame and the figure and Fable on surfaces and nature, looping for 10 hours to show each look's full potential.
- **Branches:** `d20-cel` (crisp, `TL_STYLE=crisp`) and `d20-dio` (diorama with Astra's figure).
- **Plan:** `docs/shifts/2026-11-20-day/PLAN.md`.
- **Integrations** at 13:30, 16:30 and 19:45 export `dist/day/<cel|dio>`. Verdict 20:45. Branches only.
- 10:40 four arms launched (cel-astra, cel-fable, dio-astra, dio-fable). d20-base fast PASS; world/packs running.
