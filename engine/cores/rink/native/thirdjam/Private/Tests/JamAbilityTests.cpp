// Lane A84 (R-0041 point 3): the abilities on F. Jam.Core.Abilities.*: a cartridge's game.abilities[] grants the human one ability (mode: from the drop, a cooldown;
// pickup: a boost take, held until its charges are spent), F (FJamInput::bAbility) uses it, and the four rules each in a scripted scene against a control without
// the ability: shotgun (1.5x shot speed, every skater within 1 m of the path down, the puck through the crowd), hip check (lands from a standstill, 1.5x knockdown
// frames, a 3 m push), shield (checks and lifts on the holder fail for 6 s, the body still bumps), slow puck (half speed for 2 s, then it wakes up). None when unnamed:
// a cartridge without the key hashes the same with F held every frame. Headless scenes on UJamSim (no brain). docs/experiments/ABILITIES.md.
//   UnrealEditor-Cmd.exe Game/ThirdJam.uproject -ExecCmds="Automation RunTests Jam.Core.Abilities; Quit" -unattended -nullrhi -nosplash -log
#include "Misc/AutomationTest.h"
#include "JamCartridge.h"
#include "JamSim.h"
#include "JamEventBus.h"

#if WITH_DEV_AUTOMATION_TESTS

namespace JamAbilityTests
{
	constexpr EAutomationTestFlags Flags = EAutomationTestFlags_ApplicationContextMask | EAutomationTestFlags::ProductFilter;

	UJamCartridge* LoadPreset(FAutomationTestBase& T, const FString& Name)
	{
		TArray<FString> Errors;
		UJamCartridge* C = UJamCartridge::LoadFromFile(UJamCartridge::ResolveCartridgePath(Name), Errors);
		for (const FString& E : Errors) T.AddError(FString::Printf(TEXT("%s: %s"), *Name, *E));
		return C;
	}

	FJamAbilityConfig Ab(const TCHAR* Kind, const TCHAR* Trigger, int32 Charges = 0, int32 Cooldown = 0, int32 Duration = 0, double Magnitude = 0)
	{
		FJamAbilityConfig A;
		A.Kind = Kind;
		A.Trigger = Trigger;
		A.Charges = Charges;
		A.CooldownFrames = Cooldown;
		A.DurationFrames = Duration;
		A.Magnitude = Magnitude;
		return A;
	}

	FJamGameConfig With(const FJamGameConfig& G, std::initializer_list<FJamAbilityConfig> List)
	{
		FJamGameConfig Out = G;
		Out.Abilities.Reset();
		for (const FJamAbilityConfig& A : List) Out.Abilities.Add(A);
		return Out;
	}

	int32 Count(const UJamSim* Sim, FName Event, FName Kind = NAME_None, int32 Who = -2)
	{
		int32 N = 0;
		for (const FJamSimEvent& E : Sim->GetFrameEvents())
			if (E.Name == Event && (Kind.IsNone() || E.Kind == Kind) && (Who == -2 || E.Who == Who)) ++N;
		return N;
	}

	// The human (team 0) at Origin facing the goal it attacks, every other skater parked along the far board; the puck on the human's blade when bPuck.
	struct FAbilityScene
	{
		UJamSim* Sim = nullptr;
		int32 Me = -1;
		double Dir = 1.0;
		TArray<int32> Mates, Opps;
		TArray<FJamInput> In;

		FAbilityScene(const FJamGameConfig& G, const FVector2D& Origin, bool bPuck)
		{
			Sim = NewObject<UJamSim>();
			Sim->Init(G, 1);
			Sim->SkipFaceoff();
			Me = Sim->GetHumanIndex();
			Dir = Sim->AttackGoalX(0) > 0 ? 1.0 : -1.0;
			for (const FJamSkaterState& S : Sim->GetSkaters())
			{
				if (S.Index == Me) continue;
				(S.Team == 0 ? Mates : Opps).Add(S.Index);
				Park(S.Index);
			}
			Sim->SetSkater(Me, Origin, FVector2D::ZeroVector, Dir > 0 ? 0.0 : PI);
			In.SetNum(Sim->GetSkaters().Num());
			if (bPuck)
			{
				In[Me].Stick = FVector2D(Dir, 0.0) * 0.5;
				Sim->SetPuck(Origin + FVector2D(Dir * 0.45, 0.0), FVector2D::ZeroVector);
				for (int32 i = 0; i < 6; ++i) Sim->Step(In);
			}
		}
		void Park(int32 Who) { Sim->SetSkater(Who, FVector2D(-30.0 + Who * 2.5, 20.0), FVector2D::ZeroVector, 0); }
		void Step() { Sim->Step(In); }
		void Press(bool FJamInput::* Field, int32 Who = -1) { In[Who < 0 ? Me : Who].*Field = true; Step(); In[Who < 0 ? Me : Who].*Field = false; }
		const FJamSkaterState& S(int32 i) const { return Sim->GetSkaters()[i]; }
		const FJamSkaterState& Human() const { return S(Me); }
	};

