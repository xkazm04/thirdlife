# K3 shell: standup

17:05 | state: working | did: read DIRECTIONS, BRIEF, CameraFollow/HokejGameMode/RinkActor/InputMapping; pack engine/packs/hokej scaffolded (cam, controls, stand-in law, rink gen) | next: lint, smoke, rule tests | gates: -
17:20 | state: working | did: lint, smoke, 4 bots PASS; camera oracle (thirdjam's own StepThirdPerson compiled from its source) agrees within 0.09 mm / 0.0003 deg over 1561 frames | next: look at frames, rink table | gates: lint PASS, smoke PASS, 4/4 bots PASS
17:31 | state: done | did: landable round 1: gym pack, rink table, eye list, sheets looked at (glass stripe and crate nets fixed on sight) | next: round 2 side by side with thirdjam's rendered build | gates: tl check --tier fast PASS 4/5 (arch 12/12, assets 4/4, cards 3/3, devx.test 229/229), foreman.typecheck NOT RUN (no foreman/node_modules in the worktree; foreman untouched); hokej lint/smoke/invariants PASS, bots 4/4 PASS

landable round 1
17:45 | state: working | did: round 2 started on the Director's answers; thirdjam's rendered build run once (9,465 JAMCAM lines, 317 stills; process ended by its timeout) | next: feed its path to our camera, sheets | gates: -
18:00 | state: working | did: bot_tj_replay: our camera = thirdjam's rendered camera on 9,329 steps (worst 0.54 cm, 0.097 deg); film sheets looked at, both questioned poses stand (thirdjam f5970, f1800, f6420); goal from arena.py; hall, white boards, yellow kick plate; kernel 1.17 aim_pixel + cameras.aspect, aim anchor ported | next: full gate | gates: hokej lint/smoke/invariants PASS, 7/7 bots PASS
19:20 | state: done | did: landable round 2: our camera = thirdjam's rendered camera on 9,329 of 9,465 logged steps (worst 0.54 cm / 0.097 deg, kicks apart), both questioned poses stand in its film, goal from arena.py, dark hall + white boards + yellow kick plate, kernel 1.17 (aim_pixel, cameras.aspect), aim anchor ported | next: K1 core and K2 figure when published | gates: fast PASS (arch 12/12, devx 229/229; foreman NOT RUN); full exit 1: kernel.selftest 124/125 timed out (0 failed; tail rerun e6 3/3, n3 3/3, home 9/9 PASS), packs: hockey invariants many_budget 1.05 ms FAIL also on HEAD's kernel (A/B), hokej 8/8 PASS; perf NOT RUN (busy)

landable round 2
