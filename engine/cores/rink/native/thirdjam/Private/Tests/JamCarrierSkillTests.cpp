// Lane A102 (track F2, carrier skill, evolution 1): the stop-and-go is the carrier's signature (docs/VISION.md law 3; docs/experiments/MOVEMENT-2.md).
// Jam.Core.Movement.StopAndGo (the scripted human carries at a standing pro defender: a clean stop, cut and go against a straight charge, 200 seeds each),
// Jam.Core.Movement.BodyShield (puck protection with the body between, game.stick.body_shield, and its neutral value),
// Bar.Movement.StopAndGoSweep (outside the gate's Jam filter: the same scene over the movement keys, one at a time). Headless, on UJamSim with the real brain.
//   UnrealEditor-Cmd.exe Game/ThirdJam.uproject -ExecCmds="Automation RunTests Jam.Core.Movement; Quit" -unattended -nullrhi -nosplash -log
#include "Misc/AutomationTest.h"
#include "JamCartridge.h"
#include "JamSim.h"
#include "JamEventBus.h"
#include "JamBrain.h"
#include "JamSimAdapter.h"
#include "JamRandom.h"
#include "JamCarryDrill.h"
#include "JamPlaytester.h"
#include "DifficultyResolve.h"
#include "Misc/FileHelper.h"
#include "Misc/Paths.h"
#include "UObject/Package.h"

#if WITH_DEV_AUTOMATION_TESTS

namespace JamCarrierSkillTests
{
	constexpr EAutomationTestFlags Flags = EAutomationTestFlags_ApplicationContextMask | EAutomationTestFlags::ProductFilter;

	UJamCartridge* LoadPreset(FAutomationTestBase& T, const FString& Name)
	{
		TArray<FString> Errors;
		UJamCartridge* C = UJamCartridge::LoadFromFile(UJamCartridge::ResolveCartridgePath(Name), Errors);
		for (const FString& E : Errors) T.AddError(FString::Printf(TEXT("%s: %s"), *Name, *E));
		return C;
	}

	// The scene and the scripted human are FJamCarryDrill (JamCarryDrill.h): the same code jam.ctrl.Drill 21 runs in a package.
	using FScript = FJamCarryDrill;
	using FRun = FJamCarryDrill;
	constexpr int32 Past = FJamCarryDrill::Past, Setup = FJamCarryDrill::Setup, EndCount = FJamCarryDrill::EndCount;

	FJamInput ToInput(const JamAI::FJamAIInput& A)
	{
		FJamInput I;
		I.Move = FVector2D(A.Move.X, A.Move.Y);
		I.bShoot = A.bShoot; I.bShootHeld = A.bShootHeld; I.bCheck = A.bCheck; I.bBrake = A.bBrake; I.bPass = A.bPass; I.bPassHeld = A.bPassHeld;
		I.Stick = FVector2D(A.Stick.X, A.Stick.Y);
		I.bPoke = A.bPoke; I.bLift = A.bLift; I.bDeke = A.bDeke; I.bSpin = A.bSpin; I.bSprint = A.bSprint; I.bAbility = A.bAbility;
		return I;
	}

	// One carry at the opposing chaser, which the real brain plays at Level from a standstill; everyone else is parked in a corner with no input.
	FRun Carry(const UJamCartridge& C, uint64 Seed, const FScript& Script, const TCHAR* Level = TEXT("pro"), TArray<FString>* Trace = nullptr, UJamSim* Sim = nullptr, UJamBrain* Brain = nullptr, const char* Tune = nullptr)
	{
		FJamCarryDrill D = Script;
		if (!Sim) Sim = NewObject<UJamSim>();
		if (!Brain) Brain = NewObject<UJamBrain>();
		Sim->Init(C.Game, Seed);
		Sim->SkipFaceoff();
		if (!D.Stage(*Sim, Seed)) return D;
		Brain->ApplyCartridge(C, Level);
		if (Tune && *Tune)   // lane A153: a profile tune on top of the level (a rule's neutral arm in the same run)
		{
			char Err[200] = {};
			JamAI::ApplyDifficultyTune(Tune, Brain->EditParams(), Err, sizeof(Err));
			Brain->SpeedScale = static_cast<float>(Brain->EditParams().SpeedScale);
			Brain->RedSkill = static_cast<float>(Brain->EditParams().RedSkill);
		}
		Brain->ResetBrain();
		TArray<FJamInput> In;
		In.SetNum(Sim->GetSkaters().Num());
		while (D.End == FJamCarryDrill::Running)
		{
			JamAI::FJamAIWorld W;
			JamAI::FJamSimAdapter::BuildWorld(*Sim, W);
			JamAI::FJamAIInput Out[JamAI::kMaxSkaters];
			Brain->Think(W, Out);
			for (FJamInput& I : In) I = FJamInput();
			if (!D.DefenderWaits()) In[D.Def] = ToInput(Out[D.Def]);
			In[D.Me] = D.HumanInput(*Sim);
			D.BeforeStep(*Sim, In[D.Def]);
			if (Trace && D.Frames % 4 == 0)
			{
				const FJamSkaterState& S = Sim->GetSkaters()[D.Me];
				const FJamSkaterState& O = Sim->GetSkaters()[D.Def];
				Trace->Add(FString::Printf(TEXT("f=%d phase=%d gap=%.2f me=(%.2f,%.2f) v=%.2f yaw=%.0f def=(%.2f,%.2f) v=%.2f puck=(%.2f,%.2f) carry=%d burst=%d brake=%d sweep=%d body=%d dstick=(%.2f,%.2f) dpoke=%d dlift=%d dcheck=%d dsprint=%d"),
					D.Frames, D.Phase, FVector2D::Distance(S.Pos, O.Pos), S.Pos.X, S.Pos.Y, S.Vel.Size(), FMath::RadiansToDegrees(S.Yaw), O.Pos.X, O.Pos.Y, O.Vel.Size(), Sim->GetPuck().Pos.X, Sim->GetPuck().Pos.Y,
					Sim->CarrierIndex() == D.Me ? 1 : 0, S.BurstLeft, S.bReverseBraking ? 1 : 0, S.SweepFrames, D.bBodyBefore ? 1 : 0,
					In[D.Def].Stick.X, In[D.Def].Stick.Y, In[D.Def].bPoke ? 1 : 0, In[D.Def].bLift ? 1 : 0, In[D.Def].bCheck ? 1 : 0, In[D.Def].bSprint ? 1 : 0));
			}
			Sim->Step(In);
			if (Trace) for (const FJamSimEvent& E : Sim->GetFrameEvents()) Trace->Add(FString::Printf(TEXT("  event f=%d %s who=%d kind=%s strength=%.2f"), D.Frames, *E.Name.ToString(), E.Who, *E.Kind.ToString(), E.Strength));
			D.AfterStep(*Sim);
		}
		if (Trace) Trace->Add(FString::Printf(TEXT("end=%s frames=%d min_gap=%.2f brake_frames=%d"), FJamCarryDrill::EndName(D.End), D.Frames, D.MinGapM, D.BrakeFrames));
		return D;
	}

	struct FShare
	{
		int32 N = 0;
		int32 Ends[EndCount] = {};
		int32 BodyShieldRefused = 0, DefLifts = 0, DefPokes = 0, DefChecks = 0;
		int64 Frames = 0;
		double PastShare() const { return N > 0 ? static_cast<double>(Ends[Past]) / N : 0.0; }
		// Lane A138: the carrier still has the puck at the end: past, or timed out with it (a defender that stayed goal-side and took nothing).
		double KeptShare() const { return N > 0 ? static_cast<double>(Ends[Past] + Ends[FJamCarryDrill::Timeout]) / N : 0.0; }
		FString Line() const
		{
			FString S = FString::Printf(TEXT("past %d of %d (%.1f %%)"), Ends[Past], N, 100.0 * PastShare());
			for (int32 i = 1; i < EndCount; ++i) if (Ends[i] > 0) S += FString::Printf(TEXT(", %s %d"), FJamCarryDrill::EndName(i), Ends[i]);
			S += FString::Printf(TEXT("; defender presses: lift %d poke %d check %d, lifts refused by the body %d; %.0f frames a carry"), DefLifts, DefPokes, DefChecks, BodyShieldRefused, N > 0 ? static_cast<double>(Frames) / N : 0.0);
			return S;
		}
	};

	FShare Share(const UJamCartridge& C, const FScript& Sc, int32 Seeds, const TCHAR* Level = TEXT("pro"), const char* Tune = nullptr)
	{
		FShare S;
		UJamSim* Sim = NewObject<UJamSim>();
		UJamBrain* Brain = NewObject<UJamBrain>();
		for (int32 Seed = 1; Seed <= Seeds; ++Seed)
		{
			const FRun R = Carry(C, static_cast<uint64>(Seed), Sc, Level, nullptr, Sim, Brain, Tune);
			++S.N; ++S.Ends[R.End]; S.BodyShieldRefused += R.BodyShieldRefused; S.DefLifts += R.DefLifts; S.DefPokes += R.DefPokes; S.DefChecks += R.DefChecks; S.Frames += R.Frames;
		}
		return S;
	}

	UJamCartridge* Copy(const UJamCartridge& C) { return DuplicateObject<UJamCartridge>(&C, GetTransientPackage()); }

	// The clean stop-and-go the gate holds (MOVEMENT-2.md section 2): FJamCarryDrill's own defaults.
	// Lane A128: the drill's own default stop is 8 m now (the window's centre); the gate's "clean stop" rows keep lane A102's 9.5 m, the far edge.
	// Lane A147: and one move (SecondMove 0): the rows that mean "lane A102's clean stop" keep that script; the second move has its own test.
	FScript DefaultGo() { FScript S; S.BrakeAtM = 9.5; S.SecondMove = 0; return S; }

	// A scene for the rule itself: the carrier (human) at the origin facing Yaw with the puck on its blade at StickDir, the opposing chaser standing at DefPos.
	UJamSim* ShieldScene(const FJamGameConfig& G, double Yaw, const FVector2D& StickDir, const FVector2D& DefPos, int32& Me, int32& Def)
	{
		UJamSim* Sim = NewObject<UJamSim>();
		Sim->Init(G, 1);
		Sim->SkipFaceoff();
		Me = Sim->GetHumanIndex();
		Def = -1;
		for (const FJamSkaterState& S : Sim->GetSkaters()) if (S.Team != Sim->GetSkaters()[Me].Team) { Def = S.Index; break; }
		const int32 N = Sim->GetSkaters().Num();
		for (int32 i = 0; i < N; ++i) Sim->SetSkater(i, FVector2D(-40.0 + i * 1.5, 19.0), FVector2D::ZeroVector, 0);
		Sim->SetSkater(Me, FVector2D::ZeroVector, FVector2D::ZeroVector, Yaw);
		Sim->SetPuck(StickDir.GetSafeNormal() * 0.45, FVector2D::ZeroVector);
		TArray<FJamInput> In;
		In.SetNum(N);
		In[Me].Stick = StickDir;
		for (int32 i = 0; i < 8; ++i) Sim->Step(In);
		Sim->SetSkater(Def, DefPos, FVector2D::ZeroVector, FMath::Atan2(-DefPos.Y, -DefPos.X));
		for (int32 i = 0; i < 2; ++i) Sim->Step(In);   // the defender's blade settles ahead of it
		return Sim;
	}

	// The defender presses the lift (bLift) or the poke (its blade aimed at the puck) once; true when the carrier still has the puck 12 frames later.
	// bClean: the sim called the press a clean take (its poke or lift event).
	bool Keeps(UJamSim* Sim, int32 Me, int32 Def, const FVector2D& StickDir, bool bLift, bool* bClean = nullptr)
	{
		if (bClean) *bClean = false;
		TArray<FJamInput> In;
		In.SetNum(Sim->GetSkaters().Num());
		In[Me].Stick = StickDir;
		const FVector2D ToPuck = Sim->GetPuck().Pos - Sim->GetSkaters()[Def].Pos;
		const double Reach = FMath::Max(0.01, Sim->GetConfig().Stick.ReachM);
		const FVector2D Aim = ToPuck.GetSafeNormal() * FMath::Clamp((ToPuck.Size() - UJamSim::SkaterRadius) / Reach, 0.2, 1.0);
		for (int32 F = 0; F < 12; ++F)
		{
			In[Def] = FJamInput();
			In[Def].Stick = Aim;
			if (F == 1) { In[Def].bLift = bLift; In[Def].bPoke = !bLift; }
			Sim->Step(In);
			if (bClean) for (const FJamSimEvent& E : Sim->GetFrameEvents()) if ((E.Name == JamEvents::Poke || E.Name == JamEvents::Lift) && E.Who == Def && E.Strength > 0.5f) *bClean = true;
		}
		return Sim->GetPuck().LastTouch == Me && Sim->CarrierIndex() == Me;
	}
}

