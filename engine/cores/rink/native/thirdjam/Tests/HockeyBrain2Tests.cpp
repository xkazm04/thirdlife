// Lane A115 (track Q2, evolution 2; docs/experiments/BRAIN-2.md): the brain plays hockey with the human. Headless, no world, no map:
//   UnrealEditor-Cmd ThirdJam.uproject -ExecCmds="Automation RunTests Jam.Bot.Hockey2; Quit" -nullrhi -Multiprocess -unattended -nopause -stdout
// Every test plays both arms in one process: the brain of evolution 1 (the rule's field off) must miss the bar (reported as "before"), the brain with the
// rule on must meet it. Each rule is a field of FJamHockeySense; ProHockeySense() turns them on.
#include "CoreMinimal.h"
#include "Misc/AutomationTest.h"

#include "../AI/JamBotMatch.h"
#include "../AI/JamSimAdapter.h"
#include "../AI/DifficultyResolve.h"
#include "../AI/JamAICore.h"
#include "../AI/JamPlaytester.h"
#include "JamCartridge.h"
#include "JamEventBus.h"
#include "JamSim.h"
#include "JamBaseline.h"

#if WITH_DEV_AUTOMATION_TESTS

namespace JamHockeyBrain2TestsLocal
{
	constexpr EAutomationTestFlags Flags = EAutomationTestFlags::EditorContext | EAutomationTestFlags::CommandletContext | EAutomationTestFlags::EngineFilter;
	using namespace JamAI;

	// The sense of evolution 1 (every A115 field off) and of evolution 2 (as ProHockeySense has it), executed fully and at once.
	FJamHockeySense Sense(bool bEvolution2)
	{
		FJamHockeySense H = ProHockeySense();
		H.ShapeShare = 1.0;
		H.LateFrames = 0;
		if (!bEvolution2)
		{
			SetEvolution2(H, false);
		}
		return H;
	}
	void SetSense(FJamBrain& B, bool bEvolution2)
	{
		B.Reset();
		B.Params.Mate.Hk = Sense(bEvolution2);
		B.Params.Opp.Hk = Sense(bEvolution2);
	}
	void SetSense(FJamAIParams& P, bool bEvolution2)
	{
		const FJamHockeySense Was[2] = { P.Mate.Hk, P.Opp.Hk };
		FJamHockeySense* Hk[2] = { &P.Mate.Hk, &P.Opp.Hk };
		for (int k = 0; k < 2; ++k)
		{
			*Hk[k] = Was[k];
			SetEvolution2(*Hk[k], bEvolution2);
		}
	}

	// 5 v 5 on 90 x 45: team 0 (defends -x) skaters 0-4 (chaser, support, support, back, back), team 1 skaters 5-9. Everyone parked far from the scene.
	FJamAIWorld Five()
	{
		FJamAIWorld W;
		W.HalfLength = 45.0;
		W.HalfWidth = 22.5;
		W.GoalX = 41.0;
		W.NumSkaters = 10;
		W.PlayerIndex = -1;
		W.Frame = 1000;
		const ERole Roles[5] = { ERole::Chaser, ERole::Support, ERole::Support, ERole::Back, ERole::Back };
		for (int i = 0; i < 10; ++i)
		{
			FJamAISkater& S = W.Skaters[i];
			S.Team = i < 5 ? 0 : 1;
			S.Role = Roles[i % 5];
			S.Facing = FVec2(S.Team == 0 ? 1.0 : -1.0, 0.0);
			S.Pos = FVec2(S.Team == 0 ? -30.0 : 30.0, -12.0 + 6.0 * (i % 5));
			S.Spawn = S.Pos;
		}
		return W;
	}
	// 3 v 3 on 120 x 60 (hockey.arena.large's teams): team 0: 0 the human (player), 1 chaser, 2 back; team 1: 3 chaser, 4 support, 5 back.
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
			S.Pos = FVec2(S.Team == 0 ? -40.0 : 40.0, -10.0 + 10.0 * (i % 3));
			S.Spawn = S.Pos;
		}
		return W;
	}
	void Carry(FJamAIWorld& W, int Id, const FVec2& Pos, const FVec2& Vel)
	{
		W.Skaters[Id].Pos = Pos;
		W.Skaters[Id].Vel = Vel;
		W.Skaters[Id].bCanShoot = true;
		W.PuckPos = Pos + W.Skaters[Id].Facing * 1.2;
		W.PuckVel = Vel;
		W.Carrier = W.Holder = W.PuckLastTouch = Id;
	}
}

