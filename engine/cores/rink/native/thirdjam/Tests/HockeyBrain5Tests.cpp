// Lane A167 (track Q2, evolution 5; docs/experiments/BRAIN-5.md): the brain steers round a downed skater; the chaser of three a side closes under control.
//   UnrealEditor-Cmd ThirdJam.uproject -ExecCmds="Automation RunTests Jam.Bot.Hockey5; Quit" -nullrhi -Multiprocess -unattended -nopause -stdout
// Jam.Bot.Hockey5.*: pure worlds, both arms in one process (the rule's field at its neutral value must miss the bar, the rule on must meet it).
// Bar.Bot.Hockey5.Downed (outside the gate's Jam filter): the instrument of item 1. It plays matches in process and counts, on the brain's own world,
// the spells in which a standing skater's root is within 0.9 m of a downed skater's root for more than 6 frames (lane A157's reading of B-to-A-0041
// point 2). Every number it prints is a logged line. Arms and sizes come from the environment:
//   JAM_A167_TUNES   "name:tune|name:tune"   (default: off, and the keep-out at 1.3 m with the way out at 0.7 on both sides)
//   JAM_A167_LEVELS  "pro,rookie,all_star"   (default pro; the class is the ladder's: novice at rookie, regular at pro, good at all_star)
//   JAM_A167_MATCHES 200                     (the first seeds of the curve's regular cell: 1-100, 151-250, 301-400, ...)
//   JAM_A167_CUT     hockey.regular
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

namespace JamHockeyBrain5TestsLocal
{
	constexpr EAutomationTestFlags Flags = EAutomationTestFlags::EditorContext | EAutomationTestFlags::CommandletContext | EAutomationTestFlags::EngineFilter;
	using namespace JamAI;

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
	// The pro sense on both sides, executed fully and at once, every rule of evolutions 3, 4 and 5 at its neutral value; a test switches one on.
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
		SetEvolution5(B.Params.Mate.Hk, false);
		SetEvolution5(B.Params.Opp.Hk, false);
	}

	// The bar's counter: one match's frames come through the playtest trace callback (every frame).
	struct FDownCount
	{
		int Run[kMaxSkaters][kMaxSkaters] = {};   // [standing skater][downed skater]: frames in a row within NearM
		int Spells = 0, SpellsBots = 0, SpellsHuman = 0, Longest = 0, MatchSpells = 0, MatchesWith = 0;
		int64 PairFrames = 0, DownFrames = 0, PlayFrames = 0;
		int LenHist[4] = {};          // spells of 7-10, 11-20, 21-40, 41 and more frames
		int AtKnockdown = 0;          // spells that begin within 3 frames of the knockdown (the two were together when he went down)
		int Start[kMaxSkaters][kMaxSkaters] = {};   // the downed one's frames lying when the run began
		int Lying[kMaxSkaters] = {};
		int64 NearChaser = 0, NearPuck = 0, NearSameTeam = 0, NearMoving = 0;   // of the pair frames: the standing one plays the puck; the puck within 1.5 m of the downed one; team-mates; the downed one slides faster than 1 m/s
		static constexpr double NearM = 0.9;
		static constexpr int OverFrames = 6;
		void Close(int s, int d, bool bHuman)
		{
			if (Run[s][d] > OverFrames)
			{
				++Spells; ++MatchSpells; if (bHuman) { ++SpellsHuman; } else { ++SpellsBots; }
				++LenHist[Run[s][d] <= 10 ? 0 : (Run[s][d] <= 20 ? 1 : (Run[s][d] <= 40 ? 2 : 3))];
				if (Start[s][d] <= 3) { ++AtKnockdown; }
			}
			if (Run[s][d] > Longest) { Longest = Run[s][d]; }
			Run[s][d] = 0;
		}
		void Frame(const FJamAIWorld& W, const FJamBrain& Brain)
		{
			if (W.bFrozen || W.bFaceoffPhase)
			{
				for (int s = 0; s < W.NumSkaters; ++s) for (int d = 0; d < W.NumSkaters; ++d) Close(s, d, s == W.PlayerIndex);
				return;
			}
			++PlayFrames;
			for (int d = 0; d < W.NumSkaters; ++d)
			{
				const FJamAISkater& Dn = W.Skaters[d];
				if (Dn.bDown) { ++DownFrames; ++Lying[d]; } else { Lying[d] = 0; }
				for (int s = 0; s < W.NumSkaters; ++s)
				{
					if (s == d) { continue; }
					const FJamAISkater& St = W.Skaters[s];
					const bool bNear = Dn.bDown && !St.bDown && St.Pos.DistTo(Dn.Pos) < NearM;
					if (!bNear) { Close(s, d, s == W.PlayerIndex); continue; }
					if (Run[s][d] == 0) { Start[s][d] = Lying[d]; }
					++Run[s][d];
					++PairFrames;
					if (Brain.LastRole(s) == ERole::Chaser && s != W.PlayerIndex) { ++NearChaser; }
					if (W.PuckPos.DistTo(Dn.Pos) < 1.5) { ++NearPuck; }
					if (St.Team == Dn.Team) { ++NearSameTeam; }
					if (Dn.Vel.Length() > 1.0) { ++NearMoving; }
				}
			}
		}
		void EndMatch(const FJamAIWorld* W)
		{
			for (int s = 0; s < kMaxSkaters; ++s) for (int d = 0; d < kMaxSkaters; ++d) Close(s, d, W && s == W->PlayerIndex);
			if (MatchSpells > 0) { ++MatchesWith; }
			MatchSpells = 0;
		}
	};
	int GHumanIndex = -1;
	void DownTrace(void* Ctx, const FJamAIWorld& W, const FJamAIInput*, const FJamBrain& Brain, int64_t, bool)
	{
		GHumanIndex = W.PlayerIndex;
		static_cast<FDownCount*>(Ctx)->Frame(W, Brain);
	}
}

