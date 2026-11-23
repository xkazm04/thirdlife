// Lane A2: stand-in simulation (engine-free). See BotRefSim.h.
#include "JamBotRefSim.h"

namespace JamAI
{
	namespace RefSimLocal
	{
		inline double Wrap(double A)
		{
			while (A > kPi) { A -= 2.0 * kPi; }
			while (A <= -kPi) { A += 2.0 * kPi; }
			return A;
		}
		inline double RotateToward(double From, double To, double Step)
		{
			const double D = Wrap(To - From);
			if (std::fabs(D) <= Step) { return Wrap(To); }
			return Wrap(From + (D > 0.0 ? Step : -Step));
		}
		inline double MoveToward(double A, double B, double D)
		{
			if (std::fabs(B - A) <= D) { return B; }
			return A + (B > A ? D : -D);
		}
		inline double SignOf(double V) { return V >= 0.0 ? 1.0 : -1.0; }
		inline double Max0(double V) { return V > 0.0 ? V : 0.0; }
		inline FVec2 ClosestOnSegment(const FVec2& P, const FVec2& A, const FVec2& B)
		{
			const FVec2 Ab = B - A;
			const double L2 = Ab.Dot(Ab);
			double T = L2 > 1e-12 ? (P - A).Dot(Ab) / L2 : 0.0;
			T = T < 0.0 ? 0.0 : (T > 1.0 ? 1.0 : T);
			return A + Ab * T;
		}
		// Push a circle (P, R) out of a point Q it overlaps, reflecting V with restitution E. Returns true on contact.
		inline bool PushFromPoint(FVec2& P, FVec2& V, const FVec2& Q, double R, double E, const FVec2& Fallback)
		{
			FVec2 D = P - Q;
			double L = D.Length();
			if (L >= R) { return false; }
			const FVec2 N = L > 1e-9 ? D * (1.0 / L) : Fallback;
			P = Q + N * R;
			const double Vn = V.Dot(N);
			if (Vn < 0.0) { V -= N * ((1.0 + E) * Vn); }
			return true;
		}
		inline void Fnv(uint64_t& H, int64_t V)
		{
			for (int i = 0; i < 8; ++i)
			{
				H ^= static_cast<uint64_t>((V >> (i * 8)) & 0xFF);
				H *= 0x100000001B3ull;
			}
		}
		inline int64_t Q(double V, double Scale) { return static_cast<int64_t>(std::floor(V * Scale + 0.5)); }
	}
	using namespace RefSimLocal;

	void FRefSim::Reset(const FJamMatchConfig& C, uint64_t Seed)
	{
		Cfg = C;
		Rng.Seed(Seed);
		Hx = C.LengthM * 0.5;
		Hz = C.WidthM * 0.5;
		Rc = C.CornerRadiusM;
		Gx = Hx - 4.0;
		Ghw = C.GoalWidthM * 0.5;
		Frame = 0;
		Scores[0] = Scores[1] = 0;
		PauseLeft = 0;
		bOver = false;
		WinnerTeam = -1;
		for (int i = 0; i < kMaxSkaters; ++i)
		{
			Sk[i] = FSk();
		}
		Faceoff();
	}

	void FRefSim::Faceoff()
	{
		for (int i = 0; i < Cfg.NumSkaters; ++i)
		{
			Sk[i].P = Cfg.Skaters[i].Spawn;
			Sk[i].V = FVec2();
			Sk[i].Yaw = Cfg.Skaters[i].Team == 0 ? 0.0 : kPi;
			Sk[i].NoTakeUntil = 0;
		}
		const double Jx = (Rng.Unit() - 0.5);
		const double Jy = (Rng.Unit() - 0.5);
		PuckP = FVec2(Jx, Jy);
		PuckV = FVec2();
		Owner = -1;
		LastToucher = -1;
	}

	FVec2 FRefSim::Fwd(int i) const { return FVec2(std::cos(Sk[i].Yaw), std::sin(Sk[i].Yaw)); }
	FVec2 FRefSim::Stick(int i) const { return Sk[i].P + Fwd(i) * StickAhead; }

	bool FRefSim::CanShoot(int i) const
	{
		if (bOver || PauseLeft > 0 || Frame < Sk[i].CooldownUntil)
		{
			return false;
		}
		const FVec2 To = PuckP - Sk[i].P;
		const double D = To.Length();
		if (D > Cfg.ShotReachM)
		{
			return false;
		}
		return D < 0.05 || Fwd(i).Dot(To * (1.0 / D)) >= 0.5;
	}

