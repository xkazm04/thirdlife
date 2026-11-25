// Lane A202 (track Q2, evolution 8; docs/experiments/BRAIN-8.md): the bots do nothing stupid in front of the operator.
//   Bar.Brain.Watch   real matches traced frame by frame (RunPlaytestMatch's trace, every frame, the whole UJamSim), detectors over the trace: each
//                     with its episodes a match and the worst moments (cart, level, seed, frame, who, frames). A measurement, outside the gate.
//   env JAM_BRAIN_WATCH = "levels=pro,all_star;carts=hockey.regular,hockey.arena.large;seeds=6;from=1;tune=brain8=0;player=regular" (every part optional)
//   UnrealEditor-Cmd ThirdJam.uproject -ExecCmds="Automation RunTests Bar.Brain.Watch; Quit" -nullrhi -Multiprocess -unattended -nopause -stdout
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
#include "JamBaseline.h"
#include "UObject/Package.h"

#if WITH_DEV_AUTOMATION_TESTS

namespace JamHockeyBrain8Watch
{
	using namespace JamAI;
	constexpr EAutomationTestFlags BarFlags = EAutomationTestFlags_ApplicationContextMask | EAutomationTestFlags::ProductFilter;
	constexpr int32 MaxSk = 16;

	enum EDet
	{
		BoardPress = 0, NetPress, Clump, DownStandBot, DownStandHuman, DownPushBot, Circle, LooseIgnored, OwnZoneCarry, EmptySlot, LongShot, LongShotMateOpen,
		LongGoal, OffPuckCheck, Idle, CarrierStall, HumanNoTouch30, BraceHitBot, BraceHitHuman, CircleNet, LongShotAttHalf, DetCount
	};
	const TCHAR* DetName(int32 D)
	{
		static const TCHAR* N[] = {
			TEXT("bot pressing into the boards > 60 f (BoardFrames, under 2 m/s)"), TEXT("bot pressing into a net > 60 f (inside 0.8 m of the frame, under 1 m/s)"),
			TEXT("two mates inside 1.5 m > 90 f (a clump; a bot among them)"), TEXT("bot standing inside 1.2 m of a downed body > 30 f"),
			TEXT("the human standing inside 1.2 m of a downed body > 30 f"), TEXT("bot pushing a downed body (inside 1.2 m, closing > 0.5 m/s, > 30 f)"),
			TEXT("bot circling (> 720 deg of heading in 180 f, no touch)"), TEXT("loose puck: nobody inside 6 m for 90 f, a bot inside 10 m"),
			TEXT("bot carrier skating into his own zone, open ice ahead (> 45 f)"), TEXT("slot empty of defenders, the puck carried below the circles (> 60 f)"),
			TEXT("bot shot from beyond 30 m"), TEXT("bot shot from beyond 30 m with a mate open 5 m nearer"), TEXT("goal by a bot from beyond 30 m"),
			TEXT("bot check / cross press on a man without the puck, 15 m from it"), TEXT("bot idle (under 0.3 m/s, standing, no puck, > 180 f)"),
			TEXT("bot carrier stalled (under 1 m/s with the puck > 60 f)"), TEXT("the human 30 s without a touch"), TEXT("bot hit out of a held cross-check (braced), delivered by a bot"), TEXT("braced hit delivered by the human"),
			TEXT("bot circling: net turn of its travel > 720 deg in 180 f, moving > 2 m/s, no touch"), TEXT("bot shot from beyond 30 m, released in the attacking half") };
		return D >= 0 && D < DetCount ? N[D] : TEXT("?");
	}

	struct FEp { int32 Seed = 0; int64 Frame = 0; int32 Who = -1, Len = 0; FString Cell; double Extra = 0; };

	struct FWatch
	{
		FJamSimAdapter* Sim = nullptr;
		int32 Seed = 0;
		FString Cell;
		int64 LastFrame = -1;
		int32 Counts[DetCount] = {};
		TArray<FEp> Eps[DetCount];
		// runs
		int32 BoardRun[MaxSk] = {}, NetRun[MaxSk] = {}, IdleRun[MaxSk] = {}, StallRun[MaxSk] = {}, OwnRun[MaxSk] = {};
		int32 PairRun[MaxSk][MaxSk] = {}, DownRun[MaxSk][MaxSk] = {}, PushRun[MaxSk][MaxSk] = {};
		double YawRing[MaxSk][180] = {};
		double YawSum[MaxSk] = {};
		double PrevYaw[MaxSk] = {};
		double HeadRing[MaxSk][180] = {}; double HeadSum[MaxSk] = {}; double PrevHead[MaxSk] = {}; bool bHeadArmed[MaxSk] = {};
		int64 DumpFrom = -1, DumpTo = -1; int32 DumpEvery = 5;
		const FJamBrain* Brain = nullptr;
		int64 LastTouch[MaxSk] = {};
		bool bCircleArmed[MaxSk] = {};
		int32 RingAt = 0;
		int32 LooseRun = 0, SlotRun[2] = {};
		int64 LastShotF[MaxSk] = {}; double LastShotD[MaxSk] = {};
		int64 HumanLastTouch = 0; bool bNoTouchCounted = false;
		bool bInit = false;
		void Close(int32 D, int32 Len, int32 Who, double Extra = 0)
		{
			++Counts[D];
			FEp E; E.Seed = Seed; E.Frame = LastFrame - Len; E.Who = Who; E.Len = Len; E.Cell = Cell; E.Extra = Extra;
			Eps[D].Add(E);
		}
		// a run counter: returns true the frame the run closes at or past Min
		void Run(int32& R, bool bOn, int32 Min, int32 D, int32 Who, double Extra = 0)
		{
			if (bOn) { ++R; return; }
			if (R > Min) Close(D, R, Who, Extra);
			R = 0;
		}
	};

