E1b "base" (night of 24-25 Nov 2026): what a user's cartridge puts on the rink is drawn; teams named as seen; clean top view
Tree .claude/worktrees/hk-shell, branch hk-shell at hokej 991d73e; nothing committed (the Director lands).

LANDABLE E1b

WHAT CHANGED (every shared file byte-equal in engine/templates/rink_game and engine/packs/hokej; line endings as they were:
main.gd CRLF, the rest LF)
1. scripts/rink_toys.gd (new): draws from the cartridge, never by hand:
   - game.rink.zones: thirdjam's zone decals (RinkActor.cpp:668-840: fill 0.8 cm over the ice, 25 cm rim, ZoneTint x
     (0.5 + 0.5 strength)) plus lane A69's raised ring, and a mark per kind so it reads without its colour: fast ice
     orange with speed streaks, slow ice blue with slush dots, bumper zone magenta with a rubber curb, no_shoot red
     cross-hatch, boost_only green plus; visible:false not painted; rect and circle.
   - game.rink.obstacles: box, pillar (board colour, kick plate), bumper (lane A64's magenta bollard: dark bands, lid,
     boss), goal_shield (pale wall). TLMesh + palette keys only (colours on "white"), no materials.
   - pickups: AJamPickupActor's beacon (shape by kind, pedestal, ground ring, kind colour, lowered near a skater, spin and
     bob, a shrink when taken), fed by a snapshot `Pickups` list or pickup_spawn / pickup_take events.
2. scripts/main.gd: builds the toys, steps them each sim frame; the "top" camera now fits the rink (height from the rink
   size and the window aspect, 6 % margin) and its near plane is 4 m over the ice: roof, trusses, clock and lamps are cut.
3. scripts/hud/ability.gd (new) + hud.gd: thirdjam's ability slot ("F: SHOTGUN  READY", HUDWidget.cpp:656-668/934-947,
   HokejGameMode.cpp:1590-1613: state ON n.ns / NEXT SHOT / ns / READY, xN charges, the cooldown fill), above the radar,
   only when the cartridge has game.abilities. hud.gd stays at 600 lines (the arch ratchet).
4. scripts/hud/skin.gd + captions.gd: team words as the person sees them:
   - names as written in the skin (no lower-casing: "the Glare Foxes", not "glare foxes");
   - a bare colour word that is not its team's colour in the cartridge becomes the colour seen (job 1's pond: team 0
     #D83A34 under the base's "Blue" now reads "Red": no more "It's in, for blue!" when red scored);
   - plural names: new optional skin key `team_plural` [bool, bool] (absent = guessed from the name: last word ends in a
     single s); lines read "Sharks shoot!", "Clean win for the Gulls.", "Gulls are a skater short.", "Sharks help
     themselves.", "Welcome to the rink: the Sharks against the Gulls"; "the blue line" is left alone.
   - thirdjam's own names (Blue, Orange, singular) leave every line exactly as before (hokej unchanged).
5. tests/bot_skin.gd (carried, both): the casing check follows the new rule; 9 pure grammar/colour cases added.
6. Template only: tests/bot_toys.gd (in pack.json tests: every visible zone painted, every obstacle standing, pickups
   when reported), README.md (the toys, the team words, the pickup limit).
7. engine/tools/selftest.d/852-rink-toys.sh: rink.toys (every zone kind incl. a hidden one, every obstacle kind: zones 6
   of 6, obstacles 7 of 7), rink.team_words (teal Sharks v gold Gulls: 'Sharks shoot!' / 'Clean win for the Gulls.'),
   rink.top_view.

HOKEJ STAYS HASH-EQUAL (baseline = a copy of hokej at 991d73e, same machine)
- bot_first_match fe4dd45844ce33de (core 6f45bf07503f05b8), bot_match_hand fd162294891897fc (core ab881a00fb9af8ef),
  bot_skin 0b476bdc7f9d4518, bot_tj_replay 4341753bf4227a11 (worst 0.54 cm), bot_cut_cores b7240b3b2e392418: equal to
  the baseline. All 14 hokej bots PASS (bot_hud_rules 474,784 checks, 0 failed). Nothing in the sim or _pack_state moved.

GATES
- selftest rink.: 37 PASS + rink.playtester_seat PASS on its own (the tree lacked the gitignored local build
  bin/rinkcli-thirdjam.exe; copied from hk-int's bin, then PASS). Includes rink.template (41 files equal hokej's).
- selftest hokej.: 5/5 PASS. selftest style.: 10/10 PASS.
- tl check --tier fast: 5/5 PASS (arch, assets, cards, devx.test 229/229, foreman.typecheck after `npm ci` in foreman/).

PROOF PACKS (.tl/e1b/, gitignored; template copies with a user's data)
- slush: E5 job 2's cartridge and skin as they were (6 zones, 4 corner bumpers): bot_toys zones 6 of 6, obstacles 4 of
  4; bot_first_match PASS (ROOKIE 3:0 in 1,462 frames: a goal flood on rookie, a balance matter, not the base's).
- pirate: E5 job 3's cartridge (teal #0FB5AE v gold #F2B51D, first goal wins) + a skin Sharks/Gulls: bot_skin PASS,
  bot_first_match PASS 1:0 in 2,283 frames.
- shotgun (thirdjam mode, ability from the start): the HUD plate. arsenal (pickups): bot_toys says "pickups NOT REPORTED".

STILLS (window, 1280x720, looked at)
- e1b_job2_follow.jpg: game camera in job 2: slow patch (blue, slush dots) beside the player, fast lane (orange) and a
  magenta corner bumper beyond: what E5's critic said was missing.
- e1b_job2_top.jpg: the whole job-2 rink from the top: two fast lanes, four slow patches, four bumpers; no trusses.
- e1b_pirate_follow.jpg: teal v gold, caption "Welcome to the rink: the Sharks against the Gulls, first period."
- e1b_pirate_top.jpg, e1b_hokej_top.jpg: the top view clean (compare E5's topcam_fix_pond.jpg with trusses across).
- e1b_shotgun_ability.jpg: "F: SHOTGUN  READY" above the radar.

NOT DONE / ASKS
1. Pickups cannot be drawn yet: RinkCore's snapshot carries the sim's events only (rink_core.cpp snapshot: S.GetFrameEvents);
   UJamEffectSystem keeps its pickups (GetPickups) and its pickup_spawn / pickup_take events (its own FrameEvents) to
   itself. Ask K1/E2 (core): add to snapshot() a "Pickups" list from Sim->GetSystems().Effects->GetPickups()
   ([{Id, Kind, Pos}]) and/or append the effect system's frame events to "Events" (SNAPSHOT.md addition only). The base
   draws them the frame either appears (rink_toys.gd _sync / events); bot_toys then checks them. No base change needed.
2. Seen in the top view, not fixed (pre-existing, HUD): the human's ring is drawn as for the follow camera, a large
   ellipse off the figure (all top stills). The critic will see it; the HUD could hide rings when "top" is active.
3. bot_toys adds a ~10 s runner call to every user game's verification (it is in the template's test list).
4. Effects on skaters (a boost's glow, EFFECT boosts) are not in the snapshot either (boost_look.gd NOT PORTED note).

FILES
engine/templates/rink_game/{scripts/rink_toys.gd, scripts/main.gd, scripts/hud/{ability,hud,captions,skin}.gd,
tests/{bot_skin,bot_toys}.gd, pack.json, README.md}; the same scripts and tests/bot_skin.gd in engine/packs/hokej;
engine/tools/selftest.d/852-rink-toys.sh; this folder.
