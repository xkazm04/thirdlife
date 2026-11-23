// Lane A134 (track Q2, evolution 3; docs/experiments/BRAIN-3.md): the human's side takes a kept puck back. Headless, no world, no map:
//   UnrealEditor-Cmd ThirdJam.uproject -ExecCmds="Automation RunTests Jam.Bot.Hockey3; Quit" -nullrhi -Multiprocess -unattended -nopause -stdout
// As Jam.Bot.Hockey2: every test plays both arms in one process. The rule's field at its neutral value (lane A138's tree) must miss the bar ("before"),
// the rule switched on must meet it. Each rule is a field of FJamHockeySense with a tune key; SetEvolution3() holds what ships.
#include "CoreMinimal.h"
#include "Misc/AutomationTest.h"

#include "../AI/JamBotMatch.h"
#include "../AI/JamSimAdapter.h"
#include "../AI/DifficultyResolve.h"
#include "../AI/DifficultyProfile.h"
#include "../AI/JamAICore.h"
#include "../AI/JamPlaytester.h"
#include "JamCartridge.h"
#include "JamSim.h"
#include "JamBaseline.h"

#if WITH_DEV_AUTOMATION_TESTS

namespace JamHockeyBrain3TestsLocal
{
	constexpr EAutomationTestFlags Flags = EAutomationTestFlags::EditorContext | EAutomationTestFlags::CommandletContext | EAutomationTestFlags::EngineFilter;
	using namespace JamAI;

	// 3 v 3 on 120 x 60 (hockey.arena.large's teams): team 0 (defends -x): 0 the human, 1 chaser, 2 back; team 1: 3 chaser, 4 support, 5 back. Everyone parked.
	FJamAIWorld Three()
	{
		FJamAIWorld W;
		W.HalfLength = 60.0;
		W.HalfWidth = 30.0;
		W.GoalX = 56.0;
		W.NumSkaters = 6;
		W.PlayerIndex = 0;
		W.Frame = 1000;
		const ERole Roles[6] = { ERole::Player, ERole::Chaser, ERole::Back, ERole::Chaser, ERole::Support, ERole::Back };
		for (int i = 0; i < 6; ++i)
		{
			FJamAISkater& S = W.Skaters[i];
			S.Team = i < 3 ? 0 : 1;
			S.Role = Roles[i];
			S.Facing = FVec2(S.Team == 0 ? 1.0 : -1.0, 0.0);
			S.Pos = FVec2(S.Team == 0 ? 30.0 : 45.0, -24.0 + 8.0 * i);
			S.Spawn = S.Pos;
		}
		W.Skaters[2].Pos = FVec2(-52.0, 1.5);   // the back at its post
		return W;
	}
	void Carry(FJamAIWorld& W, int Id, const FVec2& Pos, const FVec2& Vel, const FVec2& Facing)
	{
		W.Skaters[Id].Pos = Pos;
		W.Skaters[Id].Vel = Vel;
		W.Skaters[Id].Facing = Facing.Normalized();
		W.Skaters[Id].bCanShoot = true;
		W.PuckPos = Pos + W.Skaters[Id].Facing * 1.2;
		W.PuckVel = Vel;
		W.Carrier = W.Holder = W.PuckLastTouch = Id;
	}
	// The brain as the profile ships the human's side (pro sense, executed fully), every rule of evolution 3 at its neutral value; a test switches one on.
	void Start(FJamBrain& B)
	{
		B.Reset();
		B.Params.Mate.Hk = ProHockeySense();
		B.Params.Opp.Hk = ProHockeySense();
		for (FJamHockeySense* H : { &B.Params.Mate.Hk, &B.Params.Opp.Hk }) { H->ShapeShare = 1.0; H->LateFrames = 0; }
		B.Params.Mate.Hk.RoundMaxMps = 0.0;
		SetEvolution3(B.Params.Mate.Hk, false, true);
		SetEvolution3(B.Params.Opp.Hk, false, false);
	}
}

