E3 route: the Foreman's route from a prompt to a game ON THE RINK CORE (night of 24-25 Nov 2026)
Tree .claude/worktrees/hk-editor, branch hk-editor (at fdeb09f; nothing committed: the Director lands).

WHAT A SENTENCE NOW DOES
"3 against 3 hockey on a small pond rink" -> concept template rink_sport (hockey, hokej, puck, rink, shinny, bandy,
ringette; a ball game stays arcade_sport, a fight the duel) -> the designer reads the core route whole and writes, in
brief.rules after the METHOD lines (FANTASY / WORLD / TEARDOWN / 30 SECONDS / KILL IF, still required),
  CARTRIDGE: <key path> = <value> (what the player feels)   1 to 16 lines, each path checked against the house
                                                            cartridge, the twelve modes and E2's schema when there
  SKIN: <field> = <value>                                   1 to 10 lines, checked against the base's data/skin.json
                                                            when E1's base is there
-> the Planner plans cartridge first:
  1. {"id":"base","kind":"base",...}: "start from the base", executed by the Foreman (no builder, no tokens): the job's
     ref/base/rink_game/ copied into the workspace, then verified (lint, smoke, the base's first-match bot) and merged
     like any package; scope, registers, contract (with the base's PLAYER CHECK line) and acceptance fixed from the
     base; it does not count against --max-packages;
  2. the cartridge package (data/<name>.cartridge.json, optional data/<name>.rules.json), in the FIRST phase with the
     base, so the greybox is the base with the game's cartridge and plays at once;
  3. the skin package (data/skin.json); 4. only if needed one small script. Later scopes may lie inside the base's.
-> every cartridge/rules file a round changed is validated BEFORE any runner verb (E2's foreman/src/cartridge.ts
   when present, the Foreman's envelope check always); a refused edit costs the round, runs nothing, and the next
   round's feedback carries the problems -> merge gate as before -> at every look the measured check
   (`bash engine/tools/rink.sh check-cartridge <file>`, E2) on the game's cartridge beside the same check on hokej's
   data/hockey.thirdlife.cartridge.json; failed = NOT ok naming the cartridge's owner (revise round, as the tofu
   stage did); could not run = "CORE CHECK NOT MEASURED" in the milestone, never a pass, nothing sent to a builder
-> the person gate after phase 1 (unchanged phases) -> promoted.
No tofu stage, no blockout, no TOFU CHECK line, no house-hockey bot compare on a core game; the duel, arcade_sport
and own routes are unchanged (the plan check still refuses a "base" package in a hand-built game).

PROOF (fake adapter, fake runner, end to end; foreman/src/test/core_route.test.ts, last test):
foreman new "3 against 3 hockey on a small pond rink" -> approve -> plan (--max-packages 2: base + 2 built) ->
run: the base copied (no builder_run for it; a Foreman note "started from the base engine/templates/rink_game/ ...
6 file(s) copied"), cartridge round 1 writes an unknown key "kick" -> refused before any verb, round 2 (its prompt
carries "cartridge edit not valid") fixes it with a merge patch -> merged; greybox look: "core check ok ...
data/game.cartridge.json passed (rink_length_m 60, ...) beside the house game hokej ... passed" -> paused for the
person (exit 3) -> phase pass -> skin -> phase pass -> done, promoted pack carries skin title POND and the 60 x 30 rink.
The fake builder gained `patch` (RFC 7386 JSON merge patch on a file already in the workspace), so a fake builder edits
the base's cartridge as a real one would.

GATES
npm test (foreman): 340 tests, 330 pass, 0 fail, 10 skipped (baseline at fdeb09f: 325 tests, 318 pass, 7 skipped;
  +15 new, +12 passing; the 3 new skips are the named lane gaps below).
tl check --tier fast: PASS 5/5 (arch 12/12, assets 4/4, cards 3/3 with 6 cards, devx.test 229/229, foreman.typecheck).
Skips with a named reason until the lanes land (3): "lane E2's engine/cores/rink/CARTRIDGE.md has not landed",
"lane E2's foreman/src/cartridge.ts has not landed", "lane E1's engine/templates/rink_game has not landed".
No real (paid) Foreman job was run.

FILES
New: foreman/src/coreroute.ts (route, base package, plan problems, brief lines, envelope check, E2 loader, measured
check runner and fake, the core excerpt), foreman/src/coreplan.ts (what designer.ts calls: planCore, corePlanCheck,
packageLimitProblems, the Planner's core sections; out of designer.ts for its 600-line ratchet, now exactly 600),
foreman/src/coregate.ts (the V0 cartridge gate, the look's measured check), foreman/src/test/core_route.test.ts
(15 tests), foreman/fixtures/base-rink-game.json (a stand-in base for the tests only, written out by the test: no .gd
in the tree), engine/cards/rink_core.json (card.rink_core, pack hokej, `core` block).
Changed: foreman/src/templates.ts (rink_sport, coreRouteOf, brief checks), designer.ts (planCheck core shape, base
overlap, base not counted, card enforced, the Planner's {{core}}, the plan normalised; limitLine made one line), reference.ts (ref/cores/
rink/{SNAPSHOT,GAMEMODE,CARTRIDGE}.md, schema/, modes/; ref/base/<base>/), cards.ts (cardLimits.refDir, core lines in
the builder's card section), quality.ts (withStage, the core check in decideLook), roomtext.ts (a core game's builder
feel section is the core route, not the duel's hit-stop rules), room_wire.ts (template id rink_sport), events.ts
(PackageSpec.kind "base", schema), options.ts (coreCheck test seam), builder/fake.ts (patch), prompts/planner.md
({{core}}), prompts/concept.md (rink_sport rule), prompts/plan.schema.json (kind), data/job-events.schema.json
(regenerated), devx/lib/cards/{check.mjs,brief.mjs,brief.d.mts} (the `core` block), engine/cards/team_possession.json
(0.4.0: not_when hockey on a rink -> card.rink_core), .claude/sessions.json (claim hk-editor). Tests adjusted to the
new route (no count lowered): n4 (hockey -> rink_sport, + football -> arcade_sport), cards (housePacks + hokej),
designer_v2 (6 cards), helpers (the "ice hockey" room fixture is rink_sport with CARTRIDGE/SKIN lines).

FOREMAN.TS (E4's file): only the base kind and the cartridge gate, exactly these lines:
  25-27   imports (coreRouteOf, CARTRIDGE_INVALID, startFromBase, coreDataGate)
  827     runPackage: `spec.kind === "base" ? this.startFromBase(...) : await this.callBuilder(...)`
  856-857 runPackage: `let failure = await coreDataGate(...)`; the acceptance loop skipped when it failed
  (options.ts:109-113: the coreCheck test seam; foreman.ts is 1916 lines, under its 2032 ratchet)
  1551-1553 feedback(): the previous round's "cartridge edit not valid" note
  1673-1681 private startFromBase() with its comment: the Foreman note, a RunResult (ok, or refused with why)

FOR LANE E1 (base): the Foreman copies every file of engine/templates/rink_game/ except pack.json, top-level *.md/*.txt,
.godot/ and *.import; pack.json's capabilities/assets/tests/cameras become the base package's registers. Put a
"PLAYER CHECK: tests/<bot>.gd fails when ..." comment in the bot whose ok needs the human (else the Foreman names
tests/bot_match_hand.gd when the base has it). The game's cartridge = the file data/skin.json or data/match.json names
as "cartridge", else the only data/*.cartridge.json. When the base lands, add "base": "rink_game" to card.rink_core's
`core` block (the checker then requires engine/templates/rink_game/pack.json).
FOR LANE E2 (cartridge): coreroute.ts loads ./cartridge.js dynamically and calls the first export found of
validateCartridgeText | validateCartridge | checkCartridge | cartridgeProblems with (parsed cartridge, or the rules
sidecar's text, {file, text, rules}); it reads a string[] or {ok, problems|errors}. `rink.sh check-cartridge <file>`:
exit 0 pass / 1 fail / 2 could not run; its last stdout line a JSON object whose `figures` (or `metrics`, or top-level)
numbers are shown beside hokej's.
FOR LANE E4 (iterate): `foreman plan --from` does not normalise a hand-written core plan (normalizeCorePlan in
coreplan.ts; one call before the planCheck at cli.ts:562 would do it). Create's interview for "hockey" still comes from card.team_possession's
`interview` block (engine/ui reads it); card.rink_core has none yet.

PROPOSED CONTRACT WORDING (Director-only files)
JOB.md, "Added 2026-11-25 (E3): a game on a core":
  - `concept.template.id` may be `rink_sport`: a game on the rink core. Its design names the cartridge keys and skin
    fields it changes as `CARTRIDGE: <key path> = <value>` and `SKIN: <field> = <value>` lines in brief.rules after
    the method lines (1 to 16, 1 to 10), checked against the house cartridge, the modes and the core's schema.
  - `plan_set.packages[].kind` (optional) `"base"`: "start from the base". The Foreman executes it itself: no
    builder_run, a Foreman note naming what it copied from the job's ref/base/<base>/ (every file its scope covers,
    except a file another package of the plan owns that pack/ already holds); then verification and merge as for any
    package. Absent = built by a builder.
  - A plan on a core has exactly one base package, the root, milestone greybox, whose scope, registers, contract and
    acceptance the Foreman fixes from the base's pack.json; other packages' scopes may lie inside its scope (the base
    yields those files); it does not count against the package limit; no TOFU CHECK and no blockout; the package
    owning data/<name>.cartridge.json is in the first phase; the plan names the template's card.
  - Before a round's acceptance, a core job validates every data/*.cartridge.json and data/*.rules.json the round
    changed; a refused file fails the round at level V0 with nothing run, a Foreman note "cartridge edit not valid:
    ..." and reports/<pkg>-r<n>-cartridge-s<seq>.json (tl.foreman.cartridge/1); the next round's feedback carries it.
  - At every look of a core job the measured check runs on each game cartridge and once per job on the house game's
    (reports/core-<m>-s<seq>.json, tl.foreman.core/1; reports/core-house-<house>.json). Failed: the look is NOT ok
    and names the cartridge's owner. Could not run: said as NOT MEASURED in the milestone; never a pass.
  - The reference copy adds ref/cores/<core>/ (SNAPSHOT.md, GAMEMODE.md, CARTRIDGE.md, schema/, modes/) and
    ref/base/<base>/ when the engine has them.
  - JOB.md:436-441 and 524-526 (team possession = engine/packs/hockey) gain: "a rink game is card.rink_core on the
    rink core; card.team_possession is the hand-built route".
CARDS.md, a new optional key row:
  | `core` (optional; added 2026-11-25) | object | `{id, cartridge, check, base?}`: this kind of game runs on the game
  core engine/cores/<id>/; `cartridge` the example's cartridge (data/<name>.cartridge.json); `check` the measured check
  as a person types it; `base` the base a job starts from (engine/templates/<base>/). On a core card `rules_keys` are
  key paths of `cartridge` (`game.rules.score_to_win`) | engine/cores/<id>/ exists; the example holds `cartridge`; each
  rules key is a key path of it; `base`, when given, has engine/templates/<base>/pack.json |

OPEN / NOT DONE
- Verified on the fake runner only; the real route needs E1's base (the first real core job cannot start before it:
  the plan check says so by name) and E2's check-cartridge (until then a look says NOT MEASURED).
- The kit gate still runs on core jobs (harmless: the base is the first merge, data edits do not move it).
- The design doc (verbs with frames, clip moments) is still asked of a core design; its verbs are thirdjam's.
