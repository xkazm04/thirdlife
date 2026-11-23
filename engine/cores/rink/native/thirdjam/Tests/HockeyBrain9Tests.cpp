// Lane A206 (track Q2, the night; docs/experiments/BRAIN-9.md): ten skaters who play hockey.
//   Bar.Brain.Interest  real matches traced frame by frame (RunPlaytestMatch's trace), what "interested" means, per bot and per match: the share of play
//                       each bot skates faster than half its top speed, closes on the puck (or the man with it), stands with no job; loose pucks (time to
//                       the first touch, how many bots go); shots a minute by side and from where; the attacking third's possession; what a bot carrier
//                       does with the puck; the human's mates while he carries. A measurement, outside the gate.
//   env JAM_BRAIN_INTEREST = "levels=rookie,pro;carts=hockey.regular;seeds=20;from=1;tune=brain9=0;player=regular" (every part optional)
//   UnrealEditor-Cmd ThirdJam.uproject -ExecCmds="Automation RunTests Bar.Brain.Interest; Quit" -nullrhi -Multiprocess -unattended -nopause
#include "CoreMinimal.h"
#include "Misc/AutomationTest.h"

#include "../AI/JamBotMatch.h"
#include "../AI/JamSimAdapter.h"
#include "../AI/DifficultyResolve.h"
#include "../AI/DifficultyProfile.h"
#include "../AI/JamAICore.h"
#include "../AI/JamPlaytester.h"
#include "JamCartridge.h"
#include "JamSim.h"
#include "JamEventBus.h"
#include "UObject/Package.h"

#if WITH_DEV_AUTOMATION_TESTS

namespace JamHockeyBrain9Interest
{
	using namespace JamAI;
	constexpr EAutomationTestFlags BarFlags = EAutomationTestFlags_ApplicationContextMask | EAutomationTestFlags::ProductFilter;
	constexpr int32 MaxSk = 16;
	constexpr int32 NKey = 2 * 4 * 8;   // side (0 the human's mates, 1 the opponents) x role x job

	// one match's (or a sum's) numbers; side 0 = the human's mates (bots), side 1 = the opponents
	struct FAcc
	{
		int64 PlayFrames = 0;
		int64 BotFrames[2] = {}, Fast[2] = {}, Close[2] = {}, Idle[2] = {}, IdleLong[2] = {}, Drift[2] = {};
		int64 IdleKey[NKey] = {};       // idle frames by side, role (LastRole) and job (LastJob)
		int64 IdleYield = 0;            // the mates' idle frames while the distance yield holds
		int32 SkaterShares = 0, SkaterOver10 = 0; double MaxIdleShare = 0; double SumIdleShare[2] = {}; int32 NShare[2] = {};
		// loose pucks
		int32 Loose = 0, LooseBotNear = 0, LooseBotIn90 = 0, LooseHumanFirst = 0; double LooseFirstSum = 0; int32 LooseFirstN = 0; double GoersSum = 0;
		// shots: by side x distance band (<10, 10-20, 20-30, >30)
		int32 Shots[2][4] = {}; int32 HumanShots = 0;
		int64 AttThird[2] = {};          // frames the side carries the puck in its attacking third (side 0 = the human's team, human included)
		// bot carries
		int32 Carries[2] = {}, CarryShot[2] = {}, CarryPass[2] = {}, CarryLost[2] = {}, CarryOther[2] = {}, CarryToNet[2] = {}, CarryBack[2] = {}, CarrySlow[2] = {};
		int64 CarryFr[2] = {};
		// the human carries in the attacking half
		int64 HumanAttCarry = 0, HumanAttOpen = 0, MateAway = 0, MateFwdFrames = 0;
		// possession, passes, the pressure on the human carrier, the net front in attack
		int64 Poss[2] = {}, HumanCarry = 0, HumanPressed = 0, AttFrames[2] = {}, NetFront[2] = {};
		int32 Passes[2] = {}, PassDone[2] = {};
		int32 Aimed[2][4] = {};
		int32 ShotsAll[2] = {}, ShotBack[2] = {};
		// lane A206 wave 3 (EYE 8, EYE 2, EYE 3): pass quality by passing side; defence by defending side (0 the human's side, 1 the opponents)
		int32 QuickRepass[2] = {}, BackPass[2] = {}, LongDone[2] = {};
		int64 DefFrames[2] = {}, DefOnCarrier[2] = {}, DefCrease[2] = {}, DefReceiver[2] = {}, DefClump[2] = {};
		int32 FarShotsAgainst[2] = {}, FarShotsCrease[2] = {};
		int32 EarlyGoalsAgainst[2] = {}, GoalsAgainstAll[2] = {};   // wave 4: goals against a side inside 10 s (600 frames) of play resuming after a stoppage   // bot shots; of them, the shooter is the carrier again within 30 frames (his own stick took his shot back)   // shots whose puck leaves within 12 deg of the net (the rest: chips, dumps, clears)
		void Add(const FAcc& O)
		{
			for (int32 s = 0; s < 2; ++s) for (int32 b = 0; b < 4; ++b) Aimed[s][b] += O.Aimed[s][b];
			for (int32 s = 0; s < 2; ++s) { ShotsAll[s] += O.ShotsAll[s]; ShotBack[s] += O.ShotBack[s]; }
			for (int32 s = 0; s < 2; ++s)
			{
				QuickRepass[s] += O.QuickRepass[s]; BackPass[s] += O.BackPass[s]; LongDone[s] += O.LongDone[s];
				DefFrames[s] += O.DefFrames[s]; DefOnCarrier[s] += O.DefOnCarrier[s]; DefCrease[s] += O.DefCrease[s]; DefReceiver[s] += O.DefReceiver[s]; DefClump[s] += O.DefClump[s];
				FarShotsAgainst[s] += O.FarShotsAgainst[s]; FarShotsCrease[s] += O.FarShotsCrease[s];
				EarlyGoalsAgainst[s] += O.EarlyGoalsAgainst[s]; GoalsAgainstAll[s] += O.GoalsAgainstAll[s];
			}
			HumanCarry += O.HumanCarry; HumanPressed += O.HumanPressed;
			for (int32 s = 0; s < 2; ++s) { Poss[s] += O.Poss[s]; AttFrames[s] += O.AttFrames[s]; NetFront[s] += O.NetFront[s]; Passes[s] += O.Passes[s]; PassDone[s] += O.PassDone[s]; }
			PlayFrames += O.PlayFrames;
			for (int32 s = 0; s < 2; ++s)
			{
				BotFrames[s] += O.BotFrames[s]; Fast[s] += O.Fast[s]; Close[s] += O.Close[s]; Idle[s] += O.Idle[s]; IdleLong[s] += O.IdleLong[s]; Drift[s] += O.Drift[s];
				SumIdleShare[s] += O.SumIdleShare[s]; NShare[s] += O.NShare[s];
				for (int32 b = 0; b < 4; ++b) Shots[s][b] += O.Shots[s][b];
				AttThird[s] += O.AttThird[s];
				Carries[s] += O.Carries[s]; CarryShot[s] += O.CarryShot[s]; CarryPass[s] += O.CarryPass[s]; CarryLost[s] += O.CarryLost[s]; CarryOther[s] += O.CarryOther[s];
				CarryToNet[s] += O.CarryToNet[s]; CarryBack[s] += O.CarryBack[s]; CarrySlow[s] += O.CarrySlow[s]; CarryFr[s] += O.CarryFr[s];
			}
			for (int32 k = 0; k < NKey; ++k) IdleKey[k] += O.IdleKey[k];
			IdleYield += O.IdleYield;
			SkaterShares += O.SkaterShares; SkaterOver10 += O.SkaterOver10; MaxIdleShare = FMath::Max(MaxIdleShare, O.MaxIdleShare);
			Loose += O.Loose; LooseBotNear += O.LooseBotNear; LooseBotIn90 += O.LooseBotIn90; LooseHumanFirst += O.LooseHumanFirst; LooseFirstSum += O.LooseFirstSum; LooseFirstN += O.LooseFirstN; GoersSum += O.GoersSum;
			HumanShots += O.HumanShots;
			HumanAttCarry += O.HumanAttCarry; HumanAttOpen += O.HumanAttOpen; MateAway += O.MateAway; MateFwdFrames += O.MateFwdFrames;
		}
	};

