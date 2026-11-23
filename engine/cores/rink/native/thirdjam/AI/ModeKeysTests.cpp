// Lane A72 (R-0037, briefs/A72-mode-keys.md): the cartridge keys the Director's modes asked for (docs/experiments/MODES.md asks A1, A4, A5, A8).
// Headless, no world:
//   UnrealEditor-Cmd ThirdJam.uproject -ExecCmds="Automation RunTests Jam.Core.ModeKeys; Quit" -nullrhi -unattended -nopause -stdout
// A2 / A3 (the sprint) are Jam.Core.ModeKeys.Sprint. The HUD half of A1 (the clock reads 10:00) is Jam.Core.ModeKeys.HudClock in JamGame (ModeKeysHudTests.cpp).
#include "CoreMinimal.h"
#include "Misc/AutomationTest.h"
#include "Misc/FileHelper.h"

#include "DifficultyProfile.h"
#include "DifficultyResolve.h"
#include "JamCartridge.h"
#include "JamEventBus.h"
#include "JamPlaytester.h"
#include "JamSim.h"
#include "JamSimAdapter.h"

#if WITH_DEV_AUTOMATION_TESTS

namespace JamModeKeysTests
{
	constexpr EAutomationTestFlags Flags = EAutomationTestFlags_ApplicationContextMask | EAutomationTestFlags::ProductFilter;

	// hockey.regular with text pairs replaced (each must occur once); null when it does not load (the errors go to OutErrors).
	UJamCartridge* Variant(FAutomationTestBase& T, const TArray<TPair<FString, FString>>& Swaps, TArray<FString>& OutErrors, bool bExpectLoad = true)
	{
		FString Json;
		if (!FFileHelper::LoadFileToString(Json, *UJamCartridge::ResolveCartridgePath(TEXT("hockey.regular"))))
		{
			T.AddError(TEXT("FAIL hockey.regular does not read"));
			return nullptr;
		}
		for (const TPair<FString, FString>& S : Swaps)
		{
			if (Json.ReplaceInline(*S.Key, *S.Value) != 1) { T.AddError(FString::Printf(TEXT("FAIL expected one '%s' in hockey.regular"), *S.Key)); return nullptr; }
		}
		OutErrors.Reset();
		UJamCartridge* C = UJamCartridge::LoadFromString(Json, OutErrors);
		if (!C && bExpectLoad) { T.AddError(FString::Printf(TEXT("FAIL variant does not load: %s"), *FString::Join(OutErrors, TEXT("; ")))); }
		return C;
	}
	UJamCartridge* Ai(FAutomationTestBase& T, const FString& Body, TArray<FString>& Errors, bool bExpectLoad = true)
	{
		return Variant(T, { { TEXT("\"difficulty\": \"pro\""), Body } }, Errors, bExpectLoad);
	}
	bool Rejects(const TArray<FString>& Errors, const TCHAR* Pointer)
	{
		return Errors.ContainsByPredicate([Pointer](const FString& E) { return E.Contains(Pointer); });
	}

