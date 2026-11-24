// Third Life rink core: thirdjam's button-rule tests (Jam.Controls.*) re-typed against our port of the rules (native/glue/rink_gamemode.*).
// The tests live in thirdjam's JamGame module (Game/Source/JamGame/Private/ControlsTests.cpp, HEAD 8dc713c6), which needs Unreal's
// Enhanced Input, Slate and the game mode, so they cannot be compiled here as they are. The game stays byte for byte; this file is
// test code: each test below cites the lines it re-types and keeps their assertions, staging and numbers. What could not be kept
// (an Unreal-only part, or a console variable the port ships fixed) is named at the test as "not here:".
//   rinktest-thirdjam.exe <content dir> TL.Controls
#include "CoreMinimal.h"
#include "Misc/AutomationTest.h"
#include "JamSim.h"
#include "JamCartridge.h"
#include "rink_gamemode.h"
#include <algorithm>

#if WITH_DEV_AUTOMATION_TESTS

using namespace RinkGlue;

namespace TlControlsTests
{
	constexpr EAutomationTestFlags Flags = EAutomationTestFlags_ApplicationContextMask | EAutomationTestFlags::ProductFilter;
	const std::wstring LMB = L"LeftMouseButton", RMB = L"RightMouseButton", MMB = L"MiddleMouseButton", M4 = L"ThumbMouseButton", Q = L"Q",
		RT = L"Gamepad_RightTriggerAxis", RB = L"Gamepad_RightShoulder", LB = L"Gamepad_LeftShoulder", X = L"Gamepad_FaceButton_Left";

	// ControlsTests.cpp:37-45 (LoadRegular)
	bool LoadRegular(FAutomationTestBase& T, FJamGameConfig& Out)
	{
		TArray<FString> Errors;
		UJamCartridge* C = UJamCartridge::LoadFromFile(UJamCartridge::ResolveCartridgePath(TEXT("hockey.regular")), Errors);
		for (const FString& E : Errors) T.AddError(FString::Printf(TEXT("hockey.regular: %s"), *E));
		if (!C) return false;
		Out = C->Game;
		return true;
	}

	// JamControls::ApplyButtons (InputMapping.cpp:488-503) as the port runs it: FHumanControls::Read resolves the buttons by this frame's
	// ButtonContext and writes them; only the button fields are kept (ApplyButtons writes nothing else).
	struct FHand
	{
		FHumanControls Hc;
		std::vector<std::wstring> Down, PrevDown;
		void Button(const std::wstring& K, bool bDown)
		{
			auto It = std::find(Down.begin(), Down.end(), K);
			if (bDown && It == Down.end()) Down.push_back(K);
			if (!bDown && It != Down.end()) Down.erase(It);
		}
		void Apply(const UJamSim& Sim, int32 Me, FJamInput& In)
		{
			FRawInput R;
			R.Down = Down;
			for (const std::wstring& K : Down) if (std::find(PrevDown.begin(), PrevDown.end(), K) == PrevDown.end()) R.Pressed.push_back(K);
			PrevDown = Down;
			const FJamInput Got = Hc.Read(R, Sim, Me);
			In.bShootHeld = Got.bShootHeld;
			In.bPassHeld = Got.bPassHeld;
			In.bCheck = Got.bCheck;
			In.bLift = Got.bLift;
			In.bCrossHold = Got.bCrossHold;
		}
	};

	// ControlsTests.cpp:694-722 (FPhase, FPhaseOut, RunHand)
	struct FPhase { const TCHAR* Name; int32 Frames; bool bWith; bool bCarrying; bool bInReach; bool bDown; };
	struct FPhaseOut { int32 Shoot = 0, Pass = 0, Cross = 0, Lift = 0, Check = 0, ShootPress = 0, PassPress = 0; bool bFireOnFall = false; };
	TArray<FPhaseOut> RunHand(const std::wstring& Key, const TArray<FPhase>& Phases, bool bRule)
	{
		const FBindings D = FBindings::Defaults();
		FButtonResolver R;
		TArray<FPhaseOut> Out;
		bool bWasDown = false, bShootUp = false, bPassUp = false;
		for (int32 P = 0; P < Phases.Num(); ++P)
		{
			const FPhase& Ph = Phases[P];
			FPhaseOut O;
			for (int32 F = 0; F < Ph.Frames; ++F)
			{
				if (Ph.bDown && !bWasDown) R.Press(Key);
				if (!Ph.bDown && bWasDown) R.Release(Key);
				bWasDown = Ph.bDown;
				FButtonContext C;
				C.bWith = Ph.bWith; C.bCarrying = Ph.bCarrying; C.bInReach = Ph.bInReach; C.bDeadAcrossChange = bRule;
				const FButtonVerbs V = R.Step(C, D);
				O.Shoot += V.bShootHeld; O.Pass += V.bPassHeld; O.Cross += V.bCrossHeld; O.Lift += V.bLift; O.Check += V.bCheck;
				O.ShootPress += V.bShootPress; O.PassPress += V.bPassPress;
				if (P > 0 && ((bShootUp && !V.bShootHeld) || (bPassUp && !V.bPassHeld)) && Ph.bInReach && Ph.bWith) O.bFireOnFall = true;
				bShootUp = V.bShootHeld; bPassUp = V.bPassHeld;
			}
			Out.Add(O);
		}
		return Out;
	}

