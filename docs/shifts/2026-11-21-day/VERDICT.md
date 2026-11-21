# Verdict: day of 21 Nov 2026 (the game quality bar)

**Planned with you at 10:00-11:00 through the spark `game-quality-bar`.** Your words: the mini games "look and play
horrible", the notes you gave before were ignored, and the editor must design every game "like a real standalone game we
need to design and market". There were six lanes: four Opus, two Opus-directed Astra, plus three Astra arms for falls.

**Page:** https://claude.ai/artifact/LbYntZUxaofK1eDgFb8mfv

**Main:** e2a46a2 (code f389454 + the celsurf pin). **Pushed:** yes, origin/main = main at 18:20. **Final list:** green on a quiet machine (§ Gates).

## Why the games were slop (what the scouts found, 11:00)
- **The builders never saw the fun goals.** The model that writes the game code got the pitch and the cards, but not the fun checklist or any card's fun lines. Its prompt said "the smallest thing that passes the acceptance".
- **The Designer prompt contradicted your own ruling of 13 Nov.** It set difficulty as "speed, reaction and aggression" (the speed stats you ruled out) and told the Designer "no ragdoll".
- **The critic never stopped anything.** It said NOT ok at every milestone of both colosseum jobs, the jobs were promoted anyway, and it only saw stills.
- **The rig had no fight animations.** The games borrowed the hockey shot for a strike, a slide for a roll, and a flying clip for the lion's pounce.
- **Our hockey was rebuilt from memory.** Thirdjam was no longer on disk; it is now cloned from GitHub for the lanes.

## L1 editor quality: LANDED e672fe2, L1b 90f0c0c + 23d8cf2
**What changed:**
- **A 3-step design room before the cards:**
  - concept: 5 candidate pitches with likelihoods, a bold pick, reference games and what to borrow from each;
  - a game design doc: pillars that rule things out, verbs with frame data (one defensive), 2-3 playstyles, 3 s / 30 s / 3 min loops, a feel sheet in numbers, 3 clip moments;
  - a producer/marketer review against a slop list, with one revise.
- **Builders and the Planner get the feel sheet,** plus `docs/GAME-QUALITY.md`: 24 rules from game-feel and design research, and 14 slop items.
- **The critic sees motion strips** (12 frames each). A NOT-ok milestone gets 2 revise rounds that keep the better version, then **holds for you** instead of shipping.
- **L1b:**
  - an over-long line is repaired instead of killing a design;
  - crazy escapes the standard idea family;
  - clip moments are filmed first.

**Evidence:**
- Foreman 261 tests (255 pass, 0 fail, 6 skipped); ui 201/0.
- Real Opus room runs:
  - **crazy, round 1:** "Slam rival gladiators into cracked colosseum walls until the stone gives way and buries them". It picked a 0.12-likelihood pitch over the plain duel, which it named as the slop. It has jab, heavy, shove, a guard with a 6-frame parry, and a roll with 18 invulnerable frames. Playstyles: Wrecker, Duelist, Architect.
  - **crazy after L1b:** "every clean hit rips the weapon from your rival's hands".

## The proof: "a fight in a colosseum" re-run with the new editor (both HELD on quality, waiting for you)
Both jobs ran the design room for real, built phases 1 and 2, then **held at phase 3 for you**: the critic still found the greybox NOT ok after its revise rounds. Last night this would have been promoted as it was.

| | Standard (job -1) | Crazy (job -3; try 1 died in the design step on word limits, now fixed by L1b) |
|---|---|---|
| Concept | "every heavy hit smashes a rival through the colosseum walls" (candidate 3 of 5, likelihood 0.12) | "Guard Tullo's jabs, heavy him through a cracked wall breach", then Ursus the bear walks out |
| Phases passed | 1 duel, 2 arena breaks | 1 core fight, 2 the four-rival ladder |
| Held at | phase 3 greybox, after 4 revise rounds | phase 3 greybox (the Ursus walkout), after 2 revise rounds |
| Critic, last look | fun 0.15, readability 0.5, feel 0.4, silhouette 0.65 | fun 0.3, readability 0.75, feel 0.4, silhouette 0.8 |
| Slop it still sees | fighters overlap at contact; a pillar hides the rival | fighters overlap; hits without a reaction |
| Tokens in | 18.4 M | 16.1 M |

