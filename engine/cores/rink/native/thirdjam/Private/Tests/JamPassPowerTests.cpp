// Lane A207 (track P1, the night of 14 Nov, docs/experiments/PASS-SHOT.md): the pass and the shot as a player feels them. Measurements, outside the gate.
//   Bar.Pass.Measure   every pass in real matches (the scripted regular player against the brain): its speed at release and after 5 / 10 / 20 / 30 m,
//                      where it falls under a skater's 11 m/s and under the blade's 6 m/s, how close it comes to the man it was meant for (blade and body),
//                      the angle between the release and where that man was when the puck passed him, and who touched it first (the man, another mate,
//                      an opponent, nobody). By class: human -> mate, bot -> human, bot -> bot. And every shot's release speed by its charge.
//   env JAM_PASS_MEASURE = "level=pro;player=regular;seeds=40;from=1;rows=0" (every part optional; level may be a list rookie,pro)
#include "Misc/AutomationTest.h"
#include "JamCartridge.h"
#include "JamSim.h"
#include "JamEventBus.h"
#include "JamBrain.h"
#include "JamSimAdapter.h"
#include "JamPlaytester.h"
#include "DifficultyResolve.h"
#include "UObject/Package.h"

#if WITH_DEV_AUTOMATION_TESTS

namespace JamPassPowerTests
{
	constexpr EAutomationTestFlags Flags = EAutomationTestFlags_ApplicationContextMask | EAutomationTestFlags::ProductFilter;

	// One pass in flight, from the release to its first touch by anybody but the passer (or the whistle, or its death on the ice).
	struct FFlight
	{
		int32 Passer = -1, Recv = -1, Team = 0;
		bool bHumanPasser = false, bSaucer = false;
		int64 Start = 0;
		double V0 = 0, D0 = 0, Path = 0;
		FVector2D From = FVector2D::ZeroVector, Dir = FVector2D::ZeroVector, Last = FVector2D::ZeroVector;
		double VAt[4] = {-1, -1, -1, -1};   // speed after 5 / 10 / 20 / 30 m of path (-1 = never got there)
		double PathUnderSkater = -1, PathUnder6 = -1;
		double MinBlade = 1e9, MinBody = 1e9, VAtMin = 0, AngAtMin = 0, PathAtMin = 0;
		int32 RecvReceivedAtStart = 0;
		bool bBack = false;   // lane A207 (2b): back on the passer's own stick within 10 frames
		double EventV = 0; FVector2D PasserVel0 = FVector2D::ZeroVector; int32 Carrier0 = -1, LastTouch0 = -1;
	};
	struct FRow
	{
		int32 Class = 0;   // 0 human -> mate, 1 bot -> human, 2 bot -> bot
		int32 Out = 0;     // 0 the man (caught: a reception), 1 the man (a touch, not seated), 2 another mate, 3 an opponent, 4 nobody (died / whistle)
		FFlight F;
		double VEnd = 0;
		int32 Frames = 0;
	};
	const TCHAR* ClassName(int32 C) { return C == 0 ? TEXT("human_to_mate") : (C == 1 ? TEXT("bot_to_human") : TEXT("bot_to_bot")); }
	const TCHAR* OutName(int32 O) { static const TCHAR* N[] = {TEXT("caught"), TEXT("touched"), TEXT("other_mate"), TEXT("opponent"), TEXT("nobody")}; return N[FMath::Clamp(O, 0, 4)]; }

	struct FShotRow { bool bHuman = false; float Charge = 0.f; double V = 0; };
	// Lane A207: every shot's fate: the shooter's team (0 = the human's), its distance to the net it attacks, and how it ended: 0 goal, 1 saved (the crease
	// skater's save), 2 touched first by an opponent (a block), 3 touched first by a mate, 4 nothing (wide, the boards, dead) within 180 frames.
	struct FShotFate { int32 Team = 0, TeamId = 0; bool bHuman = false; double DistM = 0; float Charge = 0.f; int32 Out = 4; bool bKeeper = false; };

