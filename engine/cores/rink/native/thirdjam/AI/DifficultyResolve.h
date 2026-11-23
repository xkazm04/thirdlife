// Lane A3: the engine side of the difficulty resolution order (DifficultyProfile.h):
//   1. the profile of game.ai.difficulty (absent = pro),
//   2. the game.ai numbers the cartridge itself writes (read from UJamCartridge::RawJson: the loaded FJamAiConfig cannot tell
//      an absent key from one that equals the default),
//   3. the Designer's `values` (ai_speed_scale, ai_red_skill).
// Used by UJamBrain::ApplyCartridge (the game mode), the tournament commandlet and the bot tests.
#pragma once

#include "CoreMinimal.h"
#include "JamBotMatch.h"
#include "DifficultyProfile.h"

class UJamCartridge;

namespace JamAI
{
	struct FJamDifficultyResolution
	{
		EDifficulty Level = EDifficulty::Pro;
		bool bLevelWritten = false;        // game.ai.difficulty present in the cartridge
		TArray<FString> ExplicitKeys;      // game.ai.* numbers and values.ai_* that overrode the profile, in order applied
		FJamAIParams Params;
	};

	// DifficultyOverride (optional, "rookie" | "pro" | "all_star") replaces the cartridge's level, as if the cartridge
	// said so (sweeps, tests). Returns false only when the override is not a level name.
	JAMCORE_API bool ResolveDifficulty(const UJamCartridge& Cart, FJamDifficultyResolution& Out, const TCHAR* DifficultyOverride = nullptr);

	// JamAI::ToMatchConfig(Cart.Game) with the AI params resolved as above.
	JAMCORE_API FJamMatchConfig ToMatchConfigResolved(const UJamCartridge& Cart, const TCHAR* DifficultyOverride = nullptr);
}
