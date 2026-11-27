J5-karts REPORT (night of 27 Nov 2026, 03:02-06:04). Tree .claude/worktrees/d25-kart, branch n27-kart (fast-forwarded to 6c75354c at ~04:45).
Details, numbers and stills with notes: PROOF-J5-karts.md in this folder.

OUTCOME
All three abilities were made by the editor, through Create change sentences on the real job
.tl/jobs/bumper-kart-football-3-20261125-1 (claude-cli sonnet, the change flags of engine/ui/flags/real.json):
  1. jump + flip double jump        change 1 -> v0.1.4  46 min  3.87M in / 28.5k out
  2. aerial hits on the huge ball   change 2 -> v0.1.5  61 min  ~6.5M in / 56k out (refused once by the tofu gate, then bent)
  3. air bump (flip, stomp, whirl)  change 3 -> v0.1.6  38 min  0.98M in / 12.8k out
  3b. the bots use it / whirl back  change 4 -> v0.1.7  29 min  1.25M in / 12.1k out
The aerial was also built by hand in .tl/juice/kart_hand/ while the editor was refusing it (the fallback, not the pick).

LANDABLE: best pack C:/Users/kazda/kiro/third-life/.claude/worktrees/d25-kart/.tl/jobs/bumper-kart-football-3-20261125-1/promoted/game.bumper_kart_football_3@0.1.7
Menu title: "Bumper-kart football (jumps and aerials)"

ACCEPTANCE
- Juice sheet before the first sentence: MET (PROOF, written 03:05-03:15; first sentence 03:06:30).
- Each ability first as a Create change on the real job, with time, tokens, path, outcome: MET (4 changes, PROOF log).
- blocked-editor line for every refusal/bend + by-hand build: MET. One: "the balance (tofu) gate threw core r15 away for
  skill_spread 0.241, idle_max_f 143, lead_change_share 0.286; core r16 bent the game (sweet_add 20->23, pinned-bot rule)"
  | evidence: job event 1001, reports/core-r15-tofu-bounds-s1001.json. The aerial was built by hand meanwhile.
  After lane T's fix, change 3 got the note "balance moved by your change: built as you asked ... say make it fairer" (event 1132).
- Per ability: clip <= 20 s, stills looked at, bot uses per minute, 3600 headless frames 0 errors, same hash twice: MET.
  clips/j5_v014_jump_editor.mp4, j5_v015_aerial_editor.mp4, j5_airbump_editor.mp4, j5_bot_airbump_editor.mp4, j5_hand_aerial.mp4 (all 20 s, window, d3d12 movie writer)
  stills: 10 JPGs, each described in PROOF.
  headless (3600 frames, 0 script errors, same hash twice): v0.1.4 f3c5c32c; v0.1.5 e2bfcd46; v0.1.6 efba691f; v0.1.7 f894a8bb; hand pack ece879ce.
  bots per live minute (all five together): v0.1.4 5.7 jumps; v0.1.5 20 jumps, 7.4 aerials; v0.1.7 (mean of seeds 1-5) 22.5 jumps,
  8.7 aerials, ~1.8 air hits. Caveat: v0.1.4's _pack_state carries no kart height, so its hash sees a jump only through x/z.
- PROOF says which came from the editor and which by hand, and how each feels: MET (Verdict table at the top).
- "landable J5-karts" with pack path and title by 07:00: MET (06:04).

GATES
- node devx/bin/tl.mjs check --tier fast: PASS (arch 12/12, assets 4/4, cards 3/3, devx.test 230/230, foreman.typecheck clean), 06:03.
- Full tier: not required (no kernel/kits/rigs/style/seeds change; this lane changed only docs and .tl/).
- Foreman's own final checks of v0.1.7: V0-V4 ok, hands over 20 seeds newcomer 18/20, perfect 18/20.
- Hand pack: lint ok (main.gd 598 lines, no bypasses), smoke ok, all 6 manifest bots pass, newcomer hand 6/6 seeds won.

CHANGED FILES (tree)
- docs/shifts/2026-11-27-night/lanes/J5-karts/: PROOF-J5-karts.md, STANDUP.md, REPORT.txt, stills/ (10 jpg), clips/ (5 mp4, 36 MB folder).
- Not tracked: .tl/jobs/... (job versions 0.1.4-0.1.7, logs _ui_logs/*-015..018-change.log), .tl/juice/kart_hand/ (hand pack),
  .tl/j5/ (scripts, film copies with my counting tests). Raw captures deleted (Director's disk note).
- No foreman/, engine/ or contracts/ edits. foreman rebuilt (npm run build) and engine re-imported after the fast-forward.

FOR THE OWNER
- Watch clips/j5_v015_aerial_editor.mp4 (ball high over the deck) and clips/j5_bot_airbump_editor.mp4 (a mint kart flips me).
- Play v0.1.7: Q jump, Q again in the air for the flip; hop into the ball for an aerial; land on a mint kart for a stomp.
  Nobody has played it with real keys yet: all figures come from scripted hands.

QUESTIONS FOR THE DIRECTOR
1. Menu row: add v0.1.7 as "Bumper-kart football (jumps and aerials)"? (The hand pack does not need a row.)
2. Editor finding: a change builds what the sentence says and no more; the bots used the air bump only after a second
   sentence asked for it. Should the Planner add "and the bots use / react to it" to a new verb by default?
3. Editor finding: the teams builder noted that a bot air attack has no 24-frame tell (the core owns tells), and no test
   counts air hits; worth a card rule?

NEXT THREE
1. A person plays v0.1.7 with real keys (the bar is his hand, not the scripted one).
2. Change 5: "make it fairer" if the newcomer wins too easily (18/20), and the AERIAL! call on every aerial, not only smashes.
3. A test in the pack that counts jumps, aerials and air hits per minute, so the Foreman sees the juice it verifies.
