// Lane A2: see JamTournamentCommandlet.h.
#include "JamTournamentCommandlet.h"

#include "JamBotMatch.h"
#include "JamSimAdapter.h"
#include "JamCartridge.h"
#include "JamBotRefSim.h"
#include "DifficultyResolve.h"
#include "JamPlaytester.h"
#include "Misc/Parse.h"

DEFINE_LOG_CATEGORY_STATIC(LogJamAI, Log, All);

namespace JamTournamentLocal
{
	void TraceToLog(void* Ctx, const JamAI::FJamAIWorld& W, const JamAI::FJamAIInput* In, const JamAI::FJamBrain& Brain)
	{
		(void)Ctx;
		static char Buf[4096];
		JamAI::FormatTrace(W, In, Brain, Buf, sizeof(Buf));
		UE_LOG(LogJamAI, Display, TEXT("%s"), UTF8_TO_TCHAR(Buf));
	}

	// lane A71: the playtester's per-frame line: the brain's trace plus the carrier, the last toucher and the human's frames since a touch
	void PlaytestTraceToLog(void* Ctx, const JamAI::FJamAIWorld& W, const JamAI::FJamAIInput* In, const JamAI::FJamBrain& Brain, int64_t SinceTouch, bool bHumanTouch)
	{
		(void)Ctx;
		static char Buf[4096];
		int N = JamAI::FormatTrace(W, In, Brain, Buf, sizeof(Buf));
		if (N < 0 || N > 3900) { N = 0; }
		std::snprintf(Buf + N, sizeof(Buf) - N, " since=%lld ht=%d car=%d lt=%d fo=%d pk=%d", static_cast<long long>(SinceTouch), bHumanTouch ? 1 : 0, W.Carrier, W.PuckLastTouch,
			W.bFaceoffPhase ? 1 : 0, W.NumPickups);
		UE_LOG(LogJamAI, Display, TEXT("%s"), UTF8_TO_TCHAR(Buf));
	}
}

UJamTournamentCommandlet::UJamTournamentCommandlet()
{
	// IsEditor stays true (the default): the editor plugins this project loads assert without GEditor.
	IsClient = false;
	IsServer = false;
	LogToConsole = true;
	ShowErrorCount = true;
}

