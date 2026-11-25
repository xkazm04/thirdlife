// Lane A16 (C-0005 section 5): Jam.Core.FeelDepth: PassReachesTeammate (a scripted pass arrives within pass_lead_frames in 9 of 10 seeds),
// ChargeShot (speed scales with the hold), DeflectionConserves (70 %), StripOnCheck (a check that lands on the carrier always strips). Headless.
//   UnrealEditor-Cmd.exe Game/ThirdJam.uproject -ExecCmds="Automation RunTests Jam.Core.FeelDepth; Quit" -unattended -nullrhi -nosplash -log
#include "Misc/AutomationTest.h"
#include "JamCartridge.h"
#include "JamSim.h"
#include "JamBaseline.h"   // lane A207: PassShotNeutral
#include "JamEventBus.h"

#if WITH_DEV_AUTOMATION_TESTS

namespace JamFeelDepthTests
{
	constexpr EAutomationTestFlags Flags = EAutomationTestFlags_ApplicationContextMask | EAutomationTestFlags::ProductFilter;

	UJamCartridge* LoadPreset(FAutomationTestBase& T, const FString& Name)
	{
		TArray<FString> Errors;
		UJamCartridge* C = UJamCartridge::LoadFromFile(UJamCartridge::ResolveCartridgePath(Name), Errors);
		for (const FString& E : Errors) T.AddError(FString::Printf(TEXT("%s: %s"), *Name, *E));
		return C;
	}

	UJamSim* MakeSim(const FJamGameConfig& Config, uint64 Seed)
	{
		UJamSim* Sim = NewObject<UJamSim>();
		Sim->Init(Config, Seed);
		Sim->SkipFaceoff();
		return Sim;
	}

	void Park(UJamSim* Sim, const TArray<int32>& Keep)
	{
		for (const FJamSkaterState& S : Sim->GetSkaters())
		{
			if (Keep.Contains(S.Index)) continue;
			Sim->SetSkater(S.Index, FVector2D(-38.0 + S.Index * 2.0, 19.0), FVector2D::ZeroVector, 0);
		}
	}

	int32 Teammate(const UJamSim* Sim, int32 Me)
	{
		for (const FJamSkaterState& S : Sim->GetSkaters()) if (S.Team == Sim->GetSkaters()[Me].Team && S.Index != Me) return S.Index;
		return -1;
	}

	int32 Opponent(const UJamSim* Sim, int32 Me)
	{
		for (const FJamSkaterState& S : Sim->GetSkaters()) if (S.Team != Sim->GetSkaters()[Me].Team) return S.Index;
		return -1;
	}

	void GivePuck(UJamSim* Sim, int32 O)
	{
		const FJamSkaterState& S = Sim->GetSkaters()[O];
		Sim->SetPuck(S.Pos + S.Forward() * 0.45, FVector2D::ZeroVector);
		TArray<FJamInput> None;
		None.SetNum(Sim->GetSkaters().Num());
		Sim->Step(None);
	}