// A loose puck is the human's by arrival: a mate leaves it only while the human reaches it no later than 0.3 s after the mate would.
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamHockey3YieldArrive, "Jam.Bot.Hockey3.YieldArrive", JamHockeyBrain3TestsLocal::Flags)
bool FJamHockey3YieldArrive::RunTest(const FString& Parameters)
{
	using namespace JamHockeyBrain3TestsLocal;
	// The puck lies still at the centre dot; an opponent touched it last. The human is 4 m from it; the mate 6.3 m, standing, facing it.
	auto Play = [](double YieldArriveS, const FVec2& HumanVel, ERole& OutRole) -> double
	{
		FJamAIWorld W = Three();
		W.PuckPos = FVec2(0.0, 0.0);
		W.PuckLastTouch = 3;
		W.Skaters[0].Pos = FVec2(-4.0, 0.0);
		W.Skaters[0].Vel = HumanVel;
		W.Skaters[0].Facing = HumanVel.Normalized();
		W.Skaters[1].Pos = FVec2(-5.5, 3.0);
		FJamBrain B;
		Start(B);
		B.Params.Mate.Hk.YieldArriveS = YieldArriveS;
		FJamAIInput In[kMaxSkaters];
		B.Think(W, In);
		OutRole = B.LastRole(1);
		return In[1].Move.Normalized().Dot((W.PuckPos - W.Skaters[1].Pos).Normalized());
	};
	ERole RAwayBefore, RAwayAfter, RAtBefore, RAtAfter;
	const double AwayBefore = Play(-1.0, FVec2(-8.0, 0.0), RAwayBefore);   // the human skates away from the puck at full speed
	const double AwayAfter = Play(0.3, FVec2(-8.0, 0.0), RAwayAfter);
	const double AtBefore = Play(-1.0, FVec2(8.0, 0.0), RAtBefore);        // the human skates at it
	const double AtAfter = Play(0.3, FVec2(8.0, 0.0), RAtAfter);
	{
		FJamAIWorld W = Three();
		W.PuckPos = FVec2(0.0, 0.0);
		W.Skaters[0].Pos = FVec2(-4.0, 0.0);
		W.Skaters[0].Vel = FVec2(-8.0, 0.0);
		W.Skaters[0].Facing = FVec2(-1.0, 0.0);
		const double Away = ArriveSec(W, 0, 8.0);
		W.Skaters[0].Vel = FVec2(8.0, 0.0);
		W.Skaters[0].Facing = FVec2(1.0, 0.0);
		const double At = ArriveSec(W, 0, 8.0);
		AddInfo(FString::Printf(TEXT("ArriveSec, 4 m from a still puck at 8 m/s: skating at it %.1f s, skating away from it %.1f s"), At, Away));
		TestTrue(TEXT("a human skating away from the puck arrives at least a second later than one skating at it"), Away >= At + 1.0);
	}
	AddInfo(FString::Printf(TEXT("the human 4 m from a loose puck, the mate 6.3 m: human skating away: the mate's way towards the puck before %.2f (role %d), after %.2f (role %d); human skating at it: before %.2f, after %.2f"),
		AwayBefore, static_cast<int>(RAwayBefore), AwayAfter, static_cast<int>(RAwayAfter), AtBefore, AtAfter));
	TestTrue(TEXT("before: the mate stands off a puck the human skates away from (the distance rule)"), RAwayBefore == ERole::Support && AwayBefore < 0.5);
	TestTrue(TEXT("after: the mate takes the puck the human cannot reach in time"), RAwayAfter == ERole::Chaser && AwayAfter > 0.5);
	TestTrue(TEXT("the human skating at the puck keeps it in both arms"), RAtBefore == ERole::Support && RAtAfter == ERole::Support);
	return true;
}

