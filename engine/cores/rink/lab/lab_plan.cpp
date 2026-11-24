// Third Life rink core, LAB (lane K8 "balance"): the planning hand. See lab_plan.h. Measurement only.
#include "lab_plan.h"
#include "lab_filter.h"

#include <cmath>
#include <cstdio>
#include <cstring>

namespace Lab
{
	namespace
	{
		typedef FVector2D V2;
		inline V2 Norm(const V2& A) { const double L = A.Size(); return L > 1e-9 ? V2(A.X / L, A.Y / L) : V2(0.0, 0.0); }
		inline double Dot(const V2& A, const V2& B) { return A.X * B.X + A.Y * B.Y; }
		inline JamAI::FVec2 AI(const V2& A) { return JamAI::FVec2(A.X, A.Y); }
		inline double AngleDeg(const V2& A, const V2& B)
		{
			const V2 Na = Norm(A), Nb = Norm(B);
			const double C = FMath::Clamp(Dot(Na, Nb), -1.0, 1.0);
			return std::acos(C) * 180.0 / 3.14159265358979323846;
		}
		void Unbind(UJamSim& S) { S.SetRuleHook(nullptr); S.SetZoneSource(nullptr); S.SetModifierSource(nullptr); }

		const char* Names[I_Count] = {
			"none", "drive", "drive_l", "drive_r", "drive_sprint", "cut_l", "cut_r", "stop", "protect",
			"pass0", "pass1", "pass2", "pass3", "shoot_tap", "shoot_half", "shoot_full", "deke_l", "deke_r", "spin",
			"pressure", "pressure_sprint", "poke", "lift", "check", "brace", "goalside", "cover_lane",
			"chase", "chase_sprint", "hold", "one_timer", "receive",
			"net_front", "weak_side", "support",
		};
		enum { C_Frozen, C_Draw, C_Me, C_Mate, C_Opp, C_Loose };
		inline bool IsCarry(int I) { return I >= I_Drive && I <= I_Spin; }
		inline bool IsDefend(int I) { return I >= I_Pressure && I <= I_CoverLane; }
		inline bool IsLoose(int I) { return I >= I_Chase && I <= I_Receive; }
		inline bool IsMate(int I) { return I >= I_NetFront && I <= I_Support; }
		inline bool IsAimed(int I) { return (I >= I_Pass0 && I <= I_ShootFull) || I == I_DekeL || I == I_DekeR || I == I_OneTimer; }
		// The k-th team-mate of Me (index order), -1 = none.
		int MateOf(const UJamSim& S, int Me, int K)
		{
			const TArray<FJamSkaterState>& Sk = S.GetSkaters();
			int At = 0;
			for (const FJamSkaterState& O : Sk) { if (O.Index == Me || O.Team != Sk[Me].Team) continue; if (At == K) return O.Index; ++At; }
			return -1;
		}
	}

	const char* IntentName(int I) { return (I >= 0 && I < I_Count) ? Names[I] : "?"; }

	bool ParsePlanProfile(const char* Name, FPlanProfile& Out)
	{
		const std::string N(Name ? Name : "");
		// A person's limits (not thirdjam's playtester's 12 / 6 / 3 frames, which a script needs because it never anticipates): a choice reaction of 300 / 233 /
		// 167 ms, a decision every 0.5 / 0.33 / 0.2 s, a reading of the outcome that is off by up to 0.15 / 0.08 / 0.04 goals, the aim error and the presses
		// a second of thirdjam's three classes. Calibrated once, on hockey.regular, against thirdjam's own hands' ladder (docs/design/HOCKEY-BALANCE.md section 6).
		if (N == "novice") { Out = FPlanProfile(); Out.Name = "novice"; Out.ReactionFrames = 18; Out.AimNoiseDeg = 10.0; Out.DecideEvery = 30; Out.Horizon = 30; Out.PressPerSec = 3; Out.JudgeNoise = 0.15; Out.LapseEvery = 600; Out.LapseFrames = 30; return true; }
		if (N == "regular") { Out = FPlanProfile(); Out.Name = "regular"; Out.ReactionFrames = 14; Out.AimNoiseDeg = 5.0; Out.DecideEvery = 20; Out.Horizon = 45; Out.PressPerSec = 5; Out.JudgeNoise = 0.08; return true; }
		if (N == "good") { Out = FPlanProfile(); Out.Name = "good"; Out.ReactionFrames = 10; Out.AimNoiseDeg = 2.0; Out.DecideEvery = 12; Out.Horizon = 45; Out.PressPerSec = 8; Out.JudgeNoise = 0.04; return true; }
		return false;
	}

