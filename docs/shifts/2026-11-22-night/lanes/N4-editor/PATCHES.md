# N4 editor-knowhow: patches for the Director (contracts are Director-only)

## 1. contracts/JOB.md: append after "### Added 2026-11-21: the design room and the quality loop"

```markdown
### Added 2026-11-22: genre templates and the tofu stage

Approved by the owner on 21 Nov ("there are hundreds of duel games (souls like, for honor duels) with well known game
design paths we can mimic"; "research know how first"). The research is `docs/research/`; the handbook is
`docs/GAME-QUALITY.md` v2 (sections 8-12). Every new key is optional on read; a job made before this reads as before
(absent = omit the key, never `null`). Ids are snake_case.

- **`brief_set.brief.concept.template`** (optional on read; the concept step writes it): `{id, reference, copies}`, the
  ONE proven design the core loop copies.
  - `id`: `"duel"` (a melee duel: `docs/research/DUEL-PLAYBOOK.md`), `"arcade_sport"` (a team game with a ball or puck:
    `docs/research/HOCKEY-ARCADE.md`) or `"own"` (another genre that names its own reference).
  - `reference`: at most 20 words, the real games it is copied from. `copies`: 3 to 6 strings, each at most 20 words.
  - The writer refuses a melee-fight sentence whose template is not `duel`, a team ball/puck sentence whose template is
    not `arcade_sport`, and `copies` that do not name what the template must copy (duel: the state machine, the mutual
    reactions, the rival archetypes; arcade_sport: possession as a state, the utility AI, the roles).
- **`brief_set.brief.design.verbs[].move`** (optional): the template move a verb copies (duel: `light`, `heavy`,
  `charged`, `bash`, `block`, `parry`, `roll`, `dodge`, `taunt`; arcade_sport: `poke`). The writer refuses a verb whose
  frames differ from the template's table (GAME-QUALITY.md section 11) and a duel design with fewer than three copied
  moves, or none that is an attack, or none that is a defence. A defence move is `defensive: true`.
- **Readers of the design**: the design step, the review, the Planner and the builders receive the template's research
  excerpt (the sections of its file; builders get the implementable spec only). `own` gets none.
- **The tofu stage.** A plan made for a brief whose concept has a `template` (and a `design`):
  - The root package's contract carries ONE line `TOFU CHECK: tests/<bot>.gd reports metrics <ids>` naming every metric
    below; the root registers that bot and runs it in its acceptance. The plan is refused without it.
  - The root is milestone `blockout` (flat shapes), every package of the first phase is `blockout`, and no package of a
    later phase is: the first phase IS the blockout milestone.
  - The bot's `_bot_result()` carries `metrics` (PACK.md's "plus any numbers"; the runner reports `bot.result.metrics`),
    and `metrics.hand` (string, the TLHand profile): `feedback_f` <= 3 (checklist item 1), `skill_spread` >= 0.25 and
    `skill_variants` >= 3 (3), `idle_max_f` <= 120 (9), `tell_min_f` >= 12 and `tells` >= 3 (11), `pressure_waves` >= 2
    (12), `lead_change_share` >= 0.3 and `close_rounds` >= 1 (15); a duel adds `contact_types` >= 3 and
    `one_sided_contacts` <= 0, an arcade sport `possession_median_f` 240 to 600. An absent metric fails (not measured
    is not zero).
  - When the blockout milestone is looked at, the Foreman reads the newest finished report of that bot and judges the
    rows WITH the critic's look: one verdict. A failed tofu check makes the look NOT ok (whatever the critic said),
    names the root package, and runs the quality loop as written above (revise rounds 1 and 2, keep the better version,
    then `job_state {state: "paused", reason: "quality"}` and `foreman quality <job> accept|retry`). A version that
    passes the tofu check beats one that fails it in the keep-the-better compare.
  - The look's summary says `tofu stage NOT ok`, or `critic (V5) and tofu stage NOT ok` when both judged; the report is
    `reports/tofu-<milestone>-s<seq>.json` (`tl.foreman.tofu/1`: the rows, `hand`, `from` the bot report, and the merged
    `ok`, `scores` with `tofu` 0 or 1, `notes`, `package`, `by`, `critic`: the critic's own report).
- **The critic's notes end with** `[H] items not judged: a person must play it (items 2, 4, 13, 21, 26, 28, 30)`, the
  [H] items of the checklist (GAME-QUALITY.md section 10). The Foreman appends it when the model leaves it out.
- **`foreman quality <job> accept|retry`** records the answer (the `comment` above) and prints
  `recorded; the job is not started. continue with: foreman resume <job> <the options given>`. It no longer runs the
  job (`--no-run` is accepted and changes nothing).
```

## 2. Questions