	JamAI::FJamPlaytestStats Play(const UJamCartridge& Cart, uint64 Seed, int64 Frames, JamAI::EPlaytester Kind = JamAI::EPlaytester::Regular, bool bSprint = false)
	{
		JamAI::FJamSimAdapter Sim(Cart);
		return JamAI::RunPlaytestMatch(Sim, JamAI::ToMatchConfigResolved(Cart, nullptr), Seed, Kind, Frames, Cart.Game.Shot.ChargeFramesMax, bSprint);
	}
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamModeKeysReactFrames, "Jam.Core.ModeKeys.ReactFrames", JamModeKeysTests::Flags)
bool FJamModeKeysReactFrames::RunTest(const FString& Parameters)
{
	using namespace JamAI;
	TArray<FString> Errors;
	UJamCartridge* Base = JamModeKeysTests::Ai(*this, TEXT("\"difficulty\": \"pro\""), Errors);
	UJamCartridge* Slow = JamModeKeysTests::Ai(*this, TEXT("\"difficulty\": \"pro\", \"react_frames\": 40"), Errors);
	if (!Base || !Slow) return false;
	FJamDifficultyResolution R0, R1;
	ResolveDifficulty(*Base, R0);
	ResolveDifficulty(*Slow, R1);
	TestEqual(TEXT("absent react_frames = the level's profile"), R0.Params.Opp.ReactionFrames, GetDifficultyProfile(EDifficulty::Pro).Opp.ReactionFrames);
	TestEqual(TEXT("game.ai.react_frames 40 is the opposing bots' delay"), R1.Params.Opp.ReactionFrames, 40);
	TestEqual(TEXT("the human's teammates keep their own delay"), R1.Params.Mate.ReactionFrames, R0.Params.Mate.ReactionFrames);
	TestTrue(TEXT("listed as an explicit key"), R1.ExplicitKeys.Contains(TEXT("game.ai.react_frames")));
	TestTrue(TEXT("the ring holds 60 frames"), kMaxReactionFrames >= 60);
	UJamCartridge* Edge = JamModeKeysTests::Ai(*this, TEXT("\"difficulty\": \"rookie\", \"react_frames\": 60"), Errors);
	if (Edge) { FJamDifficultyResolution R; ResolveDifficulty(*Edge, R); TestEqual(TEXT("60 at rookie"), R.Params.Opp.ReactionFrames, 60); }
	TestNull(TEXT("61 is rejected"), JamModeKeysTests::Ai(*this, TEXT("\"difficulty\": \"pro\", \"react_frames\": 61"), Errors, false));
	TestTrue(TEXT("... at /game/ai/react_frames"), JamModeKeysTests::Rejects(Errors, TEXT("/game/ai/react_frames")));
	// the delay plays: the same seed diverges
	const FJamPlaytestStats A = JamModeKeysTests::Play(*Base, 1, 3600);
	const FJamPlaytestStats B = JamModeKeysTests::Play(*Slow, 1, 3600);
	TestNotEqual(TEXT("react_frames 40 changes the match (hash)"), A.Hash, B.Hash);
	AddInfo(FString::Printf(TEXT("seed 1, 3600 frames: absent %d-%d hash %016llx; react 40 %d-%d hash %016llx"), A.GoalsFor, A.GoalsAgainst,
		static_cast<unsigned long long>(A.Hash), B.GoalsFor, B.GoalsAgainst, static_cast<unsigned long long>(B.Hash)));
	return true;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamModeKeysBodyCheck, "Jam.Core.ModeKeys.BodyCheck", JamModeKeysTests::Flags)
bool FJamModeKeysBodyCheck::RunTest(const FString& Parameters)
{
	using namespace JamAI;
	TArray<FString> Errors;
	UJamCartridge* Never = JamModeKeysTests::Ai(*this, TEXT("\"difficulty\": \"pro\", \"body_check\": 0"), Errors);
	UJamCartridge* Half = JamModeKeysTests::Ai(*this, TEXT("\"difficulty\": \"pro\", \"body_check\": 0.5"), Errors);
	UJamCartridge* Rookie = JamModeKeysTests::Ai(*this, TEXT("\"difficulty\": \"rookie\", \"body_check\": 1"), Errors);
	UJamCartridge* Absent = JamModeKeysTests::Ai(*this, TEXT("\"difficulty\": \"pro\""), Errors);
	if (!Never || !Half || !Rookie || !Absent) return false;
	FJamDifficultyResolution R;
	ResolveDifficulty(*Absent, R);
	TestEqual(TEXT("absent: the level's rule (pro checks from 5 m/s)"), R.Params.Opp.CheckMinClosing, GetDifficultyProfile(EDifficulty::Pro).Opp.CheckMinClosing);
	TestEqual(TEXT("absent: every chance"), R.Params.Opp.BodyCheckShare, 1.0);
	ResolveDifficulty(*Never, R);
	TestTrue(TEXT("0: never"), R.Params.Opp.CheckMinClosing < 0.0);
	ResolveDifficulty(*Half, R);
	TestEqual(TEXT("0.5: the share"), R.Params.Opp.BodyCheckShare, 0.5);
	TestEqual(TEXT("0.5: at the sim's check_speed_min"), R.Params.Opp.CheckMinClosing, Half->Game.Skater.CheckSpeedMin);
	TestTrue(TEXT("listed as an explicit key"), R.ExplicitKeys.Contains(TEXT("game.ai.body_check")));
	TestEqual(TEXT("the human's teammates never check"), R.Params.Mate.CheckMinClosing, -1.0);
	ResolveDifficulty(*Rookie, R);
	TestTrue(TEXT("rookie (never by its rule) checks once body_check is written"), R.Params.Opp.CheckMinClosing >= 0.0 && R.Params.Opp.BodyCheckShare == 1.0);
	TestNull(TEXT("1.5 is rejected"), JamModeKeysTests::Ai(*this, TEXT("\"difficulty\": \"pro\", \"body_check\": 1.5"), Errors, false));
	TestTrue(TEXT("... at /game/ai/body_check"), JamModeKeysTests::Rejects(Errors, TEXT("/game/ai/body_check")));
	// it plays: on a low check_speed_min (Cage 3, Blind Side 2) the bots knock the human down with 1 and never with 0
	TArray<FString> E2;
	auto Hit = [&](const TCHAR* Share)
	{
		return JamModeKeysTests::Variant(*this, { { TEXT("\"difficulty\": \"pro\""), FString::Printf(TEXT("\"difficulty\": \"pro\", \"body_check\": %s"), Share) },
			{ TEXT("\"check_enabled\": true"), TEXT("\"check_enabled\": true, \"check_speed_min\": 2") },
			// Lane A92 (R-0045): the bots' cross-check (the lift at arm's length) shoves by momentum and lands as a check; ai.body_check is the body check's key, so
			// the lift's shove is turned off here (game.contact.thrust_mps 0) to count body checks only.
			{ TEXT("\"skater\": {"), TEXT("\"contact\": { \"thrust_mps\": 0 }, \"skater\": {") } }, E2);
	};
	UJamCartridge* On = Hit(TEXT("1"));
	UJamCartridge* Off = Hit(TEXT("0"));
	if (!On || !Off) return false;
	int32 TakenOn = 0, TakenOff = 0;
	for (uint64 Seed = 1; Seed <= 4; ++Seed)
	{
		TakenOn += JamModeKeysTests::Play(*On, Seed, 7200).ChecksTaken;
		TakenOff += JamModeKeysTests::Play(*Off, Seed, 7200).ChecksTaken;
	}
	TestEqual(TEXT("body_check 0: the human is never checked down"), TakenOff, 0);
	TestTrue(TEXT("body_check 1 at check_speed_min 2: the bots check the human down"), TakenOn > 0);
	AddInfo(FString::Printf(TEXT("seeds 1-4, 7200 frames: checks taken by the human %d (body_check 1) / %d (0)"), TakenOn, TakenOff));
	return true;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamModeKeysTimer, "Jam.Core.ModeKeys.TimerTenMinutes", JamModeKeysTests::Flags)