	std::string PlanStatsJson(const FPlanStats& S)
	{
		std::string J = "{";
		char B[256];
		std::snprintf(B, sizeof(B), "\"decisions\":%lld,\"rollouts\":%lld,\"rollout_steps\":%lld,\"frames\":%lld,\"clone_checked\":%lld,\"clone_mismatch\":%lld,\"chosen\":{",
			S.Decisions, S.Rollouts, S.RolloutSteps, S.Frames, S.CloneChecked, S.CloneMismatch);
		J += B;
		bool bFirst = true;
		for (int i = 1; i < I_Count; ++i) { if (!S.Chosen[i]) continue; std::snprintf(B, sizeof(B), "%s\"%s\":%lld", bFirst ? "" : ",", Names[i], S.Chosen[i]); J += B; bFirst = false; }
		J += "},\"frames_in\":{";
		bFirst = true;
		for (int i = 1; i < I_Count; ++i) { if (!S.FramesIn[i]) continue; std::snprintf(B, sizeof(B), "%s\"%s\":%lld", bFirst ? "" : ",", Names[i], S.FramesIn[i]); J += B; bFirst = false; }
		J += "}}";
		return J;
	}

	FPlanHand::FPlanHand()
	{
		for (int i = 0; i < kRing; ++i) { Ring[i] = new UJamSim(); RingFrame[i] = -1; }
		Bel = new UJamSim(); Roll = new UJamSim(); Check = new UJamSim();
	}
	FPlanHand::~FPlanHand()
	{
		for (int i = 0; i < kRing; ++i) delete Ring[i];
		delete Bel; delete Roll; delete Check;
	}

	void FPlanHand::Reset(const FPlanProfile& Profile, uint64_t InSeed)
	{
		P = Profile;
		if (P.ReactionFrames > kRing - 2) P.ReactionFrames = kRing - 2;
		Seed = InSeed;
		Tick = 0;
		Cur = I_None; CurSt = FIntentState();
		LastClass = -1; LastDecide = -100000;
		for (int i = 0; i < 16; ++i) PressFrames[i] = -100000;
		PressAt = 0; PlayFrames = 0;
		bPrevShootHeld = bPrevPassHeld = false;
		DrawWait = -1;
		Stats = FPlanStats();
		for (int i = 0; i < kRing; ++i) RingFrame[i] = -1;
	}

	double FPlanHand::Noise(long long Window, int Salt) const
	{
		uint64_t H = Seed * 0x9E3779B97F4A7C15ull + static_cast<uint64_t>(Window) * 0xBF58476D1CE4E5B9ull + static_cast<uint64_t>(Salt) * 0x94D049BB133111EBull;
		H ^= H >> 31; H *= 0xBF58476D1CE4E5B9ull; H ^= H >> 29; H *= 0x94D049BB133111EBull; H ^= H >> 32;
		return static_cast<double>(H & 0xFFFFFF) / static_cast<double>(0x7FFFFF) - 1.0;   // [-1, 1]
	}

	int FPlanHand::Classify(const UJamSim& S, int Me) const
	{
		if (S.IsDrawOpen()) return C_Draw;
		if (S.GetPhase() != EJamSimPhase::Playing) return C_Frozen;
		const int C = S.CarrierIndex();
		if (C == Me) return C_Me;
		if (C < 0) return C_Loose;
		return S.GetSkaters()[C].Team == S.GetSkaters()[Me].Team ? C_Mate : C_Opp;
	}

	bool FPlanHand::Allowed(int I) const
	{
		if (Remove == 0) return true;
		if ((Remove & V_Sprint) && (I == I_DriveSprint || I == I_PressureSprint || I == I_ChaseSprint)) return false;
		if ((Remove & V_Stop) && I == I_Stop) return false;
		if ((Remove & (V_Shield | V_Stick)) && I == I_Protect) return false;
		if ((Remove & V_Pass) && I >= I_Pass0 && I <= I_Pass3) return false;
		if ((Remove & V_Shoot) && (I == I_ShootTap || I == I_ShootHalf || I == I_ShootFull || I == I_DekeL || I == I_DekeR || I == I_OneTimer)) return false;
		if ((Remove & V_Tap) && (I == I_ShootTap || I == I_DekeL || I == I_DekeR)) return false;
		if ((Remove & V_Charge) && (I == I_ShootHalf || I == I_ShootFull)) return false;
		if ((Remove & V_OneTimer) && I == I_OneTimer) return false;
		if ((Remove & (V_Deke | V_Stick)) && (I == I_DekeL || I == I_DekeR)) return false;
		if ((Remove & V_Spin) && I == I_Spin) return false;
		if ((Remove & V_Poke) && I == I_Poke) return false;
		if ((Remove & V_Lift) && I == I_Lift) return false;
		if ((Remove & V_Check) && I == I_Check) return false;
		if ((Remove & V_Brace) && I == I_Brace) return false;
		return true;
	}

