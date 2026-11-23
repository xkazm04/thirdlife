// Lane A2: match runner and config parser (engine-free). See JamBotMatch.h.
#include "JamBotMatch.h"
#include "DifficultyProfile.h"

#include <cstdio>
#include <cstdlib>
#include <cstring>

namespace JamAI
{
	namespace BotMatchLocal
	{
		bool ParseRole(const char* S, ERole& Out)
		{
			if (std::strcmp(S, "player") == 0) { Out = ERole::Player; return true; }
			if (std::strcmp(S, "chaser") == 0) { Out = ERole::Chaser; return true; }
			if (std::strcmp(S, "support") == 0) { Out = ERole::Support; return true; }
			if (std::strcmp(S, "back") == 0) { Out = ERole::Back; return true; }
			return false;
		}

		void AddSkater(FJamMatchConfig& C, int Team, ERole Role, double X, double Z)
		{
			if (C.NumSkaters < kMaxSkaters)
			{
				FJamMatchSkaterCfg& S = C.Skaters[C.NumSkaters++];
				S.Team = Team;
				S.Role = Role;
				S.Spawn = FVec2(X, Z);
			}
		}

		void SetErr(char* Err, int ErrLen, const char* Msg, const char* Pair)
		{
			if (Err && ErrLen > 0)
			{
				std::snprintf(Err, static_cast<size_t>(ErrLen), "%s: %s", Msg, Pair);
			}
		}
	}
	using namespace BotMatchLocal;

	void FJamMatchConfig::SetRegular()
	{
		*this = FJamMatchConfig();
		AimConeDeg = 8.0;
		AddSkater(*this, 0, ERole::Player, -10, 0);
		AddSkater(*this, 0, ERole::Chaser, -10, -10);
		AddSkater(*this, 0, ERole::Back, -30, 0);
		AddSkater(*this, 1, ERole::Chaser, 10, 0);
		AddSkater(*this, 1, ERole::Support, 10, 10);
		AddSkater(*this, 1, ERole::Back, 30, 0);
	}

	void FJamMatchConfig::SetSmall()
	{
		SetRegular();
		LengthM = 90.0;
		WidthM = 45.0;
		Speed = 11.0;
	}

	int FJamMatchConfig::PlayerIndex() const
	{
		for (int i = 0; i < NumSkaters; ++i)
		{
			if (Skaters[i].Role == ERole::Player)
			{
				return i;
			}
		}
		return -1;
	}