	FString HashOf(const FJamGameConfig& G, bool bF)
	{
		UJamSim* Sim = NewObject<UJamSim>();
		Sim->Init(G, 1);
		TArray<FJamInput> In;
		In.SetNum(Sim->GetSkaters().Num());
		for (int32 f = 0; f < 600; ++f)
		{
			In[Sim->GetHumanIndex()].bAbility = bF && (f % 3 == 0);
			In[Sim->GetHumanIndex()].Move = FVector2D(1, 0);
			Sim->Step(In);
		}
		return Sim->StateHashHex();
	}
}

using namespace JamAbilityTests;

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamAbilitiesNone, "Jam.Core.Abilities.None", JamAbilityTests::Flags)
bool FJamAbilitiesNone::RunTest(const FString& Parameters)
{
	// Every shipped preset outside the two ability modes names no ability: nobody holds one, and F every third frame changes nothing (same hash at frame 600).
	for (const TCHAR* Preset : { TEXT("hockey.regular"), TEXT("hockey.raw"), TEXT("hockey.boost"), TEXT("modes/hockey.mode.bruisers") })
	{
		UJamCartridge* C = LoadPreset(*this, Preset);
		if (!C) continue;
		TestEqual(*FString::Printf(TEXT("%s names no ability"), Preset), C->Game.Abilities.Num(), 0);
		UJamSim* Sim = NewObject<UJamSim>();
		Sim->Init(C->Game, 1);
		for (const FJamSkaterState& S : Sim->GetSkaters()) TestEqual(*FString::Printf(TEXT("%s: skater %d holds nothing"), Preset, S.Index), S.AbilitySlot, -1);
		const FString A = HashOf(C->Game, false), B = HashOf(C->Game, true);
		TestEqual(*FString::Printf(TEXT("%s: F pressed changes nothing (frame 600 hash)"), Preset), B, A);
		AddInfo(FString::Printf(TEXT("%s frame 600 hash with and without F: %s"), Preset, *A));
	}
	return true;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamAbilitiesGrantUseCooldown, "Jam.Core.Abilities.GrantUseCooldown", JamAbilityTests::Flags)
