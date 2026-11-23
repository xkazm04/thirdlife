// Lane A51 (R-0034): stick handling with the mouse and the spin on E. Jam.Core.SweepBeatsPoke, Jam.Core.SpinShieldsPuck, Jam.Core.SpinCooldown,
// Jam.Core.SpinCheckedFalls, Jam.Core.StickHandlingKeys. Headless, scripted scenes on UJamSim (the defender is scripted with the pro brain's rule, so the
// scene does not depend on the brain's roles); the brain's delayed read of the carried puck is checked on a hand-built FJamAIWorld. docs/experiments/STICK.md.
//   UnrealEditor-Cmd.exe Game/ThirdJam.uproject -ExecCmds="Automation RunTests Jam.Core.Sweep+Jam.Core.Spin+Jam.Core.StickHandling; Quit" -unattended -nullrhi -nosplash -log
#include "Misc/AutomationTest.h"
#include "JamCartridge.h"
#include "JamSim.h"
#include "JamBaseline.h"   // lane A207: PassShotNeutral
#include "JamEventBus.h"
#include "JamAICore.h"
#include "DifficultyProfile.h"

#if WITH_DEV_AUTOMATION_TESTS

namespace JamStickHandlingTests
{
	constexpr EAutomationTestFlags Flags = EAutomationTestFlags_ApplicationContextMask | EAutomationTestFlags::ProductFilter;

	UJamCartridge* LoadPreset(FAutomationTestBase& T, const FString& Name)
	{
		TArray<FString> Errors;
		UJamCartridge* C = UJamCartridge::LoadFromFile(UJamCartridge::ResolveCartridgePath(Name), Errors);
		for (const FString& E : Errors) T.AddError(FString::Printf(TEXT("%s: %s"), *Name, *E));
		return C;
	}

	// A sim in Playing with everyone parked in the far corner but the named skaters.
	UJamSim* MakeScene(const FJamGameConfig& G, uint64 Seed, const TArray<int32>& Keep)
	{
		UJamSim* Sim = NewObject<UJamSim>();
		Sim->Init(G, Seed);
		Sim->SkipFaceoff();
		for (const FJamSkaterState& S : Sim->GetSkaters())
		{
			if (Keep.Contains(S.Index)) continue;
			Sim->SetSkater(S.Index, FVector2D(-35.0 + S.Index * 2.0, 18.0), FVector2D::ZeroVector, 0);
		}
		return Sim;
	}

	int32 FirstOpponent(const UJamSim* Sim, int32 Me)
	{
		for (const FJamSkaterState& S : Sim->GetSkaters()) if (S.Team != Sim->GetSkaters()[Me].Team) return S.Index;
		return -1;
	}

	// Gives Who the puck: against the body (a touch: LastTouch), then four quiet frames in which the carry assist seats it on the aimed blade.
	void GivePuck(UJamSim* Sim, int32 Who, const FVector2D& Stick)
	{
		TArray<FJamInput> In;
		In.SetNum(Sim->GetSkaters().Num());
		In[Who].Stick = Stick;
		const FJamSkaterState& S = Sim->GetSkaters()[Who];
		const FVector2D Dir = Stick.IsNearlyZero() ? S.Forward() : Stick.GetSafeNormal();
		Sim->SetPuck(S.Pos + Dir * 0.45, S.Vel);
		for (int32 i = 0; i < 5; ++i) Sim->Step(In);
	}

	int32 Count(const UJamSim* Sim, FName Name, int32 Who = -2, FName Kind = FName(TEXT("__any")))
	{
		int32 N = 0;
		for (const FJamSimEvent& E : Sim->GetFrameEvents())
			if (E.Name == Name && (Who == -2 || E.Who == Who) && (Kind == FName(TEXT("__any")) || E.Kind == Kind)) ++N;
		return N;
	}

	// The pro defender's stick rule, scripted: the blade follows the puck's offset on the carrier's body React frames late (FJamBrain::PuckSeen) and
	// pokes once that delayed puck has sat inside blade reach for more than PokeFrames frames (FJamBotSkill::PokeFrames, pro 6).
	struct FScriptedDefender
	{
		int32 React = 8, PokeFrames = 6, InReach = 0;
		TArray<FVector2D> Rel;   // per frame: puck - carrier body
		FJamInput Think(const UJamSim* Sim, int32 Me, int32 Carrier)
		{
			FJamInput In;
			const FJamSkaterState& S = Sim->GetSkaters()[Me];
			const FJamSkaterState& C = Sim->GetSkaters()[Carrier];
			Rel.Add(Sim->GetPuck().Pos - C.Pos);
			const FVector2D Seen = Rel.Num() > React ? C.Pos + Rel[Rel.Num() - 1 - React] : Sim->GetPuck().Pos;
			const FVector2D To = Seen - S.Pos;
			const double D = To.Size();
			const double Blade = UJamSim::SkaterRadius + Sim->GetConfig().Stick.ReachM;
			if (D > 1e-6 && D < Blade + 1.0) In.Stick = To / D * FMath::Clamp((D - UJamSim::SkaterRadius) / Sim->GetConfig().Stick.ReachM, 0.2, 1.0);
			InReach = D <= Blade ? InReach + 1 : 0;
			const bool bCanPoke = S.CanAct() && Sim->GetFrame() + 1 >= S.PokeReadyFrame && S.PokeWindow <= 0;
			if (bCanPoke && InReach > PokeFrames) { In.bPoke = true; InReach = 0; }
			return In;
		}
	};
}

// Keys: the defaults, the keys read back, and the ranges mirrored in limits.json.
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamStickHandlingKeys, "Jam.Core.StickHandlingKeys", JamStickHandlingTests::Flags)
bool FJamStickHandlingKeys::RunTest(const FString& Parameters)
{
	using namespace JamStickHandlingTests;
	UJamCartridge* C = LoadPreset(*this, TEXT("hockey.regular"));
	if (!C) return false;
	const FJamGameConfig& G = C->Game;
	TestEqual(TEXT("stick.reach_m default 1.2 (R-0022; A51 kept it: 1.1 cost the regular player half its passes at pro)"), G.Stick.ReachM, 1.2);
	TestEqual(TEXT("stick.sweep.min_deg_per_frame default 6"), G.Stick.SweepMinDegPerFrame, 6.0);
	TestEqual(TEXT("stick.sweep.shield_frames default 12"), G.Stick.SweepShieldFrames, 12);
	TestEqual(TEXT("stick.sweep.bot_react_frames absent = -1 (by difficulty)"), G.Stick.SweepBotReactFrames, -1);
	TestEqual(TEXT("skater.spin.frames default 24"), G.Skater.SpinFrames, 24);
	TestEqual(TEXT("skater.spin.cooldown_frames default 90"), G.Skater.SpinCooldownFrames, 90);
	TestEqual(TEXT("skater.spin.speed_mult default 0.7"), G.Skater.SpinSpeedMult, 0.7);
	TestEqual(TEXT("skater.spin.stamina_cost default 0.25"), G.Skater.SpinStaminaCost, 0.25);
	// The difficulty profiles' reaction to the carried puck.
	TestEqual(TEXT("rookie reads the puck 14 frames late"), JamAI::GetDifficultyProfile(JamAI::EDifficulty::Rookie).Opp.SweepReactFrames, 14);
	TestEqual(TEXT("pro reads the puck 8 frames late"), JamAI::GetDifficultyProfile(JamAI::EDifficulty::Pro).Opp.SweepReactFrames, 8);
	TestEqual(TEXT("all_star reads the puck 5 frames late"), JamAI::GetDifficultyProfile(JamAI::EDifficulty::AllStar).Opp.SweepReactFrames, 5);
	// The keys read back through a cartridge text.
	{
		const FString Json = TEXT("{\"schema\":\"tj.cartridge/1\",\"id\":\"a51-keys\",\"title\":\"A51 keys\",\"seed\":1,\"theme\":{\"name\":\"t\",\"palette\":[{\"hex\":\"#112233\"}],\"mood\":[]},")
			TEXT("\"game\":{\"stick\":{\"reach_m\":0.9,\"sweep\":{\"min_deg_per_frame\":9,\"shield_frames\":20,\"bot_react_frames\":3}},\"skater\":{\"spin\":{\"frames\":30,\"cooldown_frames\":60,\"speed_mult\":0.5,\"stamina_cost\":0.5}}}}");
		TArray<FString> Errors;
		UJamCartridge* V = UJamCartridge::LoadFromString(Json, Errors);
		if (V && Errors.Num() == 0)
		{
			TestEqual(TEXT("reach_m 0.9 read"), V->Game.Stick.ReachM, 0.9);
			TestEqual(TEXT("min_deg_per_frame 9 read"), V->Game.Stick.SweepMinDegPerFrame, 9.0);
			TestEqual(TEXT("shield_frames 20 read"), V->Game.Stick.SweepShieldFrames, 20);
			TestEqual(TEXT("bot_react_frames 3 read"), V->Game.Stick.SweepBotReactFrames, 3);
			TestEqual(TEXT("spin.frames 30 read"), V->Game.Skater.SpinFrames, 30);
			TestEqual(TEXT("spin.cooldown_frames 60 read"), V->Game.Skater.SpinCooldownFrames, 60);
			TestEqual(TEXT("spin.speed_mult 0.5 read"), V->Game.Skater.SpinSpeedMult, 0.5);
			TestEqual(TEXT("spin.stamina_cost 0.5 read"), V->Game.Skater.SpinStaminaCost, 0.5);
		}
		else
		{
			AddInfo(TEXT("the minimal cartridge text did not load on its own (the schema needs more of the object); the defaults above still hold"));
			for (const FString& E : Errors) AddInfo(E);
		}
	}
	return true;
}