	int FPlanHand::Menu(const UJamSim& S, int Me, int Class, int* Out) const
	{
		int N = 0;
		auto Add = [&](int I) { if (Allowed(I)) Out[N++] = I; };
		const TArray<FJamSkaterState>& Sk = S.GetSkaters();
		const FJamSkaterState& M = Sk[Me];
		const V2 Goal(S.AttackGoalX(M.Team), 0.0);
		if (Class == C_Me)
		{
			Add(I_Drive); Add(I_DriveL); Add(I_DriveR); Add(I_DriveSprint); Add(I_CutL); Add(I_CutR); Add(I_Stop);
			const int Opp = S.NearestOpponent(M);
			const double OppD = Opp >= 0 ? V2::Distance(Sk[Opp].Pos, M.Pos) : 1e9;
			if (OppD < 6.0) { Add(I_Protect); Add(I_Spin); }
			for (int k = 0; k < 4; ++k)
			{
				const int Mate = MateOf(S, Me, k);
				if (Mate < 0 || !Sk[Mate].CanAct()) continue;
				if (V2::Distance(Sk[Mate].Pos, M.Pos) < 3.0) continue;
				Add(I_Pass0 + k);
			}
			const double Gd = V2::Distance(S.GetPuck().Pos, Goal);
			if (Gd < 34.0) { Add(I_ShootTap); Add(I_ShootHalf); Add(I_ShootFull); }
			if (Gd < 14.0) { Add(I_DekeL); Add(I_DekeR); }
		}
		else if (Class == C_Opp)
		{
			Add(I_Pressure); Add(I_PressureSprint); Add(I_Poke); Add(I_Lift); Add(I_Check); Add(I_Brace); Add(I_Goalside); Add(I_CoverLane);
		}
		else if (Class == C_Loose)
		{
			Add(I_Chase); Add(I_ChaseSprint); Add(I_Hold);
			const FJamPuckState& Pk = S.GetPuck();
			const bool bMatePass = Pk.PassFrames > 0 && Sk.IsValidIndex(Pk.PassBy) && Pk.PassBy != Me && Sk[Pk.PassBy].Team == M.Team;
			if (bMatePass && (Pk.PassTo == Me || Pk.PassTo < 0)) Add(I_OneTimer);
		}
		else if (Class == C_Mate)
		{
			Add(I_NetFront); Add(I_WeakSide); Add(I_Support);
		}
		return N;
	}