// Item 1a: a mate passes to the human where he has room, and turns to him when he is open and ahead of the play.
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamHockey2PassRoom, "Jam.Bot.Hockey2.PassRoom", JamHockeyBrain2TestsLocal::Flags)
bool FJamHockey2PassRoom::RunTest(const FString& Parameters)
{
	using namespace JamHockeyBrain2TestsLocal;
	// (a) the human stands marked (an opponent 2.3 m off, beyond him, off the lane): the sim would give him the pass, the mate's share says pass
	auto Marked = [](bool bE2) -> bool
	{
		FJamAIWorld W = Five();
		W.PlayerIndex = 1;
		W.Skaters[1].Role = ERole::Player;
		Carry(W, 0, FVec2(0.0, 0.0), FVec2(5.0, 0.0));
		W.Skaters[1].Pos = FVec2(8.0, 8.0);
		W.Skaters[5].Pos = FVec2(9.6, 9.6);
		W.CarrierBestPass = W.HolderBestPass = 1;
		FJamBrain B;
		SetSense(B, bE2);
		B.Params.Mate.PassToHuman = 1.0;
		FJamAIInput In[kMaxSkaters];
		bool bPassed = false;
		for (int F = 0; F < 20; ++F) { W.Frame = 1000 + F; B.Think(W, In); bPassed = bPassed || In[0].bPass || In[0].bShoot; }
		return bPassed;
	};
	const bool bBefore = Marked(false), bAfter = Marked(true);
	AddInfo(FString::Printf(TEXT("a marked human (an opponent 2.3 m off): before, the mate passes onto the marked blade: %d; after: %d"), bBefore ? 1 : 0, bAfter ? 1 : 0));
	TestTrue(TEXT("before (evolution 1): the mate passes to a marked human"), bBefore);
	TestFalse(TEXT("after: no pass onto a marked blade"), bAfter);
	// the same human with room (the opponent 6 m off): the pass goes, in both arms
	{
		FJamAIWorld W = Five();
		W.PlayerIndex = 1;
		W.Skaters[1].Role = ERole::Player;
		Carry(W, 0, FVec2(0.0, 0.0), FVec2(5.0, 0.0));
		W.Skaters[1].Pos = FVec2(8.0, 8.0);
		W.Skaters[5].Pos = FVec2(12.5, 12.5);
		W.CarrierBestPass = W.HolderBestPass = 1;
		FJamBrain B;
		SetSense(B, true);
		B.Params.Mate.PassToHuman = 1.0;
		FJamAIInput In[kMaxSkaters];
		bool bPassed = false;
		for (int F = 0; F < 20; ++F) { W.Frame = 1000 + F; B.Think(W, In); bPassed = bPassed || In[0].bPass; }
		TestTrue(TEXT("after: the human with room (6 m free) gets the pass"), bPassed);
	}
	// (b) the human open and ahead of the play, 72 degrees off the carrier's way; the sim's pass would go to another teammate: the carrier turns to him
	auto TurnDot = [](bool bE2, bool& bOutTap) -> double
	{
		FJamAIWorld W = Five();
		W.PlayerIndex = 1;
		W.Skaters[1].Role = ERole::Player;
		Carry(W, 0, FVec2(0.0, 0.0), FVec2(5.0, 0.0));
		W.Skaters[1].Pos = FVec2(4.0, 12.0);
		W.CarrierBestPass = W.HolderBestPass = 2;
		FJamBrain B;
		SetSense(B, bE2);
		FJamAIInput In[kMaxSkaters];
		for (int F = 0; F < 20; ++F) { W.Frame = 1000 + F; B.Think(W, In); }
		const double Dot = In[0].Move.Normalized().Dot((W.Skaters[1].Pos - W.Skaters[0].Pos).Normalized());
		// lined up on him: the aimed tap goes
		W.Skaters[0].Facing = (W.Skaters[1].Pos - W.PuckPos).Normalized();
		W.Frame = 1020;
		B.Think(W, In);
		bOutTap = In[0].bShoot;
		return Dot;
	};
	bool bTapBefore = false, bTapAfter = false;
	const double DotBefore = TurnDot(false, bTapBefore), DotAfter = TurnDot(true, bTapAfter);
	AddInfo(FString::Printf(TEXT("the human open and ahead, the sim's pass to another: the carrier's way towards him (cosine): before %.2f, after %.2f; lined up, the tap goes: %d"), DotBefore, DotAfter, bTapAfter ? 1 : 0));
	TestTrue(TEXT("before (evolution 1): the carrier does not turn to the open human (cosine under 0.6)"), DotBefore < 0.6);
	TestTrue(TEXT("after: the carrier turns to the open human ahead (cosine over 0.95)"), DotAfter > 0.95);
	TestTrue(TEXT("after: lined up on him, the aimed tap goes"), bTapAfter);
	return true;
}

