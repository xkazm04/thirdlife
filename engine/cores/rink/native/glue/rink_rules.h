// Third Life rink core: the rules sidecar of a thirdlife cartridge (lane K8's format, its lab reader engine/cores/rink/lab/lab_rules.cpp).
// A thirdlife cartridge is two files: <name>.cartridge.json (a thirdjam cartridge) and <name>.rules.json (schema "tl.rink.rules/1"):
//   "rules":  { "<key>": number | bool }            the switches of native/patches-thirdlife, set through the patches' own TlSetRule
//   "levels": { "rookie" | "pro" | "all_star": "k=v;k=v" }   thirdjam's difficulty tune keys (DifficultyProfile.cpp ApplyDifficultyTune) on
//             top of the level's profile
// Unknown keys are errors. The plain core (thirdjam, byte for byte) refuses any rules file: only the thirdlife core (built from
// thirdjam + native/patches-thirdlife, RINK_THIRDLIFE) has the switches.
#pragma once

#include "CoreMinimal.h"
#include "JamCartridge.h"
#include "JamAICore.h"
#include <string>

namespace RinkGlue
{
	struct FRules
	{
		bool bLoaded = false;
		std::string LevelTune[3];   // rookie, pro, all_star
		std::string Applied;        // "key=value,..." of the switches set
	};
	// Parses Text and sets the switches on Cart.Game.Tl. Returns "" or the error (nothing half-applied matters: the caller refuses the cartridge).
	std::string LoadRules(UJamCartridge& Cart, const FString& Text, FRules& Out);
	// The level's tune on top of the resolved AI params. Returns "" or the error.
	std::string ApplyLevelTune(const FRules& R, const char* Level, JamAI::FJamAIParams& P);
}
