# Five tools that let players build content and still get games that are fun

Status: proposals, 2026-11-11 (devx night). Nothing here is built. Each idea names what it is anchored in today, the
smallest first build, how we would know it works, and its main risk. Order is by leverage: 1 and 2 raise the quality
floor of everything else.

Evidence this rests on (all in the repo): job 2 reached a verified marble run in 14 min 45 s for 2.0 M input tokens
with no human code; the quality came from the engine (kit, style, seeds), not from the model (`engine/JOURNAL.md`
retro); the critic's feedback round landed on the wrong package and made kit use worse (JOB2-MARBLE); a layout file
cannot express a new kind of thing without a code edit (lane B pass 3 and 4 findings); sharing needs a computed tier,
not a declared one (`docs/SHARING.md`).

## 1. Recipe cards: a technique library the builder is made to use

**What.** Prompting that works is captured as versioned, tested *recipe cards* instead of living in prompt prose. A card
is data: `{ id, applies_when, genre, do[], dont[], kit_parts[], seed_to_copy, example_pack, bot_template, acceptance[] }`.
"Hockey: use `rink`, `puck`, `paddle`, copy `seed_paddle`'s bot shape; goals are triggers, score by `TLRules`; do not
build boards from boxes". The Planner picks one or two cards for a request; the Builder's brief carries exactly those
cards plus the verbs list; the verifier's acceptance list comes from the card. A new genre is a new card, not a new
prompt.

**Anchored in.** `foreman/prompts/*.md`, the `ref/` directory the Foreman already hands builders (seeds and kit
documents), `engine/seeds/README.md`.

**First build.** Three cards written from the three seeds (paddle, drive, wall) plus a `card.schema.json`, a `tl cards
check` that verifies every referenced kit part, seed and API name exists (a card that names a vanished part fails the
gate), and the Planner told to name its cards in the plan event.

**Measured by.** Same sentence, with and without cards, N >= 5 runs each: verified-first-try rate, bypass count (job 1
had 7, job 2 had 1), script lines, tokens. Cards stay only if they win.

**Risk.** Cards rot as the kernel moves; the check above is what keeps them honest.

## 2. Similarity index: "what already exists that is close to this?"

**What.** Before a job builds anything, query an index of everything known: kit parts, seed packs, shared items, past
jobs and their verdicts, recipe cards. Two kinds of similarity, because text alone misleads:
- *Intent*: embedding of the request against pack READMEs, card `applies_when`, item titles. Answers "this is hockey
  with a twist; start from `seed_paddle` + `rink`".
- *Structure*: a cheap fingerprint of a pack (capabilities used, kit part kinds, rule types, bot shape, script size
  bucket) so a builder or the store can say "this is 90% the same as pack X" and the player is shown X first.
The same index serves the player ("did you mean the community's air hockey?"), the Planner (reuse before build), and the
store (duplicate and near-duplicate detection, a quality ranking by verified pass history).

**Anchored in.** `TLKit.list()/spec()`, pack manifests (`capabilities`, `tests`), `assets/manifest.json` (P4 of this
night), the job log.

**First build.** No embeddings yet: the structural fingerprint plus BM25-style keyword match over READMEs and cards,
local, deterministic, in `devx/` as `tl similar "<sentence>"` returning the top 5 with the reason. Add embeddings only
when keyword recall visibly fails on a written set of 20 queries.

**Measured by.** A hand-labelled set of 20 requests with the right seed/card; recall@3.

**Risk.** Embedding a player's private prompts is a privacy decision; keep the index local and the first build
embedding-free.

## 3. The quarantine: install, build and run player content without touching the player's machine

**What.** A single boundary every player-made or downloaded item crosses, with four stages and one rule: *nothing
leaves the content root and nothing executes outside the runner.*
1. **Pack** (author side): computes the tier from the folder (script/shader/scene -> `code`), writes `item.json`,
   hashes every file, runs hygiene (`devx/lib/assets/hygiene.mjs` from this night is stage zero).
2. **Admit** (install side): recomputes tier and hashes, refuses a disagreeing card, an escaping path, a foreign
   executable, an over-budget file; installs into `content/<item-id>@<hash>/` read-only, never into the game dir.
3. **Run**: data items load in-process; code items only inside the isolated runner process with the brokered `TL*` API
   (the runner's fence and lint already enforce the API surface; the process boundary is the remaining piece in
   `docs/SHARING.md`).