bool FJamAbilitiesGrantUseCooldown::RunTest(const FString& Parameters)
{
	UJamCartridge* C = LoadPreset(*this, TEXT("hockey.regular"));
	if (!C) return false;
	// A mode shield: held from the drop by the human only; F uses it (event `ability` Strength 1), the cooldown refuses a second press, it comes back after.
	{
		FAbilityScene Sc(With(C->Game, { Ab(TEXT("shield"), TEXT("mode"), 0, 300, 60) }), FVector2D(0, 0), false);
		for (const FJamSkaterState& S : Sc.Sim->GetSkaters()) TestEqual(*FString::Printf(TEXT("mode grant: skater %d"), S.Index), S.AbilitySlot, S.bHuman ? 0 : -1);
		TestEqual(TEXT("mode grant: unlimited charges"), Sc.Human().AbilityCharges, -1);
		Sc.Press(&FJamInput::bAbility);
		TestEqual(TEXT("use: one ability event, strength 1"), Count(Sc.Sim, JamEvents::Ability, TEXT("shield"), Sc.Me), 1);
		TestTrue(TEXT("use: the shield runs (duration 60, one frame spent at most)"), Sc.Human().ShieldFrames >= 59 && Sc.Human().ShieldFrames <= 60);
		TestEqual(TEXT("use: cooldown set"), Sc.Human().AbilityReadyFrame, Sc.Sim->GetFrame() + 300);
		for (int32 f = 0; f < 100; ++f) Sc.Step();
		Sc.Press(&FJamInput::bAbility);
		TestEqual(TEXT("cooldown: a second press inside it does nothing"), Sc.Human().AbilitiesUsed, 1);
		while (Sc.Sim->GetFrame() < Sc.Human().AbilityReadyFrame) Sc.Step();
		Sc.Press(&FJamInput::bAbility);
		TestEqual(TEXT("cooldown: usable again after it"), Sc.Human().AbilitiesUsed, 2);
		TestEqual(TEXT("mode: still held"), Sc.Human().AbilitySlot, 0);
	}
	// Charges: a mode with charges 1 empties the slot on its use.
	{
		FAbilityScene Sc(With(C->Game, { Ab(TEXT("shield"), TEXT("mode"), 1) }), FVector2D(0, 0), false);
		Sc.Press(&FJamInput::bAbility);
		TestEqual(TEXT("charges 1: used once"), Sc.Human().AbilitiesUsed, 1);
		TestEqual(TEXT("charges 1: the slot is empty"), Sc.Human().AbilitySlot, -1);
		TestTrue(TEXT("defaults: shield 360 frames (one spent at most)"), Sc.Human().ShieldFrames >= 359 && Sc.Human().ShieldFrames <= 360);
	}
	// Pickup: a human's boost take grants one of the pickup entries (charges 1); a bot's take grants nothing; nothing while one is held.
	{
		FAbilityScene Sc(With(C->Game, { Ab(TEXT("slow_puck"), TEXT("pickup")), Ab(TEXT("hip_check"), TEXT("pickup")) }), FVector2D(0, 0), false);
		TestEqual(TEXT("pickup: nothing at the drop"), Sc.Human().AbilitySlot, -1);
		Sc.Sim->NotifyPickupTaken(Sc.Opps[0], TEXT("speed"));
		TestEqual(TEXT("pickup: a bot's take grants nothing"), Sc.S(Sc.Opps[0]).AbilitySlot, -1);
		Sc.Sim->NotifyPickupTaken(Sc.Me, TEXT("speed"));
		const int32 Slot = Sc.Human().AbilitySlot;
		TestTrue(TEXT("pickup: the human's take grants one of the pool"), Slot == 0 || Slot == 1);
		TestEqual(TEXT("pickup: one charge"), Sc.Human().AbilityCharges, 1);
		Sc.Step();
		Sc.Sim->NotifyPickupTaken(Sc.Me, TEXT("speed"));
		TestEqual(TEXT("pickup: a second take while holding changes nothing"), Sc.Human().AbilitySlot, Slot);
		// Over many frames both entries come up (the pick is the frame's, deterministic).
		TSet<int32> Seen;
		for (int32 f = 0; f < 40; ++f)
		{
			FAbilityScene P(With(C->Game, { Ab(TEXT("slow_puck"), TEXT("pickup")), Ab(TEXT("hip_check"), TEXT("pickup")) }), FVector2D(0, 0), false);
			for (int32 k = 0; k < f; ++k) P.Step();
			P.Sim->NotifyPickupTaken(P.Me, TEXT("speed"));
			Seen.Add(P.Human().AbilitySlot);
		}
		TestEqual(TEXT("pickup: both entries granted over 40 take frames"), Seen.Num(), 2);
	}
	// Restart: the mode ability comes back fresh; the cartridge files load with their abilities.
	{
		FAbilityScene Sc(With(C->Game, { Ab(TEXT("shield"), TEXT("mode"), 1) }), FVector2D(0, 0), false);
		Sc.Press(&FJamInput::bAbility);
		Sc.Sim->Restart();
		TestEqual(TEXT("restart: held again"), Sc.Human().AbilitySlot, 0);
		TestEqual(TEXT("restart: used 0"), Sc.Human().AbilitiesUsed, 0);
	}
	if (UJamCartridge* S = LoadPreset(*this, TEXT("modes/hockey.mode.shotgun")))
	{
		TestEqual(TEXT("shotgun mode: one ability"), S->Game.Abilities.Num(), 1);
		if (S->Game.Abilities.Num() == 1) { TestEqual(TEXT("shotgun mode: kind"), S->Game.Abilities[0].Kind, FName(TEXT("shotgun"))); TestEqual(TEXT("shotgun mode: 20 s"), S->Game.Abilities[0].CooldownFrames, 1200); }
	}
	if (UJamCartridge* A = LoadPreset(*this, TEXT("modes/hockey.mode.arsenal")))
	{
		TestEqual(TEXT("arsenal mode: four pickup abilities"), A->Game.Abilities.Num(), 4);
		for (const FJamAbilityConfig& X : A->Game.Abilities) TestEqual(TEXT("arsenal: pickup trigger"), X.Trigger, FName(TEXT("pickup")));
		TestTrue(TEXT("arsenal: has pickups"), A->Game.Pickups.Num() > 0);
	}
	return true;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamAbilitiesShotgun, "Jam.Core.Abilities.Shotgun", JamAbilityTests::Flags)