// The steering rule on a pure world.
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamHockey5SteerRound, "Jam.Bot.Hockey5.SteerRound", JamHockeyBrain5TestsLocal::Flags)
bool FJamHockey5SteerRound::RunTest(const FString& Parameters)
{
	using namespace JamHockeyBrain5TestsLocal;
	// The pure read: a skater at the origin moving along +x; a downed skater ahead.
	{
		FJamAIWorld W = Three();
		W.Skaters[1].Pos = FVec2(0.0, 0.0);
		W.Skaters[3].bDown = true;
		auto Miss = [&W](const FVec2& DownAt, const FVec2& Move, double KeepM, double& OutLen) -> double
		{
			W.Skaters[3].Pos = DownAt;
			const FVec2 M = SteerRoundDowned(W, 1, Move, KeepM);
			OutLen = M.Length();
			return std::fabs((DownAt - W.Skaters[1].Pos).Cross(M.Normalized()));   // how far the new line passes from him
		};
		double L0 = 0.0, L1 = 0.0, L2 = 0.0, L3 = 0.0;
		const double Ahead = Miss(FVec2(3.0, 0.2), FVec2(1.0, 0.0), 1.3, L0);
		const double Off = Miss(FVec2(3.0, 0.0), FVec2(1.0, 0.0), 0.0, L1);
		const double Clear = Miss(FVec2(3.0, 2.0), FVec2(0.7, 0.0), 1.3, L2);
		const double Behind = Miss(FVec2(-2.0, 0.0), FVec2(1.0, 0.0), 1.3, L3);
		AddInfo(FString::Printf(TEXT("a downed skater 3 m ahead, 0.2 m off the line: the steered line passes %.2f m from him (keep-out 1.3 m; length kept %.2f); rule off %.2f; a line that clears him already: %.2f; behind the move: %.2f"), Ahead, L0, Off, Clear, Behind));
		TestTrue(TEXT("on the way: the move is turned onto the tangent of his circle"), FMath::IsNearlyEqual(Ahead, 1.3, 1e-6) && FMath::IsNearlyEqual(L0, 1.0, 1e-9));
		TestTrue(TEXT("neutral: the move is untouched"), FMath::IsNearlyEqual(Off, 0.0, 1e-12));
		TestTrue(TEXT("a line that clears him is untouched, its length too"), FMath::IsNearlyEqual(Clear, 2.0, 1e-9) && FMath::IsNearlyEqual(L2, 0.7, 1e-9));
		TestTrue(TEXT("a downed skater behind the move is ignored"), FMath::IsNearlyEqual(Behind, 0.0, 1e-9));
		// inside his circle: the move leads out of it
		W.Skaters[3].Pos = FVec2(0.6, 0.1);
		const FVec2 Out = SteerRoundDowned(W, 1, FVec2(1.0, 0.0), 1.3);
		TestTrue(TEXT("inside the circle the move leads away from him"), Out.Dot(W.Skaters[3].Pos - W.Skaters[1].Pos) < 0.0);
		// the side: the move leans left of him, the tangent is the left one
		W.Skaters[3].Pos = FVec2(3.0, -0.5);
		TestTrue(TEXT("the tangent is on the side the move already leans to"), SteerRoundDowned(W, 1, FVec2(1.0, 0.0), 1.3).Y > 0.0);
		W.Skaters[3].Pos = FVec2(3.0, 0.5);
		TestTrue(TEXT("... on either side"), SteerRoundDowned(W, 1, FVec2(1.0, 0.0), 1.3).Y < 0.0);
	}
	// In the brain: the mate chases a loose puck 6 m ahead; an opponent lies on the ice half way, 0.3 m off the line.
	auto Play = [](double KeepM, bool bLies) -> double
	{
		FJamAIWorld W = Three();
		W.PuckPos = FVec2(6.0, 0.0);
		W.PuckLastTouch = 3;
		W.Skaters[0].Pos = FVec2(-30.0, 20.0);
		W.Skaters[1].Pos = FVec2(0.0, 0.0);
		W.Skaters[4].Pos = FVec2(3.0, 0.3);
		W.Skaters[4].bDown = bLies;
		FJamBrain B;
		Start(B);
		B.Params.Mate.Hk.AvoidDownedM = KeepM;
		FJamAIInput In[kMaxSkaters];
		B.Think(W, In);
		return std::fabs((W.Skaters[4].Pos - W.Skaters[1].Pos).Cross(In[1].Move.Normalized()));
	};
	const double Before = Play(0.0, true), After = Play(1.3, true), Standing0 = Play(0.0, false), Standing1 = Play(1.3, false);
	AddInfo(FString::Printf(TEXT("a bot chasing a puck with a downed skater on its way: its line passes %.2f m from him before, %.2f m after; a standing skater there: %.2f and %.2f"), Before, After, Standing0, Standing1));
	TestTrue(TEXT("before: the bot's way goes through the downed skater's body circle"), Before < 0.8);
	TestTrue(TEXT("after: its way passes him at the keep-out distance"), After > 1.25);
	TestTrue(TEXT("a standing skater is not steered round"), FMath::IsNearlyEqual(Standing0, Standing1, 1e-9));
	return true;
}

