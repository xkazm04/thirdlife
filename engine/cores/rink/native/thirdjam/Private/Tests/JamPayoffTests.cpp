// Lane A39 (R-0029 point 4): Jam.Core.Payoffs: the three payoffs as calibrations with a cartridge key each (docs/experiments/PAYOFFS.md).
//   Keys: the defaults load, the keys load, an unknown key under one is rejected with its pointer.
//   OneTimer: a scripted cross-ice pass and a tap inside shot.one_timer.window_frames is a one-timer (full charge, kind one_timer, a 10-degree facing snapped
//             onto the net by the widened cone) where the same tap outside the window is a plain shot at tap speed that goes 10 degrees wide.
//   Breakaway: a carrier past the last defender bursts once (event breakaway), reaches the slot earlier and farther ahead of the chaser than without the
//             burst (speed_bonus 0 turns it off: no event).
//   Deke: against the crease back (the brain's last man), a deke moves the puck a metre to the side within 6 frames, a second tap inside 30 frames does
//             nothing, and the shot at the open post scores in 2 of 3 seeds where the same shot without the deke is saved.
// Headless: UnrealEditor-Cmd.exe Game/ThirdJam.uproject -ExecCmds="Automation RunTests Jam.Core.Payoffs; Quit" -unattended -nullrhi -nosplash -log
#include "Misc/AutomationTest.h"
#include "JamCartridge.h"
#include "JamSim.h"
#include "JamBaseline.h"   // lane A207: PassShotNeutral
#include "JamEventBus.h"
#include "JamAICore.h"
#include "JamSimAdapter.h"
#include "DifficultyResolve.h"

#if WITH_DEV_AUTOMATION_TESTS

namespace JamPayoffTests
{
	constexpr EAutomationTestFlags Flags = EAutomationTestFlags_ApplicationContextMask | EAutomationTestFlags::ProductFilter;
	const FName KindOneTimer(TEXT("one_timer"));

	UJamCartridge* LoadPreset(FAutomationTestBase& T, const FString& Name)
	{
		TArray<FString> Errors;
		UJamCartridge* C = UJamCartridge::LoadFromFile(UJamCartridge::ResolveCartridgePath(Name), Errors);
		for (const FString& E : Errors) T.AddError(FString::Printf(TEXT("%s: %s"), *Name, *E));
		return C;
	}

	int32 FindRole(const UJamSim* Sim, int32 Team, const TCHAR* Role)
	{
		for (const FJamSkaterState& S : Sim->GetSkaters()) if (S.Team == Team && S.Role == FName(Role)) return S.Index;
		return -1;
	}

	int32 Count(const UJamSim* Sim, FName Name, int32 Who = -2, FName Kind = FName(TEXT("__any")))
	{
		int32 N = 0;
		for (const FJamSimEvent& E : Sim->GetFrameEvents())
			if (E.Name == Name && (Who == -2 || E.Who == Who) && (Kind == FName(TEXT("__any")) || E.Kind == Kind)) ++N;
		return N;
	}

	// A scene on UJamSim through FJamSimAdapter: the brain plays every skater the script does not name; a scripted skater gets the script's input
	// (zero input = parked). The human's slot is never driven by the brain, so it is scripted by definition.
	struct FPayoffScene
	{
		TUniquePtr<JamAI::FJamSimAdapter> Adapter;
		JamAI::FJamMatchConfig Cfg;
		JamAI::FJamBrain Brain;
		JamAI::FJamAIWorld W;
		JamAI::FJamAIInput In[JamAI::kMaxSkaters];
		bool bScripted[JamAI::kMaxSkaters] = {};
		UJamSim* Sim = nullptr;

		FPayoffScene(const UJamCartridge& Cart, const FJamGameConfig& G, uint64 Seed, const TCHAR* Level)
		{
			Adapter = MakeUnique<JamAI::FJamSimAdapter>(G);
			Cfg = JamAI::ToMatchConfigResolved(Cart, Level);
			Adapter->Reset(Cfg, Seed);
			Sim = Adapter->GetSim();
			Sim->SkipFaceoff();
			Brain.Reset();
			Brain.Params = Cfg.AI;
			Brain.Params.InterceptSpeed = Cfg.Speed;
			Brain.Params.AimConeDeg = Cfg.AimConeDeg;
		}

		void ScriptAll() { for (bool& B : bScripted) B = true; }

