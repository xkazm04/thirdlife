// Lane A52 (R-0035): the puck gets a height. Jam.Core.LiftedShot, Jam.Core.SaveByHeight, Jam.Core.PostRings. Headless, no world. Run:
//   UnrealEditor-Cmd.exe Game/ThirdJam.uproject -ExecCmds="Automation RunTests Jam.Core.LiftedShot+Jam.Core.SaveByHeight+Jam.Core.PostRings; Quit" -unattended -nullrhi -nosplash -log
#include "Misc/AutomationTest.h"
#include "JamCartridge.h"
#include "JamSim.h"
#include "JamEventBus.h"

#if WITH_DEV_AUTOMATION_TESTS

namespace JamLiftedPuckTests
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

	// Everyone parked in a far corner of the -x half, out of every crease; the scene then places who it needs.
	void Park(UJamSim* Sim)
	{
		for (const FJamSkaterState& S : Sim->GetSkaters()) Sim->SetSkater(S.Index, FVector2D(-20.0, 10.0 + 2.5 * S.Index), FVector2D::ZeroVector, 0.0);
	}

	// Skater Shooter stands DistM in front of the goal line it attacks, facing it, the puck 0.8 m ahead on its blade.
	void Line(UJamSim* Sim, int32 Shooter, double DistM)
	{
		const int32 Team = Sim->GetSkaters()[Shooter].Team;
		const double Gx = Sim->AttackGoalX(Team);
		const double Dir = Gx > 0 ? 1.0 : -1.0;
		Sim->SetSkater(Shooter, FVector2D(Gx - Dir * DistM, 0.0), FVector2D::ZeroVector, Dir > 0 ? 0.0 : UE_DOUBLE_PI);
		Sim->SetPuck(FVector2D(Gx - Dir * (DistM - 0.8), 0.0), FVector2D::ZeroVector);
	}

	// The shot: HoldFrames 0 = a tap (bShoot edge); else shoot held for HoldFrames frames and released (the sim fires the charged shot on the release).
	void Shoot(UJamSim* Sim, int32 Shooter, int32 HoldFrames)
	{
		TArray<FJamInput> In; In.Init(FJamInput(), Sim->GetSkaters().Num());
		if (HoldFrames <= 0) { In[Shooter].bShoot = true; Sim->Step(In); return; }
		for (int32 f = 0; f < HoldFrames; ++f) { In[Shooter].bShootHeld = true; Sim->Step(In); }
		In[Shooter].bShootHeld = false;
		Sim->Step(In);
	}

	struct FFlight
	{
		bool bCrossed = false;   // the puck centre crossed the attacked goal line
		double ZAtLine = -1.0;   // its height there (interpolated inside the crossing frame)
		double ZMax = 0.0;
		bool bFlewOver = false;  // the puck got past the back of the net
		int32 Goals = 0;
		int32 Saves = 0;
		int32 Posts = 0;
		int32 Saver = -1;
	};

	// Runs the loose puck for up to Frames frames (nobody moves) and reads its flight to the goal line at Gx (Dir = +1 for the +x net).
	FFlight Fly(UJamSim* Sim, double Gx, int32 Frames = 240)
	{
		FFlight F;
		const double Dir = Gx > 0 ? 1.0 : -1.0;
		TArray<FJamInput> In; In.Init(FJamInput(), Sim->GetSkaters().Num());
		const int32 Score0 = Sim->GetScore(0) + Sim->GetScore(1);
		for (int32 f = 0; f < Frames; ++f)
		{
			if (Sim->GetPhase() != EJamSimPhase::Playing) break;
			Sim->Step(In);
			const FJamPuckState& P = Sim->GetPuck();
			F.ZMax = FMath::Max(F.ZMax, P.Z);
			if (!F.bCrossed && P.PrevPos.X * Dir < Gx && P.Pos.X * Dir >= Gx)
			{
				F.bCrossed = true;
				const double Span = (P.Pos.X - P.PrevPos.X) * Dir;
				const double A = Span > 1e-9 ? (Gx - P.PrevPos.X * Dir) / Span : 1.0;
				F.ZAtLine = P.PrevZ + (P.Z - P.PrevZ) * A;
			}
			if (P.Pos.X * Dir > Gx + UJamSim::NetDepth) F.bFlewOver = true;
			for (const FJamSimEvent& E : Sim->GetFrameEvents())
			{
				if (E.Name == JamEvents::Save) { ++F.Saves; F.Saver = E.Who; }
				if (E.Name == JamEvents::Post) ++F.Posts;
			}
		}
		F.Goals = Sim->GetScore(0) + Sim->GetScore(1) - Score0;
		return F;
	}
}