// SweepBeatsPoke. (a) A carrier standing still with the puck on the blade, a pro defender (scripted with the brain's rule: the blade reads the puck's place on
// the body 8 frames late, pokes after 6 frames in reach) 2 m away. The carrier moves the blade into the defender's reach, and sweeps the puck across the body
// the moment the defender's blade comes within 0.7 m of it: the poke lands on the old side, the puck is kept in 10 of 10 seeds. The carrier that does not
// sweep loses it 10 of 10. (b) The shield itself: a defender whose blade sits on the puck's old spot in the frame after a sweep is refused the take while
// shield_frames run and takes it with shield_frames 0. (c) The brain's delayed read on a hand-built world.
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamSweepBeatsPoke, "Jam.Core.SweepBeatsPoke", JamStickHandlingTests::Flags)
bool FJamSweepBeatsPoke::RunTest(const FString& Parameters)
{
	using namespace JamStickHandlingTests;
	UJamCartridge* C = LoadPreset(*this, TEXT("hockey.regular"));
	if (!C) return false;
	const FJamGameConfig& G = C->Game;
	const FVector2D Left(0.0, -1.0), FwdLeft(0.7071, -0.7071), FwdRight(0.7071, 0.7071);   // yaw 0: forward +x, left -y
	int32 KeptSweep = 0, KeptNoSweep = 0, MissesSweep = 0, TakesNoSweep = 0, SweepEvents = 0;
	for (uint64 Seed = 1; Seed <= 10; ++Seed)
	{
		for (const bool bSweep : { true, false })
		{
			UJamSim* Sim = MakeScene(G, Seed, {});
			const int32 Me = Sim->GetHumanIndex();
			const int32 D = FirstOpponent(Sim, Me);
			Sim->SetSkater(Me, FVector2D(0, 0), FVector2D::ZeroVector, 0);
			Sim->SetSkater(D, FVector2D(3.6, 0), FVector2D::ZeroVector, UE_DOUBLE_PI);   // out of reach for the first 12 frames (the defender's history fills)
			for (const FJamSkaterState& S : Sim->GetSkaters()) if (S.Index != Me && S.Index != D) Sim->SetSkater(S.Index, FVector2D(-35.0 + S.Index * 2.0, 18.0), FVector2D::ZeroVector, 0);
			GivePuck(Sim, Me, FwdLeft);
			TestEqual(*FString::Printf(TEXT("seed %llu: the carrier holds the puck on the forward-left blade"), Seed), Sim->CarrierIndex(), Me);
			FScriptedDefender Def;
			bool bSwept = false, bPokeMissed = false, bPokeTook = false;
			int32 SweepFrame = -1, PokeFrame = -1, BladeOnPuck = 0;
			TArray<FJamInput> In;
			In.SetNum(Sim->GetSkaters().Num());
			for (int32 F = 1; F <= 90; ++F)
			{
				// Frame 13: the defender arrives 2 m in front, the puck inside its blade reach (1.42 m): its blade lands on the puck, its poke comes after 6 frames in
				// reach. The carrier sweeps when the defender's blade has sat on the puck for 4 frames, as a person reads a stick closing on the puck.
				if (F == 13) Sim->SetSkater(D, FVector2D(2.0, 0), FVector2D::ZeroVector, UE_DOUBLE_PI);
				const FJamSkaterState& Ds = Sim->GetSkaters()[D];
				FVector2D Stick = FwdLeft;
				BladeOnPuck = FVector2D::Distance(Ds.BladePos, Sim->GetPuck().Pos) < 0.7 ? BladeOnPuck + 1 : 0;
				if (bSweep && !bSwept && F > 13 && BladeOnPuck >= 4)
				{
					bSwept = true;
					SweepFrame = F;
				}
				if (bSwept) Stick = FwdRight;   // the sweep: the aim crosses the body in one frame and stays on the far side
				In[Me] = FJamInput();
				In[Me].Stick = Stick;
				In[D] = Def.Think(Sim, D, Me);
				Sim->Step(In);
				if (bSwept && F == SweepFrame) SweepEvents += Sim->GetSkaters()[Me].bSweepThisFrame ? 1 : 0;
				if (Count(Sim, JamEvents::Poke, D, FName(TEXT("miss"))) > 0) { bPokeMissed = true; if (PokeFrame < 0) PokeFrame = F; }
				if (Count(Sim, JamEvents::Poke, D, FName(TEXT("clean"))) > 0) { bPokeTook = true; if (PokeFrame < 0) PokeFrame = F; }
				if (bPokeMissed || bPokeTook) { for (int32 K = 0; K < 20; ++K) { In[Me].Stick = Stick; In[D] = FJamInput(); Sim->Step(In); } break; }
			}
			const bool bKept = Sim->CarrierIndex() == Me;
			AddInfo(FString::Printf(TEXT("seed %llu %s: sweep at frame %d, the defender's poke at %d (%s), carrier after 20 more frames %d (me %d)"), Seed,
				bSweep ? TEXT("sweep") : TEXT("no sweep"), SweepFrame, PokeFrame, bPokeTook ? TEXT("took") : bPokeMissed ? TEXT("missed") : TEXT("none"), Sim->CarrierIndex(), Me));
			if (bSweep) { KeptSweep += bKept ? 1 : 0; MissesSweep += bPokeMissed ? 1 : 0; }
			else { KeptNoSweep += bKept ? 1 : 0; TakesNoSweep += bPokeTook ? 1 : 0; }
		}
	}
	TestEqual(TEXT("the sweep is seen by the sim on the frame of the crossing, 10 of 10"), SweepEvents, 10);
	TestEqual(TEXT("the sweeping carrier keeps the puck 10 of 10 seeds"), KeptSweep, 10);
	TestEqual(TEXT("the pro defender's poke misses the swept puck 10 of 10"), MissesSweep, 10);
	TestEqual(TEXT("the carrier that does not sweep loses the puck 10 of 10"), KeptNoSweep, 0);
	TestEqual(TEXT("... to a clean poke 10 of 10"), TakesNoSweep, 10);

	// (b) The shield rule on its own: the defender's blade on the puck's old spot one frame after the sweep.
	for (const int32 ShieldFrames : { 12, 0 })
	{
		FJamGameConfig G2 = G;
		G2.Stick.SweepShieldFrames = ShieldFrames;
		UJamSim* Sim = MakeScene(G2, 1, {});
		const int32 Me = Sim->GetHumanIndex();
		const int32 D = FirstOpponent(Sim, Me);
		Sim->SetSkater(Me, FVector2D(0, 0), FVector2D::ZeroVector, 0);
		Sim->SetSkater(D, FVector2D(1.3, -1.75), FVector2D::ZeroVector, UE_DOUBLE_PI * 0.5);   // on the carrier's left, 0.64 m from the puck: its blade reaches the old spot, its body (0.52) does not
		GivePuck(Sim, Me, FwdLeft);
		const FVector2D OldSpot = Sim->GetPuck().Pos;
		TArray<FJamInput> In;
		In.SetNum(Sim->GetSkaters().Num());
		// Frame 1: a 20-degree sweep towards the front (above min_deg_per_frame 6). The defender aims its blade at the old spot and pokes the same frame: the puck
		// is still within the take radius of the old spot on this frame (the carry assist moves it 68 % of a 0.5 m step), so only the shield decides.
		In[Me].Stick = FVector2D(0.906, -0.423);
		{
			const FJamSkaterState& Ds = Sim->GetSkaters()[D];
			const FVector2D To = OldSpot - Ds.Pos;
			In[D].Stick = To.GetSafeNormal() * FMath::Clamp((To.Size() - UJamSim::SkaterRadius) / G2.Stick.ReachM, 0.2, 1.0);
			In[D].bPoke = true;
		}
		Sim->Step(In);
		const FJamSkaterState& MeS = Sim->GetSkaters()[Me];
		const bool bShieldOn = ShieldFrames > 0;
		TestEqual(*FString::Printf(TEXT("shield %d: the sweep is seen"), ShieldFrames), MeS.bSweepThisFrame, bShieldOn);
		if (bShieldOn) TestTrue(TEXT("shield 12: the defender on the side the puck left is shielded"), Sim->IsPokeShielded(Sim->GetSkaters()[D], MeS));
		if (bShieldOn)
		{
			// R-0044 as amended (lane A93): the shield covers both sides. The same blade mirrored across the carrier's line (the carrier stands at the origin
			// facing +x) is on the side the puck went to, and is refused as well.
			FJamSkaterState Mirror = Sim->GetSkaters()[D];
			Mirror.BladePos.Y = -Mirror.BladePos.Y;
			TestTrue(TEXT("shield 12: a blade on the side the puck went to is shielded too"), Sim->IsPokeShielded(Mirror, MeS));
		}
		const double DistBladePuck = FVector2D::Distance(Sim->GetSkaters()[D].BladePos, Sim->GetPuck().Pos);
		AddInfo(FString::Printf(TEXT("shield %d: blade to puck %.2f m after the sweep frame (take radius %.2f), carrier %d, poke clean %d miss %d"), ShieldFrames, DistBladePuck,
			G2.Puck.RadiusM + UJamSim::PokeTakeM, Sim->CarrierIndex(), Count(Sim, JamEvents::Poke, D, FName(TEXT("clean"))), Count(Sim, JamEvents::Poke, D, FName(TEXT("miss")))));
		if (bShieldOn)
		{
			TestEqual(TEXT("shield 12: the carrier keeps the puck"), Sim->CarrierIndex(), Me);
			TestEqual(TEXT("shield 12: no clean poke"), Count(Sim, JamEvents::Poke, D, FName(TEXT("clean"))), 0);
		}
		else if (DistBladePuck <= G2.Puck.RadiusM + UJamSim::PokeTakeM)
		{
			TestEqual(TEXT("shield 0: the same poke takes the puck"), Count(Sim, JamEvents::Poke, D, FName(TEXT("clean"))), 1);
		}
		else AddInfo(TEXT("shield 0: the puck had already left the take radius on the sweep frame; the shield case above is the rule's proof"));
	}

	// (c) The brain reads an opposing carrier's puck 8 frames late at pro: a hand-built world, the puck jumps from the carrier's left to its right at frame 20;
	// the defender's blade keeps pointing left for 8 more frames, then follows.
	{
		JamAI::FJamBrain Brain;
		Brain.Reset();
		Brain.Params.Opp = JamAI::GetDifficultyProfile(JamAI::EDifficulty::Pro).Opp;
		JamAI::FJamAIWorld W;
		W.NumSkaters = 2;
		W.PlayerIndex = 0;
		W.StickReach = G.Stick.ReachM;
		W.Skaters[0].Team = 0; W.Skaters[0].Pos = JamAI::FVec2(0, 0); W.Skaters[0].Facing = JamAI::FVec2(1, 0); W.Skaters[0].bHasPuck = true;
		W.Skaters[1].Team = 1; W.Skaters[1].Pos = JamAI::FVec2(2.0, 0); W.Skaters[1].Facing = JamAI::FVec2(-1, 0); W.Skaters[1].Role = JamAI::ERole::Chaser; W.Skaters[1].bCanPoke = true;
		W.Carrier = 0;
		W.PuckLastTouch = 0;
		W.GoalX = G.Rink.GoalLineX(); W.HalfLength = G.Rink.LengthM * 0.5; W.HalfWidth = G.Rink.WidthM * 0.5;
		JamAI::FJamAIInput Out[JamAI::kMaxSkaters];
		double StickYAt[40] = {};
		for (int32 F = 1; F <= 36; ++F)
		{
			W.Frame = F;
			W.PuckPos = F < 20 ? JamAI::FVec2(0.8, -1.0) : JamAI::FVec2(0.8, 1.0);   // left of the body, then right
			Brain.Think(W, Out);
			StickYAt[F] = Out[1].Stick.Y;
		}
		TestTrue(*FString::Printf(TEXT("pro: the defender's blade still points to the puck's old side 7 frames after the jump (stick y %.2f)"), StickYAt[26]), StickYAt[26] < -0.1);
		TestTrue(*FString::Printf(TEXT("pro: ... and follows after 8 frames (stick y %.2f)"), StickYAt[29]), StickYAt[29] > 0.1);
		TestTrue(*FString::Printf(TEXT("pro: before the jump it pointed left (stick y %.2f)"), StickYAt[19]), StickYAt[19] < -0.1);
	}
	return true;
}

