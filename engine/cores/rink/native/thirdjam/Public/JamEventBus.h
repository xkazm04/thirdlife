// Gameplay events for VFX and audio hooks. Contract: contracts/events.md.
// Producer: gameplay (device A) calls Broadcast. Consumers: device B binds OnJamEvent and spawns NS_<event> / plays MS_<event>.
#pragma once

#include "CoreMinimal.h"
#include "Subsystems/GameInstanceSubsystem.h"
#include "JamEventBus.generated.h"

JAMCORE_API DECLARE_LOG_CATEGORY_EXTERN(LogJamEvents, Log, All);

// Event names (contracts/events.md). Any other name is an error: Broadcast logs it and does not deliver it.
namespace JamEvents
{
	JAMCORE_API extern const FName Shot;         // "shot"
	JAMCORE_API extern const FName Board;        // "board"
	JAMCORE_API extern const FName Goal;         // "goal"
	JAMCORE_API extern const FName Faceoff;      // "faceoff"
	JAMCORE_API extern const FName Check;        // "check"
	JAMCORE_API extern const FName Knockdown;    // "knockdown"
	JAMCORE_API extern const FName PickupSpawn;  // "pickup_spawn"
	JAMCORE_API extern const FName PickupTake;   // "pickup_take"
	JAMCORE_API extern const FName Win;          // "win"
	JAMCORE_API extern const FName Lose;         // "lose"
	JAMCORE_API extern const FName DirectorsCall; // "directors_call" (R-0001 7, R-0003 3): Who -1, Where zero, Strength = new value's position in the tunable range 0..1, Kind = tunable key
	JAMCORE_API extern const FName Period;       // "period" (R-0003 3): a TAKE starts; Who -1, Where centre ice, Strength 0, Kind = "take_<n>"
	JAMCORE_API extern const FName Bark;         // "bark" (R-0007, lane A12): Who = speaker skater index, Where = speaker, Strength 0, Kind = situation (goal_for, steal, ...)
	JAMCORE_API extern const FName Signal;       // "signal" (R-0007, lane A12): Who = the human's skater, Where = human, Strength = frames/600, Kind = defend | space | pass | praise
	// C-0005 section 6 (lane A16 registered; producers: A15 rules, A14 effects and zones, A16 passes).
	JAMCORE_API extern const FName Announce;     // "announce": a rule's text on the scoreboard line; Who -1, Where zero, Strength 0, Kind = "rule"; the text rides FJamSimEvent::Text
	JAMCORE_API extern const FName Pass;         // "pass": Who = passer, Where = puck, Strength = pass speed / puck.max_speed
	JAMCORE_API extern const FName EffectStart;  // "effect_start": Who = target skater or -1, Where = that skater (or zero), Kind = effect id
	JAMCORE_API extern const FName EffectEnd;    // "effect_end": same payload as effect_start
	JAMCORE_API extern const FName ZoneEnter;    // "zone_enter": Who = skater, Where = skater, Kind = zone id
	JAMCORE_API extern const FName ZoneExit;     // "zone_exit": same payload as zone_enter
	// R-0013 (lane A16): the stick. Who = the actor; Kind = clean | miss for poke and lift, foul_from_behind | foul_no_puck for foul.
	JAMCORE_API extern const FName Poke;         // "poke": a poke check; Where = blade, Strength 0
	JAMCORE_API extern const FName Lift;         // "lift": a stick lift; Where = the carrier, Strength 0
	JAMCORE_API extern const FName Foul;         // "foul": a check that was a foul; Who = the fouler, Where = contact, Strength = check strength
	JAMCORE_API extern const FName ShotBlocked;  // "shot_blocked" (R-0019): a shot refused inside a no_shoot zone; Who = shooter, Where = puck, Strength 0, Kind = zone id
	// Lane A32 (B-to-A-0026 ask 3): the seven events the commentator bank has lines for, proposed for C-0003 ("Proposed, for the Director" in contracts/events.md).
	// All read-outs of state the sim already has: nothing here changes play or the state hash.
	JAMCORE_API extern const FName Save;         // "save": the last man's blade or body stops a shot on goal; Who = the blocker, Where = puck, Strength = the shot's strength
	JAMCORE_API extern const FName Post;         // "post": the puck hits a goal post; Who -1, Where = the post, Strength = puck speed / game.puck.max_speed
	JAMCORE_API extern const FName Breakaway;    // "breakaway": the carrier is past every standing defender with the net ahead; Who = carrier, Where = carrier, Strength = gap to the nearest defender / 10 m, once per rush
	JAMCORE_API extern const FName Carry;        // "carry": one carrier has kept the puck for 300 frames; Who = carrier, Where = puck, Strength = metres carried / rink length, Kind = long | coast, once per possession
	JAMCORE_API extern const FName PeriodEnd;    // "period_end": a take ends (not the match); Who -1, Where centre ice, Strength 0, Kind = "take_<n>" of the take that ended
	JAMCORE_API extern const FName Clock;        // "clock": Who -1, Where centre ice, Strength 0, Kind = last_10s (600 frames left in a timed take) | sudden_death (a tie at the horn plays on)
	JAMCORE_API extern const FName SeasonTake;   // "season_take": a season match is built, before its first drop (the game mode sends it); Who -1, Where centre ice, Strength 0, Kind = "level_<n>"
	// Lane A39 (R-0029 point 4): the breakaway burst reuses `breakaway` above (one event per rush: whichever of the read-out and the burst comes first);
	// `shot` gains Kind = one_timer for a shot inside the one-timer window; the deke is new (proposed C-0003 addition).
	JAMCORE_API extern const FName Deke;         // "deke": the puck moves to the blade side; Who = the carrier, Where = puck, Strength = 0, Kind = left | right (the side in rink z)
	// Lane A84 (R-0041 point 3), proposed for C-0003: "ability": Who = the holder, Where = the holder, Kind = shotgun | hip_check | shield | slow_puck,
	// Strength = 1 for a use (F), 0 for a grant (a mode at the drop, a boost take).
	JAMCORE_API extern const FName Ability;
	// Lane A208 (contracts/events.md, the R-0067 additions): "possess": a puck nobody carried becomes a skater's; Who = the new carrier, Where = the puck,
	// Strength = the puck's speed at the take / puck.max_speed, Kind body = Variant 1 (the skates or the body), none = Variant 0 (the stick). Never for a press.
	// shot_blocked gains Kind skater = Variant 1: a shot stopped by a skater's body or stick (Who = the shooter, Strength = the puck's speed / max).
	JAMCORE_API extern const FName Possess;
	// R-0013: `faceoff` gains Kind = drop (the puck is live, Who -1) | won (Who = the centre that won) | lost (Who = the centre that lost).
}