using namespace JamLiftedPuckTests;

// The lifted shot: the release height follows the charge (game.shot.lift): a tap stays on the ice the whole way (tap_m 0 since R-0042, lane A85: at A52's 0.05
// the solve lobbed a tap from 10 m 0.5 m high and no blade could touch it), a hold of half_frames (8) arrives half_m (0.45) over the goal line, the full charge
// full_m (0.47 since R-0044, lane A91: the top shelf clearly under the 0.61 bar, whose ring starts at 0.51; 0.6 rang it from 4 to 24 m, the ruling's 0.5 from
// 15 to 24 m: the table below); a hold of shot.tap_frames (4) or fewer
// is a tap (R-0044); the carried puck sits on the ice; a cartridge with full_m 0.95 clears the 0.61 bar and goes in at 1.22.
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamLiftedShot, "Jam.Core.LiftedShot", JamLiftedPuckTests::Flags)
bool FJamLiftedShot::RunTest(const FString&)
{
	UJamCartridge* C = LoadPreset(*this, TEXT("hockey.regular"));
	if (C) { C->Game.Stick.PickupArcM = 0.0; C->Game.Stick.bPickupBody = false; }   // lane A208: re-staged at game.stick.pickup's neutral: this scene measures the lifted shot's flight over bodies and blades; the loose puck's pickup has its own (Jam.Core.Possession.*)
	if (!C) return false;
	FJamGameConfig Cfg = C->Game;
	TestEqual(TEXT("defaults: tap_m (0 since R-0042: a tap stays on the ice)"), Cfg.Shot.LiftTapM, 0.0);
	TestEqual(TEXT("defaults: half_m"), Cfg.Shot.LiftHalfM, 0.45);
	TestEqual(TEXT("defaults: full_m (0.47 since R-0044: 0.6 rang the 0.61 bar from 10 m, 0.5 from 15 m)"), Cfg.Shot.LiftFullM, 0.47);
	TestEqual(TEXT("defaults: tap_frames (R-0044: a hold of 4 frames or fewer is a tap)"), Cfg.Shot.TapFrames, 4);
	TestEqual(TEXT("defaults: half_frames"), Cfg.Shot.LiftHalfFrames, 8);
	TestEqual(TEXT("defaults: gravity"), Cfg.Puck.GravityMps2, 9.81);
	TestEqual(TEXT("defaults: ice restitution"), Cfg.Puck.IceRestitution, 0.3);
	Cfg.Rink.GoalHeightM = 1.22;   // a real net: every lift below goes in, so the flight is read to the line unhindered
	{
		UJamSim* Sim = MakeSim(Cfg, 1);
		TestEqual(TEXT("LiftForCharge(0) = tap_m = 0"), Sim->LiftForCharge(0.f), 0.0, 1e-9);
		TestEqual(TEXT("LiftForCharge(8/30) = half_m"), Sim->LiftForCharge(8.f / 30.f), 0.45, 1e-6);
		TestEqual(TEXT("LiftForCharge(1) = full_m"), Sim->LiftForCharge(1.f), 0.47, 1e-9);   // was 0.6: R-0044 moved full_m (0.47 by the table below)
		TestEqual(TEXT("LiftForCharge(19/30) = midway half -> full"), Sim->LiftForCharge(19.f / 30.f), 0.46, 1e-6);   // 0.45 + 11/22 of 0.02 (was 0.525 at full_m 0.6: R-0044)
		TestEqual(TEXT("LiftForCharge(4/30) = midway tap -> half"), Sim->LiftForCharge(4.f / 30.f), 0.225, 1e-6);   // (0 + 0.45) / 2 since tap_m 0 (R-0042)
	}
	const double Gx = C->Game.Rink.GoalLineX();
	struct FCase { int32 Hold; double Want; const TCHAR* Name; };
	for (const FCase& K : { FCase{ 0, 0.0, TEXT("tap") }, FCase{ 8, 0.45, TEXT("half (8 frames)") }, FCase{ 30, 0.47, TEXT("full (30 frames)") } })   // full: was 0.6 (R-0044: full_m 0.47)
	{
		UJamSim* Sim = MakeSim(Cfg, 1);
		Park(Sim);
		Line(Sim, 0, 12.0);
		// The carried puck is on the ice.
		TArray<FJamInput> None; None.Init(FJamInput(), Sim->GetSkaters().Num());
		for (int32 f = 0; f < 10; ++f) Sim->Step(None);
		TestEqual(*FString::Printf(TEXT("%s: the carried puck sits on the ice"), K.Name), Sim->GetPuck().Z, 0.0, 1e-9);
		Shoot(Sim, 0, K.Hold);
		TestTrue(*FString::Printf(TEXT("%s: the shot left"), K.Name), Sim->GetSkaters()[0].Shots == 1);
		const FFlight F = Fly(Sim, Gx);
		TestTrue(*FString::Printf(TEXT("%s: the puck crossed the goal line"), K.Name), F.bCrossed);
		TestEqual(*FString::Printf(TEXT("%s: height over the goal line"), K.Name), F.ZAtLine, K.Want, 0.04);
		TestEqual(*FString::Printf(TEXT("%s: a goal at 1.22"), K.Name), F.Goals, 1);
		// R-0042 (lane A85): a charge-0 shot flies flat: Z 0 the whole way (no parabola), so a blade between the shooter and the net can deflect it again.
		if (K.Hold == 0) TestEqual(TEXT("tap: on the ice the whole flight (apex 0)"), F.ZMax, 0.0, 1e-9);
		else TestTrue(*FString::Printf(TEXT("%s: lifted (apex %.2f m over 0.2)"), K.Name, F.ZMax), F.ZMax > UJamSim::BladeClearM);
		AddInfo(FString::Printf(TEXT("%s from 12 m: %.3f m over the line (apex %.2f m)"), K.Name, F.ZAtLine, F.ZMax));
	}
	// R-0044 (lane A91): a hold of shot.tap_frames (4) or fewer is a tap: charge 0, flat the whole flight, the tap's speed; the fifth frame is the first
	// charged one (5 / 30, lifted). With tap_frames 0 (the game before the ruling) a one-frame hold is a lifted shot of charge 1 / 30 again.
	{
		double TapSpeed = 0.0;
		for (const int32 Hold : { 1, 2, 3, 4, 5 })
		{
			UJamSim* Sim = MakeSim(Cfg, 1);
			Park(Sim); Line(Sim, 0, 12.0);
			Shoot(Sim, 0, Hold);
			const FJamSkaterState& Sk = Sim->GetSkaters()[0];
			const double Speed = Sim->GetPuck().Vel.Size();
			TestTrue(*FString::Printf(TEXT("hold %d: the shot left"), Hold), Sk.Shots == 1);
			const FFlight F = Fly(Sim, Gx);
			if (Hold <= 4)
			{
				TestEqual(*FString::Printf(TEXT("hold %d (<= tap_frames): charge 0"), Hold), static_cast<double>(Sk.LastShotCharge), 0.0, 1e-9);
				TestEqual(*FString::Printf(TEXT("hold %d (<= tap_frames): on the ice the whole flight"), Hold), F.ZMax, 0.0, 1e-9);
				if (Hold == 1) TapSpeed = Speed; else TestEqual(*FString::Printf(TEXT("hold %d: the tap's speed (no charge bonus)"), Hold), Speed, TapSpeed, 1e-6);
			}
			else
			{
				TestEqual(TEXT("hold 5: the first charged frame count, charge 5 / 30"), static_cast<double>(Sk.LastShotCharge), 5.0 / 30.0, 1e-4);
				TestTrue(*FString::Printf(TEXT("hold 5: lifted (apex %.2f m over 0.2)"), F.ZMax), F.ZMax > UJamSim::BladeClearM);
				TestTrue(TEXT("hold 5: faster than the tap (the charge bonus)"), Speed > TapSpeed + 0.5);
			}
			TestEqual(*FString::Printf(TEXT("hold %d: a goal"), Hold), F.Goals, 1);
		}
		FJamGameConfig NoTap = Cfg; NoTap.Shot.TapFrames = 0;
		UJamSim* Sim = MakeSim(NoTap, 1);
		Park(Sim); Line(Sim, 0, 12.0); Shoot(Sim, 0, 1);
		TestEqual(TEXT("tap_frames 0: a one-frame hold is charge 1 / 30"), static_cast<double>(Sim->GetSkaters()[0].LastShotCharge), 1.0 / 30.0, 1e-4);
		const FFlight F = Fly(Sim, Gx);
		TestTrue(TEXT("tap_frames 0: and it is lifted (the old lob)"), F.ZMax > 0.01);
	}
	// R-0044 (lane A91): the full charge at the 0.61 net. The bar rings from BarRingM + PostRadius = 0.10 m under its axis: a puck at 0.51 m or more over the
	// line is a post, not a goal; a long shot is falling at the line and is higher one puck radius before it, where the bar is tested. The table (info lines)
	// is the measurement the default was picked from; the asserts are the default's: MEASURE_ASSERT below.
	Cfg.Rink.GoalHeightM = 0.61;
	{
		TArray<double> Dists;
		for (int32 D = 3; D <= 30; ++D) Dists.Add(static_cast<double>(D));   // every metre from 3 to 30 m: one letter each, G goal, b bar, - neither
		for (const double Full : { 0.6, 0.5, 0.49, 0.48, 0.47, 0.46, 0.45 })
		{
			FString Row;
			for (const double Dist : Dists)
			{
				FJamGameConfig K = Cfg; K.Shot.LiftFullM = Full;
				UJamSim* Sim = MakeSim(K, 1);
				Park(Sim); Line(Sim, 0, Dist); Shoot(Sim, 0, 30);
				const FFlight F = Fly(Sim, Gx);
				Row += F.Goals == 1 ? TEXT("G") : (F.Posts > 0 ? TEXT("b") : TEXT("-"));
			}
			AddInfo(FString::Printf(TEXT("0.61 net, full charge, full_m %.2f, 3..30 m: %s"), Full, *Row));
		}
		for (const int32 Hold : { 8, 10, 18, 24 })
		{
			FString Row;
			for (const double Dist : Dists)
			{
				UJamSim* Sim = MakeSim(Cfg, 1);
				Park(Sim); Line(Sim, 0, Dist); Shoot(Sim, 0, Hold);
				const FFlight F = Fly(Sim, Gx);
				Row += F.Goals == 1 ? TEXT("G") : (F.Posts > 0 ? TEXT("b") : TEXT("-"));
			}
			AddInfo(FString::Printf(TEXT("0.61 net, the default lift, a hold of %d frames, 3..30 m: %s"), Hold, *Row));
		}
	}
	// The default's asserts: every hold from the first charged frame (5) to the full charge, from every metre of 3..30 m: never the bar, and the full charge
	// and the half charge a goal each time (an empty net, nobody on the lane).
	{
		int32 Bars = 0, FullGoals = 0, HalfGoals = 0, Shots = 0;
		FString First;
		for (int32 Hold = 5; Hold <= 30; ++Hold)
		{
			for (int32 D = 3; D <= 30; ++D)
			{
				UJamSim* Sim = MakeSim(Cfg, 1);
				Park(Sim); Line(Sim, 0, static_cast<double>(D)); Shoot(Sim, 0, Hold);
				const FFlight F = Fly(Sim, Gx);
				++Shots;
				if (F.Posts > 0) { ++Bars; if (First.IsEmpty()) First = FString::Printf(TEXT("hold %d from %d m"), Hold, D); }
				if (Hold == 30 && F.Goals == 1) ++FullGoals;
				if (Hold == 8 && F.Goals == 1) ++HalfGoals;
			}
		}
		AddInfo(FString::Printf(TEXT("0.61 net, the default lift: %d shots (holds 5..30 x 3..30 m): %d rang the bar%s%s; full charge goals %d of 28, half charge goals %d of 28"),
			Shots, Bars, First.IsEmpty() ? TEXT("") : TEXT(", first: "), *First, FullGoals, HalfGoals));
		TestEqual(TEXT("0.61, the default lift: no charged shot from 3..30 m rings the bar"), Bars, 0);
		TestEqual(TEXT("0.61, the full charge is a goal from every metre of 3..30"), FullGoals, 28);
		TestEqual(TEXT("0.61, the half charge is a goal from every metre of 3..30"), HalfGoals, 28);
	}
	{
		FJamGameConfig Old = Cfg; Old.Shot.LiftFullM = 0.6;
		UJamSim* Sim = MakeSim(Old, 1);
		Park(Sim); Line(Sim, 0, 10.0); Shoot(Sim, 0, 30);
		const FFlight F = Fly(Sim, Gx);
		TestTrue(TEXT("0.61, full_m 0.6 from 10 m: the bar (a post, no goal): the fault R-0044 removes"), F.Posts >= 1 && F.Goals == 0);
	}
	Cfg.Rink.GoalHeightM = 1.22;
	// The one-timer window: a shot right after a received pass lifts full without the hold (TryShoot forces Charge 1): read through LiftForCharge(1) above.
	// The 0.61 bar: a cartridge with full_m 0.95 (the sailing shot; the default is 0.47 since R-0044) flies over the net on a full charge; a tap goes in.
	Cfg.Rink.GoalHeightM = 0.61;
	{
		FJamGameConfig Sail = Cfg; Sail.Shot.LiftFullM = 0.95;
		UJamSim* Sim = MakeSim(Sail, 1);
		Park(Sim); Line(Sim, 0, 12.0); Shoot(Sim, 0, 30);
		const FFlight F = Fly(Sim, Gx);
		TestEqual(TEXT("0.61: the full charge is no goal"), F.Goals, 0);
		TestTrue(TEXT("0.61: it flew over the net"), F.bFlewOver);
	}
	{
		UJamSim* Sim = MakeSim(Cfg, 1);
		Park(Sim); Line(Sim, 0, 12.0); Shoot(Sim, 0, 0);
		const FFlight F = Fly(Sim, Gx);
		TestEqual(TEXT("0.61: the tap is a goal"), F.Goals, 1);
	}
	// The bounce: a lifted puck that lands hops lower and dies (Z and VZ both 0 within two seconds), its flight never touching the glass.
	{
		UJamSim* Sim = MakeSim(Cfg, 1);
		Sim->SetPuck(FVector2D(0.0, 0.0), FVector2D(2.0, 0.0), 1.0, 0.0);
		TArray<FJamInput> None; None.Init(FJamInput(), Sim->GetSkaters().Num());
		int32 Landings = 0;
		double PrevVZ = 0.0;
		for (int32 f = 0; f < 120; ++f)
		{
			Sim->Step(None);
			const FJamPuckState& P = Sim->GetPuck();
			if (PrevVZ < 0.0 && P.VZ > 0.0) ++Landings;
			PrevVZ = P.VZ;
		}
		TestTrue(TEXT("the drop from 1 m bounced at least once (4.4 m/s down, 1.3 up: a 9 cm hop; the second landing is under the 2 cm dead band)"), Landings >= 1);
		TestEqual(TEXT("... and died on the ice"), Sim->GetPuck().Z, 0.0, 1e-9);
		TestEqual(TEXT("... with no vertical speed left"), Sim->GetPuck().VZ, 0.0, 1e-9);
	}
	// Lift keys at 0: every shot stays on the ice (the old game).
	{
		FJamGameConfig Flat = Cfg;
		Flat.Shot.LiftTapM = Flat.Shot.LiftHalfM = Flat.Shot.LiftFullM = 0.0;
		UJamSim* Sim = MakeSim(Flat, 1);
		Park(Sim); Line(Sim, 0, 12.0); Shoot(Sim, 0, 30);
		const FFlight F = Fly(Sim, Gx);
		TestEqual(TEXT("lift 0: the full charge stays on the ice"), F.ZMax, 0.0, 1e-9);
		TestEqual(TEXT("lift 0: and scores at 0.61"), F.Goals, 1);
	}
	return true;
}