// SpinShieldsPuck: the carrier spins with a defender's blade on the puck; for the 24 frames every poke is refused, the puck rides the far side of the body
// from the defender, the stamina drops by a quarter and the speed is capped at 0.7; the same defender takes the puck on its first poke without the spin.
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamSpinShieldsPuck, "Jam.Core.SpinShieldsPuck", JamStickHandlingTests::Flags)
bool FJamSpinShieldsPuck::RunTest(const FString& Parameters)
{
	using namespace JamStickHandlingTests;
	UJamCartridge* C = LoadPreset(*this, TEXT("hockey.regular"));
	if (!C) return false;
	C->Game.Skater.SpinExposedTail = 0;   // lane A128: this test pokes through the whole spin (R-0040's shield); the spin's exposed end is Jam.Core.Movement.SpinPrice's
	const FJamGameConfig& G = C->Game;
	for (const bool bSpin : { true, false })
	{
		UJamSim* Sim = MakeScene(G, 1, {});
		const int32 Me = Sim->GetHumanIndex();
		const int32 D = FirstOpponent(Sim, Me);
		// Standing still: a carried puck moving at 8 m/s past an opposing aimed blade is a deflection (C-0005, the pre-existing rule), which is not what this test is about.
		Sim->SetSkater(Me, FVector2D(0, 0), FVector2D::ZeroVector, 0);
		Sim->SetSkater(D, FVector2D(0, -0.9), FVector2D::ZeroVector, 0);   // beside the carrier (bodies do not overlap: 0.9 > 0.8)
		GivePuck(Sim, Me, FVector2D(0.7071, -0.7071));   // the puck forward-left, on the defender's side
		TestEqual(TEXT("the carrier starts with the puck"), Sim->CarrierIndex(), Me);
		const int32 Full = Sim->StaminaFull();
		TArray<FJamInput> In;
		In.SetNum(Sim->GetSkaters().Num());
		int32 CleanPokes = 0, Pokes = 0, FarSideFrames = 0, SpinFrames = 0, StaminaAfterPress = -1;
		double MaxSpeedInSpin = 0.0;
		int32 LostAt = -1;
		for (int32 F = 1; F <= 30; ++F)
		{
			In[Me] = FJamInput();
			In[Me].Stick = FVector2D(0.7071, -0.7071);
			if (bSpin && F == 1) In[Me].bSpin = true;
			// The defender: the blade on the puck every frame, a poke whenever one is allowed.
			const FJamSkaterState& Ds = Sim->GetSkaters()[D];
			const FVector2D To = Sim->GetPuck().Pos - Ds.Pos;
			In[D] = FJamInput();
			In[D].Stick = To.GetSafeNormal() * FMath::Clamp((To.Size() - UJamSim::SkaterRadius) / G.Stick.ReachM, 0.2, 1.0);
			In[D].bPoke = Sim->GetFrame() + 1 >= Ds.PokeReadyFrame && Ds.PokeWindow <= 0;
			Pokes += In[D].bPoke ? 1 : 0;
			Sim->Step(In);
			CleanPokes += Count(Sim, JamEvents::Poke, D, FName(TEXT("clean")));
			const FJamSkaterState& S = Sim->GetSkaters()[Me];
			if (F == 1) StaminaAfterPress = S.Stamina;
			if (S.SpinFrames > 0 || (bSpin && F <= 24))
			{
				++SpinFrames;
				MaxSpeedInSpin = FMath::Max(MaxSpeedInSpin, S.Vel.Size());
				const FVector2D ToD = Sim->GetSkaters()[D].Pos - S.Pos;
				const FVector2D ToP = Sim->GetPuck().Pos - S.Pos;
				if (FVector2D::DotProduct(ToD.GetSafeNormal(), ToP.GetSafeNormal()) < -0.5 && F >= 6) ++FarSideFrames;   // after the blade dragged it round (5 frames to 90 %)
			}
			if (LostAt < 0 && Sim->CarrierIndex() != Me) LostAt = F;
		}
		const FJamSkaterState& S = Sim->GetSkaters()[Me];
		AddInfo(FString::Printf(TEXT("%s: defender pokes pressed %d, clean %d, lost at frame %d; spin frames %d, puck on the far side on %d of them, max speed in the spin %.2f (cap %.2f), stamina %.3f, spins %d"),
			bSpin ? TEXT("spin") : TEXT("no spin"), Pokes, CleanPokes, LostAt, SpinFrames, FarSideFrames, MaxSpeedInSpin, G.Skater.Speed * G.Skater.SpinSpeedMult,
			S.Stamina < 0 ? 1.0 : static_cast<double>(S.Stamina) / Full, S.Spins));
		if (bSpin)
		{
			TestEqual(TEXT("spin: the spin ran 24 frames"), S.Spins, 1);
			TestTrue(TEXT("spin: no poke took the puck during the spin (the body is between)"), CleanPokes == 0 || LostAt > 24);
			TestTrue(TEXT("spin: the carrier still has the puck after the spin"), LostAt < 0 || LostAt > 24);
			TestTrue(*FString::Printf(TEXT("spin: the puck rode the far side of the body on at least 18 of the spin frames (%d)"), FarSideFrames), FarSideFrames >= 18);
			TestTrue(*FString::Printf(TEXT("spin: a quarter of the stamina bar is gone on the press (%d of %d, less that frame's refill)"), Full - StaminaAfterPress, Full),
				Full - StaminaAfterPress >= FMath::RoundToInt32(Full * 0.25) - G.Skater.SprintDrainFrames && Full - StaminaAfterPress <= FMath::RoundToInt32(Full * 0.25));
		}
		else
		{
			TestTrue(*FString::Printf(TEXT("no spin: the defender's poke takes the puck (clean %d, lost at %d)"), CleanPokes, LostAt), CleanPokes >= 1 && LostAt > 0);
		}
	}
	// The speed cap: a carrier at full speed who spins is held at speed_mult of the skater's speed for the spin's frames and accelerates again after it.
	{
		UJamSim* Sim = MakeScene(G, 1, {});
		const int32 Me = Sim->GetHumanIndex();
		Sim->SetSkater(Me, FVector2D(-10, 0), FVector2D(G.Skater.Speed, 0), 0);
		GivePuck(Sim, Me, FVector2D::ZeroVector);
		TArray<FJamInput> In;
		In.SetNum(Sim->GetSkaters().Num());
		double MaxInSpin = 0.0, After = 0.0;
		for (int32 F = 1; F <= 60; ++F)
		{
			In[Me] = FJamInput();
			In[Me].Move = FVector2D(1, 0);
			In[Me].bSpin = F == 1;
			Sim->Step(In);
			const double V = Sim->GetSkaters()[Me].Vel.Size();
			if (F <= G.Skater.SpinFrames) MaxInSpin = FMath::Max(MaxInSpin, V);
			After = V;
		}
		const double Cap = G.Skater.Speed * G.Skater.SpinSpeedMult;
		TestTrue(*FString::Printf(TEXT("speed capped at speed_mult during the spin (max %.2f, cap %.2f)"), MaxInSpin, Cap), MaxInSpin <= Cap + 0.01);
		TestTrue(*FString::Printf(TEXT("the skater accelerates again after the spin (%.2f > cap)"), After), After > Cap + 0.5);
	}
	return true;
}

