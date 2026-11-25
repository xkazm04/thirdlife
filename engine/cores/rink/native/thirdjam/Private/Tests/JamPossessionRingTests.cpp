// Lane A218 (track F0, R-0069 point 2: "puck is not controlled by player if in his circle area, then player runs right through the pack and still does not
// have control"). The night measured loose-puck pickups with scripted hands whose stick points at the puck and who hold no button; a person's cursor is
// somewhere else. These scenes play the human as a PERSON plays him: the stick aimed 90 or 180 degrees away from the puck, buttons held.
//   Jam.Core.Possession.HumanRing  one POSRING row a scene and arm: frames from "the puck inside the ring drawn under him" (stick.pickup.ring_m, the HUD's
//                                  1.1 m) to "his" (the puck rides with him, RidingCarrier, for 10 frames in a row), or "never" inside the scene. The rule
//                                  (the default): every row his within 2 frames (the release rows: counted from the frame the release is no longer leaving
//                                  him: slower than 6 m/s against him, closing on him, or 20 frames after it left). The neutral (ring_m 0) is main's game.
#include "Misc/AutomationTest.h"
#include "JamCartridge.h"
#include "JamSim.h"
#include "UObject/Package.h"

#if WITH_DEV_AUTOMATION_TESTS

namespace JamRingTests
{
	constexpr EAutomationTestFlags Flags = EAutomationTestFlags_ApplicationContextMask | EAutomationTestFlags::ProductFilter;
	constexpr double HudRingM = 1.1;   // HUDWidget.cpp: the ring under the human, 1.1 m

	bool LoadGame(FAutomationTestBase& T, FJamGameConfig& Out)
	{
		TArray<FString> Errors;
		UJamCartridge* C = UJamCartridge::LoadFromFile(UJamCartridge::ResolveCartridgePath(TEXT("hockey.regular")), Errors);
		for (const FString& E : Errors) T.AddError(E);
		if (!C) return false;
		Out = C->Game;
		return true;
	}

	FVector2D Rot(const FVector2D& V, double Deg)
	{
		const double A = FMath::DegreesToRadians(Deg);
		return FVector2D(V.X * FMath::Cos(A) - V.Y * FMath::Sin(A), V.X * FMath::Sin(A) + V.Y * FMath::Cos(A));
	}

	// The person's cursor: the stick at full aim, Deg away from the line to the puck (0 = at the puck).
	FVector2D AimAway(const UJamSim* Sim, int32 V, double Deg)
	{
		const FVector2D To = Sim->GetPuck().Pos - Sim->GetSkaters()[V].Pos;
		const FVector2D Dir = To.IsNearlyZero() ? Sim->GetSkaters()[V].Forward() : To.GetSafeNormal();
		return Rot(Dir, Deg);
	}

	enum class EKind : uint8 { Still, Skate, OwnPass, OwnShot, OwnAhead, Poked };

	struct FCase
	{
		FString Name;
		EKind Kind = EKind::Still;
		double AimDeg = 180.0;              // the stick, degrees away from the puck
		FVector2D PuckAt = FVector2D::ZeroVector;   // Still / Skate: the puck relative to him at the start
		double Speed = 0.0;                 // Skate: his speed along +X (m/s)
		bool bSprint = false;
		int32 Lmb = 0;                      // 1 = LMB pressed and held (no puck: the cross-check press, then the brace)
		int32 Rmb = 0;                      // 1 = RMB pressed and held (no puck: the check press)
	};

	struct FOut
	{
		int32 Enter = -1;    // the first frame the puck is inside his ring (the release rows: and no longer leaving him)
		int32 His = -1;      // the first frame of his 10-frame ride
		int32 Release = -1;  // the release rows: the frame his pass or shot left
		FString Note;
		bool bLeft = false;
		FString Trace;       // the first frames from Enter (for the row's line)  // the release rows: the puck left his ring before it was his again (it got off his stick)
		int32 Frames() const { return (Enter >= 0 && His >= 0) ? FMath::Max(0, His - Enter) : -1; }
	};

	UJamSim* Stage(const FJamGameConfig& G, int32& V, int32& Opp)
	{
		UJamSim* Sim = NewObject<UJamSim>();
		Sim->Init(G, 7);
		Sim->SkipFaceoff();
		V = Sim->GetHumanIndex();
		Opp = -1;
		for (const FJamSkaterState& S : Sim->GetSkaters())
		{
			if (S.Index == V) continue;
			if (Opp < 0 && S.Team != Sim->GetSkaters()[V].Team) Opp = S.Index;
			Sim->SetSkater(S.Index, FVector2D(-35.0 + S.Index * 2.5, 18.0), FVector2D::ZeroVector, 0);
		}
		return Sim;
	}