	struct FTrace
	{
		FJamSimAdapter* Sim = nullptr;
		int64 LastFrame = -1;
		FAcc A;
		int64 IdleSk[MaxSk] = {}, PlaySk[MaxSk] = {};
		int32 IdleRun[MaxSk] = {};
		// loose episode
		bool bLoose = false; int64 LooseStart = 0; bool bLooseNear = false; int32 Goers = 0; bool bGoer[MaxSk] = {}; bool bLooseDone = false;
		// carry episode
		int32 CarryWho = -1; int64 CarryStart = 0; double CarryD0 = 0, CarryDMin = 0, CarrySpeedSum = 0; bool bCarryShot = false;
		int32 PrevCarrier = -1;
		int32 PassBy = -1; int64 PassAt = 0;
		FVector2D PassPos0; int64 RecvFrame[MaxSk] = {}; int32 RecvFrom[MaxSk] = {}; bool bRecvInit = false;
		bool bCarryLog = false, bEvery = false; int32 Seed = 0; FString Cell; double CarryOpp0 = 0; FVector2D CarryP0;
		int64 ShotF[MaxSk] = {}; bool bShotOpen[MaxSk] = {};
		int64 PlayStart = 0; bool bWasPlay = false;
		int32 ShotSide = -1, ShotBand = 0, ShotTeam = 0; int64 ShotAt = -10;
	};

	int32 Band(double D) { return D < 10.0 ? 0 : (D < 20.0 ? 1 : (D < 30.0 ? 2 : 3)); }

