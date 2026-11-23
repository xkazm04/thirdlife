// Seam B of C-0005 (contracts/depth.md section 3): rule hooks. Owned by lane A16 (the sim), consumed by lane A15 (UJamRuleSystem,
// the only IJamRuleHook). The sim calls the hook at each trigger and applies the returned actions in order within the same frame.
// No hook set = no-op, hashes unchanged. Frames are simulation frames. All randomness stays in the sim's seeded stream.
#pragma once

#include "CoreMinimal.h"
#include "JamRuleHooks.generated.h"

// When the sim calls the hook. Schema spelling (game.rules.hooks[].when) is the snake_case name from JamRules::TriggerName.
UENUM(BlueprintType)
enum class EJamRuleTrigger : uint8
{
	OnGoal,          // Who = scorer (or -1), Team = scoring team, Value = that team's new score
	OnPeriodStart,   // Who -1, Team -1, Value = period number (1-based)
	OnPeriodEnd,     // Who -1, Team -1, Value = period number that ended
	OnCheck,         // Who = checker, Team = checker's team, Value = check strength 0..1
	OnKnockdown,     // Who = the skater knocked down, Team = its team, Value = strength, Kind = cause ("check")
	OnPickupTake,    // Who = taker, Team = taker's team, Kind = pickup kind (fired through UJamSim::NotifyPickupTaken by the pickup system)
	OnFaceoff,       // Who -1, Team -1, Value = 0
	OnFrame,         // every frame; the hook filters with In.Frame % every_frames == 0. Who -1, Team -1, Value = frame
	OnScoreReached   // after OnGoal: Team = scoring team, Value = that team's new score; the hook compares with its `score`
};

// What a hook may do. Schema spelling (game.rules.hooks[].then[].do) is the snake_case name from JamRules::ActionName.
UENUM(BlueprintType)
enum class EJamRuleAction : uint8
{
	AddScore,            // Team (0 | 1; -1 = the event's team), Value = points (may be negative; a score never drops below 0)
	SetScoreMultiplier,  // Team (-1 = both), Value = points per goal from now on (1 resets)
	EndPeriod,           // ends the current period: faceoff after goal_pause_frames; timer mode jumps the clock to the next third; period 3 ends the match
	EndMatch,            // the leading team wins; a tie goes to Team when 0 | 1, else to the last team to touch the puck
	ShrinkRink,          // length and width scaled by Value (<1; a Value >1 is read as 1/Value), clamped to the schema range, applied at the next faceoff
	GrowRink,            // length and width scaled by Value (>1; a Value <1 is read as 1/Value), clamped to the schema range, applied at the next faceoff
	SetParam,            // Param = tunable key (schema/README.md "Tunables": skater_speed, shot_speed, ice_friction, ...), Value = new value; the Director's Call path
	SpawnPickup,         // Kind = pickup kind, Team / Value / Frames as the pickup system reads them; queued as a request (UJamSim::TakePickupRequests)
	SwapNets,            // the teams swap the nets they attack (applied at once)
	Announce,            // Text on the scoreboard line: event "announce", Who -1, Kind = "rule", text in FJamSimEvent::Text
	ApplyModifier        // Kind = effect id, Team / Frames / Value; queued as a request the modifier source reads (UJamSim::TakeModifierRequests)
};

USTRUCT(BlueprintType)
struct JAMCORE_API FJamRuleEventIn
{
	GENERATED_BODY()
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Rules") EJamRuleTrigger Trigger = EJamRuleTrigger::OnFrame;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Rules") int32 Frame = 0;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Rules") int32 Who = -1;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Rules") int32 Team = -1;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Rules") FName Kind;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Rules") float Value = 0.f;
};

USTRUCT(BlueprintType)
struct JAMCORE_API FJamRuleActionOut
{
	GENERATED_BODY()
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Jam|Rules") EJamRuleAction Action = EJamRuleAction::Announce;
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Jam|Rules") int32 Team = -1;
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Jam|Rules") float Value = 0.f;
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Jam|Rules") FName Param;
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Jam|Rules") FName Kind;
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Jam|Rules") int32 Frames = 0;
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Jam|Rules") FString Text;
};

// A queued SpawnPickup or ApplyModifier action with the event that caused it (proposed name, A16; the pickup system and the
// modifier source drain these from the sim once per frame).
USTRUCT(BlueprintType)
struct JAMCORE_API FJamRuleRequest
{
	GENERATED_BODY()
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Rules") FJamRuleEventIn Cause;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Rules") FJamRuleActionOut Action;
};

// Implemented by lane A15's UJamRuleSystem. Called on the game thread from UJamSim::Step; must be deterministic.
class JAMCORE_API IJamRuleHook
{
public:
	virtual ~IJamRuleHook() = default;
	virtual void OnRuleEvent(const FJamRuleEventIn& In, TArray<FJamRuleActionOut>& Out) = 0;
};

namespace JamRules
{
	inline const TCHAR* TriggerName(EJamRuleTrigger T)
	{
		switch (T)
		{
		case EJamRuleTrigger::OnGoal: return TEXT("on_goal");
		case EJamRuleTrigger::OnPeriodStart: return TEXT("on_period_start");
		case EJamRuleTrigger::OnPeriodEnd: return TEXT("on_period_end");
		case EJamRuleTrigger::OnCheck: return TEXT("on_check");
		case EJamRuleTrigger::OnKnockdown: return TEXT("on_knockdown");
		case EJamRuleTrigger::OnPickupTake: return TEXT("on_pickup_take");
		case EJamRuleTrigger::OnFaceoff: return TEXT("on_faceoff");
		case EJamRuleTrigger::OnFrame: return TEXT("on_frame");
		case EJamRuleTrigger::OnScoreReached: return TEXT("on_score_reached");
		default: return nullptr;
		}
	}

	inline bool TriggerFromName(FName Name, EJamRuleTrigger& Out)
	{
		for (uint8 i = 0; i <= static_cast<uint8>(EJamRuleTrigger::OnScoreReached); ++i)
		{
			if (Name == FName(TriggerName(static_cast<EJamRuleTrigger>(i)))) { Out = static_cast<EJamRuleTrigger>(i); return true; }
		}
		return false;
	}

	inline const TCHAR* ActionName(EJamRuleAction A)
	{
		switch (A)
		{
		case EJamRuleAction::AddScore: return TEXT("add_score");
		case EJamRuleAction::SetScoreMultiplier: return TEXT("set_score_multiplier");
		case EJamRuleAction::EndPeriod: return TEXT("end_period");
		case EJamRuleAction::EndMatch: return TEXT("end_match");
		case EJamRuleAction::ShrinkRink: return TEXT("shrink_rink");
		case EJamRuleAction::GrowRink: return TEXT("grow_rink");
		case EJamRuleAction::SetParam: return TEXT("set_param");
		case EJamRuleAction::SpawnPickup: return TEXT("spawn_pickup");
		case EJamRuleAction::SwapNets: return TEXT("swap_nets");
		case EJamRuleAction::Announce: return TEXT("announce");
		case EJamRuleAction::ApplyModifier: return TEXT("apply_modifier");
		default: return nullptr;
		}
	}

	inline bool ActionFromName(FName Name, EJamRuleAction& Out)
	{
		for (uint8 i = 0; i <= static_cast<uint8>(EJamRuleAction::ApplyModifier); ++i)
		{
			if (Name == FName(ActionName(static_cast<EJamRuleAction>(i)))) { Out = static_cast<EJamRuleAction>(i); return true; }
		}
		return false;
	}
}
