# rink_game: the base a rink game starts from

This is a working game, not a sketch. It is thirdjam's whole match (5 v 5 hockey, its bots, its camera, its HUD, its
figures) on the rink core (`engine/cores/rink`), in the hall thirdjam plays in. It is lane K3's hokej
(`engine/packs/hokej`) with the thirdjam parity proofs left out.

A game made from it is **a cartridge on the core plus a skin**. You change data, play it, and change data again. You do
not write a simulation.

## What a game is here

| Part | File | What it decides |
|---|---|---|
| the cartridge | `data/<cut>.cartridge.json` (schema `tj.cartridge/1`, thirdjam's) | everything that plays: the rink's size and corners, the goals, the teams (how many a side, roles, **colours**), speeds, contact, the puck, shots and passes, the rules (first to N, timer, penalties), the bots, pickups and abilities, zones, obstacles. Thirdjam's twelve modes in `engine/cores/rink/native/content/Cartridges/modes/` are worked examples, with `MODES.md` beside them. The schema and the catalog are lane E2's `engine/cores/rink/CARTRIDGE.md`. |
| the rules sidecar (optional) | `data/<cut>.rules.json` (schema `tl.rink.rules/1`) beside the cartridge | rules the cartridge schema cannot say. With it, `ctx.cores.open` opens the rule-patched core (`RinkCoreThirdlife`); without it, thirdjam's core byte for byte. |
| the match | `data/match.json` | `cartridge`: which cut plays (a file in `data/`). `difficulty`: the bots' level until HOME picks one (rookie, pro, all_star). |
| the skin | `data/skin.json` (schema `tl.rink.skin/1`; unknown keys are errors) | every word that belongs to the game: the title and tagline, HOME's lines, the team **names**, the level row's words, and which commentary and bark banks play (`builtin`, `off`, or a file in `data/`). See `scripts/hud/skin.gd` for each key and its default. |
| the banks | `data/hud_barks.json`, or a bank file of your own in `data/` | the skaters' barks (`{"lines": [[id, situation, speaker, tone, text], ...]}`) and the commentator's lines (`{"lines": [[id, event, kind, team, priority, cooldown_frames, text, duration_frames], ...]}`, the rows of `scripts/hud/commentary_lines.gd`). |

**What the cartridge puts on the rink is drawn from it** (`scripts/rink_toys.gd`, lane E1b): every `game.rink.zones` kind as
a tinted patch with its own mark (fast ice orange with speed streaks, slow ice blue with slush dots, a bumper zone magenta
with a rubber curb, no-shoot a red cross-hatch, boost-only green with a plus; `visible: false` is not painted), every
`game.rink.obstacles` kind standing (box, pillar, magenta bumper bollard, goal shield), pickups as turning beacons by kind
(when the core reports them: below), and a held ability on the HUD ("F: SHOTGUN  READY" above the radar). Nobody places
them by hand: change the cartridge, and the drawing follows.

**Colours have one source, the cartridge's `game.teams[].colour_hex`.** It colours the figures, the HUD's rings, the
score plates, the bark plates, the markers, the radar and the debug stand-ins. The skin names the teams in words only.
Where thirdjam's banks say "blue" and "orange", the commentator says the skin's `team_names`, as written ("the Glare
Foxes", never "glare foxes"). A plural name reads in the plural ("Sharks shoot!", "for the Gulls"; `team_plural` in the
skin, else guessed from the name). A bare colour word that is not its team's colour ("Blue" on a red team) is said as the
colour the person sees ("Red").

## What a builder may change

- **Yes:**
  - `data/*.cartridge.json` (yours, a new name), `data/*.rules.json`, `data/match.json`, `data/skin.json`.
  - New bank files in `data/`.
  - `pack.json` (`id`, `title`, the test list).
  - New tests in `tests/`.
- **Only with a reason the data cannot carry:** `scripts/**` and `gen/tj_rink.gd`. Every line there is a port of thirdjam
  that the data drives: a change there leaves the base, and the base's tests stop speaking for it.
- **Never:** `assets/hud/*.png`. These are thirdjam's UI kit: the ring and dial, plates, segments, header bar, goal banner
  and menu backdrop. A builder cannot make assets. They ship with the base: copy the whole folder.
- **Never:** `contracts/*`, the kernel, the core.

## How a game is made from it

1. Copy this folder to the game's place (for example `engine/packs/<name>/`): every file, `assets/` too.
2. In `pack.json`, set a new `id` (`game.<name>`) and a new `title` (80 characters at most).
3. Put the cartridge in `data/`: start from `hockey.regular.cartridge.json` or one of thirdjam's modes. Name it in
   `data/match.json` `cartridge`. Delete the regular cartridge if the game does not use it.
4. Write `data/skin.json`: its title, tagline, team names, level words and banks.
5. Run the tests (below). Play it in a window: `bash engine/tools/tl.sh capture --pack=<dir> --cam=follow
   --frame=1100 --hud=on --test=tests/bot_first_match.gd --out=<abs.png>`, or run it as a dungeon.

## Its tests

From the repository root (Git Bash):

```
bash engine/tools/tl.sh lint       --pack=<dir>
bash engine/tools/tl.sh smoke      --pack=<dir>
bash engine/tools/tl.sh invariants --pack=<dir>                                # determinism, the frame budget, the first test twice
bash engine/tools/tl.sh bot        --pack=<dir> --test=tests/bot_first_match.gd  # ROOKIE from HOME, a whole match to the end card
bash engine/tools/tl.sh bot        --pack=<dir> --test=tests/bot_match_hand.gd   # a whole match through the keys and mouse
bash engine/tools/tl.sh bot        --pack=<dir> --test=tests/bot_skin.gd         # the skin reads clean, its banks load, colours from the cartridge
bash engine/tools/tl.sh bot        --pack=<dir> --test=tests/bot_toys.gd         # every zone and obstacle of the cartridge is drawn (and pickups, when reported)
```

`bot_first_match` passes when the match ends (by goals or by the cartridge's timer) inside 10 minutes and the end card is
held.

## Known limits of the base

- **Pickups are not seen yet.** The core plays `game.pickups`, but its snapshot (RinkCore 1.3) carries only the sim's events;
  the effect system keeps its pickups and their events to itself. `rink_toys.gd` draws them the frame the core reports a
  `Pickups` list or `pickup_spawn` / `pickup_take` events (a core addition, lane K1/E2); until then a pickup cartridge plays
  unseen pickups, and `bot_toys` says so in its summary. Zones, obstacles and abilities are drawn today.

- **The hall.** Thirdjam's barn is built for a 90 x 45 rink. A smaller cartridge rink resizes only the ice, the boards
  and the kick plate. The barn, its stands, its benches and its penalty boxes stay where they are: on a 60 x 30 rink the
  benches stand out on the floor behind the boards.
- **The rink core** plays thirdjam's sport: skaters, sticks, a puck, two goals. A game that needs another body or another
  ball needs a core patch (lane K1), not a cartridge.
- **Front-end words not yet in the skin.** The front end's other words (MATCH card, end card, panel verbs) are
  thirdjam's. A MODES row on HOME is not ported: the cut is `data/match.json`'s.
- **The faces of the sport.** The skaters' figure and the puck are thirdjam's (engine/rigs/skater; the pack's own drawing
  of the puck).

## The same code as hokej

`scripts/**`, `gen/**`, `assets/**` and the carried tests are byte-for-byte hokej's. Selftest `rink.template` checks this.
A fix to the base goes into both, or into hokej first and is copied here.