	// One frame of an intent on the state S (a rollout's, or the believed present). AimOffDeg turns a shot's or a pass's aim (the hand's error).
	JamAI::FJamAIInput FPlanHand::Act(int Intent, FIntentState& St, const UJamSim& S, int Me, double AimOffDeg) const
	{
		JamAI::FJamAIInput In;
		const TArray<FJamSkaterState>& Sk = S.GetSkaters();
		const FJamSkaterState& M = Sk[Me];
		if (!M.CanAct() && !M.IsStumbling()) return In;
		const FJamGameConfig& G = S.GetConfig();
		const double Gx = S.AttackGoalX(M.Team);
		const double Dir = Gx >= 0.0 ? 1.0 : -1.0;
		const V2 Goal(Gx, 0.0), Own(-Gx, 0.0);
		const FJamPuckState& Pk = S.GetPuck();
		const int Class = Classify(S, Me);
		const int C = S.CarrierIndex();
		auto Seek = [&](const V2& To) { const V2 D = To - M.Pos; In.Move = D.Size() > 0.5 ? AI(Norm(D)) : JamAI::FVec2(); };
		auto StickAt = [&](const V2& To) { In.Stick = AI(Norm(To - M.Pos)); };
		// An intent that no longer fits the situation falls back to the plain one of the situation it is in (a rollout runs past a turnover).
		int I = Intent;
		if (Class == C_Frozen || Class == C_Draw) return In;
		if (Class == C_Me && !IsCarry(I) && I != I_OneTimer) I = I_Drive;
		else if (Class == C_Opp && !IsDefend(I)) I = I_Pressure;
		else if (Class == C_Loose && !IsLoose(I)) I = I_Chase;
		else if (Class == C_Mate && !IsMate(I)) I = I_NetFront;
		if (I != Intent) St.bDone = true;

		const V2 ToGoal = Norm(Goal - Pk.Pos);
		switch (I)
		{
		case I_Drive: case I_DriveSprint:
			Seek(Goal + V2(Dir * 1.0, 0.0));
			In.bSprint = I == I_DriveSprint;
			break;
		case I_DriveL: case I_DriveR:
			In.Move = AI(Norm(Goal - M.Pos).GetRotated(I == I_DriveL ? 35.0 : -35.0));
			break;
		case I_CutL: case I_CutR:
		{
			const V2 Base = M.Vel.Size() > 1.0 ? Norm(M.Vel) : M.Forward();
			In.Move = AI(Base.GetRotated(I == I_CutL ? 80.0 : -80.0));
			if (St.T >= 20) St.bDone = true;
			break;
		}
		case I_Stop:
			if (M.Vel.Size() > 1.5) In.Move = AI(Norm(M.Vel) * -1.0);
			else St.bDone = true;
			break;
		case I_Protect:
		{
			Seek(Goal);
			const int Opp = S.NearestOpponent(M);
			if (Opp >= 0) In.Stick = AI(Norm(M.Pos - Sk[Opp].Pos));
			break;
		}
		case I_Pass0: case I_Pass1: case I_Pass2: case I_Pass3:
		{
			const int Mate = MateOf(S, Me, I - I_Pass0);
			if (Mate < 0) { St.bDone = true; Seek(Goal); break; }
			const V2 To = Sk[Mate].Pos + Sk[Mate].Vel * 0.35;
			const double D = V2::Distance(To, M.Pos);
			const bool bHoldOk = !(Remove & V_Saucer);
			const int Hold = !bHoldOk || D < 14.0 ? 0 : (D < 24.0 ? 10 : 22);
			if (!St.bFired)
			{
				In.Stick = AI(Norm(To - M.Pos).GetRotated(AimOffDeg));
				In.Move = AI(M.Vel.Size() > 1.0 ? Norm(M.Vel) : M.Forward());
				if (Hold == 0) { In.bPass = true; St.bFired = true; }
				else if (St.T < Hold) In.bPassHeld = true;
				else St.bFired = true;   // the release
			}
			else { Seek(Goal); if (St.T > Hold + 3) St.bDone = true; }
			break;
		}
		case I_ShootTap: case I_ShootHalf: case I_ShootFull:
		{
			const V2 Want = ToGoal.GetRotated(AimOffDeg);
			const int Hold = I == I_ShootTap ? 0 : (I == I_ShootHalf ? G.Shot.ChargeFramesMax / 2 : G.Shot.ChargeFramesMax);
			if (!St.bFired)
			{
				In.Move = AI(Want);
				const bool bLined = AngleDeg(M.Forward(), Want) <= 6.0;
				if (St.T < Hold) In.bShootHeld = true;
				else if (bLined || St.T >= Hold + 14)
				{
					if (Hold == 0) In.bShoot = true;   // else: the release of the hold
					St.bFired = true;
				}
				else if (Hold > 0) In.bShootHeld = true;
			}
			else { Seek(Goal); if (St.T > Hold + 16) St.bDone = true; }
			break;
		}
		case I_DekeL: case I_DekeR:
		{
			const double Side = I == I_DekeL ? 1.0 : -1.0;
			const V2 Fw = M.Forward();
			In.Move = AI(ToGoal);
			In.Stick = AI(Norm(V2(-Fw.Y, Fw.X) * Side + Fw * 0.3));
			if (St.T == 0) In.bDeke = true;
			else if (St.T >= 8 && !St.bFired) { In.bShoot = true; St.bFired = true; }
			if (St.T > 14) St.bDone = true;
			break;
		}
		case I_Spin:
			Seek(Goal);
			if (St.T == 0) In.bSpin = true;
			if (St.T > 24) St.bDone = true;
			break;
		case I_Pressure: case I_PressureSprint: case I_Poke: case I_Lift: case I_Check: case I_Brace:
		{
			const FJamSkaterState& K = Sk[C];
			const double D = V2::Distance(K.Pos, M.Pos);
			Seek(K.Pos + K.Vel * FMath::Clamp(D / 14.0, 0.0, 0.5));
			StickAt(Pk.Pos);
			In.bSprint = I == I_PressureSprint || I == I_Check;
			if (I == I_Poke)
			{
				const double Bd = V2::Distance(Pk.Pos, M.Pos);
				if (S.GetFrame() + 1 >= M.PokeReadyFrame && M.PokeWindow <= 0 && Bd <= UJamSim::SkaterRadius + G.Stick.ReachM + 0.45 && St.T - St.Aux >= 20) { In.bPoke = true; St.Aux = St.T; St.bFired = true; }
			}
			else if (I == I_Lift)
			{
				if (S.GetFrame() + 1 >= M.LiftReadyFrame && D <= 2.0 * UJamSim::SkaterRadius + G.Stick.LiftRangeM - 0.1 && St.T - St.Aux >= 30) { In.bLift = true; St.Aux = St.T; St.bFired = true; }
			}
			else if (I == I_Check)
			{
				const double Closing = Dot(M.Vel - K.Vel, Norm(K.Pos - M.Pos));
				if (Closing > 2.0 && D - 2.0 * UJamSim::SkaterRadius <= Closing * (G.Contact.CheckWindupFrames + 6) / 60.0 + 0.3 && St.T - St.Aux >= 40) { In.bCheck = true; St.Aux = St.T; St.bFired = true; }
			}
			else if (I == I_Brace) { In.bCrossHold = D < 6.0; In.bSprint = false; }
			break;
		}
		case I_Goalside:
		{
			const FJamSkaterState& K = Sk[C];
			const V2 To = K.Pos + Norm(Own - K.Pos) * FMath::Min(5.0, 0.5 * V2::Distance(K.Pos, Own));
			Seek(To);
			StickAt(Pk.Pos);
			break;
		}
		case I_CoverLane:
		{
			const FJamSkaterState& K = Sk[C];
			int Danger = -1; double Best = 1e9;
			for (const FJamSkaterState& O : Sk) { if (O.Team == M.Team || O.Index == C || !O.CanAct()) continue; const double Dd = V2::Distance(O.Pos, Own); if (Dd < Best) { Best = Dd; Danger = O.Index; } }
			if (Danger < 0) { Seek(K.Pos); break; }
			Seek(K.Pos + (Sk[Danger].Pos - K.Pos) * 0.6);
			StickAt(Pk.Pos);
			break;
		}
		case I_Chase: case I_ChaseSprint: case I_Receive:
		{
			const double D = V2::Distance(Pk.Pos, M.Pos);
			Seek(Pk.Pos + Pk.Vel * FMath::Min(0.8, D / 13.0));
			StickAt(Pk.Pos);
			In.bSprint = I == I_ChaseSprint;
			break;
		}
		case I_Hold:
			Seek(Pk.Pos + Norm(Own - Pk.Pos) * 8.0);
			StickAt(Pk.Pos);
			break;
		case I_OneTimer:
		{
			const double D = V2::Distance(Pk.Pos, M.Pos);
			if (Class == C_Me)
			{
				In.Move = AI(ToGoal.GetRotated(AimOffDeg));
				const int Win = G.Shot.OneTimerWindowFrames;
				const bool bIn = Win > 0 && M.PassReceivedFrame >= 0 && (S.GetFrame() + 1) - M.PassReceivedFrame <= Win;
				if (bIn && !St.bFired) { In.bShoot = true; St.bFired = true; }
				else St.bDone = true;
			}
			else if (D > 4.0) { Seek(Pk.Pos + Pk.Vel * FMath::Min(0.6, D / 16.0)); StickAt(Pk.Pos); }
			else { In.Move = AI(Norm(Goal - M.Pos) * 0.5); StickAt(Pk.Pos); }
			break;
		}
		case I_NetFront: case I_WeakSide: case I_Support:
		{
			const FJamSkaterState& K = Sk[C];
			const double Side = K.Pos.Y >= 0.0 ? -1.0 : 1.0;
			V2 To;
			if (I == I_NetFront) To = Goal + V2(-Dir * 5.0, Side * 2.5);
			else if (I == I_WeakSide) To = V2(Dir * FMath::Min(K.Pos.X * Dir + 10.0, FMath::Abs(Gx) - 6.0), Side * 9.0);
			else To = K.Pos + V2(-Dir * 6.0, Side * 5.0);
			Seek(To);
			StickAt(K.Pos);
			break;
		}
		default: break;
		}
		return In;
	}

