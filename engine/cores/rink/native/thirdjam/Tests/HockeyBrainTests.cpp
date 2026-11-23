// Lane A94 (R-0045 law 2, docs/VISION.md section 2, docs/experiments/BRAIN.md): the hockey principles in the brain. Headless, no world, no map:
//   UnrealEditor-Cmd ThirdJam.uproject -ExecCmds="Automation RunTests Jam.Bot.Hockey; Automation RunTests Jam.Bot.CarrierDoesNotChargeTheWall; Quit" -nullrhi -unattended -nopause -stdout
#include "CoreMinimal.h"
#include "Misc/AutomationTest.h"

#include "../AI/JamBotMatch.h"
#include "../AI/JamSimAdapter.h"
#include "../AI/DifficultyResolve.h"
#include "../AI/JamAICore.h"
#include "JamCartridge.h"
#include "JamEventBus.h"
#include "JamSim.h"

#if WITH_DEV_AUTOMATION_TESTS

namespace JamHockeyBrainTestsLocal
{
	constexpr EAutomationTestFlags Flags = EAutomationTestFlags::EditorContext | EAutomationTestFlags::CommandletContext | EAutomationTestFlags::EngineFilter;

	// A 5 v 5 world on 90 x 45 for the pure tests: team 0 (defends -x) skaters 0-4 (chaser, support, support, back, back), team 1 skaters 5-9 likewise.
	JamAI::FJamAIWorld World()
	{
		using namespace JamAI;
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
}

// Step 1: the space read. The carrier (0) skates up the middle at 6 m/s; two opponents stand on its lane 8 m ahead; teammate 1 stands open on the right and
// further up; teammate 2 has an opponent on its pass lane; teammate 3 has an opponent beside it.
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamHockeySpaceRead, "Jam.Bot.Hockey.SpaceRead", JamHockeyBrainTestsLocal::Flags)
bool FJamHockeySpaceRead::RunTest(const FString& Parameters)
{
	using namespace JamAI;
	FJamAIWorld W = JamHockeyBrainTestsLocal::World();
	W.Skaters[0].Pos = FVec2(0.0, 0.0);
	W.Skaters[0].Vel = FVec2(6.0, 0.0);
	W.PuckPos = FVec2(1.2, 0.0);
	W.Carrier = 0;
	W.PuckLastTouch = 0;
	W.Skaters[5].Pos = FVec2(8.0, -1.5);
	W.Skaters[6].Pos = FVec2(8.0, 1.5);
	W.Skaters[1].Pos = FVec2(12.0, 14.0);     // open, 18 m on, nearer their net
	W.Skaters[2].Pos = FVec2(-10.0, -12.0);   // an opponent on the lane to it
	W.Skaters[7].Pos = FVec2(-5.0, -6.2);
	W.Skaters[3].Pos = FVec2(-15.0, 10.0);    // an opponent beside it
	W.Skaters[8].Pos = FVec2(-15.0, 11.5);
	W.Skaters[9].Pos = FVec2(35.0, 0.0);
	const FJamSpaceRead R = ReadSpace(W, 0, FVec2(1.0, 0.0), 5.0);
	TestEqual(TEXT("two opponents on the lane ahead"), R.OnLane, 2);
	TestTrue(*FString::Printf(TEXT("the first opponent is one of the two (%d)"), R.FirstOpp), R.FirstOpp == 5 || R.FirstOpp == 6);
	TestTrue(*FString::Printf(TEXT("it arrives inside the pro read (1.4 s) at 6 m/s closing: (8.1 - 1) / 6 = 1.19 s (%.2f s)"), R.ArriveSec), R.ArriveSec < 1.4 && R.ArriveSec > 1.0);
	TestTrue(TEXT("teammate 1: lane open, open, better placed"), R.bLaneOpen[1] && R.bOpen[1] && R.bBetter[1]);
	TestFalse(TEXT("teammate 2: a body on the pass lane"), R.bLaneOpen[2]);
	TestFalse(TEXT("teammate 3: marked (an opponent 1.5 m off)"), R.bOpen[3]);
	TestTrue(*FString::Printf(TEXT("teammate 3's free space is 1.5 m (%.2f)"), R.MateFree[3]), FMath::Abs(R.MateFree[3] - 1.5) < 1e-6);
	// the lane clear: nobody on it, no time to arrive
	W.Skaters[5].Pos = FVec2(8.0, -15.0);
	W.Skaters[6].Pos = FVec2(8.0, 15.0);
	const FJamSpaceRead Clear = ReadSpace(W, 0, FVec2(1.0, 0.0), 5.0);
	TestEqual(TEXT("open ice: nobody on the lane"), Clear.OnLane, 0);
	TestTrue(TEXT("open ice: nobody arrives"), Clear.ArriveSec > 100.0);
	return true;
}

