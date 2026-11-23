// The seam between gameplay (device A) and every skater look (device B). Contract: contracts/skater-visual.md.
// Gameplay drives an AJamSkater pawn and talks to its visual only through this interface; it never knows what the skater looks like.
#pragma once

#include "CoreMinimal.h"
#include "UObject/Interface.h"
#include "JamSkaterVisual.generated.h"

// Socket names every skater mesh carries (contracts/skater-visual.md, "Sockets").
namespace JamSkaterSockets
{
	JAMCORE_API extern const FName Stick;   // "stick_socket": where the stick attaches (T-B2: child of hand_r)
	JAMCORE_API extern const FName Puck;    // "puck_socket": where a carried puck sits, in front of the blade
	JAMCORE_API extern const FName Head;    // "head_socket": above the head, for markers
}

// Material parameter names gameplay may drive (contracts/skater-visual.md, contracts/look-tiers.md).
namespace JamMaterialParams
{
	JAMCORE_API extern const FName TeamColour;  // "TeamColour": vector, linear RGB, alpha 1
	JAMCORE_API extern const FName NumberTens;  // "NumberTens": scalar 0..9 (0 for a one-digit number)
	JAMCORE_API extern const FName NumberOnes;  // "NumberOnes": scalar 0..9
	JAMCORE_API extern const FName Emissive;    // "Emissive": scalar >= 0, emissive multiplier
	JAMCORE_API extern const FName Wet;         // "Wet": scalar 0..1, 1 = wet ice look
	JAMCORE_API extern const FName Scuff;       // "Scuff": scalar 0..1, ice scuffing
}

// Boost kinds passed to SetBoost (cartridge game.pickups[].kind). NAME_None = no boost.
namespace JamBoostKinds
{
	JAMCORE_API extern const FName Speed;         // "speed"
	JAMCORE_API extern const FName Precision;     // "precision"
	JAMCORE_API extern const FName HeavyPuck;     // "heavy_puck"
	JAMCORE_API extern const FName BigPuck;       // "big_puck"
	JAMCORE_API extern const FName ReverseOther;  // "reverse_other"
}

UINTERFACE(BlueprintType, Blueprintable)
class JAMCORE_API UJamSkaterVisual : public UInterface
{
	GENERATED_BODY()
};

// Implemented by a component (or actor) the skater pawn owns. Every call comes on the game thread from the fixed
// 60 Hz simulation tick. Units: metres per second, radians per second, degrees in FRotator.
// Call from C++ with IJamSkaterVisual::Execute_<Name>(Object, ...) so Blueprint implementations are reached too.
class JAMCORE_API IJamSkaterVisual
{
	GENERATED_BODY()

public:
	// Team id (index into game.teams, 0 or 1) and its jersey colour (linear, from game.teams[].colour_hex). At spawn and at every cartridge load.
	UFUNCTION(BlueprintNativeEvent, BlueprintCallable, Category = "Jam|SkaterVisual")
	void SetTeam(int32 TeamId, FLinearColor Colour);

	// Jersey number 0..99; drives NumberTens and NumberOnes.
	UFUNCTION(BlueprintNativeEvent, BlueprintCallable, Category = "Jam|SkaterVisual")
	void SetNumber(int32 N);

	// Every simulation frame: speed in m/s (>= 0), signed turn rate in rad/s (positive = turning left seen from above), facing (yaw only, pitch and roll 0).
	UFUNCTION(BlueprintNativeEvent, BlueprintCallable, Category = "Jam|SkaterVisual")
	void UpdateMotion(float Speed, float TurnRate, FRotator Facing);

	// One-shot: a shot (or a pass) left this skater's stick on this frame. Charge 0..1 (C-0005): 0 = a tap or a pass, 1 = a fully wound-up
	// charged shot; the visual scales its swing with it.
	UFUNCTION(BlueprintNativeEvent, BlueprintCallable, Category = "Jam|SkaterVisual")
	void PlayShoot(float Charge);

	// One-shot: this skater threw a body check on this frame.
	UFUNCTION(BlueprintNativeEvent, BlueprintCallable, Category = "Jam|SkaterVisual")
	void PlayCheck();

	// Knocked down (true) or back up (false). DirX, DirZ: unit vector on the ice plane (rink x, rink z) the figure falls towards; ignored when bDown is false.
	// C-0001 v4 (R-0031 point 1, B-to-A-0028 ask 2): KnockdownFrames = the sim's down time in frames when bDown (the figure's get-up must end when the sim
	// releases the skater, SetKnockedDown(false) follows exactly that many frames later); 0 when bDown is false.
	UFUNCTION(BlueprintNativeEvent, BlueprintCallable, Category = "Jam|SkaterVisual")
	void SetKnockedDown(bool bDown, float DirX, float DirZ, int32 KnockdownFrames);

	// The skater gained (true) or lost (false) the puck.
	UFUNCTION(BlueprintNativeEvent, BlueprintCallable, Category = "Jam|SkaterVisual")
	void SetHasPuck(bool bHasPuck);

	// Active boost kind (JamBoostKinds) or NAME_None when the boost ends.
	UFUNCTION(BlueprintNativeEvent, BlueprintCallable, Category = "Jam|SkaterVisual")
	void SetBoost(FName Kind);

