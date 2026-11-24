// Third Life rink core, LAB (lane K8 "balance"): the thirdlife rules sidecar. Measurement only (the lab's reader; the shipped core's reader is lane K1's).
//
// A cartridge of the thirdlife variant is two files side by side in <content>/Cartridges/:
//   <name>.cartridge.json   a thirdjam cartridge, valid for thirdjam's own schema: every change that is a cartridge NUMBER lives here;
//   <name>.rules.json       what thirdjam's schema cannot say (schema "tl.rink.rules/1"; unknown keys are errors):
//       "rules":  { "<key>": number | bool }   the switches of native/patches-thirdlife (FTlRules, set through the patches' own TlSetRule);
//       "levels": { "rookie" | "pro" | "all_star": "k=v;k=v" }   thirdjam's own difficulty tune keys (AI/DifficultyProfile.cpp ApplyDifficultyTune),
//                 applied on top of the level's profile: the level table of this cartridge.
// A cartridge without a rules file is plain thirdjam. A rules file needs the thirdlife runner (rinklab-thirdlife.exe): the reference runner refuses it.
// -tl=key=value,key=value (rules) and -tune="k=v;k=v" (the level's tune, appended) are an experiment's arms on top of the files.
#pragma once

#include "CoreMinimal.h"
#include "JamCartridge.h"
#include "JamAICore.h"
#include <string>

namespace Lab
{
	struct FRulesFile
	{
		bool bFound = false;
		std::string LevelTune[3];   // rookie, pro, all_star
		std::string Applied;        // "key=value,..." of the switches set (for the cell line)
	};
	// Fills Cart.Game.Tl and Out from the sidecar of CartridgeName (if any) and the overrides. Returns "" or the error.
	std::string LoadRules(UJamCartridge& Cart, const std::string& CartridgeName, const std::string& Overrides, FRulesFile& Out);
	// Applies the level's tune (the file's, then Extra) to the resolved AI params. Returns "" or the error.
	std::string ApplyLevelTune(const FRulesFile& R, const char* Level, const std::string& Extra, JamAI::FJamAIParams& P);
}
