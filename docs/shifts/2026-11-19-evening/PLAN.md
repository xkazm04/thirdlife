# Evening shift of 19 Nov 2026: plan

The owner, 19:00, on the day verdict: "0. Astra usage over plan is not an issue, we have enough tokens and if quality
needs it we can spend it 1. Flight: looks great, I would remove the wings by default and rather use key binding and
'magical' animation to summon the wings or dismiss 2. Parkour looks great, ability to customize HUD in world creator and
improve UI from user perspective would be next step. LLM itself should try to escape mediocre styling from try one 3.
Blending is looking now much better. I would accept it for now 4. For Editor I will have more opinions after more tests,
delayed for now....for points 1,2 you can proceed now before the night, where we establish again new set of scope based
on my directions"

- **Start:** 19:20. **Land-by:** 23:30 (land and push). **Standups:** hourly at :47. **Verdict:** 23:00, short, with clips.
- The night's scope is handshaken again with the owner; these two lanes do not run into the night unasked.
- Spend: the owner lifted the token limit; quality first.

| Lane | Route | Claims (write scope) | Selftest blocks |
|---|---|---|---|
| wings | Astra alone designs and builds the summon/dismiss look (look judged by eye); Opus operator verifies | `engine/kernel/world/flight_wings.gd`, `engine/kernel/world/visitor.gd`, `engine/kernel/api/tl_biped.gd`, `engine/kernel/api/tl_vfx.gd`, `engine/kernel/api/tl_vfx_node.gd`, `engine/style/tl_style_fx.gd`, `engine/style/shaders/**`, `assets/**` | 540-549 |
| hud | Astra alone designs and builds the HUD and its editor (look judged by eye); Opus operator verifies | `engine/kernel/api/tl_hud.gd`, `engine/kernel/API.md`, `engine/style/STYLE.md`, `engine/style/style.json`, `engine/style/hud/**`, `engine/ui/**`, `engine/packs/parkour/**` | 550-559 |

## Launch record (19:15)
Worktrees `e19-wings` and `e19-hud` were cut from `2950f03`, each with foreman deps, the site jobs and the class cache.
Scopes are claimed in `.claude/sessions.json` (`tl arch` scope-claims PASS).

| Lane | Agent | Started |
|---|---|---|
| wings | Opus operator, Astra builds | 19:15 |
| hud | Opus operator, Astra builds | 19:15 |

Timers: standups at 20:47, 21:47 and 22:47 (the scheduler shifts them a little), and the verdict at 23:07.
