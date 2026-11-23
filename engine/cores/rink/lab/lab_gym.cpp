// Third Life rink core, LAB (lane K4): the tempo probes. Measurement only; nothing here is a rule.
//
// Every probe is a scripted scene on thirdjam's own UJamSim through FJamSimAdapter (the input path of a match), built from the
// named cartridge with its roster cut to 2 v 2 (index 0 the human, 1 his mate, 2 and 3 the opponents; every other number as
// shipped). No brain runs: every skater gets the scene's input (bots |Move| 1 unless a probe says otherwise). Skaters the
// probe does not use stand parked near the corners. One rinklab.gym/1 JSON line per probe; frames at 60 Hz.
#include "lab_gym.h"

#include "CoreMinimal.h"
#include "JamCartridge.h"
#include "JamSimAdapter.h"
#include "JamSim.h"

#include <cmath>
#include <cstdlib>
#include <cstdio>
#include <memory>
#include <string>
#include <vector>

namespace Lab
{
	namespace
	{
		using namespace JamAI;
		constexpr double Pi = 3.14159265358979323846;

		struct FOut
		{
			std::string S;
			explicit FOut(const char* Probe) { S = std::string("{\"tool\":\"rinklab.gym/1\",\"probe\":\"") + Probe + "\""; }
			FOut& N(const char* K, double V) { char B[96]; std::snprintf(B, sizeof(B), ",\"%s\":%.4g", K, V); S += B; return *this; }
			FOut& I(const char* K, long long V) { char B[96]; std::snprintf(B, sizeof(B), ",\"%s\":%lld", K, V); S += B; return *this; }
			FOut& T(const char* K, const std::string& V) { S += std::string(",\"") + K + "\":\"" + V + "\""; return *this; }
			FOut& Raw(const char* K, const std::string& V) { S += std::string(",\"") + K + "\":" + V; return *this; }
			void Print() { std::printf("%s}\n", S.c_str()); std::fflush(stdout); }
		};

		struct FGym
		{
			UJamCartridge* Cart = nullptr;
			FJamMatchConfig Cfg;
			std::unique_ptr<FJamSimAdapter> A;
			UJamSim* S = nullptr;
			FJamAIInput In[kMaxSkaters];
			int N = 0;
			bool bTrace = false;

			void Reset()
			{
				A->Reset(Cfg, 1);
				S = A->GetSim();
				S->SkipFaceoff();
				N = S->GetSkaters().Num();
				for (int i = 0; i < kMaxSkaters; ++i) In[i] = FJamAIInput();
				const double Px[4] = {-40.0, 40.0, 40.0, -40.0}, Py[4] = {19.0, 19.0, -19.0, -19.0};
				for (int i = 0; i < N; ++i) S->SetSkater(i, FVector2D(Px[i % 4], Py[i % 4]), FVector2D(0.0, 0.0), 0.0);
				S->SetPuck(FVector2D(0.0, 21.5), FVector2D(0.0, 0.0));
			}
			const FJamSkaterState& K(int i) const { return S->GetSkaters()[i]; }
			void Place(int i, double X, double Y, double Vx, double Vy, double Yaw) { S->SetSkater(i, FVector2D(X, Y), FVector2D(Vx, Vy), Yaw); }
			double Dist(int i, int j) const { return FVector2D::Distance(K(i).Pos, K(j).Pos); }
			double Speed(int i) const { return K(i).Vel.Size(); }
			void Step()
			{
				A->Step(In);
				if (bTrace)
				{
					std::printf("TRACE f=%lld ph=%d car=%d lt=%d puck=(%.2f,%.2f|%.2f) sc=%d:%d", (long long)S->GetFrame(), (int)S->GetPhase(), S->CarrierIndex(), S->GetPuck().LastTouch,
						S->GetPuck().Pos.X, S->GetPuck().Pos.Y, S->GetPuck().Vel.Size(), S->GetScore(0), S->GetScore(1));
					for (int i = 0; i < N; ++i) std::printf(" %d:(%.2f,%.2f v%.2f y%.0f b%d r%d s%d%s)", i, K(i).Pos.X, K(i).Pos.Y, K(i).Vel.Size(), K(i).Yaw * 57.2958, K(i).BurstLeft, K(i).RestFrames, K(i).Stamina, K(i).bSprinting ? "S" : "");
					std::printf("\n");
				}
				for (int i = 0; i < kMaxSkaters; ++i)
				{
					In[i].bShoot = In[i].bPass = In[i].bCheck = In[i].bPoke = In[i].bLift = In[i].bDeke = In[i].bSpin = In[i].bAbility = false;
				}
			}
			// The puck on skater i's blade, moving with it; steps (with the current inputs) until the sim calls i the carrier. Frames used, or -1.
			int GivePuck(int i)
			{
				const FJamSkaterState& Sk = K(i);
				const FVector2D Fwd(std::cos(Sk.Yaw), std::sin(Sk.Yaw));
				S->SetPuck(Sk.Pos + Fwd * 0.85, Sk.Vel);
				for (int f = 1; f <= 12; ++f)
				{
					Step();
					if (S->CarrierIndex() == i) return f;
				}
				return -1;
			}
		};