		void Step(const TMap<int32, JamAI::FJamAIInput>& Script)
		{
			Adapter->View(W);
			for (JamAI::FJamAIInput& I : In) I = JamAI::FJamAIInput();
			Brain.Think(W, In);
			for (int32 i = 0; i < W.NumSkaters; ++i) if (bScripted[i]) In[i] = JamAI::FJamAIInput();
			for (const TPair<int32, JamAI::FJamAIInput>& P : Script) In[P.Key] = P.Value;
			Adapter->Step(In);
		}

		// The puck just ahead of Who and one quiet frame: Who is the carrier.
		void GivePuck(int32 Who)
		{
			const FJamSkaterState& S = Sim->GetSkaters()[Who];
			Sim->SetPuck(S.Pos + S.Forward() * 0.45, S.Vel);
			bool Saved[JamAI::kMaxSkaters];
			for (int32 i = 0; i < JamAI::kMaxSkaters; ++i) { Saved[i] = bScripted[i]; bScripted[i] = true; }
			Step({});
			for (int32 i = 0; i < JamAI::kMaxSkaters; ++i) bScripted[i] = Saved[i];
		}
	};

	JamAI::FJamAIInput Move(double X, double Y) { JamAI::FJamAIInput I; I.Move = JamAI::FVec2(X, Y); return I; }
}

// Keys: defaults, the keys written, an unknown key under one rejected with its pointer.
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamPayoffKeys, "Jam.Core.Payoffs.Keys", JamPayoffTests::Flags)
bool FJamPayoffKeys::RunTest(const FString& Parameters)
{
	using namespace JamPayoffTests;
	UJamCartridge* C = LoadPreset(*this, TEXT("hockey.regular"));
	if (!C) return false;
	const FJamGameConfig& G = C->Game;
	TestEqual(TEXT("shot.one_timer.window_frames default 10"), G.Shot.OneTimerWindowFrames, 10);
	TestEqual(TEXT("shot.one_timer.cone_bonus_deg default 8"), G.Shot.OneTimerConeBonusDeg, 8.0);
	TestEqual(TEXT("skater.breakaway.speed_bonus default 0.3 (lane A194)"), G.Skater.BreakawaySpeedBonus, 0.3);
	TestEqual(TEXT("skater.breakaway.frames default 60"), G.Skater.BreakawayFrames, 60);
	TestEqual(TEXT("stick.deke.offset_m default 1.0"), G.Stick.DekeOffsetM, 1.0);
	TestEqual(TEXT("stick.deke.commit_frames default 15"), G.Stick.DekeCommitFrames, 15);

	// The keys written: the loader reads the nested objects (the schema mirror accepts them: schema/game.schema.json).
	FString Raw = C->RawJson;
	const int32 ShotAt = Raw.Find(TEXT("\"shot\": {"));
	const int32 SkaterAt = Raw.Find(TEXT("\"skater\": {"));
	const int32 PuckAt = Raw.Find(TEXT("\"puck\": {"));
	if (ShotAt < 0 || SkaterAt < 0 || PuckAt < 0) { AddError(TEXT("hockey.regular's RawJson has no \"shot\": { / \"skater\": { / \"puck\": { to splice the keys into")); return false; }
	FString Edited = Raw.Replace(TEXT("\"shot\": {"), TEXT("\"shot\": {\"one_timer\": {\"window_frames\": 4, \"cone_bonus_deg\": 2},"));
	Edited = Edited.Replace(TEXT("\"skater\": {"), TEXT("\"skater\": {\"breakaway\": {\"speed_bonus\": 0.5, \"frames\": 30},"));
	Edited = Edited.Replace(TEXT("\"puck\": {"), TEXT("\"stick\": {\"deke\": {\"offset_m\": 0.5, \"commit_frames\": 9}}, \"puck\": {"));
	{
		TArray<FString> Errors;
		UJamCartridge* V = UJamCartridge::LoadFromString(Edited, Errors);
		for (const FString& E : Errors) AddError(FString::Printf(TEXT("variant: %s"), *E));
		if (V)
		{
			TestEqual(TEXT("window_frames 4 read"), V->Game.Shot.OneTimerWindowFrames, 4);
			TestEqual(TEXT("cone_bonus_deg 2 read"), V->Game.Shot.OneTimerConeBonusDeg, 2.0);
			TestEqual(TEXT("speed_bonus 0.5 read"), V->Game.Skater.BreakawaySpeedBonus, 0.5);
			TestEqual(TEXT("breakaway frames 30 read"), V->Game.Skater.BreakawayFrames, 30);
			TestEqual(TEXT("offset_m 0.5 read"), V->Game.Stick.DekeOffsetM, 0.5);
			TestEqual(TEXT("commit_frames 9 read"), V->Game.Stick.DekeCommitFrames, 9);
		}
	}
	{
		TArray<FString> Errors;
		const FString Bad = Raw.Replace(TEXT("\"shot\": {"), TEXT("\"shot\": {\"one_timer\": {\"window\": 4},"));
		UJamCartridge* V = UJamCartridge::LoadFromString(Bad, Errors);
		TestNull(TEXT("an unknown key under one_timer is rejected"), V);
		bool bPointer = false;
		for (const FString& E : Errors) if (E.Contains(TEXT("/game/shot/one_timer"))) bPointer = true;
		TestTrue(TEXT("... with the pointer /game/shot/one_timer first"), bPointer);
		if (Errors.Num()) AddInfo(Errors[0]);
	}
	return true;
}

