# Night of 22-23 Nov 2026: plan (research before any more game building)

**The owner, ~18:35, after playing the day's exe (verbatim):** "Editor cannot start new idea to build, World itslef is very
nice with downsides in blinking objects below/above the ground, and blinking objects aggressively with distance levels.
In far there are seen incomplete structures, on closer distance green ground. Hockey is unplayable garbage, analyze in
deep thirdjam - it is a mediocre hockey game we delivered but at least it has set basic gameplay mechanics, AI, bugless
graphics and balanced speed (https://github.com/xkazm04/thirdjam). Our hockey is a proof we should not start any new
minigame development as there is a lack of understanding how games should be done - we need research to change mindset
of what we are doing. The fact players can skate and shoot puck does not mean we delivered entertaining hockey
experience, the fact players can punch in arena and take damage does not mean we delivered fun fighting game. Both are
slop nobody would touch for fun and we should prepare processes and prompts to go much deeper in game design"

**Handshake (~19:05):** all four lanes; start now, land by 08:00; everything lands (research, method and prompts).

**Standing rule from tonight:** no new minigame and no game-feature rounds on duel or hockey. Lanes research, write
method and prompts, or fix engine bugs.

## Times
| What | Time |
|---|---|
| Launch | 19:15 |
| Standups | hourly at :17 |
| Lanes stop | 06:45 |
| Verdict | 07:15 |
| Push | by 08:00 |

## Lanes
| Lane | Tree / branch | Route | Claim (write set) | Selftest block | Outcome |
|---|---|---|---|---|---|
| N1 teardown | `n23-teardown` | Opus solo (research) | `docs/research/hockey-teardown/**`, its lane folder | none | a deep, evidenced gap report thirdjam vs our hockey: why theirs plays and ours doesn't |
| N2 method | `n23-method` | Opus solo (research + writing + foreman prompts) | `docs/design/**`, `docs/GAME-QUALITY.md`, `foreman/**`, `engine/cards/**`, `devx/lib/cards/**` | none (foreman tests) | a game-design method doc and the editor's prompts rewritten to it, with tests |
| N3 world | `n23-world` | Opus-directed Astra | `engine/kernel/world/**` except `pack.gd`, `world.gd`; `engine/style/**` if the cause is there | 770-779 | the ground and distance-level blinking and the far incomplete structures fixed, judged in a window |
| N4 create | `n23-create` | Opus solo | `engine/ui/**`, `engine/boot/menu.gd`, `engine/boot/hub.gd` | 780-789 | Create starts a new idea in the exe again, proven in the exported exe |

Cross-lane rules: N2 reads N1's interim findings (its lane folder) from about 01:00 and cites them. N4 needs a foreman
change? It asks the Director first (N2 owns foreman/). N3 needs `world.gd` or `pack.gd`? It asks first.

## Landing
- "landable round k" by SendMessage; no edits until "landed". Fast tier on the merged tree first; integration lists in
  `n23-int` at the merged SHA. Docs-only rounds land on the fast tier.
- Verdict 07:15: full gate, uncapped kernel suite, quiet perf, export + check at the final SHA, then push.

## Budget
Astra: N3 about 0.6-0.9 M. Claude: 4 lane agents. No Foreman build jobs tonight (no minigames).

## Agents
| Lane | Agent id | Started |
|---|---|---|
| N1 | a0ba28c8ec1ab924b | 19:12 |
| N2 | ab656217582049afd | 19:12 |
| N3 | a44c0e6e153767f2f | 19:12 |
| N4 | a32fb60e35771bb31 | 19:12 |
