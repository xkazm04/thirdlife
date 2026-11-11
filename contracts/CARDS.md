# Recipe cards (`tl.card/1`): what a builder is told for a kind of game

Written by the Director on 2026-11-11. A card is the tested, versioned form of "how to build this kind of game on this
engine". It replaces advice written as prompt prose: the Planner picks the card or two that fit a request, the
Builder's brief carries exactly those cards, and the acceptance list of the job comes from the card.

Cards live in `engine/cards/<name>.json` with id `card.<name>`. One card points at exactly one seed pack
(`engine/seeds/<seed>/`), the worked example a builder copies.

**The rule that keeps a card honest: a card names only what exists and what its seed shows.** `tl cards check` (a
fast gate step) fails when a card names a kit part that is not in the kit, an API member that is not in the engine, or
anything its seed does not actually use. So a kernel rename, a removed kit part or a changed seed turns the gate red
at the commit that causes it, and a builder is never sent to copy something that is not there.

## Keys

Unknown keys are errors. An absent optional value is an omitted key, never `null`. Lists are non-empty.

| Key | Type | Meaning | Checked against |
|---|---|---|---|
| `schema` | string | `tl.card/1` | exact |
| `id` | string | `card.<snake_name>`; the file is `engine/cards/<snake_name>.json` | unique; file name |
| `version` | string | `x.y.z`; raise it when the advice changes | format |
| `title`, `summary` | string | one line and one short paragraph for a person or a Planner | present |
| `applies_when` | list of strings | the request features that make this the right card | present |
| `not_when` (optional) | list of strings | look-alike requests this card does not cover, and where to go instead | present |
| `seed` | string | directory name under `engine/seeds/` | has a `pack.json` |
| `capabilities` | list | pack capabilities the recipe uses | in `pack.schema.json` and declared by the seed |
| `kit_parts` | list | kit part kinds the seed uses for this kind of game | in `assets/manifest.json` and used by the seed (`"kind"` in its data or `TLKit.build` in its scripts) |
| `swap_parts` (optional) | list | kit parts to reach for in a variant; not in the seed | in `assets/manifest.json` |
| `api` | list of `TLClass.member` | the calls, signals and members the seed shows | the class declares the member, and the seed's scripts or tests use it |
| `rules_keys` | list | `TLRules` config keys that carry the win condition | set in the seed's `data/rules.json` |
| `data_files` | list of `{file, role}` | the data files to write before any script | exist in the seed |
| `do`, `dont` | list of strings | the techniques and the known mistakes | present |
| `bot` | `{template, plays_by, wins_when}` | the seed's bot to copy, how it plays, what it asserts | the file exists and is in the seed's manifest `tests` |
| `acceptance` | list of strings | what must hold before the game is offered | present |
| `variants` (optional) | list of `{ask, change}` | common requests and the smallest change that answers each | shape |

Every seed must have at least one card (`cards.coverage`). A new seed therefore arrives with its card.

## Commands

```
tl cards list              id, seed, title
tl cards check [--verbose] the gate step: shape, references, coverage
tl cards show <id>         the card as JSON
tl cards brief <id>        the card as the text block that goes into a builder's brief (deterministic)
```

## What is not here yet

- **The Planner does not pick cards yet** and the Foreman does not put `tl cards brief` into builder briefs: that is a
  change in `foreman/` (prompts, the `ref/` directory, the plan event), planned once the current Foreman work has landed.
- `applies_when`, `do`, `dont` and `acceptance` are prose: the check proves they are present, not that they are right.
  Their test is the measurement named in `docs/PLAYER-CONTENT-IDEAS.md`: the same request with and without cards,
  several runs each, compared on verified-first-try rate, bypass count, script lines and tokens.
- Acceptance lines are not yet executed. The ones about a do-nothing or random player need the play profile
  (idea 4 in the same document).