bool FJamAbilitiesShotgun::RunTest(const FString& Parameters)
{
	UJamCartridge* C = LoadPreset(*this, TEXT("hockey.regular"));
	if (!C) return false;
	// The human at x = -20 with the puck, facing the far net; three opponents standing on the line at 5, 10 and 15 m (0.0, +0.6 and -0.6 m off it).
	// With F: the shot leaves 1.5x as fast, all three go down (cause shotgun) and the puck passes x = -2; without: the first body stops the shot.
	// Lane A113 (R-0051 point 3): Graced = the opponent (0 to 2) inside its release grace: the shotgun passes it over as it does a shielded skater.
	struct FOut { double Speed = 0; int32 Down = 0, Shotgun = 0; double MaxX = -100; bool bDown[3] = { false, false, false }; int32 GraceLeft = 0; };
	auto Run = [&](bool bAbility, int32 Graced = -1)
	{
		FAbilityScene Sc(With(C->Game, { Ab(TEXT("shotgun"), TEXT("mode")) }), FVector2D(-20, 0), true);
		const double D = Sc.Dir;
		TestEqual(TEXT("team 0 attacks +x"), D, 1.0);
		const double Off[3] = { 0.0, 0.6, -0.6 };
		for (int32 k = 0; k < 3 && k < Sc.Opps.Num(); ++k) Sc.Sim->SetSkater(Sc.Opps[k], FVector2D(-20 + D * (5.0 * (k + 1)), Off[k]), FVector2D::ZeroVector, D > 0 ? PI : 0.0);
		FOut O;
		if (Graced >= 0 && Graced < Sc.Opps.Num()) const_cast<FJamSkaterState&>(Sc.Sim->GetSkaters()[Sc.Opps[Graced]]).GraceFrames = 200;   // test only: just released
		Sc.Press(bAbility ? &FJamInput::bAbility : &FJamInput::bShoot);
		O.Speed = Sc.Sim->GetPuck().Vel.Size();
		O.Shotgun += Count(Sc.Sim, JamEvents::Knockdown, TEXT("shotgun"));
		for (int32 f = 0; f < 60; ++f)
		{
			Sc.Step();
			O.Shotgun += Count(Sc.Sim, JamEvents::Knockdown, TEXT("shotgun"));
			O.MaxX = FMath::Max(O.MaxX, Sc.Sim->GetPuck().Pos.X * D);
		}
		for (int32 k = 0; k < 3 && k < Sc.Opps.Num(); ++k) if (Sc.S(Sc.Opps[k]).IsDown()) { ++O.Down; O.bDown[k] = true; }
		if (Graced >= 0 && Graced < Sc.Opps.Num()) O.GraceLeft = Sc.Sim->GetSkaters()[Sc.Opps[Graced]].GraceFrames;
		AddInfo(FString::Printf(TEXT("shotgun %d: speed %.2f m/s, down %d, shotgun knockdowns %d, puck reached x %.1f, used %d"), bAbility ? 1 : 0, O.Speed, O.Down, O.Shotgun, O.MaxX * D, Sc.Human().AbilitiesUsed));
		return O;
	};
	const FOut Plain = Run(false), Gun = Run(true);
	TestTrue(TEXT("plain shot leaves"), Plain.Speed > 5.0);
	TestTrue(TEXT("shotgun leaves at 1.5x the plain shot (within 2 %)"), FMath::Abs(Gun.Speed - 1.5 * Plain.Speed) <= 0.02 * 1.5 * Plain.Speed);
	TestEqual(TEXT("shotgun: all three on the path go down"), Gun.Down, 3);
	TestEqual(TEXT("shotgun: three knockdown events, cause shotgun"), Gun.Shotgun, 3);
	TestTrue(TEXT("shotgun: the puck goes through the crowd (past the third body at x -5)"), Gun.MaxX > -4.0);
	TestEqual(TEXT("plain: nobody knocked down"), Plain.Down, 0);
	// Lane A113 (R-0051 point 3): the third skater on the path was released a moment ago: the two before it go down, it stays up.
	const FOut Grace = Run(true, 2);
	AddInfo(FString::Printf(TEXT("shotgun, the third skater inside its grace: down %d %d %d, shotgun knockdowns %d, grace left %d"), Grace.bDown[0] ? 1 : 0, Grace.bDown[1] ? 1 : 0, Grace.bDown[2] ? 1 : 0, Grace.Shotgun, Grace.GraceLeft));
	TestTrue(TEXT("shotgun, the third skater inside its release grace: the two before it go down"), Grace.bDown[0] && Grace.bDown[1] && Grace.Shotgun == 2);
	TestTrue(TEXT("... and the skater inside its grace stays up, its grace still running"), !Grace.bDown[2] && Grace.GraceLeft > 0);
	TestTrue(TEXT("plain: the first body stops it short of the second"), Plain.MaxX < -20 + 10.0 - 0.3);
	return true;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamAbilitiesHipCheck, "Jam.Core.Abilities.HipCheck", JamAbilityTests::Flags)
