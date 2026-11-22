# Day of 22 Nov 2026: plan

**The owner, ~10:40 (verbatim):** "run next shift now with all three steps as daily shift, I will play the game after before
major directions for night shift"

The three steps are STATE.md `## Now` "Next 3", set by the owner's verdicts on the night of 22 Nov (STATE `## Decisions`,
~10:30). No handshake questions: the scope, the mode (a day shift, now) and the follow-up (the owner plays, then sets the
night's direction) came in the request. The Director chose the routes and times below by the skill's defaults.

## Times
| What | Time |
|---|---|
| Launch | 12:45 |
| Standups | hourly at :17 |
| Lanes stop | 17:15 |
| Verdict | 17:30 |
| Land and push | by 18:30 (the owner plays after) |

## Lanes
| Lane | Tree / branch | Route | Claim (write set) | Selftest block | Outcome |
|---|---|---|---|---|---|
| D1 home | `d22-home` | Opus solo | `engine/kernel/world/home/**`, `engine/kernel/world/landscape.gd`, `engine/kernel/world/land/**`, `engine/boot/**`, `engine/tools/selftest.d/75*` | 750-759 | the Home arm A on main: chosen at boot, far plain removed, walkable (colliders through land/), world 8/8 |
| D2 e6 | `d22-e6` | Opus-directed Astra | `engine/kernel/world/pack.gd`, `engine/kernel/world/world.gd`, `engine/kernel/runner/**`, `engine/packs/hockey/**`, `engine/tools/selftest.d/76*` | 760-769 | E6 fixed (world = alone through static multi-contact) + a body-order selftest; then hockey r2a "pass out of pressure" |
| D3 editor | `d22-editor` | Opus solo | `foreman/**`, `docs/GAME-QUALITY.md`, `devx/lib/cards/**`, `.tl/proof/**` | none (foreman tests) | the critic cross-checks bot claims against the film; one hockey job built through the editor to its tofu look |

Write-set note: D1 and D2 both live under `engine/kernel/world/`; D1 does not touch `pack.gd` or `world.gd` (it asks the
Director if the boot hook needs them), D2 does not touch `home/`, `landscape.gd` or `land/`.

## Landing
- Each lane sends "landable round k" (SendMessage) and makes no edits until "landed".
- Director: fast tier on the merged tree first, then the pre-merge list in a dedicated integration worktree `d22-int`
  at the merged SHA (never under a running gate in main). The WHOLE list on the first merge.
- D2's E6 fix moves either every lone hash (option a) or none (option b): an A/B of all pack verb hashes against main is
  part of its evidence, and its ordering selftest must fail on main and pass on the fix.
- Verdict 17:30: full gate, uncapped kernel selftest and perf alone on the quiet machine, export + check, push.

## Budget
Astra: D2 about 0.6-0.9 M tokens. Claude: 3 lane agents; D3's hockey job is one Foreman job (Opus builders).

## Agents
| Lane | Agent id | Started |
|---|---|---|
| D1 | a27f28d4ec3c87a8a | 12:41 |
| D2 | a68b75b0ce6989e41 | 12:41 |
| D3 | acca845ac2cb413f6 | 12:41 |
