# "a fight in a colosseum": two real Designer briefs, judged against the fun checklist

Two `foreman new` calls, Designer only, no build (`--adapter claude-cli --model opus`, subscription billing), on
20 Nov between 20:41 and 20:47. Files: `brief-colosseum-standard.json`, `brief-colosseum-crazy.json` (brief, estimate,
attempts with tokens and time). The raw jobs and transcripts are under the worktree's `.tl/designer-site/`.

| | standard | crazy |
|---|---|---|
| prompt | iteration 0 | iteration 1 (word-limit targets) |
| attempts | 2 (first sent back: 7 word-limit overruns) | 1 |
| tokens in / out | 19,031 + 47,195 (22,327 cache read) / 10,875 + 11,787 | 19,287 / 11,163 |
| wall time | 116 s + 100 s | 113 s |
| pitch words | 16 | 17 |
| aspects | 6 | 6, one crazy (`runaway_chariot`) |
| longest title / line / detail | 3 / 10 / 47 words | 3 / 9 / 50 words |

## The checklist (my reading; "yes" means concrete in the brief, with numbers or an engine call)

| Ingredient | standard | crazy |
|---|---|---|
| The verb | yes: a shield bash (0.25 s lunge at 10 m/s, counter on a wind-up) | yes: the same bash, plus guard |
| Camera serves the verb | yes: chase over the shoulder, lock-on to the rival, framed at 0.26 | yes: orbit at 35 degrees, yaw eased 8 %/frame toward the rival, framed at 0.26 |
| Juice on the verbs that matter | yes: landed bash, down, crate, finishing down each with shake, burst, sound, hit-stop; a miss gets a puff only | yes: whiff, landed, guarded, wall splat, pillar break, bout-winning fall; squash on the victim |
| Rivals with character | yes: Brutus (stamp tell), Vex (circles left), Magnus (head-dip, double charge); scoring and beaten reactions | yes: Brutus, Lucia (circles left), giant Magnus (only walls drop him); reactions both ways |
| First minute teaches by playing | yes: 10 m from Brutus, one hint line, his first charge after 4 s so a counter lands within 10 s | yes: 6 m from Brutus, one hint line, a slow first tell so a sidestep splat lands within 10 s |
| Stakes | yes: a three-rival ladder, CHAMPION OF THE SAND, a champion time to beat | yes: the ladder for freedom, best ladder time and best crowd peak kept |
| Intensity curve | yes: calm open, crowd favour rising, the lion at 25 s left, sudden death | yes: crowd meter and chariot pressure, chants at 20 s, chariot nonstop, sudden death |
| One twist | yes: the lion gate hunts whoever leads | yes: crumbling pillars (rubble removes cover); the crazy aspect on top |
| Wow (deeper than the words) | yes: a crowd-favour system, named champions with tells, a lion | yes: tomatoes from a bored crowd, a runaway chariot, crumbling pillars |
| Alternatives are other games, not tweaks | yes (spear thrower, chariot rammer; five in a row, two at once, your own shadow) | yes (club swing, net and pull, sumo ring; spike walls, trapdoor pits) |
| Buildable with TL* | yes: TLBiped down/shove, TLSteer, TLFracture crates, TLHud.add_bound, TLVfx.trail | yes: TLVehicle on TLSteer.keep_lane for the chariot, TLSpawner tomatoes, body_scale 1.6; one misuse: "difficulty read through TLHand" (TLHand is a test hand) |

## Crazy against the rule
- It keeps every word: still a fight in a colosseum, the same depth as standard.
- One crazy aspect, marked `crazy: true`, removable in one tap: a driverless chariot that laps the arena every 25 s
  and downs anyone it touches (your bash into its path counts as your fall). Buildable (TLVehicle + keep_lane).
- What I would change, and did (prompt iteration 2, NOT measured by a third real call: the brief allows two): the
  chariot is a hazard, the same kind of thing as the standard design's lion. Iteration 2 tells crazy mode it is "not
  the standard twist made bigger" but a bent rule (what scores, who you control, what a hit does, what the place or
  the audience does), and tells the Designer that TLHand is not game AI. The Director's crazy proof job is the first
  real run of iteration 2.

## Prompt iterations
0. The fun-first rewrite (checklist, wow example, aspects, creativity, feasibility from API.md sections 0/12/13/17,
   kit parts, cards' fun lines).
1. After the standard call: hard word-limit targets ("aim for 2-3 / 6-10 / 30-50 words; one word over sends the
   whole answer back"). Measured: the crazy call passed on its first attempt (standard needed two).
2. After the crazy call: crazy = bend a rule, not a bigger hazard; TLHand is not AI. Unmeasured.
