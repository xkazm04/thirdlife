H2b (the base and the core), day run 25 Nov 2026. Tree .claude/worktrees/d25-hard-b at main 29c5a81 (H2 landed as 1969842).
Items 1-3 and the Director's item 5 (three-way rebase) done; item 4 (top-view ring, Boosts glow) done too, before the 17:10
message arrived (small; leave it out if you prefer: it is separable, see FILES). H2c (Create games' budget class) NOT started:
it waits for H2b to land.

== 1. A skin commentary line with no voice: text only, never an error ==
- Reproduced in a WINDOW first, on a copy of .tl/proof-games/arsenal_v014 (.tl/h2b/arsenal):
  `tl.sh capture --cam=follow --frame=600 --hud=on` -> ok:false, "rink audio: no voice for commentary line 'faceoff.drop.04'
  [frame 89]". Cause: engine/cores/rink/audio/rink_audio.gd say() push_error'd for any line without a recorded voice; the
  booth speaks only on a drawn frame (main.gd _present), so every headless check passed.
- Fix (rink_audio.gd say): no voice = the line is said as text only (the caption shows it), the voice playing before it
  fades as a cut line does, a "voice_none" row records it; no error.
- After: the same capture -> ok:true, no "rink audio" error (h2b_arsenal_window_f600.jpg); the hint stills below show the
  skin's own unvoiced line "Winch hunts the carrier. Hits hard and straight." as a caption, no error.
- Tests (block 867): rink.voice_none (headless, cores/rink/audio/review/voice_none_case.gd: voiced / unvoiced / voiced ->
  voice, voice_none, voice rows; fails on the old code: push_error and no voice_none row) and rink.voice_none_window (a
  template copy whose skin brings its own unvoiced bank, captured in a window with the HUD on: passes).

== 2. A pack's hint slot that never overlaps the captions ==
- New scripts/hud/hint.gd (template and hokej, byte-equal; rink.template passes). A game says
  `ctx.root.set_meta(&"rink_hint", "F: BUBBLE  Green spots reload it")` each frame it should show (""/absent = none);
  screen.gd hands it to hud.gd as ui "pack_hint"; hint.gd draws it on a dark plate in the HUD's look, left-aligned with the
  controls panel just above the room the panel keeps, and moves it up past anything it would touch among the caption's two
  places at their widest and the caption drawn this frame (captions.gd now records last_rect). hud.gd stays at 600 lines.
- tests/bot_hint.gd (template; selftest 868 registers it in its copy): a recorded match fed to the base's own hud.gd, a
  hint on every frame, three screen shapes (16:9, 4:3, 21:9): on the OLD hud "hint drawn on 0 of 9000 frames" (FAIL); now
  "hint drawn on 9000 of 9000 frames, beside a caption on 3278, never touching it or the faceoff hint" (PASS).
- Stills (window, LOOKED AT): h2b_hint_g1_vs_slot.jpg: left G1's own bottom label "F: BUBBLE  It comes back 8 s after you pop
  it" printed right over the caption; right the same game with its two lines changed to the slot: the hint on its plate above
  the controls panel, the caption clear at the bottom. Frame 400 too (slot_hint_f400): hint and caption apart.
- G1 adopts it by replacing `hud.add_label(&"harbour_prompt", "", &"bottom")` / `hud.set_text(&"harbour_prompt", text)` with
  `ctx.root.set_meta(&"rink_hint", text)` (that is exactly what my proof copy did). README documents the slot.

== 3 + 5. Rebase: the base's test list carried; a game's own edit kept when the base did not change the file ==
- 3: on a job, the move now re-writes the plan's base package registers (plan_set: the newest base's tests first, united
  with what the plan had; phases, card and every package state kept): a later change composes pack.json from the plan and
  keeps the newest base's bots. Test "H2b: the plan follows the base": rebase, then a change -> version 3's pack.json still
  lists the newer base's bot (fails on the old code: the plan never had it).
- 5 (Director, 17:10): three-way. For a script/test/gen/asset the game changed: if the newest base did not change it since
  the game's base (the job's ref/base copy equals the newest; for a bare pack: the base's git history holds only the newest
  version), the game's version is KEPT ("edited"); only when both changed it is it a conflict, named with what each side
  changed ("the game +3 -0 lines and the newest base +2 -0 lines since the game's base").
- Reproduced on a COPY of G1's job (.tl/h2b/g1job, from d25-arsenal's .tl/jobs/three-against-three-hockey-20261125-1,
  read-only source): before: "CONFLICT 1 scripts/main.gd" although ref/base main.gd == the newest base's (cmp). After:
  "edited 1 scripts/main.gd: the game's own changes, kept", then lint, smoke, bot_match_hand, bot_first_match, bot_skin,
  bot_toys, bot_harbour all ok -> PASS, promoted @0.1.8 in the copy; its main.gd is byte-equal to v0.1.7's (the harbour
  wiring kept) and scripts/hud/hint.gd arrived.
- Tests: "H2b: a game's own change to a base script the newest base did not change is kept" (fails on the old code: exit 1,
  refused) and "a script both changed is refused, named with what each side changed" (+ bare-pack three-way cases).
  foreman/src/test/h2_rebase.test.ts: 6 of 6.

