// Lane A15 (C-0005, contracts/depth.md section 4): the cartridge shapes of game.rules.hooks, game.rules.variants and
// game.rink.zones as the loader (JamCartridge.cpp FillGame) fills them. Wire names are snake_case FNames kept as written;
// UJamRuleSystem turns `when` / `do` into EJamRuleTrigger / EJamRuleAction (JamRuleHooks.h) when it evaluates.
// Absent value = the struct default (schema/DEFAULTS.md). Units: metres, frames.
#pragma once

#include "CoreMinimal.h"
#include "JamRulesConfig.generated.h"

// One action of a hook: { do, team?, value?, param?, kind?, frames?, text? }.
USTRUCT(BlueprintType)
struct JAMCORE_API FJamRuleActionConfig
{
	GENERATED_BODY()
	// add_score | set_score_multiplier | end_period | end_match | shrink_rink | grow_rink | set_param | spawn_pickup | swap_nets | announce | apply_modifier
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Rules") FName Do;
	// "scoring" | "conceding" | "any"; NAME_None = the hook's team.
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Rules") FName Team;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Rules") bool bHasValue = false;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Rules") double Value = 0;
	// set_param: the tunable key (skater_speed, shot_speed, ice_friction, ...).
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Rules") FName Param;
	// spawn_pickup: the pickup kind or effect id; apply_modifier: the effect id.
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Rules") FName Kind;
	// apply_modifier: duration in frames.
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Rules") int32 Frames = 0;
	// announce: the scoreboard text.
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Rules") FString Text;
};

// The `score` condition of a hook; -1 = absent.
USTRUCT(BlueprintType)
struct JAMCORE_API FJamRuleScoreCondition
{
	GENERATED_BODY()
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Rules") bool bHas = false;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Rules") int32 AtLeast = -1;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Rules") int32 AtMost = -1;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Rules") int32 LeadAtLeast = -1;
};

// One hook: { id, when, every_frames?, after_frame?, team?, score?, then[] }.
USTRUCT(BlueprintType)
struct JAMCORE_API FJamRuleHookConfig
{
	GENERATED_BODY()
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Rules") FString Id;
	// on_goal | on_period_start | on_period_end | on_check | on_knockdown | on_pickup_take | on_faceoff | on_frame | on_score_reached
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Rules") FName When;
	// on_frame only: fire when Frame % EveryFrames == 0 (0 = absent).
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Rules") int32 EveryFrames = 0;
	// Armed from this frame on (0 = always).
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Rules") int32 AfterFrame = 0;
	// "scoring" | "conceding" | "any": the team the score condition reads and the actions apply to by default.
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Rules") FName Team = TEXT("scoring");
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Rules") FJamRuleScoreCondition Score;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Rules") TArray<FJamRuleActionConfig> Then;
	// True for a hook the loader made from game.rules.variants.
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Rules") bool bFromVariant = false;
};

// game.rules.variants as written; the loader expands them into hooks (ExpandVariants) and keeps them here for display.
USTRUCT(BlueprintType)
struct JAMCORE_API FJamRuleVariantsConfig
{
	GENERATED_BODY()
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Rules") bool bSuddenDeath = false;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Rules") bool bLastGoalDouble = false;
	// 0 = absent.
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Rules") int32 MercyGoals = 0;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Rules") int32 PeriodCount = 0;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Rules") double ShrinkPerGoal = 0;
};

// One zone of game.rink.zones: { id, shape, x, z, w?, d?, r?, kind, strength?, visible? }.
USTRUCT(BlueprintType)
struct JAMCORE_API FJamZoneConfig
{
	GENERATED_BODY()
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Rules") FString Id;
	// "rect" | "circle"
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Rules") FName Shape = TEXT("circle");
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Rules") double X = 0;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Rules") double Z = 0;
	// rect: full length along the rink (W) and across it (D); circle: radius R.
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Rules") double W = 0;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Rules") double D = 0;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Rules") double R = 0;
	// slow_ice | fast_ice | bumper | no_shoot | boost_only
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Rules") FName Kind;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Rules") double Strength = 0.5;
	UPROPERTY(BlueprintReadOnly, Category = "Jam|Rules") bool bVisible = true;

	// True when the rink point P (metres) lies inside the zone (edge inclusive).
	bool Contains(const FVector2D& P) const
	{
		if (Shape == FName(TEXT("rect"))) return FMath::Abs(P.X - X) <= W * 0.5 && FMath::Abs(P.Y - Z) <= D * 0.5;
		return FVector2D::DistSquared(P, FVector2D(X, Z)) <= R * R;
	}
	// Signed distance to the zone's edge (negative inside); OutNormal points out of the zone. Rect: axis-aligned box distance.
	double EdgeDistance(const FVector2D& P, FVector2D& OutNormal) const
	{
		if (Shape == FName(TEXT("rect")))
		{
			const double Dx = FMath::Abs(P.X - X) - W * 0.5, Dz = FMath::Abs(P.Y - Z) - D * 0.5;
			const double Sx = P.X >= X ? 1.0 : -1.0, Sz = P.Y >= Z ? 1.0 : -1.0;
			if (Dx > 0 && Dz > 0) { const double L = FMath::Sqrt(Dx * Dx + Dz * Dz); OutNormal = FVector2D(Sx * Dx / L, Sz * Dz / L); return L; }
			if (Dx > Dz) { OutNormal = FVector2D(Sx, 0); return Dx; }
			OutNormal = FVector2D(0, Sz); return Dz;
		}
		const FVector2D Dlt = P - FVector2D(X, Z);
		const double L = Dlt.Size();
		OutNormal = L > 1e-9 ? Dlt / L : FVector2D(1, 0);
		return L - R;
	}
};
