// Lane A181 (track Q2, evolution 6; docs/experiments/BRAIN-6.md): the presser leaves the man who has only just won the puck; all_star's second man.
//   UnrealEditor-Cmd ThirdJam.uproject -ExecCmds="Automation RunTests Jam.Bot.Hockey6; Quit" -nullrhi -Multiprocess -unattended -nopause -stdout
// Jam.Bot.Hockey6.*: pure worlds, both arms in one process (the rule's field at its neutral value must miss the bar, the rule on must meet it).
// Bar.Bot.Hockey6.Human (outside the gate's Jam filter): the instrument of item 2. It plays matches in process and reads, on the brain's own world, how
// often the human is knocked down, how often with the puck his for under half a second ("as he won it": a carry of fewer than 30 frames that ended
// within 3 frames of the knockdown; also under 15 frames), and his share of play lying down. Logged lines only. From the environment:
//   JAM_A181_TUNES "name:tune|name:tune" (default: as shipped), JAM_A181_LEVELS "pro,rookie,all_star" (default pro), JAM_A181_MATCHES (default 200).
// Run it with JAM_PLAYTESTER_CHECK=closing for the ladder's instrument.
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

namespace JamHockeyBrain6TestsLocal
{
	constexpr EAutomationTestFlags Flags = EAutomationTestFlags::EditorContext | EAutomationTestFlags::CommandletContext | EAutomationTestFlags::EngineFilter;
	using namespace JamAI;

	// 5 v 5 on 90 x 45, no human: team 0 (defends -x) skaters 0-4, team 1 skaters 5-9 (the opposing side when no human is seated). Everyone parked.
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
	// 3 v 3 on 120 x 60: team 0: 0 the human, 1 chaser, 2 back; team 1: 3 chaser, 4 support, 5 back. Everyone parked.
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
			S.Pos = FVec2(S.Team == 0 ? -30.0 : 30.0, -24.0 + 8.0 * i);
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
	// The pro sense on both sides, executed fully and at once, every rule of evolutions 3 to 6 at its neutral value; a test switches one on.
	void Start(FJamBrain& B)
	{
		B.Reset();
		B.Params.Mate.Hk = ProHockeySense();
		B.Params.Opp.Hk = ProHockeySense();
		for (FJamHockeySense* H : { &B.Params.Mate.Hk, &B.Params.Opp.Hk }) { H->ShapeShare = 1.0; H->LateFrames = 0; }
		SetEvolution3(B.Params.Mate.Hk, false, true);
		SetEvolution3(B.Params.Opp.Hk, false, false);
		SetEvolution4(B.Params.Mate.Hk, false, true);
		SetEvolution4(B.Params.Opp.Hk, false, false);
		for (FJamHockeySense* H : { &B.Params.Mate.Hk, &B.Params.Opp.Hk }) { SetEvolution5(*H, false); SetEvolution6(*H, false); }
	}

	// The bar's counter: one match's frames through the playtest trace callback (every frame).
	struct FHumanCount
	{
		int Knockdowns = 0, AsWon30 = 0, AsWon15 = 0;
		int64 PlayFrames = 0, LyingFrames = 0;
		bool bWasDown = false;
		int OwnRun = 0, LastOwnRun = 0;
		int64 LastOwnFrame = -1000000;
		void Frame(const FJamAIWorld& W)
		{
			const int Pi = W.PlayerIndex;
			if (Pi < 0 || Pi >= W.NumSkaters) { return; }
			if (W.bFrozen || W.bFaceoffPhase) { bWasDown = W.Skaters[Pi].bDown; OwnRun = 0; return; }
			++PlayFrames;
			const bool bDown = W.Skaters[Pi].bDown;
			if (bDown) { ++LyingFrames; }
			if (bDown && !bWasDown)
			{
				++Knockdowns;
				const int Run = OwnRun > 0 ? OwnRun : ((W.Frame - LastOwnFrame) <= 3 ? LastOwnRun : -1);
				if (Run >= 0 && Run < 30) { ++AsWon30; }
				if (Run >= 0 && Run < 15) { ++AsWon15; }
			}
			bWasDown = bDown;
			if (W.CarrierOrHolder() == Pi && !bDown) { ++OwnRun; LastOwnRun = OwnRun; LastOwnFrame = W.Frame; }
			else { OwnRun = 0; }
		}
	};
	void HumanTrace(void* Ctx, const FJamAIWorld& W, const FJamAIInput*, const FJamBrain&, int64_t, bool)
	{
		static_cast<FHumanCount*>(Ctx)->Frame(W);
	}
}