// The backcheck of three a side: behind an opposing carrier that goes, the mate skates for the carrier's lane to its net, not for the puck behind the body.
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamHockey3Backcheck, "Jam.Bot.Hockey3.Backcheck", JamHockeyBrain3TestsLocal::Flags)
bool FJamHockey3Backcheck::RunTest(const FString& Parameters)
{
	using namespace JamHockeyBrain3TestsLocal;
	// The opposing carrier crosses the ice at 7 m/s (towards the far boards); the mate trails it, 7 m off, on the wrong side (not between it and our net).
	auto Play = [](double BackcheckMps, const FVec2& MatePos, double CarrierMps, double& OutToPuck) -> double
	{
		FJamAIWorld W = Three();
		Carry(W, 3, FVec2(0.0, 10.0), FVec2(0.0, CarrierMps), FVec2(0.0, 1.0));
		W.Skaters[1].Pos = MatePos;
		W.Skaters[1].Vel = FVec2(-4.0, 4.0);
		W.Skaters[1].Facing = FVec2(-1.0, 1.0).Normalized();
		FJamBrain B;
		Start(B);
		B.Params.Mate.Hk.BackcheckMps = BackcheckMps;
		FJamAIInput In[kMaxSkaters];
		B.Think(W, In);
		const FVec2 Lane = (W.OwnGoal(0) - W.Skaters[3].Pos).Normalized();
		OutToPuck = In[1].Move.Normalized().Dot((W.PuckPos - W.Skaters[1].Pos).Normalized());
		return In[1].Move.Normalized().Dot(Lane);
	};
	double PuckBefore = 0.0, PuckAfter = 0.0, PuckNear0 = 0.0, PuckNear1 = 0.0, PuckSlow0 = 0.0, PuckSlow1 = 0.0;
	const double LaneBefore = Play(0.0, FVec2(6.0, 6.0), 7.0, PuckBefore);
	const double LaneAfter = Play(3.0, FVec2(6.0, 6.0), 7.0, PuckAfter);
	const double NearBefore = Play(0.0, FVec2(1.5, 9.0), 7.0, PuckNear0);    // within 2.5 m: the puck and the body, as before
	const double NearAfter = Play(3.0, FVec2(1.5, 9.0), 7.0, PuckNear1);
	const double SlowBefore = Play(0.0, FVec2(6.0, 6.0), 2.0, PuckSlow0);    // a carrier that dawdles is played as before
	const double SlowAfter = Play(3.0, FVec2(6.0, 6.0), 2.0, PuckSlow1);
	AddInfo(FString::Printf(TEXT("behind a carrier that goes: the mate's way along the carrier's lane to our net before %.2f (towards the puck %.2f), after %.2f (towards the puck %.2f)"),
		LaneBefore, PuckBefore, LaneAfter, PuckAfter));
	TestTrue(TEXT("before: the mate chases the puck behind the carrier's body"), PuckBefore > 0.6 && LaneBefore < 0.8);
	TestTrue(TEXT("after: the mate skates for the lane to its net"), LaneAfter > 0.9 && PuckAfter < PuckBefore - 0.2);
	TestTrue(TEXT("within 2.5 m of the carrier nothing changes"), FMath::IsNearlyEqual(NearBefore, NearAfter, 1e-9) && FMath::IsNearlyEqual(PuckNear0, PuckNear1, 1e-9));
	TestTrue(TEXT("a carrier slower than the rule's speed is played as before"), FMath::IsNearlyEqual(SlowBefore, SlowAfter, 1e-9) && FMath::IsNearlyEqual(PuckSlow0, PuckSlow1, 1e-9));
	{
		// the point is on the lane, goal-side of the carrier, and the mate gets there first
		FJamAIWorld W = Three();
		Carry(W, 3, FVec2(0.0, 10.0), FVec2(0.0, 7.0), FVec2(0.0, 1.0));
		W.Skaters[1].Pos = FVec2(6.0, 6.0);
		const FVec2 Pt = BackcheckPoint(W, 1, 3, 8.0);
		const FVec2 Cp = W.Skaters[3].Pos;
		const double Along = (Pt - Cp).Dot((W.OwnGoal(0) - Cp).Normalized());
		AddInfo(FString::Printf(TEXT("the backcheck point: (%.1f, %.1f), %.1f m down the carrier's lane; the mate %.2f s, the carrier %.2f s"), Pt.X, Pt.Y, Along, W.Skaters[1].Pos.DistTo(Pt) / 8.0, Along / 7.0));
		TestTrue(TEXT("the point is goal-side of the carrier and the mate reaches it first"), Along > 2.0 && W.Skaters[1].Pos.DistTo(Pt) / 8.0 <= Along / 7.0 + 1e-9);
	}
	return true;
}