	// ControlsTests.cpp:741-753 (GiveTo): the staged skater carries.
	bool GiveTo(UJamSim* Sim, int32 Who, TArray<FJamInput>& In, FHand* Pi, int32 Me)
	{
		for (int32 F = 0; F < 40 && Sim->CarrierIndex() != Who; ++F)
		{
			const FJamSkaterState& T = Sim->GetSkaters()[Who];
			Sim->SetPuck(T.Pos + T.Forward() * 0.45, T.Vel);
			if (Pi) { In[Me] = FJamInput(); Pi->Apply(*Sim, Me, In[Me]); }
			Sim->Step(In);
		}
		return Sim->CarrierIndex() == Who;
	}
}

using namespace TlControlsTests;

// ControlsTests.cpp:57-81. Not here: the Enhanced Input mapping context's slots and IsKeyMapped (Unreal input objects; the port has none).
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FTlControlsDefaults, "TL.Controls.Defaults", TlControlsTests::Flags)
bool FTlControlsDefaults::RunTest(const FString&)
{
	const FBindings D = FBindings::Defaults();
	TestTrue(TEXT("LMB: shoot with the puck, cross-check without"), D.WithVerbOn(LMB) == EVerb::Shoot && D.WithoutVerbOn(LMB) == EVerb::CrossCheck);
	TestTrue(TEXT("RMB: pass with the puck, check without"), D.WithVerbOn(RMB) == EVerb::Pass && D.WithoutVerbOn(RMB) == EVerb::Check);
	TestTrue(TEXT("RT: shoot / cross-check"), D.WithVerbOn(RT) == EVerb::Shoot && D.WithoutVerbOn(RT) == EVerb::CrossCheck);
	TestTrue(TEXT("RB: pass / check"), D.WithVerbOn(RB) == EVerb::Pass && D.WithoutVerbOn(RB) == EVerb::Check);
	TestTrue(TEXT("second bindings: Q passes, MMB and mouse 4 cross-check, X passes, LB cross-checks"), D.Has(EVerb::Pass, Q) && D.Has(EVerb::CrossCheck, MMB)
		&& D.Has(EVerb::CrossCheck, M4) && D.Has(EVerb::Pass, X) && D.Has(EVerb::CrossCheck, LB));
	return true;
}

// ControlsTests.cpp:83-134
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FTlControlsByPossession, "TL.Controls.ByPossession", TlControlsTests::Flags)
bool FTlControlsByPossession::RunTest(const FString&)
{
	const FBindings D = FBindings::Defaults();
	auto Tap = [&](const std::wstring& K, bool bWith) { FButtonResolver R; R.Press(K); return R.Step(bWith, D); };
	FButtonVerbs V = Tap(LMB, true);
	TestTrue(TEXT("LMB with the puck: the shot's held level, no cross-check"), V.bShootHeld && V.bShootPress && !V.bLift && !V.bCrossHeld && !V.bCheck && !V.bPassHeld);
	V = Tap(LMB, false);
	TestTrue(TEXT("LMB without the puck: the cross-check and its hold, no shot"), V.bLift && V.bCrossHeld && !V.bShootHeld && !V.bShootPress);
	V = Tap(RMB, true);
	TestTrue(TEXT("RMB with the puck: the pass's held level, no check"), V.bPassHeld && V.bPassPress && !V.bCheck);
	V = Tap(RMB, false);
	TestTrue(TEXT("RMB without the puck: the body check, no pass"), V.bCheck && !V.bPassHeld && !V.bPassPress);
	V = Tap(RT, true);
	TestTrue(TEXT("RT with the puck shoots"), V.bShootHeld && !V.bLift);
	V = Tap(RT, false);
	TestTrue(TEXT("RT without cross-checks"), V.bLift && V.bCrossHeld);
	V = Tap(RB, true);
	TestTrue(TEXT("RB with the puck passes"), V.bPassHeld && !V.bCheck);
	V = Tap(RB, false);
	TestTrue(TEXT("RB without checks"), V.bCheck && !V.bPassHeld);
	V = Tap(MMB, true);
	TestTrue(TEXT("MMB (cross-check only) with the puck is still the cross-check"), V.bLift && !V.bShootHeld);
	V = Tap(Q, false);
	TestTrue(TEXT("Q (pass only) without the puck is still the pass"), V.bPassHeld && !V.bCheck);
	{
		FButtonResolver R;
		R.Press(LMB);
		const FButtonVerbs A = R.Step(false, D), B = R.Step(false, D), C = R.Step(false, D);
		TestTrue(TEXT("a held cross-check: one edge, the hold every frame"), A.bLift && !B.bLift && !C.bLift && A.bCrossHeld && B.bCrossHeld && C.bCrossHeld);
		R.Release(LMB);
		const FButtonVerbs E = R.Step(false, D);
		TestTrue(TEXT("released: no hold"), !E.bCrossHeld && !E.bLift);
	}
	{
		FButtonResolver R;
		R.Press(LMB);
		R.Release(LMB);
		const FButtonVerbs A = R.Step(true, D), B = R.Step(true, D);
		TestTrue(TEXT("a tap inside one step is one frame of the shot's level (a flat shot on its release)"), A.bShootHeld && !B.bShootHeld);
	}
	return true;
}

