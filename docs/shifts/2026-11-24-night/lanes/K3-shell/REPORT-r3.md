K3 SHELL, ROUND 3 REPORT (campaign night 23-24 Nov 2026; worktree .claude/worktrees/hk-shell, branch hk-shell, uncommitted,
on hokej 503861d)

OUTCOME
thirdjam's whole match runs in our engine from the real core: lane K1's RinkCore (thirdjam's own C++), the regular
cartridge (5 v 5, first to 3, faceoffs, goal pause, its bots at pro), the human's skater driven through thirdjam's key and
mouse mapping (all of it except the team signals), drawn with ten stand-ins, the puck at its true position and height,
thirdjam's nets, under the round-2 camera, with thirdjam's hit-stop. The state hash carries the core's hash; a match
replays to the same hash. The button rules equal thirdjam's own code (compiled from its source) on 20,000 of 20,000
frames. The style has a hall light rig now; the ice matches thirdjam's film colour.

START THE MATCH IN A WINDOW
  node devx/bin/tl.mjs play hokej          (= bash engine/tools/tl.sh play --pack=engine/packs/hokej)
Needs the built core (bash engine/tools/rink.sh build) and `res://cores/rink/rink_core.gdextension` in
engine/.godot/extension_list.cfg (rink.sh writes it; else the first --import exits 139). Level: data/match.json.

THE DIRECTOR'S POINTS
1. The real core, all of the human's input: DONE except signals 1-4.
   scripts/main.gd: ctx.cores.open("rink", "hockey.regular.cartridge.json"), set_difficulty, set_human_mode("input"),
   reset(ctx.seed); each frame raw devices -> FJamInput -> set_human_input -> step -> snapshot -> hit-stop -> camera -> draw.
   scripts/human_input.gd: raw() = K1's raw shape (stays in the shell); read() = MOVES TO CORE GLUE: ReadHumanInput
   (HokejGameMode.cpp:931-1000) + ApplyButtons (InputMapping.cpp:488-503) + FJamButtonResolver (318-425) + HasPuckForButtons
   (432-442) + ButtonContext (474-486): camera-relative move and the S lock, the cursor stick and the aim anchor, Shift,
   Ctrl, LMB shoot / cross-check (brace held 13), RMB pass (saucer) / check, Q pass, MMB and mouse 4 cross-check, Space
   poke, wheel deke, E spin, F ability, our pass in flight counting as "with the puck", a button held across a change of
   possession dead until released, R a new match. Signals 1-4: not given (they enter the brain's world inside the core,
   GAMEMODE.md row 13; RinkCore v1 in this tree has no door for them). K1's v1.1 (raw mode, rink_gamemode.cpp, in hk-core,
   not yet in this tree) does all of read(); then main.gd hands raw() to set_raw_input instead.
2. Stand-ins: DONE (scripts/match_view.gd): ten 1.64 m capsules in the team colours with a facing mark, a stick bar from
   the body to the sim's BladePos, the puck at Pos and Z, thirdjam's nets; faceoffs, the goal pause, the score and the
   end come from the snapshot. Interpolation: the engine's physics interpolation (as ApplyRender lerps PrevPos -> Pos);
   a sim teleport (PrevPos = Pos, the faceoff reset) is not slid. The seam for K2's pawn: draw_skater(i, skater_snapshot).
3. State and determinism: DONE. _pack_state()["rink"] = ctx.cores.state()["rink"] (hash, frame, score).
   invariants PASS: idle twice 79a699ba1b92ec17; bot_match_hand twice 19657a920ad7853a after 5,460 frames.
   Record and replay: tl.sh bot --record, tl.sh replay: the same state hash 19657a920ad7853a... (5,460 frames).
