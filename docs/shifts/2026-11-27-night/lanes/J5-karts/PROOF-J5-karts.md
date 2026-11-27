# J5-karts proof: Bumper-kart football gets jumps, double jumps and aerials (night of 27 Nov 2026)

Tree `.claude/worktrees/d25-kart` (branch n27-kart, main e66eb94e). Game: the real Create job
`.tl/jobs/bumper-kart-football-3-20261125-1` (v0.1.3 promoted 25 Nov 23:07). Times are local (CET).

## Verdict (06:04)

| ability | made by | sentence -> version | time | tokens in / out | on film |
|---|---|---|---|---|---|
| 1. jump + flip double jump | **the editor** | change 1 -> v0.1.4 | 46 min | 3.87M / 28.5k | `clips/j5_v014_jump_editor.mp4` |
| 2. aerial hits on the ball | **the editor** (after a tofu refusal and a bend); also built **by hand** as the fallback while it was refused | change 2 -> v0.1.5 | 61 min | ~6.5M / 56k | `clips/j5_v015_aerial_editor.mp4`; hand: `clips/j5_hand_aerial.mp4` |
| 3. air bump (flip, stomp, whirl counter) | **the editor** | change 3 -> v0.1.6 | 38 min | 0.98M / 12.8k | `clips/j5_airbump_editor.mp4` |
| 3b. the bots use it and whirl against it | **the editor** | change 4 -> v0.1.7 | 29 min | 1.25M / 12.1k | `clips/j5_bot_airbump_editor.mp4` |

- **Best pack: the job's v0.1.7**, `.tl/jobs/bumper-kart-football-3-20261125-1/promoted/game.bumper_kart_football_3@0.1.7`
  (all three abilities from the editor). Menu title: **"Bumper-kart football (jumps and aerials)"**.
- The by-hand pack `.tl/juice/kart_hand/` (v0.1.4 + a hand-made aerial) is the fallback, not the pick: the
  editor's aerial flies higher and reads better on film, and only the editor's line has the air bump.
- v0.1.7, `tests/j5_bump.gd` (perfect hand that also jumps), 3600 frames, seeds 1-5: **0 script errors in every
  run, seed 1 hash f894a8bb twice**. Per live minute (all five bots together, mean of 5 seeds): **22.5 jumps,
  8.7 aerials, about 1.8 air hits** (stomps and air flips; one of them a mint kart flipping me); the hand: about
  3.8 air hits a minute. A bot whirl against my jump did not happen in these 5 runs (whirl_read is a chance).
