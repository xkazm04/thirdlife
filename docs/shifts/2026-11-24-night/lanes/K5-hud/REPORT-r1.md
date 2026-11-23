K5 screen: REPORT, round 1 (landable), 23 Nov 20:45. Worktree .claude/worktrees/hk-hud (branch hk-hud, cut from hokej).

OUTCOME AGAINST THE ACCEPTANCE CRITERIA
- Every element of HUD.md built or listed as not yet, none invented, each citing its source: MET for round 1's scope.
  HUD.md lists every element of thirdjam HEAD 8dc713c6's match screen, the flow and the menu, with file:line for every
  rule and number. Built (R1): score plates with PERIOD n / FIRST TO 3; your ring; your double ring while you carry; the
  carrier's ring; the pickup pulse; the take grace; the loose ring; the YOU chevron and tag; the far-net and own-net badges;
  the edge chevrons; the off-screen puck arrow; the edge slots; the controls panel; the radar; the faceoff dial and its
  hint; the MATCH card. Off as shipped and NOT built (their cvars default to 0): the shot line, the pass meter, the stop
  line, the stamina bar, the controls strip and pill, and the contact, cue and brace lines. The brief named the shot line
  and the pass meter, but the source turns both off. GAP: the pass-target ring needs UJamSim::HumanPassTarget from the core.
  The flow (round 2) and the menu (round 3) are inventoried, not built.
- Positions and sizes at 1280x720 and 1920x1080 match thirdjam's layout rules: MET for the built elements (HUD.md section 4).
  Everything is laid out in Slate's 1080-unit space. Our 720p still is the 1080p one x 2/3 (score plate 90x65 -> 59x43;
  panel 264 -> 176 wide, its top 824 -> 550). Against thirdjam's own 1080p still (h43-02): the dial centre is (1400, 713),
  equal to the source rule, and the ring is 443x230 against 435x220.
- Show rules tested headless from recorded snapshots: MET. tests/bot_hud_rules.gd first ports thirdjam's own assertions
  case for case (HUDControlsPanelTests, HUDPossessionTests, CameraTests, CarrierCueTests). It then runs a second RinkCore
  whose human is thirdjam's playerbot through a whole match (30,002 frames, ending 1:2) and feeds every snapshot to hud.gd.
  Result: 151,407 checks, 0 failed. Selftest engine/tools/selftest.d/830-hokej-hud.sh: 2/2 PASS.
- My eye's list from side-by-side stills at six moments: PARTLY MET. Four moments are covered: faceoff, carrying,
  defending, goal pause (r1_sbs_sheet.jpg, ROUND-1.md). The end card and pause are round 2. The only thirdjam pictures of
  this HUD era are its submission stills (H43), taken before the one look landed. HEAD's own look has no picture; the
  runnable build is older still.
