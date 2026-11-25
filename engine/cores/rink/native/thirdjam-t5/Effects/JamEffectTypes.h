// Lane A14 (C-0005 section 4): the data side of composable effects. game.effects[], the extended game.pickups[] and the rink.zones
// geometry a pickup may be restricted to, read from the cartridge's raw JSON (the schema already validated keys, enums and ranges;
// UJamCartridge::Validate mirrors the cross-field checks). The five built-in pickup kinds are shipped effect definitions
// (Game/Content/Designer/builtin-effects.json, embedded as BuiltinEffectsData.inl) merged under every cartridge.
// Durations are frames. Absent value = the default written here, never 0 by accident.
#pragma once

#include "CoreMinimal.h"
#include "JamModifiers.h"
#include "JamEffectTypes.generated.h"

struct FJamJson;

// game.effects[].trigger (schema spelling in JamEffects::TriggerName).
enum class EJamEffectTrigger : uint8 { Pickup, GoalFor, GoalAgainst, CheckLanded, CheckReceived, PeriodStart, ZoneEnter, ZoneExit, Director, Count };
// game.effects[].stack
enum class EJamEffectStack : uint8 { Refresh, Extend, Ignore };

struct JAMCORE_API FJamEffectStat
{
	EJamStat Stat = EJamStat::SkaterSpeed;
	double Multiply = 1.0;
	double Add = 0.0;
};

// One game.effects[] entry (or a built-in).
struct JAMCORE_API FJamEffectDef
{
	FName Id;
	FName Kind = TEXT("custom");
	EJamTarget Target = EJamTarget::Self;
	int32 DurationFrames = 300;
	TArray<FJamEffectStat> Stats;
	EJamEffectTrigger Trigger = EJamEffectTrigger::Pickup;
	FName Zone;             // zone_enter / zone_exit only; NAME_None = any zone
	EJamEffectStack Stack = EJamEffectStack::Refresh;
	FName Icon;             // NAME_None until Finish() fills the kind's default
	bool bBuiltin = false;
	// Built-ins only: the stats whose Multiply is the pickup magnitude (or 1 / magnitude).
	TArray<FName> MagnitudeStats;
	TArray<FName> InverseMagnitudeStats;

	// The modifier stats for a pickup magnitude (bHasMagnitude false = as written). Built-ins: magnitude replaces the marked
	// multipliers; custom effects: multiply' = 1 + (multiply - 1) * magnitude, add' = add * magnitude; both clamped to 0.25..4.
	void BuildStats(bool bHasMagnitude, double Magnitude, TArray<FJamStatModifier>& Out) const;
};

// One game.pickups[] entry.
struct JAMCORE_API FJamPickupDef
{
	FName Kind;                 // a built-in or an effect id
	int32 SpawnEveryFrames = 600;
	int32 DurationFrames = 300;
	bool bHasMagnitude = false;
	double Magnitude = 1.0;
	FName Zone;                 // NAME_None = anywhere
	int32 MaxOnIce = 1;
};

// game.rink.zones[] geometry (lane A15's object; only what the spawner needs).
struct JAMCORE_API FJamZoneDef
{
	FName Id;
	bool bCircle = false;
	double X = 0, Z = 0, W = 0, D = 0, R = 0;
	bool Contains(const FVector2D& P) const
	{
		if (bCircle) return FVector2D::DistSquared(P, FVector2D(X, Z)) <= R * R;
		return FMath::Abs(P.X - X) <= W * 0.5 && FMath::Abs(P.Y - Z) <= D * 0.5;
	}
};

struct JAMCORE_API FJamEffectsConfig
{
	TArray<FJamEffectDef> Effects;   // the cartridge's own; built-ins are not copied here
	TArray<FJamPickupDef> Pickups;
	TArray<FJamZoneDef> Zones;

	// The cartridge's effect by id, else the built-in, else null.
	const FJamEffectDef* Find(FName Id) const;
	const FJamZoneDef* FindZone(FName Id) const;