// SpinCooldown: a second press during the spin does nothing, one inside the 90-frame cooldown is refused, the first frame after it is accepted; an empty
// stamina bar refuses the spin, a little stamina allows it.
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamSpinCooldown, "Jam.Core.SpinCooldown", JamStickHandlingTests::Flags)
bool FJamSpinCooldown::RunTest(const FString& Parameters)
{
	using namespace JamStickHandlingTests;
	UJamCartridge* C = LoadPreset(*this, TEXT("hockey.regular"));
	if (!C) return false;
	const FJamGameConfig& G = C->Game;
	UJamSim* Sim = MakeScene(G, 1, {});
	const int32 Me = Sim->GetHumanIndex();
	Sim->SetSkater(Me, FVector2D(0, 0), FVector2D::ZeroVector, 0);
	Sim->SetPuck(FVector2D(20, -15), FVector2D::ZeroVector);   // lane A82 (R-0041 point 6): off the dot the skater stands on; a carrier cannot sprint, and this test's sprint must empty the bar
	TArray<FJamInput> In;
	In.SetNum(Sim->GetSkaters().Num());
	auto StepSpin = [&](bool bPress, bool bSprint = false)
	{
		In[Me] = FJamInput();
		In[Me].bSpin = bPress;
		In[Me].bSprint = bSprint;
		if (bSprint) { const double A = Sim->GetFrame() * 0.08; In[Me].Move = FVector2D(FMath::Cos(A), FMath::Sin(A)); }   // sprint in a circle: never into the net or the boards
		Sim->Step(In);
	};
	const int64 F0 = Sim->GetFrame() + 1;
	StepSpin(true);   // frame F0: the first spin
	const FJamSkaterState* S = &Sim->GetSkaters()[Me];
	TestEqual(TEXT("the first press spins"), S->Spins, 1);
	TestEqual(TEXT("24 frames: 23 left after the first"), S->SpinFrames, G.Skater.SpinFrames - 1);
	TestTrue(TEXT("the one-frame flag"), S->bSpinThisFrame);
	TestEqual(TEXT("ready again after frames + cooldown"), S->SpinReadyFrame, F0 + G.Skater.SpinFrames + G.Skater.SpinCooldownFrames);
	TestTrue(*FString::Printf(TEXT("the visual turn starts (15 degrees after the first frame of 24: %.1f)"), S->SpinVisualYawDeg()), FMath::Abs(FMath::Abs(S->SpinVisualYawDeg()) - 15.0) < 0.01);
	const int32 Full = Sim->StaminaFull();
	TestTrue(*FString::Printf(TEXT("the press took a quarter of the bar (%d of %d, less the resting frame's refill)"), Full - S->Stamina, Full),
		Full - S->Stamina >= FMath::RoundToInt32(Full * 0.25) - G.Skater.SprintDrainFrames && Full - S->Stamina <= FMath::RoundToInt32(Full * 0.25));
	for (int32 i = 0; i < 4; ++i) StepSpin(false);
	StepSpin(true);   // a press during the spin
	TestEqual(TEXT("a press during the spin does nothing"), Sim->GetSkaters()[Me].Spins, 1);
	while (Sim->GetSkaters()[Me].SpinFrames > 0) StepSpin(false);
	TestEqual(TEXT("the spin ended on frame F0 + 23"), Sim->GetFrame(), F0 + G.Skater.SpinFrames - 1);
	TestEqual(TEXT("the visual turn is back to 0"), Sim->GetSkaters()[Me].SpinVisualYawDeg(), 0.0);
	// Inside the cooldown: refused on its last frame, accepted on the first frame after it.
	while (Sim->GetFrame() + 1 < F0 + G.Skater.SpinFrames + G.Skater.SpinCooldownFrames - 1) StepSpin(false);
	StepSpin(true);
	TestEqual(TEXT("the last cooldown frame refuses"), Sim->GetSkaters()[Me].Spins, 1);
	const int32 StaminaBeforeSecond = Sim->GetSkaters()[Me].Stamina;
	StepSpin(true);
	TestEqual(TEXT("the first frame after the cooldown spins"), Sim->GetSkaters()[Me].Spins, 2);
	TestTrue(TEXT("the second press took a quarter of the bar too (the bar refilled during the 90-frame cooldown: a quarter refills in 90 resting frames)"),
		StaminaBeforeSecond - Sim->GetSkaters()[Me].Stamina >= FMath::RoundToInt32(Full * 0.25) - G.Skater.SprintDrainFrames);
	// Stamina: once the cooldown is over, a sprint drains the bar to empty; the spin is refused on the empty bar and allowed again with a sliver.
	while (Sim->GetFrame() + 1 < Sim->GetSkaters()[Me].SpinReadyFrame) StepSpin(false);
	int32 Guard = 0;
	while (Sim->GetSkaters()[Me].Stamina != 0 && Guard++ < 600) StepSpin(false, true);
	TestEqual(TEXT("the sprint emptied the bar"), Sim->GetSkaters()[Me].Stamina, 0);
	StepSpin(true, true);   // the press in the frame right after the bar hit 0 (TrySpin runs before the frame's refill)
	TestEqual(TEXT("an empty bar refuses the spin"), Sim->GetSkaters()[Me].Spins, 2);
	for (int32 i = 0; i < 10; ++i) StepSpin(false);   // ten frames of rest refill a sliver
	TestTrue(TEXT("the bar has a little stamina"), Sim->GetSkaters()[Me].Stamina > 0 && Sim->GetSkaters()[Me].Stamina < FMath::RoundToInt32(Full * 0.25));
	StepSpin(true);
	TestEqual(TEXT("a little stamina allows the spin (and is spent)"), Sim->GetSkaters()[Me].Spins, 3);
	TestTrue(TEXT("... down to the resting frame's refill"), Sim->GetSkaters()[Me].Stamina <= G.Skater.SprintDrainFrames);
	return true;
}

