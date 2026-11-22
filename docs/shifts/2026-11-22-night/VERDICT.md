# Night of 22 Nov 2026 (19:08 to 09:00): verdict

**Page:** https://claude.ai/artifact/AmANyNo8b2bxNYHZ99BoHU

**The plan:**
- **Planned at 18:50:** the feel kit, a reference duel, hockey playability, the colosseum retry, and the Home in three
  directions.
- **Extended at 00:55, in your words:** "continue nightly shift until 9:00 looping the same goal to reach points both
  duel and hockey are high quality standalone games to set example and engine needs for all future games coming form
  editor".

**What ran:**
- Six lanes until about midnight.
- From 01:00, four lanes looping in rounds of 60-75 minutes. Each round named one gap against a reference game, built
  it, and landed with a window clip through the regular or newcomer hand.
- Every landing passed the fast tier on the merged tree. Main is pushed.

**Nobody has played anything by hand.** Every win figure comes from a scripted hand; every look judgement is from clips.

## Read first (5 minutes)
1. **Duel:**
   - `lanes/N2-duel/clips/r11_after_duelist_lessons.mp4`: the Duelist teaches his tells.
   - `r10_after_duelist.mp4`: the camera at the ring wall.
   - `r8_card.png`: the loss card.
   - Then play it: `node devx/bin/tl.mjs play duel`.
2. **Hockey:** `lanes/N3-hockey/clips/n3_r3_red_pass_out_of_pressure.mp4`, then `node devx/bin/tl.mjs play hockey`.
3. **Editor:** `docs/GAME-QUALITY.md` section 13, "What six colosseum proofs taught the editor".
4. **The Home:** `lanes/N6-world/SIDE-BY-SIDE.jpg`, then the three flyovers. You pick the direction.

## Lanes

### N2 duel (Opus): landed, 13 rounds (9d06a97 ... 4bfd439)
**What `engine/packs/duel` is now:**
- **The game:** a reference duel on the kernel feel kit. The Wall, the Duelist and the Dancer, then the champion.
- **Every contact changes both bodies:** hit-stop on both, block push, recoil, rebound, the parried pose, clash,
  guard-break and wall splat.
- **Teaching:**
  - Each rival teaches his signature in his first round.
  - A threat tag rides over his head: HEAVY, BASH, UNBLOCKABLE, and OPEN while he breathes.
  - A lost round names where your 100 health went, and the answer.
- **Identity:** each rival has his own silhouette, arena, drum beat, and push-then-breathe rhythm.
- **The KO** is a moment: a 20-frame freeze and a low camera.
- **The two-shot camera** stays inside the ring at the wall.

**Ladder** (wins of 8, best of 3, ±30 points; 21:30 in brackets):

| Rival | newcomer | regular | sharp | perfect |
|---|---|---|---|---|
| The Wall | 4 (5) | 6 (8) | 8 (8) | 8 (8) |
| The Duelist | 1 (2) | 8 (5) | 8 (8) | 8 (8) |
| The Dancer | 0 (0) | 8 (4) | 8 (8) | 8 (8) |
| Champion (round 13) | 0 (0) | 4 (1) | 5 (5) | 8 (8) |

**The lane's own read:** "a readable, teachable duel with distinct opponents, a vertical slice of the For Honor loop at
toy scale; not yet a game that sells itself by its feel". It is still one shared move set, re-dressed per rival.

**Asks:**
- (a) The Wall -> Duelist cliff for a newcomer: by your hand.
- (b) Lesson rounds at 0.4 damage: keep, or go to full damage?
- (c) The regular hand no longer finds the rungs harder in order: tune it, or leave it?
- (d) The stand-in drum: keep it until music (E5), or remove it?

### N3 hockey (Opus-directed Astra): landed (b024967, add1a0a, d18088b); done
**What changed:**
- **The puck:** a state with readable loss causes; the carrier loses it himself only on a sprint plus a hard turn.
- **Pickup and reception:** by relative speed; a pass magnet; one-timers.
- **Pokes:** odds by angle.
- **Speeds:** the HOCKEY-ARCADE ratios (the carrier at x0.88; a pass about 2x cruise).
- **The AI:** decides by utility (shoot, pass, carry, protect, dump), with roles and a perception lag by level; the
  carrier re-decides every 7-8 frames, so he passes before the hit.
