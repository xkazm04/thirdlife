// Lane A77 (R-0036): the saucer pass. Jam.Core.SaucerPass: a held pass (bPassHeld for pass.saucer.half_frames, then released) over a defender whose blade is in the lane
// and whose body is off the line: the sim refuses the flat pass (no lane), accepts the saucer, the puck is over BladeClearM when it passes the blade, lands before the
// receiver and is received without the defender touching it; a tap and a short hold stay flat (Z 0 the whole way); half_frames 0 turns the saucer off; the keys read back.
// Headless scripted scenes on UJamSim (no brain). docs/experiments/MECHANICS.md.
//   UnrealEditor-Cmd.exe Game/ThirdJam.uproject -ExecCmds="Automation RunTests Jam.Core.SaucerPass; Quit" -unattended -nullrhi -nosplash -log
#include "Misc/AutomationTest.h"
#include "JamCartridge.h"
#include "JamSim.h"
#include "JamBaseline.h"   // lane A207: PassShotNeutral
#include "JamEventBus.h"

#if WITH_DEV_AUTOMATION_TESTS

namespace JamSaucerTests
{
	constexpr EAutomationTestFlags Flags = EAutomationTestFlags_ApplicationContextMask | EAutomationTestFlags::ProductFilter;

	UJamCartridge* LoadPreset(FAutomationTestBase& T, const FString& Name)
	{
		TArray<FString> Errors;
		UJamCartridge* C = UJamCartridge::LoadFromFile(UJamCartridge::ResolveCartridgePath(Name), Errors);
		for (const FString& E : Errors) T.AddError(FString::Printf(TEXT("%s: %s"), *Name, *E));
		return C;
	}

	struct FSaucerScene
	{
		UJamSim* Sim = nullptr;
		int32 Me = -1, Mate = -1, Def = -1;
		double Dir = 1.0;
		TArray<FJamInput> In;

		// The human (team 0) at the origin facing its goal, a teammate 10 m up the ice facing it, a defender 5 m up the ice LaneOffM off the line with its blade
		// aimed at the line; everyone else parked in the far corner.
		FSaucerScene(const FJamGameConfig& G, uint64 Seed, double LaneOffM)
		{
			Sim = NewObject<UJamSim>();
			Sim->Init(G, Seed);
			Sim->SkipFaceoff();
			Me = Sim->GetHumanIndex();
			Dir = Sim->AttackGoalX(0) > 0 ? 1.0 : -1.0;
			for (const FJamSkaterState& S : Sim->GetSkaters())
			{
				if (S.Index == Me) continue;
				if (Mate < 0 && S.Team == 0) { Mate = S.Index; continue; }
				if (Def < 0 && S.Team != 0) { Def = S.Index; continue; }
				Sim->SetSkater(S.Index, FVector2D(-35.0 + S.Index * 2.0, 18.0), FVector2D::ZeroVector, 0);
			}
			const double Yaw = Dir > 0 ? 0.0 : PI;
			Sim->SetSkater(Me, FVector2D(0.0, 0.0), FVector2D::ZeroVector, Yaw);
			Sim->SetSkater(Mate, FVector2D(Dir * 10.0, 0.0), FVector2D::ZeroVector, Yaw + PI);
			Sim->SetSkater(Def, FVector2D(Dir * 5.0, LaneOffM), FVector2D::ZeroVector, Yaw + PI);
			In.SetNum(Sim->GetSkaters().Num());
			In[Me].Stick = FVector2D(Dir, 0.0) * 0.5;
			In[Def].Stick = FVector2D(0.0, -1.0) * 0.6;   // the blade 1.12 m toward the line: on it
			// Give the puck: against the body (a touch: LastTouch), then a few quiet frames in which the carry assist seats it on the aimed blade (A51's GivePuck).
			Sim->SetPuck(FVector2D(Dir * 0.45, 0.0), FVector2D::ZeroVector);
			for (int32 i = 0; i < 6; ++i) Sim->Step(In);
		}
		void Step() { Sim->Step(In); }
	};

