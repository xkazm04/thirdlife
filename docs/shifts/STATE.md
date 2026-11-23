# Third Life: shift state

The campaign memory for `/shift` (`.claude/skills/shift/SKILL.md`). Read in full at the start of every shift; the wrap
writes it back. Newest shift-log entry last.

## Now
- Focus (owner, 18 Nov): make the game playable and fun before measuring anything. The walking figure, camera and terrain
  immersion, the parkour course, and the minigame editor as the backbone of player-made games. Hockey decisions and win
  measurement are deferred (hockey re-opened as the first dungeon on 20 Nov); the construction process comes later. Since 19 Nov 22:35: the engine's look (art-engine-duo).
- Since 21 Nov: two worlds (docs/TWO-WORLDS.md): the exe opens a menu (World / Dungeons / Create); hockey is the first
  dungeon; designer v2 (pitch, aspect cards, standard/crazy, phases) builds through Create.
- Since 21 Nov day: the game quality bar (spark game-quality-bar): every generated game goes through a design room (concept
  candidates, a design doc with a feel sheet, a producer review), builders get the feel sheet, and a weak milestone holds
  for the owner. Hockey carries thirdjam's real mechanics and crazy modes.
- Since 22 Nov night: duel (engine/packs/duel) and hockey are the reference games; the editor copies them (templates
  name the house files and numbers, the critic sees the house strip). Engine needs from them land as kernel API (1.16).
- Since 22 Nov day: the Home is Wren Valley (arm A, walkable); E6 fixed (a world builds a pack's space as a first join
  does); the editor checks bot claims against the film and holds hockey to the house camera and puck.
- Since 22-23 Nov night: NO minigame building until the owner accepts a design process. docs/design/METHOD.md (a
  person wants to play it again; only a hand passes fun) and the editor rewritten to it; teardowns of hockey (vs thirdjam)
  and duel (vs For Honor / Souls / Sekiro) in docs/research/; the owner's 75 thirdjam rulings in RULINGS.md.
- Since 23 Nov day: a game is analysed and designed by BEHAVIOUR first (what a hand and the bots get back, measured in the
  running game), not by code or looks. Hockey must prove the method before any other game ("robot soccer" is next).
- Since 23 Nov 16:20: the hockey campaign (docs/design/DIRECTIONS.md): ten directions and a stair. Hockey is rebuilt as
  a 1:1 port of thirdjam (whole system: units, rink, 5 v 5, simulation, bots, chase camera, controls, a skater figure),
  judged by a tempo map, a mechanic matrix by ablation, a ladder of human-limited hands, a playtester in the loop, then
  the owner. Everything else is frozen until his word on step 6.
- Next 3: (1) step 0: thirdjam runnable and instrumented (tempo map, mechanic matrix, hand ladder); (2) step 1: the
  gym (skater, camera, controls on the ported law); (3) steps 2-5 in order, each left only at parity.

## Open owner verdicts
Asks from the day of 21 Nov: ANSWERED ~18:50 (see Decisions).
Asks from the night of 21 Nov (docs/shifts/2026-11-21-night/VERDICT.md): L2 1-4 (camera behind scenery, twist timing,
card-name drift, card fun lines to builders); L4 1-3 (pack.json dungeon block, shared watchdog, dungeon sharing); L3 1-2
(strict word limits, foreman new --card); L5 1-3 (TLVfx.burst kernel fix, HUD title widget, next fun); L1 1 (next
hardening pass); TWO-WORLDS 1-5 (Home shape, single-player first, residents' cost, guest building, small games in the Home).
Answered by the night of 21 Nov: road rails are bodies (L1 built them solid); B2 site fence follows the footprint (built).
Asks from the evening of 19 Nov: W6 summon key; H4 HUD look; H5 PACK.md hud.json convention.
Asks from the day of 19 Nov: E4 Designer call vs scorer (editor, owner tests first). The rest answered 19:00.
Night of 20 Nov D1-D5 and day of 20 Nov D3 closed by the 20 Nov 20:00 decision (crisp cel). Still open from the day: road
rails colliders (decoration or bodies); gate sign in front of the plot fence in every style or crisp only.
Asks from the night of 19 Nov, by ID (details in VERDICT.md):
- E3 village too full by the road for 45 m venues.
- P2 newcomer retry bot in the gate.
- W2 camera sideways swing near crowns, or stay behind; W3 slope jumps (D14/A11);
  W4 slide hand to the floor (Q31); W5 the three bugfix-37 camera rules.
- H1 hockey C4/C6 (deferred topic); H2 should `place()` take pack coordinates; H3 the hockey frame budget under load.

## Backlog (accepted by the owner, not yet scheduled)
- Duel: return later (owner 22 Nov); its lane's next three (a person plays 10 min; one signature animation per rival; E5
  music) wait for that.