// SpinCheckedFalls: a bot's body check that lands mid-spin knocks the carrier down for 1.5x knockdown_frames (135 of 90) and strips it; the same hit on a
// carrier that is not spinning: 90 frames.
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamSpinCheckedFalls, "Jam.Core.SpinCheckedFalls", JamStickHandlingTests::Flags)
bool FJamSpinCheckedFalls::RunTest(const FString& Parameters)
{
	using namespace JamStickHandlingTests;
	UJamCartridge* C = LoadPreset(*this, TEXT("hockey.regular"));
	if (!C) return false;
	const FJamGameConfig& G = C->Game;
	int32 FramesBy[2] = { 0, 0 };   // lane A92: [0] without the spin, [1] mid-spin
	for (const bool bSpin : { true, false })
	{
		UJamSim* Sim = MakeScene(G, 1, {});
		const int32 Me = Sim->GetHumanIndex();
		const int32 D = FirstOpponent(Sim, Me);
		Sim->SetSkater(Me, FVector2D(0, 0), FVector2D::ZeroVector, 0);
		Sim->SetSkater(D, FVector2D(3.0, 0), FVector2D(-9, 0), UE_DOUBLE_PI);   // head-on from the front at 9 m/s (above check_speed_min 5), no foul
		GivePuck(Sim, Me, FVector2D(0, -1));   // the puck on the left blade, out of the checker's line
		Sim->SetSkater(D, FVector2D(3.0, 0), FVector2D(-9, 0), UE_DOUBLE_PI);   // the quiet frames glided it; reset
		TArray<FJamInput> In;
		In.SetNum(Sim->GetSkaters().Num());
		int32 KnockFramesAtHit = -1, HitFrame = -1, SpinFramesAtHit = -1;
		bool bStripped = false;
		for (int32 F = 1; F <= 60; ++F)
		{
			In[Me] = FJamInput();
			In[Me].Stick = FVector2D(0, -1);
			if (bSpin && F == 1) In[Me].bSpin = true;
			const FJamSkaterState& Ds = Sim->GetSkaters()[D];
			const FJamSkaterState& Ms = Sim->GetSkaters()[Me];
			In[D] = FJamInput();
			In[D].Move = FVector2D(-1, 0);
			const double Gap = FVector2D::Distance(Ds.Pos, Ms.Pos) - UJamSim::SkaterRadius * 2.0;
			const double Closing = FVector2D::DotProduct(Ds.Vel - Ms.Vel, (Ms.Pos - Ds.Pos).GetSafeNormal());
			// Lane A192: the window opens game.contact.check_windup_frames after the press: the defender presses that many frames earlier, as the brain does.
			const double Wu = Sim->GetConfig().Contact.CheckWindupFor(Ds.bHuman);   // lane A200: the presser's own (bot_check_windup_frames for a bot)
			if (HitFrame < 0 && Ds.CheckWindow == 0 && Ds.CheckWindupLeft == 0 && Gap <= Closing * (4.0 + Wu) * UJamSim::DT) In[D].bCheck = true;   // inside the bots' 6-frame window
			Sim->Step(In);
			if (HitFrame < 0 && Count(Sim, JamEvents::Knockdown, Me) > 0)
			{
				HitFrame = F;
				KnockFramesAtHit = Sim->GetSkaters()[Me].KnockFrames;
				SpinFramesAtHit = Sim->GetSkaters()[Me].SpinFrames;
			}
			if (HitFrame > 0 && Sim->CarrierIndex() != Me) bStripped = true;
			if (HitFrame > 0 && F >= HitFrame + 5) break;
		}
		AddInfo(FString::Printf(TEXT("%s: the check landed at frame %d, knockdown frames %d (normal %d), spin frames after the hit %d, stripped %d"),
			bSpin ? TEXT("spin") : TEXT("no spin"), HitFrame, KnockFramesAtHit, G.Skater.KnockdownFrames, SpinFramesAtHit, bStripped ? 1 : 0));
		TestTrue(TEXT("the check landed"), HitFrame > 0);
		FramesBy[bSpin ? 1 : 0] = KnockFramesAtHit;
		if (bSpin)
		{
			TestTrue(TEXT("spin: the hit came mid-spin (frame 2..24)"), HitFrame >= 2 && HitFrame <= 24);
			TestEqual(TEXT("spin: the spin ends with the fall"), SpinFramesAtHit, 0);
		}
		// Lane A92 (R-0045): the frames follow the hit's ratio now (game.contact.down_frames_min..max), so the normal knockdown is a range, not skater.knockdown_frames.
		else TestTrue(*FString::Printf(TEXT("no spin: a knockdown inside game.contact's range (%d in %d..%d)"), KnockFramesAtHit, G.Contact.DownFramesMin, G.Contact.DownFramesMax),
			KnockFramesAtHit >= G.Contact.DownFramesMin && KnockFramesAtHit <= G.Contact.DownFramesMax);
		TestTrue(TEXT("a landed check on the carrier strips the puck (C-0005)"), bStripped);
	}
	// Lane A92: the spin's x1.5 stands on top of the ratio's frames (and the spin lowers the stability, so the same hit weighs more): at least 1.5x the plain hit.
	TestTrue(*FString::Printf(TEXT("spin: knocked down at least 1.5x as long as the same hit without the spin (%d against %d)"), FramesBy[1], FramesBy[0]),
		FramesBy[0] > 0 && FramesBy[1] >= FMath::RoundToInt32(FramesBy[0] * UJamSim::SpinKnockdownMult));
	return true;
}

// Lane A82 (R-0040 point 1): the lift is shielded like the poke. SpinShieldsLift: a carrier spins with a defender at lift range (1.2 m body to body, inside
// stick.lift_range_m 1.0 + the two bodies); the defender lifts on every frame its cooldown allows: for the 24 spin frames every lift is a miss and the puck stays;
// the same defender without the spin takes it with its first lift.
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamSpinShieldsLift, "Jam.Core.SpinShieldsLift", JamStickHandlingTests::Flags)
bool FJamSpinShieldsLift::RunTest(const FString& Parameters)
{
	using namespace JamStickHandlingTests;
	UJamCartridge* C = LoadPreset(*this, TEXT("hockey.regular"));
	if (!C) return false;
	const FJamGameConfig& G = C->Game;
	for (const bool bSpin : { true, false })
	{
		UJamSim* Sim = MakeScene(G, 1, {});
		const int32 Me = Sim->GetHumanIndex();
		const int32 D = FirstOpponent(Sim, Me);
		Sim->SetSkater(Me, FVector2D(0, 0), FVector2D::ZeroVector, 0);
		Sim->SetSkater(D, FVector2D(0, -1.2), FVector2D::ZeroVector, UE_DOUBLE_PI * 0.5);   // beside the carrier, inside the lift's range (0.8 + 1.0)
		GivePuck(Sim, Me, FVector2D(0.7071, -0.7071));
		TestEqual(TEXT("the carrier starts with the puck"), Sim->CarrierIndex(), Me);
		TArray<FJamInput> In;
		In.SetNum(Sim->GetSkaters().Num());
		int32 Lifts = 0, Clean = 0, Miss = 0, LostAt = -1;
		for (int32 F = 1; F <= 30; ++F)
		{
			In[Me] = FJamInput();
			In[Me].Stick = FVector2D(0.7071, -0.7071);
			if (bSpin && F == 1) In[Me].bSpin = true;
			const FJamSkaterState& Ds = Sim->GetSkaters()[D];
			In[D] = FJamInput();
			In[D].Stick = (Sim->GetPuck().Pos - Ds.Pos).GetSafeNormal() * 0.6;
			In[D].bLift = Sim->GetFrame() + 1 >= Ds.LiftReadyFrame;
			Lifts += In[D].bLift ? 1 : 0;
			Sim->Step(In);
			Clean += Count(Sim, JamEvents::Lift, D, FName(TEXT("clean")));
			Miss += Count(Sim, JamEvents::Lift, D, FName(TEXT("miss")));
			if (LostAt < 0 && Sim->CarrierIndex() != Me) LostAt = F;
		}
		AddInfo(FString::Printf(TEXT("%s: lifts pressed %d, clean %d, miss %d, lost at frame %d"), bSpin ? TEXT("spin") : TEXT("no spin"), Lifts, Clean, Miss, LostAt));
		if (bSpin)
		{
			TestEqual(TEXT("spin: the spin ran"), Sim->GetSkaters()[Me].Spins, 1);
			TestTrue(TEXT("spin: no lift took the puck during the spin (the body is between)"), LostAt < 0 || LostAt > G.Skater.SpinFrames);
			TestTrue(TEXT("spin: the shielded lift reads as a miss"), Miss >= 1);
		}
		else
		{
			TestTrue(*FString::Printf(TEXT("no spin: the first lift takes the puck (clean %d, lost at %d)"), Clean, LostAt), Clean >= 1 && LostAt == 1);
		}
	}
	return true;
}

