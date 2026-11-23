// Lane A138 (track I1, R-0053 point 5): ONE shared baseline for the pinned-hash neutral tests.
//
// Every lane used to pin "my rule at its neutral value replays my baseline" from its own tree, with the other lanes' neutral values written out by hand in
// each test; five landings on 13 Nov stopped on each other's pins. This header is the one place that knows what "neutral" is:
//
//   JamBaseline::MakeNeutral(Game)   every sim rule added since the vision's commit (main ee14438: lanes A92, A93, A94 and the curve of A95) at its neutral value
//   JamBaseline::BrainTune()         the same for the brain: a profile tune (JamAI::ApplyDifficultyTune) that switches off every brain evolution since
//   JamBaseline::HooksDead(World)    the brain's reads of sim rules that an older commit's brain did not have (call after BuildWorld when replaying such a commit)
//
// A neutral test calls these and then un-neutralises ONLY what its pinned commit had on (the With...() helpers below name the steps of the evening in the
// order they landed, so "the tree before lane X" is one call). A pin that still does not hold after that is a real change of the game, not a neighbour's key.
//
// THE NEXT LANE: a new rule goes in with its neutral value in MakeNeutral (one line), a new brain rule with its key in BrainTune (one pair), and, if a
// later test must replay the tree that had your rule on, one With...() step. Nothing else in any test changes.
// Header only; no state. docs/experiments/INTEGRATION.md section 1.
#pragma once

#include "CoreMinimal.h"
#include "JamCartridge.h"

namespace JamBaseline
{
	// Every rule since the vision's commit at its neutral value, in the order the rules landed.
	// Lane A207 (track P1, docs/experiments/PASS-SHOT.md): the pass and the shot before the lane (scenes that pin them call this alone).
	inline void PassShotNeutral(FJamGameConfig& G)
	{
		G.Pass.PowerFullFrames = 0; G.Pass.AimConeDeg = 0.0; G.Pass.CatchM = 0.0; G.Pass.bClearOwnBody = false; G.Shot.SpeedScale = 1.0;
		G.Skater.GoalieReadMps = 0.0;   // wave 2: game.skater.goalie.read_mps (ships 2.5)
		G.Shot.FadeM = 0.0;             // wave 2b: game.shot.fade_m (ships 6)
		G.Stick.PickupPassArcM = 0.0;   // wave 2c: game.stick.pickup.pass_arc_m (ships 0.7)
	}

