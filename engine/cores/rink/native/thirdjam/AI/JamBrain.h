// Lane A2: UObject faces of the bot brain and the scripted player bot. The logic is the engine-free
// JamAI::FJamBrain / FJamPlayerBot (JamAICore.h); these classes hold it for the game mode.
//
// SEAM (lane A1): UJamSim will own one UJamBrain and call Think once per sim step with the world view it builds
// (an IJamAISim adapter, see JamBotMatch.h), then copy the FJamAIInput of every bot skater into its FJamInput.
// The human's slot is never written by the brain. Other modules reach this header only after JamCore.Build.cs adds
// the AI folder to PublicIncludePaths (A1 owns that file; requested in the A2 report).
#pragma once

#include "CoreMinimal.h"
#include "UObject/Object.h"
#include "JamAICore.h"
#include "JamBrain.generated.h"

class UJamCartridge;

UCLASS()
class JAMCORE_API UJamBrain : public UObject
{
	GENERATED_BODY()

public:
	// game.ai (DEFAULTS.md values); call ApplyParams after changing them, then ResetBrain at match start.
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Jam|AI")
	float YieldMarginM = 2.f;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Jam|AI")
	float YieldRadiusM = 15.f;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Jam|AI")
	float HoldRadiusM = 4.5f;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Jam|AI")
	float SpeedScale = 1.f;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Jam|AI")
	float RedSkill = 1.f;

	// lane A3: game.ai.difficulty as resolved by ApplyCartridge ("rookie" | "pro" | "all_star").
	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Jam|AI")
	FName Difficulty = TEXT("pro");

	// lane A3: the whole game.ai resolution (difficulty profile -> explicit game.ai numbers -> Designer values) plus the sim
	// facts the skills read; also sets the five properties above. Call it instead of setting them, then ResetBrain.
	// DifficultyOverride replaces the cartridge's level (nullptr = the cartridge's own).
	void ApplyCartridge(const UJamCartridge& Cart, const TCHAR* DifficultyOverride = nullptr);

	void ApplyParams();
	void ResetBrain();
	// Writes Out[i] for every skater but W.PlayerIndex.
	void Think(const JamAI::FJamAIWorld& W, JamAI::FJamAIInput* Out);

	UFUNCTION(BlueprintPure, Category = "Jam|AI")
	bool IsStalled() const { return Core.IsStalled(); }

	UFUNCTION(BlueprintPure, Category = "Jam|AI")
	int32 GetStallCount() const { return Core.StallCount(); }

	const JamAI::FJamBrain& GetCore() const { return Core; }
	// Lane A95: the resolved params, for tests that replay an older profile (JamAI::PreA95Tune); call ResetBrain after (it re-applies the five properties above).
	JamAI::FJamAIParams& EditParams() { return Core.Params; }

private:
	JamAI::FJamBrain Core;
};

// Scripted input for the human's skater; tests and tournaments only.
UCLASS()
class JAMCORE_API UJamPlayerBot : public UObject
{
	GENERATED_BODY()

public:
	// bot_hockey.gd (true) or the bot_hockey_ai.gd variant (false: shoots inside 22 m, no peel to the middle).
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Jam|AI")
	bool bWinnerVariant = true;

	JamAI::FJamAIInput Think(const JamAI::FJamAIWorld& W) const;
};