// ControlsTests.cpp:136-226. Not here: jam.ctrl.OurPuckShoots 0 (the port ships the cvar's value 1 fixed: GAMEMODE.md).
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FTlControlsOutlivesPossession, "TL.Controls.PressOutlivesPossession", TlControlsTests::Flags)
bool FTlControlsOutlivesPossession::RunTest(const FString&)
{
	const FBindings D = FBindings::Defaults();
	{
		FButtonResolver R;
		R.Press(LMB);
		const FButtonVerbs A = R.Step(true, D);
		const FButtonVerbs B = R.Step(false, D);
		TestTrue(TEXT("a shot begun with the puck dies when the puck leaves: no level, never a cross-check"), A.bShootHeld && !B.bShootHeld && !B.bLift && !B.bCrossHeld
			&& B.DeadNow == EVerb::Shoot && R.ActiveVerb(LMB) == EVerb::Count);
		R.Release(LMB);
		const FButtonVerbs C = R.Step(false, D);
		TestTrue(TEXT("its release does nothing"), !C.bShootHeld && !C.bLift);
		R.Press(LMB);
		const FButtonVerbs E = R.Step(false, D);
		TestTrue(TEXT("the next press, without the puck, is the cross-check"), E.bLift && E.bCrossHeld && !E.bShootHeld);
	}
	{
		FButtonResolver R;
		R.Press(RMB);
		const FButtonVerbs A = R.Step(true, D);
		const FButtonVerbs B = R.Step(false, D);
		TestTrue(TEXT("a pass begun with the puck dies when the puck leaves (lane A199), never a check"), A.bPassHeld && !B.bPassHeld && !B.bCheck && B.DeadNow == EVerb::Pass);
	}
	{
		FButtonResolver R;
		R.Press(LMB);
		const FButtonVerbs A = R.Step(false, D);
		const FButtonVerbs B = R.Step(true, D);
		TestTrue(TEXT("a cross-check begun without the puck is no shot when the puck arrives, and its brace ends (lane A199)"), A.bLift && !B.bShootHeld && !B.bShootPress && !B.bCrossHeld
			&& B.DeadNow == EVerb::CrossCheck);
	}
	FJamGameConfig Cfg;
	if (!LoadRegular(*this, Cfg)) return false;
	UJamSim* Sim = NewObject<UJamSim>();
	Sim->Init(Cfg, 1);
	Sim->SkipFaceoff();
	TArray<FJamInput> In;
	In.Init(FJamInput(), Sim->GetSkaters().Num());
	const FJamSkaterState& H = Sim->GetSkaters()[0];
	for (int32 F = 0; F < 30 && Sim->CarrierIndex() != 0; ++F)
	{
		const FJamSkaterState& T = Sim->GetSkaters()[0];
		Sim->SetPuck(T.Pos + T.Forward() * 0.45, T.Vel);
		Sim->Step(In);
	}
	const int32 Carrier = Sim->CarrierIndex();
	AddInfo(FString::Printf(TEXT("JAMCTRL test carrier=%d last_touch=%d"), Carrier, Sim->GetPuck().LastTouch));
	if (TestEqual(TEXT("the staged human carries"), Carrier, 0))
	{
		TestTrue(TEXT("the carrier is 'with the puck'"), HasPuckForButtons(*Sim, 0));
		int32 Opp = -1;
		for (const FJamSkaterState& S : Sim->GetSkaters()) if (S.Team != H.Team) { Opp = S.Index; break; }
		if (TestTrue(TEXT("an opponent exists"), Opp >= 0)) TestFalse(TEXT("an opponent of the carrier is 'without'"), HasPuckForButtons(*Sim, Opp));
		FHand Pi;
		FJamInput A;
		Pi.Button(LMB, true);
		Pi.Apply(*Sim, 0, A);
		TestTrue(TEXT("ApplyButtons: the carrier's LMB is bShootHeld"), A.bShootHeld && !A.bLift);
		FHand Po;
		FJamInput B;
		Po.Button(LMB, true);
		if (Opp >= 0) { Po.Apply(*Sim, Opp, B); TestTrue(TEXT("ApplyButtons: the opponent's LMB is bLift"), B.bLift && !B.bShootHeld); }
	}
	{
		int32 Mate = -1;
		for (const FJamSkaterState& S : Sim->GetSkaters()) if (S.Team == H.Team && S.Index != 0) { Mate = S.Index; break; }
		if (Mate >= 0)
		{
			Sim->SetPuck(FVector2D(0.0, 0.0), FVector2D(12.0, 0.0));
			const bool bLoose = Sim->CarrierIndex() < 0 && Sim->GetPuck().LastTouch == 0;
			AddInfo(FString::Printf(TEXT("JAMCTRL test loose=%d last_touch=%d carrier=%d mate=%d"), bLoose ? 1 : 0, Sim->GetPuck().LastTouch, Sim->CarrierIndex(), Mate));
			if (bLoose) TestTrue(TEXT("our pass in flight: the mate is 'with the puck' (a one-timer's press is a shot)"), HasPuckForButtons(*Sim, Mate));
		}
	}
	return true;
}

// ControlsTests.cpp:228-263 (FBindings::Rebind is not ported: the second arm replays the same verbs, which is the test's claim: the sim sees verbs only)
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FTlControlsLockstepStream, "TL.Controls.RecordedStreamUnchanged", TlControlsTests::Flags)
bool FTlControlsLockstepStream::RunTest(const FString&)
{
	FJamGameConfig Cfg;
	if (!LoadRegular(*this, Cfg)) return false;
	auto Play = [&](int32 Frames)
	{
		UJamSim* Sim = NewObject<UJamSim>();
		Sim->Init(Cfg, 7);
		TArray<FJamInput> In;
		In.Init(FJamInput(), Sim->GetSkaters().Num());
		for (int32 F = 0; F < Frames; ++F)
		{
			In[0] = FJamInput();
			In[0].Move = FVector2D(1.0, (F / 60) % 2 ? 0.5 : -0.5);
			In[0].bShootHeld = (F % 90) > 60;
			In[0].bPassHeld = (F % 200) > 185;
			In[0].bCheck = (F % 150) == 75;
			In[0].bLift = (F % 170) == 33;
			Sim->Step(In);
		}
		return Sim->StateHash();
	};
	const uint64 A = Play(900), B = Play(900);
	AddInfo(FString::Printf(TEXT("JAMCTRL recorded stream hash first=%016llx second=%016llx"), A, B));
	TestEqual(TEXT("the recorded stream's hash does not move"), B, A);
	return true;
}

