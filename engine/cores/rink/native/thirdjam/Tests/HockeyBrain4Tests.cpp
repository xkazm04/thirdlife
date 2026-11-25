// Lane A153 (track Q2, evolution 4; docs/experiments/BRAIN-4.md): one stop distance at every level (R-0058 point 1), a mate that finishes, the carry clock.
//   UnrealEditor-Cmd ThirdJam.uproject -ExecCmds="Automation RunTests Jam.Bot.Hockey4; Quit" -nullrhi -Multiprocess -unattended -nopause -stdout
// As Jam.Bot.Hockey2 / Hockey3: both arms in one process on a pure world; the rule's field at its neutral value must miss the bar, the rule on must meet it.
// No hash of a shipped cut's default match is pinned here (the ladder moves them): a neutral is proven inside the run or on a staged scene.
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

namespace JamHockeyBrain4TestsLocal
{
	constexpr EAutomationTestFlags Flags = EAutomationTestFlags::EditorContext | EAutomationTestFlags::CommandletContext | EAutomationTestFlags::EngineFilter;
	using namespace JamAI;

	// 5 v 5 on 90 x 45, no human: team 0 (defends -x) skaters 0-4 (chaser, support, support, back, back), team 1 skaters 5-9: the opposing side
	// (FJamAIParams::Opp) when no human is seated. Everyone parked far from the scene.
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
	// 3 v 3 on 120 x 60: team 0 (defends -x): 0 the human, 1 chaser, 2 back; team 1: 3 chaser, 4 support, 5 back. Everyone parked.
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
			S.Pos = FVec2(S.Team == 0 ? -30.0 : -10.0, -24.0 + 8.0 * i);
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
	// The pro sense on both sides, executed fully and at once, every rule of evolutions 3 and 4 at its neutral value; a test switches one on.
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
	}
}

