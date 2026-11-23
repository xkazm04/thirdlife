// Lane A209 (track F1, the night; docs/experiments/CONTACT-13.md): a hit he aims lands. Jam.Core.Contact.HitFindsMan stages the human's presses on the
// cartridge as it ships (contact.check_pull_m 1.0, cross_any_man true, check_reach_m 1.0, the wind-ups 8 / 8) and at the neutral values (0, false, 0, 4 / 4):
// a check pressed at a man his straight line misses by 0.2 m lands at the wind-up's end; a standing shove is a bump; a press at a man 5.5 m away whiffs;
// a cross-check at a man without the puck shoves him; the wind-up and the pull are read from the cartridge the test builds.
#include "CoreMinimal.h"
#include "Misc/AutomationTest.h"
#include "JamCartridge.h"
#include "JamSim.h"

#if WITH_DEV_AUTOMATION_TESTS

namespace JamHitLandsTests
{
	constexpr EAutomationTestFlags Flags = EAutomationTestFlags_ApplicationContextMask | EAutomationTestFlags::ProductFilter;

	struct FOut { bool bOk = false; int32 Outcome = 0; bool bCross = false; int32 ContactFrame = -1; int32 Wu = 0; double MaxStep = 0.0; };

	// The human A skates +x at Speed from the origin; the opponent V stands at (Ahead, Off) facing him. Press: 1 = body check, 2 = cross-check (tap), on frame 0.
	FOut Scene(FAutomationTestBase& T, bool bNeutral, double Speed, double Ahead, double Off, int32 Press)
	{
		FOut O;
		TArray<FString> Errors;
		UJamCartridge* C = UJamCartridge::LoadFromFile(UJamCartridge::ResolveCartridgePath(TEXT("hockey.regular")), Errors);
		if (!C) { T.AddError(TEXT("hockey.regular does not load")); return O; }
		FJamGameConfig Cfg = C->Game;
		Cfg.Rules.bPenalties = false;
		if (bNeutral) { Cfg.Contact.CheckPullM = 0.0; Cfg.Contact.bCrossAnyMan = false; Cfg.Contact.CheckReachM = 0.0; Cfg.Contact.CheckWindupFrames = 4; Cfg.Contact.CrossWindupFrames = 4; }
		UJamSim* Sim = NewObject<UJamSim>();
		Sim->Init(Cfg, 7);
		Sim->SkipFaceoff();
		const int32 A = Sim->GetHumanIndex();
		const int32 Team = Sim->GetSkaters()[A].Team;
		int32 V = -1;
		for (const FJamSkaterState& K : Sim->GetSkaters()) if (K.Team != Team) { V = K.Index; break; }
		const double Hx = Cfg.Rink.LengthM * 0.5 - 4.0, Hz = Cfg.Rink.WidthM * 0.5 - 3.0;
		int32 N = 0;
		for (const FJamSkaterState& K : Sim->GetSkaters())
		{
			if (K.Index == A || K.Index == V) continue;
			Sim->SetSkater(K.Index, FVector2D(-Hx + 2.5 * N, (N % 2 ? 1.0 : -1.0) * Hz), FVector2D::ZeroVector, 0.0);
			++N;
		}
		Sim->SetPuck(FVector2D(-20.0, 12.0), FVector2D::ZeroVector);
		Sim->SetSkater(A, FVector2D::ZeroVector, FVector2D(Speed, 0.0), 0.0);
		Sim->SetSkater(V, FVector2D(Ahead, Off), FVector2D::ZeroVector, PI);
		O.Wu = Press == 2 ? Sim->GetConfig().Contact.CrossWindupFor(true) : Sim->GetConfig().Contact.CheckWindupFor(true);
		FVector2D Prev = Sim->GetSkaters()[A].Pos;
		for (int32 F = 0; F < 40; ++F)
		{
			TArray<FJamInput> In;
			In.SetNum(Sim->GetSkaters().Num());
			In[A].Move = Speed > 0.0 ? FVector2D(1.0, 0.0) : FVector2D::ZeroVector;
			In[A].Stick = FVector2D(1.0, 0.0);
			In[A].bCheck = Press == 1 && F == 0;
			In[A].bLift = Press == 2 && F == 0;
			Sim->Step(In);
			const FJamSkaterState& Sa = Sim->GetSkaters()[A];
			const FJamSkaterState& Sv = Sim->GetSkaters()[V];
			const bool bMet = FVector2D::Distance(Sa.Pos, Sv.Pos) < UJamSim::SkaterRadius * 2.0 + 0.02;   // the bodies' own push-out is not the pull
			if (O.ContactFrame < 0 && Sv.ContactBy == A && Sv.ContactOutcome > 0) { O.ContactFrame = F; O.Outcome = Sv.ContactOutcome; O.bCross = Sv.bContactCross; }
			if (O.ContactFrame < 0 && !bMet) O.MaxStep = FMath::Max(O.MaxStep, FVector2D::Distance(Prev, Sa.Pos) - Sa.Vel.Size() * UJamSim::DT);
			Prev = Sa.Pos;
		}
		O.bOk = true;
		T.AddInfo(FString::Printf(TEXT("JAMHIT %s press %d at %.1f m/s, man %.1f ahead %.1f aside: outcome %d cross %d contact frame %d (wind-up %d), pull beyond velocity x frame at most %.3f m"),
			bNeutral ? TEXT("neutral") : TEXT("shipped"), Press, Speed, Ahead, Off, O.Outcome, O.bCross ? 1 : 0, O.ContactFrame, O.Wu, O.MaxStep));
		return O;
	}
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamHitFindsMan, "Jam.Core.Contact.HitFindsMan", JamHitLandsTests::Flags)
bool FJamHitFindsMan::RunTest(const FString& Parameters)
{
	using namespace JamHitLandsTests;
	// 1. A body check at 5 m/s at a man 2.2 m ahead and 1.0 m aside: the straight line passes him by 0.2 m (the thin space).
	const FOut Ship = Scene(*this, false, 5.0, 2.2, 1.0, 1), Neut = Scene(*this, true, 5.0, 2.2, 1.0, 1);
	if (!Ship.bOk || !Neut.bOk) return false;
	TestTrue(TEXT("neutral: the press runs out on nobody"), Neut.Outcome == 0);
	TestTrue(*FString::Printf(TEXT("shipped: the check finds its man (outcome %d), a stumble or a knockdown"), Ship.Outcome), Ship.Outcome >= UJamSim::ContactStumble && !Ship.bCross);
	TestTrue(*FString::Printf(TEXT("shipped: the contact comes at the wind-up's end (frame %d, wind-up %d)"), Ship.ContactFrame, Ship.Wu), Ship.ContactFrame >= Ship.Wu - 2 && Ship.ContactFrame <= Ship.Wu + 1);
	TestTrue(*FString::Printf(TEXT("shipped: the pull moves the root at most check_pull_m / wind-up a frame (%.3f m)"), Ship.MaxStep), Ship.MaxStep <= 1.0 / FMath::Max(1, Ship.Wu) + 0.02);
	// 2. The size is by speed: standing, a man 1.3 m ahead (gap 0.5 m): the pull brings the bodies together and it is a bump.
	{
		const FOut S = Scene(*this, false, 0.0, 1.3, 0.0, 1);
		if (!S.bOk) return false;
		TestTrue(*FString::Printf(TEXT("standing: a bump, not a hit (outcome %d)"), S.Outcome), S.Outcome == UJamSim::ContactBump);
	}
	// 3. A press at a man 5.5 m away, standing: nothing.
	{
		const FOut S = Scene(*this, false, 0.0, 5.5, 0.0, 1);
		if (!S.bOk) return false;
		TestTrue(*FString::Printf(TEXT("a press at a man 5.5 m away whiffs (outcome %d)"), S.Outcome), S.Outcome == 0);
	}
	// 4. A cross-check at 3 m/s at a man WITHOUT the puck 1.6 m ahead (past arm's length): shipped, the shove lands at the wind-up's end; neutral, nothing.
	{
		const FOut S = Scene(*this, false, 3.0, 1.6, 0.0, 2), Nn = Scene(*this, true, 3.0, 1.6, 0.0, 2);
		if (!S.bOk || !Nn.bOk) return false;
		TestTrue(*FString::Printf(TEXT("shipped: the cross-check shoves the man without the puck (outcome %d, cross %d)"), S.Outcome, S.bCross ? 1 : 0), S.Outcome >= UJamSim::ContactStumble && S.bCross);
		TestTrue(*FString::Printf(TEXT("shipped: on the wind-up's last frame (frame %d, wind-up %d)"), S.ContactFrame, S.Wu), S.ContactFrame == S.Wu);
		TestTrue(*FString::Printf(TEXT("neutral: no shove on a man without the puck (outcome %d cross %d)"), Nn.Outcome, Nn.bCross ? 1 : 0), !(Nn.bCross && Nn.Outcome > 0));
	}
	// 5. Lane A209 wave 3: the press buffered. LMB at nobody on frame 0 (the lift's 30-frame cooldown starts), LMB again on frame 25 (5 frames before it
	// ends): shipped, the cross-check swings on frame 30 (the first free frame, LiftBufferLeft); neutral, the second press is dropped.
	for (int32 Arm = 0; Arm < 2; ++Arm)
	{
		TArray<FString> Errors;
		UJamCartridge* C = UJamCartridge::LoadFromFile(UJamCartridge::ResolveCartridgePath(TEXT("hockey.regular")), Errors);
		if (!C) return false;
		FJamGameConfig Cfg = C->Game;
		if (Arm == 1) { Cfg.Contact.CheckPullM = 0.0; Cfg.Contact.bCrossAnyMan = false; Cfg.Contact.CheckReachM = 0.0; }
		UJamSim* Sim = NewObject<UJamSim>();
		Sim->Init(Cfg, 7);
		Sim->SkipFaceoff();
		const int32 A = Sim->GetHumanIndex();
		Sim->SetPuck(FVector2D(-20.0, 12.0), FVector2D::ZeroVector);
		Sim->SetSkater(A, FVector2D(0.0, -8.0), FVector2D::ZeroVector, 0.0);
		int32 SecondSwing = -1;
		for (int32 F = 0; F < 40; ++F)
		{
			TArray<FJamInput> In;
			In.SetNum(Sim->GetSkaters().Num());
			In[A].bLift = F == 0 || F == 25;
			Sim->Step(In);
			if (F > 0 && SecondSwing < 0 && Sim->GetSkaters()[A].bLiftThisFrame) SecondSwing = F;
		}
		AddInfo(FString::Printf(TEXT("JAMHIT buffer %s: the second swing on frame %d"), Arm == 0 ? TEXT("shipped") : TEXT("neutral"), SecondSwing));
		if (Arm == 0) TestTrue(*FString::Printf(TEXT("shipped: the press inside the cooldown's last frames swings when it ends (frame %d)"), SecondSwing), SecondSwing >= 29 && SecondSwing <= 31);
		else TestTrue(*FString::Printf(TEXT("neutral: the press inside the cooldown is dropped (frame %d)"), SecondSwing), SecondSwing < 0);
	}
	return true;
}