// The presser leaves the man who has only just won the puck: no body check on a carry younger than FreshTakeFrames.
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamHockey6FreshTake, "Jam.Bot.Hockey6.FreshTake", JamHockeyBrain6TestsLocal::Flags)
bool FJamHockey6FreshTake::RunTest(const FString& Parameters)
{
	using namespace JamHockeyBrain6TestsLocal;
	// The human has the puck from the first frame; the opposing chaser meets him head-on at 8 m/s of closing, in check range. The first frame it presses check.
	auto Play = [](int FreshTakeFrames) -> int
	{
		FJamAIWorld W = Three();
		W.Skaters[3].Pos = FVec2(1.25, 0.0);
		W.Skaters[3].Vel = FVec2(-5.0, 0.0);
		W.Skaters[3].Facing = FVec2(-1.0, 0.0);
		FJamBrain B;
		Start(B);
		B.Params.Opp.Hk.FreshTakeFrames = FreshTakeFrames;
		for (int f = 0; f < 40; ++f)
		{
			W.Frame = 1000 + f;
			Carry(W, 0, FVec2(0.0, 0.0), FVec2(3.0, 0.0), FVec2(1.0, 0.0));
			FJamAIInput In[kMaxSkaters];
			B.Think(W, In);
			if (In[3].bCheck) { return f; }
		}
		return -1;
	};
	const int Before = Play(0), After = Play(15), Long = Play(30);
	AddInfo(FString::Printf(TEXT("a bot that meets a carrier head-on from his first frame with the puck: the frame of its check press: as shipped %d; with 15 frames %d; with 30 frames %d"), Before, After, Long));
	TestEqual(TEXT("before: it checks him the frame he has the puck"), Before, 0);
	TestEqual(TEXT("after: the check waits until his carry is 15 frames old"), After, 14);
	TestEqual(TEXT("... or 30"), Long, 29);
	return true;
}

// All_star's second man: only the first presser of a carry closes under control; a presser that takes over while the same skater carries hunts.
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamHockey6SecondMan, "Jam.Bot.Hockey6.SecondMan", JamHockeyBrain6TestsLocal::Flags)
bool FJamHockey6SecondMan::RunTest(const FString& Parameters)
{
	using namespace JamHockeyBrain6TestsLocal;
	// Team 0's skater 0 carries towards the net at +41. Team 1's skater 5 is the first presser (10 m goal-side); skater 6 waits 10 m behind it.
	// After 100 frames the carrier is past skater 5 and skater 6 is the presser. OutFirst: the first presser's move at frame 99.
	auto Play = [](bool bSecondManHunts, FVec2& OutFirst, FJamBrain::EJob& OutJob) -> FVec2
	{
		FJamAIWorld W = Five();
		W.Skaters[5].Pos = FVec2(10.0, 0.0);
		W.Skaters[6].Pos = FVec2(20.0, 1.0);
		FJamBrain B;
		Start(B);
		B.Params.Opp.HuntRadiusM = 30.0;
		B.Params.Opp.Hk.bPressInHunt = true;
		B.Params.Opp.Hk.bSecondManHunts = bSecondManHunts;
		FJamAIInput In[kMaxSkaters];
		for (int f = 0; f < 100; ++f)
		{
			W.Frame = 1000 + f;
			Carry(W, 0, FVec2(0.0, -2.5 + 0.05 * f), FVec2(6.0, 0.0), FVec2(1.0, 0.0));   // it drifts across (a puck that does not move is a stall)
			B.Think(W, In);
		}
		OutFirst = In[5].Move;
		W.Frame = 1100;
		Carry(W, 0, FVec2(16.0, 2.5), FVec2(6.0, 0.0), FVec2(1.0, 0.0));   // 6 m past the first presser, 4 m short of the second
		B.Think(W, In);
		OutJob = B.LastJob(6);
		return In[6].Move;
	};
	FVec2 First0, First1;
	FJamBrain::EJob Job0, Job1;
	const FVec2 Off = Play(false, First0, Job0), On = Play(true, First1, Job1);
	AddInfo(FString::Printf(TEXT("the first presser, 10 m goal-side of a carrier at 6 m/s: move length %.2f and %.2f; the second presser, once the carrier is past the first: (%.2f, %.2f) length %.2f as shipped, (%.2f, %.2f) length %.2f with the second man hunting"),
		First0.Length(), First1.Length(), Off.X, Off.Y, Off.Length(), On.X, On.Y, On.Length()));
	TestTrue(TEXT("the second skater is the presser in both arms"), Job0 == FJamBrain::EJob::Press && Job1 == FJamBrain::EJob::Press);
	TestTrue(TEXT("the first presser closes under control in both arms"), First0.Length() < 0.6 && FMath::IsNearlyEqual(First0.X, First1.X, 1e-9) && FMath::IsNearlyEqual(First0.Y, First1.Y, 1e-9));
	TestTrue(TEXT("before: the second presser closes under control too"), Off.Length() < 0.6);
	TestTrue(TEXT("after: the second presser charges"), On.Length() > 0.9);
	return true;
}