	void Trace(void* Ctx, const FJamAIWorld&, const FJamAIInput*, const FJamBrain& Br, int64_t, bool)
	{
		FWatch& T = *static_cast<FWatch*>(Ctx);
		T.Brain = &Br;
		const UJamSim* Sim = T.Sim->GetSim();
		if (!Sim || Sim->GetFrame() == T.LastFrame) return;
		T.LastFrame = Sim->GetFrame();
		const int64 Now = T.LastFrame;
		if (Now >= T.DumpFrom && Now <= T.DumpTo && (Now - T.DumpFrom) % FMath::Max(1, T.DumpEvery) == 0)
		{
			FString L = FString::Printf(TEXT("WDUMP %s s%d f%lld ph%d c%d puck(%.1f,%.1f v%.1f,%.1f lt%d) |"), *T.Cell, T.Seed, static_cast<long long>(Now), static_cast<int32>(Sim->GetPhase()), Sim->CarrierIndex(),
				Sim->GetPuck().Pos.X, Sim->GetPuck().Pos.Y, Sim->GetPuck().Vel.X, Sim->GetPuck().Vel.Y, Sim->GetPuck().LastTouch);
			for (const FJamSkaterState& Q : Sim->GetSkaters())
				L += FString::Printf(TEXT(" %d%c%d r%dj%d (%.1f,%.1f v%.1f,%.1f y%.0f)%s%s%s"), Q.Index, Q.bHuman ? 'H' : 'b', Q.Team, static_cast<int32>(Br.LastRole(Q.Index)), static_cast<int32>(Br.LastJob(Q.Index)),
					Q.Pos.X, Q.Pos.Y, Q.Vel.X, Q.Vel.Y, FMath::RadiansToDegrees(Q.Yaw), Q.IsDown() ? TEXT(" DOWN") : TEXT(""), Q.IsStumbling() ? TEXT(" stum") : TEXT(""), Q.BoardFrames > 0 ? TEXT(" brd") : TEXT(""));
			UE_LOG(LogTemp, Display, TEXT("%s"), *L);
		}
		const TArray<FJamSkaterState>& Sk = Sim->GetSkaters();
		const int32 N = FMath::Min(Sk.Num(), MaxSk);
		const FJamPuckState& Puck = Sim->GetPuck();
		const FJamRinkConfig& R = Sim->GetConfig().Rink;
		const double GL = R.GoalLineX(), HalfW = R.GoalWidthM * 0.5;
		bool bFace = Sim->IsDrawOpen();
		for (int32 i = 0; i < N; ++i) if (Sk[i].bAtFaceoff) bFace = true;
		const bool bPlay = Sim->GetPhase() == EJamSimPhase::Playing && !bFace;
		const int32 Ci = Sim->CarrierIndex();
		if (!T.bInit) { for (int32 i = 0; i < N; ++i) { T.PrevYaw[i] = Sk[i].Yaw; T.LastTouch[i] = Now; } T.HumanLastTouch = Now; T.bInit = true; }
		// goals (from beyond 30 m)
		for (const FJamSimEvent& E : Sim->GetFrameEvents())
		{
			if (E.Name == JamEvents::Goal && Sk.IsValidIndex(E.Who) && E.Who < MaxSk && !Sk[E.Who].bHuman && Now - T.LastShotF[E.Who] <= 240 && T.LastShotD[E.Who] > 30.0)
				T.Close(LongGoal, 0, E.Who, T.LastShotD[E.Who]);
		}
		for (int32 i = 0; i < N; ++i) if (Sk[i].bTouchingPuck || (Puck.LastTouch == i && Ci == i)) T.LastTouch[i] = Now;
		int32 Me = -1; for (int32 i = 0; i < N; ++i) if (Sk[i].bHuman) Me = i;
		if (Me >= 0 && (Sk[Me].bTouchingPuck || Ci == Me)) { T.HumanLastTouch = Now; T.bNoTouchCounted = false; }
		if (!bPlay)
		{
			// a whistle or a faceoff ends every run without counting it (play stopped)
			FMemory::Memzero(T.BoardRun); FMemory::Memzero(T.NetRun); FMemory::Memzero(T.IdleRun); FMemory::Memzero(T.StallRun); FMemory::Memzero(T.OwnRun);
			FMemory::Memzero(T.PairRun); FMemory::Memzero(T.DownRun); FMemory::Memzero(T.PushRun);
			T.LooseRun = 0; T.SlotRun[0] = T.SlotRun[1] = 0;
			for (int32 i = 0; i < N; ++i) { T.PrevYaw[i] = Sk[i].Yaw; T.YawSum[i] = 0; for (double& Y : T.YawRing[i]) Y = 0; T.HeadSum[i] = 0; for (double& Y : T.HeadRing[i]) Y = 0; T.PrevHead[i] = FMath::Atan2(Sk[i].Vel.Y, Sk[i].Vel.X); }
			T.HumanLastTouch = Now;
			return;
		}
		// the human 30 s without a touch
		if (Me >= 0 && !T.bNoTouchCounted && Now - T.HumanLastTouch >= 1800) { T.bNoTouchCounted = true; T.Close(HumanNoTouch30, 1800, Me); }
		// circling ring
		T.RingAt = (T.RingAt + 1) % 180;
		for (int32 i = 0; i < N; ++i)
		{
			const FJamSkaterState& S = Sk[i];
			double D = FMath::Abs(FMath::FindDeltaAngleRadians(T.PrevYaw[i], S.Yaw));
			T.PrevYaw[i] = S.Yaw;
			if (!S.CanAct() || S.IsSpinning()) D = 0;
			T.YawSum[i] += D - T.YawRing[i][T.RingAt];
			T.YawRing[i][T.RingAt] = D;
			{
				const double Hd = FMath::Atan2(S.Vel.Y, S.Vel.X);
				double Dh = FMath::FindDeltaAngleRadians(T.PrevHead[i], Hd);
				T.PrevHead[i] = Hd;
				if (!S.CanAct() || S.Vel.Size() < 2.0) Dh = 0;
				T.HeadSum[i] += Dh - T.HeadRing[i][T.RingAt];
				T.HeadRing[i][T.RingAt] = Dh;
				if (!S.bHuman && FMath::Abs(T.HeadSum[i]) > 4.0 * PI && Now - T.LastTouch[i] > 180 && !T.bHeadArmed[i]) { T.bHeadArmed[i] = true; T.Close(CircleNet, 180, i, FMath::RadiansToDegrees(T.HeadSum[i])); }
				else if (FMath::Abs(T.HeadSum[i]) < 2.0 * PI) T.bHeadArmed[i] = false;
			}
			if (S.bHuman) continue;
			if (T.YawSum[i] > 4.0 * PI && Now - T.LastTouch[i] > 180 && !T.bCircleArmed[i]) { T.bCircleArmed[i] = true; T.Close(Circle, 180, i, FMath::RadiansToDegrees(T.YawSum[i])); }
			else if (T.YawSum[i] < 2.0 * PI) T.bCircleArmed[i] = false;
		}
		for (int32 i = 0; i < N; ++i)
		{
			const FJamSkaterState& S = Sk[i];
			const double V = S.Vel.Size();
			const bool bBot = !S.bHuman;
			// boards
			T.Run(T.BoardRun[i], bBot && S.CanAct() && S.BoardFrames > 0 && V < 2.0, 60, BoardPress, i);
			// nets
			bool bNet = false;
			for (int32 Side : { -1, 1 })
			{
				const double X0 = Side > 0 ? GL - 0.8 : -GL - UJamSim::NetDepth - 0.8, X1 = Side > 0 ? GL + UJamSim::NetDepth + 0.8 : -GL + 0.8;
				if (S.Pos.X > X0 && S.Pos.X < X1 && FMath::Abs(S.Pos.Y) < HalfW + 0.8) bNet = true;
			}
			T.Run(T.NetRun[i], bBot && S.CanAct() && bNet && V < 1.0, 60, NetPress, i);
			// idle / carrier stall
			T.Run(T.IdleRun[i], bBot && S.CanAct() && Ci != i && V < 0.3, 180, Idle, i, T.Brain ? static_cast<double>(T.Brain->LastRole(i)) * 10 + static_cast<double>(T.Brain->LastJob(i)) : -1.0);
			T.Run(T.StallRun[i], bBot && Ci == i && V < 1.0, 60, CarrierStall, i);
			// own-zone carry with open ice ahead
			{
				const double Dir = Sim->AttackGoalX(S.Team) > 0 ? 1.0 : -1.0;
				bool bOn = false;
				if (bBot && Ci == i && S.Vel.X * Dir < -2.0 && S.Pos.X * Dir < -R.LengthM * 0.125)
				{
					bOn = true;
					for (int32 j = 0; j < N; ++j)
					{
						if (Sk[j].Team == S.Team || !Sk[j].CanAct()) continue;
						const FVector2D Rel = Sk[j].Pos - S.Pos;
						if (Rel.Size() < 8.0 && Rel.X * Dir > Rel.Size() * 0.7) { bOn = false; break; }
					}
				}
				T.Run(T.OwnRun[i], bOn, 45, OwnZoneCarry, i, T.Brain ? static_cast<double>(T.Brain->LastRole(i)) * 10 + static_cast<double>(T.Brain->LastJob(i)) : -1.0);
			}
			// shots
			if (bBot && S.bShotThisFrame)
			{
				const FVector2D G(Sim->AttackGoalX(S.Team), 0.0);
				const double D = FVector2D::Distance(S.Pos, G);
				T.LastShotF[i] = Now; T.LastShotD[i] = D;
				if (D > 30.0)
				{
					T.Close(LongShot, 0, i, D);
					if (S.Pos.X * G.X > 0.0) T.Close(LongShotAttHalf, 0, i, D);
					for (int32 j = 0; j < N; ++j)
					{
						if (j == i || Sk[j].Team != S.Team || !Sk[j].CanAct() || FVector2D::Distance(Sk[j].Pos, G) > D - 5.0) continue;
						bool bOpen = true;
						for (int32 k = 0; k < N; ++k) if (Sk[k].Team != S.Team && Sk[k].CanAct() && FVector2D::Distance(Sk[k].Pos, Sk[j].Pos) < 3.0) { bOpen = false; break; }
						if (bOpen) { T.Close(LongShotMateOpen, 0, i, D); break; }
					}
				}
			}
			// presses on a man without the puck, far from it
			if (bBot && (S.bCheckThisFrame || S.bLiftThisFrame))
			{
				int32 Tg = -1; double Best = 3.5;
				for (int32 j = 0; j < N; ++j) { if (Sk[j].Team == S.Team) continue; const double D = FVector2D::Distance(Sk[j].Pos, S.Pos); if (D < Best) { Best = D; Tg = j; } }
				if (Tg >= 0 && Ci != Tg && FVector2D::Distance(Sk[Tg].Pos, Puck.Pos) > 15.0) T.Close(OffPuckCheck, 0, i, FVector2D::Distance(Sk[Tg].Pos, Puck.Pos));
			}
			if (S.bCrossBraceHit && Sk.IsValidIndex(S.ContactBy)) T.Close(Sk[S.ContactBy].bHuman ? BraceHitHuman : BraceHitBot, 0, S.ContactBy, i);
			// pairs
			for (int32 j = 0; j < N; ++j)
			{
				if (j == i) continue;
				const FJamSkaterState& O = Sk[j];
				const double D = FVector2D::Distance(S.Pos, O.Pos);
				if (j > i && O.Team == S.Team) T.Run(T.PairRun[i][j], (bBot || !O.bHuman) && S.CanAct() && O.CanAct() && D < 1.5, 90, Clump, i, j);
				const bool bNear = S.CanAct() && O.IsDown() && D < 1.2;
				T.Run(T.DownRun[i][j], bNear, 30, bBot ? DownStandBot : DownStandHuman, i, j);
				const double Closing = D > 0.01 ? FVector2D::DotProduct(S.Vel, (O.Pos - S.Pos) / D) : 0.0;
				T.Run(T.PushRun[i][j], bBot && bNear && Closing > 0.5, 30, DownPushBot, i, j);
			}
		}
		// loose puck nobody goes to
		{
			bool bOn = false;
			if (Ci < 0 && Puck.Vel.Size() < 4.0)
			{
				double Near = 1e9; bool bBotReach = false;
				for (int32 j = 0; j < N; ++j)
				{
					if (!Sk[j].CanAct()) continue;
					const double D = FVector2D::Distance(Sk[j].Pos, Puck.Pos);
					Near = FMath::Min(Near, D);
					if (!Sk[j].bHuman && D < 10.0) bBotReach = true;
				}
				bOn = Near > 6.0 && bBotReach;
			}
			T.Run(T.LooseRun, bOn, 90, LooseIgnored, -1);
		}
		// the slot empty with the puck carried below the circles
		for (int32 Def = 0; Def < 2; ++Def)
		{
			bool bOn = false;
			const double OwnX = -Sim->AttackGoalX(Def);
			if (Ci >= 0 && Sk[Ci].Team != Def && FMath::Abs(Puck.Pos.X - OwnX) < 7.0)
			{
				bool bAnyBot = false, bIn = false;
				for (int32 j = 0; j < N; ++j)
				{
					if (Sk[j].Team != Def) continue;
					if (!Sk[j].bHuman) bAnyBot = true;
					const double Out = (OwnX > 0 ? OwnX - Sk[j].Pos.X : Sk[j].Pos.X - OwnX);
					if (Sk[j].CanAct() && Out > -0.5 && Out < 10.0 && FMath::Abs(Sk[j].Pos.Y) < 4.5) bIn = true;
				}
				bOn = bAnyBot && !bIn;
			}
			T.Run(T.SlotRun[Def], bOn, 60, EmptySlot, Def);
		}
	}