	void Trace(void* Ctx, const FJamAIWorld& AW, const FJamAIInput* AIn, const FJamBrain& Br, int64_t, bool)
	{
		FTrace& T = *static_cast<FTrace*>(Ctx);
		const UJamSim* Sim = T.Sim->GetSim();
		if (!Sim || Sim->GetFrame() == T.LastFrame) return;
		T.LastFrame = Sim->GetFrame();
		const int64 Now = T.LastFrame;
		const TArray<FJamSkaterState>& Sk = Sim->GetSkaters();
		const int32 N = FMath::Min(Sk.Num(), MaxSk);
		const FJamPuckState& Puck = Sim->GetPuck();
		const FJamRinkConfig& R = Sim->GetConfig().Rink;
		const double Top = FMath::Max(1.0, static_cast<double>(Sim->GetConfig().Skater.Speed));
		int32 Me = -1; for (int32 i = 0; i < N; ++i) if (Sk[i].bHuman) Me = i;
		const int32 HumanTeam = Me >= 0 ? Sk[Me].Team : 0;
		auto SideOf = [&](int32 i) { return Sk[i].Team == HumanTeam ? 0 : 1; };
		bool bFace = Sim->IsDrawOpen();
		for (int32 i = 0; i < N; ++i) if (Sk[i].bAtFaceoff) bFace = true;
		const bool bPlay = Sim->GetPhase() == EJamSimPhase::Playing && !bFace;
		const int32 Ci = Sim->CarrierIndex();
		auto GoalD = [&](int32 i) { return FVector2D::Distance(Sk[i].Pos, FVector2D(Sim->AttackGoalX(Sk[i].Team), 0.0)); };
		// the shot of the frame before: aimed if the puck leaves within 12 deg of the net's centre
		if (T.ShotSide >= 0 && Now == T.ShotAt + 1)
		{
			const FVector2D G(Sim->AttackGoalX(T.ShotTeam), 0.0);
			const FVector2D To = G - Puck.Pos; const double V = Puck.Vel.Size();
			if (V > 1.0 && To.Size() > 0.1 && FVector2D::DotProduct(Puck.Vel / V, To / To.Size()) > FMath::Cos(FMath::DegreesToRadians(12.0))) ++T.A.Aimed[T.ShotSide][T.ShotBand];
			T.ShotSide = -1;
		}
		// shots (every frame of play, the human's too)
		if (bPlay)
		{
			for (int32 i = 0; i < N; ++i)
			{
				if (!Sk[i].bShotThisFrame) continue;
				{
					const FVector2D G(Sim->AttackGoalX(Sk[i].Team), 0.0);
					if (FVector2D::Distance(Sk[i].Pos, G) > 15.0)
					{
						const int32 Def = 1 - SideOf(i);
						++T.A.FarShotsAgainst[Def];
						for (int32 j = 0; j < N; ++j) if (Sk[j].Team != Sk[i].Team && Sk[j].CanAct() && FVector2D::Distance(Sk[j].Pos, G) < 3.0) { ++T.A.FarShotsCrease[Def]; break; }
						if (T.bCarryLog)
						{
							FString Ds;
							for (int32 j = 0; j < N; ++j) if (Sk[j].Team != Sk[i].Team)
								Ds += FString::Printf(TEXT(" [%d%s r%d j%d g%.1f s%.1f%s]"), j, Sk[j].bHuman ? TEXT("H") : TEXT(""), static_cast<int32>(Br.LastRole(j)), static_cast<int32>(Br.LastJob(j)),
									FVector2D::Distance(Sk[j].Pos, G), FVector2D::Distance(Sk[j].Pos, Sk[i].Pos), Sk[j].CanAct() ? TEXT("") : TEXT(" down"));
							UE_LOG(LogTemp, Display, TEXT("FARSHOT %s s%d f%lld by %d (side %d) from %.1f m | defenders:%s"), *T.Cell, T.Seed, static_cast<long long>(Now), i, SideOf(i), FVector2D::Distance(Sk[i].Pos, G), *Ds);
						}
					}
				}
				if (Sk[i].bHuman) { ++T.A.HumanShots; continue; }
				++T.A.Shots[SideOf(i)][Band(GoalD(i))];
				++T.A.ShotsAll[SideOf(i)]; T.ShotF[i] = Now; T.bShotOpen[i] = true;
				T.ShotSide = SideOf(i); T.ShotBand = Band(GoalD(i)); T.ShotTeam = Sk[i].Team; T.ShotAt = Now;
				if (T.CarryWho == i) T.bCarryShot = true;
			}
		}
		// the bot carry episode: opens when a bot becomes the carrier, closes when the carrier changes or play stops
		if (bPlay && !T.bWasPlay) T.PlayStart = Now;
		T.bWasPlay = bPlay;
		for (const FJamSimEvent& E : Sim->GetFrameEvents())
		{
			if (E.Name != JamEvents::Goal || !Sk.IsValidIndex(E.Who)) continue;
			const int32 Against = 1 - SideOf(E.Who);   // the side that conceded (the scorer's last touch; an own goal counts against the scorer's opponents)
			++T.A.GoalsAgainstAll[Against];
			if (Now - T.PlayStart <= 600) ++T.A.EarlyGoalsAgainst[Against];
		}
		const int32 CarrierNow = bPlay ? Ci : -1;
		if (T.CarryWho >= 0 && CarrierNow != T.CarryWho)
		{
			// a carrier of -1 for a few frames (a puck a few centimetres out of reach) does not end it: it ends at the next carrier or a stop
			if (CarrierNow >= 0 || !bPlay || T.bCarryShot || Now - T.CarryStart > 600)
			{
				const int32 W = T.CarryWho, Sd = SideOf(W);
				const int64 Len = FMath::Max<int64>(1, Now - T.CarryStart);
				++T.A.Carries[Sd]; T.A.CarryFr[Sd] += Len;
				if (T.bCarryShot) ++T.A.CarryShot[Sd];
				else if (CarrierNow >= 0 && Sk[CarrierNow].Team == Sk[W].Team) ++T.A.CarryPass[Sd];
				else if (CarrierNow >= 0) ++T.A.CarryLost[Sd];
				else ++T.A.CarryOther[Sd];
				if (T.CarryD0 - T.CarryDMin > 5.0) ++T.A.CarryToNet[Sd];
				if (GoalD(W) > T.CarryD0 + 3.0) ++T.A.CarryBack[Sd];
				if (T.CarrySpeedSum / Len < 3.0 && Len > 30) ++T.A.CarrySlow[Sd];
				if (T.bCarryLog && T.CarryD0 < 30.0)
				{
					const FVector2D G(Sim->AttackGoalX(Sk[W].Team), 0.0);
					const FVector2D F(FMath::Cos(Sk[W].Yaw), FMath::Sin(Sk[W].Yaw));
					const FVector2D Tg = (G - Sk[W].Pos).GetSafeNormal();
					UE_LOG(LogTemp, Display, TEXT("CARRY %s s%d f%lld %s#%d %lld f: d0 %.1f dmin %.1f dend %.1f p0 (%.1f,%.1f) opp0 %.1f | end %s next %d | facing-to-net %.0f deg, speed %.1f"), *T.Cell, T.Seed, static_cast<long long>(T.CarryStart),
						Sd == 0 ? TEXT("MATE") : TEXT("OPP"), W, static_cast<long long>(Len), T.CarryD0, T.CarryDMin, GoalD(W), T.CarryP0.X, T.CarryP0.Y, T.CarryOpp0,
						T.bCarryShot ? TEXT("shot") : (CarrierNow >= 0 ? (Sk[CarrierNow].Team == Sk[W].Team ? TEXT("pass") : TEXT("lost")) : TEXT("other")), CarrierNow,
						FMath::RadiansToDegrees(FMath::Acos(FMath::Clamp(FVector2D::DotProduct(F, Tg), -1.0, 1.0))), Sk[W].Vel.Size());
				}
				T.CarryWho = -1; T.bCarryShot = false;
			}
		}
		if (bPlay && Ci >= 0 && Ci < N && !Sk[Ci].bHuman && T.CarryWho != Ci && T.CarryWho < 0)
		{
			T.CarryWho = Ci; T.CarryStart = Now; T.CarryD0 = T.CarryDMin = GoalD(Ci); T.CarrySpeedSum = 0; T.bCarryShot = false;
			T.CarryP0 = Sk[Ci].Pos; T.CarryOpp0 = 1e9;
			for (int32 k = 0; k < N; ++k) if (Sk[k].Team != Sk[Ci].Team && Sk[k].CanAct()) T.CarryOpp0 = FMath::Min(T.CarryOpp0, FVector2D::Distance(Sk[k].Pos, Sk[Ci].Pos));
		}
		if (T.bCarryLog && T.CarryWho >= 0 && T.CarryWho < AW.NumSkaters && GoalD(T.CarryWho) < 17.0 && (T.bEvery || (Now - T.CarryStart) % 10 == 0))
		{
			const int32 c = T.CarryWho;
			const JamAI::FJamAISkater& A = AW.Skaters[c];
			const JamAI::FVec2 G = AW.OppGoal(A.Team);
			const JamAI::FVec2 Dg = (G - AW.PuckPos).Normalized();
			const double Fa = FMath::RadiansToDegrees(FMath::Acos(FMath::Clamp(A.Facing.Normalized().Dot(Dg), -1.0, 1.0)));
			const JamAI::FVec2 Tg = G - AW.PuckPos;
			UE_LOG(LogTemp, Display, TEXT("CFRAME %s s%d f%lld #%d dgoal %.1f facing-off %.0f axis-off %.0f canshoot %d dpuck %.2f reach %.2f speed %.1f move (%.2f,%.2f) shoot %d held %d pass %d cone %.1f ready-in %lld frontdot %.2f"), *T.Cell, T.Seed, static_cast<long long>(Now), c,
				GoalD(c), Fa, FMath::RadiansToDegrees(FMath::Atan2(FMath::Abs(Tg.Y), FMath::Abs(Tg.X))), A.bCanShoot ? 1 : 0, A.Pos.DistTo(AW.PuckPos), AW.CarrierReach(), Sk[c].Vel.Size(),
				AIn ? AIn[c].Move.X : 0.0, AIn ? AIn[c].Move.Y : 0.0, AIn ? AIn[c].bShoot : 0, AIn ? AIn[c].bShootHeld : 0, AIn ? AIn[c].bPass : 0, Br.Params.AimConeDeg, static_cast<long long>(Sk[c].ShotReadyFrame - Now), FVector2D::DotProduct(Sk[c].Forward(), (Puck.Pos - Sk[c].Pos).GetSafeNormal()));
		}
		if (T.CarryWho >= 0) { T.CarryDMin = FMath::Min(T.CarryDMin, GoalD(T.CarryWho)); T.CarrySpeedSum += Sk[T.CarryWho].Vel.Size(); }
		if (!bPlay)
		{
			T.PassBy = -1;
			for (int32 i = 0; i < N; ++i) T.IdleRun[i] = 0;
			T.bLoose = false;
			T.PrevCarrier = -1;
			return;
		}
		++T.A.PlayFrames;
		for (int32 i = 0; i < N; ++i)
		{
			if (!T.bShotOpen[i] || Now == T.ShotF[i]) continue;
			if (Now - T.ShotF[i] > 30 || (Ci >= 0 && Ci != i)) { T.bShotOpen[i] = false; continue; }
			if (Ci == i && Now - T.ShotF[i] > 3 && (Puck.Vel - Sk[i].Vel).Size() < 2.0) { ++T.A.ShotBack[SideOf(i)]; T.bShotOpen[i] = false; }   // the puck rides with him again
		}
		if (Ci >= 0) ++T.A.Poss[SideOf(Ci)];
		// passes by bots: complete when the next carrier is a team-mate within 2 s
		if (T.PassBy >= 0 && (Ci >= 0 && Ci != T.PassBy))
		{
			if (Sk[Ci].Team == Sk[T.PassBy].Team)
			{
				const int32 Ps = SideOf(T.PassBy);
				++T.A.PassDone[Ps];
				if (FVector2D::Distance(Sk[Ci].Pos, T.PassPos0) > 6.0) ++T.A.LongDone[Ps];
				if (T.RecvFrom[T.PassBy] == Ci && T.PassAt - T.RecvFrame[T.PassBy] <= 60) ++T.A.BackPass[Ps];   // straight back to the man it came from
				T.RecvFrame[Ci] = Now; T.RecvFrom[Ci] = T.PassBy;
			}
			T.PassBy = -1;
		}
		if (T.PassBy >= 0 && Now - T.PassAt > 120) T.PassBy = -1;
		if (!T.bRecvInit) { for (int32 i = 0; i < MaxSk; ++i) { T.RecvFrame[i] = -1000; T.RecvFrom[i] = -1; } T.bRecvInit = true; }
		for (int32 i = 0; i < N; ++i) if (!Sk[i].bHuman && Sk[i].bPassThisFrame)
		{
			++T.A.Passes[SideOf(i)]; T.PassBy = i; T.PassAt = Now; T.PassPos0 = Sk[i].Pos;
			if (Now - T.RecvFrame[i] <= 15) ++T.A.QuickRepass[SideOf(i)];   // touched again within 15 frames of receiving it
		}
		// defence: the carrier's opponents while the puck is in their own half
		if (Ci >= 0)
		{
			const int32 Att = SideOf(Ci), Def = 1 - Att;
			const int32 DefTeam = Sk[Ci].Team == 0 ? 1 : 0;
			const FVector2D Own(Sim->AttackGoalX(Sk[Ci].Team), 0.0);   // the defenders' own net
			if (Puck.Pos.X * FMath::Sign(Own.X) > 0.0)
			{
				++T.A.DefFrames[Def];
				const FVector2D Cp = Sk[Ci].Pos;
				bool bOn = false, bCrease = false, bRecv = false, bClump = false;
				int32 Rv = -1; double Rd = 1e9;
				for (int32 j = 0; j < N; ++j) if (j != Ci && Sk[j].Team == Sk[Ci].Team && Sk[j].CanAct()) { const double D = FVector2D::Distance(Sk[j].Pos, Own); if (D < Rd) { Rd = D; Rv = j; } }
				for (int32 j = 0; j < N; ++j)
				{
					if (Sk[j].Team != DefTeam || !Sk[j].CanAct()) continue;
					if (FVector2D::Distance(Sk[j].Pos, Cp) < 3.0 && FVector2D::DotProduct(Sk[j].Pos - Cp, Own - Cp) > 0.0) bOn = true;
					if (FVector2D::Distance(Sk[j].Pos, Own) < 4.0) bCrease = true;
					if (Rv >= 0 && FVector2D::Distance(Sk[j].Pos, Sk[Rv].Pos) < 3.0) bRecv = true;
					for (int32 k = j + 1; k < N; ++k)
						if (Sk[k].Team == DefTeam && Sk[k].CanAct() && !Sk[j].bHuman && !Sk[k].bHuman && FVector2D::Distance(Sk[j].Pos, Sk[k].Pos) < 3.0
							&& FVector2D::Distance(Sk[j].Pos, Puck.Pos) > 3.0 && FVector2D::Distance(Sk[k].Pos, Puck.Pos) > 3.0) bClump = true;
				}
				if (bOn) ++T.A.DefOnCarrier[Def]; if (bCrease) ++T.A.DefCrease[Def]; if (bRecv) ++T.A.DefReceiver[Def]; if (bClump) ++T.A.DefClump[Def];
			}
		}
		// the human carrying: an opponent within 4 m of him
		if (Me >= 0 && Ci == Me)
		{
			++T.A.HumanCarry;
			for (int32 k = 0; k < N; ++k) if (Sk[k].Team != HumanTeam && Sk[k].CanAct() && FVector2D::Distance(Sk[k].Pos, Sk[Me].Pos) < 4.0) { ++T.A.HumanPressed; break; }
		}
		// a side carrying in its attacking third: a team-mate of the carrier (not him) within 7 m of the net front (5 m out on the axis)
		if (Ci >= 0)
		{
			const double Ax = Sim->AttackGoalX(Sk[Ci].Team);
			if (Puck.Pos.X * FMath::Sign(Ax) > R.LengthM / 6.0)
			{
				const int32 Sd = SideOf(Ci);
				++T.A.AttFrames[Sd];
				const FVector2D Nf(Ax - FMath::Sign(Ax) * 5.0, 0.0);
				for (int32 j = 0; j < N; ++j) if (j != Ci && Sk[j].Team == Sk[Ci].Team && Sk[j].CanAct() && FVector2D::Distance(Sk[j].Pos, Nf) < 7.0) { ++T.A.NetFront[Sd]; break; }
			}
		}
		// the attacking third
		if (Ci >= 0)
		{
			const double Ax = Sim->AttackGoalX(Sk[Ci].Team);
			if (Puck.Pos.X * FMath::Sign(Ax) > R.LengthM / 6.0) ++T.A.AttThird[SideOf(Ci)];
		}
		// loose pucks: an episode opens the frame the carrier is lost (a pass, a shot, a poke, a rebound) and closes at the next carrier
		if (Ci < 0 && !T.bLoose)
		{
			T.bLoose = true; T.LooseStart = Now; T.Goers = 0; T.bLooseDone = false; FMemory::Memzero(T.bGoer);
			double Nb = 1e9; for (int32 j = 0; j < N; ++j) if (!Sk[j].bHuman && Sk[j].CanAct()) Nb = FMath::Min(Nb, FVector2D::Distance(Sk[j].Pos, Puck.Pos));
			T.bLooseNear = Nb < 15.0;
			++T.A.Loose; if (T.bLooseNear) ++T.A.LooseBotNear;
		}
		if (T.bLoose && Now - T.LooseStart < 45)
		{
			for (int32 j = 0; j < N; ++j)
			{
				if (Sk[j].bHuman || !Sk[j].CanAct() || T.bGoer[j]) continue;
				const FVector2D To = Puck.Pos - Sk[j].Pos; const double L = To.Size();
				if (L < 15.0 && L > 0.1 && FVector2D::DotProduct(Sk[j].Vel, To / L) > 0.4 * Top) { T.bGoer[j] = true; ++T.Goers; }
			}
		}
		if (T.bLoose && Ci >= 0)
		{
			const double Sec = (Now - T.LooseStart) / 60.0;
			if (Sk[Ci].bHuman) ++T.A.LooseHumanFirst;
			else { T.A.LooseFirstSum += Sec; ++T.A.LooseFirstN; if (T.bLooseNear && Now - T.LooseStart <= 90) ++T.A.LooseBotIn90; }
			T.A.GoersSum += T.Goers;
			T.bLoose = false;
		}
		// the human carries in the attacking half: an open mate ahead of him (nearer the net, no opponent within 3 m)
		if (Me >= 0 && Ci == Me)
		{
			const double Ax = Sim->AttackGoalX(HumanTeam);
			if (Sk[Me].Pos.X * FMath::Sign(Ax) > 0.0)
			{
				++T.A.HumanAttCarry;
				const double Dh = GoalD(Me);
				for (int32 j = 0; j < N; ++j)
				{
					if (j == Me || Sk[j].Team != HumanTeam || !Sk[j].CanAct() || GoalD(j) > Dh - 2.0) continue;
					bool bOpen = true;
					for (int32 k = 0; k < N; ++k) if (Sk[k].Team != HumanTeam && Sk[k].CanAct() && FVector2D::Distance(Sk[k].Pos, Sk[j].Pos) < 3.0) { bOpen = false; break; }
					if (bOpen) { ++T.A.HumanAttOpen; break; }
				}
			}
		}
		// per bot
		const bool bMatesOwn = Ci >= 0 && Sk[Ci].Team == HumanTeam;
		for (int32 i = 0; i < N; ++i)
		{
			const FJamSkaterState& S = Sk[i];
			if (S.bHuman) continue;
			const int32 Sd = SideOf(i);
			++T.A.BotFrames[Sd]; ++T.PlaySk[i];
			const double V = S.Vel.Size();
			if (V > 0.5 * Top) ++T.A.Fast[Sd];
			// closing on the puck or on the man with it
			{
				const FVector2D Tg = Ci >= 0 && Ci != i ? Sk[Ci].Pos : Puck.Pos;
				const FVector2D To = Tg - S.Pos; const double L = To.Size();
				if (Ci != i && L > 0.5 && FVector2D::DotProduct(S.Vel, To / L) > 0.35 * Top) ++T.A.Close[Sd];
			}
			// no job: on its feet, not the carrier, under 1.5 m/s, not within 4 m of its own goal (the last man in his crease), not within 3 m of the puck
			const FVector2D Own(-Sim->AttackGoalX(S.Team), 0.0);
			const bool bCrease = FVector2D::Distance(S.Pos, Own) < 4.0;
			const bool bIdle = S.CanAct() && Ci != i && V < 1.5 && !bCrease && FVector2D::Distance(S.Pos, Puck.Pos) > 3.0;
			const bool bDrift = S.CanAct() && Ci != i && V >= 1.5 && V < 0.3 * Top && !bCrease;
			if (bDrift) ++T.A.Drift[Sd];
			if (bIdle)
			{
				++T.A.Idle[Sd]; ++T.IdleSk[i]; ++T.IdleRun[i];
				const int32 Ro = FMath::Clamp(static_cast<int32>(Br.LastRole(i)), 0, 3), Jo = FMath::Clamp(static_cast<int32>(Br.LastJob(i)), 0, 7);
				++T.A.IdleKey[Sd * 32 + Ro * 8 + Jo];
				if (Sd == 0 && Me >= 0)
				{
					const double Db = FVector2D::Distance(Sk[Me].Pos, Puck.Pos), D = FVector2D::Distance(S.Pos, Puck.Pos);
					if (Db <= D + Br.Params.YieldMarginM && Db < Br.Params.YieldRadiusM) ++T.A.IdleYield;
				}
			}
			else
			{
				if (T.IdleRun[i] > 60) T.A.IdleLong[Sd] += T.IdleRun[i];
				T.IdleRun[i] = 0;
			}
			// the human's forward mates while their side has the puck: skating away from the puck at more than a third of top speed, 12 m or more from it
			if (Sd == 0 && bMatesOwn && Ci != i && S.CanAct() && Br.LastRole(i) != ERole::Back)
			{
				++T.A.MateFwdFrames;
				const FVector2D To = Puck.Pos - S.Pos; const double L = To.Size();
				if (L > 12.0 && FVector2D::DotProduct(S.Vel, To / L) < -0.33 * Top) ++T.A.MateAway;
			}
		}
	}

