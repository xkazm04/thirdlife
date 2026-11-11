# N7: one world you can walk through

You are the builder who **joins tonight's pieces into one world**. Third Life is a single-player sandbox on Godot 4.7.2
(Jolt, 60 Hz) in which an LLM builds small games ("packs"). Tonight four things were built apart and verified:
many packs alive in one process, each in its own physics space (N2); a scheduler that gives each pack ticks by tier:
`stage`, `sideline`, `backdrop`, `ledger` (N5a); a drawing layer that shows every pack at its plot although each is
simulated at its own origin (N5b); and a new look (N1). The scheduler has only ever run headless; the drawing has only
ever run with every pack ticked on every frame; nobody has walked from one game to another. You make that one thing.

The owner's rulings: every game in the world stays alive; a far game runs in slow motion (fewer ticks, unchanged step)
and is never switched off; the look should reach the level of the concept image, with no generative model.

## Read first
1. `docs\reports\N5A-TIERS.md` and `docs\reports\N5B-DRAW.md` (each ends with the Director's verification and
   decisions), then in the engine: `kernel\world\TIERS.md`, `kernel\world\draw\DRAW.md`,
   `kernel\world\draw\PATCHES.md`, `kernel\world\PATCHES-N5A.md` (entry 6 is the scheduler builder's note to you),
   `kernel\API.md` sections 19 and 20.
2. `kernel\world\world.gd`, `pack.gd`, `tiers.gd`, `tiers.json`, `draw\draw.gd`, `draw\view.gd`, `tools\world.sh`,
   `tools\view.sh`.
3. The concept: `spike\lab\ref\B_toon_ink.png`. And what a world looks like today from above:
   `docs\reports\img\world_overview.jpg`, `docs\reports\img\world_12_packs.jpg` (round plots on a flat hazy plain).

## Where you work
**In the main tree, `C:\Users\kazda\kiro\third-life\engine\`.** `TL_GODOT=C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe`.
Yours: `kernel/world/**`, `kernel/host/host.gd`, `kernel/runner/verbs.json`, `kernel/api/tl_hud.gd`,
`kernel/api/tl_context.gd`, `kits/**` and `style/**` only for what the world's own landscape needs, `tools/world.sh`,
`tools/view.sh`, `tools/selftest.sh`, `kernel/API.md` (sections 19, 20 and a new 21), `JOURNAL.md`.
Not yours: `seeds/**`, `kernel/share/**`, `kernel/runner/lint.gd`, `kernel/runner/manifest.gd`, the camera files,
`foreman/`, `contracts/`, `docs/`, `site/`. Another builder is finishing a UI panel in a copy and does not touch the
main tree. **A real job is being verified on this machine tonight**: keep heavy runs short, never run two engine
processes at once, and never leave a window behind (the drawing builder's orphan window at 0,1440 slowed every later
window for 43 minutes: check for your own stray processes after every failed run).

## The work, in this order
1. **One host.** Apply the drawing builder's patches 1 to 4 (a pack knows at load whether it is on stage; a non-stage
   pack's HUD is hidden when made; a world that outlives its bots; a `world-view` mode through `host.gd` and
   `verbs.json`, so the viewer starts like every other mode). A windowed world then runs the scheduler: the tier of
   each plot decides both its ticks and its drawing. `stage`: zero offset, its cameras, its HUD. `sideline`: drawn in
   full at its plot. `backdrop`: its stand-in mesh, ticked on its slice. `ledger`: its stand-in, no pack in memory.
   A tier change re-bases or swaps drawing at a tick boundary. For worlds, `scenery = "plot"` is the default (a pack
   brings no far terrain and no forest of its own; decision of the Director), and a pack's plot comes from its
   `footprint` in `pack.json` when it has one.
2. **The visitor.** The player as a walker between games: a kernel-owned biped from the rigs on the world's ground with
   a chase camera, moved by WASD in a window and by the walk script's positions in a scripted run. While the visitor
   walks, no pack is on stage and every near pack is `sideline`. Stepping into a plot and pressing E (an `enter` event
   in a walk script) puts that pack on stage: its own camera, HUD and input take over, played by its bot in scripted
   runs. Esc or Q (a `leave` event) returns the visitor to the plot's edge and the pack does what its `on_leave` says.
   A game that ended by itself and is not on stage starts its next round after a pause set in `tiers.json`.
3. **The proof.** A scripted tour, `bash tools/world.sh tour <walk> --out-dir=<abs dir>`: six games on plots, the
   visitor walks past two, enters one, leaves, walks on, enters another. It writes numbered pictures at the moments
   the walk names and one line per pack with its hash. Every pack's hash must equal the same pack run alone for the
   same number of its own ticks with the same inputs, with drawing on, and the world log must replay to the same
   hashes. Add it as a selftest case in its headless form.
4. **A landscape, not islands.** Today's overview is round discs on a flat plain, 100 m and more apart. Move it toward
   the concept, in this order, looking at a capture after each step: plots as close as their footprints allow, on a
   world the size of a village and not a county; a dirt road from plot to plot (the kit has road and ground parts);
   trees, rocks and bushes scattered by the world between plots, never inside one (the kit's nature parts; watch the
   cost: N5a measured that a seed's own forest was most of its loading time); far mesas and the painted sky drawn
   once; the haze toned so that a venue 200 m away still reads. The ground may stay flat. Each plot's edge should read
   as a place (a fence line, a kerb, a change of ground) and not as a disc.
5. **The pictures for the owner**, under `kernel/world/captures/` (with a `.gdignore`): the tour's frames; one
   overview with six games that you would put beside the concept; `world_vs_concept.png` with the two side by side;
   one frame that shows a far game and a near game in the same view.

## Acceptance (the Director will run these and look at the pictures)
- `bash tools/tl.sh selftest`, `bash tools/tl.sh seeds`, `bash tools/k.sh selftest`, `bash tools/item.sh selftest`
  pass; seed hashes unchanged; `bash tools/view.sh check ...` still passes.
- `world.sh tour` on your six-game walk: the hash table (in the tour = alone = replay) for every pack, the tier log,
  and the pictures. No engine error, no gate leak, no pack script run on a tick its pack did not get.
- From the visitor's camera near one game, another game is visible at its plot, drawn right, and the far ones are
  stand-ins; entering switches to the game's own camera and HUD; leaving switches back.
- `kernel/world/WORLD.md`: how the pieces fit (one page), the walk and tour format, what a pack author must know,
  what is not built.

## How to work
Small steps, each followed by a capture you look at; journal in `JOURNAL.md` under "N7". Kill every process you
start; never kill others. **No git command of any kind**, not even a read-only one and not from a test: another
session shares this repository. No network. No interactive window: pictures come from the tools. Never read, use or
print any `ANTHROPIC_KEY_*` variable. Timing figures taken tonight are under load: say so. Where a premise of this
brief is wrong, say so with the evidence and propose the alternative; your measurement outranks the brief.

## Final message (your report, as text)
Status; per item what was built and the capture or command that proves it (full paths); the hash table; what the
world costs per tick in the tour; what is still wrong in the picture against the concept; what a pack author must
know; the list of files changed; what you did not verify (no person has walked it); questions; minutes spent from
real timestamps (`date`).

## Time-box
Until the list is done or **100 minutes after your start** (run `date` first and often). Items 1 to 3 proven are
worth more than a pretty overview on a host that does not hold together; then item 4 with pictures you looked at.
Leave the last ten minutes for the gates and the report. A usage limit can cut you off without warning: keep the
journal current.
