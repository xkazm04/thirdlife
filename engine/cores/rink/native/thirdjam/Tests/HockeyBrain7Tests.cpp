// Lane A193 (track Q2, evolution 7; docs/experiments/BRAIN-7.md): the bots know how fast everyone now is. A skater without the puck has
// skater.free_speed_mult more top speed and thrust (lane A185); the brain's arrival estimates and the presser's gap now read it (FJamHockeySense::
// bTrueSpeed, bTrueGap; tune keys opp./mate.hk_true_speed, hk_true_gap; brain7=0 = evolution 6).
//   UnrealEditor-Cmd ThirdJam.uproject -ExecCmds="Automation RunTests Jam.Bot.Hockey7; Quit" -nullrhi -Multiprocess -unattended -nopause -stdout
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

namespace JamHockeyBrain7TestsLocal
{
	constexpr EAutomationTestFlags Flags = EAutomationTestFlags::EditorContext | EAutomationTestFlags::CommandletContext | EAutomationTestFlags::EngineFilter;
	using namespace JamAI;

	// 5 v 5 on 90 x 45, no human: team 0 (defends -x) skaters 0-4, team 1 skaters 5-9. Everyone parked.
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
			S.Pos = FVec2(S.Team == 0 ? -30.0 : 38.0, -12.0 + 6.0 * (i % 5));
			S.Spawn = S.Pos;
		}
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
	// The pro sense on both sides, executed fully and at once, every rule of evolutions 3 to 7 at its neutral value; the sim's speeds of hockey.regular
	// (skater.speed 11, free_speed_mult as given). A test switches one rule on.
	void Start(FJamBrain& B, double FreeMul)
	{
		B.Reset();
		B.Params.Mate.Hk = ProHockeySense();
		B.Params.Opp.Hk = ProHockeySense();
		for (FJamHockeySense* H : { &B.Params.Mate.Hk, &B.Params.Opp.Hk }) { H->ShapeShare = 1.0; H->LateFrames = 0; }
		SetEvolution3(B.Params.Mate.Hk, false, true);
		SetEvolution3(B.Params.Opp.Hk, false, false);
		SetEvolution4(B.Params.Mate.Hk, false, true);
		SetEvolution4(B.Params.Opp.Hk, false, false);
		for (FJamHockeySense* H : { &B.Params.Mate.Hk, &B.Params.Opp.Hk }) { SetEvolution5(*H, false); SetEvolution6(*H, false); SetEvolution7(*H, false); }
		B.Params.InterceptSpeed = 11.0;
		B.Params.FreeSpeedMult = FreeMul;
	}
}

// The speeds the brain plans with: skater.speed with the rule off (exactly: a pin of every older tree), x free_speed_mult with it on.
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamHockey7Speeds, "Jam.Bot.Hockey7.Speeds", JamHockeyBrain7TestsLocal::Flags)
bool FJamHockey7Speeds::RunTest(const FString& Parameters)
{
	using namespace JamHockeyBrain7TestsLocal;
	FJamBrain B;
	Start(B, 1.15);
	FJamHockeySense H = B.Params.Opp.Hk;
	TestEqual(TEXT("off: a free skater planned at skater.speed"), B.FreeSpeed(H), 11.0);
	TestEqual(TEXT("off: the presser's gap at skater.speed"), B.GapSpeed(H), 11.0);
	H.bTrueSpeed = H.bTrueGap = true;
	AddInfo(FString::Printf(TEXT("skater.speed 11, free_speed_mult 1.15: the brain plans a free skater at %.4f m/s, the presser's gap at %.4f m/s"), B.FreeSpeed(H), B.GapSpeed(H)));
	TestTrue(TEXT("on: a free skater planned at skater.speed x free_speed_mult"), FMath::IsNearlyEqual(B.FreeSpeed(H), 12.65, 1e-9));
	TestTrue(TEXT("on: the presser's gap at its true top speed"), FMath::IsNearlyEqual(B.GapSpeed(H), 12.65, 1e-9));
	B.Params.FreeSpeedMult = 1.0;
	TestEqual(TEXT("on, free_speed_mult 1: skater.speed"), B.FreeSpeed(H), 11.0);
	return true;
}