1. The tofu rows are checked against `bot.result.metrics`. PACK.md says `_bot_result()` returns "at least `{"ok": bool,
   "summary": String}` plus any numbers"; a nested `metrics` object passes the runner today (`StateHash.plain` keeps
   dictionaries; the fake runner models it). Should PACK.md name `metrics` as the place for named bot figures?
2. `foreman/data/job-events.schema.json` is regenerated here (concept.template, verbs[].move); the strict site reader
   (`engine/kernel/world/site/event_schema.gd`) takes concept and design as opaque, so it needs no change.
3. Hand checks (`tl ladder`, card `hands`) stay where they were (final verification); the tofu stage does not replace
   them.

# Loop round 1 (22 Nov 01:00-01:45): the editor copies the house games

## 3. contracts/JOB.md: append to "### Added 2026-11-22: genre templates and the tofu stage"

```markdown
- **House games** (owner 22 Nov 00:55). A template names its house game, the reference implementation on this engine:
  `duel` -> `engine/packs/duel` (`game.duel`), `arcade_sport` -> `engine/packs/hockey`. The design step and the Planner
  read the house game's README rules; builders read its files in `ref/packs/<pack>/`. A copied `move` is checked against
  the house game's own frame table (`engine/packs/duel/data/moves.json`) when it can be read, else the research's.
  A duel brief must also keep the house game's lock-on facing and its over-the-shoulder camera (said in `rules`,
  `controls`, `arena` or `design.feel.camera`).
- **The house baseline.** Once per job whose brief has a design and whose template has a house game, the Foreman plays
  the house game's measuring bot on `ref/packs/<pack>/` (a job-level `verify` with stem `house-<pack>`) and writes
  `reports/house-<pack>.json` (`tl.foreman.house/1`: `pack`, `test`, `hand`, `metrics` by the tofu names, `from`,
  `note`). It reads the bot result's `metrics` object first and the house pack's own state through a fixed map second.
- **Every look** of such a job sets the tofu bot's figures beside the house game's (a line in the milestone summary:
  "house game engine/packs/<pack> (...), yours vs the house game's: ..."; a figure is SHORT when the house game passes
  its bound and the build does not, or the build is worse by more than 25 % of the house figure). The critic gets the
  line in its context and one more rubric item, `house_game` (0..1: the build's exchange against the house game's).
  The comparison itself does not gate; the critic's `house_game` score does, like every rubric item.
```

## 4. Requests to the game lanes (the Director relays)
- **N2 (duel):** have `tests/support/pilot.gd` return `metrics` in `_bot_result()` under the tofu names
  (`feedback_f`, `skill_spread`, `skill_variants`, `idle_max_f`, `tell_min_f`, `tells`, `pressure_waves`,
  `lead_change_share`, `close_rounds`, `contact_types`, `one_sided_contacts`) plus `hand`. Until then the Foreman reads
  four of them from `pack_state` (`rival_passive_max`, `rival_tells_min`, the keys of `kinds`, `failures`;
  `foreman/src/house.ts` HOUSE_BOTS). The house game is the bar only for the figures it reports.
- **N3 (hockey):** the same for one regular-hand bot (`tests/bot_ladder_pro_regular.gd` today), with
  `possession_median_f` and the HOCKEY-ARCADE 5.5 figures by name. Until then the arcade-sport compare has no figures
  ("no figure to compare by the tofu names") and the critic judges the house game by the README alone.
- **The Planner's time limit** (22 Nov: the standard proof's Planner timed out at 10 minutes): a Planner call (plan and
  re-plan) has 20 minutes unless `foreman plan --timeout-ms N` (or `--planner-timeout-ms N`) says otherwise; `run` and
  `resume` take `--planner-timeout-ms N` for a re-plan (their `--timeout-ms` stays the builder's). Contracts name the
  house game's files and rows instead of retyping its tables.

# Loop round 2 (22 Nov 01:50-02:15): the critic sees the house game's own exchange

## 5. contracts/JOB.md: append to the house-baseline paragraph

```markdown
- **The house strip.** When a look films motion strips, the Foreman also films the house game's exchange once per job:
  it plays the house drill bot on `ref/packs/<pack>/` (duel: `tests/bot_contact_heavy_block.gd`, stem
  `house-<pack>-drill`), takes the contact frame from the bot result (`contact.f`; else 60 frames before the bot
  finished) and captures one strip from 15 frames before it (camera `side`, stem `house-<pack>-strip`) into
  `reports/house-<pack>/strip-<cam>-f<from>.png`, kept in `reports/house-<pack>.json` as `strips` ([] when it could not
  be filmed). The critic gets it as the last image, labelled `HOUSE GAME engine/packs/<pack> (the bar, not this build)`,
  and the `house_game` item asks it to set the build's strips beside it.
- **The house figures** are read from the house bot's result first (the duel pilot returns `rival_passive_max`,
  `rival_tells_min`, `failures` in its result; the verify report carries no `pack_state`), then from `pack_state`.
  `contact_types` is not compared: the house game counts every 6.3 row, a build its own coarser names.
- **`skill_spread` passes from 0.25 to 0.95** (was >= 0.25) and counts variants of the core verb only: the crazy
  colosseum proof of 22 Nov reported 1.0 by counting a bash (0 damage) as a variant of its light.
```

# Loop round 3 (22 Nov 02:10-02:40): the tofu stage proves the whole exchange, the root frames it

## 6. contracts/JOB.md: append to the tofu-stage metrics

```markdown
- **`verbs_used`** joins the tofu rows: how many of the design's verbs the tofu bot pressed at least 3 times each; it
  passes at the design's verb count (`brief.design.verbs.length`; 2 when a plan is checked without a design). The TOFU
  CHECK line names it. (The crazy colosseum proof of 22 Nov passed every other row while no strip showed its parry, roll
  or bash.)
```
Planner text only (no contract change): the root copies the house game's cameras and declares only views that frame the
action (every declared camera is filmed); it shows the template's resource bars (duel: health, stamina, posture); the
tofu bot presses every verb.