		FJamAIInput MoveOnly(double X, double Y) { FJamAIInput I; I.Move = FVec2(X, Y); return I; }

		// 1. From a standing start, straight along the rink: speed by time and distance by time.
		void ProbeSkate(FGym& G, const char* Name, int Who, double MoveMag, bool bSprint, bool bCarry)
		{
			G.Reset();
			G.Place(Who, -38.0, 0.0, 0.0, 0.0, 0.0);   // in front of the goal line (GoalLineX), on the centre line
			int Got = 0;
			if (bCarry) Got = G.GivePuck(Who);
			G.In[Who] = MoveOnly(MoveMag, 0.0);
			G.In[Who].bSprint = bSprint;
			const double X0 = G.K(Who).Pos.X;
			const double Vs[] = {4, 6, 8, 10, 11, 12, 13, 14};
			const double Ds[] = {1, 2, 3, 5, 10, 20, 30, 60};
			long long FV[8], FD[8];
			for (int k = 0; k < 8; ++k) FV[k] = FD[k] = -1;
			double Top = 0.0, V60 = 0, V120 = 0;
			long long Carried = 0, Frames = 0, SprintFrames = 0;
			std::vector<double> Trace;
			for (int f = 1; f <= 600; ++f)
			{
				G.Step();
				++Frames;
				const double V = G.Speed(Who), D = G.K(Who).Pos.X - X0;
				Trace.push_back(V);
				if (V > Top) Top = V;
				if (f == 60) V60 = V;
				if (f == 120) V120 = V;
				if (G.S->CarrierIndex() == Who) ++Carried;
				if (G.K(Who).bSprinting) ++SprintFrames;
				for (int k = 0; k < 8; ++k) { if (FV[k] < 0 && V >= Vs[k]) FV[k] = f; if (FD[k] < 0 && D >= Ds[k]) FD[k] = f; }
				if (G.K(Who).Pos.X > 38.0) break;
			}
			long long F95 = -1;
			for (size_t k = 0; k < Trace.size(); ++k) if (Trace[k] >= 0.95 * Top) { F95 = (long long)k + 1; break; }
			FOut O("skate");
			O.T("variant", Name).I("who", Who).N("move", MoveMag).I("sprint", bSprint).I("carry", bCarry).I("pickup_frames", Got)
				.N("top_mps", Top).I("f_to_95pct_top", F95).N("v_at_1s", V60).N("v_at_2s", V120).I("frames", Frames).I("carried_frames", Carried).I("sprint_frames", SprintFrames);
			std::string Fv = "{", Fd = "{";
			for (int k = 0; k < 8; ++k)
			{
				char B[64];
				std::snprintf(B, sizeof(B), "%s\"%g\":%lld", k ? "," : "", Vs[k], FV[k]); Fv += B;
				std::snprintf(B, sizeof(B), "%s\"%g\":%lld", k ? "," : "", Ds[k], FD[k]); Fd += B;
			}
			O.Raw("f_to_mps", Fv + "}").Raw("f_to_m", Fd + "}").Print();
		}