- Colosseum: the owner's next direction for the fight jobs (six proofs accepted, not resumed).
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
- 2026-11-23 ~16:20 (owner, after playing the hockey behaviour pass, branch d23-hockey; verbatim in
  docs/design/DIRECTIONS.md): "the same garbage as before. It is not even close to thirdjam"; deformed players, a stick
  flying and under the surface, speed and sprint not balanced as thirdjam, unnatural animations. He asked for ten
  directions toward AAA design in this sandbox and to execute them until the Director thinks the game is perfect, for as
  long as it takes; then he decides whether to throw or freeze Third Life or keep a recipe. And: "the pictures will not
  uncover core problem which is the gameplay itself in speed and balancing of skill mechanisms". Branch d23-hockey is
  NOT landed (rejected by his hand).
- 2026-11-23 ~09:10 (owner, after reading the night's verdict; verbatim in docs/shifts/2026-11-23-day/PLAN.md): (1) the
  hockey teardown is rejected as focused on the visual side: "the core of gameplay design is in behavior, which is almost
  untouched by your analysis. Please do repeat it" on movement sensitivity (speed, acceleration, deceleration), tackles
  and cross-checks and their reactivity, bot aggressivity and ability to play hockey, openness to a sandbox (weapons,
  special equipment, boosts), stick control and the puck sticking to players; (2) person gate after the first greybox
  phase: yes; (3) design lines stay labelled lines (no contract keys); (4) he tests the method on "robot soccer" in the
  evening, once hockey shows we can design an entertaining game.
- 2026-11-22 ~18:35 (owner, after playing the day's exe; verbatim in docs/shifts/2026-11-23-night/PLAN.md): the World
  is "very nice" but objects blink at the ground and between distance levels, with incomplete far structures; Create
  cannot start a new idea; "Hockey is unplayable garbage"; thirdjam is the floor; NO new minigame development until we
  research how games are designed and build "processes and prompts to go much deeper in game design". Night handshake
  ~19:05: all four lanes (teardown, method, world flicker, Create fix), land by 08:00, everything lands.
- 2026-11-22 ~10:30 (owner, on the night verdict of 22 Nov; verbatim: "A. Keep duel as is, we will return there later
  2.Keep bots as is for now, land 'pass out of pressure' once E6 is fidex 3. Home - A 4. Accept for now, the game does
  not play well but I will need to think more before next directions 5. PACK.md per your recmmomendation"):
  1 duel stays as landed (cliff, 0.4 lesson damage, regular ordering, drum all kept); returned to later.
  2 hockey bots as they are (no keep_off_m spacing); r2a "pass out of pressure" lands once E6 is fixed.
  3 the Home is arm A, one continuous land (branch n22-world-a, 71e80bf); it lands behind the boot hook with the far
    plain removed, chunked through N5's land/ format (N6 REPORT next 2).
  4 the six colosseum proofs (fight-colosseum-20261122-1..6) accepted with `foreman quality ... accept`, NOT resumed:
    the game does not play well and the owner decides the next direction first.
  5 contracts/PACK.md names `metrics` and `moments` in a bot's result (amendment of 2026-11-22).
- 2026-11-21 ~18:50 (owner, on the day verdict): "The games are still mediocre slop. even though improved no real person
  would play and enjoy the games, because they miss quality gameplay elements. Arena mutual reaction on attacks and
  collision is almost non-existing, we don't need to reinvent wheel, there are hundreds of duel games (souls like, for
  honor duels) with well known game design paths we can mimic. We don't have ambition to reach the amount of graphical
  detail, but regarding gameplay elements and rules our engine is much more flexible to reach similar level of choices
  and creativity." Verdicts: 1 falls arm A (authored) lands; 2 colosseum retry AFTER researching the know-how ("what's
  making games popular in videogame history"); 3 engine feel kit next shift; 4 big puck: add a kernel radius setter;
  5 hockey bots' body-check rate: keep. And: hockey "is unplayable through inbalancing of puck stickiness, players
  speed, ability AI to decide what to do, when to pass and shoot."
- 2026-11-20 ~20:00 (owner, after playing both final exes and reading the Director's read on minigames and low-end PCs):
  "ok, lets pick crisp cel as the baseline and remove artifacts and outputs from the session we won't need anymore."
  Crisp cel (`d20-cel` 4ca822a) is the baseline look. The toy diorama is not pursued; its branches stay on origin as an
  archive (`d20-dio` c41885a, `diorama-*`). Why: readability for minigames, cost that grows with content (diorama
  1.8-2.1x vs cel 1.1x, busy machine), one look to keep right for every new kit part.
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
- 11:35 standup: base fix e191d8f (figure _face vs TLMesh._face), base re-gated green; four arms on track; exe AA (msaa2+TAA) found as a blur source, the Astra arms own it as a style key.
- 12:35 standup: base fully green (e191d8f), pushed; four arms on track (cel-astra r1 and dio-astra r2 verified, both Fable arms on r2/r3); picture cache not keyed by style (dio-fable keys it).
- 13:30 integration 1: d20-cel 597a374 and d20-dio 1070eea joined without conflicts; world 8/8 + packs 48/48 on both; exes in dist/day/cel and dist/day/dio; one cel seam (toon.shade_k clamp) sent to cel-fable; arms resumed on the joined trees.
- 13:35 standup: four arms on track on the joined trees; cel shade_k seam fixed by cel-fable; dio 16x anisotropy diorama-only; i1 gaps measured.
- 14:35 standup: four arms on track; cel-astra wrote round 3 as `done` and was sent to round 4 (plum shadows, shimmer, figure scale); cel-fable granted landscape.gd for a crisp-keyed road fence row (no colliders), to be offered to dio at i2; dio round-3 warm light matches the board spread (123 vs 122).
- 15:35 standup: four arms on track; cel road rails (crisp key, no colliders) put board 2's composition in the visitor frame; dio flock golden-olive; dio-fable at 2.27x GPU (busy), cutting counts to hold 2x before i2.
- 16:33 standup (integration 2): all four arms committed (c9d14ba, cd89476, 008ee0c, 74208f6) and merged: d20-cel 5e4b5c8, d20-dio 8968ffe (+ inert road_rails port); fast + full PASS on both (world 8/8, packs 48/48, kit 95/95); arms fast-forwarded and resumed; selftests, export and shots running.
- 16:48 integration 2 done: selftests green on both (dio `diorama.` block still running), both exes exported and checked (cel 5e4b5c8, dio 8968ffe), shots taken; by eye cel is clean and closest to its board yet, dio is richer in material but its grade reads sepia/mustard: sent to dio-astra (grade) and dio-fable (dye).
- 17:33 standup: four arms on track; dio felt-wood road rails + relief dye make the chase frame the closest to board 4 today; dio-astra steering Astra by the luma-spread figure (77 vs board 122); cel fixed the three i2 gaps (sign fence, C-band cloud shadow, river streaks); cel full gate PASS 17:07.
- 18:33 standup: four arms on track and gated; cel road-visitor frame reads as board 2; dio grade now matches board luma (07 lower half 59/134/182 vs 59/133/181) but GPU 2.23x classic, over 2x: dio-astra round 6 cuts cost (five switch-off keys exist); cel about 1.1x (busy).
- 19:20 stopped at the owner's word; final merges d20-cel 4ca822a (all gates incl. crisp+classic hashes PASS, export PASS) and d20-dio c41885a (default+diorama hashes PASS, export PASS; classic hash run broke at process level 0xC0000142 = NOT verified, re-run before any landing). Verdict: docs/shifts/2026-11-20-day/VERDICT.md. Owner playing the diorama. Open: D3 (which look), rails colliders, sign placement.
- ~20:00 owner decision: crisp cel is the baseline (see Decisions). Cleanup: 13 worktrees removed via tl trees remove (d20-base, d20-dio, d20-dio-astra, d20-dio-fable, d20-cel-fable, all eight n20 diorama trees); d20-cel-astra lost its 58 GB of raw captures but its 0.5 GB checkout is held open by another process (remove later with `tl trees remove d20-cel-astra --apply`); dist/arms and dist/day/dio deleted; branches kept on origin; d20-cel worktree and dist/day/cel kept for the landing. Disk 221 -> 328 GB free.

### 2026-11-21 night: plan (designer for fun, dungeons, crisp cel hardening)
- 20:05 planned with the owner through the spark designer-and-two-worlds (3 waves, go-gate). Base main 3a4580b: crisp cel merged (516f637), asset manifest re-scanned (5144deb; the merge had made the fast gate red), contract wire text for designer v2 + card fun block (3a4580b). Five Opus lanes: L1 crisp-harden, L2 designer-foreman, L3 create-screen, L4 dungeons-menu, L5 hockey-fun (the owner re-opened hockey as the first dungeon). Director: proof jobs standard vs crazy ("a fight in a colosseum") after L2, docs/TWO-WORLDS.md. Plan: docs/shifts/2026-11-21-night/PLAN.md.
- 20:09 five lanes launched; docs/TWO-WORLDS.md written (09e8e84). 20:58 L2 done in 47 min. Found: my 5144deb "re-scan" ran on main's stale engine/.godot class cache (19 Nov) and wrote pre-merge kit hashes over the merge's correct manifest; reverted (dd1064f), main re-imported, lanes told (their base carries it: one devx.test known-red-inherited). Merged d20-cel dc9024b (selftest fixes under the crisp default, 54ba8e7). L2 landed 32918b6: foreman tests 245 (240 pass, 0 fail), fast gate green. 21:15 proof jobs started (opus, run-through): standard, then crazy.
- 21:20 standup: L1 split-run proof accepted (busy machine), L3 near done, L4 gate running, L5 goalies+hit-stop+aim fix (ladder v3 20 seeds); proof jobs planning; crazy brief bends rules (grow with glory, Emperor's flood).
- 22:17 standup: L1 done (8 harden cases, split kernel suite 356/0, classic world,packs, seed.wall hash moved by the sign collider: intended), re-dispatched to bank rails (60 min), lands last. L3/L4 near done; contract tl.dungeons/1 declared for L4 (342ca06). L5 idle-hand bug fixed (AI mates won alone), ladder v6. Proof jobs had failed in 0 ms on my missing --allow-edit; resumed 22:20.
- 23:20 standup: landed L4 (d0d0bd9: menu + dungeons; pre-merge list green except the busy-cut kernel suite), L4b (344a4e7 watchdog + moving load screen), L3 (7f53372 Create page), L5 (630c387 hockey fun pass). Contracts: tl.dungeons/1 (342ca06), JOB v2 narrowings (91a86cd). Both proof jobs done (standard 4 phases, crazy 5); the critic missed the crazy flood (captures too early); Director stills show it. L1 waits to land last; L5b polishing until 05:30.
- 00:17 standup: pre-merge on 630c387 green but for the kernel suite (cut; k2.down_invariants failed under load, 4/4 alone); uncapped run going. Re-dispatched and committed: L2b 4280f7d (critic films the newest package's own bot; contract 52837d5), L4c dd8a658 (menu fits 720p, export step 3 route), L5b 981cf41 (goalie figure, one-timer). L5c running to 05:30; L1 waits.
- 01:17 standup: all lanes landed: L2b de9b3b9, L4c b280393, L5b+c ea5645a, L1 4318c0b (+43e8ea9 manifest re-scan matching L1's 5 kit parts, +3461190 harden_case split for the size budget). Pre-merge on 630c387 green (uncapped kernel suite 368/0). Final list on 3461190 running on the quiet machine.
- 02:17 standup: final full gate on 3461190 11/14 PASS (world 8/8 = alone); kernel suite cut at 1800 s (115/116, 0 failed), hockey many_budget 1.339 ms and perf NOT RUN at CPU 100 % from the gate itself: re-read alone (uncapped suite, classic packs, quiet perf).
- 03:15 verdict (early): final list on 3461190 green when read alone: full gate 11/14 with its 3 load items re-read alone (uncapped kernel suite 377/0; classic world,packs PASS with hockey p50 0.921 ms; quiet perf 6/6 PASS, ledger line 11), tours headless + window PASS, export + check PASS (step 3 SHOWN). arch --index unchanged. Proof-game clips recorded (proof/*.mp4). VERDICT.md + page.

### 2026-11-21 night: wrap (03:20)
- Done: L1 crisp-harden (4318c0b, 43e8ea9, 3461190), L2 designer v2 (32918b6, L2b de9b3b9), L3 Create (7f53372), L4 menu + dungeons (d0d0bd9, L4b 344a4e7, L4c b280393), L5 hockey fun (630c387, L5b+c ea5645a); contracts tl.dungeons/1 (342ca06), JOB v2 narrowings (91a86cd), capture frames (52837d5); docs/TWO-WORLDS.md. Proof jobs: standard and crazy colosseum both done, both open as dungeons.
- Open: the owner's asks (above); proof-job findings (camera blocked by the arena wall in both, flood at 0:42 not 0:20, standard HUD title overlap, card-name drift); hockey invariants p50 0.92-0.97 ms against 1.0 (tight); site fixtures without an owner (L1); nobody has played any of it by hand.
- Route: 5 Opus lanes + 7 follow-up rounds, all landed; no Codex. Proof jobs 26.0 M tokens in.

### 2026-11-21 day: plan (the game quality bar)
- 10:00-11:00 planned with the owner through the spark game-quality-bar, after he judged last night's colosseum games "horrible", said his earlier quality notes were ignored, and asked for games designed "like a real standalone game we need to design and market". Scouts: the builder never saw the fun goals; the critic's NOT ok never stopped a job; the rig has no fight clips; hockey was rebuilt from memory (thirdjam cloned from GitHub to the scratchpad). Decided: all four tracks (editor quality, fight clips, hockey thirdjam mechanics, hockey crazy + neon) + crisp hardening; critic revise x2 keep-better then hold; falls as 3 Astra arms (owner picks by eye); a 3-step design room; colosseum proof re-run. Base df58f0b (JOB.md design room + quality loop; TLHit stub, API 1.12). Plan: docs/shifts/2026-11-21-day/PLAN.md.
- 11:23 standup: all six lanes on track; L5 unblocked (lint counts tests apart, lazy declares, neon glow keys append-only); L4 watch: busy p50 1.400 vs 1.275 ms base; L2 first to land.
- 12:20 standup: L1 landed (e672fe2; contract c25ce00); post-L1 checks running, then the proof re-run (cap 8 packages); L2/L5/L6 near landable; L3 arm A r1 hashes = base.
- 13:20 standup: L2 landed (f3e1e18); lint split 686213c; proof re-run started 13:04 (standard + crazy, cap 8); main merged into L4/L5 trees (unblocked); pre-merge list on main running.
- 14:20 standup: proof standard paused on a good builder question (rival silhouettes), answered + resumed; crazy failed in design on word limits, restarted, L1b fixing (repair call). L3 falls clips in; L4 joined L5.
- 15:20 standup: L2b, L1b, L6 landed (manifest = 5 kit rows); pre-merge full gate functional steps green (load items for the final quiet list); proof standard held on quality (critic precise), retried with a note; crazy at phase 3.
- 16:20 standup: hockey (L4+L5) landed 4fbf72d; falls arms committed to branches a/b/c (all eligible); L4b budget work; proof standard retry 4 after quality round 3 (bots drive no exchange), crazy answered (Ursus earlier).
- 17:20 standup: L4b landed f389454; all lanes done; final list running; both proof jobs HELD on quality (left for the owner), filmed as they stand.
- 18:20 final list on f389454 green on a quiet machine (perf 2/2, packs 74/74, kernel 407/408 then the celsurf style pin updated for L5's appended neon keys, e2a46a2); pushed.

### 2026-11-21 day: wrap (18:40)
- Done: L1 editor quality (e672fe2, L1b 90f0c0c+23d8cf2: design room, feel sheet to builders, quality loop with hold, strips, length repair, crazy idea diversity); L2 fight clips (f3e1e18, L2b 5b89bdf); L6 crisp hardening (df7762f, 7eba720); L4 hockey thirdjam mechanics + L5 crazy modes (4fbf72d, L4b f389454); contracts JOB.md design room + quality loop (df58f0b, c25ce00), RUNNER.md capture --strip, PACK.md tests counted apart (686213c); kernel TLHit (API 1.12). Falls arms on branches n21d-falls-a 074fa5c / -b 74935d2 / -c 4c70e93 for the owner's pick.
- Proof: colosseum re-run with the new editor; standard (-1) held after 4 revise rounds, crazy (-3) held after 2, both at phase 3 greybox; 34.5 M tokens in. Better rivals/HUD/verbs; still no hit-stop, bodies overlap, the breach not on camera.
- Open: owner asks; a person's play of hockey and the arenas; foreman `quality retry` runs the job in the foreground (backlog).
- Route: 4 Opus + 2 Opus-directed Astra lanes + 3 Astra arms; Astra hockey 0.89 M + crazy 1.18 M (over budget), falls 1.65 M.

### 2026-11-22 night: plan (feel kit, duel reference, hockey playability, editor know-how, the Home)
- 19:00 planned with the owner after the day verdict ("still mediocre slop"; mimic proven duel designs; research first). Research landed c7dad86 (docs/research: DUEL-PLAYBOOK, HOCKEY-ARCADE, WHAT-MADE-GAMES-POPULAR). Falls arm A merged aa82c4f. Lanes: N1 feel kit (Astra), N2 duel reference pack + card (Opus), N3 hockey playability (Astra), N4 editor know-how + tofu stage (Opus), N5 world chunks (Astra), N6 world directions (3 Astra-solo arms, grind loops; owner picks). Colosseum proof retry at the end. Plan: docs/shifts/2026-11-22-night/PLAN.md.
- 20:17 standup: N4 landed edf4337 (+contract cfa2155); N1 API final (relayed), full tier running; N2, N3, N5 on track; N6 arms A, B through 12 rounds.
- 21:17 standup: N1 landed 8e2202a (API 1.13), main merged into duel/hockey; N6 done (arms on branches, compare on main d4155dd); N2 near landable; N3, N5 on track.
- 22:17 standup: N2 near landable on the kernel kit (ladder order right); N3 tuning rookie newcomer; N5 near landable (load faster 940->622 ms).
- 23:17 standup: N5 landed 637573d (+LAND.md 64f26a1); N2 quiet since 22:07, nudged (land core by 00:30); N3 final verification (budget busy 1.080 vs base ~0.95).
- 00:35 standup: N2 past target, told to stop at a clean point; Director fast tier on n22-duel red only on cards.references (card lists TLVfx.squash, unused since the kernel switch); N3 re-verifying on t20 after the frame-cost cuts.
- 00:58 N2 landed a6fc8ad (merge 90ce6a4; fast 5/5 on merged; card dropped unused TLVfx.squash). Owner extended the shift to 09:00 (LOOP.md): N2 duel / N3 hockey quality rounds, N1 engine needs (API 1.14), N4 editor copies the house games. Colosseum proof re-run started 00:56 (jobs 20261122-1 standard, -2 crazy).
- 01:37 standup: duel r1 landed 28d963a (lessons; newcomer hits taken 43 -> 13); N1 E1+E2 near landable; N3 world fixed (8/8), t21 running; standard proof planner timed out (re-run after N4 r1), crazy building core r3.
- 02:47 standup: landed N4 r1-r3, N3 hockey (b024967), duel r2-r4 (09fd089), N1 r1 API 1.14 (c1cca38); JOB.md house games + verbs_used; pushed. Proofs -1/-2 held on quality (old prompts); fresh -3 crazy, -4 standard on r3 prompts.
- 03:45 standup: landed hockey r1-r2 (metrics, pass measure; b2e4ce6), duel r5 KO (20b8a2e), editor r4-r6 (0a7ad79), N1 r2 API 1.15 (8741c9a); integration 09fd089 world 8/8, only wall-clock budgets red (busy). Proof -3 best build so far.
- 04:37 standup: landed duel r6-r8 (de9c48c), hockey r3+r4b+report (d18088b; N3 done), editor r7-r10 (c5dcb62), N1 r3 API 1.16 (69d0513), hook fix 3e1b7e3. N1 on E6 world=alone physics. Proofs -1..-4 held; fresh -5/-6 on r10 foreman.
- 05:39 standup: landed editor r11-r16 (e6b1e7f), duel r9-r12 (9d06a97). Proof -5 passed its blockout look (feel 0.75, house 0.7); -6 held. N2/N4 writing reports; N1 silent on E6, asked.
- 06:37 standup: editor r17 + duel r13 landed (4bfd439); N2/N3/N4 done with reports; N1 silent on E6 (hard stop 07:15); full gate running in n22-int.
- 07:37 standup: final list: full gate green but wall-clock; uncapped 478/2 (one load flake, one test patch fixed 7ba57e4); export, check, tours PASS; quiet perf running; N1 still silent.
- 07:55 verdict: perf 6/6 quiet, packs 129/129 (hockey p50 0.979 ms), world 8/8, export+tours PASS. Page https://claude.ai/artifact/AmANyNo8b2bxNYHZ99BoHU. N1 never reported on E6 (open). Claims released.
- 10:02 late: N1 final report, E6 diagnosed not fixed (body insertion order differs world vs alone); recorded in VERDICT, ENGINE-NEEDS, lanes/N1-kit/REPORT.md + e6/.

### 2026-11-22 day: plan (the three steps of the night verdict)
- Owner ~10:40: "run next shift now with all three steps as daily shift, I will play the game after before major directions for night shift".
- Lanes (launched 12:41): D1 home (Home arm A into the World, Opus), D2 e6 (world = alone fix + selftest, then hockey r2a; Opus-directed Astra),
  D3 editor (critic cross-checks bot claims against film; one hockey job; Opus). Standups :17 hourly; lanes stop 17:15; verdict 17:30; push by 18:30.
  Plan: docs/shifts/2026-11-22-day/PLAN.md.
- 13:44 standup: D3 r1 (9f7f077) + r2 (b0bb985) landed with JOB.md notes; D1 r1+r2 in its full tier; D2 asked for status (silent since 12:45).
- 14:44 standup: D1 r1+2 landed (efbf00f; integration list running in d22-int); D3 r3 (d060ac8) + r4 (9f9ca12) landed, re-dispatched; D2 E6 fix verified (selftest 760 3/3 vs 0/3 on main), A/B next.
- 15:44 standup: D2 r1 integration PASS (2fdfef2), D2 r2 r2a landed (59ada89); D3 r5 landed (167698c), hockey job -3 building; D1 round 3 in its gates.
- 16:44 standup: D1 done (r3 2fdaee0), D3 done (r6 6fb5ea3), D2 wrapping; verdict list started early in d22-int.
- 17:00-18:30 verdict: lanes done (D1 efbf00f/2fdaee0, D2 2fdfef2/59ada89, D3 9f7f077..6fb5ea3). Final list at 48c4f59 in
  d22-int: full gate green but hockey many_budget (1.072 ms, busy), uncapped kernel 492/0, perf 6/6 quiet, export + check;
  packs alone stopped by low memory (not re-run). Page https://claude.ai/artifact/Hzud79BFgAamu4A5yS35dg. Claims released, timers deleted. Hockey jobs -2/-3 held for the owner.

### 2026-11-23 night: plan (research before any more game building)
- Lanes launched 19:12: N1 thirdjam teardown (Opus, research only), N2 game-design method + editor prompts (Opus, web
  research), N3 World flicker and far structures (Opus-directed Astra), N4 Create fix (Opus). Standups :17; lanes stop
  06:45; verdict 07:15; push by 08:00. Plan: docs/shifts/2026-11-23-night/PLAN.md.
- 20:27 standup: N4 done (88ae2cd, fc59f3a); N1 r1+r2 landed (065f28e, 17973df), re-dispatched to a duel teardown; N2 r1 landed (a9b5447); N3 r1 landed (484f58e).
- 21:25 standup: N1 done (11e8936 duel teardown); N2 r2 42b1097 + r3 85d9953 landed, r4 (WORLD line) approved; N3 on floors and tufts.
- 22:25 standup: N2 r4 6be8539 + r5 5910b8a landed; N3 r2 eaa6742 landed, on the far picture's ground re-mesh (finding 1).
- 19:12-23:07 lanes: N1 teardowns (065f28e, 17973df, 11e8936), N2 method (a9b5447..f4f71d2; JOB.md 2599ebe, b925a54),
  N3 world six fixes (484f58e..ea65073), N4 Create (88ae2cd, fc59f3a). All done by 23:07; verdict started early (23:08).
- 03:20 verdict: re-check at bf75b0d green (world 8/8 crisp+classic, uncapped kernel 498/0, tours, perf 6/6, export + check incl. Create); 4 tests red at fa086cb fixed by N3 round 6. Page https://claude.ai/artifact/5og2f2Jykp6iMSUg8NqBJQ. Claims released, timers deleted.

### 2026-11-23 day: plan
- 09:35 three lanes from the owner's answers (no handshake): H1 hand and H2 bots repeat the hockey teardown on behaviour,
  measured in both running games; H3 makes the first (greybox) phase a person gate. Plan: docs/shifts/2026-11-23-day/PLAN.md.
- ~11:00 landed on main: H3 the person gate (624fb73, JOB.md worded a9f7477; foreman 325 tests, 0 fail); H1 hand rounds 1-2
  (5d07c50, f1659f1: BEHAVIOUR-HAND.md) and H2 bots rounds 1-2 (2e33922, 22f9aa4: BEHAVIOUR-BOTS.md), fast tier green
  each time. Then the hockey behaviour pass started: H1 builds its 19 shared rows + route A, H2 its 18 bot lines, each on
  its branch (not main), landable 14:30; an exe from the combined branch for the owner's evening.
- ~14:00 verdict: the hockey behaviour pass is on branch d23-hockey (7c7c996), not main: hand rows S1-S17 + route A,
  18 bot lines, the stick ladder by level; hockey 56 bot tests, world 8/8, export check PASS; many_budget FAIL busy
  (1.31 ms, main 1.07), not read quietly. METHOD 8a on main (6106c56). Exe: .claude/worktrees/n23-int/dist/PLAY-LATEST.cmd.
  Open: the owner's hand; body size (route B); the sandbox's first toys. docs/shifts/2026-11-23-day/VERDICT.md.


### 2026-11-24 night (campaign): plan and log
- 23 Nov ~17:40 three lanes on the stair (docs/shifts/2026-11-24-night/PLAN.md): K1 core (thirdjam's C++ compiled into
  the engine), K2 figure (thirdjam's skater exported and driven), K3 shell (the gym). Branch `hokej`, tree hk-int.
- 17:37 standup: K1's native build of thirdjam's own sim and bots gives 611,543 of 611,543 trace lines identical to the
  Unreal build; K2 exported 202 of 202 clips within 0.19 mm of Unreal's poses; K3 round 1 landed on hokej (c7c8149).
- 18:37 standup: K1 round 2 landed on hokej (aa609ce; thirdjam's code compiled with zero edits, trace-identical); K2 (figure: 92 pose pairs within 0.09 mm of thirdjam's own render) and K3 (camera equals thirdjam's rendered camera on 9,329 steps) built and gating; K4 reference started.
- 19:37 standup: on hokej: K2 round 1 (99b06df), K3 round 2 (camera = thirdjam's rendered camera; kernel 1.17), cores context (503861d). K1 published GAMEMODE.md (14 play rules into core glue); K3 builds the whole match from the core with stand-ins; K4 lab runner and ladder running.