	FOut Run(const FJamGameConfig& G, const FCase& C)
	{
		int32 V = -1, O = -1;
		UJamSim* Sim = Stage(G, V, O);
		TArray<FJamInput> In;
		In.SetNum(Sim->GetSkaters().Num());
		const double Ring = HudRingM;
		FOut Out;
		auto Clear = [&]() { for (FJamInput& I : In) I = FJamInput(); };
		auto Carry = [&](const FVector2D& Pos, double Yaw, const FVector2D& Vel, int32 Frames)
		{
			const FVector2D Fwd(FMath::Cos(Yaw), FMath::Sin(Yaw));
			Sim->SetSkater(V, Pos, Vel, Yaw);
			Sim->SetPuck(Pos + Fwd * 0.9, Vel);
			for (int32 F = 0; F < Frames; ++F) { Clear(); In[V].Move = Vel.IsNearlyZero() ? FVector2D::ZeroVector : Vel.GetSafeNormal() * FMath::Min(1.0, Vel.Size() / 8.0); In[V].Stick = Fwd; Sim->Step(In); }
		};
		int32 Start = 0;
		if (C.Kind == EKind::Still || C.Kind == EKind::Skate)
		{
			// An opponent touched it last (a loose puck of the game), far away; then the scene.
			const FJamSkaterState& Os = Sim->GetSkaters()[O];
			Sim->SetPuck(Os.Pos + Os.Forward() * 0.45, FVector2D::ZeroVector);
			Clear(); Sim->Step(In);
			const FVector2D P0 = C.Kind == EKind::Skate ? FVector2D(-8.0, 0.0) : FVector2D::ZeroVector;
			Sim->SetSkater(V, P0, FVector2D(C.Speed, 0.0), 0.0);
			Sim->SetPuck(FVector2D(20.0, -14.0), FVector2D::ZeroVector);
			Clear(); Sim->Step(In);
			Sim->SetSkater(V, P0, FVector2D(C.Speed, 0.0), 0.0);
			Sim->SetPuck(C.Kind == EKind::Skate ? C.PuckAt : P0 + C.PuckAt, FVector2D::ZeroVector);
		}
		else if (C.Kind == EKind::OwnPass)
		{
			Carry(FVector2D(-20.0, 0.0), 0.0, FVector2D(6.0, 0.0), 12);   // he carries up the ice at a glide
		}
		else if (C.Kind == EKind::OwnShot)
		{
			const double Wy = G.Rink.WidthM * 0.5;
			Carry(FVector2D(10.0, Wy - 6.0), UE_DOUBLE_PI * 0.5, FVector2D::ZeroVector, 12);   // he stands 6 m off the side boards, facing them
		}
		else if (C.Kind == EKind::OwnAhead)
		{
			// His own puck squirted ahead of him the way he skates (a bobble, a lost touch): 3 m ahead at 5 m/s, he skates after it at 8.
			Carry(FVector2D(-20.0, 0.0), 0.0, FVector2D(8.0, 0.0), 8);
			const FJamSkaterState& S = Sim->GetSkaters()[V];
			Sim->SetPuck(S.Pos + FVector2D(3.0, 0.0), FVector2D(5.0, 0.0));
		}
		else if (C.Kind == EKind::Poked)
		{
			// He carries standing still; an opponent in front pokes it off his blade; the poker is then taken away (as a poker who loses the puck at once), the
			// puck left loose inside his ring.
			Carry(FVector2D(0.0, 0.0), 0.0, FVector2D::ZeroVector, 8);
			Sim->SetSkater(O, FVector2D(2.1, 0.0), FVector2D::ZeroVector, UE_DOUBLE_PI);
			int32 Took = -1;
			for (int32 F = 0; F < 12 && Took < 0; ++F)
			{
				Clear();
				const FVector2D ToP = Sim->GetPuck().Pos - Sim->GetSkaters()[O].Pos;   // the poker's blade at the puck (his stick at the length that reaches it)
				In[O].Stick = ToP.GetSafeNormal() * FMath::Clamp((ToP.Size() - UJamSim::SkaterRadius) / FMath::Max(0.1, G.Stick.ReachM), 0.06, 1.0);
				In[O].bPoke = F == 0;
				In[V].Stick = FVector2D(1.0, 0.0);
				Sim->Step(In);
				if (Sim->GetPuck().LastTouch == O) Took = F;
			}
			if (Took < 0) { Out.Note = TEXT("staging: the poke did not take it"); return Out; }
			Sim->SetSkater(O, FVector2D(-30.0, -20.0), FVector2D::ZeroVector, 0);
			Sim->SetPuck(Sim->GetSkaters()[V].Pos + FVector2D(0.0, -0.8), FVector2D::ZeroVector);   // loose, beside him
		}
		bool bLeftRing = false;
		int32 Run = 0, RunStart = -1;
		const int32 MaxF = 150;
		for (int32 F = Start; F < MaxF; ++F)
		{
			Clear();
			FJamInput& I = In[V];
			const FJamSkaterState& S0 = Sim->GetSkaters()[V];
			const bool bReleased = Out.Release >= 0;
			switch (C.Kind)
			{
			case EKind::Still: case EKind::Poked: I.Stick = AimAway(Sim, V, C.AimDeg); break;
			case EKind::Skate:
				I.Move = FVector2D(FMath::Min(1.0, C.Speed / 8.0), 0.0); I.bSprint = C.bSprint; I.Stick = AimAway(Sim, V, C.AimDeg);
				break;
			case EKind::OwnPass:
				if (!bReleased) { I.Move = FVector2D(1, 0); I.Stick = FVector2D(1, 0); I.bPassHeld = F == 0; }   // the tap: one frame of RMB with the puck, to nobody
				else { I.Move = (Sim->GetPuck().Pos - S0.Pos).GetSafeNormal(); I.bSprint = true; I.Stick = AimAway(Sim, V, C.AimDeg); }   // he chases at once
				break;
			case EKind::OwnShot:
				if (!bReleased) { I.Stick = FVector2D(0, 1); I.bShootHeld = F == 0; }   // the tap shot into the boards
				else I.Stick = AimAway(Sim, V, C.AimDeg);
				break;
			case EKind::OwnAhead:
				I.Move = FVector2D(1, 0); I.bSprint = true; I.Stick = AimAway(Sim, V, C.AimDeg);
				break;
			}
			// The buttons as a person holds them (InputMapping: without the puck LMB is the cross-check: a press, then the brace held; RMB is the check: a press).
			// Once he carries, the held LMB is dead (the brace ends) until it is released (A199).
			if (C.Lmb) { I.bLift = F == Start; I.bCrossHold = Sim->RidingCarrier() != V && Run == 0; }
			if (C.Rmb) I.bCheck = F == Start;
			Sim->Step(In);
			const FJamSkaterState& S = Sim->GetSkaters()[V];
			const FJamPuckState& P = Sim->GetPuck();
			if ((C.Kind == EKind::OwnPass || C.Kind == EKind::OwnShot) && Out.Release < 0 && (S.bPassThisFrame || S.bShotThisFrame)) { Out.Release = F; continue; }
			if ((C.Kind == EKind::OwnPass || C.Kind == EKind::OwnShot) && Out.Release < 0) { if (F > 6) { Out.Note = TEXT("staging: no release"); return Out; } continue; }
			const double D = FVector2D::Distance(P.Pos, S.Pos);
			if (Out.Release >= 0 && D > Ring) bLeftRing = true;
			if (Out.Enter < 0 && D <= Ring)
			{
				bool bCount = true;
				if (Out.Release >= 0)
				{
					const FVector2D Rel = P.Vel - S.Vel;
					const bool bClosing = FVector2D::DotProduct(Rel, P.Pos - S.Pos) < 0.0;
					bCount = F - Out.Release >= 20 || Rel.Size() < 6.0 || bClosing || bLeftRing;
				}
				if (bCount) Out.Enter = F;
			}
			// His: the puck rides with him (RidingCarrier) and moves with him (the read alone says 'riding' for his own release under 4 m/s while the lock keeps
			// the carry from pulling it).
			const bool bHisNow = Sim->RidingCarrier() == V && P.LastTouch == V && (P.Vel - S.Vel).Size() < 1.0;
			if (Out.Enter < 0 && bHisNow && (Out.Release < 0 || F - Out.Release >= 1)) Out.Enter = F;   // his before it reached the ring (the blade met it further out): 0 frames
			if (bHisNow) { if (Run++ == 0) RunStart = F; if (Run >= 10 && Out.His < 0 && Out.Enter >= 0) Out.His = FMath::Max(RunStart, Out.Release >= 0 ? Out.Release + 1 : RunStart); }
			else { Run = 0; RunStart = -1; }
			if (Out.Enter >= 0 && F - Out.Enter < 8) Out.Trace += FString::Printf(TEXT(" [f%d d%.2f rel%.1f lt%d ride%d]"), F, D, (P.Vel - S.Vel).Size(), P.LastTouch, Sim->RidingCarrier());
			if (Out.His >= 0) { Out.bLeft = bLeftRing; break; }
			if (P.LastTouch != V && P.LastTouch >= 0 && Sim->GetSkaters()[P.LastTouch].Team == S.Team && Out.Release >= 0) { Out.Note = TEXT("a mate took it"); }
		}
		if (Out.Enter < 0 && Out.Note.IsEmpty()) Out.Note = TEXT("never inside his ring");
		return Out;
	}