	void Finish(FTrace& T)
	{
		const UJamSim* Sim = T.Sim->GetSim();
		if (!Sim) return;
		const TArray<FJamSkaterState>& Sk = Sim->GetSkaters();
		int32 Me = -1; for (int32 i = 0; i < FMath::Min(Sk.Num(), MaxSk); ++i) if (Sk[i].bHuman) Me = i;
		const int32 HumanTeam = Me >= 0 ? Sk[Me].Team : 0;
		for (int32 i = 0; i < FMath::Min(Sk.Num(), MaxSk); ++i)
		{
			if (Sk[i].bHuman || T.PlaySk[i] <= 0) continue;
			if (T.IdleRun[i] > 60) T.A.IdleLong[Sk[i].Team == HumanTeam ? 0 : 1] += T.IdleRun[i];
			const double Sh = static_cast<double>(T.IdleSk[i]) / T.PlaySk[i];
			const int32 Sd = Sk[i].Team == HumanTeam ? 0 : 1;
			++T.A.SkaterShares; if (Sh > 0.10) ++T.A.SkaterOver10;
			T.A.MaxIdleShare = FMath::Max(T.A.MaxIdleShare, Sh);
			T.A.SumIdleShare[Sd] += Sh; ++T.A.NShare[Sd];
		}
	}