	// ---- C-0001 v3 (B-to-A-0014, R-0013 stick verbs; proposed by lane A16, cosmetic only, empty defaults so every visual keeps compiling) ----
	// Every simulation frame: where the blade is held. AngleDeg: 0 = the skater's forward, positive = to its left; ReachM: skater centre to the blade on the ice.
	UFUNCTION(BlueprintNativeEvent, BlueprintCallable, Category = "Jam|SkaterVisual")
	void SetStickAim(float AngleDeg, float ReachM);
	virtual void SetStickAim_Implementation(float AngleDeg, float ReachM) {}

	// One-shot on the frame a poke resolves: true = the blade took the puck, false = mistimed (a stumble of game.stick.stumble_frames follows).
	UFUNCTION(BlueprintNativeEvent, BlueprintCallable, Category = "Jam|SkaterVisual")
	void PlayPoke(bool bClean);
	virtual void PlayPoke_Implementation(bool bClean) {}

	// One-shot: a stick lift (clean or not).
	UFUNCTION(BlueprintNativeEvent, BlueprintCallable, Category = "Jam|SkaterVisual")
	void PlayLift();
	virtual void PlayLift_Implementation() {}

	// One-shot: a pass left the stick; Strength = pass speed / puck.max_speed (0..1).
	UFUNCTION(BlueprintNativeEvent, BlueprintCallable, Category = "Jam|SkaterVisual")
	void PlayPass(float Strength);
	virtual void PlayPass_Implementation(float Strength) {}

	// Every frame: the shot charge 0..1 while shoot is held with the puck (0 when not charging); PlayShoot(Charge) then releases it.
	UFUNCTION(BlueprintNativeEvent, BlueprintCallable, Category = "Jam|SkaterVisual")
	void SetShotCharge(float Charge01);
	virtual void SetShotCharge_Implementation(float Charge01) {}

	// True while this skater stands at the dot as a centre before the drop; false at the drop and for everybody else.
	UFUNCTION(BlueprintNativeEvent, BlueprintCallable, Category = "Jam|SkaterVisual")
	void SetFaceoff(bool bReady);
	virtual void SetFaceoff_Implementation(bool bReady) {}

	// One-shot on the frame the draw resolves, for the two centres: won or lost.
	UFUNCTION(BlueprintNativeEvent, BlueprintCallable, Category = "Jam|SkaterVisual")
	void PlayFaceoffDraw(bool bWon);
	virtual void PlayFaceoffDraw_Implementation(bool bWon) {}

	// The last man holding the crease (R-0013 point 3); Side -1 left, 0 centre, +1 right plays and holds a block. Called by the brain's owner, not the sim.
	UFUNCTION(BlueprintNativeEvent, BlueprintCallable, Category = "Jam|SkaterVisual")
	void SetGoalieStance(bool bOn, int32 Side);
	virtual void SetGoalieStance_Implementation(bool bOn, int32 Side) {}

	// One-shot on the fouler when a foul is called (the fouler then sits in the box).
	UFUNCTION(BlueprintNativeEvent, BlueprintCallable, Category = "Jam|SkaterVisual")
	void PlayFoulReaction();
	virtual void PlayFoulReaction_Implementation() {}

	// ---- C-0001 v4 (R-0031 point 1, B-to-A-0028; lane A45; cosmetic only, empty defaults so every visual keeps compiling) ----
	// One-shot on a skater that takes a hit and stays up: a check that landed without a knockdown (none in today's sim: every landed check knocks down), or a
	// skater-skater collision at 3 m/s closing or more with no check landed. DirX, DirZ: the push on this skater (unit, rink x / z), the other skater towards this one:
	// classify against the facing exactly as SetKnockedDown's direction (along the facing = from behind, against it = from the front, else the side the other came from).
	UFUNCTION(BlueprintNativeEvent, BlueprintCallable, Category = "Jam|SkaterVisual")
	void PlayHitReaction(float DirX, float DirZ);
	virtual void PlayHitReaction_Implementation(float DirX, float DirZ) {}

	// One-shot: this skater hit the boards at 4 m/s or more along the normal (the skater `board` event of C-0003, Who = this skater; its Strength is on the bus).
	UFUNCTION(BlueprintNativeEvent, BlueprintCallable, Category = "Jam|SkaterVisual")
	void PlayBoardHit();
	virtual void PlayBoardHit_Implementation() {}

	// Level: true while this skater has been pressed against the boards for 10 frames or more with an opponent within 1.2 m (centre to centre), false when either ends
	// or the skater goes down. Called only on the change.
	UFUNCTION(BlueprintNativeEvent, BlueprintCallable, Category = "Jam|SkaterVisual")
	void SetBoardPin(bool bOn);
	virtual void SetBoardPin_Implementation(bool bOn) {}

	// One-shot on the carrier that lost the puck to an opponent's stick this frame: a clean poke (bLifted false) or a stick lift (true). The poker's own
	// PlayPoke(true) / PlayLift() still play on the other skater.
	UFUNCTION(BlueprintNativeEvent, BlueprintCallable, Category = "Jam|SkaterVisual")
	void PlayStickHit(bool bLifted);
	virtual void PlayStickHit_Implementation(bool bLifted) {}
};