	// Reads game.effects, game.pickups and game.rink.zones from a validated cartridge text. False (and OutErrors, "at <pointer>: ...")
	// only for what the schema cannot see: a stat name the seam does not know.
	static bool Parse(const FString& RawCartridgeJson, FJamEffectsConfig& Out, TArray<FString>& OutErrors);
	static bool ParseGame(const FJamJson& Game, FJamEffectsConfig& Out, TArray<FString>& OutErrors);

	// The five built-ins (speed, precision, heavy_puck, big_puck, reverse_other), parsed once from the embedded file.
	static const TArray<FJamEffectDef>& Builtins();
	static FString BuiltinsJson();
	static bool IsBuiltin(FName Kind);
};

namespace JamEffects
{
	JAMCORE_API const TCHAR* TriggerName(EJamEffectTrigger T);
	JAMCORE_API bool TriggerFromName(FName Name, EJamEffectTrigger& Out);
	JAMCORE_API bool TargetFromName(FName Name, EJamTarget& Out);
	JAMCORE_API const TCHAR* TargetName(EJamTarget T);
	JAMCORE_API bool StackFromName(FName Name, EJamEffectStack& Out);
	// bolt (speed), crosshair (precision), weight (heavy_puck), circle (big_puck), swirl (reverse_other), star (custom).
	JAMCORE_API FName DefaultIcon(FName Kind);
	// Team-neutral colour per kind for the pickup, its beacon, the radar and the HUD: the colours of contracts/events.md (linear): speed cyan
	// (0.1, 0.9, 1.0), precision magenta (1.0, 0.2, 0.9), heavy_puck violet (0.55, 0.3, 1.0), big_puck amber (1.0, 0.75, 0.1), reverse_other red
	// (1.0, 0.15, 0.1), custom and unknown white (lane A210: yellow / cyan / violet / white / magenta / green before).
	JAMCORE_API FLinearColor KindColour(FName Kind);
	constexpr int32 MaxDurationFrames = 7200;
	constexpr double MinMultiply = 0.25;
	constexpr double MaxMultiply = 4.0;

	// Event names this system emits (contracts/events.md, C-0005 section 6 additions). Broadcast only when the bus knows them.
	JAMCORE_API extern const FName EffectStart;   // "effect_start": Who = target skater or -1, Kind = effect id
	JAMCORE_API extern const FName EffectEnd;     // "effect_end"
}

// What the HUD reads (lane A5's strip; AHokejGameMode::GetEffects()->GetHudFeed()). One row per active modifier.
USTRUCT(BlueprintType)
struct JAMCORE_API FJamEffectHudEntry
{
	GENERATED_BODY()
	// The skater the row belongs to for target self; -1 for a team, everyone, the puck or the rink.
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Effects") int32 Skater = -1;
	// Team for own_team / other_team rows (already resolved to the team that is affected); -1 otherwise.
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Effects") int32 Team = -1;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Effects") EJamTarget Target = EJamTarget::Everyone;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Effects") FName EffectId;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Effects") FName Kind;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Effects") FName Icon;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Effects") int32 FramesLeft = 0;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Effects") int32 DurationFrames = 1;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Effects") FLinearColor Colour = FLinearColor::White;
	// True when the row touches this skater (the HUD shows the human's rows).
	bool Covers(int32 SkaterIndex, int32 SkaterTeam) const
	{
		switch (Target)
		{
		case EJamTarget::Self: return Skater == SkaterIndex;
		case EJamTarget::OwnTeam: case EJamTarget::OtherTeam: return Team == SkaterTeam;
		case EJamTarget::Everyone: return true;
		default: return false;
		}
	}
};

// A pickup lying on the ice.
USTRUCT(BlueprintType)
struct JAMCORE_API FJamPickupOnIce
{
	GENERATED_BODY()
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Effects") int32 Id = 0;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Effects") int32 PickupIndex = 0;   // into FJamEffectsConfig::Pickups
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Effects") FName Kind;
	// Rink metres (x, z).
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Effects") FVector2D Pos = FVector2D::ZeroVector;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Effects") int64 SpawnFrame = 0;
};