	FString Summary(const FAcc& A, int32 Matches)
	{
		const double Mn = FMath::Max(1, Matches);
		const double Min = FMath::Max(1.0, A.PlayFrames / 3600.0);
		auto Pc = [](int64 a, int64 b) { return b > 0 ? 100.0 * a / b : 0.0; };
		FString L;
		for (int32 s = 0; s < 2; ++s)
		{
			const int32 Sh = A.Shots[s][0] + A.Shots[s][1] + A.Shots[s][2] + A.Shots[s][3];
			L += FString::Printf(TEXT(" | %s: fast %.1f %% close %.1f %% idle %.1f %% (in runs > 1 s %.1f %%) drift %.1f %% mean-idle/skater %.1f %% | shots/min %.2f (<10 %d, 10-20 %d, 20-30 %d, >30 %d; aimed %d / %d / %d / %d) | att-third s/match %.1f | carries %d: shot %.0f %% pass %.0f %% lost %.0f %% other %.0f %%; to-net %.0f %% back %.0f %% slow %.0f %%; mean %.1f s | possession %.1f %% | passes %d done %.0f %% | net front in att third %.0f %% | shots taken back by the shooter %d of %d | PASSQ re-passed within 15 f %.0f %% back to the passer %.0f %% done over 6 m %.0f %% of passes | DEF (defending) frames %lld on-carrier %.0f %% crease %.0f %% receiver %.0f %% clump %.0f %% | far shots against %d crease held %.0f %% | goals against %d, inside 10 s of a restart %d"),
				s == 0 ? TEXT("MATES") : TEXT("OPPS"), Pc(A.Fast[s], A.BotFrames[s]), Pc(A.Close[s], A.BotFrames[s]), Pc(A.Idle[s], A.BotFrames[s]), Pc(A.IdleLong[s], A.BotFrames[s]), Pc(A.Drift[s], A.BotFrames[s]),
				A.NShare[s] > 0 ? 100.0 * A.SumIdleShare[s] / A.NShare[s] : 0.0,
				Sh / Min, A.Shots[s][0], A.Shots[s][1], A.Shots[s][2], A.Shots[s][3], A.Aimed[s][0], A.Aimed[s][1], A.Aimed[s][2], A.Aimed[s][3], A.AttThird[s] / 60.0 / Mn,
				A.Carries[s], Pc(A.CarryShot[s], A.Carries[s]), Pc(A.CarryPass[s], A.Carries[s]), Pc(A.CarryLost[s], A.Carries[s]), Pc(A.CarryOther[s], A.Carries[s]),
				Pc(A.CarryToNet[s], A.Carries[s]), Pc(A.CarryBack[s], A.Carries[s]), Pc(A.CarrySlow[s], A.Carries[s]), A.Carries[s] > 0 ? A.CarryFr[s] / 60.0 / A.Carries[s] : 0.0,
				Pc(A.Poss[s], A.PlayFrames), A.Passes[s], Pc(A.PassDone[s], A.Passes[s]), Pc(A.NetFront[s], A.AttFrames[s]), A.ShotBack[s], A.ShotsAll[s],
				Pc(A.QuickRepass[s], A.Passes[s]), Pc(A.BackPass[s], A.Passes[s]), Pc(A.LongDone[s], A.Passes[s]),
				static_cast<long long>(A.DefFrames[s]), Pc(A.DefOnCarrier[s], A.DefFrames[s]), Pc(A.DefCrease[s], A.DefFrames[s]), Pc(A.DefReceiver[s], A.DefFrames[s]), Pc(A.DefClump[s], A.DefFrames[s]),
				A.FarShotsAgainst[s], Pc(A.FarShotsCrease[s], A.FarShotsAgainst[s]), A.GoalsAgainstAll[s], A.EarlyGoalsAgainst[s]);
		}
		L += FString::Printf(TEXT(" | skaters over 10 %% idle %d of %d (max %.1f %%) | loose %d: bot within 15 m %d, a bot on it within 1.5 s %.1f %%, human first %d, mean to first bot touch %.2f s, bots going (first 0.75 s) %.2f | human shots/min %.2f | human carries in att half %.1f s/match, open mate ahead %.1f %% | mates skating away %.1f %% | mates' idle under the yield %.1f %% of their idle | human carry pressed (opp within 4 m) %.1f %% | play min/match %.2f"),
			A.SkaterOver10, A.SkaterShares, 100.0 * A.MaxIdleShare, A.Loose, A.LooseBotNear, Pc(A.LooseBotIn90, A.LooseBotNear), A.LooseHumanFirst, A.LooseFirstN > 0 ? A.LooseFirstSum / A.LooseFirstN : 0.0,
			A.Loose > 0 ? A.GoersSum / A.Loose : 0.0, A.HumanShots / Min, A.HumanAttCarry / 60.0 / Mn, Pc(A.HumanAttOpen, A.HumanAttCarry), Pc(A.MateAway, A.MateFwdFrames), Pc(A.IdleYield, A.Idle[0]), Pc(A.HumanPressed, A.HumanCarry), A.PlayFrames / 3600.0 / Mn);
		return L;
	}

