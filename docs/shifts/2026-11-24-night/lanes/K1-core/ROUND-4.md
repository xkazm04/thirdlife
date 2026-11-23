# K1 round 4 (20:18-21:30): the window, the quit, the replay, the gym, thirdjam's contact tests, its playtester

## 1a. Scripted keys in a real window (kernel runner)
- The flush the Director asked for was already in `kernel/runner/session.gd` (pre_sample: `Input.flush_buffered_events()`).
  The real cause, reproduced: when another window takes the focus, the OS layer releases every held key. A small window
  opened 20 s into a scripted run lost 142 frames of held keys (4,955 samples against the headless 5,179).
- Fix (session.gd): the session remembers which keys and mouse buttons its script holds and presses them again before
  each sample if the engine no longer sees them down. A person's released key stays released (scripted runs only). The
  headless record is unchanged byte for byte.
- Selftest 801 `window.scripted_focus` PASS: the focus stolen in window 1, both windows' records equal the headless one
  (5,179 of 5,179 samples each).

## 1b. Quitting the game with a dungeon open (exit 139)
- Reproduced in our engine: boot.tscn with `--dungeon=<parkour|duel|hockey>` and the engine's `--quit-after`: exit 139,
  4 of 4. The dungeon's own end and the main menu exit 0.
- Cause: an engine quit tears the tree down without `dungeon.close()`, leaving its watchdog thread running and its script
  logger registered. Fix: `kernel/dungeon/dungeon.gd` `_exit_tree` does the pack's teardown and `_free_pack()` (stops the
  watch, removes the logger) when close() never ran. After: 0 of 9 quits crash (parkour, duel, hockey x 3); a person
  closing the window: 3 of 3 exit 0. Selftest 802 `dungeon.quit_after` PASS.
- Also found (not ours): a bare Godot 4.7.2 project with no code of ours crashes on windowed quit 5 of 10 times on Vulkan,
  0 of 10 on Direct3D 12. engine/project.godot already picks d3d12; anything that forces Vulkan meets it.

## 5. K3's recorded raw stream parting at frame 1,294
- Reproduced on a copy of K3's pack (in .tl/, my binaries): tool and pack parted at frame 1,506, input first at 1,294.
- Cause: the glue used `CameraYaw` as a double. The pack hands it single-precision exact; the replay's yaw went through
  Godot's JSON number parser and came back one double ulp away (pack 0.93477410078048706, replay ...717). The skater
  positions already differed by ~1e-12 at frame 1,288, under the state hash and under the float snapshot.
- Fix (RinkCore.set_raw_input): every raw value is single precision: `CameraYaw` is rounded to float on entry; optional
  `CameraYawDeg` (thirdjam's form, degrees to radians in double). `rink_rawtrace.gd` now writes one line per stream entry
  (it stopped one short when the match ended). K3's own `rawtrace_compare.py` on the copy: PASS, 9,071 of 9,071 frames;
  its exact per-field replay: no input and no hash difference.
- No pixel: omit `CursorPx` or give a negative coordinate (a bot's (-1, -1)): no anchor, the blade follows the hit point.
  Documented in SNAPSHOT.md v1.2.

## 3. The gym
- The "drifting" opposing centre was the human pushing him: he stands at the dot in the human's path and thirdjam's contact
  law carries him ~40 m. Not a drift.
- `set_bot_mode("off")`: the other nine kept in thirdjam's own penalty box every frame (no body, no contact): an empty
  sheet. Measured: the human skates 43.9 m, the others 0.000 m (selftest rink.rawhand's gym check).

## 2. thirdjam's tests through the pawn shim; Jam.Controls not done
- 38 pawn-dependent tests now compiled through a minimal pawn shim (the five pure helpers' bodies extracted verbatim from
  JamPawns.cpp at build time; CallFigure by name for the one probe class): **38 of 38 PASS** (36 contact, 2 stick).
  With round 3: 218 of 219 tests compiled; **Jam.* 195 of 195 PASS**, Bar.* 22 of 23 (the one that fails in thirdjam too).
  The last one (VisualSwapTests) loads Unreal classes.
- Jam.Controls.* (24 tests, JamGame/Private/ControlsTests.cpp): NOT run. The file includes Slate, menus, the settings widget
  and the game mode; about 10 of its tests exercise the button rules, the rest the rebinding screen, saving and the HUD.
  Compiling it needs a UI shim far larger than the pawn's; extracting single tests would be a re-typing. Evidence today:
  K3's compiled thirdjam resolver agrees with the glue on 5,198 of 5,198 frames. Next round, if the Director wants it.

## 4. thirdjam's playtester as a hand
- `set_human_mode("playtester:<novice|regular|good>[:sprint]")` seats FJamPlaytester exactly as RunPlaytestMatch does
  (native/glue/rink_playtester.cpp). Proof: seeds 1 and 2 (pro, regular, sprint) end on thirdjam's own tournament hashes:
  973d6c043707b703 after 12,206 frames, 1bbdb50b63cdaac3 after 16,903. Selftest rink.playtester_seat PASS.
  (A first run failed: my own parse of "regular:sprint" dropped the sprint; fixed.)
- Through the REAL keys (`tools/rink_keyshand.gd`: each frame's decision turned into the devices a person would press, fed
  to a second core in raw mode, both stepped in lock): it is not the same match.
  Seed 1 parts at frame 162: the inputs are equal at single precision, the doubles are not (the playtester's analog move and
  stick are doubles; a device axis is a float). Seed 2 parts at frame 196: a stick lift pressed while the same button (LMB,
  cross-check) is still held: a person must let go for a frame before the press counts.
  So a shell bot pressing the playtester's keys plays a hand next to thirdjam's, not its replay; the keys path cannot carry
  the analog decision to the bit while the raw shape is single precision.

## What my eye rejects
No picture in this lane.
