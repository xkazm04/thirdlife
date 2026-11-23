// Lane A33 (R-0028 point 3): the sim's read-outs for tackling that reads. Jam.Core.TacklingEvents: two skaters sent into each other at centre ice
// at three closing speeds from the four directions; the check event carries Kind = front | side_l | side_r | behind and Strength = closing speed / skater.speed;
// a skater into the boards above 4 m/s emits board (Who = skater, Kind = skater), below it nothing; the state hash of the scene is the same with and without
// the events being read (they are read-outs). Run:
//   UnrealEditor-Cmd.exe Game/ThirdJam.uproject -ExecCmds="Automation RunTests Jam.Core.Tackling; Quit" -unattended -nullrhi -nosplash -log
#include "Misc/AutomationTest.h"
#include "JamCartridge.h"
#include "JamSim.h"
#include "JamEventBus.h"

#if WITH_DEV_AUTOMATION_TESTS

namespace JamTacklingTests
{
	constexpr EAutomationTestFlags Flags = EAutomationTestFlags_ApplicationContextMask | EAutomationTestFlags::ProductFilter;

	// Lane A92 (R-0045): bNeutral = game.contact's neutral block (the check rule before contact by momentum); Jam.Core.TacklingEvents proves that rule on it, so the
	// neutral values give back the game the test was written for. The model itself is Jam.Core.Contact.* (JamContactTests.cpp).
	UJamSim* MakeRaw(FAutomationTestBase& T, bool bNeutral = false)
	{
		TArray<FString> Errors;
		UJamCartridge* C = UJamCartridge::LoadFromFile(UJamCartridge::ResolveCartridgePath(TEXT("hockey.raw")), Errors);
		for (const FString& E : Errors) T.AddError(FString::Printf(TEXT("hockey.raw: %s"), *E));
		if (!C) return nullptr;
		if (bNeutral) C->Game.Contact.SetNeutral();
		UJamSim* Sim = NewObject<UJamSim>();
		Sim->Init(C->Game, 7);
		Sim->SkipFaceoff();
		return Sim;
	}

	// Parks every skater in a corner so only the two of the scene can touch; the puck far away.
	void ClearIce(UJamSim* Sim, int32 KeepA, int32 KeepB)
	{
		const double Hx = Sim->GetConfig().Rink.LengthM * 0.5 - 3.0;
		const double Hz = Sim->GetConfig().Rink.WidthM * 0.5 - 3.0;
		int32 K = 0;
		for (const FJamSkaterState& S : Sim->GetSkaters())
		{
			if (S.Index == KeepA || S.Index == KeepB) continue;
			Sim->SetSkater(S.Index, FVector2D(-Hx + 2.0 * K, (K % 2 ? 1.0 : -1.0) * Hz), FVector2D::ZeroVector, 0.0);
			++K;
		}
		// Lane A192: the puck at the side boards' middle. At (Hx, 0) it sat in a net mouth and the scene's first frame was a goal: everything after it ran in the
		// goal pause (braking, no presses), which a check pressed with a wind-up does not survive.
		Sim->SetPuck(FVector2D(0.0, Hz + 1.5), FVector2D::ZeroVector);
	}

	// Runs until a check event or MaxFrames; returns the event (Name None when none).
	FJamSimEvent RunUntil(UJamSim* Sim, FName Name, int32 Checker, int32 MaxFrames, uint64* OutHash)
	{
		const int32 N = Sim->GetSkaters().Num();
		for (int32 F = 0; F < MaxFrames; ++F)
		{
			TArray<FJamInput> In;
			In.SetNum(N);
			if (Checker >= 0 && F == 0) In[Checker].bCheck = true;
			Sim->Step(In);
			for (const FJamSimEvent& E : Sim->GetFrameEvents())
			{
				if (E.Name == Name) { if (OutHash) *OutHash = Sim->StateHash(); return E; }
			}
		}
		if (OutHash) *OutHash = Sim->StateHash();
		return FJamSimEvent();
	}
}

