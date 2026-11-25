// Lane A15 (C-0005): zones in the sim. Two parts.
//
// 1. IJamZoneSource: the seam the sim consumes (PROPOSED to lane A16 in the A15 report; until the sim calls it, zones only
//    produce events and the ice effects are applied through the modifier request path). Four questions the sim asks per frame:
//      IceAt(pos)        slow_ice / fast_ice under a skater or the puck -> speed and friction multipliers
//      BlocksShot(pos)   no_shoot: a shot taken from inside is refused (the sim emits "shot_blocked", proposed name, Who = shooter, Kind = zone id)
//      BumpPuck(...)     bumper zones: the puck is thrown back from the zone's edge with restitution JamZones::BumperRestitution * strength scale
//      AllowsPickupAt    boost_only: when any boost_only zone exists, pickups may spawn only inside one
//    Bumper OBSTACLES (game.rink.obstacles[].kind "bumper") and goal shields are plain collision shapes the sim owns; the sim
//    should reflect the puck off a bumper with JamZones::ReflectOffBumper(Vel, Normal, JamZones::BumperRestitution).
//
// 2. UJamZoneSystem: the only IJamZoneSource. Keeps the zones of a loaded config, computes per-frame membership for every
//    skater and the puck from sim state (read-only) and emits zone_enter / zone_exit events (Who = skater index or -1 for the
//    puck, Where = its position, Kind = zone id) for the host to broadcast. Deterministic: membership is a pure function of positions.
#pragma once

#include "CoreMinimal.h"
#include "UObject/Object.h"
#include "JamCartridge.h"
#include "JamSim.h"
#include "JamZones.generated.h"

// Speed and glide-friction multipliers for the ice under a point; 1 / 1 on plain ice.
struct JAMCORE_API FJamIceFactors
{
	double SpeedMul = 1.0;
	double FrictionMul = 1.0;
};

class JAMCORE_API IJamZoneSource
{
public:
	virtual ~IJamZoneSource() = default;
	virtual FJamIceFactors IceAt(const FVector2D& PosM) const = 0;
	virtual bool BlocksShot(const FVector2D& PosM, FName& OutZoneId) const = 0;
	// Puck (centre Pos, radius RadiusM) against every bumper zone: pushed out of the zone and thrown back. True when it bounced.
	virtual bool BumpPuck(FVector2D& Pos, FVector2D& Vel, double RadiusM) const = 0;
	virtual bool AllowsPickupAt(const FVector2D& PosM) const = 0;
};

namespace JamZones
{
	// game.rink.obstacles[].kind "bumper" (C-0005 section 4) and a bumper zone at strength 0.5.
	constexpr double BumperRestitution = 1.6;
	// Depth of a goal_shield wall in metres (it is Size metres wide).
	constexpr double GoalShieldDepthM = 0.3;
	// A bumper zone's restitution from its strength: 1.0 at 0, BumperRestitution at 0.5, 2.2 at 1.
	inline double BumperRestitutionFor(double Strength) { return 1.0 + (BumperRestitution - 1.0) * 2.0 * FMath::Clamp(Strength, 0.0, 1.0); }
	// Reflects the normal part of Vel off a surface with outward normal N (unit) and restitution E; the tangent part is kept.
	// Only the approaching case changes anything (Vel . N < 0).
	inline void ReflectOffBumper(FVector2D& Vel, const FVector2D& N, double E)
	{
		const double Vn = Vel.X * N.X + Vel.Y * N.Y;
		if (Vn < 0) Vel -= N * ((1.0 + E) * Vn);
	}
	// Ice factors of one zone kind at a strength: slow_ice halves speed at strength 1 and makes the glide 4x stickier; fast_ice adds
	// half the speed and cuts the glide friction to a fifth. Other kinds are plain ice.
	JAMCORE_API FJamIceFactors IceFactors(FName Kind, double Strength);
}

UCLASS(BlueprintType)
class JAMCORE_API UJamZoneSystem : public UObject, public IJamZoneSource
{
	GENERATED_BODY()

public:
	static constexpr int32 MaxZones = 8;
	static constexpr int32 PuckWho = -1;

	// Takes the zones of a loaded config (at most MaxZones; extras are dropped with a log line) and clears membership.
	void Init(const FJamGameConfig& Config);
	// New match: everyone is outside every zone again (the next Update emits enter events for whoever starts inside).
	void ResetMatch();

	// Per-frame membership from sim state. Emits zone_enter / zone_exit into GetFrameEvents() (cleared at the start of every call).
	void Update(int64 Frame, const TArray<FJamSkaterState>& Skaters, const FJamPuckState& Puck);
	const TArray<FJamSimEvent>& GetFrameEvents() const { return FrameEvents; }

	// IJamZoneSource
	virtual FJamIceFactors IceAt(const FVector2D& PosM) const override;
	virtual bool BlocksShot(const FVector2D& PosM, FName& OutZoneId) const override;
	virtual bool BumpPuck(FVector2D& Pos, FVector2D& Vel, double RadiusM) const override;
	virtual bool AllowsPickupAt(const FVector2D& PosM) const override;

	const TArray<FJamZoneConfig>& GetZones() const { return Zones; }
	UFUNCTION(BlueprintPure, Category = "Jam|Rules") int32 GetZoneCount() const { return Zones.Num(); }
	// Who = skater index, or PuckWho (-1) for the puck.
	UFUNCTION(BlueprintPure, Category = "Jam|Rules") bool IsInside(int32 Who, int32 ZoneIndex) const;
	// Index of the first zone (of Kind when given) that contains P; -1 when none.
	int32 ZoneIndexAt(const FVector2D& P, FName Kind = NAME_None) const;
	// Brain note for lane A3: true when P lies in a slow_ice zone (a carrier should steer around it).
	UFUNCTION(BlueprintPure, Category = "Jam|Rules") bool IsSlowIceAt(const FVector2D& P) const { return ZoneIndexAt(P, FName(TEXT("slow_ice"))) >= 0; }
	UFUNCTION(BlueprintPure, Category = "Jam|Rules") int32 GetEnterCount() const { return EnterCount; }
	UFUNCTION(BlueprintPure, Category = "Jam|Rules") int32 GetExitCount() const { return ExitCount; }

	// FNV-1a 64 over the membership bits and counters.
	uint64 StateHash() const;

private:
	// Bit per zone; index 0 = the puck, 1 + i = skater i.
	uint32& MaskFor(int32 Who) { return Inside[Who + 1]; }
	uint32 MaskFor(int32 Who) const { return Inside.IsValidIndex(Who + 1) ? Inside[Who + 1] : 0; }

	UPROPERTY() TArray<FJamZoneConfig> Zones;
	UPROPERTY() TArray<FJamSimEvent> FrameEvents;
	TArray<uint32> Inside;
	int32 EnterCount = 0;
	int32 ExitCount = 0;
};