- **Goals:** only through the mouth.
- **The big puck:** TLBall.set_radius.

**Metrics:**
- **In band:**
  - poke share of turnovers 54-77 % -> 9-21 %;
  - slot or one-timer share 10-27 % -> 55-68 %;
  - shots 2.2-3.0 a minute;
  - goals 2.6-3.4 a match.
- **Near the band:**
  - possession 0.4-0.8 s -> 3.0-4.1 s (band 4-10);
  - red passes per possession 1.4-2.1 after round 3 (band 1.5-3).
- **Over:**
  - completion 83-91 % (the bots pass only when safe);
  - check share 43-57 % (band at most 45).
- **Hits on your side:**
  - rookie, pro, all-star: 2.3 / 3.9 / 3.2 a minute;
  - 21 Nov: 2.5 / 4.3 / 4.9;
  - round 3 cost 7-16 %.

**Ladder, landed round 0** (wins of 20; newcomer, regular, sharp, perfect):
- rookie 15 / 19 / 19 / 20;
- pro 6 / 14 / 14 / 19;
- all-star 0 / 3 / 7 / 17;
- idle 0 of 60.

**Asks:**
- (a) Spacing against hits: `ai.json keep_off_m` cuts the scrums but costs about 25 % of red's hits. The sheets are
  `sheet_r1_keepoff_both_before_after.jpg`.
- (b) The frame budget: settled for tonight. On the quiet machine hockey reads p50 0.979 ms against 1.0, which is thin headroom; say if you want it cut further.
- (c) Land "r2a" (re-decide under pressure: more passes, hits kept) once E6 is fixed.

### N1 feel kit and engine needs (Opus-directed Astra): landed, API 1.13 -> 1.16
**Landed:**
- **1.13, the feel kit:** TLHit hit-stop and the six mutual contacts, the pushbox, the occluder fade,
  TLBall.set_radius.
- **1.14:** play_clip with frame knots and set_clip_speed (the duel dropped its shim), and re-posed strike and
  strike_heavy (the heavy coils and lunges).
- **1.15:** TLHit.swing_trail, TLHud.set_color, add_tag and remove_widget.
- **1.16:** TLBall.set_max_gain and set_velocity.

**Proof for every round:** world 8/8, and every pack verb hash unchanged against main.

**E6, the world = alone breach that N3 found:**
- **What diverges:** a skater touching the static net or boards integrates about 1e-3 m differently in the world
  runner than in the lone runner (identical to frame 2015, divergent at 2016).
- **Who it hits:** landed hockey passes only because its trajectories never make that contact.
- **Status:** open. N1 has not reported a diagnosis: it went silent after 03:27 and missed both the 06:00 and the 07:15 stops. The repro is kept (n22-hockey/.tl/w_r2a, wcmp.sh 2015/2016), and the next shift starts there.

### N4 editor (Opus): landed, 17 loop rounds after the first brief
**What the editor now does:**
- Designs from templates that copy the two house games (files, numbers, rival silhouettes, camera).
- Films the bot's reported moments in close contact strips: parries, rolls and falls first.
- Shows the critic the house game's own strip as the bar.
- Treats a build's bot figures as claims.
- Refuses hook families it already used.
- The Planner's timeout fix: 571 s -> 207 s.

**Six colosseum proofs** (all held on quality for your accept or retry):

| Job | Run | Outcome |
|---|---|---|
| -1 | standard, old prompts | feel 0.5 |
| -2 | crazy, old prompts | feel 0.35 |
| -3 | crazy, round-3 prompts | feel 0.6, house 0.5 |
| -4 | standard, round-3 prompts | feel 0.55 |
| **-5** | **crazy, round-10 prompts** | **blockout PASSED: feel 0.75, house 0.7, tofu 1**; greybox held (the echo twist never seen striking) |
| -6 | standard, round-10 prompts | feel 0.45 (hit without reaction, recoloured rivals) |

- **-5's hook:** "every swing leaves a ghost that strikes again"; the first non-soul-swap crazy hook tonight.
- **-6:** the first standard design that does not break the walls.