	// What the hand expects of the other nine: they keep doing what it last saw them do; an opponent within 12 m of a puck that is not his side's goes
	// for it (a pass in flight: for its line), and one that reaches a carrier presses his stick on him.
	void FPlanHand::ModelOthers(const UJamSim& S, int Me, const FSeen& Sn, JamAI::FJamAIInput* Out) const
	{
		const TArray<FJamSkaterState>& Sk = S.GetSkaters();
		const int N = FMath::Min(Sk.Num(), JamAI::kMaxSkaters);
		const int MyTeam = Sk[Me].Team;
		const FJamPuckState& Pk = S.GetPuck();
		const int C = S.CarrierIndex();
		const bool bOppPuck = C >= 0 && Sk[C].Team != MyTeam;
		for (int i = 0; i < N; ++i)
		{
			if (i == Me) continue;
			JamAI::FJamAIInput In;
			if (i < Sn.N) { In.Move = Sn.In[i].Move; In.Stick = Sn.In[i].Stick; In.bSprint = Sn.In[i].bSprint; In.bGoalie = Sn.In[i].bGoalie; In.GoalieSide = Sn.In[i].GoalieSide; }
			const FJamSkaterState& O = Sk[i];
			if (O.Team != MyTeam && !bOppPuck && O.CanAct())
			{
				const double D = V2::Distance(O.Pos, Pk.Pos);
				if (D < 12.0)
				{
					V2 To = Pk.Pos + Pk.Vel * FMath::Min(0.6, D / 13.0);
					const double Sp = Pk.Vel.Size();
					if (C < 0 && Sp > 4.0)
					{
						// the nearest point of the puck's line ahead of it
						const V2 L = Pk.Vel / Sp;
						const double Along = FMath::Clamp(Dot(O.Pos - Pk.Pos, L), 0.0, Sp * 1.0);
						To = Pk.Pos + L * Along;
					}
					const double Mag = FMath::Max(1.0, In.Move.Length());
					const V2 Mv = Norm(To - O.Pos) * Mag;
					In.Move = AI(Mv);
					In.Stick = AI(Norm(Pk.Pos - O.Pos));
					if (C >= 0 && V2::Distance(O.Pos, Sk[C].Pos) <= 2.0 * UJamSim::SkaterRadius + 0.9 && (S.GetFrame() + i * 7) % 30 == 0) In.bLift = true;
				}
			}
			Out[i] = In;
		}
	}