		// 2. The sprint bar: sprint on a 15 m circle until it is refused, then skate on until it is full.
		void ProbeStamina(FGym& G)
		{
			G.Reset();
			const double R = 15.0;
			G.Place(0, 0.0, -R, 10.0, 0.0, 0.0);
			const int Full = G.S->StaminaFull();
			auto Steer = [&]() {
				const FVector2D P = G.K(0).Pos;
				const double r = P.Size();
				const FVector2D U = r > 1e-6 ? P / r : FVector2D(0.0, -1.0);
				const FVector2D Tn(-U.Y, U.X);
				FVector2D M = Tn + U * ((R - r) * 0.3);
				M = M.GetSafeNormal();
				G.In[0].Move = FVec2(M.X, M.Y);
			};
			long long SprintFrames = 0, Refill = -1, f = 0;
			double SumS = 0, SumC = 0; long long NS = 0, NC = 0;
			for (int k = 0; k < 120; ++k) { Steer(); G.Step(); }   // up to cruise on the circle
			G.In[0].bSprint = true;
			while (f < 2000)
			{
				Steer(); G.Step(); ++f;
				if (!G.K(0).bSprinting) break;
				++SprintFrames; SumS += G.Speed(0); ++NS;
			}
			const int AtEmpty = G.K(0).Stamina;
			G.In[0].bSprint = false;
			for (long long k = 1; k <= 2000; ++k)
			{
				Steer(); G.Step();
				SumC += G.Speed(0); ++NC;
				if (G.K(0).Stamina >= Full) { Refill = k; break; }
			}
			// the spin's price: a spin from a full bar
			G.In[0].bSpin = true; Steer(); G.Step();
			const double SpinShare = double(Full - G.K(0).Stamina) / Full;
			FOut("stamina").I("bar_ticks", Full).I("sprint_frames_full_bar", SprintFrames).I("stamina_at_refusal", AtEmpty).I("refill_frames", Refill)
				.N("circle_mps_sprint", NS ? SumS / NS : 0).N("circle_mps_cruise", NC ? SumC / NC : 0).N("spin_bar_share", SpinShare).Print();
		}

		// 3. Stops and turns from the free cruise top speed (no puck).
		void ProbeStop(FGym& G, const char* Name, bool bCarry)
		{
			G.Reset();
			G.Place(0, -36.0, 0.0, 6.0, 0.0, 0.0);
			G.In[0] = MoveOnly(1.0, 0.0);
			if (bCarry) G.GivePuck(0);
			for (int k = 0; k < 150 && G.K(0).Pos.X < 0.0; ++k) G.Step();
			const double V0 = G.Speed(0);
			const FVector2D P0 = G.K(0).Pos;
			const std::string N(Name);
			if (N == "reverse" || N == "carry_reverse") G.In[0] = MoveOnly(-1.0, 0.0);
			else if (N == "brake") { G.In[0] = MoveOnly(0.0, 0.0); G.In[0].bBrake = true; }
			else if (N == "glide") G.In[0] = MoveOnly(0.0, 0.0);
			else if (N == "turn90") G.In[0] = MoveOnly(0.0, 1.0);
			long long FStop = -1, FTurn = -1, FBack = -1, Kept = 0;
			double DStop = 0, V1s = 0, VTurn = 0;
			for (int f = 1; f <= 600; ++f)
			{
				G.Step();
				const double V = G.Speed(0);
				if (bCarry && G.S->CarrierIndex() == 0) ++Kept;
				if (f == 60) V1s = V;
				if (FStop < 0 && V < 0.5) { FStop = f; DStop = FVector2D::Distance(P0, G.K(0).Pos); }
				const double Ang = std::atan2(G.K(0).Vel.Y, G.K(0).Vel.X) * 180.0 / Pi;
				if (FTurn < 0 && Ang >= 80.0) { FTurn = f; VTurn = V; }
				if (FBack < 0 && G.K(0).Vel.X <= -5.0) FBack = f;
				if ((N == "glide" && f >= 60) || (FStop >= 0 && N != "reverse" && N != "carry_reverse") || (FBack >= 0) || (N == "turn90" && FTurn >= 0)) break;
			}
			FOut O("stop");
			O.T("variant", Name).N("v0_mps", V0).I("f_to_stop", FStop).N("stop_m", DStop).N("v_after_1s", V1s).I("f_turn90", FTurn).N("v_turn90", VTurn).I("f_about_turn_5mps", FBack);
			if (bCarry) O.I("carried_frames", Kept);
			O.Print();
		}

