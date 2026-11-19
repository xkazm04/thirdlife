# Recipe cards (`tl.card/1`): what a builder is told for a kind of game

Written by the Director on 2026-11-11. A card is the tested, versioned form of "how to build this kind of game on this
engine". It replaces advice written as prompt prose: the Planner picks the card or two that fit a request, the
Builder's brief carries exactly those cards, and the acceptance list of the job comes from the card.

Not to be confused with an **item's card** (`item.json`, `tl.item/1`, `docs/SHARING.md`): that one describes a finished
thing a player shares; a recipe card describes how to build a kind of game.

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
| `pack` | string | instead of `seed`: directory name under `engine/packs/` (a house game); exactly one of `seed` and `pack` | has a `pack.json` |
| `capabilities` | list | pack capabilities the recipe uses | in `pack.schema.json` and declared by the seed |
| `kit_parts` | list | kit part kinds the seed uses for this kind of game | in `assets/manifest.json` and used by the seed (`"kind"` in its data or `TLKit.build` in its scripts) |
| `swap_parts` (optional) | list | kit parts to reach for in a variant; not in the seed | in `assets/manifest.json` |
| `api` | list of `TLClass.member` | the calls, signals and members the seed shows | the class declares the member, and the seed's scripts or tests use it |
| `rules_keys` | list | `TLRules` config keys that carry the win condition | set in the example's data: the top level of `data/rules.json`, or the `"rules"` object of a `data/*.json` the pack passes to `TLRules.create` |
| `data_files` | list of `{file, role}` | the data files to write before any script | exist in the seed |
| `do`, `dont` | list of strings | the techniques and the known mistakes | present |
| `bot` | `{template, plays_by, wins_when}` | the seed's bot to copy, how it plays, what it asserts | the file exists and is in the seed's manifest `tests` |
| `acceptance` | list of strings | what must hold before the game is offered | present |
| `hands` (optional) | object | `{seeds, checks: [{hand, wins_min?, wins_max?, measured}]}`: what a person's hand must find over seeds 1..`seeds`; `hand` is `idle` or a `TLHand` profile (`newcomer`, `regular`, `sharp`, `perfect`); at least one bound per check; `measured` is the row the bound came from | known hand, bounds within 0..`seeds` |
| `variants` (optional) | list of `{ask, change}` | common requests and the smallest change that answers each | shape |
| `interview` (optional) | object | the editor's questions for this kind of game: see "Interview and footprint" | shape; every `propose` is one of its question's option ids; option ids unique per question |
| `footprint` (optional) | object | `{size_m: [w, d], height_m, shape, source}`: the worked example's measured size on the ground; `shape` one of `rink`, `pitch`, `court`, `track`, `slalom`, `course`, `arena`, `yard` | numbers > 0; `source` names the file it was measured from |

Every seed must have at least one card (`cards.coverage`). A new seed therefore arrives with its card.

Added 2026-11-17: a card may point at a tracked house game (`pack`) instead of a seed, when the house game is the worked
example of its kind (team possession: `engine/packs/hockey`). Every rule a card's seed meets, its house pack meets the same
way; `cards.coverage` still counts seeds only. The Foreman copies every card to `<job>/ref/cards/` and every house pack a
card names, whole, to `<job>/ref/packs/<pack>/`; a builder brief maps the card's `engine/...` path to that copy in one line
above the card text.

## Hand checks (added 2026-11-18)

A bound comes only from a measured row of the card's own example: `wins_max: 0` for `idle` only where idle won 0 of
`seeds`; `wins_min` is floor(Wilson 95 % low end x seeds), set only when it is at least 1. A hand with no such row is
not set. A pack meets a check through its own test `tests/bot_hand_<hand>.gd` (registered by a package) whose
`_bot_result()` returns `won` (bool). An `idle` test presses nothing and has no frame cap of its own: a game whose round does not
end by itself fails its idle check. A card's example carries every hand test the card checks (`tl cards check`). `tl cards hands <pack> --card <id> [--seeds N] [--tests <dir>] [--par N]` runs
a card's checks on any pack; the Foreman runs them at final verification (`JOB.md`, "Added 2026-11-18").

## Interview and footprint (added 2026-11-19)

Approved by the owner on 19 Nov (E2). `interview` moves the minigame editor's questions into the card (they were in
`engine/ui/interview/*.json`): `{kind, example, match: [words], estimate: {packages, minutes, source}, questions:
[{key, group, ask, options: [{id, label, say, from_words?, size?, shape?}], propose, reason}]}`. `group` is one of
`who`, `win`, `where`. `propose` names the option the editor proposes; `reason` says why, with a measured figure where
one exists. `size` on an option changes the footprint (`{set: [w, d, h]}` or `{scale: f}`). The editor's answers travel in
`job_created.answers` (JOB.md, "Added 2026-11-19"). A request no card fits uses the editor's own `none` questions, which
stay in `engine/ui/`.

## Commands

```
tl cards list              id, seed, title
tl cards check [--verbose] the gate step: shape, references, coverage
tl cards show <id>         the card as JSON
tl cards brief <id>        the card as the text block that goes into a builder's brief (deterministic)
```

## What is not here yet

- (2026-11-17: the Planner picking a card is specified in `JOB.md`, "Added 2026-11-17".)
- Hand checks (`hands`) are executed; `applies_when`, `do`, `dont` and `acceptance` are still prose: the check proves they are present, not that they are right.
  Their test is the measurement named in `docs/PLAYER-CONTENT-IDEAS.md`: the same request with and without cards,
  several runs each, compared on verified-first-try rate, bypass count, script lines and tokens.
- Acceptance lines are not yet executed. The ones about a do-nothing or random player need the play profile
  (idea 4 in the same document).
