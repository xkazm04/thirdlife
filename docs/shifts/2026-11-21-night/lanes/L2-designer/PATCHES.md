# L2 designer-foreman: what other lanes' files need from this lane

L2 owns `foreman/**`, `engine/cards/**` and the `fun` part of `devx/lib/cards/check.mjs`. Nothing here edits another
lane's file; these are the facts the Director (or L3) needs at landing.

## For L3 (engine/ui/job_model.gd, engine/kernel/world/site/event_schema.gd): the reader schema

The generated vocabulary is `foreman/data/job-events.schema.json` (regenerated from `foreman/src/events.ts`). It
follows JOB.md "Added 2026-11-20" with three narrowings where the contract text says nothing; a strict Godot mirror
should accept exactly these:
- `aspect_reacted.aspect` and `.choice`, `phase_done.phase`, `phase_reviewed.phase`: `^[a-z][a-z0-9_]*$`.
- An aspect's alternative `id` and a phase `id`: `^[a-z][a-z0-9_]*$` (the contract says snake_case only for the
  aspect id). An alternative id is never `keep` or `drop`.
- `aspect_reacted.note` and `phase_reviewed.note`: a non-empty string when present.
Everything else is the contract word for word (`creativity` only `"crazy"`, `run_through` only `true`, `crazy` only
`true`, word limits counted as runs of non-space characters).

## For L3 (engine/ui/foreman_door.gd): the commands

- `foreman new "<sentence>" [--creativity crazy|standard] [--run-through] ...`: `standard` writes no key.
- `foreman react <job> <aspect> keep|drop|<alternative id> [--note "..."]`: refused (exit 2, one line on stderr,
  nothing written) for an unknown aspect or choice, or after approval.
- `foreman redesign <job> [--adapter A] [--model M]`: one Designer call; a new `brief_set` (reactions lapse). A failed
  redesign writes no brief_set and exits 1: the earlier brief stands.
- `foreman approve <job>`: unchanged; approves the latest brief with the reactions on it.
- `foreman phase <job> pass|hold [--note "..."]`: writes `phase_reviewed` (by player) on the phase that waits, then
  runs the job exactly as `resume` (same run flags as `resume`), so the door can treat it like `change`. With
  `--no-run` it only records the verdict (then `resume`). Exit 3 when the job stops at the next phase, 0 when it ends
  done. Refused while a Foreman holds the job's lock (a verdict is given while the job waits).
- `foreman resume` on a job that waits for a verdict writes nothing and exits 3.
- A job waiting for a verdict reads `job_state {state: "paused", reason: "phase"}`; `foreman status` prints
  `waiting  phase <id> is done: try it ("<try>"), then: foreman phase <job> pass   or   ... hold --note "..."`.
- `foreman init-fixture <dir> --phases` copies a crazy three-phase fixture job (fake adapter, fake runner) for UI work.

## For the Director: contract questions (not edited; see REPORT.txt)

1. The three narrowings above: write them into JOB.md, or loosen the reader?
2. Proposed: a job-level `builder_run` may carry `role` (designer, planner, critic, placer); the redesign calls are
   indistinguishable from the first design in the log otherwise (the transcript file name says the role).

## L2b (23:35 re-dispatch): milestone captures film the newest package's own bot. Contract wording for the Director

Replace, in `contracts/JOB.md` "Amendments of 2026-11-10, second round", the bullet **Capture frames**:

> - **Capture frames.** 25 % and 75 % of the frame at which the first bot finished in its last passing report; 120
>   and 480 when there is none.

with:

> - **Capture frames.** A milestone films at most two bots. First the manifest's first test, at 25 % and 75 % of the
>   frame at which it finished in its last passing report (the same shot every milestone, which the no-visible-change
>   rule compares). Then the milestone's packages, newest merge first: the first one with an own acceptance bot (a
>   test its acceptance runs and its `registers.tests` lists, not the first test) is filmed at 25 % and 95 % of the
>   frame at which THAT bot finished. 120 and 480 for a bot without such a report. The first bot's captures keep the
>   name `captures/<milestone>-<cam>-f<frame>.png`; the second bot's are `captures/<milestone>-<cam>-<bot stem>-f<frame>.png`.
>   No visible change compares the first bot's captures only. The critic is told, per capture, the camera, the frame
>   and which bot of which package was playing; `reports/critic-<milestone>-s<seq>.json` carries `shots[]`
>   (`{capture, label}`).
> - `foreman critique <job> <milestone> --out DIR` (added 2026-11-21): the milestone's captures and one critic call
>   again on `pack/` as it is, writing only into DIR (captures, runner reports, `critique.json` with `dry: true`);
>   nothing is written to the job.

Why 95 % and not 75 % for the package's own bot: the crazy job's `tests/bot_flood.gd` finishes at frame 2582 and the
flood starts at 2402 (its own report). 75 % is 1937, still before the flood; 95 % is 2453, inside it (the Director's
stills at f2460/f2560 show it). A late twist's bot ends shortly after the twist, so the last tenth of its run is where
the twist is. Why the first test stays: dropping it would change every milestone's frames and blind the art-pass
no-visible-change check, which compares like with like.