		// 4. A chaser behind a carrier, both at their top speed from a flying start: frames to close to stick range and to the body.
		void ProbeChase(FGym& G, double Gap, bool bChaserSprint, bool bCarrierSprint)
		{
			G.Reset();
			const double Vc = 11.0 * 0.92, Vch = 11.0 * 1.15;   // the carried and the free cruise tops (hockey.regular skater.speed x carry / free mult)
			// The chaser's mate (3) stands at (30, 3): a defender ahead, so the carrier never gets the breakaway burst (JamSim.cpp:2946-2992) on the way.
			G.Place(3, 30.0, 3.0, 0.0, 0.0, Pi);
			const double X0 = -38.0 + Gap;   // the chaser starts at x = -38, in front of its goal line
			G.Place(0, X0, 0.0, Vc, 0.0, 0.0);
			G.In[0] = MoveOnly(1.0, 0.0);
			G.Place(2, X0 - Gap, 0.0, Vch, 0.0, 0.0);
			G.In[2] = MoveOnly(1.0, 0.0);
			const int Got = G.GivePuck(0);
			G.Place(2, G.K(0).Pos.X - Gap, 0.0, Vch, 0.0, 0.0);
			G.In[0].bSprint = bCarrierSprint;
			G.In[2].bSprint = bChaserSprint;
			const double D0 = G.Dist(0, 2);
			long long F2 = -1, F08 = -1, Kept = 0;
			double Vca = 0, Vcha = 0;
			for (int f = 1; f <= 900; ++f)
			{
				const FVector2D To = (G.K(0).Pos - G.K(2).Pos).GetSafeNormal();
				G.In[2].Move = FVec2(To.X, To.Y);
				G.Step();
				if (G.S->CarrierIndex() == 0) ++Kept;
				const double D = G.Dist(0, 2);
				if (F2 < 0 && D <= 2.0) { F2 = f; Vca = G.Speed(0); Vcha = G.Speed(2); }
				if (F08 < 0 && D <= 0.85) F08 = f;
				if (F08 >= 0 || G.K(0).Pos.X > 26.0) break;
			}
			FOut("chase").N("run_m", G.K(0).Pos.X - X0).N("gap_m", Gap).N("gap_measured_m", D0).I("chaser_sprint", bChaserSprint).I("carrier_sprint", bCarrierSprint).I("pickup_frames", Got)
				.I("f_to_2m", F2).I("f_to_body", F08).N("carrier_mps_at_2m", Vca).N("chaser_mps_at_2m", Vcha).I("carried_frames", Kept).Print();
		}