// The back of three a side steps up: an opposing carrier in its half within the rule's distance is met from the front.
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamHockey3StepUp, "Jam.Bot.Hockey3.StepUp", JamHockeyBrain3TestsLocal::Flags)
bool FJamHockey3StepUp::RunTest(const FString& Parameters)
{
	using namespace JamHockeyBrain3TestsLocal;
	auto Play = [](double StepUpM, double CarrierX) -> double
	{
		FJamAIWorld W = Three();
		Carry(W, 3, FVec2(CarrierX, 5.0), FVec2(-6.0, 0.0), FVec2(-1.0, 0.0));
		FJamBrain B;
		Start(B);
		B.Params.Mate.Hk.StepUpM = StepUpM;
		FJamAIInput In[kMaxSkaters];
		B.Think(W, In);
		return In[2].Move.Normalized().Dot((W.PuckPos - W.Skaters[2].Pos).Normalized());
	};
	const double Before = Play(0.0, -40.0), After = Play(14.0, -40.0), FarBefore = Play(0.0, -20.0), FarAfter = Play(14.0, -20.0);
	AddInfo(FString::Printf(TEXT("a carrier 11 m from the back: the back's way towards the puck before %.2f, after %.2f; a carrier 31 m off: %.2f and %.2f"), Before, After, FarBefore, FarAfter));
	TestTrue(TEXT("before: the back holds its post"), Before < 0.5);
	TestTrue(TEXT("after: the back goes at the carrier"), After > 0.7);
	TestTrue(TEXT("a carrier outside the distance: the post, as before"), FMath::IsNearlyEqual(FarBefore, FarAfter, 1e-9));
	return true;
}

// The pincer of three a side: the human is on an opposing carrier, his mate comes from the other side.
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamHockey3Pincer, "Jam.Bot.Hockey3.Pincer", JamHockeyBrain3TestsLocal::Flags)
bool FJamHockey3Pincer::RunTest(const FString& Parameters)
{
	using namespace JamHockeyBrain3TestsLocal;
	// The carrier crosses the ice slowly; the human stands on its goal side (towards our net at -x); the mate comes from below.
	auto Play = [](double PincerM, double HumanX) -> double
	{
		FJamAIWorld W = Three();
		Carry(W, 3, FVec2(0.0, 0.0), FVec2(0.0, 2.0), FVec2(0.0, 1.0));
		W.Skaters[0].Pos = FVec2(HumanX, 0.0);
		W.Skaters[1].Pos = FVec2(0.0, -4.0);
		W.Skaters[1].Facing = FVec2(0.0, 1.0);
		FJamBrain B;
		Start(B);
		B.Params.Mate.Hk.PincerM = PincerM;
		FJamAIInput In[kMaxSkaters];
		B.Think(W, In);
		return In[1].Move.Normalized().X;
	};
	const double Before = Play(0.0, -3.0), After = Play(8.0, -3.0), FarBefore = Play(0.0, -20.0), FarAfter = Play(8.0, -20.0);
	AddInfo(FString::Printf(TEXT("the human 3 m goal-side of the carrier: the mate's way across (x, + is the side away from the human) before %.2f, after %.2f; the human 20 m off: %.2f and %.2f"),
		Before, After, FarBefore, FarAfter));
	TestTrue(TEXT("before: the mate comes to the human's side of the carrier (the puck's goal-side)"), Before < 0.0);
	TestTrue(TEXT("after: the mate comes from the other side"), After > Before + 0.3 && After > 0.0);
	TestTrue(TEXT("the human far from the carrier: as before"), FMath::IsNearlyEqual(FarBefore, FarAfter, 1e-9));
	return true;
}