	struct FOpt { TArray<FString> Levels, Carts; int32 Seeds = 20, From = 1; FString Tune, Player = TEXT("regular"); bool bCarryLog = false, bEvery = false; };
	FOpt ReadOpt()
	{
		FOpt O;
		O.Levels = { TEXT("rookie"), TEXT("pro") };
		O.Carts = { TEXT("hockey.regular") };
		const FString Env = FPlatformMisc::GetEnvironmentVariable(TEXT("JAM_BRAIN_INTEREST"));
		TArray<FString> Parts;
		Env.ParseIntoArray(Parts, TEXT(";"));
		for (const FString& Part : Parts)
		{
			FString K, V;
			if (!Part.Split(TEXT("="), &K, &V)) continue;
			if (K == TEXT("levels")) { O.Levels.Reset(); V.ParseIntoArray(O.Levels, TEXT(",")); }
			else if (K == TEXT("carts")) { O.Carts.Reset(); V.ParseIntoArray(O.Carts, TEXT(",")); }
			else if (K == TEXT("seeds")) O.Seeds = FCString::Atoi(*V);
			else if (K == TEXT("from")) O.From = FCString::Atoi(*V);
			else if (K == TEXT("player")) O.Player = V;
			else if (K == TEXT("carrylog")) { O.bCarryLog = V == TEXT("1") || V == TEXT("2"); O.bEvery = V == TEXT("2"); }
			else if (K == TEXT("tune")) O.Tune = V.Replace(TEXT("|"), TEXT(";"));   // the tune's own ';' written as '|'
		}
		return O;
	}
	const TCHAR* RoleName(int32 R) { static const TCHAR* N[] = { TEXT("Player"), TEXT("Chaser"), TEXT("Support"), TEXT("Back") }; return R >= 0 && R < 4 ? N[R] : TEXT("?"); }
	const TCHAR* JobName(int32 J) { static const TCHAR* N[] = { TEXT("None"), TEXT("Puck"), TEXT("Support"), TEXT("Far"), TEXT("Point"), TEXT("Press"), TEXT("Cover"), TEXT("Weak") }; return J >= 0 && J < 8 ? N[J] : TEXT("?"); }
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamBarBrainInterest, "Bar.Brain.Interest", JamHockeyBrain9Interest::BarFlags)
bool FJamBarBrainInterest::RunTest(const FString& Parameters)
{
	using namespace JamHockeyBrain9Interest;
	const FOpt O = ReadOpt();
	const EPlaytester Kind = O.Player == TEXT("novice") ? EPlaytester::Novice : (O.Player == TEXT("good") ? EPlaytester::Good : EPlaytester::Regular);
	for (const FString& CartName : O.Carts)
	{
		TArray<FString> Errors;
		UJamCartridge* C = UJamCartridge::LoadFromFile(UJamCartridge::ResolveCartridgePath(CartName), Errors);
		for (const FString& E : Errors) AddError(E);
		if (!C) continue;
		C->AddToRoot();
		for (const FString& Lv : O.Levels)
		{
			FAcc Sum;
			int32 Matches = 0, Wins = 0;
			for (int32 Seed = O.From; Seed < O.From + O.Seeds; ++Seed)
			{
				FJamMatchConfig Cfg = ToMatchConfigResolved(*C, *Lv);
				if (!O.Tune.IsEmpty()) { char Err[256] = {}; if (!ApplyDifficultyTune(TCHAR_TO_ANSI(*O.Tune), Cfg.AI, Err, sizeof(Err))) AddError(FString::Printf(TEXT("tune: %hs"), Err)); }
				FJamSimAdapter Sim(*C);
				FTrace* T = new FTrace();
				T->Sim = &Sim; T->bCarryLog = O.bCarryLog; T->bEvery = O.bEvery; T->Seed = Seed; T->Cell = Lv;
				const FJamPlaytestStats S = RunPlaytestMatch(Sim, Cfg, static_cast<uint64>(Seed), Kind, 36000, C->Game.Shot.ChargeFramesMax, false, &Trace, T, 1);
				Finish(*T);
				++Matches; if (S.GoalsFor > S.GoalsAgainst) ++Wins;
				AddInfo(FString::Printf(TEXT("INTEREST match %s@%s seed %d: %lld frames, %d:%d, hash %016llx | HITS kd_given %d checks_landed %d presses %d cross_landed %d knocked_down %d%s"), *CartName, *Lv, Seed, static_cast<long long>(S.Frames), S.GoalsFor, S.GoalsAgainst,
					static_cast<unsigned long long>(S.Hash), S.KdGiven, S.ChecksLanded, S.CheckPresses, S.CrossLanded, S.Knockdowns, *Summary(T->A, 1)));
				Sum.Add(T->A);
				delete T;
			}
			AddInfo(FString::Printf(TEXT("INTEREST cell %s@%s player %s tune \"%s\": %d matches, human wins %d%s"), *CartName, *Lv, *O.Player, *O.Tune, Matches, Wins, *Summary(Sum, Matches)));
			// which role and job the idle frames are in
			TArray<TPair<int64, int32>> Keys;
			for (int32 k = 0; k < NKey; ++k) if (Sum.IdleKey[k] > 0) Keys.Add(TPair<int64, int32>(Sum.IdleKey[k], k));
			Keys.Sort([](const TPair<int64, int32>& A, const TPair<int64, int32>& B) { return A.Key > B.Key; });
			FString Ks;
			for (int32 k = 0; k < FMath::Min(10, Keys.Num()); ++k)
			{
				const int32 Key = Keys[k].Value, Sd = Key / 32, Ro = (Key / 8) % 4, Jo = Key % 8;
				Ks += FString::Printf(TEXT(" [%s %s/%s %.1f %%]"), Sd == 0 ? TEXT("mate") : TEXT("opp"), RoleName(Ro), JobName(Jo), Sum.Idle[Sd] > 0 ? 100.0 * Keys[k].Key / Sum.Idle[Sd] : 0.0);
			}
			AddInfo(FString::Printf(TEXT("INTEREST idle-by-job %s@%s:%s"), *CartName, *Lv, *Ks));
		}
		C->RemoveFromRoot();
	}
	return true;
}


