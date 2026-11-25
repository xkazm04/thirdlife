# K2 figure, round 4: the contact, the hit read, the puck in the picture (23 Nov 2026, 21:44 to 22:20)

## What stands

- **The contact is in the figure**, both sides, in one landing: `tl_rig_skater_whip.gd`, `tl_rig_skater_falls.gd`,
  `tl_rig_skater_contact.gd` (the figure's `takes` chain: Puck <- Whip <- Falls <- Contact). Attacker: the body check
  in three sizes by the closing speed, its wind-up takes (SetWindupTakes, PlayCheckWindup with the held first key),
  the bus's check cut, the cross-check's wind, hold layer, release and whiff, the check's miss and whiff. Victim: hit
  reactions (three directions), stumbles stretched over their frames, knockdowns (four directions, three sizes, the
  spin variants), board falls, the lie loops entered on the key that ends where the get-up starts, the get-ups (snap,
  quick, plain, wall), the early get-up and its rate, the board hit and pin, the whip of the upper body on a hit, the
  mesh's turn and slide while he is down. A fork translated the listing in round 3; this round gave it what it lacked
  (looping takes, a take's rate and length, the mesh's world yaw and shift, the hold layer LayeredBoneBlend_0 with its
  three evaluators, the whip's four bone modifiers) and ran it.
- **The hit read** (`engine/cores/rink/view/hit_read.gd`, by a fork): thirdjam's model of presses and hits as far as it
  reaches a figure: PlayWhiff(0 / 1) on the sim's miss, and the check's re-time (the figure's time dilation set to the
  frames it is short, for one frame). thirdjam's own tests of it are ported: 6 of 6 cases.
- **The puck is in both pictures**: the gym draws a puck where the puck show puts it (on the blade after the frame's
  pose); the oracle has thirdjam's own puck actor at the same point. The figures now look at it, so **the look at the
  puck is compared** (round 2 left it uncompared).
- **Proof.** First, on round 3's stream with every call given (6 checks, 5 cross-checks, 31 hit reactions, 7 knockdowns,
  10 pins, a stumble, 5 whiffs, 2 re-times): 18,000 of 18,000 rows within 1 cm, worst 0.48 cm, on the first complete
  run of the draft. Then a new stream (`verbs.stream.json`, seed 2, 1,800 frames: also a held cross-check, a board
  hit with a board fall, three stumbles, a goal and its faceoff) with the puck actor: **17,998 of 18,000 rows within
  1 cm, worst 1.61 cm**. The two rows are single frames of one bot each (frames 1074 and 1359), the puck socket only,
  1.6 and 1.3 cm; I did not find their cause.
- The skating gym's golden was made again (its two hit reactions play now): 940 of 940 frames, worst 0.01 cm.
- **Head socket** (lane K3's chevron): thirdjam's mesh socket `head_socket` sits ON the bone of that name with a roll
  of -90 degrees and no offset (read from the mesh in Unreal). Our place for it and for the head bone agree with
  thirdjam's within 0.02 cm on every compared frame; only the socket's own turn was missing, and is added. thirdjam's
  marker rule reads two places and no axis (HUDWidget.cpp:1114-1121), so the export was not the cause of what K3 saw.
- **A native pose blend, measured not built** (a fork): of about 2.2 ms a frame for ten figures (headless, median of
  five runs, 1.9 to 2.7), the pose arithmetic a native library would take over is 1.13 ms; it would save about 0.9 ms
  (0.8 to 1.0) and leave 1.2 to 1.4 ms. Table in the report.

## What the oracle caught this round

1. **The oracle's world can stand still while Slate ticks** (a blocking load when the first knockdown's effects came
   in): two of my frames fell into one world tick and every figure was out of phase from then on. The oracle now
   reads the world's clock and does not count such a tick.
2. **The warm-up needs the puck too**: thirdjam's figures looked at the puck actor before the first call.
3. Two GPU crashes of Unreal at start ("device removed") while other lanes rendered; reruns were clean.
Nothing in the contact's translation had to be changed for parity.

## What my eye rejects (looked at: two crops at full size: the human's knockdown, a check; the other 27 sheets and the film not)

1. In the knockdown the checker stands IN the man he felled for half a second (frames 1146 to 1173): the sim's
   bodies, in both pictures.
2. A skater who skates in front of the follow camera fills a third of the frame (1173). The gym's camera, not the game's.
3. The held cross-check shows for one frame only in this run (the hold pose wanted on frames 435 and 992): the hold
   layer is run and compared, but nobody has seen a brace held.
4. The board fall happened to a bot (skater 7, frame 840), not in the followed skater's sheets: compared in numbers,
   not looked at.
5. thirdjam's oracle picture has no rink, so the wall rules (which way a man falls beside the boards, the slide off
   the wall) run on zeros there, in both figures. In our game mode they get the cartridge's rink; that is not compared.
In the two crops (16 pairs) no pair differs in pose; our figure now wears lane K7's felt and number.

## Deviations (this round's)

1. `set_rink`: the rink's half length, half width and corner radius are given to the figure from the cartridge (the
   Blueprint reads the bounds of thirdjam's RinkActor's "Ice" mesh and its material's corner radius). Not compared.
2. The trip (SetTripped) is ported and has no caller in thirdjam. The dive, slide, wipe and bonk branches of the
   falls are counted in `not_ported`, not played. Equipment, the slide's particles, the contact shadow: not ported.
3. [ChkMissTick]'s timer is kept and never fires (nothing in thirdjam sets bAutoCheckMiss).
4. The hit read's re-time sets the figure's dilation only (thirdjam also the pawn actor's; ours has no clock).
5. bUpRun: thirdjam's own figure clears it on the tick an early get-up starts; ours does the same (its debug read
   shows it never true for the human). Kept as is: parity.

## Not ported yet

Weapons and abilities, dash, dive, slide tackle, celebrations, the boost glow, equipment; the hit read's bars, lean and
pop (HUD and camera, not figure calls); PlayCallForPass still waits for K1's pass target.

## Next

1. The two unexplained rows, and a run that holds a brace for a second and pins a man (the old stream had ten pins,
   compared by hand; the tracked one has none).
2. A rink in the oracle (thirdjam's RinkActor needs a cartridge object Python cannot build), so the wall rules are compared.
3. The last family: abilities and weapons, dash, dive, celebrations.
