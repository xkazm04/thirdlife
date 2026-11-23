// Lane A16 (R-0013): the stick and the faceoff. Jam.Core.Stick: countdown and draw (early mover loses), poke takes cleanly / stumbles on a miss,
// stick lift strips, a foul sends the checker to the box and the faceoff to its end, carry assist holds a gentle turn and loses a hard one. Headless.
//   UnrealEditor-Cmd.exe Game/ThirdJam.uproject -ExecCmds="Automation RunTests Jam.Core.Stick; Quit" -unattended -nullrhi -nosplash -log
#include "Misc/AutomationTest.h"
#include "JamCartridge.h"
#include "JamSim.h"
#include "JamEventBus.h"
#include "JamPawns.h"

#if WITH_DEV_AUTOMATION_TESTS

namespace JamStickTests
{
	constexpr EAutomationTestFlags Flags = EAutomationTestFlags_ApplicationContextMask | EAutomationTestFlags::ProductFilter;

	UJamCartridge* LoadPreset(FAutomationTestBase& T, const FString& Name)
	{
		TArray<FString> Errors;
		UJamCartridge* C = UJamCartridge::LoadFromFile(UJamCartridge::ResolveCartridgePath(Name), Errors);
		for (const FString& E : Errors) T.AddError(FString::Printf(TEXT("%s: %s"), *Name, *E));
		return C;
	}

	UJamSim* MakeSim(const FJamGameConfig& Config, uint64 Seed, bool bSkip)
	{
		UJamSim* Sim = NewObject<UJamSim>();
		Sim->Init(Config, Seed);
		if (bSkip) Sim->SkipFaceoff();
		return Sim;
	}

	// Everyone but the named skaters to the far corner, still.
	void Park(UJamSim* Sim, const TArray<int32>& Keep)
	{
		for (const FJamSkaterState& S : Sim->GetSkaters())
		{
			if (Keep.Contains(S.Index)) continue;
			Sim->SetSkater(S.Index, FVector2D(-35.0 + S.Index * 2.0, 18.0), FVector2D::ZeroVector, 0);
		}
	}

	int32 FirstOpponent(const UJamSim* Sim, int32 Me)
	{
		for (const FJamSkaterState& S : Sim->GetSkaters()) if (S.Team != Sim->GetSkaters()[Me].Team && !S.bHuman) return S.Index;
		return -1;
	}

	int32 CountEvents(const UJamSim* Sim, FName Name, FName Kind, int32 Who = -2)
	{
		int32 N = 0;
		for (const FJamSimEvent& E : Sim->GetFrameEvents()) if (E.Name == Name && (Kind.IsNone() || E.Kind == Kind) && (Who == -2 || E.Who == Who)) ++N;
		return N;
	}

