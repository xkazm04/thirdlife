# Scout 23:45: the editor path to a rink game (read-only scout of hk-int at hokej; file:line)

Nothing in foreman/, engine/cards/ or engine/ui/ knows hokej, `ctx.cores` or cartridges (grep finds only a comment at
foreman/src/shots.ts:185). A generated pack could already call the core; no builder is pointed there.

## 1. Prompt to pack today
- Create GO: `create_design.gd:162-180` -> `foreman_door.gd:155-160` runs `foreman new "<s>" --site <jobs>` (+ `--answers`,
  `--creativity`, `--run-through`). Flags: `engine/ui/flags/real.json` (claude-cli, sonnet, --max-packages 4,
  --timeout-ms 900000, --parallel 2).
- Design room: `cli.ts:505` -> `room.ts:93-124` (concept 5 candidates, design, review max 2 rounds `room_wire.ts:35`).
  Engine context `designctx.ts:35-48`: only API.md headings + sections 0, 12, 13, 17 (section 24 "Game cores" heading only);
  cards' fun blocks `designctx.ts:52`; template excerpt `templates.ts:452-461`, `houseExcerpt :371`; METHOD lines
  `method.ts:17-73` (FANTASY / WORLD / TEARDOWN / 30 SECONDS / KILL IF, refused if missing).
- Approve: `foreman_door.gd:192-197` (react -> approve -> plan -> run). Planner `designer.ts:404-415`, `prompts/planner.md`
  (card index `cards.ts:89`, template excerpt); plan check `designer.ts:266-270` (package limit, phases, TOFU CHECK, PLAYER
  CHECK, card hand bots, no pack.json in scope).
- Builders: `foreman.ts:1623-1659` + `prompts/builder.md` (brief, phase, contract, scope, manifest, card text, feel
  section, reference `reference.ts:143-175`, verifier feedback). `ref/` (`reference.ts:31-104`): API.md, two examples,
  law tables, seeds, KIT/LAYOUT/RIGS/STYLE.md, cards, every house pack a card names copied to `ref/packs/<pack>/`.
  Workspace `site/<job>/ws/<pkg>/` (`foreman.ts:1675-1683`); writes outside scope dropped (`:686-764`), pack.json put back,
  ref/ restored (`:1686-1692`); shell limited to verify commands (`builder/allowlist.ts`, `claude-cli.ts:380-390`);
  scopes cover scripts/ data/ gen/ tests/ (`planner.md:143-144`); PACK.md:14: assets/ are build outputs only.
- Merge gate `foreman.ts:1115` (V0-V2, pack tests); milestones `runMilestone`/`decideLook` (`foreman.ts:1473`,
  `quality.ts:375`): critic, tofu rows (`tofu.ts`), house compare (`house.ts:162-244`); a look NOT ok pauses (`quality`).
- Phases `phases.ts:48-62`; the person gate `design_state.ts:58-60`; Create Try it / Pass / Hold `create_build.gd:178-257`.
- Finish `foreman.ts:1757-1824`, hand checks `:1801`, `promotePack` `promoter.ts:29-45` -> `site/<job>/promoted/<id>[@ver]/`.