// The human's mates body-check an opposing carrier from the front, never from behind.
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamHockey3MateCheck, "Jam.Bot.Hockey3.MateCheck", JamHockeyBrain3TestsLocal::Flags)
bool FJamHockey3MateCheck::RunTest(const FString& Parameters)
{
	using namespace JamHockeyBrain3TestsLocal;
	auto Play = [](double MateCheckClosing, bool bFromBehind, int MaxTeam = 5) -> bool
	{
		FJamAIWorld W = Three();
		Carry(W, 3, FVec2(0.0, 0.0), FVec2(-3.0, 0.0), FVec2(-1.0, 0.0));
		W.Skaters[1].Pos = bFromBehind ? FVec2(1.2, 0.0) : FVec2(-1.2, 0.0);
		W.Skaters[1].Vel = bFromBehind ? FVec2(-8.0, 0.0) : FVec2(5.0, 0.0);
		W.Skaters[1].Facing = bFromBehind ? FVec2(-1.0, 0.0) : FVec2(1.0, 0.0);
		FJamBrain B;
		Start(B);
		B.Params.Mate.Hk.MateCheckClosing = MateCheckClosing;
		B.Params.Mate.Hk.MateCheckMaxTeam = MaxTeam;
		FJamAIInput In[kMaxSkaters];
		B.Think(W, In);
		return In[1].bCheck;
	};
	const bool bBefore = Play(-1.0, false), bAfter = Play(2.0, false), bBehind = Play(2.0, true);
	AddInfo(FString::Printf(TEXT("a mate meets an opposing carrier head-on, closing at 8 m/s: checks before %d, after %d; from behind %d"), bBefore ? 1 : 0, bAfter ? 1 : 0, bBehind ? 1 : 0));
	TestFalse(TEXT("before: a mate never checks"), bBefore);
	TestTrue(TEXT("after: the mate checks from the front"), bAfter);
	TestFalse(TEXT("never from behind"), bBehind);
	TestFalse(TEXT("only in a team smaller than hk_mate_check_max_team (three a side with the limit at 3: no check)"), Play(2.0, false, 3));
	return true;
}

// Shot selection: no aimed shot from the corner by the goal line; the carrier takes the puck to the slot. From the slot it shoots as before.
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamHockey3ShotSelect, "Jam.Bot.Hockey3.ShotSelect", JamHockeyBrain3TestsLocal::Flags)
bool FJamHockey3ShotSelect::RunTest(const FString& Parameters)
{
	using namespace JamHockeyBrain3TestsLocal;
	// Team 1 attacks the net at -56. OutToSlot: the carrier's way towards the slot (9 m out on the net's axis).
	auto Play = [](double MaxAngleDeg, const FVec2& Pos, double& OutToSlot) -> bool
	{
		FJamAIWorld W = Three();
		W.Skaters[2].Pos = FVec2(30.0, 20.0);   // no back in the lane
		const FVec2 Goal = W.OppGoal(1);
		Carry(W, 3, Pos, FVec2(0.0, 0.0), Goal - Pos);
		FJamBrain B;
		Start(B);
		B.Params.Opp.Hk.ShotMaxAngleDeg = MaxAngleDeg;
		B.Params.Opp.Hk.bCarryOrPass = false;   // the shot rule alone
		FJamAIInput In[kMaxSkaters];
		B.Think(W, In);
		OutToSlot = In[3].Move.Normalized().Dot((FVec2(Goal.X + 9.0, 0.0) - W.PuckPos).Normalized());
		return In[3].bShoot || In[3].bShootHeld;
	};
	double CornerSlot0 = 0.0, CornerSlot1 = 0.0, S0 = 0.0, S1 = 0.0, P0 = 0.0;
	const bool bCornerBefore = Play(0.0, FVec2(-53.0, 13.0), CornerSlot0);
	const bool bCornerAfter = Play(60.0, FVec2(-53.0, 13.0), CornerSlot1);
	const bool bSlotBefore = Play(0.0, FVec2(-44.0, 1.0), S0);
	const bool bSlotAfter = Play(60.0, FVec2(-44.0, 1.0), S1);
	const bool bPointAfter = Play(60.0, FVec2(-34.0, 9.0), P0);   // the point: 22 degrees off the axis
	AddInfo(FString::Printf(TEXT("the corner by the goal line (77 degrees off the net's axis): shoots before %d, after %d (its way towards the slot %.2f); the slot: %d and %d; the point: %d"),
		bCornerBefore ? 1 : 0, bCornerAfter ? 1 : 0, CornerSlot1, bSlotBefore ? 1 : 0, bSlotAfter ? 1 : 0, bPointAfter ? 1 : 0));
	TestTrue(TEXT("before: the bot shoots from the corner"), bCornerBefore);
	TestFalse(TEXT("after: no shot from the corner"), bCornerAfter);
	TestTrue(TEXT("after: the carrier takes the puck towards the slot"), CornerSlot1 > 0.5);
	TestTrue(TEXT("the slot and the point shoot in both arms"), bSlotBefore && bSlotAfter && bPointAfter);
	return true;
}