	int32 Count(const UJamSim* Sim, FName Name, int32 Who = -2)
	{
		int32 N = 0;
		for (const FJamSimEvent& E : Sim->GetFrameEvents()) if (E.Name == Name && (Who == -2 || E.Who == Who)) ++N;
		return N;
	}

// The test stays inside the namespace (no using-directive): unity builds merge files, and a file-scope using would make LoadPreset ambiguous elsewhere.
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamFeelDepth, "Jam.Core.FeelDepth", JamFeelDepthTests::Flags)
bool FJamFeelDepth::RunTest(const FString& Parameters)
{
	UJamCartridge* C = LoadPreset(*this, TEXT("hockey.regular"));
	if (C) { C->Game.Stick.PickupArcM = 0.0; C->Game.Stick.bPickupBody = false; }   // lane A208: re-staged at game.stick.pickup's neutral: this scene measures the C-0005 blade deflection, which the pickup arc replaces when on; the loose puck's pickup has its own (Jam.Core.Possession.*)
	if (!C) return false;
	JamBaseline::PassShotNeutral(C->Game);   // lane A207: this scene pins the pass and shot before game.pass.power / aim / catch_m / clear_own_body and game.shot.speed_scale: their neutral values
	const FJamGameConfig& G = C->Game;
	TestEqual(TEXT("pass_speed default 14"), G.Skater.PassSpeed, 14.0);
	TestEqual(TEXT("pass_lead_frames default 20"), G.Skater.PassLeadFrames, 20);
	TestEqual(TEXT("charge_frames_max default 30"), G.Shot.ChargeFramesMax, 30);
	TestEqual(TEXT("charge_speed_bonus default 8"), G.Shot.ChargeSpeedBonus, 8.0);
	TestTrue(TEXT("deflect default true"), G.Shot.bDeflect);
	TestEqual(TEXT("carry_assist default 0.6"), G.Puck.CarryAssist, 0.6);
	TestEqual(TEXT("puck.count default 1"), G.Puck.Count, 1);

	// PassReachesTeammate: a receiver crossing the lane at 5 m/s, 12 m up the ice, facing its motion; the pass (braked by puck.drag) must land on
	// its blade within pass_lead_frames of the flight time the drag curve predicts.
	{
		int32 Arrived = 0;
		TArray<FString> Rows;
		for (uint64 Seed = 1; Seed <= 10; ++Seed)
		{
			UJamSim* Sim = MakeSim(G, Seed);
			const int32 Me = Sim->GetHumanIndex();
			const int32 T = Teammate(Sim, Me);
			Park(Sim, { Me, T });
			Sim->SetSkater(Me, FVector2D(-20, 0), FVector2D::ZeroVector, 0);
			// The receiver crosses the lane (skating +z at 5 m/s, facing +z), 11..13 m up the ice, starting 2..5 m below the lane; varied per seed.
			const double Up = 11.0 + (Seed % 3);
			const double Below = -2.0 - 1.0 * (Seed % 4);
			Sim->SetSkater(T, FVector2D(-20.0 + Up, Below), FVector2D(0, 5), UE_DOUBLE_PI * 0.5);
			GivePuck(Sim, Me);
			TArray<FJamInput> In;
			In.SetNum(Sim->GetSkaters().Num());
			// The receiver glides (no input): a near-constant 5 m/s the lead can be checked against.
			In[Me].bPass = true;
			Sim->Step(In);
			In[Me].bPass = false;
			const bool bPassed = Count(Sim, JamEvents::Pass, Me) == 1;
			FString PassKind;
			for (const FJamSimEvent& E : Sim->GetFrameEvents()) if (E.Name == JamEvents::Pass) PassKind = E.Kind.ToString();
			const FVector2D V0 = Sim->GetPuck().Vel;
			const FVector2D P0 = Sim->GetPuck().Pos;
			// Expected flight from the same drag curve the sim uses: first t with (v0/k)(1 - e^(-kt)) >= |receiver(t) - puck|.
			const FVector2D PV = Sim->GetPuck().Vel;
			const double Vp = FMath::Max(1.0, PV.Size()), Kd = G.Puck.Drag;
			const FVector2D Rel0 = Sim->GetSkaters()[T].Pos - Sim->GetPuck().Pos;
			const FVector2D TV = Sim->GetSkaters()[T].Vel;
			double Tf = 4.0;
			for (int32 i = 1; i <= 400; ++i) { const double t = 0.01 * i; const double Flown = Kd > 1e-6 ? (Vp / Kd) * (1.0 - FMath::Exp(-Kd * t)) : Vp * t; if (Flown >= (Rel0 + TV * t).Size()) { Tf = t; break; } }
			const int32 Expected = FMath::RoundToInt32(Tf / UJamSim::DT);
			int32 ArriveFrame = -1;
			FString Trace;
			for (int32 F = 1; F <= 240 && ArriveFrame < 0; ++F)
			{
				Sim->Step(In);
				if (F % 20 == 0) Trace += FString::Printf(TEXT(" f%d:d%.1f,p(%.1f,%.1f),t(%.1f,%.1f),lt%d"), F, FVector2D::Distance(Sim->GetSkaters()[T].Pos, Sim->GetPuck().Pos), Sim->GetPuck().Pos.X, Sim->GetPuck().Pos.Y, Sim->GetSkaters()[T].Pos.X, Sim->GetSkaters()[T].Pos.Y, Sim->GetPuck().LastTouch);
				if (FVector2D::Distance(Sim->GetSkaters()[T].Pos, Sim->GetPuck().Pos) <= G.Shot.ReachM) ArriveFrame = F;
			}
			if (Seed <= 2) AddInfo(FString::Printf(TEXT("seed %llu trace: T=%d %s, pass v0 (%.1f,%.1f) from (%.1f,%.1f);%s"), Seed, T, *PassKind, V0.X, V0.Y, P0.X, P0.Y, *Trace));
			const bool bOk = bPassed && ArriveFrame > 0 && FMath::Abs(ArriveFrame - Expected) <= G.Skater.PassLeadFrames;
			if (bOk) ++Arrived;
			Rows.Add(FString::Printf(TEXT("seed %llu: passed %d, expected %d frames, arrived %d"), Seed, bPassed ? 1 : 0, Expected, ArriveFrame));
		}
		for (const FString& R : Rows) AddInfo(R);
		TestTrue(*FString::Printf(TEXT("PassReachesTeammate: %d of 10 seeds within pass_lead_frames (need 9)"), Arrived), Arrived >= 9);
	}

	// ChargeShot: hold 0 (tap), 15 and 30 frames; the exit speed grows with the hold, capped at puck.max_speed.
	{
		TArray<double> Speeds;
		for (const int32 Hold : { 0, 15, 30, 60 })
		{
			UJamSim* Sim = MakeSim(G, 1);
			const int32 Me = Sim->GetHumanIndex();
			Park(Sim, { Me });
			Sim->SetSkater(Me, FVector2D(0, 0), FVector2D::ZeroVector, 0);
			GivePuck(Sim, Me);
			TArray<FJamInput> In;
			In.SetNum(Sim->GetSkaters().Num());
			double Exit = 0;
			if (Hold == 0)
			{
				In[Me].bShoot = true;
				Sim->Step(In);
			}
			else
			{
				In[Me].bShootHeld = true;
				for (int32 F = 0; F < Hold; ++F) Sim->Step(In);
				TestEqual(*FString::Printf(TEXT("charge after %d held frames"), Hold), Sim->GetSkaters()[Me].ChargeFrames, FMath::Min(Hold, G.Shot.ChargeFramesMax));
				In[Me].bShootHeld = false;
				Sim->Step(In);
			}
			TestEqual(*FString::Printf(TEXT("hold %d: one shot"), Hold), Count(Sim, JamEvents::Shot, Me), 1);
			Exit = Sim->GetPuck().Vel.Size();
			Speeds.Add(Exit);
			AddInfo(FString::Printf(TEXT("hold %d frames: exit %.2f m/s, charge %.2f"), Hold, Exit, Sim->GetSkaters()[Me].LastShotCharge));
		}
		if (Speeds.Num() == 4)
		{
			TestTrue(TEXT("tap shoots at shot.speed"), FMath::IsNearlyEqual(Speeds[0], FMath::Min(G.Shot.Speed, G.Puck.MaxSpeed), 0.6));
			TestTrue(TEXT("half hold is faster than a tap"), Speeds[1] > Speeds[0] + 2.0);
			TestTrue(TEXT("full hold is faster than half"), Speeds[2] > Speeds[1] + 2.0);
			TestTrue(TEXT("full hold = speed + bonus"), FMath::IsNearlyEqual(Speeds[2], FMath::Min(G.Shot.Speed + G.Shot.ChargeSpeedBonus, G.Puck.MaxSpeed), 0.6));
			TestTrue(TEXT("holding past the max adds nothing"), FMath::IsNearlyEqual(Speeds[3], Speeds[2], 0.3));
		}
	}

	// DeflectionConserves: a 20 m/s puck through a parked skater's blade leaves at 70 % (and is credited to that skater).
	{
		UJamSim* Sim = MakeSim(G, 1);
		const int32 Me = Sim->GetHumanIndex();
		const int32 O = Opponent(Sim, Me);
		Park(Sim, { O });
		Sim->SetSkater(O, FVector2D(0, 0), FVector2D::ZeroVector, UE_DOUBLE_PI);   // faces -x
		Sim->SetPuck(FVector2D(20, 15), FVector2D::ZeroVector);                       // away from everybody for the setup step
		TArray<FJamInput> In;
		In.SetNum(Sim->GetSkaters().Num());
		In[O].Stick = FVector2D(-0.5, 0);   // an aimed stick (only an aimed blade deflects); blade 1.2 m towards -x
		Sim->Step(In);
		const FVector2D Blade = Sim->GetSkaters()[O].BladePos;
		// A puck coming from -x along the blade's line, aimed a little off the blade so it does not hit the body first; shot by the human (an opponent).
		Sim->SetPuck(Blade + FVector2D(-3.0, 0.25), FVector2D(20, 0));
		Sim->SetSkater(Me, Blade + FVector2D(-3.6, 0.25), FVector2D::ZeroVector, 0);
		Sim->SetPuck(Blade + FVector2D(-3.1, 0.25), FVector2D::ZeroVector);
		Sim->Step(In);   // the human touches it: LastTouch = an opponent of O
		Sim->SetPuck(Blade + FVector2D(-3.0, 0.25), FVector2D(20, 0));
		Sim->SetSkater(Me, FVector2D(-30, -15), FVector2D::ZeroVector, 0);
		double Before = 20.0, After = -1;
		int32 HitFrame = -1;
		for (int32 F = 1; F <= 30 && HitFrame < 0; ++F)
		{
			Sim->Step(In);
			if (Sim->GetPuck().LastTouch == O) { HitFrame = F; After = Sim->GetPuck().Vel.Size(); }
		}
		AddInfo(FString::Printf(TEXT("deflection at frame %d: %.2f -> %.2f m/s (ratio %.3f), puck velocity (%.2f, %.2f)"), HitFrame, Before, After, After / Before, Sim->GetPuck().Vel.X, Sim->GetPuck().Vel.Y));
		TestTrue(TEXT("the shot touched the blade"), HitFrame > 0);
		// Drag over the 3 m of approach costs about 1 % per 0.15 s; allow 10 % of slack around 70 %.
		TestTrue(TEXT("deflection keeps about 70 %"), After > Before * 0.6 && After < Before * 0.78);
		TestTrue(TEXT("the puck bounces back off the blade"), Sim->GetPuck().Vel.X < 0.0);
		// With deflect off the body only pushes: the puck keeps going past.
		FJamGameConfig NoDef = G;
		NoDef.Shot.bDeflect = false;
		UJamSim* S2 = MakeSim(NoDef, 1);
		Park(S2, { O });
		S2->SetSkater(O, FVector2D(0, 0), FVector2D::ZeroVector, UE_DOUBLE_PI);
		S2->SetPuck(FVector2D(20, 15), FVector2D::ZeroVector);
		S2->Step(In);   // In[O].Stick still aimed
		S2->SetSkater(Me, S2->GetSkaters()[O].BladePos + FVector2D(-3.6, 0.25), FVector2D::ZeroVector, 0);
		S2->SetPuck(S2->GetSkaters()[O].BladePos + FVector2D(-3.1, 0.25), FVector2D::ZeroVector);
		S2->Step(In);
		S2->SetPuck(S2->GetSkaters()[O].BladePos + FVector2D(-3.0, 0.25), FVector2D(20, 0));
		S2->SetSkater(Me, FVector2D(-30, -15), FVector2D::ZeroVector, 0);
		for (int32 F = 1; F <= 30; ++F) S2->Step(In);
		TestTrue(TEXT("deflect off: the puck is not bounced back"), S2->GetPuck().Vel.X > 0.0);
	}

	// StripOnCheck: a check that lands on the carrier takes the puck off it every time (10 seeds).
	{
		int32 Strips = 0, Landed = 0;
		for (uint64 Seed = 1; Seed <= 10; ++Seed)
		{
			UJamSim* Sim = MakeSim(G, Seed);
			const int32 Me = Sim->GetHumanIndex();
			const int32 O = Opponent(Sim, Me);
			Park(Sim, { Me, O });
			// The carrier skates +x slowly; the checker comes from the side (a legal check: the carrier has the puck, the hit is not from behind).
			Sim->SetSkater(O, FVector2D(0, 0), FVector2D(2, 0), 0);
			Sim->SetSkater(Me, FVector2D(0.6, -2.4), FVector2D(0, 8), UE_DOUBLE_PI * 0.5);
			GivePuck(Sim, O);
			TArray<FJamInput> In;
			In.SetNum(Sim->GetSkaters().Num());
			In[O].Move = FVector2D(1, 0);
			In[Me].Move = FVector2D(0, 1);
			In[Me].bCheck = true;
			bool bHit = false;
			for (int32 F = 0; F < 12 && !bHit; ++F)
			{
				Sim->Step(In);
				In[Me].bCheck = (F % 4 == 3);   // keep the window alive until contact
				bHit = Count(Sim, JamEvents::Check, Me) > 0;
			}
			if (!bHit) { AddInfo(FString::Printf(TEXT("seed %llu: the check did not land"), Seed)); continue; }
			++Landed;
			const bool bFoul = Count(Sim, JamEvents::Foul) > 0;
			const bool bStripped = Sim->GetPuck().LastTouch != O;
			if (bStripped) ++Strips;
			AddInfo(FString::Printf(TEXT("seed %llu: landed, stripped %d, foul %d, puck %.2f m from the carrier"), Seed, bStripped ? 1 : 0, bFoul ? 1 : 0, FVector2D::Distance(Sim->GetSkaters()[O].Pos, Sim->GetPuck().Pos)));
		}
		TestTrue(TEXT("the side check lands in most seeds"), Landed >= 8);
		TestEqual(TEXT("StripOnCheck: every landed check on the carrier strips the puck"), Strips, Landed);
	}
	return true;
}

} // namespace JamFeelDepthTests

#endif