// OneTimer: a cross-ice pass lands on the slot man's blade; a tap inside the window is a one-timer (full charge, kind one_timer, the widened cone
// snaps a facing 10 degrees off the net onto it) where the same tap outside the window is a plain shot (tap speed, no snap: it goes 10 degrees wide).
// (The puck sits 1.1 m to the side of the body on the blade, which adds 5 degrees between the facing and the puck's line to the net: 10 + 5 < 8 + 8.)
// The brain's pro back plays the scene; whether either shot beats it is reported, not asserted: the guard post follows the puck in flight, so from 12 m
// a back with zero reaction frames is on the receiver's line before a 16 m pass arrives (PAYOFFS.md says what the one-timer buys instead).
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamPayoffOneTimer, "Jam.Core.Payoffs.OneTimer", JamPayoffTests::Flags)
bool FJamPayoffOneTimer::RunTest(const FString& Parameters)
{
	using namespace JamPayoffTests;
	UJamCartridge* C = LoadPreset(*this, TEXT("hockey.regular"));
	if (!C) return false;
	FJamGameConfig G = C->Game;
	JamBaseline::PassShotNeutral(G);   // lane A207: this scene pins the pass and shot before game.pass.power / aim / catch_m / clear_own_body and game.shot.speed_scale: their neutral values
	// The scene's pass crosses 16 m; the sim receives a teammate's puck on the blade only above 6 m/s (DeflectMinSpeed), and 14 m/s minus puck.drag 0.5
	// per metre arrives at 5.9: the scene passes at 20 m/s (a scene number, not a calibration).
	G.Skater.PassSpeed = 20.0;
	bool bOk = true;
	for (const double OffDeg : { 0.0, 10.0 })
	{
		for (const bool bInside : { true, false })
		{
			FPayoffScene Sc(*C, G, 1, TEXT("pro"));
			UJamSim* Sim = Sc.Sim;
			const double Gx = Sim->GoalLineX();
			const int32 Me = Sim->GetHumanIndex();
			const int32 Passer = FindRole(Sim, 0, TEXT("chaser"));
			const int32 OwnBack = FindRole(Sim, 0, TEXT("back"));
			const int32 Back = FindRole(Sim, 1, TEXT("back"));
			const int32 Between = FindRole(Sim, 1, TEXT("chaser"));
			const int32 Far = FindRole(Sim, 1, TEXT("support"));
			if (Me < 0 || Passer < 0 || OwnBack < 0 || Back < 0 || Between < 0 || Far < 0) { AddError(TEXT("hockey.regular roster: player + chaser + back against chaser + support + back expected")); return false; }
			Sc.ScriptAll();
			Sc.bScripted[Back] = false;   // the back is the brain's (pro: blocks shots, holds the crease as the last man)
			Sim->SetSkater(OwnBack, FVector2D(-30, 10), FVector2D::ZeroVector, 0);
			Sim->SetSkater(Far, FVector2D(-30, -10), FVector2D::ZeroVector, UE_DOUBLE_PI);
			// An opponent on the passer's line to the net: the back is not the last man while the passer carries, so it guards 5 m out on that line.
			Sim->SetSkater(Between, FVector2D(Gx - 7.2, -4.8), FVector2D::ZeroVector, UE_DOUBLE_PI);
			Sim->SetSkater(Back, FVector2D(Gx - 4.2, -2.8), FVector2D::ZeroVector, UE_DOUBLE_PI);
			Sim->SetSkater(Passer, FVector2D(Gx - 12, -8), FVector2D::ZeroVector, UE_DOUBLE_PI * 0.5);
			const FVector2D Recv(Gx - 9, 8);   // 12.04 m from the goal centre
			const FVector2D ToGoal = (FVector2D(Gx, 0) - Recv).GetSafeNormal();
			// The receiver faces the net, or OffDeg towards the passer (clockwise: the passer is at -z): inside the plain 8-degree cone at 0, outside it at 10.
			Sim->SetSkater(Me, Recv, FVector2D::ZeroVector, FMath::Atan2(ToGoal.Y, ToGoal.X) - FMath::DegreesToRadians(OffDeg));
			Sc.GivePuck(Passer);
			// The receiver holds the blade towards the passer at 0.6 of the reach (1.12 m from the body: inside shot reach, so the seated puck is carried);
			// the back settles on its guard post.
			JamAI::FJamAIInput R;
			{
				const FVector2D D = (Sim->GetSkaters()[Passer].Pos - Recv).GetSafeNormal() * 0.6;
				R.Stick = JamAI::FVec2(D.X, D.Y);
			}
			for (int32 F = 0; F < 60; ++F) Sc.Step({ { Me, R } });
			TestEqual(TEXT("the passer carries"), Sim->CarrierIndex(), Passer);
			JamAI::FJamAIInput Pz;
			Pz.bPass = true;
			Sc.Step({ { Passer, Pz }, { Me, R } });
			TestTrue(TEXT("the pass leaves"), Count(Sim, JamEvents::Pass, Passer) == 1);
			int32 RecvFrame = -1;
			for (int32 F = 1; F <= 240 && RecvFrame < 0; ++F)
			{
				Sc.Step({ { Me, R } });
				if (Sim->GetPuck().LastTouch == Me && Sim->GetSkaters()[Me].PassReceivedFrame >= 0) RecvFrame = F;
			}
			TestTrue(TEXT("the pass is received on the blade"), RecvFrame > 0);
			if (RecvFrame < 0) { bOk = false; continue; }
			int32 ShotFrame = -1;
			bool bGoal = false;
			FName Kind = NAME_None;
			float Charge = -1.f;
			double Exit = 0, YAtLine = 1e9;
			for (int32 F = 1; F <= 200; ++F)
			{
				JamAI::FJamAIInput H;   // the stick stays on the puck (R) until the tap, so the shot leaves from where the pass landed
				if (bInside) { if (F <= 1) { H = R; H.bShoot = true; } }
				else { if (F < 40) H = R; if (F == 40) { H = R; H.bShoot = true; } }   // the same tap 40 frames later: outside the 10-frame window
				Sc.Step({ { Me, H } });
				for (const FJamSimEvent& E : Sim->GetFrameEvents())
				{
					if (E.Name == JamEvents::Shot && E.Who == Me)
					{
						ShotFrame = F;
						Kind = E.Kind;
						Exit = Sim->GetPuck().Vel.Size();
						Charge = Sim->GetSkaters()[Me].LastShotCharge;
						const FVector2D P = Sim->GetPuck().Pos, V = Sim->GetPuck().Vel;
						if (V.X > 1e-6) YAtLine = P.Y + V.Y * (Gx - P.X) / V.X;   // where the shot's line crosses the goal line (no drag, no bodies)
					}
					if (E.Name == JamEvents::Goal && ShotFrame > 0) bGoal = true;
				}
				if (bGoal || (ShotFrame > 0 && F > ShotFrame + 90)) break;
			}
			AddInfo(FString::Printf(TEXT("facing %.0f deg off, %s the window: received at +%d, shot at +%d, kind %s, charge %.2f, exit %.1f m/s, line crosses the goal line at z %.2f, goal %d"),
				OffDeg, bInside ? TEXT("inside") : TEXT("outside"), RecvFrame, ShotFrame, *Kind.ToString(), Charge, Exit, YAtLine, bGoal ? 1 : 0));
			if (ShotFrame < 0) { AddError(TEXT("no shot left")); bOk = false; continue; }
			const double Hw = G.Rink.GoalWidthM * 0.5;
			if (bInside)
			{
				TestEqual(TEXT("a tap inside the window is a one-timer"), Kind, KindOneTimer);
				TestTrue(TEXT("a one-timer tap has the full charge"), FMath::IsNearlyEqual(Charge, 1.f, 0.01f));
				TestTrue(TEXT("a one-timer leaves at speed + charge bonus"), FMath::IsNearlyEqual(Exit, FMath::Min(G.Shot.Speed + G.Shot.ChargeSpeedBonus, G.Puck.MaxSpeed), 0.6));
				TestEqual(TEXT("the one-timer is counted"), Sim->GetSkaters()[Me].OneTimers, 1);
				TestTrue(*FString::Printf(TEXT("the one-timer's cone (%g + %g degrees) snaps a facing %.0f degrees off onto the net"), G.Shot.AimConeDeg, G.Shot.OneTimerConeBonusDeg, OffDeg), FMath::Abs(YAtLine) < Hw);
			}
			else
			{
				TestEqual(TEXT("a tap outside the window is a plain shot"), Kind, FName(NAME_None));
				TestTrue(TEXT("... at tap speed"), FMath::IsNearlyEqual(Exit, FMath::Min(G.Shot.Speed, G.Puck.MaxSpeed), 0.6));
				if (OffDeg > G.Shot.AimConeDeg) TestTrue(*FString::Printf(TEXT("a plain tap facing %.0f degrees off (outside the %g-degree cone) goes wide"), OffDeg, G.Shot.AimConeDeg), FMath::Abs(YAtLine) > Hw);
				else TestTrue(TEXT("a plain tap facing the net is on the net"), FMath::Abs(YAtLine) < Hw);
			}
		}
	}
	return bOk;
}

