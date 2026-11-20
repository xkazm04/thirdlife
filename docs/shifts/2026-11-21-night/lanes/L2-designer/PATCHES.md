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