	bool FJamMatchConfig::Parse(const char* Text, char* Err, int ErrLen)
	{
		bool bSkatersReset = false;
		bool bAiNumberSeen = false;   // lane A3: ai.difficulty applies its profile, so it must come before explicit ai.* numbers
		const char* P = Text;
		char Pair[256];
		while (P && *P)
		{
			const char* End = std::strchr(P, ';');
			const size_t Len = End ? static_cast<size_t>(End - P) : std::strlen(P);
			if (Len >= sizeof(Pair))
			{
				BotMatchLocal::SetErr(Err, ErrLen, "pair too long", "");
				return false;
			}
			std::memcpy(Pair, P, Len);
			Pair[Len] = 0;
			P = End ? End + 1 : nullptr;
			if (Len == 0)
			{
				continue;
			}
			char* Eq = std::strchr(Pair, '=');
			if (!Eq)
			{
				BotMatchLocal::SetErr(Err, ErrLen, "no '=' in pair", Pair);
				return false;
			}
			*Eq = 0;
			const char* Key = Pair;
			const char* Val = Eq + 1;
			if (std::strcmp(Key, "sk") == 0)
			{
				// sk=<team>,<role>,<x>,<z>
				if (!bSkatersReset)
				{
					NumSkaters = 0;
					bSkatersReset = true;
				}
				char Buf[128];
				std::snprintf(Buf, sizeof(Buf), "%s", Val);
				char* Tok[4] = {};
				int N = 0;
				for (char* T = Buf; N < 4 && T;)
				{
					Tok[N++] = T;
					char* C = std::strchr(T, ',');
					if (C) { *C = 0; T = C + 1; } else { T = nullptr; }
				}
				ERole Role = ERole::Chaser;
				if (N != 4 || !ParseRole(Tok[1], Role) || NumSkaters >= kMaxSkaters)
				{
					*Eq = '=';
					BotMatchLocal::SetErr(Err, ErrLen, "bad skater", Pair);
					return false;
				}
				AddSkater(*this, std::atoi(Tok[0]), Role, std::atof(Tok[2]), std::atof(Tok[3]));
				continue;
			}
			if (std::strcmp(Key, "ai.difficulty") == 0)
			{
				EDifficulty Level = EDifficulty::Pro;
				if (!ParseDifficulty(Val, Level) || bAiNumberSeen)
				{
					*Eq = '=';
					BotMatchLocal::SetErr(Err, ErrLen, bAiNumberSeen ? "ai.difficulty must come before the ai numbers" : "bad ai.difficulty", Pair);
					return false;
				}
				ApplyDifficultyProfile(GetDifficultyProfile(Level), AI);
				continue;
			}
			if (std::strcmp(Key, "ai.tune") == 0)
			{
				// lane A3: tools/sweep tuning hook, "ai.tune=opp.reaction_frames:6,hold_radius_m:3" (':' and ',' as the pair already uses '=' and ';')
				char Tune[256];
				std::snprintf(Tune, sizeof(Tune), "%s", Val);
				for (char* C = Tune; *C; ++C) { if (*C == ':') { *C = '='; } else if (*C == ',') { *C = ';'; } }
				char TuneErr[200] = {};
				if (!ApplyDifficultyTune(Tune, AI, TuneErr, sizeof(TuneErr)))
				{
					BotMatchLocal::SetErr(Err, ErrLen, "bad ai.tune", TuneErr);
					return false;
				}
				continue;
			}
			if (std::strcmp(Key, "rules.mode") == 0)
			{
				if (std::strcmp(Val, "timer") == 0) { bTimer = true; }
				else if (std::strcmp(Val, "first_to") == 0) { bTimer = false; }
				else { *Eq = '='; BotMatchLocal::SetErr(Err, ErrLen, "bad rules.mode", Pair); return false; }
				continue;
			}
			char* NumEnd = nullptr;
			const double V = std::strtod(Val, &NumEnd);
			if (NumEnd == Val || *NumEnd != 0)
			{
				*Eq = '=';
				BotMatchLocal::SetErr(Err, ErrLen, "not a number", Pair);
				return false;
			}
			struct FKey { const char* Name; double* D; int* I; };
			const FKey Keys[] = {
				{"rink.length_m", &LengthM, nullptr}, {"rink.width_m", &WidthM, nullptr}, {"rink.corner_radius_m", &CornerRadiusM, nullptr},
				{"rink.board_restitution", &BoardRestitution, nullptr}, {"rink.ice_friction", &IceFriction, nullptr}, {"rink.goal_width_m", &GoalWidthM, nullptr},
				{"skater.speed", &Speed, nullptr}, {"skater.accel", &Accel, nullptr}, {"skater.turn_rate", &TurnRate, nullptr},
				{"skater.lateral_grip", &LateralGrip, nullptr}, {"skater.brake_decel", &BrakeDecel, nullptr},
				{"puck.radius_m", &PuckRadiusM, nullptr}, {"puck.max_speed", &PuckMaxSpeed, nullptr}, {"puck.drag", &PuckDrag, nullptr},
				{"shot.reach_m", &ShotReachM, nullptr}, {"shot.speed", &ShotSpeed, nullptr}, {"shot.aim_cone_deg", &AimConeDeg, nullptr},
				{"shot.cooldown_frames", nullptr, &ShotCooldownFrames},
				{"rules.score_to_win", nullptr, &ScoreToWin}, {"rules.timer_frames", nullptr, &TimerFrames}, {"rules.goal_pause_frames", nullptr, &GoalPauseFrames},
				{"ai.yield_margin_m", &AI.YieldMarginM, nullptr}, {"ai.yield_radius_m", &AI.YieldRadiusM, nullptr}, {"ai.hold_radius_m", &AI.HoldRadiusM, nullptr},
				{"ai.speed_scale", &AI.SpeedScale, nullptr}, {"ai.red_skill", &AI.RedSkill, nullptr},
			};
			bool bFound = false;
			for (const FKey& K : Keys)
			{
				if (std::strcmp(K.Name, Key) == 0)
				{
					if (K.D) { *K.D = V; } else { *K.I = static_cast<int>(V); }
					bFound = true;
					bAiNumberSeen = bAiNumberSeen || std::strncmp(Key, "ai.", 3) == 0;
					break;
				}
			}
			if (!bFound)
			{
				*Eq = '=';
				BotMatchLocal::SetErr(Err, ErrLen, "unknown key", Pair);
				return false;
			}
		}
		return true;
	}

