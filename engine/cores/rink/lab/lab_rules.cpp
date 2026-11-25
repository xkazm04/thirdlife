// Third Life rink core, LAB (lane K8 "balance"): see lab_rules.h. Measurement only.
#include "lab_rules.h"

#include "JamJson.h"
#include "DifficultyProfile.h"
#include "Misc/FileHelper.h"
#include "Misc/Paths.h"

#include <cstdio>
#include <cstdlib>
#include <cstring>

namespace Lab
{
	namespace
	{
		std::string U8(const FString& S) { const FTCHARToUTF8 A(*S); return std::string(A.Get()); }
		std::string SetOne(UJamCartridge& Cart, const std::string& Key, double Value, FRulesFile& Out)
		{
#if defined(RINK_THIRDLIFE)
			if (!TlSetRule(Cart.Game.Tl, Key.c_str(), Value)) return "unknown rule \"" + Key + "\" (not a switch of native/patches-thirdlife)";
			char B[96];
			std::snprintf(B, sizeof(B), "%s%s=%g", Out.Applied.empty() ? "" : ",", Key.c_str(), Value);
			Out.Applied += B;
			return "";
#else
			(void)Cart; (void)Value; (void)Out;
			return "rule \"" + Key + "\" needs the thirdlife runner (rinklab-thirdlife.exe: rink.sh lab-build-thirdlife)";
#endif
		}
	}

	std::string LoadRules(UJamCartridge& Cart, const std::string& CartridgeName, const std::string& Overrides, FRulesFile& Out)
	{
		Out = FRulesFile();
		FString Path = UJamCartridge::ResolveCartridgePath(FString(CartridgeName.c_str()));
		const FString Suffix(TEXT(".cartridge.json"));
		if (Path.EndsWith(Suffix)) Path = Path.LeftChop(Suffix.Len()) + TEXT(".rules.json");
		else Path = Path + TEXT(".rules.json");
		FString Text;
		if (FPaths::FileExists(Path) && FFileHelper::LoadFileToString(Text, *Path))
		{
			Out.bFound = true;
			FString Err;
			const TSharedPtr<FJamJson> Root = FJamJson::Parse(Text, Err);
			if (!Root.IsValid() || !Root->IsObject()) return "rules file " + U8(Path) + ": " + U8(Err);
			for (const auto& KV : Root->Object)
			{
				const std::string K = U8(KV.Key);
				if (K == "schema") { if (!KV.Value->IsString() || U8(KV.Value->String) != "tl.rink.rules/1") return "rules file: schema must be \"tl.rink.rules/1\""; }
				else if (K == "title" || K == "notes") { if (!KV.Value->IsString()) return "rules file: " + K + " must be a string"; }
				else if (K == "rules")
				{
					if (!KV.Value->IsObject()) return "rules file: rules must be an object";
					for (const auto& RV : KV.Value->Object)
					{
						if (!RV.Value->IsNumber() && !RV.Value->IsBool()) return "rules file: rule " + U8(RV.Key) + " must be a number or a bool";
						const std::string E = SetOne(Cart, U8(RV.Key), RV.Value->IsBool() ? (RV.Value->Bool ? 1.0 : 0.0) : RV.Value->Number, Out);
						if (!E.empty()) return E;
					}
				}
				else if (K == "levels")
				{
					if (!KV.Value->IsObject()) return "rules file: levels must be an object";
					for (const auto& LV : KV.Value->Object)
					{
						const std::string L = U8(LV.Key);
						const int At = L == "rookie" ? 0 : L == "pro" ? 1 : L == "all_star" ? 2 : -1;
						if (At < 0 || !LV.Value->IsString()) return "rules file: levels." + L + " must be rookie | pro | all_star with a tune string";
						Out.LevelTune[At] = U8(LV.Value->String);
					}
				}
				else return "rules file: unknown key \"" + K + "\"";
			}
		}
		// -tl=key=value,key=value
		size_t At = 0;
		while (At < Overrides.size())
		{
			size_t Comma = Overrides.find(',', At);
			if (Comma == std::string::npos) Comma = Overrides.size();
			const std::string Pair = Overrides.substr(At, Comma - At);
			At = Comma + 1;
			if (Pair.empty()) continue;
			const size_t Eq = Pair.find('=');
			if (Eq == std::string::npos) return "bad -tl pair \"" + Pair + "\" (key=value)";
			const std::string E = SetOne(Cart, Pair.substr(0, Eq), std::atof(Pair.substr(Eq + 1).c_str()), Out);
			if (!E.empty()) return E;
		}
		return "";
	}

	std::string ApplyLevelTune(const FRulesFile& R, const char* Level, const std::string& Extra, JamAI::FJamAIParams& P)
	{
		const std::string L(Level ? Level : "");
		const int At = L == "rookie" ? 0 : L == "all_star" ? 2 : 1;
		std::string Tune = R.LevelTune[At];
		if (!Extra.empty()) Tune += (Tune.empty() ? "" : ";") + Extra;
		if (Tune.empty()) return "";
		char Err[256] = {};
		if (!JamAI::ApplyDifficultyTune(Tune.c_str(), P, Err, sizeof(Err))) return std::string("level tune: ") + Err;
		return "";
	}
}