// The cover reads the pass the carrier would make: the Cover job stands on the lane to the sim's own pick, not to the nearest team-mate.
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamHockey6CoverBestPass, "Jam.Bot.Hockey6.CoverBestPass", JamHockeyBrain6TestsLocal::Flags)
bool FJamHockey6CoverBestPass::RunTest(const FString& Parameters)
{
	using namespace JamHockeyBrain6TestsLocal;
	// Team 0's skater 0 carries at centre ice; its nearest team-mate (1) is 5 m behind and beside it, the one its pass would go to (2) is 12 m up the ice.
	// OutTo: the cover's way towards the lane to skater 2 (the pass); the return: towards the lane to skater 1 (the nearest).
	auto Play = [](bool bCoverBestPass, double& OutToPass, int& OutCover) -> double
	{
		FJamAIWorld W = Five();
		W.Skaters[1].Pos = FVec2(-3.0, 4.0);
		W.Skaters[2].Pos = FVec2(9.0, -8.0);
		W.Skaters[5].Pos = FVec2(8.0, 1.0);    // the presser
		W.Skaters[6].Pos = FVec2(6.0, 9.0);    // the cover
		FJamBrain B;
		Start(B);
		B.Params.Opp.Hk.bCoverBestPass = bCoverBestPass;
		FJamAIInput In[kMaxSkaters];
		for (int f = 0; f < 100; ++f)   // past the transition's 90 frames
		{
			W.Frame = 1000 + f;
			Carry(W, 0, FVec2(0.0, -1.0 + 0.04 * f), FVec2(4.0, 0.0), FVec2(1.0, 0.0));
			W.CarrierBestPass = W.HolderBestPass = 2;
			B.Think(W, In);
		}
		OutCover = -1;
		for (int i = 5; i < 10; ++i) { if (B.LastJob(i) == FJamBrain::EJob::Cover) { OutCover = i; } }
		if (OutCover < 0) { OutToPass = 0.0; return 0.0; }
		const FVec2 Cp = W.Skaters[0].Pos, Me = W.Skaters[OutCover].Pos;
		const FVec2 OnPass = Cp + (W.Skaters[2].Pos - Cp) * 0.7, OnNearest = Cp + (W.Skaters[1].Pos - Cp) * 0.7;
		OutToPass = In[OutCover].Move.Normalized().Dot((OnPass - Me).Normalized());
		return In[OutCover].Move.Normalized().Dot((OnNearest - Me).Normalized());
	};
	double Pass0 = 0.0, Pass1 = 0.0;
	int Cover0 = -1, Cover1 = -1;
	const double Near0 = Play(false, Pass0, Cover0), Near1 = Play(true, Pass1, Cover1);
	AddInfo(FString::Printf(TEXT("the cover (skater %d / %d): its way towards the lane to the carrier's nearest team-mate %.2f, to the one its pass would go to %.2f; with the switch %.2f and %.2f"), Cover0, Cover1, Near0, Pass0, Near1, Pass1));
	TestTrue(TEXT("a skater has the Cover job in both arms"), Cover0 >= 0 && Cover1 >= 0);
	TestTrue(TEXT("before: the cover heads for the lane of the nearest team-mate, away from the lane of the pass"), Near0 > 0.5 && Pass0 < 0.0);   // not straight at it: a shape job keeps its room from the puck
	TestTrue(TEXT("after: the cover goes to the lane of the pass"), Pass1 > 0.9 && Pass1 > Pass0 + 0.2);
	return true;
}