	const char* ModeName(EJamPlayerMode M)
	{
		switch (M)
		{
		case EJamPlayerMode::PlayerBot: return "playerbot";
		case EJamPlayerMode::PlayerBotAI: return "playerbot_ai";
		case EJamPlayerMode::Brain: return "brain";
		default: return "idle";
		}
	}

	bool ParseMode(const char* Name, EJamPlayerMode& Out)
	{
		if (std::strcmp(Name, "playerbot") == 0) { Out = EJamPlayerMode::PlayerBot; return true; }
		if (std::strcmp(Name, "playerbot_ai") == 0) { Out = EJamPlayerMode::PlayerBotAI; return true; }
		if (std::strcmp(Name, "brain") == 0) { Out = EJamPlayerMode::Brain; return true; }
		if (std::strcmp(Name, "idle") == 0) { Out = EJamPlayerMode::Idle; return true; }
		return false;
	}

	int FormatTrace(const FJamAIWorld& W, const FJamAIInput* In, const FJamBrain& Brain, char* Buf, int BufLen)
	{
		int N = std::snprintf(Buf, static_cast<size_t>(BufLen), "TRACE f=%lld%s stall=%d puck(%.1f,%.1f v%.1f)", static_cast<long long>(W.Frame),
			W.bFrozen ? " frozen" : "", Brain.IsStalled() ? 1 : 0, W.PuckPos.X, W.PuckPos.Y, W.PuckVel.Length());
		static const char Letters[] = {'P', 'C', 'S', 'B'};
		for (int i = 0; i < W.NumSkaters && N < BufLen - 80; ++i)
		{
			const FJamAISkater& S = W.Skaters[i];
			const char L = i == W.PlayerIndex ? 'H' : Letters[static_cast<int>(Brain.LastRole(i))];
			N += std::snprintf(Buf + N, static_cast<size_t>(BufLen - N), " %d%c(%.1f,%.1f)>%.0f[%.1f,%.1f%s]", S.Team, L, S.Pos.X, S.Pos.Y,
				std::atan2(S.Facing.Y, S.Facing.X) * 180.0 / kPi, In[i].Move.X, In[i].Move.Y, In[i].bShoot ? " SHOOT" : "");
		}
		return N;
	}