bool FJamAbilitiesHipCheck::RunTest(const FString& Parameters)
{
	UJamCartridge* C = LoadPreset(*this, TEXT("hockey.regular"));
	if (!C) return false;
	// The human gliding at 0.5 m/s into an opponent standing 0.85 m ahead (penalties off: a check on a skater without the puck would send the human to the box).
	// A plain check press does not land (0.5 m/s of own speed is under the human's 2 m/s); the hip check (F) lands: strength 1, 1.5x knockdown frames, and the
	// opponent slides about 3 m (HipCheckPushM) from where it stood.
	FJamGameConfig G = With(C->Game, { Ab(TEXT("hip_check"), TEXT("mode")) });
	G.Rules.bPenalties = false;
	struct FOut { bool bDown = false; int32 Frames = 0; double Slide = 0; float Strength = -1; };
	auto Run = [&](bool bHip)
	{
		FAbilityScene Sc(G, FVector2D(0, 0), false);
		const double D = Sc.Dir;
		const int32 V = Sc.Opps[0];
		const FVector2D Start(D * 0.85, 0.0);
		Sc.Sim->SetSkater(Sc.Me, FVector2D(0, 0), FVector2D(D * 0.5, 0.0), D > 0 ? 0.0 : PI);
		Sc.Sim->SetSkater(V, Start, FVector2D::ZeroVector, D > 0 ? PI : 0.0);
		FOut O;
		Sc.In[Sc.Me].bAbility = bHip;
		Sc.In[Sc.Me].bCheck = !bHip;
		for (int32 f = 0; f < 240; ++f)
		{
			Sc.Step();
			Sc.In[Sc.Me].bAbility = Sc.In[Sc.Me].bCheck = false;
			for (const FJamSimEvent& E : Sc.Sim->GetFrameEvents()) if (E.Name == JamEvents::Check && E.Who == Sc.Me) O.Strength = E.Strength;
			if (!O.bDown && Sc.S(V).IsDown()) { O.bDown = true; O.Frames = Sc.S(V).KnockFrames; }
		}
		O.Slide = (Sc.S(V).Pos - Start).Size();
		AddInfo(FString::Printf(TEXT("hip %d: down %d for %d frames, strength %.2f, victim %.2f m from where it stood"), bHip ? 1 : 0, O.bDown ? 1 : 0, O.Frames, O.Strength, O.Slide));
		return O;
	};
	const FOut Plain = Run(false), Hip = Run(true);
	TestFalse(TEXT("plain check from a standstill does not land"), Plain.bDown);
	TestTrue(TEXT("hip check lands from a standstill"), Hip.bDown);
	TestEqual(TEXT("hip check: strength 1"), Hip.Strength, 1.f);
	const int32 Base = C->Game.Skater.KnockdownFrames;
	TestTrue(TEXT("hip check: 1.5x knockdown frames"), FMath::Abs(Hip.Frames - FMath::RoundToInt32(Base * 1.5)) <= 1);
	TestTrue(TEXT("hip check: a push of about 3 m (2.6..3.8 m from where it stood)"), Hip.Slide >= 2.6 && Hip.Slide <= 3.8);
	return true;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamAbilitiesShield, "Jam.Core.Abilities.Shield", JamAbilityTests::Flags)