	TArray<FCase> Cases()
	{
		TArray<FCase> L;
		auto Add = [&](const FString& N, EKind K, double Aim, FVector2D At = FVector2D::ZeroVector, double Sp = 0.0, bool bSpr = false, int32 Lmb = 0, int32 Rmb = 0)
		{
			FCase C; C.Name = N; C.Kind = K; C.AimDeg = Aim; C.PuckAt = At; C.Speed = Sp; C.bSprint = bSpr; C.Lmb = Lmb; C.Rmb = Rmb; L.Add(C);
		};
		Add(TEXT("still: beside 0.8 m, stick 180 off"), EKind::Still, 180, FVector2D(0, 0.8));
		Add(TEXT("still: beside 1.0 m, stick 90 off"), EKind::Still, 90, FVector2D(0, -1.0));
		Add(TEXT("still: behind 0.8 m, stick 180 off"), EKind::Still, 180, FVector2D(-0.8, 0));
		Add(TEXT("still: behind 1.0 m, stick 90 off"), EKind::Still, 90, FVector2D(-1.0, 0.0));
		Add(TEXT("still: behind-left 0.7 m, stick 90 off"), EKind::Still, -90, FVector2D(-0.5, 0.5));
		const TCHAR* Gaits[] = { TEXT("walk 3"), TEXT("full 8"), TEXT("sprint 10") };
		const double Sp[] = { 3.0, 8.0, 10.0 };
		for (int32 Gi = 0; Gi < 3; ++Gi)
			for (double Lat : { 0.0, 0.7 })
				for (double Aim : { 90.0, 180.0 })
					Add(FString::Printf(TEXT("skate through %s m/s, lateral %.1f, stick %.0f off"), Gaits[Gi], Lat, Aim), EKind::Skate, Lat > 0.0 ? -Aim : Aim, FVector2D(0, Lat), Sp[Gi], Gi == 2);
		Add(TEXT("own tapped pass to nobody, he chases, stick 90 off"), EKind::OwnPass, 90);
		Add(TEXT("own shot's rebound off the boards, stick 90 off"), EKind::OwnShot, 90);
		Add(TEXT("own puck squirted ahead, he catches up, stick 90 off"), EKind::OwnAhead, 90);
		Add(TEXT("LMB held: skate through full 8, lateral 0.0"), EKind::Skate, 90, FVector2D(0, 0.0), 8.0, false, 1, 0);
		Add(TEXT("LMB held: skate through full 8, lateral 0.7"), EKind::Skate, -90, FVector2D(0, 0.7), 8.0, false, 1, 0);
		Add(TEXT("LMB held: still beside 0.8 m"), EKind::Still, 180, FVector2D(0, 0.8), 0.0, false, 1, 0);
		Add(TEXT("RMB held: skate through full 8, lateral 0.0"), EKind::Skate, 90, FVector2D(0, 0.0), 8.0, false, 0, 1);
		Add(TEXT("RMB held: skate through full 8, lateral 0.7"), EKind::Skate, -90, FVector2D(0, 0.7), 8.0, false, 0, 1);
		Add(TEXT("RMB held: still beside 0.8 m"), EKind::Still, 180, FVector2D(0, 0.8), 0.0, false, 0, 1);
		Add(TEXT("just poked off him, loose beside 0.8 m, stick 180 off"), EKind::Poked, 180);
		return L;
	}