		// 5. A pass from a standing passer to a standing mate d metres ahead: the edge pass (a tap) and the held pass (30 frames).
		void ProbePass(FGym& G, double D, int HoldFrames)
		{
			G.Reset();
			G.Place(0, -20.0, 0.0, 0.0, 0.0, 0.0);
			G.Place(1, -20.0 + D, 0.0, 0.0, 0.0, Pi);
			const int Got = G.GivePuck(0);
			for (int k = 0; k < 30; ++k) G.Step();   // settle, both standing (the take grace and the reception clocks run out)
			G.In[0].Stick = FVec2(1.0, 0.0);
			long long FRelease = -1, FCatch = -1, F = 0;
			double VRel = 0, VArr = 0;
			const int Passes0 = G.K(0).Passes, Rec0 = G.K(1).PassesReceived;
			if (HoldFrames <= 0) G.In[0].bPass = true; else G.In[0].bPassHeld = true;
			for (F = 1; F <= 300; ++F)
			{
				if (HoldFrames > 0 && F > HoldFrames) G.In[0].bPassHeld = false;
				const double VBefore = G.S->GetPuck().Vel.Size();
				G.Step();
				if (FRelease < 0 && G.K(0).Passes > Passes0) { FRelease = F; VRel = G.S->GetPuck().Vel.Size(); }
				if (FRelease >= 0 && FCatch < 0 && (G.K(1).PassesReceived > Rec0 || G.S->GetPuck().LastTouch == 1)) { FCatch = F; VArr = VBefore; break; }
			}
			FOut("pass").N("dist_m", D).I("hold_frames", HoldFrames).I("pickup_frames", Got).I("f_release", FRelease).I("f_catch", FCatch)
				.I("flight_frames", (FRelease >= 0 && FCatch >= 0) ? FCatch - FRelease : -1).N("release_mps", VRel).N("arrive_mps", VArr).N("puck_z_max_m", 0).Print();
		}

		// 6. A shot from d metres in front of the empty net (no goalie: nobody is driven there): the tap and the full charge.
		void ProbeShot(FGym& G, double D, int HoldFrames)
		{
			G.Reset();
			const double Gx = G.S->AttackGoalX(0);
			const double Sign = Gx > 0 ? 1.0 : -1.0;
			G.Place(0, Gx - Sign * D, 0.0, 0.0, 0.0, Sign > 0 ? 0.0 : Pi);
			const int Got = G.GivePuck(0);
			for (int k = 0; k < 30; ++k) G.Step();
			const int Shots0 = G.K(0).Shots, Score0 = G.S->GetScore(0);
			long long FRel = -1, FGoal = -1, FLine = -1;
			double VRel = 0, ZMax = 0;
			if (HoldFrames <= 0) G.In[0].bShoot = true; else G.In[0].bShootHeld = true;
			for (int F = 1; F <= 300; ++F)
			{
				if (HoldFrames > 0 && F > HoldFrames) G.In[0].bShootHeld = false;
				G.Step();
				if (FRel < 0 && G.K(0).Shots > Shots0) { FRel = F; VRel = G.S->GetPuck().Vel.Size(); }
				if (FRel >= 0)
				{
					if (G.S->GetPuck().Z > ZMax) ZMax = G.S->GetPuck().Z;
					if (FLine < 0 && G.S->GetPuck().Pos.X * Sign >= G.S->GoalLineX()) FLine = F;
					if (G.S->GetScore(0) > Score0) { FGoal = F; break; }
				}
			}
			FOut("shot").N("dist_m", D).I("hold_frames", HoldFrames).I("pickup_frames", Got).I("f_release", FRel).N("release_mps", VRel).N("puck_z_max_m", ZMax)
				.I("flight_frames_to_line", (FRel >= 0 && FLine >= 0) ? FLine - FRel : -1).I("flight_frames_to_goal", (FRel >= 0 && FGoal >= 0) ? FGoal - FRel : -1).Print();
		}

