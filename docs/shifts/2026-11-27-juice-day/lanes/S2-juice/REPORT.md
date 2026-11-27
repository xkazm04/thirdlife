S2-juice REPORT: a standard juice pass for every new ability, automatic (A) or a choice in Create (B). Juice day, 27 Nov 2026.

Trees: arm A d25-robot (branch d27-sp-juice), arm B d27-sp-juice-b (branch d27-sp-juice-b), both from main 8be26d61.
Nothing is committed by me: the Director commits each arm on its own branch. Evidence and the recommendation are in
SPIKE.md beside this file; the shared pass is JUICE-PASS.md.

OUTCOME AGAINST THE BRIEF
- One juice pass, shared by both arms: MET.
  - The pass is foreman/prompts/juice_pass.md, identical in both trees.
  - It covers a tell that grows, exaggeration in numbers, hit-stop and a camera kick or follow, an impact word, particles
    and sound, a slow beat on the signature moment, and the world answering.
  - It scales down: the builder sizes the move small, big or signature first.
  - JUICE-PASS.md says where each part comes from in last night's hand layers.
- Arm A, automatic: MET.
  - JUICE_MODE "auto": a change that adds a move runs the pass, unless the words say "keep it plain".
  - The Foreman logs a note, and Create's done screen says it ran and how to leave it out.
  - Live on 2 real jobs.
- Arm B, a choice: MET.
  - JUICE_MODE "choice": the pass runs only on "make it juicy".
  - Create has a "Make it juicy" card on the change row, and a one-click "Juice that move" follow-up on the done screen
    when the Foreman offered the pass for a move built plain.
  - Window stills: stills/B-create-card-picked.jpg and stills/B-create-followup.jpg, on the real job.
  - Live on 2 real jobs with the card's words, and 2 plain.
  - The follow-up was not run as a real job: shown and selftested only.
- Robots from v0.1.5 with J2's exact hammer sentence: MET.
  - Foreman has no rollback, so the copy was set back to v0.1.5 by hand (.tl/spike/rollback_robot_v015.py; SPIKE.md
    section 3 says how):
    - the log was cut after event 929;
    - pack/ is promoted@0.1.5;
    - the workspaces were re-cut from pack/.
  - foreman status then read v0.1.5, core r12, 26.69M tokens.
- Shield wall: MET. A new crazy ability on v0.1.7, a shield throw on G that ricochets.
- Compared by eye with last night's editor and the hand version: MET for robots.
  - side-by-side clips;
  - a juice checklist;
  - the same measure on all five robot packs. Its hashes for the editor and hand packs equal J2's.
  - Shield has no throw in the night's packs, so the comparison there is A, B-juicy and B-plain.
- Cost, and whether it harms a game: MET. SPIKE.md sections 4 and 5.
- Window clips of 30 s or less and stills I looked at: MET.
  - clips/: robot 29 s and shield 11 s side by side, and a robot 5-up with the references (29 s);
  - stills/: 8 JPG.
- Headless: 3600 frames, 0 script errors, the same hash twice: MET for all 6 arm packs and both references (seeds 1,
  1, 2, 3).

RESULTS IN ONE PARAGRAPH
All six changes went through in one core round each, with no refusal or question. Robots B-juicy needed one more show
round for the end card. Where the pass ran (robots A and B-juicy, shield A and B-juicy):
- every build gained the tell, the impact word, the hit-stop and the camera/lens kick, which plain did not get;
- robots B-juicy also reached hand-level flight (4.4-4.6 m, against the hand's 3.7-5.4 and plain's 1.9-2.5), a camera
  that follows you up, and a slow beat.

Not always obeyed:
- robots A kept the slide's 28-frame flight and has no follow;
- both shield runs skipped the launch and the slow beat;
- each builder's JUICE: line says so.

Cost over plain: robots +0.8M / +1.6M tokens and +10 / +21 min; shield -0.2M / +0.7M and +2 / +1 min. Builder variance
is of the same size. The pass broke no test and did not lengthen matches: robots A 39160 frames for 3 matches, plain
40599.

