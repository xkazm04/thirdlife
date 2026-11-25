// Lane A2: stand-in simulation (in AI/, not Tests/, so the tournament commandlet links in Game targets) for the bot tests and the tournament, written from tools/skills/skating-physics.md
// (skater step, rounded-rectangle boards, skater contacts, puck with 4 sub-steps, possession, shot, goal, faceoff).
// Engine-free. It exists only because UJamSim (lane A1) did not exist when this lane started; when UJamSim lands,
// an IJamAISim adapter over it replaces this class in every test (SEAM, see AI/JamBotMatch.h).
//
// Choices the physics recipe leaves open (to agree with lane A1):
//  - possession: a free puck within 0.6 m of a stick point (0.6 m ahead of the skater), slower than 12 m/s relative,
//    is taken by the nearest; the shooter cannot retake it for 15 frames (else a 18 m/s shot at 8 m/s skating
//    is retaken at once: relative 10 m/s < 12); an opponent's stick within 0.5 m steals a puck held 30+ frames;
//  - a shot may also be taken by a non-carrier whose reach covers a carried puck (a poke);
//  - analog thrust: top speed is speed * |move| (so game.ai.speed_scale and red_skill slow bots, as in Godot);
//  - shot.aim_cone_deg present: a shot within the cone of the goal centre goes to the goal centre;
//  - faceoff drop: the puck lands up to 0.5 m off centre from the seeded stream, so the seed changes the match.
#pragma once

#include "JamBotMatch.h"

namespace JamAI
{
	// SEAM (lane A1): FJamRandom. splitmix64 here.
	struct FRefRandom
	{
		uint64_t State = 1;
		void Seed(uint64_t S) { State = S * 0x9E3779B97F4A7C15ull + 0x632BE59BD9B4E019ull; }
		uint64_t Next()
		{
			uint64_t Z = (State += 0x9E3779B97F4A7C15ull);
			Z = (Z ^ (Z >> 30)) * 0xBF58476D1CE4E5B9ull;
			Z = (Z ^ (Z >> 27)) * 0x94D049BB133111EBull;
			return Z ^ (Z >> 31);
		}
		double Unit() { return static_cast<double>(Next() >> 11) * (1.0 / 9007199254740992.0); }   // [0, 1)
	};

	class FRefSim : public IJamAISim
	{
	public:
		void Reset(const FJamMatchConfig& C, uint64_t Seed) override;
		void View(FJamAIWorld& W) const override;
		FJamAIStepEvents Step(const FJamAIInput* In) override;
		bool IsOver() const override { return bOver; }
		int Winner() const override { return WinnerTeam; }
		int Score(int Team) const override { return Scores[Team]; }
		uint64_t StateHash() const override;
		double BoardDistance(const FVec2& P) const override;

		static constexpr double DT = 1.0 / 60.0;
		static constexpr double SkaterRadius = 0.4;
		static constexpr double StickAhead = 0.6;
		static constexpr double TakeRadius = 0.6;
		static constexpr double StealRadius = 0.5;
		static constexpr int StealProtectFrames = 30;
		static constexpr int ShooterNoTakeFrames = 15;
		static constexpr double NetDepth = 1.5;

	private:
		struct FSk
		{
			FVec2 P, V;
			double Yaw = 0.0;
			int CooldownUntil = 0;
			int NoTakeUntil = 0;
		};
		FJamMatchConfig Cfg;
		FRefRandom Rng;
		FSk Sk[kMaxSkaters];
		FVec2 PuckP, PuckV;
		int Owner = -1;
		int OwnerSince = 0;
		int LastToucher = -1;
		int Frame = 0;
		int Scores[2] = {0, 0};
		int PauseLeft = 0;
		bool bOver = false;
		int WinnerTeam = -1;
		double Hx = 60, Hz = 30, Rc = 5, Gx = 56, Ghw = 2;

		void Faceoff();
		FVec2 Fwd(int i) const;
		FVec2 Stick(int i) const;
		bool CanShoot(int i) const;
		void BoardNormal(const FVec2& P, double& D, FVec2& N) const;
		bool PuckSubstep(double H, int& GoalTeam);
		void PushSkaterFromNets(FSk& S) const;
		int CheckGoalCrossing(const FVec2& From, const FVec2& To) const;
	};
}
