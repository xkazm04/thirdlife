// Lane A17: the bot suite on season takes 1-4 at their own levels (docs/experiments/LADDER.md). Lives in JamCore because the bot
// match runner (JamAI::RunMatch) is JamCore-internal. Headless, no world:
//   UnrealEditor-Cmd ThirdJam.uproject -ExecCmds="Automation RunTests Jam.Bot.SeasonTakes; Quit" -nullrhi -unattended -nopause -stdout
// Per take, seeds 1, 2, 7, the scripted human (PlayerBot) at the take's game.ai.difficulty:
//   every match ends (first_to) or runs its clock (timer) inside 10 minutes; no faceoff leaves the human without a touch for 600 frames;
//   every skater moves; the puck stays inside the boards; the AI shoots (matches of a minute or more); at rookie the human wins at least 2 of 3; matches are deterministic.
#include "CoreMinimal.h"
#include "Misc/AutomationTest.h"
#include "Misc/Paths.h"

#include "../AI/JamBotMatch.h"
#include "../AI/JamSimAdapter.h"
#include "../AI/DifficultyResolve.h"
#include "JamCartridge.h"

#if WITH_DEV_AUTOMATION_TESTS

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamBotSeasonTakes, "Jam.Bot.SeasonTakes",
	EAutomationTestFlags::EditorContext | EAutomationTestFlags::CommandletContext | EAutomationTestFlags::EngineFilter)

bool FJamBotSeasonTakes::RunTest(const FString& Parameters)
{
	constexpr int64 MaxFrames = 36000;
	bool bOk = true;
	for (int32 Take = 1; Take <= 4; ++Take)
	{
		const FString Name = FString::Printf(TEXT("take-%d"), Take);
		const FString Path = FPaths::Combine(UJamCartridge::GetCartridgeDir(), TEXT("ladder"), Name + TEXT(".cartridge.json"));
		TArray<FString> Errors;
		UJamCartridge* Cart = UJamCartridge::LoadFromFile(Path, Errors);
		if (!Cart) { AddError(FString::Printf(TEXT("FAIL %s does not load: %s"), *Name, *FString::Join(Errors, TEXT("; ")))); bOk = false; continue; }
		JamAI::FJamDifficultyResolution Res;
		JamAI::ResolveDifficulty(*Cart, Res);
		const bool bRookie = Res.Level == JamAI::EDifficulty::Rookie;
		const bool bTimer = Cart->Game.Rules.Mode == FName(TEXT("timer"));
		const JamAI::FJamMatchConfig C = JamAI::ToMatchConfigResolved(*Cart);
		const int32 Pi = C.PlayerIndex();
		const int32 PlayerTeam = C.Skaters[Pi].Team;
		int32 Wins = 0;
		int32 TakeAiShots = 0;      // Director (A94 landing): the AI-shot clause is per take, over its three seeds
		int64 TakeLongFrames = 0;   // frames of the take's matches that ran a minute or more
		for (const uint64 Seed : { 1ull, 2ull, 7ull })
		{
			JamAI::FJamSimAdapter SimA(*Cart), SimB(*Cart);   // lane A41: the takes play with their hooks, zones and pickups
			const JamAI::FJamMatchStats A = JamAI::RunMatch(SimA, C, Seed, JamAI::EJamPlayerMode::PlayerBot, MaxFrames, 60);
			const JamAI::FJamMatchStats B = JamAI::RunMatch(SimB, C, Seed, JamAI::EJamPlayerMode::PlayerBot, MaxFrames, 60);
			bool bMoved = true;
			int32 AiShots = 0;
			for (int32 i = 0; i < A.NumSkaters; ++i) { bMoved &= A.MovedMax[i] >= 3.0; AiShots += i == Pi ? 0 : A.Shots[i]; }
			const bool bWin = A.bOver && A.Winner == PlayerTeam;
			Wins += bWin ? 1 : 0;
			const bool bEnded = A.bOver;   // first_to ends by score; a timer cut ends at its clock
			const bool bSame = A.Hash == B.Hash && A.Frames == B.Frames;
			const FString Msg = FString::Printf(TEXT("%s (%s) seed %llu: %d:%d in %lld frames, %s, faceoffs %d without a touch %d, AI shots %d, worst board %.3f m, hash %016llx %s"),
				*Name, *Cart->Title, Seed, A.Goals[PlayerTeam], A.Goals[1 - PlayerTeam], A.Frames, bWin ? TEXT("WIN") : TEXT("no win"), A.Faceoffs,
				A.FaceoffsWithoutPlayerTouch, AiShots, A.MaxBoardDistance, A.Hash, bSame ? TEXT("same") : TEXT("DIFFERENT"));
			// A rookie human can win 2:0 inside 20 s before the AI ever shoots: the AI-shot clause applies to matches of a minute or more.
			// Per seed this clause was a coin at rookie (A82, A85, A94 each met it: a rookie bot shoots about once a minute, and with the hockey principles it passes more
			// and shoots less): the clause now reads over the take's three seeds, below the loop.
			TakeAiShots += AiShots;
			if (A.Frames >= 3600) TakeLongFrames += A.Frames;
			const bool bAiShot = true;
			if (bEnded && A.FaceoffsWithoutPlayerTouch == 0 && bMoved && bAiShot && A.MaxBoardDistance <= 0.01 && bSame) AddInfo(TEXT("PASS ") + Msg);
			else { AddError(TEXT("FAIL ") + Msg + (bEnded ? TEXT("") : TEXT(" (did not end inside 10 minutes)"))); bOk = false; }
		}
		if (TakeLongFrames > 0 && TakeAiShots == 0)
		{
			AddError(FString::Printf(TEXT("FAIL %s: the AI never shot in %lld frames of matches a minute or longer (three seeds)"), *Name, TakeLongFrames));
			bOk = false;
		}
		const FString W = FString::Printf(TEXT("%s (%s, %s): the scripted human won %d of 3"), *Name, bRookie ? TEXT("rookie") : TEXT("pro or harder"), bTimer ? TEXT("timer") : TEXT("first_to"), Wins);
		if (!bRookie || Wins >= 2) AddInfo(TEXT("PASS ") + W);
		else { AddError(TEXT("FAIL ") + W + TEXT(" (rookie needs 2)")); bOk = false; }
	}
	return bOk;
}

#endif