int32 UJamTournamentCommandlet::Main(const FString& Params)
{
	FString CfgText, Cartridge = TEXT("hockey.regular"), ModeText = TEXT("playerbot"), Seeds = TEXT("1-1"), Preset = TEXT("regular"), SimName = TEXT("jam");
	int64 MaxFrames = 36000;
	FParse::Value(*Params, TEXT("-cfg="), CfgText, false);
	FParse::Value(*Params, TEXT("-cartridge="), Cartridge, false);
	FParse::Value(*Params, TEXT("-mode="), ModeText, false);
	FParse::Value(*Params, TEXT("-seeds="), Seeds, false);
	FParse::Value(*Params, TEXT("-preset="), Preset, false);
	FParse::Value(*Params, TEXT("-maxframes="), MaxFrames);
	FParse::Value(*Params, TEXT("-sim="), SimName, false);
	int32 TraceEvery = 0;
	FParse::Value(*Params, TEXT("-trace="), TraceEvery);
	// lane A3: -difficulty=rookie|pro|all_star replaces the cartridge's game.ai.difficulty; -aitune="k=v;k=v" (DifficultyProfile.h)
	// adjusts the resolved params after it (tools/sweep tuning only).
	FString DifficultyArg, TuneArg;
	FParse::Value(*Params, TEXT("-difficulty="), DifficultyArg, false);
	FParse::Value(*Params, TEXT("-aitune="), TuneArg, false);
	JamAI::EDifficulty LevelArg = JamAI::EDifficulty::Pro;
	if (!DifficultyArg.IsEmpty() && !JamAI::ParseDifficulty(TCHAR_TO_UTF8(*DifficultyArg), LevelArg))
	{
		UE_LOG(LogJamAI, Error, TEXT("FAIL tournament bad -difficulty=%s (rookie | pro | all_star)"), *DifficultyArg);
		return 2;
	}

	// -sim=jam (default): lane A1's UJamSim with the cartridge file as the loader reads it (values applied); -cfg is ignored.
	// -sim=ref: the stand-in sim (AI/JamBotRefSim) with -cfg, as tools/tournament/native does.
	UJamCartridge* Cart = nullptr;
	if (SimName == TEXT("jam"))
	{
		TArray<FString> Errors;
		Cart = UJamCartridge::LoadFromFile(UJamCartridge::ResolveCartridgePath(Cartridge), Errors);
		if (!Cart)
		{
			UE_LOG(LogJamAI, Error, TEXT("FAIL tournament cartridge %s does not load: %s"), *Cartridge, *FString::Join(Errors, TEXT("; ")));
			return 2;
		}
		Cart->AddToRoot();
	}
	else if (SimName != TEXT("ref"))
	{
		UE_LOG(LogJamAI, Error, TEXT("FAIL tournament bad -sim=%s (jam | ref)"), *SimName);
		return 2;
	}

	JamAI::FJamMatchConfig Cfg;
	if (Preset == TEXT("small")) { Cfg.SetSmall(); } else { Cfg.SetRegular(); }
	FString Level = TEXT("pro");
	if (Cart)
	{
		JamAI::FJamDifficultyResolution Res;
		JamAI::ResolveDifficulty(*Cart, Res, DifficultyArg.IsEmpty() ? nullptr : *DifficultyArg);
		Cfg = JamAI::ToMatchConfig(Cart->Game);
		Cfg.AI = Res.Params;
		Level = UTF8_TO_TCHAR(JamAI::DifficultyName(Res.Level));
	}
	char Err[512] = {};
	if (!Cart && !Cfg.Parse(TCHAR_TO_UTF8(*CfgText), Err, sizeof(Err)))
	{
		UE_LOG(LogJamAI, Error, TEXT("FAIL tournament bad -cfg: %s"), UTF8_TO_TCHAR(Err));
		return 2;
	}
	if (!Cart && !DifficultyArg.IsEmpty())
	{
		JamAI::ApplyDifficultyProfile(JamAI::GetDifficultyProfile(LevelArg), Cfg.AI);
		Level = DifficultyArg;
	}
	if (!TuneArg.IsEmpty() && !JamAI::ApplyDifficultyTune(TCHAR_TO_UTF8(*TuneArg), Cfg.AI, Err, sizeof(Err)))
	{
		UE_LOG(LogJamAI, Error, TEXT("FAIL tournament bad -aitune: %s"), UTF8_TO_TCHAR(Err));
		return 2;
	}
	JamAI::EJamPlayerMode Mode = JamAI::EJamPlayerMode::PlayerBot;
	if (!JamAI::ParseMode(TCHAR_TO_UTF8(*ModeText), Mode))
	{
		UE_LOG(LogJamAI, Error, TEXT("FAIL tournament bad -mode=%s"), *ModeText);
		return 2;
	}
	FString Lo, Hi;
	if (!Seeds.Split(TEXT("-"), &Lo, &Hi)) { Lo = Hi = Seeds; }
	const int32 SeedLo = FCString::Atoi(*Lo);
	const int32 SeedHi = FCString::Atoi(*Hi);
	static char Line[8192];
	const FTCHARToUTF8 CartUtf8(*Cartridge);
	// lane A34: -player=novice|regular|good puts the human-like playtester in the human's slot (needs the jam sim) and prints
	// one thirdjam.playtest/1 line per match (the fun metrics) instead of the tournament line.
	FString PlayerArg;
	FParse::Value(*Params, TEXT("-player="), PlayerArg, false);
	if (!PlayerArg.IsEmpty())
	{
		JamAI::EPlaytester Kind = JamAI::EPlaytester::Regular;
		if (!JamAI::ParsePlaytester(TCHAR_TO_UTF8(*PlayerArg), Kind))
		{
			UE_LOG(LogJamAI, Error, TEXT("FAIL tournament bad -player=%s (novice | regular | good)"), *PlayerArg);
			return 2;
		}
		if (!Cart)
		{
			UE_LOG(LogJamAI, Error, TEXT("FAIL tournament -player needs -sim=jam (the playtester reads UJamSim's events)"));
			return 2;
		}
		const FTCHARToUTF8 LevelUtf8(*Level);
		// lane A72 (ask A3): -playersprint lets the regular and good players press sprint (off by default: the curves measured before stay comparable)
		const bool bPlayerSprint = FParse::Param(*Params, TEXT("playersprint"));
		for (int32 Seed = SeedLo; Seed <= SeedHi; ++Seed)
		{
			JamAI::FJamSimAdapter Sim(*Cart);   // lane A41: with the game mode's rule, zone and effect systems
			const JamAI::FJamPlaytestStats St = JamAI::RunPlaytestMatch(Sim, Cfg, static_cast<uint64_t>(Seed), Kind, MaxFrames, Cart->Game.Shot.ChargeFramesMax, bPlayerSprint,
				TraceEvery > 0 ? &JamTournamentLocal::PlaytestTraceToLog : nullptr, nullptr, TraceEvery);
			JamAI::FormatPlaytestJson(St, CartUtf8.Get(), LevelUtf8.Get(), Kind, Line, sizeof(Line));
			UE_LOG(LogJamAI, Display, TEXT("%s"), UTF8_TO_TCHAR(Line));
		}
		Cart->RemoveFromRoot();
		return 0;
	}
	for (int32 Seed = SeedLo; Seed <= SeedHi; ++Seed)
	{
		JamAI::FJamMatchStats St;
		if (Cart)
		{
			JamAI::FJamSimAdapter Sim(*Cart);   // lane A41: with the game mode's rule, zone and effect systems
			St = JamAI::RunMatch(Sim, Cfg, static_cast<uint64_t>(Seed), Mode, MaxFrames, 600, TraceEvery > 0 ? &JamTournamentLocal::TraceToLog : nullptr, nullptr, TraceEvery);
		}
		else
		{
			JamAI::FRefSim Sim;
			St = JamAI::RunMatch(Sim, Cfg, static_cast<uint64_t>(Seed), Mode, MaxFrames, 600, TraceEvery > 0 ? &JamTournamentLocal::TraceToLog : nullptr, nullptr, TraceEvery);
		}
		JamAI::FormatStatsJson(St, CartUtf8.Get(), JamAI::ModeName(Mode), Line, sizeof(Line));
		// the sim that produced the line, appended for run.mjs
		FString Out = UTF8_TO_TCHAR(Line);
		Out.LeftChopInline(1);
		Out += FString::Printf(TEXT(",\"sim\":\"%s\",\"difficulty\":\"%s\"}"), *SimName, *Level);
		UE_LOG(LogJamAI, Display, TEXT("%s"), *Out);
	}
	if (Cart) { Cart->RemoveFromRoot(); }
	return 0;
}