== 4. (from my next three) the follow ring in the top view; the Boosts glow ==
- Cause found: the runner's still grabs a HUD frame drawn for the pack's active camera ("follow") and only then activates
  the capture's camera with the tree paused: every world mark of the HUD (rings, YOU chevron, badges) was projected for the
  follow camera and printed on the top image. Fix: kernel/runner/worker.gd activates the capture's camera on the frame BEFORE
  the grab, for HUD-on stills only (strips and HUD-off captures unchanged; 4 lines). The base also draws no ground rings when
  the "top" camera is the one seen (screen.gd ui "top_view"; hud.gd _ring).
  h2b_top_ring_before_after.jpg (LOOKED AT): left the big blue ellipse off the figure, right none, the chevron on the figure.
  bot_hint checks it too: rings on 4390 follow frames, 0 top-view frames.
- Boosts glow: cores/rink/view/boost_look.gd sync tells a figure SetBoost(kind) when the snapshot's Boosts changes for it
  (thirdjam HokejGameMode.cpp:1696-1703); never called for a skater never boosted (hokej untouched). Block 869
  rink.boost_glow (recording pawns: calls on change only; fails on the old code: no call). NOT seen in a still: the rig's
  glow is jersey_emissive 3.0 against 2.0, and my two follow stills had no boosted skater in view.

== GATES (tree as it stands) ==
- hokej bot hashes, all 14, before (HEAD copy of the pack) and after: IDENTICAL, all passed:
    bot_match_hand fd162294891897fc  bot_gym_hand 83e7ddd8360faed6  bot_rule_w_away c69a8362eda1d6b1
    bot_rule_s_lock ed4ae31c4537d66a  bot_rule_aim 85e156b868c93dd0  bot_rule_aim_anchor 51848c0a83b7c4d9
    bot_tj_replay 4341753bf4227a11  bot_rule_restart a81ec62c09aca9f5  bot_rule_signals db66e2a271264059
    bot_hud_rules 3905d475ae359ba0  bot_level_record b80f28fdb0a38050  bot_first_match fe4dd45844ce33de
    bot_cut_cores b7240b3b2e392418  bot_skin 0b476bdc7f9d4518   (.tl/hashes-h2b-{before,after}.txt)
- k.sh selftest: 120 passed, 0 failed.
- selftest rink.: 45 cases: 43 PASS in the block run + rink.voice_none_window and rink.hint_window, which failed there only
  because I named that run's report folder "st_rink." (Windows cannot create a folder ending in a dot: "Could not create
  directory"); both PASS in their own runs, before and after (st867/st868, st_vnw/st_hw). 40 on main + 5 new.
- selftest hokej.: 5 PASS. Blocks 867, 868, 869: 5 of 5 PASS.
- selftest create.: 19 PASS of 20 (rebase 4, iterate.path, go 3, estimate 3, toys 2, schema, model, door, page, site,
  complete) and create.pause.path FLAKY: in this round it failed in 2 of 3 clean runs and passed in 1 (in H2: 1 failed, 1
  passed), at a different card each time ("quality retry/change/accept is sent (the page waits for the Foreman)"); its check
  reads page.busy 6 frames after a press, and a fake-adapter Foreman that answers inside those frames clears it (a race).
  The Director's merged tree had it green. None of my edits touch the pause cards or busy. Two other create. failures in one run came from my rebuilding
  foreman/dist while that block's Foremen ran; the rerun passed them.
- foreman npm test: 396 tests, 389 pass, 0 fail, 7 skipped (main 394 + my 2).
- tl check --tier fast: PASS arch 12/12, assets, cards, devx.test 229/229, foreman.typecheck. EXIT 0.
- tl check --only world: PASS [9/9] (worker.gd changed after it ran: captures only, the world gate runs no capture).

== FILES ==
engine/cores/rink/audio/rink_audio.gd; engine/cores/rink/audio/review/voice_none_case.gd (+uid);
engine/templates/rink_game/scripts/hud/{hint.gd (new), hud.gd, captions.gd, screen.gd} = engine/packs/hokej/scripts/hud/ same;
engine/templates/rink_game/tests/bot_hint.gd (new, template only); engine/templates/rink_game/README.md;
foreman/src/{rebase.ts, cli_rebase.ts, test/h2_rebase.test.ts}; engine/tools/selftest.d/{867,868,869}-*.sh;
item 4: engine/kernel/runner/worker.gd (4 lines), engine/cores/rink/view/boost_look.gd, cores/rink/view/boost_glow_case.gd
(+uid), and the top_view lines in hud.gd/screen.gd.
Stills here: h2b_arsenal_window_f600.jpg, h2b_hint_g1_vs_slot.jpg, h2b_top_ring_before_after.jpg.

== FOR THE DIRECTOR ==
- G1 can now: take the newest base from My games (its main.gd edit is kept), then move its prompt to the slot (two lines).
- Contracts: RUNNER.md could say a HUD-on still is drawn through its camera from the frame before (worker.gd change).
- create.pause.path is a race (above); worth a look by its owner (stage_pauses.gd:110-111 waits 6 frames, then reads busy).
- H2c (budget class for Create games) is next; I have not touched it.