// Item 1b: the human's side supports him. (a) He forechecks an opposing carrier on the big rink (three a side): his mate goes at it too instead of standing
// off. (b) He carries: the mate offers an open lane beside or ahead of him instead of standing between its own net and the puck.
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamHockey2SupportsHuman, "Jam.Bot.Hockey2.SupportsHuman", JamHockeyBrain2TestsLocal::Flags)
bool FJamHockey2SupportsHuman::RunTest(const FString& Parameters)
{
	using namespace JamHockeyBrain2TestsLocal;
	auto Forecheck = [](bool bE2, ERole& OutRole) -> double
	{
		FJamAIWorld W = Three();
		W.Skaters[3].Facing = FVec2(-1.0, 0.0);
		Carry(W, 3, FVec2(5.0, 0.0), FVec2(-3.0, 0.0));
		W.Skaters[0].Pos = FVec2(-1.0, 1.0);    // the human, 5 m from the puck, forechecking
		W.Skaters[1].Pos = FVec2(-8.0, 3.0);    // the mate, 12 m from the puck
		FJamBrain B;
		SetSense(B, bE2);
		FJamAIInput In[kMaxSkaters];
		for (int F = 0; F < 3; ++F) { W.Frame = 1000 + F; B.Think(W, In); }
		OutRole = B.LastRole(1);
		return In[1].Move.Normalized().Dot((W.PuckPos - W.Skaters[1].Pos).Normalized());
	};
	ERole RoleBefore = ERole::Back, RoleAfter = ERole::Back;
	const double FcBefore = Forecheck(false, RoleBefore), FcAfter = Forecheck(true, RoleAfter);
	AddInfo(FString::Printf(TEXT("the human forechecks an opposing carrier: the mate's way towards the puck (cosine) before %.2f (role %d), after %.2f (role %d)"), FcBefore, static_cast<int>(RoleBefore), FcAfter, static_cast<int>(RoleAfter)));
	TestTrue(TEXT("before (evolution 1): the mate stands off the opposing carrier (the support's place)"), RoleBefore == ERole::Support && FcBefore < 0.5);
	TestTrue(TEXT("after: the mate goes at the opposing carrier with the human"), RoleAfter == ERole::Chaser && FcAfter > 0.8);

	auto Lane = [this](bool bE2) -> double
	{
		FJamAIWorld W = Three();
		Carry(W, 0, FVec2(0.0, 0.0), FVec2(6.0, 0.0));
		W.Skaters[1].Pos = FVec2(-3.0, -6.0);
		W.Skaters[4].Pos = FVec2(8.0, -5.0);    // an opponent on the lanes of the near side
		FJamBrain B;
		SetSense(B, bE2);
		FJamAIInput In[kMaxSkaters];
		for (int F = 0; F < 3; ++F) { W.Frame = 1000 + F; B.Think(W, In); }
		if (bE2)
		{
			const FVec2 T = OfferLane(W, 1, 0);
			const FVec2 L = T - W.Skaters[0].Pos;
			const FVec2 Lu = L.Normalized();
			double Near = 1e9;
			for (int o = 3; o < 6; ++o)
			{
				const double Along = FMath::Clamp((W.Skaters[o].Pos - W.Skaters[0].Pos).Dot(Lu), 0.0, L.Length());
				Near = FMath::Min(Near, (W.Skaters[0].Pos + Lu * Along).DistTo(W.Skaters[o].Pos));
			}
			AddInfo(FString::Printf(TEXT("the offered spot (%.1f, %.1f): the nearest opponent to the lane from the human %.1f m"), T.X, T.Y, Near));
			TestTrue(TEXT("after: the offered lane is open (no opponent within 2 m of it)"), Near > 2.0);
			TestTrue(TEXT("after: the spot is beside or ahead of the human, never behind"), T.X >= W.Skaters[0].Pos.X);
			TestTrue(TEXT("after: the mate skates to the offered spot"), In[1].Move.Normalized().Dot((T - W.Skaters[1].Pos).Normalized()) > 0.9);
		}
		return In[1].Move.X;
	};
	const double UpBefore = Lane(false), UpAfter = Lane(true);
	AddInfo(FString::Printf(TEXT("the human carries: the mate's move up the ice before %.2f, after %.2f"), UpBefore, UpAfter));
	TestTrue(TEXT("before (evolution 1): the mate drops back behind the human's puck"), UpBefore < 0.0);
	TestTrue(TEXT("after: the mate goes up the ice with him"), UpAfter > 0.3);
	return true;
}