bool FJamModeKeysTimer::RunTest(const FString& Parameters)
{
	TArray<FString> Errors;
	auto Timer = [&](int32 Frames, bool bExpect)
	{
		return JamModeKeysTests::Variant(*this, { { TEXT("\"mode\": \"first_to\""), TEXT("\"mode\": \"timer\"") },
			{ TEXT("\"score_to_win\": 3,"), FString::Printf(TEXT("\"timer_frames\": %d,"), Frames) } }, Errors, bExpect);
	};
	UJamCartridge* Ten = Timer(28800, true);
	if (!Ten) return false;
	TestEqual(TEXT("timer_frames 28800 loads"), Ten->Game.Rules.TimerFrames, 28800);
	UJamSim* Sim = NewObject<UJamSim>();
	Sim->Init(Ten->Game, 1);
	TestEqual(TEXT("the sim's clock starts at 28800"), Sim->GetTimerFrames(), 28800);
	TestNull(TEXT("28801 is rejected"), Timer(28801, false));
	TestTrue(TEXT("... at /game/rules/timer_frames"), JamModeKeysTests::Rejects(Errors, TEXT("/game/rules/timer_frames")));
	return true;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamModeKeysPenalty, "Jam.Core.ModeKeys.PenaltyFrames", JamModeKeysTests::Flags)