// Step 3: the shapes. Team 0 carries in the neutral zone: one close support, the far side, both backs at the points; team 1 defends: one presser, one on the
// carrier's nearest pass. With the sense off nobody has a job (the brain before A94).
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamHockeyShapes, "Jam.Bot.Hockey.Shapes", JamHockeyBrainTestsLocal::Flags)
bool FJamHockeyShapes::RunTest(const FString& Parameters)
{
	using namespace JamAI;
	FJamAIWorld W = JamHockeyBrainTestsLocal::World();
	W.Skaters[0].Pos = FVec2(-5.0, 3.0);
	W.Skaters[0].Vel = FVec2(5.0, 0.0);
	W.PuckPos = FVec2(-3.8, 3.0);
	W.Skaters[1].Pos = FVec2(-3.0, 1.0);   // a teammate 2.8 m from the carrier (the old support pounced on the puck inside 5 m)
	W.Carrier = 0;
	W.PuckLastTouch = 0;
	FJamBrain Brain;
	Brain.Reset();
	Brain.Params.Mate.Hk = ProHockeySense();
	Brain.Params.Mate.Hk.ShapeShare = 1.0;
	Brain.Params.Mate.Hk.LateFrames = 0;
	Brain.Params.Opp.Hk = Brain.Params.Mate.Hk;
	FJamAIInput In[kMaxSkaters];
	for (int F = 0; F < 3; ++F) { W.Frame = 1000 + F; Brain.Think(W, In); }
	using EJob = FJamBrain::EJob;
	int Support = 0, Far = 0, Point = 0, Press = 0, Cover = 0;
	for (int i = 0; i < 10; ++i)
	{
		const EJob J = Brain.LastJob(i);
		if (i < 5) { Support += J == EJob::Support; Far += J == EJob::Far; Point += J == EJob::Point; }
		else { Press += J == EJob::Press; Cover += J == EJob::Cover; }
	}
	TestEqual(TEXT("attack: one close support"), Support, 1);
	TestEqual(TEXT("attack: one far side"), Far, 1);
	TestEqual(TEXT("attack: both backs at the points"), Point, 2);
	TestEqual(TEXT("defence: one presses"), Press, 1);
	TestEqual(TEXT("defence: one covers the nearest pass"), Cover, 1);
	// nobody of the attacking team goes for its own carrier's puck: only the carrier has the puck job, and the teammate beside it skates away to give it room
	int PuckJobs = 0;
	for (int i = 1; i < 5; ++i) { PuckJobs += Brain.LastJob(i) == EJob::Puck; }
	TestEqual(TEXT("only the carrier has the puck"), PuckJobs, 0);
	{
		const FVec2 ToC = (W.Skaters[0].Pos - W.Skaters[1].Pos).Normalized();
		const double Dot = In[1].Move.Normalized().Dot(ToC);
		TestTrue(*FString::Printf(TEXT("the teammate 2.8 m off skates away from its carrier (%.2f)"), Dot), Dot < 0.0);
	}
	FJamBrain Off;
	Off.Reset();
	Off.Params.Mate.Hk = FJamHockeySense();
	Off.Params.Opp.Hk = FJamHockeySense();
	Off.Think(W, In);
	int Jobs = 0;
	for (int i = 0; i < 10; ++i) { Jobs += Off.LastJob(i) != EJob::None; }
	TestEqual(TEXT("sense off: no jobs"), Jobs, 0);
	return true;
}