// The chase intercept and the presser's gap read the true speed: the moves change with the rule on, and not at all with free_speed_mult 1.
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamHockey7Moves, "Jam.Bot.Hockey7.Moves", JamHockeyBrain7TestsLocal::Flags)
bool FJamHockey7Moves::RunTest(const FString& Parameters)
{
	using namespace JamHockeyBrain7TestsLocal;
	// (a) The intercept: a loose puck crosses the ice at 10 m/s, 5 m in front of team 1's chaser (skater 5). Its first move.
	auto Chase = [](bool bOn, double FreeMul) -> FVec2
	{
		FJamAIWorld W = Five();
		W.Skaters[5].Pos = FVec2(5.0, 0.0);
		W.PuckPos = FVec2(0.0, -3.0);
		W.PuckVel = FVec2(0.0, 10.0);   // the intercept: 0.48 s at 11 m/s, 0.40 s at 12.65 (inside the lead's cap of 1 s)
		W.PuckLastTouch = 1;
		FJamBrain B;
		Start(B, FreeMul);
		B.Params.Opp.Hk.bTrueSpeed = bOn;
		B.Params.Mate.Hk.bTrueSpeed = bOn;
		FJamAIInput In[kMaxSkaters];
		B.Think(W, In);
		return In[5].Move;
	};
	const FVec2 C0 = Chase(false, 1.15), C1 = Chase(true, 1.15), C2 = Chase(true, 1.0);
	AddInfo(FString::Printf(TEXT("the chaser of a crossing puck: its move (%.3f, %.3f) planning at skater.speed, (%.3f, %.3f) at the true speed, (%.3f, %.3f) on with free_speed_mult 1"),
		C0.X, C0.Y, C1.X, C1.Y, C2.X, C2.Y));
	TestTrue(TEXT("the chaser's move changes when it knows it is faster"), FMath::Abs(C1.Y - C0.Y) > 1e-3 || FMath::Abs(C1.X - C0.X) > 1e-3);
	TestTrue(TEXT("free_speed_mult 1: the rule changes nothing"), C2.X == C0.X && C2.Y == C0.Y);
	// (b) The presser's gap: team 0's skater 0 carries at 6 m/s towards the net at +41; team 1's skater 5 presses 10 m goal-side (kept on its job).
	auto Press = [](bool bOn, double FreeMul) -> FVec2
	{
		FJamAIWorld W = Five();
		W.Skaters[5].Pos = FVec2(10.0, 0.0);
		FJamBrain B;
		Start(B, FreeMul);
		B.Params.Opp.HuntRadiusM = 30.0;
		B.Params.Opp.Hk.bPressInHunt = true;
		B.Params.Opp.Hk.bTrueGap = bOn;
		FJamAIInput In[kMaxSkaters];
		for (int f = 0; f < 100; ++f)
		{
			W.Frame = 1000 + f;
			Carry(W, 0, FVec2(0.0, -2.5 + 0.05 * f), FVec2(6.0, 0.0), FVec2(1.0, 0.0));
			B.Think(W, In);
		}
		return B.LastJob(5) == FJamBrain::EJob::Press ? In[5].Move : FVec2(99.0, 99.0);
	};
	const FVec2 P0 = Press(false, 1.15), P1 = Press(true, 1.15), P2 = Press(true, 1.0);
	AddInfo(FString::Printf(TEXT("the presser 10 m goal-side of a carrier at 6 m/s: its move (%.3f, %.3f) as before, (%.3f, %.3f) with the true gap, (%.3f, %.3f) on with free_speed_mult 1"),
		P0.X, P0.Y, P1.X, P1.Y, P2.X, P2.Y));
	TestTrue(TEXT("the skater is the presser in every arm"), P0.X < 50.0 && P1.X < 50.0 && P2.X < 50.0);
	TestTrue(TEXT("with the true gap it backs off less (its retreat matches the carrier instead of outrunning it by the multiplier)"), P1.X < P0.X - 1e-3);
	TestTrue(TEXT("free_speed_mult 1: the rule changes nothing"), P2.X == P0.X && P2.Y == P0.Y);
	return true;
}

