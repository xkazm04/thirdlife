// Lane A16 (R-0016 point 2): Jam.Bot.VisualSwap. Both of device B's skater visuals load from /JamAssets/Skaters/ and implement IJamSkaterVisual,
// and the bot suite's AiBotPlays gate passes on hockey.test.visual-b2 and on its humanoid_b1 variant with the same state hash (visuals never
// feed the simulation). Headless, no world:
//   UnrealEditor-Cmd ThirdJam.uproject -ExecCmds="Automation RunTests Jam.Bot.VisualSwap; Quit" -nullrhi -unattended -nopause -stdout
#include "CoreMinimal.h"
#include "Misc/AutomationTest.h"
#include "../AI/JamBotMatch.h"
#include "../AI/JamSimAdapter.h"
#include "../AI/DifficultyResolve.h"
#include "JamCartridge.h"
#include "JamSkaterVisual.h"

#if WITH_DEV_AUTOMATION_TESTS

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamBotVisualSwap, "Jam.Bot.VisualSwap",
	EAutomationTestFlags::EditorContext | EAutomationTestFlags::CommandletContext | EAutomationTestFlags::EngineFilter)

bool FJamBotVisualSwap::RunTest(const FString& Parameters)
{
	bool bOk = true;
	// 1. The classes the game mode loads by game.skater.visual (AHokejGameMode::ResolveVisualClass).
	for (const TCHAR* Path : { TEXT("/JamAssets/Skaters/BP_SkaterVisual_TB1.BP_SkaterVisual_TB1_C"), TEXT("/JamAssets/Skaters/BP_SkaterVisual_TB2.BP_SkaterVisual_TB2_C") })
	{
		UClass* Cls = LoadClass<UObject>(nullptr, Path, nullptr, LOAD_NoWarn | LOAD_Quiet);
		if (!Cls) { AddError(FString::Printf(TEXT("FAIL %s does not load"), Path)); bOk = false; continue; }
		const bool bImpl = Cls->ImplementsInterface(UJamSkaterVisual::StaticClass());
		if (!bImpl) { AddError(FString::Printf(TEXT("FAIL %s does not implement JamSkaterVisual"), Path)); bOk = false; }
		else AddInfo(FString::Printf(TEXT("PASS %s loads and implements JamSkaterVisual"), Path));
	}

	// 2. The bot suite on both tracks: hockey.test.visual-b2 and the same cartridge with humanoid_b1.
	TArray<FString> Errors;
	UJamCartridge* B2 = UJamCartridge::LoadFromFile(UJamCartridge::ResolveCartridgePath(TEXT("hockey.test.visual-b2")), Errors);
	if (!B2) { AddError(TEXT("FAIL hockey.test.visual-b2 does not load: ") + FString::Join(Errors, TEXT("; "))); return false; }
	FString B1Text = B2->RawJson;
	B1Text.ReplaceInline(TEXT("\"generated_b2\""), TEXT("\"humanoid_b1\""));
	UJamCartridge* B1 = UJamCartridge::LoadFromString(B1Text, Errors);
	if (!B1) { AddError(TEXT("FAIL the humanoid_b1 variant does not load: ") + FString::Join(Errors, TEXT("; "))); return false; }
	TestEqual(TEXT("variant carries humanoid_b1"), B1->Game.Skater.Visual, FName(TEXT("humanoid_b1")));
	// Lane A26 (R-0024): the skeletal toy figure is a third track; it must leave the hash alone too.
	FString SkText = B2->RawJson;
	SkText.ReplaceInline(TEXT("\"generated_b2\""), TEXT("\"toy_skeletal\""));
	UJamCartridge* Sk = UJamCartridge::LoadFromString(SkText, Errors);
	if (!Sk) { AddError(TEXT("FAIL the toy_skeletal variant does not load: ") + FString::Join(Errors, TEXT("; "))); return false; }
	TestEqual(TEXT("variant carries toy_skeletal"), Sk->Game.Skater.Visual, FName(TEXT("toy_skeletal")));

	uint64 Hashes[3] = { 0, 0, 0 };
	int32 K = 0;
	for (UJamCartridge* Cart : { B2, B1, Sk })
	{
		JamAI::FJamSimAdapter Sim(*Cart);   // lane A41: with the game mode's systems
		const JamAI::FJamMatchStats S = JamAI::RunMatch(Sim, JamAI::ToMatchConfigResolved(*Cart, nullptr), 1, JamAI::EJamPlayerMode::PlayerBotAI, 36000, 60);
		const int32 Pi = JamAI::ToMatchConfig(Cart->Game).PlayerIndex();
		bool bMoved = true;
		double MinMoved = 1e9;
		int32 AiShots = 0;
		for (int32 i = 0; i < S.NumSkaters; ++i)
		{
			MinMoved = FMath::Min(MinMoved, S.MovedMax[i]);
			bMoved &= S.MovedMax[i] >= 3.0;
			AiShots += i == Pi ? 0 : S.Shots[i];
		}
		const bool bInside = S.MaxBoardDistance <= 0.01;
		const FString Msg = FString::Printf(TEXT("%s seed 1: least moved %.1f m, puck path %.1f m, AI shots %d, worst board distance %.3f m, over %s, hash %016llx"),
			*Cart->Game.Skater.Visual.ToString(), MinMoved, S.PuckPathM, AiShots, S.MaxBoardDistance, S.bOver ? TEXT("yes") : TEXT("no"), static_cast<unsigned long long>(S.Hash));
		if (bMoved && S.PuckPathM > 30.0 && AiShots >= 1 && bInside) { AddInfo(TEXT("PASS ") + Msg); }
		else { AddError(TEXT("FAIL ") + Msg); bOk = false; }
		if (K < 3) Hashes[K++] = S.Hash;
	}
	TestEqual(TEXT("the visual never feeds the simulation: same hash on both tracks"), Hashes[0], Hashes[1]);
	TestEqual(TEXT("the visual never feeds the simulation: same hash with toy_skeletal"), Hashes[0], Hashes[2]);
	return bOk;
}

#endif
