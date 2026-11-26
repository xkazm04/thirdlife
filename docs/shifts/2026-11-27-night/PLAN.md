# Night run, 27 Nov 2026 (03:00-08:00): a unique juice for each game

**The owner (26 Nov, ~00:10 27 Nov), verbatim:** "lets use the night to give each game a unique juice. We will need to
demonstrate juicy/crazy ability to express we can compose any ide there: For example carts with ability to jump, Robots
with doublesledged hammer allowed to bash oponents, Basketball with crazy high jumps and dunks/blocks. Plan the nighly run
from 3:00 until 8:00 and we will see whether to continue during the day"

**Handshake (00:20):**
- Scope: all four offered lanes:
  - the tofu-gate fix;
  - the owner's three ideas (karts, robots, basketball);
  - Biplane and Shield wall;
  - Arsenal hockey.
- Route: editor first, then by hand. Each ability goes in first as a Create change sentence on the game's real job. Where
  the editor fails, the lane records the finding and builds that ability by hand in a copy of the pack. The verdict says
  which abilities came from the editor and which were built by hand.
- Builders: 5 Opus agents. RAM up to 80 %, no CPU cap. Every heavy step waits on `tools/room.sh`.
- Landing: land on main and push by 08:00. The morning gets a new exe, the juiced games in the Dungeons list, and one clip
  per ability on the verdict page.

## What "juice" means tonight (every game lane)
An ability is juicy when a person **sees it coming, feels it land and sees the world answer it**:
- **Anticipation:** a wind-up, a crouch, a charge, a glow.
- **Exaggeration:** hang time, huge arcs, launch distance far past "realistic".
- **Impact:** hit-stop frames, camera kick or shake, knockback with a tumble, dust or sparks, a sound, the score or HUD
  reacting.
- **The game answers it:** the bots use the ability and react to it (dodge, block, punish). There is counterplay, a
  cooldown or a cost, so it is a decision and not spam.

Proven references to mimic (memory: copy proven designs):
- Rocket League: jumps, double jumps and aerials for karts.
- NBA Jam: on-fire, 3-metre dunks, swat blocks.
- Smash Bros and Gang Beasts: hammer knockback and ragdoll tumbles.
- Star Fox and Crimson Skies: barrel roll and loop.
- For Honor and Mordhau: shield bash and an overhead slam.
- NHL Hitz and Mutant League: a slapshot that floors skaters.

Behaviour comes first (owner, 23 Nov): the ability must change what the hand and the bots do, not only the look.

## The machine
- RAM used at most 80 %, no CPU cap (owner, tonight).
- Before every heavy step run `bash C:/Users/kazda/kiro/third-life/.claude/worktrees/d25-main/docs/shifts/2026-11-27-night/tools/room.sh --wait`.
  Heavy steps: a Foreman job start or change, any Godot run, a lab check, npm test, a selftest block.
- Another session (spark-ws5, the Home sandbox M5) runs all night. It claims `engine/kits/**`, `engine/kernel/API.md`,
  `engine/kernel/dungeon/**`, `engine/kernel/world/**` and `engine/boot/boot.gd`. Tonight's lanes never edit those. A
  need there is a finding for the Director.
- At most 5 agents at once.

## Lanes
| Lane | Game, ability (first proposal; the lane designs the details) | Model | Tree / branch | Job |
|---|---|---|---|---|
| T tofu gate | the editor: balance bounds stop bending games; then editor findings from the J lanes | Opus | d25-hard-a / n27-tofu | its own test job |
| J5 karts | Bumper-kart football: jump, double jump and aerial hits (Rocket League), a mid-air bump that flips | Opus | d25-kart / n27-kart | bumper-kart-football-3-20261125-1 |
| J2 robots | Robot soccer: a double-sledged hammer (wind-up, swing, robots launched and tumbling, sparks) | Opus | d25-robot / n27-robot | robot-soccer-3-v-20261125-1 |
| J4 court | Half-court: crazy high jumps, slam dunks from the free-throw line, swat blocks at the rim | Opus | d25-court / n27-court | half-court-3-v-20261125-1 |
| J11 biplane | Biplane duel: loop-the-loop that reverses a chase, barrel roll that dodges shots | Opus | d25-biplane / n27-biplane | biplane-duel-two-biplanes-20261125-1 |
| queued J19 shield | Shield wall: a shield charge that launches a line, a leaping overhead slam | Opus | d25-shield / n27-shield | shield-wall-3-v-20261125-1 |
| queued J1 arsenal | Arsenal hockey: a slapshot that floors skaters, a fire trail on the puck | Opus | d25-arsenal / n27-arsenal | three-against-three-hockey-20261125-1 |

The queued lanes start when a lane finishes (usually T after its fix lands, or a J lane done early). J19 starts before J1.

## Routing
- J lanes play the PERSON on the editor path. They never edit `foreman/`, `engine/` (outside the by-hand pack copy) or
  `contracts/`.
- What blocks a J lane goes to the Director as a `blocked-editor` line. The Director routes it to T.
- Editor fixes land on main. The Director fast-forwards each J lane's tree to main (`git merge --ff-only main` while the
  lane waits), and the lane rebuilds foreman/ and re-imports.
- By-hand fallback: only after the editor failed on that ability, with the finding written down. The lane copies the job's
  pack to `.tl/juice/<slug>_hand/` in its own tree and builds the ability there with the TL* API only. The Director copies
  it into `C:/Users/kazda/kiro/third-life/.tl/proof-games/` and adds the menu row ("... (juice by hand)").
- Menu rows (`dungeons.user.json`) are Director-only. Lanes give the pack path and the title they want.

## Times
- 00:10-01:00: handshake, plan, preflight (each tree branched from main e66eb94e, foreman built, class cache imported).
- 03:00: one-shot launch of T, J5, J2, J4, J11.
- Standups hourly at :47 (03:47, 04:47, 05:47, 06:47). Lanes write STANDUP.md lines; the Director lands and re-dispatches.
- 07:15: the verdict:
  - final landings, then on main the fast tier, npm test and the touched blocks;
  - the exe (`export.sh` + `check`);
  - menu rows;
  - VERDICT.md and the page;
  - push by 08:00.

## Landing
- **Editor fixes (T):** Director-verified on the merged tree:
  - the fast tier in the main checkout tree (d25-main);
  - foreman `npm test` (every suite that reads a touched file);
  - create. and the touched blocks;
  - one real job (the 25 Nov rule).
- **J lanes:** they land docs (PROOF, STANDUP, stills, clips at 30 s or less) and give pack paths.
- **Push:** origin main by 08:00 (`git rev-list --count origin/main..main` = 0). Main may also carry the Home session's
  merges; they are pushed with ours.
- Selftest blocks: T owns 790-799. The J lanes add no selftests.