	void FPlanHand::StepSim(UJamSim& S, const JamAI::FJamAIInput* In, int N)
	{
		Buf.SetNum(N);
		for (int i = 0; i < N; ++i)
		{
			FJamInput& I = Buf[i];
			I = FJamInput();
			I.Move = FVector2D(In[i].Move.X, In[i].Move.Y);
			I.bShoot = In[i].bShoot; I.bShootHeld = In[i].bShootHeld; I.bCheck = In[i].bCheck; I.bBrake = In[i].bBrake; I.bPass = In[i].bPass; I.bPassHeld = In[i].bPassHeld;
			I.Stick = FVector2D(In[i].Stick.X, In[i].Stick.Y);
			I.bPoke = In[i].bPoke; I.bLift = In[i].bLift; I.bDeke = In[i].bDeke; I.bSpin = In[i].bSpin; I.bSprint = In[i].bSprint; I.bAbility = In[i].bAbility; I.bCrossHold = In[i].bCrossHold;
		}
		S.Step(Buf);
	}

	// What the position is worth to the hand's side, in goals (about): who has the puck, how near which net, who gets a loose one first, is he on his feet.
	double FPlanHand::Value(const UJamSim& S, int Me) const
	{
		const TArray<FJamSkaterState>& Sk = S.GetSkaters();
		const FJamSkaterState& M = Sk[Me];
		const double Gx = S.AttackGoalX(M.Team);
		const V2 Goal(Gx, 0.0), Own(-Gx, 0.0);
		const FJamPuckState& Pk = S.GetPuck();
		const double ThrFor = std::exp(-V2::Distance(Pk.Pos, Goal) / 18.0), ThrAg = std::exp(-V2::Distance(Pk.Pos, Own) / 18.0);
		const double Mine = 0.06 + 0.30 * ThrFor, Mates = 0.05 + 0.26 * ThrFor, Theirs = -(0.05 + 0.28 * ThrAg);
		const int C = S.CarrierIndex();
		double V = 0.0;
		if (C == Me) V = Mine;
		else if (C >= 0) V = Sk[C].Team == M.Team ? Mates : Theirs;
		else
		{
			// a loose puck: a shot on its way into their net, or a race
			const double Sp = Pk.Vel.Size();
			bool bOnNet = false;
			if (Sp > 10.0 && Pk.Vel.X * Gx > 0.0)
			{
				const double T = (Gx - Pk.Pos.X) / Pk.Vel.X;
				const double Y = Pk.Pos.Y + Pk.Vel.Y * T;
				bOnNet = T > 0.0 && T < 1.0 && FMath::Abs(Y) < S.GetConfig().Rink.GoalWidthM * 0.5 - 0.2;
			}
			if (bOnNet) V = 0.35;
			else
			{
				double Tm = 1e9, To = 1e9;
				for (const FJamSkaterState& O : Sk)
				{
					if (!O.CanAct()) continue;
					const double T = V2::Distance(O.Pos, Pk.Pos + Pk.Vel * 0.3) / 11.0;
					if (O.Team == M.Team) Tm = FMath::Min(Tm, T); else To = FMath::Min(To, T);
				}
				const double Pm = 1.0 / (1.0 + std::exp(-(To - Tm) / 0.25));
				V = Pm * Mates + (1.0 - Pm) * Theirs;
			}
		}
		if (M.IsDown()) V -= 0.06 * FMath::Min(1.0, M.KnockFrames / 90.0);
		else if (M.IsStumbling()) V -= 0.02;
		// where he stands when he does not have it: open near their net while his side has it; goal-side of the puck while they have it
		if (C != Me)
		{
			const bool bOurs = C >= 0 && Sk[C].Team == M.Team;
			if (bOurs)
			{
				const int Opp = S.NearestOpponent(M);
				const double Open = Opp >= 0 ? FMath::Clamp((V2::Distance(Sk[Opp].Pos, M.Pos) - 1.0) / 3.0, 0.0, 1.0) : 1.0;
				V += 0.04 * std::exp(-V2::Distance(M.Pos, Goal) / 18.0) * Open;
			}
			else if (C >= 0)
			{
				const V2 Line = Norm(Own - Pk.Pos);
				const double Along = Dot(M.Pos - Pk.Pos, Line);
				const V2 Foot = Pk.Pos + Line * Along;
				const double Off = V2::Distance(M.Pos, Foot);
				if (Along > 0.0) V += 0.03 * FMath::Clamp(1.0 - Off / 6.0, 0.0, 1.0) * FMath::Clamp(1.0 - Along / 15.0, 0.0, 1.0);
				V += 0.02 * FMath::Clamp(1.0 - V2::Distance(M.Pos, Pk.Pos) / 10.0, 0.0, 1.0);
			}
		}
		return V;
	}

