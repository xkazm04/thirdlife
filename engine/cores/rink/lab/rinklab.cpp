// Third Life rink core, LAB (lane K4 "reference"): rinklab.exe, the measurement runner. Measurement only; never in a game.
//
//   rinklab match <content dir> -cartridge=hockey.regular -seeds=1-200 -difficulty=pro -player=regular [-playersprint]
//                 [-remove=verb,verb] [-only=verb,verb] [-signal=defend|space|pass|praise] [-trace=N]
//       thirdjam's playtester match (AI/JamPlaytester.cpp:809 RunPlaytestMatch, the same setup as the tournament commandlet's
//       -player branch, AI/JamTournamentCommandlet.cpp:136-168) on FLabSimAdapter: per seed thirdjam's own thirdjam.playtest/1
//       line, then the lab's rinklab.stats/1 line. -remove takes verbs from the human's hand; -only keeps skating, the stick's
//       aim, the draw and the named verbs. Verbs: lab_filter.h EVerb (idle = no input at all).
//   rinklab gym <content dir> [-cartridge=hockey.regular]
//       the tempo probes: scripted scenes on UJamSim (2 v 2 roster of the same cartridge, every other number unchanged),
//       one rinklab.gym/1 JSON line per probe.
#include "CoreMinimal.h"
#include "JamCartridge.h"
#include "JamSimAdapter.h"
#include "JamPlaytester.h"
#include "DifficultyResolve.h"
#include "DifficultyProfile.h"
#include "lab_filter.h"
#include "lab_gym.h"
#include "lab_plan.h"
#include "lab_rules.h"

#include <cstdio>
#include <cstring>
#include <cstdlib>
#include <string>

namespace
{
	std::string Arg(int argc, wchar_t** argv, const char* Key, const char* Def = "")
	{
		const std::string K = std::string("-") + Key + "=";
		for (int i = 3; i < argc; ++i)
		{
			const FTCHARToUTF8 A(argv[i]);
			const std::string S(A.Get());
			if (S.rfind(K, 0) == 0) return S.substr(K.size());
		}
		return Def;
	}
	bool Flag(int argc, wchar_t** argv, const char* Key)
	{
		const std::string K = std::string("-") + Key;
		for (int i = 3; i < argc; ++i) { const FTCHARToUTF8 A(argv[i]); if (K == A.Get()) return true; }
		return false;
	}

	// thirdjam's playtest trace line (JamTournamentCommandlet.cpp:26-35, PlaytestTraceToLog): FormatTrace's "TRACE f=..." line of the
	// frame, then since / ht / car / lt / fo / pk as the commandlet prints them.
	void LabTrace(void* Ctx, const JamAI::FJamAIWorld& W, const JamAI::FJamAIInput* In, const JamAI::FJamBrain& Brain, int64_t SinceTouch, bool bHumanTouch)
	{
		(void)Ctx;
		static char Buf[4096];
		int N = JamAI::FormatTrace(W, In, Brain, Buf, sizeof(Buf));
		if (N < 0 || N > 3900) { N = 0; }
		std::snprintf(Buf + N, sizeof(Buf) - N, " since=%lld ht=%d car=%d lt=%d fo=%d pk=%d", static_cast<long long>(SinceTouch), bHumanTouch ? 1 : 0, W.Carrier, W.PuckLastTouch,
			W.bFaceoffPhase ? 1 : 0, W.NumPickups);
		std::printf("%s\n", Buf);
	}

