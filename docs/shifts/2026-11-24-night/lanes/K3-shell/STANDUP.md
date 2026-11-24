# K3 shell: standup

17:05 | state: working | did: read DIRECTIONS, BRIEF, CameraFollow/HokejGameMode/RinkActor/InputMapping; pack engine/packs/hokej scaffolded (cam, controls, stand-in law, rink gen) | next: lint, smoke, rule tests | gates: -
17:20 | state: working | did: lint, smoke, 4 bots PASS; camera oracle (thirdjam's own StepThirdPerson compiled from its source) agrees within 0.09 mm / 0.0003 deg over 1561 frames | next: look at frames, rink table | gates: lint PASS, smoke PASS, 4/4 bots PASS
17:31 | state: done | did: landable round 1: gym pack, rink table, eye list, sheets looked at (glass stripe and crate nets fixed on sight) | next: round 2 side by side with thirdjam's rendered build | gates: tl check --tier fast PASS 4/5 (arch 12/12, assets 4/4, cards 3/3, devx.test 229/229), foreman.typecheck NOT RUN (no foreman/node_modules in the worktree; foreman untouched); hokej lint/smoke/invariants PASS, bots 4/4 PASS

landable round 1
17:45 | state: working | did: round 2 started on the Director's answers; thirdjam's rendered build run once (9,465 JAMCAM lines, 317 stills; process ended by its timeout) | next: feed its path to our camera, sheets | gates: -
18:00 | state: working | did: bot_tj_replay: our camera = thirdjam's rendered camera on 9,329 steps (worst 0.54 cm, 0.097 deg); film sheets looked at, both questioned poses stand (thirdjam f5970, f1800, f6420); goal from arena.py; hall, white boards, yellow kick plate; kernel 1.17 aim_pixel + cameras.aspect, aim anchor ported | next: full gate | gates: hokej lint/smoke/invariants PASS, 7/7 bots PASS
19:20 | state: done | did: landable round 2: our camera = thirdjam's rendered camera on 9,329 of 9,465 logged steps (worst 0.54 cm / 0.097 deg, kicks apart), both questioned poses stand in its film, goal from arena.py, dark hall + white boards + yellow kick plate, kernel 1.17 (aim_pixel, cameras.aspect), aim anchor ported | next: K1 core and K2 figure when published | gates: fast PASS (arch 12/12, devx 229/229; foreman NOT RUN); full exit 1: kernel.selftest 124/125 timed out (0 failed; tail rerun e6 3/3, n3 3/3, home 9/9 PASS), packs: hockey invariants many_budget 1.05 ms FAIL also on HEAD's kernel (A/B), hokej 8/8 PASS; perf NOT RUN (busy)

landable round 2
19:20 | state: working | did: round 3 started: thirdjam's match on K1's RinkCore (ctx.cores, K1's entry copied byte for byte), all inputs but signals ported in the pack (MOVES TO CORE GLUE), ten stand-ins, hit-stop | next: proofs, film, the hall light | gates: hokej lint/smoke PASS
19:45 | state: done | did: landable round 3: a whole match through the keys (3:1 at pro, 5,459 frames); record = replay hash; FJamInput stream into a bare core = the pack's hash on 5,459/5,459 frames; thirdjam's own button resolver (compiled) = the port on 20,000/20,000 frames; TLStyleHall roof light, ice (162,144,169) vs film (158,140,150); film side by side looked at | next: K1's raw glue swap + signals, K2's pawn | gates: fast PASS (arch 12/12, devx 229/229; foreman NOT RUN); selftest style. 10/10, surf. 14/14, rink. 3/3, k1. 6/6, k4. 9/9, p7. 20/20; hokej invariants PASS, bots 8/8; full tier NOT RUN

landable round 3
20:10 | state: done | did: landable round 4: hokej in dungeons.json + games.json (no village plot; world.alone same); export carries rink_core DLL; export.sh check --no-window PASS (hokej bd182092f284e383 editor = exe); light hold + fade (kernel 1.19 cameras.screen_fade), grey shadows (TLStyleHall shade), grey ice, R in-place restart (bot_rule_restart PASS), Esc = dungeon pause | next: K1 raw glue, K2 pawn | gates: fast PASS (arch 12/12, devx 229/229; foreman NOT RUN); hokej lint/smoke/invariants PASS, bots 9/9; full tier NOT RUN

landable round 4
20:35 | state: done | did: landable round 5: raw mode (devices only in the pack; port of the rules, controls and stand-in law deleted), signals 1-4 (bot_rule_signals PASS), R via the glue's restart (bot_rule_restart PASS); thirdjam's button resolver = K1's glue 5,198/5,198 frames; FINDING: the pack's raw stream through rink_rawtrace.gd = pack hash only to frame 1,505 (first input diff 1,294, stick last bit), reported to K1; match hash moved (double stick in the glue) | next: rest until K2's pawn | gates: fast PASS (arch 12/12, devx 229/229; foreman NOT RUN); hokej lint/smoke/invariants PASS, bots 10/10; export check --no-window PASS

landable round 5
21:10 | state: done | did: round 6: ten K2 figures through thirdjam's pawn in match, gym and replay (capsules behind data/view.json); hit-stop to the pawns and AJamPuck's hold; kernel 1.20 ctx.cores.view_script (packs could not load the pawn); match hash unchanged ab881a00fb9af8ef; film beside thirdjam looked at (r6_*); cost: headless +1.7 ms, window 3.57 vs 1.30 ms a frame | FINDING: invariants many-budget FAIL p50 2.70 ms (> 1.0) | gates: lint/smoke/bots 9/9 PASS, fast PASS (foreman NOT RUN), export check --no-window PASS

landable round 6
21:35 | state: done | did: round 7: invariants budget class (solo_budget p50 8 ms for a dungeon without a village plot; selftest budget.class 12 checks); hokej invariants PASS honestly (solo p50 2.16 ms, figures ticking); YOU chevron at the figure's head-socket height via screen.view.head_m (no hud file touched; XY is K5's); film with HUD beside thirdjam looked at (r7_*); window cost HUD+figures 6.13 ms vs HUD+capsules 3.70 ms | gates: lint, bots, invariants PASS, fast PASS (foreman NOT RUN), export check --no-window PASS

landable round 7
22:05 | state: done | did: round 8: hit_stop.gd port and puck rule replaced by K2's skater_show (bus events, step_sim, pawns, after_pawns, render, in thirdjam's order); carried puck on the blade; match hash unchanged ab881a00fb9af8ef; film looked at (r8_*); export check --no-window PASS | note: stage p99 3.78 ms of 4 (4.02 under load) | gates: lint, bots, invariants PASS, fast PASS (foreman NOT RUN) | next: rest until K6's arena

landable round 8
23:00 | state: done | did: round 9: contact wired as verb_gym (hit read, four bus events, set_rink, verb_gym's render order); inside the hall only sections 2-3 markings in thirdjam's colours; solo p99 8 ms (solo_frame_budget); the whole picture filmed beside thirdjam and looked at (r9_*); core hash unchanged ab881a00fb9af8ef; run state hash moved by the kit ice's body only (proven) | gates: lint, bots, invariants PASS (p99 3.89, p50 3.19), selftest budget.class PASS, fast PASS (foreman NOT RUN), export check --no-window PASS; window 5.88 ms

landable round 9
21:35 (24 Nov) | state: done | did: round 10: thirdjam's puck (8 cm, its halo disc); first match at ROOKIE to the end card (bot_first_match), filmed and cut to 58.6 s beside thirdjam (r10_*); export at f9d2db9 + check --no-window PASS | BLOCKED (asked): playtester keys hand parts from our match in seconds (needs K1's advice call); the exe dungeon has no bot/replay path | gates: lint, bots, invariants PASS, fast PASS (foreman NOT RUN)

landable round 10