	double FPlanHand::Rollout(const UJamSim& From, int Me, int Intent, FIntentState St, const FSeen& Sn, double AimOffDeg)
	{
		*Roll = From;
		Unbind(*Roll);
		const int Team = Roll->GetSkaters()[Me].Team;
		const int S0 = Roll->GetScore(Team), O0 = Roll->GetScore(1 - Team);
		const int N = FMath::Min(Roll->GetSkaters().Num(), JamAI::kMaxSkaters);
		const int H = P.Horizon + (IsAimed(Intent) ? 30 : 0);
		JamAI::FJamAIInput In[JamAI::kMaxSkaters];
		double Pen = 0.0;
		bool bWasDown = Roll->GetSkaters()[Me].IsDown();
		++Stats.Rollouts;
		for (int h = 0; h < H; ++h)
		{
			ModelOthers(*Roll, Me, Sn, In);
			In[Me] = Act(Intent, St, *Roll, Me, AimOffDeg);
			++St.T;
			StepSim(*Roll, In, N);
			++Stats.RolloutSteps;
			const double Disc = std::pow(0.995, h);
			if (Roll->GetScore(Team) > S0) return 1.0 * Disc + Pen;
			if (Roll->GetScore(1 - Team) > O0) return -1.0 * Disc + Pen;
			const bool bDown = Roll->GetSkaters()[Me].IsDown();
			if (bDown && !bWasDown) Pen -= 0.05;
			bWasDown = bDown;
			if (Roll->GetPhase() != EJamSimPhase::Playing) break;
		}
		return Value(*Roll, Me) + Pen;
	}

	void FPlanHand::CheckBegin(const UJamSim& S)
	{
		*Check = S;
		Unbind(*Check);
	}

	void FPlanHand::CheckEnd(const UJamSim& S, const JamAI::FJamAIInput* In, int N)
	{
		StepSim(*Check, In, N);
		++Stats.CloneChecked;
		if (Check->StateHash() != S.StateHash()) ++Stats.CloneMismatch;
	}

