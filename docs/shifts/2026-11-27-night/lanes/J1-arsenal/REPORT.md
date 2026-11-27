J1-arsenal REPORT (night 27 Nov 2026, tree d25-arsenal, branch n27-arsenal at b1ee0b1d; nothing committed, the Director lands)

THE ABILITY: the meteor slapshot. F lights the stick; hold shoot to wind up; let go: the puck leaves at twice the speed,
trails fire and knocks down every skater within 1 m of its path (the rink core's own `shotgun`, so the knockdowns are the
C++ sim's, not a drawing); back 12 s after each use; a skater winding up stands at 0.6 of his stability.

BEST PACK: C:/Users/kazda/kiro/third-life/.claude/worktrees/d25-arsenal/.tl/juice/arsenal_hand  (game.three_against_three_hockey 0.1.22, by hand over the job's v0.1.21)
MENU TITLE: "Arsenal hockey: meteor slapshot (juice by hand)"
Optional editor row: .tl/jobs/three-against-three-hockey-20261125-1/promoted/game.three_against_three_hockey@0.1.23  "Arsenal hockey: meteor slapshot (editor)"

ACCEPTANCE
- Juice sheet before the first sentence: MET (PROOF-J1-arsenal.md, 05:11; sentence sent 05:12).
- Each ability first as a Create change sentence on the real job, with time/tokens/path/outcome: MET.
  round 1 (05:12:01-05:23:43, 11.7 min, 0.77M in, full path): the Planner named the drawing package; its builder wrote
    the exact cartridge edit as "outside my scope"; v0.1.22 promoted with a thin fire puff + flash + kick, rules unchanged.
  round 2 (05:25:51-05:35:25, 9.6 min, 0.58M in, cartridge path, diff refused twice -> one builder round): v0.1.23
    promoted with the meteor's rules byte-equal to the by-hand cartridge.
- blocked-editor lines with evidence: MET (STANDUP.md, PROOF):
  1. a play change went to the drawing package; the cartridge edit it named word for word was never carried to the
     cartridge's owner; v0.1.22 promoted without it (job events 1008, 1012, 1039-1042).
  2. the builder said "the cartridge has no key" for a charged shot and for weakness while winding up; both keys exist
     (shot.charge_frames_max/charge_speed_bonus, contact.spin_stability; event 1012).
  Minor: v0.1.23's note says "removed: 2 shields ... why: not said" though the sentence said why; no question before
  the removal on the builder path. v0.1.23 shows two names (CANNON hint, SHOTGUN plate).
- Built by hand where the editor fell short: MET (.tl/juice/arsenal_hand: scripts/meteor.gd, main.gd gate, tuning, skin, tests/bot_meteor.gd).
- Clip <=20 s: MET for the hand (clips/hand_meteor.mp4, 19.3 s, final take 06:04; take1 05:39) and for the editor (clips/editor_v0123_meteor.mp4, 19.5 s).
  "a bot using it": NOT MET, cannot be: the rink core gives no ability to bots (CARTRIDGE.md:475) and has no dive verb.
- Stills looked at: MET (11 single/sheet stills by hand, 2 editor sheets, 2 pre-gate sheets).
- 3600 headless frames, 0 script errors, bots' uses/minute: MET. Hand 2-5 meteors a minute over seeds 1-3; bots 0 (core).
- Same hash twice: MET. seed 1: run 097fcaa8 twice (core 8a2b5987); earlier builds c651f4fb twice, b7b4b1a3 twice.
- PROOF says editor vs hand and how it feels: MET (Verdict table).

GATES
- tl check --tier fast: PASS (arch 12/12, assets 4/4, cards 3/3, devx.test 230/230, foreman.typecheck clean).
- hand pack: lint PASS; smoke 3600 f PASS; bot_meteor seeds 1,1,2,3 ok, 0 errors; bot_first_match ok (13:3), bot_skin ok,
  bot_toys ok. bot_harbour removed from the hand manifest (it drills the bubble that this version removes; named).
  bot_header/bot_hint are not in the manifest (as in v0.1.21).
- No kernel/kits/rigs/style/seeds/engine/foreman/contracts file changed: full tier not required.
- Windowed captures print "SCRIPT ERROR: Cannot call method 'lock' on a null value" from kernel/runner/worker.gd:387 at
  quit (the movie writer's --quit-after; J2's captures show the same); not the pack's.

MEASURED (lab: the core playtester on the cartridge alone, without the pack's faceoff gate, 40 seeds)
  pro: wins with F 39, without F 23, bare rink 28; 14.8 F a match; knockdowns 34.2 vs 20.8. all_star 40/37/30.
  A 20 s cooldown: pro 37/23. The meteor decides matches for this hand: crazy, not fair.

CHANGED FILES (all untracked, for the Director)
- docs/shifts/2026-11-27-night/lanes/J1-arsenal/: PROOF-J1-arsenal.md, STANDUP.md, REPORT.txt, clips/ (2 mp4), stills/ (12 jpg)
- .tl/juice/arsenal_hand/ (pack copy; .tl is not tracked): data/harbour.cartridge.json, data/skin.json,
  data/tuning.json, scripts/meteor.gd (new), scripts/main.gd (+hook, +_meteor_gate), tests/bot_meteor.gd (new), pack.json
- The real job: two change requests, v0.1.22 and v0.1.23 promoted (the job's own record).
BEHAVIOUR CHANGES (hand pack against v0.1.21): the bubble and the green-spot tricks are gone (F is the meteor); shots
charge; F is held back during a faceoff and 60 frames after the drop.

FOR THE OWNER: play it and lose a few meteors to checks while winding up; watch whether the net and the glass read
(they did not on film, at the follow camera's distance).

QUESTIONS FOR THE DIRECTOR
1. Route blocked-editor 1 and 2 to lane T (a play request the drawing package names for the cartridge should be carried
   there, not promoted without it; the builder's "no key" claim should be checked against CARTRIDGE.md).
2. Bots using an ability / diving to block is a core patch (native/patches-thirdlife). Worth a lane?

NEXT THREE: make the net/glass read (bigger, or a goal camera beat); the bot meteor + block as a core patch; balance
through TLHand regular/newcomer (20 s cooldown, a minimum charge before it is a meteor).