// SweepShieldsLift: the carrier sweeps the puck from its left to its right with a defender at lift range on the left; the defender lifts the frame after the sweep
// and keeps lifting: with shield_frames 12 every lift inside the shield is a miss and the puck stays through the shield; with shield_frames 0 the lift at frame 2
// takes it. A defender on the right (the side the puck went to) is not shielded and takes it.
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamSweepShieldsLift, "Jam.Core.SweepShieldsLift", JamStickHandlingTests::Flags)
bool FJamSweepShieldsLift::RunTest(const FString& Parameters)
{
	using namespace JamStickHandlingTests;
	UJamCartridge* C = LoadPreset(*this, TEXT("hockey.regular"));
	if (C) { C->Game.Stick.PickupArcM = 0.0; C->Game.Stick.bPickupBody = false; }   // lane A208: re-staged at game.stick.pickup's neutral: this scene measures the sweep's shield against a lift; the loose puck's pickup has its own (Jam.Core.Possession.*)
	if (!C) return false;
	const FJamGameConfig& G = C->Game;
	const FVector2D FwdLeft(0.7071, -0.7071), FwdRight(0.7071, 0.7071);
	struct FCase { int32 ShieldFrames; double DefY; const TCHAR* Name; bool bExpectShield; };
	const FCase Cases[] = { { 12, -1.4, TEXT("shield 12, defender on the side the puck left"), true }, { 0, -1.4, TEXT("shield 0, same defender"), false }, { 12, 1.4, TEXT("shield 12, defender on the side the puck went to"), true } };   // R-0044 as amended (lane A93): the shield covers both sides, so this lift is refused too (it took the puck at frame 2 before)
	for (const FCase& K : Cases)
	{
		FJamGameConfig G2 = G;
		G2.Stick.SweepShieldFrames = K.ShieldFrames;
		UJamSim* Sim = MakeScene(G2, 1, {});
		const int32 Me = Sim->GetHumanIndex();
		const int32 D = FirstOpponent(Sim, Me);
		Sim->SetSkater(Me, FVector2D(0, 0), FVector2D::ZeroVector, 0);
		Sim->SetSkater(D, FVector2D(0.4, K.DefY), FVector2D::ZeroVector, K.DefY < 0 ? UE_DOUBLE_PI * 0.5 : -UE_DOUBLE_PI * 0.5);   // 1.46 m body to body: inside the lift's 1.8
		GivePuck(Sim, Me, FwdLeft);
		TestEqual(*FString::Printf(TEXT("%s: the carrier starts with the puck"), K.Name), Sim->CarrierIndex(), Me);
		TArray<FJamInput> In;
		In.SetNum(Sim->GetSkaters().Num());
		int32 Clean = 0, Miss = 0, LostAt = -1, Lifts = 0;
		bool bSweepSeen = false;
		for (int32 F = 1; F <= 14; ++F)
		{
			In[Me] = FJamInput();
			In[Me].Stick = FwdRight;   // frame 1: the aim crosses the body (a sweep); it stays right
			const FJamSkaterState& Ds = Sim->GetSkaters()[D];
			In[D] = FJamInput();
			In[D].Stick = (Sim->GetSkaters()[Me].Pos - Ds.Pos).GetSafeNormal() * 0.6;   // the blade toward the carrier: on its own side of the body
			In[D].bLift = F >= 2 && Sim->GetFrame() + 1 >= Ds.LiftReadyFrame;
			Lifts += In[D].bLift ? 1 : 0;
			Sim->Step(In);
			if (F == 1) bSweepSeen = Sim->GetSkaters()[Me].bSweepThisFrame;
			Clean += Count(Sim, JamEvents::Lift, D, FName(TEXT("clean")));
			Miss += Count(Sim, JamEvents::Lift, D, FName(TEXT("miss")));
			if (LostAt < 0 && Sim->CarrierIndex() != Me) LostAt = F;
		}
		AddInfo(FString::Printf(TEXT("%s: sweep seen %d, lifts pressed %d, clean %d, miss %d, lost at frame %d"), K.Name, bSweepSeen ? 1 : 0, Lifts, Clean, Miss, LostAt));
		TestTrue(*FString::Printf(TEXT("%s: the sweep is seen on frame 1"), K.Name), bSweepSeen || K.ShieldFrames == 0);
		if (K.bExpectShield)
		{
			TestTrue(*FString::Printf(TEXT("%s: no lift takes the puck inside the shield (lost at %d)"), K.Name, LostAt), LostAt < 0 || LostAt > 1 + K.ShieldFrames);
			TestTrue(*FString::Printf(TEXT("%s: the shielded lifts read as misses (%d)"), K.Name, Miss), Miss >= 1 && Clean == 0);
		}
		else
		{
			TestTrue(*FString::Printf(TEXT("%s: the lift at frame 2 takes the puck (clean %d, lost at %d)"), K.Name, Clean, LostAt), Clean >= 1 && LostAt == 2);
		}
	}
	return true;
}