Arm A's detector, audited on every real change sentence in the trees (65): it runs on 9, exactly the new moves.

Lane's pick: A, with B's card and follow-up turned round into "keep it plain", plus a Foreman check of the JUICE: line.
That is opinion, kept apart from the evidence in SPIKE.md.

GATES
- node devx/bin/tl.mjs check --tier fast:
  - A: PASS 5/5 (arch 12/12, assets 4/4, cards 3/3, devx.test 230/230, foreman.typecheck clean);
  - B: PASS 5/5, the same counts.
  - An earlier run failed the size ratchet on foreman.ts (2007 > 2005). The hooks were folded to one line each, and
    foreman.ts is now 2004.
- foreman npm test:
  - A: 465 tests, 458 pass, 0 fail, 7 skipped (main 460/453/0/7, plus juicepass.test 5);
  - B: 465, 457 pass, 1 fail, 7 skipped. The fail is cli.test "kill the Foreman mid-run, then resume", a kill-timing
    test, at CPU 100 %. Rerun alone: cli.test 10/10 pass. The code is identical to A's except the mode constant.
- selftest create.:
  - A: 31 passed, 0 failed;
  - B: 32 passed, 0 failed (29 existing plus block 812).
  - The first run in each tree stopped create.pause.path after 7 steps under load; the reruns passed.
- selftest create.juice (block 812): A 2/0, B 3/0.
- NOT RUN: the full tier. Kernel, kits, rigs, style and seeds are untouched.

CHANGED FILES (uncommitted, per tree)
Both trees, identical except JUICE_MODE:
- foreman/prompts/juice_pass.md (new)
- foreman/src/juicepass.ts (new)
- foreman/src/test/juicepass.test.ts (new)
- foreman/src/foreman.ts (+2 lines)
- foreman/src/boundlift.ts (+2)
- engine/ui/create/create_model.gd (+23)
- engine/tools/selftest.d/812-create-juice.sh (new; each tree names its own checks)
- engine/ui/create/create_juice_case.gd (new, per arm) and its .gd.uid
Arm A only: engine/ui/create/create_build.gd (+4, the done-screen note).
Arm B only: engine/ui/create/create_build.gd (+20: the card, the follow-up, the pick; 599 of 600 lines).
Docs, in the A tree: docs/shifts/2026-11-27-juice-day/lanes/S2-juice/
- BRIEF.md
- STANDUP.md
- JUICE-PASS.md
- SPIKE.md
- REPORT.txt
- clips/ (3 mp4)
- stills/ (8 JPG)
.tl/ (ignored): spike-base/, jobs-a/, the B tree's .tl/jobs and .tl/jobs-plain, spike/ (tools, packs, runs, clips).

BEHAVIOUR CHANGES
- Arm A: a person's change that adds a move now also sends the pass to its builder; a note says so. It changes what the
  editor builds (more drawing, hit-stop, sometimes a slow beat).
- Both arms:
  - The pass's words count as asked for, in the balance rows that measure hit-stop, launch and tell. Without this, the
    pass would be refused as a regression of a row the person's words did not name.
  - B's change box is narrower (490 px) to make room for the card.
- No existing test expectation moved.

QUESTIONS FOR THE DIRECTOR
1. Menu rows for the six versions: SPIKE.md section 6 has the paths and titles. They share pack ids with the night's
   rows.
2. contracts/JOB.md (Director-only): if an arm lands, the notes "[foreman] juice pass: ..." and "[foreman] juice pass
   offered: ..." belong in its list of notes a person reads.
3. The arms' code, both ready: "arm-ready S2-juice A" and "arm-ready S2-juice B".

NEXT THREE THINGS
1. Run B's "Juice that move" follow-up as a real job on robots B-plain, to price the second change.
2. A Foreman check that reads the builder's JUICE: line and sends one more round when a big move has no launch, slow
   beat or follow.
3. Turn B's card round into "Keep it plain" on top of A, if the owner picks A, and add a "make it plain" follow-up.