// Item 2: the chaser is picked by where the puck will be, the passer is not the chaser of its own pass, the yield next to a downed human ends.
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamHockey2LoosePuck, "Jam.Bot.Hockey2.LoosePuck", JamHockeyBrain2TestsLocal::Flags)
bool FJamHockey2LoosePuck::RunTest(const FString& Parameters)
{
	using namespace JamHockeyBrain2TestsLocal;
	using EJob = FJamBrain::EJob;
	// (a) five a side: skater 0 has just passed at 15 m/s to skater 2, 20 m up the ice; the puck is 3 m from the passer and 17 m from the receiver
	auto Pass = [](bool bE2, int& OutPasser, int& OutReceiver)
	{
		FJamAIWorld W = Five();
		W.Skaters[0].Pos = FVec2(0.0, 0.0);
		W.Skaters[2].Pos = FVec2(20.0, 0.0);
		W.PuckPos = FVec2(3.0, 0.0);
		W.PuckVel = FVec2(15.0, 0.0);
		W.PuckLastTouch = 0;
		FJamBrain B;
		SetSense(B, bE2);
		FJamAIInput In[kMaxSkaters];
		for (int F = 0; F < 3; ++F) { W.Frame = 1000 + F; B.Think(W, In); }
		OutPasser = B.LastJob(0) == EJob::Puck ? 1 : 0;
		OutReceiver = B.LastJob(2) == EJob::Puck ? 1 : 0;
		return LoosePuckOwner(W, 0, 8.0);
	};
	int PasserBefore = 0, ReceiverBefore = 0, PasserAfter = 0, ReceiverAfter = 0;
	Pass(false, PasserBefore, ReceiverBefore);
	const int Owner = Pass(true, PasserAfter, ReceiverAfter);
	AddInfo(FString::Printf(TEXT("a 20 m pass in flight: the puck job before: passer %d, receiver %d; after: passer %d, receiver %d (LoosePuckOwner %d)"), PasserBefore, ReceiverBefore, PasserAfter, ReceiverAfter, Owner));
	TestTrue(TEXT("before (evolution 1): the passer chases its own pass"), PasserBefore == 1 && ReceiverBefore == 0);
	TestTrue(TEXT("after: the receiver has the puck job, the passer does not"), PasserAfter == 0 && ReceiverAfter == 1 && Owner == 2);
	// three a side (no shape jobs): the passing chaser leaves its pass to the back it passed to
	auto Pass3 = [](bool bE2) -> ERole
	{
		FJamAIWorld W = Three();
		W.PlayerIndex = -1;
		W.Skaters[0].Role = ERole::Chaser;
		W.Skaters[1].Pos = FVec2(0.0, 0.0);
		W.Skaters[0].Pos = FVec2(20.0, 0.0);
		W.PuckPos = FVec2(3.0, 0.0);
		W.PuckVel = FVec2(15.0, 0.0);
		W.PuckLastTouch = 1;
		FJamBrain B;
		SetSense(B, bE2);
		FJamAIInput In[kMaxSkaters];
		for (int F = 0; F < 3; ++F) { W.Frame = 1000 + F; B.Think(W, In); }
		return B.LastRole(1);
	};
	TestTrue(TEXT("before (evolution 1), three a side: the passer chases its own pass"), Pass3(false) == ERole::Chaser);
	TestTrue(TEXT("after, three a side: the passer takes the support's place"), Pass3(true) == ERole::Support);
	// (b) the human lies knocked down 1.5 m from a loose puck; his mate is 6 m from it
	auto Downed = [](bool bE2) -> double
	{
		FJamAIWorld W = Three();
		W.PuckPos = FVec2(0.0, 0.0);
		W.PuckLastTouch = 3;
		W.Skaters[0].Pos = FVec2(1.5, 0.0);
		W.Skaters[0].bDown = true;
		W.Skaters[1].Pos = FVec2(-6.0, 0.5);
		FJamBrain B;
		SetSense(B, bE2);
		FJamAIInput In[kMaxSkaters];
		for (int F = 0; F < 3; ++F) { W.Frame = 1000 + F; B.Think(W, In); }
		return In[1].Move.Normalized().Dot((W.PuckPos - W.Skaters[1].Pos).Normalized());
	};
	const double DownBefore = Downed(false), DownAfter = Downed(true);
	AddInfo(FString::Printf(TEXT("a loose puck 1.5 m from the downed human: the mate's way towards it (cosine) before %.2f, after %.2f"), DownBefore, DownAfter));
	TestTrue(TEXT("before (evolution 1): the mate holds off the puck next to the downed human"), DownBefore < 0.3);
	TestTrue(TEXT("after: the mate takes the loose puck"), DownAfter > 0.7);
	return true;
}