		// 7. When to commit: the human (index 0) skates at a bot carrier (index 2) and presses the verb when the centres are d metres apart.
		// Geometry head = the carrier skates at him; chase = from behind, same direction. Outcome per d: what the press did inside 60 frames.
		void ProbeCommit(FGym& G, const char* Verb, const char* Geo)
		{
			const std::string V(Verb), Ge(Geo);
			const double Vc = 11.0 * 0.92, Va = 11.0 * 1.15;
			std::string Rows = "[";
			double DMinOk = -1, DMaxOk = -1;
			int Ok = 0, Trials = 0;
			double Closing = 0;
			const bool bChase = Ge == "chase";
			const int Steps = bChase ? 18 : 20;
			for (int k = 0; k <= Steps; ++k)
			{
				const double D = bChase ? 0.75 + 0.25 * k : 0.5 + 0.5 * k;
				G.Reset();
				if (Ge == "head") { G.Place(2, 12.0, 0.0, -Vc, 0.0, Pi); G.Place(0, -14.0, 0.0, Va, 0.0, 0.0); }
				else { G.Place(2, -30.0, 0.0, Vc, 0.0, 0.0); G.Place(0, -30.0 - 8.0, 0.0, Va, 0.0, 0.0); }
				G.In[2] = MoveOnly(Ge == "head" ? -1.0 : 1.0, 0.0);
				G.In[0] = MoveOnly(1.0, 0.0);
				if (G.GivePuck(2) < 0) { Rows += std::string(k ? "," : "") + "\"nopuck\""; continue; }
				++Trials;
				long long FPress = -1, FBody = -1;
				int Outcome = 0, Taken = 0, Strip = 0, SelfDown = 0, SelfStumble = 0, PokeRes = 0;
				double CloseAtPress = 0;
				for (int f = 1; f <= 400; ++f)
				{
					const FVector2D To = G.K(2).Pos - G.K(0).Pos;
					const FVector2D U = To.GetSafeNormal();
					G.In[0].Move = FVec2(U.X, U.Y);
					const FVector2D ToP = (G.S->GetPuck().Pos - G.K(0).Pos).GetSafeNormal();
					G.In[0].Stick = FVec2(ToP.X, ToP.Y);
					if (FPress < 0 && To.Size() <= D)
					{
						FPress = f;
						CloseAtPress = -FVector2D::DotProduct(G.K(2).Vel - G.K(0).Vel, U);
						if (V == "check") G.In[0].bCheck = true;
						else if (V == "lift") G.In[0].bLift = true;
						else if (V == "poke") G.In[0].bPoke = true;
					}
					G.Step();
					if (FBody < 0 && G.Dist(0, 2) <= 0.85) FBody = f;
					if (FPress >= 0)
					{
						const FJamSkaterState& C = G.K(2);
						if (C.ContactBy == 0 && C.ContactOutcome > Outcome) Outcome = C.ContactOutcome;
						if (C.StickHitResult == 2) Strip = 1;
						if (C.StickHitResult == 1) Taken = 1;
						if (G.K(0).PokeResult != 0 && PokeRes == 0) PokeRes = G.K(0).PokeResult;
						if (G.K(0).IsDown()) SelfDown = 1;
						if (G.K(0).IsStumbling()) SelfStumble = 1;
						if (G.S->CarrierIndex() == 0) Taken = 1;
						if (f - FPress >= 60) break;
					}
					if (G.K(0).Pos.X > 40.0 || G.K(2).Pos.X > 40.0 || G.K(2).Pos.X < -42.0) break;
				}
				if (FPress < 0) { Rows += std::string(k ? "," : "") + "\"nopress\""; continue; }
				Closing = CloseAtPress;
				// landed: the body check stumbles or fells him; the lift strips him or its cross-check stumbles or fells him; the poke is clean. "taken" = the
				// attacker ended with the puck by any means (the body takes a puck skated into it: compare the verb "none").
				const bool bOk = (V == "check") ? Outcome >= 2 : (V == "lift") ? (Strip || Outcome >= 2) : (V == "poke") ? PokeRes == 1 : Taken;
				if (bOk) { ++Ok; if (DMinOk < 0) DMinOk = D; DMaxOk = D; }
				char B[256];
				std::snprintf(B, sizeof(B), "%s{\"d\":%.1f,\"closing\":%.2f,\"f_press_to_body\":%lld,\"outcome\":%d,\"taken\":%d,\"strip\":%d,\"poke\":%d,\"self_down\":%d,\"self_stumble\":%d,\"ok\":%d}",
					k ? "," : "", D, CloseAtPress, FBody >= 0 ? FBody - FPress : -1LL, Outcome, Taken, Strip, PokeRes, SelfDown, SelfStumble, bOk ? 1 : 0);
				Rows += B;
			}
			Rows += "]";
			FOut("commit").T("verb", Verb).T("geometry", Geo).N("closing_mps", Closing).I("trials", Trials).I("ok", Ok).N("d_ok_min", DMinOk).N("d_ok_max", DMaxOk).Raw("rows", Rows).Print();
		}
	}