// R-0058 point 1: all_star's presser stays on its job inside the hunt. The profile carries the switch at all_star only; the presser inside the hunt radius
// closes under control (the Press job's gap) instead of charging.
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamHockey4PressInHunt, "Jam.Bot.Hockey4.PressInHunt", JamHockeyBrain4TestsLocal::Flags)
bool FJamHockey4PressInHunt::RunTest(const FString& Parameters)
{
	using namespace JamHockeyBrain4TestsLocal;
	// The profiles
	{
		FJamAIParams Rk, Pro, Star;
		ApplyDifficultyProfile(GetDifficultyProfile(EDifficulty::Rookie), Rk);
		ApplyDifficultyProfile(GetDifficultyProfile(EDifficulty::Pro), Pro);
		ApplyDifficultyProfile(GetDifficultyProfile(EDifficulty::AllStar), Star);
		TestTrue(TEXT("all_star's presser stays on its job inside the hunt"), Star.Opp.Hk.bPressInHunt);
		// lane A221 (LADDER SET 4, CURVE-14.md): R-0063's dial: pro's presser keeps its job inside the hunt and commits at its old hunt radius, 8 m (law 3's drill
		// 94.0 % at 8 m, straight charge 0, as with it off). Before: TestFalse "pro's does not (it breaks pro's drill: BRAIN-3.md section 6)", which was so without the commit.
		TestTrue(TEXT("pro's presser stays on its job inside the hunt and commits at 8 m (R-0063's dial, LADDER SET 4)"), Pro.Opp.Hk.bPressInHunt && Pro.Opp.Hk.PressCommitM == 8.0);
		TestFalse(TEXT("rookie's does not"), Rk.Opp.Hk.bPressInHunt);
		TestFalse(TEXT("the human's mates never carry the switch"), Star.Mate.Hk.bPressInHunt || Pro.Mate.Hk.bPressInHunt);
		for (const char* Tune : { "opp.hk_press_in_hunt=0", "brain4=0", "brain3=0", "brain2=0" })
		{
			FJamAIParams P = Star;
			char Err[200] = {};
			TestTrue(*FString::Printf(TEXT("the tune %s applies"), ANSI_TO_TCHAR(Tune)), ApplyDifficultyTune(Tune, P, Err, sizeof(Err)));
			TestFalse(*FString::Printf(TEXT("%s gives all_star's presser back to the hunt"), ANSI_TO_TCHAR(Tune)), P.Opp.Hk.bPressInHunt);
			if (FCStringAnsi::Strcmp(Tune, "brain4=0") == 0 || FCStringAnsi::Strcmp(Tune, "opp.hk_press_in_hunt=0") == 0)
			{
				TestTrue(*FString::Printf(TEXT("%s leaves evolution 3 on"), ANSI_TO_TCHAR(Tune)), P.Mate.Hk.StepUpM == Star.Mate.Hk.StepUpM && P.Mate.Hk.MateCheckClosing == Star.Mate.Hk.MateCheckClosing && P.Opp.Hk.bReadShield);
			}
		}
		char Err[200] = {};
		FJamAIParams P = Star;
		TestTrue(TEXT("the shared baseline's all_star tune applies"), ApplyDifficultyTune(JamBaseline::BrainTune("all_star"), P, Err, sizeof(Err)));
		TestFalse(TEXT("the shared baseline switches it off"), P.Opp.Hk.bPressInHunt);
	}
	// The presser: team 1's chaser, goal-side of a team 0 carrier that comes at 6 m/s, 10 m off, inside a hunt radius of 30 m.
	auto Play = [](bool bPressInHunt, double HuntM, FJamBrain::EJob& OutJob) -> FVec2
	{
		FJamAIWorld W = Five();
		Carry(W, 0, FVec2(0.0, 0.0), FVec2(6.0, 0.0), FVec2(1.0, 0.0));
		W.Skaters[5].Pos = FVec2(10.0, 0.0);
		FJamBrain B;
		Start(B);
		B.Params.Opp.HuntRadiusM = HuntM;
		B.Params.Opp.Hk.bPressInHunt = bPressInHunt;
		FJamAIInput In[kMaxSkaters];
		B.Think(W, In);
		OutJob = B.LastJob(5);
		return In[5].Move;
	};
	FJamBrain::EJob JobHunt, JobPress, JobNoHunt;
	const FVec2 Hunt = Play(false, 30.0, JobHunt), Press = Play(true, 30.0, JobPress), NoHunt = Play(false, 0.0, JobNoHunt);
	AddInfo(FString::Printf(TEXT("the presser 10 m goal-side of a carrier at 6 m/s: inside the hunt, off its job: move (%.2f, %.2f), length %.2f; kept on its job: (%.2f, %.2f), length %.2f; with no hunt at all: (%.2f, %.2f)"),
		Hunt.X, Hunt.Y, Hunt.Length(), Press.X, Press.Y, Press.Length(), NoHunt.X, NoHunt.Y));
	TestTrue(TEXT("the skater is the presser in every arm"), JobHunt == FJamBrain::EJob::Press && JobPress == FJamBrain::EJob::Press && JobNoHunt == FJamBrain::EJob::Press);
	TestTrue(TEXT("before: inside the hunt the presser charges the carrier at full stick"), Hunt.X < -0.9);
	TestTrue(TEXT("after: it closes under control (the Press job's gap: under half stick towards the carrier)"), Press.Length() < 0.6);
	TestTrue(TEXT("kept on its job it plays exactly what a presser with no hunt plays"), FMath::IsNearlyEqual(Press.X, NoHunt.X, 1e-9) && FMath::IsNearlyEqual(Press.Y, NoHunt.Y, 1e-9));
	return true;
}

