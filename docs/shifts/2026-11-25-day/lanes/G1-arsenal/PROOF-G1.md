# G1: Arsenal hockey through Create (25 Nov 2026, tree d25-arsenal)

One job, driven as Create drives it:
- jobs root `.tl/jobs/`, job `three-against-three-hockey-20261125-1`;
- every step through `engine/ui/foreman_run.mjs` in `foreman_door.gd`'s order, with the flags of
  `engine/ui/flags/real.json` (claude-cli, sonnet);
- cards answered as a person would. No code of foreman/, engine/ or contracts/ was touched.

Stills are in `stills/`; I looked at every one named here. Raw captures stay in the tree's `.tl/g1-raw/`.
Times are local. Target images: `docs/shifts/2026-11-24-night/concepts/arsenal_hockey_concept.jpg` and
`arsenal_hockey_screenshot.jpg`.

## 1. The sentence and the design

My words: **"three against three hockey on a harbour rink at dusk with power-ups on the ice: grab a shield bubble,
skate over boost arrows for a burst of speed, and drop a slow field that traps the puck"**. Standard, stop after each
phase.

| step | time | what came back |
|---|---|---|
| new (12:40 to 12:47, 6.5 min) | 5 model calls, 352k tokens in, 52k out | Candidate 1 of 5, likelihood 0.85: faithful (3 v 3, 60 x 30, bubble, four arrow strips, dusk). **But "drop a slow field" became an ordered core patch**: new C++ plus rules keys, "never substitute a weaker trick". Estimate 9 packages, 480 minutes, 7M tokens. |
| my reactions on the cards | | Trap card: keep, with the note "No new engine code. Make the slow field from what the rink already has: slow ice rings painted on the ice, and the slow puck trick on F that I get from a pickup. I want to play it today." Bubble card: the alternative "Saved shield" (hold it, pop it on F), with "use the shield trick the rink already has". |
| redesign (12:56 to 13:02, 5.8 min) | 5 model calls | No core patch. Two slow-ice rings (r 3.5 m), four fast-ice arrow strips with a speed burst on entry, two green spots where pickups appear, a shield held from the first drop, shield or slow puck from a pickup, first to 5, teal Tide Otters against orange Crane Gulls, a dusk harbour drawn by the pack instead of the barn. Estimate 7 packages, 260 minutes. |

