// Third Life rink core shim: the part of thirdjam's JamPawns.h (Public/JamPawns.h, HEAD 8dc713c6) that has no Unreal actor in it, for
// thirdjam's own tests (JamContactTests.cpp, JamStickTests.cpp). AJamSkater here is NOT a pawn: it carries only the pure helpers
// the tests call, whose bodies are thirdjam's own, extracted verbatim from Private/JamPawns.cpp at build time
// (native/tools/extract_pawn_helpers.py). Declarations copied from JamPawns.h with their line numbers. The real header (actors,
// components) is in native/thirdjam/Public/JamPawns.h and is not compiled.
#pragma once

#include "CoreMinimal.h"
#include "JamSim.h"

// JamPawns.h:16-24
struct FJamHitStopPick
{
	int32 Victim = -1, Checker = -1;
	int32 Outcome = 0;      // UJamSim::ContactNone (a knockdown the momentum model did not resolve), ContactStumble (also the human's own bounce) or ContactDown
	float Ratio = 0.f;      // the victim's ContactRatio (the bounce: contact.bump_ratio)
	float Strength = 0.f;   // the hit's event strength: the knockdown's, or the check event's for a stumble
	FName Kind;             // the check event's kind for a knockdown (front, behind, side_l, side_r), "stumble" or "bounce"
};

class AJamSkater
{
public:
	// JamPawns.h:92-94
	static constexpr float AimClampDeg = 70.f;
	static constexpr float AimSlewDegPerFrame = 15.f;
	static float SmoothAimDeg(float RawRelDeg, float Prev, int32& Side, bool& bInit);
	// JamPawns.h:137, 141, 146, 163, 168, 170
	static int32 HitStopFrames();
	static int32 HitStopFramesFor(int32 Outcome, float Ratio, const FJamContactConfig& Contact, int32 Base);
	static FJamHitStopPick HitStopPick(const TArray<FJamSkaterState>& Skaters, const TArray<FJamSimEvent>& Events, int32 Human, double BumpRatio);
	static bool CallFigure(UObject* Figure, FName Function, std::initializer_list<double> Args);   // shim: by-name call without reflection (pawn_helpers.cpp)
	static int32 StumbleFramesFor(const FJamSkaterState& S);
	static float BrakeDecelFor(double SpeedBefore, const FJamSkaterState& S);
};

// JamPawns.h:313-326 (a recording stand-in for a figure, for Jam.Core.Contact.FigureCalls)
UCLASS()
class JAMCORE_API UJamFigureCallProbe : public UObject
{
	GENERATED_BODY()

public:
	UFUNCTION() void PlayStumble(double DirX, double DirZ, int32 Frames) { ++Stumbles; LastDirX = DirX; LastDirZ = DirZ; LastFrames = Frames; }
	UFUNCTION() void SetBraking(bool bOn, float Decel) { ++Brakes; bLastOn = bOn; LastDecel = Decel; }
	UFUNCTION() void PlayWrongShape(FName Kind) {}
	int32 Stumbles = 0, Brakes = 0, LastFrames = 0;
	double LastDirX = 0.0, LastDirZ = 0.0;
	bool bLastOn = false;
	float LastDecel = 0.f;
};