bool FJamAbilitiesShield::RunTest(const FString& Parameters)
{
	UJamCartridge* C = LoadPreset(*this, TEXT("hockey.regular"));
	if (!C) return false;
	// The human carries the puck standing still; an opponent charges at 7 m/s from 2 m pressing check. Unshielded: knocked down. Shielded (F): no knockdown, a bump.
	// Then a lift from 1 m beside the carrier: clean unshielded, a miss shielded; the shield ends after 360 frames.
	auto Check = [&](bool bShield, int32& OutBumps)
	{
		FAbilityScene Sc(With(C->Game, { Ab(TEXT("shield"), TEXT("mode")) }), FVector2D(0, 0), true);
		if (bShield) Sc.Press(&FJamInput::bAbility);
		const double D = Sc.Dir;
		const int32 O = Sc.Opps[0];
		// Lane A200: the window opens game.contact.bot_check_windup_frames after the press: the charger starts that much ground farther out (the same contact).
		const double Wu = Sc.Sim->GetConfig().Contact.CheckWindupFor(Sc.Sim->GetSkaters()[O].bHuman);
		Sc.Sim->SetSkater(O, FVector2D(D * (1.4 + 7.0 * Wu / 60.0), 0.0), FVector2D(-D * 7.0, 0.0), D > 0 ? PI : 0.0);
		Sc.In[O].bCheck = true;
		Sc.Step();
		Sc.In[O].bCheck = false;
		bool bDown = false;
		OutBumps = 0;
		// Lane A92 (R-0045): by momentum a 7 m/s check from the front on a standing carrier is a stumble that knocks the puck loose (ratio 0.9), not a knockdown;
		// "the check lands" is a stumble or a knockdown. Counted before the frame's bump read-out so the stumble's own hit reaction is not a "body bump".
		for (int32 f = 0; f < 30; ++f) { bDown |= Sc.Human().IsDown() || Sc.Human().ContactOutcome >= UJamSim::ContactStumble; OutBumps += Sc.Human().bBumpThisFrame ? 1 : 0; Sc.Step(); }
		return bDown;
	};
	int32 B0 = 0, B1 = 0;
	TestTrue(TEXT("unshielded: the check knocks the carrier down"), Check(false, B0));
	TestFalse(TEXT("shielded: the check fails"), Check(true, B1));
	TestTrue(TEXT("shielded: the body still bumps"), B1 >= 1);
	auto Lift = [&](bool bShield)
	{
		FAbilityScene Sc(With(C->Game, { Ab(TEXT("shield"), TEXT("mode")) }), FVector2D(0, 0), true);
		if (bShield) Sc.Press(&FJamInput::bAbility);
		const int32 O = Sc.Opps[0];
		Sc.Sim->SetSkater(O, FVector2D(0.0, 1.0), FVector2D::ZeroVector, -PI * 0.5);
		Sc.Press(&FJamInput::bLift, O);
		int32 Clean = Count(Sc.Sim, JamEvents::Lift, TEXT("clean"), O);
		return Clean;
	};
	TestEqual(TEXT("unshielded: the lift is clean"), Lift(false), 1);
	TestEqual(TEXT("shielded: the lift fails"), Lift(true), 0);
	{
		FAbilityScene Sc(With(C->Game, { Ab(TEXT("shield"), TEXT("mode")) }), FVector2D(0, 0), false);
		Sc.Press(&FJamInput::bAbility);
		for (int32 f = 0; f < 360; ++f) Sc.Step();
		TestEqual(TEXT("the shield ends after 6 s"), Sc.Human().ShieldFrames, 0);
	}
	AddInfo(FString::Printf(TEXT("shield: bumps while shielded %d, unshielded %d"), B1, B0));
	return true;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamAbilitiesSlowPuck, "Jam.Core.Abilities.SlowPuck", JamAbilityTests::Flags)
