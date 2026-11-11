# N6: the designer panel in the game

You are the builder for the **player's interface** of Third Life, a single-player sandbox on Godot 4.7.2 in which an LLM
builds small games ("packs") from the player's sentence. The build machinery exists and works from the command line
(the Foreman, `foreman/`): a sentence becomes a brief, a plan of packages, verified rounds, milestones with pictures,
and a promoted pack; since tonight it also takes change requests. **No player has ever seen any of it**: there is no
text input, no menu and no button anywhere in the engine. You build the first panel: describe a game, read the brief,
approve, watch it being built, ask for a change, tune it by hand.

## Read first
1. `C:\Users\kazda\kiro\third-life\contracts\JOB.md` (the job log `tl.job/1`: events, states, files of a job
   directory; read the "Added after N3" section at the end).
2. A finished real job, your main test input (read only):
   `C:\Users\kazda\kiro\third-life\site\marble-run-three-marbles-20261110-2\` (`job.jsonl` 126 events, `state.json`,
   `captures\`, `reports\`, `promoted\`). A real hockey job is running tonight at
   `site\ice-hockey-three-against-20261111-1\`; use it too once it exists, read only.
3. `docs\reports\N3-FOREMAN.md` (the command lines: `new`, `plan`, `run`, `change`, `answer`, `follow`, `status
   --json`), `foreman\dry\n3-prompts-hockey.txt` only if you need to see what a brief looks like.
4. `engine\style\STYLE.md` and `engine\style\style.json` (the palette the panel must sit in), the last section of
   `contracts\PACK.md` (`params`: what a player may tune), `engine\look\after\wall_player_f700.png` (the look).

## The owner's taste (binding)
Dense and calm, like a macOS inspector: **two layers**. Layer one is a list of short indicative rows (a name, a state
chip, one figure, a thin progress bar). Layer two is a sheet for the selected row with the detail. No paragraph of
text on layer one, no wall of text anywhere, nothing that looks like a chat log by default. Small type (about 13 px on
a 1080p frame), tight rows (about 24 px), clear alignment, few colours taken from the style palette, ink-dark panels
that sit over the game picture without hiding it all.

## What to build
A panel scene the game can show over the world, plus a small stand-alone host to run and capture it tonight.

1. **Games list (layer one).** One row per job directory found under a jobs root: title, state chip (`designing`,
   `planning`, `running`, `paused`, `done`, `failed`), packages done of total, a thin bar, elapsed time. A first row
   "New game...".
2. **Sheet (layer two)** for the selected game, in sections that fold:
   - **Brief:** the player's sentence, the designer's brief in a few short lines, the estimate, and Approve / Discard
     while the job waits for approval.
   - **Build:** one row per package (state, round, minutes, tokens), the current activity in one line, milestones as
     small pictures from `captures/` (click to enlarge), builder notes folded away, and any question a builder asked
     with a field to answer it (and a "let it change package X" choice).
   - **Change:** one field, "What should be different?", and a send button; the list of earlier change requests with
     their outcome.
   - **Tune:** one slider per entry of the promoted pack's `params` (label, min, max, step, current value read from
     the named JSON file). Moving a slider writes the value to the pack's data file. Say honestly in the sheet when a
     change takes effect (next start of the game) unless you find a clean live path.
3. **New game:** a field "Describe a game...", then the brief appears in the sheet as soon as the Foreman has it.
4. **The Foreman behind it.** The panel never builds anything itself. It starts
   `node <repo>/foreman/dist/cli.js new|plan|run|change|answer ...` as a detached process and learns everything by
   reading the job directory (`state.json`, `job.jsonl`, `captures/`), polled about once a second, tolerant of a file
   that is being written. A dead or missing Foreman must show as such, never as a frozen bar.
5. **States to show properly:** nothing built yet (empty list); a job waiting for approval; running; paused on a
   question; paused on budget; done; failed with its cause in one line; a change request in flight; the Foreman not
   found.

## Scope
**You work in your own copy of the engine: `C:\Users\kazda\kiro\third-life\site\_work\n6\engine\`**. Yours: new
`ui/**` and new `tools/ui.sh`. Nothing else in the engine: if the kernel needs a hook (for example to stop the game
from receiving keys while a field has focus, or to show the panel inside a running pack), write the exact patch and
its reason to `ui/PATCHES.md`. `foreman/` is read only: run its command line, never edit it. Tonight's panel runs in
its own host scene, started by `bash tools/ui.sh open --jobs=<dir>` and captured by
`bash tools/ui.sh shot --jobs=<dir> --select=<job> --section=<name> --out=<abs png>` (a window at `--position 0,1440`,
`--rendering-driver d3d12`, 1920x1080, like `tools/tl.sh capture` does it; read how `kernel/host/host.gd` spawns a
windowed worker). Put a seed frame behind the panel in captures so its weight over a game picture can be judged.

**No model calls.** For the live path use the Foreman's fake adapter (`--adapter fake`; see how its tests start a
fixture job in `foreman/src/test/`) with `TL_ENGINE_DIR=C:/Users/kazda/kiro/third-life/site/_engine_snapshot4` and
`TL_GODOT=C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe`, writing its jobs under a
scratch jobs root of your own (never into `site/` beside the real jobs).

## Acceptance (the Director will run these in your copy and look at the pictures)
- `bash tools/ui.sh selftest`: headless checks that the model behind the panel reads the marble job correctly
  (3 packages, the milestones, 6 notes, 1 question and its answer, the final state, the token and time totals), reads
  a half-written `job.jsonl` without failing, and reports a missing Foreman.
- Captures, each looked at by you, under `ui/captures/`: empty list; the marble job selected with Brief, Build, Change
  and Tune open in turn; a job waiting for approval; a job paused on a question; a failed job; a live fake-adapter job
  at three moments (just approved, mid-build, done). A sheet `ui/captures/sheet.png` with all of them.
- The live path end to end with the fake adapter, driven by the panel's own code (not by you typing): describe,
  approve, progress to done, send a change request, see the second promotion. State which steps were driven through
  real UI events and which through direct calls.
- A Tune slider changes the value in a copy of a pack's data file and the file stays valid JSON.
- Text stays inside its boxes at 1920x1080 and at 1280x720; nothing overlaps; the list is readable at arm's length.

## How to work
Small steps, each followed by a capture you look at; journal in `ui/JOURNAL.md`. Kill every process you start
(including `node` and Godot children); never kill others: other sessions and a real job run Godot and `claude`
processes on this machine tonight. No git. No network. Never read, use or print any `ANTHROPIC_KEY_*` variable.
Where the brief's premise is wrong, say so with the evidence and propose the alternative.

## Final message (your report, as text)
Status; what the panel does, section by section, with the capture that shows each (full paths); the selftest count;
the live-path proof and which steps went through real UI events; the contents of `PATCHES.md`; what a player still
cannot do; what you did not verify (no person has clicked it); questions; minutes spent from real timestamps (`date`).

## Time-box
Until the list is done or **90 minutes after your start** (run `date` first and often). The list, the sheet's Build
section on the real marble job, and the live fake path are worth more than every state half-drawn. Leave the last ten
minutes for the selftest, the sheet of captures and the report. A usage limit can cut you off without warning: keep
the journal current.