// Item 1: the scripted human reads the body shield and the take grace: no poke and no lift the sim would refuse.
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamHockey3HumanReads, "Jam.Bot.Hockey3.HumanReads", JamHockeyBrain3TestsLocal::Flags)
bool FJamHockey3HumanReads::RunTest(const FString& Parameters)
{
	using namespace JamHockeyBrain3TestsLocal;
	// The human right behind an opposing carrier whose body is between his stick and the puck; then in front of it; then in front of one inside its take grace.
	auto Play = [](bool bRead, bool bBehind, int Grace) -> int
	{
		FJamAIWorld W = Three();
		Carry(W, 3, FVec2(0.0, 0.0), FVec2(-2.0, 0.0), FVec2(-1.0, 0.0));
		W.Skaters[3].TakeGraceFrames = Grace;
		W.bBodyShield = true;
		W.Skaters[0].Pos = bBehind ? FVec2(1.2, 0.0) : FVec2(-2.4, 0.0);
		W.Skaters[0].Vel = FVec2(bBehind ? -2.0 : 2.0, 0.0);
		W.Skaters[0].Facing = FVec2(bBehind ? -1.0 : 1.0, 0.0);
		W.Skaters[0].bCanPoke = true;
		W.Skaters[0].bCanLift = true;
		FJamPlaytester T;
		T.Reset(EPlaytester::Regular, 1);
		T.bReadShield = bRead;
		int Swings = 0;
		for (int f = 0; f < 20; ++f)
		{
			W.Frame = 1000 + f;
			const FJamAIInput In = T.Think(W);
			Swings += (In.bPoke ? 1 : 0) + (In.bLift ? 1 : 0);
		}
		return Swings;
	};
	const int BehindOff = Play(false, true, 0), BehindOn = Play(true, true, 0), FrontOn = Play(true, false, 0), GraceOff = Play(false, false, 20), GraceOn = Play(true, false, 20);
	AddInfo(FString::Printf(TEXT("swings in 20 frames: behind the body unread %d, read %d; in front, read %d; in front of a carrier inside its take grace unread %d, read %d"),
		BehindOff, BehindOn, FrontOn, GraceOff, GraceOn));
	TestTrue(TEXT("unread: the scripted human swings into the body and into the grace"), BehindOff > 0 && GraceOff > 0);
	TestEqual(TEXT("read: no swing into the body"), BehindOn, 0);
	TestEqual(TEXT("read: no swing into the take grace"), GraceOn, 0);
	TestTrue(TEXT("read: in front of an open puck he swings"), FrontOn > 0);
	return true;
}