**Where it falls short (the lane's own words):**
- builds still stall at house 0.45-0.55 on the mutual reaction;
- the loop converges on the core, not on the twist;
- hockey has been tested on paper only.

**Ask:** should PACK.md name `metrics` and `moments` as where a bot result carries figures and filmed frames?

### N5 world chunks (Opus-directed Astra): landed earlier (637573d, LAND.md 64f26a1)
- 96 m chunks with `tl.land/1` records.
- Per-chunk colliders.
- The ledger on at 960 m.
- world 8/8 identical.
- Load 940 -> 622 ms.

### N6 the Home in three directions (Astra solo arms): on branches n22-world-a, -b, -c; you pick
| Arm | Branch | What it is |
|---|---|---|
| A | n22-world-a | one continuous land, 6.5 km |
| B | n22-world-b | islands |
| C | n22-world-c | highlands; the only one walkable |

- All three score 21 of 28 and have world 8/8.
- **Ask:** pick A, B, C or a hybrid.

## Engine needs found by the reference games (`ENGINE-NEEDS.md`)
- **Closed tonight:**
  - E1 clip timing;
  - E2 swing weight;
  - E2b trail;
  - E3 and E4 HUD colour and tags;
  - H1 the ball's gain cap.
- **Open:**
  - E5 music;
  - E6 world = alone physics;
  - E7 pushbox against a wall;
  - E8 rig gear slots;
  - hockey's perception history, own_tick, a lone-runner trace and stick reach.

## Gates (final list on main, integration worktree n22-int)
- **Full gate** on 4bfd439 (n22-int, 05:55-06:56, busy): arch 12/12, assets 4/4, cards 3/3, devx 229/229, foreman.typecheck, foreman.test 290 (284 pass, 0 fail, 6 skip), kit 120/120, seeds 39/39, item 91/91, ui 201/201, **world 8/8 = alone**. Three wall-clock steps were read again alone (below): kernel.selftest was cut at the 1800 s cap (247/248 run, 0 failed); packs failed only hockey many_budget (1.008 ms, busy); perf was NOT RUN (busy).
- **Uncapped kernel selftest:** 478 passed, 2 failed. diverge.bot_state_key passes alone (4/4; it failed under load). style.frame.rink failed because a skater from the new hockey AI stands in its ice patch; the test now samples the median (7ba57e4) and passes (west 253 vs east 248, limit 14).
- **Quiet machine, 07:37-07:51:** tl perf run --quiet-only **6/6 PASS** (tour6 frame p50 2.68 ms, walk30 2.55 ms, load6 575 ms). Packs alone **3/3, 129/129 verb runs**; hockey many_budget p50 **0.979 ms** (budget 1.0).
- **Export** at 7fd0fa7 (contains every landing): built in 114 s; export.sh check PASS (the same games and 3 dungeons hash as in the editor, it leaves nothing behind). Tours headless and in a window PASS: every pack equals alone.
- **Pushed:** origin/main..main = 0 at the verdict commit.

## Owner asks (answer in chat)
1. **Duel:** the Wall -> Duelist cliff; the lesson damage; the regular ordering; the drum.
2. **Hockey:** spacing against hits (keep_off_m); land r2a after E6.
3. **The Home:** A, B, C or a hybrid.
4. **The colosseum proofs:** `foreman quality fight-colosseum-20261122-<n> accept|retry` for any you want carried on;
   -5 is the one worth it.
5. **Contracts:** PACK.md names `metrics` and `moments`?

## Route scoreboard
| Route | Lanes | Result |
|---|---|---|
| Opus-directed Astra | N1 kernel, N3 hockey, N5 chunks | held for engineering. N1 shipped 4 API versions with hash A/B every round; N3's bisection found the kernel's E6 |
| Opus solo | N2 duel, N4 editor | held for design and judgement: 13 and 17 landable rounds, each with clip evidence |
| Astra solo | N6 arms | three looks of equal score; your eye picks |

## Cost
- **Astra:**
  - N1: at least 0.6 M (kit 280 k, rounds 2-3 336 k; later runs not reported);
  - N3: 633 k;
  - N5: 391 k;
  - N6: 1.82 M.
- **Claude:**
  - proof jobs: six colosseum jobs;
  - agents: 6 lanes, about 0.9 M subagent tokens each for the long lanes.

## Next shift
1. **You play** the duel (the Wall, then the Duelist) and hockey (rookie, pro) by hand; the asks follow from that.
2. **E6:** fix world = alone physics (kernel), then land hockey r2a.
3. **Editor:** cross-check bot claims against the film; one hockey job built through the editor to its tofu look.
