K2 FIGURE, ROUND 7 REPORT (24 Nov; worktree .claude/worktrees/hk-figure, uncommitted, on hokej b1ea774)

FINDING: our rule already equals thirdjam's. No behaviour change.
thirdjam: UJamSim::ScoreGoal (JamSim.cpp:4421-4424) sets Who = Puck.LastTouch (the LAST TOUCHER, not the shooter) and emits Goal with it.
JamBoostLook::PickScorer (JamPickupActor.cpp:630-653) takes Who as the scorer when he skates for the scoring team, else the scoring
team's skater nearest the puck; his nearest mate gets the mate's take. CelebrateGoal (:654-679) calls PlayCelebrate on those two only.
Ours (boost_look.gd pick_scorer / deliver_events) reads ev["Who"] from the snapshot's goal event, the same field. Nothing is chosen by
position unless Who is not on the scoring team.

WHY K3 SAW A MATE: I ran bot_first_match (seed 1, K3's match) with a trace. Goals: frame 3540 Who=4 (a teammate, human=0), scorer 4,
mate 1; frame 5822 Who=0 (the human), scorer 0; frame 6294 Who=0, scorer 0. K3's film (frames 3560-3760) is the first goal: the
last toucher was skater 4, so he celebrates in thirdjam too. The human celebrates on the goals he last touched (5822, 6294).
(Frame 6294 re-delivers on every held end-card frame; same pick, harmless.)

CHANGES
- engine/cores/rink/view/verb_gym.gd: report["goals"] = [frame, goal event Who, his team, human index].
- engine/tools/selftest.d/812-skater-verbs.sh, case rig.skater.verbs.toys: on the recorded arsenal match (the human, skater 0, scores
  at 784) it now also requires goals == [[784,0,0,0]] and the celebration's scorer == the human (mate 1).
- engine/cores/rink/view/boost_look.gd: comment only (who celebrates, with the source lines).
GATES: tl check --tier fast PASS; selftest rig.skater (11) PASS; rink.view (2) PASS.
FOR K3: nothing to change; the strip shows the right figure. If the owner wants the shooter to celebrate rather than the last
toucher, that is a deviation from thirdjam. The snapshot carries the field (Events goal Who); no ask to K1.
No git writes; no Unreal.
