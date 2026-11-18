# Night shift of 19 Nov 2026: plan

Agreed with the owner on 18 Nov at 20:40 (the `/shift` handshake). Director: Claude Opus 5.5, in the main checkout.

- **Start:** 00:03 (a one-shot timer). Lanes are cut from main AFTER the `bugfix-37` lane has landed (the 37 defects of
  the astra-trial bug hunt; it started at 20:20, outside this shift).
- **Land-by:** 08:00. Each lane lands when it passes its own gates plus the overlay's pre-merge list. The exe is
  exported and main is pushed by 08:00.
- **Standups:** hourly at :47, from 00:47 to 06:47. The verdict runs at 07:12.
- **Morning:** a verdict page with a card per lane and a short clip for each visual lane (owner's pick: "Page + short
  videos"), plus the exe.

## Lanes (3 at once; hunt2 queued)

| Lane | Route | Worktree / branch | Claims | Time box |
|---|---|---|---|---|
| parkour | Astra alone for the look; an Opus agent launches it and verifies | `n19-parkour` | `engine/packs/parkour/**`, `engine/kits/**` | 00:03-06:30 |
| walker | Opus directing Astra | `n19-walker` | `engine/kernel/world/**`, `engine/kernel/runner/**`, `engine/style/**`, `engine/rigs/**` | 00:03-06:30 |
| editor | Opus designs and builds; Astra alone draws the mockups | `n19-editor` | `engine/ui/**`, `engine/tools/ui.sh` | 00:03-07:00 |
| hunt2 | Opus directing Astra | `n19-hunt2` | assigned at launch: what the live lanes do not claim | after the first landing, until 07:00 |

Briefs: `lanes/<lane>/BRIEF.md` (each ends with `.claude/skills/shift/lane-rules.md` verbatim).

## Capacity
- At 20:40 the machine had 42.8 GB free of 63.1 GB and 384 GB of disk. Three lanes, each with at most one Godot-heavy gate
  at a time, keep it in the 60-80 % band.
- Codex 0.170.0 reaches gpt-6.2-astra. Estimated spend: walker 600-900 k, hunt2 600-900 k, parkour about 300-500 k,
  editor mockups about 100 k. About 2 M Astra tokens in all.
- Not offered: hockey, win measurement and the construction process (deferred by the owner).

## Landing order
The first lane that is done lands first. hunt2 is cut from that merge. Kernel/style lanes (walker) run the full
pre-merge list on the merged tree; the parkour and editor lanes run `packs,world` and `ui.sh selftest` plus the fast tier.
At 07:12 the verdict: final full gate, `tl arch --index`, export the exe, push, publish the page.

## Launch record (00:03-00:10)
- Preflight: bugfix-37 on main (`c8b88fc`, 0 behind origin); disk 323 GB free; RAM 38.0 GB free of 63.1; standby off;
  4 Godot processes running that the Director did not start (left alone).
- Worktrees cut from `c8b88fc`, each with `npm ci` in foreman/, plain copies of the two marble-run site jobs and the class
  cache imported. Scopes claimed in `.claude/sessions.json` (`tl arch` scope-claims PASS).

| Lane | Worktree | Agent (SendMessage id) | Started |
|---|---|---|---|
| parkour | `.claude/worktrees/n19-parkour` | a81bbee6e7f18ff8d (Opus operator, Astra builds) | 00:08 |
| walker | `.claude/worktrees/n19-walker` | a49944906952f0dab (Opus director of Astra) | 00:08 |
| editor | `.claude/worktrees/n19-editor` | a2525ec4bc5815931 (Opus designs and builds; Astra mockups) | 00:08 |
| hunt2 | (cut after the first landing) | - | - |