// REVIEW-2 item 10: a mate inside 15 m with an open lane shoots.
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamHockey4MateFinish, "Jam.Bot.Hockey4.MateFinish", JamHockeyBrain4TestsLocal::Flags)
bool FJamHockey4MateFinish::RunTest(const FString& Parameters)
{
	using namespace JamHockeyBrain4TestsLocal;
	// The mate (skater 1) carries towards the net at +56, its facing OffDeg off the line to the net; BlockAt > 0 puts an opponent on that line.
	auto Play = [](double MateFinishM, double DistM, double OffDeg, double BlockAt) -> bool
	{
		FJamAIWorld W = Three();
		const FVec2 Goal = W.OppGoal(0);
		const FVec2 Pos(Goal.X - DistM - 1.2, 0.0);
		Carry(W, 1, Pos, FVec2(3.0, 0.0), AIMath::Rotate(FVec2(1.0, 0.0), AIMath::DegToRad(OffDeg)));
		W.PuckPos = Pos + FVec2(1.2, 0.0);   // the puck ahead on the net's axis; the body turned OffDeg off it
		if (BlockAt > 0.0) { W.Skaters[3].Pos = W.PuckPos + FVec2(BlockAt, 0.3); }
		W.Skaters[5].Pos = Goal - FVec2(1.5, 0.0);   // the last man in his crease
		FJamBrain B;
		Start(B);
		B.Params.AimConeDeg = 15.0;
		B.Params.Mate.Hk.bCarryOrPass = false;   // the shot's rule alone
		B.Params.Mate.Hk.MateFinishM = MateFinishM;
		FJamAIInput In[kMaxSkaters];
		B.Think(W, In);
		return In[1].bShoot || In[1].bShootHeld;
	};
	const bool bBefore = Play(0.0, 10.0, 10.0, 0.0), bAfter = Play(15.0, 10.0, 10.0, 0.0), bBlocked = Play(15.0, 10.0, 10.0, 4.0);
	const bool bFar0 = Play(0.0, 22.0, 10.0, 0.0), bFar1 = Play(15.0, 22.0, 10.0, 0.0), bWide = Play(15.0, 10.0, 30.0, 0.0), bLined0 = Play(0.0, 10.0, 0.0, 0.0), bLined1 = Play(15.0, 10.0, 0.0, 0.0);
	AddInfo(FString::Printf(TEXT("a mate 10 m out, 10 degrees off the net, the lane open but for the last man: shoots before %d, after %d; an opponent on the lane %d; 22 m out %d and %d; 30 degrees off %d; lined up %d and %d"),
		bBefore ? 1 : 0, bAfter ? 1 : 0, bBlocked ? 1 : 0, bFar0 ? 1 : 0, bFar1 ? 1 : 0, bWide ? 1 : 0, bLined0 ? 1 : 0, bLined1 ? 1 : 0));
	TestFalse(TEXT("before: the mate carries on (it shoots only lined up to atan(1.4 / distance): 8 degrees at 10 m)"), bBefore);
	TestTrue(TEXT("after: the mate finishes (inside the sim's aim cone the shot is on the net)"), bAfter);
	TestFalse(TEXT("an opponent on the lane: no shot"), bBlocked);
	TestTrue(TEXT("outside the distance nothing changes"), bFar0 == bFar1);
	TestFalse(TEXT("outside the aim cone it still lines up first"), bWide);
	TestTrue(TEXT("lined up it shoots in both arms"), bLined0 && bLined1);
	return true;
}

// A mate with an open lane takes the puck to the net: inside MateDriveM it does not hand it to an open human on the way.
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamHockey4MateDrive, "Jam.Bot.Hockey4.MateDrive", JamHockeyBrain4TestsLocal::Flags)
bool FJamHockey4MateDrive::RunTest(const FString& Parameters)
{
	using namespace JamHockeyBrain4TestsLocal;
	// The mate carries 22 m out on the net's axis; the human is open, 10 m nearer the net and 9 m to the side; the sim's pass would go to him.
	auto Play = [](double DriveM, bool bSetUp) -> int
	{
		FJamAIWorld W = Three();
		const FVec2 Goal = W.OppGoal(0);
		W.Skaters[0].Pos = FVec2(Goal.X - 12.0, 9.0);
		W.Skaters[0].Facing = bSetUp ? (Goal - W.Skaters[0].Pos).Normalized() : FVec2(0.0, -1.0);
		W.Skaters[5].Pos = Goal - FVec2(1.5, 0.0);
		FJamBrain B;
		Start(B);
		B.Params.Mate.PassToHuman = 0.4;
		B.Params.Mate.Hk.MateDriveM = DriveM;
		int Passes = 0;
		for (int f = 0; f < 30; ++f)
		{
			W.Frame = 1000 + f;
			Carry(W, 1, FVec2(Goal.X - 23.2 + 0.1 * f, 0.0), FVec2(6.0, 0.0), FVec2(1.0, 0.0));
			W.CarrierBestPass = W.HolderBestPass = 0;
			FJamAIInput In[kMaxSkaters];
			B.Think(W, In);
			Passes += (In[1].bPass || In[1].bPassHeld) ? 1 : 0;
		}
		return Passes;
	};
	const int Before = Play(0.0, false), After = Play(25.0, false), SetUp = Play(25.0, true);
	AddInfo(FString::Printf(TEXT("a mate 22 m out with an open lane, the human open and better placed: pass frames in half a second before %d, with the drive at 25 m %d; the human set up for the one-timer %d"), Before, After, SetUp));
	TestTrue(TEXT("before: the mate hands the puck to the open human"), Before > 0);
	TestEqual(TEXT("after: it takes the puck to the net"), After, 0);
	TestTrue(TEXT("a human set up for the one-timer still gets the puck"), SetUp > 0);
	return true;
}

