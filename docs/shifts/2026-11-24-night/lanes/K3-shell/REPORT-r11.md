K3 SHELL, ROUND 11 REPORT (24 Nov; worktree .claude/worktrees/hk-shell, uncommitted, on hokej 8fff52d)

OUTCOME
The owner-ready build at hokej's head:
- K2's celebration and equipment are wired.
- The Third Life cut is a second choice: a data flag, because HOME has no mode row.
- Each cut opens its own core. The regular cut hashes exactly as before.
- The whole first match is filmed again with K7's shadows and the celebration, beside thirdjam's film, and looked at.
- The exe is exported and checked.
The owner's command is under 4.

1. THE CELEBRATION (scripts/match_view.gd, main.gd).
   - boost = ctx.cores.view_script("rink", "boost_look").new(); boost.abilities = abilities_of(cartridge).
   - Each frame:
     - boost.deliver_events(snap, pawns) runs with the bus events, before skater_show's step_sim (DeliverEvents,
       HokejGameMode.cpp:1504).
     - boost.sync(snap, pawns) runs after the hit read (AJamBoostAura::Sync, cpp:1744).
   - This is K2's REPORT-r6 "FOR K3" wiring, line for line.
   - On film (r11_celebration_strip.jpg, frames 3560-3760, the first goal): a blue mate throws his arms and stick up under
     the GOAL banner.