// ---- Jam.Bot.Hockey9.*: evolution 9's switch and its rules in staged scenes (in the gate) ----
namespace JamHockeyBrain9TestsLocal
{
	constexpr EAutomationTestFlags Flags = EAutomationTestFlags::EditorContext | EAutomationTestFlags::CommandletContext | EAutomationTestFlags::EngineFilter;
	using namespace JamAI;
	bool Off9(const FJamHockeySense& H)
	{
		return H.ShootExtra9M == 0.0 && !H.bAimCone9 && H.OppPace9 == 0.0 && H.AimError9Deg == 0.0 && H.React9Frames == 0 && !H.bNetFront9 && !H.bChipUp9
			&& H.DriveNet9M == 0.0 && H.Pressure9S == 0.0 && H.ShotCharge9Frames == 0 && !H.bOneTimer9 && H.Poke9Frames == 0 && !H.bMeetPass9 && !H.bAheadWeak9 && !H.bMarkMan9 && !H.bShotLane9 && !H.bDriveFirst9 && H.Dodge9Share == 0.0 && H.DropNoHit9Frames == 0 && !H.bPassCare9 && !H.bDefendTeam9 && !H.bCreaseKeeper9 && !H.bScrumStay9 && !H.bNetNeverEmpty9 && H.EarlyLongShot9Frames == 0 && !H.bMeetLine9;
	}
	// 5 v 5 on 90 x 45: the human is skater 0 (team 0, attacks +x); team 1 (attacks -x) skaters 5-9.
	FJamAIWorld Five()
	{
		FJamAIWorld W;
		W.HalfLength = 45.0; W.HalfWidth = 22.5; W.GoalX = 41.0; W.NumSkaters = 10; W.PlayerIndex = 0; W.Frame = 1000;
		const ERole Roles[5] = { ERole::Player, ERole::Support, ERole::Support, ERole::Back, ERole::Back };
		for (int i = 0; i < 10; ++i)
		{
			FJamAISkater& S = W.Skaters[i];
			S.Team = i < 5 ? 0 : 1;
			S.Role = i == 5 ? ERole::Chaser : Roles[i % 5];
			S.Facing = FVec2(S.Team == 0 ? 1.0 : -1.0, 0.0);
			S.Pos = FVec2(S.Team == 0 ? -30.0 : 30.0, -12.0 + 6.0 * (i % 5));
			S.Spawn = S.Pos;
		}
		return W;
	}
}

