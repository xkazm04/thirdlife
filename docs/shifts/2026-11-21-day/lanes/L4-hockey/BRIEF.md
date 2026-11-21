# L4 hockey-mechanics: thirdjam's hockey, felt in the hands

Read `docs/shifts/2026-11-21-day/COMMON.md` first: the owner's words, the laws, the Codex call, and your column
(`engine/packs/hockey/**` except L5's files). Then read the spark note `.spark/Spark/ideas/game-quality-bar.md` (main
checkout): digest C is your spec, with file:line in both games.

- **You are the Opus director.** Astra builds through Codex; you verify, re-run every gate, and play it in a window.
- **Worktree:** `C:/Users/kazda/kiro/third-life/.claude/worktrees/n21d-hockey`, branch `n21d-hockey`, base main
  `df58f0b`.
- **Time box:** until 18:30.
- **Standups:** in `lanes/L4-hockey/STANDUP.md`. When you are landable, also send the Director a message.
- **Thirdjam's code** is the reference (clone path in COMMON.md): `Game/Source/JamCore/Private/JamSim.cpp`,
  `Public/JamCartridge.h`, `docs/VISION.md`, `contracts/RULINGS.md`.
  - Last night's L5 rebuilt hockey from memory because the repo was not on disk. Today you have the real numbers: port
    them, and quote the thirdjam line for each rule.

## The owner's words
- "For hockey try to look at mechanics thirdjam has: tackle, movement balance, crosschecks, failing physics and
  animations, puck sticking to the player."
- His laws of 13 Nov (VISION.md, R-0045):
  - contact strength = closing speed times mass, against the victim's stability;
  - the attacker pays;
  - the carrier cannot hit;
  - braking by reversing the input, and a first-step burst;
  - the puck rides closer when not sprinting;
  - a defender's sprint is always faster.
- Also: "skill in movement and stick control rather than speed stats".
- 15 Nov: "puck is not controlled by player"; the cross-check must be shown by the player's animation.

## Work, in the order a player feels it (each step gated before the next)
1. **The puck on the blade.**
   - Carry it at 1.2 m from the body (×0.75 of that when not sprinting), not 3 m (`tuning.json:7`,
     `rink_api.gd:214-239`).
   - The blade follows the mouse aim within reach, with thirdjam's carry assist (puck to blade, the carrier's
     velocity).
   - A sweep faster than 6°/frame shields the puck for 12 frames.
   - Use `stick_yaw` and the `body_check` / `cross_check` clips when L2 lands (the Director merges main into your tree
     then); until then, the puck distance and the shield.
2. **Brake by reversing.**
   - Input more than 120° against the velocity is a hard stop at 26 m/s², with the `skate_stop` clip and an ice spray.
   - A first-step burst: acceleration ×1.8 for 20 frames after your own stop or a sharp cut. Bots use it too.
3. **The stability contact model** (`JamSim.cpp:2534-2762`):
   - impulse = mass × closing speed + 1.5 m/s lunge;
   - stability = mass × 6 m/s, modified by: ×1.5 when standing and seeing it (×5 against a side hit), down to ×0.85 at
     top speed, ×0.7 sprinting, ×0.8 for a spin, a charge or a blind side;
   - by the ratio: below 0.4 a bump, below 1 a stumble (via `TLHit.react`; the puck comes loose from 0.7), 1 and up
     down for 60-150 frames (via `TLHit.down` with `from_dir`);
   - the attacker pays: momentum is exchanged, and a sprinting attacker into a braced man stumbles himself;
   - boards ×1.25; the carrier cannot hit; a 120-frame grace after a get-up.
4. **The cross-check, a hit not a shove.**
   - A 3 m/s thrust. From the front it beats the standing brace. Hold it to skate in with it held (R-0064): no sprint,
     slower turns, easier to knock over.
   - An 8-frame wind-up, 12 for bots. Bots use it.
   - The `cross_check` clip when L2 lands. Never a drawn rectangle.
5. **Sprint with stamina:** +15 %, 180 frames to drain, 360 to refill; free skater ×1.15; the carrier capped so a
   defender is faster. A HUD bar.
6. **Hold-to-charge shot** (flat): up to 30 frames for +8 m/s; a tap stays flat. Keep last night's one-timer.
- Keep what is better than thirdjam: the goalies, the broadcast camera, the goal replay, the fun layer.
- Every check and hit calls `TLHit.react` / `TLHit.down` with `from_dir`, so the falls the owner picks later show up in
  hockey without a pack change.

## Acceptance
- Packs PASS, with counts at least main's (61+ verb runs); world 8/8 = alone. Hockey hashes move: say why for each.
- `hockey invariants` p50 ≤ 1.0 ms, measured quiet (or A/B against main when busy, labelled busy).
- A new bot per rule:
  - a braced man stops a sprinting attacker, who stumbles;
  - head-on at full speed downs;
  - same direction and same speed exchanges almost nothing;
  - a front cross-check downs a standing man;
  - the carrier keeps the puck within 1.3 m through a turn;
  - reverse input stops within thirdjam's distance.
  - Each must hold on 20 of 20 seeds before it enters the gate.
- `tl ladder --pack engine/packs/hockey --seeds 20` re-run, quoted with hands. The idle hand still wins nothing.
- Clips, 20 s or less each, played and judged in a window:
  - a check that lands;
  - a check that rebounds on the attacker;
  - a held cross-check;
  - brake and burst;
  - the puck on the blade through a deke.
- `engine/packs/hockey/README.md` gets a "Contact and skating (thirdjam port)" section with the rules and their numbers.