USTRUCT(BlueprintType)
struct JAMCORE_API FJamEventPayload
{
	GENERATED_BODY()

	// Skater index (0..N-1 in game.teams order, team 0's skaters first) or -1 when no skater is involved.
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Jam|Events")
	int32 Who = -1;

	// World position in Unreal units (centimetres) where the event happened.
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Jam|Events")
	FVector Where = FVector::ZeroVector;

	// Event-specific magnitude, 0..1 (contracts/events.md says what it means per event).
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Jam|Events")
	float Strength = 0.f;

	// R-0001 item 3: pickup kind for pickup_spawn / pickup_take, cause ("check" | "boost") for knockdown; NAME_None otherwise.
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Jam|Events")
	FName Kind = NAME_None;

	// Lane A47 (B-to-A-0029): a unit direction on the rink plane (world x, y; z 0). check and knockdown: the contact normal, checker towards victim
	// (the binder's Niagara User.Dir); board: the board normal pointing into the rink (User.Normal). Zero for every other event. A read-out of the sim.
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Jam|Events")
	FVector Dir = FVector::ZeroVector;

	// Lane A143 (B-answer-0024 ask b): what a landed `check` did to the victim, `stumble` or `down` (the binder sends a stumble as Variant 4); NAME_None for
	// every other event. A read-out of the sim; the log line prints it as ` outcome=<x>` only when set.
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Jam|Events")
	FName Outcome = NAME_None;
};

DECLARE_DYNAMIC_MULTICAST_DELEGATE_TwoParams(FJamEventSignature, FName, Event, const FJamEventPayload&, Payload);

UCLASS()
class JAMCORE_API UJamEventBus : public UGameInstanceSubsystem
{
	GENERATED_BODY()

public:
	// Delivers a known event to every listener and logs it as
	// "JAMEVENT <name> who=<int> where=(x,y,z) strength=<float> frame=<uint64> kind=<name>". Returns false (and logs an error) for an unknown name.
	UFUNCTION(BlueprintCallable, Category = "Jam|Events")
	bool Broadcast(FName Event, const FJamEventPayload& Payload);

	// True when Event is one of JamEvents.
	UFUNCTION(BlueprintPure, Category = "Jam|Events")
	static bool IsKnownEvent(FName Event);

	// The known event names, in contract order (the ten of C-0003, then directors_call and period).
	UFUNCTION(BlueprintPure, Category = "Jam|Events")
	static TArray<FName> GetKnownEvents();

	// Number of events delivered since this game instance started (tests read it).
	UFUNCTION(BlueprintPure, Category = "Jam|Events")
	int32 GetBroadcastCount() const { return BroadcastCount; }

	UPROPERTY(BlueprintAssignable, Category = "Jam|Events")
	FJamEventSignature OnJamEvent;

	// Logging every event is on by default; long bot runs may turn it off.
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Jam|Events")
	bool bLogEvents = true;

	// The simulation frame the game mode is delivering events for; the log line prints it as frame= (contracts/events.md open
	// question 3). -1 (default, no simulation running) prints the engine frame counter instead.
	UFUNCTION(BlueprintCallable, Category = "Jam|Events")
	void SetSimFrame(int64 InFrame) { SimFrame = InFrame; }

	UFUNCTION(BlueprintPure, Category = "Jam|Events")
	int64 GetSimFrame() const { return SimFrame; }

private:
	int32 BroadcastCount = 0;
	int64 SimFrame = -1;
};