	void FRefSim::BoardNormal(const FVec2& P, double& D, FVec2& N) const
	{
		const double Qx = std::fabs(P.X) - (Hx - Rc);
		const double Qy = std::fabs(P.Y) - (Hz - Rc);
		const double Mx = Max0(Qx), My = Max0(Qy);
		D = std::sqrt(Mx * Mx + My * My) + (Qx > Qy ? (Qx < 0.0 ? Qx : 0.0) : (Qy < 0.0 ? Qy : 0.0)) - Rc;
		if (Qx > 0.0 && Qy > 0.0)
		{
			N = FVec2(SignOf(P.X) * Qx, SignOf(P.Y) * Qy).Normalized();
		}
		else if (Qx > Qy)
		{
			N = FVec2(SignOf(P.X), 0.0);
		}
		else
		{
			N = FVec2(0.0, SignOf(P.Y));
		}
	}

	double FRefSim::BoardDistance(const FVec2& P) const
	{
		double D = 0.0;
		FVec2 N;
		BoardNormal(P, D, N);
		return D;
	}

	void FRefSim::PushSkaterFromNets(FSk& S) const
	{
		for (int Side = -1; Side <= 1; Side += 2)
		{
			const double X0 = Side > 0 ? Gx : -Gx - NetDepth;
			const double X1 = Side > 0 ? Gx + NetDepth : -Gx;
			const FVec2 Qp(S.P.X < X0 ? X0 : (S.P.X > X1 ? X1 : S.P.X), S.P.Y < -Ghw ? -Ghw : (S.P.Y > Ghw ? Ghw : S.P.Y));
			const bool bInside = Qp.X == S.P.X && Qp.Y == S.P.Y;
			if (bInside)
			{
				// inside the net box: out through the nearest face
				const double Dl = S.P.X - X0, Dr = X1 - S.P.X, Dd = S.P.Y + Ghw, Du = Ghw - S.P.Y;
				double M = Dl; FVec2 N(-1, 0);
				if (Dr < M) { M = Dr; N = FVec2(1, 0); }
				if (Dd < M) { M = Dd; N = FVec2(0, -1); }
				if (Du < M) { M = Du; N = FVec2(0, 1); }
				S.P += N * (M + SkaterRadius);
				const double Vn = S.V.Dot(N);
				if (Vn < 0.0) { S.V -= N * Vn; }
			}
			else
			{
				PushFromPoint(S.P, S.V, Qp, SkaterRadius, 0.0, FVec2(-Side, 0));
			}
		}
	}

	int FRefSim::CheckGoalCrossing(const FVec2& From, const FVec2& To) const
	{
		if (From.X < Gx && To.X >= Gx)
		{
			const double T = (Gx - From.X) / (To.X - From.X);
			if (std::fabs(From.Y + (To.Y - From.Y) * T) < Ghw) { return 0; }
		}
		if (From.X > -Gx && To.X <= -Gx)
		{
			const double T = (-Gx - From.X) / (To.X - From.X);
			if (std::fabs(From.Y + (To.Y - From.Y) * T) < Ghw) { return 1; }
		}
		return -1;
	}

	bool FRefSim::PuckSubstep(double H, int& GoalTeam)
	{
		const double R = Cfg.PuckRadiusM;
		PuckV = PuckV * Max0(1.0 - Cfg.PuckDrag * H);
		const double Sp = PuckV.Length();
		if (Sp > Cfg.PuckMaxSpeed) { PuckV = PuckV * (Cfg.PuckMaxSpeed / Sp); }
		const FVec2 Prev = PuckP;
		PuckP += PuckV * H;
		const int G = CheckGoalCrossing(Prev, PuckP);
		if (G >= 0)
		{
			GoalTeam = G;
			return true;
		}
		bool bBoard = false;
		double D = 0.0;
		FVec2 N;
		BoardNormal(PuckP, D, N);
		if (D + R > 0.0)
		{
			PuckP -= N * (D + R);
			const double Vn = PuckV.Dot(N);
			if (Vn > 0.0)
			{
				const FVec2 Vt = PuckV - N * Vn;
				PuckV = N * (-Cfg.BoardRestitution * Vn) + Vt * 0.9;
			}
			bBoard = true;
		}
		// posts and net walls, e = 0.3
		for (int Side = -1; Side <= 1; Side += 2)
		{
			const double Gl = Side * Gx;
			const double Back = Side * (Gx + NetDepth);
			for (int Ys = -1; Ys <= 1; Ys += 2)
			{
				PushFromPoint(PuckP, PuckV, FVec2(Gl, Ys * Ghw), R + 0.05, 0.3, FVec2(-Side, 0));
				const FVec2 A(Gl, Ys * Ghw), B(Back, Ys * Ghw);
				PushFromPoint(PuckP, PuckV, ClosestOnSegment(PuckP, A, B), R + 0.03, 0.3, FVec2(0, Ys));
			}
			const FVec2 A(Back, -Ghw), B(Back, Ghw);
			PushFromPoint(PuckP, PuckV, ClosestOnSegment(PuckP, A, B), R + 0.03, 0.3, FVec2(Side, 0));
		}
		return bBoard;
	}

