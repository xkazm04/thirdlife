# Night of 21 Nov 2026: plan (designer for fun, dungeons, crisp cel hardening)

**Planned:** with the owner, 19:40-20:05 on 20 Nov, through the spark `designer-and-two-worlds`. There were three waves of
questions and a go-gate; the decisions and rejected options are in `.spark/Spark/ideas/designer-and-two-worlds.md`.
The common brief is `COMMON.md`, and each lane has `lanes/<lane>/BRIEF.md`.

**Base:** main `3a4580b`, which is:
- `516f637`: crisp cel merged (d20-cel `8df936a`; crisp is the default look);
- `5144deb`: the asset manifest re-scanned. The merge had moved kit part hashes, and the fast gate was red until then;
- `3a4580b`: the contract wire text (JOB.md designer v2, CARDS.md `fun`).

The fast gate was green on `5144deb`.

| Lane | Worktree / branch | Route | Selftest block | Agent | Started |
|---|---|---|---|---|---|
| L1 crisp-harden | `n21-harden` | Opus | 620-629 | (at launch) | |
| L2 designer-foreman | `n21-designer` | Opus | n/a | | |
| L3 create-screen | `n21-create` | Opus | 630-639 | | |
| L4 dungeons-menu | `n21-dungeon` | Opus | 640-649 | | |
| L5 hockey-fun | `n21-hockey` | Opus | 650-659 | | |

**Director's own work:**
- The two proof jobs once L2 lands (target 02:30-03:00). The sentence is "a fight in a colosseum", run once standard and
  once crazy, both with `--run-through`, on the merged tree. Both get stills/clips of each phase for the verdict.
- `docs/TWO-WORLDS.md` must decide four things for the main world: chunked streaming terrain, build layers, AI residents,
  and friends visiting. It also gives the dungeon principle as L4 built it.

**Landing order:** L2 first (the proof jobs need it), then L4 (the menu), L3 (it mounts in the menu), L5 and L1. Run the
whole pre-merge list on the first merged tree. Run `world,packs` under crisp and classic on every integration (the 20 Nov
per-style lesson).

**Times:**
- Standups hourly at :17.
- Lanes stop at 06:30 at a clean point.
- Verdict at 07:15, with the full gate on a quiet machine first.
- Push by 08:00.

**Risks:**
- Five Godot-heavy lanes on 31 GB free RAM: hold a lane when free RAM falls under 10 GB.
- Perf figures are labelled busy.
- Hockey hashes move (L5).
- The exe default becomes a menu (L4), so the tour and export scripts must keep their flags.
- Two real jobs mean real spend (about 2x one job).