// The evolution's number: a clean stop-and-go past a standing pro defender against a straight charge at it.
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamMovementStopAndGo, "Jam.Core.Movement.StopAndGo", JamCarrierSkillTests::Flags)
bool FJamMovementStopAndGo::RunTest(const FString& Parameters)
{
	using namespace JamCarrierSkillTests;
	UJamCartridge* C = LoadPreset(*this, TEXT("hockey.regular"));
	if (!C) return false;
	FScript Go = DefaultGo(), Straight = DefaultGo();
	Straight.bStopAndGo = false;
	const FShare A = Share(*C, Go, 200), B = Share(*C, Straight, 200);
	AddInfo(FString::Printf(TEXT("STOPGO pro clean stop-and-go (the stop begins at 9.5 m): %s"), *A.Line()));
	AddInfo(FString::Printf(TEXT("STOPGO pro straight charge: %s"), *B.Line()));
	// The same two carries with the neutral value of this lane's rule (game.stick.body_shield false): what the game was.
	UJamCartridge* N = Copy(*C);
	N->Game.Stick.bBodyShield = false;
	const FShare An = Share(*N, Go, 200), Bn = Share(*N, Straight, 200);
	AddInfo(FString::Printf(TEXT("STOPGO pro clean stop-and-go, body_shield false: %s"), *An.Line()));
	AddInfo(FString::Printf(TEXT("STOPGO pro straight charge, body_shield false: %s"), *Bn.Line()));
	// The game before the lane: both neutral values (body_shield false, passive_take true) and the teammate's touch.
	UJamCartridge* Old = Copy(*C);
	Old->Game.Stick.bBodyShield = false;
	Old->Game.Stick.bPassiveTake = true;
	Old->Game.Stick.bTeammateTouchTakes = true;
	const FShare Ao = Share(*Old, Go, 200), Bo = Share(*Old, Straight, 200);
	AddInfo(FString::Printf(TEXT("STOPGO pro clean stop-and-go, the game before the lane: %s"), *Ao.Line()));
	AddInfo(FString::Printf(TEXT("STOPGO pro straight charge, the game before the lane: %s"), *Bo.Line()));
	// The skill is the timing and the mouse: the same stop begun late (6 m), at the brief's 5 m, and with the blade left ahead.
	FScript Late = Go, Brief = Go, NoMouse = Go;
	Late.BrakeAtM = 6.0;
	Brief.BrakeAtM = 5.0;
	NoMouse.bStickAway = false;
	const FShare L = Share(*C, Late, 200), Br = Share(*C, Brief, 200), M = Share(*C, NoMouse, 200);
	AddInfo(FString::Printf(TEXT("STOPGO pro stop begun late, at 6 m: %s"), *L.Line()));
	AddInfo(FString::Printf(TEXT("STOPGO pro stop begun at the brief's 5 m: %s"), *Br.Line()));
	AddInfo(FString::Printf(TEXT("STOPGO pro clean stop-and-go, the blade left ahead (no mouse): %s"), *M.Line()));
	TestEqual(TEXT("every scene set up (the human carries when the brain takes the defender over)"), A.Ends[Setup] + B.Ends[Setup] + An.Ends[Setup] + Bn.Ends[Setup] + L.Ends[Setup] + Br.Ends[Setup] + M.Ends[Setup], 0);
	// Lane A185 (track F2 evolution 9, R-0064 point 2; MOVEMENT-10.md): with the free skaters 15 % faster the defender closes sooner and the stop's far edge
	// came in from 9.5 m to 9 m at pro (9.5 m: 97 -> 78 %; 9 m 94.5 %; 8.5 m 99.5 %; 8 m 94 %; Bar.Curve.Law3). The far-edge bars below are held at 9 m.
	FScript Far = Go, FarNoMouse = Go;
	Far.BrakeAtM = 9.0; FarNoMouse.BrakeAtM = 9.0; FarNoMouse.bStickAway = false;
	const FShare F9 = Share(*C, Far, 200), M9 = Share(*C, FarNoMouse, 200);
	AddInfo(FString::Printf(TEXT("STOPGO pro stop begun at 9 m (the far edge since lane A185): %s"), *F9.Line()));
	AddInfo(FString::Printf(TEXT("STOPGO pro stop begun at 9 m, the blade left ahead (no mouse): %s"), *M9.Line()));
	// Lane A121 (track F2, evolution 2: the carrier's answer inside ten metres; MOVEMENT-3.md): the stop begun at 8 m, under the defaults and under that
	// lane's neutral block (take_grace_frames 0, reverse_brake_decel 20, burst.own_stop false: lane A102's game, where 8 m was 25.5 %).
	{
		FScript At8 = Go;
		At8.BrakeAtM = 8.0;
		UJamCartridge* E1 = Copy(*C);
		E1->Game.Stick.TakeGraceFrames = 0; E1->Game.Skater.ReverseBrakeDecel = 20; E1->Game.Skater.bBurstOwnStop = false; E1->Game.Skater.BurstRestFrames = 0; E1->Game.Skater.SpinExposedTail = 0;   // lane A128: and before its two keys
		const FShare G8 = Share(*C, At8, 200), G8n = Share(*E1, At8, 200), A1 = Share(*E1, Go, 200);
		AddInfo(FString::Printf(TEXT("STOPGO pro stop begun at 8 m: %s"), *G8.Line()));
		AddInfo(FString::Printf(TEXT("STOPGO pro stop begun at 8 m, lane A121's neutral block: %s"), *G8n.Line()));
		AddInfo(FString::Printf(TEXT("STOPGO pro clean stop-and-go (9.5 m), lane A121's neutral block: %s"), *A1.Line()));
		TestTrue(FString::Printf(TEXT("A121: a stop begun at 8 m passes a pro at least 55 %% (%.1f %%)"), 100.0 * G8.PastShare()), G8.PastShare() >= 0.55);
		// Lane A138 (R-0053): this is the bar the parked landing broke (50 %: 73 of 200 carries timed out with the puck kept, 26 were lifted). The brain of
		// evolution 2 reads the body shield, swings nothing and went round the body at any speed: against a stop begun this early it rode level with the
		// carrier and was never passed. The way round is now for a carrier that dawdles (FJamHockeySense::RoundMaxMps 3 m/s); one that stops and goes is
		// chased and overrun, as R-0053 rules. With hk_round_max_mps 0 (lane A115's rule) this row reads 72.5 %.
		TestTrue(FString::Printf(TEXT("A121 / A185: the stop begun at the far edge (9 m) stays at 90 %% or more (%.1f %%; 9.5 m: %.1f %%)"), 100.0 * F9.PastShare(), 100.0 * A.PastShare()), F9.PastShare() >= 0.90);
		TestTrue(FString::Printf(TEXT("A138 / A185: the stop begun at 9 m keeps the puck at least 95 %% of the time (%.1f %% kept, %.1f %% past)"), 100.0 * F9.KeptShare(), 100.0 * F9.PastShare()), F9.KeptShare() >= 0.95);
		TestTrue(FString::Printf(TEXT("A121: the evolution is worth at least 30 points at 8 m (%.1f against %.1f under its neutral block)"), 100.0 * G8.PastShare(), 100.0 * G8n.PastShare()), G8.PastShare() >= G8n.PastShare() + 0.30);
		TestTrue(FString::Printf(TEXT("A121: the neutral block is lane A102's late edge (8 m under 35 %%: %.1f)"), 100.0 * G8n.PastShare()), G8n.PastShare() <= 0.35);
	}
	// Lane A128 (track F2, evolution 3; MOVEMENT-4.md): with the standing start (burst.rest_frames) the defender starts from rest with its first step too.
	// The brief's bars: the stop begun at 8 m still passes a pro 95 % or more; the straight charge stays under 20 % (below).
	{
		FScript At8 = Go;
		At8.BrakeAtM = 8.0;
		UJamCartridge* R0 = Copy(*C);
		R0->Game.Skater.BurstRestFrames = 0;
		FScript NoMouse8 = At8;
		NoMouse8.bStickAway = false;
		const FShare G8 = Share(*C, At8, 200), G8n = Share(*R0, At8, 200), Dflt = Share(*C, FScript(), 200), M8 = Share(*C, NoMouse8, 200);
		AddInfo(FString::Printf(TEXT("STANDING pro stop begun at 8 m, the blade left ahead (no mouse): %s"), *M8.Line()));
		TestTrue(FString::Printf(TEXT("A128: the mouse is the skill at 8 m: with the blade left ahead the stop is at least 20 points worse (%.1f %%)"), 100.0 * M8.PastShare()), M8.PastShare() <= G8.PastShare() - 0.20);
		AddInfo(FString::Printf(TEXT("STANDING pro stop begun at 8 m: %s"), *G8.Line()));
		AddInfo(FString::Printf(TEXT("STANDING pro stop begun at 8 m, burst.rest_frames 0: %s"), *G8n.Line()));
		AddInfo(FString::Printf(TEXT("STANDING pro the drill's own default script: %s"), *Dflt.Line()));
		TestTrue(FString::Printf(TEXT("A128: with the standing start the stop begun at 8 m passes a pro 90 %% or more (%.1f %%; 95 before lane A185's faster defender, 94 after)"), 100.0 * G8.PastShare()), G8.PastShare() >= 0.90);
		TestEqual(TEXT("A128: the drill's default stop is at 8 m"), FScript().BrakeAtM, 8.0);
		TestEqual(TEXT("A128: the drill's default script is the stop at 8 m"), Dflt.Ends[Past], G8.Ends[Past]);
	}
	// Bars. R-0053 point 1 (lane A138): law 3 is a gate. On main, at pro, a stop begun at 8 m (the window's centre since lane A121, the drill's default since
	// lane A128) passes at least 80 % and a straight charge under 20 %; at all_star the stop passes at least 50 % where its window is (10 to 12 m: all_star
	// does not creep, lane A128). The gate's own bars read the stop at 8 m; lane A102's clean stop at 9.5 m keeps its 95 % in lane A121's block above.
	{
		FScript At8 = Go, At11 = Go, At12 = Go;
		At8.BrakeAtM = 8.0; At11.BrakeAtM = 11.0; At12.BrakeAtM = 12.0;
		const FShare G8 = Share(*C, At8, 200), G8n = Share(*N, At8, 200);
		// Lane A208 (game.stick.pickup): the body shield's worth is read at the pickup's neutral value on both arms. With the pickup on a lift from behind no
		// longer takes the puck held ahead with or without the shield (the carrier's own body blocks the lifted puck and his arc takes it back after the
		// lost-puck frames), so the shield's 10 points are carried by the body itself (94.0 on both arms at the pickup's default).
		UJamCartridge* Cp = Copy(*C); Cp->Game.Stick.PickupArcM = 0.0; Cp->Game.Stick.bPickupBody = false;
		UJamCartridge* Np = Copy(*N); Np->Game.Stick.PickupArcM = 0.0; Np->Game.Stick.bPickupBody = false;
		const FShare G8p = Share(*Cp, At8, 200), G8np = Share(*Np, At8, 200);
		AddInfo(FString::Printf(TEXT("LAW3 pro stop begun at 8 m at the pickup's neutral: shield %s | body_shield false %s"), *G8p.Line(), *G8np.Line()));
		const FShare S8 = Share(*C, At8, 200, TEXT("all_star")), S95 = Share(*C, Go, 200, TEXT("all_star")), S11 = Share(*C, At11, 200, TEXT("all_star")), S12 = Share(*C, At12, 200, TEXT("all_star")), SB = Share(*C, Straight, 200, TEXT("all_star"));
		AddInfo(FString::Printf(TEXT("LAW3 pro stop begun at 8 m: %s"), *G8.Line()));
		AddInfo(FString::Printf(TEXT("LAW3 pro stop begun at 8 m, body_shield false: %s"), *G8n.Line()));
		AddInfo(FString::Printf(TEXT("LAW3 all_star stop begun at 8 m: %s"), *S8.Line()));
		AddInfo(FString::Printf(TEXT("LAW3 all_star stop begun at 9.5 m: %s"), *S95.Line()));
		AddInfo(FString::Printf(TEXT("LAW3 all_star stop begun at 11 m: %s"), *S11.Line()));
		AddInfo(FString::Printf(TEXT("LAW3 all_star stop begun at 12 m: %s"), *S12.Line()));
		AddInfo(FString::Printf(TEXT("LAW3 all_star straight charge: %s"), *SB.Line()));
		TestTrue(FString::Printf(TEXT("law 3 (R-0053): at pro a stop begun at 8 m beats the defender at least 8 times in 10 (%.1f %%)"), 100.0 * G8.PastShare()), G8.PastShare() >= 0.80);
		TestTrue(FString::Printf(TEXT("law 3 (R-0053): at pro a straight charge beats it at most 1 time in 5 (%.1f %%)"), 100.0 * B.PastShare()), B.PastShare() <= 0.20);
		TestTrue(FString::Printf(TEXT("the gap between the two is at least 47 points (%.1f)"), 100.0 * (G8.PastShare() - B.PastShare())), G8.PastShare() - B.PastShare() >= 0.47);
		// Lane A153 (R-0058 point 1, which replaces R-0055 point 2): one stop distance at every level. All_star's presser stays on its job inside the hunt,
		// so the bar at all_star is pro's: the stop begun at 8 m passes 80 % or more (before: 50 % at the best of the four distances, which was 12 m).
		AddInfo(FString::Printf(TEXT("LAW3 all_star by distance: 8 m %.1f, 9.5 m %.1f, 11 m %.1f, 12 m %.1f"), 100.0 * S8.PastShare(), 100.0 * S95.PastShare(), 100.0 * S11.PastShare(), 100.0 * S12.PastShare()));
		TestTrue(FString::Printf(TEXT("law 3 (R-0058): at all_star a stop begun at 8 m beats the defender at least 8 times in 10 (%.1f %%)"), 100.0 * S8.PastShare()), S8.PastShare() >= 0.80);
		{
			// the rule's neutral value inside this run: with the switch off (the tune opp.hk_press_in_hunt=0) the same 200 carries are the game before the lane
			const FShare S8off = Share(*C, At8, 200, TEXT("all_star"), "opp.hk_press_in_hunt=0"), S12off = Share(*C, At12, 200, TEXT("all_star"), "opp.hk_press_in_hunt=0");
			AddInfo(FString::Printf(TEXT("LAW3 all_star, opp.hk_press_in_hunt=0 (the game before lane A153): stop begun at 8 m: %s"), *S8off.Line()));
			AddInfo(FString::Printf(TEXT("LAW3 all_star, opp.hk_press_in_hunt=0: stop begun at 12 m: %s"), *S12off.Line()));
			TestTrue(FString::Printf(TEXT("the presser on its job is worth at least 50 points to the stop at 8 m at all_star (%.1f against %.1f with the switch off)"), 100.0 * S8.PastShare(), 100.0 * S8off.PastShare()), S8.PastShare() >= S8off.PastShare() + 0.50);
		}
		TestTrue(FString::Printf(TEXT("at all_star a straight charge beats it at most 1 time in 5 (%.1f %%)"), 100.0 * SB.PastShare()), SB.PastShare() <= 0.20);
		TestTrue(FString::Printf(TEXT("the body between is worth at least 10 points to the stop-and-go at 8 m, at the pickup's neutral (%.1f against %.1f with body_shield false)"), 100.0 * G8p.PastShare(), 100.0 * G8np.PastShare()), G8p.PastShare() >= G8np.PastShare() + 0.10);
		// Lane A121: the window moved about 1.5 m toward the defender (6 m: 2.5 -> 23.5 %; 5 m stays 0): the timing bar is the brief's 5 m, and 6 m against the clean stop.
		TestTrue(FString::Printf(TEXT("timing is the skill: the stop begun at 5 m beats the defender at most 1 time in 10 (%.1f %%)"), 100.0 * Br.PastShare()), Br.PastShare() <= 0.10);
		TestTrue(FString::Printf(TEXT("timing is the skill: the stop begun at 6 m is at least 40 points worse than the one at 8 m (%.1f %%)"), 100.0 * L.PastShare()), L.PastShare() <= G8.PastShare() - 0.40);
		// The mouse is the skill: the 20-point bar is held at 8 m in lane A128's block above; at 9.5 m the blade left ahead costs 10 points or more, as before.
		AddInfo(FString::Printf(TEXT("LAW3 pro stop begun at 9.5 m: with the mouse %.1f %% past and %.1f %% kept; the blade left ahead %.1f %% past and %.1f %% kept"), 100.0 * A.PastShare(), 100.0 * A.KeptShare(), 100.0 * M.PastShare(), 100.0 * M.KeptShare()));
		// Lane A185: at the far edge, now 9 m (at 9.5 m the stop is begun too early against the faster defender and the blade no longer decides it).
		TestTrue(FString::Printf(TEXT("the mouse is the skill: with the blade left ahead the stop-and-go at 9 m is at least 10 points worse (%.1f %% against %.1f %%)"), 100.0 * M9.PastShare(), 100.0 * F9.PastShare()), M9.PastShare() <= F9.PastShare() - 0.10);
		TestTrue(FString::Printf(TEXT("the mouse is the skill at 9 m: with the blade left ahead the puck is lost at least 10 points more often (kept %.1f %% against %.1f %%)"), 100.0 * M9.KeptShare(), 100.0 * F9.KeptShare()), M9.KeptShare() <= F9.KeptShare() - 0.10);
	}
	// Determinism of the scene: the same seed twice is the same carry.
	const FRun R1 = Carry(*C, 7, Go), R2 = Carry(*C, 7, Go);
	TestTrue(TEXT("the same seed is the same carry"), R1.End == R2.End && R1.Frames == R2.Frames);
	// A sim and a brain used again for the next seed (how the 200 are run) give the carry fresh ones give.
	{
		UJamSim* Sim = NewObject<UJamSim>();
		UJamBrain* Brain = NewObject<UJamBrain>();
		int32 Differ = 0;
		for (uint64 Seed = 1; Seed <= 12; ++Seed)
		{
			const FRun Used = Carry(*C, Seed, Seed % 2 ? Go : Straight, TEXT("pro"), nullptr, Sim, Brain), Fresh = Carry(*C, Seed, Seed % 2 ? Go : Straight);
			if (Used.End != Fresh.End || Used.Frames != Fresh.Frames) ++Differ;
		}
		TestEqual(TEXT("a re-used sim and brain play the same 12 carries as fresh ones"), Differ, 0);
	}
	return true;
}

// Puck protection (game.stick.body_shield): with the carrier's body between a defender's stick and the puck, that defender's poke or lift fails; no button.
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamMovementBodyShield, "Jam.Core.Movement.BodyShield", JamCarrierSkillTests::Flags)
bool FJamMovementBodyShield::RunTest(const FString& Parameters)
{
	using namespace JamCarrierSkillTests;
	UJamCartridge* C = LoadPreset(*this, TEXT("hockey.regular"));
	if (C) { C->Game.Stick.PickupArcM = 0.0; C->Game.Stick.bPickupBody = false; C->Game.Stick.PickupRingM = 0.0; }   // lane A218: and the human's ring (the track's neutral)   // lane A208: re-staged at game.stick.pickup's neutral: this scene measures the shield against a poke and a lift; the loose puck's pickup has its own (Jam.Core.Possession.*)
	if (!C) return false;
	FJamGameConfig On = C->Game, Off = C->Game;
	On.Stick.bBodyShield = true;
	Off.Stick.bBodyShield = false;
	int32 Me = -1, Def = -1;
	struct FCase { const TCHAR* Name; double Yaw; FVector2D Stick; FVector2D DefPos; bool bShield; };
	const FCase Cases[] = {
		{ TEXT("defender behind, puck ahead"), 0.0, FVector2D(1, 0), FVector2D(-1.6, 0), true },
		{ TEXT("defender at one side, puck held to the other"), 0.0, FVector2D(0, 1), FVector2D(0, -1.6), true },
		{ TEXT("defender in front, puck ahead (the chest is open)"), 0.0, FVector2D(1, 0), FVector2D(1.6, 0.6), false },
		{ TEXT("defender in front, puck held behind the back (facing it shields nothing)"), 0.0, FVector2D(-1, 0), FVector2D(1.6, 0), false },
		{ TEXT("defender at the side, puck on its side"), 0.0, FVector2D(0, -1), FVector2D(0, -1.9), false },
		{ TEXT("defender behind but 2.5 m away"), 0.0, FVector2D(1, 0), FVector2D(-2.5, 0), false },
	};
	for (const FCase& K : Cases)
	{
		UJamSim* Sim = ShieldScene(On, K.Yaw, K.Stick, K.DefPos, Me, Def);
		TestEqual(FString::Printf(TEXT("%s: carried"), K.Name), Sim->CarrierIndex(), Me);
		const bool bGot = Sim->IsBodyShielded(Sim->GetSkaters()[Def], Sim->GetSkaters()[Me]);
		TestEqual(FString::Printf(TEXT("%s: body shield"), K.Name), bGot, K.bShield);
		TestEqual(FString::Printf(TEXT("%s: the poke's and the lift's shield follow it"), K.Name), Sim->IsPokeShielded(Sim->GetSkaters()[Def], Sim->GetSkaters()[Me]), K.bShield);
		UJamSim* SimOff = ShieldScene(Off, K.Yaw, K.Stick, K.DefPos, Me, Def);
		TestFalse(FString::Printf(TEXT("%s: never with body_shield false"), K.Name), SimOff->IsBodyShielded(SimOff->GetSkaters()[Def], SimOff->GetSkaters()[Me]));
	}
	// The lift from behind: refused with the body between, clean with the neutral value and from in front.
	{
		UJamSim* Sim = ShieldScene(On, 0.0, FVector2D(1, 0), FVector2D(-1.6, 0), Me, Def);
		TestTrue(TEXT("a lift from behind does not take a puck held ahead"), Keeps(Sim, Me, Def, FVector2D(1, 0), true));
		Sim = ShieldScene(Off, 0.0, FVector2D(1, 0), FVector2D(-1.6, 0), Me, Def);
		TestFalse(TEXT("body_shield false: the lift from behind takes it, as before"), Keeps(Sim, Me, Def, FVector2D(1, 0), true));
		Sim = ShieldScene(On, 0.0, FVector2D(1, 0), FVector2D(1.6, 0.6), Me, Def);
		TestFalse(TEXT("a lift from in front takes it: the body is not between"), Keeps(Sim, Me, Def, FVector2D(1, 0), true));
	}
	// The poke across the body: the defender at the side, the puck held close on the far side (a third of the aim), inside the reach of a blade that
	// has to pass through the carrier to get there.
	{
		UJamSim* Sim = ShieldScene(On, 0.0, FVector2D(0, 0.3), FVector2D(0, -0.9), Me, Def);
		TestTrue(TEXT("the poke's scene: the body is between"), Sim->IsBodyShielded(Sim->GetSkaters()[Def], Sim->GetSkaters()[Me]));
		bool bClean = false;
		TestTrue(TEXT("a poke across the body does not take the puck"), Keeps(Sim, Me, Def, FVector2D(0, 0.3), false, &bClean));
		TestFalse(TEXT("a poke across the body is not a clean poke"), bClean);
		Sim = ShieldScene(Off, 0.0, FVector2D(0, 0.3), FVector2D(0, -0.9), Me, Def);
		const bool bKeptOff = Keeps(Sim, Me, Def, FVector2D(0, 0.3), false, &bClean);
		// With the neutral value the blade reaches through the carrier and the sim calls it a clean poke (the puck may still bounce back off the body it was pulled through).
		AddInfo(FString::Printf(TEXT("BODYSHIELD poke across the body with body_shield false: clean poke %d, the carrier %s the puck"), bClean ? 1 : 0, bKeptOff ? TEXT("keeps") : TEXT("loses")));
		TestTrue(TEXT("body_shield false: the blade reaches through the body, a clean poke as before"), bClean);
	}
	// No state, no hash: two sims that differ only in the key hash alike while nobody presses a stick.
	{
		UJamSim* A = NewObject<UJamSim>();
		A->Init(On, 3);
		UJamSim* B = NewObject<UJamSim>();
		B->Init(Off, 3);
		TArray<FJamInput> In;
		In.SetNum(A->GetSkaters().Num());
		for (int32 F = 0; F < 200; ++F) { In[A->GetHumanIndex()].Move = FVector2D(1, 0); A->Step(In); B->Step(In); }
		TestEqual(TEXT("the key adds no state: the hash without a stick press is the same"), A->StateHashHex(), B->StateHashHex());
	}
	return true;
}