// The neutral values: the tune keys; brain7=0 and every older switch put evolution 7 off; the rule reads only the multiplier (free_speed_mult 1: the
// shipped match is brain7=0's); the same match twice is the same match; with the multiplier the rule is alive.
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamHockey7Neutral, "Jam.Bot.Hockey7.Neutral", JamHockeyBrain7TestsLocal::Flags)
bool FJamHockey7Neutral::RunTest(const FString& Parameters)
{
	using namespace JamHockeyBrain7TestsLocal;
	for (EDifficulty Lv : { EDifficulty::Rookie, EDifficulty::Pro, EDifficulty::AllStar })
	{
		FJamAIParams A;
		ApplyDifficultyProfile(GetDifficultyProfile(Lv), A);
		AddInfo(FString::Printf(TEXT("%hs as shipped: true speed %d / %d, true gap %d / %d (opposing side / mates)"), DifficultyName(Lv),
			A.Opp.Hk.bTrueSpeed ? 1 : 0, A.Mate.Hk.bTrueSpeed ? 1 : 0, A.Opp.Hk.bTrueGap ? 1 : 0, A.Mate.Hk.bTrueGap ? 1 : 0));
		const bool bLevel = GetDifficultyProfile(Lv).bTrueSpeeds;
		TestEqual(TEXT("rookie keeps the old planning; pro and all_star plan with the true speeds"), bLevel, Lv != EDifficulty::Rookie);
		TestTrue(TEXT("as shipped: the level plays evolution 7 as kEvo7TrueSpeed / kEvo7TrueGap and its bTrueSpeeds say"), A.Opp.Hk.bTrueSpeed == (bLevel && kEvo7TrueSpeed) && A.Mate.Hk.bTrueSpeed == (bLevel && kEvo7TrueSpeed)
			&& A.Opp.Hk.bTrueGap == (bLevel && kEvo7TrueGap) && A.Mate.Hk.bTrueGap == (bLevel && kEvo7TrueGap));
		for (const char* Tune : { "brain7=0", "brain6=0", "brain5=0", "brain4=0", "brain3=0", "brain2=0" })
		{
			FJamAIParams P = A;
			P.Opp.Hk.bTrueSpeed = P.Mate.Hk.bTrueSpeed = P.Opp.Hk.bTrueGap = P.Mate.Hk.bTrueGap = true;
			char Err[200] = {};
			TestTrue(*FString::Printf(TEXT("the tune %hs applies"), Tune), ApplyDifficultyTune(Tune, P, Err, sizeof(Err)));
			TestTrue(*FString::Printf(TEXT("%hs: evolution 7 is off"), Tune), !P.Opp.Hk.bTrueSpeed && !P.Mate.Hk.bTrueSpeed && !P.Opp.Hk.bTrueGap && !P.Mate.Hk.bTrueGap);
		}
		FJamAIParams Q = A;
		char Err[200] = {};
		TestTrue(TEXT("the one-rule keys apply"), ApplyDifficultyTune("brain7=0;opp.hk_true_speed=1;mate.hk_true_gap=1", Q, Err, sizeof(Err)));
		TestTrue(TEXT("... and set what they name"), Q.Opp.Hk.bTrueSpeed && !Q.Mate.Hk.bTrueSpeed && !Q.Opp.Hk.bTrueGap && Q.Mate.Hk.bTrueGap);
	}
	auto Match = [this](const char* Tune, double FreeMul) -> FString
	{
		TArray<FString> Errors;
		UJamCartridge* Cart = UJamCartridge::LoadFromFile(UJamCartridge::ResolveCartridgePath(TEXT("hockey.regular")), Errors);
		if (!Cart) { AddError(TEXT("FAIL hockey.regular does not load")); return FString(); }
		if (FreeMul > 0.0) { Cart->Game.Skater.FreeSpeedMult = FreeMul; }
		FJamMatchConfig C = ToMatchConfigResolved(*Cart, TEXT("pro"));
		TestEqual(TEXT("the brain is told the cartridge's free_speed_mult"), C.AI.FreeSpeedMult, Cart->Game.Skater.FreeSpeedMult);
		TestEqual(TEXT("the match config carries it"), C.FreeSpeedMult, Cart->Game.Skater.FreeSpeedMult);
		if (Tune) { char Err[200] = {}; TestTrue(TEXT("the tune applies"), ApplyDifficultyTune(Tune, C.AI, Err, sizeof(Err))); }
		FJamSimAdapter Sim(*Cart);
		const FJamPlaytestStats St = RunPlaytestMatch(Sim, C, 1, EPlaytester::Regular, 36000, Cart->Game.Shot.ChargeFramesMax, false, nullptr, nullptr, 0);
		Cart->RemoveFromRoot();
		return FString::Printf(TEXT("%016llx (%lld frames, %d:%d)"), static_cast<unsigned long long>(St.Hash), static_cast<long long>(St.Frames), St.GoalsFor, St.GoalsAgainst);
	};
	const FString A1 = Match(nullptr, 0.0), A2 = Match(nullptr, 0.0), Off = Match("brain7=0", 0.0), N1 = Match(nullptr, 1.0), N0 = Match("brain7=0;brain8=1;brain9=1;opp.hk_dodge9_share=0.3;opp.hk_drop_no_hit9_frames=45;opp.hk_early_long_shot9_frames=600", 1.0);   // lane A202: brain7=0 also switches evolution 8 off; brain8=1 puts it back as shipped   // lane A206: brain9=1 too
	AddInfo(FString::Printf(TEXT("hockey.regular at pro, the regular player, seed 1: as shipped %s; brain7=0 %s; free_speed_mult 1: as shipped %s, brain7=0 %s"), *A1, *Off, *N1, *N0));
	TestEqual(TEXT("the same match twice is the same match"), A1, A2);
	TestEqual(TEXT("free_speed_mult 1: the rule reads only the multiplier (as shipped = brain7=0)"), N1, N0);
	if (kEvo7TrueSpeed || kEvo7TrueGap) { TestNotEqual(TEXT("with the multiplier the rule plays (as shipped differs from brain7=0)"), A1, Off); }
	else { TestEqual(TEXT("as shipped is brain7=0 (the rule ships at its neutral value)"), A1, Off); }
	return true;
}

#endif
