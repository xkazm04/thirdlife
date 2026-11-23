// Lane T5 (tiger run 2026-11-15-the-play, item T5.a = scope C2 slice 1, pool P16 (5)): every pass says why it failed. MEASUREMENT ONLY, read-only.
//
// FJamPassFateObserver watches a UJamSim after each Step (it only reads the sim: no state, no rule, no hash change) and gives every pass, human or bot,
// one fate and one cause, logged as one line:
//   JAMPASS f=<release frame> from=<i> to=<j> fate=<mate|opp|loose|self|dead> cause=<arrived|aim|intercept|drift|on_point> ...
// fate  = who ended the pass: a mate of the passer touched it first (mate), an opponent (opp), nobody inside 180 frames (loose), the passer played the puck
//         again (self), the play stopped (dead: a goal, out of play, the end).
// cause = why (precedence in this order, the first that holds):
//   arrived    a mate touched it first (to_called=1 when he was the called receiver).
//   aim        the release does not meet the called receiver even if he skates on as he skated at the release: UJamSim::AimPassAt, the sim's own solver, on the
//              launched speed finds no meeting (he outruns it), or the launched direction misses the solved meeting point by catch_m or more (aim_miss_m: the
//              exit or the speed floor moved the pass after the solve, P18), or the pass had no receiver at all (to=-1, along the stick).
//   intercept  an opponent touched it first, no later than 2 frames after the solved meeting frame: an opponent reached the lane before the puck met him.
//   drift      at the solved meeting frame (or at the end of the pass, if earlier) the called receiver's blade is catch_m or more from where the solver led him
//              (blade + velocity x t at the release, AimPassAt's constant-velocity lead): he left the path the solver assumed (drift_m).
//   on_point   he was on the solved path and the aim was good, and still the pass was not his (a refused catch: down, braced, a cooldown, the puck high or fast).
// Counts by cause are kept for human and bot passes apart; Logged == Passes is the coverage check (every pass gets a cause).
#pragma once

#include "CoreMinimal.h"

class UJamSim;

enum class EJamPassCause : uint8 { Arrived, Aim, Intercept, Drift, OnPoint, Count };

struct JAMCORE_API FJamPassFateCounts
{
	int32 Passes = 0;                                         // releases seen
	int32 Logged = 0;                                         // releases given a fate and a cause
	int32 ByCause[static_cast<int32>(EJamPassCause::Count)] = {};
	int32 ToCalled = 0;                                       // arrived at the called receiver himself
	int32 AimNone = 0, AimUnsolved = 0, AimMiss = 0;
	int32 Previewed = 0, PreviewSame = 0;                     // the human's held passes, and those whose release went to the man the preview named          // the aim cause split: no receiver (to=-1), the solver finds no meeting, the launch misses the solved point
	void Add(const FJamPassFateCounts& O);
	double Share(EJamPassCause C) const { return Logged > 0 ? static_cast<double>(ByCause[static_cast<int32>(C)]) / Logged : 0.0; }
	FString Summary() const;                                  // "passes=N logged=N arrived=.. aim=.. intercept=.. drift=.. on_point=.."
};

class JAMCORE_API FJamPassFateObserver
{
public:
	bool bLog = true;              // one JAMPASS line per pass (UE_LOG LogJamPass, Display)
	FString Tag;                   // prefixed to each line's fields (a seed, a cell), may be empty
	FJamPassFateCounts Human, Bot;

	static const TCHAR* CauseName(EJamPassCause C);

	// A new match: forget the pass in flight (counts are kept: call ResetCounts for those).
	void ResetMatch();
	void ResetCounts() { Human = FJamPassFateCounts(); Bot = FJamPassFateCounts(); }
	// After every UJamSim::Step (and once after the last one, then Finish).
	void Observe(const UJamSim& Sim);
	// The match ended with a pass still open: its fate is dead.
	void Finish(const UJamSim& Sim);

private:
	struct FOpen
	{
		bool bOpen = false;
		bool bHuman = false;
		int64 At = 0;              // release frame
		int32 From = -1, To = -1;
		bool bSaucer = false;
		bool bSolved = false;      // AimPassAt met him at the launched speed
		double AimMissM = 0.0;     // launched direction's miss of the solved meeting point
		double MeetS = 0.0;        // solved flight time (s)
		int64 MeetFrame = 0;
		FVector2D Blade0 = FVector2D::ZeroVector, Vel0 = FVector2D::ZeroVector, MeetAt = FVector2D::ZeroVector;
		double DriftM = -1.0;      // at the meeting frame (-1: not reached yet)
		double MissAtMeetM = -1.0; // his blade to the puck at the meeting frame
		double Speed = 0.0;
		int32 PreviewTo = -2;      // the human's pass: whom UJamSim::HumanPassTarget (the power meter's and the brain's call) named on the last held frame; -2 = no hold seen
	};
	FOpen Open;
	int32 PrevLastTouch = -1;
	int32 HeldPreviewTo = -2;      // the last held frame's preview for the human (P18: does the preview name the man the release picks?)
	bool bPrevPlaying = false;

	void Close(const UJamSim& Sim, const TCHAR* Fate, int32 Taker);
	void Release(const UJamSim& Sim, int32 Passer, int32 To, bool bSaucer);
};