**Better than last night:**
- rivals are distinct bodies with weapons (Brutus armoured with a club, Tullo with a knife), no longer the player recoloured;
- a damage-percent HUD (Smash-style knockback);
- guard and roll inputs, readable wind-ups on Tullo.

**Still weak:**
- no hit-stop, and the struck rival barely reacts;
- the bodies merge at contact;
- the wall-breach promise never happens on camera;
- the overview camera is too far out.

Two builders asked good questions mid-job, and I answered both:
- how to give the rivals different silhouettes when the rig has no body-shape parameters;
- whether to fix a clock bug and release the bear earlier.

The critic's notes are precise, and they point at the bots and at the engine (hit-stop, push-apart), not at the design.

Films as they stand: `proof/standard-duel-held.mp4`, `proof/crazy-feel-held.mp4`. Each job is in `site/fight-colosseum-20261121-{1,3}`. `node foreman/dist/cli.js status <job>` shows the hold and the critic's words.

## L2 fight clips: LANDED f3e1e18, L2b 5b89bdf
**What it adds:** eight new biped clips (strike, strike_heavy, block, roll, dodge, body_check, cross_check, taunt), `stick_yaw`, a hit frame per clip, and `dodge_side`.

**Evidence:**
- The pose hashes of all 20 older clips are unchanged (120/120 runs); world hashes are identical.
- L2b made block, body_check, cross_check and taunt read in silhouette at the arena and hockey cameras: before/after sheets in `lanes/L2-clips/lab/`.

## L3 falls: three Astra arms, YOUR PICK (branches n21d-falls-a / -b / -c; not on main)
**Today on main a hit drops the victim INTO the hitter.** In all three arms he falls away from the blow.

| Arm | What it is | Character |
|---|---|---|
| A | authored clips | the best front fall: knees give, seat, roll back, get up |
| B | clips plus a spring | a tap rings; the side get-up goes through hand and knee |
| C | active ragdoll | really physical and never the same twice; costs about 0.32 ms per falling figure; the neck bends oddly for a few frames in the side fall |

All three are eligible: deterministic, hockey hashes = base, world 8/8.

**Clips:** `lanes/L3-falls/falls-side-by-side.mp4` (2x2 lab) and `falls-hockey-side-by-side.mp4`.

## L4 hockey (thirdjam mechanics) + L5 crazy modes: LANDED 4fbf72d, L4b f389454
**L4, thirdjam's numbers, quoted line by line:**
- the puck on the blade, which follows the mouse, with a sweep shield;
- brake by reversing the input, plus a first-step burst;
- the stability contact model, where the attacker pays;
- a cross-check that hits and can be held;
- sprint stamina; a charge shot;
- contact bodies = drawn bodies (no more overlap);
- a body-check wind-up with a pull that lands on the clip's hit frame;
- skaters go round a downed man.

**L5:**
- **Modes:** Arsenal (light beacons with speed, precision, big and heavy puck), Shotgun, and Glow Ice (a neon arena).
- **F abilities:** shotgun, hip check, shield, slow puck.

**Evidence:**
- packs 53/53, world 8/8 = alone, selftest hockey 30/30; every new bot 20/20.
- Ladder 300/300 runs; the idle hand wins 0 at every level.
- Budget at parity with the pre-hockey pack: 0.981 against 0.995 ms busy, 0.971 alone.
- Clips: `lanes/L4-hockey/clips/`, `lanes/L5-crazy/clip-{glow,shotgun,arsenal}.mp4`.

