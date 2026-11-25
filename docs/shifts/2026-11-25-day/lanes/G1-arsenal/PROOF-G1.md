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
