REPORT: character-astra (night of 20 Nov 2026, the toy-diorama duel)
Operator: Opus 5.5. Designer and builder: GPT 6.2 Astra via Codex, one session (01a1f5ef), three rounds.
Worktree .claude/worktrees/n20-character-astra, branch diorama-character-astra from diorama-base 781d32b. Nothing committed.
Verdict: DONE. On the frozen tree, every gate COMMON.md requires before done is PASS. The rest of the full tier is
PASS except kernel.selftest, which stopped at its 1800 s limit with 258 of 259 units done and 0 failed (see Gates).

WHAT WAS BUILT AND WHY IT READS AS A DIORAMA
- Route: Astra refined the code-built figure, not a Blender import. Its reasoning: the board-4 shapes that carry the toy
  are the two hair locks, the raised collar, the short jacket over jeans with turn-ups, and heavy boots. Those can be
  sculpted once on the existing 29-bone skeleton, recoloured by every pack, and need no per-game asset or loader.
  New files: engine/rigs/biped/clay_rig.gd (extends TLRigBiped), clay_biped.gd (the sculpt), clay_form.gd (skinned
  sections, weights, one grip blend shape), clay_motion.gd (fixed-tick secondary motion, two-link palm IK), and
  engine/style/shaders/body_clay.gdshader (painted clay: fingerprint relief and chipped paint at elbow, hip, knee and boot
  welt, anchored to bind-space coordinates so it does not crawl).
- Dispatch: tl_rigs.gd picks the clay rig when the loaded style file is style_diorama.json; classic builds TLRigBiped as
  before.
- The figure, as built: separate clay pieces. A red jacket with a rolled collar and cuffs, brass snaps, a short hem that
  shows the jeans from behind. Blue jeans with turn-ups. Sculpted brown hair: two staggered crown curls, a fringe, ears
  showing below the nape. Boots with a welt and a thick sole. Curled bare hands with thumbs. Hockey keeps its helmets,
  team colours (rig_params.colors), mittens, skates and stick. Parkour keeps its blue jacket.
- The motion, toy-like (Astra's own figures; its case 590 measures them and passes in my run; I saw the pocket brush
  in the close-ups and the wing pose in the sheet):
  - an idle that glances, then brushes a mitten against the pocket;
  - a chest roll over each planted boot;
  - the leading knee kept through the take-off, with the opposite arm driving;
  - the crown and collar/satchel settle a tick apart on landing;
  - the palms meet ledges and bars (hand opening fitted to the 5 cm bar), and the second hand meets the hockey stick;
  - a heel tuck at the wing summon, and the arm opening in a bank.
- Evidence:
  - contact-sheet.jpg: classic | diorama pairs: close-up back and front, parkour f520, hockey f1500, flight f300,
    village 07, and board 4 beside the exe's own village road frame;
  - character-sheet.jpg: base classic on the top row, then the diorama figure in front, back, three-quarter, walk, run,
    skate blue and red, jump, and the wings at summon, unfold, spread and bank;
  - clip.mp4 and clip-strip.jpg; shots/ (34 JPGs: 17 classic and diorama pairs).