	int RunGym(const char* Cartridge)
	{
		TArray<FString> Errors;
		UJamCartridge* Cart = UJamCartridge::LoadFromFile(UJamCartridge::ResolveCartridgePath(FString(Cartridge)), Errors);
		if (!Cart) { std::fprintf(stderr, "FAIL rinklab gym: cartridge %s does not load\n", Cartridge); return 2; }
		Cart->AddToRoot();
		// 2 v 2: the first two skaters of each team (hockey.regular: player + chaser, chaser + support).
		for (FJamTeamConfig& T : Cart->Game.Teams) { while (T.Skaters.Num() > 2) T.Skaters.RemoveAt(T.Skaters.Num() - 1); }
		FGym G;
		G.Cart = Cart;
		G.Cfg = JamAI::ToMatchConfig(Cart->Game);
		G.A.reset(new FJamSimAdapter(*Cart));
		G.Reset();
		const char* TraceEnv = std::getenv("LAB_TRACE");
		const std::string TraceProbe = TraceEnv ? TraceEnv : "";
		if (G.S->GetHumanIndex() != 0) { std::fprintf(stderr, "FAIL rinklab gym: human index %d, expected 0\n", G.S->GetHumanIndex()); return 2; }

		// LAB_ONLY=<n> runs probe n alone (0-based, in the order below); LAB_TRACE=1 prints every frame of the probes that run (debugging a scene).
		const char* OnlyEnv = std::getenv("LAB_ONLY");
		const int OnlyN = OnlyEnv ? std::atoi(OnlyEnv) : -1;
		G.bTrace = !TraceProbe.empty();
		int Nth = -1;
		auto Run = [&](auto&& Fn) { ++Nth; if (OnlyN < 0 || OnlyN == Nth) Fn(); };
		Run([&] { ProbeSkate(G, "cruise", 0, 1.0, false, false); });
		Run([&] { ProbeSkate(G, "sprint", 0, 1.0, true, false); });
		Run([&] { ProbeSkate(G, "carry", 0, 1.0, false, true); });
		Run([&] { ProbeSkate(G, "carry_sprint", 0, 1.0, true, true); });
		Run([&] { ProbeSkate(G, "bot_move1", 2, 1.0, false, false); });
		Run([&] { ProbeSkate(G, "bot_move1.5", 2, 1.5, false, false); });
		Run([&] { ProbeSkate(G, "bot_move1.5_sprint", 2, 1.5, true, false); });
		Run([&] { ProbeStamina(G); });
		Run([&] { ProbeStop(G, "reverse", false); });
		Run([&] { ProbeStop(G, "brake", false); });
		Run([&] { ProbeStop(G, "glide", false); });
		Run([&] { ProbeStop(G, "turn90", false); });
		Run([&] { ProbeStop(G, "carry_reverse", true); });
		for (double Gap : {5.0, 10.0, 20.0})
		{
			Run([&] { ProbeChase(G, Gap, false, false); });
			Run([&] { ProbeChase(G, Gap, true, false); });
			Run([&] { ProbeChase(G, Gap, false, true); });
			Run([&] { ProbeChase(G, Gap, true, true); });
		}
		for (double D : {5.0, 15.0, 30.0}) { Run([&] { ProbePass(G, D, 0); }); Run([&] { ProbePass(G, D, 30); }); }
		for (double D : {10.0, 20.0}) { Run([&] { ProbeShot(G, D, 0); }); Run([&] { ProbeShot(G, D, 30); }); }
		for (const char* Verb : {"none", "check", "lift", "poke"}) for (const char* Geo : {"head", "chase"}) Run([&] { ProbeCommit(G, Verb, Geo); });
		Cart->RemoveFromRoot();
		return 0;
	}
}