// brain3=0 gives back this evolution's start (lane A138's tree: main e44df14), hash for hash; brain2=0 still switches evolution 3 off with evolution 2.
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamHockey3Neutral, "Jam.Bot.Hockey3.Neutral", JamHockeyBrain3TestsLocal::Flags)
bool FJamHockey3Neutral::RunTest(const FString& Parameters)
{
	using namespace JamHockeyBrain3TestsLocal;
	{
		FJamAIParams A, B, C;
		ApplyDifficultyProfile(GetDifficultyProfile(EDifficulty::Pro), A);
		B = A; C = A;
		char Err[200] = {};
		TestTrue(TEXT("brain3=0 applies"), ApplyDifficultyTune("brain3=0", B, Err, sizeof(Err)));
		TestTrue(TEXT("brain2=0 applies"), ApplyDifficultyTune("brain2=0", C, Err, sizeof(Err)));
		for (const FJamAIParams* P : { &B, &C })
		{
			for (const FJamHockeySense* H : { &P->Mate.Hk, &P->Opp.Hk })
			{
				TestTrue(TEXT("every rule of evolution 3 is at its neutral value"), H->YieldArriveS < 0.0 && H->BackcheckMps == 0.0 && H->StepUpM == 0.0 && H->MateCheckClosing < 0.0 && H->ShotMaxAngleDeg == 0.0 && H->PincerM == 0.0 && !H->bPressInHunt);
			}
		}
		{
			// a level's own switch survives the profile's SetEvolution3 (on) and is switched off by brain3=0
			FJamDifficultyProfile Lv = GetDifficultyProfile(EDifficulty::AllStar);
			Lv.Opp.Hk.bPressInHunt = true;
			FJamAIParams L;
			ApplyDifficultyProfile(Lv, L);
			TestTrue(TEXT("a level that sets bPressInHunt keeps it through ApplyDifficultyProfile"), L.Opp.Hk.bPressInHunt && !L.Mate.Hk.bPressInHunt);
			TestTrue(TEXT("brain3=0 applies"), ApplyDifficultyTune("brain3=0", L, Err, sizeof(Err)));
			TestFalse(TEXT("brain3=0 switches a level's bPressInHunt off"), L.Opp.Hk.bPressInHunt);
		}
		TestTrue(TEXT("brain3=0 leaves evolution 2 on"), B.Mate.Hk.bSupportHuman && B.Opp.Hk.bReadShield && B.Mate.Hk.MateStickFrames == 10);
		AddInfo(FString::Printf(TEXT("as shipped, the mates: yield by arrival %.2f s, backcheck %.1f m/s, step up %.1f m, check at %.1f m/s; shot angle mates %.0f, opposing side %.0f degrees"),
			A.Mate.Hk.YieldArriveS, A.Mate.Hk.BackcheckMps, A.Mate.Hk.StepUpM, A.Mate.Hk.MateCheckClosing, A.Mate.Hk.ShotMaxAngleDeg, A.Opp.Hk.ShotMaxAngleDeg));
		TestTrue(TEXT("the opposing side's approach is untouched (law 3's drill is measured on it)"), A.Opp.Hk.YieldArriveS < 0.0 && A.Opp.Hk.BackcheckMps == 0.0 && A.Opp.Hk.StepUpM == 0.0 && A.Opp.Hk.MateCheckClosing < 0.0);
	}
	struct FPin { const TCHAR* Cart; uint64 Seed; const TCHAR* Hash; };
	const FPin Pins[] = {
		{ TEXT("hockey.regular"), 1, TEXT("f63ac57227255064") }, { TEXT("hockey.regular"), 2, TEXT("3277289d27155239") },
		{ TEXT("hockey.arena.large"), 1, TEXT("95e0858675dfe149") }, { TEXT("hockey.arena.large"), 2, TEXT("4c4de08a20d2f482") } };
	for (const FPin& P : Pins)
	{
		TArray<FString> Errors;
		UJamCartridge* Cart = UJamCartridge::LoadFromFile(UJamCartridge::ResolveCartridgePath(P.Cart), Errors);
		if (!Cart) { AddError(FString::Printf(TEXT("FAIL %s does not load"), P.Cart)); return false; }
		FJamMatchConfig C = ToMatchConfigResolved(*Cart, TEXT("pro"));
		char Err[200] = {};
		TestTrue(TEXT("brain3=0 applies"), ApplyDifficultyTune("brain3=0", C.AI, Err, sizeof(Err)));
		FJamSimAdapter Sim(*Cart);
		const FJamPlaytestStats St = RunPlaytestMatch(Sim, C, P.Seed, EPlaytester::Regular, 36000, Cart->Game.Shot.ChargeFramesMax, false, nullptr, nullptr, 0);
		const FString Hash = FString::Printf(TEXT("%016llx"), static_cast<unsigned long long>(St.Hash));
		AddInfo(FString::Printf(TEXT("%s seed %llu with brain3=0: %lld frames, hash %s"), P.Cart, P.Seed, static_cast<long long>(St.Frames), *Hash));
		// Director at the landing (14 Nov): logged, not asserted. The pins are matches of shipped cuts at the lane's start commit (e44df14), and the cuts'
		// own numbers moved under them before this landed (the ladder, the whistle, the kept first step). The lane proved the neutral on its tree (100 of 100
		// hashes against the unedited build); a pin on a shipped cut's default match is a pin on every other lane's work. The profile assertions above hold.
		AddInfo(FString::Printf(TEXT("%s seed %llu with brain3=0: %s (at the lane's start commit: %s)"), P.Cart, P.Seed, *Hash, P.Hash));
		Cart->RemoveFromRoot();
	}
	return true;
}

#endif
