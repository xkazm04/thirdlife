# How we design a game for fun (the method, v1, 23 Nov 2026)

**The owner, 22 Nov, after playing the day's build:** "The fact players can skate and shoot puck does not mean we
delivered entertaining hockey experience, the fact players can punch in arena and take damage does not mean we delivered
fun fighting game. Both are slop nobody would touch for fun and we should prepare processes and prompts to go much
deeper in game design."

Until now our test was "the mechanics exist and the bot metrics are green". **The test is now: a person wants to play
it again.** This file is the order in which a game is decided, what each stage writes down, and who checks it. It is
read by the Designer (concept and design), the design review, the Planner, the builders, the capture critic and the
person who plays the build. The Foreman pastes its sections into the editor's prompts by number, so each section
stands alone. `docs/GAME-QUALITY.md` stays the handbook of numbers (the feel sheet, the slop ids, the checklist, the
templates); this file decides when those numbers are chosen and who says they are right. Worked cases:
`docs/design/CASES.md`. Numbers are frames at 60 Hz. A claim from a source cites it by number (Sources, at the end).

## 1. The test, and what evidence counts

- **Fun is found by playing, not written into a spec.** Every studio method we read gets there by building the smallest
  playable thing, putting it in a person's hands, watching, changing it and doing it again [7, 8, 9, 10, 11]. Valve:
  "game designs are hypotheses, playtests are experiments", and the goal of a playtest is fun, not bugs and not
  balance [10]. A design doc is a bet; the playtest settles it.
- **The test: offered "stop or play again", the player plays again.** Nothing else proves fun. The owner is the first
  player; a newcomer who has never seen the game is the second.
- **The evidence ladder.** Four kinds of evidence, and what each may decide:

  | Mark | Evidence | It can PASS | It can FAIL |
  |---|---|---|---|
  | [H] | A person's hand: the build played in a window or the exported game, as a player meets it, watched without help | every stage, the fun and the feel | every stage |
  | [C] | Film: window clips, motion strips, stills | readability (can you see what happened) | any stage (what the frames show is real) |
  | [B] | Bot figures, quoted with their hand (`TLHand`) | regressions: no crash, no idle rival, determinism | any stage (a figure out of band is a place to look) |
  | [P] | Paper: the design read aloud | the paper stages only (fantasy, pillars, loop, the 30 s script, the teardown, the kill lines) | the paper stages |

- **A bot figure never passes a stage that asks about fun or feel.** On 22 Nov the hockey was "in band" on shots,
  goals and its ladder; the owner, playing it, called it unplayable (section 2). A green figure that a person's hand
  contradicts is wrong, and the report says so.
- **Watch, don't ask.** What a player does (hesitates, mashes, stops, laughs, asks to go again) is the evidence; what
  he says afterwards explains it: "people don't know why they do what they do" [10]. Valve's observers of Half-Life
  were not allowed to give a hint [11]. Never help him during the run.
- **Say who played.** Every verdict on fun names who played, which build, for how long, and what they did. A build no
  person has played is "unplayed", never "fun" or "done".
- **The owner's standing rulings.** He judged thirdjam, our jam hockey, in 75 rulings with his own words (12-15 Nov);
  the ones about how ANY game is made stand for every game we make [35, section 10]:
  1. The owner's eye is the bar: say what a person sees or feels, and measure that (R-0067).
  2. Reproduce a fault as he meets it before a cure, and accept the cure on the same reproduction (R-0069).
  3. A list of what a first-time player feels outranks a lane's own bars (R-0068, R-0047).
  4. His numbers are taken as given; what they break is fixed (R-0067).
  5. A level is easy by clumsiness, never by absence (R-0067).
  6. Nothing technical is drawn on or in front of a figure; the animation is the message (R-0069, R-0070).
  7. The camera stays bound to the player and never moves under his aim; the HUD points at what is off screen (R-0038,
     R-0064).
  8. The arena's size is chosen by measured pacing, and measured again when the head count changes (R-0010, R-0041).
  9. Proof comes through the real input path in the packaged build (R-0032, R-0043).
  10. Gameplay over fidelity, collisions and mechanics before modes (R-0036); the genre first, the theme in the menu
      (R-0021).
  A design that breaks one says so and why, for the owner to judge.

## 2. What our games missed

Our own evidence, 19 to 22 Nov. The research on LLM-built games says the same (GAME-QUALITY.md section 5).

- **Mechanics without a game.** Hockey skates, passes and shoots; the duel strikes, blocks and parries. Neither has a
  moment a player wants to repeat. Each verb was built to its contract; nobody designed what the player feels doing it.
- **Bars we could measure instead of the bar that matters.** The hockey of the 22 Nov night had shots 2.2 to 3.0 a
  minute and 2.6 to 3.4 goals a match "in band", and a ladder that rose with skill; the duel ladder rose from
  newcomer to perfect. Every verdict of 19 to 22 Nov carries the line "nobody has played anything by hand". When the
  measure becomes the target it stops measuring [21].