// The screen: in the first frames of the human's carry the mate nearest his nearest opponent stands in its way.
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamHockey4Screen, "Jam.Bot.Hockey4.Screen", JamHockeyBrain4TestsLocal::Flags)
bool FJamHockey4Screen::RunTest(const FString& Parameters)
{
	using namespace JamHockeyBrain4TestsLocal;
	// The human has just taken the puck at centre ice; an opponent stands 5 m from him up the ice; the mate is 4 m to the side of that opponent.
	// Five a side (another forward is there to offer the lane); bThree: three a side, where the only forward keeps offering it.
	auto Play = [](int ScreenFrames, int Thinks, bool bThree = false) -> double
	{
		FJamAIWorld W = bThree ? Three() : Five();
		const int Opp = bThree ? 3 : 5;
		W.PlayerIndex = 0;
		W.Skaters[0].Role = ERole::Player;
		Carry(W, 0, FVec2(0.0, 0.0), FVec2(3.0, 0.0), FVec2(1.0, 0.0));
		W.Skaters[Opp].Pos = FVec2(5.0, 0.0);
		W.Skaters[1].Pos = FVec2(5.0, 4.0);
		FJamBrain B;
		Start(B);
		B.Params.Mate.Hk.ScreenFrames = ScreenFrames;
		FJamAIInput In[kMaxSkaters];
		for (int f = 0; f < Thinks; ++f) { W.Frame = 1000 + f; B.Think(W, In); }
		const FVec2 Spot = W.Skaters[Opp].Pos + (W.Skaters[0].Pos - W.Skaters[Opp].Pos).Normalized() * 1.2;
		return In[1].Move.Normalized().Dot((Spot - W.Skaters[1].Pos).Normalized());
	};
	const double Before = Play(0, 1), After = Play(60, 1), Late0 = Play(0, 70), Late1 = Play(60, 70);
	AddInfo(FString::Printf(TEXT("the human's first frame with the puck: the mate's way towards the spot between him and his nearest opponent before %.2f, after %.2f; 70 frames into his carry %.2f and %.2f"), Before, After, Late0, Late1));
	TestTrue(TEXT("before: the mate goes to offer a lane"), Before < 0.7);
	TestTrue(TEXT("after: it steps between the opponent and the human"), After > 0.9);
	TestTrue(TEXT("once the frames are up it offers a lane as before"), FMath::IsNearlyEqual(Late0, Late1, 1e-6));
	const double Three0 = Play(0, 1, true), Three1 = Play(60, 1, true);
	AddInfo(FString::Printf(TEXT("three a side, the same scene: %.2f and %.2f (the only forward offers the lane)"), Three0, Three1));
	TestTrue(TEXT("three a side: no screen, the only forward offers the lane"), FMath::IsNearlyEqual(Three0, Three1, 1e-9));
	return true;
}

// The carry clock of three a side: after its seconds with the puck the carrier moves it or shoots it at the net.
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamHockey4CarryClock, "Jam.Bot.Hockey4.CarryClock", JamHockeyBrain4TestsLocal::Flags)
bool FJamHockey4CarryClock::RunTest(const FString& Parameters)
{
	using namespace JamHockeyBrain4TestsLocal;
	// The opposing chaser (skater 3) holds the puck at centre ice, facing the net it attacks (-56), 56 m out, drifting across at 3 m/s (a puck that does
	// not move is a stall, which has its own rule): no shot is on. OutFirst: the first frame it releases.
	auto Play = [](double ClockS, int Frames, int BestPass, int& OutFirst) -> int
	{
		FJamAIWorld W = Three();
		W.Skaters[0].Pos = FVec2(40.0, -20.0);   // the human and his mate far from the play
		W.Skaters[1].Pos = FVec2(40.0, 20.0);
		W.Skaters[2].Pos = FVec2(-52.0, 0.0);
		W.Skaters[4].Pos = FVec2(30.0, 10.0);
		W.Skaters[5].Pos = FVec2(52.0, 0.0);
		FJamBrain B;
		Start(B);
		B.Params.Opp.Hk.CarryClockS = ClockS;
		int Releases = 0;
		OutFirst = -1;
		for (int f = 0; f < Frames; ++f)
		{
			W.Frame = 1000 + f;
			Carry(W, 3, FVec2(0.0, -5.0 + 0.05 * f), FVec2(0.0, 3.0), FVec2(-1.0, 0.0));
			W.CarrierBestPass = W.HolderBestPass = BestPass;
			FJamAIInput In[kMaxSkaters];
			B.Think(W, In);
			if (In[3].bShoot || In[3].bPass) { ++Releases; if (OutFirst < 0) { OutFirst = f; } }
		}
		return Releases;
	};
	int F0 = -1, F1 = -1, F2 = -1;
	const int Before = Play(0.0, 200, -1, F0), After = Play(2.0, 200, -1, F1), AfterPass = Play(2.0, 200, 4, F2);
	AddInfo(FString::Printf(TEXT("a carrier that holds the puck at centre ice for 200 frames: releases before %d; with a 2 s clock %d (first at frame %d); with a receiver for the sim's pass %d (first at frame %d)"),
		Before, After, F1, AfterPass, F2));
	TestEqual(TEXT("before: it keeps the puck"), Before, 0);
	TestTrue(TEXT("after: it shoots the puck at the net once two seconds are up, and not before"), After > 0 && F1 >= 119 && F1 <= 123);
	TestTrue(TEXT("with a receiver it moves the puck once two seconds are up"), AfterPass > 0 && F2 >= 119 && F2 <= 123);
	return true;
}