	// Gives skater O the puck: the puck inside its reach, touched once.
	void GivePuck(UJamSim* Sim, int32 O)
	{
		const FJamSkaterState& S = Sim->GetSkaters()[O];
		Sim->SetPuck(S.Pos + S.Forward() * 0.45, FVector2D::ZeroVector);
		TArray<FJamInput> None;
		None.SetNum(Sim->GetSkaters().Num());
		Sim->Step(None);
	}

// The test stays inside the namespace (no using-directive): unity builds merge files, and a file-scope using would make LoadPreset ambiguous elsewhere.
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamStick, "Jam.Core.Stick", JamStickTests::Flags)
bool FJamStick::RunTest(const FString& Parameters)
{
	UJamCartridge* C = LoadPreset(*this, TEXT("hockey.regular"));
	if (!C) return false;
	FJamGameConfig G = C->Game;
	TestTrue(TEXT("regular has the body check (R-0013)"), G.Skater.bCheckEnabled);
	TestFalse(TEXT("regular has no whistle (R-0048 point 2; lane A112)"), G.Rules.bPenalties);
	G.Rules.bPenalties = true;   // lane A112: the cases below are about the whistle's rules (fouls, the box), which modes keep: switched on here

	// 1. Faceoff: countdown, drop, the human (a centre) wins with the first clean press after the drop.
	{
		UJamSim* Sim = MakeSim(G, 1, false);
		const int32 Me = Sim->GetHumanIndex();
		TestEqual(TEXT("match opens in the Faceoff phase"), Sim->GetPhase(), EJamSimPhase::Faceoff);
		TestEqual(TEXT("countdown 90"), Sim->GetFaceoffCountdown(), UJamSim::FaceoffCountdownFrames);
		TestTrue(TEXT("the human takes the draw"), Sim->GetSkaters()[Me].bCentre);
		int32 Centres = 0;
		for (const FJamSkaterState& S : Sim->GetSkaters()) if (S.bCentre) ++Centres;
		TestEqual(TEXT("two centres"), Centres, 2);
		TArray<FJamInput> In;
		In.SetNum(Sim->GetSkaters().Num());
		In[Me].Move = FVector2D(1, 0);   // moving the stick is not a press
		for (int32 F = 0; F < UJamSim::FaceoffCountdownFrames - 1; ++F) Sim->Step(In);
		TestEqual(TEXT("still counting down after 89 frames"), Sim->GetPhase(), EJamSimPhase::Faceoff);
		TestTrue(TEXT("the puck sits at the dot"), Sim->GetPuck().Pos.Size() <= UJamSim::FaceoffDropM + 1e-9);
		Sim->Step(In);
		TestEqual(TEXT("the drop"), Sim->GetPhase(), EJamSimPhase::Playing);
		TestEqual(TEXT("faceoff drop event"), CountEvents(Sim, JamEvents::Faceoff, FName(TEXT("drop"))), 1);
		TestTrue(TEXT("draw open"), Sim->IsDrawOpen());
		In[Me].bPoke = true;
		Sim->Step(In);
		In[Me].bPoke = false;
		TestFalse(TEXT("draw closed on the first press"), Sim->IsDrawOpen());
		TestEqual(TEXT("faceoff won by the human"), CountEvents(Sim, JamEvents::Faceoff, FName(TEXT("won")), Me), 1);
		TestEqual(TEXT("faceoff lost by the other centre"), CountEvents(Sim, JamEvents::Faceoff, FName(TEXT("lost"))), 1);
		TestEqual(TEXT("the puck is the human's"), Sim->GetPuck().LastTouch, Me);
		TestTrue(TEXT("the puck goes back towards the human's side"), Sim->GetPuck().Vel.X * Sim->AttackGoalX(Sim->GetHumanTeam()) < 0);
	}

	// 2. An early press loses the draw to the bot centre.
	{
		UJamSim* Sim = MakeSim(G, 1, false);
		const int32 Me = Sim->GetHumanIndex();
		TArray<FJamInput> In;
		In.SetNum(Sim->GetSkaters().Num());
		In[Me].bPoke = true;
		Sim->Step(In);
		In[Me].bPoke = false;
		TestEqual(TEXT("early mover flagged"), Sim->GetSkaters()[Me].DrawFrame, (int64)-2);
		int32 WonBy = -1;
		for (int32 F = 0; F < UJamSim::FaceoffCountdownFrames + UJamSim::DrawWindowFrames + 2 && WonBy < 0; ++F)
		{
			In[Me].bPoke = (F % 5 == 0);   // keeps pressing: never counts after an early move
			Sim->Step(In);
			for (const FJamSimEvent& E : Sim->GetFrameEvents()) if (E.Name == JamEvents::Faceoff && E.Kind == FName(TEXT("won"))) WonBy = E.Who;
		}
		TestTrue(TEXT("the draw resolved"), WonBy >= 0);
		TestNotEqual(TEXT("the early human lost the draw"), WonBy, Me);
		AddInfo(FString::Printf(TEXT("bot centre %d won the draw after the human's early move"), WonBy));
	}

	// 3. Poke: clean take from a carrier the blade reaches; a miss next to a carrier stumbles.
	{
		UJamSim* Sim = MakeSim(G, 1, true);
		const int32 Me = Sim->GetHumanIndex();
		const int32 O = FirstOpponent(Sim, Me);
		Park(Sim, { Me, O });
		Sim->SetSkater(O, FVector2D(0, 0), FVector2D::ZeroVector, 0);
		Sim->SetSkater(Me, FVector2D(2.6, 0), FVector2D::ZeroVector, UE_DOUBLE_PI);   // the carried puck sits on the carrier's blade 1.0 m ahead (reach 1.2); full aim from 2.6 m lands the blade on it
		GivePuck(Sim, O);
		TestEqual(TEXT("the opponent carries"), Sim->GetPuck().LastTouch, O);
		TArray<FJamInput> In;
		In.SetNum(Sim->GetSkaters().Num());
		In[Me].Stick = FVector2D(-1, 0);   // full reach at the puck
		In[Me].bPoke = true;
		Sim->Step(In);
		In[Me].bPoke = false;
		AddInfo(FString::Printf(TEXT("poke: blade at (%.2f, %.2f), puck at (%.2f, %.2f)"), Sim->GetSkaters()[Me].BladePos.X, Sim->GetSkaters()[Me].BladePos.Y, Sim->GetPuck().Pos.X, Sim->GetPuck().Pos.Y));
		TestEqual(TEXT("clean poke event"), CountEvents(Sim, JamEvents::Poke, FName(TEXT("clean")), Me), 1);
		TestEqual(TEXT("the puck is the poker's"), Sim->GetPuck().LastTouch, Me);
		TestFalse(TEXT("no stumble on a clean poke"), Sim->GetSkaters()[Me].IsStumbling());

		// Miss: armed (carrier within reach + 1 m) but the blade falls short.
		// Lane A152: the blade rule and the stumble are the neutral values of game.stick.poke_assist_deg and miss_recovery_frames (a person's poke now reaches
		// a puck inside its stick's reach and its miss costs a recovery: Jam.Core.Movement.PokeReach, .PokeRecovery). This block keeps the rule underneath.
		FJamGameConfig GBlade = G;
		GBlade.Stick.PokeAssistDeg = 0.0; GBlade.Stick.MissRecoveryFrames = 0;
		UJamSim* S2 = MakeSim(GBlade, 1, true);
		Park(S2, { Me, O });
		S2->SetSkater(O, FVector2D(0, 0), FVector2D::ZeroVector, 0);
		S2->SetSkater(Me, FVector2D(2.9, 0), FVector2D::ZeroVector, UE_DOUBLE_PI);   // inside the arming distance (two bodies + reach + 1 m = 3.0)
		GivePuck(S2, O);
		In[Me].Stick = FVector2D(-0.5, 0);   // half aim: the blade (1.0 m out) stops 0.9 m short of the carried puck
		In[Me].bPoke = true;
		S2->Step(In);
		In[Me].bPoke = false;
		AddInfo(FString::Printf(TEXT("miss poke: blade at (%.2f, %.2f), puck at (%.2f, %.2f)"), S2->GetSkaters()[Me].BladePos.X, S2->GetSkaters()[Me].BladePos.Y, S2->GetPuck().Pos.X, S2->GetPuck().Pos.Y));
		TestTrue(TEXT("poke armed next to the carrier"), S2->GetSkaters()[Me].bPokeArmed);
		int32 Misses = 0;
		for (int32 F = 0; F < G.Stick.PokeWindowFrames + 1; ++F) { S2->Step(In); Misses += CountEvents(S2, JamEvents::Poke, FName(TEXT("miss")), Me); }
		TestEqual(TEXT("one miss event when the window runs out"), Misses, 1);
		TestTrue(TEXT("the poker stumbles"), S2->GetSkaters()[Me].IsStumbling());
		TestEqual(TEXT("the carrier kept the puck"), S2->GetPuck().LastTouch, O);
		In[Me].Move = FVector2D(1, 0);
		for (int32 F = 0; F < G.Stick.StumbleFrames - 2; ++F) S2->Step(In);
		TestTrue(TEXT("no thrust while stumbling"), S2->GetSkaters()[Me].Vel.Size() < 0.5);
		for (int32 F = 0; F < 30; ++F) S2->Step(In);
		TestTrue(TEXT("control is back after the stumble"), S2->GetSkaters()[Me].Vel.Size() > 2.0);
	}

	// 4. Stick lift strips a carrier in contact range.
	{
		UJamSim* Sim = MakeSim(G, 1, true);
		const int32 Me = Sim->GetHumanIndex();
		const int32 O = FirstOpponent(Sim, Me);
		Park(Sim, { Me, O });
		Sim->SetSkater(O, FVector2D(0, 0), FVector2D::ZeroVector, 0);
		Sim->SetSkater(Me, FVector2D(0.0, 1.2), FVector2D::ZeroVector, -UE_DOUBLE_PI / 6.0);   // lane A95 (B-to-A-0037): 60 degrees off the line to the carrier, inside stick.lift_cone_deg 70 (was 90)
		GivePuck(Sim, O);
		TArray<FJamInput> In;
		In.SetNum(Sim->GetSkaters().Num());
		In[Me].bLift = true;
		Sim->Step(In);
		TestEqual(TEXT("clean lift event"), CountEvents(Sim, JamEvents::Lift, FName(TEXT("clean")), Me), 1);
		TestEqual(TEXT("the puck is the lifter's"), Sim->GetPuck().LastTouch, Me);
		// Out of range: a miss.
		UJamSim* S2 = MakeSim(G, 1, true);
		Park(S2, { Me, O });
		S2->SetSkater(O, FVector2D(0, 0), FVector2D::ZeroVector, 0);
		S2->SetSkater(Me, FVector2D(0.0, 3.0), FVector2D::ZeroVector, 0);
		GivePuck(S2, O);
		S2->Step(In);
		TestEqual(TEXT("lift miss out of range"), CountEvents(S2, JamEvents::Lift, FName(TEXT("miss")), Me), 1);
		TestEqual(TEXT("the carrier kept the puck"), S2->GetPuck().LastTouch, O);
	}

	// 5. Foul: a check on a skater without the puck. Box, free faceoff at the fouler's end.
	{
		UJamSim* Sim = MakeSim(G, 1, true);
		const int32 Me = Sim->GetHumanIndex();
		const int32 O = FirstOpponent(Sim, Me);
		Park(Sim, { Me, O });
		Sim->SetPuck(FVector2D(20, 15), FVector2D::ZeroVector);   // the puck is nowhere near
		Sim->SetSkater(O, FVector2D(0, 0), FVector2D::ZeroVector, 0);
		// Lane A192: the window opens game.contact.check_windup_frames after the press: the charger starts that much ground farther out and the scene runs
		// that many frames longer (the same contact on the same course).
		const int32 Wu = Sim->GetConfig().Contact.CheckWindupFor(Sim->GetSkaters()[Me].bHuman);   // lane A200: the presser's own (bot_check_windup_frames for a bot)
		Sim->SetSkater(Me, FVector2D(-1.2 - 8.0 * Wu / 60.0, 0), FVector2D(8, 0), 0);
		TArray<FJamInput> In;
		In.SetNum(Sim->GetSkaters().Num());
		In[Me].Move = FVector2D(1, 0);
		In[Me].bCheck = true;
		int32 Fouls = 0, Checks = 0;
		for (int32 F = 0; F < 6 + Wu; ++F)
		{
			Sim->Step(In);
			In[Me].bCheck = false;
			Fouls += CountEvents(Sim, JamEvents::Foul, FName(TEXT("foul_no_puck")), Me);
			Checks += CountEvents(Sim, JamEvents::Check, NAME_None, Me);
		}
		TestEqual(TEXT("the check landed"), Checks, 1);
		TestEqual(TEXT("a foul: the victim had no puck"), Fouls, 1);
		TestTrue(TEXT("the fouler sits 300 frames (less the frames since the hit)"), Sim->GetSkaters()[Me].PenaltyFrames > UJamSim::BoxFrames - 8 && Sim->GetSkaters()[Me].PenaltyFrames <= UJamSim::BoxFrames);
		TestEqual(TEXT("play pauses for the free faceoff"), Sim->GetPhase(), EJamSimPhase::GoalPause);
		TestTrue(TEXT("the victim is down"), Sim->GetSkaters()[O].IsDown());
		for (int32 F = 0; F < UJamSim::FoulPauseFrames + 1; ++F) Sim->Step(In);
		TestEqual(TEXT("faceoff countdown at the fouler's end"), Sim->GetPhase(), EJamSimPhase::Faceoff);
		const FVector2D Dot = Sim->GetFaceoffDot();
		AddInfo(FString::Printf(TEXT("foul faceoff dot (%.1f, %.1f); fouler at (%.1f, %.1f)"), Dot.X, Dot.Y, Sim->GetSkaters()[Me].Pos.X, Sim->GetSkaters()[Me].Pos.Y));
		TestTrue(TEXT("the dot is in the fouler's own end"), Dot.X * Sim->AttackGoalX(Sim->GetHumanTeam()) < 0 && FMath::Abs(Dot.X) > 10.0);
		TestTrue(TEXT("the fouler is in the box, not a centre"), Sim->GetSkaters()[Me].InBox() && !Sim->GetSkaters()[Me].bCentre);
		FVector2D N;
		TestTrue(TEXT("the box is inside the boards"), Sim->BoardDistance(Sim->GetSkaters()[Me].Pos, N) < 0);
		// No foul when penalties are off (hockey.raw's rule).
		FJamGameConfig Raw = G;
		Raw.Rules.bPenalties = false;
		UJamSim* S2 = MakeSim(Raw, 1, true);
		Park(S2, { Me, O });
		S2->SetPuck(FVector2D(20, 15), FVector2D::ZeroVector);
		S2->SetSkater(O, FVector2D(0, 0), FVector2D::ZeroVector, 0);
		S2->SetSkater(Me, FVector2D(-1.2 - 8.0 * Wu / 60.0, 0), FVector2D(8, 0), 0);   // lane A192: as above
		In[Me].bCheck = true;
		int32 Fouls2 = 0;
		for (int32 F = 0; F < 6 + Wu; ++F) { S2->Step(In); In[Me].bCheck = false; Fouls2 += CountEvents(S2, JamEvents::Foul, NAME_None); }
		TestEqual(TEXT("penalties off: no foul"), Fouls2, 0);
		TestEqual(TEXT("penalties off: nobody in the box"), S2->GetSkaters()[Me].PenaltyFrames, 0);
	}

	// 5b. R-0029 point 3, foul grace: the human lifts the puck off O, then checks O from the side. Six frames after the strip the check is clean
	// (O carried within foul_grace_frames); twenty frames after, the same check is foul_no_puck.
	G.Contact.StandSideBrace = 0.0;   // lane A151 (track F1): this scene and the next stage their rule with a body check from the side on a STANDING skater without the puck, at the brace that hit had (CONTACT-6.md section 3)
	for (const int32 Wait : { 6, 20 })
	{
		UJamSim* Sim = MakeSim(G, 1, true);
		const int32 Me = Sim->GetHumanIndex();
		const int32 O = FirstOpponent(Sim, Me);
		Park(Sim, { Me, O });
		Sim->SetSkater(O, FVector2D(0, 0), FVector2D::ZeroVector, 0);
		Sim->SetSkater(Me, FVector2D(0.0, 1.2), FVector2D::ZeroVector, -UE_DOUBLE_PI / 6.0);   // lane A95 (B-to-A-0037): 60 degrees off the line to the carrier, inside stick.lift_cone_deg 70 (was 90)
		GivePuck(Sim, O);
		TArray<FJamInput> In;
		In.SetNum(Sim->GetSkaters().Num());
		In[Me].bLift = true;
		Sim->Step(In);
		In[Me].bLift = false;
		TestEqual(*FString::Printf(TEXT("grace %d: the lift stripped O"), Wait), CountEvents(Sim, JamEvents::Lift, FName(TEXT("clean")), Me), 1);
		const int64 StripFrame = Sim->GetFrame();
		// Lane A192: the press goes the wind-up earlier, so the hit lands as many frames after the strip as it did.
		for (int32 F = 0; F < Wait - Sim->GetConfig().Contact.CheckWindupFor(Sim->GetSkaters()[Me].bHuman); ++F) Sim->Step(In);   // lane A200: the presser's own (bot_check_windup_frames for a bot)
		// Charge O from the side (not from behind): O faces +x, the hit comes along -z.
		// Lane A92 (R-0045): the puck the lift sent the human's way is parked, so the charger does not carry it (the carrier cannot hit once the grace is over).
		Sim->SetPuck(FVector2D(-15.0, -10.0), FVector2D::ZeroVector);
		const int32 Wu = Sim->GetConfig().Contact.CheckWindupFor(Sim->GetSkaters()[Me].bHuman);   // lane A200: the presser's own; lane A192: the charger starts the wind-up's ground farther out; the scene runs that much longer
		Sim->SetSkater(Me, FVector2D(0.0, 1.3 + 8.0 * Wu / 60.0), FVector2D(0, -8), -UE_DOUBLE_PI * 0.5);
		In[Me].Move = FVector2D(0, -1);
		In[Me].bCheck = true;
		int32 Checks = 0, Fouls = 0;
		int64 HitFrame = -1;
		for (int32 F = 0; F < 8 + Wu; ++F)
		{
			Sim->Step(In);
			In[Me].bCheck = (F % 4 == 3);
			if (CountEvents(Sim, JamEvents::Check, NAME_None, Me) > 0 && HitFrame < 0) HitFrame = Sim->GetFrame();
			Checks += CountEvents(Sim, JamEvents::Check, NAME_None, Me);
			Fouls += CountEvents(Sim, JamEvents::Foul, FName(TEXT("foul_no_puck")), Me);
		}
		AddInfo(FString::Printf(TEXT("grace %d: strip at frame %lld, hit at %lld (%lld frames after; grace %d), fouls %d"), Wait, StripFrame, HitFrame, HitFrame - StripFrame, G.Stick.FoulGraceFrames, Fouls));
		TestTrue(*FString::Printf(TEXT("grace %d: the check landed"), Wait), Checks >= 1);
		if (Wait <= G.Stick.FoulGraceFrames - 2) TestEqual(*FString::Printf(TEXT("grace %d: no foul right after the strip"), Wait), Fouls, 0);
		else TestEqual(*FString::Printf(TEXT("grace %d: a foul once the grace is over"), Wait), Fouls, 1);
	}

	// 6. Carry (R-0021 feel.00): the puck stays on the blade through a gentle 90 and through an instant 180 at full speed; a check takes it away.
	{
		UJamSim* Sim = MakeSim(G, 1, true);
		const int32 Me = Sim->GetHumanIndex();
		Park(Sim, { Me });
		Sim->SetSkater(Me, FVector2D(-30, -10), FVector2D::ZeroVector, 0);
		GivePuck(Sim, Me);
		TArray<FJamInput> In;
		In.SetNum(Sim->GetSkaters().Num());
		In[Me].Move = FVector2D(1, 0);
		for (int32 F = 0; F < 90; ++F) Sim->Step(In);
		const double Speed = Sim->GetSkaters()[Me].Vel.Size();
		TestTrue(TEXT("carrying at speed on the straight"), Sim->GetSkaters()[Me].bHasPuck && Speed > 7.5);
		// A 90-degree arc over 80 frames: 1.18 rad/s of steering, under the 90 deg/s carry limit.
		for (int32 F = 1; F <= 80; ++F)
		{
			const double A = (UE_DOUBLE_PI * 0.5) * F / 80.0;
			In[Me].Move = FVector2D(FMath::Cos(A), FMath::Sin(A));
			Sim->Step(In);
		}
		for (int32 F = 0; F < 30; ++F) Sim->Step(In);
		const FJamSkaterState& S = Sim->GetSkaters()[Me];
		AddInfo(FString::Printf(TEXT("after the gentle 90: speed %.2f, puck %.2f m away, has puck %d"), S.Vel.Size(), FVector2D::Distance(S.Pos, Sim->GetPuck().Pos), S.bHasPuck ? 1 : 0));
		TestTrue(TEXT("kept the puck through the gentle 90"), S.bHasPuck);
		// Instant 180 at full speed: the puck stays on the blade (it leaves only on a shot, pass, poke, lift or check).
		In[Me].Move = -S.Forward();
		bool bLost = false;
		for (int32 F = 0; F < 90 && !bLost; ++F) { Sim->Step(In); bLost = !Sim->GetSkaters()[Me].bHasPuck; }
		TestFalse(TEXT("kept the puck through the hard 180"), bLost);
		AddInfo(FString::Printf(TEXT("after the 180: speed %.2f, puck %.2f m from the body"), Sim->GetSkaters()[Me].Vel.Size(), FVector2D::Distance(Sim->GetSkaters()[Me].Pos, Sim->GetPuck().Pos)));
	}
	return true;
}