// Item 3: the brain brakes on purpose, and a bot carrier sprints on an open lane. Pure: a reversal far from anything is carved into a turn; a loose puck
// just behind is a decided stop. The real sim (hockey.regular at pro, the brain on every skater, 2 seeds of 3,600 frames): reverse brakes and carrier
// sprint frames in both arms.
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamHockey2BrakeOnPurpose, "Jam.Bot.Hockey2.BrakeOnPurpose", JamHockeyBrain2TestsLocal::Flags)
bool FJamHockey2BrakeOnPurpose::RunTest(const FString& Parameters)
{
	using namespace JamHockeyBrain2TestsLocal;
	auto Reverse = [](bool bE2, double PuckX, bool& bOutBraking, int& OutCarves, int& OutMeant) -> double
	{
		FJamAIWorld W = Three();
		W.PlayerIndex = -1;
		W.Skaters[0].Role = ERole::Support;
		W.ReverseBrakeDecel = 20.0;
		W.Skaters[1].Pos = FVec2(0.0, 0.0);
		W.Skaters[1].Vel = FVec2(8.0, 0.0);
		W.PuckPos = FVec2(PuckX, 3.0);
		W.PuckLastTouch = 4;
		FJamBrain B;
		SetSense(B, bE2);
		FJamAIInput In[kMaxSkaters];
		B.Think(W, In);
		bOutBraking = B.IsBraking(1);
		OutCarves = B.GetCarves();
		OutMeant = B.GetMeantBrakes();
		const double L = In[1].Move.Length();
		return L > 1e-6 ? In[1].Move.Dot(W.Skaters[1].Vel) / (L * 8.0) : 0.0;
	};
	bool bBrk = false;
	int Carves = 0, Meant = 0;
	const double FarBefore = Reverse(false, -25.0, bBrk, Carves, Meant);
	const double FarAfter = Reverse(true, -25.0, bBrk, Carves, Meant);
	AddInfo(FString::Printf(TEXT("a puck 25 m behind a bot at 8 m/s: the input against the velocity (cosine) before %.2f (the sim brakes under -0.5), after %.2f; carves %d, decided stops %d"), FarBefore, FarAfter, Carves, Meant));
	TestTrue(TEXT("before (evolution 1): the chase reverses against the velocity (a reverse brake by accident)"), FarBefore < -0.5);
	TestTrue(TEXT("after: the reversal is carved into a turn (115 degrees off the velocity: no brake)"), FarAfter > -0.5 && FarAfter < -0.3 && Carves == 1 && Meant == 0 && !bBrk);
	const double NearAfter = Reverse(true, -4.0, bBrk, Carves, Meant);
	AddInfo(FString::Printf(TEXT("a loose puck 4 m behind: the input against the velocity %.2f; decided stops %d, carves %d"), NearAfter, Meant, Carves));
	TestTrue(TEXT("after: a loose puck just behind is a decided stop (the input straight against the velocity, held)"), NearAfter < -0.99 && Meant == 1 && Carves == 0 && bBrk);

	TArray<FString> Errors;
	UJamCartridge* Cart = UJamCartridge::LoadFromFile(UJamCartridge::ResolveCartridgePath(TEXT("hockey.regular")), Errors);
	if (!Cart) { AddError(FString::Printf(TEXT("FAIL hockey.regular does not load: %s"), *FString::Join(Errors, TEXT("; ")))); return false; }
	const FJamMatchConfig C = ToMatchConfigResolved(*Cart, TEXT("pro"));
	struct FArm { int64 Brakes = 0, CarrySprint = 0; int32 Meant = 0, Carves = 0, Goals = 0; };
	auto Play = [&](bool bE2) -> FArm
	{
		FArm A;
		for (uint64 Seed = 1; Seed <= 2; ++Seed)
		{
			FJamSimAdapter Sim(*Cart);
			Sim.Reset(C, Seed);
			UJamSim* S = Sim.GetSim();
			S->SkipFaceoff();
			FJamBrain Brain;
			Brain.Reset();
			Brain.Params = C.AI;
			Brain.Params.InterceptSpeed = C.Speed;
			Brain.Params.AimConeDeg = C.AimConeDeg;
			SetSense(Brain.Params, bE2);
			FJamAIWorld W;
			FJamAIInput In[kMaxSkaters];
			for (int32 F = 0; F < 3600 && !Sim.IsOver(); ++F)
			{
				Sim.View(W);
				W.PlayerIndex = -1;   // no human: the brain plays every skater
				for (int32 i = 0; i < kMaxSkaters; ++i) In[i] = FJamAIInput();
				Brain.Think(W, In);
				Sim.Step(In);
			}
			for (const FJamSkaterState& K : S->GetSkaters()) { A.Brakes += K.ReverseBrakes; A.CarrySprint += K.CarrySprintFrames; }
			A.Meant += Brain.GetMeantBrakes();
			A.Carves += Brain.GetCarves();
			A.Goals += Sim.Score(0) + Sim.Score(1);
		}
		return A;
	};
	const FArm Before = Play(false), After = Play(true);
	AddInfo(FString::Printf(TEXT("hockey.regular pro, ten bots, 2 x 3,600 frames: reverse brakes before %lld, after %lld (decided stops %d, reversals carved %d); carrier sprint frames before %lld, after %lld; goals %d / %d"),
		Before.Brakes, After.Brakes, After.Meant, After.Carves, Before.CarrySprint, After.CarrySprint, Before.Goals, After.Goals));
	TestTrue(TEXT("before (evolution 1): the bots reverse-brake by accident (over 300 in 7,200 frames)"), Before.Brakes > 300);
	TestTrue(TEXT("after: under two fifths of the reverse brakes"), After.Brakes * 5 < Before.Brakes * 2);
	TestEqual(TEXT("before (evolution 1): no bot carrier ever sprints"), static_cast<int32>(Before.CarrySprint), 0);
	TestTrue(TEXT("after: bot carriers sprint on an open lane (60 frames or more)"), After.CarrySprint >= 60);
	Cart->RemoveFromRoot();
	return true;
}