What a person meets here: the first design reads well on the cards ("Drop a glowing ring, catch their puck, and steal
it"), and only the small print of one card says "Ordered core patch". The page does not show the estimate. A person
who presses Build on it has ordered eight hours of work without knowing.

## 2. Build to the first hold (13:12 to 13:58, 46 min; not promoted yet)

Plan (2.0 min): `base` (copied), `cartridge` (data/harbour.cartridge.json, match.json), `harbour` (a script package:
scripts/harbour.gd draws the harbour and the toys, tests/bot_harbour.gd drills them), `skin` (phase 2).

| span | min | what happened |
|---|---|---|
| base | 3.3 | 43 files copied; its first lint 2.1 min |
| cartridge r1 | 3.9 | builder 2.6 min (713k tokens in); merged. Its note: "`check-cartridge` was not run, because it is not among the shell commands this job allows" |
| harbour r1 | 4.6 | builder 4.5 min (1.79M in). **Refused** by the measured check on its own drill file `data/drill_slush100.cartridge.json` (6.33 goals a minute at rookie) |
| harbour r2 | 6.2 | builder 4.7 min (1.10M in): narrowed the drill file's goal to pass; merged |
| greybox look 1 | 4.2 | 16 captures, critic NOT ok: "the bubble changes nothing visible" |
| harbour r3 (revise 1 of 2) | 6.5 | builder 4.4 min (1.08M in); merged; "kept new" |
| look 2, harbour r4 (revise 2 of 2), look 3 | 15.8 | builder 3.7 min (542k in); the critic preferred the earlier one: **r4 thrown away** ("kept previous") |
| quality hold | | 13:58, "milestone greybox is still NOT ok after revise round 2" |

Tokens so far (foreman status): 6.37M in, 247k out. Wall time from the sentence to the hold: 78 min, of which about
11 min were my waits for room on the machine.

**The cartridge** (as designed): 60 x 30, 3 v 3, teal `#1FB5A8` against orange `#E8622C`, first to 5;
- four `fast_ice` strips 6 x 3 m at (+-10, +-9), each with a `zone_enter` effect (speed x 1.35, accel x 2, 75 frames);
- two `slow_ice` rings r 3.5 m, strength 0.7, at (+-10, 0);
- two `boost_only` spots r 1 m at (0, +-9) with pickups (speed, precision; every 180 frames);
- abilities: a shield held from the drop (1 charge, 240 frames), a shield or a slow puck (x 0.75, 60 frames) from a
  pickup;
- hooks: TIDE TURNS (the side that concedes skates 12 % faster for 8 s), MATCH POINT at four;
- reception 3 m, one-timer window 20, bot body_check 0.6, look l2_night with amber trim.

**Measured by the Foreman at the cartridge merge** (thirdjam's regular playtester, 10 seeds a level):
- rookie 10/10, pro 6/10, **all_star 10/10** (warning "trivial at all_star");
- pro: 6.8 goals in 1.5 min, carry 1.1 s, shots 22, passes 1.3, speed 9.7 m/s, knockdowns 5;
- idle 0/16, skating alone 0/16.
- hokej the same way: pro 7/10, 4.2 goals in 3.1 min, passes 3.2, knockdowns 12.4, all_star 5/10.

## 3. P1, the greybox at the hold: what I saw

Filmed from the job's `pack/` in a window:
- `p1_strip.jpg`: follow camera, HUD on, the scripted hand of `tests/bot_match_hand.gd`, 16 tiles a second apart
  from frame 240;
- `p1_top.jpg` (frame 900) and `p1_still.jpg` (frame 1500);
- `p1_bubble_drill.jpg`: the Foreman's own drill strip of the bubble, 2 frames apart;
- `p1_vs_target.jpg`: the target screenshot beside two of my tiles.

What is there:
- The barn is gone. There is an orange dusk sky, a tiled quay round the boards, a lattice crane, a strip of water.
- On the ice: four tan pads with dotted white chevrons, two blue slush pools with bead rims, two green spots with a
  white bottle standing on them.
- Teal against orange, "FIRST TO 5", "F: SHIELD READY x1" above the radar.
- The rivals wear floating white words (WINCH, GULL, BREAKWATER) and carry black blocks: a black cylinder on a stick,
  two black boxes. In tile 2 the boxes cover the puck and half of my skater.
- The opening hint "F: BUBBLE  Green spots reload it" sits on top of the commentator's line for the first ten seconds;
  both are half unreadable.
- The bubble (drill strip) is a cloud of small cyan beads, then a ring of white beads on the ice. Winch walks into it
  and stands in it.
- Two goals in the first 17 seconds of the hand's match (tiles 7 and 14). The hand never pressed F in those 16 tiles.
- Pickups are not drawn (the base's known limit until lane H2 lands): the green spots look the same loaded or empty.

### The three lenses, P1

**First-timer.** In the first minute I learn one thing: F is a bubble. The screen tells me so twice. What the bubble
is for I do not learn, because nobody hits me before the first goal, and when Winch does reach the bubble he walks
into it and nothing happens that I can read. The tan pads and blue pools carry no word and no sign of what they do; I
would find out the pads are fast only by crossing one and noticing. The green spots promise a reload and show nothing
to pick up. The floating names read as signs on the rink, not as people, and the black boxes are in my way. Two goals
have fallen before I have tried anything. Readable: the teams, the score, where the net is. Not readable: every toy
but the name of one.

**Competitive hand.** The toys do not decide matches. I ran thirdjam's regular playtester (a scripted hand that
presses F where a player would: the shield while carrying with a rival within 4 m) on this cartridge with and
without the F press, 20 seeds a level, paired by seed (`.tl/g1-tools/lab.py`, `rinklab -remove=ability`):

| level | wins with F | wins without F | paired goal difference | F presses a match | rivals' hits on the hand, with / without F | seconds the hand lies on the ice, with / without F |
|---|---|---|---|---|---|---|
| pro | 8/20 | 8/20 | +0.20 | 1.6 | 1.5 / 1.5 | 2.4 / 2.2 |
| all_star | 19/20 | 18/20 | +0.65 | 1.3 | 1.2 / 1.2 | 2.3 / 2.1 |

(Corrected at 15:00: my first table had a column "hits the shield stopped 0.0", read from the lab's `shield_human`
counter. That counter is the puck-take shield's, not the F bubble's (`JamPlaytester.h:231`); the lab has no count
of hits the bubble stopped. The columns above are what it does count.)

With the bubble or without it the hand is hit as often and lies on the ice as long: the rivals hit it 1.5 times a
match, and a match is over in 1.1 to 1.2 minutes of play (pro 3.4 : 3.8 goals). There is no timing to learn and
nothing to counter. Two more things a
competitive hand would say at once: a goal falls every ten seconds, and **all_star is easier than pro** (19 of 20
against 8 of 20; the Foreman's own figures say the same, 10/10 against 6/10, and pass it with a warning). The scripted
hand measures the game, not a person; no person has played it.

**Sandbox player.** There are three toys and nothing to do with them twice. I get one bubble a match unless a green
spot gives another, and I cannot see whether it holds one. The pads are the best of it: in the lab's seed-1 match at pro the hand peaked
at 20.4 m/s and a rival at 24.4, against a plain top speed of 11 (the builder's drill saw a 24.7 peak within 75
frames of a pad), so a pad into a shot or a pad into a hit could be a moment. The pools slow the puck a little (strength 0.7); the builder's own drill saw one puck stall in seven
entries. Nothing combines yet: no bubble on a pad, no pass through slush that a mate collects, neither on film nor in
the drill's counts (Otters collected 2 stalls of a target of 7). A match of 70 seconds leaves no time to play with
anything.

### The gap, P1

To the target images:
1. The toys are bead clouds and tan pads, where the target has one clear glass bubble, yellow chevrons painted flat on
   the ice and purple rings: at a glance the target says what each is, mine do not.
2. The harbour is a flat tiled quay and one crane under a plain orange sky; the target has the warehouse with lit
   windows, the boat, snow, lamps and blue dusk.
3. The target's ice is clean: no floating words, no black boxes, a pickup icon standing on the ice, one prompt per
   button. Mine has clutter on the rivals and no pickup to see.

To hokej:
1. It moves and hits like hokej (the same core, figures, camera, HUD), on less than half the ice with six skaters.
2. It scores like nothing hokej does: 6.8 goals in 1.5 minutes at pro against 4.2 in 3.1, with 5 knockdowns a match
   against 12.4 and 1.3 completed passes against 3.2.
3. hokej's levels climb (7/10 pro, 5/10 all_star); this one's hardest level is its easiest.

## 4. Editor defects met so far

1. A clause of the sentence became an ordered core patch (C++), 9 packages and 480 minutes; the pitch page shows no
   estimate (events 8, 10).
2. The builder cannot measure its cartridge ("`check-cartridge` ... is not among the shell commands this job
   allows", event 42). The Foreman then refuses the next package on a drill file that is not the game's cartridge,
   and the builder answers by narrowing the drill's goal, not by touching the game (events 57, 60). That cost one
   builder round, 4.7 min and 1.1M tokens, and the game's own 6.8 goals in 1.5 minutes went through as "measured ok".
3. Two critic revise rounds on one drawing complaint; the second was thrown away. About 22 of the 46 minutes
   (events 88, 127, 165).
4. To give the critic its bounce, the builder draws the rival away from where the core has him ("drawing only, so
   the figure can stand well away from where the core has the body", event 92; also a stand-off of 1.55 m while
   the shield is on). The picture now disagrees with the simulation that hits the player.
5. The measured check passes "all_star 10/10" with a warning, and says nothing about the toys: it has no figure
   for whether an ability changes a match.
6. The pack's second HUD writes its hint on top of the base's commentary line (`p1_strip.jpg`, tiles 1 to 6).

---

# Round 2 (14:25 onward, tree at main faddaff: H1's fixes in, foreman rebuilt by the Director)

The Director's order for the changes: behaviour first (longer matches with fewer goals, rivals that hit, toys that
change who wins), then the clutter, then the look.

## 5. How every version is measured

`.tl/g1-tools/lab.py` plays the version's cartridge in the lab three ways, 20 seeds a level, paired by seed:
- **with F**: thirdjam's regular playtester with sprint, a scripted hand that presses F where a player would (the
  bubble while carrying with a rival within 4 m);
- **without F**: the same hand with the F press taken out (`rinklab -remove=ability`);
- **bare rink**: a copy of the cartridge without abilities, pickups, effects and zones.

"Minutes" here are minutes of play (goal pauses and faceoffs left out), so they are shorter than the Foreman's
`pro_minutes`. The scripted hand does not steer for a pad or a pool and uses the bubble crudely, so its figures are
a floor for what a timed hand gets. No person has played any version.

| version | level | wins of 20: with F / without F / bare rink | minutes of play | goals a minute | rivals' hits on the hand: with / without F | seconds on the ice: with / without F | F presses |
|---|---|---|---|---|---|---|---|
| v0.1.0 | pro | 8 / 8 / 14 | 1.1 | 6.3 | 1.5 / 1.5 | 2.4 / 2.2 | 1.6 |
| v0.1.0 | all_star | 19 / 18 / 15 | 1.2 | 5.9 | 1.2 / 1.2 | 2.3 / 2.1 | 1.3 |
| v0.1.1 | pro | 16 / 15 / 13 | 1.4 | 5.3 | 1.6 / 1.6 | 3.3 / 3.2 | 2.0 |
| v0.1.1 | all_star | 18 / 18 / 18 | 1.3 | 5.1 | 1.4 / 1.4 | 1.7 / 2.3 | 1.6 |
| v0.1.2 | pro | 11 / 10 / 13 | 1.4 | 5.3 | 3.0 / 2.9 | 5.0 / 5.0 | 3.9 |
| v0.1.2 | all_star | 18 / 15 / 15 | 1.7 | 3.9 | 2.2 / 2.8 | 3.8 / 4.5 | 4.2 |
| v0.1.3 | pro | 12 / 10 / 13 | 1.3 | 5.5 | 2.5 / 2.9 | 4.5 / 5.0 | 4.0 |
| v0.1.3 | all_star | 17 / 15 / 15 | 1.6 | 4.1 | 2.0 / 2.8 | 3.4 / 4.5 | 5.0 |
| **v0.1.4** | pro | 11 / 10 / 13 | 1.4 | 5.3 | **1.8 / 2.9** | **3.3 / 5.0** | 10.1 |
| **v0.1.4** | all_star | 17 / 15 / 15 | 1.5 | 4.8 | **1.2 / 2.8** | **2.2 / 4.5** | 9.8 |

## 6. v0.1.0 (promoted 14:38)

- **Time:** 118 min from the sentence: design 12 min, build to the hold 46 min, the hold waited 27 min for the
  fast-forward, then "It's fine, go on", phase 1 passed, the skin 7 min (no critic on it), phase 2 passed, promoted.
- **Tokens:** design 0.73M in, 100k out; build 6.65M in (5.57M cache reads), 163k out.
- **Path:** full (two phases, one quality hold).
- **What changed since P1:** the skin. "Harbour Playmakers", Tide Otters against Crane Gulls, its own commentary
  ("In! Tide Otters score!", "Winch hunts the carrier. Hits hard and straight.").
- **Seen** (`v010_strip.jpg`, `v010_top.jpg`, `v010_still.jpg`): P1 with the new words. In a window the capture
  reports two script errors: the skin's own commentary lines have no voice ("no voice for commentary line
  'faceoff.drop.04'", 'goal.blue.05'). The Foreman's checks are headless and passed.

**First-timer.** As P1: F is a bubble, and nothing tells me what the pads, the pools or the green spots do. The
commentator now names Winch and says he hits hard, which is the first hint of what the bubble is for; he says it under
the hint line, where I cannot read either.
**Competitive hand.** Noise: 8 wins of 20 with F and 8 without at pro. A goal every ten seconds, 66 seconds of play.
The bare rink is won more often (14 of 20): the toys on the ice cost this hand matches.
**Sandbox player.** One bubble, no visible pickup, 66 seconds. Nothing to play with twice.

Gap to the target: bead toys against a glass bubble, yellow chevrons and purple rings; a bare quay against a lit
harbour; clutter on the rivals. Gap to hokej: the same hands and bodies; three times the goals a minute; no hits to
speak of (5 knockdowns a match against 12.4).

## 7. v0.1.1: "The matches are over in a minute and a goal falls every ten seconds. Make goals much harder to score so a match lasts about three minutes."

- **Time:** 3.0 min (14:39:11 to 14:42:13), my answer included. **Path:** fast (data only: lint, smoke, one picture).
- **Tokens:** 61k in, 3k out (4 small calls, no builder).
- **The editor asked first** (H1's new guard): the diff wanted a three-minute clock, a bigger rink, slower shots, and
  to drop the MATCH POINT call, and asked "I must remove match-point: OK?". I answered "Keep first to five and the
  match point call, and keep the rink the size it is. Make goals harder with a better goalkeeper and smaller nets
  instead." It did exactly that.
- **What changed:** goal width 4 -> 2.8 m; keeper reach 1.4, block height 0.9. Nothing else (the what-changed note
  says so in one line).
- **Measured by the Foreman, before -> after (pro, 10 seeds):** wins 6 -> 10, goals a match 6.8 -> 7.7, minutes
  1.5 -> 2.1, knockdowns 5 -> 6.5; all_star 10 -> 8. "No warning", though pro is now won every time.
- **Seen** (`v011_strip.jpg`): the net is visibly narrower (tile 14). The hand's first 17 seconds are frame for frame
  those of v0.1.0, two goals included.

**First-timer.** Nothing new to read. I still concede or score before I have tried a toy.
**Competitive hand.** Matches are a quarter longer (1.4 minutes of play against 1.1) and still nowhere near three;
5.3 goals a minute against 6.3. The bubble is still noise (16 against 15 wins).
**Sandbox player.** As v0.1.0.

Gap to the target: unchanged. Gap to hokej: a match is still half as long with twice the goals.

## 8. v0.1.2: "The rivals almost never hit me, so my bubble has nothing to stop. Make the rivals body-check whoever has the puck often and hard, and let me hold three bubbles instead of one."

- **Time:** 102 s (14:42:56 to 14:44:38). **Path:** fast. **Tokens:** 18k in, 1k out (2 calls).
- **What changed:** bot `body_check` 0.6 -> 1, check reach 2 m, `check_speed_min` 1.5 (a slower arrival fells a man),
  bubble charges 1 -> 3 (both entries).
- **Measured by the Foreman (pro):** wins 10 -> 6, knockdowns 6.5 -> 10.2, minutes 2.1 -> 1.9; all_star 8 -> 9.
- **Seen** (`v012_strip.jpg`): "F: SHIELD READY x3"; one goal in the first 17 seconds instead of two; in tile 15
  three Gulls close on the carrier together.

**First-timer.** Now there is a reason for the bubble: I get knocked down (the lab's hand lies on the ice 5 seconds a
match against 2.4). Whether I connect the knockdowns with the F on the screen in the first minute I cannot say from
film: the filming hand never presses F, so no strip of a match shows the bubble at work.
**Competitive hand.** The first sign that the bubble matters, and only at the top level: all_star 18 wins with F
against 15 without, hit 2.2 times against 2.8, 0.7 seconds less on the ice. At pro still nothing (11 against 10;
hits 3.0 against 2.9). Three charges of four seconds, spent by this hand the moment a rival is within 4 metres, cover
12 of 85 seconds. A person who waits for the wind-up would get more; nobody has tried.
**Sandbox player.** Rougher and better for it: twice the knockdowns (9.6 a match), three bubbles. Still no visible
pickup and no second trick worth pressing.

Gap to the target: unchanged in looks. Gap to hokej: the contact is now hokej's (10.2 knockdowns a match against
12.4 by the Foreman's figures); the match is still 1.9 minutes against 3.1 with twice the goals.


## 9. v0.1.3: "Using the toys well should win matches. Let my bubble come back by itself eight seconds after I pop it, as often as I like. And make the green spots hand out a trick worth having: a cannon shot that flattens anyone in its way, or a big hip check."

**Not delivered, in 33.5 minutes and 3.98M tokens** (14:47:47 to 15:21:18; 5 builder runs). What happened, as a
person met it:

1. The change was given to the wrong package: `harbour` (the drawing), which cannot touch the game's cartridge.
2. The cartridge diff was tried all the same and refused twice by the validator (5 abilities where the limit is 4;
   pickup kinds "shotgun" and "hip_check" do not exist). So it went to a builder.
3. The builder (2.5 min) drew rings and names for a cannon and a hip check that the game does not have, and asked me:
   "Can the cartridge package (or this one, with `data/harbour.cartridge.json` added to its scope) apply the three
   ability entries above ...? If they do not, which matters more: the bubble that comes back, or the spot tricks?"
4. Create shows a "Yes, let it" chip on such a question. I pressed it and added "If both cannot be had, the bubble
   that comes back matters more."
5. **The chip sent my answer, not my request, to the cartridge package.** Its builder read "Yes, let it change what it
   needs ..." and **removed the slow-puck trick** ("following the change request's priority on the returning
   bubble"), added no returning bubble, and merged. Nothing asked me before the removal.
6. `harbour` ran again (5.8 min) and asked a second time, now in JSON: "Will the cartridge package set
   `game.abilities` to the single entry `{"kind":"shield","trigger":"mode",...}` ...?" There is no chip on this one.
   I answered "Yes: the bubble that comes back by itself every eight seconds, and nothing else on F."
7. It ran again (2.6 min) and asked the same thing a third time. I answered "You asked me that already. Stop asking:
   finish with what you have and I will ask for the bubble again afterwards." It ran a fourth time (2.6 min), merged,
   and v0.1.3 was promoted.

One true thing came out of the builder's notes: the two halves of my request exclude each other in the core. A spot
grants a trick only when nothing is held, and a bubble that always comes back is always held. No card said that to me
in words I could act on.

- **What changed in the game:** the slow-puck trick is gone from the green spots (they give a second set of three
  bubbles). The what-changed note names it ("removed: a slow_puck ... why: not said") and also says "removed: a
  shield", which is not true: both shield entries are there.
- **The eight pictures of the promotion all failed** (`ok: false`, the script error of the commentary voice) and the
  version was promoted.
- **Seen** (`v013_strip.jpg`): as v0.1.2.

**First-timer, competitive hand, sandbox player:** as v0.1.2 in every figure that matters (pro 12 wins with F against
10 without; all_star 17 against 15). For the sandbox player it is poorer by one toy. A person would also be angry:
half an hour, three times the same question, and the opposite of the request.

Gap to the target and to hokej: as v0.1.2.

## 10. v0.1.4: "In the game's own settings: my bubble comes back by itself eight seconds after I use it, with no limit on how many times, and it lasts two seconds so I have to time it. Nothing else on F."

- **Time:** 2.5 min (15:27:55 to 15:30:27), my "OK" included. **Path:** fast. **Tokens:** 22k in, 2k out.
- The owner was right this time (the cartridge), and the editor asked first: "I must remove a shield: OK?" (the
  pickup entry). I answered OK.
- **What changed:** `game.abilities` is one entry: the shield from the drop, 120 frames long, back 480 frames after a
  use, no charge count.
- **Measured by the Foreman (pro):** wins 6 -> 6, goals 7.8 -> 7.8, minutes 1.8 -> 1.9, knockdowns 8.7 -> 8.9. Its
  figures cannot see the change.
- **Seen:**
  - `v014_bubble_drill.jpg` (the pack's own drill, HUD on, 6 frames apart): the hint "F: BUBBLE  It comes back 8 s
    after you pop it"; "F: BUBBLE NOW" when Winch closes; the bead bubble; "F: SHIELD ON 2.0s" counting down above the
    radar; an orange ring under Winch as he winds up; a white burst and the word "BOUNCED!"; Winch pushed away.
  - `v014_strip.jpg`, `v014_top.jpg`: the match as before; "F: SHIELD READY" without a count.
  - The hint still sits on the commentary line, the rivals still carry boxes and names, and the skin's tagline still
    says "Green spots reload it", which is no longer true.

**First-timer.** This is the first version where the bubble explains itself, if I press it: the screen says NOW as
the man with the hammer closes in, I press, a word says BOUNCED and he is thrown back, and a clock shows it running
out. It is still a cloud of beads, and the hint still fights the commentator for the same line. The pads and pools
remain unexplained; the green spots now do nothing I can see or feel.

**Competitive hand.** The bubble now does what it says, measured: the rivals land 1.8 hits a match on the hand
against 2.9 without F at pro (1.2 against 2.8 at all_star), and it lies on the ice 3.3 seconds against 5.0 (2.2
against 4.5). **It still does not win matches at pro**: 11 wins of 20 against 10, goal difference -0.5. Staying on my
feet is not what decides an 85-second race to five; goals are. There is a timing skill now (two seconds up, eight
down, a wind-up to read) and a counter the design names (a poke takes the puck through it), but no proof of either
by a hand. The bare rink is still won more often at pro (13) than the rink with toys (11).

**Sandbox player.** One trick, always there, pleasant to press: ten uses a match. But it is the only trick. The spots
give boosts nobody can see, nothing combines, and the cannon and hip check I asked for are not in the game.

Gap to the target:
1. A bead cloud and a word, against a glass bubble that needs no word.
2. Tan pads, blue pools and bottles, against yellow chevrons, purple rings and a shield icon to grab. The target's
   "B SHIELD" prompt is the one thing mine now has an equal of ("F: SHIELD READY").
3. The harbour and the clutter are untouched since P1.

Gap to hokej:
1. Contact is close to hokej's now (8.9 knockdowns a match against 12.4), and the bubble is a toy hokej does not have.
2. A match is 1.9 minutes against 3.1, with twice the goals a minute; change 1 moved it from 1.5.
3. Three a side passes little: 1.4 completed passes a match against hokej's 3.2.

**In the menu:** v0.1.4, with the function Create's Add to menu button calls (`Dungeons.add_user`), into the list
file `.tl/g1-menu/dungeons.user.json` in this tree. Its pack is
`.tl/jobs/three-against-three-hockey-20261125-1/promoted/game.three_against_three_hockey@0.1.4`, and `read_user`
reads the row back ok. I did not write the owner's own list.

## 11. Editor defects met in round 2

7. v0.1.0 to v0.1.4 throw a script error in a window whenever a commentary line of the skin's own bank is spoken ("no
   voice for commentary line 'faceoff.drop.04'"). The headless checks pass. From v0.1.3 on, all eight promotion
   pictures report `ok: false` for it and the version is promoted anyway (events 354 to 363).
8. Change 3 went to a package that cannot make it (events 280, 284, 286 to 288).
9. The "Yes, let it" chip turns the person's answer into the change request for the other package, so that package
   never sees the request (events 292, 298, 301). A removal made by a builder is not asked first.
10. A package that cannot make a change asks the same question again after every answer: three times, four builder
    runs, 13.5 minutes, 3.3M tokens (events 288, 316, 324). A person has no way out but to tell it to stop.
11. The what-changed note of v0.1.3 names a removal that did not happen ("removed: a shield").
12. The Foreman's before/after figures cannot see a change to a toy (v0.1.4: every figure the same), so the person
    gets no answer to "did that do anything?". The lab can tell (`-remove=ability`: hits on the hand 1.8 against 2.9).
13. Asked for "about three minutes", change 1 delivered 2.1 by the Foreman's own figure and said "measured, no
    warning"; nothing told me the request was missed.

What worked, and should be said: both changes that the cartridge owned and a diff could make took 102 s and 2.5 min;
the guard that asks before removing something worked twice (changes 1 and 4), in words a person can answer.

## 12. Next

1. Toys that change who wins: the bubble protects but does not score. In a player's words: the boost pads and the
   bubble should lead to goals, or the match should be long enough that staying on my feet adds up.
2. The clutter: boxes and names off the rivals, the hint off the commentary line, the tagline.
3. The look of the toys toward the target; pickups when H2 lands (a fast-forward at a pause, then "Newest base").

---

# Round 3 (15:54 onward, tree at main 29c5a81: H1c's toy figures and H2's pickups in)

## 13. "Newest base" and the pickups

- **My games' "Newest base" refused the game** (`foreman rebase`, 1 s, no model): "CONFLICT 1 scripts/main.gd: the game
  changed these base files; moving it would lose that". The game's own drawing package had added seven lines to the
  base's `scripts/main.gd` (its hook). The newest base did not change `main.gd` at all: the old base's and the new
  base's are byte-equal; only `rink_toys.gd` and `tests/bot_toys.gd` moved. So a game that has any script package of
  its own cannot take a newer base, even when nothing collides.
- **The pickups show all the same.** The game's older `rink_toys.gd` already draws whatever the core reports, and the
  core now reports them. Seen from above (`v014_pickups_top.jpg`, four tiles a second apart): a cyan beacon on the
  north spot and a pink one on the south spot; the north one is gone in the second tile, after a skater crossed it,
  and back in the fourth. Seen from the ice (`v017_strip.jpg`, tiles 2 to 4 and 11): a cyan cone and a pink shape
  standing on the green spots. `bot_toys`: "pickups put down 4, taken 2, standing 2".

## 14. A correction: 20 seeds were too few

In round 2 I wrote that the returning bubble of v0.1.4 "still does not win matches at pro" (11 wins of 20 with F
against 10 without). Over 80 seeds that is wrong:

| version (pro, 80 seeds, the scripted hand) | wins with F | wins without F | won only with F / only without F | bare rink | hits on the hand, with / without F | seconds on the ice, with / without F |
|---|---|---|---|---|---|---|
| v0.1.0 (one bubble) | 44 | 47 | 5 / 8 | 47 | 1.3 / 1.2 | 2.2 / 2.0 |
| v0.1.1 (smaller nets) | 61 | 57 | 7 / 3 | 56 | 1.7 / 1.6 | 3.0 / 2.8 |
| v0.1.2 (rivals hit, three bubbles) | 47 | 43 | 14 / 10 | 46 | 2.7 / 3.1 | 4.6 / 5.6 |
| **v0.1.4 to v0.1.7 (the bubble returns)** | **54** | **43** | **22 / 11** | 46 | 1.9 / 3.2 | 3.2 / 5.6 |
| v0.1.4 at all_star | 73 | 65 | 11 / 3 | 55 | 1.4 / 2.8 | 2.7 / 4.9 |

So the three behaviour changes did what they were for: the bubble went from worth nothing (44 against 47) to worth
eleven wins in eighty at pro, and the game with its toys is now won more often than the bare rink (54 against 46).
It is a moderate effect, read through a scripted hand; 22 against 11 is likely real and not proven.

The check's new toy figures (H1c, `check-cartridge --toys`) say the same at 80 seeds and something else at its
default of 20:

| toy (v0.1.7's cartridge, pro) | 20 seeds: with / without, points | 80 seeds: with / without, points |
|---|---|---|
| the F bubble | 11 / 10, +5 | 54 / 43, +14 |
| the pickups (speed, precision) | 11 / 14, -15 | 54 / 59, -6 |
| the four boost pads | 11 / 13, -10 | 54 / 53, +1 |
| the two slush pools | 11 / 13, -10 | 54 / 46, +10 |

At 20 seeds every toy on the ice reads as a loss and the pools read -10; at 80 the pools are worth +10, the pads
nothing, and the pickups a little less than nothing. A person shown the 20-seed line at a pause is told the wrong
thing about three toys of four.

## 15. The decision: a bubble that returns, or tricks from the green spots

The core allows one or the other (a spot grants a trick only when nothing is held). I measured both in the lab
before asking the editor, on copies of v0.1.4's cartridge (`.tl/g1-tools/whatif.py`, pro, 80 seeds, with F against
without F):

| what F is | wins with F | wins without F | won only with F / only without F | F presses a match | goals with F |
|---|---|---|---|---|---|
| the bubble returns every 8 s (v0.1.4) | 54 | 43 | 22 / 11 | 10.4 | 4.3 : 3.0 |
| one bubble at the start, then a spot hands out two bubbles, a cannon shot or a hip check | 52 | 43 | 12 / 3 | 2.2 | 4.2 : 3.3 |
| the same with pickups twice as often | 55 | 46 | 10 / 1 | 2.2 | 4.3 : 3.1 |
| a cannon shot that returns every 8 s, no bubble | 76 | 42 | 34 / 0 | 6.2 | 4.9 : 1.7 |

- Tricks from the spots are worth as many wins as the returning bubble with a fifth of the presses: each press
  decides more (12 against 3), and the hand almost never loses a match by having them.
- This hand does not skate for a pickup; it gets 2.2 tricks a match by crossing spots in the flow of play, and more
  pickups did not give it more. A person who goes to the spot would hold more.
- The cannon shot is the toy that scores: on a timer it wins 76 of 80 and ends the game as a contest. It belongs on
  the ice as something to fetch, not under a key for free.

**As the person I choose the tricks from the green spots.** It ties the toys to the map, it is what the target
picture shows (a shield to pick up, a held trick under a button), it puts a toy that leads to goals into the game at
a price, and it costs nothing in wins against what I have.

## 16. v0.1.5, v0.1.6, v0.1.7: the same wish three times, never delivered

| | my words | given to | time | tokens in | what changed in the match |
|---|---|---|---|---|---|
| v0.1.5 | "Take the bubble off the timer. I start the match with one bubble. After that the green spots hand me one trick at a time when I pick up what lies there: two bubbles, or a cannon shot that flattens anyone in its way, or a big hip check." | `harbour` (the drawing) | 11.0 min | 1.03M | nothing |
| v0.1.6 | "Nothing changed in the match. In the game's own settings: ..." (the same wish) | `harbour` | 4.5 min | 0.58M | nothing |
| v0.1.7 | "Change the rules of the match, not the drawing: ..." (the same wish as rules) | `harbour` | 8.0 min | 0.46M | nothing |

- Each time the builder wrote that it could not make the change ("the cartridge ... is outside this package's
  scope"), asked nothing, and the job ended **done** with a new version. The cartridge of v0.1.7 is byte-equal to
  v0.1.4's.
- What did change: the drawing learnt names and prompts for tricks the game does not have ("F: CANNON  Your next
  shot flattens"), and the green spot's bottle now shows only while a pickup lies there, which is a real gain for
  the eye.
- A person sees "version 8", plays, and finds the bubble exactly as before. Nothing on the screen says the wish was
  not made. This is worse than change 3's three questions: silence with a version number on it.
- The fix for this (H1d, play words to the cartridge's owner) reached main during the round; my tree does not have it
  yet.

**The three lenses, v0.1.7** (it plays as v0.1.4; the pickups can be seen):

**First-timer.** One more thing reads now: something cyan stands on a green spot and is gone when I skate over it.
What I got from it nothing tells me (a short speed or aim boost, no word, no icon). The bubble still explains
itself when pressed (NOW, the countdown, BOUNCED). The pads and pools are still unexplained, the hint still lies on
the commentary line, and the rivals still carry boxes and names.

**Competitive hand.** By the 80-seed figures the bubble is worth learning: 54 wins against 43, hit 1.9 times a match
against 3.2. The skill is the timing (two seconds up, eight down, read the wind-up). The pickups are worth a little
less than nothing to this hand (54 against 59 without them), since whoever crosses the spot gets the boost and the
rivals cross it too. The pools help (54 against 46). Matches are still 1.5 minutes of play.

**Sandbox player.** Three things to touch now (bubble, pads, pickups) and still one trick. The cannon and the hip
check are drawn, named and prompted in the pack, and not in the game.

Gap to the target: the pickup on the ice is there now, as a plain cone where the target has an icon that says what
it gives; the rest as v0.1.4. Gap to hokej: as v0.1.4.

## 17. Editor defects met in round 3

14. "Newest base" refuses a game with a script package although the newest base did not change the file in question
    (`.tl/g1-logs/16-rebase.log`, event 397).
15. A change about the bubble or the spots goes to the drawing package whatever the words ("in the game's own
    settings", "the rules of the match, not the drawing"): events 401, 442, 470.
16. A package that cannot make a change ends the job done and promotes a version; the what-changed note lists files
    and not that the wish was not made (events 405, 436, 446, 464, 474, 506). Three versions, 23.5 minutes, 2.07M
    tokens.
17. The builder's note of v0.1.7 says "No file changed in this round" and the merge lists seven files (events 474,
    489).
18. The toy figures at the check's default of 20 seeds flip sign against 80 seeds for three toys of four (section
    14). The figure needs more seeds or a word about how sure it is.
19. The drawing package writes prompts for tricks that are not in the game, because each misrouted change leaves its
    drawing half behind (`data/tuning.json` `trick_prompts`).

## 18. Next (after a fast-forward to main with H1d)

1. The decision of section 15, asked once more: one bubble at the start, tricks from the green spots (two bubbles,
   a cannon shot, a hip check). Then the lab three ways and the toy figures at 80 seeds.
2. Longer matches (1.5 minutes of play; first to five with smaller nets has not got there).
3. The clutter (boxes, names, the hint), then the look of the toys.

One thing to check before the fast-forward: H1d refuses a promotion whose window pictures report script errors, and
every version of this game reports one (the commentary line without a voice, defect 7). Until H2b's fix for that
is in the same tree, no change of mine will be promoted.

---

# Round 4 (16:35 to 17:05, tree at main 6c02504 with H1d; light work only)

No Foreman job was started: H1d refuses a promotion whose window pictures report script errors, every version of this
game reports the missing-voice one, and its fix (H2b) is not on main yet. I measured what the next changes should ask
for, and wrote their words.

## 19. What makes a match longer (lab what-ifs)

All on a copy of the cartridge with the chosen trick design (one bubble at the start, then a green spot hands out two
bubbles, a cannon shot or a hip check), at pro, 80 seeds, thirdjam's regular playtester with and without the F press
(`.tl/g1-tools/whatif2.py`, `whatif3.py`). Never the job's file. A scripted hand measures the game, not a person.

| what I would ask for | minutes of play | whole match, min | goals | goals a minute of play | wins with F / without F | won only with F / only without F |
|---|---|---|---|---|---|---|
| first to 5 (as now) | 1.5 | 1.9 | 4.2 : 3.3 | 4.9 | 52 / 43 | 12 / 3 |
| first to 7 | 2.2 | 2.8 | 6.1 : 4.9 | 5.0 | 51 / 43 | 14 / 6 |
| first to 9 | 3.0 | 3.9 | 7.9 : 6.6 | 4.8 | 49 / 45 | 14 / 10 |
| **a three-minute clock** | **3.0** | **3.9** | 8.1 : 6.6 | 4.9 | **55 / 47** | **13 / 5** |
| a further-reaching keeper (1.9 m) and a 2.4 m net | 1.7 | 2.1 | 4.2 : 3.3 | 4.5 | 48 / 51 | 7 / 10 |
| slower shots (14 m/s for 18) | 1.4 | 1.8 | 4.1 : 3.2 | 5.3 | 51 / 47 | 11 / 7 |
| a bigger rink (70 x 35) | 1.7 | 2.1 | 3.8 : 3.7 | 4.5 | 39 / 42 | 4 / 7 |
| first to 7 with that keeper and net | 2.5 | 3.1 | 6.3 : 4.9 | 4.6 | 54 / 49 | 14 / 9 |
| no aim help on shots | 1.8 | 2.2 | 3.8 : 3.5 | 4.1 | 41 / 45 | 8 / 12 |
| a shot every 1.2 s at most | 1.6 | 2.0 | 4.3 : 2.9 | 4.6 | 58 / 50 | 14 / 6 |
| a low net (crossbar 0.61 m) | 1.5 | 1.9 | 4.2 : 3.3 | 4.9 | 52 / 43 | 12 / 3 |
| a strong keeper (reach 2.6 m, reads shots) | 1.8 | 2.2 | 4.4 : 3.3 | 4.4 | 58 / 50 | 15 / 7 |
| a slower puck carrier (0.75 of a free skater) | 1.7 | 2.1 | 4.4 : 2.9 | 4.3 | 59 / 53 | 10 / 4 |
| strong keeper and slower carrier | 1.9 | 2.3 | 4.3 : 3.1 | 4.0 | 57 / 50 | 16 / 9 |

What it says:
- **Nothing I can ask of the goals moves the scoring rate much.** Keeper, net, shot speed, shot rhythm, aim help,
  carrier speed, rink size: the rate stays between 4.0 and 5.3 goals a minute of play. A goal every 12 to 15 seconds
  is what three a side on this ice with these bots is. My change 1 ("make goals much harder to score") asked for the
  wrong thing; hokej's 4.2 goals in 3.1 minutes is five a side on 90 x 45.
- **Only the count or a clock makes the match longer.** A three-minute clock gives three minutes of play (3.9 with
  the pauses) and about fifteen goals.
- **The toys keep their worth on the clock** (55 wins against 47; 13 matches won only with F against 5) and lose it
  on a bigger rink (39 against 42) or without aim help (41 against 45).
- The low net changes nothing at all (every figure equal): the key does not act on these shots, or 0.61 is what the
  game already has.

**As the person:** a three-minute clock. In change 1 I refused the clock to keep "first to five"; I was wrong to.
The target picture has a clock between the scores, and the figures say it is the one request that gets the three
minutes without taking the toys' worth away.

## 20. The words of the next changes (ready to send when H2b is in the tree)

1. **The tricks** (the decision of section 15): "I start the match with one shield bubble on F, and it no longer comes
   back by itself. When I have no trick, picking up a boost from a green spot gives me one, whichever comes: two
   shield bubbles, or a cannon shot that flattens anyone in its way, or a big hip check."
   Then: check that it went to the cartridge; the lab three ways and the toy figures at 80 seeds; film the pack's
   drill and a match.
2. **The length:** "Play to a three-minute clock instead of first to five. The MATCH POINT call can go."
   Then: minutes of play and the toys' worth again.
3. **The clutter:** "Take the black boxes, the drum and the visor off the rival skaters, and take away the big names
   floating above them. Move the F hint so it does not lie on the commentator's line. Change the line under the title
   to: Grab a trick at the green spots. F uses it."
4. **The look of the toys:** "Draw the bubble as one smooth see-through ball round my skater, not a cloud of beads.
   Paint each boost pad as three big yellow arrows flat on the ice, with no tan pad under them. Draw the slow pools as
   purple rings on the ice."

The first two are data and should take the fast path (2 to 3 minutes each). The last two belong to the drawing
package and will go through its look and the critic.

---

# Round 5 (17:24 onward, tree at main 5b17c0d: H1d, H1e and H2b in)

The four prepared changes of section 20, sent in order. Every one reached the package that can make it, none asked a
question twice, and none ended "done" without the change.

| version | what | time | path | tokens in | reached |
|---|---|---|---|---|---|
| v0.1.8 | My games' "Newest base" | 88 s | no model; lint, smoke, five bots | 0 | the base: 5 files brought up to date, 2 added, my `main.gd` edit kept |
| v0.1.9 | the tricks from the green spots | 4.1 min | no key for a diff, one builder round, then the data-only checks | 0.66M | **the cartridge** (the Planner again named the drawing package; the new rule moved it) |
| v0.1.10 | a three-minute clock | 2.7 min | fast (a diff) | 18k | the cartridge |
| v0.1.11 | the clutter, the hint place, the title line | 12.4 min | one builder round, the whole verification and its pictures, no hold | 0.88M | the drawing package |

## 21. v0.1.8: the newest base

"Newest base" worked this time: "edited 1 scripts/main.gd: the game's own changes, kept (the newest base did not
change these files)", 7 checks, promoted. The window capture of `v018_still` reports `ok: true` for the first time:
the commentary line without a voice is said as text. It plays as v0.1.7 (`v018_strip.jpg`).

## 22. v0.1.9: "I start the match with one shield bubble on F, and it no longer comes back by itself. When I have no trick, picking up a boost from a green spot gives me one, whichever comes: two shield bubbles, or a cannon shot that flattens anyone in its way, or a big hip check."

- **What changed:** `game.abilities` is now one bubble from the drop (1 charge), and three pickup entries: two
  bubbles, a shotgun (the cannon shot), a hip check. Exactly the cartridge of my lab what-if. The builder named what
  it left out and why (no slow puck: four entries is the limit) and what it had not seen ("Not verified: that all
  three rewards are actually granted in play").
- **Measured, pro, 80 seeds:** wins with F 52, without F 43, bare rink 46; won only with F 12, only without F 3;
  2.2 F presses a match; 1.5 minutes of play. As the what-if said.
- **Seen** (`v019_take_f3075.jpg`, the pack's drill, HUD on, 8 frames apart): #7 skates over the green spot with a
  green pickup standing on it; a teal ring flashes; the base's plate above the radar says "F: SHOTGUN READY x1" and
  the pack's line says "F: CANNON  Your next shot flattens". The drill counted 4 spot takes, 2 bubble uses and
  1 cannon shot that flattened nobody; nobody was floored by a hip check.

**First-timer.** The loop reads at last: a thing stands on the green spot, I skate through it, and the screen tells
me what I got and what it does, in one line. Two names for one trick (SHOTGUN on one plate, CANNON on the other) is
the kind of thing that makes a first-timer doubt he read it right. Which trick comes is chance, and nothing on the
spot says which.

**Competitive hand.** A trick is now scarce and worth having: the scripted hand gets 2.2 a match by accident and
wins 12 matches it would have lost against 3 the other way. Going for the spot is a decision with a cost (I leave the
play), which is the first real choice the toys give. The rivals can skate over the spot too and get its boost, but
never a trick: only I hold tricks.

**Sandbox player.** Three tricks now, and the best of them changes a shot. Still no combination seen on film: the
drill fired one cannon and flattened nobody ("cannon_flats 0").

Gap to the target: the idea of the picture is in the game now (a thing to pick up, a trick under a key); its look is
not. Gap to hokej: unchanged.

## 23. v0.1.10: "Play to a three-minute clock instead of first to five. The MATCH POINT call can go."

- **What changed:** `rules.mode` timer, 10,800 frames; first to five and the MATCH POINT hook gone. The note names
  the removal and why.
- **Measured by the Foreman (pro, before -> after):** goals a match 7.5 -> 14.2, minutes 1.8 -> 3.9, knockdowns
  10.8 -> 21.1, completed passes 2 -> 3.3; warning "a goal flood at rookie (20.4 a match)".
- **Measured in the lab, pro, 80 seeds:** wins with F 55, without F 47, bare rink 45; won only with F 13, only
  without 5; 3.0 minutes of play; 4.9 goals a minute; 3.3 F presses and 20 knockdowns a match.
- **The check's own toy figures over 80 seeds** (H1e now says how sure it is): the F tricks 55 against 47, "helps";
  the slush pools 55 against 42, "helps"; the pickups' boosts 55 against 51 and the boost pads 55 against 51, "not
  clear".
- **Seen** (`v0110_strip.jpg`, `v0110_no_clock.jpg`): **there is no clock on the screen.** The plate between the
  scores says "PERIOD 1" and is empty underneath, where "FIRST TO 5" stood. I asked for a clock, the match ends on
  one, and I cannot see it run.
- The Foreman's note "not what you asked: you asked for matches of about 3 minutes; they last 3.9 min ... falls
  short" is the right idea with the wrong reading: it is a three-minute clock, and 3.9 counts the pauses after
  fifteen goals. And 3.9 is over, not short.

**First-timer.** Twice the match and time to try things: I can lose a goal and still learn what the pads do. But
without a clock on the screen I do not know it is a timed match at all until it ends.

**Competitive hand.** The toys keep their worth over the longer match (55 against 47; the game with toys 55 against
45 on the bare rink), and there are 3.3 tricks to place instead of 2.2. Fifteen goals a match is a lot: no single
goal matters much, which blunts the one trick that scores. Not being able to see the time left takes away the end
game.

**Sandbox player.** The first version with room to mess about: three minutes, twenty knockdowns, three or four
tricks, the rivals' TIDE TURNS burst after every goal.

Gap to the target: the target has the clock mine lacks. Gap to hokej: the length is hokej's now (3.9 minutes against
3.1) with three times the goals (14.2 against 4.2) and nearly twice the knockdowns (21.1 against 12.4).

## 24. v0.1.11: "Take the black boxes, the drum and the visor off the rival skaters, and take away the big names floating above them. Show the F hint in the game's own hint place, not on the commentator's line. Change the line under the title to: Grab a trick at the green spots. F uses it."

- **What changed:** the rivals' gear and name tags are gone; every F line goes to the base's hint place; the title
  line is set by the drawing package over the skin's (the skin file is not its to edit, and it said so).
- **Seen** (`v0111_strip.jpg`, `v0111_top.jpg`, `v0111_bubble_drill.jpg`): clean rivals in plain orange; the hint in
  a small plate above the key list ("F: BUBBLE x1  Green spots hand out your next trick"); the commentator's line
  readable under it for the first time ("Winch hunts the carrier. Hits hard and straight."); the pickups standing on
  their spots. The cartridge is byte-equal to v0.1.10's.

**First-timer.** The screen finally says one thing at a time. I can read the hint, and the commentator, and see
the puck, which the boxes used to cover. The rivals are now three orange skaters I cannot tell apart, which costs
nothing I could use before.

**Competitive hand, sandbox player:** as v0.1.10 (the same cartridge).

Gap to the target: the ice is as clean as the picture's now. What is left is the look of each toy (beads, tan pads,
blue pools), the harbour, and the clock. Gap to hokej: as v0.1.10.

## 25. Editor: what worked in round 5, and what I met

Worked, all of it new since round 3:
- "Newest base" kept my script edit.
- Play words reached the cartridge although the Planner named the drawing package.
- No question was asked twice; no version was promoted without its change; removals were named with their reason.
- A window error no longer blocks or slips through: the voice line is text.
- The toy figures say "helps" or "not clear" instead of a bare number.

Met:
20. **A clock game shows no clock** (`v0110_no_clock.jpg`): the base's header has nothing for a timer where "FIRST TO
    5" stood.
21. The named-figure check reads "about three minutes" against the whole match with its goal pauses (3.9) and calls
    an overshoot "falls short" (event 558).
22. One trick has two names on one screen: the base's plate says SHOTGUN, the pack's line says CANNON
    (`v019_take_f3075.jpg`).
23. The title line cannot be changed by the package that got the change: it overrides the skin from its own tuning
    file, so the skin file still says "Green spots reload it" (event 584).

## 26. v0.1.12: "Draw the bubble as one smooth see-through ball round my skater, not a cloud of beads. Paint each boost pad as three big yellow arrows flat on the ice, with no tan pad under them. Draw the slow pools as purple rings on the ice."

- **Time:** 12.3 min (17:49:17 to 18:01:34). **Path:** one builder round (4.3 min), the whole verification and its
  pictures, no hold, no question. **Tokens:** 1.40M in.
- **What changed** (the drawing package only; the cartridge is byte-equal to v0.1.10's): the bubble is one glass
  sphere from the kit; each boost pad is three flat yellow arrows pointing the way I attack, with a pale copy that
  blinks the way a skater crosses; each slow pool is one purple ring; the base's tan pads and blue fills are hidden.
- **Seen** (`v0112_bubble_drill.jpg`, `v0112_strip.jpg`, `v0112_top.jpg`, `v0112_vs_target.jpg`):
  - a clear ball round #7 that I can see him through; it swells when it comes up and when Winch hits it; "BOUNCED!";
    the countdown "F: SHIELD ON 1.8s";
  - yellow arrows and purple rings that read from the ice and from above;
  - clean orange rivals, the hint in its own plate, the commentator's line free;
  - cyan and pink pickups on the green spots.
  - Still: no clock in the header; the quay and the one crane; a pickup is a cone, not an icon of what it gives.

**First-timer.** In the first minute I can now read most of it without being told: a ball round me is a shield,
yellow arrows are speed, a thing on a green spot is to be picked up, and a plate tells me what F holds. The purple
rings I would not guess (they slow the puck); nothing says so. I do not know the match is timed, because no clock
shows. It looks like a game someone meant.

**Competitive hand.** As v0.1.10, the same cartridge: tricks 55 wins against 47 (the check: "helps"), pools 55
against 42 ("helps"), pads and pickup boosts not clear. The arrows all point one way while the pads boost both ways:
a rival skating "against" the arrows gets the same push, and the picture says otherwise.

**Sandbox player.** The toys are now pleasant to look at while messing about, and there are three minutes to do it
in. Still thin on moments: on film I have one bubble bounce and one cannon shot that hit nobody.

Gap to the target images:
1. The toys on the ice are now the picture's own kinds (glass bubble, yellow arrows, purple rings, a pickup on a
   spot, a plate for the held trick). They are plainer: block arrows for glowing chevrons, one ring for three, a cone
   for a shield icon.
2. The place is not the picture's: a flat tiled quay, one crane and an orange sky, where the target has blue dusk,
   snow, a boat and a lit warehouse. And felt figures, not knitted ones.
3. The header has no clock, where the target shows 01:38 between the scores.

Gap to hokej:
1. It moves, hits and reads like hokej, and it has what hokej has not: tricks that decide matches (55 against 47 at
   pro over 80 seeds, through a scripted hand).
2. Three times hokej's goals in about its length (14.2 in 3.9 minutes against 4.2 in 3.1): three a side on this ice
   scores every 12 seconds whatever I ask.
3. Nobody has played it. Every figure here is a scripted hand's.

**In the menu:** v0.1.12, with the function Create's Add to menu button calls, in `.tl/g1-menu/dungeons.user.json`
(the row moved from v0.1.4 to
`.tl/jobs/three-against-three-hockey-20261125-1/promoted/game.three_against_three_hockey@0.1.12`).

## 27. The whole job in figures (to v0.1.12)

- 13 promotions (v0.1.0 to v0.1.12): one build, eleven changes, one move to the newest base.
- Wall 320 min, run 287 min; 16.5M tokens in (13.4M cache reads), 437k out; 17 builder runs, 2 critic calls.
- Changes that delivered what I asked or answered: v0.1.1 (the smaller nets of my answer, not the three minutes of
  my request), v0.1.2, v0.1.4 (before the fixes), v0.1.9, v0.1.10, v0.1.11, v0.1.12 (after them). Changes that did not: v0.1.3, v0.1.5, v0.1.6, v0.1.7 (all before H1d).
- The worth of F to the scripted hand at pro over 80 seeds, version by version: 44 wins with F against 47 without
  (v0.1.0), 61 / 57 (v0.1.1), 47 / 43 (v0.1.2), 54 / 43 (v0.1.4), 52 / 43 (v0.1.9), 55 / 47 (v0.1.10 to v0.1.12).

## 28. Next

1. A clock on the screen. I would ask in the change box, "Show the time left between the scores"; it is the base's
   header, so the Director may prefer to fix it there.
2. One name for the cannon; the arrows as chevrons that do not claim a direction; a word or a sign on the purple
   rings.
3. The harbour toward the picture: blue dusk, lamps, the warehouse and the boat. Scenery, so last.

---

# Round 6 (18:05 onward, tree at main c0f96da)

The clock and the two names of one trick are the base's (H2d); I left them. Mine this round: the arrows, a sign on
the purple rings, then the harbour.

## 29. The other levels (v0.1.10 to v0.1.13's cartridge, 80 seeds, the scripted hand)

| level | wins with F | wins without F | bare rink | goals with F | won only with F / only without F |
|---|---|---|---|---|---|
| rookie | 80 | 80 | 80 | 16.7 : 2.6 | 0 / 0 |
| pro | 55 | 47 | 45 | 8.1 : 6.6 | 13 / 5 |
| all_star | 72 | 68 | 58 | 9.5 : 4.1 | 7 / 3 |

- At **rookie**, the level a new game starts on, this hand wins every match seventeen to three, with or without any
  toy. A first-timer is not this hand, but the level offers no resistance for the toys to matter against.
- At **all_star** the game with its toys is won 72 times against 58 on the bare rink; the tricks alone are worth 4
  (7 against 3: likely, not proven). all_star is still easier than pro (the open owner question; not mine to fight).

## 30. v0.1.13: "The yellow arrows on the boost pads all point one way, but the pads speed me up whichever way I cross them. Draw them so they point both ways. And put a sign on the purple rings so I can see they slow the puck down: the word SLOW painted inside each ring."

- **Time:** 10.8 min (18:07:47 to 18:18:37). **Path:** one builder round (2.6 min), the whole verification, no hold,
  no question. **Tokens:** 0.45M in. The cartridge is byte-equal to v0.1.10's.
- **Seen** (`v0113_top.jpg`, `v0113_strip.jpg`): each pad is three long double-headed yellow arrows; each purple ring
  has SLOW painted in it in purple strokes. From the ice SLOW reads right way up when I skate toward the rivals' net
  (tiles 5, 9, 10) and upside down when I skate back (tiles 2, 3, 15).

**First-timer.** The last unexplained thing on the ice now says what it is. Everything a toy does can be read in the
first minute: a ball round me, arrows, SLOW, a thing to pick up, a plate for F. Half the time the word is upside
down; a sign that reads both ways (a snail, three rings) would be better than a word.

**Competitive hand, sandbox player:** as v0.1.12 (the same cartridge). The arrows no longer tell a rival's side of
the ice something false.

Gap to the target: as v0.1.12, minus one: the arrows now say what the pads do. Gap to hokej: as v0.1.12.

## 31. v0.1.14: "Make the place look like a winter harbour at dusk: a deep blue evening sky instead of the orange one, snow on the quay round the rink, lamps that glow on the masts, a warehouse with lit windows behind one end of the rink and a fishing boat on the water."

- **Time:** 11.7 min (18:22:22 to 18:34:03). **Path:** one builder round (3.6 min), the whole verification, no hold.
  **Tokens:** 1.62M in.
- **What changed:** a warehouse and a boat built from the kit's mesh maker (the kit has neither; the builder said so);
  snow for the quay; lower masts with lanterns; and, because a pack cannot change the sky, "four blue walls and a
  lid" standing in front of it.
- **Seen** (`v0114_strip.jpg`, `v0114_top.jpg`, `v0114_vs_target.jpg`): everything I named is there, and the picture
  is worse. The blue sky is a flat band with a hard edge and reads as a wall. The snow is bright cream and makes the
  whole scene look like noon. The warehouse is a brown block with yellow squares, the boat three red boxes.

**First-timer.** Nothing changes in what I can read on the ice. The place now says "harbour" in words (a warehouse, a
boat) and "building blocks" in looks.
**Competitive hand, sandbox player:** as v0.1.12 (the same cartridge).

Gap to the target: nearer in what stands there, further in mood; the warm evening of v0.1.13 was closer to dusk
than this noon. Gap to hokej: as v0.1.12.

## 32. v0.1.15: "The blue sky looks like a wall and the snow glares like noon. Take the blue sky wall away and bring the warm evening sky back. Make the snow round the rink a dim blue-grey evening snow, not bright cream. Keep the warehouse with the lit windows, the boat and the lamps."

- **Time:** 10.6 min (18:36:10 to 18:46:47). **Path:** one builder round (2.2 min), the whole verification, no hold.
  **Tokens:** 0.49M in. It took back exactly what I named and kept the rest.
- **Seen** (`v0115_bubble_drill.jpg`, `v0115_vs_target.jpg` with two tiles of the match strip, `v0115_top.jpg`): the
  warm evening sky again; dim blue-grey ground round the rink; the warehouse with its lit windows behind the far net; the red boat
  on the water; the crane. With the glass bubble, the double arrows, SLOW in the purple rings, the pickups on their
  spots and clean rivals, this is the best the game has looked.

**First-timer.** As v0.1.13 for reading the toys; and the place now has a far end I can aim at (the lit warehouse
stands behind the rivals' net), which helps me know which way I attack.

**Competitive hand.** The same cartridge as v0.1.10: tricks worth 55 wins against 47 at pro over 80 seeds, 72
against 68 at all_star, nothing at rookie; the pools help, the pads and the pickup boosts are not clear. Still no
clock on the screen.

**Sandbox player.** Three minutes, three tricks, twenty knockdowns a match, and a place worth looking at while I do
it. Still short of moments worth retelling: a cannon shot that flattens a rival into a goal has not happened on any
film of mine.

Gap to the target images:
1. Toys: the same kinds as the picture's, plainer (arrows for glowing chevrons, a word for rings, a cone for an
   icon).
2. Place: the picture's things are there (warehouse, boat, crane, evening), as blocks and in warm orange where the
   picture is blue dusk with snow and lamps that glow on the ice. The ice and the figures are lit as by day in every
   still, although the cartridge has said `l2_night` since the design.
3. No clock (the base's, with H2d), and felt figures where the picture has knitted ones.

Gap to hokej:
1. It plays like hokej with tricks that decide matches for a scripted hand; hokej has none.
2. Three times hokej's goals in about its length.
3. Nobody has played it.

**In the menu:** v0.1.15 (the row moved with Create's own function; `.tl/g1-menu/dungeons.user.json`).

## 33. Editor notes from round 6

Worked: four changes to the drawing in 10 to 12 minutes each, one builder round each, no hold, no question; a
change that took back part of the one before did exactly that and no more.

Met:
24. **Dusk cannot be asked for.** A pack may not make a light or a sky, so "a deep blue evening sky" became four
    walls and a lid (event 698), and the ice stays lit as by day whatever the cartridge's look tier says (`l2_night`
    since v0.1.0). A person who asks for evening gets coloured scenery round a daylight rink.
25. The kit has no warehouse and no boat, so both are blocks from the mesh maker (event 698). They read, and they
    look like placeholders.
26. A word painted on the ice is upside down half the time (`v0113_strip.jpg`); nothing offered me a sign that reads
    both ways.

---

# Round 7 (19:48 onward, tree at main 816b996: H2d and H1h in)

## 34. v0.1.16: "Newest base" for the clock

- About 2 min, no model, 7 checks, promoted; six base files brought up to date, my `main.gd` edit kept.
- **Seen** (`v0116_clock.jpg`): the plate between the scores says "PERIOD 1" and under it **2:53**, counting down.
  The clock I asked for in v0.1.10 can be seen.
- The new base brought a test for the header (`tests/bot_header.gd`); the game's own list of tests was not given it,
  so the game's checks do not run it.

**First-timer.** I now know it is a timed match from the first faceoff. **Competitive hand.** There is an end game:
I can see when a trick must be spent. **Sandbox player:** as v0.1.15. The cartridge is byte-equal to v0.1.10's.

## 35. v0.1.17, v0.1.18, v0.1.19: one name for a trick, asked three times

| | my words | given to | time | tokens in | what changed |
|---|---|---|---|---|---|
| v0.1.17 | "Call the shotgun trick CANNON everywhere on the screen, and the shield BUBBLE, so one trick has one name. And change the line under the title to: Grab a trick at the green spots. F uses it." | the names to the cartridge, the title line to the skin | 13.3 min | 0.73M | **the title line, in the skin** (it reached the right owner); the names not |
| v0.1.18 | "The names are still SHIELD and SHOTGUN on the F plate. In the game's own words, name the shield BUBBLE and the shotgun CANNON. And the line that says first to five goals wins is wrong now: say Three minutes on the clock, most goals wins." | the cartridge | 11.9 min | 0.38M | nothing |
| v0.1.19 | "Change the game's text, nothing else: the trick names are BUBBLE for the shield and CANNON for the shotgun. And the HOME line that reads First to five goals wins becomes: Three minutes on the clock, most goals wins." | the cartridge | 12.2 min | 0.28M | nothing |

- Each time the cartridge's builder wrote, correctly, that the names live in the skin and what the skin needs
  ("`ability_names`: shield BUBBLE, shotgun CANNON"; the HOME line too), and that the skin file is not its to edit.
  Nobody carried that to the skin's owner. The version was promoted with the cartridge unchanged.
- What is better than in round 3: the what-changed note now says in the builder's words that the wish was NOT done
  and what it needs. A person is told. A person still cannot make it happen: the change box offers no way to say
  whose it is.
- The same builder found a line I had not noticed: HOME still says "First to five goals wins." under a three-minute
  clock.

The three lenses are those of v0.1.16: the trick is still SHOTGUN on the base's plate and CANNON on the pack's line.

## 36. Editor notes from round 7

Worked: "Newest base" a third time; the clock; a title line that reached the skin's owner; a missed wish named in the
what-changed note.

Met:
27. Words about what a trick is called go to the cartridge, three wordings out of three ("call the shotgun trick
    CANNON", "in the game's own words, name ...", "change the game's text, nothing else: the trick names are ...").
    The cartridge's builder names the right owner and the exact key each time, and the job ends done.
28. A base test that comes with "Newest base" is not added to the game's list of tests.
29. Nothing checks the skin's words against the game after a change. HOME still says "First to five goals wins." (a
    clock game since v0.1.10), "Orange arrows burst you. Blue slush drags the puck." (yellow arrows and purple rings
    since v0.1.12) and "F pops your bubble" (tricks from the spots since v0.1.9).

## 37. v0.1.20 and v0.1.21: a SLOW that reads from both ends, asked twice

| | my words | given to | time | tokens in | what changed |
|---|---|---|---|---|---|
| v0.1.20 | "The word SLOW in the purple rings is upside down when I skate back toward my own net. Paint it twice in each ring, once facing each end of the rink, so it reads right from both sides." | the cartridge (the Planner named the drawing package; the rule "these words ask for play, not a picture" moved it) | 9.0 min | 0.20M | nothing |
| v0.1.21 | "A change to the picture only: draw the word SLOW twice inside each purple ring, the second copy turned round, so the painted word can be read from both ends of the rink." | the drawing package | 9.6 min | 0.39M | **done** |

- The rule that saved the tricks in round 5 (play words go to the cartridge) took a wish about paint for a wish about
  play, because I said why I wanted it ("when I skate back toward my own net"). The cartridge's builder wrote out
  what the drawing package should do, to the line of the script, and the version was promoted unchanged.
- Said again without the reason, it went to the right package and was made in one builder round.
- **Seen** (`v0121_vs_target.jpg`, two tiles of the match strip): each ring holds SLOW twice, one above the other and
  turned round; from either end the nearer copy is the right way up. The clock runs between the scores (2:53, 2:57).

**The three lenses, v0.1.21** (the best version; the cartridge is v0.1.10's)

**First-timer.** In the first minute, without being told: it is a timed match (a clock counts down between the
scores); a clear ball round me is a shield; the yellow arrows are speed, both ways; the purple rings say SLOW
whichever way I come; a thing stands on a green spot to be picked up, and a plate tells me what F holds and what I
got. The lit warehouse behind the rivals' net tells me which way I attack. What still trips me: one trick is SHOTGUN
on one plate and CANNON on the other, and HOME tells me "First to five goals wins" before a three-minute match.

**Competitive hand.** Tricks are scarce and worth fetching (55 wins against 47 at pro over 80 seeds for the scripted
hand; 72 against 68 at all_star; nothing at rookie, which it wins 80 times of 80 either way). Going to a spot costs
position, the bubble has a wind-up to read, and with the clock on the screen there is now an end game: a held
cannon in the last ten seconds is a decision. Fifteen goals a match still makes any one goal cheap. All of it is a
scripted hand's reading; no person has played.

**Sandbox player.** Three minutes, three tricks, twenty knockdowns, pads to ride and rings to bait a pass into, in a
place that looks like somewhere. The moment I keep asking for (a cannon shot through a rival into the net) has not
happened on any film of mine; whether it happens under a hand is for a hand to find.

Gap to the target images:
1. Toys: the picture's own kinds, drawn plainer (arrows for glowing chevrons, a painted word for rings, a cone for an
   icon).
2. Place and light: the picture's things as blocks, in warm evening; the picture is blue dusk with snow and lamps.
   The engine has only the daylight rig for the arena (the Director's finding); not a thing more rounds can buy.
3. Words: SHOTGUN beside CANNON, and a HOME screen that describes the game of this morning.

Gap to hokej:
1. Hokej's movement, contact, camera and HUD, on a third of the ice with three a side.
2. Three times hokej's goals in about its length (14.2 in 3.9 minutes against 4.2 in 3.1).
3. Tricks that decide matches for a scripted hand, which hokej has not; and no hand has tried either claim.

**In the menu:** v0.1.21 (the row moved with Create's own function; `.tl/g1-menu/dungeons.user.json`).

## 38. The whole job in figures (to v0.1.21)

- 22 promotions: one build, nineteen changes, two moves to the newest base (a first try was refused, before H2b).
- Changes that delivered what I asked or answered: v0.1.1, v0.1.2, v0.1.4, v0.1.9, v0.1.10, v0.1.11, v0.1.12,
  v0.1.13, v0.1.14, v0.1.15, v0.1.21, and half of v0.1.17 (the title line).
- Changes that did not: v0.1.3, v0.1.5, v0.1.6, v0.1.7 (the drawing package got play words), v0.1.18, v0.1.19 (the
  cartridge got the skin's words), v0.1.20 (the cartridge got a picture's words).
- Every miss was a wish handed to a package that could not make it. No builder made the wrong thing.
