# The owner's thirdjam rulings, distilled (standing owner rulings for third-life game work)

Source: thirdjam `contracts/RULINGS.md` (R-0001 to R-0075, 12-15 Nov 2026), read in full from the read-only clone
(`.tl/thirdjam`, HEAD `8dc713c6`). Lane N1, night of 22-23 Nov. Companion to `TEARDOWN.md`.

**How to read this page.**
- **Owner, verbatim**: his own words, copied exactly as the thirdjam Director recorded them, typos included. Only these are his.
- **Ruling**: what thirdjam's Director decided from those words. Where the Director marked a reading of his own, this page says
  "Director's reading". The owner could overturn any ruling with a word (R-0064, R-0065).
- **Scope**: **ANY** = a ruling about how a game is made, judged or presented, which applies to every third-life game (the
  editor's games, Foreman packs, house games). **HOCKEY** = specific to a hockey or team-sport game, though often a pattern for one.
- **Ours today**: whether `engine/packs/hockey` on main (`1fa3b56`) follows the ruling. Evidence: `TEARDOWN.md`.
- Most of the 75 rulings are plumbing: merge windows, lockstep protocols, prize texts, licences, keys. Those are left out; the
  list at the end names them.

## 1. The bar: who judges a game, and with what

| R | Owner, verbatim | Ruling | Scope | Ours today |
|---|---|---|---|---|
| R-0032 (12 Nov, after H18) | "Difficulty does not matter if the game is trash." | Every control proof comes from a packaged build through the real input path, not from the editor; no calibration verdicts are asked of the owner until a person can play; the playtester keeps measuring in the background. | ANY | Breaks: no hockey verb was proven through a person's input path in the exe. |
| R-0067 (14 Nov, after H34) | "the game itself does not look bad, but effectively is unplayable" | Point (2), the Director: "**The operator's eye is the bar.** The day measured the game with scripted players and a win-rate ladder and shipped a game its player called unplayable: the ladder was on target at every level while the skaters looked asleep, the passes died and the hits missed. Tonight every lane states what a person sees or feels, measures that, and proves it moved." The ladder is set last, on the game that plays. | ANY | Breaks: N3 (22 Nov) was accepted on five bot metrics and the ladder. |
| R-0068 (15 Nov, 00:00) | "last night ahead of us, keep loops with perfecting the game similarly to last night with focus to transforming today's found weaknesses into strengths." | Point (3): an "eye" lane plays what he will play and lists what a stranger sees; **"The eye's list outranks a lane's own bars."** When the eye says a stranger sees a fault, the owning lane takes it before its own next item. | ANY | Breaks: we have no eye lane. |
| R-0069 (15 Nov, after "H39") | "Still two same issues 1. puck is not controlled by player if in his circle area, then player runs right through the pack and still does not have control 2. Crosscheck still displays blue line/rectangle in front of player. This should player never see" | Point (1): "The night's measures called both fixed and his hand says no." Each fault is first **reproduced as he meets it** (a stick aimed away from the puck; the package's own look, from the game camera) and shown in stills before a cure is written; a cure is accepted only on the same stills. | ANY | Breaks: our hockey's faults are found by idle-hand wins, not by reproducing his play. |
| R-0069, addition of 11:05 | (none: Windows' own start record showed he had played H34, not H39) | Notes are read only after confirming **which build he actually started**; every release writes a launcher to the newest package and HOME shows the build's name in a corner. | ANY | Unknown for our exe: check that a build tag is on screen. |
| R-0043 (13 Nov) | "please reconcile the plan as previous model may not lead into best possible directions we can achieve" | No package without an **acceptance run** that plays the first five minutes through the cursor and the buttons, pass or fail per verb: "H19 to H24 shipped unable to shoot or pass while aiming because no gate drives the real input." | ANY | Breaks: our gate drives the hockey only through injected actions. |
| R-0029 (12 Nov) | (Director's ruling) | The difficulty curve is measured with a **person-like playtester through the real input path** (novice, regular, good), not the scripted human; targets novice 85 % at rookie and scoring inside two minutes, regular about 50 % at pro, good about 25 % at all-star. | ANY | Half: `TLHand` is a person-like hand, but it drives a bot that reads the true puck position. |
| R-0060 (14 Nov) | (Director's ruling) | When the measuring instrument changes, the ladder is **not** re-set silently; both columns are reported on the same commit, and the owner says which player he is. | ANY | Follows in spirit: our README quotes every figure with its hand. |
| R-0021, R-0024 (12 Nov) | "all your judgement can only improve and I am fine with that." | Until the game is playable and watchable, **calibrations need no owner approval**: the Director decides and records them; taste items (lines, names, art) go to the owner as review pages; milestone playtests are his. | ANY | Follows. The risk it carries: calibrating a game nobody plays (thirdjam R-0067, our hockey). |

## 2. Scale, the arena, the team size

| R | Owner, verbatim | Ruling | Scope | Ours today |
|---|---|---|---|---|
| R-0004, R-0010 (12 Nov) | "lets then keep 90x45 as default" | The default rink went from 120 x 60 to **90 x 45 m at skater speed 11**, chosen on **measured pacing** (a goal every 70 s, 16 of 20 bot matches finishing, the two-minute first play), with 120 x 60 kept as a cut. | HOCKEY (the method, size chosen by measured pacing, is ANY) | Breaks: our 60 x 30 m rink with 2.2x figures is 34 body widths long against thirdjam's 112. Nobody chose it. |
| R-0041 (13 Nov) | "I feel like the arena can be built for 5v5 game" | **5 v 5 is the regular game**; "the rink stays 90 x 45 unless 5 v 5 crowds it (then 100 x 50 by measurement)". | HOCKEY (re-measure the arena when the head count changes: ANY) | Breaks: three a side plus goalies; the crowding was never measured until this lane (4+ of 6 within 5 m of the puck in 15-16 % of play). |

## 3. Camera and aim

| R | Owner, verbatim | Ruling | Scope | Ours today |
|---|---|---|---|---|
| R-0032 (12 Nov) | "Camera does not stay where player moves, mouse is not binded to work with the stick, the stick blinks back and forth." | Lane A49 owns input, the control path, the follow camera and the stick aim; five root causes fixed in a packaged build (among them "the camera's lead and lift turned away from the player"). | ANY | Breaks: our camera frames the puck, not the player. |
| R-0038 (13 Nov) | (Director's ruling, from a lane's finding) | **The camera stays bound to the human.** "No camera lead, lift or turn is added that moves under the cursor while the player aims"; what is off screen (the puck, its carrier, the far net) is pointed at by the HUD; a camera that leaves the human (a replay, an end-zone shot) is a separate mode, never the play camera. | ANY (any game where the cursor aims in world space) | Breaks: our play camera follows the puck with leads, a widening and a punch zoom; the stick is the cursor's point through it; no off-screen pointer. |
| R-0064 (14 Nov, after H31) | "Camera around arena borders is autocorrecting unnaturally making hard to recalibrate" | Point (4): "**no correction the player did not cause**": the picture near the boards moves only as fast as the player does. Later the aim got an anchor: a still hand keeps its point on the ice through camera corrections. | ANY | Breaks (as above). |

## 4. Controls

| R | Owner, verbatim | Ruling | Scope | Ours today |
|---|---|---|---|---|
| R-0013 (12 Nov, first playtest) | "Control: Ability to control stick with mouse and without puck with the mouse. ... The tackles and hard fouls will be key for dynamic gameplay as now it is hard to take puck from another player." | **The stick is the core verb**, aimed by the mouse (the right stick on a pad), with clean stick tackles (poke, lift) and the body check. | HOCKEY | Follows. |
| R-0032 (12 Nov) | "Player should have option with mouse to tackle or cross-check instead of the shift. Using shift rather for sprint." | **The bindings are the owner's**: the mouse aims the stick, left shoots (hold to charge), right tackles, Shift sprints. | ANY (bindings are the owner's to set) | Follows (H7 mouse buttons, Shift sprint). |
| R-0064 (14 Nov) | "Key bindings: Possibility to rebind needs to be there. And rebinding: a) Cross check on Left mouse. available only if plaeyr not on puck, if yes then shoot b) Right mouse if on puck: Pass. Hold for saucer pass c) Crosscheck should be holdable so player with speed momentum can run with held crosscheck into another player" | Contextual buttons as written; **every verb can be rebound**, saved, and the on-screen hints come from the live bindings, never from fixed text. | ANY (rebinding; hints from the live bindings) | Half: the contextual buttons follow; no rebinding; key hints vanish after the first press. |
| R-0065 (14 Nov) | (Director's ruling) | **A button held across a change of possession does nothing until released and pressed again**; a held charge dies with the possession. | ANY (any context-dependent button) | Follows (`tests/bot_buttons.gd`). |

## 5. The puck: possession, passing, shooting

| R | Owner, verbatim | Ruling | Scope | Ours today |
|---|---|---|---|---|
| R-0011 (12 Nov) | (Director's ruling, from lanes A3 and A10) | **Puck drag 0.5 adopted**: "carrying is the fun", +45 % touches, 40 % shorter matches. | HOCKEY | Breaks: our drag is 0 (the ice alone takes 1.0 m/s2). |
| R-0021 (12 Nov) | (his one comment on the feel page) | "the stick must read as a hockey stick (shaft and blade), the figures need hands on it, and a carried puck must stay on the blade". | HOCKEY | Follows (the carry on the drawn blade, H9a). |
| R-0048 (13 Nov) | (Director's ruling, from the design eye's REVIEW-1) | **A carried puck leaves its carrier only by an action** (shot, pass, poke, lift, a check that loosens it, his own release), never by an unpressed blade or a body's touch; never to a teammate by touch. | HOCKEY (the pattern: a loss must have a readable cause: ANY) | Follows. |
| R-0049 (13 Nov) | (Director's ruling, from device B's play-through: "the human knocked down every 7 seconds", "the carrier losing the puck 1.4 times a second") | "A tackle is an event, not a rhythm": a **release grace** after a get-up and a **take grace** after winning the puck. | ANY (an action game's hits are events, not a rhythm) | Follows in rules (120-frame get-up grace, 24-frame poke immunity); the rate is still high (3.9-4.6 knockdowns a minute). |
| R-0067 (14 Nov) | "They want to pass but no pass reaches the end (inprecise direction or speed), passess need to be able to be hold enough to cross 1/3 of arena length on max, shoot speed should double 2. Puck does not stick with players, it moves through them without locking" | Point (4): "**His three orders that are numbers are taken as given**: a full-hold pass crosses at least a third of the rink's length; the shot's speed doubles; the hit lands when a person facing a man presses. Where an order breaks something measurable, the thing it breaks is fixed." | ANY (his numbers are taken as given; what they break is fixed) | Breaks: our pass is a fixed 18/23 m/s with no hold; our shot 24-32 m/s. |
| R-0069 (15 Nov) | "puck is not controlled by player if in his circle area, then player runs right through the pack and still does not have control" | Point (2): "**The puck inside his ring is his.** Whatever his stick points at: a loose puck that is inside the ring drawn under him, or that he skates through, becomes his on that frame, at any speed he can skate". | ANY (what is drawn as his reach is his reach) | Half: ours takes a puck in the ring only under 15 m/s relative; 15-20 bobbles; faster passes through. |

## 6. Contact, and what is drawn at a contact

| R | Owner, verbatim | Ruling | Scope | Ours today |
|---|---|---|---|---|
| R-0045 (13 Nov) | "If tackle is done between players going to same direction with similar speed, the impact is almost none next to a tackle or cross-check from player facing full speed towards the player. Applying principles of physics law will make the game much more natural and logical." (thirdjam `docs/VISION.md`, law 1) | Contact by inertia: closing speed x mass against stability; three outcomes; **the attacker pays**; **the carrier cannot hit**. | ANY (contact obeys momentum, readable from the bodies) | Follows (L4 port). |
| R-0060 (14 Nov) | "Stationary player can resist most of side tackles" | A standing skater without the puck holds a side hit. | HOCKEY | Follows (the standing brace). |
| R-0064 (14 Nov) | "Animations of crosscheck and body check are short and not clear, may need today to evolve" | Point (5): longer, clearer takes (a wind-up an eye catches, the contact, a follow-through); the game holds the hit a beat. | ANY (a hit must read at play distance) | Half: L4b's 12-frame wind-up on the clip's hit frame; the owner has not judged it. |
| R-0067 (14 Nov) | "Tackles/Crosschecks are difficult to land as they need to land to thin space of the player, crosscheck has bug in animation displaying technical blue rectangle instead of animating player with stick into its position. Tackle is also unrecognizable and animation too quick" | Point (4): "the hit lands when a person facing a man presses"; point (6): the marks go; the figure does the hitting. | ANY | Unmeasured with a person's hand in ours. |
| R-0069 (15 Nov) | "Crosscheck still displays blue line/rectangle in front of player. This should player never see" | Point (3): "**Nothing technical is ever drawn on or in front of a skater.** No line, bar, rectangle, arc or strip that belongs to the game's mechanics ... only the figure and its stick. What he sees must be found by looking, not by listing switches." | ANY | Breaks: an orange ring under every downed man; bursts and chips at hits; rings under carriers. |
| R-0070 (15 Nov) | "no aim line needed, the player animation should reflect the crosscheck movement and that should be all" | The figure's animation is the whole message at a cross-check or a check, his or a bot's, landed or missed: no arc, chevron, burst, down ring, swell of a ring, plate. The control legend stays. The animation must therefore read by itself at game distance. | ANY | Breaks (as above). |

## 7. AI and difficulty

| R | Owner, verbatim | Ruling | Scope | Ours today |
|---|---|---|---|---|
| R-0041 (13 Nov) | "I would reframe also the difficulty direction to focus more on aggressivity. ... tackles and cross-checks can be vital for fun gameplay which will become on harder difficulty a beating massacre." | **The difficulty ladder is an aggression ladder**: rookie bots rarely check, pro check as a matter of course, all-star hunt the carrier. | HOCKEY (difficulty by behaviour, not by stats: ANY) | Half: our levels differ by reaction, thrust and noise, with checks by closing speed per level. |
| R-0041 (13 Nov), R-0045 (13 Nov) | "skater with puck will need slight speed reduction and inability to sprint, to incentivize passing with other players and ability to defend"; later "Sprint should be allowed but with caveats: if puck is far from player easier to get by others, and sprint speed of defenders should be always higher." | The carrier is slower; the carrier may sprint, but a defender's sprint is always faster (VISION law 4, which replaced R-0041 point 6). | HOCKEY | Follows the numbers; our bots never sprint at all. |
| R-0045 (13 Nov) | "AI should know going all the way forward will lead to failure. We should establish hockey principles into the game and AI: awareness of free space around, and free positioning of team players to decide when to push solo, when to pass. Based on position of other players there should be decision making logic different during attack and defense." | VISION law 2: bots read open ice; carry or pass by it; an attack shape and a defence shape and the two transitions; "the level decides how well a bot executes them, not whether it knows them". | ANY (bots play by the genre's principles; the level changes execution) | Half: our utility AI and roles exist; the scale crowds them into scrums. |
| R-0067 (14 Nov) | "1. AI is the main flaw, it does not try to play hockey to achieve a goal, all teammates/oponents are not interested in game, disengaged." | Point (3): "**A level is easy by clumsiness, never by absence.** Rookie's bots want the puck and the net as pro's do; they are slower to release, wider in aim, later to read." | ANY | Breaks for teammates: ours refuse to shoot unless the human just passed or shot. |
| R-0047 (13 Nov) | "difficulty setup fine for me" | The ladder of R-0046 stands. | HOCKEY | n/a |
| R-0064 (14 Nov) | "Skaters without puck should be 15% faster than now" | Free skaters x1.15, bots and human alike; law 3's stop distance and the ladder re-read after it. | HOCKEY | Follows (`free_speed_mult` 1.15). |

## 8. Identity, look, menus, words

| R | Owner, verbatim | Ruling | Scope | Ours today |
|---|---|---|---|---|
| R-0012 (12 Nov) | "each dimension we touched is in very basic game design and gameplay state ... master game on P2 ... let players design custom boosts, rules and aspects" | Depth on every dimension already started; "Ahead of schedule" retired as a status word: "the milestones are met, the dimensions are first drafts". | ANY | The same is true of ours: modes and abilities on a first-draft match. |
| R-0013 (12 Nov) | "HUD elements and typography are ugly to look and read ... Face-off needs to be implemented to start the game. / No need to mention Director's cut in the name of the game." | A UI pass with generated art; a real face-off; the name is HOKEJ. | ANY (the HUD is judged as type and art, not as text on screen) | Half: our face-off exists; our HUD is plain plates. |
| R-0021 (12 Nov) | "We are pushing the theme too far, it should be hockey first theme, keeping director cut in the menu for its adjustments." | **The game is the genre first**; the jam's theme lives in the menu and the Designer, not on the ice. | ANY | n/a for the house game. |
| R-0036 (13 Nov) | "P4 descoped as it seems the realistic output is not worth the chase. P3 remains target to master - physics and animations especially around collisions, gameplay mechanics, director's choices -> ways/modes to change character of the game for creative variations of possibilities." | The look stops at the clay tier; the work in value order is collisions, gameplay mechanics, then modes. | ANY (gameplay over fidelity; collisions first) | Our order was the reverse: look, fun layer, modes, then mechanics. |
| R-0041 (13 Nov) | "This can make whole concept of the game more raw and brutal promoting into its brand (logo, banner, tone of the game)." | A raw, rough brand inside the teen rating (no gore, mild words at most one line in ten). | ANY (tone inside the rating) | n/a |
| R-0064 (14 Nov) | "Menu HUD is a mess, leave concept of director's cut and try to create profi NHL-like menu UI and landing experience ... Special boosts are not seen on ice, not seen equipped on players ... Puck's white outer ring for visibility can be 50% thinner ... Nice to have: short celebration animation set after a goal, HUD middle screen large banner saying 'Goal'" | A professional sports-game front end ("NHL-like" is a standard of finish, not a look to copy: no league or broadcaster likeness); boosts seen on the ice and on the skater; a goal is an event. | ANY (finish of a commercial game; nothing copied; pickups visible; a goal is an event) | Half: our goal card and replay exist; boosts are beacons. |
| R-0069 (15 Nov) | "For modes selection the previous images are deformed, rather create list with titles on left side with mode names sorted asc, and preview on right half of the screen." | MODES is a sorted list with a whole, unstretched preview. | ANY | n/a |
| R-0015, R-0007 (12 Nov) | "you can be also more offensive with the mockery. The current scripts are too safe and childish" | Barks at a harsher register inside the rating. | ANY (voice and commentary) | We have no commentary. |

## 9. Scope, rhythm of work, stabilization

| R | Owner, verbatim | Ruling | Scope |
|---|---|---|---|
| R-0047 (13 Nov) | "We need to iterate on top of existing concepts and make evolution after evolution in tracks where possible. Next 24h will be key ... RAM 60-80% used, Fable agents thinking how to improve game mechanics and design, executing in blender. Opus subagents to improve the codebase and quality of implementation, Sonnet subagents to run tests and harden the game." | Ten standing evolution tracks, among them **F0 the design eye** (a critic who plays each build as a first-time player and ranks the ten things he feels in five minutes). | ANY |
| R-0056 (14 Nov) | "keep the plan and same good evolutionary effort until 10:00am, I will then play the game and set priorities for last 24h" | Work runs to his play; his play sets the priorities. | ANY |
| R-0073 (15 Nov) | "There are 9 hours until submission, we can run current tracks 2 more hours, then spend 3 hours on testing/fixing/stabilizing where possible." | A fix lands only if it cures a fault seen in the candidate package and is proven on the same reproduction; nothing is improved after the stabilization line. | ANY |

## 10. The rulings a game-design method should cite first (N2)

1. **The owner's eye is the bar**; a lane states what a person sees or feels and measures that (R-0067 point 2).
2. **Reproduce as he meets it** before a cure, accept the cure on the same reproduction (R-0069 point 1).
3. **An eye lane's list outranks a lane's own bars** (R-0068 point 3; the design eye of R-0047).
4. **His numbers are taken as given**; what they break is fixed (R-0067 point 4).
5. **A level is easy by clumsiness, never by absence** (R-0067 point 3).
6. **Nothing technical is drawn on or in front of a figure**; the animation is the message (R-0069 point 3, R-0070).
7. **The camera stays bound to the player and never moves under his aim**; the HUD points at what is off screen (R-0038, R-0064 point 4).
8. **The arena's size is chosen by measured pacing**, and re-measured when the head count changes (R-0010, R-0041 point 2).
9. **Proof comes through the real input path in the packaged build** (R-0032 point 3, R-0043 point 1).
10. **Gameplay over fidelity; collisions and mechanics before modes** (R-0036), and **the genre first, the theme in the menu** (R-0021).

## Left out (plumbing)

R-0001 to R-0003, R-0005, R-0006, R-0008, R-0009, R-0014, R-0016 to R-0020, R-0022, R-0023, R-0025 to R-0028, R-0030, R-0031,
R-0033 to R-0035 (figure, goalie stance and puck height: technical answers to his notes, summarized under 4-5 where they matter),
R-0037, R-0039, R-0040, R-0042, R-0044, R-0046, R-0050 to R-0055, R-0057 to R-0059, R-0061 to R-0063, R-0066, R-0071, R-0072,
R-0074, R-0075: merge windows, protocols, the ladder's sets, the release chain, prize texts, licences, keys, the submission.
Process guards from R-0050 (a detached HEAD, a script edited while it ran, `-Multiprocess`, batched landings) are already in
third-life's memory and CLAUDE.md.
