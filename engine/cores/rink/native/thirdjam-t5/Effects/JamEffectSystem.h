// Lane A14 (C-0005): UJamEffectSystem, the only IJamModifierSource. Owns the active modifiers (stack policy, deterministic order
// by frame then id), the triggers (the sim's frame events: goal, check, knockdown; the zone system's zone_enter / zone_exit, read
// from the sim's IJamZoneSource (lane A41: the sim never carries zone events itself); period changes; pickup takes; a live Director's
// Call or Designer cut; the rule system's ApplyModifier requests) and the pickup spawner (table-driven, the seeded stream, optional
// zone, max_on_ice). Engine-free: no world, no bus, no actors; the host steps it right after UJamSim::Step and UJamZoneSystem::Update
// (that order: the zone events of the frame must be fresh) and hands its events to the bus, AJamPickupActor draws the pickups.
// Same cartridge + seed + inputs = same StateHash().
//
// Order inside one frame: the sim collected last frame's modifiers at the start of its Step; this Step then expires, applies and
// spawns for the frame that just ran, so a modifier added here is in force from the next sim frame (deterministic one-frame latency).
#pragma once

#include "CoreMinimal.h"
#include "UObject/Object.h"
#include "JamModifiers.h"
#include "JamRandom.h"
#include "JamSim.h"
#include "JamEffectTypes.h"
#include "JamEffectSystem.generated.h"

JAMCORE_API DECLARE_LOG_CATEGORY_EXTERN(LogJamEffects, Log, All);

UCLASS(BlueprintType)
class JAMCORE_API UJamEffectSystem : public UObject, public IJamModifierSource
{
	GENERATED_BODY()

public:
	static constexpr double PickupRadiusM = 0.5;
	static constexpr double PickupBoardMarginM = 1.5;
	static constexpr uint64 RngStream = 0xA14;   // its own PCG32 stream off the cartridge seed: the sim's draws are untouched

	// Binds to a sim (SetModifierSource(this)), reads game.effects / pickups / rink.zones from the cartridge text, resets the match
	// state and fires period_start effects for TAKE 1. Errors (unknown stat names) are returned and the entry is skipped.
	bool Init(UJamSim* InSim, const FString& RawCartridgeJson, TArray<FString>& OutErrors);
	// New match, same config: call after UJamSim::Restart().
	void Restart();
	// R-0003 3: a Director's Call or a Designer cut applied live: re-reads the lists (active modifiers keep running) and fires the
	// `director` trigger. Returns false (and logs) when the text does not parse; the old lists then stay.
	bool ApplyLiveConfig(const FString& RawCartridgeJson);

	// Once per frame, right after UJamSim::Step and the host's UJamZoneSystem::Update (the zone_enter / zone_exit triggers read that
	// system's frame events through the sim's zone source; the puck's zone events fire puck / rink / everyone targets, a skater's fire
	// self / own_team / other_team / everyone with the skater as self).
	void Step();

	// IJamModifierSource: every modifier active for Frame, in (start frame, id) order.
	virtual void CollectModifiers(int32 Frame, TArray<FJamActiveModifier>& Out) const override;

	// Starts an effect by id (a cartridge effect or a built-in) as if its trigger fired: SourceSkater -1 and Team -1 mean "nobody"
	// (self / own_team / other_team then widen to everyone). FramesOverride > 0 replaces the definition's duration; bHasMagnitude
	// applies a pickup magnitude. The rule system's ApplyModifier and the console use this. False for an unknown id.
	UFUNCTION(BlueprintCallable, Category = "Jam|Effects")
	bool RequestEffect(FName EffectId, int32 SourceSkater, int32 Team, int32 FramesOverride = 0, bool bHasMagnitude = false, double Magnitude = 1.0);

	// Places a pickup of a kind (built-in or effect id) now; Pos outside the boards = a seeded spot. False for an unknown kind.
	UFUNCTION(BlueprintCallable, Category = "Jam|Effects")
	bool SpawnPickup(FName Kind, FVector2D Pos, int32 PickupIndex = -1);

	// Events produced by the last Step (cleared at its start): pickup_spawn, pickup_take, effect_start, effect_end. Where in rink metres.
	const TArray<FJamSimEvent>& GetFrameEvents() const { return FrameEvents; }
	const TArray<FJamActiveModifier>& GetActive() const { return Active; }
	const TArray<FJamPickupOnIce>& GetPickups() const { return OnIce; }
	// The HUD rows (rebuilt every Step).
	UFUNCTION(BlueprintPure, Category = "Jam|Effects") const TArray<FJamEffectHudEntry>& GetHudFeed() const { return Hud; }
	// The rows that touch one skater (the human's strip).
	UFUNCTION(BlueprintPure, Category = "Jam|Effects") TArray<FJamEffectHudEntry> GetHudFeedFor(int32 Skater) const;
	// The kind of the newest effect covering a skater (IJamSkaterVisual::SetBoost), NAME_None when none.
	UFUNCTION(BlueprintPure, Category = "Jam|Effects") FName GetBoostKindFor(int32 Skater) const;
	const FJamEffectsConfig& GetConfig() const { return Config; }
	UJamSim* GetSim() const { return Sim; }

	// FNV-1a 64 over the active modifiers, the pickups on the ice, the spawn timers, the id counter and the rng (the Determinism test).
	uint64 StateHash() const;
	int32 GetEffectsStarted() const { return EffectsStarted; }
	int32 GetPickupsTaken() const { return PickupsTaken; }
	int32 GetPickupsSpawned() const { return PickupsSpawned; }

private:
	struct FTimer { int64 NextSpawnFrame = 0; };

	void ResetState();
	void Fire(EJamEffectTrigger Trigger, int32 SourceSkater, int32 Team, FName ZoneId = NAME_None);
	bool Apply(const FJamEffectDef& Def, int32 SourceSkater, int32 Team, int32 Frames, bool bHasMagnitude, double Magnitude);
	void StepPickups();
	bool PickSpot(const FJamPickupDef* Def, FVector2D& Out);
	void ExpireAndRebuildHud();
	void Emit(FName Name, int32 Who, const FVector2D& Where, float Strength, FName Kind);
	int32 TeamOf(int32 Skater) const;
	FVector2D PosOf(int32 Skater) const;

	UPROPERTY(Transient) TObjectPtr<UJamSim> Sim;
	FJamEffectsConfig Config;
	TArray<FJamActiveModifier> Active;
	TArray<int64> ActiveStart;           // start frame per Active entry (the order key)
	TArray<int32> ActiveDuration;        // for the HUD bar
	TArray<FJamPickupOnIce> OnIce;
	TArray<FTimer> Timers;
	TArray<FJamSimEvent> FrameEvents;
	// Events emitted outside Step (Init / Restart period_start effects, ApplyLiveConfig's director trigger): delivered with the next Step.
	TArray<FJamSimEvent> PendingEvents;
	bool bInStep = false;
	TArray<FJamEffectHudEntry> Hud;
	FJamRandom Rng;
	int64 Frame = 0;
	int32 NextId = 1;
	int32 LastScore[2] = { 0, 0 };
	int32 LastPeriod = 0;
	int32 EffectsStarted = 0;
	int32 PickupsTaken = 0;
	int32 PickupsSpawned = 0;
};
