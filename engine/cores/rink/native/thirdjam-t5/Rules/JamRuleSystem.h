// Lane A15 (C-0005 seam B): UJamRuleSystem, the only IJamRuleHook. The sim (lane A16) calls OnRuleEvent at every trigger
// (JamRuleHooks.h) and applies the actions it returns, in order, within the same frame. This class is pure data over
// game.rules.hooks: it evaluates the hooks in id order, honours every_frames / after_frame / team / score, and emits actions.
// It has no randomness and no clock; the same events in the same order give the same actions (hashes stay deterministic).
//
// Wire -> seam mapping (decided here, proposed to the Director in the A15 report):
//   `team` selectors: scoring = In.Team, conceding = the other team, any = -1 (both / none).
//   `score` reads the mirror this system keeps from OnGoal / OnScoreReached events (Value = the new score of In.Team) and from
//   its own AddScore actions; the host may correct it with SetScore every frame.
//   shrink_rink / grow_rink carry the fraction in the cartridge (0.1 = 10 %); the action's Value is the scale factor the sim
//   applies (0.9 / 1.1), as JamRuleHooks.h reads it.
//   announce: Text travels in FJamRuleActionOut::Text; the sim puts it on FJamSimEvent::Text of the "announce" event. The
//   last text is also kept here (GetLastAnnouncement) for hosts that show the scoreboard line themselves.
#pragma once

#include "CoreMinimal.h"
#include "UObject/Object.h"
#include "JamRuleHooks.h"
#include "JamCartridge.h"
#include "JamRuleSystem.generated.h"

JAMCORE_API DECLARE_LOG_CATEGORY_EXTERN(LogJamRules, Log, All);

UCLASS(BlueprintType)
class JAMCORE_API UJamRuleSystem : public UObject, public IJamRuleHook
{
	GENERATED_BODY()

public:
	// Takes the hooks of a loaded config (explicit ones and the variants the loader expanded), sorted by id. Resets the match state.
	void Init(const FJamGameConfig& Config);
	// New match (Restart): fire counts, score mirror and announcements back to zero; the hooks stay.
	void ResetMatch();

	// IJamRuleHook. Appends to Out (never clears it).
	virtual void OnRuleEvent(const FJamRuleEventIn& In, TArray<FJamRuleActionOut>& Out) override;

	// The score mirror the `score` conditions read. Updated from OnGoal / OnScoreReached and from AddScore actions; a host
	// that knows better (the game mode reading UJamSim::GetScore) may set it every frame.
	UFUNCTION(BlueprintCallable, Category = "Jam|Rules") void SetScore(int32 Team, int32 Score);
	UFUNCTION(BlueprintPure, Category = "Jam|Rules") int32 GetScore(int32 Team) const { return (Team == 0 || Team == 1) ? Scores[Team] : 0; }

	const TArray<FJamRuleHookConfig>& GetHooks() const { return Hooks; }
	UFUNCTION(BlueprintPure, Category = "Jam|Rules") int32 GetHookCount() const { return Hooks.Num(); }
	// How many times a hook fired this match (0 for an unknown id).
	UFUNCTION(BlueprintPure, Category = "Jam|Rules") int32 GetFireCount(const FString& HookId) const;
	UFUNCTION(BlueprintPure, Category = "Jam|Rules") int32 GetTotalFires() const { return TotalFires; }

	// The last announce text and the frame it was emitted (-1 = none this match).
	const FString& GetLastAnnouncement() const { return LastAnnouncement; }
	UFUNCTION(BlueprintPure, Category = "Jam|Rules") int64 GetLastAnnouncementFrame() const { return LastAnnouncementFrame; }
	// Announce texts emitted since the last call (for a host that broadcasts "announce" itself when the sim does not).
	void TakePendingAnnouncements(TArray<FString>& Out) { Out.Append(PendingAnnouncements); PendingAnnouncements.Reset(); }

	// FNV-1a 64 over fire counts and the score mirror (tests: same events = same hash).
	uint64 StateHash() const;

	// ---- pure helpers (tests call them) ----
	// scoring -> EventTeam, conceding -> the other team (-1 when EventTeam is -1), any / none -> -1.
	static int32 ResolveTeam(FName Selector, int32 EventTeam);
	// The `score` condition against a team's score and the other team's score.
	static bool ScoreMatches(const FJamRuleScoreCondition& C, int32 TeamScore, int32 OtherScore);
	// The seam Value for shrink_rink / grow_rink from the cartridge fraction: 1 - f / 1 + f. Other actions return Value unchanged.
	static float SeamValue(FName Do, bool bHasValue, double Value);

private:
	bool HookMatches(const FJamRuleHookConfig& H, const FJamRuleEventIn& In, int32& OutTeam) const;

	UPROPERTY() TArray<FJamRuleHookConfig> Hooks;
	TArray<int32> FireCounts;
	int32 Scores[2] = { 0, 0 };
	int32 TotalFires = 0;
	FString LastAnnouncement;
	int64 LastAnnouncementFrame = -1;
	TArray<FString> PendingAnnouncements;
};