	inline void MakeNeutral(FJamGameConfig& G)
	{
		G.Contact.BoardBonus = 1.0;               // lane A101 (track F1): game.contact.board_bonus (default 1.25)
		G.Contact.ReleaseGraceFrames = 0;         // lane A113 (track F1, R-0049 / R-0051): game.contact.release_grace_frames (default 120)
		G.Stick.bPassiveTake = true;              // lane A102 (track F2, R-0048): game.stick.passive_take (default false) ...
		G.Stick.bTeammateTouchTakes = true;       // ... with the teammate-touch switch (a rule, no key)
		G.Stick.bBodyShield = false;              // lane A102: game.stick.body_shield (default true)
		G.Stick.TakeGraceFrames = 0;              // lane A121 (track F2, R-0049 point 2): game.stick.take_grace_frames (default 30)
		G.Skater.ReverseBrakeDecel = 20;          // lane A121: game.skater.reverse_brake_decel (default 26)
		G.Skater.bBurstOwnStop = false;           // lane A121: game.skater.burst.own_stop (default true)
		G.Contact.CheckReachM = 0.0;              // lane A125 (track F1): game.contact.check_reach_m (ships at 0)
		G.Contact.bShieldShove = false;           // lane A125 / A138 (R-0050 point 2): the shield refuses the stick, never the shove (a rule, no key)
		G.Skater.BurstRestFrames = 0;             // lane A128 (track F2): game.skater.burst.rest_frames (default 6)
		G.Skater.SpinExposedTail = 0;             // lane A128: game.skater.spin.exposed_frames (default 5)
		G.Contact.ShoveBehindMatchMps = 0.0;      // lane A138 (track I1, R-0053 point 3): a push in the back at matched speed is a bump (a rule, no key; 0 = off)
		G.Stick.bTakeGraceSameFrame = false;      // lane A138 (track I1): the take grace covers the frame the puck is won in (a rule, no key)
		G.Contact.bPlaytesterClosingPress = false;   // lane A132 (track F1): the scripted human presses its check on closing speed (the instrument, no key; false = its own speed, as the pins were played)
		G.Skater.BurstRestKeptMps = 0.0;          // lane A147 (track F2): game.skater.burst.rest_kept_mps (default 3)
		G.Contact.bPlaytesterCoursePress = false;    // lane A151 (track F1): the scripted human presses its check on course and time (the instrument, no key)
		G.Contact.LatePressFrames = 0;            // lane A151 (track F1): the late press: a check pressed just after an unpressed body contact is that hit (a rule, no key yet)
		G.Contact.StandSideBrace = 0.0;           // lane A151 (track F1): the standing skater's brace against a body hit from the side (a rule, no key yet; 0 = stand_brace there too)
		G.Contact.bBraceExchange = false;         // lane A151: the brace is mass in the skater-to-skater bounce (a rule, no key yet)
		G.Stick.StopGraceFrames = 0; G.Stick.bStopGraceBots = false;   // lane A163 (track F2 evolution 6): game.stick.stop_grace_frames (ships at 0: this line is for the day it ships on)
		G.Stick.PokeAssistDeg = 0.0; G.Stick.MissRecoveryFrames = 0; G.Stick.bPlaytesterPokeRead = false;   // lane A152 (track F2, R-0059 point 4): game.stick.poke_assist_deg, game.stick.miss_recovery_frames, the scripted human's poke read (the instrument, no key)
		G.Contact.DownedRadiusM = 0.0;            // lane A157 (track F1): game.contact.downed_radius_m, the push-out around a downed skater (ships at 0)
		G.Contact.CheckCooldownFrames = 0;        // lane A157: game.contact.check_cooldown_frames (ships at 0)
		G.Contact.LungeFrames = 0; G.Contact.LungeStepMps = 0.0;   // lane A157: game.contact.lunge_frames, game.contact.lunge_step_mps, the lunge as a motion (ship at 0)
		G.Contact.bCheckCooldownRestart = false; G.Contact.BoardSlamFrames = 0;   // lane A165 (track F1): game.contact.check_cooldown_restart, game.contact.board_slam_frames (ship at false and 0)
		G.Contact.TakeShieldFrames = 0; G.Contact.bTakeShieldHumanSide = false; G.Contact.TakeShieldStaggerMax = 0;   // lane A177 (track F1): game.contact.take_shield_frames, take_shield_human_side, take_shield_stagger_max (ship at 0, false, 0)
		G.Skater.FreeSpeedMult = 1.0;             // lane A185 (track F2 evolution 9, R-0064 point 2): game.skater.free_speed_mult (default 1.15)
		G.Contact.bCrossHold = false; G.Contact.CheckWindupFrames = 0; G.Contact.CrossWindupFrames = 0; G.Contact.BotCheckWindupFrames = G.Contact.BotCrossWindupFrames = -1;   // lane A200: bot_*_windup_frames absent; lane A184 (track F1): game.contact.cross_hold, check_windup_frames, cross_windup_frames
		G.Skater.BreakawaySpeedBonus = 0.2;       // lane A194 (track F2 evolution 10): game.skater.breakaway.speed_bonus (default 0.3)
		G.Skater.bChargeDiesOnLoss = false;      // lane A203 (track K1 evolution 4): game.skater.charge_dies_on_loss (ships true since the Director, 17:01)
		G.Contact.CheckPullM = 0.0; G.Contact.bCrossAnyMan = false;   // lane A209 (track F1, the night): game.contact.check_pull_m, cross_any_man (ship 1.0, true)
		G.Contact.CrossLiveFrames = 0; G.Contact.bCrossBackHuman = false;   // lane A215 (track F1, the night): game.contact.cross_live_frames, cross_back_human (ship 10, true)
		PassShotNeutral(G);                      // lane A207 (track P1): game.pass.power / aim / catch_m / clear_own_body (ship 30, 25, 1.2, true), game.shot.speed_scale (ships 2)
		G.Stick.PickupArcM = 0.0; G.Stick.bPickupBody = false;   // lane A208 (track F0, R-0067 point 2): game.stick.pickup.arc_m, pickup.body (default 1.5 and true)
		G.Stick.FaceoffCentreGapM = 0.0; G.Stick.FaceoffWinnerShieldFrames = 0; G.Stick.FaceoffNoHitFrames = 0;   // lane A208 (the eye's list 1): game.stick.faceoff (default 1.8 / 90 / 45)
		G.Puck.bNetOwnWall = false; G.Puck.bNetMouthOnly = false;   // lane A208 (the eye's list 2 item 12; A212 01:17): game.puck.net (default true / true)
		G.Stick.PickupRingM = 0.0;               // lane A218 (R-0069 point 2): game.stick.pickup.ring_m (default 1.1)
		// THE NEXT LANE: your rule's neutral value here, one line.
	}