using namespace JamTacklingTests;

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamTacklingEvents, "Jam.Core.TacklingEvents", JamTacklingTests::Flags)
bool FJamTacklingEvents::RunTest(const FString& Parameters)
{
	UJamSim* Probe = MakeRaw(*this, true);
	if (!Probe) return false;
	const double MaxSpeed = Probe->GetConfig().Skater.Speed;
	// Skater 0 (team 0) checks skater 3 (team 1). The victim stands still at the centre facing +x; the checker starts 1.2 m away, moving at the victim at ClosingSpeed,
	// its window opened on frame 0 (the window lasts 6 frames; at 6 m/s the gap of 0.4 m to contact closes in 4 frames).
	struct FCase { const TCHAR* Name; FVector2D From; double VictimYaw; const TCHAR* Kind; };
	const FCase Cases[] = {
		{ TEXT("head-on"), FVector2D(1.0, 0.0), 0.0, TEXT("front") },        // checker in front of the victim (+x), pushes toward -x: against the facing
		{ TEXT("from behind"), FVector2D(-1.0, 0.0), 0.0, TEXT("behind") },  // checker behind (-x), pushes toward +x: along the facing
		{ TEXT("from the left"), FVector2D(0.0, -1.0), 0.0, TEXT("side_l") }, // the victim's left is -z (the yaw grows to the right): checker at -z pushes toward +z
		{ TEXT("from the right"), FVector2D(0.0, 1.0), 0.0, TEXT("side_r") },
		{ TEXT("head-on, victim facing -z"), FVector2D(0.0, -1.0), -PI / 2, TEXT("front") },
	};
	const double Speeds[] = { 6.0, 9.0, 12.0 };
	for (const FCase& C : Cases)
	{
		for (double V : Speeds)
		{
			UJamSim* Sim = MakeRaw(*this, true);
			if (!Sim) return false;
			ClearIce(Sim, 0, 3);
			Sim->SetSkater(3, FVector2D::ZeroVector, FVector2D::ZeroVector, C.VictimYaw);
			const FVector2D Dir = -C.From;   // the push: from the checker toward the victim
			// Lane A192: the window opens game.contact.check_windup_frames after the press: the checker starts that much ground farther out (the same contact).
			Sim->SetSkater(0, C.From * (1.2 + V * Sim->GetConfig().Contact.CheckWindupFor(Sim->GetSkaters()[0].bHuman) / 60.0), Dir * V, FMath::Atan2(Dir.Y, Dir.X));   // lane A200: the presser's own (bot_check_windup_frames for a bot)
			uint64 Hash = 0;
			const FJamSimEvent E = RunUntil(Sim, JamEvents::Check, 0, 8 + Sim->GetConfig().Contact.CheckWindupFor(Sim->GetSkaters()[0].bHuman), &Hash);   // lane A209: the window's frames after the presser's own wind-up (was 12 at 4)
			const FString Label = FString::Printf(TEXT("%s at %.0f m/s"), C.Name, V);
			if (!TestEqual(*FString::Printf(TEXT("%s: a check lands"), *Label), E.Name.ToString(), JamEvents::Check.ToString())) continue;
			TestEqual(*FString::Printf(TEXT("%s: who = the checker"), *Label), E.Who, 0);
			TestEqual(*FString::Printf(TEXT("%s: kind"), *Label), E.Kind.ToString(), FString(C.Kind));
			// Strength = closing speed / skater.speed, clamped (the victim stands, so closing = the checker's speed, less a frame of glide).
			const float Expect = static_cast<float>(FMath::Min(1.0, V / MaxSpeed));
			TestTrue(*FString::Printf(TEXT("%s: strength %.2f near %.2f"), *Label, E.Strength, Expect), FMath::Abs(E.Strength - Expect) < 0.08f);
			// The knockdown follows with the same strength and the victim is down for knockdown_frames.
			bool bKnock = false;
			for (const FJamSimEvent& K : Sim->GetFrameEvents()) if (K.Name == JamEvents::Knockdown && K.Who == 3)
			{
				bKnock = true;
				TestEqual(*FString::Printf(TEXT("%s: knockdown strength"), *Label), K.Strength, E.Strength, 0.001f);
				// Lane A47 (B-to-A-0029 ask 1): the read-out Dir on knockdown is the victim's KnockDir, on check the same contact normal (checker towards victim), unit length.
				TestTrue(*FString::Printf(TEXT("%s: knockdown Dir = KnockDir"), *Label), K.Dir.Equals(Sim->GetSkaters()[3].KnockDir, 0.001));
				TestTrue(*FString::Printf(TEXT("%s: check Dir = the push (unit)"), *Label), E.Dir.Equals(K.Dir, 0.001) && FMath::IsNearlyEqual(E.Dir.Size(), 1.0, 0.001));
			}
			TestTrue(*FString::Printf(TEXT("%s: knockdown event"), *Label), bKnock);
			TestEqual(*FString::Printf(TEXT("%s: victim down for knockdown_frames"), *Label), Sim->GetSkaters()[3].KnockFrames, Sim->GetConfig().Skater.KnockdownFrames);
			AddInfo(FString::Printf(TEXT("%s: check kind=%s strength=%.3f at frame %lld, hash %016llx"), *Label, *E.Kind.ToString(), E.Strength, E.Frame, static_cast<unsigned long long>(Hash)));
		}
	}

	// Below check_speed_min nothing lands for a bot (and no event of any kind is emitted by the contact); the human lands from
	// HumanCheckSpeedMinMs (lane A49, R-0032: the operator skates slowly into the carrier and the hit must land).
	{
		UJamSim* Sim = MakeRaw(*this, true);
		ClearIce(Sim, 1, 3);
		Sim->SetSkater(3, FVector2D::ZeroVector, FVector2D::ZeroVector, 0.0);
		Sim->SetSkater(1, FVector2D(1.2, 0.0), FVector2D(-3.0, 0.0), PI);
		const FJamSimEvent E = RunUntil(Sim, JamEvents::Check, 1, 30, nullptr);
		TestTrue(TEXT("bot at 3 m/s: no check lands (below check_speed_min 5)"), E.Name.IsNone());
	}
	{
		UJamSim* Sim = MakeRaw(*this, true);
		ClearIce(Sim, 0, 3);
		Sim->SetSkater(3, FVector2D::ZeroVector, FVector2D::ZeroVector, 0.0);
		Sim->SetSkater(0, FVector2D(1.2, 0.0), FVector2D(-3.0, 0.0), PI);
		const FJamSimEvent E = RunUntil(Sim, JamEvents::Check, 0, 30, nullptr);
		TestTrue(TEXT("human at 3 m/s: the check lands (HumanCheckSpeedMinMs 2, lane A49)"), E.Name == JamEvents::Check);
	}

	// The boards: a skater sliding into the side boards at 6 m/s emits board (Who = skater, Kind = skater, Strength 6 / speed); at 3 m/s nothing.
	for (double V : { 6.0, 3.0 })
	{
		UJamSim* Sim = MakeRaw(*this, true);
		ClearIce(Sim, 0, 3);
		Sim->SetSkater(3, FVector2D(-10.0, 0.0), FVector2D::ZeroVector, 0.0);
		const double Hz = Sim->GetConfig().Rink.WidthM * 0.5;
		Sim->SetSkater(0, FVector2D(0.0, Hz - 2.0), FVector2D(0.0, V), PI / 2);
		FJamSimEvent Found;
		for (int32 F = 0; F < 40 && Found.Name.IsNone(); ++F)
		{
			TArray<FJamInput> In; In.SetNum(Sim->GetSkaters().Num());
			Sim->Step(In);
			for (const FJamSimEvent& E : Sim->GetFrameEvents()) if (E.Name == JamEvents::Board && E.Who == 0) Found = E;
		}
		if (V > 4.0)
		{
			TestEqual(TEXT("6 m/s into the boards: board event for the skater"), Found.Name.ToString(), JamEvents::Board.ToString());
			TestEqual(TEXT("6 m/s: kind skater"), Found.Kind.ToString(), FString(TEXT("skater")));
			// Lane A47 (B-to-A-0029 ask 2): the read-out Dir on board is the board normal pointing into the rink: unit, and it points from the contact towards the rink centre.
			TestTrue(TEXT("board Dir is a unit vector into the rink"), FMath::IsNearlyEqual(Found.Dir.Size(), 1.0, 0.001) && FVector2D::DotProduct(Found.Dir, -Found.Where.GetSafeNormal()) > 0.5);
			// The skater glides 2 m before the boards, so it arrives between the 4 m/s threshold and its 6 m/s start (hockey.raw: 4.5 m/s measured, 0.52 of its 8.6 m/s top speed).
			TestTrue(*FString::Printf(TEXT("6 m/s start: strength %.2f between %.2f (the threshold) and %.2f"), Found.Strength, 4.0 / MaxSpeed, 6.0 / MaxSpeed),
				Found.Strength >= static_cast<float>(4.0 / MaxSpeed) - 0.001f && Found.Strength <= static_cast<float>(6.0 / MaxSpeed) + 0.001f);
			AddInfo(FString::Printf(TEXT("board at 6 m/s start: strength %.3f (%.2f m/s of %.1f) at frame %lld"), Found.Strength, Found.Strength * MaxSpeed, MaxSpeed, Found.Frame));
			TestTrue(TEXT("6 m/s: the contact point is on the boards"), FMath::Abs(FMath::Abs(Found.Where.Y) - Hz) < 0.05);
		}
		else
		{
			TestTrue(TEXT("3 m/s into the boards: no board event"), Found.Name.IsNone());
		}
	}

	// Read-out only: the hash at frame 300 of a bot-free scene is the same as the Determinism baseline's style of run (two runs agree).
	{
		UJamSim* A = MakeRaw(*this, true);
		UJamSim* B = MakeRaw(*this, true);
		for (int32 F = 0; F < 300; ++F)
		{
			TArray<FJamInput> In; In.SetNum(A->GetSkaters().Num());
			In[0].Move = FVector2D(1.0, 0.0); In[0].bCheck = (F % 20) == 0;
			In[3].Move = FVector2D(-1.0, 0.0); In[3].bCheck = (F % 20) == 10;
			A->Step(In);
			B->Step(In);
		}
		TestEqual(TEXT("two runs of the collision scene agree"), A->StateHash(), B->StateHash());
		AddInfo(FString::Printf(TEXT("collision scene frame 300 hash %016llx"), static_cast<unsigned long long>(A->StateHash())));
	}
	return true;
}