bool FJamModeKeysPenalty::RunTest(const FString& Parameters)
{
	TArray<FString> Errors;
	auto Pen = [&](int32 Frames, bool bExpect)
	{
		return JamModeKeysTests::Variant(*this, { { TEXT("\"penalties\": false"), FString::Printf(TEXT("\"penalties\": true, \"penalty_frames\": %d"), Frames) } }, Errors, bExpect);   // lane A112: hockey.regular has no whistle (R-0048)
	};
	UJamCartridge* Short = Pen(120, true);
	UJamCartridge* Absent = JamModeKeysTests::Variant(*this, { { TEXT("\"penalties\": false"), TEXT("\"penalties\": true") } }, Errors);
	if (!Short || !Absent) return false;
	TestEqual(TEXT("absent = 300"), Absent->Game.Rules.PenaltyFrames, UJamSim::BoxFrames);
	TestEqual(TEXT("penalty_frames 120 loads"), Short->Game.Rules.PenaltyFrames, 120);
	for (const int32 Bad : { 59, 601 })
	{
		TestNull(*FString::Printf(TEXT("%d is rejected"), Bad), Pen(Bad, false));
		TestTrue(TEXT("... at /game/rules/penalty_frames"), JamModeKeysTests::Rejects(Errors, TEXT("/game/rules/penalty_frames")));
	}
	// the foul of Jam.Core.Stick case 5 (a check on a skater without the puck): the fouler sits penalty_frames
	for (const UJamCartridge* C : { Short, Absent })
	{
		UJamSim* Sim = NewObject<UJamSim>();
		Sim->Init(C->Game, 1);
		Sim->SkipFaceoff();
		const int32 Me = Sim->GetHumanIndex();
		int32 O = -1;
		for (const FJamSkaterState& S : Sim->GetSkaters()) if (S.Team != Sim->GetSkaters()[Me].Team && !S.bHuman) { O = S.Index; break; }
		for (const FJamSkaterState& S : Sim->GetSkaters()) if (S.Index != Me && S.Index != O) Sim->SetSkater(S.Index, FVector2D(-35.0 + S.Index * 2.0, 18.0), FVector2D::ZeroVector, 0);
		Sim->SetPuck(FVector2D(20, 15), FVector2D::ZeroVector);
		Sim->SetSkater(O, FVector2D(0, 0), FVector2D::ZeroVector, 0);
		// Lane A192: the window opens game.contact.check_windup_frames after the press: the charger starts that much ground farther out, the scene runs that much longer.
		const int32 Wu = Sim->GetConfig().Contact.CheckWindupFor(Sim->GetSkaters()[Me].bHuman);   // lane A200: the presser's own (bot_check_windup_frames for a bot)
		Sim->SetSkater(Me, FVector2D(-1.2 - 8.0 * Wu / 60.0, 0), FVector2D(8, 0), 0);
		TArray<FJamInput> In;
		In.SetNum(Sim->GetSkaters().Num());
		In[Me].Move = FVector2D(1, 0);
		In[Me].bCheck = true;
		int32 Fouls = 0;
		for (int32 F = 0; F < 6 + Wu; ++F)
		{
			Sim->Step(In);
			In[Me].bCheck = false;
			for (const FJamSimEvent& E : Sim->GetFrameEvents()) if (E.Name == JamEvents::Foul && E.Who == Me) ++Fouls;
		}
		const int32 Want = C->Game.Rules.PenaltyFrames;
		TestEqual(TEXT("a foul"), Fouls, 1);
		const int32 Left = Sim->GetSkaters()[Me].PenaltyFrames;
		TestTrue(*FString::Printf(TEXT("the fouler sits %d frames (less the frames since the hit; %d left)"), Want, Left), Left > Want - 8 && Left <= Want);
	}
	return true;
}


IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamModeKeysSprint, "Jam.Core.ModeKeys.Sprint", JamModeKeysTests::Flags)
bool FJamModeKeysSprint::RunTest(const FString& Parameters)
{
	using namespace JamAI;
	TArray<FString> Errors;
	UJamCartridge* Absent = JamModeKeysTests::Ai(*this, TEXT("\"difficulty\": \"pro\""), Errors);
	UJamCartridge* Half = JamModeKeysTests::Ai(*this, TEXT("\"difficulty\": \"pro\", \"sprint\": 0.5"), Errors);
	UJamCartridge* All = JamModeKeysTests::Ai(*this, TEXT("\"difficulty\": \"pro\", \"sprint\": 1"), Errors);
	if (!Absent || !Half || !All) return false;
	FJamDifficultyResolution R;
	ResolveDifficulty(*Absent, R);
	TestEqual(TEXT("absent: the level's share (lane A95: FJamBotSkill::SprintShare per side, -1 here)"), R.Params.SprintShare, -1.0);
	ResolveDifficulty(*Half, R);
	TestEqual(TEXT("ai.sprint 0.5 is the share"), R.Params.SprintShare, 0.5);
	TestTrue(TEXT("listed as an explicit key"), R.ExplicitKeys.Contains(TEXT("game.ai.sprint")));
	TestNull(TEXT("1.2 is rejected"), JamModeKeysTests::Ai(*this, TEXT("\"difficulty\": \"pro\", \"sprint\": 1.2"), Errors, false));
	TestTrue(TEXT("... at /game/ai/sprint"), JamModeKeysTests::Rejects(Errors, TEXT("/game/ai/sprint")));
	// A2: bots sprint only when the key is written, more with a larger share
	const FJamPlaytestStats S0 = JamModeKeysTests::Play(*Absent, 1, 3600);
	const FJamPlaytestStats S5 = JamModeKeysTests::Play(*Half, 1, 3600);
	const FJamPlaytestStats S1 = JamModeKeysTests::Play(*All, 1, 3600);
	// Lane A95 (R-0045 law 4): absent = the level's share (pro 0.35 per side); game.ai.sprint 0 = never
	TestTrue(TEXT("absent: the level's share, bots sprint"), S0.BotSprintFrames > 0);
	{
		UJamCartridge* Zero = JamModeKeysTests::Ai(*this, TEXT("\"difficulty\": \"pro\", \"sprint\": 0"), Errors);
		if (Zero) TestEqual(TEXT("ai.sprint 0: no bot sprint frame"), JamModeKeysTests::Play(*Zero, 1, 3600).BotSprintFrames, static_cast<int64_t>(0));
	}
	TestTrue(TEXT("ai.sprint 0.5: bots sprint"), S5.BotSprintFrames > 0);
	TestTrue(TEXT("ai.sprint 1: more than 0.5"), S1.BotSprintFrames > S5.BotSprintFrames);
	// A3: the playtester sprints only when asked (-playersprint), the regular and good players, never the novice
	const FJamPlaytestStats Off = JamModeKeysTests::Play(*Absent, 1, 3600, EPlaytester::Regular, false);
	const FJamPlaytestStats Reg = JamModeKeysTests::Play(*Absent, 1, 3600, EPlaytester::Regular, true);
	const FJamPlaytestStats Good = JamModeKeysTests::Play(*Absent, 1, 3600, EPlaytester::Good, true);
	const FJamPlaytestStats Nov = JamModeKeysTests::Play(*Absent, 1, 3600, EPlaytester::Novice, true);
	// Lane A95 (brief A95 job 3): the regular and good players sprint with the puck on an open lane by default (R-0045 law 4); -playersprint adds A72's chase sprint.
	// Lane A115: this was an equality that held on the match of that day. The playtester's own carry test (JamPlaytester.cpp: the last toucher with the puck in
	// reach) and the sim's carrier of record differ on a few frames at the edge of a carry (20 against 16 on the match evolution 2 plays), so the rule is said
	// as what it means: most of the sprint is with the puck, and it is far less than with -playersprint.
	TestTrue(*FString::Printf(TEXT("without -playersprint the human sprints with the puck (A95's carry sprint): %lld sprint frames, %lld of them carrying, %lld with -playersprint"),
		static_cast<long long>(Off.SprintFrames), static_cast<long long>(Off.CarrySprintFrames), static_cast<long long>(Reg.SprintFrames)),
		Off.SprintFrames < Reg.SprintFrames);   // Director, 14 Nov 22:40: "less than half" was a statistic of one match (29 against 49 once passes arrive and hits land:
	// R-0067's night); the rule is that -playersprint adds sprint, so: fewer frames without it. The share is in the message above.
	// Director, 14 Nov (the landing of the held cross-check on the speed rule): "most of it is with the puck" read 5 of 11 frames on this one match: a
	// share of a handful of frames is logged, not asserted (the rule of 13 Nov for statistics on one match); what is asserted is the rule: far less than
	// with -playersprint.
	AddInfo(FString::Printf(TEXT("carry sprint share without -playersprint: %lld of %lld frames"), static_cast<long long>(Off.CarrySprintFrames), static_cast<long long>(Off.SprintFrames)));
	TestEqual(TEXT("... and the match is the same as before"), Off.Hash, S0.Hash);
	TestTrue(TEXT("the regular player sprints"), Reg.SprintFrames > 0);
	TestTrue(TEXT("the good player sprints"), Good.SprintFrames > 0);
	TestEqual(TEXT("the novice never"), Nov.SprintFrames, static_cast<int64_t>(0));
	AddInfo(FString::Printf(TEXT("seed 1, 3600 frames: bot sprint frames %lld / %lld / %lld (absent / 0.5 / 1); human sprint frames regular %lld, good %lld"),
		static_cast<long long>(S0.BotSprintFrames), static_cast<long long>(S5.BotSprintFrames), static_cast<long long>(S1.BotSprintFrames),
		static_cast<long long>(Reg.SprintFrames), static_cast<long long>(Good.SprintFrames)));
	return true;
}

#endif
