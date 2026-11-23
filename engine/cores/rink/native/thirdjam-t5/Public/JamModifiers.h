// Seam A of C-0005 (contracts/depth.md section 2): stat modifiers. Owned by lane A16 (the sim), consumed by lane A14 (UJamEffectSystem,
// the only IJamModifierSource). The sim resolves, once per frame before integration,
//   effective(stat, skater) = base * prod(Multiply) + sum(Add)
// over the modifiers whose Target covers the skater (or the puck / the rink), clamped to the schema range of the stat
// (schema/limits.json game_ranges). No source set, or no modifier returned = the base value, bit for bit (the Determinism test proves it).
// Active modifier ids go into UJamSim::StateHash, so a modifier changes the hash deterministically. Durations are frames.
#pragma once

#include "CoreMinimal.h"
#include "JamModifiers.generated.h"

// The tunables a modifier may scale. Schema spelling (game.effects[].stats[].stat) is the snake_case name from JamStats::ToName.
UENUM(BlueprintType)
enum class EJamStat : uint8
{
	SkaterSpeed,       // skater.speed (m/s)                   3..16
	SkaterAccel,       // skater.accel (m/s^2)                 4..40
	SkaterTurnRate,    // skater.turn_rate (rad/s)             1..12
	SkaterGrip,        // skater.lateral_grip                  0.5..12
	SkaterMass,        // skater.mass (kg)                     40..160
	ShotSpeed,         // shot.speed (m/s)                     5..40
	ShotAimConeDeg,    // shot.aim_cone_deg                    0..45 (0 = no aim help)
	ShotReach,         // shot.reach_m                         0.5..4
	CheckSpeedMin,     // skater.check_speed_min (m/s)         1..12
	KnockdownFrames,   // skater.knockdown_frames              15..300
	PuckDrag,          // puck.drag (1/s)                      0..2
	PuckMaxSpeed,      // puck.max_speed (m/s)                 10..60
	PuckRadius,        // puck.radius_m                        0.06..0.4
	IceFriction,       // rink.ice_friction                    0..0.1
	BoardRestitution,  // rink.board_restitution               0..1
	SkaterControlsSign, // multiplies the move input: 1 normal, -1 reversed (reverse_other, R-0017 point 2); base 1, range -1..1
	Count UMETA(Hidden)
};

// Who a modifier applies to. Self / OwnTeam / OtherTeam are read against FJamActiveModifier::SourceSkater and Team.
UENUM(BlueprintType)
enum class EJamTarget : uint8
{
	Self,
	OwnTeam,
	OtherTeam,
	Everyone,
	Puck,
	Rink
};

USTRUCT(BlueprintType)
struct JAMCORE_API FJamStatModifier
{
	GENERATED_BODY()
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Jam|Modifiers") EJamStat Stat = EJamStat::SkaterSpeed;
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Jam|Modifiers") float Multiply = 1.f;
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Jam|Modifiers") float Add = 0.f;
};

USTRUCT(BlueprintType)
struct JAMCORE_API FJamActiveModifier
{
	GENERATED_BODY()
	// Unique per activation; hashed by the sim. The source allocates it.
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Jam|Modifiers") int32 Id = 0;
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Jam|Modifiers") EJamTarget Target = EJamTarget::Everyone;
	// Skater that caused it (Self / OwnTeam / OtherTeam are relative to it), -1 none.
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Jam|Modifiers") int32 SourceSkater = -1;
	// Team the modifier belongs to when SourceSkater is -1 (OwnTeam = this team, OtherTeam = the other), -1 none.
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Jam|Modifiers") int32 Team = -1;
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Jam|Modifiers") TArray<FJamStatModifier> Stats;
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Jam|Modifiers") int32 FramesLeft = 0;
	// The effect id (game.effects[].id) or built-in pickup kind.
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Jam|Modifiers") FName Kind;
};

// Implemented by lane A14's UJamEffectSystem. Called by the sim once per Step with the frame about to be integrated;
// append every modifier that is active on that frame. Must be deterministic (same inputs = same list, same order).
class JAMCORE_API IJamModifierSource
{
public:
	virtual ~IJamModifierSource() = default;
	virtual void CollectModifiers(int32 Frame, TArray<FJamActiveModifier>& Out) const = 0;
};