// ControlsTests.cpp:491-540. Not here: CursorAimFromRay / CursorAimFromHit (AHokejGameMode statics; the shell hands the ice point) and the two
// cvar reads (the port ships AimAnchor 1, AimAnchorSpeed 0.3 fixed).
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FTlControlsAimAnchor, "TL.Controls.AimAnchor", TlControlsTests::Flags)
bool FTlControlsAimAnchor::RunTest(const FString&)
{
	const FVector2D Sk(10.0, 5.0), Px(1100.0, 600.0);
	FAimAnchor A;
	FVector2D Got = A.Step(Px, Sk + FVector2D(2.5, 0.0), Sk, true, 0.3);
	TestTrue(TEXT("the first step aims at the cursor's ice point"), Got.Equals(Sk + FVector2D(2.5, 0.0), 1e-6));
	double WorstTurn = 0.0;
	for (int32 F = 1; F <= 30; ++F)
	{
		Got = A.Step(Px, Sk + FVector2D(2.5, 0.4 * F / 30.0), Sk, true, 0.3);
		WorstTurn = FMath::Max(WorstTurn, FMath::Abs(FMath::RadiansToDegrees(FMath::Atan2(Got.Y - Sk.Y, Got.X - Sk.X))));
	}
	TestTrue(TEXT("a still hand on a standing skater: the blade holds through the correction (0 deg)"), WorstTurn < 1e-6 && A.IsAnchored());
	Got = A.Step(Px + FVector2D(1.0, 0.0), Sk + FVector2D(2.5, 0.4), Sk, true, 0.3);
	TestTrue(TEXT("a moved pixel re-projects"), Got.Equals(Sk + FVector2D(2.5, 0.4), 1e-6) && !A.IsAnchored());
	FAimAnchor D;
	D.Step(Px, Sk + FVector2D(2.5, 0.0), Sk, true, 0.3);
	D.Step(Px + FVector2D(0.3, 0.0), Sk + FVector2D(2.5, 0.1), Sk, true, 0.3);
	TestTrue(TEXT("0.3 px: still anchored"), D.IsAnchored());
	Got = D.Step(Px + FVector2D(0.6, 0.0), Sk + FVector2D(2.5, 0.2), Sk, true, 0.3);
	TestTrue(TEXT("0.6 px from where the anchor began: re-projected"), !D.IsAnchored() && Got.Equals(Sk + FVector2D(2.5, 0.2), 1e-6));
	FAimAnchor M;
	M.Step(Px, Sk + FVector2D(2.5, 0.0), Sk, true, 0.3);
	const FVector2D Sk2 = Sk + FVector2D(1.0 / 60.0, 0.0);
	Got = M.Step(Px, Sk2 + FVector2D(2.5, 0.3), Sk2, true, 0.3);
	TestTrue(TEXT("a skating skater (1 m/s, over 0.3): re-projected"), !M.IsAnchored() && Got.Equals(Sk2 + FVector2D(2.5, 0.3), 1e-6));
	FAimAnchor O;
	O.Step(Px, Sk + FVector2D(2.5, 0.0), Sk, false, 0.3);
	Got = O.Step(Px, Sk + FVector2D(2.5, 0.3), Sk, false, 0.3);
	TestTrue(TEXT("jam.ctrl.AimAnchor 0: re-projected every step"), Got.Equals(Sk + FVector2D(2.5, 0.3), 1e-6));
	return true;
}

// ControlsTests.cpp:542-587 (JAM_INPUT_HAS_CROSS_HOLD is 1 on HEAD, InputMapping.h:171; SetCrossHold writes FJamInput::bCrossHold)
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FTlControlsHeldCrossCheck, "TL.Controls.HeldCrossCheck", TlControlsTests::Flags)
bool FTlControlsHeldCrossCheck::RunTest(const FString&)
{
	FJamGameConfig Cfg;
	if (!LoadRegular(*this, Cfg)) return false;
	Cfg.Stick.PickupRingM = 0.0;
	UJamSim* Sim = NewObject<UJamSim>();
	Sim->Init(Cfg, 1);
	Sim->SkipFaceoff();
	const int32 Me = Sim->GetHumanIndex();
	int32 Opp = -1;
	for (const FJamSkaterState& S : Sim->GetSkaters()) if (S.Team != Sim->GetSkaters()[Me].Team) { Opp = S.Index; break; }
	if (!TestTrue(TEXT("an opponent"), Opp >= 0)) return false;
	for (const FJamSkaterState& S : Sim->GetSkaters()) if (S.Index != Me && S.Index != Opp) Sim->SetSkater(S.Index, FVector2D(-25.0, -10.0 + S.Index), FVector2D::ZeroVector, 0.0);
	Sim->SetSkater(Me, FVector2D(-9.0, 0.0), FVector2D(5.0, 0.0), 0.0);
	Sim->SetSkater(Opp, FVector2D(2.0, 0.0), FVector2D::ZeroVector, PI);
	Sim->ClearReleaseGrace(Opp);
	Sim->SetPuck(FVector2D(2.45, 0.0), FVector2D::ZeroVector);
	TArray<FJamInput> In;
	In.Init(FJamInput(), Sim->GetSkaters().Num());
	bool bDown = false;
	double Closing = 0.0;
	for (int32 F = 0; F < 240 && !bDown; ++F)
	{
		In[Me] = FJamInput();
		In[Me].Move = FVector2D(1.0, 0.0);
		In[Me].bLift = F == 0;
		In[Me].bCrossHold = true;
		Sim->Step(In);
		const FJamSkaterState& Hs = Sim->GetSkaters()[Me];
		const FJamSkaterState& O = Sim->GetSkaters()[Opp];
		if (Closing == 0.0 && FVector2D::Distance(Hs.Pos, O.Pos) <= UJamSim::SkaterRadius * 2.0 + 0.25) Closing = (Hs.Vel - O.Vel).Size();
		bDown = O.IsDown();
	}
	AddInfo(FString::Printf(TEXT("JAMCTRL held cross-check: down=%d closing=%.2f"), bDown ? 1 : 0, Closing));
	TestTrue(TEXT("held into a standing man at speed: he goes down"), bDown);
	return true;
}

