# K3 shell, round 5: the human on the core's glue

- The pack sends the devices; K1's glue (RinkCore human mode "raw") applies thirdjam's rules. The pack's port of the
  rules, the controls script and the gym's stand-in law are deleted; the gym is the core with the other nine parked.
- Signals 1-4 through the glue: bot_rule_signals PASS (faceoff ignored, the 60-frame cooldown, the intents).
- thirdjam's compiled button resolver = K1's glue on 5,198 of 5,198 frames of a real match (proof/buttons_vs_glue.py).
- FINDING for K1: the pack's recorded raw stream through rink_rawtrace.gd matches the pack's core hash to frame 1,505;
  the first input difference is frame 1,294 (the stick's last single-precision bit), with that frame's devices equal to
  the bit. Both replays agree with each other and are deterministic; the pack is deterministic. Not patched in the pack.
- R restarts through the glue (RinkCore.restart()); bot_rule_restart PASS (240 frames after R = an untouched match).
- The match hash changed because the glue passes the stick in double precision as thirdjam does (my port used single):
  round 4's match first differs at frame 361 with no input field more than 1e-5 apart before frame 564.
- Re-run: camera vs film 0.54 cm PASS; full-match hand 3:1 in 9,071 frames PASS; invariants PASS; record = replay;
  export build + check --no-window PASS (hokej 6e9c32c23eaf3d45 editor = exe).
- No picture changed this round (the input path only); nothing new to look at.