4. Proof:
   - proof/core_replay.gd: the FJamInput stream the pack sent (bot_match_hand's result), fed straight into a bare RinkCore:
     the core's hash equals the pack's on every one of 5,459 frames.
   - oracle/make_button_oracle.sh + proof/buttons_compare.py: thirdjam's FJamButtonResolver, Defaults and verb table
     copied VERBATIM by line range (InputMapping.h:27-145; InputMapping.cpp:78-90, 98-120, 146-168, 318-425), clang-built,
     against the pack's port on a seeded stream of the five two-role keys under a changing possession: 20,000 of 20,000
     frames equal (shoot held 2,161, pass held 4,224, check 206, cross-check press 1,022, brace 3,874).
   - "the same raw input through thirdjam's own playtester path": NOT DONE as asked. RinkCore v1 does not expose
     FJamPlayerBot's inputs and takes no raw input; K1's v1.1 does (raw mode, last_human_input). With it: feed my raw()
     stream to K1's glue and compare FJamInput per frame with read() (two ports of the same lines), and replay the
     playtester's own FJamInput through the shell. Asked below.
   - A whole match through the keys: tests/bot_match_hand.gd (a scripted hand: chase, carry to the net, a held shot inside
     14 m, check or poke an opposing carrier, the faceoff press): the match ran to its end, 3:1 at pro, 5,459 frames,
     21 shots, 269 checks and pokes.
   - Film: r3_sbs_film_20s.mp4 (thirdjam's 20 s beside ours, from the opening faceoff), r3_sbs_sheet_a/b.jpg. Looked at.
     What my eye rejects about motion and framing (not the capsules):
       a. The first rendered frame (1/60 s) shows the camera behind the spawn before the faceoff places the skaters;
          thirdjam hides it under its light-hold fade.
       b. Our scripted hand weaves (eight-way keys re-decided every 12 frames): the camera, following his facing as
          thirdjam's does, swings left and right more than in thirdjam's film. The hand, not the game.
       c. The figures' shadows are light-blue pools (the cel shade of the lit ice); thirdjam's are soft dark grey.
     The same as thirdjam: the opening faceoff framing, the human low in the middle in play, the far boards at about
     15 % of the height, two or three skaters round the carrier at 2.5 s in both.
     Fixed on sight: every stick ran to the centre dot at frame 0 (BladePos unset before the first step); the figures
     and the camera slid in from the origin on the first frames.
5. The hall light and the ice: DONE. engine/style/tl_style_hall.gd (NEW file; no shader bytes, no style file touched):
   TLStyleHall.apply(root, {color, energy, shadows}) turns the installed style's sun straight down (a roof light), sets
   the cel shader's sun colour and direction globals, the fog off, pauses the cel style's OverheadKey; clear() reinstalls
   the style. The hall's roof casts no shadow; the figures' shadows fall straight down. data/gym.json hall.light #a88b7e:
   the ice measures median sRGB (162, 144, 169) against thirdjam's film (158, 140, 150) near, (182, 168, 180) far.
   Style blocks of the kernel suite, run uncapped after the change: style.* 10/10 PASS (walker.ink, first_reject, switch,
   frame.focus, frame.rig, frame.pixels, frame.rink, cel.frame, cel.camera, cel.exe_aa ...), surf.* + celsurf.* 14/14 PASS
   (surf.classic_source: toon.gdshader byte for byte the base).

GATES
hokej verbs: lint PASS (2,189 lines, bypasses []), smoke PASS (3,600 frames), invariants PASS (above; frame p99 0.793 ms,
  many p50 0.508 ms), bots 8/8 PASS: match_hand, w_away, s_lock, aim, aim_anchor, gym_hand, tj_replay (camera = thirdjam's
  rendered camera, 9,329 steps, 0.54 cm), and the gym hand's oracle compare still PASS.
selftest blocks (uncapped, after the kernel and style changes): style. 10/10, surf. 14/14 (with celsurf), rink. 3/3
  (rink.smoke e9e795069734352c, trace_head 51/51, trace_t5 21/21), k1. 6/6, k4. 9/9, p7. 20/20: 0 failed.
tl check --tier fast: arch 12/12 (api-v1 1.18: 46 classes, 699 members), assets 4/4, cards 3/3, devx.test 229/229 PASS;
  foreman.typecheck NOT RUN (no foreman/node_modules in this worktree).
tl check --tier full: NOT RUN this round (last round's run: kernel.selftest timed out at 1,800 s with 124/125 passed on a
  loaded machine; the blocks above are the ones this round's changes touch). Please run it on a quiet machine at landing.

CHANGED FILES
engine/kernel/api/tl_cores.gd (+uid) and the tl_context.gd hunk: K1's kernel entry, copied BYTE FOR BYTE from hk-core
  (cmp identical; the same diff hunk) so this pack runs before K1 lands; engine/kernel/API.md section 24 = K1's text, header
  1.18; engine/kernel/runner/manifest.gd KERNEL_API 1.18 (K1's number); docs/generated/* regenerated (tl arch --index).
engine/style/tl_style_hall.gd (+uid): NEW, the hall light rig.
engine/packs/hokej: pack.json (kernelApi 1.18, bot_match_hand first), README.md, data/match.json (new), data/gym.json
  (hall.light), gen/tj_rink.gd (team colour and name for the figure, the puck, the hall's roof casts no shadow),
  scripts/main.gd (rewritten: the match on the core; gym and replay as proof modes), scripts/human_input.gd (new),
  scripts/match_view.gd (new), scripts/hit_stop.gd (new), scripts/skate_standin.gd (snapshot keys of the core's shape),
  tests/bot_match_hand.gd (new), tests/bot_rule_*.gd and bot_gym_hand.gd (the gym through the new key actions).
docs/shifts/2026-11-24-night/lanes/K3-shell: ROUND-3.md, REPORT.txt, STANDUP.md, r3_sbs_film_20s.mp4, r3_sbs_sheet_a.jpg,
  r3_sbs_sheet_b.jpg, oracle/{make_button_oracle.sh, button_main.cpp, ue_shim_input.h}, proof/{core_replay.gd,
  buttons_port.gd, buttons_compare.py} (+uids).
Behaviour changes elsewhere: none (the hall rig acts only when a pack asks; tl_cores/tl_context as K1's).

DEVIATIONS (new or changed this round)
1. The input rules are the pack's own port (MOVES TO CORE GLUE) until K1's v1.1 lands; signals 1-4 not given meanwhile.
2. R = core.reset(seed) (thirdjam's RestartMatch: UJamSim::Restart on the same seed, rules, zones, effects and brain reset).
3. A key pressed and released inside one physics frame is not seen (the kernel samples key states per frame).
4. CarrierReachM for the in-reach test is max(shot.reach_m, 0.4 + stick reach 1.2) + 0.05 = 1.65 m; thirdjam's Eff()
   lets an effect (a boost) change shot reach: the regular cut has none; K1's glue reads the sim's own.
5. The hit-stop's figures and puck hold is the stand-ins' (K2's pawn owns AJamSkater::BeginHitStop); the camera hold is
   thirdjam's rule.
6. The hall light acts on the whole process (a dungeon, tl play), not per pack in a shared world.
7. A blade the sim has not placed (more than 3 m away) is drawn ahead (stand-in rule).
8. The first frame shows no light-hold fade (thirdjam's TickLightHold).
Still standing from rounds 1-2: no glass, the move reads the last sim frame's camera yaw, netting as square cords,
B's line paint widths unread, no arena, the gym's stand-in law (proof mode only now), Shift/Ctrl of either side.

QUESTIONS FOR THE DIRECTOR
1. K1's v1.1 (raw mode, rink_gamemode.cpp) and its kernel entry are not in this tree; I copied the entry byte for byte so
   the pack runs. Land K1 first, then this; the pack then swaps human.read() for core.set_raw_input(raw) (one call), and
   signals 1-4 come with it. Should I do that swap as soon as K1 lands, and drop human_input.read() (the oracle stays as
   the check on K1's glue)?
2. The proof "the same raw input through thirdjam's own playtester path": with v1.1's last_human_input I can (a) feed
   my raw() stream to K1's glue and compare FJamInput per frame with mine, (b) record the playtester's FJamInput and
   play it through the shell. Is that the proof you want, or does K1's runner take a recorded raw stream?
3. PACK.md and API.md section 2 need the `ctx.cores` row (K1's note) and a line for TLStyleHall (style, new entry).

NEXT THREE
1. Swap to K1's raw glue when it lands; signals 1-4; rerun the button oracle against the glue.
2. K2's pawn in place of the capsules (draw_skater's seam), with its hit-stop hold.
3. The tempo rows and the hand ladder with a smoother scripted hand (or the playtester's inputs) through the shell.