4. **Remove**: uninstall is deleting one directory; nothing is registered elsewhere, so no residue.
Generated content (the in-game builder's output) enters through the same door as downloaded content, so there is one
path to secure and test.

**Anchored in.** `docs/SHARING.md` tiers, `untrusted-extension-host` registry subject read last night, runner lint
(`bypass`, fence), `contracts/ASSETS.md`.

**First build.** `tl item pack|admit|remove` over a content root, with a hostile-fixture corpus (path traversal, a `.bat`
in a texture folder, a tier lie, zip-bomb size, a symlink) that must all be refused; this corpus becomes a gate step.

**Measured by.** The corpus passes in CI; after install/remove of 50 items the content root is byte-identical to its
start and the game dir is untouched.

**Risk.** Windows quirks (reserved names, long paths, case-insensitive collisions): put them in the corpus on day one.

## 4. Fun gate: automatic play-based quality scoring before a game is offered

**What.** "Verified" today means lints pass, a bot finishes and state is deterministic. That proves it runs, not that it
is fun. Add a *playability profile*: bots of several skill levels (random, greedy, scripted-good) play N seeds and the
gate computes cheap, honest proxies: win rate by skill (a good game rewards skill: random << good), decisive-moment
density (events per minute from `TLRules`), dead time (frames with no input effect), stuck/degenerate detection (same
state hash reached repeatedly, score unreachable, trivial win by doing nothing), and difficulty curve across seeds.
A game whose profile is degenerate is sent back with the *named* finding to the *right* package (the critic's open
defect from job 2 was exactly that it could not name the package at fault: profile findings carry the system that
produced them, e.g. "rules: do-nothing bot wins").

**Anchored in.** The bot test mechanism (`tests/bot_*.gd`), `TLRules`, `invariants` replaying the first bot, capture
frames from the bot's finishing frame.

**First build.** Two extra verbs on the runner side (the kernel session, not tonight): `profile` running the existing bot
under a `--skill=` option plus a do-nothing and random bot; Foreman records the profile in the job log; a threshold
file per genre card (idea 1). Start with only the three checks that cannot be argued with: do-nothing bot must not win,
random bot must win less than the scripted-good bot, and a scripted-good bot must finish inside the genre's time range.

**Measured by.** Run it on the three seeds (must pass) and on deliberately broken variants (must fail with the right
named system).

**Risk.** Proxies are not fun; they only remove the clearly broken. Keep the human-play note in the report (the retro
already flagged that no person has played anything).

## 5. The workshop: a player-facing builder session with a bounded, previewable, undoable loop

**What.** The in-game panel is not a chat box; it is a *change request on a living item* with a fixed shape: pick an
item (or "new from <card>"), say what to change, see an estimate (time, cost band), watch a staged preview (kit-level
look first, then rules, then play), accept or revert. Every accepted change is a commit on the item: the player can
branch ("my version of hockey"), diff (parameters and layout changed, in plain words), and share the card. Three limits
make quality reliable: the builder may only touch the *data layers first* (tuning, layout, look) and escalates to a
scripted change only when the card says the request cannot be expressed in data (lane B finding: data first, code as the
escape hatch); every change is verified by the gate and by the fun gate (4); and a failed change leaves the previous
version playing, so the player never loses a working game.

**Anchored in.** Foreman change requests and item card (night items N3/N4), `docs/SHARING.md` item kinds (`tuning`,
`venue`, `look` are data), `foreman` job states, the construction-site log.

**First build.** The tuning-only path end to end: sliders declared by the pack (`tuning.json`), a one-sentence
"make it faster and the ball lighter" request that the model turns into a `tuning` diff validated against declared
ranges, run through smoke and bot, previewed, accepted or reverted. It needs no model-written code at all, so it is
cheap, safe and the first thing a player can feel.

**Measured by.** Median seconds and tokens from request to accepted change; revert rate; how often a request had to
escalate beyond data.

**Risk.** Players will ask for things the engine cannot express; the honest answer ("this needs a new kit part") should
become a visible, countable demand signal feeding the kit backlog, not a silent failure.

## What I would build first

Cards (1) and the quarantine corpus (3) are the foundation and are mostly data and checks, so they fit the devx style of
work. The fun gate (4) needs a kernel session. The similarity index (2) is small once cards and the asset manifest exist.
The workshop (5) is the visible product and should start with the tuning-only path while 1-4 harden underneath.