// The neutral values, inside one run: the same all_star match twice is the same match (no pinned hash of a shipped cut), and the profile's values are logged.
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamHockey4Neutral, "Jam.Bot.Hockey4.Neutral", JamHockeyBrain4TestsLocal::Flags)
bool FJamHockey4Neutral::RunTest(const FString& Parameters)
{
	using namespace JamHockeyBrain4TestsLocal;
	{
		FJamAIParams A, B;
		ApplyDifficultyProfile(GetDifficultyProfile(EDifficulty::Pro), A);
		B = A;
		char Err[200] = {};
		TestTrue(TEXT("brain4=0 applies"), ApplyDifficultyTune("brain4=0", B, Err, sizeof(Err)));
		for (const FJamHockeySense* H : { &B.Mate.Hk, &B.Opp.Hk })
		{
			TestTrue(TEXT("brain4=0: every rule of evolution 4 is at its neutral value"), H->MateFinishM == 0.0 && H->CarryClockS == 0.0 && H->MateDriveM == 0.0 && H->ScreenFrames == 0 && !H->bPressInHunt);
		}
		TestTrue(TEXT("the mates' rule is the mates' and the clock is the opposing side's"), A.Opp.Hk.MateFinishM == 0.0 && A.Mate.Hk.CarryClockS == 0.0);
		AddInfo(FString::Printf(TEXT("as shipped at pro: the mates finish inside %.1f m; the opposing side's carry clock %.1f s (0 = the rule ships at its neutral value)"), A.Mate.Hk.MateFinishM, A.Opp.Hk.CarryClockS));
	}
	auto Match = [this](const char* Tune) -> FString
	{
		TArray<FString> Errors;
		UJamCartridge* Cart = UJamCartridge::LoadFromFile(UJamCartridge::ResolveCartridgePath(TEXT("hockey.regular")), Errors);
		if (!Cart) { AddError(TEXT("FAIL hockey.regular does not load")); return FString(); }
		FJamMatchConfig C = ToMatchConfigResolved(*Cart, TEXT("all_star"));
		if (Tune) { char Err[200] = {}; TestTrue(TEXT("the tune applies"), ApplyDifficultyTune(Tune, C.AI, Err, sizeof(Err))); }
		FJamSimAdapter Sim(*Cart);
		const FJamPlaytestStats St = RunPlaytestMatch(Sim, C, 1, EPlaytester::Good, 36000, Cart->Game.Shot.ChargeFramesMax, false, nullptr, nullptr, 0);
		Cart->RemoveFromRoot();
		return FString::Printf(TEXT("%016llx (%lld frames, %d:%d)"), static_cast<unsigned long long>(St.Hash), static_cast<long long>(St.Frames), St.GoalsFor, St.GoalsAgainst);
	};
	const FString A1 = Match(nullptr), A2 = Match(nullptr), Off1 = Match("opp.hk_press_in_hunt=0"), Off2 = Match("brain4=0;brain7=1;brain8=1;brain9=1;opp.hk_dodge9_share=0.2;opp.hk_drop_no_hit9_frames=45;opp.hk_early_long_shot9_frames=600");   // re-pinned to LADDER SET 3, 15 Nov (the Director's ruling 07:25): all_star's shipped dodge 0.2 (the level profiles' numbers changed, no rule did)   // lane A193: brainN=0 also switches evolution 7 off; brain7=1 puts it back as shipped, so the pair compares only evolution N   // lane A206: and brain9=1 puts evolution 9 back
	AddInfo(FString::Printf(TEXT("hockey.regular at all_star, the good player, seed 1: as shipped %s; with opp.hk_press_in_hunt=0 %s; with brain4=0 %s"), *A1, *Off1, *Off2));
	TestEqual(TEXT("the same match twice is the same match"), A1, A2);
	if (kEvo4MateFinishM == 0.0 && kEvo4CarryClockS == 0.0 && kEvo4MateDriveM == 0.0 && kEvo4ScreenFrames == 0)
	{
		TestEqual(TEXT("brain4=0 and the switch's own key give the same all_star match while the other two rules ship neutral"), Off1, Off2);
	}
	return true;
}

#endif