## 2. What the editor knows of the old hockey / duel
- Template `arcade_sport` `templates.ts:226-316` (words hockey, football, soccer `:228`); house game `engine/packs/hockey`
  (`:276-278`); builders told to copy carry.gd, poke.gd, ai/*, skate.gd, hits.gd, keeper.gd, ai.json, metrics.gd
  (`:281-293`); house rules `:297-306`; house numbers from tuning.json `:307-314`; the "bar" quotes thirdjam's numbers as
  prose (`:251-274`). Duel `:134-225` / `:192-221`. House bot = old hockey's `bot_ladder_pro_regular.gd` (`house.ts:51-66`).
- Cards: `engine/cards/team_possession.json:17` "pack": "hockey"; `duel.json:17`. JOB.md:436-441, 524-526 restate it.

## 3. Can a generated pack use a core?
- `ctx.cores` needs no capability (API.md:1237; `tl_cores.gd:4`); `open :36-72`, `view_script :79-90`, `part :112-122`
  (arena, audio), `state :95`, `opened :127`; lint forbids `res://cores/` loads directly (`lint.gd:15, :593-596`).
- `open()` reads `<pack>/data/<file>` (`tl_cores.gd:44-52`); a `<name>.rules.json` beside it opens the thirdlife variant
  (`:53-58`). Validation is thirdjam's C++ (`JamCartridge.h:~693-699`; embedded schema `JamSchemaData.inl:3560-3562`:
  cartridge.schema.json, game.schema.json, limits.json; unknown keys error `JamCartridge.cpp:252`); a bad cartridge -> open
  returns null (`tl_cores.gd:62-65`), seen only at smoke.
- Blocks: `KNOWN` only rink (`:17-20`), `PARTS` only arena/audio (`:112-114`); Windows DLLs only; no readable schema in our
  tree; ref/ lacks SNAPSHOT.md and any core pack; builder told engine dir unreadable (`reference.ts:174`); new core rules
  need C++ patches + rebuild.

## 4. hokej: generic vs game-specific (16,509 lines)
Reusable unchanged: main.gd 297 (change cartridge name), cam.gd 465, human_input.gd 70, match_view.gd 241 (stand-in colours
hard-coded :49), gen/tj_rink.gd 289 (sized from game.rink), hud/screen.gd, kit.gd, panel.gd, hud.gd 593, markers.gd,
charge.gd, flow.gd, cards.gd, pausecard.gd, barks.gd. Game-specific: hud/rules.gd 376 (BLUE/ORANGE :10-11), front.gd 160
("HOKEJ", "HOCKEY WITH THE WHISTLE TAKEN OUT." :83-111), captions.gd 584 (team names :142-194), commentary_lines.gd 422
(415 hockey lines), data/hud_barks.json 9,384 (1,340 barks), data/*.cartridge.json (the game), rules.json, match/view/
gym/hand_gym json; data/tj_trace_regular_pro.json (579 KB, parity proof only); tests: 13 bots mostly parity proofs (only
bot_first_match / bot_match_hand style carry over); assets/hud/*.png (11, thirdjam's UI kit; builders cannot make these).
3 v 3 small rink: cartridge rink + teams (MODES.md: Marathon 3 v 3, Pond 60 x 30), HUD colours/words, title; the arena is
a baked 90 x 45 barn (`rink_arena.gd:61-110`), only ice surfaces resize (`:107-109`); at three a side the human passes
0.2-0.8 times a minute. Robot soccer needs more than a cartridge (stick sport sim, TLRigSkater only, hockey barn; a kick
or ball bounce = a C++ patch).

## 5. The cartridge `tj.cartridge/1`
Envelope: schema, id, title, seed, theme{palette}, tunables[] (9 with min/max/default), values, rules[], entities, ai, game
(+ optional game.meta). FJamGameConfig (`JamCartridge.h:666-682`): rink (`:26-40`: size, corner, restitution, friction,
goal size, obstacles[], zones[] slow_ice/fast_ice/bumper/no_shoot/boost_only `JamRulesConfig.h:77`), skater (`:47-150`,
~60 fields), stick (`:155-280`), puck (`:287-306`), shot (`:310-350`), pass (`:353-378`), contact (`:381-540`), rules
(`:543-561`: first_to / timer, score_to_win, goal pause, penalties, hooks[] on_goal/on_check... with then[]
`JamRulesConfig.h:44`, variants: sudden death, last-goal-double, mercy, periods, shrink per goal), teams[] (colour,
skaters' role and spawn `:574`: team sizes free per side), ai (`:585`), pickups[] (`:602`), abilities[] (`:616`: shotgun,
hip_check, shield, slow_puck), look (`:634`), camera (`:646`). Modes: `native/content/Cartridges/modes/` 12 cuts + 2
parked (MODES.md:13-26); ladder `ladder/season.ladder.json` `tj.ladder/1`; `content/Designer/cached-cuts.json` =
thirdjam's own sentence-to-cartridge cache made by claude CLI (precedent for an LLM writing cartridges). Validation C++
only (`JamCartridge.h:~696` "C++ mirror of validateCartridge()"); validate.mjs / schema files not in our tree.
Thirdlife sidecar `tl.rink.rules/1` (`native/glue/rink_rules.h:1-27`, `.cpp:33-63`): rules{key: number|bool} via
TlSetRule (patch 0001 :16-30; today one switch net_carry_wall, patch 0002 :79), levels{rookie|pro|all_star: "k=v;..."};
unknown keys error; the plain core refuses rules.

## 6. Iterations today
aspect_reacted (Create card taps keep -> alternatives -> drop + note, `create_model.gd:62-121`) and redesign
(`create_design.gd:479-482`) only BEFORE approval (`cli_design.ts:75, 96`); phase hold note (`create_build.gd:197-257`,
240 chars) reopens ONE package (`whoOwns phases.ts:79-101`); change_requested `foreman change [--package]` (Planner picks
`foreman.ts:1223-1256`, dependants re-verified `:1258`, new promoted/<id>@0.1.n JOB.md:138-149) but Create's done screen
has only Play (`create_build.gd:291-313`); change box only in the old panel (`ui/panel.gd:1215-1232`), not reached from the
exe menu (`boot/menu.gd:2`). A change cannot add a package; Create has no job list (`new_idea()` forgets the job,
`create_build.gd:361-371`); retyping a sentence goes to a different hook (JOB.md:478-481).

## 7. The exe path
Create GO -> pitch -> Build it -> phase pause Try it launches a second exe with `--dungeon=<job>/pack`
(`create_build.gd:272-286`, `dungeons.gd:134-145`) -> Pass -> "Your game is ready" Play (`create_model.gd:198-204`,
`job_model.gd:90-96`). A generated game is already played as a dungeon, but only from inside Create; nothing writes
`engine/boot/dungeons.json` (pack relative to engine/, no `..`, `dungeons.gd:62-64`), `games.json` (export copies,
`export.sh:212-221`) or `village.json` (`boot.gd:279-315`).

## The 8 biggest gaps
1. No core-game route (templates.ts:226-316, house.ts:35-67, team_possession.json:17).
2. Builders cannot see the core's interface (reference.ts:27-104,174).
3. No cartridge-first build path; no Foreman validator (planner.md, builder.md, JamCartridge.cpp).
4. hokej is not a reusable base (hud/rules.gd, front.gd, captions.gd, commentary_lines.gd, hud_barks.json; PACK.md:14).
5. Quality gates assume hand-built games (tofu.ts, designer.ts:266-270, devx/lib/cards/check.mjs, JOB.md:412-430).
6. Iterations cannot grow the game (create_build.gd:291-371, phases.ts:79-101, foreman.ts:1223-1256, cli_design.ts:75,96).
7. Budget cannot hold a hokej-class hand build (real.json, designer.ts:409): needs a "start from the base" package kind.
8. The core is closed (new sim / figure / arena size = C++ / new KNOWN, PARTS rows) and finished games stay in site/
   (no promote-to-menu: promoter.ts, boot/*.json).