// Lane A209 (the fault of 23:50, Jam.Controls.FirstFiveMinutes seed 3): a short LMB tap never braces. The mapping sends the brace's level from its 4th
// step; the sim braces after 10 frames of it. Before the fix a brace held into a goal kept its count (StepCrossHold does not run in the pause or the
// faceoff), the release was never seen, and a tap pressed in the countdown braced on the first frame of play.
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamTapNeverBraces, "Jam.Core.Contact.TapNeverBraces", JamHitLandsTests::Flags)
bool FJamTapNeverBraces::RunTest(const FString& Parameters)
{
	for (int32 Arm = 0; Arm < 3; ++Arm)
	{
		TArray<FString> Errors;
		UJamCartridge* C = UJamCartridge::LoadFromFile(UJamCartridge::ResolveCartridgePath(TEXT("hockey.regular")), Errors);
		if (!C) return false;
		FJamGameConfig Cfg = C->Game;
		Cfg.Rules.bPenalties = false;
		UJamSim* Sim = NewObject<UJamSim>();
		Sim->Init(Cfg, 11);
		Sim->SkipFaceoff();
		const int32 A = Sim->GetHumanIndex();
		const int32 Team = Sim->GetSkaters()[A].Team;
		Sim->SetSkater(A, FVector2D(0.0, -10.0), FVector2D::ZeroVector, 0.0);
		bool bBracedBefore = false, bBracedOnTap = false, bSawPause = false;
		int32 TapLeft = -1, TapFrames = 0;
		for (int32 F = 0; F < 900 && TapLeft != 0; ++F)
		{
			TArray<FJamInput> In;
			In.SetNum(Sim->GetSkaters().Num());
			const EJamSimPhase Ph = Sim->GetPhase();
			if (Arm == 0)
			{
				// a brace held into a goal: held 30 frames, the goal scored on frame 20, released in the pause; a 6-frame level on the first frames of play
				if (F == 20) { const double Gx = Sim->AttackGoalX(Team); Sim->SetPuck(FVector2D(Gx - FMath::Sign(Gx) * 1.0, 0.0), FVector2D(FMath::Sign(Gx) * 20.0, 0.0)); }
				if (Ph != EJamSimPhase::Playing) bSawPause = true;
				if (TapLeft < 0 && bSawPause && Ph == EJamSimPhase::Playing) TapLeft = 6;
				In[A].bCrossHold = F < 30 || TapLeft > 0;
			}
			else if (Arm == 2)
			{
				// a change of possession under the hold: held 20 frames (braced), the puck on his blade frames 20 to 40 (he carries: the brace ends), let go
				// on frame 40 with the puck taken away, a 6-frame level from frame 45
				if (F >= 20 && F < 40) Sim->SetPuck(Sim->GetSkaters()[A].BladePos, Sim->GetSkaters()[A].Vel);
				if (F == 40) Sim->SetPuck(FVector2D(-20.0, 12.0), FVector2D::ZeroVector);
				if (F >= 45 && TapLeft < 0) TapLeft = 6;
				In[A].bCrossHold = F < 40 || (F >= 45 && TapLeft > 0);
			}
			else
			{
				// a release, then a tap: held 20 frames (braced), let go 5, a 6-frame level
				if (F >= 25 && TapLeft < 0) TapLeft = 6;
				In[A].bCrossHold = F < 20 || (F >= 25 && TapLeft > 0);
			}
			Sim->Step(In);
			const FJamSkaterState& H = Sim->GetSkaters()[A];
			if (TapLeft > 0) { if (H.bCrossBraced) bBracedOnTap = true; --TapLeft; ++TapFrames; }
			else if (TapLeft < 0 && H.bCrossBraced) bBracedBefore = true;
		}
		const TCHAR* Name = Arm == 0 ? TEXT("a brace held into a goal, a tap after the faceoff") : Arm == 2 ? TEXT("a brace through a change of possession, let go, a tap 5 frames later") : TEXT("a brace let go, a tap 5 frames later");
		AddInfo(FString::Printf(TEXT("JAMBRACE %s: braced before %d, tap frames %d, braced on the tap %d"), Name, bBracedBefore ? 1 : 0, TapFrames, bBracedOnTap ? 1 : 0));
		TestTrue(*FString::Printf(TEXT("%s: the long hold braced (the scene is real)"), Name), bBracedBefore);
		TestTrue(*FString::Printf(TEXT("%s: the tap ran its 6 frames"), Name), TapFrames == 6);
		TestFalse(*FString::Printf(TEXT("%s: a tap never braces"), Name), bBracedOnTap);
	}
	return true;
}