- hokej lint, smoke, bots pass; tl check --tier fast passes: MET with one condition.
  - hokej: lint PASS; smoke PASS; invariants PASS with K3's hashes (idle 79a699ba1b92ec17, bot 19657a920ad7853a), so the
    HUD changes nothing in the state; all 7 earlier bots PASS, plus bot_hud_rules PASS.
  - Fast tier with a regenerated index and main's .claude/sessions.json: arch 12/12, assets, cards, devx.test 229/229,
    foreman.typecheck: all PASS.
  - Fast tier in the tree as cut: arch FAIL and devx.test 225/229. The only causes are the stale docs/generated index
    (which my 1.19 addition makes stale; regeneration is the Director's) and the hk-shell/hk-hud claim overlap. The Director
    says both are fixed on hokej. I put both files back exactly as they were.
  - Full tier: stopped on the Director's order (20:37). It was not run to the end, so it is NOT RUN, not PASS.

GATES (last lines)
PASS  hokej lint; PASS hokej smoke (1800 frames, 0 errors); PASS hokej invariants (many_budget p50 0.499 ms)
PASS  bots: match_hand 3:1 in 5459 frames, gym_hand, rule_w_away, rule_s_lock, rule_aim 12/12, rule_aim_anchor,
      tj_replay 9329 of 9465; bot_hud_rules 151,407 checks 0 failed
PASS  selftest hokej.hud_rules, hokej.hud_layer (2 passed, 0 failed)
PASS  fast tier with a fresh index and main's claims: arch [12/12], assets [4/4], cards [3/3], devx.test [229/229], foreman.typecheck
FAIL  fast tier as cut: arch (scope-claims, api-index-fresh, api-v1, reports-index-fresh), devx.test 225/229 (api-v1 tests):
      the stale generated index and the claims overlap only
NOT RUN  full tier (stopped on the Director's order)

CHANGED FILES
kernel (API 1.19):
  engine/kernel/api/tl_hud_layer.gd (new): class TLHudLayer, the painter.
  engine/kernel/api/tl_hud.gd: TLHud.add_layer.
  engine/kernel/runner/manifest.gd: KERNEL_API 1.18 -> 1.19.
  engine/kernel/API.md: appended section 25.
style:
  engine/style/hud/faces.gd (new).
  engine/style/hud/Roboto-Regular.ttf, Roboto-Bold.ttf, Roboto-BoldCondensed.ttf, Roboto-Black.ttf (new).
  engine/style/hud/ROBOTO_License.txt (new). Copied from UE 5.9's Engine/Content/Slate/Fonts, Apache 2.0, the same files
  thirdjam ships; outside assets/, like Archivo.ttf.
pack:
  engine/packs/hokej/scripts/hud/ (new): rules.gd, hud.gd, markers.gd, panel.gd, cards.gd, screen.gd.
  engine/packs/hokej/tests/bot_hud_rules.gd (new).
  engine/packs/hokej/pack.json: capability "ui", kernelApi 1.19, the test appended last.
  engine/packs/hokej/scripts/main.gd (K3's file, CRLF kept): THE CALL SITE. In _draw(), after ctx.cameras.add_view(&"follow", ...):
      if mode == "match":
          screen = Screen.frame_of(screen, ctx, snap, human, last_in, last_raw)
    plus `const Screen := preload("hud/screen.gd")` and `var screen`. To keep it one line on hokej's new main.gd, the call
    can read `screen = preload("hud/screen.gd").frame_of(...)` with `var screen`. It needs the human's raw keys
    (last_raw["Down"]), the FJamInput sent (last_in) and the button resolver's held list (human.held, for BRACED). If the
    core's raw glue now owns those, screen.gd's ui_of() is the one place to adapt.
selftest: engine/tools/selftest.d/830-hokej-hud.sh (new).
lane: HUD.md, ROUND-1.md, STANDUP.md, REPORT.txt, r1_sbs_sheet.jpg, r1_ours_faceoff_1080.jpg, r1_ours_faceoff_720.jpg,
  r1_ours_carry_1080.jpg.

BEHAVIOUR CHANGES
- In a window, the hokej match now has thirdjam's in-play HUD.
- Headless, the HUD does nothing (presentation only). Painting it every headless frame cost 0.6 ms and tripped the
  many-pack budget (p50 1.14 ms).
- No sim, input, camera or state-hash change: same hashes as K3 round 3.

DEVIATIONS
1. The ring texture T_UI_RingPlain (a uasset) is drawn as a band: 8.2 % of the box with 0.86 % ink edges, measured on
   thirdjam's still h43-07.
2. The dial's T_UI_Ring art is drawn from primitives: a chalk ring, blue and orange arcs, four ticks.
3. The chevron and the tag use the stand-in's top of bounds (1.64 m) as the head anchor until K2's figure has a head socket.
   They stand higher than thirdjam's crouching figure at a faceoff.
4. The take grace's ring reads TakeGraceLeft only. thirdjam's InTakeGrace also counts the frame the puck is won on, which
   needs TakeOwner (not in the snapshot), so our ring swells one frame late.
5. The pass-target ring is not built: RinkCore has no HumanPassTarget.
6. Projection uses the camera pose of this frame, as thirdjam's widget does. Godot renders the physics-interpolated pose,
   so the two agree at 60 Hz rendering.
7. Text tracking is rounded to whole pixels.
8. "MATCH 1" is fixed (no season yet); the level word comes from data/match.json.
9. The HUD does not run headless (see BEHAVIOUR CHANGES).

QUESTIONS FOR THE DIRECTOR
1. K1: expose per skater TakeOwner (or InTakeGrace), and a pass-target query (UJamSim::HumanPassTarget(skater, stick,
   hold)). Two elements wait on them: the grace's first frame, and the pass-target ring (plus the teach pulse's pass half
   in round 2).
2. The GOAL banner's plate and the end card's panel are kit textures (T_UI_Banner_Goal, T_UI_Panel; uassets). Should round 2
   draw them from primitives, or may one Unreal process export them to PNG once? An export would add assets to the
   manifest.
3. The commentator's line choice in thirdjam is salted with the wall clock (not deterministic). Round 2 will draw it from a
   seeded stream of its own; say if you want otherwise.
4. contracts: the new kernel API (1.19) needs its API-V1/API-INDEX regeneration on hokej (tl arch --index).

FOR THE OWNER TO LOOK AT
docs/shifts/2026-11-24-night/lanes/K5-hud/r1_sbs_sheet.jpg (thirdjam left, ours right: faceoff, carrying, defending, goal
pause); r1_ours_faceoff_1080.jpg; r1_ours_faceoff_720.jpg; r1_ours_carry_1080.jpg. In play: `node devx/bin/tl.mjs play hokej`.

NEXT THREE
1. Round 2, the flow: GOAL banner and pause, end card with its 1.9 s wait and stats table, pause card on Esc and restart,
   fade from black, IN THE BOX.
2. The commentator's captions (415 lines, triggers, one line per 150 frames) and the one-line rule; the brake prompt; the
   teach pulse.
3. The contested-puck rings (JamCarrierMarks.h's rule), then round 3: the menu and the first 30 seconds beside thirdjam's.