	FString Cell(const FOut& O)
	{
		if (O.Frames() >= 0) return FString::Printf(TEXT("%d"), O.Frames());
		return O.Note.IsEmpty() ? FString(TEXT("never")) : FString::Printf(TEXT("never (%s)"), *O.Note);
	}
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamPossessionHumanRing, "Jam.Core.Possession.HumanRing", JamRingTests::Flags)
bool FJamPossessionHumanRing::RunTest(const FString& Parameters)
{
	using namespace JamRingTests;
	FJamGameConfig G;
	if (!LoadGame(*this, G)) return false;
	TestTrue(TEXT("the rule ships on: stick.pickup.ring_m 1.1 (the HUD's ring)"), FMath::IsNearlyEqual(G.Stick.PickupRingM, HudRingM));
	FJamGameConfig N = G;
	N.Stick.PickupRingM = 0.0;   // the neutral value: main's game
	int32 Bad = 0, Rows = 0, BadN = 0;
	for (const FCase& C : Cases())
	{
		const FOut R = Run(G, C);
		const FOut Rn = Run(N, C);
		++Rows;
		AddInfo(FString::Printf(TEXT("POSRING %-58s | neutral: %-12s | rule: %s (enter %d, his %d, release %d)"), *C.Name, *Cell(Rn), *Cell(R), R.Enter, R.His, R.Release));
		if (Rn.Frames() < 0 || Rn.Frames() > 2) ++BadN;
		if (R.Frames() < 0 || R.Frames() > 2) { ++Bad; AddError(FString::Printf(TEXT("the rule: %s: %s frames from inside his ring to his (want 2 at most):%s"), *C.Name, *Cell(R), *R.Trace)); }
	}
	AddInfo(FString::Printf(TEXT("POSRING total %d rows | neutral: %d not his within 2 frames | rule: %d"), Rows, BadN, Bad));
	// The release still leaves him: his tap to a mate 9 m ahead while he follows it (at a glide, at a sprint) is the mate's, under the rule as at the neutral;
	// and his own tap to nobody left his ring before he took it back.
	for (const FCase& C : Cases())
	{
		if (C.Kind != EKind::OwnPass && C.Kind != EKind::OwnShot) continue;
		const FOut R = Run(G, C);
		TestTrue(*FString::Printf(TEXT("the rule: %s: the release left his ring before it was his again"), *C.Name), R.bLeft);
	}
	int32 GotN[2] = { -1, -1 };
	for (int32 Arm = 0; Arm < 2; ++Arm)
		for (const bool bSprint : { false, true })
		{
			int32 V = -1, O = -1;
			UJamSim* Sim = Stage(Arm == 0 ? N : G, V, O);
			int32 M = -1;
			for (const FJamSkaterState& S : Sim->GetSkaters()) if (M < 0 && S.Index != V && S.Team == Sim->GetSkaters()[V].Team) M = S.Index;
			Sim->SetSkater(M, FVector2D(-11.0, 0.0), FVector2D::ZeroVector, UE_DOUBLE_PI);
			TArray<FJamInput> In;
			In.SetNum(Sim->GetSkaters().Num());
			Sim->SetSkater(V, FVector2D(-20.0, 0.0), FVector2D(6.0, 0.0), 0.0);
			Sim->SetPuck(FVector2D(-19.1, 0.0), FVector2D(6.0, 0.0));
			for (int32 F = 0; F < 12; ++F) { for (FJamInput& I : In) I = FJamInput(); In[V].Move = FVector2D(0.75, 0); In[V].Stick = FVector2D(1, 0); Sim->Step(In); }
			const bool bCarried = Sim->RidingCarrier() == V;
			int32 Got = -1, Back = -1, Rel = -1;
			for (int32 F = 0; F < 90 && Got < 0; ++F)
			{
				for (FJamInput& I : In) I = FJamInput();
				In[V].Move = FVector2D(1, 0); In[V].bSprint = bSprint; In[V].Stick = FVector2D(1, 0); In[V].bPassHeld = F == 0;
				Sim->Step(In);
				if (Rel < 0 && Sim->GetSkaters()[V].bPassThisFrame) Rel = F;
				if (Rel >= 0 && F > Rel && Back < 0 && Sim->GetPuck().LastTouch == V && Sim->RidingCarrier() == V) Back = F;
				if (Sim->GetPuck().LastTouch == M) Got = F;
			}
			AddInfo(FString::Printf(TEXT("POSRING tap pass to a mate 9 m ahead, he follows at a %s | %s: carried before %d, released at %d, the mate's at frame %d, his again at %d"), bSprint ? TEXT("sprint") : TEXT("glide"), Arm == 0 ? TEXT("neutral") : TEXT("rule"), bCarried ? 1 : 0, Rel, Got, Back));
			if (Arm == 0) GotN[bSprint ? 1 : 0] = Got;
			else TestTrue(*FString::Printf(TEXT("the rule: his tap to a mate 9 m ahead arrives while he follows at a %s, as at the neutral (frame %d, neutral %d)"), bSprint ? TEXT("sprint") : TEXT("glide"), Got, GotN[bSprint ? 1 : 0]), bCarried && Rel >= 0 && Got >= 0 && Got <= GotN[bSprint ? 1 : 0] + 2);
		}
	TestTrue(TEXT("the neutral value reproduces the fault (main's game: at least one row not his)"), BadN > 0);
	return true;
}

#endif