bool FJamAbilitiesSlowPuck::RunTest(const FString& Parameters)
{
	UJamCartridge* C = LoadPreset(*this, TEXT("hockey.regular"));
	if (!C) return false;
	// The human at x = -30 shooting up the empty ice. Armed slow puck (F, then the shot): the puck travels at half the plain shot's speed for 120 frames, then wakes up.
	auto Run = [&](bool bSlow, TArray<double>& Speeds)
	{
		FAbilityScene Sc(With(C->Game, { Ab(TEXT("slow_puck"), TEXT("mode")) }), FVector2D(-30, 0), true);
		if (bSlow) Sc.Press(&FJamInput::bAbility);
		TestEqual(TEXT("slow puck armed, not fired"), Sc.Human().AbilityArmed, bSlow ? FName(TEXT("slow_puck")) : FName(NAME_None));
		Sc.Press(&FJamInput::bShoot);
		Speeds.Reset();
		Speeds.Add(Sc.Sim->GetPuck().Vel.Size());
		for (int32 f = 0; f < 130; ++f) { Sc.Step(); Speeds.Add(Sc.Sim->GetPuck().Vel.Size()); }
		AddInfo(FString::Printf(TEXT("slow %d: speed at release %.2f, frame 60 %.2f, frame 117 %.2f, frame 121 %.2f, puck x %.1f"), bSlow ? 1 : 0, Speeds[0], Speeds[60], Speeds[117], Speeds[121], Sc.Sim->GetPuck().Pos.X));
	};
	TArray<double> P, S;
	Run(false, P);
	Run(true, S);
	TestTrue(TEXT("slow: half the speed at release (within 3 %)"), FMath::Abs(S[0] - 0.5 * P[0]) <= 0.03 * P[0]);
	TestTrue(TEXT("slow: still slower than the plain shot at frame 60"), S[60] < 0.75 * P[60]);
	TestTrue(TEXT("slow: wakes up after 120 frames (speed about doubles)"), S[121] > 1.7 * S[117]);
	return true;
}

