// Lane A2: one bot match, start to end, with the numbers the tests and the tournament need. Engine-free.
//
// SEAM (lane A1): IJamAISim is the narrow face this lane needs from the simulation. Today it is implemented by
// JamAI::FRefSim (AI/JamBotRefSim.*, a stand-in written from tools/skills/skating-physics.md so this lane can
// measure before UJamSim exists). When UJamSim lands, an adapter implements IJamAISim over it (View fills
// FJamAIWorld from the sim state, Step copies FJamAIInput into FJamInput, StateHash forwards state_hash()) and
// every test and the tournament run on the real sim unchanged.
#pragma once

#include "JamAICore.h"

namespace JamAI
{
	struct FJamMatchSkaterCfg
	{
		int Team = 0;
		ERole Role = ERole::Chaser;
		FVec2 Spawn;
	};

	// The cartridge `game` fields the match needs, with DEFAULTS.md values. Filled from a flat "key=value;..." text
	// (keys are the cartridge paths: rink.length_m=90;skater.speed=11;sk=0,player,-10,0;...), written by
	// tools/tournament/run.mjs from a cartridge file after `values` overrides are applied.
	struct FJamMatchConfig
	{
		double LengthM = 120.0, WidthM = 60.0, CornerRadiusM = 5.0, BoardRestitution = 0.4, IceFriction = 0.015, GoalWidthM = 4.0;
		double Speed = 8.0, Accel = 12.0, TurnRate = 5.0, LateralGrip = 3.0, BrakeDecel = 6.0;
		double FreeSpeedMult = 1.0;   // lane A193: skater.free_speed_mult (lane A185), for the brain's planning only
		double PuckRadiusM = 0.12, PuckMaxSpeed = 30.0, PuckDrag = 0.0;
		double ShotReachM = 1.5, ShotSpeed = 18.0, AimConeDeg = 0.0;   // 0 = absent (no aim assist)
		int ShotCooldownFrames = 24;
		bool bTimer = false;
		int ScoreToWin = 3, TimerFrames = 0, GoalPauseFrames = 120;
		FJamAIParams AI;
		int NumSkaters = 0;
		FJamMatchSkaterCfg Skaters[kMaxSkaters];

		// hockey.regular as shipped (Game/Content/Cartridges/hockey.regular.cartridge.json).
		void SetRegular();
		// hockey.arena.small (90 x 45, speed 11; everything else as regular).
		void SetSmall();
		// Applies "k=v;k=v". Returns false and writes the first bad pair into Err on an unknown key or a bad value.
		bool Parse(const char* Text, char* Err, int ErrLen);
		int PlayerIndex() const;
	};

	struct FJamAIStepEvents
	{
		uint32_t TouchMask = 0;   // bit i: skater i started touching / took the puck this frame
		int Shot = -1;       // skater that shot this frame
		int GoalTeam = -1;   // team that scored this frame
		bool bFaceoff = false;
	};

	class IJamAISim
	{
	public:
		virtual ~IJamAISim() {}
		virtual void Reset(const FJamMatchConfig& C, uint64_t Seed) = 0;
		virtual void View(FJamAIWorld& W) const = 0;
		virtual FJamAIStepEvents Step(const FJamAIInput* In) = 0;
		virtual bool IsOver() const = 0;
		virtual int Winner() const = 0;              // team, or -1 for a draw / not over
		virtual int Score(int Team) const = 0;
		virtual uint64_t StateHash() const = 0;
		virtual double BoardDistance(const FVec2& P) const = 0;   // signed distance to the boards, inside negative
	};

	enum class EJamPlayerMode : uint8_t
	{
		PlayerBot,     // bot_hockey.gd: the human's skater played by FJamPlayerBot
		PlayerBotAI,   // bot_hockey_ai.gd variant (shoot range 22, no peel to the middle)
		Brain,         // the human's slot played by the brain as a chaser, no yields (pure bot-vs-bot)
		Idle           // the human stands still
	};

	struct FJamMatchStats
	{
		uint64_t Seed = 0;
		int Goals[2] = {0, 0};
		int Shots[kMaxSkaters] = {};
		int Touches[kMaxSkaters] = {};
		double MovedMax[kMaxSkaters] = {};   // furthest distance from spawn
		int NumSkaters = 0;
		int PlayerIndex = -1;
		double PuckPathM = 0.0;
		int Stalls = 0;
		int64_t Frames = 0;
		bool bOver = false;
		int Winner = -1;
		uint64_t Hash = 0;
		double MaxBoardDistance = -1e9;      // worst skater centre against the boards (> 0.01 = outside)
		int Faceoffs = 0;
		int FaceoffsWithoutPlayerTouch = 0;  // faceoffs after which the human did not touch the puck within 600 frames
		int MaxFaceoffToTouch = 0;           // frames, worst case
		int64_t PlayFrames = 0;              // frames not frozen
		int GoalFrames[16] = {};             // frame of each goal (first 16)
		uint64_t Hashes[64] = {};            // StateHash every HashEvery frames (first 64)
		int NumHashes = 0;
		int DrawJumps = 0;                   // lane A3 diagnostics: early draw presses the brain sent / draws it took early
		int DrawPresses = 0;
	};

	// Optional trace: called every TraceEvery frames with the world the bots saw and the inputs they sent.
	typedef void (*FJamTraceFn)(void* Ctx, const FJamAIWorld& W, const FJamAIInput* In, const FJamBrain& Brain);

	FJamMatchStats RunMatch(IJamAISim& Sim, const FJamMatchConfig& C, uint64_t Seed, EJamPlayerMode Mode, int64_t MaxFrames, int HashEvery = 600,
		FJamTraceFn Trace = nullptr, void* TraceCtx = nullptr, int TraceEvery = 0);
	// One trace line (no newline): frame, puck, then every skater as role-letter(x,y)>facing-deg [input].
	int FormatTrace(const FJamAIWorld& W, const FJamAIInput* In, const FJamBrain& Brain, char* Buf, int BufLen);

	// One JSON line (no newline) into Buf. Returns the length written.
	int FormatStatsJson(const FJamMatchStats& S, const char* Cartridge, const char* Mode, char* Buf, int BufLen);
	const char* ModeName(EJamPlayerMode M);
	bool ParseMode(const char* Name, EJamPlayerMode& Out);
}