// R-0048 (game.stick.passive_take): a carried puck leaves its carrier only by a press. The human carries at 9 m/s past a standing skater whose aimed blade
// lies across its line (the deflection of C-0005), and past one whose body the puck brushes; an opponent and a teammate; both values of the key.
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamMovementPassiveTake, "Jam.Core.Movement.PassiveTake", JamCarrierSkillTests::Flags)
bool FJamMovementPassiveTake::RunTest(const FString& Parameters)
{
	using namespace JamCarrierSkillTests;
	UJamCartridge* C = LoadPreset(*this, TEXT("hockey.regular"));
	if (C) { C->Game.Stick.PickupArcM = 0.0; C->Game.Stick.bPickupBody = false; }   // lane A208: re-staged at game.stick.pickup's neutral: this scene measures the unpressed take of a carried puck (R-0048) against its neutral; the loose puck's pickup has its own (Jam.Core.Possession.*)
	if (!C) return false;
	TestFalse(TEXT("game.stick.passive_take is false when the key is absent"), C->Game.Stick.bPassiveTake);
	TestTrue(TEXT("game.stick.body_shield is true when the key is absent"), C->Game.Stick.bBodyShield);
	FJamGameConfig Off = C->Game, On = C->Game;
	Off.Stick.bPassiveTake = false;
	On.Stick.bPassiveTake = true;
	// Frames (of 90) on which somebody else was the puck's last toucher; bBlade: the other's aimed blade lies across the line, else its body brushes the puck.
	auto Pass = [&](const FJamGameConfig& G, bool bBlade, bool bMate) -> int32
	{
		UJamSim* Sim = NewObject<UJamSim>();
		Sim->Init(G, 1);
		Sim->SkipFaceoff();
		const int32 Me = Sim->GetHumanIndex();
		const int32 N = Sim->GetSkaters().Num();
		int32 Other = -1;
		for (const FJamSkaterState& S : Sim->GetSkaters()) if (S.Index != Me && (S.Team == Sim->GetSkaters()[Me].Team) == bMate) { Other = S.Index; break; }
		if (Other < 0) return -1;
		for (int32 i = 0; i < N; ++i) Sim->SetSkater(i, FVector2D(-40.0 + i * 1.5, 19.0), FVector2D::ZeroVector, 0);
		const FVector2D Aim = bBlade ? FVector2D(1, 0) : FVector2D(1, 0.5).GetSafeNormal();
		Sim->SetSkater(Me, FVector2D(-6, 0), FVector2D(9, 0), 0);
		Sim->SetPuck(FVector2D(-6, 0) + Aim * 0.45, FVector2D(9, 0));
		// Blade: the other stands 1.3 m off the line and reaches across it. Body: it stands 0.95 m off the line, its back to it, and the puck (held half a metre to that side) brushes it.
		Sim->SetSkater(Other, bBlade ? FVector2D(4, 1.3) : FVector2D(4, 0.95), FVector2D::ZeroVector, UE_DOUBLE_PI * 0.5 * (bBlade ? -1.0 : 1.0));
		TArray<FJamInput> In;
		In.SetNum(N);
		int32 Taken = 0;
		for (int32 F = 0; F < 90; ++F)
		{
			In[Me].Move = FVector2D(0.89, 0);
			In[Me].Stick = Aim;
			if (bBlade) In[Other].Stick = FVector2D(0, -1);
			Sim->Step(In);
			if (F >= 10 && Sim->GetPuck().LastTouch != Me) ++Taken;
		}
		return Taken;
	};
	for (int32 Blade = 0; Blade < 2; ++Blade)
	{
		const TCHAR* What = Blade ? TEXT("an aimed blade across the line") : TEXT("a body the puck brushes");
		const int32 OppOff = Pass(Off, Blade != 0, false), OppOn = Pass(On, Blade != 0, false), MateOff = Pass(Off, Blade != 0, true), MateOn = Pass(On, Blade != 0, true);
		AddInfo(FString::Printf(TEXT("PASSIVE %s: frames the puck was somebody else's: opponent %d (passive_take false) / %d (true), teammate %d / %d"), What, OppOff, OppOn, MateOff, MateOn));
		TestEqual(FString::Printf(TEXT("%s, an opponent's, does not take a carried puck"), What), OppOff, 0);
		TestTrue(FString::Printf(TEXT("%s, an opponent's, takes it with passive_take true, as before"), What), OppOn > 0);
		TestEqual(FString::Printf(TEXT("%s, a teammate's, does not take a carried puck"), What), MateOff, 0);
		TestEqual(FString::Printf(TEXT("%s, a teammate's, does not take it with passive_take true either"), What), MateOn, 0);
	}
	// A shot is not a carried puck: a body two metres ahead still blocks it (the puck does not ride with the shooter).
	{
		UJamSim* Sim = NewObject<UJamSim>();
		Sim->Init(Off, 1);
		Sim->SkipFaceoff();
		const int32 Me = Sim->GetHumanIndex();
		const int32 N = Sim->GetSkaters().Num();
		int32 Opp = -1;
		for (const FJamSkaterState& S : Sim->GetSkaters()) if (S.Team != Sim->GetSkaters()[Me].Team) { Opp = S.Index; break; }
		for (int32 i = 0; i < N; ++i) Sim->SetSkater(i, FVector2D(-40.0 + i * 1.5, 19.0), FVector2D::ZeroVector, 0);
		Sim->SetSkater(Me, FVector2D::ZeroVector, FVector2D::ZeroVector, 0);
		Sim->SetPuck(FVector2D(0.45, 0), FVector2D::ZeroVector);
		TArray<FJamInput> In;
		In.SetNum(N);
		In[Me].Stick = FVector2D(1, 0);
		for (int32 i = 0; i < 8; ++i) Sim->Step(In);
		TestEqual(TEXT("the shot's scene: carried"), Sim->CarrierIndex(), Me);
		TestEqual(TEXT("the shot's scene: the puck rides"), Sim->RidingCarrier(), Me);
		Sim->SetSkater(Opp, FVector2D(2.0, 0), FVector2D::ZeroVector, 0);   // its back to the shooter: no blade in the way
		bool bBlocked = false;
		for (int32 F = 0; F < 20; ++F)
		{
			In[Me].bShoot = F == 0;
			Sim->Step(In);
			if (Sim->GetPuck().LastTouch == Opp) bBlocked = true;
		}
		TestTrue(TEXT("a shot from two metres is still blocked by the body in its way"), bBlocked);
	}
	return true;
}

// Lane A121 (track F2, evolution 2; R-0049 point 2): game.stick.take_grace_frames. A skater that has just won the puck cannot be poked or lifted for that many
// frames. The rule in a staged scene (a lift, the lift back, the poke back and its stumble), then in play: three minutes of pro hockey with the grace and
// without, every stick takeaway timed from the frame its victim won the puck.
namespace JamCarrierSkillTests
{
	struct FTakeCount
	{
		JamAI::FJamSimAdapter* Sim = nullptr;
		int64 LastFrame = -1;
		int32 Owner = -1;                 // the owner at the end of the previous frame
		int64 WonFrame = -1;              // the frame it won the puck
		int32 LiftPresses = 0, PokePresses = 0, CleanLifts = 0, CleanPokes = 0, Wins = 0;
		int32 Under30 = 0, MinHeld = 1 << 30;
		TArray<int32> Held;               // frames each stick takeaway's victim had held the puck
		// Lane A128: what a takeaway inside 30 frames of a win was: the owner's grace and the carrier at the end of the frame before it.
		int32 PrevGrace = 0, PrevCarrier = -1, PrevSpin = 0;
		TArray<FString> Notes;
	};

	void TakeTrace(void* Ctx, const JamAI::FJamAIWorld&, const JamAI::FJamAIInput*, const JamAI::FJamBrain&, int64_t, bool)
	{
		FTakeCount& C = *static_cast<FTakeCount*>(Ctx);
		const UJamSim* Sim = C.Sim->GetSim();
		if (!Sim || Sim->GetFrame() == C.LastFrame) return;
		C.LastFrame = Sim->GetFrame();
		for (const FJamSkaterState& S : Sim->GetSkaters()) { if (S.bLiftThisFrame) ++C.LiftPresses; if (S.bPokeThisFrame) ++C.PokePresses; }
		static const FName Clean(TEXT("clean"));
		for (const FJamSimEvent& E : Sim->GetFrameEvents())
		{
			const bool bLift = E.Name == JamEvents::Lift && E.Strength > 0.5f, bPoke = E.Name == JamEvents::Poke && E.Kind == Clean && E.Strength > 0.5f;
			if (!bLift && !bPoke) continue;
			if (bLift) ++C.CleanLifts; else ++C.CleanPokes;
			if (C.Owner >= 0 && C.Owner != E.Who && Sim->GetSkaters()[C.Owner].Team != Sim->GetSkaters()[E.Who].Team)
			{
				const int32 Held = static_cast<int32>(Sim->GetFrame() - C.WonFrame);
				C.Held.Add(Held);
				C.MinHeld = FMath::Min(C.MinHeld, Held);
				if (Held <= 30)
				{
					++C.Under30;
					const FJamSkaterState& V = Sim->GetSkaters()[C.Owner];
					C.Notes.Add(FString::Printf(TEXT("frame %lld: %s by %d on owner %d after %d frames; the frame before: the owner's grace %d, the carrier %d, the owner's spin frames %d; now: owner stumble %d, settle %d, down %d"),
						static_cast<long long>(Sim->GetFrame()), bLift ? TEXT("lift") : TEXT("poke"), E.Who, C.Owner, Held, C.PrevGrace, C.PrevCarrier, C.PrevSpin, V.StumbleFrames, V.SettleFrames, V.IsDown() ? 1 : 0));
				}
			}
		}
		const int32 Now = Sim->GetTakeOwner();
		if (Now >= 0 && Now != C.Owner) { C.WonFrame = Sim->GetFrame(); ++C.Wins; }
		C.Owner = Now;
		C.PrevGrace = Now >= 0 ? Sim->GetSkaters()[Now].TakeGraceLeft : 0;
		C.PrevCarrier = Sim->CarrierIndex();
		C.PrevSpin = Now >= 0 ? Sim->GetSkaters()[Now].SpinFrames : 0;
	}
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamMovementTakeGrace, "Jam.Core.Movement.TakeGrace", JamCarrierSkillTests::Flags)
bool FJamMovementTakeGrace::RunTest(const FString& Parameters)
{
	using namespace JamCarrierSkillTests;
	UJamCartridge* C = LoadPreset(*this, TEXT("hockey.regular"));
	if (!C) return false;
	TestEqual(TEXT("game.stick.take_grace_frames is 30 when the key is absent"), C->Game.Stick.TakeGraceFrames, 30);
	FJamGameConfig On = C->Game, Off = C->Game;
	Off.Stick.TakeGraceFrames = 0;
	// The scene: the human carries a placed puck (no grace: a placed puck is not won) facing an opponent that stands in front of it and lifts the puck (it
	// wins it: the grace starts). The human presses back Wait frames after the lift: a lift, or a poke with its blade on the puck.
	// Returns the frame (after the opponent's lift) on which the human had the puck back, or -1 inside 20 frames of its press.
	struct FBack { int32 GraceAtWin = -1, Owner = -1, BackFrame = -1, Stumble = 0; bool bCleanBack = false, bOppTook = false; };
	auto Back = [&](const FJamGameConfig& G, int32 Wait, bool bLift) -> FBack
	{
		FBack R;
		int32 Me = -1, Def = -1;
		UJamSim* Sim = ShieldScene(G, 0.0, FVector2D(1, 0), FVector2D(1.6, 0.6), Me, Def);
		TArray<FJamInput> In;
		In.SetNum(Sim->GetSkaters().Num());
		In[Me].Stick = FVector2D(1, 0);
		In[Def].bLift = true;
		Sim->Step(In);
		In[Def] = FJamInput();
		R.bOppTook = Sim->GetPuck().LastTouch == Def;
		// The puck comes to the opponent's blade (unaimed: an aim that followed the puck would be a sweep, with its own shield); the human waits.
		int32 F = 0;
		for (; F < Wait; ++F)
		{
			Sim->Step(In);
			if (R.GraceAtWin < 0 && Sim->CarrierIndex() == Def) { R.GraceAtWin = Sim->GetSkaters()[Def].TakeGraceLeft; R.Owner = Sim->GetTakeOwner(); }
		}
		for (int32 K = 0; K < 20; ++K, ++F)
		{
			const FVector2D ToPuck = Sim->GetPuck().Pos - Sim->GetSkaters()[Me].Pos;
			In[Me] = FJamInput();
			In[Me].Stick = ToPuck.GetSafeNormal() * FMath::Clamp((ToPuck.Size() - UJamSim::SkaterRadius) / FMath::Max(0.01, G.Stick.ReachM), 0.2, 1.0);
			if (K == 0) { In[Me].bLift = bLift; In[Me].bPoke = !bLift; }
			Sim->Step(In);
			if (R.GraceAtWin < 0 && Sim->CarrierIndex() == Def) { R.GraceAtWin = Sim->GetSkaters()[Def].TakeGraceLeft; R.Owner = Sim->GetTakeOwner(); }
			for (const FJamSimEvent& E : Sim->GetFrameEvents()) if ((E.Name == JamEvents::Poke || E.Name == JamEvents::Lift) && E.Who == Me && E.Strength > 0.5f) R.bCleanBack = true;
			R.Stumble = FMath::Max(R.Stumble, Sim->GetSkaters()[Me].StumbleFrames);
			if (R.BackFrame < 0 && Sim->GetPuck().LastTouch == Me) R.BackFrame = F;
		}
		return R;
	};
	for (const bool bLift : { true, false })
	{
		const TCHAR* What = bLift ? TEXT("lift") : TEXT("poke");
		const FBack Early = Back(On, 6, bLift), Late = Back(On, 40, bLift), EarlyOff = Back(Off, 6, bLift);
		AddInfo(FString::Printf(TEXT("TAKEGRACE the %s back: 6 frames after the take: clean %d, back at frame %d, stumble %d (grace at the win %d, owner %d); 40 frames after: clean %d, back at %d; take_grace_frames 0, 6 frames after: clean %d, back at %d, stumble %d"),
			What, Early.bCleanBack ? 1 : 0, Early.BackFrame, Early.Stumble, Early.GraceAtWin, Early.Owner, Late.bCleanBack ? 1 : 0, Late.BackFrame, EarlyOff.bCleanBack ? 1 : 0, EarlyOff.BackFrame, EarlyOff.Stumble));
		TestTrue(FString::Printf(TEXT("%s: the scene's opponent takes the placed puck (a placed puck gives its first carrier no grace)"), What), Early.bOppTook && Late.bOppTook && EarlyOff.bOppTook);
		TestTrue(FString::Printf(TEXT("%s: the winner's grace is up (%d of 30)"), What, Early.GraceAtWin), Early.GraceAtWin > 20 && Early.GraceAtWin <= 30);
		TestFalse(FString::Printf(TEXT("%s back inside the grace is refused"), What), Early.bCleanBack);
		TestTrue(FString::Printf(TEXT("%s back after the grace takes the puck"), What), Late.bCleanBack);
		TestTrue(FString::Printf(TEXT("%s back at once takes it with take_grace_frames 0, as before"), What), EarlyOff.bCleanBack);
		TestEqual(FString::Printf(TEXT("%s: take_grace_frames 0 leaves no grace"), What), EarlyOff.GraceAtWin, 0);
		if (!bLift) TestEqual(TEXT("a poke the grace refused costs no stumble"), Early.Stumble, 0);
	}
	// In play: hockey.regular at pro, the regular playtester and nine bots, 3 seeds of 10 800 frames (9 minutes), with the grace and with its neutral value.
	FTakeCount Sum[2];
	for (int32 Arm = 0; Arm < 2; ++Arm)
	{
		for (uint64 Seed = 1; Seed <= 3; ++Seed)
		{
			UJamCartridge* M = Copy(*C);
			M->Game.Rules.ScoreToWin = 99;
			M->Game.Rules.bPenalties = false;
			if (Arm == 1) M->Game.Stick.TakeGraceFrames = 0;
			JamAI::FJamSimAdapter Sim(*M);
			FTakeCount Count;
			Count.Sim = &Sim;
			const JamAI::FJamMatchConfig Cfg = JamAI::ToMatchConfigResolved(*M, TEXT("pro"));
			const JamAI::FJamPlaytestStats S = JamAI::RunPlaytestMatch(Sim, Cfg, Seed, JamAI::EPlaytester::Regular, 10800, M->Game.Shot.ChargeFramesMax, false, &TakeTrace, &Count, 1);
			Count.Held.Sort();
			AddInfo(FString::Printf(TEXT("TAKEGRACE match pro seed %llu, take_grace_frames %d: %lld frames, %d:%d, hash %016llx | lift presses %d, clean lifts %d, poke presses %d, clean pokes %d, pucks won %d | stick takeaways %d, shortest hold before one %d frames, median %d, inside 30 frames %d"),
				Seed, M->Game.Stick.TakeGraceFrames, static_cast<long long>(S.Frames), S.GoalsFor, S.GoalsAgainst, static_cast<unsigned long long>(S.Hash), Count.LiftPresses, Count.CleanLifts, Count.PokePresses, Count.CleanPokes, Count.Wins,
				Count.Held.Num(), Count.Held.Num() ? Count.MinHeld : -1, Count.Held.Num() ? Count.Held[Count.Held.Num() / 2] : -1, Count.Under30));
			if (Arm == 0) for (const FString& Note : Count.Notes) AddInfo(FString::Printf(TEXT("TAKEGRACE match pro seed %llu, a stick takeaway inside 30 frames of the win: %s"), Seed, *Note));
			FTakeCount& T = Sum[Arm];
			T.LiftPresses += Count.LiftPresses; T.PokePresses += Count.PokePresses; T.CleanLifts += Count.CleanLifts; T.CleanPokes += Count.CleanPokes; T.Wins += Count.Wins;
			T.Under30 += Count.Under30; T.MinHeld = FMath::Min(T.MinHeld, Count.MinHeld); T.Held.Append(Count.Held);
		}
	}
	for (int32 Arm = 0; Arm < 2; ++Arm)
	{
		FTakeCount& T = Sum[Arm];
		T.Held.Sort();
		AddInfo(FString::Printf(TEXT("TAKEGRACE pro, 9 minutes, take_grace_frames %d: per 104 s: lift presses %.0f, clean lifts %.1f, poke presses %.0f, clean pokes %.1f, pucks won %.0f | stick takeaways %d, shortest hold %d frames, median %d, inside 30 frames %d"),
			Arm == 0 ? C->Game.Stick.TakeGraceFrames : 0, T.LiftPresses * 104.0 / 540.0, T.CleanLifts * 104.0 / 540.0, T.PokePresses * 104.0 / 540.0, T.CleanPokes * 104.0 / 540.0, T.Wins * 104.0 / 540.0,
			T.Held.Num(), T.Held.Num() ? T.MinHeld : -1, T.Held.Num() ? T.Held[T.Held.Num() / 2] : -1, T.Under30));
	}
	TestTrue(TEXT("pucks were taken by a stick in play, with the grace"), Sum[0].Held.Num() > 10);
	// Lane A128 found one takeaway 8 frames after a win under its defaults (seed 2, frame 8488) and relaxed the bar to "at most one": ResolvePokes runs right
	// after the puck moved, the winner's grace was counted from the end of the frame, so an open poke window took the puck in the frame its carrier had won it.
	// Lane A138 closed the hole (stick.bTakeGraceSameFrame: a carrier that is not yet the take owner is inside its grace) and the bar is zero again.
	// R-0053 point 4: the grace refuses the stick's take only; a body check that lands loosens the puck as before; this counts clean pokes and lifts only.
	TestEqual(TEXT("with the grace no carrier loses the puck to a stick inside half a second of winning it"), Sum[0].Under30, 0);
	TestTrue(FString::Printf(TEXT("the shortest hold before a stick takeaway is more than 30 frames (%d)"), Sum[0].MinHeld), Sum[0].MinHeld > 30);
	// The hole itself, counted: the same three matches with the same-frame cover off.
	{
		int32 Under30Hole = 0, Takeaways = 0;
		for (uint64 Seed = 1; Seed <= 3; ++Seed)
		{
			UJamCartridge* M = Copy(*C);
			M->Game.Rules.ScoreToWin = 99;
			M->Game.Rules.bPenalties = false;
			M->Game.Stick.bTakeGraceSameFrame = false;
			JamAI::FJamSimAdapter Sim(*M);
			FTakeCount Count;
			Count.Sim = &Sim;
			const JamAI::FJamMatchConfig Cfg = JamAI::ToMatchConfigResolved(*M, TEXT("pro"));
			JamAI::RunPlaytestMatch(Sim, Cfg, Seed, JamAI::EPlaytester::Regular, 10800, M->Game.Shot.ChargeFramesMax, false, &TakeTrace, &Count, 1);
			Under30Hole += Count.Under30; Takeaways += Count.Held.Num();
			for (const FString& Note : Count.Notes) AddInfo(FString::Printf(TEXT("TAKEGRACE match pro seed %llu, bTakeGraceSameFrame false, a stick takeaway inside 30 frames of the win: %s"), Seed, *Note));
		}
		AddInfo(FString::Printf(TEXT("TAKEGRACE pro, 9 minutes, take_grace_frames 30 without the same-frame cover (lane A121's rule as it was): stick takeaways %d, inside 30 frames %d"), Takeaways, Under30Hole));
	}
	TestTrue(FString::Printf(TEXT("with the grace such takeaways are at most a tenth of what they are without it (%d against %d)"), Sum[0].Under30, Sum[1].Under30), Sum[0].Under30 * 10 <= Sum[1].Under30);
	TestTrue(FString::Printf(TEXT("without it some did (%d inside 30 frames): the rule has something to do"), Sum[1].Under30), Sum[1].Under30 > 0);
	return true;
}