// Lane A105 (track Q2): the slow puck's wake-up belongs to a puck in flight. Before the fix StepSlowPuck divided the puck's speed by slow_puck's magnitude after
// duration_frames whenever the shooter was still its last touch: the shooter who skated after its own slow puck and carried it again had the carried puck
// thrown ahead at twice the carrier's speed (out of the carry assist's 4 m/s), and a second plain shot or pass by the same skater inside the window was
// doubled in mid-flight. Now the shooter's carry or its next shot or pass spends the slow puck quietly.
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamAbilitiesSlowPuckRetaken, "Jam.Core.Abilities.SlowPuckRetaken", JamAbilityTests::Flags)
bool FJamAbilitiesSlowPuckRetaken::RunTest(const FString& Parameters)
{
	UJamCartridge* C = LoadPreset(*this, TEXT("hockey.regular"));
	if (!C) return false;
	const FJamGameConfig G = With(C->Game, { Ab(TEXT("slow_puck"), TEXT("mode")) });
	// (1) The human shoots a slow puck from x = -30, and 30 frames later it is put back on the puck at the puck's own speed, skating on with the stick forward
	// (the carry assist takes it). Through and past the 120 frames of the slow puck the puck must stay carried, riding at the carrier's speed.
	{
		FAbilityScene Sc(G, FVector2D(-30, 0), true);
		const double D = Sc.Dir;
		Sc.Press(&FJamInput::bAbility);
		Sc.Press(&FJamInput::bShoot);
		TestTrue(TEXT("retaken: the slow puck runs"), Sc.Sim->GetPuck().SlowFrames > 0);
		for (int32 f = 0; f < 30; ++f) Sc.Step();
		const FJamPuckState& P = Sc.Sim->GetPuck();
		const FVector2D PV = P.Vel;
		Sc.Sim->SetSkater(Sc.Me, P.Pos - FVector2D(D * 0.45, 0.0), FVector2D(PV.X, 0.0), D > 0 ? 0.0 : PI);
		Sc.In[Sc.Me].Move = FVector2D(D, 0.0);
		Sc.In[Sc.Me].Stick = FVector2D(D, 0.0) * 0.5;
		bool bAlwaysCarried = true;
		double WorstRel = 0.0;
		for (int32 f = 0; f < 120; ++f)
		{
			Sc.Step();
			if (f < 6) continue;   // the carry assist settles the puck on the blade
			const double Rel = (Sc.Sim->GetPuck().Vel - Sc.Human().Vel).Size();
			WorstRel = FMath::Max(WorstRel, Rel);
			bAlwaysCarried &= Sc.Sim->CarrierIndex() == Sc.Me;
		}
		AddInfo(FString::Printf(TEXT("retaken: carried throughout %d, worst puck-carrier speed difference %.2f m/s, slow frames left %d"), bAlwaysCarried ? 1 : 0, WorstRel, Sc.Sim->GetPuck().SlowFrames));
		TestTrue(TEXT("retaken: the shooter keeps its own slow puck through the wake-up"), bAlwaysCarried);
		TestTrue(TEXT("retaken: the puck rides at the carrier's speed (under 4 m/s apart)"), WorstRel < 4.0);
	}
	// (2) The same skater's next plain shot inside the window: no mid-flight doubling at frame 120 of the first.
	{
		FAbilityScene Sc(G, FVector2D(-30, 0), true);
		const double D = Sc.Dir;
		Sc.Press(&FJamInput::bAbility);
		Sc.Press(&FJamInput::bShoot);
		for (int32 f = 0; f < 40; ++f) Sc.Step();
		// Back on the puck (standing), wait out the shot cooldown, shoot plain.
		const FJamPuckState& P = Sc.Sim->GetPuck();
		Sc.Sim->SetSkater(Sc.Me, P.Pos - FVector2D(D * 0.45, 0.0), FVector2D::ZeroVector, D > 0 ? 0.0 : PI);
		Sc.Sim->SetPuck(P.Pos, FVector2D::ZeroVector);
		for (int32 f = 0; f < 30; ++f) Sc.Step();
		Sc.Press(&FJamInput::bShoot);
		TArray<double> Speeds;
		for (int32 f = 0; f < 80; ++f) { Speeds.Add(Sc.Sim->GetPuck().Vel.Size()); Sc.Step(); }
		double WorstJump = 0.0;
		for (int32 i = 1; i < Speeds.Num(); ++i) WorstJump = FMath::Max(WorstJump, Speeds[i] / FMath::Max(1e-6, Speeds[i - 1]));
		AddInfo(FString::Printf(TEXT("second shot: release %.2f m/s, worst frame-to-frame speed ratio %.2f"), Speeds[0], WorstJump));
		TestTrue(TEXT("second shot: never sped up in flight (frame-to-frame ratio under 1.05)"), WorstJump < 1.05);
	}
	return true;
}

// Lane A105 (track Q2): a hip check in a cartridge whose body checks are off (skater.check_enabled false) could arm and never fire: both of its landing
// sites sit behind check_enabled, so F spent the charge, the slot stayed held for the match and a pickup slot never emptied (no further pickup granted).
// Now F refuses it there (nothing spent) and a pickup draw passes it over.
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamAbilitiesHipCheckNoChecks, "Jam.Core.Abilities.HipCheckNoChecks", JamAbilityTests::Flags)
bool FJamAbilitiesHipCheckNoChecks::RunTest(const FString& Parameters)
{
	UJamCartridge* C = LoadPreset(*this, TEXT("hockey.regular"));
	if (!C) return false;
	FJamGameConfig G = With(C->Game, { Ab(TEXT("hip_check"), TEXT("mode"), 2) });
	G.Skater.bCheckEnabled = false;
	FAbilityScene Sc(G, FVector2D(0, 0), false);
	TestEqual(TEXT("granted from the drop"), Sc.Human().AbilitySlot, 0);
	Sc.Press(&FJamInput::bAbility);
	TestTrue(TEXT("checks off: F does not arm a hip check"), Sc.Human().AbilityArmed.IsNone());
	TestEqual(TEXT("checks off: no charge spent"), Sc.Human().AbilityCharges, 2);
	TestEqual(TEXT("checks off: no use counted"), Sc.Human().AbilitiesUsed, 0);
	return true;
}

#endif
