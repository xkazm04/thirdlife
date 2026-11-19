# The minigame editor: design (lane editor, night of 19 Nov 2026)

Status: problem statement written 00:20; the rest of this file is filled in below it during the night.

## 1. Problem statement (this is what Astra draws from)

**Third Life** is a cosy toy-like 3D sandbox village (golden-hour light, ink outlines, chunky low-poly kit parts:
fences, cranes, rinks, stands, scaffolds, flags). A player describes a minigame; AI builders (the Foreman) make it
over 30-60 minutes; while they work, a construction site with a crane and one "bay" per package rises on a fenced
round lot in the village; when the game is finished the scaffold comes down and the game stands on the lot, playable
by walking in. The village has a road, about ten round plots (radius 28 to 64 m) and site lots beside it.

**The editor** is the player's tool for this. Today it is a dark developer panel: a list of jobs with state chips and
a sheet with folding sections (brief, build, change, tune). A new game starts from one blank text box ("Describe a
game..."). The owner calls it "very static and mediocre"; it should become **the backbone for thoughtful minigames and
worldbuilding**: games like ice hockey (two teams, a puck, periods), an arena RPG (a fighter, waves of enemies,
abilities), and Takeshi's-Castle-style obstacle courses (jumps, slides, beams, a clock).

The editor must do three things well:

1. **Draw out what the player wants.** Not a blank box. The engine has *recipe cards*: one per kind of game it knows
   how to build (today: team possession = hockey/football, knock-down = throw at breakable walls, timed drive =
   laps against a clock, two sides and a ball = pong/air hockey). Each card knows the questions that matter for its
   kind (players a side, periods and their length, score to win, laps, difficulty as opponent reaction, the
   surface: ice or grass, the venue's dressing: stands, scoreboard, light masts) and offers common variants
   ("football instead of hockey", "harder opponents"). For each question the editor can propose an answer with a
   one-line reason, so the player adjudicates instead of composing. Some ideas fit no card (an arena RPG has none
   yet): the editor must say so honestly (built without a recipe: slower, riskier, more questions from builders).
   The player's own sentence still matters: it is the first thing asked and it is kept, word for word.
2. **Present a game in progress.** What is decided (answers, the brief), what is still open (a builder's question
   waiting for the player, choices left to defaults), what the builders are doing now (packages: waiting, building,
   checking, on hold, built, failed; minutes and tokens spent), and pictures as they come. A builder can stop and
   ask a question; the game can stall; a change can be asked for after the first part is built; numbers can be
   tuned with sliders once it is done.
3. **Size and place the construction in the world.** The game needs ground: a footprint (a hockey rink 60 x 30 m
   plus stands; an obstacle course 18 x 50 m and 12 m high; a throwing range). The player must see how big it will
   be against a 2 m tall walking figure, which plot of the village it takes, its neighbours, which way its gate
   faces the road, and whether it fits (no overlap with other games, not on the road, a path in from the road).
   Answers change the size (more players a side = bigger rink; more obstacles = a longer course) and the placement
   must follow live.

**Who uses it:** a player, not a developer; at a desk (mouse and keyboard, 1280x720 to 1920x1080 window), inside the
game (the village behind the panel) or on its own. Patient enough to answer six good questions, not twenty.

**Constraints for any design:**
- Built in Godot 4.7 from code (Controls, a 2D top-down map drawn with draw_* calls, optionally a small 3D view);
  no web views. Colours come from the house style file (golden hour palette: warm cream, honey, terracotta, sage
  grass, dusk violet shade, ink-dark outlines); the current panel is a dark violet card over the scene.
- Every state must exist on screen: empty (no games yet; no card fits), waiting (builders working, nothing to see
  yet; Foreman not reachable), error (the game could not be finished; a builder's question blocks; the placement
  overlaps a neighbour or the road).
- Nothing is spent before the player commits: answers and a placement are a staged proposal until "Build it".
- The player's own words are kept and shown; the engine's proposals are visibly proposals (with their reason).
- Figures are honest: a size or estimate that is a guess is shown as a guess.

## 2. Today's panel, screen by screen

Captures: `stills/today/` (1280x720, `ui.sh shot` on the seven display fixtures cut from the real marble job).

| Screen | What it does well | What fails a player |
|---|---|---|
| List (`new.png`) | One row per game, state chip, packages n/m, a bar, time. Honest states (stalled, budget, question). | Rows are named by the job, not by the game; nothing says *where* the game is or will be in the village. The list is the home screen, so the first thing a player meets is a jobs table. |
| New game (`new.png`, top) | It exists and is one click away. | **A blank text box and a "Design" button.** Nothing tells the player what the engine can build, what it will ask, or what a good sentence looks like. Every decision (players a side, rink size, periods, difficulty) is left to the Designer model to guess, and the player sees the guesses only when the brief comes back (minutes later, tokens spent). |
| Brief (`01-approve.png`) | The player's sentence in quotes; the brief's five fields; an estimate; Approve / Discard. | The five fields are prose cut at one line ("...side by...") and none can be changed except by Discard and typing the whole idea again. The estimate is shown as a fact. Size, place and look are buried in "arena" prose. The approve gate comes *after* the Designer run is paid for. |
| Build (`fx-2-question.png`) | Packages with state, round, time, tokens; a builder's question with an answer field and "let it change core". | It speaks the Foreman's language (`core_run`, `workshop_look`, rnd, tokens). What the question *means for my game* is not said; there is no picture of what is built so far in the place it will stand. |
| Change (`fx-7-change.png`) | One field; requests listed with their outcome. | A change is a blank box again; nothing ties it to the decision it would overturn. |
| Tune (`fx-6-tune.png`) | Sliders with labels and units straight from the pack's declared params; writes a copy. | Good and kept: the only screen that works on the *game* rather than on the *job*. |

Verdict: today's panel is a faithful **job monitor**. It shows the log honestly and its live path is proven (N6). It
is not an **editor**: the player cannot see or change the decisions that make the game (they live in model prose),
the recipe cards the engine already has never reach the player, and the game has no size and no place until it
appears in the village.

## 3. Patterns taken from the registry (before inventing)

- **wizard-flows** (software-engineering/ui-surfaces): one owned model behind every step, never screen-local
  answers; the progress contract (where am I, what remains, what is blocked and by what, what did I already say);
  *frontier-batched elicitation*: ask every question whose dependencies are met in one turn, **each with the answer
  the system would choose and a one-line reason**, so the player adjudicates instead of composing; "a recommendation
  is a position, never a default that applies on silence"; nothing irreversible before the commit; generated
  elicitation may propose content but never owns the flow.
- **templates-scaffolding**: a template is a contract with a parameter surface (question, options, a default that is
  a member of its options), and **an honest preview renders the mapped result**, the exact instance that confirm
  creates, not a stock picture; adoption is transactional; readiness is gated before adoption, with a named
  prerequisite and a remedy. A recipe card is this kind of template; the editor is its adoption pipeline: browse
  (which card) -> interview -> preview (request + footprint + place) -> review -> adopt (the Foreman job).
- **review-before-commit** (import-normalization): a staged proposal that nothing persists until commit; disclosure
  at the decision point (a guess is marked where it is made, not in a log); a collision is an explicit choice (a
  placement that overlaps a neighbour is shown and named, never silently shifted).
- **conversation-orchestration**: a turn that outlives the player's attention must narrate itself; next moves are
  proposed and bounded, never self-executing. (For the in-progress view: the builders' work told in the player's
  words; a builder's question arrives as a bounded choice with what each answer affects.)

## 4. The editor: information architecture

The editor is organised around **the game**, not around the job. Three places, one model per game:

```
VILLAGE BOARD (home)        top-down map of the village: every plot and site, the road, a chip per game
  |- NEW GAME = workbench   idea -> recipe -> questions -> size -> place -> review -> Build it (nothing spent before)
  '- A GAME   = game sheet  Decided | Open | Now (builders), pictures on its plot; Change, Tune
```

**One staged model per new game** (`tl.editor-draft/1`, UI-owned, section 8): the player's sentence (verbatim), the
card (or none), the answers (each `{value, by: player | sentence | proposal}`), the placement (`at`, `yaw`, lot
radius), the derived request, the derived footprint, the checks. Every view on the workbench is a projection of it;
the map, the scale strip and the request preview are recomputed from it on every change, so the preview is always the
exact thing "Build it" sends.

### 4.1 Drawing out what the player wants (the interview)

1. **Idea.** One line, first, as today ("What do you want to play?"), with example sentences under it that come from
   the cards (so the examples are what the engine really builds). The sentence is kept verbatim and stays at the top
   of the workbench for the whole flow.
2. **Recipe.** The editor matches the sentence against the cards (a word list per card's interview, plus the words of
   its title) and shows the best one as a **recipe chip**: its title, *why it matched* (the player's words that hit),
   and its worked example ("plays like the house game Ice hockey, three against three"). The other cards are one click
   away, and so is **"None of these"**. Matching is deterministic and explained: no model call before the commit.
3. **Questions, as a frontier.** The card's interview (section 8) has 4-6 questions in three groups a player knows:
   **Who plays** (players a side, opponents), **How it is won** (score, periods, clock, laps), **Where and how it
   looks** (surface, venue size, dressing). All questions are on screen at once (no paging; they barely depend on
   each other once the card is chosen). Each shows its options as chips, the **proposed** option marked and its
   one-line reason ("a newcomer's hand wins 18 of 20 against rookie: tl ladder, 16 Nov"), and nothing counts as
   answered until the player clicks a chip, or presses "Take the proposals" for the rest. An answer read out of the
   sentence ("three against three") is pre-filled as the player's own, with the words it came from.
4. **Variants** of the card ("football instead of hockey", "harder opponents") are one-click chips that set the
   answers they imply; they come from the card's `variants`, so they are the changes the engine knows are small.
5. **No recipe fits.** When nothing matches (an arena RPG) or the player picks "None of these", the workbench says so
   plainly where the recipe chip stands: *"No recipe for this kind of game yet. It can still be built from your words
   alone: expect more questions from the builders, a longer build, and a real chance it does not finish."* The
   interview falls back to the questions every game has (what you control, what is against you, how a round ends, how
   big), and the nearest worked example, if any, is named (an obstacle course: the house game Timber Run, 18 x 50 x 12
   m from its `pack.json`). This is the template system's readiness gate, told honestly.

### 4.2 Sizing and placing the construction

The footprint is **derived**: the card's worked example gives a measured base (hockey: rink 60 x 30 m, apron 3.5 m;
Timber Run 18 x 50 x 12 m from its `pack.json`), and answers scale it (big ice 80 x 40 with no stands; stands add a
band on both long sides). The lot's radius follows the world's own rule (WORLD.md S3: half-diagonal of the footprint
+ 4 m, at least 12 m), so the ring on the map is the ring the site will fence. The size is labelled **estimate**
until the game is built (the site then measures the real extent: S4).

- **The map** (right half): the village from `boot/village.json`, top-down, north up: the road, every plot as a ring
  with its game's name, the site lots. The new game is a **ghost** of its footprint (a rectangle inside its lot ring),
  dragged with the mouse and turned with the wheel or Q/E in 15 degree steps. Its **gate** turns to face the nearest
  point of the road; the path in is drawn dashed with its length.
- **Checks, named, live** (never a silent nudge): *overlaps "hockey" by 6 m*; *stands on the road*; *outside the
  village*; a warning: *a 46 m walk from the road*. The ring turns red with the reason written by it, and "Build it"
  is disabled with the same reason next to it (never a grey button without a why).
- **Scale against the walker** (a strip under the map): a side elevation at true scale: the 2 m walker, the
  footprint's long side and its height, and in words: *"60 x 30 m; 34 m across: about 8 s at a run"*. The nearest
  plot of the same kind is named for comparison ("the house hockey plot is 88 m").
- **Answers move the map**: choosing big ice grows the ghost and may turn its ring red where it stands; the map never
  moves the ghost by itself.

### 4.3 Review and commit

A bottom bar, always visible: the **request** that will be sent (the player's words, then the decided details in
one paragraph; proposals the player did not confirm are named "left to the proposal"), the lot (x, z, radius), and
the card's estimate marked as a guess. **Build it** is the only button that spends anything: it starts the Foreman
with that request through the existing door (`foreman_door.new_game`), and writes the draft beside the jobs so the
site can later take the lot. While the Foreman cannot be reached, the button says why and the draft is kept.

### 4.4 A game in progress (the game sheet)

Replaces today's sheet head and Build section; Tune stays as it is.

- **Decided**: the answers (from the draft), the approved brief's fields as one-liners that open, the plot. Each can
  become a change request by clicking it ("make it big ice"), so a change starts from a decision, not a blank box.
- **Open**: builder questions, each as a bounded choice (the builder's proposed answers as chips, plus "my own
  words"), with what the answer affects; and proposals the player never confirmed ("difficulty: rookie, by
  proposal").
- **Now**: what the builders are doing, in the player's words: one line per package from its title and the site's
  own state words (waiting, building, checking, on hold, built, failed), the current one first with its minutes;
  tokens and rounds behind a fold for the curious. Pictures appear on the plot's mini map and as a strip.
- The **village board** shows every game on its lot with the same state words the 3D site uses, so the map and the
  walk through the village tell one story.

## 5. Flows

1. **Hockey (a card fits).** Type "ice hockey, three against three, against the computer" -> recipe chip *Team
   possession* (matched: hockey, three against three, computer) -> 6 questions, 2 already answered from the sentence
   -> the player takes rookie, keeps the proposed rink, picks "one 3-minute period" -> the map shows the ghost; dropped
   first next to the house hockey plot it is red, "overlaps hockey by 9 m" -> dragged to a free spot: gate faces the
   road, 12 m path -> Build it.
2. **Obstacle course (no card, a nearest example).** "a Takeshi's castle obstacle course with jumps and a slide" ->
   no card matches; nearest example Timber Run -> generic questions (you control: a runner; against you: the clock and
   falls; a round ends at the finish or after 90 s; size: long course 18 x 50 x 12) -> ghost 18 x 50 -> placed.
3. **Arena RPG (no card, no example).** "an arena where I fight waves of goblins with a sword" -> the honest
   no-recipe notice -> generic questions; the size asked directly (small 30 m, medium 50 m, large 70 m arena, each
   shown against the walker) -> placed -> Build it, with the warning repeated in the review bar.
4. **Change after the build.** In the game sheet click the decided line "rink: standard 60 x 30" -> pick big ice ->
   the map shows the new ring; when it no longer fits, the editor says so before the change is sent.

## 6. States (every one is on screen)

| Where | Empty | Waiting | Error |
|---|---|---|---|
| Idea | "What do you want to play?" + example sentences from the cards | - | under 2 words: no recipe is chosen; the examples stay |
| Recipe | - | - | no card fits: the honest notice and the generic interview |
| Questions | none confirmed: "6 proposals, 0 confirmed" in the progress line | - | - |
| Map | village file missing: "The village map could not be read"; Build it says the lot is not chosen | - | overlap / road / outside the village: red ring + reason; Build it disabled with the reason |
| Commit | - | "Starting the builders..." with the door's own busy word | Foreman not reachable (no flags, no CLI): "The builders cannot be started: <door's reason>. Your draft is kept." |
| Game sheet | no builder started yet: the decided list and "waiting for the first builder" | Now: current package and minutes, live | stalled (no Foreman), failed ("This game could not be finished" + the reason + Resume / Change) |

## 7. The slice built tonight, and why this one

The owner's needle is "clarity of how to extract needs from the user" and "how to size and place the constructions
in the world". Both live in the **workbench**: the card-shaped interview and the placement map with the walker
scale. The game sheet (4.4) rearranges data the panel already shows correctly; the workbench is the part that does not
exist at all. So the slice is the workbench, end to end, driven by input events:

idea -> recipe match with its reasons -> questions with proposals and reasons -> live footprint -> village map with
drag, turn, named checks, gate and path -> walker scale strip -> review bar -> Build it (through the existing door;
fake adapter in the drive) -> the job appears in the panel's list.

Not in the slice: the village board as home screen, change-from-a-decision.

**Built later the same night (E2): the game sheet (4.4) for a game made in the workbench.** It opens when such a game is
selected (the draft under `<jobs>/_editor/` is found by the job's sentence): Open (approve or discard the brief, a
builder's question with an answer field, Resume for a stopped game, the door's own error), Decided (every answer
with who gave it, the lot, then the brief the Designer wrote), On its lot (the close-up map, one bay per package
coloured and named by the site's state words) and Now (the packages in the site's words, the working one first).

**One change to 4.2 made while building it:** the ghost is placed by the workbench on the first free place by the road
as soon as a recipe gives it a size, and it *follows the size* (big ice moves it if it no longer fits) **until the
player places it by hand** (drag, click or turn); from then on only the player moves it. Without this, the ghost first
placed for a transient size (while the idea was still being typed) stood on a neighbour by the time the sentence was
finished. "No recipe fits" is said only from four words on, so it does not flash while the first words are typed.
When no free place by the road fits the size at all (a 96 x 70 m track), that is the first thing the checks say.

## 8. Data the slice adds (UI-owned) and the contract proposals

- `engine/ui/interview/<card>.json` (`tl.ui-interview/1`), one per card plus `none.json`: the card id it serves, the
  match words, the questions (`key`, `group`, `ask`, `options [{id, label, say, size?}]`, `propose`, `reason`,
  `from_words` to read an answer out of the sentence), the base footprint with its source, the request template.
  Every `propose` is a member of its own options (checked by `ui.sh selftest`: the template rule from the registry).
- The draft (`tl.editor-draft/1`) written at commit under the jobs root: `_editor/<slug>.json` with the sentence,
  card, answers, placement, request.
- **Proposal for CARDS.md (Director):** move the interview into the card as an optional `interview` key, so a card
  carries its own questions and `tl cards check` checks them with the card (every `propose` among its `options`; every
  size names numbers the example shows); and an optional `footprint` (from the example's `pack.json`), so the size
  estimate comes from the card, not from the UI.
- **Proposal for JOB.md (Director):** optional `job_created.answers` (the confirmed answers, so the Designer is bound by
  them and the game sheet can show Decided from the log) and `job_created.lot` (`{at, yaw, radius}`), so the site takes
  the place the player chose. Tonight the slice puts the decisions into the sentence (which the Designer already reads)
  and keeps the lot in the draft file.