RULES, EACH WITH ITS EVIDENCE (all my own runs on the frozen tree unless said)
1. No pack file changes: git status has nothing under engine/packs/** or engine/seeds/**. No palette key was added or
   renamed. The kernel API keeps every v1 signature: tl arch is PASS 12/12 in the fast gate.
2. Today's look stays exact under TL_STYLE=classic:
   - The rig probe (walker, visitor, skater blue and red, worker) gives byte-identical output to the clean base copy.
   - Pixel diff of my final classic shot set against the base's classic set, 34 frames: the close-ups (5), parkour f520
     and f987, 3 of 8 flight frames and 11 of 16 village frames have max 0/255.
   - The other 13 frames are run-to-run noise:
     - the 5 flight frames change 0 pixels in the box around the flying figure;
     - the 5 village frames and hockey differ by the same amount when base is compared with a second base run
       (0.01-0.31 % of pixels).
     File: .tl/final/classic-proof.txt.
3. No game's state hash moves:
   - check --tier full --only world,packs,kit.selftest: PASS.
   - world 8/8, every hash and tick count equal to diorama-base (drive a2940a17@3441, wall d5aea03b@1220, paddle
     dff1a390@4486, walker f1c7b537@371, kit ca698e71@332, car 3a459d0f@1872, hockey a29dcdf0@4186, parkour f7abac00@988).
   - packs 2/2, 48/48 verb runs: all 46 state hashes equal to base (the 2 lint runs carry none).
4. Cache keys: no kit, terrain or crown generator changed, so PIC_VERSION is not bumped. The picture cache skips skinned
   meshes (draw_pictures.gd _collect_standin, Astra's reading). The exe check shows the clay figure in the real build.
5. Performance (windowed, tl perf run --no-record; the machine was BUSY both times, util 0.72 base and 0.91 final):
   - tour6 gpu 1.199 -> 1.212 ms, frame p50 3.194 -> 3.223 ms;
   - walk30 gpu 1.238 -> 1.234 ms;
   - hero1440 primitives 1,667,300 -> 1,671,776, draw calls 239 -> 239.
   No doubling. Hockey's frame budget (many_budget, 1.0 ms), interleaved A/B with 3 runs each: base 0.962/1.071/0.937 ms,
   round 1 0.987/0.976/1.001 ms, final 0.929 ms. It fails on base too under this load; no regression.
Character rails:
   - API: TLBiped.create options are unchanged. 20 clips, 29 bone names and the sockets (hand_r, hand_l, head, back) are
     identical to base in all five configurations, in both styles.
   - Size: metrics() height 2.0 and radius 0.3 everywhere. Bones 29 (limit 30). Tris by metrics(): walker and worker
     11,788, visitor 10,916, skaters 10,760. Visible meshes: 11,652 / 10,780 / 10,760. Limit 12k; 212 to spare on the
     largest wardrobe.
   - Every game works: hockey skaters (helmet, stick, blue and red), the parkour runner, the village walker and the
     summoned wings all appear in the shot set and sheets.

GATES (frozen tree; source files unchanged since Astra's 03:23 freeze, md5 checked 03:33-03:41)
- check --tier fast: PASS 5/5 (arch 12/12, assets 4/4, cards 3/3, devx.test 229/229, foreman.typecheck).
- check --tier full --only world,packs,kit.selftest: PASS (kit.selftest 95/95, packs 2/2 with 48/48, world 8/8).
- selftest rig. 14/14, moves. 14/14, flight. 13/13, wings 2/2, style. 3/3, character. 1/1 (new case 590). Same counts
  as on base, plus the new case.
- check --tier full --only seeds,item.selftest,ui.selftest: seeds PASS 39/39 and ui.selftest PASS 166/166.
  item.selftest hit the 600 s limit with 88 of 89 units done: a stopped run, not a pass. Re-run alone: PASS 91/91.
- kernel.selftest on the final tree: FAIL as a stopped run. It hit the 1800 s step limit with 258 of 259 units done,
  0 failed, 258 passed. This is NOT a pass. Astra's round-1 full run stopped at the same limit; its direct kernel
  script, run without the limit, reported 326/326 on round 1. The machine was loaded by six arms all night.
- Every full-tier step has now run on the final tree. All PASS except kernel.selftest, which stopped at its limit.
  perf: PASS on every scenario, but BUSY, so measured and not judged.
- Exe: export.sh built dist/arms/character-astra/ThirdLife, tag "781d32b 2026-11-20 03:54" (HEAD plus the uncommitted
  lane files). export.sh check: PASS. The exe, the editor binary and a spaced copy run the same 10 plots to the same
  hashes. The exe shows the village (with the clay figure on the road), obeys W and Esc, and leaves no process.
  Note: export writes dist/arms/PLAY-LATEST.cmd, which the arms share.

CHANGED FILES
engine/rigs/tl_rigs.gd (the biped picks the clay rig under the diorama style)
engine/rigs/biped/clay_rig.gd, clay_biped.gd, clay_form.gd, clay_motion.gd (+ .uid)
engine/style/shaders/body_clay.gdshader (+ .uid)
engine/kernel/api/tl_biped.gd: after the rig tick, passes the bar or ledge line to the rig's _fit_grip (presentation
  only; hashes unchanged). Also two cosmetic hunks Astra made: a shortened doc comment on _ready and a one-line
  _rig_has. Same behaviour, but the old comment said more; the Director may want to restore those two hunks at landing.
engine/kernel/world/visitor.gd: the same grip line for the village visitor.
engine/rigs/review/review.gd: --backpack=0|1 override.
engine/rigs/review/clay_case.gd + engine/tools/selftest.d/590-character-clay.sh: the new case (tris budget, palette
  swaps, the rig contract, grip, takeoff lead, landing settle).
Lane folder: REPORT.txt, STANDUP.md, ASTRA-NOTES.md (Astra's own report, rounds 1-3), PATCHES.md, contact-sheet.jpg,
  character-sheet.jpg, clip.mp4, clip-strip.jpg, shots/*.jpg.

PATCHES.md (for the other pillars, from Astra)
The frame's dark contour runs evenly across the crown, cuffs and boot rolls, and the front fill flattens the clay. The
combined build wants the frame arm's softer outline and a warm side light on the figure's back. Keep the depth-of-field
focal plane on the runner through the parkour jump. The picture cache needs no bump for this arm.

WHAT STILL DOES NOT READ AS DIORAMA (honest)
- Close up, the coat still looks moulded rather than thumb-worked: the joins between clay pieces are crisp, and the
  continuous ink contour plus even light flatten it. Board 4 has softer joins and strong warm side light. Part of this
  belongs to the frame pillar.
- At play distance (village road, rink overview, flight) the silhouette carries the toy, but the fingerprints, chips and
  pocket edges disappear.
- The summoned wings are still today's paper-and-ink wings; they are not clay or felt. flight_wings.gd was only allowed
  to change for fit.
- Hockey from the overview camera: the skaters read as rounder toys, with less difference between them than the board
  figure shows close up.
- Nobody has played it by hand. The clip and the stills are scripted, and the exe was checked by script (W, Esc).

COST PER NEW GAME: unchanged. A game calls TLBiped.create and names palette keys as today. The clay figure, its grip,
landing and idle come with the biped. No asset, import or loader per game.

FOR THE DIRECTOR
- flight_review's still mode (no --seq) draws no wings on base either: flight_wings sets root.visible only in tick().
  The sheets use --seq=1.
- Hockey invariants.many_budget (1.0 ms) flips under tonight's load on base too; it is not a character regression.
- TLStyle.ensure() is now called inside TLRigs._build_rig, which _rig_ahead can run on a worker thread. Gates and the exe
  are green, but a first ensure() on a thread is worth a look at landing.
- Next three: (1) soften the clay joins and get the frame arm's side light onto the figure, then re-judge the close-up;
  (2) make the wings clay or felt in the diorama style; (3) a person plays the exe: road, parkour and hockey.