## L6 crisp hardening: LANDED df7762f + 7eba720
**Fixed:**
- road-edge things at an exact distance (46 were on the road or rails);
- kit collider top = mesh top: bodies for barricade, cabin, house and timber_frame;
- site fixtures owned;
- the block 502 flake (a frame budget raced the site's worker meshes);
- lot props and rock tops solid as drawn.

**Evidence:** 6 new cases, each failing on the base; world 8/8 crisp + classic; the manifest moved exactly the 5 kit rows. Clip: `lanes/L6-harden/clip-harden-day.mp4`.

## Gates
Final list on f389454 (all lanes landed), 16:46-18:15, on a quiet machine (proof jobs held):

| Step | Result |
|---|---|
| Full gate | 13/14 PASS: arch 12/12, devx 229/229, foreman 261 (256 + 5 skipped), kit 103/103, packs 74/74 verb runs (hockey's frame budget passes quiet), **perf 2/2 PASS (quiet)**, seeds 39/39, item 91/91, ui 201/201, world 8/8 = alone |
| Kernel suite (in the gate, not cut) | 407/408. The one FAIL was `celsurf.classic_files`, the byte pin of classic `style.json`: L5 appended 3 neon palette keys (classic draws nothing new; `celsurf.palette` needs them in both files). The pin was updated as its own comment prescribes (e2a46a2); celsurf 9/9 |
| `TL_STYLE=classic` world,packs | PASS: world 8/8, packs 74/74 |
| Tours headless + window | PASS |
| Export + export check | PASS (the exe runs the same games and 3 dungeons to the same hashes) |
| `tl arch --index` | unchanged |

## Asks
1. **Falls: which arm lands?**
   - (a) A, authored clips: the best-looking falls, cheapest.
   - (b) B, clips plus a spring: a livelier tap.
   - (c) C, active ragdoll: the most physical, 0.32 ms per falling figure, an odd neck angle to fix.
   - (d) none yet.
2. **The two held proof games:**
   - (a) `quality accept` both, so the jobs finish phase 4 and you play them.
   - (b) retry with your note.
   - (c) drop them; the next round fixes the engine side first (hit-stop helper, contact push-apart, a camera that fades occluders) and runs the proof again.
3. **An engine "feel kit"** for generated games, because the critic's repeated findings are engine-level: a kernel hit-stop that freezes both bodies, a contact push-apart, and occluder fading on the play camera.
   - (a) Yes, next shift.
   - (b) Later.
4. **Big puck** (L5) resizes the puck's collision shape past the TL API.
   - (a) Add a kernel `TLBall.set_radius`.
   - (b) Make it visual only.
   - (c) Keep it.
5. **Hockey bots now land far fewer body checks** (they time the 12-frame wind-up; 107 hits became 36 in `bot_modes`).
   - (a) Add a bot pull, as thirdjam had for humans only.
   - (b) Keep it.
6. **Play it:**
   - `dist/PLAY-LATEST.cmd` → Dungeons → Ice hockey. Try the brake by reversing, the burst, a held cross-check, the body-check wind-up, and the puck on the blade.
   - Then the start panel → Glow Ice / Arsenal / Shotgun, with F for abilities.

## Route and cost
- **Lanes:** 6 lanes plus 3 Astra arms, and 4 follow-up rounds (L1b, L2b, L4b, and L5 folded into L4).
- **Opus lanes held:** editor, clips, harden.
- **Opus-directed Astra held:**
  - hockey: 892 k Astra tokens (L4) + 1.18 M (L5), over the 800 k budget each;
  - falls: 517 / 457 / 678 k.
- **Proof jobs:** 34.5 M (18.4 + 16.1) Claude tokens in.
- **Director faults:**
  - my own timeout wrappers stopped runs twice;
  - `foreman quality retry` runs the job in the foreground; I chained it, stopped it, and resumed both jobs detached.
- **A lane fault:** L4 wrote its standup into the main checkout twice. It blocked one merge and is fixed.