	FString PassKind(const UJamSim* Sim, int32 Who)
	{
		for (const FJamSimEvent& E : Sim->GetFrameEvents()) if (E.Name == JamEvents::Pass && E.Who == Who) return E.Kind.ToString();
		return TEXT("");
	}

	struct FFlight { double MaxZ = 0, ZAtDef = -1, LandDistToMate = -1; int64 LandFrame = -1; bool bDefTouched = false, bMateReceived = false; int32 FramesToMate = -1; };
	// Landed: on the ice or inside the dying 3 cm hop of the landing (Z < 0.05 after the arc).
	FFlight Fly(FSaucerScene& Sc, int32 MaxFrames)
	{
		FFlight R;
		const double DefX = Sc.Sim->GetSkaters()[Sc.Def].Pos.X;
		bool bPassedDef = false;
		const int32 DefTouches0 = Sc.Sim->GetSkaters()[Sc.Def].Touches;
		for (int32 f = 0; f < MaxFrames; ++f)
		{
			Sc.Step();
			const FJamPuckState& P = Sc.Sim->GetPuck();
			R.MaxZ = FMath::Max(R.MaxZ, P.Z);
			if (!bPassedDef && (P.Pos.X - DefX) * Sc.Dir >= 0.0) { bPassedDef = true; R.ZAtDef = P.Z; }
			if (R.LandFrame < 0 && f > 2 && R.MaxZ > 0.1 && P.Z < 0.05) { R.LandFrame = f; R.LandDistToMate = FVector2D::Distance(P.Pos, Sc.Sim->GetSkaters()[Sc.Mate].Pos); }
			if (P.LastTouch == Sc.Def || Sc.Sim->GetSkaters()[Sc.Def].Touches != DefTouches0) R.bDefTouched = true;
			if (P.LastTouch == Sc.Mate) { R.bMateReceived = true; R.FramesToMate = f; break; }
		}
		return R;
	}
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamSaucerPass, "Jam.Core.SaucerPass", JamSaucerTests::Flags)
bool FJamSaucerPass::RunTest(const FString& Parameters)
{
	using namespace JamSaucerTests;
	UJamCartridge* C = LoadPreset(*this, TEXT("hockey.regular"));
	if (!C) return false;
	JamBaseline::PassShotNeutral(C->Game);   // lane A207: this scene pins the pass and shot before game.pass.power / aim / catch_m / clear_own_body and game.shot.speed_scale: their neutral values
	const FJamGameConfig& G = C->Game;
	TestEqual(TEXT("pass.saucer.half_frames default 8"), G.Pass.SaucerHalfFrames, 8);
	TestEqual(TEXT("pass.saucer.lift_m default 0.35"), G.Pass.SaucerLiftM, 0.35);

	// Lane A82 (R-0040 point 2): the lane margin 0.9 m and the airborne window from 1.5 m along, the sim's constants.
	TestEqual(TEXT("SaucerLaneMinM 0.9"), UJamSim::SaucerLaneMinM, 0.9);
	TestEqual(TEXT("SaucerAirFromM 1.5"), UJamSim::SaucerAirFromM, 1.5);
	// (a) The saucer over a blade in the lane: the body 1.0 m off the line (lane A82: at the 0.9 margin the flat rule allows this lane too; the blade on the line
	// deflects the flat pass, the saucer flies over it), the blade on the line.
	for (uint64 Seed = 1; Seed <= 3; ++Seed)
	{
		{
			FSaucerScene Flat(G, Seed, 1.0);
			FVector2D AimF;
			TestEqual(FString::Printf(TEXT("seed %llu: the flat rule allows the lane (the body 1.0 m off the line)"), Seed), Flat.Sim->BestPass(Flat.Me, AimF, false), Flat.Mate);
			Flat.In[Flat.Me].bPass = true; Flat.Step(); Flat.In[Flat.Me].bPass = false;
			const FFlight RF = Fly(Flat, 120);
			AddInfo(FString::Printf(TEXT("seed %llu: the flat pass through the blade: defender touched %d, mate received %d (max Z %.3f)"), Seed, RF.bDefTouched ? 1 : 0, RF.bMateReceived ? 1 : 0, RF.MaxZ));
			TestTrue(FString::Printf(TEXT("seed %llu: the flat pass does not arrive clean past the blade on the line"), Seed), RF.bDefTouched || !RF.bMateReceived);
		}
		FSaucerScene Sc(G, Seed, 1.0);
		TestEqual(FString::Printf(TEXT("seed %llu: the human carries"), Seed), Sc.Sim->CarrierIndex(), Sc.Me);
		FVector2D Aim;
		TestEqual(FString::Printf(TEXT("seed %llu: a body 0.8 m off the line refuses the saucer too (the margin)"), Seed), FSaucerScene(G, Seed, 0.8).Sim->BestPass(Sc.Me, Aim, true), -1);
		TestEqual(FString::Printf(TEXT("seed %llu: the saucer has the teammate"), Seed), Sc.Sim->BestPass(Sc.Me, Aim, true), Sc.Mate);
		for (int32 i = 0; i < G.Pass.SaucerHalfFrames; ++i) { Sc.In[Sc.Me].bPassHeld = true; Sc.Step(); }
		TestEqual(FString::Printf(TEXT("seed %llu: the charge sits at half_frames while held"), Seed), Sc.Sim->GetSkaters()[Sc.Me].PassChargeFrames, G.Pass.SaucerHalfFrames);
		Sc.In[Sc.Me].bPassHeld = false;
		Sc.Step();   // the release
		const FString Kind = PassKind(Sc.Sim, Sc.Me);
		TestTrue(FString::Printf(TEXT("seed %llu: the release passes a saucer (kind %s)"), Seed, *Kind), Kind.StartsWith(TEXT("saucer_to_")));
		TestTrue(FString::Printf(TEXT("seed %llu: bSaucerThisFrame"), Seed), Sc.Sim->GetSkaters()[Sc.Me].bSaucerThisFrame);
		TestTrue(FString::Printf(TEXT("seed %llu: the puck left the ice (VZ %.2f)"), Seed, Sc.Sim->GetPuck().VZ), Sc.Sim->GetPuck().VZ > 1.0);
		const FFlight R = Fly(Sc, 120);
		AddInfo(FString::Printf(TEXT("seed %llu saucer: max Z %.3f, Z at the defender %.3f, landed frame %lld at %.2f m from the receiver, received %d after %d frames, defender touched %d"),
			Seed, R.MaxZ, R.ZAtDef, R.LandFrame, R.LandDistToMate, R.bMateReceived ? 1 : 0, R.FramesToMate, R.bDefTouched ? 1 : 0));
		TestTrue(FString::Printf(TEXT("seed %llu: over the blade at the defender (Z %.3f >= %.2f)"), Seed, R.ZAtDef, UJamSim::BladeClearM), R.ZAtDef >= UJamSim::BladeClearM);
		TestTrue(FString::Printf(TEXT("seed %llu: the apex under lift_m + 5 cm (%.3f)"), Seed, R.MaxZ), R.MaxZ <= G.Pass.SaucerLiftM + 0.05 && R.MaxZ >= G.Pass.SaucerLiftM * 0.6);
		TestTrue(FString::Printf(TEXT("seed %llu: landed before the receiver (%.2f m short)"), Seed, R.LandDistToMate), R.LandFrame >= 0 && R.LandDistToMate > 0.8);
		TestFalse(FString::Printf(TEXT("seed %llu: the defender never touched it"), Seed), R.bDefTouched);
		TestTrue(FString::Printf(TEXT("seed %llu: the teammate received it"), Seed), R.bMateReceived);
	}
	// (b) A tap with an open lane stays flat; (c) a short hold too.
	{
		FSaucerScene Sc(G, 1, 4.0);
		FVector2D Aim;
		TestEqual(TEXT("open lane: the flat pass has the teammate"), Sc.Sim->BestPass(Sc.Me, Aim, false), Sc.Mate);
		Sc.In[Sc.Me].bPass = true; Sc.Step(); Sc.In[Sc.Me].bPass = false;
		TestTrue(TEXT("the tap passes flat (kind to_N)"), PassKind(Sc.Sim, Sc.Me).StartsWith(TEXT("to_")));
		const FFlight R = Fly(Sc, 120);
		TestEqual(TEXT("the tap's puck never leaves the ice"), R.MaxZ, 0.0);
		TestTrue(TEXT("the tap is received"), R.bMateReceived);
	}
	{
		FSaucerScene Sc(G, 1, 4.0);
		for (int32 i = 0; i < G.Pass.SaucerHalfFrames / 2; ++i) { Sc.In[Sc.Me].bPassHeld = true; Sc.Step(); }
		Sc.In[Sc.Me].bPassHeld = false; Sc.Step();
		TestTrue(TEXT("a hold under half_frames passes flat on the release"), PassKind(Sc.Sim, Sc.Me).StartsWith(TEXT("to_")));
		const FFlight R = Fly(Sc, 120);
		TestEqual(TEXT("the short hold's puck never leaves the ice"), R.MaxZ, 0.0);
	}
	// (d) half_frames 0: the saucer is off, a long hold is a flat pass; the keys read back from a cartridge text.
	{
		FString Raw = C->RawJson;
		if (Raw.Find(TEXT("\"shot\": {")) < 0) { AddError(TEXT("hockey.regular's RawJson has no \"shot\": { to splice the keys before")); return false; }
		TArray<FString> Errors;
		UJamCartridge* Off = UJamCartridge::LoadFromString(Raw.Replace(TEXT("\"shot\": {"), TEXT("\"pass\": {\"saucer\": {\"half_frames\": 0, \"lift_m\": 0.35}}, \"shot\": {")), Errors);
		for (const FString& E : Errors) AddError(FString::Printf(TEXT("half_frames 0 variant: %s"), *E));
		if (Off)
		{
			TestEqual(TEXT("half_frames 0 read"), Off->Game.Pass.SaucerHalfFrames, 0);
			const FJamGameConfig& GOff = Off->Game;
			FSaucerScene Sc(GOff, 1, 4.0);
			for (int32 i = 0; i < 12; ++i) { Sc.In[Sc.Me].bPassHeld = true; Sc.Step(); }
			Sc.In[Sc.Me].bPassHeld = false; Sc.Step();
			TestTrue(TEXT("with the saucer off a 12-frame hold passes flat"), PassKind(Sc.Sim, Sc.Me).StartsWith(TEXT("to_")));
			TestEqual(TEXT("with the saucer off the puck stays on the ice"), Fly(Sc, 120).MaxZ, 0.0);
		}
		Errors.Reset();
		UJamCartridge* V = UJamCartridge::LoadFromString(Raw.Replace(TEXT("\"shot\": {"), TEXT("\"pass\": {\"saucer\": {\"half_frames\": 12, \"lift_m\": 0.5}}, \"shot\": {")), Errors);
		for (const FString& E : Errors) AddError(FString::Printf(TEXT("keys variant: %s"), *E));
		if (V)
		{
			TestEqual(TEXT("half_frames 12 read"), V->Game.Pass.SaucerHalfFrames, 12);
			TestEqual(TEXT("lift_m 0.5 read"), V->Game.Pass.SaucerLiftM, 0.5);
		}
		Errors.Reset();
		UJamCartridge* Bad = UJamCartridge::LoadFromString(Raw.Replace(TEXT("\"shot\": {"), TEXT("\"pass\": {\"saucer\": {\"height\": 1}}, \"shot\": {")), Errors);
		TestTrue(TEXT("an unknown key under pass.saucer is rejected"), Bad == nullptr || Errors.Num() > 0);
	}
	return true;
}

#endif
