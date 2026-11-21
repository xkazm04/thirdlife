# N2 duel-reference: report (night of 22 Nov 2026, branch n22-duel)

Saved by the Director from the lane's final message (00:53). The earlier draft, REPORT.txt, was written before the
kernel switch and is superseded.

## What it is
`engine/packs/duel` (game.duel 0.1.0), a hand-built duel house game.
- **Format:** one fighter against a ladder of three rivals (the Wall, the Duelist, the Dancer), then the Duelist at the
  champion tier. Matches are best of 3 rounds of up to 70 s, in a walled ring whose wall splats.
- **Rules:** from `docs/research/DUEL-PLAYBOOK.md` §6; every contact changes BOTH fighters.
- **Recipe card:** `engine/cards/duel.json`.
- **Play:** `node devx/bin/tl.mjs play duel`. V cycles the camera, R restarts, ENTER after a win takes the next rival.

## Since 22:07: on N1's feel kit (kernel API 1.13)
- **Contacts:** `feel.gd` calls TLHit.impact / hit / blocked / parried / clash / guard_break / wall_splat with the
  duel's tune. The kernel plays the reaction clips.
- **Bodies:** `stop_left` holds the duel's counters during hit-stop. While `busy_left` > 0 the fighter writes no
  velocity or facing.
- **Pushbox and camera:** the pushbox is 0.45 x scale; `fade_occluders` covers both duellists; `clear` runs at round
  restart.
- **Walls:** the kernel's wall test decides the bash splat and the knocked-into-wall splat. The attacker gets the same
  8-frame stop, so both freeze.
- **Fixes found by the contact drills:**
  - A guard held on from a stun is no longer a parry.
  - The blocked heavy pushes 0.35 / 0.2 m (the playbook has 0.5 / 0.3), and the light steps in 0.5 m. With the
    kernel's pushes the fighters ended 2.46 m apart, and the "guaranteed" light fell short.
- **Look:** weapon swing trails, with a red arc on the unblockable charged heavy.
- **Evidence:** clips re-recorded, the ladder re-run and the hand checks re-measured, all on the kernel.

## Gates
| Run | Result |
|---|---|
| Lane: duel's packs units (lint, smoke, 43 bots, invariants) | 46/46; 0 bypasses; invariants hash 0082d470fa428493 on both runs; p50 0.587 ms |
| Lane: `selftest.sh duel.` | 8/8 (the replay hash equals the bot hash) |
| Lane: contact drills | 22/22; both fighters change in every contact |
| Lane: hand checks, 20 seeds vs the Wall | idle 0/20, perfect 20/20 |
| Director, 00:58: fast tier | arch 12/12, assets 4/4, cards 3/3, devx 229/229; foreman.typecheck NOT RUN (the tree has no node_modules) |
| Director, 00:58: `tl cards check` | PASS |

The Director removed one line from the card first: `TLVfx.squash` was still listed though the pack no longer calls it.

## Ladder on the kernel (wins of 8; each seed is one best-of-3)
| Rival | newcomer | regular | sharp | perfect |
|---|---|---|---|---|
| The Wall | 5 | 8 | 8 | 8 |
| The Duelist | 2 | 5 | 8 | 8 |
| The Dancer | 0 | 4 | 8 | 8 |
| Champion (the Duelist) | 0 | 1 | 5 | 8 |

8 seeds give about +-30 points. Nobody has played it by hand.

## Clips (`clips/`, each with a contact sheet)
- `parry_riposte.mp4`: the parry flash; the attacker's arms are flung open and held; the heavy riposte lands.
- `punish_heavy.mp4`: the Wall's heavy bounces off your guard; your light lands before he recovers.
- `splat.mp4`: a bash slams the Wall into the ring wall, then your heavy follows.
- `clash.mp4`: both lights are thrown back. The weakest of the six.
- `tell_puzzle.mp4`: the Duelist raises his blade; strike during the raise for a counter-hit.
- `round_won.mp4` (15 s, the play camera): a real match against the Wall. **Watch this first.**

**Souls / For Honor read: partly.**
- What reads: the mutual reactions, the guard / parry / punish loop and the splat.
- What does not: light and heavy differ by wind-up, arc and banner, not by the figure's weight. The toy figures and the
  thin blades limit it.

## Rules changed from the playbook (also in the README)
- **Poise:** reset, because the playbook's figures absorbed every light.
- **Parry:** the window is the first frames of a block press.
- **Clash:** two swings of the same class clash within 5 frames of each other.
- **Additions:** a visible rally rule and a crowd meter.
- **The Wall:** slowed as the first rival.
- **Pace:** a per-tier "pace" between rival strings.
- **Rival reads:** rivals read light chains and swings out of range.
- **The Dancer:** her blade hits do 11, 9 when chained.

## Questions (PATCHES.md)
- The duel stretches fight clips by writing `rig.clip_t` every frame. Document it as pack API, or add a kernel clip
  speed?
- CARDS.md has no key for data tables, so the frame table is in the card's `do` text.
- `engine/packs/README.md` needs one line for the duel.
- N4's duel genre template has not been checked against `data/moves.json`.

## Next three
1. A person plays 10 minutes against the Wall; read why they lose.
2. Give the swings weight; thicken the rapier and blades.
3. Clips of the Dancer's roll-attack and the Wall's phase 2.