// The neutral values: as shipped every rule of evolution 6 is off at every level; brain6=0 and the older switches put them there; one match twice.
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamHockey6Neutral, "Jam.Bot.Hockey6.Neutral", JamHockeyBrain6TestsLocal::Flags)
bool FJamHockey6Neutral::RunTest(const FString& Parameters)
{
	using namespace JamHockeyBrain6TestsLocal;
	for (EDifficulty Lv : { EDifficulty::Rookie, EDifficulty::Pro, EDifficulty::AllStar })
	{
		FJamAIParams A;
		ApplyDifficultyProfile(GetDifficultyProfile(Lv), A);
		AddInfo(FString::Printf(TEXT("%hs as shipped: no check on a carry younger than %d frames (opposing side), %d (mates); the second man hunts: %d"),
			DifficultyName(Lv), A.Opp.Hk.FreshTakeFrames, A.Mate.Hk.FreshTakeFrames, A.Opp.Hk.bSecondManHunts ? 1 : 0));
		if (kEvo6FreshTakeFrames == 0)
		{
			TestTrue(TEXT("as shipped every rule of evolution 6 is at its neutral value"), A.Opp.Hk.FreshTakeFrames == 0 && A.Mate.Hk.FreshTakeFrames == 0 && !A.Opp.Hk.bSecondManHunts && !A.Mate.Hk.bSecondManHunts && !A.Opp.Hk.bCoverBestPass);
		}
		for (const char* Tune : { "brain6=0", "brain5=0", "brain4=0", "brain3=0", "brain2=0" })
		{
			FJamAIParams P = A;
			P.Opp.Hk.FreshTakeFrames = P.Mate.Hk.FreshTakeFrames = 15;
			P.Opp.Hk.bSecondManHunts = true;
			P.Opp.Hk.bCoverBestPass = true;
			P.Opp.Hk.StepUpMaxTeam = 99;
			char Err[200] = {};
			TestTrue(*FString::Printf(TEXT("the tune %hs applies"), Tune), ApplyDifficultyTune(Tune, P, Err, sizeof(Err)));
			TestTrue(*FString::Printf(TEXT("%hs: every rule of evolution 6 is at its neutral value"), Tune), P.Opp.Hk.FreshTakeFrames == 0 && P.Mate.Hk.FreshTakeFrames == 0 && !P.Opp.Hk.bSecondManHunts && !P.Opp.Hk.bCoverBestPass && P.Opp.Hk.StepUpMaxTeam == 5);
		}
	}
	auto Match = [this](const char* Tune) -> FString
	{
		TArray<FString> Errors;
		UJamCartridge* Cart = UJamCartridge::LoadFromFile(UJamCartridge::ResolveCartridgePath(TEXT("hockey.regular")), Errors);
		if (!Cart) { AddError(TEXT("FAIL hockey.regular does not load")); return FString(); }
		FJamMatchConfig C = ToMatchConfigResolved(*Cart, TEXT("pro"));
		if (Tune) { char Err[200] = {}; TestTrue(TEXT("the tune applies"), ApplyDifficultyTune(Tune, C.AI, Err, sizeof(Err))); }
		FJamSimAdapter Sim(*Cart);
		const FJamPlaytestStats St = RunPlaytestMatch(Sim, C, 1, EPlaytester::Regular, 36000, Cart->Game.Shot.ChargeFramesMax, false, nullptr, nullptr, 0);
		Cart->RemoveFromRoot();
		return FString::Printf(TEXT("%016llx (%lld frames, %d:%d)"), static_cast<unsigned long long>(St.Hash), static_cast<long long>(St.Frames), St.GoalsFor, St.GoalsAgainst);
	};
	const FString A1 = Match("brain8=0"), A2 = Match("brain8=0"), Off = Match("brain6=0;brain7=1;brain8=0"),   // lane A202: evolution 8 ships on: the pair is read with it off
		 On = Match("opp.hk_fresh_take_frames=15");
	AddInfo(FString::Printf(TEXT("hockey.regular at pro, the regular player, seed 1: as shipped %s; with brain6=0 %s; with opp.hk_fresh_take_frames=15 %s"), *A1, *Off, *On));
	TestEqual(TEXT("the same match twice is the same match"), A1, A2);
	if (kEvo6FreshTakeFrames == 0)
	{
		TestEqual(TEXT("as shipped is brain6=0 (every rule ships at its neutral value)"), A1, Off);   // lane A193: brainN=0 also switches evolution 7 off; brain7=1 puts it back as shipped, so the pair compares only evolution N
	}
	return true;
}