	int RunMatches(int argc, wchar_t** argv)
	{
		const std::string Cartridge = Arg(argc, argv, "cartridge", "hockey.regular");
		const std::string Seeds = Arg(argc, argv, "seeds", "1-1");
		const std::string Diff = Arg(argc, argv, "difficulty", "");
		const std::string Player = Arg(argc, argv, "player", "regular");
		const bool bSprint = Flag(argc, argv, "playersprint");
		std::string Err;
		uint32_t Remove = Lab::ParseVerbs(Arg(argc, argv, "remove").c_str(), Err);
		if (!Err.empty()) { std::fprintf(stderr, "FAIL rinklab: %s\n", Err.c_str()); return 2; }
		const std::string Only = Arg(argc, argv, "only", "");
		if (!Only.empty())
		{
			const uint32_t Keep = Lab::ParseVerbs(Only.c_str(), Err);
			if (!Err.empty()) { std::fprintf(stderr, "FAIL rinklab: %s\n", Err.c_str()); return 2; }
			Remove |= Lab::AllVerbs() & ~(Keep | Lab::V_Stick | Lab::V_Draw);
			if (Keep & Lab::V_Shield) Remove &= ~Lab::V_Shield;
		}
		const std::string Signal = Arg(argc, argv, "signal", "");
		const int SignalKind = Signal == "defend" ? 1 : Signal == "space" ? 2 : Signal == "pass" ? 3 : Signal == "praise" ? 4 : 0;
		if (!Signal.empty() && SignalKind == 0) { std::fprintf(stderr, "FAIL rinklab: bad -signal=%s (defend | space | pass | praise)\n", Signal.c_str()); return 2; }
		JamAI::EPlaytester Kind = JamAI::EPlaytester::Regular;
		if (!JamAI::ParsePlaytester(Player.c_str(), Kind)) { std::fprintf(stderr, "FAIL rinklab: bad -player=%s\n", Player.c_str()); return 2; }
		// lane K8: -plan=novice|regular|good seats the planning hand (lab_plan.h) in the human's slot; -plancheck verifies its copies of the sim.
		const std::string PlanName = Arg(argc, argv, "plan", "");
		Lab::FPlanProfile PlanProfile;
		if (!PlanName.empty() && !Lab::ParsePlanProfile(PlanName.c_str(), PlanProfile)) { std::fprintf(stderr, "FAIL rinklab: bad -plan=%s (novice | regular | good)\n", PlanName.c_str()); return 2; }
		const int PlanHorizon = std::atoi(Arg(argc, argv, "planhorizon", "0").c_str());
		if (PlanHorizon > 0) PlanProfile.Horizon = PlanHorizon;
		// tuning arms of the hand's limits (measurement of the hand itself; the profiles in lab_plan.cpp are what the tables use)
		if (!Arg(argc, argv, "planreact").empty()) PlanProfile.ReactionFrames = std::atoi(Arg(argc, argv, "planreact").c_str());
		if (!Arg(argc, argv, "plandecide").empty()) PlanProfile.DecideEvery = std::atoi(Arg(argc, argv, "plandecide").c_str());
		if (!Arg(argc, argv, "plannoise").empty()) PlanProfile.JudgeNoise = std::atof(Arg(argc, argv, "plannoise").c_str());
		if (!Arg(argc, argv, "planpress").empty()) PlanProfile.PressPerSec = std::atoi(Arg(argc, argv, "planpress").c_str());
		Lab::FPlanHand PlanHand;
		TArray<FString> Errors;
		UJamCartridge* Cart = UJamCartridge::LoadFromFile(UJamCartridge::ResolveCartridgePath(FString(Cartridge.c_str())), Errors);
		if (!Cart) { std::fprintf(stderr, "FAIL rinklab: cartridge %s does not load\n", Cartridge.c_str()); return 2; }
		Cart->AddToRoot();
		// lane K8: the thirdlife rules sidecar (<cartridge>.rules.json) and an experiment's arms (-tl=, -tune=); a cartridge without one is plain thirdjam.
		Lab::FRulesFile Rules;
		{
			const std::string E = Lab::LoadRules(*Cart, Cartridge, Arg(argc, argv, "tl"), Rules);
			if (!E.empty()) { std::fprintf(stderr, "FAIL rinklab: %s\n", E.c_str()); return 2; }
		}
		// The tournament commandlet's setup, line for line (JamTournamentCommandlet.cpp:94-103).
		JamAI::FJamMatchConfig Cfg;
		Cfg.SetRegular();
		JamAI::FJamDifficultyResolution Res;
		const FString DiffT(Diff.c_str());
		JamAI::ResolveDifficulty(*Cart, Res, Diff.empty() ? nullptr : *DiffT);
		Cfg = JamAI::ToMatchConfig(Cart->Game);
		Cfg.AI = Res.Params;
		const char* Level = JamAI::DifficultyName(Res.Level);
		{
			const std::string E = Lab::ApplyLevelTune(Rules, Level, Arg(argc, argv, "tune"), Cfg.AI);
			if (!E.empty()) { std::fprintf(stderr, "FAIL rinklab: %s\n", E.c_str()); return 2; }
		}
		int Lo = 1, Hi = 1;
		if (std::sscanf(Seeds.c_str(), "%d-%d", &Lo, &Hi) < 2) Hi = Lo;
		static char Line[8192];
		std::string RemoveNames;
		for (int b = 0; b < 31; ++b) if (Remove & (1u << b)) { if (!RemoveNames.empty()) RemoveNames += ","; RemoveNames += Lab::VerbName(1u << b); }
		for (int Seed = Lo; Seed <= Hi; ++Seed)
		{
			Lab::FLabSimAdapter Sim(*Cart);
			Sim.Remove = Remove;
			Sim.SignalKind = SignalKind;
			Sim.bDebugGoals = Flag(argc, argv, "debuggoals");
			if (!PlanName.empty())
			{
				PlanHand.Reset(PlanProfile, static_cast<uint64_t>(Seed));
				PlanHand.Remove = Remove;
				PlanHand.bCheckClone = Flag(argc, argv, "plancheck");
				Sim.Plan = &PlanHand;
			}
			const int TraceEvery = std::atoi(Arg(argc, argv, "trace", "0").c_str());
			const JamAI::FJamPlaytestStats St = JamAI::RunPlaytestMatch(Sim, Cfg, static_cast<uint64_t>(Seed), Kind, 36000, Cart->Game.Shot.ChargeFramesMax, bSprint,
				TraceEvery > 0 ? &LabTrace : nullptr, nullptr, TraceEvery);
			JamAI::FormatPlaytestJson(St, Cartridge.c_str(), Level, Kind, Line, sizeof(Line));
			std::printf("%s\n", Line);
			std::printf("{\"tool\":\"rinklab.cell/1\",\"seed\":%d,\"difficulty\":\"%s\",\"player\":\"%s\",\"sprint\":%s,\"remove\":\"%s\",\"signal\":\"%s\",\"plan\":\"%s\",\"stats\":%s%s%s}\n",
				Seed, Level, Player.c_str(), bSprint ? "true" : "false", RemoveNames.c_str(), Signal.c_str(), PlanName.c_str(), Lab::StatsJson(Sim.Stats).c_str(),
				PlanName.empty() ? "" : ",\"planstats\":", PlanName.empty() ? "" : Lab::PlanStatsJson(PlanHand.Stats).c_str());
		}
		std::fflush(stdout);
		Cart->RemoveFromRoot();
		return 0;
	}
}

int wmain(int argc, wchar_t** argv)
{
	if (argc < 3) { std::fprintf(stderr, "usage: rinklab match|gym <content dir> [args]\n"); return 2; }
	JamShimSetContentDir(FString(argv[2]));
	const FTCHARToUTF8 Mode(argv[1]);
	if (std::strcmp(Mode.Get(), "match") == 0) return RunMatches(argc, argv);
	if (std::strcmp(Mode.Get(), "gym") == 0) return Lab::RunGym(Arg(argc, argv, "cartridge", "hockey.regular").c_str(), Arg(argc, argv, "tl").c_str());
	std::fprintf(stderr, "FAIL rinklab: unknown mode %s\n", Mode.Get());
	return 2;
}