	// Every brain evolution since the vision's commit switched off, as a profile tune (append it to any other tune with ';').
	// brain2=0: lane A115 (track Q2, evolution 2), both sides, every rule. Lane A138's three brain rules need no pair: the way round the body
	// (hk_round_max_mps) and the spin's exposed end (hk_spin_end_share) are read only with the shield read on, which brain2=0 switches off, and the
	// no-shove-from-behind rule is dead wherever MakeNeutral has switched the sim's shove rule off (or HooksDead was called).
	// brain7=0: lane A193 (track Q2, evolution 7): the brain plans with skater.speed for everyone (with MakeNeutral's free_speed_mult 1 it is the same).
	// brain8=0: lane A202 (track Q2, evolution 8): every rule of evolution 8 off (all four ship on: the pair gives back evolution 7, the old game).
	// brain9=0: lane A206 (track Q2, evolution 9, BRAIN-9.md): every rule of evolution 9 off, rookie's pace and read included (evolution 8 as shipped).
	// THE NEXT LANE: your brain rule's off-switch here, one pair.
	// Level ("rookie", "pro", "all_star"; every pin so far is a pro match): THE CURVE LANE: when you move a level's profile numbers, the numbers that level
	// had before you go here for that level (as JamAI::PreA95Tune carries the levels of the commit before the vision), and the pins stay where they are.
	// Lanes A112 / A133 (track C0, CURVE-6.md, CURVE-7.md): each level's profile numbers those lanes moved, back to the values main had before them
	// (rookie: poke never, shot reach + 5, mates at speed_scale; pro: poke after 6 frames, hunt 8 m, checks from 2 m/s, pressure 1.4 s / better by 3 m; all_star: hunt 20, shot reach + 40,
	// mates at speed_scale). The large-rink offsets are not tune keys: every pin is a hockey.regular match.
	// bLargeRink: a rink of JamAI::LargeRinkM or longer, whose red skill offsets the curve lanes also moved (pro 1.04, rookie 0.9; all_star's large speed is
	// not a tune key: no pin is an all_star match on the large rink).
	inline const char* BrainTune(const char* Level = "pro", bool bLargeRink = false)
	{
		if (Level && Level[0] == 'r') return bLargeRink ? "brain2=0;brain3=0;brain4=0;brain5=0;brain6=0;brain7=0;brain8=0;brain9=0;opp.poke_frames=-1;opp.shoot_extra_m=5;mate_speed_scale=0;red_skill=0.9" : "brain2=0;brain3=0;brain4=0;brain5=0;brain6=0;brain7=0;brain8=0;brain9=0;opp.poke_frames=-1;opp.shoot_extra_m=5;mate_speed_scale=0;red_skill=0.97";
		if (Level && Level[0] == 'a') return "brain2=0;brain3=0;brain4=0;brain5=0;brain6=0;brain7=0;brain8=0;brain9=0;opp.hunt_radius_m=20;opp.shoot_extra_m=40;mate_speed_scale=0;speed_scale=1.4";   // lane A154: all_star speed 1.4 -> 1.45
		return bLargeRink ? "brain2=0;brain3=0;brain4=0;brain5=0;brain6=0;brain7=0;brain8=0;brain9=0;opp.poke_frames=6;opp.hunt_radius_m=8;opp.check_min_closing=2;opp.hk_pressure_s=1.4;opp.hk_better_by_m=3;mate_speed_scale=0;red_skill=1.04"
			: "brain2=0;brain3=0;brain4=0;brain5=0;brain6=0;brain7=0;brain8=0;brain9=0;opp.poke_frames=6;opp.hunt_radius_m=8;opp.check_min_closing=2;opp.hk_pressure_s=1.4;opp.hk_better_by_m=3;mate_speed_scale=0";
	}

	// Lane A133 (track C0): the shipped cuts' whistle. Lane A112 took it out of hockey.regular, hockey.arena.wide, hockey.arena.large and the season's takes
	// (rules.penalties false: content, not a rule, so not in MakeNeutral, whose callers may switch the whistle off themselves). A pin made on one of those cuts
	// before lane A112, with the cut's own rules, calls this after MakeNeutral.
	inline void WithWhistle(FJamGameConfig& G) { G.Rules.bPenalties = true; }
	// brain3=0: lane A134 (track Q2, evolution 3), both sides, every rule (brain2=0 switches them off as well; the pair is here so the list reads whole).

	// The brain's reads of track F2's shields (lane A115's two hooks, wired at the landing of 22:20): dead, as on any commit before them. Call on the world
	// right after FJamSimAdapter::BuildWorld when replaying such a commit with the body shield or the take grace on. (A template: no brain header here.)
	template <typename TWorld> inline void HooksDead(TWorld& W)
	{
		W.bBodyShield = false;
		W.bShieldShove = false; W.SpinExposedFrames = 0;   // lane A138's two world facts
		for (int i = 0; i < W.NumSkaters; ++i) W.Skaters[i].TakeGraceFrames = 0;
	}

	// The steps of 13 Nov, each on top of MakeNeutral, for a test whose pinned commit already had them on. They stack: call the ones the commit had.
	// Each writes the values that commit had, not today's defaults: a later lane that moves a default (the curve, a re-tuned grace) does not move a pin.
	inline void WithBoards(FJamGameConfig& G) { G.Contact.BoardBonus = 1.25; }                 // lane A101
	inline void WithReleaseGrace(FJamGameConfig& G) { G.Contact.ReleaseGraceFrames = 120; }    // lane A113 (R-0051)
	inline void WithKeptPuck(FJamGameConfig& G)                                                // lane A102 (R-0048, R-0050)
	{
		G.Stick.bPassiveTake = false; G.Stick.bTeammateTouchTakes = false; G.Stick.bBodyShield = true;
	}
	inline void WithCarrierAnswer(FJamGameConfig& G)                                           // lane A121
	{
		G.Stick.TakeGraceFrames = 30; G.Skater.ReverseBrakeDecel = 26; G.Skater.bBurstOwnStop = true;
	}
}