	struct FOpt { TArray<FString> Levels, Carts; int32 Seeds = 6, From = 1; FString Tune, Player = TEXT("regular"); int64 DumpFrom = -1, DumpTo = -1; int32 DumpEvery = 5; };
	FOpt ReadOpt()
	{
		FOpt O;
		O.Levels = { TEXT("pro"), TEXT("all_star") };
		O.Carts = { TEXT("hockey.regular"), TEXT("hockey.arena.large"), TEXT("modes/hockey.mode.arsenal"), TEXT("modes/hockey.mode.shotgun"), TEXT("modes/hockey.mode.marathon") };
		const FString Env = FPlatformMisc::GetEnvironmentVariable(TEXT("JAM_BRAIN_WATCH"));
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
			else if (K == TEXT("dump")) { TArray<FString> D; V.ParseIntoArray(D, TEXT(":")); if (D.Num() >= 2) { O.DumpFrom = FCString::Atoi64(*D[0]); O.DumpTo = FCString::Atoi64(*D[1]); } if (D.Num() >= 3) O.DumpEvery = FCString::Atoi(*D[2]); }
			else if (K == TEXT("tune")) O.Tune = V.Replace(TEXT("|"), TEXT(";"));   // the tune's own ';' written as '|'
		}
		return O;
	}
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamBarBrainWatch, "Bar.Brain.Watch", JamHockeyBrain8Watch::BarFlags)
bool FJamBarBrainWatch::RunTest(const FString& Parameters)
{
	using namespace JamHockeyBrain8Watch;
	const FOpt O = ReadOpt();
	const EPlaytester Kind = O.Player == TEXT("novice") ? EPlaytester::Novice : (O.Player == TEXT("good") ? EPlaytester::Good : EPlaytester::Regular);
	int32 Total[DetCount] = {};
	TArray<FEp> All[DetCount];
	int32 Matches = 0;
	TMap<FString, TArray<int32>> CellCounts;
	TMap<FString, int32> CellMatches;
	for (const FString& CartName : O.Carts)
	{
		TArray<FString> Errors;
		UJamCartridge* C = UJamCartridge::LoadFromFile(UJamCartridge::ResolveCartridgePath(CartName), Errors);
		for (const FString& E : Errors) AddError(E);
		if (!C) continue;
		C->AddToRoot();
		for (const FString& Lv : O.Levels)
		{
			const FString Cell = FString::Printf(TEXT("%s@%s"), *CartName.Replace(TEXT("modes/hockey.mode."), TEXT("")).Replace(TEXT("hockey.arena."), TEXT("")).Replace(TEXT("hockey."), TEXT("")), *Lv);
			TArray<int32>& CC = CellCounts.FindOrAdd(Cell); CC.SetNumZeroed(DetCount);
			for (int32 Seed = O.From; Seed < O.From + O.Seeds; ++Seed)
			{
				FJamMatchConfig Cfg = ToMatchConfigResolved(*C, *Lv);
				if (!O.Tune.IsEmpty()) { char Err[256] = {}; if (!ApplyDifficultyTune(TCHAR_TO_ANSI(*O.Tune), Cfg.AI, Err, sizeof(Err))) AddError(FString::Printf(TEXT("tune: %hs"), Err)); }
				FJamSimAdapter Sim(*C);
				FWatch* W = new FWatch();
				W->Sim = &Sim; W->Seed = Seed; W->Cell = Cell; W->DumpFrom = O.DumpFrom; W->DumpTo = O.DumpTo; W->DumpEvery = O.DumpEvery;
				const FJamPlaytestStats S = RunPlaytestMatch(Sim, Cfg, static_cast<uint64>(Seed), Kind, 36000, C->Game.Shot.ChargeFramesMax, false, &Trace, W, 1);
				++Matches; ++CellMatches.FindOrAdd(Cell);
				FString Line;
				for (int32 D = 0; D < DetCount; ++D) { Total[D] += W->Counts[D]; CC[D] += W->Counts[D]; All[D].Append(W->Eps[D]); Line += FString::Printf(TEXT(" %d"), W->Counts[D]); }
				AddInfo(FString::Printf(TEXT("WATCH match %s seed %d: %lld frames, %d:%d, hash %016llx | counts%s"), *Cell, Seed, static_cast<long long>(S.Frames), S.GoalsFor, S.GoalsAgainst,
					static_cast<unsigned long long>(S.Hash), *Line));
				delete W;
			}
		}
		C->RemoveFromRoot();
	}
	const double Mn = FMath::Max(1, Matches);
	AddInfo(FString::Printf(TEXT("WATCH table: %d matches, tune \"%s\", player %s"), Matches, *O.Tune, *O.Player));
	for (int32 D = 0; D < DetCount; ++D)
	{
		All[D].Sort([](const FEp& A, const FEp& B) { return A.Len != B.Len ? A.Len > B.Len : A.Extra > B.Extra; });
		FString Worst;
		for (int32 k = 0; k < FMath::Min(3, All[D].Num()); ++k)
			Worst += FString::Printf(TEXT(" [%s seed %d f %lld who %d len %d x %.1f]"), *All[D][k].Cell, All[D][k].Seed, static_cast<long long>(All[D][k].Frame), All[D][k].Who, All[D][k].Len, All[D][k].Extra);
		FString Cells;
		for (const TPair<FString, TArray<int32>>& P : CellCounts) Cells += FString::Printf(TEXT(" %s=%d"), *P.Key, P.Value[D]);
		AddInfo(FString::Printf(TEXT("WATCH row | %02d | %-80s | %5d | %6.2f a match | worst%s | cells%s"), D, DetName(D), Total[D], Total[D] / Mn, *Worst, *Cells));
	}
	return true;
}


