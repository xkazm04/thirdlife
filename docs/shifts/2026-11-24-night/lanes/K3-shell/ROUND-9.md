# K3 shell, round 9: the whole picture

- K2's contact wired as verb_gym.gd: the hit read after the show's after_pawns, all four bus events, set_rink once,
  set_puck from the drawn puck before each tick, the carried puck on its socket after the tick. Core hash unchanged
  (ab881a00fb9af8ef).
- Inside thirdjam's hall the rink draws only RinkActor's sections 2 and 3 (faceoff circles, dots, creases, trapezoids,
  centre dot) in thirdjam's colours from arena.json; the hall's ice paints the rest. The run's state hash moved only
  because the kit ice's physics body is gone (proven by putting it back).
- Solo class p99: 8 ms, `invariants.solo_frame_budget`. hokej: p99 3.89 ms, p50 3.19 ms.
- Looked at beside thirdjam (r9_*): the faceoff is close to a copy. Most visible differences: shadows (thirdjam's dark and
  long, ours faint), the six-row controls panel, the knockdown (thirdjam's man flies, ours falls flat), the small puck
  without the faceoff glow, the ice a shade brighter.
- Export check headless PASS (hokej bf0f453fe32b7bb2 editor = exe). Window: 5.88 ms a frame (capsules 3.21 ms).