// ControlsTests.cpp:756-822 (both rules: RunHand sets the context's bDeadAcrossChange itself; the jam.ctrl.HeldAcrossChange cvar read is not here)
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FTlControlsHeldAcrossChange, "TL.Controls.HeldAcrossChange", TlControlsTests::Flags)
bool FTlControlsHeldAcrossChange::RunTest(const FString&)
{
	struct FScene { int32 Id; const TCHAR* Name; bool bLeft; TArray<FPhase> Phases; };
	const TArray<FScene> Scenes = {
		{ 1, TEXT("held braced, takes the puck in the hit, loses it, still held; then let go and pressed without"), true, {
			{ TEXT("held without"), 20, false, false, false, true }, { TEXT("takes the puck"), 20, true, true, true, true },
			{ TEXT("loses it, still held"), 20, false, false, false, true }, { TEXT("let go"), 2, false, false, false, false }, { TEXT("pressed again"), 3, false, false, false, true } } },
		{ 2, TEXT("shot loading, stripped (out of reach), still held, puck back on his stick, let go"), true, {
			{ TEXT("loading with the puck"), 20, true, true, true, true }, { TEXT("stripped, held"), 10, false, false, false, true },
			{ TEXT("puck back, held"), 10, true, true, true, true }, { TEXT("let go"), 3, true, true, true, false } } },
		{ 3, TEXT("shot loading, stripped but the puck still in his reach, then out of it"), true, {
			{ TEXT("loading with the puck"), 20, true, true, true, true }, { TEXT("stripped, in reach"), 5, false, false, true, true },
			{ TEXT("out of reach, held"), 10, false, false, false, true }, { TEXT("let go"), 3, false, false, false, false } } },
		{ 4, TEXT("check called, passed to (our pass in flight, then on his stick), still held, let go, pressed again"), false, {
			{ TEXT("held without"), 5, false, false, false, true }, { TEXT("our pass in flight"), 10, true, false, false, true },
			{ TEXT("on his stick, held"), 20, true, true, true, true }, { TEXT("let go"), 2, true, true, true, false }, { TEXT("pressed again"), 3, true, true, true, true } } },
		{ 5, TEXT("saucer loading, stripped (out of reach), still held, puck back, let go"), false, {
			{ TEXT("loading with the puck"), 12, true, true, true, true }, { TEXT("stripped, held"), 10, false, false, false, true },
			{ TEXT("puck back, held"), 10, true, true, true, true }, { TEXT("let go"), 3, true, true, true, false } } } };
	for (const bool bPad : { false, true })
	{
		for (const FScene& Sc : Scenes)
		{
			const std::wstring Key = Sc.bLeft ? (bPad ? RT : LMB) : (bPad ? RB : RMB);
			const TArray<FPhaseOut> Before = RunHand(Key, Sc.Phases, false), After = RunHand(Key, Sc.Phases, true);
			const FString K(Key.c_str());
			switch (Sc.Id)
			{
			case 1:
				TestTrue(*FString::Printf(TEXT("%s: main re-braced after the loss (the leak measured)"), *K), Before[2].Cross == 20);
				TestTrue(*FString::Printf(TEXT("%s: braced while held without"), *K), After[0].Cross == 20 && After[0].Lift == 1);
				TestTrue(*FString::Printf(TEXT("%s: taking the puck ends the brace, no shot"), *K), After[1].Cross == 0 && After[1].Shoot == 0 && After[1].ShootPress == 0);
				TestTrue(*FString::Printf(TEXT("%s: losing it again under the same press does nothing"), *K), After[2].Cross == 0 && After[2].Lift == 0);
				TestTrue(*FString::Printf(TEXT("%s: the next press is a cross-check again"), *K), After[4].Lift == 1 && After[4].Cross == 3);
				break;
			case 2:
				TestTrue(*FString::Printf(TEXT("%s: main shot on the release with the old charge"), *K), Before[3].bFireOnFall);
				TestTrue(*FString::Printf(TEXT("%s: stripped, the held shot does nothing (no level, no cross-check)"), *K), After[1].Shoot == 0 && After[1].Lift == 0 && After[1].Cross == 0);
				TestTrue(*FString::Printf(TEXT("%s: the puck back under the same press: nothing, and the release fires nothing"), *K), After[2].Shoot == 0 && !After[3].bFireOnFall);
				break;
			case 3:
				TestTrue(*FString::Printf(TEXT("%s: stripped with the puck in reach: the dead level is held up (its fall would fire at the loose puck)"), *K), After[1].Shoot == 5);
				TestTrue(*FString::Printf(TEXT("%s: out of reach: the level falls and stays down"), *K), After[2].Shoot == 0 && After[3].Shoot == 0);
				break;
			case 4:
				TestTrue(*FString::Printf(TEXT("%s: passed to with a check held: one check on the press, no pass in either rule"), *K), Before[0].Check == 1 && After[0].Check == 1
					&& Before[2].Pass == 0 && After[2].Pass == 0 && After[1].Check == 0 && After[2].Check == 0 && !After[3].bFireOnFall);
				TestTrue(*FString::Printf(TEXT("%s: the next press passes"), *K), After[4].PassPress == 1 && After[4].Pass == 3);
				break;
			default:
				TestTrue(*FString::Printf(TEXT("%s: main passed on the release with the old charge"), *K), Before[3].bFireOnFall);
				TestTrue(*FString::Printf(TEXT("%s: stripped, the held pass does nothing; the release fires nothing"), *K), After[1].Pass == 0 && After[1].Check == 0 && After[2].Pass == 0 && !After[3].bFireOnFall);
				break;
			}
		}
	}
	return true;
}

