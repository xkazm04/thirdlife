// Third Life rink core: see rink_rules.h. The parse follows lane K8's lab reader (engine/cores/rink/lab/lab_rules.cpp) key for key.
#include "rink_rules.h"

#include "JamJson.h"
#include "DifficultyProfile.h"
#include <cstdio>

namespace RinkGlue
{
	namespace
	{
		std::string U8(const FString& S) { const FTCHARToUTF8 A(*S); return std::string(A.Get()); }
		std::string SetOne(UJamCartridge& Cart, const std::string& Key, double Value, FRules& Out)
		{
#if defined(RINK_THIRDLIFE)
			if (!TlSetRule(Cart.Game.Tl, Key.c_str(), Value)) return "unknown rule \"" + Key + "\" (not a switch of native/patches-thirdlife)";
			char B[96];
			std::snprintf(B, sizeof(B), "%s%s=%g", Out.Applied.empty() ? "" : ",", Key.c_str(), Value);
			Out.Applied += B;
			return "";
#else
			(void)Cart; (void)Value; (void)Out;
			return "rule \"" + Key + "\" needs the thirdlife core (RinkCoreThirdlife: engine/tools/rink.sh build thirdlife)";
#endif
		}
	}

	std::string LoadRules(UJamCartridge& Cart, const FString& Text, FRules& Out)
	{
		Out = FRules();
		FString Err;
		const TSharedPtr<FJamJson> Root = FJamJson::Parse(Text, Err);
		if (!Root.IsValid() || !Root->IsObject()) return "rules file: " + U8(Err);
		bool bSchema = false;
		for (const auto& KV : Root->Object)
		{
			const std::string K = U8(KV.Key);
			if (K == "schema") { if (!KV.Value->IsString() || U8(KV.Value->String) != "tl.rink.rules/1") return "rules file: schema must be \"tl.rink.rules/1\""; bSchema = true; }
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
		if (!bSchema) return "rules file: no schema (want \"tl.rink.rules/1\")";
		Out.bLoaded = true;
		return "";
	}

	std::string ApplyLevelTune(const FRules& R, const char* Level, JamAI::FJamAIParams& P)
	{
		const std::string L(Level ? Level : "");
		const int At = L == "rookie" ? 0 : L == "all_star" ? 2 : 1;
		if (R.LevelTune[At].empty()) return "";
		char Err[256] = {};
		if (!JamAI::ApplyDifficultyTune(R.LevelTune[At].c_str(), P, Err, sizeof(Err))) return std::string("level tune: ") + Err;
		return "";
	}
}
