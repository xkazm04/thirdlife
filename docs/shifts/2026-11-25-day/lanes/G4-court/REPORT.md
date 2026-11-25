G4 Half-court 3 v 3: report (day of 25 Nov 2026). Details are in PROOF-G4.md; stills are in stills/.

Acceptance:
- v0.1.0 plus four change rounds: partly met.
  - v0.1.0 at 21:34, v0.1.1 (spacing) at 22:26, v0.1.2 (camera) at 23:18.
  - Two change rounds, the Director's cap for tonight; not four.
  - Before v0.1.0 there was a clear stop with evidence (rounds 1-2).
- blocked-editor lines: met. STANDUP.md has 11; most are fixed today by H1 and H2.
- PROOF-G4.md and stills: met (26 JPGs, 17 MB in the lane folder).
- Best version in the menu: met. v0.1.0 is in the owner's menu (.tl/proof-games/court_v010, the Director). My tree's
  list .tl/menu/dungeons.user.json points at v0.1.2.
- "landable G4" after each round: met.

Gates: tl check --tier fast PASS (arch 12/12, assets 4/4, cards 3/3, devx.test 229/229, foreman.typecheck clean).
No code changed: lane docs and stills only.

Changed files: docs/shifts/2026-11-25-day/lanes/G4-court/{PROOF-G4.md, STANDUP.md, REPORT.txt, stills/*.jpg}.

Look first:
- stills/compare_target_hokej_v010_v012.jpg (the target, hokej, v0.1.0, v0.1.2).
- stills/strips_v010_vs_v011.jpg (spacing before and after).
- The game: .tl/jobs/half-court-3-v-20261125-1/promoted/game.half_court_3_v@0.1.2.

Main finding:
- The route to a first version took 9 h and needed four editor fixes a person could not make (the budget class, hockey
  rows in the critic, scope by a person's yes, the hand-check gate).
- After that, the change box converged fast: two sentences, about 30 min each, gave the target's camera and a spaced
  floor.
- Verbs and bodies are not reached yet.

Questions for the Director:
1. Should every change re-run all 40 hand seeds (17 min of each 30-37 min change)?
2. Should a builder answering a camera change be allowed to change a test's input policy (tests/support/hand.gd)?
3. Does the art_pass critic still name hockey contact rows after H1e (events 412, 443)?

Next three things for this lane:
1. A change for readable verbs: a visible screen plant and snag, a swat that lands on the ball.
2. A change for distinct players in jerseys, no backpacks.
3. A change for brick arches and autumn-yellow trees; then play v0.1.x with a person's hand in a window.