// The instrument of item 2 (header of this file). Outside the gate.
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamHockey6HumanBar, "Bar.Bot.Hockey6.Human", JamHockeyBrain6TestsLocal::Flags)
bool FJamHockey6HumanBar::RunTest(const FString& Parameters)
{
	using namespace JamHockeyBrain6TestsLocal;
	const FString TunesEnv = FPlatformMisc::GetEnvironmentVariable(TEXT("JAM_A181_TUNES"));
	const FString LevelsEnv = FPlatformMisc::GetEnvironmentVariable(TEXT("JAM_A181_LEVELS"));
	const FString MatchesEnv = FPlatformMisc::GetEnvironmentVariable(TEXT("JAM_A181_MATCHES"));
	TArray<FString> Arms, Levels;
	(TunesEnv.IsEmpty() ? FString(TEXT("as shipped:")) : TunesEnv).ParseIntoArray(Arms, TEXT("|"), true);
	(LevelsEnv.IsEmpty() ? FString(TEXT("pro")) : LevelsEnv).ParseIntoArray(Levels, TEXT(","), true);
	const int32 Matches = MatchesEnv.IsEmpty() ? 200 : FMath::Clamp(FCString::Atoi(*MatchesEnv), 1, 2000);
	TArray<FString> Errors;
	UJamCartridge* Cart = UJamCartridge::LoadFromFile(UJamCartridge::ResolveCartridgePath(TEXT("hockey.regular")), Errors);
	if (!Cart) { AddError(TEXT("FAIL hockey.regular does not load")); return false; }
	for (const FString& Level : Levels)
	{
		const EPlaytester Kind = Level == TEXT("rookie") ? EPlaytester::Novice : (Level == TEXT("all_star") ? EPlaytester::Good : EPlaytester::Regular);
		for (const FString& Arm : Arms)
		{
			FString Name = Arm, Tune;
			Arm.Split(TEXT(":"), &Name, &Tune);
			FJamMatchConfig C = ToMatchConfigResolved(*Cart, *Level);
			if (!Tune.IsEmpty())
			{
				char Err[200] = {};
				if (!ApplyDifficultyTune(TCHAR_TO_ANSI(*Tune), C.AI, Err, sizeof(Err))) { AddError(FString::Printf(TEXT("FAIL tune %s: %hs"), *Tune, Err)); continue; }
			}
			FHumanCount N;
			int32 Wins = 0, Gf = 0, Ga = 0, KdLine = 0;
			for (int32 m = 0; m < Matches; ++m)
			{
				const uint64 Seed = static_cast<uint64>((m / 100) * 150 + (m % 100) + 1);   // the curve's regular cell: 1-100 of each band of 150
				FJamSimAdapter Sim(*Cart);
				N.bWasDown = false; N.OwnRun = 0; N.LastOwnFrame = -1000000;
				const FJamPlaytestStats St = RunPlaytestMatch(Sim, C, Seed, Kind, 36000, Cart->Game.Shot.ChargeFramesMax, false, &HumanTrace, &N, 1);
				Wins += St.Winner == St.PlayerTeam ? 1 : 0;
				Gf += St.GoalsFor; Ga += St.GoalsAgainst; KdLine += St.Knockdowns;
			}
			AddInfo(FString::Printf(TEXT("HUMAN %s | %s | %d matches | knocked down %.2f a match (the playtest line: %.2f), as he won it (puck his under 30 frames) %.2f, under 15 frames %.2f | lying %.2f %% of play | win %.1f %%, goals %.2f : %.2f"),
				*Level, *Name, Matches, static_cast<double>(N.Knockdowns) / Matches, static_cast<double>(KdLine) / Matches, static_cast<double>(N.AsWon30) / Matches, static_cast<double>(N.AsWon15) / Matches,
				N.PlayFrames > 0 ? 100.0 * N.LyingFrames / N.PlayFrames : 0.0, 100.0 * Wins / Matches, static_cast<double>(Gf) / Matches, static_cast<double>(Ga) / Matches));
		}
	}
	Cart->RemoveFromRoot();
	return true;
}

#endif