// ControlsTests.cpp:824-874. Not here: main's rule arm (jam.ctrl.HeldAcrossChange 0; the port ships 1 fixed, so its ButtonContext has no switch):
// the shipped arm only, through the port's real input path (FHumanControls::Read).
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FTlControlsChangeInTheSim, "TL.Controls.HeldAcrossChangeInTheSim", TlControlsTests::Flags)
bool FTlControlsChangeInTheSim::RunTest(const FString&)
{
	FJamGameConfig Cfg;
	if (!LoadRegular(*this, Cfg)) return false;
	Cfg.Skater.bChargeDiesOnLoss = false;
	UJamSim* Sim = NewObject<UJamSim>();
	Sim->Init(Cfg, 1);
	Sim->SkipFaceoff();
	const int32 Me = Sim->GetHumanIndex();
	int32 Opp = -1;
	for (const FJamSkaterState& S : Sim->GetSkaters()) if (S.Team != Sim->GetSkaters()[Me].Team) { Opp = S.Index; break; }
	if (!TestTrue(TEXT("an opponent"), Opp >= 0)) return false;
	for (const FJamSkaterState& S : Sim->GetSkaters()) if (S.Index != Me && S.Index != Opp) Sim->SetSkater(S.Index, FVector2D(-25.0, -10.0 + S.Index), FVector2D::ZeroVector, 0.0);
	Sim->SetSkater(Me, FVector2D(0.0, 0.0), FVector2D::ZeroVector, 0.0);
	Sim->SetSkater(Opp, FVector2D(0.0, 8.0), FVector2D::ZeroVector, 0.0);
	TArray<FJamInput> In;
	In.Init(FJamInput(), Sim->GetSkaters().Num());
	FHand Pi;
	if (!TestTrue(TEXT("the human carries"), GiveTo(Sim, Me, In, &Pi, Me))) return false;
	Pi.Button(LMB, true);
	auto Steps = [&](int32 N) { for (int32 F = 0; F < N; ++F) { In[Me] = FJamInput(); Pi.Apply(*Sim, Me, In[Me]); Sim->Step(In); } };
	Steps(15);
	const int32 Charge = Sim->GetSkaters()[Me].ChargeFrames;
	const bool bTaken = GiveTo(Sim, Opp, In, &Pi, Me);
	Steps(3);
	const bool bBack = GiveTo(Sim, Me, In, &Pi, Me);
	Steps(3);
	const int32 Shots0 = Sim->GetSkaters()[Me].Shots;
	Pi.Button(LMB, false);
	Steps(10);
	const int32 ShotsBy = Sim->GetSkaters()[Me].Shots - Shots0;
	AddInfo(FString::Printf(TEXT("JAMCTRL A199 sim | rule 1 | charge %d before the take | taken %d | back %d | shots by the release %d |"), Charge, bTaken ? 1 : 0, bBack ? 1 : 0, ShotsBy));
	TestTrue(TEXT("the staging: charged, taken, back"), Charge > 4 && bTaken && bBack);
	TestEqual(TEXT("the shipped rule: the release after the change shoots nothing"), ShotsBy, 0);
	return true;
}