// The chaser of three a side closes under control: goal-side of a carrier that goes, the Press job's gap instead of the charge.
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamHockey5PressThree, "Jam.Bot.Hockey5.PressThree", JamHockeyBrain5TestsLocal::Flags)
bool FJamHockey5PressThree::RunTest(const FString& Parameters)
{
	using namespace JamHockeyBrain5TestsLocal;
	// The human carries at 6 m/s towards the net at +56; the opposing chaser (skater 3) is 10 m goal-side of him (CarrierMps 2: a carrier that dawdles).
	auto Play = [](bool bPressThree, double CarrierMps) -> FVec2
	{
		FJamAIWorld W = Three();
		Carry(W, 0, FVec2(0.0, 0.0), FVec2(CarrierMps, 0.0), FVec2(1.0, 0.0));
		W.Skaters[3].Pos = FVec2(10.0, 0.0);
		FJamBrain B;
		Start(B);
		B.Params.Opp.Hk.bPressThree = bPressThree;
		FJamAIInput In[kMaxSkaters];
		B.Think(W, In);
		return In[3].Move;
	};
	const FVec2 Before = Play(false, 6.0), After = Play(true, 6.0), Slow0 = Play(false, 2.0), Slow1 = Play(true, 2.0);
	AddInfo(FString::Printf(TEXT("the chaser 10 m goal-side of a carrier at 6 m/s: move (%.2f, %.2f) before, (%.2f, %.2f) after; a carrier at 2 m/s: (%.2f, %.2f) and (%.2f, %.2f)"),
		Before.X, Before.Y, After.X, After.Y, Slow0.X, Slow0.Y, Slow1.X, Slow1.Y));
	TestTrue(TEXT("before: the chaser charges the carrier at full stick"), Before.X < -0.9);
	TestTrue(TEXT("after: it closes under control (under half stick towards him)"), After.Length() < 0.6);
	TestTrue(TEXT("a carrier that dawdles is played as before"), FMath::IsNearlyEqual(Slow0.X, Slow1.X, 1e-9) && FMath::IsNearlyEqual(Slow0.Y, Slow1.Y, 1e-9));
	return true;
}