// Breakaway: the burst fires once past the last defender and the carrier reaches the slot before the chaser can.
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamPayoffBreakaway, "Jam.Core.Payoffs.Breakaway", JamPayoffTests::Flags)
bool FJamPayoffBreakaway::RunTest(const FString& Parameters)
{
	using namespace JamPayoffTests;
	UJamCartridge* C = LoadPreset(*this, TEXT("hockey.regular"));
	if (!C) return false;
	int32 Arrive[2] = { -1, -1 };
	double Gap[2] = { 0, 0 };
	int32 Events[2] = { 0, 0 };
	for (int32 Run = 0; Run < 2; ++Run)
	{
		const bool bBurst = Run == 0;
		FJamGameConfig G = C->Game;
		if (!bBurst) G.Skater.BreakawaySpeedBonus = 0.0;   // off
		FPayoffScene Sc(*C, G, 1, TEXT("pro"));
		UJamSim* Sim = Sc.Sim;
		Sc.ScriptAll();
		const double Gx = Sim->GoalLineX();
		const int32 Me = Sim->GetHumanIndex();
		const int32 Mate = FindRole(Sim, 0, TEXT("chaser"));
		const int32 OwnBack = FindRole(Sim, 0, TEXT("back"));
		const int32 Chaser = FindRole(Sim, 1, TEXT("chaser"));
		const int32 Support = FindRole(Sim, 1, TEXT("support"));
		const int32 Back = FindRole(Sim, 1, TEXT("back"));
		const double V = G.Skater.Speed;
		// Past centre ice at top speed, the chaser 3.5 m behind at the same speed, the support behind on the side, the back home in its crease.
		Sim->SetSkater(Me, FVector2D(2, 0), FVector2D(V, 0), 0);
		Sim->SetSkater(Chaser, FVector2D(-1.5, 0), FVector2D(V, 0), 0);
		Sim->SetSkater(Support, FVector2D(-1.5, 4), FVector2D(V, 0), 0);
		Sim->SetSkater(Back, FVector2D(Gx - 2, 0), FVector2D::ZeroVector, UE_DOUBLE_PI);
		Sim->SetSkater(Mate, FVector2D(-30, 10), FVector2D::ZeroVector, 0);
		Sim->SetSkater(OwnBack, FVector2D(-30, -10), FVector2D::ZeroVector, 0);
		Sc.GivePuck(Me);
		TestEqual(TEXT("the human carries"), Sim->CarrierIndex(), Me);
		int32 FirstEvent = -1;
		for (int32 F = 1; F <= 300; ++F)
		{
			Sc.Step({ { Me, Move(1, 0) }, { Chaser, Move(1, 0) }, { Support, Move(1, 0) } });
			const int32 N = Count(Sim, JamEvents::Breakaway, Me);
			if (Sim->GetSkaters()[Me].bBreakawayThisFrame && FirstEvent < 0)
			{
				FirstEvent = F;
				TestEqual(TEXT("the burst runs skater.breakaway.frames"), Sim->GetSkaters()[Me].BreakawayFrames, G.Skater.BreakawayFrames);
			}
			Events[Run] += N;   // lane A32's read-out and the burst share the name: one event per rush
			if (Sim->CarrierIndex() != Me)
			{
				if (Arrive[Run] < 0) AddError(FString::Printf(TEXT("run %d: the carry was lost at frame %d before the slot"), Run, F));
				break;   // past the slot the carrier runs into the crease back: the scene is over
			}
			if (Arrive[Run] < 0 && Sim->GetSkaters()[Me].Pos.X >= Gx - 8.0)
			{
				Arrive[Run] = F;
				Gap[Run] = Sim->GetSkaters()[Me].Pos.X - Sim->GetSkaters()[Chaser].Pos.X;
			}
			if (Arrive[Run] > 0 && F >= Arrive[Run] + 30) break;   // a little past the slot: still one burst per possession
		}
		AddInfo(FString::Printf(TEXT("%s: breakaway events %d (first at frame %d), the slot reached at frame %d, %.2f m ahead of the chaser, top speed seen %.2f m/s"),
			bBurst ? TEXT("burst on") : TEXT("speed_bonus 0"), Events[Run], FirstEvent, Arrive[Run], Gap[Run], Sim->GetSkaters()[Me].Vel.Size()));
		if (bBurst)
		{
			TestEqual(TEXT("one breakaway event per rush (A32's read-out or the burst, never both)"), Events[Run], 1);
			TestEqual(TEXT("the burst fires once the carry has settled (BreakawayCarryFrames + 1)"), FirstEvent, UJamSim::BreakawayCarryFrames + 1);
			TestEqual(TEXT("... and is counted"), Sim->GetSkaters()[Me].Breakaways, 1);
			TestTrue(TEXT("PastLastDefender reads true while carrying with the net ahead"), Sim->PastLastDefender(Me) || Sim->GetSkaters()[Me].Pos.X > Gx - UJamSim::BreakawayMinGoalM);
		}
		else
		{
			TestEqual(TEXT("speed_bonus 0: no burst (A32's read-out may still call the rush)"), Sim->GetSkaters()[Me].Breakaways, 0);
		}
	}
	TestTrue(TEXT("both runs reached the slot"), Arrive[0] > 0 && Arrive[1] > 0);
	if (Arrive[0] > 0 && Arrive[1] > 0)
	{
		// Lane A185 (R-0064 point 2): the chaser became a free skater 15 % faster and closed what the burst won (4 frames and 0.74 m at speed_bonus 0.2).
		// Lane A194 (track F2 evolution 10): speed_bonus 0.3 (0.92 x 1.3 = 1.196 > 1.15): the bars before lane A185 again, 8 frames and 1.5 m.
		TestTrue(*FString::Printf(TEXT("the burst reaches the slot earlier (%d vs %d frames, need 8 fewer)"), Arrive[0], Arrive[1]), Arrive[0] <= Arrive[1] - 8);
		TestTrue(*FString::Printf(TEXT("... and farther ahead of the chaser (%.2f vs %.2f m, need 1.5 more)"), Gap[0], Gap[1]), Gap[0] >= Gap[1] + 1.5);
	}
	return true;
}