	struct FTrace
	{
		JamAI::FJamSimAdapter* Sim = nullptr;
		int64 LastFrame = -1;
		bool bOpen = false;
		FFlight F;
		TArray<FRow> Rows;
		TArray<FShotRow> Shots;
		// The puck's integrity: frames it lay outside the boards; substeps... frames in which it moved through a standing body it never touched.
		int32 OutFrames = 0, Through = 0, FastFrames = 0;
		TArray<FString> ThroughRows;
		TArray<FString> BackRows;
		TArray<FShotFate> Fates;
		bool bShotOpen = false;
		int32 ShotBy = -1, ShotScore[2] = {0, 0};
		int64 ShotAt = 0;
		FVector2D LastPuck = FVector2D::ZeroVector;
		int32 LastToucher = -1;
		bool bHaveLast = false;
	};

	int32 ParseRecv(const FName& Kind)
	{
		const FString K = Kind.ToString();
		int32 At = K.Find(TEXT("to_"), ESearchCase::CaseSensitive, ESearchDir::FromEnd);
		return At >= 0 ? FCString::Atoi(*K.Mid(At + 3)) : -1;
	}

	void Close(FTrace& T, int32 Out, double VEnd, int64 Now, const UJamSim& Sim)
	{
		FRow R;
		R.F = T.F;
		const TArray<FJamSkaterState>& Sk = Sim.GetSkaters();
		R.Class = T.F.bHumanPasser ? 0 : ((Sk.IsValidIndex(T.F.Recv) && Sk[T.F.Recv].bHuman) ? 1 : 2);
		R.Out = Out;
		R.VEnd = VEnd;
		R.Frames = static_cast<int32>(Now - T.F.Start);
		T.Rows.Add(R);
		T.bOpen = false;
	}