// Step 2 (brief A94 point 2): a carrier facing a set defence of two on its lane, with an open teammate, passes inside 60 frames, 10 of 10 seeds. The real sim
// (hockey.regular, pro), the brain on every skater; the scene varies by seed (the carrier's lane, the wall's depth, the teammate's side). The same scenes
// with the sense off are reported (the brain before A94 charges).
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamCarrierDoesNotChargeTheWall, "Jam.Bot.CarrierDoesNotChargeTheWall", JamHockeyBrainTestsLocal::Flags)
bool FJamCarrierDoesNotChargeTheWall::RunTest(const FString& Parameters)
{
	using namespace JamAI;
	TArray<FString> Errors;
	UJamCartridge* Cart = UJamCartridge::LoadFromFile(UJamCartridge::ResolveCartridgePath(TEXT("hockey.regular")), Errors);
	if (!Cart) { AddError(FString::Printf(TEXT("FAIL hockey.regular does not load: %s"), *FString::Join(Errors, TEXT("; ")))); return false; }
	const FJamMatchConfig C = ToMatchConfigResolved(*Cart, TEXT("pro"));
	auto Scene = [&](uint64 Seed, bool bSense, int32& OutFrame, int32& OutCarrier) -> bool
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
		if (!bSense) { Brain.Params.Mate.Hk = FJamHockeySense(); Brain.Params.Opp.Hk = FJamHockeySense(); }
		const TArray<FJamSkaterState>& All = S->GetSkaters();
		const int32 Hi = S->GetHumanIndex();
		TArray<int32> T0, T1;
		for (const FJamSkaterState& K : All) { if (K.Index == Hi) continue; (K.Team == 0 ? T0 : T1).Add(K.Index); }
		if (T0.Num() < 3 || T1.Num() < 3) { return false; }
		const int32 Carrier = T0[0], Mate = T0[1];
		OutCarrier = Carrier;
		const double Y0 = (static_cast<double>(Seed % 5) - 2.0) * 1.5;
		const double Wall = 9.0 + static_cast<double>(Seed % 3);
		const double Side = (Seed % 2) ? 1.0 : -1.0;
		// everyone else far away: team 0 deep in its end, team 1 on its own blue line wide
		int32 k = 0;
		for (const FJamSkaterState& K : All)
		{
			const double Y = -16.0 + 8.0 * (k++ % 5);
			S->SetSkater(K.Index, K.Team == 0 ? FVector2D(-32.0, Y) : FVector2D(34.0, Y), FVector2D::ZeroVector, K.Team == 0 ? 0.0 : UE_DOUBLE_PI);
		}
		S->SetSkater(Carrier, FVector2D(-6.0, Y0), FVector2D(6.0, 0.0), 0.0);
		S->SetPuck(FVector2D(-4.9, Y0), FVector2D(6.0, 0.0));
		S->SetSkater(T1[0], FVector2D(-6.0 + Wall, Y0 - 1.6), FVector2D::ZeroVector, UE_DOUBLE_PI);
		S->SetSkater(T1[1], FVector2D(-6.0 + Wall, Y0 + 1.6), FVector2D::ZeroVector, UE_DOUBLE_PI);
		S->SetSkater(Mate, FVector2D(-2.0, Y0 + Side * 11.0), FVector2D(4.0, 0.0), 0.0);
		FJamAIWorld W;
		FJamAIInput In[kMaxSkaters];
		for (int32 F = 0; F < 60 && !Sim.IsOver(); ++F)
		{
			Sim.View(W);
			W.PlayerIndex = -1;   // no human: the brain plays every skater
			for (int32 i = 0; i < kMaxSkaters; ++i) In[i] = FJamAIInput();
			Brain.Think(W, In);
			Sim.Step(In);
			for (const FJamSimEvent& E : S->GetFrameEvents())
			{
				if (E.Name == JamEvents::Pass && E.Who == Carrier) { OutFrame = F; return true; }
			}
		}
		return false;
	};
	int32 Passed = 0, PassedOff = 0;
	for (uint64 Seed = 1; Seed <= 10; ++Seed)
	{
		int32 Frame = -1, Carrier = -1;
		const bool bPass = Scene(Seed, true, Frame, Carrier);
		int32 FrameOff = -1, CarrierOff = -1;
		const bool bPassOff = Scene(Seed, false, FrameOff, CarrierOff);
		Passed += bPass ? 1 : 0;
		PassedOff += bPassOff ? 1 : 0;
		AddInfo(FString::Printf(TEXT("seed %llu: carrier %d %s (sense off: %s)"), Seed, Carrier, bPass ? *FString::Printf(TEXT("passes at frame %d"), Frame) : TEXT("no pass in 60 frames"),
			bPassOff ? *FString::Printf(TEXT("passes at frame %d"), FrameOff) : TEXT("no pass")));
	}
	AddInfo(FString::Printf(TEXT("the wall: %d of 10 pass inside 60 frames (the brain before A94: %d of 10)"), Passed, PassedOff));
	TestEqual(TEXT("a set defence of two on the lane and an open teammate: a pass inside 60 frames, 10 of 10 seeds"), Passed, 10);
	Cart->RemoveFromRoot();
	return true;
}