// Lane A121 (track F2, evolution 2, the brief's point 4): the late answer inside 7 m. A player who reacts late (6 m from a charging pro) has an answer: no
// stop, the cut with the spin or with the deke tap (FJamCarryDrill::Late, jam.ctrl.CarryScript 3 and 4). Inside 4 m nothing answers.
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamMovementLateAnswer, "Jam.Core.Movement.LateAnswer", JamCarrierSkillTests::Flags)
bool FJamMovementLateAnswer::RunTest(const FString& Parameters)
{
	using namespace JamCarrierSkillTests;
	UJamCartridge* C = LoadPreset(*this, TEXT("hockey.regular"));
	if (!C) return false;
	UJamCartridge* E1 = Copy(*C);   // lane A121's neutral block
	E1->Game.Stick.TakeGraceFrames = 0; E1->Game.Skater.ReverseBrakeDecel = 20; E1->Game.Skater.bBurstOwnStop = false; E1->Game.Skater.BurstRestFrames = 0; E1->Game.Skater.SpinExposedTail = 0;   // lane A128: and before its two keys
	FScript StopAt6 = DefaultGo();
	StopAt6.BrakeAtM = 6.0;
	const FShare Cut6 = Share(*C, FScript::Late(0), 200), Spin6 = Share(*C, FScript::Late(1), 200), Deke6 = Share(*C, FScript::Late(2), 200), Stop6 = Share(*C, StopAt6, 200);
	const FShare Spin4 = Share(*C, FScript::Late(1, 4.0), 200), Deke4 = Share(*C, FScript::Late(2, 4.0), 200);
	const FShare Cut6n = Share(*E1, FScript::Late(0), 200), Spin6n = Share(*E1, FScript::Late(1), 200), Deke6n = Share(*E1, FScript::Late(2), 200);
	AddInfo(FString::Printf(TEXT("LATE pro from 6 m, the cut alone: %s"), *Cut6.Line()));
	AddInfo(FString::Printf(TEXT("LATE pro from 6 m, the spin with the cut: %s"), *Spin6.Line()));
	AddInfo(FString::Printf(TEXT("LATE pro from 6 m, the deke tap with the cut: %s"), *Deke6.Line()));
	AddInfo(FString::Printf(TEXT("LATE pro from 6 m, the stop-and-go: %s"), *Stop6.Line()));
	AddInfo(FString::Printf(TEXT("LATE pro from 4 m, the spin with the cut: %s"), *Spin4.Line()));
	AddInfo(FString::Printf(TEXT("LATE pro from 4 m, the deke tap with the cut: %s"), *Deke4.Line()));
	AddInfo(FString::Printf(TEXT("LATE pro from 6 m under lane A121's neutral block: the cut alone: %s"), *Cut6n.Line()));
	AddInfo(FString::Printf(TEXT("LATE pro from 6 m under lane A121's neutral block: the spin with the cut: %s"), *Spin6n.Line()));
	AddInfo(FString::Printf(TEXT("LATE pro from 6 m under lane A121's neutral block: the deke tap with the cut: %s"), *Deke6n.Line()));
	TestEqual(TEXT("every scene set up"), Cut6.Ends[Setup] + Spin6.Ends[Setup] + Deke6.Ends[Setup] + Stop6.Ends[Setup] + Spin4.Ends[Setup] + Deke4.Ends[Setup], 0);
	// The brief's bar: from 6 m the carrier passes a pro at least one time in three (measured: the spin 100, the deke 56.5, the cut alone 64.5).
	TestTrue(FString::Printf(TEXT("from 6 m the spin with the cut passes a pro at least one time in three (%.1f %%)"), 100.0 * Spin6.PastShare()), Spin6.PastShare() >= 1.0 / 3.0);
	TestTrue(FString::Printf(TEXT("from 6 m the deke tap with the cut passes a pro at least one time in three (%.1f %%)"), 100.0 * Deke6.PastShare()), Deke6.PastShare() >= 1.0 / 3.0);
	// Lane A128 (skater.spin.exposed_frames): the spin has a price: from 6 m it is an answer, not the sure one (100 % before; Jam.Core.Movement.SpinPrice holds the band).
	TestTrue(FString::Printf(TEXT("the spin is an answer, not the sure one (%.1f; the cut alone %.1f)"), 100.0 * Spin6.PastShare(), 100.0 * Cut6.PastShare()), Spin6.PastShare() <= 0.70);
	TestTrue(FString::Printf(TEXT("late, a stop is the wrong answer (%.1f against the cut alone %.1f)"), 100.0 * Stop6.PastShare(), 100.0 * Cut6.PastShare()), Stop6.PastShare() <= Cut6.PastShare() - 0.20);
	TestTrue(FString::Printf(TEXT("inside 4 m nothing answers more than one time in two (the spin %.1f, the deke %.1f)"), 100.0 * Spin4.PastShare(), 100.0 * Deke4.PastShare()), Spin4.PastShare() <= 0.5 && Deke4.PastShare() <= 0.5);
	return true;
}

// Lane A128 (track F2, evolution 3): the standing start (game.skater.burst.rest_frames). A skater that has been at rest (under 1 m/s for rest_frames) has
// earned its first step: after a faceoff, standing, lying. Never on a charge already under way. And UJamSim::Restart forgets the burst of the run before.
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamMovementStandingStart, "Jam.Core.Movement.StandingStart", JamCarrierSkillTests::Flags)
bool FJamMovementStandingStart::RunTest(const FString& Parameters)
{
	using namespace JamCarrierSkillTests;
	UJamCartridge* C = LoadPreset(*this, TEXT("hockey.regular"));
	if (!C) return false;
	const FJamGameConfig& G = C->Game;
	TestEqual(TEXT("game.skater.burst.rest_frames is 6 when the key is absent"), G.Skater.BurstRestFrames, 6);
	FJamGameConfig Off = G;
	Off.Skater.BurstRestFrames = 0;
	// The human alone (everyone else parked). Stand: frames it stands first (0 = straight out of the faceoff); GlideMps > 0: it glides at that speed with no
	// input for Stand frames instead. Then W is held: frames to 8 m/s, the most BurstLeft seen, the rest counter when W went down.
	struct FStart { int32 To8 = -1, Armed = 0, RestAtGo = 0; double V0 = 0.0; };
	auto Start = [](const FJamGameConfig& Cfg, int32 Stand, double GlideMps) -> FStart
	{
		FStart R;
		UJamSim* Sim = NewObject<UJamSim>();
		Sim->Init(Cfg, 1);
		Sim->SkipFaceoff();
		const int32 Me = Sim->GetHumanIndex();
		const int32 N = Sim->GetSkaters().Num();
		for (int32 i = 0; i < N; ++i) if (i != Me) Sim->SetSkater(i, FVector2D(-40.0 + i * 1.5, 19.0), FVector2D::ZeroVector, 0);
		Sim->SetSkater(Me, FVector2D(-30, 0), FVector2D(GlideMps, 0), 0);
		Sim->SetPuck(FVector2D(30, 19), FVector2D::ZeroVector);
		TArray<FJamInput> In;
		In.SetNum(N);
		for (int32 F = 0; F < Stand; ++F) Sim->Step(In);
		R.RestAtGo = Sim->GetSkaters()[Me].RestFrames;
		R.V0 = Sim->GetSkaters()[Me].Vel.Size();
		In[Me].Move = FVector2D(1, 0);
		for (int32 F = 1; F <= 120 && R.To8 < 0; ++F)
		{
			Sim->Step(In);
			R.Armed = FMath::Max(R.Armed, Sim->GetSkaters()[Me].BurstLeft);
			if (Sim->GetSkaters()[Me].Vel.Size() >= 7.99) R.To8 = F;
		}
		return R;
	};
	const FStart Stood = Start(G, 30, 0.0), Draw = Start(G, 0, 0.0), StoodOff = Start(Off, 30, 0.0), Glide = Start(G, 12, 6.0), GlideOff = Start(Off, 12, 6.0);
	AddInfo(FString::Printf(TEXT("STANDING 0 to 8 m/s: after standing 30 frames %d frames (burst %d), straight out of the faceoff %d (burst %d), with burst.rest_frames 0: %d (burst %d)"),
		Stood.To8, Stood.Armed, Draw.To8, Draw.Armed, StoodOff.To8, StoodOff.Armed));
	AddInfo(FString::Printf(TEXT("STANDING a charge under way (gliding at %.1f m/s when W goes down): to 8 m/s in %d frames (burst %d); with burst.rest_frames 0: %d (burst %d)"),
		Glide.V0, Glide.To8, Glide.Armed, GlideOff.To8, GlideOff.Armed));
	// The brief's bar: 0 to 8 m/s from rest in 26 frames or fewer (41 before, 23 with lane A93's burst for everyone).
	TestTrue(FString::Printf(TEXT("from rest 0 to 8 m/s takes 26 frames or fewer (%d)"), Stood.To8), Stood.To8 > 0 && Stood.To8 <= 26);
	TestTrue(FString::Printf(TEXT("straight out of the faceoff 0 to 8 m/s takes 26 frames or fewer (%d)"), Draw.To8), Draw.To8 > 0 && Draw.To8 <= 26);
	TestEqual(TEXT("the standing skater's burst is the whole burst"), Stood.Armed, G.Skater.BurstFrames);
	TestEqual(TEXT("the rest counter is full after standing"), Stood.RestAtGo, G.Skater.BurstRestFrames);
	TestTrue(FString::Printf(TEXT("burst.rest_frames 0: the standing start is lane A121's (35..45 frames: %d), no burst"), StoodOff.To8), StoodOff.To8 >= 35 && StoodOff.To8 <= 45 && StoodOff.Armed == 0 && StoodOff.RestAtGo == 0);
	TestEqual(TEXT("never on a charge already under way: no burst"), Glide.Armed, 0);
	TestEqual(TEXT("a charge under way is the same charge with burst.rest_frames 0"), Glide.To8, GlideOff.To8);
	// Restart forgets the burst that was running (lane A121's finding): start a burst, restart, nothing is left of it.
	{
		UJamSim* Sim = NewObject<UJamSim>();
		Sim->Init(G, 1);
		Sim->SkipFaceoff();
		const int32 Me = Sim->GetHumanIndex();
		TArray<FJamInput> In;
		In.SetNum(Sim->GetSkaters().Num());
		In[Me].Move = FVector2D(1, 0);
		for (int32 F = 0; F < 12; ++F) Sim->Step(In);
		const int32 Running = Sim->GetSkaters()[Me].BurstLeft;
		Sim->Restart();
		int32 Left = 0;
		for (const FJamSkaterState& S : Sim->GetSkaters()) Left += S.BurstLeft + S.SpinRecoverLeft;
		TestTrue(FString::Printf(TEXT("a burst was running before the restart (%d frames left)"), Running), Running > 0);
		TestEqual(TEXT("Restart leaves no burst and no recovery running"), Left, 0);
	}
	// The counter is in the lockstep hash: the same standing frame hashes differently with the rule and without.
	{
		UJamSim* A = NewObject<UJamSim>();
		UJamSim* B = NewObject<UJamSim>();
		A->Init(G, 1); A->SkipFaceoff();
		B->Init(Off, 1); B->SkipFaceoff();
		TestTrue(TEXT("RestFrames is hashed (a standing skater under the rule against none)"), A->StateHash() != B->StateHash());
	}
	return true;
}