	FJamAIStepEvents FRefSim::Step(const FJamAIInput* In)
	{
		FJamAIStepEvents Ev;
		++Frame;
		if (bOver)
		{
			return Ev;
		}
		const bool bFrozen = PauseLeft > 0;
		const int N = Cfg.NumSkaters;
		const int PlayerTeam = Cfg.PlayerIndex() >= 0 ? Cfg.Skaters[Cfg.PlayerIndex()].Team : 0;
		(void)PlayerTeam;
		// skaters
		for (int i = 0; i < N; ++i)
		{
			FSk& S = Sk[i];
			FVec2 Move = bFrozen ? FVec2() : In[i].Move;
			const bool bBrake = bFrozen || In[i].bBrake;
			double M = Move.Length();
			if (M > 1.0) { Move = Move * (1.0 / M); M = 1.0; }
			if (M > 0.05)
			{
				S.Yaw = RotateToward(S.Yaw, std::atan2(Move.Y, Move.X), Cfg.TurnRate * DT);
			}
			const FVec2 F = Fwd(i);
			double Along = S.V.Dot(F);
			FVec2 Side = S.V - F * Along;
			const double Top = Cfg.Speed * M;
			if (M > 0.05 && !bBrake && Along < Top)
			{
				Along = Along + Cfg.Accel * M * DT;
				if (Along > Top) { Along = Top; }
			}
			Along = MoveToward(Along, 0.0, (Cfg.IceFriction * 9.8 + (bBrake ? Cfg.BrakeDecel : 0.0)) * DT);
			Side = Side * Max0(1.0 - (Cfg.LateralGrip + (bBrake ? Cfg.BrakeDecel * 0.5 : 0.0)) * DT);
			S.V = F * Along + Side;
			S.P += S.V * DT;
			double D = 0.0;
			FVec2 Nb;
			BoardNormal(S.P, D, Nb);
			if (D + SkaterRadius > 0.0)
			{
				S.P -= Nb * (D + SkaterRadius);
				const double Vn = S.V.Dot(Nb);
				if (Vn > 0.0) { S.V -= Nb * ((1.0 + 0.3) * Vn); }
			}
			PushSkaterFromNets(S);
		}
		// skater contacts (fixed order)
		for (int i = 0; i < N; ++i)
		{
			for (int j = i + 1; j < N; ++j)
			{
				FVec2 D = Sk[j].P - Sk[i].P;
				const double L = D.Length();
				if (L < 2.0 * SkaterRadius)
				{
					const FVec2 Nn = L > 1e-9 ? D * (1.0 / L) : FVec2(1.0, 0.0);
					const double Over = 2.0 * SkaterRadius - L;
					Sk[i].P -= Nn * (Over * 0.5);
					Sk[j].P += Nn * (Over * 0.5);
					const double Rel = (Sk[j].V - Sk[i].V).Dot(Nn);
					if (Rel < 0.0)
					{
						const double J = -(1.0 + 0.2) * Rel * 0.5;
						Sk[i].V -= Nn * J;
						Sk[j].V += Nn * J;
					}
				}
			}
		}
		// shots: first in index order wins the frame
		if (!bFrozen)
		{
			for (int i = 0; i < N; ++i)
			{
				if (In[i].bShoot && CanShoot(i))
				{
					FVec2 Aim = Fwd(i);
					if (Cfg.AimConeDeg > 0.0)
					{
						const FVec2 Goal(Cfg.Skaters[i].Team == 0 ? Gx : -Gx, 0.0);
						const FVec2 Gd = (Goal - PuckP).Normalized();
						if (Aim.Dot(Gd) >= std::cos(Cfg.AimConeDeg * kPi / 180.0)) { Aim = Gd; }
					}
					PuckV = Aim * Cfg.ShotSpeed;
					Owner = -1;
					LastToucher = i;
					Sk[i].NoTakeUntil = Frame + ShooterNoTakeFrames;
					Sk[i].CooldownUntil = Frame + Cfg.ShotCooldownFrames;
					Ev.Shot = i;
					break;
				}
			}
		}
		// puck
		int GoalTeam = -1;
		if (bFrozen)
		{
			PuckV = FVec2();
		}
		else if (Owner >= 0)
		{
			const FVec2 Prev = PuckP;
			PuckP = Stick(Owner);
			PuckV = Sk[Owner].V;
			double D = 0.0;
			FVec2 Nb;
			BoardNormal(PuckP, D, Nb);
			if (D + Cfg.PuckRadiusM > 0.0) { PuckP -= Nb * (D + Cfg.PuckRadiusM); }
			GoalTeam = CheckGoalCrossing(Prev, PuckP);
		}
		else
		{
			for (int s = 0; s < 4 && GoalTeam < 0; ++s)
			{
				PuckSubstep(DT / 4.0, GoalTeam);
			}
		}
		// possession
		if (!bFrozen && GoalTeam < 0)
		{
			if (Owner < 0)
			{
				int Best = -1;
				double BestD = TakeRadius;
				for (int i = 0; i < N; ++i)
				{
					if (Frame < Sk[i].NoTakeUntil) { continue; }
					const double D = Stick(i).DistTo(PuckP);
					if (D < BestD && (PuckV - Sk[i].V).Length() < 12.0)
					{
						BestD = D;
						Best = i;
					}
				}
				if (Best >= 0)
				{
					Owner = Best;
					OwnerSince = Frame;
					Ev.TouchMask |= 1u << Best;
					LastToucher = Best;
				}
			}
			else if (Frame - OwnerSince >= StealProtectFrames)
			{
				int Best = -1;
				double BestD = StealRadius;
				for (int i = 0; i < N; ++i)
				{
					if (Cfg.Skaters[i].Team == Cfg.Skaters[Owner].Team || Frame < Sk[i].NoTakeUntil) { continue; }
					const double D = Stick(i).DistTo(PuckP);
					if (D < BestD) { BestD = D; Best = i; }
				}
				if (Best >= 0)
				{
					Owner = Best;
					OwnerSince = Frame;
					Ev.TouchMask |= 1u << Best;
					LastToucher = Best;
				}
			}
		}
		if (GoalTeam >= 0)
		{
			++Scores[GoalTeam];
			Ev.GoalTeam = GoalTeam;
			Owner = -1;
			PuckV = FVec2();
			PauseLeft = Cfg.GoalPauseFrames;
			if (!Cfg.bTimer && Scores[GoalTeam] >= Cfg.ScoreToWin)
			{
				bOver = true;
				WinnerTeam = GoalTeam;
			}
		}
		else if (bFrozen)
		{
			--PauseLeft;
			if (PauseLeft == 0)
			{
				Faceoff();
				Ev.bFaceoff = true;
			}
		}
		if (Cfg.bTimer && !bOver && Frame >= Cfg.TimerFrames)
		{
			bOver = true;
			WinnerTeam = Scores[0] > Scores[1] ? 0 : (Scores[1] > Scores[0] ? 1 : -1);
		}
		return Ev;
	}