// Lane A45 (C-0001 v4, R-0031 point 1): the read-outs the pawn's four new calls hang on. A collision at 4 m/s closing without a check press bumps both skaters (the push on
// each is the other towards it), at 2 m/s nothing; a skater into the end boards at 6 m/s sets the board flag on the frame of the board event; a skater pressed into the side
// boards for 10 frames with an opponent 1 m away is pinned, and released when the opponent leaves; a clean lift flags the carrier with 2. None of it is in the hash: the
// hash of the bump scene equals the hash of the same scene with the read-outs ignored (they are plain fields the sim never reads).
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamTacklingReadouts, "Jam.Core.TacklingReadouts", JamTacklingTests::Flags)
bool FJamTacklingReadouts::RunTest(const FString& Parameters)
{
	using namespace JamTacklingTests;
	auto StepN = [](UJamSim* Sim, int32 Frames, TFunctionRef<void(TArray<FJamInput>&, int32)> Fill)
	{
		const int32 N = Sim->GetSkaters().Num();
		for (int32 F = 0; F < Frames; ++F) { TArray<FJamInput> In; In.SetNum(N); Fill(In, F); Sim->Step(In); }
	};
	// 1. The bump.
	for (const double Speed : { 4.0, 2.0 })
	{
		UJamSim* Sim = MakeRaw(*this);
		if (!Sim) return false;
		ClearIce(Sim, 0, 3);
		Sim->SetPuck(FVector2D(-20.0, 0.0), FVector2D::ZeroVector);   // ClearIce parks the puck at (Hx, 0): inside the net on the raw rink, a goal and the pause
		Sim->SetSkater(3, FVector2D::ZeroVector, FVector2D::ZeroVector, PI);
		Sim->SetSkater(0, FVector2D(-1.3, 0.0), FVector2D(Speed, 0.0), 0.0);
		bool bBumpA = false, bBumpB = false, bCheck = false;
		FVector2D DirA, DirB;
		for (int32 F = 0; F < 40 && !bBumpA; ++F)
		{
			StepN(Sim, 1, [](TArray<FJamInput>&, int32) {});
			const FJamSkaterState& A = Sim->GetSkaters()[0];
			const FJamSkaterState& B = Sim->GetSkaters()[3];
			if (A.bBumpThisFrame) { bBumpA = true; DirA = A.BumpDir; }
			if (B.bBumpThisFrame) { bBumpB = true; DirB = B.BumpDir; }
			for (const FJamSimEvent& E : Sim->GetFrameEvents()) if (E.Name == JamEvents::Check || E.Name == JamEvents::Knockdown) bCheck = true;
		}
		if (Speed >= 3.0)
		{
			TestTrue(TEXT("4 m/s into a standing opponent: the mover is bumped"), bBumpA);
			TestTrue(TEXT("4 m/s into a standing opponent: the one hit is bumped the same frame"), bBumpB);
			TestTrue(TEXT("the mover's push points back along its path"), bBumpA && DirA.X < -0.9);
			TestTrue(TEXT("the one hit is pushed on along the mover's path"), bBumpB && DirB.X > 0.9);
			TestFalse(TEXT("no check and no knockdown: nobody pressed check"), bCheck);
		}
		else
		{
			TestFalse(TEXT("2 m/s closing bumps nobody"), bBumpA || bBumpB);
		}
	}
	// 2. The board flag rides with the board event.
	{
		UJamSim* Sim = MakeRaw(*this);
		if (!Sim) return false;
		ClearIce(Sim, 0, 3);
		Sim->SetPuck(FVector2D(-20.0, 0.0), FVector2D::ZeroVector);
		const double Hx = Sim->GetConfig().Rink.LengthM * 0.5;
		Sim->SetSkater(3, FVector2D(0.0, 10.0), FVector2D::ZeroVector, 0.0);
		Sim->SetSkater(0, FVector2D(Hx - 2.0, 0.0), FVector2D(6.0, 0.0), 0.0);
		bool bFlag = false, bEvent = false, bSameFrame = false;
		for (int32 F = 0; F < 60 && !bFlag; ++F)
		{
			StepN(Sim, 1, [](TArray<FJamInput>& In, int32) { In[0].Move = FVector2D(1.0, 0.0); });
			bool bE = false;
			for (const FJamSimEvent& E : Sim->GetFrameEvents()) if (E.Name == JamEvents::Board && E.Who == 0) bE = true;
			bEvent |= bE;
			if (Sim->GetSkaters()[0].bBoardHitThisFrame) { bFlag = true; bSameFrame = bE; }
		}
		TestTrue(TEXT("6 m/s into the end boards: the skater board event"), bEvent);
		TestTrue(TEXT("... and the board flag on the same frame"), bFlag && bSameFrame);
	}
	// 3. The pin.
	{
		UJamSim* Sim = MakeRaw(*this);
		if (!Sim) return false;
		ClearIce(Sim, 0, 3);
		Sim->SetPuck(FVector2D(-20.0, 0.0), FVector2D::ZeroVector);
		const double Hz = Sim->GetConfig().Rink.WidthM * 0.5;
		// Skater 0 skates into the side boards from 0.3 m out and keeps pressing (it stops with its centre 0.4 m from the boards); skater 3 stands 0.6 m aside and 1 m
		// further in, 1.17 m from where 0 stops: within the 1.2 m, off the boards itself, and out of 0's path.
		Sim->SetSkater(0, FVector2D(0.0, Hz - 0.7), FVector2D(0.0, 3.0), PI * 0.5);
		Sim->SetSkater(3, FVector2D(0.6, Hz - 1.4), FVector2D::ZeroVector, PI * 0.5);
		int32 PinFrame = -1, BoardFramesAtPin = 0, FirstContact = -1;
		FString Trace;
		for (int32 F = 0; F < 120 && PinFrame < 0; ++F)
		{
			StepN(Sim, 1, [](TArray<FJamInput>& In, int32) { In[0].Move = FVector2D(0.0, 1.0); });
			const FJamSkaterState& A = Sim->GetSkaters()[0];
			if (F % 10 == 0) Trace += FString::Printf(TEXT(" f%d z=%.2f bf=%d d3=%.2f;"), F, A.Pos.Y, A.BoardFrames, FVector2D::Distance(A.Pos, Sim->GetSkaters()[3].Pos));
			if (FirstContact < 0 && A.BoardFrames > 0) FirstContact = F;
			if (A.bBoardPinned) { PinFrame = F; BoardFramesAtPin = A.BoardFrames; }
		}
		AddInfo(FString::Printf(TEXT("pin trace (Hz %.1f):%s"), Hz, *Trace));
		TestTrue(TEXT("the skater reached the boards"), FirstContact >= 0);
		TestTrue(TEXT("pressed into the side boards with an opponent 1 m away: pinned"), PinFrame >= 0);
		TestTrue(TEXT("... after ten frames on the boards, not before"), PinFrame >= 0 && BoardFramesAtPin >= 10 && PinFrame - FirstContact >= 9);
		AddInfo(FString::Printf(TEXT("pin: first board contact at frame %d, pinned at frame %d with %d board frames"), FirstContact, PinFrame, BoardFramesAtPin));
		TestFalse(TEXT("the opponent 1 m off the boards is not pinned"), Sim->GetSkaters()[3].bBoardPinned);
		Sim->SetSkater(3, FVector2D(0.0, Hz - 6.0), FVector2D::ZeroVector, 0.0);
		StepN(Sim, 1, [](TArray<FJamInput>& In, int32) { In[0].Move = FVector2D(0.0, 1.0); });
		TestFalse(TEXT("the opponent leaves: the pin is released the next frame"), Sim->GetSkaters()[0].bBoardPinned);
	}
	// 4. The stick hit (a lift).
	{
		UJamSim* Sim = MakeRaw(*this);
		if (!Sim) return false;
		ClearIce(Sim, 0, 3);
		// Skater 3 dribbles the puck for 40 frames so it is the carrier (CarrierIndex reads the last toucher); skater 0 is then set 1.2 m beside it and lifts.
		Sim->SetSkater(3, FVector2D::ZeroVector, FVector2D::ZeroVector, 0.0);
		Sim->SetPuck(FVector2D(0.8, 0.0), FVector2D::ZeroVector);
		Sim->SetSkater(0, FVector2D(-8.0, 8.0), FVector2D::ZeroVector, 0.0);
		StepN(Sim, 40, [](TArray<FJamInput>& In, int32) { In[3].Move = FVector2D(1.0, 0.0); });
		const FJamSkaterState& Carrier = Sim->GetSkaters()[3];
		TestTrue(TEXT("skater 3 carries the puck"), Carrier.bHasPuck);
		// Lane A102: the lifter stands 1.2 m beside the carrier and faces it (it stood 1.2 m behind): with game.stick.body_shield a lift from behind does not take a puck held ahead.
		Sim->SetSkater(0, Carrier.Pos - FVector2D(0.0, 1.2), Carrier.Vel, UE_DOUBLE_PI * 0.5);
		StepN(Sim, 1, [](TArray<FJamInput>& In, int32) { In[3].Move = FVector2D(1.0, 0.0); In[0].Move = FVector2D(1.0, 0.0); In[0].bLift = true; });
		bool bLiftClean = false;
		for (const FJamSimEvent& E : Sim->GetFrameEvents()) if (E.Name == JamEvents::Lift && E.Who == 0 && E.Strength > 0.5f) bLiftClean = true;
		TestTrue(TEXT("the lift took the puck"), bLiftClean);
		TestEqual(TEXT("the carrier is flagged with a lift (2)"), Sim->GetSkaters()[3].StickHitResult, 2);
		TestEqual(TEXT("the lifter is not flagged"), Sim->GetSkaters()[0].StickHitResult, 0);
		StepN(Sim, 1, [](TArray<FJamInput>&, int32) {});
		TestEqual(TEXT("the flag lasts one frame"), Sim->GetSkaters()[3].StickHitResult, 0);
	}
	return true;
}

#endif