// ControlsTests.cpp:876-951. The pass part in both arms (the resolver with the delay ApplyButtons takes: 13 shipped, 0 neutral); the cross-check part
// in the shipped arm only (not here: BraceHoldFrames 0; the port ships 13 fixed), through the port's real input path.
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FTlControlsTapHold, "TL.Controls.TapAgainstHold", TlControlsTests::Flags)
bool FTlControlsTapHold::RunTest(const FString&)
{
	FJamGameConfig Cfg;
	if (!LoadRegular(*this, Cfg)) return false;
	const int32 Half = Cfg.Pass.SaucerHalfFrames;
	const int32 Lengths[] = { 1, 3, 6, 8, 9, 10, 12, 13, 16, 20 };
	for (const int32 Shipped : { 0, 1 })
	{
		for (const int32 N : Lengths)
		{
			FButtonResolver R;
			FButtonContext C;
			C.bWith = C.bCarrying = C.bInReach = true;
			// JamControls::SaucerHoldFrames (InputMapping.cpp:463-468): the cvar (13 shipped, 0 neutral) or the half, whichever is longer
			C.SaucerDelaySteps = FMath::Max(0, (Shipped ? FMath::Max(Half, 13) : Half) - Half);
			R.Press(RMB);
			int32 Charge = 0, Fired = -1;
			bool bUp = false;
			for (int32 F = 1; F <= N + 4; ++F)
			{
				if (F == N + 1) R.Release(RMB);
				const FButtonVerbs V = R.Step(C, FBindings::Defaults());
				if (V.bPassHeld) Charge = FMath::Min(Charge + 1, FMath::Max(Half, 1));
				if (bUp && !V.bPassHeld && Fired < 0) Fired = F;
				bUp = V.bPassHeld;
			}
			const bool bSaucer = Charge >= Half;
			const int32 SaucerFrom = Shipped ? 13 : Half;
			TestEqual(*FString::Printf(TEXT("%d frames: saucer iff held %d or more"), N, SaucerFrom), bSaucer, N >= SaucerFrom);
			const int32 Late = C.SaucerDelaySteps > 0 && N <= C.SaucerDelaySteps ? 1 : 0;
			TestTrue(*FString::Printf(TEXT("%d frames: the pass fires on the release's step (+%d), never before it"), N, Late), Fired == N + 1 + Late);
			if (!Shipped) continue;
			UJamSim* Sim = NewObject<UJamSim>();
			Sim->Init(Cfg, 1);
			Sim->SkipFaceoff();
			const int32 Me = Sim->GetHumanIndex();
			for (const FJamSkaterState& S : Sim->GetSkaters()) if (S.Index != Me) Sim->SetSkater(S.Index, FVector2D(-25.0, -10.0 + S.Index), FVector2D::ZeroVector, 0.0);
			Sim->SetSkater(Me, FVector2D(5.0, 0.0), FVector2D::ZeroVector, 0.0);
			Sim->SetPuck(FVector2D(20.0, 8.0), FVector2D::ZeroVector);
			TArray<FJamInput> In;
			In.Init(FJamInput(), Sim->GetSkaters().Num());
			// The delays the port's ButtonContext hands the resolver are thirdjam's (InputMapping.cpp:474-486 with the shipped cvars: SaucerHoldFrames 13,
			// BraceHoldFrames 13, HeldAcrossChange 1; ControlsTests.cpp:891-892 asserts they ship 13 and 13).
			{
				const FButtonContext Bc = ButtonContext(*Sim, Me);
				const int32 WantSaucer = Half > 0 && Cfg.Pass.PowerFullFrames <= 0 ? FMath::Max(0, FMath::Max(Half, 13) - Half) : 0;
				const int32 WantBrace = FMath::Max(0, FMath::Max(UJamSim::CrossHoldTapFrames, 13) - UJamSim::CrossHoldTapFrames);
				TestEqual(TEXT("the port's ButtonContext: the saucer's late start"), Bc.SaucerDelaySteps, WantSaucer);
				TestEqual(TEXT("the port's ButtonContext: the brace's late start"), Bc.BraceDelaySteps, WantBrace);
				TestTrue(TEXT("the port's ButtonContext: held across a change is dead (HeldAcrossChange ships 1)"), Bc.bDeadAcrossChange);
			}
			FHand Pi;
			Pi.Button(LMB, true);
			int32 Lifts = 0, Braced = 0, FirstBraced = -1;
			for (int32 F = 1; F <= N + 6; ++F)
			{
				if (F == N + 1) Pi.Button(LMB, false);
				In[Me] = FJamInput();
				Pi.Apply(*Sim, Me, In[Me]);
				Lifts += In[Me].bLift;
				Sim->Step(In);
				if (Sim->GetSkaters()[Me].bCrossBraced) { ++Braced; if (FirstBraced < 0) FirstBraced = F; }
			}
			AddInfo(FString::Printf(TEXT("JAMCTRL A199 hold | shipped 13/13 | %d frames | pass: charge %d, %s, fires on step %d | cross-check: presses %d, braced frames %d (from frame %d) |"),
				N, Charge, bSaucer ? TEXT("SAUCER") : TEXT("flat"), Fired, Lifts, Braced, FirstBraced));
			TestEqual(*FString::Printf(TEXT("%d frames: one cross-check press"), N), Lifts, 1);
			TestEqual(*FString::Printf(TEXT("%d frames: braced iff held 13 or more (from that frame)"), N), FirstBraced, N >= 13 ? 13 : -1);
		}
	}
	return true;
}

