K5 screen: REPORT, round 3 (landable), 23 Nov 22:35. Worktree .claude/worktrees/hk-hud at hokej ddd357f + this round.

OUTCOME
1. Pause card: MET.
   - Kernel pieces (yours to number 1.24; the version lines stay at the branch's 1.22):
     ctx.own_pause / can_pause / pause / resume / leave_game / paused, TLHud.on_paused, ctx.input.menu_keys,
     ctx.cores.opened.
   - ctx.leave() was already taken: it is the context's own static, TLContext.leave(before). So the frame's Leave is
     ctx.leave_game().
   - thirdjam's card (pausecard.gd): its rows, words and hints. RESTART presses the glue's R. QUIT TO MENU asks
     LEAVE THE MATCH? first.
   - Other dungeons keep the frame's card. Both cases are tested in selftest 830: hokej.pause_own and hokej.pause_frame.
2. The menu: MET for what a player needs.
   - The title and HOME (PLAY NOW, the level row and its line, ONE MATCH, YOUR STICK, header, footer), drawn before the
     match's frame 0 while the frame holds the pack paused.
   - The lit level reaches the core (set_difficulty + reset before frame 0); the MATCH card names it.
   - Not built, and listed in HUD.md: SEASON, MODES, PLAY WITH A FRIEND, CONTROLS, SETTINGS, CREDITS, QUIT, and keeping the
     level for next time.
3. The first 30 seconds as a newcomer meets them: MET in stills, LOOKED AT.
   - Path: title -> HOME -> ROOKIE -> PLAY NOW -> light hold -> MATCH card -> dial and hint -> drop -> the welcome line ->
     play -> pause card -> leave confirmation -> resume -> restart -> leave.
   - The stills come from a window probe of the exe's dungeon frame. They sit beside thirdjam's own front-end (menu-3) and
     one-look stills in r3_sbs_sheet.jpg.
4. Bark bubbles and the bark lane: NOT BUILT. HEAD ships them on (jam.hud.BarkLane 1). They are a second booth of about
   1,000 lines (BarkSystem.cpp 622, BarkWidget.cpp 385); round 4.
Folded in from your 20:xx notes:
- The head point now comes through the call; main.gd's line is below.
- The keep-clear box is the figure's bones (+14 cm); the capsule's bounds are only the fallback.
- A caption yields to a distance label.
- The answers on the panel, the plates, "HE JUST GOT IT", "Blue shoots!" and the chevron are in ROUND-3.md.

THE ONE LINE FOR main.gd (K3's file; you merge it)
    screen = Screen.frame_of(screen, ctx, snap, null, last_in, last_raw, view.head_world(int(snap["HumanIndex"])))
  The 7th argument is the head socket in the world, or null. K3's `screen.view.head_m` keeps working as the stand-in fallback.

VERSION LINES FOR YOU TO NUMBER (1.24)
  engine/kernel/runner/manifest.gd:7   const KERNEL_API: String = "1.24"
  engine/packs/hokej/pack.json:4        "kernelApi": "1.24"
  (I wrote 1.24 in API.md section 26 and in the comments. The 830 fixture pack declares 1.22 and stays compatible.)

KERNEL FILES TOUCHED (for the contract's wording)
  engine/kernel/api/tl_context.gd   paused, owns_pause, _pause_hook, _leave_hook, own_pause(), can_pause(), pause(), resume(), leave_game()
  engine/kernel/api/tl_input.gd     _menu, menu_keys(), _menu_key()
  engine/kernel/api/tl_hud.gd       _paused_handler, on_paused(), _paused_tick()
  engine/kernel/api/tl_cores.gd     opened(id)
  engine/kernel/dungeon/dungeon.gd  _pause_asked; the hooks set in open(); the pause asked during the load starts after it;
                                    _input: menu keys and click to an owning pack; _pack_owns_pause(); pause()/resume() keep
                                    ctx.paused and skip the frame's card for an owner; _process calls the HUDs' painter while paused
  engine/kernel/API.md              section 26 (appended)

GATES
PASS  hokej lint
PASS  hokej smoke
PASS  bots 10/10 (bot_hud_rules: 152,736 checks, 0 failed)
PASS  selftest 830: 4/4 (hud_rules, hud_layer, pause_own, pause_frame)
PASS  dungeon 640: 5 of 6 (list, bypass, refused, hash_alone, watchdog)
FAIL  dungeon.trips: not this lane. The case compares dungeon index 0 (now hokej, since K3's 39c6a39) with packs/hockey's
      alone hash. The trip's hash 6e9c32c23eaf is hokej's own alone hash.
FAIL  hokej invariants: hashes equal (ad03a2add6ce42c1 / 4685cd21e60096f0), but many_budget is p50 2.75 ms against 1.0, and
      frame p99 is 3.8 ms against a 4 ms budget. The same 2.75 ms with the HUD's call removed: it is the branch's figure
      drawing since round 2, not the screen. seed_paddle measures 0.17 ms at the same time.
FAIL  fast tier as cut: arch (api-index-fresh, api-v1) and devx.test 226/229, only because the new kernel members are
      unnumbered and the index is stale. assets, cards and foreman.typecheck PASS.
(no full tier, as ordered)

CHANGED FILES
- kernel: the six above.
- pack:
    engine/packs/hokej/scripts/hud/front.gd, pausecard.gd, kit.gd (new).
    engine/packs/hokej/scripts/hud/screen.gd, hud.gd, flow.gd, cards.gd, captions.gd, markers.gd (changed).
    engine/packs/hokej/assets/hud/T_UI_Button_Normal.png, T_UI_Button_Focused.png, T_UI_Button_Disabled.png,
      T_UI_Segment_Lit.png, T_UI_Segment_Unlit.png, T_UI_HeaderBar.png, T_UI_MenuBackdrop.png (new, exported once).
- selftest: engine/tools/selftest.d/830-hokej-hud.sh (+2 cases with a generated fixture pack).
- lane: ROUND-3.md, REPORT.txt, STANDUP.md, HUD.md, r3_sbs_sheet.jpg, r3_01_landing.jpg, r3_03_home_rookie.jpg,
  r3_05_match_dial.jpg, r3_06_after_drop.jpg, r3_08_pause.jpg, r3_09_leave_confirm.jpg, r3_12_restarted.jpg.
- The Unreal copy .tl/tj-ui is deleted (the textures are final).

BEHAVIOUR CHANGES
- In the exe: hokej opens on thirdjam's title, then HOME; the match starts at the chosen level. Esc opens thirdjam's pause card
  instead of the frame's.
- `tl play` and verify runs: no front end (can_pause() is false), no change.
- No hash change.

DEVIATIONS (new; earlier rounds in REPORT-r1.md and REPORT-r2.md)
1. CHANGE A RULE and CONTROLS are disabled rows, and there is no rule line on the pause card.
2. Esc on the title leaves to the exe's menu.
3. HOME's other entries are not drawn, and the lit level is not kept for next time.
4. Only a click on the title is read (no hover, no clicks on items).
5. The paused painter runs outside the tick's watchdog.
6. A level chosen on HOME is not in an input record (a contract question).
7. Without a head bone, the marker's lift is along the world's up.

QUESTIONS FOR THE DIRECTOR
1. The many_budget miss: it comes from the branch's figures, not the screen. Whose is it?
2. dungeon.trips: fix the case (hash index 0's pack, or pass --dungeon-index for hockey).
3. The level choice and the input record: should HOME's choice enter the record (an input) so a recorded session replays
   at its level?
4. K2: the head socket's height (the chevron's tip sinks if K2's socket is lower than device B's, which sits about 19 cm over
   the helmet).
5. Exit 139 under --quit-after: not reproduced here. My window probes quit with exit 0, after reporting leaked textures and
   resources still in use at exit.

FOR THE OWNER TO LOOK AT
r3_sbs_sheet.jpg: thirdjam left, ours right: title, HOME, MATCH card and dial, pause card, the first ten seconds.
Then r3_03_home_rookie.jpg, r3_08_pause.jpg, r3_09_leave_confirm.jpg.
In the exe: open the Hokej dungeon from the menu.

NEXT THREE
1. Barks: the bark system and the bark lane.
2. K1's fields: the panel's possession, the pass-target ring, the teach pulse, the take grace's first frame.
3. HOME's remaining entries as the campaign needs them (CONTROLS first), and keeping the level for next time.