// Lane A49 (complaint 3): the aim sent to the visual is side-stable across the +-180 wrap and never jumps more than 15 degrees in a frame.
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamAimSmoothing, "Jam.Core.AimSmoothing", JamStickTests::Flags)
bool FJamAimSmoothing::RunTest(const FString& Parameters)
{
	int32 Side = 0;
	bool bInit = false;
	float Sent = 0.f;
	// Settle on the left at 60 degrees.
	for (int32 i = 0; i < 30; ++i) Sent = AJamSkater::SmoothAimDeg(60.f, Sent, Side, bInit);
	TestEqual(TEXT("settled at 60"), Sent, 60.f, 0.1f);
	TestEqual(TEXT("side left"), Side, 1);
	// The aim swings behind and jitters across +-180 (what the stuck mouse aim did while the skater skated): the sent aim holds +70, never flips.
	float MaxStep = 0.f;
	for (int32 i = 0; i < 600; ++i)
	{
		const float Raw = (i % 2 == 0) ? 179.f : -179.f;
		const float Prev = Sent;
		Sent = AJamSkater::SmoothAimDeg(Raw, Sent, Side, bInit);
		MaxStep = FMath::Max(MaxStep, FMath::Abs(Sent - Prev));
		if (Sent < 0.f) { AddError(FString::Printf(TEXT("flipped to the right at frame %d (sent %.1f)"), i, Sent)); break; }
	}
	TestEqual(TEXT("held at the left clamp"), Sent, AJamSkater::AimClampDeg, 0.1f);
	TestTrue(TEXT("every step under 15 degrees behind"), MaxStep <= AJamSkater::AimSlewDegPerFrame + 1e-3f);
	// Through the front to the right: the side changes, the sent aim slews at most 15 degrees per frame and settles.
	MaxStep = 0.f;
	for (int32 i = 0; i < 60; ++i)
	{
		const float Prev = Sent;
		Sent = AJamSkater::SmoothAimDeg(-60.f, Sent, Side, bInit);
		MaxStep = FMath::Max(MaxStep, FMath::Abs(Sent - Prev));
	}
	TestEqual(TEXT("settled at -60"), Sent, -60.f, 0.1f);
	TestEqual(TEXT("side right"), Side, -1);
	TestTrue(TEXT("every step under 15 degrees through the front"), MaxStep <= AJamSkater::AimSlewDegPerFrame + 1e-3f);
	AddInfo(FString::Printf(TEXT("max step through the front %.2f degrees (slew %.0f)"), MaxStep, AJamSkater::AimSlewDegPerFrame));
	return true;
}

} // namespace JamStickTests

#endif
