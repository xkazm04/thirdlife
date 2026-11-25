E1 BASE (K3's lane), ROUND 12 REPORT (night 24-25 Nov; worktree .claude/worktrees/hk-shell, uncommitted, on hokej fdeb09f)

OUTCOME
hokej is now the base a user's game starts from.
- Everything game-specific in words and banks is in data/skin.json.
- Team colours have one source, the cartridge.
- engine/templates/rink_game is the base a Foreman job copies: hokej's generic part, byte for byte, held equal by a
  selftest, with a builder's README.
- A copy of the template with another skin and thirdjam's Pond cartridge plays a whole match headless and shows its own
  names and colours in a window.
- hokej is the same game: the core hash and the run hashes are unchanged.

1. THE SKIN (engine/packs/hokej).
   - data/skin.json, schema tl.rink.skin/1, read by scripts/hud/skin.gd. Unknown keys are errors: each problem is pushed
     as an error and that key keeps its default. The defaults are hokej's (thirdjam's) words. The keys:
     - title, tagline: the title screen and HOME's header ("HOKEJ", "HOCKEY WITH THE WHISTLE TAKEN OUT.").
     - about: HOME's ONE MATCH lines.
     - team_names: the commentator says these where thirdjam's bank says blue / orange, by word boundary, keeping
       thirdjam's capitalisation.
     - levels: the level row's three labels and their lines.
     - commentary: "builtin" (thirdjam's three banks), "off", or a bank file in data/.
     - barks: a bank file in data/ (hokej: hud_barks.json, thirdjam's 1,340 barks) or "off".
   - Wired through screen.gd, front.gd, hud.gd, captions.gd and barks.gd. screen.gd also reads the cartridge
     data/match.json names; it read hockey.regular by name before.
   - SKIN AND CARTRIDGE: the cartridge is the game. It holds the rink, teams, rules and bots, and the team COLOURS
     (game.teams[].colour_hex: one source of truth). The skin is the game's words and banks only.
   - What the cartridge colour now reaches:
     - Already before this round: the figures (K2's SetTeam) and the HUD's team colours (hud.gd team_col).
     - Now also: the bark plates (barks.gd used R.BLUE / R.ORANGE) and the debug stand-ins (match_view used palette keys).
   - rules.gd's BLUE / ORANGE constants remain only as thirdjam's menu-look constants; nothing team-coloured reads them now.
   - tests/bot_skin.gd (new) PASS, headless:
     - the pack's skin.json reads clean, and every key is set;
     - a bad skin (an unknown key, a wrong type, a bad level row) gives exactly three problems;
     - the team words map;
     - the banks the skin names load (commentary 415 lines, barks 1,340);
     - the team colours come from the cartridge.
   - tests/bot_match_hand.gd: MAX_FRAMES raised from 10,800 to 36,000. A timed cut (Pond 3:00) ends on its whistle, not
     on the bound; the regular match ends at 9,071 either way, so its hash is unchanged.
2. THE TEMPLATE (engine/templates/rink_game, new).
   - What it holds:
     - pack.json: id template.rink_game, tests bot_match_hand, bot_first_match, bot_skin. Determinism is
       `tl invariants` on the first test.
     - scripts/** and gen/tj_rink.gd.
     - assets/hud/*.png: thirdjam's 11 UI images.
     - data/: hockey.regular.cartridge.json, skin.json, match.json (cartridge plus level), view.json, gym.json (the
       hall's light without the arena), hud_barks.json.
     - README.md for builders: what a game is (cartridge + skin + rules sidecar + optional scripts), which files they may
       change, how to make a game from it, its tests, the known limits.
   - Left out: the thirdjam parity proofs (the gym and replay rule tests, tj_replay, the 579 KB trace, hand_gym.json, the
     HUD rules recording) and the Third Life cut. Those stay in hokej.
   - Kept equal: engine/tools/selftest.d/850-rink-template.sh (new). `rink.template`: 39 shared files equal hokej's byte
     for byte, PASS. `rink.template_bots`: the template's first match, PASS.
   - hokej "becomes" the base + thirdjam's skin (the base's default skin is hokej's) + its parity proofs. hokej stays
     where it is: a pack cannot load scripts outside itself (lint N4), so the base is a checked copy, not a parent.
   - The template's own bots: bot_match_hand PASS (core hash ab881a00fb9af8ef, the same as hokej's), bot_first_match PASS
     (6f45bf07503f05b8, the same), bot_skin PASS. lint PASS.
   - THE PROOF COPY (.tl/pond_game: the template copied, then only data changed):
     - pack id game.pond_test.
     - data/pond.cartridge.json = thirdjam's modes/hockey.mode.pond.cartridge.json (60 x 30, corners 3, 6 m goals, no body
       checks, timer 3:00, 5 v 5), with its team colours changed to #2E9E44 green and #8E44AD purple.
     - skin: title POND, tagline "PASS, SKATE, NOBODY GETS HIT.", teams Ducks / Geese, levels EASY / NORMAL / HARD, barks
       off.
     - The regular cartridge deleted.
     - lint PASS.
     - bot_first_match PASS: ROOKIE, a whole match on the timer, 9:2 (over) in 13,212 frames.
     - bot_match_hand PASS: 2:5.
     - bot_skin PASS: POND, Ducks / Geese in #2E9E44 / #8E44AD, barks off, "Ducks shoots!".
     - In a window (r12_pond_copy.jpg): green and purple felt figures, score plates, rings and radar; the commentator says
       "ducks against geese, first period". The MATCH card says ROOKIE. Its words are still thirdjam's: "PERIOD 1", no
       FIRST TO 3, because Pond plays on a timer.
     - NOT SEEN: the title screen and HOME with the new words. They show only in the exe's dungeon, and this copy is not an
       export game. Their words come from the skin through front.gd, read by the same path bot_skin checks.
     - Small things a person will notice: "Ducks shoots!" (thirdjam's lines are singular: a skin's plural names read
       wrong); "ducks against geese" in lower case (thirdjam's line has "blue against orange" lower case).
3. THE ARENA AT 60 x 30 (r12_pond_60x30_in_barn.jpg, looked at).
   - The ice, boards, kick plate and the rink's own markings resize to the cartridge. The barn does not: its stands, roof,
     lamps, benches and penalty boxes stay where a 90 x 45 rink puts them.
   - What it looks like:
     - a band of barn floor 7.5 m wide behind the side boards and 15 m at the ends;
     - the team bench and the penalty boxes standing out on that floor, behind the boards, not at them;
     - the stands far off.
     It reads as a practice rink set inside a big hall. Nothing floats, nothing cuts through anything.
   - My answer:
     - The barn should STAY. It is thirdjam's hall, built and lit for one size: scaling it would move its lights, and the
       whole look is lit by them.
     - The rink furniture (ArenaBench*, ArenaBox*, ArenaTable, the goal lights: arena.json layer "rink") should follow
       the boards. That is K6's file.
     - A rink larger than 90 x 45 (Marathon's 140 x 70) would run into the stands: worth K6 refusing or warning.
4. THE HUD PNGs.
   - They live in engine/packs/hokej/assets/hud/ and in engine/templates/rink_game/assets/hud/: 11 files, the same bytes,
     checked by `rink.template`.
   - Every game copied from the template carries them in its own assets/hud/; the HUD loads them by that pack path. A
     builder never makes or edits them (the README says so).
   - The fast tier's `assets` step does not cover them: no manifest entries. If the kernel wants them registered,
     ASSETS.md is yours.

GATES
- hokej:
  - lint PASS.
  - invariants PASS: idle 3b762bc25ee35dbc and the bot fd162294891897fc, both unchanged; solo p99 3.78 ms, p50 3.08 ms.
  - bots 14 of 14 PASS: match_hand ab881a00fb9af8ef (unchanged), first_match 6f45bf07503f05b8 (unchanged), skin (new),
    cut_cores, rule_restart, rule_aim, rule_aim_anchor, rule_s_lock, rule_w_away, rule_signals, gym_hand, tj_replay
    0.54 cm, level_record, hud_rules 474,784 checks (the same count as at the head without my changes, checked).
- The template: lint and its 3 bots PASS. The Pond copy: lint and its 3 bots PASS.
- Selftests: rink.template, rink.template_bots, budget.class PASS.
- tl check --tier fast: arch 12/12, assets 4/4, cards 3/3, devx.test 229/229 PASS; foreman NOT RUN (no node_modules
  here). Full tier not run (your instruction).

OUTSIDE MY SCOPE, LISTED
- devx/arch.rules.json: the smallest row. The uid-orphans rule gets `params.noUidDirs` with "engine/templates/" added to
  its built-in list: packs and pack templates are loaded by the runner only and have no .uid files. The context map
  already covered engine/templates; lint needed nothing.
- engine/tools/selftest.d/850-rink-template.sh (new).
- No kernel line.

CHANGED FILES
engine/packs/hokej:
- scripts/hud/skin.gd (new), data/skin.json (new), tests/bot_skin.gd (new).
- scripts/hud/{screen,front,hud,captions,barks}.gd, scripts/match_view.gd, gen/tj_rink.gd (stand-in colour).
- tests/bot_match_hand.gd (MAX_FRAMES), pack.json, README.md.
engine/templates/rink_game/** (new). engine/tools/selftest.d/850-rink-template.sh (new). devx/arch.rules.json.
docs/shifts/2026-11-24-night/lanes/K3-shell: REPORT.txt, ROUND-12.md, STANDUP.md, r12_*.jpg.
No git writes.

FOR LANE E3 (the Foreman's route)
Point builders at engine/templates/rink_game/README.md. A job copies the folder whole (assets/ too) and changes:
- pack.json's id and title;
- data/<cut>.cartridge.json (with E2's schema and catalog), and data/match.json's `cartridge`;
- data/skin.json.
It runs the three bots. A change the data cannot carry is a script change, and the README says the base's tests stop
speaking for it.

QUESTIONS FOR THE DIRECTOR
1. The furniture of the barn (benches, boxes, table, goal lights) following a smaller rink's boards: K6?
2. Team names that are plural ("Ducks"): a skin key for the singular, or bank lines that do not need it?
3. The MATCH card's "PERIOD / FIRST TO N" and the end card's words into the skin next, or after E2's catalog?

IMAGES TO LOOK AT (docs/shifts/2026-11-24-night/lanes/K3-shell/)
r12_pond_copy.jpg (the template copy: Pond, Ducks / Geese in green and purple, a window), r12_pond_60x30_in_barn.jpg
(a 60 x 30 rink in thirdjam's barn: the far side and the bench on the floor)