// ---- Jam.Bot.Hockey8.*: the rules of evolution 8 in staged scenes (in the gate), and their neutral values ----
namespace JamHockeyBrain8TestsLocal
{
	constexpr EAutomationTestFlags Flags = EAutomationTestFlags::EditorContext | EAutomationTestFlags::CommandletContext | EAutomationTestFlags::EngineFilter;
	using namespace JamAI;

	// 5 v 5 on 90 x 45, no human: team 0 (defends -x, attacks +x) skaters 0-4, team 1 (attacks -x) skaters 5-9, parked far from the scene.
	FJamAIWorld Five()
	{
		FJamAIWorld W;
		W.HalfLength = 45.0; W.HalfWidth = 22.5; W.GoalX = 41.0; W.NumSkaters = 10; W.PlayerIndex = -1; W.Frame = 1000;
		const ERole Roles[5] = { ERole::Chaser, ERole::Support, ERole::Support, ERole::Back, ERole::Back };
		for (int i = 0; i < 10; ++i)
		{
			FJamAISkater& S = W.Skaters[i];
			S.Team = i < 5 ? 0 : 1;
			S.Role = Roles[i % 5];
			S.Facing = FVec2(S.Team == 0 ? 1.0 : -1.0, 0.0);
			S.Pos = FVec2(S.Team == 0 ? -30.0 : 38.0, -12.0 + 6.0 * (i % 5));
			S.Spawn = S.Pos;
		}
		return W;
	}
	// The pro sense on both sides, every rule of evolutions 3 to 8 at its neutral value (a test switches one on).
	void Start(FJamBrain& B)
	{
		B.Reset();
		B.Params.Mate.Hk = ProHockeySense();
		B.Params.Opp.Hk = ProHockeySense();
		for (FJamHockeySense* H : { &B.Params.Mate.Hk, &B.Params.Opp.Hk }) { H->ShapeShare = 1.0; H->LateFrames = 0; }
		SetEvolution3(B.Params.Mate.Hk, false, true);
		SetEvolution3(B.Params.Opp.Hk, false, false);
		SetEvolution4(B.Params.Mate.Hk, false, true);
		SetEvolution4(B.Params.Opp.Hk, false, false);
		for (FJamHockeySense* H : { &B.Params.Mate.Hk, &B.Params.Opp.Hk }) { SetEvolution5(*H, false); SetEvolution6(*H, false); SetEvolution7(*H, false); SetEvolution8(*H, false); }
		B.Params.InterceptSpeed = 11.0;
	}
}