	JamAI::FJamAIInput FPlanHand::Think(const UJamSim& S, int Me, const JamAI::FJamAIInput* All, int N)
	{
		++Stats.Frames;
		// what he sees now is kept; what he acts on is what he saw ReactionFrames ago, carried forward with his own keys and the others as he expects them
		const int Slot = static_cast<int>(Tick % kRing);
		*Ring[Slot] = S;
		RingFrame[Slot] = Tick;
		Seen[Slot].N = N;
		for (int i = 0; i < N; ++i) Seen[Slot].In[i] = All[i];
		const long long Back = FMath::Min<long long>(P.ReactionFrames, Tick);
		const long long Fb = Tick - Back;
		const int BSlot = static_cast<int>(Fb % kRing);
		*Bel = *Ring[BSlot];
		Unbind(*Bel);
		const FSeen& Sn = Seen[BSlot];
		JamAI::FJamAIInput In[JamAI::kMaxSkaters];
		for (long long f = Fb; f < Tick; ++f)
		{
			ModelOthers(*Bel, Me, Sn, In);
			In[Me] = Sent[f % kRing];
			StepSim(*Bel, In, N);
		}
		JamAI::FJamAIInput Out;
		const int TrueClass = Classify(S, Me);
		const int Class = Classify(*Bel, Me);
		if (TrueClass == C_Frozen || TrueClass == C_Draw)
		{
			// the draw: any press once it is open, his reaction after the drop (thirdjam's playtester: 4 frames plus its reaction)
			if (TrueClass == C_Draw)
			{
				if (DrawWait < 0) DrawWait = 0;
				++DrawWait;
				const FJamSkaterState& M = S.GetSkaters()[Me];
				Out.Stick = AI(Norm(S.GetPuck().Pos - M.Pos));
				if (DrawWait == P.ReactionFrames + 4 && !(Remove & V_Draw)) Out.bPoke = true;
				if (DrawWait > P.ReactionFrames + 4) Out.Move = AI(Norm(S.GetPuck().Pos - M.Pos));
			}
			else DrawWait = -1;
			Cur = I_None; CurSt = FIntentState(); LastClass = -1;
			Sent[Slot] = Out;
			bPrevShootHeld = bPrevPassHeld = false;
			++Tick;
			return Out;
		}
		DrawWait = -1;
		++PlayFrames;
		if (Class == C_Frozen || Class == C_Draw)
		{
			// he has not yet seen the puck drop: he goes for it
			const FJamSkaterState& M = Bel->GetSkaters()[Me];
			Out.Move = AI(Norm(Bel->GetPuck().Pos - M.Pos));
			Out.Stick = Out.Move;
			Sent[Slot] = Out;
			++Tick;
			return Out;
		}
		const bool bHolding = Cur == I_OneTimer && !CurSt.bDone && CurSt.T < 120;
		const bool bDecide = Cur == I_None || CurSt.bDone || (Class != LastClass && !bHolding) || Tick - LastDecide >= P.DecideEvery;
		if (bDecide)
		{
			int Opts[I_Count];
			const int NOpt = Menu(*Bel, Me, Class, Opts);
			double BestV = -1e9, CurV = -1e9;
			int Best = I_None;
			const double Err = 0.7 * P.AimNoiseDeg;
			for (int k = 0; k < NOpt; ++k)
			{
				const int I = Opts[k];
				const bool bCont = I == Cur && !CurSt.bDone;
				const FIntentState St0 = bCont ? CurSt : FIntentState();
				double V;
				if (IsAimed(I) && Err > 0.0) V = 0.5 * (Rollout(*Bel, Me, I, St0, Sn, Err) + Rollout(*Bel, Me, I, St0, Sn, -Err));
				else V = Rollout(*Bel, Me, I, St0, Sn, 0.0);
				if (P.JudgeNoise > 0.0) V += P.JudgeNoise * Noise(Tick, 100 + I);
				if (bCont) CurV = V;
				if (V > BestV) { BestV = V; Best = I; }
			}
			++Stats.Decisions;
			if (Best != I_None && !(CurV > -1e8 && BestV < CurV + 0.015))
			{
				if (Best != Cur || CurSt.bDone) { Cur = Best; CurSt = FIntentState(); }
			}
			if (Cur != I_None) ++Stats.Chosen[Cur];
			LastDecide = Tick;
			LastClass = Class;
		}
		if (Cur != I_None)
		{
			const double AimOff = Noise(Tick / 120, 7) * P.AimNoiseDeg;
			Out = Act(Cur, CurSt, *Bel, Me, AimOff);
			++CurSt.T;
			++Stats.FramesIn[Cur];
		}
		// a person's hands: so many presses a second, and (the novice) a lapse
		const bool bEdge = Out.bShoot || Out.bPass || Out.bCheck || Out.bPoke || Out.bLift || Out.bDeke || Out.bSpin || (Out.bShootHeld && !bPrevShootHeld) || (Out.bPassHeld && !bPrevPassHeld);
		if (bEdge)
		{
			int Recent = 0;
			for (int i = 0; i < 16; ++i) if (Tick - PressFrames[i] < 60) ++Recent;
			if (Recent >= P.PressPerSec && !bPrevShootHeld && !bPrevPassHeld)
			{
				Out.bShoot = Out.bPass = Out.bCheck = Out.bPoke = Out.bLift = Out.bDeke = Out.bSpin = false;
				Out.bShootHeld = Out.bPassHeld = false;
			}
			else { PressFrames[PressAt] = Tick; PressAt = (PressAt + 1) % 16; }
		}
		if (P.LapseEvery > 0 && (PlayFrames % P.LapseEvery) < P.LapseFrames && PlayFrames >= P.LapseEvery) Out = JamAI::FJamAIInput();
		bPrevShootHeld = Out.bShootHeld; bPrevPassHeld = Out.bPassHeld;
		Sent[Slot] = Out;
		++Tick;
		return Out;
	}
}