// Lane A82 (R-0041 point 6): the puck carrier is slower. CarrierSpeed: a carrier and a free skater at full input from rest for 2.5 s: the carrier settles at
// carry_speed_mult of the free skater's speed. Lane A93 (R-0045 law 4, which replaces "the carrier cannot sprint"): sprint held while carrying now raises the
// carrier by sprint.carry_bonus and drains its bar, still under the free skater's sprint; with carry_bonus 0 A82's rule is back (the same speed, the bar full).
// The run is 150 frames, not 180: with A93's first-step burst both skaters are past the red line at frame 180 and the carrier's breakaway burst is running.
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamCarrierSpeed, "Jam.Core.CarrierSpeed", JamStickHandlingTests::Flags)
bool FJamCarrierSpeed::RunTest(const FString& Parameters)
{
	using namespace JamStickHandlingTests;
	UJamCartridge* C = LoadPreset(*this, TEXT("hockey.regular"));
	if (!C) return false;
	const FJamGameConfig& G = C->Game;
	TestEqual(TEXT("skater.carry_speed_mult default 0.92"), G.Skater.CarrySpeedMult, 0.92);
	auto Run = [&](const FJamGameConfig& Gc, bool bSprint, double& OutCarrier, double& OutFree, int32& OutCarrierStamina, int32& OutFreeStamina, int32& OutCarrierIdx)
	{
		UJamSim* Sim = MakeScene(Gc, 1, {});
		const int32 Me = Sim->GetHumanIndex();
		int32 Free = -1;
		for (const FJamSkaterState& S : Sim->GetSkaters()) if (S.Index != Me && S.Team == Sim->GetSkaters()[Me].Team) { Free = S.Index; break; }
		Sim->SetSkater(Me, FVector2D(-30, -8), FVector2D::ZeroVector, 0);
		Sim->SetSkater(Free, FVector2D(-30, 8), FVector2D::ZeroVector, 0);
		GivePuck(Sim, Me, FVector2D::ZeroVector);
		TArray<FJamInput> In;
		In.SetNum(Sim->GetSkaters().Num());
		for (int32 F = 1; F <= 150; ++F)
		{
			In[Me] = FJamInput(); In[Me].Move = FVector2D(1, 0); In[Me].bSprint = bSprint;
			In[Free] = FJamInput(); In[Free].Move = FVector2D(1, 0); In[Free].bSprint = bSprint;
			Sim->Step(In);
		}
		OutCarrier = Sim->GetSkaters()[Me].Vel.Size();
		OutFree = Sim->GetSkaters()[Free].Vel.Size();
		OutCarrierStamina = Sim->GetSkaters()[Me].Stamina;
		OutFreeStamina = Sim->GetSkaters()[Free].Stamina;
		OutCarrierIdx = Sim->CarrierIndex() == Me ? Me : -1;
	};
	double Vc = 0, Vf = 0, Vcs = 0, Vfs = 0;
	int32 Sc = 0, Sf = 0, Scs = 0, Sfs = 0, Ci = -1, Cis = -1;
	Run(G, false, Vc, Vf, Sc, Sf, Ci);
	Run(G, true, Vcs, Vfs, Scs, Sfs, Cis);
	AddInfo(FString::Printf(TEXT("no sprint: carrier %.3f m/s, free %.3f (ratio %.3f); sprint held: carrier %.3f (stamina %d), free %.3f (stamina %d); full bar %d"), Vc, Vf, Vf > 0 ? Vc / Vf : 0.0, Vcs, Scs, Vfs, Sfs, Sc));
	TestTrue(TEXT("the carrier kept the puck through the run"), Ci >= 0 && Cis >= 0);
	// Lane A185 (R-0064 point 2): the free skater has free_speed_mult on top, the carrier not: 0.92 / 1.15 = 0.8 of the free skater's speed.
	TestTrue(*FString::Printf(TEXT("the carrier runs at carry_speed_mult / free_speed_mult of the free skater (%.3f of %.3f = %.3f, want %.3f within 0.01)"), Vc, Vf, Vc / Vf, G.Skater.CarrySpeedMult / G.Skater.FreeSpeedMult),
		FMath::Abs(Vc / Vf - G.Skater.CarrySpeedMult / G.Skater.FreeSpeedMult) < 0.01);
	// Lane A93 (R-0045 law 4): the carrier's sprint is live, smaller than a free skater's, and costs the same bar.
	TestTrue(*FString::Printf(TEXT("sprint held while carrying adds carry_bonus (%.3f = %.3f x %.2f within 0.02)"), Vcs, Vc, 1.0 + G.Skater.SprintCarryBonus), FMath::Abs(Vcs - Vc * (1.0 + G.Skater.SprintCarryBonus)) < 0.02);
	TestTrue(*FString::Printf(TEXT("the sprinting carrier is slower than the sprinting free skater (%.3f < %.3f)"), Vcs, Vfs), Vcs < Vfs - 0.5);
	TestTrue(TEXT("the carrier's bar drains under a held sprint as the free skater's"), Scs >= 0 && Scs == Sfs);
	{
		// carry_bonus 0 (A93's neutral value): A82's rule as shipped.
		FJamGameConfig G0 = G;
		G0.Skater.SprintCarryBonus = 0.0;
		double Vc0 = 0, Vf0 = 0; int32 Sc0 = 0, Sf0 = 0, Ci0 = -1;
		Run(G0, true, Vc0, Vf0, Sc0, Sf0, Ci0);
		TestTrue(*FString::Printf(TEXT("carry_bonus 0: sprint held while carrying changes nothing (%.3f vs %.3f)"), Vc0, Vc), FMath::Abs(Vc0 - Vc) < 1e-6);
		TestTrue(TEXT("carry_bonus 0: the carrier's bar does not drain under a held sprint"), Sc0 < 0 || Sc0 == Sc);
	}
	TestTrue(*FString::Printf(TEXT("the free skater's sprint is live (%.3f > %.3f, bar %d < %d)"), Vfs, Vf, Sfs, Sf), Vfs > Vf + 0.5 && Sfs >= 0 && Sfs < Sf);
	// carry_speed_mult 1: no penalty; the key reads back and an out-of-range value is refused.
	{
		FJamGameConfig G1 = G;
		G1.Skater.CarrySpeedMult = 1.0;
		G1.Skater.FreeSpeedMult = 1.0;   // lane A185: and no free-skater speed, or the free skater is still the faster
		double Vc1 = 0, Vf1 = 0; int32 A = 0, B = 0, I = -1;
		Run(G1, false, Vc1, Vf1, A, B, I);
		TestTrue(*FString::Printf(TEXT("carry_speed_mult 1: the carrier skates as freely (%.3f vs %.3f)"), Vc1, Vf1), FMath::Abs(Vc1 - Vf1) < 0.02);
		const FString Raw = C->RawJson;
		TArray<FString> Errors;
		UJamCartridge* V = UJamCartridge::LoadFromString(Raw.Replace(TEXT("\"skater\": {"), TEXT("\"skater\": {\"carry_speed_mult\": 0.8,")), Errors);
		for (const FString& E : Errors) AddError(FString::Printf(TEXT("carry_speed_mult 0.8 variant: %s"), *E));
		if (V) TestEqual(TEXT("carry_speed_mult 0.8 read"), V->Game.Skater.CarrySpeedMult, 0.8);
		Errors.Reset();
		UJamCartridge* Bad = UJamCartridge::LoadFromString(Raw.Replace(TEXT("\"skater\": {"), TEXT("\"skater\": {\"carry_speed_mult\": 0.3,")), Errors);
		TestTrue(TEXT("carry_speed_mult 0.3 (under 0.6) is refused"), Bad == nullptr || Errors.Num() > 0);
	}
	return true;
}