2. THE THIRD LIFE CUT.
   - Copied K8's hockey.thirdlife.cartridge.json and hockey.thirdlife.rules.json into data/.
   - The two cartridges' game sections are identical. The cut is the rules sidecar (net_carry_wall), which makes
     ctx.cores.open open the rule-patched core, RinkCoreThirdlife (kernel 1.27).
   - HOW THE PLAYER CHOOSES: data/match.json `cartridge` (default hockey.regular.cartridge.json). This is a data flag, not
     a choice on screen: K5's HOME has no mode row (front.gd: "SEASON, MODES ... are not ported"). A MODES row is K5's to
     add; it would set this the way the level does.
   - PROOF that each opens its own core:
     - tests/bot_cut_cores.gd (new, in pack.json) PASS. It opens both cuts beside the pack's own core:
       - hockey.regular: RinkCore, 7,621 frames, 3:1, hash d29b7bac2cd5317f.
       - hockey.thirdlife: RinkCoreThirdlife, 7,621 frames, 3:1, hash 5244f9c417eea7e7.
       - Both are bots-only matches from seed 1; they end on different hashes.
     - The pack itself on the Third Life cut (match.json flipped for one run, then put back): bot_first_match at ROOKIE
       PASS, 3:0 in 6,295 frames, core hash 234493d46ba8a8a0. The regular cut gives 6f45bf07503f05b8.
     - The same hand ends on the same score and frame count with both cuts: the net-carry rule rarely fires for it.
     - The exe on the Third Life cut (dist's match.json flipped for one run, then put back): its dungeon ran 600 frames,
       state hash 8a7bc10f21e2f913, 0 script errors, 0 engine errors. Both core DLLs ship beside the exe, and the
       sidecar ships in games/hokej/data.
   - THE REGULAR CUT HASHES AS BEFORE:
     - bot_match_hand core hash ab881a00fb9af8ef.
     - bot_first_match 6f45bf07503f05b8, as round 10.
     - invariants: idle 3b762bc25ee35dbc, the bot fd162294891897fc, as round 10.
     - The exe's dungeon: 95da6c8cccc47e0a, as round 10.
   - The HUD (K5's screen.gd:54) still reads hockey.regular's game section; the two cuts' game sections are equal, so
     nothing differs today. K5 should read the cut in force if a cut ever changes the game section.
3. THE FIRST MATCH, AGAIN, LOOKED AT.
   - Files: r11_first_match_60s.mp4 (the same 58.6 s cut as round 10, beside thirdjam's 20 s film looped),
     r11_sheet_a.jpg, r11_sheet_b.jpg, r11_celebration_strip.jpg.
   - The match is the same as round 10's (same core hash), now with K7's shadows and K2's celebration, contact and spray.
   - Most visible differences first:
     a. SHADOWS ARE THERE NOW: dark, directional, at the feet under every figure, as in thirdjam's. The difference that led
        round 9's list is gone. Ours fall a little shorter and harder-edged than thirdjam's soft long ones.
     b. THE MATCH CARD says PRO at ROOKIE in a run that skips HOME (K5's, already passed on). Through the exe's HOME it
        reads the level picked.
     c. THE CONTROLS PANEL. Ours is a six-row block. thirdjam's film shows one line of keys at the faceoff and a two-word
        strip after (K5's).
     d. BARKS. Ours are small grey lines at the bottom; thirdjam's are framed plates over the play (K5's).
     e. THE CELEBRATION shows: a mate's arms and stick up under the GOAL banner. Our human (#7, who scored) stands still.
        thirdjam's scorer would raise his stick (K2's PickScorer chose by place). K2 to say whether the human should have
        been the scorer here.
     f. The puck's halo reads yellow-green; thirdjam's is near white (round 10's deviation).
     g. Same as thirdjam: the hall and its light, the felt figures with numbers, the rings, the dial, the GOAL banner, the
        end card.
4. EXPORT AND THE OWNER'S COMMAND.
   - Build: export.sh build --no-warm PASS, tag 8fff52d 2026-11-24 21:52.
   - Check: export.sh check --no-window PASS. hokej is 95da6c8cccc47e0a in the editor binary and the exe (600 frames). The
     world has 0 script errors and 0 engine errors (editor, exe, exe copied elsewhere).
   - THE OWNER, from a checkout at hokej's head, in Git Bash at the repository root:
       bash engine/tools/export.sh build --no-warm --out .tl/dist
     then double-click .tl\PLAY-LATEST.cmd (or run .tl\dist\ThirdLife.exe). From the menu choose the dungeons, then
     "Hokej: thirdjam's match, five against five". On thirdjam's title press Enter, on HOME pick ROOKIE with Left / Right,
     then PLAY NOW (Enter). R restarts, Esc pauses.
   - Straight into it: .tl\dist\ThirdLife.exe -- --dungeon=<absolute path>/.tl/dist/games/hokej
   - The build made this round: C:\Users\kazda\kiro\third-life\.claude\worktrees\hk-shell\.tl\PLAY-LATEST.cmd
   - To try the Third Life cut: set "cartridge": "hockey.thirdlife.cartridge.json" in .tl\dist\games\hokej\data\match.json
     (or in engine/packs/hokej/data/match.json before the export).

GATES
- hokej:
  - lint PASS.
  - bots PASS: match_hand (ab881a00fb9af8ef), first_match (6f45bf07503f05b8), cut_cores (new), rule_restart,
    tj_replay (0.54 cm), level_record, hud_rules (474,995 checks), rule_signals.
  - invariants PASS: solo p99 3.94 ms of 8, p50 3.35 ms of 8, determinism, the bot twice.
- tl check --tier fast: arch 12/12, assets 4/4, cards 3/3, devx.test 229/229 PASS; foreman NOT RUN (no node_modules here).
- export build and check --no-window PASS. Full tier not run (your instruction).

CHANGED FILES
engine/packs/hokej:
- scripts/match_view.gd: boost_look.
- scripts/main.gd: the cut from match.json; boost_look's script.
- data/match.json: `cartridge`.
- data/hockey.thirdlife.cartridge.json and data/hockey.thirdlife.rules.json: new, K8's, copied.
- tests/bot_cut_cores.gd: new.
- pack.json, README.md.
docs/shifts/2026-11-24-night/lanes/K3-shell: REPORT.txt, ROUND-11.md, STANDUP.md, r11_* images and film.
No git writes.

QUESTIONS FOR THE DIRECTOR
1. The cut choice on screen: a MODES row on K5's HOME, or keep the data flag for the owner's first build?
2. The celebration's scorer (3e): K2 to check against a goal by the human.

IMAGES TO LOOK AT (docs/shifts/2026-11-24-night/lanes/K3-shell/)
r11_first_match_60s.mp4, r11_sheet_a.jpg, r11_sheet_b.jpg, r11_celebration_strip.jpg