// The neutral values: as shipped every rule of evolution 5 is off; brain5=0 (and brain4=0) switch them off; the same match twice is the same match.
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamHockey5Neutral, "Jam.Bot.Hockey5.Neutral", JamHockeyBrain5TestsLocal::Flags)
bool FJamHockey5Neutral::RunTest(const FString& Parameters)
{
	using namespace JamHockeyBrain5TestsLocal;
	for (EDifficulty Lv : { EDifficulty::Rookie, EDifficulty::Pro, EDifficulty::AllStar })
	{
		FJamAIParams A;
		ApplyDifficultyProfile(GetDifficultyProfile(Lv), A);
		AddInfo(FString::Printf(TEXT("%hs as shipped: keep-out round a downed skater %.2f m (opposing side), %.2f m (mates); the three's chaser closes under control: %d"),
			DifficultyName(Lv), A.Opp.Hk.AvoidDownedM, A.Mate.Hk.AvoidDownedM, A.Opp.Hk.bPressThree ? 1 : 0));
		for (const char* Tune : { "brain5=0", "brain4=0", "brain3=0", "brain2=0" })
		{
			FJamAIParams P = A;
			P.Opp.Hk.AvoidDownedM = P.Mate.Hk.AvoidDownedM = 1.3;
			P.Opp.Hk.bPressThree = true;
			P.Opp.Hk.PressCommitM = 8.0;
			P.Opp.Hk.PressThreeCommitM = 6.0;
			P.Mate.Hk.AvoidDownedOut = 0.5;
			P.Opp.Hk.PressRetreatCap = 0.5;
			char Err[200] = {};
			TestTrue(*FString::Printf(TEXT("the tune %hs applies"), Tune), ApplyDifficultyTune(Tune, P, Err, sizeof(Err)));
			for (const FJamHockeySense* H : { &P.Mate.Hk, &P.Opp.Hk })
			{
				TestTrue(*FString::Printf(TEXT("%hs: every rule of evolution 5 is at its neutral value"), Tune), H->AvoidDownedM == 0.0 && H->AvoidDownedOut == 0.0 && H->PressCommitM == 0.0 && H->PressThreeCommitM == 0.0 && H->PressRetreatCap == 1.0 && !H->bPressThree);
			}
		}
		if (kEvo5AvoidDownedM == 0.0)
		{
			const double KeepOut = kEvo8ShipDownedLeave ? kEvo8AvoidDownedM : 0.0;   // lane A202: evolution 8's downed rule ships the keep-out on
			TestTrue(TEXT("as shipped every rule of evolution 5 is at its neutral value (the keep-out: evolution 8's)"), A.Opp.Hk.AvoidDownedM == KeepOut && A.Mate.Hk.AvoidDownedM == KeepOut && !A.Opp.Hk.bPressThree && !A.Mate.Hk.bPressThree);
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
	const FString A1 = Match("brain8=0"), A2 = Match("brain8=0"), Off = Match("brain5=0;brain7=1;brain8=0;opp.hk_press_commit_m=8"),   // lane A221 (LADDER SET 4): pro's commit distance 8 is a level number now (R-0063's dial); brain5=0 zeroes it, the tune gives it back
		    // lane A202: evolution 8 ships on (its downed rule steers round him): the pair is read with it off
		 On = Match("opp.hk_avoid_downed_m=1.3;mate.hk_avoid_downed_m=1.3");
	AddInfo(FString::Printf(TEXT("hockey.regular at pro, the regular player, seed 1: as shipped %s; with brain5=0 %s; with the keep-out at 1.3 m %s"), *A1, *Off, *On));
	TestEqual(TEXT("the same match twice is the same match"), A1, A2);
	if (kEvo5AvoidDownedM == 0.0)
	{
		TestEqual(TEXT("as shipped is brain5=0 (every rule ships at its neutral value)"), A1, Off);   // lane A193: brainN=0 also switches evolution 7 off; brain7=1 puts it back as shipped, so the pair compares only evolution N
	}
	return true;
}

// The instrument of item 1 (header of this file). Outside the gate.
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamHockey5DownedBar, "Bar.Bot.Hockey5.Downed", JamHockeyBrain5TestsLocal::Flags)
bool FJamHockey5DownedBar::RunTest(const FString& Parameters)
{
	using namespace JamHockeyBrain5TestsLocal;
	const FString TunesEnv = FPlatformMisc::GetEnvironmentVariable(TEXT("JAM_A167_TUNES"));
	const FString LevelsEnv = FPlatformMisc::GetEnvironmentVariable(TEXT("JAM_A167_LEVELS"));
	const FString MatchesEnv = FPlatformMisc::GetEnvironmentVariable(TEXT("JAM_A167_MATCHES"));
	const FString CutEnv = FPlatformMisc::GetEnvironmentVariable(TEXT("JAM_A167_CUT"));
	TArray<FString> Arms, Levels;
	(TunesEnv.IsEmpty() ? FString(TEXT("off:|keep13out07:opp.hk_avoid_downed_m=1.3;mate.hk_avoid_downed_m=1.3;opp.hk_avoid_downed_out=0.7;mate.hk_avoid_downed_out=0.7")) : TunesEnv).ParseIntoArray(Arms, TEXT("|"), true);
	(LevelsEnv.IsEmpty() ? FString(TEXT("pro")) : LevelsEnv).ParseIntoArray(Levels, TEXT(","), true);
	const int32 Matches = MatchesEnv.IsEmpty() ? 200 : FMath::Clamp(FCString::Atoi(*MatchesEnv), 1, 2000);
	const FString Cut = CutEnv.IsEmpty() ? FString(TEXT("hockey.regular")) : CutEnv;
	TArray<FString> Errors;
	UJamCartridge* Cart = UJamCartridge::LoadFromFile(UJamCartridge::ResolveCartridgePath(Cut), Errors);
	if (!Cart) { AddError(FString::Printf(TEXT("FAIL %s does not load"), *Cut)); return false; }
	const bool bLarge = Cut != TEXT("hockey.regular");   // the curve numbers the large cells' seeds 1..n
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
			FDownCount N;
			int32 Wins = 0, Gf = 0, Ga = 0;
			int64 Frames = 0;
			for (int32 m = 0; m < Matches; ++m)
			{
				// the curve's seeds: the regular cell takes 1-100 of each band of 150, the large one 1..n
				const uint64 Seed = bLarge ? static_cast<uint64>(m + 1) : static_cast<uint64>((m / 100) * 150 + (m % 100) + 1);
				FJamSimAdapter Sim(*Cart);
				const FJamPlaytestStats St = RunPlaytestMatch(Sim, C, Seed, Kind, 36000, Cart->Game.Shot.ChargeFramesMax, false, &DownTrace, &N, 1);
				N.EndMatch(nullptr);
				Wins += St.Winner == St.PlayerTeam ? 1 : 0;
				Gf += St.GoalsFor; Ga += St.GoalsAgainst; Frames += St.Frames;
			}
			const double Pf = N.PairFrames > 0 ? static_cast<double>(N.PairFrames) : 1.0;
			AddInfo(FString::Printf(TEXT("DOWNED %s | %s | %s | %d matches | spells over 6 frames within 0.9 m: %d (bots %d, the human %d) in %d matches, longest %d frames; by length 7-10 / 11-20 / 21-40 / 41+: %d / %d / %d / %d; begun at the knockdown %d | pair frames a match %.1f, frames lying a match %.0f | of the pair frames: the standing one chases the puck %.0f %%, the puck within 1.5 m of the downed one %.0f %%, team-mates %.0f %%, the downed one still slides %.0f %% | win %.1f %%, goals %.2f : %.2f, %.0f s a match"),
				*Cut, *Level, *Name, Matches, N.Spells, N.SpellsBots, N.SpellsHuman, N.MatchesWith, N.Longest, N.LenHist[0], N.LenHist[1], N.LenHist[2], N.LenHist[3], N.AtKnockdown, static_cast<double>(N.PairFrames) / Matches, static_cast<double>(N.DownFrames) / Matches,
				100.0 * N.NearChaser / Pf, 100.0 * N.NearPuck / Pf, 100.0 * N.NearSameTeam / Pf, 100.0 * N.NearMoving / Pf,
				100.0 * Wins / Matches, static_cast<double>(Gf) / Matches, static_cast<double>(Ga) / Matches, static_cast<double>(Frames) / Matches / 60.0));
		}
	}
	Cart->RemoveFromRoot();
	return true;
}

#endif