// Lane A105 (track Q2): a skater in the penalty box is not on the ice for the brain. FJamSimAdapter::BuildWorld mapped only the knockdown into
// FJamAISkater::bDown, so a boxed skater (pinned at UJamSim::BoxPos, on the ice by the bottom boards at centre) still counted for its team as a presser, a
// cover, a pass outlet or the loose puck's owner, and for the other team as pressure on a carrier passing the box. Every brain read skips bDown: the box is
// mapped into it. Staged: hockey.regular (penalties on), a 7 m/s check pressed head-on into an opponent without the puck: a foul, the checker boxed.
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamHockeyBoxedIsOffIce, "Jam.Bot.Hockey.BoxedIsOffIce", JamHockeyBrainTestsLocal::Flags)
bool FJamHockeyBoxedIsOffIce::RunTest(const FString& Parameters)
{
	TArray<FString> Errors;
	UJamCartridge* C = UJamCartridge::LoadFromFile(UJamCartridge::ResolveCartridgePath(TEXT("hockey.regular")), Errors);
	if (!C) { AddError(TEXT("hockey.regular did not load")); return false; }
	FJamGameConfig G = C->Game;
	G.Rules.bPenalties = true;
	UJamSim* Sim = NewObject<UJamSim>();
	Sim->Init(G, 1);
	Sim->SkipFaceoff();
	const int32 Human = Sim->GetHumanIndex();
	int32 A = -1, V = -1;
	for (const FJamSkaterState& S : Sim->GetSkaters())
	{
		if (S.Index == Human) continue;
		if (S.Team == 0 && A < 0) A = S.Index;
		if (S.Team == 1 && V < 0) V = S.Index;
	}
	// Everybody parked along the top boards, the puck far away, the checker at 7 m/s head-on into the victim skating back at 4 m/s.
	for (const FJamSkaterState& S : Sim->GetSkaters()) Sim->SetSkater(S.Index, FVector2D(-30.0 + S.Index * 3.0, 20.0), FVector2D::ZeroVector, 0.0);
	Sim->SetPuck(FVector2D(-35.0, -15.0), FVector2D::ZeroVector);
	Sim->SetSkater(A, FVector2D(0.0, 0.0), FVector2D(7.0, 0.0), 0.0);
	// Lane A192: the window opens game.contact.check_windup_frames after the press: the victim starts the closing's ground farther out, the scene runs that much longer.
	const int32 Wu = G.Contact.CheckWindupFor(Sim->GetSkaters()[A].bHuman);   // lane A200: the presser's own (bot_check_windup_frames for a bot)
	Sim->SetSkater(V, FVector2D(1.2 + 11.0 * Wu / 60.0, 0.0), FVector2D(-4.0, 0.0), PI);   // head-on: the biggest hit, a knockdown
	TArray<FJamInput> In;
	In.SetNum(Sim->GetSkaters().Num());
	In[A].bCheck = true;
	for (int32 f = 0; f < 10 + Wu && !Sim->GetSkaters()[A].InBox(); ++f) { Sim->Step(In); In[A].bCheck = false; }
	if (!Sim->GetSkaters()[A].InBox()) { AddError(TEXT("staging: the check from behind did not send the checker to the box")); return false; }
	JamAI::FJamAIWorld W;
	JamAI::FJamSimAdapter::BuildWorld(*Sim, W);
	AddInfo(FString::Printf(TEXT("checker %d boxed for %d frames at (%.1f, %.1f); brain bDown %d"), A, Sim->GetSkaters()[A].PenaltyFrames, W.Skaters[A].Pos.X, W.Skaters[A].Pos.Y, W.Skaters[A].bDown ? 1 : 0));
	TestTrue(TEXT("a boxed skater is off the ice for the brain (bDown)"), W.Skaters[A].bDown);
	TestEqual(TEXT("the victim reads as down exactly when the sim has it down"), W.Skaters[V].bDown, Sim->GetSkaters()[V].IsDown());
	return true;
}

#endif