// The save by height: a skater in the crease stance (within 3 m of its own goal centre) within game.skater.goalie.reach_m (0.9) of a low shot's path saves
// it (the `save` read-out, the puck dies at its feet, its touch); a puck over goalie.block_height_m (0.4) passes it; the human in the stance saves the same way;
// a stance skater off the path by more than the reach saves nothing.
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamSaveByHeight, "Jam.Core.SaveByHeight", JamLiftedPuckTests::Flags)
bool FJamSaveByHeight::RunTest(const FString&)
{
	UJamCartridge* C = LoadPreset(*this, TEXT("hockey.regular"));
	if (C) { C->Game.Stick.PickupArcM = 0.0; C->Game.Stick.bPickupBody = false; }   // lane A208: re-staged at game.stick.pickup's neutral: this scene measures the crease skater's save by height; the loose puck's pickup has its own (Jam.Core.Possession.*)
	if (!C) return false;
	FJamGameConfig Cfg = C->Game;
	TestEqual(TEXT("defaults: goalie reach"), Cfg.Skater.GoalieReachM, 0.9);
	TestEqual(TEXT("defaults: goalie block height"), Cfg.Skater.GoalieBlockHeightM, 0.4);
	Cfg.Rink.GoalHeightM = 1.22;   // a real net, so only the stance decides
	const double Gx = Cfg.Rink.GoalLineX();
	// Team 1 defends +x: its first skater is the crease skater.
	int32 Goalie = -1, Shooter = -1;
	{
		UJamSim* Sim = MakeSim(Cfg, 1);
		for (const FJamSkaterState& S : Sim->GetSkaters()) { if (S.Team == 1 && Goalie < 0) Goalie = S.Index; if (S.Team == 0 && Shooter < 0) Shooter = S.Index; }
	}
	TestTrue(TEXT("both teams have a skater"), Goalie >= 0 && Shooter >= 0);
	// A tap from 8 m through the stance: saved.
	{
		UJamSim* Sim = MakeSim(Cfg, 1);
		Park(Sim); Line(Sim, Shooter, 8.0);
		Sim->SetSkater(Goalie, FVector2D(Gx - 1.0, 0.0), FVector2D::ZeroVector, UE_DOUBLE_PI);
		Shoot(Sim, Shooter, 0);
		const FFlight F = Fly(Sim, Gx);
		TestEqual(TEXT("tap: one save"), F.Saves, 1);
		TestEqual(TEXT("tap: by the crease skater"), F.Saver, Goalie);
		TestEqual(TEXT("tap: no goal"), F.Goals, 0);
		TestTrue(TEXT("tap: the puck came back off the pads, loose in front of the crease (and on the ice)"), Sim->GetPuck().Pos.X < Gx - 1.0 && Sim->GetPuck().Z == 0.0);
	}
	// The full charge from 12 m passes over the stance (0.6 > 0.4) and goes in at 1.22.
	{
		UJamSim* Sim = MakeSim(Cfg, 1);
		Park(Sim); Line(Sim, Shooter, 12.0);
		Sim->SetSkater(Goalie, FVector2D(Gx - 1.0, 0.0), FVector2D::ZeroVector, UE_DOUBLE_PI);
		Shoot(Sim, Shooter, 30);
		const FFlight F = Fly(Sim, Gx);
		TestEqual(TEXT("full: no save"), F.Saves, 0);
		TestEqual(TEXT("full: a goal over the stance"), F.Goals, 1);
	}
	// The stance skater 1.5 m off the path: no save, the tap goes in.
	{
		UJamSim* Sim = MakeSim(Cfg, 1);
		Park(Sim); Line(Sim, Shooter, 8.0);
		Sim->SetSkater(Goalie, FVector2D(Gx - 1.0, 1.5), FVector2D::ZeroVector, UE_DOUBLE_PI);
		Shoot(Sim, Shooter, 0);
		const FFlight F = Fly(Sim, Gx);
		TestEqual(TEXT("off the path: no save"), F.Saves, 0);
		TestEqual(TEXT("off the path: the tap is a goal"), F.Goals, 1);
	}
	// A skater 3.5 m out is not in the stance: the puck passes it on the way in (nobody in the crease), the tap goes in.
	{
		UJamSim* Sim = MakeSim(Cfg, 1);
		Park(Sim); Line(Sim, Shooter, 8.0);
		Sim->SetSkater(Goalie, FVector2D(Gx - 3.5, 0.9), FVector2D::ZeroVector, UE_DOUBLE_PI);
		Shoot(Sim, Shooter, 0);
		const FFlight F = Fly(Sim, Gx);
		TestEqual(TEXT("out of the crease: no save by height"), F.Saves, 0);
	}
	// The human in the stance saves the same way: team 0's human in its own crease at -x, a team-1 shooter taps from 8 m.
	{
		UJamSim* Sim = MakeSim(Cfg, 1);
		const int32 Human = Sim->GetHumanIndex();
		TestTrue(TEXT("the human is on team 0"), Sim->GetSkaters()[Human].Team == 0);
		Park(Sim); Line(Sim, Goalie, 8.0);   // the team-1 skater shoots at the -x net
		Sim->SetSkater(Human, FVector2D(-Gx + 1.0, 0.0), FVector2D::ZeroVector, 0.0);
		Shoot(Sim, Goalie, 0);
		const FFlight F = Fly(Sim, -Gx);
		TestEqual(TEXT("human: one save"), F.Saves, 1);
		TestEqual(TEXT("human: by the human"), F.Saver, Human);
		TestEqual(TEXT("human: no goal"), F.Goals, 0);
	}
	// goalie.reach_m 0 turns the save by height off: the tap through the stance is stopped by the body as before (no save by height; the body's own
	// read-out may call it), never a goal from 8 m straight into a skater.
	{
		FJamGameConfig Off = Cfg;
		Off.Skater.GoalieReachM = 0.0;
		UJamSim* Sim = MakeSim(Off, 1);
		Park(Sim); Line(Sim, Shooter, 8.0);
		Sim->SetSkater(Goalie, FVector2D(Gx - 1.0, 0.0), FVector2D::ZeroVector, UE_DOUBLE_PI);
		Shoot(Sim, Shooter, 0);
		const FFlight F = Fly(Sim, Gx);
		TestEqual(TEXT("reach 0: no goal (the body stops it)"), F.Goals, 0);
	}
	return true;
}