// The hook for track F2's body shield (lane A102, game.stick.body_shield): with FJamAIWorld::bBodyShield set, a bot behind an opposing carrier whose body
// is between its stick and the puck does not lift (the sim would refuse it) and goes round the body. The adapter does not set the flag in this tree.
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamHockey2ShieldHook, "Jam.Bot.Hockey2.ShieldHook", JamHockeyBrain2TestsLocal::Flags)
bool FJamHockey2ShieldHook::RunTest(const FString& Parameters)
{
	using namespace JamHockeyBrain2TestsLocal;
	// Lane A138: the way round the body is for a carrier that dawdles (FJamHockeySense::RoundMaxMps 3 m/s): the scene's carrier glides at 2 m/s (3 before).
	// CarrierMps: its speed; RoundMax below 0 = the default.
	auto Behind = [](bool bShieldInSim, bool bRead, double& OutSideways, double CarrierMps = 2.0, double RoundMax = -1.0) -> bool
	{
		FJamAIWorld W = Three();
		W.PlayerIndex = -1;
		W.Skaters[0].Role = ERole::Support;
		W.Skaters[3].Facing = FVec2(1.0, 0.0);
		Carry(W, 3, FVec2(0.0, 0.0), FVec2(CarrierMps, 0.0));
		W.Skaters[1].Pos = FVec2(-1.2, 0.0);    // directly behind the carrier, the puck on the far side of its body
		W.Skaters[1].Vel = FVec2(3.0, 0.0);
		W.Skaters[1].bCanLift = true;
		W.bBodyShield = bShieldInSim;
		FJamBrain B;
		SetSense(B, true);
		B.Params.Mate.bLift = true;
		B.Params.Mate.Hk.bReadShield = bRead;
		if (RoundMax >= 0.0) { B.Params.Mate.Hk.RoundMaxMps = RoundMax; }
		FJamAIInput In[kMaxSkaters];
		B.Think(W, In);
		OutSideways = FMath::Abs(In[1].Move.Normalized().Y);
		return In[1].bLift;
	};
	double SideOff = 0.0, SideUnread = 0.0, SideRead = 0.0;
	const bool bLiftNoShield = Behind(false, true, SideOff);
	const bool bLiftUnread = Behind(true, false, SideUnread);
	const bool bLiftRead = Behind(true, true, SideRead);
	AddInfo(FString::Printf(TEXT("behind a carrier whose body is between: lifts with no shield in the sim %d; shield in the sim, unread %d (the refused lift); read %d, sideways share of its way %.2f (unread %.2f)"),
		bLiftNoShield ? 1 : 0, bLiftUnread ? 1 : 0, bLiftRead ? 1 : 0, SideRead, SideUnread));
	TestTrue(TEXT("no shield in the sim: the bot lifts from behind (as today)"), bLiftNoShield);
	TestTrue(TEXT("the shield unread: the bot lifts into the body (the lift the sim refuses)"), bLiftUnread);
	TestFalse(TEXT("the shield read: no lift into the body"), bLiftRead);
	TestTrue(TEXT("the shield read: the bot goes round the body (its way has a sideways share over 0.5)"), SideRead > 0.5);
	// Lane A138 (R-0053: a defender that contains wins when the carrier dawdles, not when he stops and goes): a carrier that goes (6 m/s) is not rounded: the
	// bot still presses no lift into the body, and its way is the chase's, not the point beside the carrier. hk_round_max_mps 0 = lane A115's rule: round at any speed.
	{
		double SideGo = 0.0, SideGoOld = 0.0;
		const bool bLiftGo = Behind(true, true, SideGo, 6.0);
		const bool bLiftGoOld = Behind(true, true, SideGoOld, 6.0, 0.0);
		AddInfo(FString::Printf(TEXT("behind a carrier that goes at 6 m/s, the shield read: lifts %d, sideways share of its way %.2f; with hk_round_max_mps 0 (lane A115's rule): lifts %d, sideways %.2f"),
			bLiftGo ? 1 : 0, SideGo, bLiftGoOld ? 1 : 0, SideGoOld));
		TestFalse(TEXT("a carrier that goes: still no lift into the body"), bLiftGo);
		TestTrue(TEXT("a carrier that goes: the bot does not go round (its way is not the point beside the carrier)"), SideGo < SideGoOld - 0.2);
		TestTrue(TEXT("hk_round_max_mps 0: the bot goes round at any speed, as lane A115 had it"), !bLiftGoOld && SideGoOld > 0.5);
	}
	// from the front the body shields nothing
	{
		FJamAIWorld W = Three();
		W.Skaters[3].Facing = FVec2(1.0, 0.0);
		Carry(W, 3, FVec2(0.0, 0.0), FVec2(3.0, 0.0));
		W.Skaters[1].Pos = FVec2(1.9, 0.0);
		W.bBodyShield = true;
		TestFalse(TEXT("a defender in front of the carrier is not shielded"), BodyShields(W, 1, 3));
		W.Skaters[1].Pos = FVec2(-1.2, 0.0);
		TestTrue(TEXT("a defender behind the carrier is"), BodyShields(W, 1, 3));
	}
	return true;
}