- **Designs that score high on paper and low in motion.** The editor's pond hockey (job -2, 22 Nov) passed its design
  review with hook 0.85 and gif 0.85; its first look scored feel 0.25 and house_game 0.35 (board scrums of 3 to 6
  merged bodies, a puck too small to find, no reaction on any contact).
- **Copied numbers, not copied feel.** Colosseum proofs -5 and -6 copied the duel's contact numbers row for row and
  still read short of it (house_game 0.45 to 0.55): "the gap is in how the numbers are played, not in the numbers"
  (D3 report, 22 Nov). A table copied from a reference is not its feel; the feel is in the timing, the camera, the
  bodies and the sound, tuned by hand.
- **The builder's own bot as the judge.** Proof -3's bot reported `idle_max_f` 42 and 37 while its strips held both
  fighters still for 55 frames. A system that grades itself passes itself.
- **Checklists filled, decisions not made.** Every design field filled to its word limit, every slop id avoided on
  paper, and still no answer to "why would anyone play this twice?".
- **No person in the loop.** Jobs ran with `--run-through` (the Foreman passes its own phases); the held jobs waited
  for an owner who had not been asked to play anything specific.
- **Our measures cannot see what he sees** (N1's central finding). By thirdjam's own first-five-minutes measures our
  hockey scores better (first touch 0.6-0.7 s against 1.8 s, the puck on your blade 18-21 % of the time against
  10 %), and the owner calls it garbage (`docs/research/hockey-teardown/TEARDOWN.md` section 0; CASES.md stage 6b). The lesson "his hand is
  the bar" had been written down four times and was lost each time it crossed into a brief: the next night's brief
  made five bot metrics its acceptance. thirdjam had been judged by his hand: five plays, each verdict turned
  into numbered rulings in his words.
- **A world size nobody chose.** Our hockey's figures were drawn 2.2 times bigger by a drawing fix on 16 Nov, so the
  rink is 34 body widths long (thirdjam 112, a real rink about 100) and every play is a scrum. "At no point did anyone
  ask how big the ice is for the players" (N1).
- **Rules made to pass a metric.** Teammates who shoot only within 4 s of your own pass, so that an idle hand loses the
  ladder; a hit rate kept because a figure asked for it. A rule invented to pass a measure is a design decision, and no
  person ever faced it (N1).
- **Ports move numbers, not experience.** thirdjam's skating and contact were ported line by line into a world three
  times smaller, with another camera and goalies (N1). The numbers were right; the frame they lived in was not.
- **The reference from memory.** Our hockey was rebuilt from memory of thirdjam (21 Nov day verdict), and research that
  did not read the last game prescribed what thirdjam had already measured as wrong (N1).
- **Juice instead of a core.** Our hockey's fun pass added hit-stop, shake, bursts, a replay and rings at downed men on
  a match whose space, teammates and puck did not work, and re-added marks the owner had ruled out of thirdjam six days
  before ("the player animation should reflect the crosscheck movement and that should be all") (N1).
- **Breadth hides the core.** Modes, abilities, rivals and menus were added while the base match was unplayable, in
  both games (N1).
- **The rules were right; everything a person reads them through was not** (N1's duel teardown,
  `docs/research/duel-teardown/TEARDOWN.md`). The house duel copies For Honor's, Souls' and Sekiro's rules faithfully;
  its bodies do not tell (a 3-frame pose of a generic clip, stretched, with the intent written over the rival's head),
  its tutorial hits while it teaches, its rounds end in 20 seconds, and its fastest threats wind up in 12 frames where
  For Honor's take 24 to 30. A spec is not a game, and a faithful build of a spec is not either.
- **The identity went into the HUD because the rig could not carry it.** Each gap that needed the player to see
  something added a word (a tag, a cue, a banner, a card). When a game needs a body to speak, the body is the work.
- **A checklist number set below the human limit it protects.** The duel's rubric accepts a 12-frame tell; the same
  research names about 15 frames as a person's average reaction and 20 as reliable (CASES.md [B25]). A threshold comes
  from the person it protects, never from what the build already does.
- **A copied idea without its conditions.** "Teach by play" was copied from For Honor and Sekiro without their rule that
  the practice partner cannot hurt you while you learn; a copied design idea needs its conditions copied with it.
- **Loops that only add.** Twelve 20-minute rounds, each adding (lessons, tags, cards, drums, hats), none removing, and
  the base exchange never shown to a person. A loop that only adds is decoration.
- **Briefs that accept a mechanic, not a minute of play.** The briefs asked for clips of "a poke that frees the puck"
  and bands of bot figures; nothing in their acceptance could fail on what the owner meets (N1).

What fixes it: design from the feeling backwards (sections 4 to 6), write the first 30 seconds as the player meets
them (7), tune the feel by hand on a greybox (8, 10), decide before the build what would kill it (11), and let a
person's hand decide at every stage that asks about fun (12).

## 3. The stages before any build

A game passes eight stages in this order before content is built. A stage that fails sends the design back to the
first stage it touches; it never moves on with a note.

| # | Stage | It writes (in the brief) | Who checks | Passes on |
|---|---|---|---|---|
| 1 | Fantasy (4) | `FANTASY:` line; the concept's pitch | the review; the person approving the brief | [P] |
| 2 | Pillars (5) | `design.pillars`: three experiences, each ruling something out | the review | [P] |
| 3 | Core loop (6) | `design.loops`, `design.verbs`, the decision in the loop | the review | [P] |
| 4 | The 30-second test (7) | `30 SECONDS:` line; `design.first_minute` | the review on paper; the person on the greybox | [P], then [H] |
| 5 | The feel spec (8) | `design.feel`, verb frames, speeds and the camera in `rules` | the builders build it; the critic's strips; the person | [C] fails, [H] passes |
| 6 | The reference-game teardown (9) | `TEARDOWN:` lines; the concept's `references` and `template` | the review (is it concrete?); a person who played the reference | [P] |
| 7 | The greybox prototype (10) | the first phase of the plan (the tofu stage) | the person at the phase pause | [H] only |
| 8 | Kill criteria (11) | `KILL IF:` lines, written before the build | the person at the phase pause; the critic flags those the film shows | [H]; [C] can kill, never save |

Stages 1 to 6 and 8 are on paper and take minutes; stage 7 is the first build. Content (more rivals, the twist, art,
modes) comes only after stage 7 passes by a person's hand.

**The method lines.** The brief has keys for stages 2, 3 and 5. The other four are labelled lines at the head of
`brief.rules`, each on its own line, so the Planner, every builder and the critic read them:

```
FANTASY: <who the player is and what it feels like, at most 25 words>
TEARDOWN: <reference game>: <one moment of it: what you press, what you see, the numbers; at most 45 words>   (1 to 3)
30 SECONDS: <0-5 s ...; 5-15 s ...; 15-30 s ...: what the newcomer sees, does and feels; at most 70 words>
KILL IF: <what a person playing the first phase would see that stops this game; at most 30 words>   (2 to 4)
```

## 4. Stage 1: the fantasy

- **What.** One sentence a player would say about himself: who he is, what he does, how it feels. "I'm the fastest
  skater on the pond and I can thread a pass through anyone", not "arcade hockey with power-ups".
- **Why first.** Designers build mechanics, mechanics produce dynamics, and the player meets only the aesthetics, "the
  desirable emotional responses evoked in the player" [1]. Thinking from the player "encourages experience-driven (as
  opposed to feature-driven) design" [1]; Fullerton calls these player experience goals, set before the rules [7]. Designing from the feeling backwards is the only way the mechanics end up serving it. A fantasy also
  decides between features: the one that serves it stays.
- **It is delivered, not told.** The fantasy happens to the player in his first 30 seconds (stage 4), through the
  verb, never through a text line.
- **Name the aesthetic.** MDA's eight: sensation, fantasy, narrative, challenge, fellowship, discovery, expression,
  submission [1]. An arcade game aims at one or two (hockey: sensation and challenge; the duel: challenge and
  fantasy). Name them; a game that aims at all eight aims at none.
- **Fails when** it is a genre name, a feature list, a mood ("epic battles"), or something the engine cannot deliver in
  30 seconds.
- **The person checks** by reading it aloud: "would you want to be that for five minutes?"

## 5. Stage 2: pillars

- **Three pillars, each an experience, each ruling something out.** A pillar is a feeling the player must have ("every
  pass is a risk you chose"), not a feature ("passing system"). Each names what it rules out; a pillar that rules
  nothing out is a slogan [13]. Assassin's Creed had three gameplay pillars (fight, navigation, social stealth) and
  "the entire game was designed around these pillars" [12].
- **Pillars cut features.** Every verb, rival, rule and effect names the pillar it serves. One that serves none is cut,
  however cheap it is to build [13]. This is how a small team stays small.
- **The person checks**: for each pillar, a moment of the 30-second script (stage 4) where the player feels it.

## 6. Stage 3: the core loop

- **Three loops nested** (Griesemer, Halo): a 3-second action, a 30-second encounter made of those actions, a 3-minute
  match made of encounters, and the context changing so the 30 seconds never repeat [4]. The 3-second loop is the one
  that has to be fun with nothing around it (section 10). Cook's test for a loop: "what repeats and what does not?" [29].
- **Every loop holds a decision.** Sid Meier: a game is a series of interesting decisions [5]: at 3 s (pass now or carry one more
  stride; parry or roll), at 30 s (attack the weak side or reset), at 3 min (protect a lead or press). An action with
  one right answer is a chore; a loop without a decision is a toy.
- **Write the dynamics, not only the mechanics.** The design says what players will DO over time because of the rules:
  "the carrier cuts to open ice because the defender's hit takes 20 frames to wind up", "players bait the heavy
  because its recovery is long". A mechanic whose dynamic nobody can name is decoration [1].
- **Risk and reward in the verb.** The strong option leaves you open: a heavy has a long wind-up, a one-timer needs a
  pass across the crease, a sprint loses the puck on a hard turn (GAME-QUALITY.md section 1).
- **Difficulty keeps the player in flow.** Challenge beyond ability makes anxiety, below it boredom; flow needs clear
  goals, direct and immediate feedback and a sense of control [22]. Games are "boring when they are too easy and
  frustrating when they are too hard" [23]. Ours: difficulty from the opponents' design (aggression, tells, patterns;
  GAME-QUALITY.md section 1), the choice put inside the play (Chen: "embed choices inside the core activities" [22]),
  never a hidden adjuster. A difficulty figure is quoted with the hand that read it (`tl ladder`).
- **The person checks**: "what do you do every 3 seconds, and what do you choose every 30?" Two sentences, or the loop
  is not designed.

## 7. Stage 4: the 30-second test

- **The first 30 seconds as a newcomer meets them, in beats.** Written before anything is built:
  - **0 to 5 s:** what is on screen, the first press, the answer within 3 frames. The player knows who he is and where
    the goal or the rival is without reading.
  - **5 to 15 s:** the first success, against a safe first threat that teaches the verb (World 1-1's first enemy can
    only walk at you, so the first thing learned is to jump on it; Miyamoto: the player must "gradually and naturally
  understand what they're doing" [6]).
  - **15 to 30 s:** the fantasy happens once: the first real exchange, with a risk, a reaction in the bodies and a
    result the player caused.
- **No menu, no text wall, no wait.** The game opens on play; one hint line at most. "Start onboarding at launch" and
  "let them start self-directed gameplay as soon as possible" [33]. Later minutes teach the same way: introduce,
  develop, twist, conclude (kishotenketsu, Hayashida on Super Mario 3D Land [32]).
- **The 30 seconds are the acceptance of a game, not its mechanics' clips.** A brief accepts "a minute of play from the
  player's camera, with what he should feel at each moment", never "a clip of a poke that frees the puck" (N1).
- **The script names the player's feeling at each beat**, and what he says afterwards ("I scored off a pass I
  threaded", "I parried him and he staggered").
- **The person checks** on the greybox (stage 7): hand it to someone who has never seen it, start a clock, say
  nothing. By 5 s does he know what to do? By 30 s has the fantasy happened once? If not, the 30 seconds are rewritten
  before anything else is built.

## 8. Stage 5: the feel spec, in numbers

- **Game feel is real-time control of a body in a simulated space, with polish on top** (Swink): the input, the
  response the player sees and hears, the space it happens in, and the effects that sell it: "real-time control of
  virtual objects in a simulated space, with interactions emphasized by polish" [2]. Each of those is a number someone
  chose, and Swink's minimum feel prototype is the mapping, a basic layout and the camera [2].
- **The size of the world comes first, in the player's units**: the body's size, the arena in body lengths, speeds in
  body lengths (or heights) a second, the camera's distance in body heights, a figure's height on the screen. Written before any mechanic, owned by the
  design, and changed only as a design change (N1's first lesson: our rink of 34 body widths against thirdjam's 112).
  A real rink is about 100 body widths long; a figure that moves 2 of its heights a second reads as a jog whatever its
  speed in metres.
- **The sheet lists, per verb:** the input; frames from the press to the first visible response (at most 3, the full
  pose by 6: GAME-QUALITY.md section 2); anticipation, active and recovery frames; speeds and accelerations in m/s and
  m/s^2, turn rates; the camera (distance, angle, lag, what it frames); the juice by force (hit-stop, shake, burst,
  sound, each scaled, none on a whiff); the forgiveness (input buffer, coyote time, a generous catch radius).
- **Response is the first feel.** Mick West, filming pad and screen: a 60 fps game "should shoot for 3/60ths" (about
  50 ms) and stay "not above 4/60ths"; "200ms is too long to wait for a gun to fire"; he measured Halo 3 at 8 to 10
  frames [3]. At 60 Hz that is our 3-frame rule. Forgive the input: Braid keeps a jump press for 0.23 s [28].
- **Every action is answered, and the important ones loudest.** Silhouettes first, and "the amount of attention an
  ability grabs should match its level of importance" (Riot [24]); Team Fortress 2 reads team by colour, class by
  silhouette, weapon last [25]. An attack reads as anticipation, attack, recovery [26], and the tell is what makes it
  fair: "the harder it is for players to read these tells, the more difficult the combat becomes" [27].
- **Juice amplifies a loop that works; it never rescues one that does not.** Screen shake, hit-stop, particles and
  sound make a hit read and feel strong [14, 15, 31], but scaled by force (GAME-QUALITY.md slop id
  `juice_on_everything`). Juice on a verb nobody wants to press is lipstick.
- **The numbers are a starting point to tune by hand.** Every feel number lives in one tuning file
  (`data/tuning.json`) the person can change between two plays. "You want to make it feel good, not look good" (Mark
  Lesser, NHL '94's programmer; CASES.md [A1]). The feel spec passes when a person's hand says the verb feels good, not when the
  numbers match the reference.
- **The person checks**: the verb alone, in an empty room (stage 7): does pressing it feel good ten times in a row?

## 9. Stage 6: the reference-game teardown

- **Play the reference game, or watch long unedited footage of people playing it, before designing.** Never from
  memory: our hockey was rebuilt from memory and lost what made thirdjam work (section 2).
- **Write it down as a player meets it:**
  - the controls: each button and what it does, how many there are;
  - the numbers: speeds, timings, period and round lengths, scoring rates, how often each verb is used;
  - the moments: what players remember and clip (the one-timer, the parry into a heavy);
  - the AI: what the opponents and the teammates do, and how difficulty changes it;
  - what critics and players disliked.
- **Then three lists: copy, change, drop.** Copy the core that made it fun, with its numbers; change what our engine
  or our fantasy needs; drop what does not serve a pillar. GAME-QUALITY.md section 11 holds the copied cores of our two
  templates; CASES.md holds the teardowns.
- **Read the last game first.** When this studio has built the kind of game before (thirdjam for hockey), its code, its
  measurements and the owner's rulings on it are the first reference: research that skips it rediscovers what it had
  already measured and dropped. The owner's rulings, in his own words, are design assets: thirdjam keeps 75 of them
  (N1 collects them verbatim in `docs/research/hockey-teardown/RULINGS.md`), and a game of the same kind reads them
  before its design.
- **Port the frame of reference and the reasons first, the numbers last.** A number copied into a world of another
  size, with another camera, is another number. Copy the scale, the camera and why each rule exists before any table.
- **A teardown line is concrete**: "NHL '94: pass across the crease and shoot as it arrives; the goalie cannot get
  across", never "the fast feel of NHL '94".
- **The person checks**: someone who played the reference reads it: "is this what made it fun?"

## 10. Stage 7: the greybox prototype (finding the fun)

- **Prototype the core verb ugly, before any content.** A paper prototype tests rules and decisions; a greybox tests
  feel: flat shapes, the core exchange, the feel sheet, one opponent, the camera, nothing else [7, 8, 9]. Splatoon
  began as "a white thing and a black thing shaped like blocks of tofu, and they were shooting ink", after 50 to 70
  ideas in about six months [8]; "build the toy first" and "heavy theming will not salvage bad design" [9]. Our first
  phase is that greybox (the tofu stage, GAME-QUALITY.md section 12).
- **A prototype asks one question: is it fun?** A vertical slice asks another: can we build it to final quality? Our
  pipeline used to jump to the slice. Content goes on a core that a person has called fun, never on one that only
  passed its bots [7, 9].
- **Breadth hides the core.** No mode, ability, menu or second rival while the base match is not called fun.
- **Iterate in minutes.** Play, change one number, play again. A prototype that takes a day to change is not a
  prototype. The tuning file (section 8) is what makes this possible.
- **Kill freely.** Most prototypes should die. Supercell: "when a project gets killed, we pop champagne" [16]; nine
  other projects were shelved while Clash Royale was made [17]. "Learn when to shoot your baby in the crib" [9]; Valve
  cut Half-Life content "regardless of the level of emotional attachment" its maker had [11]. A killed greybox costs an
  hour; a finished game nobody plays costs a week.
- **The gate**: the person plays the first phase for 5 minutes at its phase pause and answers `pass` or `hold` with
  what he felt. Only `pass` lets the content phases start. The bot metrics of the tofu stage are the floor under this
  gate, never the gate.

## 11. Stage 8: kill criteria

- **Written before the build**, as things a person playing the first phase would SEE or DO, with no figure he cannot
  check by hand:
  - "KILL IF: after three rounds a newcomer cannot say why he lost the puck";
  - "KILL IF: the carrier is caught within 2 s every time, so nobody skates with it";
  - "KILL IF: a hit reads as two bodies sliding, with no stagger and no sound".
- **Kill means back to stage 3 (the core loop) or stop**, never "add content to make it fun". Sunk cost is not a
  reason [16, 17]. Supercell kills against goals set in advance (Smash Land: "so close to meeting our metric goals, but
  it didn't" [17]); our goals are what a person sees, because our metrics were green on games nobody wanted.
- **Who decides**: the person at the phase pause. The critic names a kill line the frames plainly show (it can kill,
  never save). A bot figure can point at a kill line, never clear it.
- **Two holds on the first phase** bring the kill lines to the owner: kill, redesign the core, or a third round, his
  choice.

## 12. The playtest loop (a person's hand)

- **Who**: the owner, a newcomer who has never seen the game, and when there is one, a player who knows the reference
  game. Five testers of one build find about 85 % of its usability problems, and several small rounds beat one big
  one [18]. Halo 3 was tested for more than 3,000 hours by about 600 players; "people were lost" until it changed [19].
- **How**: the build as a player meets it (a window or the exported game, never headless), the controls on the screen,
  no help and no explanation. The observer writes what the player did, where he hesitated, what he tried that did not
  work, when he laughed or swore. Observation shows "what people do, not what they say" [10]; Half-Life's 200+ sessions
  gave about 100 action items each [11].
- **For 5 minutes, then three questions**: what were you doing? what was the best moment? what was the worst? Then
  offer "stop or play again": the act is the answer to "is it fun".
- **Rank what he felt.** The output of a playtest is a ranked list: the things a first-time player feels in his first
  five minutes, worst first (thirdjam's standing "design eye" kept exactly this list, and it outranked every lane's own
  bars; N1). The worst line of the list is the next change.
- **One change between two plays**, so the person can tell what it did; and the owner plays the package that lands.
- **A rule made to pass a metric faces a person** before it stays: say which figure asked for it, and let the player
  judge what it does to the game.
- **Record it** in the phase answer (`foreman phase <job> pass|hold --note`): who played, which build, how long, the
  best and worst moment, the kill lines seen. The editor reads that note in the next round.
- **What the machine still does**: bots guard against regressions (crash, idle rivals, determinism) and measure
  difficulty per hand (`tl ladder`); the film shows readability. Both are quoted with what they are, and neither is
  the answer to "is it fun".
- **The playtest card.** At a phase pause `foreman status` prints the card: the fantasy, the 30-second script (first
  phase), the phase's promise, the kill lines, and how to answer.

## 13. The one-page design of a small arcade game

Librande: "most people don't read past the first page or screen", so only use one page, and "the act of creating the
diagram is the act of designing" [20]. A concept doc is 1 to 2 pages, "brief and simple", written in the second
person [30]. Ours is the brief, and it holds, in this order:

1. The fantasy, and the line "<anchor genre> where <hook>" (GAME-QUALITY.md section 3).
2. Three pillars, each with what it rules out.
3. The core loop at 3 s, 30 s and 3 min, with the decision in each.
4. The verbs with frames, one defensive, each with its own clip.
5. The feel sheet in numbers (section 8), and the camera.
6. The 30-second script (section 7) and the first minute.
7. The opponents: body, habit, tell, what makes them harder (never speed stats).
8. The three clip moments.
9. The end of a round and the restart (within 2 s).
10. The reference teardown: copy, change, drop.
11. The kill criteria.
12. Out of scope.

It does not hold lore, menus, an economy, or any feature no pillar asks for.

## 14. Rules by role

Concept:
1. Start from the fantasy: each of the five candidates is a different fantasy a player would say about himself, on
   the same proven core. The chosen one is the fantasy a stranger most wants to be, that the engine delivers in 30 s.
2. Each reference is a teardown line: the reference game's moment, what you press, what you see, its numbers. Never a
   mood.
3. `why` names the fantasy and the moment of the first 30 seconds where the player feels it.

Designer:
1. Write the method lines first (section 3): FANTASY, 1 to 3 TEARDOWN, 30 SECONDS, 2 to 4 KILL IF, at the head of
   `rules`, then design everything else to serve them.
2. Name the one or two MDA aesthetics the game aims at (in the FANTASY line or the first pillar).
3. Pillars are experiences that rule something out; every verb and aspect serves one of them.
4. The loops name the decision at each scale and the dynamics the rules produce.
5. The 30-second script is beats a newcomer meets: 0-5 s, 5-15 s, 15-30 s, the fantasy happening once by 30 s.
6. The feel sheet is numbers, and every number lives in the tuning file a person changes between two plays. It opens
   with the size of the world in the player's units (body size, arena in body lengths, speeds in body lengths a
   second, camera distance in body heights).
7. Kill lines are things a person sees or does in the first phase, never a bot figure.
8. No rule exists only to pass a bot figure; when a rule answers a figure, say so in `rules` so a person judges it.
9. Keep the owner's standing rulings (section 1); a design that breaks one says which and why.

Reviewer:
1. Read the 30-second script as the newcomer: second by second, could he do it, and would he feel the fantasy by 30 s?
   If not, `fit` and `gif` are low, and the notes say which beat fails.
2. A pillar that rules nothing out, a teardown that is a mood, a loop with no decision, a kill line only a bot can
   check: each is a revise, named in the notes.
3. Ask of every verb and aspect which pillar it serves; name the ones that serve none.

Planner:
1. The first phase is the greybox of section 10: the core loop, the feel sheet, one opponent, the camera, the tuning
   file. Its `try` line is the 30-second promise the person checks with his hands.
2. Every feel number of the design goes into the pack's tuning file, named the way the design names it, so a person
   can change it between two plays.
3. No content phase (rivals, twist, art, modes) is planned before the greybox; each later phase names the pillar it
   serves.

Builder:
1. Build for a person's hand, not for the bot: the first 30 seconds of the script, as a newcomer meets them, are your
   acceptance in spirit; the bot is the floor.
2. Read the FANTASY and KILL IF lines of the brief: when your package makes one of the kill lines true, say so under
   DEVIATIONS instead of passing quietly.
3. Put every feel number your package uses in the tuning file, never as a constant in a script.

Critic:
1. Watch as the newcomer would: from these frames, could he tell who he is, where the puck or the rival is, what just
   happened and why? Say what you see first, in plain words.
2. Judge the kill lines the frames can show (`kill_criteria`), and name each one you see happening.
3. Never call the game fun: no frame can show it. The last note lists what only a person can judge.
4. Rank what a first-time player would feel first in these frames, worst first, and put the worst in the first note.

Director:
1. A lane brief for a game accepts an experience: a minute of play from the player's camera, with what the player
   should feel at each moment, through a person's hand; mechanic clips and bot figures are its parts, never its bar.
2. A lane that changes a verb the player uses shows that verb played through a person's hand, from the player's camera,
   before and after; the owner plays the package that lands, not its description.
3. A rule a lane adds to pass a figure (an idle hand must lose, a hit rate to keep) is named in the report as a design
   decision for a person to judge.
4. A game of a kind we built before reads the last game and the owner's rulings on it first (section 1, [35]).

Person:
1. Play the build as a player meets it, 5 minutes, with the playtest card (section 12); or hand it to a newcomer and
   watch without helping.
2. Answer `pass` only when you wanted another go. Otherwise `hold` with what you felt and where it stopped being fun,
   the worst three things first.
3. A kill line you saw is a hold, whatever the bot figures say.

## Sources

Quotes from web pages were read through a fetch tool and are worth a check before they are printed elsewhere.
"[search]" marks a source seen in search results only.

1. Robin Hunicke, Marc LeBlanc, Robert Zubek, "MDA: A Formal Approach to Game Design and Game Research", AAAI
   Workshop WS-04-04 (2004): https://users.cs.northwestern.edu/~hunicke/MDA.pdf
2. Steve Swink, *Game Feel: A Game Designer's Guide to Virtual Sensation* (Morgan Kaufmann, 2008), chapter 1:
   https://puccjogos.github.io/balanceamento-2017-1s/materiais/GameFeel_Chap1.pdf ; and "Game Feel: The Secret
   Ingredient", Gamasutra (2007): https://www.gamedeveloper.com/design/game-feel-the-secret-ingredient
3. Mick West, "Measuring Responsiveness in Video Games", Gamasutra (2008):
   https://www.gamedeveloper.com/design/measuring-responsiveness-in-video-games
4. "Half-Minute Halo: An Interview with Jaime Griesemer", Joystiq/Engadget (2011):
   https://www.engadget.com/2011-07-14-half-minute-halo-an-interview-with-jaime-griesemer.html
5. Sid Meier, "Interesting Decisions", GDC 2012: https://gdcvault.com/play/1015756/Interesting ; coverage:
   https://gamedeveloper.com/design/gdc-2012-sid-meier-on-how-to-see-games-as-sets-of-interesting-decisions [search]
6. Iwata Asks, New Super Mario Bros. Wii, vol. 1 part 4 (Nintendo, 2009):
   https://www.nintendo.com/en-gb/Iwata-Asks/Iwata-Asks-New-Super-Mario-Bros-Wii/Volume-1/4-Letting-Everyone-Know-It-Was-A-Good-Mushroom/4-Letting-Everyone-Know-It-Was-A-Good-Mushroom-210863.html ;
   Chris Kerr, "How Miyamoto built Super Mario Bros.' legendary World 1-1", Game Developer (2015):
   https://www.gamedeveloper.com/design/how-miyamoto-built-i-super-mario-bros-i-legendary-world-1-1
7. Tracy Fullerton, *Game Design Workshop: A Playcentric Approach* (5th ed., CRC Press, 2024):
   https://www.routledge.com/Game-Design-Workshop-A-Playcentric-Approach-to-Creating-Innovative-Games/Fullerton/p/book/9781032607009 ;
   excerpt: https://gamedeveloper.com/design/book-excerpt-game-design-workshop
8. Iwata Asks, Splatoon, "It Started With Tofu" (Nintendo, 2015): https://iwataasks.nintendo.com/interviews/wiiu/splatoon/0/0
9. Kyle Gabler, Kyle Gray, Matt Kucic, Shalin Shodhan, "How to Prototype a Game in Under 7 Days", Gamasutra (2005):
   https://www.gamedeveloper.com/game-platforms/how-to-prototype-a-game-in-under-7-days
10. Mike Ambinder, "Valve's Approach to Playtesting", GDC 2009 (slides):
    https://cdn.fastly.steamstatic.com/apps/valve/2009/GDC2009_ValvesApproachToPlaytesting.pdf
11. Ken Birdwell, "The Cabal: Valve's Design Process for Creating Half-Life", Gamasutra (1999):
    https://www.gamedeveloper.com/design/the-cabal-valve-s-design-process-for-creating-i-half-life-i-
12. Mikel Reparaz, "Looking back on 10 years of Assassin's Creed" (Jean Guesdon at GDC 2018), Ubisoft News (2018):
    https://news.ubisoft.com/en-us/article/6P2OoMbx17TavKwwHev2eT/looking-back-on-10-years-of-assassins-creed
13. Max Pears, "Design Pillars: The Core of Your Game", Game Developer (2017):
    https://gamedeveloper.com/design/design-pillars-the-core-of-your-game
14. Martin Jonasson and Petri Purho, "Juice It or Lose It", GDC Europe 2012: https://gdcvault.com/play/1016487/Juice-It-or-Lose
15. Jan Willem Nijman, "The Art of Screenshake" (2013), written up by Alex Wawro, Game Developer (2014):
    https://gamedeveloper.com/design/vlambeer-co-founder-shares-advice-on-building-better-action-games
16. Supercell, "Learning from failures" (2026): https://supercell.com/en/news/learning-from-failures/
17. Matt Suckley, "5 lessons from Ilkka Paananen's BAFTA Games Lecture", PocketGamer.biz (2016):
    https://www.pocketgamer.biz/5-lessons-from-ilkka-paananens-bafta-games-lecture/
18. Jakob Nielsen, "Why You Only Need to Test with 5 Users", Nielsen Norman Group (2000):
    https://www.nngroup.com/articles/why-you-only-need-to-test-with-5-users/
19. Clive Thompson, "Halo 3: How Microsoft Labs Invented a New Science of Play", Wired (2007), read on a mirror:
    https://wirednews.pages.dev/2007/08/ff-halo-2 ; Pagulayan et al., "Designing for fun: User-testing case studies",
    *Funology 2* (Springer, 2018): https://www.microsoft.com/en-us/research/?p=588829
20. Stone Librande, "One-Page Designs", GDC 2010: https://www.gdcvault.com/play/1012356 ; slides:
    https://www.slideshare.net/slideshow/one-pagedesigns/13460886
21. Goodhart's law in Marilyn Strathern's wording ("when a measure becomes a target, it ceases to be a good measure"):
    https://en.wikipedia.org/wiki/Goodhart%27s_law
22. Jenova Chen, "Flow in Games (and Everything Else)", *Communications of the ACM* 50(4) (2007):
    https://khoury.northeastern.edu/~lieber/courses/csu670/f08/materials/p31-chen-flow-in-games.pdf
23. Robin Hunicke and Vernell Chapman, "AI for Dynamic Difficulty Adjustment in Games" (about 2004):
    https://users.cs.northwestern.edu/~hunicke/pubs/Hamlet.pdf
24. Riot Games, "Clarity in League" (2021): https://www.leagueoflegends.com/en-us/news/dev/clarity-in-league/
25. Jason Mitchell, "Stylization with a Purpose: The Illustrative World of Team Fortress 2", GDC 2008 (slides):
    https://cdn.fastly.steamstatic.com/apps/valve/2008/GDC2008_StylizationWithAPurpose_TF2.pdf
26. Jerry Zhang, "Anatomy of an Enemy Attack in Dark Souls 3", Game Developer blog (2022):
    https://www.gamedeveloper.com/game-platforms/anatomy-of-an-enemy-attack-in-dark-souls-3
27. Bart Vossen, "Enemy design and enemy AI for melee combat systems", Game Developer blog (2015):
    https://gamedeveloper.com/design/enemy-design-and-enemy-ai-for-melee-combat-systems
28. Martin Pichlmair and Mads Johansen, "Designing Game Feel. A Survey", arXiv 2011.09201 (2020):
    https://arxiv.org/abs/2011.09201
29. Daniel Cook, "Loops and Arcs", Lostgarden (2012): https://lostgarden.com/2012/04/30/loops-and-arcs/ ; "The
    Chemistry of Game Design", Gamasutra (2007): https://www.gamedeveloper.com/design/the-chemistry-of-game-design
30. Tim Ryan, "The Anatomy of a Design Document, Part 1", Gamasutra (1999):
    https://www.gamedeveloper.com/design/the-anatomy-of-a-design-document-part-1-documentation-guidelines-for-the-game-concept-and-proposal
31. Masahiro Sakurai, Famitsu column vol. 490 on hitstop (2015), translated by Source Gaming:
    https://sourcegaming.info/2015/11/11/thoughts-on-hitstop-sakurais-famitsu-column-vol-490-1/
32. Christian Nutt, "The Structure of Fun: Learning from Super Mario 3D Land's Director" (Koichi Hayashida), Gamasutra
    (2012): https://www.gamedeveloper.com/design/the-structure-of-fun-learning-from-i-super-mario-3d-land-i-s-director
33. Apple Developer, "Onboarding for Games": https://developer.apple.com/app-store/onboarding-for-games/
34. Our own evidence: the shift verdicts of 19 to 22 Nov (`docs/shifts/*/VERDICT.md`), the D3 editor report of 22 Nov
    (`docs/shifts/2026-11-22-day/lanes/D3-editor/REPORT.md`), `docs/GAME-QUALITY.md` sections 5 and 13, and N1's
    thirdjam teardown (CASES.md).
35. The owner's thirdjam rulings, distilled by N1 (R-0001 to R-0075, 12-15 Nov 2026, his words verbatim; section 10
    is the ten a method cites first): `docs/research/hockey-teardown/RULINGS.md`; the teardown beside it:
    `docs/research/hockey-teardown/TEARDOWN.md`.
