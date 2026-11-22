# N1 interim (for N2 and the Director): why thirdjam plays and our hockey does not

Full text with file:line on both sides: `docs/research/hockey-teardown/TEARDOWN.md` (this tree). Media and the probe's
numbers: `docs/research/hockey-teardown/media/` (`probe.md`, clips of 20 s, sheets). Written 20:10, 22 Nov; updated as the lane goes.

## How it was read
- thirdjam cloned read-only (`.tl/thirdjam`, HEAD 8dc713c6) and **run on this machine** from a built thirdjam tree of 15 Nov
  (copied to `.tl/tj-run`; UE 5.9 `-game`, its own measured person hand `jam.ScriptHuman 2`, stills from its viewport).
- Ours played in a window (`tl play hockey` untouched; ladder bots through `TLHand`), and measured "as b0 meets it" by a probe
  test in a copy of the pack (`.tl/probe`, 20 seeds a cell).

## The top 10 (ranked by what each costs the player)
1. **There is no ice.** Bodies of radius 0.879 m (figures drawn 2.2x, "our 4.4 m figure") on 60 x 30 m: the rink is 34 body widths
   long (thirdjam 112, a real rink about 100). 4+ of the 6 field skaters are within 5 m of the puck in 15-16 % of play. The scale
   came from a drawing fix on 16 Nov (H7), never from a design decision.
2. **Your teammates refuse to play.** Mates shoot only within 4 s of your own pass or shot and hold 8 m out of the net, a rule made
   so an idle hand loses the ladder. thirdjam's owner called the same thing "disengaged"; thirdjam's mates shoot and drive the net.
3. **The camera follows the puck, not you; the stick (the cursor on the ice) moves when the hand does not.** thirdjam: a chase
   camera behind you and an aim anchor, both after the owner's complaints.
4. **The puck hardly slows (no drag; the ice takes about 1 m/s2, measured) and passes leave at a fixed 18/23 m/s**; thirdjam's puck slows and its pass is solved to arrive at
   8 m/s. We patched the consequences with a dozen own-goal guards.
5. **The game keeps stopping:** 36-s periods, a whole-game freeze on hard hits near you 3.8 times a minute, goal holds, replays.
   thirdjam: one run to three goals.
6. **The figures glitch, and our own README lists it** (a statue goalie, sticks through boards, overlaps, falls under the hitter).
   The owner calls thirdjam's graphics "bugless".
7. **Hits decide the game and are drawn loudly** (rings, bursts, punches): the owner had ruled those out in thirdjam on 14-15 Nov.
8. **The bots read the play 5-18 frames late and decide at 4 Hz; nobody but you sprints.** thirdjam: every frame, no delay,
   "a level is easy by clumsiness, never by absence" (measured speeds in ours are close: this costs less than it sounds).
9. **Shooting asks for precision the screen cannot give** (exactly at the cursor through a moving camera, 24 m/s); thirdjam snaps
   to the net inside 8 deg and shoots at double speed by the owner's order.
10. **The screen stops explaining itself after the first key** (key lines vanish; no radar, no off-screen markers); thirdjam keeps
    a controls panel, a chevron and a radar all match.

## The finding under all ten
By thirdjam's own first-five-minutes measures, ours scores **better** (first touch 0.6-0.7 s vs 1.8 s; carry median 1.2-1.5 s vs
0.87 s; puck on your blade 18-21 % vs 10 %). The owner calls ours garbage. **Our measures cannot see what he sees.**

## Process lessons (for N2's method)
1. **A game has a size, and someone must own it**: a one-page "world in the player's units" (body size, arena in body lengths,
   speeds in body lengths a second, camera distance in body heights) before any mechanic; changing one is a design change.
2. **A metric a scripted hand can pass is not evidence of fun.** Written down four times (thirdjam R-0067 "The operator's eye is
   the bar", memory 15 Nov "His hand is the bar", memory 21 Nov "judge playability by hand, not by bot win rates") and lost each
   time it crossed into a brief: N3's brief made five bot metrics its acceptance the same night.
3. **A rule invented to pass a metric is a design decision and must face a person** ("mates set you up" for the idle hand; "keep
   the body-check rate" vetoed N3's anti-scrum rules).
4. **Ports move numbers, not experience**: L4 ported thirdjam's contact and skating line by line into a world three times smaller,
   with another camera and goalies. Port the frame of reference and the reasons first, numbers last.
5. **The owner's rulings are design assets**: thirdjam has 75 with his verbatim words; L5's brief worked from "second-hand; the
   repo is not on disk" and put back what he had ruled out.
6. **"Fun" is not a list of juice**: hit-stop, shake, burst, replay on a broken core.
7. **Research that does not read the last game is rediscovery**: HOCKEY-ARCADE.md prescribed perception lag as difficulty,
   which thirdjam had measured as wrong and dropped.
8. **The first five minutes must be a measured, watched product**: thirdjam had a standing design critic ("the ten things a
   first-time player feels in five minutes, ranked") and an "eye" lane whose list outranked the lanes' own bars.
9. **Breadth hides the core** (modes, abilities, menus while the base match is unplayable; both games did it).
10. **One hand on the controls per change**, and the owner plays the package.
11. **Our briefs accept proof that a mechanic exists** (clips of "a poke that frees the puck"), not proof that a minute of a match
    is worth playing. The owner: "The fact players can skate and shoot puck does not mean we delivered entertaining hockey
    experience."
