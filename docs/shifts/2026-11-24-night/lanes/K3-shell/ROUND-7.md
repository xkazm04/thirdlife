# K3 shell, round 7: the budget class, the chevron on the head, the HUD on film

- invariants.gd: a dungeon with no village plot is held to `invariants.solo_budget` (p50 8.0 ms); a village pack to
  `invariants.many_budget` (1.0 ms), as before. Test: selftest `budget.class` (12 checks). hokej invariants PASS: solo p50
  2.16 ms, stage p99 3.44 ms (budget 4), determinism ad03a2add6ce42c1, the bot twice 4685cd21e60096f0.
- The YOU chevron and tag: the figure's head socket height (thirdjam's HumanHeadWorld, MarkerLiftCm -18) goes to K5's
  layer through `screen.view.head_m` before the existing frame_of call; the XY stays K5's (the skater's point).
- Film with the HUD (r7_sbs_*): it reads as thirdjam's (card, plates, dial, rings, markers, radar). Rejected: the
  chevron sits on the helmet where thirdjam's floats above (head_socket height, K2); a six-row controls panel where
  thirdjam shows one line (K5); no barks (K5/K6); the carried puck and contact (K2's next round).
- Export check headless PASS (hokej 6e9c32c23eaf3d45). Window: HUD + figures 6.13 ms a frame, HUD + capsules 3.70 ms.