// Lane A215 (track F1, the eye's list 2 item 4; game.contact.cross_live_frames): the pressed cross-check's stick stays live after its wind-up. The human stands
// facing +x and presses LMB on frame 0 at a man 2.0 m ahead (inside the press's reach, outside the shove's); the man is held 2.2 m ahead of him (out of the
// shove's reach) until frame InFrom, then 1.2 m ahead (inside it). Shipped (10 frames): a man back in reach on frames 9 to 18 takes the shove; neutral (0):
// the single frame 8 finds nobody and nothing lands; a man back in reach after the window (frame 20) is a miss either way; a second man who comes into
// reach while the first stays away takes it (the first man met).
namespace JamHitLandsTests
{
	struct FLive { bool bOk = false; int32 Frame = -1; int32 Who = -1; int32 Outcome = 0; int32 V = -1, W = -1; };

	FLive LiveScene(FAutomationTestBase& T, int32 LiveFrames, int32 InFrom, bool bOther)
	{
		FLive O;
		TArray<FString> Errors;
		UJamCartridge* C = UJamCartridge::LoadFromFile(UJamCartridge::ResolveCartridgePath(TEXT("hockey.regular")), Errors);
		if (!C) { T.AddError(TEXT("hockey.regular does not load")); return O; }
		FJamGameConfig Cfg = C->Game;
		Cfg.Rules.bPenalties = false;
		if (LiveFrames >= 0) Cfg.Contact.CrossLiveFrames = LiveFrames;
		UJamSim* Sim = NewObject<UJamSim>();
		Sim->Init(Cfg, 7);
		Sim->SkipFaceoff();
		const int32 A = Sim->GetHumanIndex();
		const int32 Team = Sim->GetSkaters()[A].Team;
		for (const FJamSkaterState& K : Sim->GetSkaters()) if (K.Team != Team) { if (O.V < 0) O.V = K.Index; else if (O.W < 0) O.W = K.Index; }
		if (O.V < 0 || O.W < 0) { T.AddError(TEXT("two opponents wanted")); return O; }
		const double Hx = Cfg.Rink.LengthM * 0.5 - 4.0, Hz = Cfg.Rink.WidthM * 0.5 - 3.0;
		int32 N = 0;
		for (const FJamSkaterState& K : Sim->GetSkaters())
		{
			if (K.Index == A || K.Index == O.V || K.Index == O.W) continue;
			Sim->SetSkater(K.Index, FVector2D(-Hx + 2.5 * N, (N % 2 ? 1.0 : -1.0) * Hz), FVector2D::ZeroVector, 0.0);
			++N;
		}
		Sim->SetPuck(FVector2D(-20.0, 12.0), FVector2D::ZeroVector);
		Sim->SetSkater(A, FVector2D::ZeroVector, FVector2D::ZeroVector, 0.0);
		for (int32 F = 0; F < 40; ++F)
		{
			const FVector2D Me = Sim->GetSkaters()[A].Pos;
			// the aimed man: 2.0 m ahead at the press, 2.2 m until InFrom (bOther: always 2.2 m), then 1.2 m; the other man far aside, or 1.2 m ahead and 0.3 m aside from InFrom
			const double Va = F == 0 ? 2.0 : (!bOther && F >= InFrom ? 1.2 : 2.2);
			Sim->SetSkater(O.V, Me + FVector2D(Va, 0.0), FVector2D::ZeroVector, PI);
			Sim->SetSkater(O.W, bOther && F >= InFrom ? Me + FVector2D(1.2, 0.3) : FVector2D(Hx, Hz), FVector2D::ZeroVector, PI);
			TArray<FJamInput> In;
			In.SetNum(Sim->GetSkaters().Num());
			In[A].Stick = FVector2D(1.0, 0.0);
			In[A].bLift = F == 0;
			Sim->Step(In);
			for (const int32 X : { O.V, O.W })
			{
				const FJamSkaterState& Sx = Sim->GetSkaters()[X];
				if (O.Frame < 0 && Sx.ContactBy == A && Sx.ContactOutcome > 0 && Sx.bContactCross) { O.Frame = F; O.Who = X; O.Outcome = Sx.ContactOutcome; }
			}
		}
		O.bOk = true;
		T.AddInfo(FString::Printf(TEXT("JAMHIT live %d, in reach from frame %d%s: the shove on frame %d on %s, outcome %d"), LiveFrames, InFrom, bOther ? TEXT(" (the other man)") : TEXT(""),
			O.Frame, O.Who == O.V ? TEXT("the aimed man") : O.Who == O.W ? TEXT("the other man") : TEXT("nobody"), O.Outcome));
		return O;
	}
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamHitCrossLive, "Jam.Core.Contact.CrossLive", JamHitLandsTests::Flags)
bool FJamHitCrossLive::RunTest(const FString& Parameters)
{
	using namespace JamHitLandsTests;
	TArray<FString> Errors;
	if (UJamCartridge* C = UJamCartridge::LoadFromFile(UJamCartridge::ResolveCartridgePath(TEXT("hockey.regular")), Errors))
		TestEqual(TEXT("game.contact.cross_live_frames ships at 10"), C->Game.Contact.CrossLiveFrames, 10);
	const FLive Ship = LiveScene(*this, -1, 11, false), Neut = LiveScene(*this, 0, 11, false), Late = LiveScene(*this, -1, 20, false), Other = LiveScene(*this, -1, 12, true);
	if (!Ship.bOk || !Neut.bOk || !Late.bOk || !Other.bOk) return false;
	TestTrue(*FString::Printf(TEXT("shipped: the man back in reach on frame 11 takes the shove (frame %d, outcome %d)"), Ship.Frame, Ship.Outcome), Ship.Who == Ship.V && Ship.Frame == 11 && Ship.Outcome >= UJamSim::ContactStumble);
	TestTrue(*FString::Printf(TEXT("neutral: the single frame finds nobody (frame %d)"), Neut.Frame), Neut.Frame < 0);
	TestTrue(*FString::Printf(TEXT("shipped: back in reach on frame 20, after the window: a miss (frame %d)"), Late.Frame), Late.Frame < 0);
	TestTrue(*FString::Printf(TEXT("shipped: the first man met takes it (the other man, frame %d)"), Other.Frame), Other.Who == Other.W && Other.Frame == 12);
	return true;
}