// Lane A128 (track F2, evolution 3): the spin's price (game.skater.spin.exposed_frames). For the last exposed_frames frames of a spin the body has come
// round: nothing shields the puck from a stick; with 0 the whole spin shields. The carry scene: the spin with the cut is no longer the sure answer from 6 m.
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamMovementSpinPrice, "Jam.Core.Movement.SpinPrice", JamCarrierSkillTests::Flags)
bool FJamMovementSpinPrice::RunTest(const FString& Parameters)
{
	using namespace JamCarrierSkillTests;
	UJamCartridge* C = LoadPreset(*this, TEXT("hockey.regular"));
	if (C) { C->Game.Stick.PickupArcM = 0.0; C->Game.Stick.bPickupBody = false; C->Game.Stick.PickupRingM = 0.0; }   // lane A218: and the human's ring (the track's neutral)   // lane A208: re-staged at game.stick.pickup's neutral: this scene measures the lift in the spin's exposed end; the loose puck's pickup has its own (Jam.Core.Possession.*)
	if (!C) return false;
	TestEqual(TEXT("game.skater.spin.exposed_frames is 5 when the key is absent"), C->Game.Skater.SpinExposedTail, 5);
	TestEqual(TEXT("the recovery after the spin is off (code only)"), C->Game.Skater.SpinRecoveryFrames, 0);
	FJamGameConfig On = C->Game, Off = C->Game;
	Off.Skater.SpinExposedTail = 0;
	// The rule: the carrier stands with the puck ahead, a defender right behind it. The carrier spins; the defender lifts when the spin has Left frames to
	// run (0 = the frame after its last). True when the carrier keeps the puck.
	auto LiftAtSpinLeft = [&](const FJamGameConfig& Cfg, int32 Left, int32& OutLeftSeen) -> bool
	{
		int32 Me = -1, Def = -1;
		UJamSim* Sim = ShieldScene(Cfg, 0.0, FVector2D(1, 0), FVector2D(-1.6, 0), Me, Def);
		TArray<FJamInput> In;
		In.SetNum(Sim->GetSkaters().Num());
		In[Me].Stick = FVector2D(1, 0);
		In[Me].bSpin = true;
		Sim->Step(In);
		In[Me].bSpin = false;
		// Keeps() steps one frame before the press: stop one frame early.
		for (int32 F = 0; F < 200 && Sim->GetSkaters()[Me].SpinFrames > Left + 1; ++F) Sim->Step(In);
		OutLeftSeen = Sim->GetSkaters()[Me].SpinFrames;
		if (Sim->CarrierIndex() != Me) return false;
		return Keeps(Sim, Me, Def, FVector2D(1, 0), true);
	};
	const int32 Tail = On.Skater.SpinExposedTail;
	int32 SeenMid = 0, SeenTail = 0, SeenTailOff = 0, SeenEdge = 0, SeenAfter = 0;
	const bool bMid = LiftAtSpinLeft(On, Tail + 6, SeenMid), bTail = LiftAtSpinLeft(On, 2, SeenTail), bTailOff = LiftAtSpinLeft(Off, 2, SeenTailOff);
	const bool bEdge = LiftAtSpinLeft(On, Tail + 1, SeenEdge), bAfter = LiftAtSpinLeft(On, -1, SeenAfter);
	AddInfo(FString::Printf(TEXT("SPINPRICE the lift from behind, the carrier keeps the puck: mid-spin %d, in the exposed end %d, the same frame with exposed_frames 0 %d, one frame before the exposed end %d, after the spin %d"),
		bMid ? 1 : 0, bTail ? 1 : 0, bTailOff ? 1 : 0, bEdge ? 1 : 0, bAfter ? 1 : 0));
	TestEqual(TEXT("the scene: the lift comes with the spin's frames it names"), SeenTail, 3);
	TestTrue(TEXT("a lift in the middle of the spin is refused (the body is between)"), bMid);
	TestFalse(TEXT("a lift in the spin's exposed end takes the puck"), bTail);
	TestTrue(TEXT("spin.exposed_frames 0: the same lift is refused, as before the lane"), bTailOff);
	TestTrue(TEXT("one frame before the exposed end the body is still between"), bEdge);
	TestTrue(TEXT("after the spin the body shields as for any carrier (the defender is behind it)"), bAfter);
	// The carry scene (pro, 200 seeds; FJamCarryDrill::Late): the spin with the cut from 6 m and from 5 m, with the price and without; the deke tap; the stop at 8 m.
	UJamCartridge* N = Copy(*C);
	N->Game.Skater.SpinExposedTail = 0;
	FScript At8 = DefaultGo();
	At8.BrakeAtM = 8.0;
	const FShare Spin6 = Share(*C, FScript::Late(1), 200), Spin5 = Share(*C, FScript::Late(1, 5.0), 200), Spin7 = Share(*C, FScript::Late(1, 7.0), 200), Deke6 = Share(*C, FScript::Late(2), 200), Stop8 = Share(*C, At8, 200);
	const FShare Spin6n = Share(*N, FScript::Late(1), 200), Spin5n = Share(*N, FScript::Late(1, 5.0), 200), Deke6n = Share(*N, FScript::Late(2), 200);
	AddInfo(FString::Printf(TEXT("SPINPRICE pro from 6 m, the spin with the cut: %s"), *Spin6.Line()));
	AddInfo(FString::Printf(TEXT("SPINPRICE pro from 5 m, the spin with the cut: %s"), *Spin5.Line()));
	AddInfo(FString::Printf(TEXT("SPINPRICE pro from 7 m, the spin with the cut: %s"), *Spin7.Line()));
	AddInfo(FString::Printf(TEXT("SPINPRICE pro from 6 m, the deke tap with the cut: %s"), *Deke6.Line()));
	AddInfo(FString::Printf(TEXT("SPINPRICE pro the stop begun at 8 m: %s"), *Stop8.Line()));
	AddInfo(FString::Printf(TEXT("SPINPRICE pro from 6 m, the spin with the cut, spin.exposed_frames 0: %s"), *Spin6n.Line()));
	AddInfo(FString::Printf(TEXT("SPINPRICE pro from 5 m, the spin with the cut, spin.exposed_frames 0: %s"), *Spin5n.Line()));
	AddInfo(FString::Printf(TEXT("SPINPRICE pro from 6 m, the deke tap with the cut, spin.exposed_frames 0: %s"), *Deke6n.Line()));
	TestEqual(TEXT("every scene set up"), Spin6.Ends[Setup] + Spin5.Ends[Setup] + Spin7.Ends[Setup] + Deke6.Ends[Setup] + Stop8.Ends[Setup] + Spin6n.Ends[Setup] + Spin5n.Ends[Setup], 0);
	// The brief's bars. Measured on sweep 2: 6 m 53.0 (99.5 with 0), 5 m 53.5 (60.0 with 0), the deke tap 52.0, the stop at 8 m 100.
	// Lane A185: 53 % before the faster defender, 48.5 % after it.
	TestTrue(FString::Printf(TEXT("from 6 m the spin with the cut passes a pro 45 to 70 %% (%.1f %%)"), 100.0 * Spin6.PastShare()), Spin6.PastShare() >= 0.45 && Spin6.PastShare() <= 0.70);
	TestTrue(FString::Printf(TEXT("the price is worth at least 30 points at 6 m (%.1f against %.1f with exposed_frames 0)"), 100.0 * Spin6.PastShare(), 100.0 * Spin6n.PastShare()), Spin6.PastShare() <= Spin6n.PastShare() - 0.30);
	// The brief asked under 50 % from 5 m: the stick's price reaches 53.5 (the losses there are body checks, which no shield rule moves); held at 60.
	TestTrue(FString::Printf(TEXT("from 5 m the spin with the cut passes a pro at most 60 %% (%.1f %%; the brief's bar is under 50)"), 100.0 * Spin5.PastShare()), Spin5.PastShare() <= 0.60);
	TestTrue(FString::Printf(TEXT("the deke tap stays near its 56 %% (%.1f %%)"), 100.0 * Deke6.PastShare()), Deke6.PastShare() >= 0.46 && Deke6.PastShare() <= 0.66);
	TestTrue(FString::Printf(TEXT("the stop begun at 8 m stays at 90 %% or more (%.1f %%; 95 before lane A185's faster defender)"), 100.0 * Stop8.PastShare()), Stop8.PastShare() >= 0.90);
	TestEqual(TEXT("the price is the spin's alone: the deke tap is the same carry with spin.exposed_frames 0"), Deke6.Ends[Past], Deke6n.Ends[Past]);
	return true;
}

// Outside the gate (Bar.*): the carry scene over the keys and the script's numbers. Rows come from Game/logs/a102/sweep.txt when it exists (one row a line:
// "name | key=value, key=value"; # starts a comment), so one build serves every sweep; without the file, the rows of docs/experiments/MOVEMENT-2.md section 3.
// Keys of the game: burst.frames, burst.accel_mult, reverse_brake_decel, brake_reach (code only), carry_reach_mult, carry_speed_mult, body_shield, passive_take,
// sweep.shield_frames, lift_range_m. Keys of the script: brake_at, cut, go_below, stick_away, stop, carry, defender_m, spread, stick_deg.
// Keys of the run: seeds, straight (0 = skip that arm), level (0 rookie, 1 pro, 2 all_star), trace (a seed to print frame by frame).
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamMovementStopAndGoSweep, "Bar.Movement.StopAndGoSweep", JamCarrierSkillTests::Flags)
bool FJamMovementStopAndGoSweep::RunTest(const FString& Parameters)
{
	using namespace JamCarrierSkillTests;
	UJamCartridge* Base = LoadPreset(*this, TEXT("hockey.regular"));
	if (!Base) return false;
	TArray<FString> Rows;
	const FString File = FPaths::Combine(FPaths::ProjectDir(), TEXT("logs/a102/sweep.txt")), File2 = FPaths::Combine(FPaths::ProjectDir(), TEXT("logs/a121/sweep.txt")), File3 = FPaths::Combine(FPaths::ProjectDir(), TEXT("logs/a128/sweep.txt"));
	// Lane A147: its own rows first; JAM_SWEEP_FILE names another file (so two or three sweeps can run side by side, one process each).
	const FString EnvFile = FPlatformMisc::GetEnvironmentVariable(TEXT("JAM_SWEEP_FILE")), File4 = FPaths::Combine(FPaths::ProjectDir(), TEXT("logs/a147/sweep.txt"));
	if (!(!EnvFile.IsEmpty() && FFileHelper::LoadFileToStringArray(Rows, *EnvFile)) && !FFileHelper::LoadFileToStringArray(Rows, *File4)
		&& !FFileHelper::LoadFileToStringArray(Rows, *File3) && !FFileHelper::LoadFileToStringArray(Rows, *File2) && !FFileHelper::LoadFileToStringArray(Rows, *File))
	{
		Rows = {
			TEXT("defaults |"),
			TEXT("body_shield false | body_shield=0"),
			TEXT("passive_take true | passive_take=1"),
			TEXT("the game before the lane | body_shield=0, passive_take=1"),
			TEXT("the brief's script: brake at 5 m | brake_at=5"),
			TEXT("no first-step burst | burst.frames=0"),
			TEXT("no reverse brake | reverse_brake_decel=0"),
			TEXT("the blade stays ahead (no mouse) | stick_away=0"),
			TEXT("the cut without the stop | stop=0"),
			TEXT("rookie | level=0"),
			TEXT("all_star | level=2"),
		};
	}
	const TCHAR* Levels[3] = { TEXT("rookie"), TEXT("pro"), TEXT("all_star") };
	for (const FString& Raw : Rows)
	{
		FString Line = Raw.TrimStartAndEnd();
		if (Line.IsEmpty() || Line.StartsWith(TEXT("#"))) continue;
		FString Name = Line, Spec;
		Line.Split(TEXT("|"), &Name, &Spec);
		Name.TrimStartAndEndInline();
		UJamCartridge* C = Copy(*Base);
		FJamGameConfig& G = C->Game;
		FScript Go = DefaultGo();
		int32 Seeds = 200, Level = 1, TraceSeed = 0, StandingRows = 0, TraceSeed2 = 0, TraceSeed3 = 0;
		bool bStraight = true, bListEnds = false;
		TArray<FString> Pairs;
		Spec.ParseIntoArray(Pairs, TEXT(","), true);
		for (const FString& Pair : Pairs)
		{
			FString K, VS;
			if (!Pair.Split(TEXT("="), &K, &VS)) continue;
			K.TrimStartAndEndInline();
			const double V = FCString::Atod(*VS.TrimStartAndEnd());
			if (K == TEXT("burst.frames")) G.Skater.BurstFrames = FMath::RoundToInt32(V);
			else if (K == TEXT("burst.own_stop")) G.Skater.bBurstOwnStop = V != 0.0;                 // lane A121
			else if (K == TEXT("burst.carry_accel_mult")) G.Skater.BurstCarryAccelMult = V;         // lane A121 (code only)
			else if (K == TEXT("take_grace")) G.Stick.TakeGraceFrames = FMath::RoundToInt32(V);     // lane A121
			else if (K == TEXT("miss_recovery")) G.Stick.MissRecoveryFrames = FMath::RoundToInt32(V);   // lane A152
			else if (K == TEXT("poke_assist")) G.Stick.PokeAssistDeg = V;                             // lane A152
			else if (K == TEXT("burst.rest_frames")) G.Skater.BurstRestFrames = FMath::RoundToInt32(V);         // lane A128
			else if (K == TEXT("burst.rest_hold")) G.Skater.BurstRestHoldMps = V;                             // lane A128 (code only)
			else if (K == TEXT("burst.rest_push")) G.Skater.bBurstRestPushOff = V != 0.0;                     // lane A128 (code only)
			else if (K == TEXT("spin.exposed_head")) G.Skater.SpinExposedHead = FMath::RoundToInt32(V);       // lane A128 (code only)
			else if (K == TEXT("burst.rest_burst")) G.Skater.BurstRestBurstFrames = FMath::RoundToInt32(V);   // lane A128 (code only)
			else if (K == TEXT("spin.recovery_frames")) G.Skater.SpinRecoveryFrames = FMath::RoundToInt32(V); // lane A128
			else if (K == TEXT("spin.recovery_accel")) G.Skater.SpinRecoveryAccelMult = V;                    // lane A128 (code only)
			else if (K == TEXT("spin.exposed_tail")) G.Skater.SpinExposedTail = FMath::RoundToInt32(V);       // lane A128 (code only)
			else if (K == TEXT("spin.stability")) G.Contact.SpinStability = V;                                // lane A128 (the contact family's key, read only here)
			else if (K == TEXT("ends")) bListEnds = V != 0.0;                                                 // lane A128: list the seeds that did not pass
			else if (K == TEXT("trace2")) TraceSeed2 = FMath::RoundToInt32(V);
			else if (K == TEXT("trace3")) TraceSeed3 = FMath::RoundToInt32(V);
			else if (K == TEXT("standing")) StandingRows = FMath::RoundToInt32(V);                            // lane A128: also print 0 to 8 m/s from rest
			else if (K == TEXT("answer")) Go.Answer = FMath::RoundToInt32(V);                       // lane A121: 1 = the spin, 2 = the deke tap, with the cut
			else if (K == TEXT("second")) Go.SecondMove = FMath::RoundToInt32(V);                   // lane A147: the second move (0 none, 1 the cut back, 2 stop and cut back)
			else if (K == TEXT("second_after")) Go.SecondAfter = FMath::RoundToInt32(V);            // lane A147
			else if (K == TEXT("second_gap")) Go.SecondGapM = V;                                    // lane A147
			else if (K == TEXT("second_wait")) Go.SecondWait = FMath::RoundToInt32(V);              // lane A147: frames of the footrace before the second move
			else if (K == TEXT("second_lead_min")) Go.SecondLeadMinM = V;                           // lane A147
			else if (K == TEXT("second_gain")) Go.SecondGainM = V;                                  // lane A147: the gain along the attack under which the footrace is called
			else if (K == TEXT("second_max")) Go.SecondMax = FMath::RoundToInt32(V);                // lane A147: answers a carry
			else if (K == TEXT("second_stop")) Go.SecondStopMps = V;                                // lane A147: how slow the second stop goes
			else if (K == TEXT("second_cut")) Go.SecondCutDeg = V;                                  // lane A147
			else if (K == TEXT("burst.rest_kept")) G.Skater.BurstRestKeptMps = V;                   // lane A147 (code only)
			else if (K == TEXT("spin.frames")) G.Skater.SpinFrames = FMath::RoundToInt32(V);
			else if (K == TEXT("spin.speed_mult")) G.Skater.SpinSpeedMult = V;
			else if (K == TEXT("deke.offset_m")) G.Stick.DekeOffsetM = V;
			else if (K == TEXT("deke.commit_frames")) G.Stick.DekeCommitFrames = FMath::RoundToInt32(V);
			else if (K == TEXT("burst.accel_mult")) G.Skater.BurstAccelMult = V;
			else if (K == TEXT("reverse_brake_decel")) G.Skater.ReverseBrakeDecel = V;
			else if (K == TEXT("brake_reach")) G.Stick.BrakeReachMult = V;
			else if (K == TEXT("carry_reach_mult")) G.Stick.CarryReachMult = V;
			else if (K == TEXT("carry_speed_mult")) G.Skater.CarrySpeedMult = V;
			else if (K == TEXT("body_shield")) G.Stick.bBodyShield = V != 0.0;
			else if (K == TEXT("passive_take")) { G.Stick.bPassiveTake = V != 0.0; G.Stick.bTeammateTouchTakes = V != 0.0; }
			else if (K == TEXT("sweep.shield_frames")) G.Stick.SweepShieldFrames = FMath::RoundToInt32(V);
			else if (K == TEXT("lift_range_m")) G.Stick.LiftRangeM = V;
			else if (K == TEXT("brake_at")) Go.BrakeAtM = V;
			else if (K == TEXT("cut")) Go.CutDeg = V;
			else if (K == TEXT("go_below")) Go.GoBelowMps = V;
			else if (K == TEXT("stick_away")) Go.bStickAway = V != 0.0;
			else if (K == TEXT("stop")) Go.bBrake = V != 0.0;
			else if (K == TEXT("carry")) Go.CarryMps = V;
			else if (K == TEXT("defender_m")) Go.DefenderM = V;
			else if (K == TEXT("spread")) Go.Spread = V;
			else if (K == TEXT("stick_deg")) Go.StickDegPerFrame = V;
			else if (K == TEXT("seeds")) Seeds = FMath::Clamp(FMath::RoundToInt32(V), 1, 2000);
			else if (K == TEXT("straight")) bStraight = V != 0.0;
			else if (K == TEXT("level")) Level = FMath::Clamp(FMath::RoundToInt32(V), 0, 2);
			else if (K == TEXT("trace")) TraceSeed = FMath::RoundToInt32(V);
			else AddError(FString::Printf(TEXT("sweep row '%s': unknown key '%s'"), *Name, *K));
		}
		FScript Straight = Go;
		Straight.bStopAndGo = false;
		const FShare A = Share(*C, Go, Seeds, Levels[Level]);
		if (bStraight)
		{
			const FShare B = Share(*C, Straight, Seeds, Levels[Level]);
			AddInfo(FString::Printf(TEXT("SWEEP %s | go %.1f | straight %.1f | gap %.1f | go: %s | straight: %s"), *Name, 100.0 * A.PastShare(), 100.0 * B.PastShare(), 100.0 * (A.PastShare() - B.PastShare()), *A.Line(), *B.Line()));
		}
		else AddInfo(FString::Printf(TEXT("SWEEP %s | go %.1f | go: %s"), *Name, 100.0 * A.PastShare(), *A.Line()));
		if (StandingRows > 0)
		{
			// Lane A128: the standing start under this row's keys: the human alone, at rest for 30 frames, then W held: frames to 6 m/s and to 8 m/s.
			UJamSim* Sim = NewObject<UJamSim>();
			Sim->Init(G, 1);
			Sim->SkipFaceoff();
			const int32 Me = Sim->GetHumanIndex();
			const int32 N = Sim->GetSkaters().Num();
			for (int32 i = 0; i < N; ++i) Sim->SetSkater(i, FVector2D(-40.0 + i * 1.5, 19.0), FVector2D::ZeroVector, 0);
			Sim->SetSkater(Me, FVector2D(-30, 0), FVector2D::ZeroVector, 0);
			TArray<FJamInput> In;
			In.SetNum(N);
			for (int32 F = 0; F < 30; ++F) Sim->Step(In);
			In[Me].Move = FVector2D(1, 0);
			int32 To6 = -1, To8 = -1;
			for (int32 F = 1; F <= 120 && To8 < 0; ++F)
			{
				Sim->Step(In);
				const double Vm = Sim->GetSkaters()[Me].Vel.Size();
				if (To6 < 0 && Vm >= 6.0) To6 = F;
				if (Vm >= 8.0) To8 = F;
			}
			AddInfo(FString::Printf(TEXT("SWEEP %s | standing start: 0 to 6 m/s in %d frames, 0 to 8 m/s in %d frames"), *Name, To6, To8));
		}
		if (bListEnds)
		{
			FString List;
			for (int32 Seed = 1; Seed <= Seeds; ++Seed)
			{
				const FRun R = Carry(*C, static_cast<uint64>(Seed), Go, Levels[Level]);
				if (R.End != Past) List += FString::Printf(TEXT(" %d:%s"), Seed, FJamCarryDrill::EndName(R.End));
			}
			AddInfo(FString::Printf(TEXT("SWEEP %s | not past:%s"), *Name, *List));
		}
		for (const int32 TS : { TraceSeed, TraceSeed2, TraceSeed3 })
		{
			if (TS <= 0) continue;
			TArray<FString> Trace;
			Carry(*C, static_cast<uint64>(TS), Go, Levels[Level], &Trace);
			for (const FString& L : Trace) AddInfo(FString::Printf(TEXT("TRACE %s seed %d: %s"), *Name, TS, *L));
		}
	}
	return true;
}

