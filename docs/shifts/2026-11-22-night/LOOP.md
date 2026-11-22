# Night of 22 Nov, extension to 09:00: the quality loop

**The owner, 00:55 (verbatim):** "continue nightly shift until 9:00 looping the same goal to reach points both duel and
hockey are high quality standalone games to set example and engine needs for all future games coming form editor"

**What it means:**
- `engine/packs/duel` and `engine/packs/hockey` become the reference games.
- Each one should be good enough to stand alone: a person would play it twice, by the owner's hand and eye.
- What they needed from the engine becomes kernel API that every future editor game gets.
- What makes them good becomes the template the editor copies.

## Times
| What | Time |
|---|---|
| Standups | hourly at :17 |
| Each lane sends "landable round k" | about every 60-75 min |
| Lanes stop | 07:45 |
| Verdict | 08:15 |
| Push | by 09:00 |

## Lanes in the loop
| Lane | Tree | Route | Scope (claim) | The loop's job |
|---|---|---|---|---|
| N2 duel | `n22-duel` | Opus | `engine/packs/duel/**`, `engine/cards/duel.json` | the duel to Souls / For Honor quality |
| N3 hockey | `n22-hockey` | Opus-directed Astra | `engine/packs/hockey/**` | hockey playable and fun (puck, speed, AI decisions) |
| N1 engine-needs | `n22-kit` | Opus-directed Astra | N1's claim (TLHit, TLBiped, TLBall, feel, cameras, rigs/biped) | turns the games' needs into kernel API |
| N4 editor-example | `n22-editor` | Opus | `foreman/**`, `docs/GAME-QUALITY.md`, `devx/lib/cards/**` | the editor copies the two house games |

## One round (every game lane, about 60-75 min)
1. **Pick the biggest gap.** Name the ONE gap that most stops a person from playing twice. Read it against:
   - the reference (DUEL-PLAYBOOK, or HOCKEY-ARCADE and thirdjam);
   - the plays-twice checklist in `docs/GAME-QUALITY.md`.

   Write it first, in your STANDUP line: "round k: gap = ..., reference does ...".
2. **Build it** inside your scope.
3. **Evidence, as a person meets it:**
   - a window clip of 20 s or less through the regular or newcomer hand, on the play camera;
   - a before/after contact sheet;
   - the bot metrics that move.

   A perfect-hand win is never the evidence. Judge the clip against what the reference game does, in one honest
   paragraph.
4. **Engine needs:** something the game needed that the kernel lacks goes into the ENGINE-NEEDS list (below):
   - one row: the need, the exact API you propose, who needs it, and the local shim you use until it lands;
   - never edit kernel files from a game lane;
   - N1 picks rows up and lands them as kernel API; the Director merges main into your tree and tells you, and you
     drop your shim.
5. **Gates:** lint, smoke and your selftest block; the game's bots and ladder spot-check; fast tier.
6. **Hand it over:**
   - append a STANDUP line;
   - SendMessage the Director "landable round k" with the gate counts and the clip path.

   The Director lands each round (the fast tier on the merged tree, then the packs units in `n22-int`). Keep working on
   round k+1 meanwhile, but only on files the round did not hand over, or wait for "landed".

## ENGINE-NEEDS
`docs/shifts/2026-11-22-night/ENGINE-NEEDS.md`. Game lanes append rows to their own copy at
`lanes/<lane>/ENGINE-NEEDS.md`; the Director collects them into the shift file.

Already known:
- **N2:** the duel stretches the rig's fight clips by writing `rig.clip_t` every frame. It needs a kernel clip speed
  (the shape is N1's call, e.g. `TLBiped.set_clip_speed(who, s)`).
- **N2:** swings with weight: anticipation, follow-through and a heavier arc read for heavy against light.

## Rules (in addition to COMMON.md and the lane rules)
- **Paths:** absolute paths only; never `cd` in a backgrounded line.
- **Git:** read-only. The Director commits.
- **Wall-clock checks:** p50 budgets on a busy machine are not evidence; say "busy" and A/B against main.
- **Captures:** a window capture takes the shared window lock. Keep each one short, and queue rather than retry.
- **Honesty:** "nobody has played it by hand" stays true until the owner does. Never call it fun; show it.
