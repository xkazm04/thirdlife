K3 SHELL, ROUND 5 REPORT (campaign night 23-24 Nov 2026; worktree .claude/worktrees/hk-shell, branch hk-shell, uncommitted,
on hokej 38862d9). The lane rests after this round until K2's pawn and figure land.

OUTCOME
The human's skater now runs on K1's core glue: the pack sends only the devices (keys, buttons, wheel, the cursor's ice
point and pixel, the camera's yaw) through RinkCore human mode "raw"; thirdjam's rules (two-role buttons, possession,
holds, the S lock, the stick and its anchor, signals 1-4, R) are the core's. The pack's own port of those rules is deleted.
thirdjam's own button resolver (compiled from its source) equals K1's glue on 5,198 of 5,198 frames of a real match.
FINDING for K1: the pack's recorded raw stream replayed through rink_rawtrace.gd gives the pack's core hash only up to
frame 1,505 (details below).

1. RAW MODE, SIGNALS: DONE.
   - scripts/human_input.gd is the device read only (declare, axis, raw); the rules went with it. Deleted: the rule port
     (read, the button resolver, the context), scripts/controls.gd (the S lock, the stick, the anchor), and the gym's
     stand-in law (scripts/skate_standin.gd, data/standin_law.json).
   - main.gd: rink.set_human_mode("raw"), each frame set_raw_input(raw) -> step -> last_human_input(). The camera yaw is
     sent in single precision (FRotator's yaw is a float) so a record holds it exactly.
   - The gym (proof mode of the control tests) is now the same core with the other nine parked (set_bot_mode("parked"))
     and restart(); its frame-0 tick steps through the opening faceoff so the hand starts at the drop (a test stand).
   - Signals 1-4: the keys One..Four go in Down / Pressed; the glue gives the intent. New test bot_rule_signals PASS:
     during the faceoff One -> no intent; Two -> 2; Four 20 frames later -> still 2 (the 60-frame cooldown); Three 80
     frames after Two -> 3. The pack state carries Controls.IntentKind as `intent`.
2. ORACLES.
   - thirdjam's button resolver vs K1's glue: proof/buttons_glue.gd + proof/buttons_vs_glue.py: a seeded stream of the five
     two-role keys (presses, holds, taps inside a frame, releases) in a real match, the human skating at the puck so the
     possession changes under the keys; the context the oracle gets is read from the snapshot before each step as
     JamControls::ButtonContext reads the sim. PASS: 5,198 of 5,198 frames (the match's end) equal (glue frames with shoot
     held 322, pass held 768, check 74, cross-check 293, brace 2,300). The round-3 comparison against my own port is gone
     with the port.
   - rink_rawtrace.gd on a stream recorded from the pack: FAIL, a finding against the glue or the record, not patched:
     proof/rawtrace_compare.py writes the pack's raw devices (bot_match_hand's result, metrics.raw.devices; vectors and the
     camera yaw as integers x 2^50, exact) as a rawtrace stream and compares its per-frame hash with the pack's.
     First differing core hash: frame 1,506 (tool 8e3fc4d801a2fad2, pack 18199f274aa77233), 9,071 frames.
     proof/raw_replay_exact.gd (the same stream, a fresh RinkCore, exact comparison of last_human_input with the pack's):
     the first FJamInput difference is frame 1,294, Stick y -0.384519189596 (replay) against -0.384519159794 (pack): one
     single-precision step, with the cursor's ice point, pixel, the camera yaw and the keys of that frame equal to the bit;
     the core hashes are equal up to 1,505. Both replays are deterministic (twice the same) and agree with each other; the
     pack is deterministic (the bot twice, and record -> replay: the same hash 4685cd21e60096f0). Calling snapshot() and
     get_frame() around each replayed step changes nothing. So the live pack run and a fresh core fed the recorded raw
     devices part at the anchor's / stick's last bit: either some input the glue reads is not in the raw dictionary as
     recorded, or the glue keeps state a fresh core does not have. Reproduce: tl.sh bot --pack=engine/packs/hokej
     --test=tests/bot_match_hand.gd --report=<r.json>, then python proof/rawtrace_compare.py <r.json> <godot> <engine> <dir>.
3. RESTART: DONE. R goes to the glue in the raw stream (GAMEMODE.md row 14, RinkCore.restart()); the pack only notices the
   frame going back (clears its hit-stop and "over"). bot_rule_restart PASS with the glue's restart: R at frame 540 ->
   frame 0 at 0:0; 240 core frames after R hash as the untouched match's, 0 differ. The gym uses restart() too.
4. PROOFS RE-RUN.
   - Camera vs thirdjam's film (bot_tj_replay): PASS, 9,329 steps, 0.54 cm, 0.097 deg (unchanged). The camera vs thirdjam's
     code on the new gym hand: PASS, 0.0106 cm, 0.00016 deg.
   - The full-match hand bot: PASS, 3:1, 9,071 frames, 27 shots, 445 checks and pokes (round 4: 3:1 in 5,459 frames).
   - Determinism: invariants PASS (idle twice ad03a2add6ce42c1; bot_match_hand twice 4685cd21e60096f0 after 9,072 frames);
     record and replay: the same state hash 4685cd21e60096f0.
   - Export headless: export.sh build --no-warm PASS (the core's DLL beside the exe), export.sh check --no-window PASS:
     hokej 6e9c32c23eaf3d45 in the editor binary and the exe (600 frames).
   WHAT CHANGED IN THE HASHES, AND WHY:
   - The match (core hash): the glue gives the skater's stick in double precision, as thirdjam's FVector2D; my port sent
     it through a single-precision Vector2. On round 4's recorded match the core hash first differs at frame 361, and
     no field of the human's input differs by more than 1e-5 before frame 564: the matches part on that last bit, and
     after that they are different matches (3:1 in 5,459 frames then, 3:1 in 9,071 now). The new one is the faithful one.
   - The idle run (pack state hash 79a699ba -> ad03a2ad; dungeon 600 frames bd182092 -> 6e9c32c2): the core is unchanged
     when nobody plays (input mode with nothing and raw mode with no device: the same core hash for 3,600 frames,
     checked); the pack's own state changed shape (it now carries the raw devices and the glue's input).
   - proof/core_replay.gd (round 3: the FJamInput stream into input mode) no longer holds and is marked so: last_human_input
     reports the glue's double stick in single precision, so that replay drifts; rawtrace_compare.py replaces it.

GATES
hokej: lint PASS, smoke PASS, invariants PASS (above), bots 10/10 PASS: match_hand, rule_w_away, rule_s_lock, rule_aim,
  rule_aim_anchor, rule_signals (new), rule_restart, gym_hand, tj_replay (+ the camera oracle on the gym hand).
tl check --tier fast: arch 12/12, assets 4/4, cards 3/3, devx.test 229/229 PASS; foreman NOT RUN (no node_modules here).
export build + check --no-window: PASS. Full tier: not run (no kernel, kit, rig or style file changed this round).

TESTS CHANGED (behaviour moved from the pack to the glue; nothing loosened)
- bot_rule_s_lock: the lock's state is the glue's: checked by the move alone (on the locked back direction; a new pull
  relocks to the camera's yaw of that moment). bot_rule_aim_anchor: the "anchored" flag is the glue's: checked by where the
  stick points (phase B still holds +x after the point moved under a still pixel). bot_rule_aim: the cursor moves its
  pixel each step (a still pixel on a standing skater anchors, as thirdjam's rule says); both aim tests give no cursor on
  frame 0 (the gym places the skater at the drop on that frame; a point read before would be stale).

CHANGED FILES
engine/packs/hokej: scripts/main.gd, scripts/human_input.gd (device read only), README.md, pack.json (bot_rule_signals),
  tests/bot_match_hand.gd (records the raw devices), tests/bot_rule_s_lock.gd, bot_rule_aim.gd, bot_rule_aim_anchor.gd,
  tests/bot_rule_signals.gd (new). Deleted: scripts/controls.gd, scripts/skate_standin.gd, data/standin_law.json.
docs/shifts/2026-11-24-night/lanes/K3-shell: REPORT.txt, ROUND-5.md, STANDUP.md; proof/buttons_glue.gd, buttons_vs_glue.py,
  rawtrace_compare.py, raw_replay_exact.gd (new, + uids); proof/core_replay.gd (marked obsolete); deleted proof/buttons_port.gd
  (+uid) and buttons_compare.py (they tested the deleted port).
A slip, undone: I ran `git rm --cached` on the three deleted pack files and then `git restore --staged` on them; the index is
  as it was (nothing staged). No other git write.

QUESTIONS FOR THE DIRECTOR
1. The rawtrace finding (above) goes to K1: the first frame (1,294 input, 1,506 hash) and the reproduction.
2. A bot that gives an aim without a pixel now reaches the glue as a still pixel (-1, -1): the anchor holds its point
   while the skater stands. A person's cursor always has a pixel; only bots meet it. Fine for thirdjam's rule; say if the
   raw shape should carry "no pixel".

NEXT (when K2 lands): the capsules out, K2's pawn through match_view.draw_skater, its hit-stop hold; then the person's play.