// ---- Lane A147 (track F2, evolution 4): the first step by hand (docs/experiments/MOVEMENT-5.md section 4) ---------------------------------------------
namespace JamCarrierSkillTests
{
	// One start by hand, the human alone or with one opposing skater that bumps or checks it. Frames from the go (the first frame the human can act and
	// pushes) to 8 m/s, the metres covered in the first 30 frames of the push, the burst it had, the rest counter and the speed when it went.
	struct FFirstStep { int32 To8 = -1, Burst = 0, RestAtGo = 0, DownFrames = 0, StumbleFrames = 0; double VAtGo = 0.0, M30 = 0.0; };
	enum EFirstStep { FsRest, FsBumpAlong, FsBumpAcross, FsBumpWait, FsPivot180, FsPivot135, FsPivot90, FsTap, FsHitStanding, FsHitSkating, FsNudged, FsFaceoff, FsGlideIn, FsBumpLate, FsCount };
	inline const TCHAR* FirstStepName(int32 K)
	{
		static const TCHAR* N[FsCount] = { TEXT("from rest (30 frames), W"), TEXT("at rest, bumped to 2 m/s along the push, W at once"), TEXT("at rest, bumped to 2 m/s across the push, W at once"),
			TEXT("at rest, bumped to 2 m/s, W six frames later"), TEXT("at rest, the push straight behind the facing (180 degrees)"), TEXT("at rest, the push 135 degrees off the facing"),
			TEXT("at rest, the push 90 degrees off the facing"), TEXT("at rest, one frame of W tapped, W held three frames later"), TEXT("standing, body-checked by a skater at 9 m/s, W held from the hit"),
			TEXT("skating at 8 m/s, body-checked head-on, W held throughout"), TEXT("at rest, run into by a gliding skater (no check), W from the contact"), TEXT("the faceoff: W held through the countdown, from the drop"),
			TEXT("a charge let go: W for 10 frames, coasting 12 frames, W again (never at rest)"), TEXT("at rest, bumped to 2 m/s, W 24 frames later") };
		return K >= 0 && K < FsCount ? N[K] : TEXT("?");
	}
	FFirstStep FirstStep(const FJamGameConfig& Cfg, int32 Kind)
	{
		FFirstStep R;
		UJamSim* Sim = NewObject<UJamSim>();
		Sim->Init(Cfg, 1);
		if (Kind != FsFaceoff) Sim->SkipFaceoff();
		const int32 Me = Sim->GetHumanIndex();
		const int32 N = Sim->GetSkaters().Num();
		TArray<FJamInput> In;
		In.SetNum(N);
		int32 Att = -1;
		for (const FJamSkaterState& S : Sim->GetSkaters()) if (S.Team != Sim->GetSkaters()[Me].Team) { Att = S.Index; break; }
		FVector2D Push(1, 0);
		const FVector2D Home(-20, 0);
		const bool bContact = Kind == FsHitStanding || Kind == FsHitSkating || Kind == FsNudged;
		if (Kind != FsFaceoff)
		{
			for (int32 i = 0; i < N; ++i) if (i != Me) Sim->SetSkater(i, FVector2D(-40.0 + i * 1.5, 19.0), FVector2D::ZeroVector, 0);
			Sim->SetSkater(Me, Home, FVector2D::ZeroVector, 0);
			Sim->SetPuck(FVector2D(30, 19), FVector2D::ZeroVector);
			for (int32 F = 0; F < 30; ++F) Sim->Step(In);
			if (Kind == FsGlideIn) { In[Me].Move = FVector2D(1, 0); for (int32 F = 0; F < 10; ++F) Sim->Step(In); In[Me].Move = FVector2D::ZeroVector; for (int32 F = 0; F < 12; ++F) Sim->Step(In); }
		}
		auto Me_ = [&]() -> const FJamSkaterState& { return Sim->GetSkaters()[Me]; };
		int32 Wait = 0;
		switch (Kind)
		{
		case FsBumpAlong: Sim->SetSkater(Me, Me_().Pos, FVector2D(2, 0), Me_().Yaw); break;
		case FsBumpAcross: Sim->SetSkater(Me, Me_().Pos, FVector2D(0, 2), Me_().Yaw); break;
		case FsBumpWait: Sim->SetSkater(Me, Me_().Pos, FVector2D(2, 0), Me_().Yaw); Wait = 6; break;
		case FsBumpLate: Sim->SetSkater(Me, Me_().Pos, FVector2D(2, 0), Me_().Yaw); Wait = 24; break;
		case FsPivot180: Push = FVector2D(-1, 0); break;
		case FsPivot135: Push = FVector2D(-0.7071, 0.7071); break;
		case FsPivot90: Push = FVector2D(0, 1); break;
		case FsTap: In[Me].Move = Push; Sim->Step(In); In[Me].Move = FVector2D::ZeroVector; Wait = 3; break;
		case FsFaceoff: Push = FVector2D(0, 1); break;
		default: break;
		}
		if (bContact && Att >= 0)
		{
			// The opposing skater comes at the human along -x; a check is pressed once in range. The human pushes across (+y), away from the traffic.
			Push = FVector2D(0, 1);
			const double Speed = Kind == FsNudged ? 3.0 : 9.0;
			if (Kind == FsHitSkating) { Sim->SetSkater(Me, Me_().Pos, FVector2D(8, 0), 0); In[Me].Move = FVector2D(1, 0); }
			Sim->SetSkater(Att, Me_().Pos + FVector2D(Kind == FsHitSkating ? 9.0 : 5.0, 0.0), FVector2D(-Speed, 0), UE_DOUBLE_PI);
			bool bHit = false, bPressed = false;
			for (int32 F = 0; F < 90 && !bHit; ++F)
			{
				const double Gap = FVector2D::Distance(Me_().Pos, Sim->GetSkaters()[Att].Pos);
				In[Att] = FJamInput();
				if (Kind != FsNudged) { In[Att].Move = FVector2D(-1, 0); if (!bPressed && Gap < 2.2) { In[Att].bCheck = true; bPressed = true; } }
				const double VBefore = Me_().Vel.Size();
				Sim->Step(In);
				bHit = Me_().IsDown() || Me_().IsStumbling() || FMath::Abs(Me_().Vel.Size() - VBefore) > 0.5;
			}
			In[Att] = FJamInput();
			R.DownFrames = Me_().KnockFrames; R.StumbleFrames = Me_().StumbleFrames;
		}
		for (int32 F = 0; F < Wait; ++F) Sim->Step(In);
		// The key goes down (and stays down). A skater that cannot act yet (down, stumbling, the countdown) holds it until it can.
		In[Me] = FJamInput();
		In[Me].Move = Push;
		for (int32 F = 0; F < 400 && (!Me_().CanAct() || Sim->GetPhase() != EJamSimPhase::Playing); ++F) Sim->Step(In);
		R.RestAtGo = Me_().RestFrames; R.VAtGo = Me_().Vel.Size();
		const double D0 = Me_().DistanceM;
		for (int32 F = 1; F <= 150 && (R.To8 < 0 || F <= 30); ++F)
		{
			Sim->Step(In);
			R.Burst = FMath::Max(R.Burst, Me_().BurstLeft);
			if (R.To8 < 0 && Me_().Vel.Size() >= 7.99) R.To8 = F;
			if (F == 30) R.M30 = Me_().DistanceM - D0;
		}
		return R;
	}
}

// Bar.Movement.FirstStepCases (outside the gate's Jam filter): the brief's item 4, every start a player makes by hand, under the defaults and with
// game.skater.burst.rest_kept_mps 0 (lane A128's rule), and by the kept speed.
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamMovementFirstStepCases, "Bar.Movement.FirstStepCases", JamCarrierSkillTests::Flags)
bool FJamMovementFirstStepCases::RunTest(const FString& Parameters)
{
	using namespace JamCarrierSkillTests;
	UJamCartridge* C = LoadPreset(*this, TEXT("hockey.regular"));
	if (!C) return false;
	for (const double Kept : { 0.0, 2.5, 3.0, 4.0 })
	{
		FJamGameConfig G = C->Game;
		G.Skater.BurstRestKeptMps = Kept;
		for (int32 K = 0; K < FsCount; ++K)
		{
			const FFirstStep R = FirstStep(G, K);
			AddInfo(FString::Printf(TEXT("FIRSTSTEP rest_kept_mps %.1f | %s | to 8 m/s in %d frames, %.2f m in the first 30 frames, burst %d, at the go: %.2f m/s, rest counter %d (down %d, stumble %d frames at the hit)"),
				Kept, FirstStepName(K), R.To8, R.M30, R.Burst, R.VAtGo, R.RestAtGo, R.DownFrames, R.StumbleFrames));
		}
	}
	return true;
}

// Jam.Core.Movement.SecondMove (lane A147, track F2, evolution 4; MOVEMENT-5.md sections 1 and 2): the carrier's second move (the cut back when the first
// move left a footrace) is never worse than one move and takes time-outs away; the brief's bar for it (the stop at 9.5 m 99 % or more with no time-out)
// was NOT reached (97.5 %, 4 time-outs) and is not asserted; its other two are (the stop at 8 m 95 % or more, the straight charge under 20 %). And the
// stop's window is the level's: drill 21's distance for each level passes that level's defender.
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamMovementSecondMove, "Jam.Core.Movement.SecondMove", JamCarrierSkillTests::Flags)
bool FJamMovementSecondMove::RunTest(const FString& Parameters)
{
	using namespace JamCarrierSkillTests;
	UJamCartridge* C = LoadPreset(*this, TEXT("hockey.regular"));
	if (!C) return false;
	FScript One = DefaultGo(), Two = DefaultGo(), At8, Straight;
	Two.SecondMove = FScript().SecondMove;
	// Lane A194 (track F2 evolution 10): one move against two at the window's far edge, 9 m since lane A185 (9.5 m is outside it now: 77 %, where the
	// breakaway's 0.3 moved one move against two by a carry or three).
	One.BrakeAtM = 9.0; Two.BrakeAtM = 9.0;
	Straight.bStopAndGo = false;
	const FShare A = Share(*C, One, 200), B = Share(*C, Two, 200), E = Share(*C, At8, 200), S = Share(*C, Straight, 200);
	AddInfo(FString::Printf(TEXT("SECOND pro stop begun at 9 m, one move: %s"), *A.Line()));
	AddInfo(FString::Printf(TEXT("SECOND pro stop begun at 9 m, with the second move: %s"), *B.Line()));
	{
		// Measured, not the default: the second stop before the cut back. A pro on the shoulder brakes with the carrier; the stop ends under its stick or body.
		FScript Stop2 = DefaultGo();
		Stop2.SecondMove = 2;
		AddInfo(FString::Printf(TEXT("SECOND pro stop begun at 9.5 m, with a second stop before the cut back (measured, not the default): %s"), *Share(*C, Stop2, 200).Line()));
	}
	AddInfo(FString::Printf(TEXT("SECOND pro the drill's own script (the stop at 8 m, the second move armed): %s"), *E.Line()));
	AddInfo(FString::Printf(TEXT("SECOND pro straight charge: %s"), *S.Line()));
	TestTrue(TEXT("the drill's script has a second move"), FScript().SecondMove != 0);
	TestTrue(TEXT("the late answers and lane A102's clean stop stay one move"), FJamCarryDrill::Late(1).SecondMove == 0 && FJamCarryDrill::Late(2).SecondMove == 0 && DefaultGo().SecondMove == 0);
	TestTrue(FString::Printf(TEXT("with the second move the stop begun at 9 m passes a pro at least as often as with one (%.1f %% against %.1f %%)"), 100.0 * B.PastShare(), 100.0 * A.PastShare()), B.PastShare() >= A.PastShare());
	TestTrue(FString::Printf(TEXT("with the second move no more carries time out with the puck kept, one of 200 allowed (%d against %d)"), B.Ends[FJamCarryDrill::Timeout], A.Ends[FJamCarryDrill::Timeout]), B.Ends[FJamCarryDrill::Timeout] <= A.Ends[FJamCarryDrill::Timeout] + 1 || A.Ends[FJamCarryDrill::Timeout] == 0);   // Director at the landing (14 Nov): "no more", not "fewer": 4 against 4 on the merged tree (the lane measured 4 against 5 on its own); a count of four is not a bar. Lane A194: at 9 m (the far edge) 11 against 10 of 200, the same 93.5 % past: one carry is not a bar either (+1)
	TestTrue(FString::Printf(TEXT("the stop begun at 8 m still passes a pro 90 %% or more (%.1f %%; 95 before lane A185's faster defender)"), 100.0 * E.PastShare()), E.PastShare() >= 0.90);
	TestTrue(FString::Printf(TEXT("the straight charge stays under 20 %% (%.1f %%)"), 100.0 * S.PastShare()), S.PastShare() <= 0.20);
	// The window by level: where drill 21 begins its stop against each level's defender.
	for (const TCHAR* Level : { TEXT("rookie"), TEXT("pro"), TEXT("all_star") })
	{
		FScript L;
		L.BrakeAtM = FJamCarryDrill::StopAtForLevel(FName(Level));
		const FShare W = Share(*C, L, 200, Level);
		AddInfo(FString::Printf(TEXT("WINDOW %s, the stop begun at %.1f m (\"%s\"): %s"), Level, L.BrakeAtM, *FJamCarryDrill::CoachLine(1, L.BrakeAtM, UJamSim::SkaterRadius + C->Game.Stick.ReachM), *W.Line()));
		TestTrue(FString::Printf(TEXT("%s: the drill's stop distance (%.1f m) passes that level's defender 95 %% or more (%.1f %%; lane A194: the bar back with the drill at the window's centre)"), Level, L.BrakeAtM, 100.0 * W.PastShare()), W.PastShare() >= 0.95);
	}
	// Lane A201 (track F2 evolution 11): the stop begun on the light of the stop's line (the rule the screen draws, JamCarrierMarks::StopMark), a quarter
	// second after it lights (the hand's lag the rule's ReactSec allows for), passes law 3's defender at pro.
	{
		FScript L;
		L.LightReactFrames = 15;
		const FShare W = Share(*C, L, 200, TEXT("pro"));
		AddInfo(FString::Printf(TEXT("LIGHT pro, the stop begun 15 frames after the line lit: %s"), *W.Line()));
		TestTrue(FString::Printf(TEXT("pro: the stop begun on the light passes 90 %% or more (%.1f %%)"), 100.0 * W.PastShare()), W.PastShare() >= 0.90);
		// Lane A201 (evolution 12, the late hand): a press made while the bar is still lit passes 90 % or more for hands of 12 to 24 frames.
		for (const int32 React : { 12, 18, 24 })
		{
			FScript Lh;
			Lh.LightReactFrames = React; Lh.bOnlyWhileLit = true;
			const FShare Wl = Share(*C, Lh, 200, TEXT("pro"));
			const int32 Invited = Wl.N - Wl.Ends[FJamCarryDrill::Setup];
			const double Pass = Invited > 0 ? static_cast<double>(Wl.Ends[FJamCarryDrill::Past]) / Invited : 0.0;
			AddInfo(FString::Printf(TEXT("LATE pro, a press %d frames after the light, made only while lit: invited %d of %d, past %.1f %% of those"), React, Invited, Wl.N, 100.0 * Pass));
			TestTrue(FString::Printf(TEXT("A201: pro, a %d-frame hand pressing while the bar is lit passes 90 %% or more (%.1f %% of %d; none invited = no late press made)"), React, 100.0 * Pass, Invited), Invited == 0 || Pass >= 0.90);
			if (React <= 18) TestTrue(FString::Printf(TEXT("A201: ... and the bar still invites a %d-frame hand (%d of %d)"), React, Invited, Wl.N), Invited >= Wl.N * 3 / 4);
		}
	}
	// Lane A194: the window's centre since the free skaters are 15 % faster (lane A185): 8.5 m at every level, still five stick lengths.
	TestEqual(TEXT("pro stops at 8.5 m"), FJamCarryDrill::StopAtForLevel(FName(TEXT("pro"))), 8.5);
	TestEqual(TEXT("all_star stops at 8.5 m too (R-0058 point 1: one stop distance at every level)"), FJamCarryDrill::StopAtForLevel(FName(TEXT("all_star"))), 8.5);
	TestEqual(TEXT("rookie stops at 8.5 m"), FJamCarryDrill::StopAtForLevel(FName(TEXT("rookie"))), 8.5);
	TestEqual(TEXT("8.5 m in a player's words: five stick lengths"), FString(FJamCarryDrill::StickLengthsWord(8.5, 1.6)), FString(TEXT("FIVE")));
	TestEqual(TEXT("8 m in a player's words: five stick lengths"), FString(FJamCarryDrill::StickLengthsWord(8.0, 1.6)), FString(TEXT("FIVE")));
	TestEqual(TEXT("12 m in a player's words: eight stick lengths"), FString(FJamCarryDrill::StickLengthsWord(12.0, 1.6)), FString(TEXT("EIGHT")));
	// Lane A201 (evolution 12): the drill's words are what the line teaches now: stop when it turns his colour. One line at 1280 (28 characters or fewer: one line in the caption box).
	TestTrue(TEXT("A201: the drill's line says to stop on the line's colour"), FJamCarryDrill::CoachLine(1, 8.5, 1.6).Contains(TEXT("LINE LIT: STOP")) && FJamCarryDrill::CoachLine(1, 8.5, 1.6).Len() <= 28);
	return true;
}