// A bot at a downed body: team 0's skater 0 lies at the centre with the puck beside him; team 1's chaser stands 1 m from him on the puck's far side.
// Off it stays at him (it plays the puck through his body); with hk_downed_leave_frames it leaves him once the run is that long, and goes back to its
// own move once 2 m clear.
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamHockey8Downed, "Jam.Bot.Hockey8.DownedLeave", JamHockeyBrain8TestsLocal::Flags)
bool FJamHockey8Downed::RunTest(const FString& Parameters)
{
	using namespace JamHockeyBrain8TestsLocal;
	auto Scene = [](int LeaveFrames, int Frames, FVec2& OutMove)
	{
		FJamAIWorld W = Five();
		W.Skaters[0].Pos = FVec2(0.0, 0.0); W.Skaters[0].bDown = true; W.Skaters[0].Vel = FVec2(0.0, 0.0);
		W.PuckPos = FVec2(-0.6, 0.0); W.PuckVel = FVec2(0.0, 0.0); W.PuckLastTouch = 0; W.Carrier = W.Holder = -1;
		W.Skaters[5].Pos = FVec2(1.0, 0.0); W.Skaters[5].Facing = FVec2(-1.0, 0.0);
		FJamBrain B;
		Start(B);
		B.Params.Opp.Hk.DownedLeaveFrames = LeaveFrames;
		FJamAIInput In[kMaxSkaters];
		for (int f = 0; f < Frames; ++f) { W.Frame = 1000 + f; B.Think(W, In); }
		OutMove = In[5].Move;
	};
	FVec2 Off, On, Early;
	Scene(0, 30, Off); Scene(15, 30, On); Scene(15, 10, Early);
	AddInfo(FString::Printf(TEXT("the chaser 1 m from a downed skater, the puck beside him: its move after 30 frames (%.3f, %.3f) off, (%.3f, %.3f) with leave 15; after 10 frames with leave 15 (%.3f, %.3f)"),
		Off.X, Off.Y, On.X, On.Y, Early.X, Early.Y));
	TestTrue(TEXT("off: it stays at the body (no move out from him)"), Off.X <= 0.2);
	TestTrue(TEXT("on: after the run it goes out from his body"), On.X > 0.3);
	TestTrue(TEXT("on, before the run is 15 frames long: its own move, as off"), Early.X <= 0.2);
	// the function itself: 2.5 m from the body it gives the move back
	{
		FJamAIWorld W = Five();
		W.Skaters[0].Pos = FVec2(0.0, 0.0); W.Skaters[0].bDown = true;
		W.Skaters[5].Pos = FVec2(2.5, 0.0);
		FJamBrain B; Start(B); B.Params.Opp.Hk.DownedLeaveFrames = 1;
		const FVec2 M = B.LeaveDowned(W, 5, FVec2(-1.0, 0.0));
		TestTrue(TEXT("2.5 m from the body: the move is its own"), M.X == -1.0 && M.Y == 0.0);
	}
	return true;
}