// ControlsTests.cpp:1220-1313 (the sim's own rule at the input the port sends). Not here: JamBaseline::MakeNeutral (JamGame).
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FTlControlsChargeDiesOnLoss, "TL.Controls.ChargeDiesOnLoss", TlControlsTests::Flags)
bool FTlControlsChargeDiesOnLoss::RunTest(const FString&)
{
	FJamGameConfig Base;
	if (!LoadRegular(*this, Base)) return false;
	TestTrue(TEXT("game.skater.charge_dies_on_loss ships true (absent from hockey.regular)"), Base.Skater.bChargeDiesOnLoss);
	for (const bool bPass : { false, true })
	{
		int32 ByRelease[2] = { -1, -1 };
		for (const bool bKey : { false, true })
		{
			FJamGameConfig Cfg = Base;
			Cfg.Skater.bChargeDiesOnLoss = bKey;
			UJamSim* Sim = NewObject<UJamSim>();
			Sim->Init(Cfg, 1);
			Sim->SkipFaceoff();
			const int32 Me = Sim->GetHumanIndex();
			int32 Opp = -1, Mate = -1;
			for (const FJamSkaterState& K : Sim->GetSkaters())
			{
				if (K.Team != Sim->GetSkaters()[Me].Team && Opp < 0) Opp = K.Index;
				if (K.Team == Sim->GetSkaters()[Me].Team && K.Index != Me && Mate < 0) Mate = K.Index;
			}
			if (!TestTrue(TEXT("an opponent and a teammate"), Opp >= 0 && Mate >= 0)) return false;
			const int32 N = Sim->GetSkaters().Num();
			for (int32 i = 0; i < N; ++i) Sim->SetSkater(i, FVector2D(-40.0 + i * 1.5, 19.0), FVector2D::ZeroVector, 0);
			Sim->SetSkater(Me, FVector2D::ZeroVector, FVector2D::ZeroVector, 0);
			Sim->SetSkater(Mate, FVector2D(4.0, -9.0), FVector2D::ZeroVector, UE_DOUBLE_PI * 0.5);
			Sim->SetPuck(FVector2D(0.45, 0.0), FVector2D::ZeroVector);
			TArray<FJamInput> In;
			In.SetNum(N);
			In[Me].Stick = FVector2D(1.0, 0.0);
			for (int32 i = 0; i < 8; ++i) Sim->Step(In);
			const bool bCarried = Sim->CarrierIndex() == Me;
			auto Hold = [&](bool bOn) { In[Me].bShootHeld = bOn && !bPass; In[Me].bPassHeld = bOn && bPass; };
			Hold(true);
			for (int32 i = 0; i < 15; ++i) Sim->Step(In);
			const int32 Charged = bPass ? Sim->GetSkaters()[Me].PassChargeFrames : Sim->GetSkaters()[Me].ChargeFrames;
			Sim->SetSkater(Opp, FVector2D(2.6, 0.0), FVector2D::ZeroVector, UE_DOUBLE_PI);
			In[Opp].Stick = (Sim->GetPuck().Pos - FVector2D(2.6, 0.0)).GetSafeNormal();
			In[Opp].bPoke = true;
			bool bTaken = false;
			for (int32 i = 0; i < Cfg.Stick.PokeWindowFrames + 2 && !bTaken; ++i)
			{
				Sim->Step(In);
				In[Opp].bPoke = false;
				bTaken = Sim->GetPuck().LastTouch == Opp;
			}
			In[Opp] = FJamInput();
			const int32 AfterStrip = bPass ? Sim->GetSkaters()[Me].PassChargeFrames : Sim->GetSkaters()[Me].ChargeFrames;
			Sim->SetSkater(Opp, FVector2D(6.0, 6.0), FVector2D::ZeroVector, UE_DOUBLE_PI);
			Sim->SetPuck(FVector2D(0.8, 0.0), FVector2D::ZeroVector);
			for (int32 i = 0; i < 4; ++i) Sim->Step(In);
			const double InReach = FVector2D::Distance(Sim->GetSkaters()[Me].Pos, Sim->GetPuck().Pos);
			const int32 Shots0 = Sim->GetSkaters()[Me].Shots, Passes0 = Sim->GetSkaters()[Me].Passes;
			Hold(false);
			for (int32 i = 0; i < 6; ++i) Sim->Step(In);
			ByRelease[bKey ? 1 : 0] = bPass ? Sim->GetSkaters()[Me].Passes - Passes0 : Sim->GetSkaters()[Me].Shots - Shots0;
			const int32 AfterRelease = bPass ? Sim->GetSkaters()[Me].PassChargeFrames : Sim->GetSkaters()[Me].ChargeFrames;
			TestTrue(TEXT("the staging: carried, charged, stripped by the poke"), bCarried && Charged > 4 && bTaken);
			TestTrue(TEXT("the puck is in his reach at the release"), InReach <= 1.6);
			if (bKey)
			{
				TestEqual(TEXT("the key on: the strip made the press dead (-1)"), AfterStrip, -1);
				TestEqual(TEXT("the key on: the release reset it"), AfterRelease, 0);
				Sim->SetPuck(FVector2D(0.8, 0.0), FVector2D::ZeroVector);
				for (int32 i = 0; i < 4; ++i) Sim->Step(In);
				const int32 Shots1 = Sim->GetSkaters()[Me].Shots, Passes1 = Sim->GetSkaters()[Me].Passes;
				Hold(true);
				for (int32 i = 0; i < 12; ++i) Sim->Step(In);
				Hold(false);
				for (int32 i = 0; i < 6; ++i) Sim->Step(In);
				const int32 Again = bPass ? Sim->GetSkaters()[Me].Passes - Passes1 : Sim->GetSkaters()[Me].Shots - Shots1;
				TestEqual(TEXT("the key on: a new press fires again"), Again, 1);
			}
			else TestTrue(TEXT("the key off: the strip leaves the charge as it was"), AfterStrip > 0);
		}
		TestEqual(*FString::Printf(TEXT("%s: the neutral value (false): the release after the strip fires the old charge"), bPass ? TEXT("pass") : TEXT("shot")), ByRelease[0], 1);
		TestEqual(*FString::Printf(TEXT("%s: charge_dies_on_loss true: the release after the strip fires nothing"), bPass ? TEXT("pass") : TEXT("shot")), ByRelease[1], 0);
	}
	return true;
}

#endif