// Jam.Core.Movement.FirstStepKept (lane A147; game.skater.burst.rest_kept_mps; MOVEMENT-5.md section 4): the first step a skater earned by standing is not
// lost to what is not its own doing (a bump that moves it, a turn on the spot), and never comes on a charge of its own. 0 = lane A128's rule.
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamMovementFirstStepKept, "Jam.Core.Movement.FirstStepKept", JamCarrierSkillTests::Flags)
bool FJamMovementFirstStepKept::RunTest(const FString& Parameters)
{
	using namespace JamCarrierSkillTests;
	UJamCartridge* C = LoadPreset(*this, TEXT("hockey.regular"));
	if (!C) return false;
	const FJamGameConfig& G = C->Game;
	FJamGameConfig Off = G;
	Off.Skater.BurstRestKeptMps = 0.0;
	TestEqual(TEXT("game.skater.burst.rest_kept_mps is 3 when the key is absent"), G.Skater.BurstRestKeptMps, 3.0);
	const FFirstStep Rest = FirstStep(G, FsRest), RestOff = FirstStep(Off, FsRest), Late = FirstStep(G, FsBumpLate), LateOff = FirstStep(Off, FsBumpLate);
	const FFirstStep Turn = FirstStep(G, FsPivot180), TurnOff = FirstStep(Off, FsPivot180), Let = FirstStep(G, FsGlideIn), LetOff = FirstStep(Off, FsGlideIn);
	AddInfo(FString::Printf(TEXT("KEPT from rest: to 8 m/s in %d frames (burst %d); rest_kept_mps 0: %d (burst %d)"), Rest.To8, Rest.Burst, RestOff.To8, RestOff.Burst));
	AddInfo(FString::Printf(TEXT("KEPT at rest, bumped to 2 m/s, W 24 frames later: to 8 m/s in %d frames (burst %d, %.2f m in 30 frames); rest_kept_mps 0: %d (burst %d, %.2f m)"), Late.To8, Late.Burst, Late.M30, LateOff.To8, LateOff.Burst, LateOff.M30));
	AddInfo(FString::Printf(TEXT("KEPT at rest, the push straight behind the facing: to 8 m/s in %d frames (%.2f m in 30 frames); rest_kept_mps 0: %d (%.2f m)"), Turn.To8, Turn.M30, TurnOff.To8, TurnOff.M30));
	AddInfo(FString::Printf(TEXT("KEPT a charge let go and taken up again: to 8 m/s in %d frames (burst %d); rest_kept_mps 0: %d (burst %d)"), Let.To8, Let.Burst, LetOff.To8, LetOff.Burst));
	TestEqual(TEXT("the standing start itself is lane A128's under either value"), Rest.To8, RestOff.To8);
	TestEqual(TEXT("a rested skater that was bumped still has its whole first step 24 frames later"), Late.Burst, G.Skater.BurstFrames);
	TestEqual(TEXT("rest_kept_mps 0 (lane A128's rule): the bump bled the burst away"), LateOff.Burst, 0);
	TestTrue(FString::Printf(TEXT("the kept first step is worth 8 frames or more to 8 m/s after a bump (%d against %d)"), Late.To8, LateOff.To8), Late.To8 > 0 && LateOff.To8 >= Late.To8 + 8);
	TestTrue(FString::Printf(TEXT("turning on the spot is not the push-off: the start straight behind is quicker (%d against %d frames)"), Turn.To8, TurnOff.To8), Turn.To8 > 0 && Turn.To8 < TurnOff.To8);
	TestEqual(TEXT("never on a charge of its own: a charge let go and taken up again has no burst"), Let.Burst, 0);
	TestEqual(TEXT("... and is the same charge under either value"), Let.To8, LetOff.To8);
	return true;
}

// ---- Lane A138 (track I1, R-0053): the sim-and-brain seam, integrated (docs/experiments/INTEGRATION.md) --------------------------------------------------
namespace JamCarrierSkillTests
{
	// How a carry ended, with the contact that ended it told apart: a cross-check's shove from behind (the push along the carrier's facing), a shove from
	// the front or the side, a body check.
	enum EHow { HPast, HLift, HPoke, HShoveBehind, HShoveOther, HChecked, HOther, HTimeout, HowCount };
	struct FHow
	{
		int32 N = 0, H[HowCount] = {}, Lifts = 0, Pokes = 0, Checks = 0, Setup = 0;
		int64 Frames = 0;
		double PastShare() const { return N > 0 ? static_cast<double>(H[HPast]) / N : 0.0; }
		FString Line() const
		{
			return FString::Printf(TEXT("past %d of %d (%.1f %%) | lifted %d, poked %d, shoved from behind %d, shoved front or side %d, checked %d, other %d, timed out with the puck %d | defender presses: lift %d poke %d check %d; %.0f frames a carry%s"),
				H[HPast], N, 100.0 * PastShare(), H[HLift], H[HPoke], H[HShoveBehind], H[HShoveOther], H[HChecked], H[HOther], H[HTimeout], Lifts, Pokes, Checks, N > 0 ? static_cast<double>(Frames) / N : 0.0,
				Setup > 0 ? *FString::Printf(TEXT(" (%d scenes not set up)"), Setup) : TEXT(""));
		}
	};

	// Carry() over Seeds seeds with a profile tune on the brain (nullptr = the level as shipped), each end classified.
	FHow CarryHow(const UJamCartridge& C, const FScript& Script, int32 Seeds, const TCHAR* Level = TEXT("pro"), const char* Tune = nullptr)
	{
		FHow R;
		UJamSim* Sim = NewObject<UJamSim>();
		UJamBrain* Brain = NewObject<UJamBrain>();
		TArray<FJamInput> In;
		for (int32 Seed = 1; Seed <= Seeds; ++Seed)
		{
			FJamCarryDrill D = Script;
			Sim->Init(C.Game, static_cast<uint64>(Seed));
			Sim->SkipFaceoff();
			++R.N;
			if (!D.Stage(*Sim, static_cast<uint64>(Seed))) { ++R.Setup; ++R.H[HOther]; continue; }
			Brain->ApplyCartridge(C, Level);
			if (Tune && *Tune)
			{
				char Err[200] = {};
				JamAI::ApplyDifficultyTune(Tune, Brain->EditParams(), Err, sizeof(Err));
				Brain->SpeedScale = static_cast<float>(Brain->EditParams().SpeedScale);
				Brain->RedSkill = static_cast<float>(Brain->EditParams().RedSkill);
			}
			Brain->ResetBrain();
			In.SetNum(Sim->GetSkaters().Num());
			int32 HitFrame = -1;
			bool bHitCross = false, bHitBehind = false;
			while (D.End == FJamCarryDrill::Running)
			{
				JamAI::FJamAIWorld W;
				JamAI::FJamSimAdapter::BuildWorld(*Sim, W);
				JamAI::FJamAIInput Out[JamAI::kMaxSkaters];
				Brain->Think(W, Out);
				for (FJamInput& I : In) I = FJamInput();
				if (!D.DefenderWaits()) In[D.Def] = ToInput(Out[D.Def]);
				In[D.Me] = D.HumanInput(*Sim);
				D.BeforeStep(*Sim, In[D.Def]);
				const FJamSkaterState& S0 = Sim->GetSkaters()[D.Me];
				const bool bBehind = FVector2D::DotProduct((S0.Pos - Sim->GetSkaters()[D.Def].Pos).GetSafeNormal(), S0.Forward()) > 0.5;
				Sim->Step(In);
				const FJamSkaterState& S1 = Sim->GetSkaters()[D.Me];
				if (S1.ContactBy == D.Def && S1.ContactOutcome >= UJamSim::ContactStumble) { HitFrame = D.Frames; bHitCross = S1.bContactCross; bHitBehind = bBehind; }
				D.AfterStep(*Sim);
			}
			R.Lifts += D.DefLifts; R.Pokes += D.DefPokes; R.Checks += D.DefChecks; R.Frames += D.Frames;
			EHow How = HOther;
			switch (D.End)
			{
			case FJamCarryDrill::Past: How = HPast; break;
			case FJamCarryDrill::Timeout: How = HTimeout; break;
			case FJamCarryDrill::Poke: How = HPoke; break;
			case FJamCarryDrill::Lift: How = HLift; break;
			case FJamCarryDrill::Setup: ++R.Setup; break;
			default: How = HitFrame < 0 ? HOther : !bHitCross ? HChecked : bHitBehind ? HShoveBehind : HShoveOther; break;
			}
			++R.H[How];
		}
		return R;
	}
}

// Bar.Integration.Carry (outside the gate's Jam filter; the brief's item 2): what broke law 3. The carry scene (200 seeds an arm, the real brain) with the
// brain's second evolution on and off, its shield and grace reads on and off, the shove rule on and off: the stop begun at 8 m, at 9.5 m, the straight
// charge, and how each failed carry ended.
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamIntegrationCarry, "Bar.Integration.Carry", JamCarrierSkillTests::Flags)
bool FJamIntegrationCarry::RunTest(const FString& Parameters)
{
	using namespace JamCarrierSkillTests;
	UJamCartridge* C = LoadPreset(*this, TEXT("hockey.regular"));
	if (!C) return false;
	struct FArm { const TCHAR* Name; const char* Tune; bool bShieldShove; double MatchMps; };
	const double M = C->Game.Contact.ShoveBehindMatchMps;
	const FArm Arms[] = {
		{ TEXT("everything on, as the tree stands"), nullptr, true, M },
		{ TEXT("brain2=0 (the brain of evolution 1)"), "brain2=0", true, M },
		{ TEXT("the brain's shield and grace reads off"), "opp.hk_read_shield=0;mate.hk_read_shield=0", true, M },
		{ TEXT("the brain's meant brake off"), "opp.hk_brake_meant=0;mate.hk_brake_meant=0", true, M },
		{ TEXT("the shove rule off (the shields refuse the shove too)"), nullptr, false, M },
		{ TEXT("brain2=0 and the shove rule off (main before the parked landing)"), "brain2=0", false, M },
		{ TEXT("the parked tree: everything on, the thrust whole from behind"), nullptr, true, 0.0 },
		{ TEXT("the parked tree with the reads off: the thrust whole from behind"), "opp.hk_read_shield=0;mate.hk_read_shield=0", true, 0.0 },
		{ TEXT("brain2=0, the shove rule on, the thrust whole from behind"), "brain2=0", true, 0.0 },
		{ TEXT("brain2=0, the shove rule on, the thrust on a back by the closing speed"), "brain2=0", true, 3.0 } };
	FScript At8, At95, Straight;
	At8.BrakeAtM = 8.0; At95.BrakeAtM = 9.5; Straight.bStopAndGo = false;
	const int32 Seeds = 200;
	for (const FArm& A : Arms)
	{
		UJamCartridge* G = Copy(*C);
		G->Game.Contact.bShieldShove = A.bShieldShove;
		G->Game.Contact.ShoveBehindMatchMps = A.MatchMps;
		AddInfo(FString::Printf(TEXT("INTCARRY pro | %s | stop at 8 m: %s"), A.Name, *CarryHow(*G, At8, Seeds, TEXT("pro"), A.Tune).Line()));
		AddInfo(FString::Printf(TEXT("INTCARRY pro | %s | stop at 9.5 m: %s"), A.Name, *CarryHow(*G, At95, Seeds, TEXT("pro"), A.Tune).Line()));
		AddInfo(FString::Printf(TEXT("INTCARRY pro | %s | straight charge: %s"), A.Name, *CarryHow(*G, Straight, Seeds, TEXT("pro"), A.Tune).Line()));
	}
	// The way round the body (the brain's shield read): candidates for "a defender that contains wins when the carrier dawdles, not when he stops and goes".
	// (Build 4, hk_round_max_mps 0 as the default: lead 0 74.5 % at 9.5 m, lead 0.15 71.5 %; max 3 / 5 / 7 m/s 97.0 % each. The default is 3 since.)
	for (const char* Tune : { "opp.hk_round_max_mps=0", "opp.hk_round_max_mps=0;opp.hk_round_lead_s=0", "opp.hk_round_max_mps=3", "opp.hk_round_max_mps=5" })
	{
		for (const TCHAR* Level : { TEXT("pro"), TEXT("all_star") })
		{
			FScript At11 = At95;
			At11.BrakeAtM = 11.0;
			AddInfo(FString::Printf(TEXT("INTROUND %s | %s | stop at 8 m: %s"), Level, ANSI_TO_TCHAR(Tune), *CarryHow(*C, At8, Seeds, Level, Tune).Line()));
			AddInfo(FString::Printf(TEXT("INTROUND %s | %s | stop at 9.5 m: %s"), Level, ANSI_TO_TCHAR(Tune), *CarryHow(*C, At95, Seeds, Level, Tune).Line()));
			AddInfo(FString::Printf(TEXT("INTROUND %s | %s | stop at 11 m: %s"), Level, ANSI_TO_TCHAR(Tune), *CarryHow(*C, At11, Seeds, Level, Tune).Line()));
			AddInfo(FString::Printf(TEXT("INTROUND %s | %s | straight charge: %s"), Level, ANSI_TO_TCHAR(Tune), *CarryHow(*C, Straight, Seeds, Level, Tune).Line()));
		}
	}
	// For the curve lane (CURVE-6: a pro that pokes after 2 frames won the drill): law 3's budget by the levers the curve moves, as the tree stands.
	for (const char* Tune : { "opp.poke_frames=2", "opp.poke_frames=3", "opp.poke_frames=4", "opp.check_min_closing=1", "opp.hunt_radius_m=20", "opp.sprint_share=0.7", "opp.lift_cooldown_frames=45",
		"opp.hunt_radius_m=20;opp.check_min_closing=1;opp.poke_frames=2;opp.sprint_share=0.7;opp.lift_cooldown_frames=45", "opp.hunt_radius_m=20;opp.check_min_closing=1;opp.poke_frames=4;opp.sprint_share=0.7;opp.lift_cooldown_frames=45" })
	{
		AddInfo(FString::Printf(TEXT("INTCURVE pro | %s | stop at 8 m: %s"), ANSI_TO_TCHAR(Tune), *CarryHow(*C, At8, Seeds, TEXT("pro"), Tune).Line()));
		AddInfo(FString::Printf(TEXT("INTCURVE pro | %s | straight charge: %s"), ANSI_TO_TCHAR(Tune), *CarryHow(*C, Straight, Seeds, TEXT("pro"), Tune).Line()));
	}
	// The curve lane's hunt radius moves the stop's window (the pro leaves its creep): where is it then?
	for (const char* Tune : { "opp.hunt_radius_m=8", "opp.hunt_radius_m=12", "opp.hunt_radius_m=20" })
	{
		for (const double At : { 8.0, 9.5, 11.0, 12.0, 13.0 })
		{
			FScript S;
			S.BrakeAtM = At;
			AddInfo(FString::Printf(TEXT("INTHUNT pro | %s | stop at %.1f m: %s"), ANSI_TO_TCHAR(Tune), At, *CarryHow(*C, S, Seeds, TEXT("pro"), Tune).Line()));
		}
	}
	// The spin's exposed end: the share of spins the bot answers (hk_spin_end_share), the spin with the cut from 5, 6 and 7 m.
	for (const char* Tune : { "opp.hk_spin_end_share=0", "opp.hk_spin_end_share=0.25", "opp.hk_spin_end_share=0.4", "opp.hk_spin_end_share=0.5", "opp.hk_spin_end_share=0.6", "opp.hk_spin_end_share=0.75", "opp.hk_spin_end_share=1" })
	{
		for (const double At : { 5.0, 6.0, 7.0 })
		{
			AddInfo(FString::Printf(TEXT("INTSPIN pro | %s | the spin with the cut from %.0f m: %s"), ANSI_TO_TCHAR(Tune), At, *CarryHow(*C, FJamCarryDrill::Late(1, At), Seeds, TEXT("pro"), Tune).Line()));
		}
	}
	// The take grace's same-frame hole, counted over 20 pro matches of three minutes: stick takeaways inside 30 frames of the win, with the cover and without.
	for (const bool bCover : { true, false })
	{
		int32 Under30 = 0, Takeaways = 0;
		FString Notes;
		for (uint64 Seed = 1; Seed <= 20; ++Seed)
		{
			UJamCartridge* Mc = Copy(*C);
			Mc->Game.Rules.ScoreToWin = 99;
			Mc->Game.Rules.bPenalties = false;
			Mc->Game.Stick.bTakeGraceSameFrame = bCover;
			JamAI::FJamSimAdapter Sim(*Mc);
			FTakeCount Count;
			Count.Sim = &Sim;
			const JamAI::FJamMatchConfig Cfg = JamAI::ToMatchConfigResolved(*Mc, TEXT("pro"));
			JamAI::RunPlaytestMatch(Sim, Cfg, Seed, JamAI::EPlaytester::Regular, 10800, Mc->Game.Shot.ChargeFramesMax, false, &TakeTrace, &Count, 1);
			Under30 += Count.Under30; Takeaways += Count.Held.Num();
			for (const FString& Note : Count.Notes) Notes += FString::Printf(TEXT(" [seed %llu: %s]"), Seed, *Note);
		}
		AddInfo(FString::Printf(TEXT("INTGRACE pro, 20 matches of 10800 frames, bTakeGraceSameFrame %d: stick takeaways %d, inside 30 frames of the win %d%s"), bCover ? 1 : 0, Takeaways, Under30, *Notes));
	}
	// One carry that timed out with the puck kept and one that was lifted (the stop at 9.5 m, as the tree stands), frame by frame.
	{
		bool bTimeout = false, bLift = false;
		for (uint64 Seed = 1; Seed <= 200 && !(bTimeout && bLift); ++Seed)
		{
			const FRun R = Carry(*C, Seed, At95);
			const bool bT = R.End == FJamCarryDrill::Timeout && !bTimeout, bL = R.End == FJamCarryDrill::Lift && !bLift;
			if (!bT && !bL) continue;
			bTimeout |= bT; bLift |= bL;
			TArray<FString> Trace;
			Carry(*C, Seed, At95, TEXT("pro"), &Trace);
			for (const FString& Line : Trace) AddInfo(FString::Printf(TEXT("INTTRACE %s seed %llu | %s"), bT ? TEXT("timeout") : TEXT("lift"), Seed, *Line));
		}
	}
	// By where the stop begins, as the tree stands: pro, all_star, rookie.
	for (const TCHAR* Level : { TEXT("pro"), TEXT("all_star"), TEXT("rookie") })
	{
		for (const double At : { 6.0, 7.0, 8.0, 9.0, 9.5, 10.0, 11.0, 12.0 })
		{
			FScript S;
			S.BrakeAtM = At;
			AddInfo(FString::Printf(TEXT("INTWINDOW %s | stop at %.1f m: %s"), Level, At, *CarryHow(*C, S, Seeds, Level).Line()));
		}
		AddInfo(FString::Printf(TEXT("INTWINDOW %s | straight charge: %s"), Level, *CarryHow(*C, Straight, Seeds, Level).Line()));
	}
	return true;
}