// The hook for track F2's take grace (lane A121, game.stick.take_grace_frames): with FJamAISkater::TakeGraceFrames set on an opposing carrier, a bot in
// front of it at lift range does not lift (the sim would refuse it) and contains: it goes goal-side of the carrier. The adapter does not set the field here.
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamHockey2TakeGraceHook, "Jam.Bot.Hockey2.TakeGraceHook", JamHockeyBrain2TestsLocal::Flags)
bool FJamHockey2TakeGraceHook::RunTest(const FString& Parameters)
{
	using namespace JamHockeyBrain2TestsLocal;
	auto Front = [](int Grace, bool bRead, double& OutMoveX) -> bool
	{
		FJamAIWorld W = Three();
		W.PlayerIndex = -1;
		W.Skaters[0].Role = ERole::Support;
		W.Skaters[3].Facing = FVec2(-1.0, 0.0);
		Carry(W, 3, FVec2(0.0, 6.0), FVec2(-3.0, 0.0));
		W.Skaters[3].TakeGraceFrames = Grace;
		W.Skaters[1].Pos = FVec2(-1.5, 6.0);    // in front of the carrier, at lift range, facing it, between it and its own net
		W.Skaters[1].bCanLift = true;
		FJamBrain B;
		SetSense(B, true);
		B.Params.Mate.bLift = true;
		B.Params.Mate.Hk.bReadShield = bRead;
		FJamAIInput In[kMaxSkaters];
		B.Think(W, In);
		OutMoveX = In[1].Move.Normalized().X;
		return In[1].bLift;
	};
	double XNone = 0.0, XUnread = 0.0, XRead = 0.0;
	const bool bLiftNone = Front(0, true, XNone);
	const bool bLiftUnread = Front(20, false, XUnread);
	const bool bLiftRead = Front(20, true, XRead);
	AddInfo(FString::Printf(TEXT("in front of a carrier at lift range: lifts with no grace %d; 20 frames of grace, unread %d (the refused swing); read %d, its way along x %.2f (unread %.2f: through the puck; read: back goal-side)"),
		bLiftNone ? 1 : 0, bLiftUnread ? 1 : 0, bLiftRead ? 1 : 0, XRead, XUnread));
	TestTrue(TEXT("no grace: the bot lifts (as today)"), bLiftNone);
	TestTrue(TEXT("the grace unread: the bot swings a lift the sim refuses"), bLiftUnread);
	TestFalse(TEXT("the grace read: no lift"), bLiftRead);
	TestTrue(TEXT("the grace read: the bot contains, goal-side of the carrier (its way points back to its own net)"), XRead < -0.5);
	TestTrue(TEXT("the grace unread: the bot skates through the puck"), XUnread > 0.5);
	return true;
}