// Lane A215 (the Director's ruling of 02:39; game.contact.cross_back_human): the human's tap into a carrier's back. The carrier skates away (+x, 3 m/s) with
// the puck on his blade; the presser stands 1.5 m behind him facing his back and taps LMB on frame 0. Shipped: the carrier stumbles (never more) and the puck
// is off his blade; neutral (false): the puck stays (A125's stick-only shove from behind is tonight's game); a bot that taps the same: a bump at most; the human
// holding LMB (a hold, not a tap): no strip, a stumble at most.
namespace JamHitLandsTests
{
	struct FBack { bool bOk = false; int32 Outcome = 0; bool bCross = false; bool bKept = true; int32 Grace = 0; };

	FBack BackScene(FAutomationTestBase& T, bool bKey, bool bBot, bool bHold, int32 Warm = 50)
	{
		FBack O;
		TArray<FString> Errors;
		UJamCartridge* C = UJamCartridge::LoadFromFile(UJamCartridge::ResolveCartridgePath(TEXT("hockey.regular")), Errors);
		if (!C) { T.AddError(TEXT("hockey.regular does not load")); return O; }
		FJamGameConfig Cfg = C->Game;
		Cfg.Rules.bPenalties = false;
		Cfg.Contact.bCrossBackHuman = bKey;
		UJamSim* Sim = NewObject<UJamSim>();
		Sim->Init(Cfg, 7);
		Sim->SkipFaceoff();
		const int32 H = Sim->GetHumanIndex();
		const int32 Team = Sim->GetSkaters()[H].Team;
		int32 V = -1, M = -1;
		for (const FJamSkaterState& K : Sim->GetSkaters()) { if (K.Team != Team && V < 0) V = K.Index; if (K.Team == Team && K.Index != H && M < 0) M = K.Index; }
		if (V < 0 || M < 0) { T.AddError(TEXT("a mate and an opponent wanted")); return O; }
		const int32 A = bBot ? M : H;
		const double Hx = Cfg.Rink.LengthM * 0.5 - 4.0, Hz = Cfg.Rink.WidthM * 0.5 - 3.0;
		int32 N = 0;
		for (const FJamSkaterState& K : Sim->GetSkaters())
		{
			if (K.Index == A || K.Index == V) continue;
			Sim->SetSkater(K.Index, FVector2D(-Hx + 2.5 * N, (N % 2 ? 1.0 : -1.0) * Hz), FVector2D::ZeroVector, 0.0);
			++N;
		}
		Sim->SetSkater(A, FVector2D(-6.0, 0.0), FVector2D(3.0, 0.0), 0.0);
		Sim->SetSkater(V, FVector2D(-4.5, 0.0), FVector2D(3.0, 0.0), 0.0);
		Sim->SetPuck(FVector2D(-4.5 + 0.6, 0.0), FVector2D(3.0, 0.0));
		Sim->ClearReleaseGrace(V);
		// he takes the puck first (the pickup by touch), then the presser is set 1.5 m behind him at his speed, past the take grace (stick.take_grace_frames 30: inside it the stick is refused and A125's stick-only widening shoves from any side, for everyone)
		for (int32 F = 0; F < Warm; ++F)
		{
			TArray<FJamInput> In;
			In.SetNum(Sim->GetSkaters().Num());
			In[V].Move = FVector2D(0.3, 0.0);
			In[V].Stick = FVector2D(0.5, 0.0);
			Sim->Step(In);
		}
		{
			const FJamSkaterState& Sv = Sim->GetSkaters()[V];
			Sim->SetSkater(A, Sv.Pos - FVector2D(1.5, 0.0), Sv.Vel, 0.0);
		}
		if (Sim->CarrierIndex() != V) { T.AddError(FString::Printf(TEXT("the opponent is not the carrier at the press (carrier %d)"), Sim->CarrierIndex())); return O; }
		for (int32 F = 0; F < 30; ++F)
		{
			TArray<FJamInput> In;
			In.SetNum(Sim->GetSkaters().Num());
			In[V].Move = FVector2D(0.3, 0.0);
			In[V].Stick = FVector2D(0.5, 0.0);
			In[A].Move = FVector2D(0.3, 0.0);
			In[A].Stick = FVector2D(1.0, 0.0);
			In[A].bLift = F == 0;
			In[A].bCrossHold = bHold;
			Sim->Step(In);
			const FJamSkaterState& Sv = Sim->GetSkaters()[V];
			if (Sv.ContactBy == A && Sv.bContactCross && Sv.ContactOutcome > O.Outcome) { O.Outcome = Sv.ContactOutcome; O.bCross = true; }
		}
		O.bKept = Sim->CarrierIndex() == V;
		O.Grace = Warm;
		O.bOk = true;
		T.AddInfo(FString::Printf(TEXT("JAMHIT back key %d %s%s: outcome %d cross %d, the carrier kept the puck %d"), bKey ? 1 : 0, bBot ? TEXT("bot") : TEXT("human"), bHold ? TEXT(" holding") : TEXT(""), O.Outcome, O.bCross ? 1 : 0, O.bKept ? 1 : 0));
		return O;
	}
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamHitCrossBack, "Jam.Core.Contact.CrossBack", JamHitLandsTests::Flags)
bool FJamHitCrossBack::RunTest(const FString& Parameters)
{
	using namespace JamHitLandsTests;
	TArray<FString> Errors;
	if (UJamCartridge* C = UJamCartridge::LoadFromFile(UJamCartridge::ResolveCartridgePath(TEXT("hockey.regular")), Errors))
		TestTrue(TEXT("game.contact.cross_back_human ships true"), C->Game.Contact.bCrossBackHuman);
	const FBack Ship = BackScene(*this, true, false, false), Neut = BackScene(*this, false, false, false), Bot = BackScene(*this, true, true, false), Hold = BackScene(*this, true, false, true);
	if (!Ship.bOk || !Neut.bOk || !Bot.bOk || !Hold.bOk) return false;
	TestTrue(*FString::Printf(TEXT("shipped: the human's tap in the carrier's back is a stumble, never more (outcome %d)"), Ship.Outcome), Ship.bCross && Ship.Outcome == UJamSim::ContactStumble);
	TestFalse(TEXT("shipped: the puck is off his blade"), Ship.bKept);
	// neutral = tonight's game: from behind the carrier's body shields the puck (stick.body_shield), the stick is refused, and A125's stick-only widening lets the
	// shove land from behind (uncapped, bots too): the puck stays his
	TestTrue(*FString::Printf(TEXT("neutral: no strip from behind (outcome %d, the A125 shove)"), Neut.Outcome), Neut.bKept);
	TestTrue(*FString::Printf(TEXT("a bot's tap from behind stays the stick lift (outcome %d)"), Bot.Outcome), !Bot.bCross);
	TestTrue(*FString::Printf(TEXT("a hold is not a tap: no strip, a stumble at most (outcome %d)"), Hold.Outcome), Hold.bKept && Hold.Outcome <= UJamSim::ContactStumble);
	// the ruling of 04:05: pressed 20 frames after the carrier took the puck his stick is refused (the scene where A125's stick-only widening shoved from behind
	// in every arm before): the human's tap is a stumble at most; a bot's is a bump at most
	const FBack HG = BackScene(*this, true, false, false, 20), BG = BackScene(*this, true, true, false, 20);
	if (!HG.bOk || !BG.bOk) return false;
	TestTrue(*FString::Printf(TEXT("stick refused: the human's tap is a stumble at most (outcome %d)"), HG.Outcome), HG.bCross && HG.Outcome == UJamSim::ContactStumble);
	TestTrue(*FString::Printf(TEXT("stick refused: a bot's tap from behind is a bump at most (outcome %d)"), BG.Outcome), BG.Outcome <= UJamSim::ContactBump);
	return true;
}

#endif