// Bar.Curve.Law3 (lane A133, outside the gate's Jam filter): law 3's drill (R-0053, R-0055) under candidate profile tunes, so the curve lane measures a
// profile number against the gate before it builds it. JAM_LAW3_TUNES = "level:tune|level:tune|..." (a tune of "-" = the level as shipped); 200 seeds an arm:
// the stop at 8, 9.5, 10, 11, 12 m and the straight charge.
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamCurveLaw3, "Bar.Curve.Law3", JamCarrierSkillTests::Flags)
bool FJamCurveLaw3::RunTest(const FString& Parameters)
{
	using namespace JamCarrierSkillTests;
	UJamCartridge* C = LoadPreset(*this, TEXT("hockey.regular"));
	if (!C) return false;
	FString Env = FPlatformMisc::GetEnvironmentVariable(TEXT("JAM_LAW3_TUNES"));
	if (Env.IsEmpty()) Env = TEXT("pro:-|all_star:-");
	// Lane A185 (track F2 evolution 9): JAM_LAW3_FREE = skater.free_speed_mult for the run (absent = as shipped; 1 = the game before the lane), and
	// JAM_LAW3_AT = the stop distances, comma separated (absent = 8, 9.5, 10, 11, 12), so the stop's window is read on both arms in one build.
	const FString FreeEnv = FPlatformMisc::GetEnvironmentVariable(TEXT("JAM_LAW3_FREE"));
	if (!FreeEnv.IsEmpty()) { C = DuplicateObject<UJamCartridge>(C, GetTransientPackage()); C->Game.Skater.FreeSpeedMult = FCString::Atod(*FreeEnv); }
	// Lane A194 (track F2 evolution 10): JAM_LAW3_SET = "key=value;..." of the movement numbers a candidate moves (absent = as shipped).
	const FString SetEnv = FPlatformMisc::GetEnvironmentVariable(TEXT("JAM_LAW3_SET"));
	if (!SetEnv.IsEmpty())
	{
		C = DuplicateObject<UJamCartridge>(C, GetTransientPackage());
		TArray<FString> Parts;
		SetEnv.ParseIntoArray(Parts, TEXT(";"));
		for (const FString& Part : Parts)
		{
			FString K, Vs;
			if (!Part.Split(TEXT("="), &K, &Vs)) continue;
			const double V = FCString::Atod(*Vs);
			FJamSkaterConfig& Sk = C->Game.Skater;
			if (K == TEXT("reverse_brake_decel")) Sk.ReverseBrakeDecel = V;
			else if (K == TEXT("carry_brake_mult")) Sk.CarryReverseBrakeMult = V;
			else if (K == TEXT("burst.frames")) Sk.BurstFrames = FMath::RoundToInt32(V);
			else if (K == TEXT("burst.accel_mult")) Sk.BurstAccelMult = V;
			else if (K == TEXT("burst_carry_accel_mult")) Sk.BurstCarryAccelMult = V;
			else if (K == TEXT("breakaway.speed_bonus")) Sk.BreakawaySpeedBonus = V;
			else if (K == TEXT("pickup.arc_m")) C->Game.Stick.PickupArcM = V;   // lane A208 (game.stick.pickup): the neutral arm is pickup.arc_m=0;pickup.body=0
			else if (K == TEXT("pickup.body")) C->Game.Stick.bPickupBody = V > 0.5;
			else if (K == TEXT("pickup.ring_m")) C->Game.Stick.PickupRingM = V;   // lane A218 (game.stick.pickup.ring_m): the neutral arm is pickup.ring_m=0
			else AddError(FString::Printf(TEXT("JAM_LAW3_SET: unknown key %s"), *K));
		}
		AddInfo(FString::Printf(TEXT("LAW3T set %s"), *SetEnv));
	}
	TArray<double> Ats = { 8.0, 9.5, 10.0, 11.0, 12.0 };
	{
		const FString AtEnv = FPlatformMisc::GetEnvironmentVariable(TEXT("JAM_LAW3_AT"));
		TArray<FString> Parts;
		AtEnv.ParseIntoArray(Parts, TEXT(","));
		if (Parts.Num()) { Ats.Reset(); for (const FString& P : Parts) Ats.Add(FCString::Atod(*P)); }
	}
	AddInfo(FString::Printf(TEXT("LAW3T free_speed_mult %.3f"), C->Game.Skater.FreeSpeedMult));
	TArray<FString> Arms;
	Env.ParseIntoArray(Arms, TEXT("|"));
	for (const FString& Arm : Arms)
	{
		FString Level, Tune;
		if (!Arm.Split(TEXT(":"), &Level, &Tune)) { Level = Arm; Tune = TEXT("-"); }
		const FTCHARToUTF8 T8(*Tune);
		const char* T = Tune == TEXT("-") ? nullptr : T8.Get();
		for (const double At : Ats)
		{
			FScript S;
			S.BrakeAtM = At;
			AddInfo(FString::Printf(TEXT("LAW3T %s | %s | stop at %.1f m: %s"), *Level, *Tune, At, *CarryHow(*C, S, 200, *Level, T).Line()));
		}
		FScript Straight;
		Straight.BrakeAtM = 9.5;
		Straight.bStopAndGo = false;
		AddInfo(FString::Printf(TEXT("LAW3T %s | %s | straight charge: %s"), *Level, *Tune, *CarryHow(*C, Straight, 200, *Level, T).Line()));
		for (const int32 React : { 0, 6, 9, 12, 15, 18, 21, 24 })   // lane A201: the stop begun on the stop line's light, after the hand's lag
		{
			FScript L;
			L.LightReactFrames = React;
			AddInfo(FString::Printf(TEXT("LAW3T %s | %s | stop on the light + %d frames: %s"), *Level, *Tune, React, *CarryHow(*C, L, 200, *Level, T).Line()));
		}
		// Lane A201 (evolution 12, the late hand): the press made only while the bar is still lit (JAM_MARK_RULE moves the line's rule: near=, ...).
		for (const int32 React : { 12, 15, 18, 21, 24, 27, 30 })
		{
			FScript L;
			L.LightReactFrames = React; L.bOnlyWhileLit = true; L.LightRule = JamCarrierMarks::StopRuleFromEnv();
			const FShare W = Share(*C, L, 200, *Level, T);
			const int32 Invited = W.N - W.Ends[FJamCarryDrill::Setup];
			AddInfo(FString::Printf(TEXT("LAW3T %s | %s | late hand + %d frames, only while lit: invited %d of %d, past %d of those (%.1f %%)"), *Level, *Tune, React, Invited, W.N, W.Ends[FJamCarryDrill::Past], Invited > 0 ? 100.0 * W.Ends[FJamCarryDrill::Past] / Invited : 0.0));
		}
	}
	return true;
}

// Bar.Bot.Hockey5.Stops (lane A167, track Q2, evolution 5; outside the gate's Jam filter; BRAIN-5.md sections 3 and 4). The carry scene of
// Jam.Core.Movement.StopAndGo, 200 seeds an arm, logged only. PRESSPRO: pro on hockey.regular with its presser kept on its job inside the hunt
// (opp.hk_press_in_hunt=1). SIX: the stop by distance at each level on the six-skater cuts, as shipped and with the chaser closing under control
// (opp.hk_press_three=1).
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamHockey5StopsBar, "Bar.Bot.Hockey5.Stops", JamCarrierSkillTests::Flags)
bool FJamHockey5StopsBar::RunTest(const FString& Parameters)
{
	using namespace JamCarrierSkillTests;
	auto At = [](double M) { FScript S; S.BrakeAtM = M; return S; };
	FScript Straight;
	Straight.bStopAndGo = false;
	if (UJamCartridge* C = LoadPreset(*this, TEXT("hockey.regular")))
	{
		for (const char* Tune : { "", "opp.hk_press_in_hunt=1", "opp.hunt_radius_m=20", "opp.hk_press_in_hunt=1;opp.hk_press_commit_m=8", "opp.hk_press_in_hunt=1;opp.hk_press_commit_m=8;opp.hunt_radius_m=20",
			"opp.hk_press_in_hunt=1;opp.hk_press_commit_m=8;opp.hunt_radius_m=20;opp.hk_press_three=1;opp.hk_press_three_commit_m=6;opp.hk_press_retreat_cap=0.7" })
		{
			FString L = FString::Printf(TEXT("PRESSPRO pro | %s |"), Tune[0] ? ANSI_TO_TCHAR(Tune) : TEXT("as shipped"));
			for (double M : { 5.0, 6.0, 8.0, 9.5, 11.0 }) L += FString::Printf(TEXT(" %.1f m %.1f %%"), M, 100.0 * Share(*C, At(M), 200, TEXT("pro"), Tune).PastShare());
			const FShare S95 = Share(*C, At(9.5), 200, TEXT("pro"), Tune), SB = Share(*C, Straight, 200, TEXT("pro"), Tune);
			L += FString::Printf(TEXT(" | straight %.1f %% | the stop at 9.5 m: %s"), 100.0 * SB.PastShare(), *S95.Line());
			AddInfo(L);
		}
	}
	for (const TCHAR* Cut : { TEXT("hockey.arena.large"), TEXT("hockey.chaos"), TEXT("hockey.arena.wide"), TEXT("hockey.boost") })   // hockey.raw reads as the large rink does (build 1: the same numbers)
	{
		UJamCartridge* C = LoadPreset(*this, Cut);
		if (!C) continue;
		for (const TCHAR* Level : { TEXT("rookie"), TEXT("pro"), TEXT("all_star") })
		{
			for (const char* Tune : { "", "opp.hk_press_three=1;opp.hk_press_three_commit_m=6", "opp.hk_press_three=1;opp.hk_press_three_commit_m=6;opp.hk_press_retreat_cap=0.7",
				"opp.hk_press_three=1;opp.hk_press_three_commit_m=6;opp.hk_press_retreat_cap=0.7;opp.hk_press_in_hunt=1;opp.hk_press_commit_m=8" })
			{
				FString L = FString::Printf(TEXT("SIX %s | %s | %s |"), Cut, Level, Tune[0] ? ANSI_TO_TCHAR(Tune) : TEXT("as shipped"));
				for (double M : { 6.0, 8.0, 9.5, 11.0, 12.0 }) L += FString::Printf(TEXT(" %.1f m %.1f %%"), M, 100.0 * Share(*C, At(M), 200, Level, Tune).PastShare());
				const FShare S8 = Share(*C, At(8.0), 200, Level, Tune), SB = Share(*C, Straight, 200, Level, Tune);
				L += FString::Printf(TEXT(" | straight %.1f %% | the stop at 8 m: %s"), 100.0 * SB.PastShare(), *S8.Line());
				AddInfo(L);
			}
		}
	}
	return true;
}

// Bar.Bot.Hockey6.Law3Row (lane A181, track Q2, evolution 6; outside the gate's Jam filter; BRAIN-6.md). Law 3's row in the carry scene of
// Jam.Core.Movement.StopAndGo on hockey.regular, 200 seeds a number, logged only, for each arm of JAM_A181_TUNES ("name:tune|name:tune"; default: as
// shipped) at each level of JAM_A181_LEVELS (default "all_star,pro"): the stop begun at 8 / 9 / 9.5 / 11 / 12 m, and the straight charge.
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamHockey6Law3RowBar, "Bar.Bot.Hockey6.Law3Row", JamCarrierSkillTests::Flags)
bool FJamHockey6Law3RowBar::RunTest(const FString& Parameters)
{
	using namespace JamCarrierSkillTests;
	UJamCartridge* C = LoadPreset(*this, TEXT("hockey.regular"));
	if (!C) return false;
	const FString TunesEnv = FPlatformMisc::GetEnvironmentVariable(TEXT("JAM_A181_TUNES"));
	const FString LevelsEnv = FPlatformMisc::GetEnvironmentVariable(TEXT("JAM_A181_LEVELS"));
	TArray<FString> Arms, Levels;
	(TunesEnv.IsEmpty() ? FString(TEXT("as shipped:")) : TunesEnv).ParseIntoArray(Arms, TEXT("|"), true);
	(LevelsEnv.IsEmpty() ? FString(TEXT("all_star,pro")) : LevelsEnv).ParseIntoArray(Levels, TEXT(","), true);
	FScript Straight;
	Straight.bStopAndGo = false;
	for (const FString& Level : Levels)
	{
		for (const FString& Arm : Arms)
		{
			FString Name = Arm, Tune;
			Arm.Split(TEXT(":"), &Name, &Tune);
			const FTCHARToUTF8 TuneA(*Tune);
			FString L = FString::Printf(TEXT("LAW3ROW %s | %s |"), *Level, *Name);
			for (double M : { 8.0, 9.0, 9.5, 11.0, 12.0 })
			{
				FScript S;
				S.BrakeAtM = M;
				L += FString::Printf(TEXT(" %.1f m %.1f"), M, 100.0 * Share(*C, S, 200, *Level, TuneA.Get()).PastShare());
			}
			L += FString::Printf(TEXT(" | straight %.1f"), 100.0 * Share(*C, Straight, 200, *Level, TuneA.Get()).PastShare());
			AddInfo(L);
		}
	}
	return true;
}

#endif