- Hands over 20 seeds (the Foreman's final check) for v0.1.7: **newcomer 18 of 20, perfect 18 of 20**
  (v0.1.3: 15 and 18). The newcomer hand never presses Q, so this says the jumps did not break the match for a
  person who ignores them, not how hard aerials are.
- How it feels to a person (from the film; nobody has played it with real keys yet): the jump is floaty and high,
  the flip is the best stunt; the ball in the air with its shadow far below is the picture of the night; an air
  bump is loud and funny (a tub upside down on the ball, a kart pressed flat). The bots answer it, but less often
  than a good player uses it.

## Juice sheet (written 03:05-03:15, before the first sentence)

What the game is today: a flat game. Karts and the 3.6 m ball live on the deck plane (`TLBall` planar, kart bodies
locked in y); verbs are bump (Space), whirl (E), boost ram (Shift). Nothing ever leaves the floor. The juice is to give
it a third dimension, Rocket League style.

### 1. Spring hop and double jump ("jump")
- **Key:** Q (and the left mouse button). Space stays bump, E whirl, Shift boost.
- **Wind-up:** 7 frames of crouch: the tub sinks on its springs (squashed to 65 % height, widened), a spring "boing";
  the kart keeps its speed, so a person sees it coming and a rival can read it.
- **Exaggeration:** the first hop rises to about 3 m (the tub is about 1.2 m tall: two and a half times its height),
  with floaty gravity (about 0.9 s in the air). A second press in the air is the **double jump**: another kick of
  about 3 m, apex about 5.5 m, over the top of the 3.6 m ball, and the tub does a full front flip (or a side roll
  with A/D held, a Rocket League dodge) with a puff ring under it.
- **Impact:** on landing the tub squashes flat (to about 55 % for 6 frames) and springs back, a dust ring on the
  deck, a rubber thump; a fall from over 4 m adds a camera dip.
- **The bots with it and against it:** they hop for a ball bouncing high in front of them; they hop over a rival
  kart that boost-rams them (a ram passes under an airborne kart).
- **Counterplay / cost:** in the air the kart barely steers (air control about 25 %), cannot bump or whirl, and loses
  throttle; landing costs 10 frames of no drive. One ground hop each 40 frames, one double jump per flight. A
  wasted jump leaves you out of the play.
- **Copies:** Rocket League (jump, double jump, dodge flip), Mario Kart (the crouch-hop).

Sentence (Create change):
> Give my kart a jump on Q, like Rocket League: the tub crouches down on its springs for a moment, then hops about
> three metres up, more than twice its own height, with a long floaty hang. Press Q again in the air for a double
> jump that flips the kart over and goes higher than the ball. It lands with a squash, a puff of dust and a thump.
> The mint karts jump too, for high balls and to hop over a kart charging at them. In the air you can hardly steer
> and cannot bump, so a wasted jump costs you.

### 2. Aerial hits on the huge ball ("aerial")
- **Key:** none of its own: it is what happens when a kart in the air (hop or double jump) meets the ball.
- **Wind-up:** the jump itself; the ball now leaves the deck too (it gets height, gravity and bounces), so a person
  sees a high ball coming down and lines up under it.
- **Exaggeration:** an aerial touch launches the ball at about 20 m/s with a strong upward kick (8-12 m/s): it sails
  in an arc over the karts; a double-jump flip into the ball is the hardest hit in the game (about 26 m/s).
- **Impact:** 6 frames of hit-stop, camera punch toward the ball, a big "whump", the ball squashes, a ring of sparks,
  an "AERIAL!" call on the HUD. The ball bounces on the deck with weight (restitution about 0.55, a thud each bounce).
- **Bots:** they jump to meet a high or bouncing ball when they are lined up toward the rival goal (more often at
  higher tiers).
- **Counterplay / cost:** a mistimed aerial leaves you in the air under a ball that drops behind you; a ball over the
  bar (4.2 m) is no goal: it hits the back boards and bounces back.
- **Copies:** Rocket League aerials and flip shots.

Sentence (Create change):
> When a kart meets the huge ball in the air, the ball flies: it leaves the deck in a high arc over the karts, comes
> down and bounces with weight, and can sail into the goal under the bar. A double-jump flip into the ball smashes
> it hardest, with a short freeze, a camera kick, a big whump and AERIAL! on the screen. The mint karts go for high
> balls in the air too.

### 3. Mid-air bump flips a rival ("air bump")
- **Key:** none of its own: a kart in the air that crashes into a rival, or lands on its top.
- **Wind-up:** the jump; the victim sees the shadow coming.
- **Exaggeration:** the rival is thrown about 6 m and tumbles: a full barrel roll in the air, lands upside down for
  about half a second, then rights itself with a hop (about 1.5 s out of play in all). Landing on its top is a
  **stomp**: it is squashed flat for 40 frames and the jumper bounces up again with a free jump (a flip reset).
- **Impact:** hit-stop 6 frames, a bang and a big spark burst, camera kick when the hand is involved, the victim's
  driver and pennant whipping.
- **Bots:** they jump at a rival that sits on the ball near their goal; they whirl (E) against a jumper coming in.
- **Counterplay / cost:** a whirl (E) at the right moment throws the jumper off into a spin; a ground kart can drive
  out from under a falling jumper; the jumper cannot steer in the air, so it is a read, not a homing attack.
- **Copies:** Rocket League demolition and flip reset, Mario's stomp, bumper-car flips.

Sentence (Create change):
> If a kart in the air crashes into a rival or lands on top of it, the rival is flipped: it tumbles over in the air,
> lands upside down for a moment and rights itself with a hop before it drives on, with sparks and a bang where they
> met. Landing right on a rival's top squashes it flat and bounces you up for a free extra jump. A kart that whirls
> with E as a jumper comes in throws the jumper off instead.

## Log

(Each change: time, tokens, path, what changed, is it what I asked, as I see it played.)

### Change 1: the jump (03:06 -> v0.1.4 at 03:52)
- Sent 03:06:30 as `foreman change` through `engine/ui/foreman_run.mjs` with the `change` flags of
  `engine/ui/flags/real.json` (claude-cli sonnet), log `.tl/jobs/_ui_logs/1795745190-015-change.log`.
  Path: full (the Planner routed it to **core** in 5 s; core r14, then teams r4 for a broken dependent, then the four
  packages re-verified and 40 hand matches).
- **Time: 46 min from sending to v0.1.4** (core r14 built in 6.6 min; teams r4 5.9 min; the rest verification).
  **Tokens: 3.87M in (most cache reads), 28.5k out** over the job's builder calls of this change.
- The possession bound was lifted by my 25 Nov answer again ("plan bound lifted, not judged"); no tofu refusal.
- What changed (builder's words, checked in `scripts/core/hop.gd`): Q jumps; a 7-frame crouch (tub down 0.35 m),
  launch 8.5 m/s under gravity 12 (apex 3.0 m, 1.4 s in the air), a double jump of 8.2 m/s with a flip of the
  whole visual (apex about 5.8 m), air steer 0.2 and air drive 0.1, no bump/whirl/ram in the air or the crouch;
  landing squash, dust and a rubber thump, a `land` event. Kart-kart contact is skipped when heights differ by
  more than `hop.clear_m`; a high hop clears the ball. Bots hop over a rival that boost-rams at them and
  double-jump at the top.
- **Bent, said plainly by the builder:** "Mint karts do not jump for high balls: the ball is planar (TLBall planar)
  and never leaves the deck, so there are no high balls." That half of my sentence is ability 2's job (change 2).
- **Also:** the jump is visual height only, and `_pack_state` does not carry `hop_y`, so the state hash sees a jump
  only through its effects on x/z. A test that wants to know if p1 is in the air cannot read it from the state.
- Hand checks of v0.1.4 over 20 seeds: **newcomer 16 of 20, perfect 19 of 20** (v0.1.3: 15 and 18).

### Change 2: aerial hits on the ball (sent 03:53:23)
- Routed to **core** in 4 s (core r15). r15 built in 5.2 min (2.59M in, 23.6k out): the ball gets a height layer
  (`ball.h`, `ball.vh`, a shadow), kinds `aerial` and `smash`, karts drive under a flying ball, a too-high ball
  rebounds off the bar, AERIAL! on the banner, goal height 4.2 -> 5 m, bots jump for a ball over 0.6 m within 8 m.
  The builder's note named its own out-of-bound tofu figures.
- **blocked-editor: the balance (tofu) gate threw core r15 away for three figures the change was bound to move
  (skill_spread 0.241 < 0.25, idle_max_f 143 > 120, lead_change_share 0.286 < 0.3); core r16 now runs to bend the
  game back inside the 1 v 1 tofu bounds | evidence: job event 1001, `reports/core-r15-tofu-bounds-s1001.json`
  (tofugate.ts on `reports/core-r15-bot-s999.json`), 04:00.** A person in Create sees only "working"; nothing
  tells them their aerial is being re-tuned to fit the 1 v 1 tofu numbers.
- Meanwhile, by the brief, the aerial is being built by hand in `.tl/juice/kart_hand/` from v0.1.4.
- core r16 (04:00-04:06): to meet the tofu bounds the builder changed things I never asked for: `bump.sweet_add`
  20 -> 23 and a new "pinned bot reverses" rule (`bot.pinned_f` 50), and still read idle_max_f 131 > 120; lint then
  failed (main.gd 602 lines > 600). core r17 (45 s) trimmed it and is verifying (04:07).
- core r17 merged at 04:12 (the gate yields after its rounds); teams r5/r6 had to fix bots standing still after the
  change (the same thing I met by hand: a bot that hops from a standstill hangs in the air going nowhere).

### By hand: the aerial in `.tl/juice/kart_hand/` (04:02-04:20, from v0.1.4)
Built while the editor was refusing and re-tuning (TL* API only; files: `scripts/core/air.gd` new, `karts.gd`,
`hop.gd`, `main.gd`, `data/tuning.json`, `tests/bot_juice.gd` new and in the manifest):
- The ball keeps its planar body; `ball.h`/`ball.vh` are a height layer with gravity 14 and a weighted bounce
  (0.55, a thud, a squash and dust on hard falls). A shadow disc on the planks shrinks as it climbs.
- Kart and ball meet only where their heights overlap (kart 1.4 m tall, the ball's sphere at its height), so a high
  ball sails over karts on the deck and only a jump reaches it.
- **Aerial:** a kart more than 0.25 m up that meets the ball sends it at 19 m/s plus 30 % of the kart's speed, aimed
  between the contact line and the kart's nose, climbing at 9 m/s (+1.5 per metre the ball sits above the kart's
  middle). **Smash:** a double-jump flip into it: 25 m/s, climbing 11 m/s. Each: hit-stop 6 frames (smash 9) on
  kart and ball, camera kick (0.25 / 0.4), a rubber whump + metal ring (+ a cheer on a smash), sparks and dust, the
  ball squashed, a streak behind the ball in the hitter's colour, and "AERIAL!" / "SMASH!" popping big in the
  hitter's colour.
- Ground lift: a sweet bump pops the ball 5 m/s up, a boost ram 3.5, a whirl swat 3, so high balls come up in play.
- The bar: goal height 4.2 -> 5.4 m; a ball whose top is over the bar + 0.3 m does not go in, it rings off the bar.
- Bots: a bot driving at 5 m/s or more hops (chance 0.55) for a ball over 0.7 m (or climbing) 2.5-10 m ahead within
  35 degrees, and double-jumps at the top (hop.gd's rule). A first cut let bots hop from a standstill: `bot_teams`
  failed on idle_max 116 (a kart hanging 2 s in the air at walking pace); fixed with the 5 m/s rule and a smaller
  kart pop after an aerial (3 -> 1.5 m/s).
- Checks (hand pack): lint ok (main.gd 598 lines, no bypasses), smoke ok, bot_tofu, bot_hand_perfect, bot_teams,
  bot_hand_newcomer, bot_show and bot_juice all pass; newcomer hand wins 6 of 6 seeds (3:1, 3:0, 3:2, 2:1, 2:1, 3:1).
  bot_juice 3600 frames: 0 script errors, the same hash twice; bots about 14 jumps and 14 aerials a minute
  (all five bots together).
- 04:20-04:40, a fault found on film-prep counts (probe of the event frames): two karts hanging in the air on
  either side of the ball hit it in turn every 7 frames (each frozen by the hit-stop, so neither fell), the ball
  climbing to 5.6 m: a mid-air pinball, 16 "smashes" a minute. Fixed with a 40-frame aerial cooldown per kart (a
  flip may still smash right after a plain aerial: Rocket League's double touch). After: bots 13.7 aerials a
  minute (all five), 3600 frames 0 errors.

## Seen on film

### Jump (editor, v0.1.4): `clips/j5_v014_jump_editor.mp4` (20 s, window, d3d12 movie writer, seed 1, perfect hand
that also presses Q every ~3 s and again near the top)
- `stills/v014_jump_hop.jpg`: my red tub (yellow self-ring) hangs well above a mint kart, its shadow on the planks
  below; the mint kart drives on underneath. It reads as a hop at once: the shadow is what sells the height.
- `stills/v014_jump_flip.jpg`: my tub upside-down mid-flip, its spiral underside facing the camera, over a scrum by
  the boards. The flip is big and clear; it reads as a stunt.
- How it feels to a person (from the film, not my hands): the crouch is short (7 frames) and the hop is floaty and
  high, the flip is the best moment. A bot's own dodge-hop is rare (the bots hop only for a ram aimed at them):
  about 1 jump a minute per bot. There is nothing to do with a jump in v0.1.4 except dodge: the ball never leaves
  the deck, so a hop near the ball sails over it. That is why ability 2 matters.

### Aerial (by hand, `.tl/juice/kart_hand`): `clips/j5_hand_aerial.mp4` (20 s, seed 3, `tests/bot_juice.gd`)
- `stills/hand_aerial_goalmouth.jpg`: my hop at the mint goal mouth knocks the ball in over a mint kart; AERIAL! in
  red pops over the goal (the call sits a little low: it covers the goal it is celebrating).
- `stills/hand_aerial_hit.jpg`: at the kick-off my tub is mid-flip into the stitched ball, sparks at the contact,
  two shadows on the planks (ball and kart) show both are in the air, AERIAL! over the deck.
- `stills/hand_aerial_flip_away.jpg`: a frame later the tub tumbles on round and the ball flies off toward the far
  goal.
- How it feels: the hit-stop plus the big red word makes each aerial a moment; the ball now has a life above the
  karts. Too strong for the perfect hand at the kick-off: in seed 3 three of its four goals came from a kick-off hop
  into the ball (the perfect hand's aim is perfect; a person will miss more). The rivals do aerials too (mint_3,
  mint_2 in seed 1), so it is not one-sided.

### Change 2, the end: v0.1.5 promoted at 04:54 (61 min after sending)
- After the refusal (r15) and the bend (r16: sweet_add 20 -> 23, pinned-bot rule), core r17 merged; teams r5 and
  r6 fixed bots that stood still after jumps (`drive.still_hop_f`, a boost-out); show and look re-verified; 40 hand
  matches. **Tokens: about 6.5M in, 56k out.** Hands over 20 seeds: **newcomer 15 of 20, perfect 16 of 20**
  (v0.1.4: 16 and 19).
- So **the editor did make the aerial**, the long way round: the ball's height layer (`scripts/core/flight.gd`),
  aerial and smash touches, a weighted bounce, the bar (goal 4.2 -> 5 m), bots that hop for a ball over 0.6 m.
  "AERIAL!" shows only on a smash in its build.
- Headless, `tests/j5_air.gd` (a film copy with my counting hand), 3600 frames seed 1: 0 script errors, hash
  e2bfcd46 twice; bots 20 jumps and 7.4 aerials a minute (all five).
- 04:54 the job ended; per the Director, foreman rebuilt (`npm run build` ok) and the engine re-imported (exit 0) on
  6c75354c before change 3.

### Change 3: the air bump (sent 04:55:21)
- core r18 built in 3.8 min (0.98M in, 12.5k out): states `flipped` (tumble, upside down, righting hop) and
  `squashed`; contact kinds `air_flip`, `stomp`, `air_block` (a whirl throws the jumper, +10 boost), sparks and the
  camera punch on all three; a stomp gives the jumper the free double jump back. Its own balance note: tofu
  lead_change_share 0.29 against 0.3 ("for the person to judge": lane T's note, no refusal).

### Aerial (editor, v0.1.5) on film: `clips/j5_v015_aerial_editor.mp4` (20 s, seed 1, `tests/j5_air.gd` in a film copy)
- `stills/v015_aerial_high_ball.jpg`: the huge stitched ball hangs high over the deck heading for the mint goal,
  its shadow far below; my tub is upside down mid-flip under it, its own shadow beside. This is the picture of the
  night: you can see the ball is IN THE AIR, and that a kart put it there.
- `stills/v015_aerial_flip_under.jpg`: a frame earlier, the flip into the ball.
- How it feels: the editor's arc is higher and slower than my hand build's, so the ball reads better in flight; its
  AERIAL! shows only on a smash, so a plain aerial has less ceremony than in the hand build.
- 05:01 **lane T's fix seen working on my job:** "[foreman] balance moved by your change: built as you asked; the share
  of test rounds where the lead changes hands: now 0.29, was 0.33. Say "make it fairer" to tune it." (event 1132).
  No refusal and no bend this time: the round went on to verification.

### Air bump (editor, core r18 merged 05:05) on film: `clips/j5_airbump_editor.mp4` (20 s, seed 2, frames 1380-2580;
filmed from the merged core's workspace copy with `tests/j5_bump.gd`, whose hand also jumps at a mint kart close ahead)
- `stills/airbump_flip.jpg`: the camera has punched in on the hit: a mint kart is flipped upside down on top of the
  ball, my tub is sideways in the air beside it, a red mate boosts in below. Loud, clear, funny: the bumper-car flip
  I asked for.
- `stills/airbump_stomp.jpg`: a stomp: the mint kart pressed flat, its driver's head poking out of a squashed tub, dust
  on the planks; the camera leans in.
- In the first second a bot does it too (mint_1 flips red_3 in the air while both hop for the ball): by accident, not
  by intent.
- Headless (seed 1, 3600 frames): 0 script errors; p1 3 stomps and 1 air flip; the bots 0 deliberate air bumps and
  0 whirl blocks against my jumps: the bots never aim a jump at a rival and never whirl to meet a jumper. That half of
  "the game answers it" is missing, so it goes in as change 4 (a person would ask next).

### Change 3, the end: v0.1.6 promoted at 05:33 (38 min after sending)
- core r18 only (one round, no refusal, no bend), dependents re-verified unchanged, 40 hand matches.
  **Tokens: about 0.98M in, 12.8k out.** Hands over 20 seeds: **newcomer 15 of 20, perfect 19 of 20.**
- v0.1.6 is byte-for-byte the core I filmed (diff of every file but my test files: none).
- Headless `tests/j5_bump.gd`, seed 1, 3600 frames: **0 script errors, hash efba691f twice**; bots 25 jumps and
  12.6 aerials a minute (all five); air hits: p1 3 stomps + 1 air flip, bots 0 on purpose.

### Change 4: the bots use the air bump and whirl against it (sent 05:33:37)
> The mint karts should use the air bump on me too: when I am at the ball, one of them jumps and crashes into me in
> the air or lands on my roof, and when they see me jumping at them they whirl with E to throw me off. Right now only
> I ever do it, and they just sit there and get flipped.
- Routed to **teams** in 4 s (the bot brains: the right package). teams r7 built in 2.3 min (1.25M in, 11.8k out):
  a mint bot near the ball-holding player leaps at him (a stomp or a crash, chance 0.35 / 0.55 / 0.75 by tier,
  min speed 7, a 150-frame cooldown) and whirls when it reads a jumping player (the tier's `whirl_read`). The
  builder said plainly: a mint air attack has no 24-frame warning (only the 7-frame crouch), the red mates do
  neither, and no test counts air hits. Merged 05:40.
- Preview of the merged workspace (`tests/j5_bump.gd`, 3600 frames, seeds 1, 2, 4, 5): 0 script errors every run;
  bot air hits about 1.3 a minute (stomps and air flips, by mint and red bots); one is a mint kart flipping me.

### The bots answer (editor, teams r7) on film: `clips/j5_bot_airbump_editor.mp4` (20 s, seed 4, frames 1260-2460)
- `stills/bot_flips_me.jpg`: mint_2 has crashed into me in the air: my tub is upside down in the foreground with
  sparks, the mint kart knocked beside the ball, the camera punched in. For the first time I am on the receiving end
  of my own trick: the game answers it.
- Earlier in the same clip I air-flip and stomp mint karts three times; the bots' answer is rarer than my use, so the
  hand still wins the air.

### Change 4, the end: v0.1.7 promoted at 06:02 (29 min after sending)
- teams r7 only, no refusal, no bend, dependents re-verified unchanged, 40 hand matches. **Tokens: 1.25M in, 12.1k
  out.** Hands over 20 seeds: **newcomer 18 of 20, perfect 18 of 20.**
- v0.1.7 is byte-for-byte the workspace I filmed (diff: only my test files differ).
- Counts on v0.1.7 (`tests/j5_bump.gd`, 3600 frames each): seed 1 f894a8bb twice; seeds 2-5 7281c8ad, d8def9a7,
  e24e0b73, 5868c854; 0 script errors in all six runs. Air hits by bots per seed: 1, 1, 2 (one air_block), 2, 2.

## What a person in Create met tonight
1. Change 1 and change 3 went straight through: routed in 4-5 s, built in 4-7 min, the rest re-verification.
2. Change 2 was refused once by the tofu gate (event 1001) and then bent (sweet_add 20 -> 23, a pinned-bot rule)
   before it merged. Lane T's fix (main 6c75354c) landed meanwhile; changes 3 and 4 ran on it and got the new note
   ("balance moved by your change: built as you asked ... say make it fairer") instead of a refusal.
3. The editor does what the sentence says and little more: change 3 made the air bump for everyone but no bot used
   it on purpose until I asked in change 4. A person has to ask for "the game answers it" in so many words.
4. Most of the time is verification (40 hand matches each promotion): 29-61 min per change.