// The neutral value: with every A115 field off the brain is evolution 1's, hash for hash. The four pins are evolution 1's own matches (the regular
// playtester at pro, seeds 1 and 2, hockey.regular and hockey.arena.large; Game/logs/a115/base-*.log, the build of 19:41 before any A115 edit).
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamHockey2Neutral, "Jam.Bot.Hockey2.Neutral", JamHockeyBrain2TestsLocal::Flags)
bool FJamHockey2Neutral::RunTest(const FString& Parameters)
{
	using namespace JamHockeyBrain2TestsLocal;
	struct FPin { const TCHAR* Cart; uint64 Seed; const TCHAR* Hash; };
	const FPin Pins[] = {
		// re-pinned to LADDER SET 3, 15 Nov (the Director's ruling 07:25): the level profiles' numbers changed, no rule did
		{ TEXT("hockey.regular"), 1, TEXT("91796e904a3fb739") }, { TEXT("hockey.regular"), 2, TEXT("ecb9d7ad4e24eef7") },
		// re-pinned to LADDER SET 3, 15 Nov (the Director's ruling 07:25): the level profiles' numbers changed, no rule did
		{ TEXT("hockey.arena.large"), 1, TEXT("99062c5d29d5071d") }, { TEXT("hockey.arena.large"), 2, TEXT("d976fb612d1665e1") } };
	// Lane A138 (R-0053 point 5): the pins are evolution 1's matches on the tree lane A115 began from (the vision's commit: none of the evening's sim rules).
	// The neutral arm is the shared baseline (JamBaseline.h: every rule since at its neutral value) with every A115 field off; evolution 2 plays the tree as it stands.
	for (const FPin& P : Pins)
	{
		for (int Arm = 0; Arm < 2; ++Arm)
		{
			TArray<FString> Errors;
			UJamCartridge* Cart = UJamCartridge::LoadFromFile(UJamCartridge::ResolveCartridgePath(P.Cart), Errors);
			if (!Cart) { AddError(FString::Printf(TEXT("FAIL %s does not load"), P.Cart)); return false; }
			if (Arm == 0) { JamBaseline::MakeNeutral(Cart->Game); JamBaseline::WithWhistle(Cart->Game); }   // lane A133: the pins blew the whistle (lane A112 took it out of the cuts)
			FJamMatchConfig C = ToMatchConfigResolved(*Cart, TEXT("pro"));
			SetSense(C.AI, Arm == 1);
			if (Arm == 0)
			{
				char Err[200] = {};
				TestTrue(TEXT("the shared baseline's brain tune applies"), ApplyDifficultyTune(JamBaseline::BrainTune("pro", Cart->Game.Rink.LengthM >= JamAI::LargeRinkM), C.AI, Err, sizeof(Err)));
			}
			FJamSimAdapter Sim(*Cart);
			const FJamPlaytestStats St = RunPlaytestMatch(Sim, C, P.Seed, EPlaytester::Regular, 36000, Cart->Game.Shot.ChargeFramesMax, false, nullptr, nullptr, 0);
			const FString Hash = FString::Printf(TEXT("%016llx"), static_cast<unsigned long long>(St.Hash));
			AddInfo(FString::Printf(TEXT("%s seed %llu, %s: %lld frames, hash %s"), P.Cart, P.Seed, Arm == 0 ? TEXT("the shared baseline, every A115 field off") : TEXT("evolution 2, the tree as it stands"), static_cast<long long>(St.Frames), *Hash));
			if (Arm == 0) { TestEqual(*FString::Printf(TEXT("%s seed %llu with every A115 field off is evolution 1's match"), P.Cart, P.Seed), Hash, FString(P.Hash)); }
			else { TestNotEqual(*FString::Printf(TEXT("%s seed %llu: evolution 2 plays another match"), P.Cart, P.Seed), Hash, FString(P.Hash)); }
			Cart->RemoveFromRoot();
		}
	}
	return true;
}

#endif