	void Trace(void* Ctx, const JamAI::FJamAIWorld&, const JamAI::FJamAIInput*, const JamAI::FJamBrain&, int64_t, bool)
	{
		FTrace& T = *static_cast<FTrace*>(Ctx);
		const UJamSim* Sim = T.Sim->GetSim();
		if (!Sim || Sim->GetFrame() == T.LastFrame) return;
		T.LastFrame = Sim->GetFrame();
		const int64 Now = Sim->GetFrame();
		const TArray<FJamSkaterState>& Sk = Sim->GetSkaters();
		const FJamPuckState& P = Sim->GetPuck();
		const double V = P.Vel.Size();
		{
			// Integrity (the doubled shot at 60 Hz with 4 substeps): outside the boards; or through a body: the frame's path passes within 0.3 m of a standing
			// skater's centre (the body radius is 0.4 + the puck's 0.12) under body height while the toucher did not change and it was not that skater's puck.
			FVector2D Nrm;
			if (Sim->BoardDistance(P.Pos, Nrm) > 0.02) ++T.OutFrames;
			if (T.bHaveLast && P.LastTouch == T.LastToucher && P.Z < 0.35 && Sim->GetPhase() == EJamSimPhase::Playing && V > 20.0)
			{
				++T.FastFrames;
				const FVector2D Seg = P.Pos - T.LastPuck;
				const double L2 = Seg.SizeSquared();
				for (const FJamSkaterState& S : Sk)
				{
					if (S.Index == P.LastTouch || S.InBox() || S.IsDown() || L2 < 1e-6) continue;
					const double Tt = FMath::Clamp(FVector2D::DotProduct(S.Pos - T.LastPuck, Seg) / L2, 0.0, 1.0);
					if (FVector2D::Distance(T.LastPuck + Seg * Tt, S.Pos) < 0.3)
					{
						++T.Through;
						T.ThroughRows.Add(FString::Printf(TEXT("f=%lld skater=%d team=%d down=%d stumble=%d pos=(%.2f,%.2f) prevpos=(%.2f,%.2f) vel=(%.1f,%.1f) | puck (%.2f,%.2f)->(%.2f,%.2f) v=%.1f z=%.2f last=%d carrier=%d"),
							static_cast<long long>(Now), S.Index, S.Team, S.IsDown() ? 1 : 0, S.IsStumbling() ? 1 : 0, S.Pos.X, S.Pos.Y, S.PrevPos.X, S.PrevPos.Y, S.Vel.X, S.Vel.Y,
							T.LastPuck.X, T.LastPuck.Y, P.Pos.X, P.Pos.Y, V, P.Z, P.LastTouch, Sim->CarrierIndex()));
						break;
					}
				}
			}
			T.LastPuck = P.Pos; T.LastToucher = P.LastTouch; T.bHaveLast = true;
		}
		// The shot in flight before this frame's events.
		if (T.bShotOpen)
		{
			FShotFate& Fa = T.Fates.Last();
			const int32 S0 = Sim->GetScore(0), S1 = Sim->GetScore(1);
			if (S0 != T.ShotScore[0] || S1 != T.ShotScore[1]) { const int32 Scorer = S0 != T.ShotScore[0] ? 0 : 1; Fa.Out = Scorer == Fa.TeamId ? 0 : 4; T.bShotOpen = false; }
			else if (P.LastTouch != T.ShotBy && Sk.IsValidIndex(P.LastTouch))
			{
				bool bSave = false;
				for (const FJamSimEvent& E : Sim->GetFrameEvents()) if (E.Name == JamEvents::Save && E.Who == P.LastTouch) bSave = true;
				Fa.Out = Sk[P.LastTouch].Team == Fa.TeamId ? 3 : (bSave ? 1 : 2);
				T.bShotOpen = false;
			}
			else if (Now - T.ShotAt > 180 || Sim->GetPhase() != EJamSimPhase::Playing) T.bShotOpen = false;
		}
		// The flight before this frame's events: a touch by somebody else ends it.
		if (T.bOpen)
		{
			if (Sim->GetPhase() != EJamSimPhase::Playing) Close(T, 4, V, Now, *Sim);
			else if (P.LastTouch != T.F.Passer && !Sk[T.F.Passer].bPassThisFrame)
			{
				const int32 Who = P.LastTouch;
				int32 Out = 3;
				if (Who >= 0 && Who == T.F.Recv && Sk.IsValidIndex(Who)) Out = Sk[Who].PassesReceived > T.F.RecvReceivedAtStart ? 0 : 1;
				else if (Sk.IsValidIndex(Who) && Sk[Who].Team == T.F.Team) Out = 2;
				else if (!Sk.IsValidIndex(Who)) Out = 4;
				Close(T, Out, V, Now, *Sim);
			}
			else
			{
				FFlight& F = T.F;
				if (!F.bBack && Now - F.Start <= 10 && Sim->CarrierIndex() == F.Passer && (P.Vel - Sk[F.Passer].Vel).Size() < 4.0)
				{
					F.bBack = true;
					FVector2D Nrm;
					if (T.BackRows.Num() < 12) T.BackRows.Add(FString::Printf(TEXT("after %lld frames: release (event) %.1f m/s, at the frame's end lasttouch %d carrier %d passer v (%.1f,%.1f) | human %d v0 %.1f path %.2f | puck (%.1f,%.1f) v (%.1f,%.1f) | passer (%.1f,%.1f) v (%.1f,%.1f) | boards %.2f m | pass_frames %d recv %d"),
						static_cast<long long>(Now - F.Start), F.EventV, F.LastTouch0, F.Carrier0, F.PasserVel0.X, F.PasserVel0.Y, Sk[F.Passer].bHuman ? 1 : 0, F.V0, F.Path, P.Pos.X, P.Pos.Y, P.Vel.X, P.Vel.Y, Sk[F.Passer].Pos.X, Sk[F.Passer].Pos.Y, Sk[F.Passer].Vel.X, Sk[F.Passer].Vel.Y,
						-Sim->BoardDistance(P.Pos, Nrm), P.PassFrames, F.Recv));
				}
				F.Path += FVector2D::Distance(F.Last, P.Pos);
				F.Last = P.Pos;
				static const double Marks[4] = {5, 10, 20, 30};
				for (int32 k = 0; k < 4; ++k) if (F.VAt[k] < 0 && F.Path >= Marks[k]) F.VAt[k] = V;
				if (F.PathUnderSkater < 0 && V < 11.0) F.PathUnderSkater = F.Path;
				if (F.PathUnder6 < 0 && V < 6.0) F.PathUnder6 = F.Path;
				if (Sk.IsValidIndex(F.Recv))
				{
					const FJamSkaterState& R = Sk[F.Recv];
					const double Db = FVector2D::Distance(P.Pos, R.BladePos);
					F.MinBody = FMath::Min(F.MinBody, FVector2D::Distance(P.Pos, R.Pos));
					if (Db < F.MinBlade)
					{
						F.MinBlade = Db; F.VAtMin = V; F.PathAtMin = F.Path;
						const FVector2D ToR = (R.BladePos - F.From).GetSafeNormal();
						F.AngAtMin = FMath::RadiansToDegrees(FMath::Acos(FMath::Clamp(FVector2D::DotProduct(ToR, F.Dir), -1.0, 1.0)));
					}
				}
				if (V < 0.3 || Now - F.Start > 420) Close(T, 4, V, Now, *Sim);
			}
		}
		// This frame's releases.
		for (const FJamSkaterState& S : Sk)
		{
			if (S.bShotThisFrame)
			{
				FShotRow Sh; Sh.bHuman = S.bHuman; Sh.Charge = S.LastShotCharge; Sh.V = V; T.Shots.Add(Sh);
				const int32 HumanTeam = Sim->GetHumanTeam();
				FShotFate Fa; Fa.Team = S.Team == HumanTeam ? 0 : 1; Fa.TeamId = S.Team; Fa.bHuman = S.bHuman; Fa.Charge = S.LastShotCharge;
				Fa.DistM = FVector2D::Distance(P.Pos, FVector2D(Sim->AttackGoalX(S.Team), 0.0));
				for (const FJamSkaterState& D : Sk)   // a defender standing as the crease man (UJamSim::InCreaseStance's geometry: within 3 m of his own goal centre, able to act)
					if (D.Team != S.Team && D.CanAct() && FVector2D::Distance(D.Pos, FVector2D(Sim->AttackGoalX(S.Team), 0.0)) <= 3.0) Fa.bKeeper = true;
				T.Fates.Add(Fa); T.bShotOpen = true; T.ShotBy = S.Index; T.ShotAt = Now; T.ShotScore[0] = Sim->GetScore(0); T.ShotScore[1] = Sim->GetScore(1);
			}
			bool bPassEvent = false;   // lane A207 (2b): a flight starts on the sim's pass event (a skater who cannot act keeps last frame's one-frame flags)
			for (const FJamSimEvent& E : Sim->GetFrameEvents()) if (E.Name == JamEvents::Pass && E.Who == S.Index) bPassEvent = true;
			if (!S.bPassThisFrame || !bPassEvent) continue;
			if (T.bOpen) Close(T, 4, V, Now, *Sim);
			FFlight F;
			F.Passer = S.Index; F.Team = S.Team; F.bHumanPasser = S.bHuman; F.Start = Now; F.V0 = V; F.From = P.Pos; F.Last = P.Pos; F.Dir = P.Vel.GetSafeNormal();
			F.bSaucer = S.bSaucerThisFrame;
			for (const FJamSimEvent& E : Sim->GetFrameEvents()) if (E.Name == JamEvents::Pass && E.Who == S.Index) { F.Recv = ParseRecv(E.Kind); F.EventV = E.Strength * 30.0; }
			F.PasserVel0 = S.Vel; F.Carrier0 = Sim->CarrierIndex(); F.LastTouch0 = P.LastTouch;
			if (Sk.IsValidIndex(F.Recv)) { F.D0 = FVector2D::Distance(P.Pos, Sk[F.Recv].Pos); F.RecvReceivedAtStart = Sk[F.Recv].PassesReceived; }
			T.F = F;
			T.bOpen = true;
		}
	}