// The switch: every level's profile plays evolution 9 (the mates' shot, the drive, the net front; rookie's pace and read); brain9=0 and every older brainN=0
// switch all of it off on both sides (the old game: the hash proof is the measurement's, status/A206.md).
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamHockey9Neutral, "Jam.Bot.Hockey9.Neutral", JamHockeyBrain9TestsLocal::Flags)
bool FJamHockey9Neutral::RunTest(const FString& Parameters)
{
	using namespace JamHockeyBrain9TestsLocal;
	for (EDifficulty Lv : { EDifficulty::Rookie, EDifficulty::Pro, EDifficulty::AllStar })
	{
		FJamAIParams A; ApplyDifficultyProfile(GetDifficultyProfile(Lv), A);
		TestTrue(*FString::Printf(TEXT("%hs: the mates shoot (cone, reach, one-timer), drive and go to the net front"), DifficultyName(Lv)),
			A.Mate.Hk.bAimCone9 && A.Mate.Hk.ShootExtra9M == kEvo9MateShootExtraM && A.Mate.Hk.bOneTimer9 && A.Mate.Hk.DriveNet9M == kEvo9DriveNetM && A.Mate.Hk.bNetFront9
			&& A.Mate.Hk.Pressure9S == kEvo9MatePressureS);
		TestTrue(TEXT("the opponents drive, go to the net front, chip only up the ice"), A.Opp.Hk.DriveNet9M == kEvo9DriveNetM && A.Opp.Hk.bNetFront9 && A.Opp.Hk.bChipUp9
			&& !A.Opp.Hk.bAimCone9 && A.Opp.Hk.Pressure9S == 0.0);
		const bool bRk = Lv == EDifficulty::Rookie;
		TestTrue(TEXT("rookie's pace and clumsy execution (stick, aim, reach) are rookie's alone; no level reads late by evolution 9"),
			(bRk ? (A.Opp.Hk.OppPace9 > 0.0 && A.Opp.Hk.Poke9Frames > 0 && A.Opp.Hk.AimError9Deg > 0.0 && A.Opp.Hk.ShootExtra9M > 0.0)
				 : (A.Opp.Hk.OppPace9 == 0.0 && A.Opp.Hk.Poke9Frames == 0 && A.Opp.Hk.AimError9Deg == 0.0 && A.Opp.Hk.ShootExtra9M == 0.0)) && A.Opp.Hk.React9Frames == 0);
		TestTrue(TEXT("wave 2: pro and all_star step off the human's hit a share of the time, rookie never; the mates never"), (Lv == EDifficulty::Rookie ? A.Opp.Hk.Dodge9Share == 0.0 : A.Opp.Hk.Dodge9Share > 0.0) && A.Mate.Hk.Dodge9Share == 0.0);
		for (const char* Tune : { "brain9=0", "brain8=0", "brain2=0", "brain7=0" })
		{
			FJamAIParams P = A; char Err[200] = {};
			TestTrue(*FString::Printf(TEXT("%hs applies"), Tune), ApplyDifficultyTune(Tune, P, Err, sizeof(Err)));
			TestTrue(*FString::Printf(TEXT("%hs: every rule of evolution 9 off, both sides"), Tune), Off9(P.Opp.Hk) && Off9(P.Mate.Hk));
		}
	}
	FJamAIParams Q; ApplyDifficultyProfile(GetDifficultyProfile(EDifficulty::Pro), Q); char Err[200] = {};
	TestTrue(TEXT("the one-rule keys apply"), ApplyDifficultyTune("brain9=0;opp.hk_opp_pace9=0.9;mate.hk_aim_cone9=1;opp.hk_drive_net9_m=18;mate.hk_net_front9=1;opp.hk_react9_frames=4;mate.hk_shoot_extra9_m=12;opp.hk_chip_up9=1;mate.hk_pressure9_s=0.5;opp.hk_shot_charge9_frames=8;mate.hk_one_timer9=1;opp.hk_aim_error9_deg=3", Q, Err, sizeof(Err)));
	TestTrue(TEXT("... and set what they name"), Q.Opp.Hk.OppPace9 == 0.9 && Q.Mate.Hk.bAimCone9 && Q.Opp.Hk.DriveNet9M == 18.0 && Q.Mate.Hk.bNetFront9 && !Q.Opp.Hk.bNetFront9 && Q.Opp.Hk.React9Frames == 4
		&& Q.Mate.Hk.ShootExtra9M == 12.0 && Q.Opp.Hk.bChipUp9 && Q.Mate.Hk.Pressure9S == 0.5 && Q.Opp.Hk.ShotCharge9Frames == 8 && Q.Mate.Hk.bOneTimer9 && Q.Opp.Hk.AimError9Deg == 3.0);
	return true;
}

// OppPace9: rookie's opposing chaser skates at SpeedScale x RedSkill (0.85 x 0.80 = 0.68 of top speed) without it; with it at least OppPace9. The human's
// mates are not touched.
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamHockey9Pace, "Jam.Bot.Hockey9.OppPace", JamHockeyBrain9TestsLocal::Flags)
bool FJamHockey9Pace::RunTest(const FString& Parameters)
{
	using namespace JamHockeyBrain9TestsLocal;
	auto Scene = [](double Pace, double& OutOpp, double& OutMate)
	{
		FJamAIWorld W = Five();
		W.PuckPos = FVec2(0.0, 15.0); W.PuckVel = FVec2(0.0, 0.0); W.PuckLastTouch = 0; W.Carrier = W.Holder = -1;
		FJamBrain B;
		B.Reset();
		B.Params.SpeedScale = 0.85; B.Params.RedSkill = 0.80; B.Params.MateSpeedScale = 1.0;
		B.Params.Opp.Hk.OppPace9 = Pace; B.Params.Mate.Hk.OppPace9 = Pace;
		FJamAIInput In[kMaxSkaters];
		for (int f = 0; f < 5; ++f) { W.Frame = 1000 + f; B.Think(W, In); }
		OutOpp = In[5].Move.Length(); OutMate = In[1].Move.Length();
	};
	double Oo = 0, Mo = 0, On = 0, Mn = 0;
	Scene(0.0, Oo, Mo); Scene(0.95, On, Mn);
	AddInfo(FString::Printf(TEXT("the opposing chaser's move %.3f off, %.3f with OppPace9 0.95; the human's mate %.3f / %.3f"), Oo, On, Mo, Mn));
	TestTrue(TEXT("off: SpeedScale x RedSkill (0.68)"), FMath::Abs(Oo - 0.68) < 0.02);
	TestTrue(TEXT("on: the pace floor (0.95)"), FMath::Abs(On - 0.95) < 0.02);
	TestTrue(TEXT("the human's mate is not touched"), FMath::Abs(Mo - Mn) < 1e-9);
	return true;
}

#endif