// A long shot with a mate open nearer: team 1's skater 5 carries 35 m from the net it attacks (-41), lined up, in its skill's reach (60 m); its mate 6
// stands open 14 m from that net, and the sim's pass would go to him. Off it shoots (or charges the shot); with hk_long_pass_m 30 it passes.
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamHockey8LongPass, "Jam.Bot.Hockey8.LongPass", JamHockeyBrain8TestsLocal::Flags)
bool FJamHockey8LongPass::RunTest(const FString& Parameters)
{
	using namespace JamHockeyBrain8TestsLocal;
	auto Scene = [](double LongM, double MateX, FJamAIInput& Out, int BestPass = 6)
	{
		FJamAIWorld W = Five();
		for (int i = 0; i < 5; ++i) { W.Skaters[i].Pos = FVec2(20.0, -12.0 + 6.0 * i); }   // team 0 behind the play
		W.Skaters[5].Pos = FVec2(-5.0, 0.0); W.Skaters[5].Vel = FVec2(-4.0, 0.0); W.Skaters[5].Facing = FVec2(-1.0, 0.0); W.Skaters[5].bCanShoot = true;
		W.PuckPos = FVec2(-6.0, 0.0); W.PuckVel = FVec2(-4.0, 0.0);
		W.Carrier = W.Holder = W.PuckLastTouch = 5;
		W.Skaters[6].Pos = FVec2(MateX, 6.0);
		W.CarrierBestPass = BestPass;
		FJamBrain B;
		Start(B);
		B.Params.Opp.ShootExtraM = 60.0;
		B.Params.Opp.Hk.bCarryOrPass = false;   // the shot decision alone
		B.Params.Opp.Hk.LongPassM = LongM;
		FJamAIInput In[kMaxSkaters];
		B.Think(W, In);
		Out = In[5];
	};
	FJamAIInput Off, On, Far, NoLane;
	Scene(0.0, -27.0, Off); Scene(30.0, -27.0, On); Scene(30.0, -5.0, Far); Scene(30.0, -27.0, NoLane, -1);
	AddInfo(FString::Printf(TEXT("the carrier 35 m out: off shoot %d held %d pass %d; with long pass 30: shoot %d held %d pass %d; the mate level with him: shoot %d held %d pass %d"),
		Off.bShoot ? 1 : 0, Off.bShootHeld ? 1 : 0, Off.bPass ? 1 : 0, On.bShoot ? 1 : 0, On.bShootHeld ? 1 : 0, On.bPass ? 1 : 0, Far.bShoot ? 1 : 0, Far.bShootHeld ? 1 : 0, Far.bPass ? 1 : 0));
	TestTrue(TEXT("off: it shoots from 35 m"), (Off.bShoot || Off.bShootHeld) && !Off.bPass);
	TestTrue(TEXT("on: it passes to the open mate nearer the net"), On.bPass && !On.bShoot && !On.bShootHeld);
	TestTrue(TEXT("on, the mate no nearer: it shoots as before"), (Far.bShoot || Far.bShootHeld) && !Far.bPass);
	TestTrue(TEXT("on, the mate open nearer but the sim's pass has no lane to him: no shot, no pass (it carries on)"), !NoLane.bShoot && !NoLane.bShootHeld && !NoLane.bPass);
	return true;
}