	struct FOpt { FString Levels = TEXT("pro"), Player = TEXT("regular"), Rink = TEXT("hockey.regular"); int32 Seeds = 40, Rows = 0, From = 1; double Shot = -1; bool bPassOff = false; double ReadMps = -1, ReadMax = -1, Fade = -1; };
	FOpt ReadOpt()
	{
		FOpt O;
		TArray<FString> Parts;
		FPlatformMisc::GetEnvironmentVariable(TEXT("JAM_PASS_MEASURE")).ParseIntoArray(Parts, TEXT(";"));
		for (const FString& Part : Parts)
		{
			FString K, V;
			if (!Part.Split(TEXT("="), &K, &V)) continue;
			if (K == TEXT("level")) O.Levels = V; else if (K == TEXT("player")) O.Player = V; else if (K == TEXT("seeds")) O.Seeds = FCString::Atoi(*V);
			else if (K == TEXT("rows")) O.Rows = FCString::Atoi(*V); else if (K == TEXT("from")) O.From = FCString::Atoi(*V); else if (K == TEXT("rink")) O.Rink = V;
			else if (K == TEXT("shot")) O.Shot = FCString::Atod(*V); else if (K == TEXT("pass")) O.bPassOff = V == TEXT("off");
			else if (K == TEXT("fade")) O.Fade = FCString::Atod(*V);
			else if (K == TEXT("read")) { FString A, B; if (V.Split(TEXT(":"), &A, &B)) { O.ReadMps = FCString::Atod(*A); O.ReadMax = FCString::Atod(*B); } else O.ReadMps = FCString::Atod(*V); }
		}
		return O;
	}
	double Median(TArray<double> A) { if (A.Num() == 0) return -1; A.Sort(); return A[A.Num() / 2]; }
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamBarPassMeasure, "Bar.Pass.Measure", JamPassPowerTests::Flags)
bool FJamBarPassMeasure::RunTest(const FString& Parameters)
{
	using namespace JamPassPowerTests;
	const FOpt O = ReadOpt();
	TArray<FString> Errors;
	UJamCartridge* C = UJamCartridge::LoadFromFile(UJamCartridge::ResolveCartridgePath(O.Rink), Errors);
	for (const FString& E : Errors) AddError(E);
	if (!C) return false;
	const JamAI::EPlaytester Kind = O.Player == TEXT("novice") ? JamAI::EPlaytester::Novice : (O.Player == TEXT("good") ? JamAI::EPlaytester::Good : JamAI::EPlaytester::Regular);
	TArray<FString> Levels;
	O.Levels.ParseIntoArray(Levels, TEXT(","));
	for (const FString& Level : Levels)
	{
		TArray<FRow> All;
		TArray<FShotRow> Shots;
		TArray<FShotFate> Fates;
		int32 Wins = 0, OutFrames = 0, Through = 0, FastFrames = 0;
		for (int32 Seed = O.From; Seed < O.From + O.Seeds; ++Seed)
		{
			UJamCartridge* M = DuplicateObject<UJamCartridge>(C, GetTransientPackage());
			if (O.Shot > 0.0) M->Game.Shot.SpeedScale = O.Shot;
			if (O.ReadMps >= 0.0) M->Game.Skater.GoalieReadMps = O.ReadMps;
			if (O.Fade >= 0.0) M->Game.Shot.FadeM = O.Fade;
			if (O.ReadMax >= 0.0) M->Game.Skater.GoalieReadMaxM = O.ReadMax;
			if (O.bPassOff) { M->Game.Pass.PowerFullFrames = 0; M->Game.Pass.AimConeDeg = 0.0; M->Game.Pass.CatchM = 0.0; M->Game.Pass.bClearOwnBody = false; }
			JamAI::FJamSimAdapter Sim(*M);
			FTrace* T = new FTrace();
			T->Sim = &Sim;
			const JamAI::FJamMatchConfig Cfg = JamAI::ToMatchConfigResolved(*M, *Level);
			const JamAI::FJamPlaytestStats S = JamAI::RunPlaytestMatch(Sim, Cfg, static_cast<uint64>(Seed), Kind, 36000, M->Game.Shot.ChargeFramesMax, false, &Trace, T, 1);
			if (S.GoalsFor > S.GoalsAgainst) ++Wins;
			All.Append(T->Rows);
			Shots.Append(T->Shots);
			Fates.Append(T->Fates);
			OutFrames += T->OutFrames; Through += T->Through; FastFrames += T->FastFrames;
			for (const FString& Row : T->BackRows) AddInfo(FString::Printf(TEXT("PASSBACK level=%s seed=%d %s"), *Level, Seed, *Row));
			for (const FString& Row : T->ThroughRows) AddInfo(FString::Printf(TEXT("PASSTHROUGH level=%s seed=%d %s"), *Level, Seed, *Row));
			delete T;
		}
		int32 Shown = 0;
		for (const FRow& R : All)
		{
			if (Shown++ >= O.Rows) break;
			AddInfo(FString::Printf(TEXT("PASSROW level=%s class=%s out=%s v0=%.1f d0=%.1f v5=%.1f v10=%.1f v20=%.1f v30=%.1f under11=%.1f under6=%.1f minblade=%.2f minbody=%.2f vmin=%.1f pathmin=%.1f ang=%.1f path=%.1f vend=%.1f frames=%d saucer=%d"),
				*Level, ClassName(R.Class), OutName(R.Out), R.F.V0, R.F.D0, R.F.VAt[0], R.F.VAt[1], R.F.VAt[2], R.F.VAt[3], R.F.PathUnderSkater, R.F.PathUnder6, R.F.MinBlade, R.F.MinBody,
				R.F.VAtMin, R.F.PathAtMin, R.F.AngAtMin, R.F.Path, R.VEnd, R.Frames, R.F.bSaucer ? 1 : 0));
		}
		for (int32 Cl = 0; Cl < 3; ++Cl)
		{
			int32 Back = 0, N = 0, NoMan = 0, Out[5] = {0, 0, 0, 0, 0}, Near = 0, DiedBefore = 0, Far = 0, FarCaught = 0, Ang20 = 0, Ang20Caught = 0;
			TArray<double> V0, D0, MinB, Ang, U6, VMin;
			for (const FRow& R : All)
			{
				if (R.Class != Cl) continue;
				if (R.F.Recv < 0) { ++NoMan; continue; }   // a pass along the stick with no mate in the cone: counted apart
				++N; ++Out[R.Out]; Back += R.F.bBack ? 1 : 0;
				V0.Add(R.F.V0); D0.Add(R.F.D0); MinB.Add(R.F.MinBlade); Ang.Add(R.F.AngAtMin); VMin.Add(R.F.VAtMin);
				if (R.F.PathUnder6 >= 0) U6.Add(R.F.PathUnder6);
				if (R.F.MinBlade < 0.6) ++Near;
				if (R.F.MinBlade < 1.5 && R.F.VAtMin < 6.0) ++DiedBefore;
				if (R.F.D0 >= 15.0) { ++Far; if (R.Out <= 1) ++FarCaught; }
				if (R.F.AngAtMin <= 20.0) { ++Ang20; if (R.Out <= 1) ++Ang20Caught; }
			}
			const double Nn = FMath::Max(1, N);
			AddInfo(FString::Printf(TEXT("PASSSUM level=%s class=%s n=%d no_man=%d per_match=%.1f back_on_own_stick_10f=%.1f%% | caught=%.1f%% touched=%.1f%% other_mate=%.1f%% opponent=%.1f%% nobody=%.1f%% | median v0=%.1f d0=%.1f minblade=%.2f ang=%.1f v_at_min=%.1f under6_at=%.1f | blade_within_0.6=%.1f%% slow_at_him(<6)=%.1f%% | d0>=15m: %d, reached %.1f%% | ang<=20: %d, reached %.1f%%"),
				*Level, ClassName(Cl), N, NoMan, N / static_cast<double>(FMath::Max(1, O.Seeds)), 100.0 * Back / FMath::Max(1, N), 100.0 * Out[0] / Nn, 100.0 * Out[1] / Nn, 100.0 * Out[2] / Nn, 100.0 * Out[3] / Nn, 100.0 * Out[4] / Nn,
				Median(V0), Median(D0), Median(MinB), Median(Ang), Median(VMin), Median(U6), 100.0 * Near / Nn, 100.0 * DiedBefore / Nn, Far, 100.0 * FarCaught / FMath::Max(1, Far), Ang20, 100.0 * Ang20Caught / FMath::Max(1, Ang20)));
		}
		for (int32 H = 0; H < 2; ++H)
		{
			TArray<double> Tap, Half, Full;
			for (const FShotRow& Sh : Shots)
			{
				if (Sh.bHuman != (H == 1)) continue;
				if (Sh.Charge <= 0.f) Tap.Add(Sh.V); else if (Sh.Charge < 0.99f) Half.Add(Sh.V); else Full.Add(Sh.V);
			}
			AddInfo(FString::Printf(TEXT("SHOTSUM level=%s who=%s tap n=%d median %.1f | part n=%d median %.1f | full n=%d median %.1f"), *Level, H ? TEXT("human") : TEXT("bots"),
				Tap.Num(), Median(Tap), Half.Num(), Median(Half), Full.Num(), Median(Full)));
		}
		// The shots' fates by the shooter's team (0 the human's side incl. the human, 1 the bots against him) and distance band.
		{
			static const double Bands[4] = {0, 12, 25, 35};
			static const TCHAR* BandName[4] = {TEXT("0-12"), TEXT("12-25"), TEXT("25-35"), TEXT("35+")};
			for (int32 Tm = 0; Tm < 2; ++Tm)
			{
				FString Row;
				for (int32 b = 0; b < 4; ++b)
				{
					int32 N = 0, Cnt[5] = {0, 0, 0, 0, 0}, Kept = 0, KeptGoal = 0;
					for (const FShotFate& Fa : Fates)
					{
						if (Fa.Team != Tm || Fa.DistM < Bands[b] || (b < 3 && Fa.DistM >= Bands[b + 1])) continue;
						++N; ++Cnt[FMath::Clamp(Fa.Out, 0, 4)];
						if (Fa.bKeeper) { ++Kept; if (Fa.Out == 0) ++KeptGoal; }
					}
					const double Nn = FMath::Max(1, N);
					Row += FString::Printf(TEXT(" | %s m: n=%d goal %.1f%% saved %.1f%% blocked %.1f%% mate %.1f%% nothing %.1f%% keeper_in_crease %.0f%% (goal %.0f%% with him, %.0f%% without)"), BandName[b], N, 100.0 * Cnt[0] / Nn, 100.0 * Cnt[1] / Nn, 100.0 * Cnt[2] / Nn, 100.0 * Cnt[3] / Nn, 100.0 * Cnt[4] / Nn,
						100.0 * Kept / Nn, 100.0 * KeptGoal / FMath::Max(1, Kept), 100.0 * (Cnt[0] - KeptGoal) / FMath::Max(1, N - Kept));
				}
				AddInfo(FString::Printf(TEXT("SHOTFATE level=%s side=%s%s"), *Level, Tm == 0 ? TEXT("human_team") : TEXT("bots_against"), *Row));
			}
		}
		AddInfo(FString::Printf(TEXT("PASSMATCHES level=%s seeds=%d wins=%d | puck outside the boards %d frames, through a standing body %d of %d frames over 20 m/s (bar 0, 0)"), *Level, O.Seeds, Wins, OutFrames, Through, FastFrames));
	}
	return true;
}

#endif