	void FRefSim::View(FJamAIWorld& W) const
	{
		W.Frame = Frame;
		W.bFrozen = bOver || PauseLeft > 0;
		W.PuckPos = PuckP;
		W.PuckVel = PuckV;
		W.PuckLastTouch = LastToucher;
		W.NumSkaters = Cfg.NumSkaters;
		W.PlayerIndex = Cfg.PlayerIndex();
		W.HalfLength = Hx;
		W.HalfWidth = Hz;
		W.CornerRadius = Rc;
		W.GoalX = Gx;
		W.GoalHalfWidth = Ghw;
		W.ShotReach = Cfg.ShotReachM;
		for (int i = 0; i < Cfg.NumSkaters; ++i)
		{
			FJamAISkater& S = W.Skaters[i];
			S.Pos = Sk[i].P;
			S.Vel = Sk[i].V;
			S.Facing = Fwd(i);
			S.Spawn = Cfg.Skaters[i].Spawn;
			S.Team = Cfg.Skaters[i].Team;
			S.Role = Cfg.Skaters[i].Role;
			S.bCanShoot = CanShoot(i);
			S.bHasPuck = Owner == i;
			S.bDown = false;
		}
	}

	uint64_t FRefSim::StateHash() const
	{
		uint64_t H = 0xCBF29CE484222325ull;
		Fnv(H, Frame);
		Fnv(H, Scores[0]);
		Fnv(H, Scores[1]);
		Fnv(H, Owner);
		Fnv(H, PauseLeft);
		for (int i = 0; i < Cfg.NumSkaters; ++i)
		{
			Fnv(H, Q(Sk[i].P.X, 1000.0)); Fnv(H, Q(Sk[i].P.Y, 1000.0));
			Fnv(H, Q(Sk[i].V.X, 1000.0)); Fnv(H, Q(Sk[i].V.Y, 1000.0));
			Fnv(H, Q(Sk[i].Yaw, 10000.0));
		}
		Fnv(H, Q(PuckP.X, 1000.0)); Fnv(H, Q(PuckP.Y, 1000.0));
		Fnv(H, Q(PuckV.X, 1000.0)); Fnv(H, Q(PuckV.Y, 1000.0));
		return H;
	}
}