// The carrier in its own zone, skating back towards its own net with open ice ahead, turns up the ice; with an opponent 5 m ahead of it, it does not.
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamHockey8OwnZone, "Jam.Bot.Hockey8.OwnZoneTurn", JamHockeyBrain8TestsLocal::Flags)
bool FJamHockey8OwnZone::RunTest(const FString& Parameters)
{
	using namespace JamHockeyBrain8TestsLocal;
	FJamAIWorld W = Five();
	W.Skaters[5].Pos = FVec2(25.0, 4.0); W.Carrier = W.Holder = W.PuckLastTouch = 5; W.PuckPos = FVec2(25.8, 4.0);   // team 1 defends +x
	FJamBrain B; Start(B); B.Params.Opp.Hk.bOwnZoneTurn = true;
	const FVec2 Back(0.9, 0.3);
	const FVec2 M = B.OwnZoneTurn(W, 5, Back);
	AddInfo(FString::Printf(TEXT("carrier at (25, 4) in its own zone moving (0.9, 0.3) towards its net: turned to (%.3f, %.3f)"), M.X, M.Y));
	TestTrue(TEXT("open ice ahead: the move turns up the ice (towards -x), its length kept"), M.X < -0.5 && FMath::IsNearlyEqual(M.Length(), Back.Length(), 1e-9));
	W.Skaters[0].Pos = FVec2(20.0, 4.0);
	const FVec2 M2 = B.OwnZoneTurn(W, 5, Back);
	TestTrue(TEXT("an opponent 5 m up the ice: the move is its own"), M2.X == Back.X && M2.Y == Back.Y);
	W.Skaters[0].Pos = FVec2(-30.0, 4.0);
	W.Skaters[5].Pos = FVec2(5.0, 4.0); W.PuckPos = FVec2(5.8, 4.0);
	const FVec2 M3 = B.OwnZoneTurn(W, 5, Back);
	TestTrue(TEXT("in the neutral zone: the move is its own"), M3.X == Back.X && M3.Y == Back.Y);
	return true;
}

// Two mates in one spot: skaters 6 and 7 of team 1 stand 1 m apart; the higher index gives way once the run is ClumpFrames long, until 3 m apart.
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamHockey8Clump, "Jam.Bot.Hockey8.Clump", JamHockeyBrain8TestsLocal::Flags)
bool FJamHockey8Clump::RunTest(const FString& Parameters)
{
	using namespace JamHockeyBrain8TestsLocal;
	FJamAIWorld W = Five();
	W.Skaters[6].Pos = FVec2(10.0, 0.0); W.Skaters[7].Pos = FVec2(10.0, 1.0);
	FJamBrain B; Start(B); B.Params.Opp.Hk.ClumpFrames = 45;
	const FVec2 Into(0.0, -0.5);
	FVec2 M7, M6, M7Early;
	for (int f = 0; f < 50; ++f) { W.Frame = 2000 + f; M7 = B.SplitClump(W, 7, Into); M6 = B.SplitClump(W, 6, Into); if (f == 30) { M7Early = M7; } }
	AddInfo(FString::Printf(TEXT("two mates 1 m apart, both moving (0, -0.5): after 50 frames skater 7 (%.3f, %.3f), skater 6 (%.3f, %.3f); skater 7 after 31 frames (%.3f, %.3f)"), M7.X, M7.Y, M6.X, M6.Y, M7Early.X, M7Early.Y));
	TestTrue(TEXT("the higher index gives way: its move points away from its mate"), M7.Y > 0.2);
	TestTrue(TEXT("the lower index keeps its line"), M6.X == Into.X && M6.Y == Into.Y);
	TestTrue(TEXT("before the run is 45 frames long: its own move"), M7Early.X == Into.X && M7Early.Y == Into.Y);
	return true;
}