	FJamMatchStats RunMatch(IJamAISim& Sim, const FJamMatchConfig& C, uint64_t Seed, EJamPlayerMode Mode, int64_t MaxFrames, int HashEvery,
		FJamTraceFn Trace, void* TraceCtx, int TraceEvery)
	{
		FJamMatchStats St;
		St.Seed = Seed;
		St.NumSkaters = C.NumSkaters;
		St.PlayerIndex = C.PlayerIndex();
		Sim.Reset(C, Seed);
		FJamBrain Brain;
		Brain.Reset();
		Brain.Params = C.AI;
		// lane A3: the sim facts the skills read
		Brain.Params.InterceptSpeed = C.Speed;
		Brain.Params.FreeSpeedMult = C.FreeSpeedMult;   // lane A193
		Brain.Params.AimConeDeg = C.AimConeDeg;
		FJamPlayerBot Bot;
		if (Mode == EJamPlayerMode::PlayerBotAI)
		{
			Bot.ShootRangeM = 22.0;
			Bot.bPeelToMiddle = false;
		}
		FJamAIWorld W;
		FJamAIInput In[kMaxSkaters];
		Sim.View(W);
		FVec2 PrevPuck = W.PuckPos;
		const int Pi = St.PlayerIndex;
		// faceoff -> human touch tracking
		int64_t SinceFaceoff = 0;
		bool bWaitingTouch = Pi >= 0;
		St.Faceoffs = 1;
		const int TouchWindow = 600;
		for (int64_t F = 0; F < MaxFrames && !Sim.IsOver(); ++F)
		{
			Sim.View(W);
			for (int i = 0; i < kMaxSkaters; ++i)
			{
				In[i] = FJamAIInput();
			}
			if (Mode == EJamPlayerMode::Brain)
			{
				// no human: the player's slot is a chaser and nobody yields
				FJamAIWorld Wb = W;
				Wb.PlayerIndex = -1;
				Brain.Think(Wb, In);
			}
			else
			{
				Brain.Think(W, In);
				if (Pi >= 0 && Mode != EJamPlayerMode::Idle)
				{
					In[Pi] = Bot.Think(W);
				}
			}
			if (Trace && TraceEvery > 0 && W.Frame % TraceEvery == 0)
			{
				Trace(TraceCtx, W, In, Brain);
			}
			const FJamAIStepEvents Ev = Sim.Step(In);
			++St.Frames;
			Sim.View(W);
			if (!W.bFrozen)
			{
				++St.PlayFrames;
			}
			const double Step = W.PuckPos.DistTo(PrevPuck);
			if (Step < 5.0)
			{
				St.PuckPathM += Step;
			}
			PrevPuck = W.PuckPos;
			for (int i = 0; i < W.NumSkaters; ++i)
			{
				const double M = W.Skaters[i].Pos.DistTo(C.Skaters[i].Spawn);
				if (M > St.MovedMax[i]) { St.MovedMax[i] = M; }
				const double Bd = Sim.BoardDistance(W.Skaters[i].Pos);
				if (Bd > St.MaxBoardDistance) { St.MaxBoardDistance = Bd; }
			}
			for (int i = 0; i < W.NumSkaters; ++i)
			{
				if ((Ev.TouchMask >> i) & 1u) { ++St.Touches[i]; }
			}
			if (Pi >= 0 && ((Ev.TouchMask >> Pi) & 1u))
			{
				if (bWaitingTouch)
				{
					bWaitingTouch = false;
					if (SinceFaceoff > St.MaxFaceoffToTouch) { St.MaxFaceoffToTouch = static_cast<int>(SinceFaceoff); }
					if (SinceFaceoff > TouchWindow) { ++St.FaceoffsWithoutPlayerTouch; }
				}
			}
			if (Ev.Shot >= 0)
			{
				++St.Shots[Ev.Shot];
			}
			if (Ev.GoalTeam >= 0)
			{
				const int G = St.Goals[0] + St.Goals[1];
				if (G < 16) { St.GoalFrames[G] = static_cast<int>(St.Frames); }
				++St.Goals[Ev.GoalTeam];
				if (bWaitingTouch)
				{
					// a goal before the human touched: counts against the window only when the window was exceeded
					if (SinceFaceoff > TouchWindow) { ++St.FaceoffsWithoutPlayerTouch; }
					if (SinceFaceoff > St.MaxFaceoffToTouch) { St.MaxFaceoffToTouch = static_cast<int>(SinceFaceoff); }
					bWaitingTouch = false;
				}
			}
			if (Ev.bFaceoff)
			{
				++St.Faceoffs;
				SinceFaceoff = 0;
				bWaitingTouch = Pi >= 0;
			}
			else if (!W.bFrozen)
			{
				++SinceFaceoff;
			}
			if (HashEvery > 0 && St.Frames % HashEvery == 0 && St.NumHashes < 64)
			{
				St.Hashes[St.NumHashes++] = Sim.StateHash();
			}
		}
		if (bWaitingTouch && SinceFaceoff > TouchWindow)
		{
			++St.FaceoffsWithoutPlayerTouch;
			if (SinceFaceoff > St.MaxFaceoffToTouch) { St.MaxFaceoffToTouch = static_cast<int>(SinceFaceoff); }
		}
		St.Stalls = Brain.StallCount();
		St.DrawJumps = Brain.GetDrawJumps();
		St.DrawPresses = Brain.GetDrawPresses();
		St.bOver = Sim.IsOver();
		St.Winner = Sim.Winner();
		St.Hash = Sim.StateHash();
		return St;
	}

