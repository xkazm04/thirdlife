// Third Life rink core, LAB (lane K8 "balance"): the planning hand. Measurement only; never in a game.
//
// thirdjam's playtester (AI/JamPlaytester.cpp) is a script written for thirdjam's rules: when a rule changes, or a verb is taken away, it
// keeps pressing what it was written to press. FPlanHand has no script. Every few frames it looks at the game as a person would see it
// (late, by its reaction time), rolls the real simulation forward under each of a small menu of intents ("drive the net", "pass to that
// mate", "charge a shot", "poke him", "get goal-side" ...), and takes the one whose outcome is worth most. What it knows about the other
// nine is what a player knows: they keep doing what they were doing, opponents near the puck go for it and hit a carrier they reach. It
// never reads the bots' brain. Its limits are a person's: it sees late, its aim is off by a few degrees, it presses a limited number of
// buttons a second, it re-decides only every few frames, and it looks less than a second ahead.
//
// The rollouts run UJamSim itself (a copy of the match's sim; rule hooks, zones and effects unbound: hockey.regular and hockey.thirdlife
// have none), so a rule changed by a cartridge number or by a thirdlife patch is the rule the hand plans with. A verb's value is what this
// hand does with it: -remove=<verb> takes the verb out of its menu (it re-plans without it) and out of its keys (the filter).
//
// Determinism: no wall clock, no engine randomness; noise is a hash of (seed, frame window, salt). Same seed = same match.
#pragma once

#include "CoreMinimal.h"
#include "JamSim.h"
#include "JamAICore.h"
#include <string>

namespace Lab
{
	struct FPlanProfile
	{
		const char* Name = "regular";
		int ReactionFrames = 6;      // sees the world this many frames late (thirdjam's playtester: 12 / 6 / 3)
		double AimNoiseDeg = 5.0;    // aim error on a shot or a pass (thirdjam's playtester: 10 / 5 / 2)
		int DecideEvery = 10;        // re-decides every this many frames (sooner when the situation changes)
		int Horizon = 45;            // looks this many frames ahead
		int PressPerSec = 5;         // button presses a second, at most
		double JudgeNoise = 0.0;     // how far off his reading of an outcome can be (in goals, either way; a fixed draw per decision and intent)
		int LapseEvery = 0;          // every this many play frames stops pressing for LapseFrames (the novice)
		int LapseFrames = 30;
	};
	bool ParsePlanProfile(const char* Name, FPlanProfile& Out);   // novice | regular | good

	enum EIntent : int
	{
		I_None,
		// with the puck
		I_Drive, I_DriveL, I_DriveR, I_DriveSprint, I_CutL, I_CutR, I_Stop, I_Protect,
		I_Pass0, I_Pass1, I_Pass2, I_Pass3, I_ShootTap, I_ShootHalf, I_ShootFull, I_DekeL, I_DekeR, I_Spin,
		// an opponent has it
		I_Pressure, I_PressureSprint, I_Poke, I_Lift, I_Check, I_Brace, I_Goalside, I_CoverLane,
		// loose
		I_Chase, I_ChaseSprint, I_Hold, I_OneTimer, I_Receive,
		// a mate has it
		I_NetFront, I_WeakSide, I_Support,
		I_Count
	};
	const char* IntentName(int I);

	struct FPlanStats
	{
		long long Decisions = 0, Rollouts = 0, RolloutSteps = 0, Frames = 0;
		long long Chosen[I_Count] = {};       // decisions that picked the intent
		long long FramesIn[I_Count] = {};     // frames played under it
		long long CloneMismatch = 0;          // -plancheck: frames where a copy stepped with the true inputs did not hash as the match
		long long CloneChecked = 0;
	};
	std::string PlanStatsJson(const FPlanStats& S);

	class FPlanHand
	{
	public:
		FPlanProfile P;
		uint32_t Remove = 0;                  // EVerb bits (lab_filter.h): out of the menu
		bool bCheckClone = false;             // -plancheck
		FPlanStats Stats;

		FPlanHand();
		~FPlanHand();
		FPlanHand(const FPlanHand&) = delete;
		FPlanHand& operator=(const FPlanHand&) = delete;
		void Reset(const FPlanProfile& Profile, uint64_t Seed);
		// One frame. S = the match's sim before this frame's step; All = the inputs every skater is about to send (the bots' from the brain).
		JamAI::FJamAIInput Think(const UJamSim& S, int Pi, const JamAI::FJamAIInput* All, int N);
		// -plancheck: a copy of the sim (hooks unbound, as every rollout) stepped with the inputs the match's step got must hash as the match.
		void CheckBegin(const UJamSim& S);
		void CheckEnd(const UJamSim& S, const JamAI::FJamAIInput* In, int N);

	private:
		struct FIntentState { int T = 0; bool bFired = false; bool bDone = false; int Aux = 0; };
		struct FSeen { JamAI::FJamAIInput In[JamAI::kMaxSkaters]; int N = 0; };
		enum { kRing = 32 };
		UJamSim* Ring[kRing] = {};            // the sim as it was before frame f's step, f % kRing
		FSeen Seen[kRing];
		JamAI::FJamAIInput Sent[kRing];       // what the hand sent on frame f
		long long RingFrame[kRing];
		UJamSim* Bel = nullptr;               // the believed present
		UJamSim* Roll = nullptr;              // a rollout
		UJamSim* Check = nullptr;             // -plancheck
		TArray<FJamInput> Buf;
		uint64_t Seed = 0;
		long long Tick = 0;
		int Cur = I_None;
		FIntentState CurSt;
		int LastClass = -1;
		long long LastDecide = -100000;
		long long PressFrames[16];
		int PressAt = 0;
		long long PlayFrames = 0;
		bool bPrevShootHeld = false, bPrevPassHeld = false;
		int DrawWait = -1;

		double Noise(long long Window, int Salt) const;
		int Classify(const UJamSim& S, int Me) const;
		int Menu(const UJamSim& S, int Me, int Class, int* Out) const;
		bool Allowed(int Intent) const;
		JamAI::FJamAIInput Act(int Intent, FIntentState& St, const UJamSim& S, int Me, double AimOffDeg) const;
		void ModelOthers(const UJamSim& S, int Me, const FSeen& Sn, JamAI::FJamAIInput* Out) const;
		void StepSim(UJamSim& S, const JamAI::FJamAIInput* In, int N);
		double Rollout(const UJamSim& From, int Me, int Intent, FIntentState St, const FSeen& Sn, double AimOffDeg);
		double Value(const UJamSim& S, int Me) const;
	};
}