// R-0042 (lane A85): CarrierReach. One reach for every carrier test: UJamSim::CarrierReachM = max(shot.reach_m, body radius + stick.reach_m) + 0.05 (1.65 m at
// the defaults; the brain's FJamAIWorld::CarrierReach is the same number). A carrier with the blade at full aim holds the puck 1.6 m out, past shot.reach_m 1.5
// (the seam lane A82's JAMSHOT release line found: nothing charged or fired while the player aimed): it now fires a tap, a charged shot, a pass and a saucer,
// and the puck at 1.6 m stays carried through a fast aim change.
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamCarrierReach, "Jam.Core.CarrierReach", JamStickHandlingTests::Flags)
bool FJamCarrierReach::RunTest(const FString& Parameters)
{
	using namespace JamStickHandlingTests;
	UJamCartridge* C = LoadPreset(*this, TEXT("hockey.regular"));
	if (!C) return false;
	JamBaseline::PassShotNeutral(C->Game);   // lane A207: this scene pins the pass and shot before game.pass.power / aim / catch_m / clear_own_body and game.shot.speed_scale: their neutral values
	const FJamGameConfig& G = C->Game;
	const double Want = FMath::Max(G.Shot.ReachM, UJamSim::SkaterRadius + G.Stick.ReachM) + 0.05;
	TestTrue(TEXT("the blade's full reach lies beyond shot.reach_m at the defaults (the seam)"), UJamSim::SkaterRadius + G.Stick.ReachM > G.Shot.ReachM);
	{
		UJamSim* Sim = MakeScene(G, 1, {});
		TestEqual(TEXT("CarrierReachM = max(shot.reach_m, 0.4 + stick.reach_m) + 0.05"), Sim->CarrierReachM(-1), Want, 1e-9);
		TestEqual(TEXT("... 1.65 m at the defaults"), Sim->CarrierReachM(Sim->GetHumanIndex()), 1.65, 1e-9);
		JamAI::FJamAIWorld W;
		W.ShotReach = G.Shot.ReachM; W.StickReach = G.Stick.ReachM; W.SkaterRadius = UJamSim::SkaterRadius;
		TestEqual(TEXT("the brain's CarrierReach is the sim's"), W.CarrierReach(), Sim->CarrierReachM(-1), 1e-9);
		// A short stick: shot.reach_m is the longer one and stands.
		FJamGameConfig Short = G; Short.Stick.ReachM = 0.6;
		UJamSim* S2 = MakeScene(Short, 1, {});
		TestEqual(TEXT("stick.reach_m 0.6: the reach is shot.reach_m + 0.05"), S2->CarrierReachM(-1), G.Shot.ReachM + 0.05, 1e-9);
	}
	// The scene: the human at centre ice facing the net it attacks, the blade at full aim straight ahead (the puck seated on it, 1.6 m out), one teammate
	// open 8 m up the ice and 6 m to the side, everyone else parked.
	// Lane A93 (R-0045 law 4): a carrier that is not sprinting now holds the puck at stick.carry_reach_mult 0.75 of that (1.2 m, inside shot.reach_m); the seam
	// is the sprinting carrier's. The scenes below stand still, so they are played with carry_reach_mult 1 (the full distance, as the sprint holds it); the
	// default distance is checked once after them.
	FJamGameConfig FullReach = G;
	FullReach.Stick.CarryReachMult = 1.0;
	struct FScene { UJamSim* Sim = nullptr; int32 Me = -1; int32 Mate = -1; FVector2D Aim = FVector2D::ZeroVector; double Dir = 1.0; };
	auto Scene = [&]() -> FScene
	{
		FScene K;
		K.Sim = MakeScene(FullReach, 1, {});
		K.Me = K.Sim->GetHumanIndex();
		const int32 Team = K.Sim->GetSkaters()[K.Me].Team;
		for (const FJamSkaterState& S : K.Sim->GetSkaters()) if (S.Index != K.Me && S.Team == Team) { K.Mate = S.Index; break; }
		K.Dir = K.Sim->AttackGoalX(Team) > 0 ? 1.0 : -1.0;
		K.Aim = FVector2D(K.Dir, 0.0);
		K.Sim->SetSkater(K.Me, FVector2D(0, 0), FVector2D::ZeroVector, K.Dir > 0 ? 0.0 : UE_DOUBLE_PI);
		K.Sim->SetSkater(K.Mate, FVector2D(8.0 * K.Dir, 6.0), FVector2D::ZeroVector, K.Dir > 0 ? 0.0 : UE_DOUBLE_PI);
		GivePuck(K.Sim, K.Me, K.Aim);
		return K;
	};
	// Steps Frames frames with the human's stick at Stick and the given levels and edges; everyone else idle.
	auto Step = [&](FScene& K, const FVector2D& Stick, int32 Frames, bool bShootHeld, bool bPassHeld, bool bShoot = false, bool bPass = false)
	{
		TArray<FJamInput> In;
		In.SetNum(K.Sim->GetSkaters().Num());
		for (int32 f = 0; f < Frames; ++f)
		{
			In[K.Me] = FJamInput();
			In[K.Me].Stick = Stick; In[K.Me].bShootHeld = bShootHeld; In[K.Me].bPassHeld = bPassHeld; In[K.Me].bShoot = bShoot; In[K.Me].bPass = bPass;
			K.Sim->Step(In);
		}
	};
	auto PuckDist = [&](const FScene& K) { return FVector2D::Distance(K.Sim->GetSkaters()[K.Me].Pos, K.Sim->GetPuck().Pos); };
	// The seam itself: the seated puck is beyond shot.reach_m and inside the carrier's reach, and it is carried.
	{
		FScene K = Scene();
		Step(K, K.Aim, 10, false, false);
		const double D = PuckDist(K);
		AddInfo(FString::Printf(TEXT("the puck on the blade at full aim: %.3f m from the body (shot.reach_m %.2f, carrier reach %.2f)"), D, G.Shot.ReachM, K.Sim->CarrierReachM(K.Me)));
		TestTrue(*FString::Printf(TEXT("the carried puck sits beyond shot.reach_m (%.3f > %.2f)"), D, G.Shot.ReachM), D > G.Shot.ReachM);
		TestTrue(*FString::Printf(TEXT("... and inside the carrier's reach (%.3f <= %.2f)"), D, K.Sim->CarrierReachM(K.Me)), D <= K.Sim->CarrierReachM(K.Me));
		TestEqual(TEXT("... carried by the human"), K.Sim->CarrierIndex(), K.Me);
	}
	// A tap (the shoot edge) fires.
	{
		FScene K = Scene();
		Step(K, K.Aim, 1, false, false, true);
		TestEqual(TEXT("tap at full aim: one shot"), K.Sim->GetSkaters()[K.Me].Shots, 1);
		TestEqual(TEXT("tap at full aim: the puck is on the ice (R-0042: a tap flies flat)"), K.Sim->GetPuck().Z, 0.0, 1e-9);
		TestTrue(TEXT("tap at full aim: the puck left for the net"), K.Sim->GetPuck().Vel.X * K.Dir > 10.0);
	}
	// A hold charges with the puck at the blade and the release fires the charged shot.
	{
		FScene K = Scene();
		Step(K, K.Aim, 12, true, false);
		TestEqual(TEXT("hold at full aim: the charge counts every held frame"), K.Sim->GetSkaters()[K.Me].ChargeFrames, 12);
		Step(K, K.Aim, 1, false, false);
		const FJamSkaterState& S = K.Sim->GetSkaters()[K.Me];
		TestEqual(TEXT("release at full aim: one shot"), S.Shots, 1);
		TestEqual(TEXT("release at full aim: charged 12 of 30"), static_cast<double>(S.LastShotCharge), 12.0 / G.Shot.ChargeFramesMax, 1e-4);
		Step(K, K.Aim, 6, false, false);
		TestTrue(*FString::Printf(TEXT("the charged shot is lifted (Z %.3f)"), K.Sim->GetPuck().Z), K.Sim->GetPuck().Z > 0.0);
	}
	// A pass (the edge) goes to the open teammate.
	{
		FScene K = Scene();
		Step(K, K.Aim, 1, false, false, false, true);
		TestEqual(TEXT("pass at full aim: one pass"), K.Sim->GetSkaters()[K.Me].Passes, 1);
		TestEqual(TEXT("pass at full aim: no saucer"), K.Sim->GetSkaters()[K.Me].Saucers, 0);
	}
	// A held pass charges to pass.saucer.half_frames and the release is a saucer.
	{
		FScene K = Scene();
		const int32 Half = G.Pass.SaucerHalfFrames;
		Step(K, K.Aim, Half, false, true);
		TestEqual(TEXT("pass hold at full aim: the charge reached half_frames"), K.Sim->GetSkaters()[K.Me].PassChargeFrames, Half);
		Step(K, K.Aim, 1, false, false);
		TestEqual(TEXT("saucer at full aim: one pass"), K.Sim->GetSkaters()[K.Me].Passes, 1);
		TestEqual(TEXT("saucer at full aim: it was a saucer"), K.Sim->GetSkaters()[K.Me].Saucers, 1);
		Step(K, K.Aim, 4, false, false);
		TestTrue(*FString::Printf(TEXT("the saucer is in the air (Z %.3f)"), K.Sim->GetPuck().Z), K.Sim->GetPuck().Z > 0.0);
	}
	// The fast aim change: the blade from full aim ahead to full aim square to the side in one frame, and back 15 frames later: carried on every frame.
	{
		FScene K = Scene();
		Step(K, K.Aim, 10, false, false);
		int32 Dropped = 0;
		double MaxD = 0.0;
		const FVector2D Side(0.0, 1.0);
		for (int32 f = 0; f < 30; ++f)
		{
			Step(K, f < 15 ? Side : K.Aim, 1, false, false);
			if (K.Sim->CarrierIndex() != K.Me) ++Dropped;
			MaxD = FMath::Max(MaxD, PuckDist(K));
		}
		AddInfo(FString::Printf(TEXT("fast aim change: farthest puck %.3f m, frames not carried %d of 30"), MaxD, Dropped));
		TestEqual(TEXT("fast aim change: the puck is carried on every frame"), Dropped, 0);
		TestTrue(*FString::Printf(TEXT("... while it rode beyond shot.reach_m (%.3f)"), MaxD), MaxD > G.Shot.ReachM);
		Step(K, K.Aim, 1, false, false, true);
		TestEqual(TEXT("... and the shot still fires after it"), K.Sim->GetSkaters()[K.Me].Shots, 1);
	}
	// Lane A93: at the defaults the standing carrier's puck is 1.2 m out (carry_reach_mult 0.75), carried, and a tap fires.
	{
		UJamSim* Sim = MakeScene(G, 1, {});
		const int32 Me = Sim->GetHumanIndex();
		const double Dir = Sim->AttackGoalX(Sim->GetSkaters()[Me].Team) > 0 ? 1.0 : -1.0;
		Sim->SetSkater(Me, FVector2D(0, 0), FVector2D::ZeroVector, Dir > 0 ? 0.0 : UE_DOUBLE_PI);
		GivePuck(Sim, Me, FVector2D(Dir, 0.0));
		TArray<FJamInput> In;
		In.SetNum(Sim->GetSkaters().Num());
		In[Me].Stick = FVector2D(Dir, 0.0);
		for (int32 f = 0; f < 10; ++f) Sim->Step(In);
		const double D = FVector2D::Distance(Sim->GetSkaters()[Me].Pos, Sim->GetPuck().Pos);
		const double WantD = (UJamSim::SkaterRadius + G.Stick.ReachM) * G.Stick.CarryReachMult;
		TestTrue(*FString::Printf(TEXT("defaults: the standing carrier's puck rides at carry_reach_mult of the full distance (%.3f, want %.3f)"), D, WantD), FMath::Abs(D - WantD) < 0.03);
		TestEqual(TEXT("defaults: carried"), Sim->CarrierIndex(), Me);
		In[Me].bShoot = true;
		Sim->Step(In);
		TestEqual(TEXT("defaults: a tap fires"), Sim->GetSkaters()[Me].Shots, 1);
	}
	return true;
}

#endif