// The neutral values: every level ships evolution 8 as its ship flags say (all off), brain8=0 switches every rule off, brain8=1 puts every rule on, the
// one-rule keys set what they name; the same match twice is the same match and, as shipped, the match is brain8=0's; brain8=1 plays.
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamHockey8Neutral, "Jam.Bot.Hockey8.Neutral", JamHockeyBrain8TestsLocal::Flags)
bool FJamHockey8Neutral::RunTest(const FString& Parameters)
{
	using namespace JamHockeyBrain8TestsLocal;
	auto Off8 = [](const FJamHockeySense& H) { return H.DownedLeaveFrames == 0 && H.LongPassM == 0.0 && !H.bOwnZoneTurn && H.ClumpFrames == 0; };
	auto Shipped = [](const FJamHockeySense& H) {
		return H.DownedLeaveFrames == (kEvo8ShipDownedLeave ? kEvo8DownedLeaveFrames : 0) && H.AvoidDownedM == (kEvo8ShipDownedLeave ? kEvo8AvoidDownedM : kEvo5AvoidDownedM) && H.LongPassM == (kEvo8ShipLongPass ? kEvo8LongPassM : 0.0)
			&& H.bOwnZoneTurn == (kEvo8ShipOwnZoneTurn && kEvo8OwnZoneTurn) && H.ClumpFrames == (kEvo8ShipClump ? kEvo8ClumpFrames : 0); };
	for (EDifficulty Lv : { EDifficulty::Rookie, EDifficulty::Pro, EDifficulty::AllStar })
	{
		FJamAIParams A; ApplyDifficultyProfile(GetDifficultyProfile(Lv), A);
		TestTrue(*FString::Printf(TEXT("%hs: the profile plays evolution 8 as the ship flags say, both sides"), DifficultyName(Lv)), Shipped(A.Opp.Hk) && Shipped(A.Mate.Hk));
		FJamAIParams P = A; char Err[200] = {};
		TestTrue(TEXT("item 4's two rules ship off at every level (not part of brain8)"), !A.Opp.Hk.bTrueLead && !A.Mate.Hk.bTrueLead && !A.Opp.Hk.bMateTrueScale && !A.Mate.Hk.bMateTrueScale);
		TestTrue(TEXT("brain8=0 applies"), ApplyDifficultyTune("brain8=0", P, Err, sizeof(Err)));
		TestTrue(TEXT("brain8=0: every rule off, both sides"), Off8(P.Opp.Hk) && Off8(P.Mate.Hk));
		FJamAIParams Q = A;
		TestTrue(TEXT("brain8=1 applies"), ApplyDifficultyTune("brain8=1", Q, Err, sizeof(Err)));
		TestTrue(TEXT("brain8=0: evolution 5's steering round a downed man back at its own value"), P.Opp.Hk.AvoidDownedM == kEvo5AvoidDownedM && P.Mate.Hk.AvoidDownedOut == kEvo5AvoidDownedOut);
		TestTrue(TEXT("brain8=1: every rule at its measured value"), Q.Opp.Hk.DownedLeaveFrames == kEvo8DownedLeaveFrames && Q.Opp.Hk.LongPassM == kEvo8LongPassM
			&& Q.Mate.Hk.AvoidDownedM == kEvo8AvoidDownedM && Q.Opp.Hk.AvoidDownedOut == kEvo8AvoidDownedOut
			&& Q.Opp.Hk.bOwnZoneTurn == kEvo8OwnZoneTurn && Q.Mate.Hk.ClumpFrames == kEvo8ClumpFrames);
	}
	{
		FJamAIParams Q; ApplyDifficultyProfile(GetDifficultyProfile(EDifficulty::Pro), Q); char Err[200] = {};
		TestTrue(TEXT("the one-rule keys apply"), ApplyDifficultyTune("brain8=0;opp.hk_downed_leave_frames=20;mate.hk_long_pass_m=25;opp.hk_own_zone_turn=1;mate.hk_clump_frames=30", Q, Err, sizeof(Err)));
		TestTrue(TEXT("... and set what they name"), Q.Opp.Hk.DownedLeaveFrames == 20 && Q.Mate.Hk.DownedLeaveFrames == 0 && Q.Mate.Hk.LongPassM == 25.0 && Q.Opp.Hk.LongPassM == 0.0
			&& Q.Opp.Hk.bOwnZoneTurn && !Q.Mate.Hk.bOwnZoneTurn && Q.Mate.Hk.ClumpFrames == 30 && Q.Opp.Hk.ClumpFrames == 0);
		FJamAIParams R; ApplyDifficultyProfile(GetDifficultyProfile(EDifficulty::Pro), R);
		TestTrue(TEXT("item 4's keys apply"), ApplyDifficultyTune("opp.hk_true_lead=1;mate.hk_mate_true_scale=1", R, Err, sizeof(Err)));
		TestTrue(TEXT("... and set what they name"), R.Opp.Hk.bTrueLead && !R.Mate.Hk.bTrueLead && R.Mate.Hk.bMateTrueScale && !R.Opp.Hk.bMateTrueScale);
	}
	auto Match = [this](const char* Tune) -> FString
	{
		TArray<FString> Errors;
		UJamCartridge* Cart = UJamCartridge::LoadFromFile(UJamCartridge::ResolveCartridgePath(TEXT("hockey.regular")), Errors);
		if (!Cart) { AddError(TEXT("FAIL hockey.regular does not load")); return FString(); }
		FJamMatchConfig C = ToMatchConfigResolved(*Cart, TEXT("pro"));
		if (Tune) { char Err[200] = {}; TestTrue(TEXT("the tune applies"), ApplyDifficultyTune(Tune, C.AI, Err, sizeof(Err))); }
		FJamSimAdapter Sim(*Cart);
		const FJamPlaytestStats St = RunPlaytestMatch(Sim, C, 1, EPlaytester::Regular, 36000, Cart->Game.Shot.ChargeFramesMax, false, nullptr, nullptr, 0);
		Cart->RemoveFromRoot();
		return FString::Printf(TEXT("%016llx (%lld frames, %d:%d)"), static_cast<unsigned long long>(St.Hash), static_cast<long long>(St.Frames), St.GoalsFor, St.GoalsAgainst);
	};
	const FString A1 = Match(nullptr), A2 = Match(nullptr), Off = Match("brain8=0"), On = Match("brain8=1");
	AddInfo(FString::Printf(TEXT("hockey.regular at pro, the regular player, seed 1: as shipped %s; brain8=0 %s; brain8=1 %s"), *A1, *Off, *On));
	TestEqual(TEXT("the same match twice is the same match"), A1, A2);
	if (!kEvo8ShipDownedLeave && !kEvo8ShipLongPass && !kEvo8ShipOwnZoneTurn && !kEvo8ShipClump) { TestEqual(TEXT("as shipped is brain8=0 (every rule ships off)"), A1, Off); }
	if (kEvo8ShipDownedLeave && kEvo8ShipLongPass && kEvo8ShipOwnZoneTurn && kEvo8ShipClump) { TestEqual(TEXT("as shipped is brain8=1 (every rule ships on)"), A1, On); }
	TestNotEqual(TEXT("brain8=1 plays (the rules are alive in a match; brain8=0 is evolution 7)"), On, Off);
	return true;
}

#endif
