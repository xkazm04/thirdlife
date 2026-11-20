# L5 hockey-fun: make hockey play like a game someone designed to be fun

Read `docs/shifts/2026-11-21-night/COMMON.md` first: it has the owner's words, the laws, your file column
(`engine/packs/hockey/**` only) and selftest block 650-659.
- **Worktree:** `C:/Users/kazda/kiro/third-life/.claude/worktrees/n21-hockey`, branch `n21-hockey`, base main `3a4580b`.
- **Route:** Opus solo.
- **Time box:** until 06:30.
- **Standups:** in `lanes/L5-hockey/STANDUP.md`; send a message when landable.

## Owner's words
"Minigames are there physically, but not have in design to be actually playable and fun. Example: game design of thirdjam
vs our hockey design (camera, ai, gameplay mechanics)." The owner re-opened hockey for this: it is the first dungeon and
the yardstick the new Designer is measured against.

## The gap list (scout, file:line; verify each)
1. **Camera.** It is fixed top-down, 100 m up at fov 20: `data/tuning.json:10` and `scripts/main.gd:279-292`. A
   `chase_camera` exists (`tuning.json:9`), but only for stills. `ctx.cameras.shake` exists (`engine/kernel/API.md:478`)
   and nothing uses it.
2. **Impact.** Hits are "heard, never drawn" (`scripts/fx/fx.gd:36-38`). There is no hit-stop, shake, slow-mo or replay.
3. **AI.** `scripts/ai/brain.gd` has three roles and no goalies, so an open net can be scored from the face-off dot.
   Difficulty is reaction frames tuned to bot win rate.
4. **Win flow.** It is a bare "WIN / LOSE / DRAW + R" in the centre (`look.gd:92-93`, `main.gd:392-395`). Nothing marks the
   moment of a goal beyond horn, confetti and flash.
5. **First minute.** There is a keys panel and a 10 s auto-start. `drills.json` is bot-only.

What thirdjam aimed for (second-hand; the repo is not on disk): skaters as "the key piece whether the game will play well
and be fun", body checks that land, boosts, arena twists, a following feel camera, and judging on fun.

## Work
1. **Play camera.** A following camera is the default play view. It frames the puck carrier and the attack direction, and
   leads the play at speed so it reads fast. The old top view stays on a key (say which).
   - Tune it by looking: produce a clip, judge it, tune again. Repeat at least 3 times, and keep the clips.
2. **Juice on checks.** Above a closing-speed threshold, a check gets:
   - a hit-stop of a few frames;
   - `ctx.cameras.shake` scaled by the impact;
   - a drawn effect: ice burst and the knocked-down figure reading as down.
   Small bumps stay quiet.
   - Hit-stop must be deterministic in frames, and the hash law holds.
3. **Goalies.** One per side, who:
   - tracks the puck between the posts;
   - can make saves through reach/possession rules;
   - is beatable by a shot from an angle or after a pass across;
   - is still beaten by a perfect hand.
   - Rookie, pro and all-star change the goalie's reaction too.
4. **Goal moment.** A short slow-mo of the shot (frames, not wall clock), a goal card ("GOAL — <scorer>", score), then
   the face-off.
   - **Match-end card:** result, score, the best moment (biggest hit or fastest shot), and "R: rematch / Esc: leave".
5. **First minute.** On entry, a short drill is playable at once: skate to a ring, take a pass (Q), shoot (click) into an
   empty net, then the match. There is a skip key. Use few words: a key glyph and 3-5 words per step.
6. **Gates.**
   - `tl check --tier full --only packs` is green, and every hockey bot passes.
   - The hockey hash changes: say so. "World == alone" must still hold, so also run the `world` step.
   - Re-read the ladder (`tl ladder hockey`) and quote every figure with its hand and seed count. The win rates will
     move with goalies. Report them; do not tune back to the old numbers.
   - An idle hand must still win 0.

## Acceptance
- [ ] Packs and world gate steps are green; the counts are >= base; any moved test expectation is named, with why.
- [ ] Clips of 20-30 s each from a window (not headless):
  - the follow camera in open play;
  - a big check with hit-stop and shake;
  - a goalie save and a goal with the goal moment;
  - the first-minute drill;
  - the match-end card.
- [ ] Ladder table (rookie, pro, all-star × newcomer, regular, sharp, perfect, idle) for the new hockey, with seeds.
- [ ] The README has a new "Fun" section: what each ingredient is and the key that turns it off for comparison.
- [ ] REPORT: the three things that would make it more fun next, judged by your own play in a window.