// Schema spellings and ranges, in one place for the sim, the effect system and the schema generator.
namespace JamStats
{
	// "skater_speed", "shot_aim_cone_deg", ... ; nullptr for Count.
	inline const TCHAR* ToName(EJamStat S)
	{
		switch (S)
		{
		case EJamStat::SkaterSpeed: return TEXT("skater_speed");
		case EJamStat::SkaterAccel: return TEXT("skater_accel");
		case EJamStat::SkaterTurnRate: return TEXT("skater_turn_rate");
		case EJamStat::SkaterGrip: return TEXT("skater_grip");
		case EJamStat::SkaterMass: return TEXT("skater_mass");
		case EJamStat::ShotSpeed: return TEXT("shot_speed");
		case EJamStat::ShotAimConeDeg: return TEXT("shot_aim_cone_deg");
		case EJamStat::ShotReach: return TEXT("shot_reach");
		case EJamStat::CheckSpeedMin: return TEXT("check_speed_min");
		case EJamStat::KnockdownFrames: return TEXT("knockdown_frames");
		case EJamStat::PuckDrag: return TEXT("puck_drag");
		case EJamStat::PuckMaxSpeed: return TEXT("puck_max_speed");
		case EJamStat::PuckRadius: return TEXT("puck_radius");
		case EJamStat::IceFriction: return TEXT("ice_friction");
		case EJamStat::BoardRestitution: return TEXT("board_restitution");
		case EJamStat::SkaterControlsSign: return TEXT("skater_controls_sign");
		default: return nullptr;
		}
	}

	// False (Out untouched) for an unknown name: unknown values are errors.
	inline bool FromName(FName Name, EJamStat& Out)
	{
		for (uint8 i = 0; i < static_cast<uint8>(EJamStat::Count); ++i)
		{
			if (Name == FName(ToName(static_cast<EJamStat>(i)))) { Out = static_cast<EJamStat>(i); return true; }
		}
		return false;
	}

	// The schema range (schema/limits.json game_ranges) an effective value is clamped to.
	inline void Range(EJamStat S, double& OutMin, double& OutMax)
	{
		switch (S)
		{
		case EJamStat::SkaterSpeed: OutMin = 3; OutMax = 16; break;
		case EJamStat::SkaterAccel: OutMin = 4; OutMax = 40; break;
		case EJamStat::SkaterTurnRate: OutMin = 1; OutMax = 12; break;
		case EJamStat::SkaterGrip: OutMin = 0.5; OutMax = 12; break;
		case EJamStat::SkaterMass: OutMin = 40; OutMax = 160; break;
		case EJamStat::ShotSpeed: OutMin = 5; OutMax = 40; break;
		case EJamStat::ShotAimConeDeg: OutMin = 0; OutMax = 45; break;
		case EJamStat::ShotReach: OutMin = 0.5; OutMax = 4; break;
		case EJamStat::CheckSpeedMin: OutMin = 1; OutMax = 12; break;
		case EJamStat::KnockdownFrames: OutMin = 15; OutMax = 300; break;
		case EJamStat::PuckDrag: OutMin = 0; OutMax = 2; break;
		case EJamStat::PuckMaxSpeed: OutMin = 10; OutMax = 60; break;
		case EJamStat::PuckRadius: OutMin = 0.06; OutMax = 0.4; break;
		case EJamStat::IceFriction: OutMin = 0; OutMax = 0.1; break;
		case EJamStat::BoardRestitution: OutMin = 0; OutMax = 1; break;
		case EJamStat::SkaterControlsSign: OutMin = -1; OutMax = 1; break;
		default: OutMin = -1e300; OutMax = 1e300; break;
		}
	}

	// True for the stats that belong to the puck or the rink (resolved once, not per skater).
	inline bool IsGlobal(EJamStat S)
	{
		return S == EJamStat::PuckDrag || S == EJamStat::PuckMaxSpeed || S == EJamStat::PuckRadius || S == EJamStat::IceFriction || S == EJamStat::BoardRestitution;
	}
}