// Posts and the bar: a puck crossing the goal line with its centre within 5 cm of the crossbar (plus the bar's radius) rings `post` and reflects; under
// it scores; over it flies over the net (no goal, no post); a puck into a post rings as before; a puck over the post's height flies over it.
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamPostRings, "Jam.Core.PostRings", JamLiftedPuckTests::Flags)
bool FJamPostRings::RunTest(const FString&)
{
	UJamCartridge* C = LoadPreset(*this, TEXT("hockey.regular"));
	if (!C) return false;
	const FJamGameConfig& Cfg = C->Game;
	const double Gx = Cfg.Rink.GoalLineX();
	const double Hw = Cfg.Rink.GoalWidthM * 0.5;
	const double Bar = Cfg.Rink.GoalHeightM;
	// 1 m out at 20 m/s: 0.05 s of flight, a 1.2 cm drop; the start height puts the centre at the bar on the line.
	const double Drop = 0.5 * Cfg.Puck.GravityMps2 * 0.05 * 0.05;
	struct FCase { double Y; double Z0; bool bPost; int32 Goal; const TCHAR* Name; };
	const FCase Cases[] = {
		{ 0.0, Bar + Drop, true, 0, TEXT("at the bar: rings, no goal") },
		{ 0.0, Bar + Drop - 0.07, true, 0, TEXT("7 cm under the bar's axis: rings") },
		{ 0.0, Bar + Drop + 0.07, true, 0, TEXT("7 cm over the bar's axis: rings") },
		{ 0.0, 0.30, false, 1, TEXT("30 cm up: under the bar, a goal") },
		{ 0.0, 0.0, false, 1, TEXT("on the ice: a goal") },
		{ 0.0, Bar + 0.30, false, 0, TEXT("30 cm over the bar: flies over, no post, no goal") },
		{ Hw, 0.30, true, 0, TEXT("into the post at 30 cm: rings") },
		{ Hw, Bar + 0.30, false, 0, TEXT("over the post: flies over") },
	};
	for (const FCase& K : Cases)
	{
		UJamSim* Sim = MakeSim(Cfg, 1);
		Park(Sim);
		Sim->SetPuck(FVector2D(Gx - 1.0, K.Y), FVector2D(20.0, 0.0), K.Z0, 0.0);
		const FFlight F = Fly(Sim, Gx, 60);
		TestEqual(*FString::Printf(TEXT("%s: post events"), K.Name), F.Posts > 0, K.bPost);
		TestEqual(*FString::Printf(TEXT("%s: goals"), K.Name), F.Goals, K.Goal);
		if (K.bPost && K.Y == 0.0) TestTrue(*FString::Printf(TEXT("%s: the puck came back off the bar"), K.Name), Sim->GetPuck().Vel.X < 0.0 || Sim->GetPuck().Pos.X < Gx);
	}
	// The post event carries the post (or the bar's crossing point) and the puck's strength; Who is -1.
	{
		UJamSim* Sim = MakeSim(Cfg, 1);
		Park(Sim);
		Sim->SetPuck(FVector2D(Gx - 1.0, 0.0), FVector2D(20.0, 0.0), Bar + Drop, 0.0);
		TArray<FJamInput> None; None.Init(FJamInput(), Sim->GetSkaters().Num());
		bool bSeen = false;
		for (int32 f = 0; f < 10 && !bSeen; ++f)
		{
			Sim->Step(None);
			for (const FJamSimEvent& E : Sim->GetFrameEvents())
			{
				if (E.Name != JamEvents::Post) continue;
				bSeen = true;
				TestEqual(TEXT("post: Who -1"), E.Who, -1);
				TestEqual(TEXT("post: at the goal line"), E.Where.X, Gx, 1e-6);
				TestTrue(TEXT("post: strength from the speed"), E.Strength > 0.5f && E.Strength <= 1.f);
			}
		}
		TestTrue(TEXT("the bar's post event was seen"), bSeen);
	}
	return true;
}

#endif
