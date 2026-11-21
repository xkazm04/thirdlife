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
