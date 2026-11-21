# L5 hockey-crazy: boosts, abilities, crazy modes, a neon arena

Read `docs/shifts/2026-11-21-day/COMMON.md` first: the owner's words, the laws, the Codex call, and your column. You
share the hockey pack with L4: your files are listed there, and `main.gd` wiring goes to L4 through your `PATCHES.md`.
Then read the spark note `.spark/Spark/ideas/game-quality-bar.md` (main checkout): digest C, "Crazy (TJ)".

- **You are the Opus director.** Astra builds through Codex; you verify, re-run every gate, and play it in a window.
- **Worktree:** `C:/Users/kazda/kiro/third-life/.claude/worktrees/n21d-crazy`, branch `n21d-crazy`, base main `df58f0b`.
- **Time box:** until 18:30.
- **Standups:** in `lanes/L5-crazy/STANDUP.md`. When you are landable, also send the Director a message.
- **Thirdjam reference** (clone path in COMMON.md):
  - `Game/Content/Designer/builtin-effects.json`, `Game/Source/JamCore/Private/Effects/JamEffectSystem.cpp:324-361`;
  - `JamSim.cpp:4455-4590` (abilities, `StepShotgun` :4536), `JamSim.h:604-609`;
  - `JamGame/Private/NeonArena.cpp`;
  - `docs/experiments/{BOOSTS,ABILITIES,NEON}.md`;
  - `Game/Content/Cartridges/modes/` (Arsenal, Shotgun, Glow Ice and more).

## The owner's words
- "For crazy modes there are in thirdjam for inspiration neon arena, boosts like a shotgun or speed boosts."
- 12 Nov: "'raw' play with tackles without rules, random boost packages on ice (speed, shooting precision)", and "I love
  the Neon art".
- 13 Nov: special abilities on F through boosts ("a one-shot shotgun").

## Work
1. **Pickups** (`scripts/boosts.gd`, `data/boosts.json`):
   - Spawned in zones every N frames, a set number at a time, from the kernel's seeded generator only.
   - The nearest skater within 0.5 m plus his radius takes one; bots take them too.
   - Kinds: speed (speed and acceleration ×1.5 for 300 frames), precision (aim cone ×2 for 480 frames), big puck
     (radius ×1.5), heavy puck (drag ×2, top speed ×0.5).
   - On the ice: a turning shape over a light pedestal with a ground ring. The holder gets a ring of light at his waist.
     Use the TL API only (`TLSpawner`, `TLTrigger`, `TLVfx`, `TLHud`; `ex_car`'s nitro is a precedent).
2. **Abilities on F** (`scripts/abilities.gd`), with a 20 s cooldown and a HUD icon:
   - **shotgun:** the next shot leaves at ×1.5 and downs every standing skater within 1 m of its path, for up to 120
     frames of flight. It hits teammates too. Downs go through `TLHit.down` with `from_dir` along the shot.
   - **hip check:** lands from a standstill; down ×1.5 longer; pushes the victim 3 m.
   - **shield:** checks do not land on the holder for 6 s; draw a visible bubble.
   - **slow puck:** the puck flies at ×0.5 for 2 s, then wakes up.
   - Abilities come from the mode or from a pickup. Bots use them.
3. **Modes** (`data/modes/arsenal.json`, `shotgun.json`, `glow.json`; extend `scripts/modes.gd`'s schema for the new
   keys; unknown keys stay errors):
   - **Arsenal:** pickups on, all abilities from pickups.
   - **Shotgun:** everyone has the shotgun.
   - **Glow Ice:** the neon arena with the base rules.
   - Each is reachable from the start panel (via L4's `main.gd`, through PATCHES).
4. **The neon arena** (`scripts/look.gd`, `scripts/fx/**`):
   - dark ice, lines of light, emissive trim on figures, light trails behind skaters and the puck (the puck's
     brightest), an accent colour per mode;
   - `TLVfx.trail`, `TLStyleFx.glow`, and whatever the style offers.
   - If it truly needs an `engine/style` addition, ask the Director in your STANDUP first: `engine/style` is not in your
     column.
   - Judge it by eye in a window; produce, judge, tune, at least 3 rounds.

## Acceptance
- The base mode's hashes are unchanged: pickups and abilities are off in base, and drawing has no hash effect. Prove it
  with `bot_hockey` and the packs step.
- Each new mode runs to the end with a bot. One bot per ability shows its effect (the shotgun downs two skaters on its
  path; the shield blocks a check; slow puck slows; hip check pushes 3 m). Each holds on 20 of 20 seeds.
- Packs PASS and world 8/8; hockey invariants p50 ≤ 1.0 ms in the base mode (quiet, or A/B busy).
- Clips, 20 s or less, played and judged in a window:
  - a 15 s neon Glow Ice clip;
  - the shotgun;
  - an Arsenal match with pickups taken.
- The README gets a "Crazy modes" section.