// Deke: against the brain's crease back, the puck moves a metre to the side, a second tap does nothing, and the shot at the open post scores in 2 of 3 seeds.
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamPayoffDeke, "Jam.Core.Payoffs.Deke", JamPayoffTests::Flags)
bool FJamPayoffDeke::RunTest(const FString& Parameters)
{
	using namespace JamPayoffTests;
	UJamCartridge* C = LoadPreset(*this, TEXT("hockey.regular"));
	if (!C) return false;
	const FJamGameConfig& G = C->Game;
	int32 DekeGoals = 0, ControlGoals = 0, DekeEvents = 0, Seeds = 0;
	double MinLateral = 1e9;
	for (const uint64 Seed : { 1ull, 2ull, 3ull })
	{
		const double Y0 = static_cast<double>(Seed) - 2.0;   // -1, 0, +1: the approach line
		for (const bool bDeke : { true, false })
		{
			FPayoffScene Sc(*C, G, Seed, TEXT("pro"));
			UJamSim* Sim = Sc.Sim;
			const double Gx = Sim->GoalLineX();
			const int32 Me = Sim->GetHumanIndex();
			const int32 Mate = FindRole(Sim, 0, TEXT("chaser"));
			const int32 OwnBack = FindRole(Sim, 0, TEXT("back"));
			const int32 Chaser = FindRole(Sim, 1, TEXT("chaser"));
			const int32 Support = FindRole(Sim, 1, TEXT("support"));
			const int32 Back = FindRole(Sim, 1, TEXT("back"));
			Sc.ScriptAll();
			Sc.bScripted[Back] = false;   // the brain's last man: holds the crease squared to the carrier, blade on the puck
			Sim->SetSkater(Mate, FVector2D(-30, 10), FVector2D::ZeroVector, 0);
			Sim->SetSkater(OwnBack, FVector2D(-30, -10), FVector2D::ZeroVector, 0);
			Sim->SetSkater(Chaser, FVector2D(-30, 0), FVector2D::ZeroVector, UE_DOUBLE_PI);
			Sim->SetSkater(Support, FVector2D(-30, -5), FVector2D::ZeroVector, UE_DOUBLE_PI);
			Sim->SetSkater(Back, FVector2D(Gx - 1.5, Y0 * 0.2), FVector2D::ZeroVector, UE_DOUBLE_PI);
			Sim->SetSkater(Me, FVector2D(Gx - 14, Y0), FVector2D(5, 0), 0);
			Sc.GivePuck(Me);
			int32 T = -1, ShotFrame = -1;
			bool bGoal = false;
			double Lateral = -1;
			int32 Dekes = 0;
			FVector2D PuckAtShot = FVector2D::ZeroVector, BackAtShot = FVector2D::ZeroVector;   // A55: C4701, printed below even when no shot came
			for (int32 F = 1; F <= 300; ++F)
			{
				JamAI::FJamAIInput H = Move(0.5, 0);   // a half stick: 5.5 m/s at the net
				const double Dgoal = FMath::Abs(Gx - Sim->GetPuck().Pos.X);
				if (T < 0 && Dgoal <= 8.5) { T = F; if (bDeke) H.bDeke = true; }
				if (T > 0 && F == T + 10 && bDeke) H.bDeke = true;   // the second tap inside the lockout: must do nothing
				if (T > 0 && F == T + 8) H.bShoot = true;
				Sc.Step({ { Me, H } });
				Dekes += Count(Sim, JamEvents::Deke, Me);
				if (T > 0 && F == T + 6)
				{
					const FJamSkaterState& S = Sim->GetSkaters()[Me];
					const FVector2D Fwd = S.Forward();
					const FVector2D Rel = Sim->GetPuck().Pos - S.Pos;
					Lateral = FMath::Abs(Fwd.X * Rel.Y - Fwd.Y * Rel.X);
				}
				for (const FJamSimEvent& E : Sim->GetFrameEvents())
				{
					if (E.Name == JamEvents::Shot && E.Who == Me) { ShotFrame = F; PuckAtShot = Sim->GetPuck().Pos; BackAtShot = Sim->GetSkaters()[Back].Pos; }
					if (E.Name == JamEvents::Goal && ShotFrame > 0) bGoal = true;
				}
				if (bGoal || (ShotFrame > 0 && F > ShotFrame + 90)) break;
			}
			AddInfo(FString::Printf(TEXT("seed %llu %s: deke at frame %d (events %d, puck %.2f m off the body line at +6), shot at %d from (%.1f, %.1f) with the back at (%.1f, %.1f): goal %d"),
				Seed, bDeke ? TEXT("deke") : TEXT("no deke"), T, Dekes, Lateral, ShotFrame, PuckAtShot.X, PuckAtShot.Y, BackAtShot.X, BackAtShot.Y, bGoal ? 1 : 0));
			if (bDeke)
			{
				++Seeds;
				DekeEvents += Dekes;
				if (Lateral >= 0) MinLateral = FMath::Min(MinLateral, Lateral);
				if (bGoal) ++DekeGoals;
				TestEqual(TEXT("the deke is counted once"), Sim->GetSkaters()[Me].Dekes, 1);
			}
			else if (bGoal) ++ControlGoals;
		}
	}
	TestEqual(TEXT("one deke event per seed: the second tap inside 30 frames does nothing"), DekeEvents, Seeds);
	TestTrue(*FString::Printf(TEXT("the puck moves at least 0.8 m to the side within 6 frames (min %.2f)"), MinLateral), MinLateral >= 0.8);
	TestTrue(*FString::Printf(TEXT("the deke opens the far side in 2 of 3 seeds (%d; without the deke %d)"), DekeGoals, ControlGoals), DekeGoals >= 2);
	TestTrue(TEXT("the same shot without the deke is saved more often"), DekeGoals > ControlGoals);
	return true;
}