	int FormatStatsJson(const FJamMatchStats& S, const char* Cartridge, const char* Mode, char* Buf, int BufLen)
	{
		int N = std::snprintf(Buf, static_cast<size_t>(BufLen),
			"{\"tool\":\"thirdjam.tournament/1\",\"cartridge\":\"%s\",\"mode\":\"%s\",\"seed\":%llu,\"goals\":[%d,%d],\"winner\":%d,\"over\":%s,"
			"\"frames\":%lld,\"play_frames\":%lld,\"puck_path_m\":%.1f,\"stalls\":%d,\"faceoffs\":%d,\"faceoffs_without_player_touch\":%d,"
			"\"max_faceoff_to_touch\":%d,\"max_board_distance\":%.3f,\"hash\":\"%016llx\",\"player\":%d,\"draw_jumps\":%d,\"draw_presses\":%d",
			Cartridge, Mode, static_cast<unsigned long long>(S.Seed), S.Goals[0], S.Goals[1], S.Winner, S.bOver ? "true" : "false",
			static_cast<long long>(S.Frames), static_cast<long long>(S.PlayFrames), S.PuckPathM, S.Stalls, S.Faceoffs, S.FaceoffsWithoutPlayerTouch,
			S.MaxFaceoffToTouch, S.MaxBoardDistance, static_cast<unsigned long long>(S.Hash), S.PlayerIndex, S.DrawJumps, S.DrawPresses);
		auto Arr = [&](const char* Name, const int* I, const double* D)
		{
			N += std::snprintf(Buf + N, static_cast<size_t>(BufLen - N), ",\"%s\":[", Name);
			for (int k = 0; k < S.NumSkaters && N < BufLen; ++k)
			{
				if (I) { N += std::snprintf(Buf + N, static_cast<size_t>(BufLen - N), "%s%d", k ? "," : "", I[k]); }
				else { N += std::snprintf(Buf + N, static_cast<size_t>(BufLen - N), "%s%.1f", k ? "," : "", D[k]); }
			}
			N += std::snprintf(Buf + N, static_cast<size_t>(BufLen - N), "]");
		};
		Arr("shots", S.Shots, nullptr);
		Arr("touches", S.Touches, nullptr);
		Arr("moved_max_m", nullptr, S.MovedMax);
		const int G = S.Goals[0] + S.Goals[1] < 16 ? S.Goals[0] + S.Goals[1] : 16;
		N += std::snprintf(Buf + N, static_cast<size_t>(BufLen - N), ",\"goal_frames\":[");
		for (int k = 0; k < G && N < BufLen; ++k)
		{
			N += std::snprintf(Buf + N, static_cast<size_t>(BufLen - N), "%s%d", k ? "," : "", S.GoalFrames[k]);
		}
		N += std::snprintf(Buf + N, static_cast<size_t>(BufLen - N), "]}");
		return N;
	}
}