// EmptyNetScript: the Jam.Core.Seams scene (a scripted attacker alone against an empty net at skater speed 13) scores with the burst on as it does with it off.
// The first cut of the burst fired on the touch and the 15.6 m/s attacker outran its own 17.8 m/s tap, turned after the puck and carried it to its own end for
// the rest of the match; the burst now needs BreakawayCarryFrames of carry.
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamPayoffEmptyNetScript, "Jam.Core.Payoffs.EmptyNetScript", JamPayoffTests::Flags)
bool FJamPayoffEmptyNetScript::RunTest(const FString& Parameters)
{
	using namespace JamPayoffTests;
	UJamCartridge* C = LoadPreset(*this, TEXT("hockey.regular"));
	if (!C) return false;
	for (const bool bBurst : { true, false })
	{
		FJamGameConfig G = C->Game;
		G.Skater.Speed = 13.0;   // Jam.Core.Seams section 3: SetParam skater_speed 13 at frame 10
		if (!bBurst) G.Skater.BreakawaySpeedBonus = 0.0;
		UJamSim* Sim = NewObject<UJamSim>();
		Sim->Init(G, 1);
		Sim->SkipFaceoff();
		const int32 Me = Sim->GetHumanIndex();
		for (const FJamSkaterState& S : Sim->GetSkaters())
			if (S.Index != Me) Sim->SetSkater(S.Index, FVector2D(-30.0 + S.Index * 6.0, S.Index % 2 ? 18.0 : -18.0), FVector2D::ZeroVector, 0);
		TArray<FJamInput> Inputs;
		Inputs.SetNum(Sim->GetSkaters().Num());
		int32 GoalFrame = -1, Shots = 0, Bursts = 0;
		FString Trace;
		for (int32 F = 0; F < 1800 && GoalFrame < 0; ++F)
		{
			const FJamSkaterState& S = Sim->GetSkaters()[Me];
			const FVector2D Puck = Sim->GetPuck().Pos;
			const FVector2D Goal(Sim->AttackGoalX(S.Team), 0.0);
			const FVector2D ToGoal = (Goal - Puck).GetSafeNormal();
			const FVector2D Behind = Puck - ToGoal * 0.7;
			FJamInput In;
			const FVector2D D = Behind - S.Pos;
			In.Move = D.Size() > 0.3 ? D.GetSafeNormal() : ToGoal;
			const FVector2D ToPuck = Puck - S.Pos;
			const double Dist = ToPuck.Size();
			const FVector2D Fwd = S.Forward();
			if (Dist < G.Shot.ReachM && FVector2D::DotProduct(Fwd, ToGoal) > 0.97 && FVector2D::DotProduct(Fwd, ToPuck / FMath::Max(Dist, 1e-6)) > 0.6) In.bShoot = true;
			Inputs[Me] = In;
			Sim->Step(Inputs);
			for (const FJamSimEvent& E : Sim->GetFrameEvents())
			{
				if (E.Name == JamEvents::Goal) GoalFrame = F;
				if (E.Name == JamEvents::Shot && E.Who == Me) { ++Shots; Trace += FString::Printf(TEXT(" shot@%d(%.1f,%.1f v%.1f)"), F, Puck.X, Puck.Y, Sim->GetPuck().Vel.Size()); }
				if (E.Name == JamEvents::Breakaway && E.Who == Me) { ++Bursts; Trace += FString::Printf(TEXT(" burst@%d(x%.1f)"), F, S.Pos.X); }
			}
			if (F % 120 == 0) Trace += FString::Printf(TEXT(" f%d:me(%.1f,%.1f v%.1f y%.2f) puck(%.1f,%.1f v%.1f) c%d"), F, S.Pos.X, S.Pos.Y, S.Vel.Size(), S.Yaw, Puck.X, Puck.Y, Sim->GetPuck().Vel.Size(), Sim->CarrierIndex());
		}
		AddInfo(FString::Printf(TEXT("%s: goal at %d, shots %d, bursts %d;%s"), bBurst ? TEXT("burst on") : TEXT("burst off"), GoalFrame, Shots, Bursts, *Trace));
		TestTrue(*FString::Printf(TEXT("the scripted attacker scores against the empty net (%s)"), bBurst ? TEXT("burst on") : TEXT("burst off")), GoalFrame > 0 && GoalFrame < 600);
	}
	return true;
}

#endif
