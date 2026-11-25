// Lane A93 (R-0045 laws 3 and 4): speed change is the carrier's weapon. Jam.Core.Movement.ReverseBrake, .Burst, .CarrierSprint, .PuckDistance, .SprintShield,
// .BotMatchPro and Jam.Core.MovementNeutral (the neutral block gives back main 8f6b157's bot matches, hash for hash). Bar.Movement.CurveSensitivity (outside
// the gate's Jam filter) measures the two novice-at-rookie bars rule by rule. Headless, scripted scenes on UJamSim. docs/experiments/MOVEMENT.md.
//   UnrealEditor-Cmd.exe Game/ThirdJam.uproject -ExecCmds="Automation RunTests Jam.Core.Movement; Quit" -unattended -nullrhi -nosplash -log
#include "Misc/AutomationTest.h"
#include "HAL/FileManager.h"
#include "Misc/Paths.h"
#include "JamCartridge.h"
#include "JamSim.h"
#include "JamBaseline.h"
#include "JamEventBus.h"
#include "JamBrain.h"
#include "JamSimAdapter.h"
#include "JamPlaytester.h"
#include "DifficultyResolve.h"

#if WITH_DEV_AUTOMATION_TESTS

namespace JamMovementTests
{
	constexpr EAutomationTestFlags Flags = EAutomationTestFlags_ApplicationContextMask | EAutomationTestFlags::ProductFilter;

	// The neutral block (MOVEMENT.md section 4): with these six values the game is the one main 8f6b157 shipped.
	const TCHAR* NeutralSkater = TEXT("\"skater\": {\"reverse_brake_decel\": 0, \"burst\": {\"frames\": 0, \"accel_mult\": 1}, \"sprint\": {\"carry_bonus\": 0}, \"spin\": {\"exposed_frames\": 0}, \"free_speed_mult\": 1,");   // lane A128: the whole spin shields; lane A185: no free-skater speed
	const TCHAR* NeutralStick = TEXT("\"stick\": {\"carry_reach_mult\": 1, \"body_shield\": false, \"passive_take\": true, \"take_grace_frames\": 0, \"lift_cone_deg\": 180, \"sweep\": {\"sprint_shield_mult\": 1}}, \"skater\": {");

	UJamCartridge* LoadPreset(FAutomationTestBase& T, const FString& Name)
	{
		TArray<FString> Errors;
		UJamCartridge* C = UJamCartridge::LoadFromFile(UJamCartridge::ResolveCartridgePath(Name), Errors);
		for (const FString& E : Errors) T.AddError(FString::Printf(TEXT("%s: %s"), *Name, *E));
		return C;
	}

	// The preset with the neutral block written into its text, through the loader (the block is what a cartridge author would write).
	UJamCartridge* LoadNeutral(FAutomationTestBase& T, const UJamCartridge& C, bool bWithContact = false)
	{
		FString Raw = C.RawJson;
		if (!Raw.Contains(TEXT("\"skater\": {")) || Raw.Contains(TEXT("\"stick\": {"))) { T.AddError(TEXT("the preset's text has no plain \"skater\": { or already has a stick object: the neutral block cannot be spliced in")); return nullptr; }
		Raw = Raw.Replace(TEXT("\"skater\": {"), NeutralSkater);
		Raw = Raw.Replace(TEXT("\"skater\": {\"reverse_brake_decel\""), *(FString(NeutralStick) + TEXT("\"reverse_brake_decel\"")));
		// Lane A95 (the merge of A92 + A93 on A94): the other vision lane's neutral block too, and the bots' sprint at 0 (game.ai.sprint: the levels' sprint
		// shares are A95's profile numbers, R-0045 law 4), so the block is proven against main bb18439 (A94's brain, before A92 and A93).
		if (bWithContact)
		{
			Raw = Raw.Replace(TEXT("\"stick\": {\"carry_reach_mult\""), TEXT("\"contact\": {\"momentum\": false, \"carrier_can_hit\": true}, \"stick\": {\"carry_reach_mult\""));
			Raw = Raw.Replace(TEXT("\"ai\": {"), TEXT("\"ai\": {\"sprint\": 0, "));
		}
		TArray<FString> Errors;
		UJamCartridge* N = UJamCartridge::LoadFromString(Raw, Errors);
		for (const FString& E : Errors) T.AddError(FString::Printf(TEXT("neutral block: %s"), *E));
		return N;
	}

	void MakeNeutral(FJamGameConfig& G)
	{
		G.Skater.ReverseBrakeDecel = 0; G.Skater.BurstFrames = 0; G.Skater.BurstAccelMult = 1; G.Skater.SprintCarryBonus = 0;
		G.Stick.CarryReachMult = 1; G.Stick.SweepSprintShieldMult = 1;
		G.Stick.bBodyShield = false;   // lane A102 (track F2): puck protection with the body is off in the neutral block
		G.Stick.bPassiveTake = true; G.Stick.bTeammateTouchTakes = true;   // lane A102 (R-0048): the unpressed take, and the teammate's touch (a rule: a code switch)
		G.Stick.bSweepShieldOneSided = true;   // R-0044 as amended landed with this lane (both sides): main 8f6b157 shielded one side
		G.Stick.TakeGraceFrames = 0; G.Skater.bBurstOwnStop = false;   // lane A121 (track F2, evolution 2): no take grace, the burst for any slow skater
		G.Skater.BurstRestFrames = 0; G.Skater.SpinExposedTail = 0;   // lane A128 (track F2, evolution 3): no standing start, the whole spin shields
		G.Skater.FreeSpeedMult = 1.0;   // lane A185 (track F2, evolution 9): no free-skater speed
	}

	// A sim in Playing with everyone parked in the far corner.
	UJamSim* MakeScene(const FJamGameConfig& G, uint64 Seed)
	{
		UJamSim* Sim = NewObject<UJamSim>();
		Sim->Init(G, Seed);
		Sim->SkipFaceoff();
		for (const FJamSkaterState& S : Sim->GetSkaters()) Sim->SetSkater(S.Index, FVector2D(-35.0 + S.Index * 2.0, 18.0), FVector2D::ZeroVector, 0);
		Sim->SetPuck(FVector2D(30, 18), FVector2D::ZeroVector);
		return Sim;
	}

	int32 FirstOpponent(const UJamSim* Sim, int32 Me)
	{
		for (const FJamSkaterState& S : Sim->GetSkaters()) if (S.Team != Sim->GetSkaters()[Me].Team) return S.Index;
		return -1;
	}

	// Gives Who the puck: against the body (a touch), then five quiet frames in which the carry assist seats it on the aimed blade.
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

	// Stop, cut, go: a skater at full speed along +x reverses its input. StopFrames = frames from the reversal until it no longer moves along +x;
	// To6Frames = frames from the reversal until it moves at 6 m/s along -x (the brief's timing); V0 = the speed at the reversal.
	struct FReverse { double V0 = 0; int32 StopFrames = -1, To6Frames = -1, StillFrames = -1, BrakeFlagFrames = 0, ReverseBrakes = 0; double TravelM = 0; };
	FReverse Reverse(const FJamGameConfig& G, bool bCarrier)
	{
		FReverse R;
		UJamSim* Sim = MakeScene(G, 1);
		const int32 Me = Sim->GetHumanIndex();
		Sim->SetSkater(Me, FVector2D(-34, 0), FVector2D::ZeroVector, 0);
		if (bCarrier) GivePuck(Sim, Me, FVector2D(1, 0));
		TArray<FJamInput> In;
		In.SetNum(Sim->GetSkaters().Num());
		In[Me].Move = FVector2D(1, 0);
		if (bCarrier) In[Me].Stick = FVector2D(1, 0);
		for (int32 F = 0; F < 150; ++F) Sim->Step(In);
		R.V0 = Sim->GetSkaters()[Me].Vel.Size();
		const double X0 = Sim->GetSkaters()[Me].Pos.X;
		double MaxX = X0;
		In[Me].Move = FVector2D(-1, 0);
		for (int32 F = 1; F <= 400 && R.To6Frames < 0; ++F)
		{
			Sim->Step(In);
			const FJamSkaterState& S = Sim->GetSkaters()[Me];
			MaxX = FMath::Max(MaxX, S.Pos.X);
			if (S.bReverseBraking) ++R.BrakeFlagFrames;
			if (R.StopFrames < 0 && S.Vel.X <= 1e-6) R.StopFrames = F;
			if (R.StillFrames < 0 && S.Vel.Size() < 1e-6) R.StillFrames = F;
			if (S.Vel.X <= -6.0) R.To6Frames = F;
		}
		R.TravelM = MaxX - X0;
		R.ReverseBrakes = Sim->GetSkaters()[Me].ReverseBrakes;
		return R;
	}

	// A bot match the way Jam.Core.NetTrap plays it (the real brain at Level, the scripted player bot in the human's slot, the same four input fields).
	struct FBot { int64 Frames = 0; FString Hash; int32 Score0 = 0, Score1 = 0; };
	// bHooksDead (lane A138): the brain reads nothing of track F2's shields (JamBaseline::HooksDead), as on a commit before those reads were wired.
	FBot NetTrapMatch(const UJamCartridge& C, const TCHAR* Level, uint64 Seed, int32 MaxFrames, const char* Tune = nullptr, bool bHooksDead = false)
	{
		UJamSim* Sim = NewObject<UJamSim>();
		Sim->Init(C.Game, Seed);
		UJamBrain* Brain = NewObject<UJamBrain>();
		Brain->ApplyCartridge(C, Level);
		if (Tune)
		{
			char Err[200] = {};
			JamAI::ApplyDifficultyTune(Tune, Brain->EditParams(), Err, sizeof(Err));   // lane A95: an older profile (JamAI::PreA95Tune)
			Brain->SpeedScale = static_cast<float>(Brain->EditParams().SpeedScale);
			Brain->RedSkill = static_cast<float>(Brain->EditParams().RedSkill);
		}
		Brain->ResetBrain();
		UJamPlayerBot* Player = NewObject<UJamPlayerBot>();
		const int32 N = Sim->GetSkaters().Num();
		TArray<FJamInput> Inputs;
		Inputs.SetNum(N);
		for (int32 F = 0; F < MaxFrames && Sim->GetPhase() != EJamSimPhase::Over; ++F)
		{
			JamAI::FJamAIWorld W;
			JamAI::FJamSimAdapter::BuildWorld(*Sim, W);
			if (bHooksDead) JamBaseline::HooksDead(W);
			JamAI::FJamAIInput Out[JamAI::kMaxSkaters];
			Brain->Think(W, Out);
			const int32 Human = Sim->GetHumanIndex();
			for (int32 i = 0; i < N && i < JamAI::kMaxSkaters; ++i)
			{
				const JamAI::FJamAIInput& A = i == Human ? Player->Think(W) : Out[i];
				Inputs[i].Move = FVector2D(A.Move.X, A.Move.Y);
				Inputs[i].bShoot = A.bShoot;
				Inputs[i].bCheck = A.bCheck;
				Inputs[i].bBrake = A.bBrake;
			}
			Sim->Step(Inputs);
		}
		FBot B;
		B.Frames = Sim->GetFrame(); B.Hash = Sim->StateHashHex(); B.Score0 = Sim->GetScore(0); B.Score1 = Sim->GetScore(1);
		return B;
	}

	// A bot match with every input field (the adapter's mapping), the real brain at pro on both sides and the scripted player bot in the human's slot; with
	// bCarrierSprints every carrier holds the sprint. Counts the carrier's frames by pace and the sticks (clean pokes and lifts by an opponent) by the pace
	// of the carrier they took it from.
	struct FPace { int64 Frames = 0, CarryWalk = 0, CarrySprint = 0; int32 TakenWalk = 0, TakenSprint = 0, Goals = 0, ReverseBrakes = 0; FString Hash; };
	FPace PaceMatch(const UJamCartridge& C, uint64 Seed, int32 MaxFrames, bool bCarrierSprints)
	{
		UJamSim* Sim = NewObject<UJamSim>();
		Sim->Init(C.Game, Seed);
		UJamBrain* Brain = NewObject<UJamBrain>();
		Brain->ApplyCartridge(C, TEXT("pro"));
		Brain->ResetBrain();
		UJamPlayerBot* Player = NewObject<UJamPlayerBot>();
		const int32 N = Sim->GetSkaters().Num();
		TArray<FJamInput> Inputs;
		Inputs.SetNum(N);
		FPace P;
		const FName Clean(TEXT("clean"));
		for (int32 F = 0; F < MaxFrames && Sim->GetPhase() != EJamSimPhase::Over; ++F)
		{
			JamAI::FJamAIWorld W;
			JamAI::FJamSimAdapter::BuildWorld(*Sim, W);
			JamAI::FJamAIInput Out[JamAI::kMaxSkaters];
			Brain->Think(W, Out);
			const int32 Human = Sim->GetHumanIndex();
			const int32 Carrier = Sim->CarrierIndex();
			const bool bWasSprinting = Carrier >= 0 && Sim->GetSkaters()[Carrier].bSprinting;
			for (int32 i = 0; i < N && i < JamAI::kMaxSkaters; ++i)
			{
				const JamAI::FJamAIInput& A = i == Human ? Player->Think(W) : Out[i];
				FJamInput& I = Inputs[i];
				I = FJamInput();
				I.Move = FVector2D(A.Move.X, A.Move.Y);
				I.bShoot = A.bShoot; I.bShootHeld = A.bShootHeld; I.bCheck = A.bCheck; I.bBrake = A.bBrake; I.bPass = A.bPass; I.bPassHeld = A.bPassHeld;
				I.Stick = FVector2D(A.Stick.X, A.Stick.Y);
				I.bPoke = A.bPoke; I.bLift = A.bLift; I.bDeke = A.bDeke; I.bSpin = A.bSpin; I.bSprint = A.bSprint; I.bAbility = A.bAbility;
				if (bCarrierSprints && i == Carrier) I.bSprint = true;
			}
			Sim->Step(Inputs);
			if (Sim->GetPhase() == EJamSimPhase::Playing && Carrier >= 0)
			{
				if (Sim->GetSkaters()[Carrier].bSprinting) ++P.CarrySprint; else ++P.CarryWalk;
				for (const FJamSimEvent& E : Sim->GetFrameEvents())
				{
					if ((E.Name == JamEvents::Poke || E.Name == JamEvents::Lift) && E.Kind == Clean && E.Strength > 0.5f && E.Who != Carrier
						&& Sim->GetSkaters().IsValidIndex(E.Who) && Sim->GetSkaters()[E.Who].Team != Sim->GetSkaters()[Carrier].Team)
					{
						if (bWasSprinting || Sim->GetSkaters()[Carrier].bSprinting) ++P.TakenSprint; else ++P.TakenWalk;
					}
				}
			}
		}
		P.Frames = Sim->GetFrame(); P.Hash = Sim->StateHashHex(); P.Goals = Sim->GetScore(0) + Sim->GetScore(1);
		for (const FJamSkaterState& S : Sim->GetSkaters()) P.ReverseBrakes += S.ReverseBrakes;
		return P;
	}
}

// ReverseBrake (job 1 and the timing of job 2). W then S: from full speed the skater is still inside about half a second (reverse_brake_decel 26 since lane
// A121: 19 frames from 8 m/s; hockey.regular skates 11 m/s: 26 frames; 20 before: 24 and 33), the read-out says so, and it then goes the other way. The Ctrl brake is untouched. The timings from
// full speed one way to 6 m/s the other way are printed for the neutral block, the brake alone and the brake with the burst, free skater and carrier.
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamMovementReverseBrake, "Jam.Core.Movement.ReverseBrake", JamMovementTests::Flags)
bool FJamMovementReverseBrake::RunTest(const FString& Parameters)
{
	using namespace JamMovementTests;
	UJamCartridge* C = LoadPreset(*this, TEXT("hockey.regular"));
	if (!C) return false;
	const FJamGameConfig& G = C->Game;
	TestEqual(TEXT("skater.reverse_brake_decel default 26 (lane A121: the stop's grip; 20 before)"), G.Skater.ReverseBrakeDecel, 26.0);
	FJamGameConfig Neutral = G; MakeNeutral(Neutral);
	FJamGameConfig BrakeOnly = Neutral; BrakeOnly.Skater.ReverseBrakeDecel = G.Skater.ReverseBrakeDecel;
	FJamGameConfig BurstOnly = Neutral; BurstOnly.Skater.BurstFrames = G.Skater.BurstFrames; BurstOnly.Skater.BurstAccelMult = G.Skater.BurstAccelMult;
	struct FRow { const TCHAR* Name; const FJamGameConfig* Cfg; };
	const FRow Rows[] = { { TEXT("neutral (main)"), &Neutral }, { TEXT("reverse brake only"), &BrakeOnly }, { TEXT("burst only"), &BurstOnly }, { TEXT("defaults (brake + burst)"), &G } };
	FReverse Free[4], Carry[4];
	for (int32 i = 0; i < 4; ++i)
	{
		Free[i] = Reverse(*Rows[i].Cfg, false);
		Carry[i] = Reverse(*Rows[i].Cfg, true);
		AddInfo(FString::Printf(TEXT("TIMING %s: free skater from %.2f m/s: no longer forward after %d frames, still at %d, 6 m/s the other way after %d frames (%.2f s), %.2f m past the reversal; carrier from %.2f m/s: %d / %d frames (%.2f s), %.2f m"),
			Rows[i].Name, Free[i].V0, Free[i].StopFrames, Free[i].StillFrames, Free[i].To6Frames, Free[i].To6Frames / 60.0, Free[i].TravelM,
			Carry[i].V0, Carry[i].StopFrames, Carry[i].To6Frames, Carry[i].To6Frames / 60.0, Carry[i].TravelM));
	}
	const FReverse& D = Free[3];
	const int32 Want = FMath::CeilToInt32(D.V0 / G.Skater.ReverseBrakeDecel * 60.0);
	TestTrue(*FString::Printf(TEXT("the reverse brake stops the skater dead (still at frame %d)"), D.StillFrames), D.StillFrames > 0);
	TestTrue(*FString::Printf(TEXT("from %.2f m/s to still in %d frames (v / reverse_brake_decel = %d frames, within 1)"), D.V0, D.StillFrames, Want), FMath::Abs(D.StillFrames - Want) <= 1);
	TestTrue(*FString::Printf(TEXT("still inside 30 frames (%d; 33 at the 20 m/s^2 before lane A121)"), D.StillFrames), D.StillFrames <= 30);
	TestTrue(*FString::Printf(TEXT("the read-out bReverseBraking was up while it braked (%d frames)"), D.BrakeFlagFrames), D.BrakeFlagFrames >= Want - 4 && D.BrakeFlagFrames <= Want);
	TestEqual(TEXT("one reverse brake counted"), D.ReverseBrakes, 1);
	TestTrue(*FString::Printf(TEXT("then the input accelerates the other way (6 m/s back after %d frames)"), D.To6Frames), D.To6Frames > D.StillFrames && D.To6Frames < 150);
	TestTrue(*FString::Printf(TEXT("stop, cut, go is faster than main's (%d frames against %d)"), D.To6Frames, Free[0].To6Frames), Free[0].To6Frames > 0 && D.To6Frames < Free[0].To6Frames);
	TestTrue(*FString::Printf(TEXT("the carrier's too (%d frames against %d)"), Carry[3].To6Frames, Carry[0].To6Frames), Carry[0].To6Frames > 0 && Carry[3].To6Frames > 0 && Carry[3].To6Frames < Carry[0].To6Frames);
	TestEqual(TEXT("the neutral block never reverse-brakes"), Free[0].ReverseBrakes + Free[0].BrakeFlagFrames, 0);
	// 8 m/s (the schema's base speed): the vision's "about half a second".
	{
		FJamGameConfig G8 = G; G8.Skater.Speed = 8; G8.Skater.FreeSpeedMult = 1.0;   // lane A185: a free skater at exactly 8 m/s (the vision's number), not 8 x free_speed_mult
		const FReverse R8 = Reverse(G8, false);
		AddInfo(FString::Printf(TEXT("TIMING skater.speed 8: from %.2f m/s still after %d frames (%.2f s), 6 m/s the other way after %d frames"), R8.V0, R8.StillFrames, R8.StillFrames / 60.0, R8.To6Frames));
		TestTrue(*FString::Printf(TEXT("8 m/s to still in about a third of a second (%d frames, want 17..22; 24 at the 20 m/s^2 before lane A121)"), R8.StillFrames), R8.StillFrames >= 17 && R8.StillFrames <= 22);
		FJamGameConfig G20 = G8; G20.Skater.ReverseBrakeDecel = 20;
		const FReverse R20 = Reverse(G20, false);
		AddInfo(FString::Printf(TEXT("TIMING skater.speed 8, reverse_brake_decel 20 (lane A121's neutral value): still after %d frames, 6 m/s the other way after %d frames"), R20.StillFrames, R20.To6Frames));
		TestTrue(*FString::Printf(TEXT("reverse_brake_decel 20 is lane A93's stop: 8 m/s to still in 24 frames (%d)"), R20.StillFrames), FMath::Abs(R20.StillFrames - 24) <= 1);
	}
	// Ctrl keeps working, and exactly as before: the same glide to the same speed under the defaults and under the neutral block.
	{
		double V[2] = { 0, 0 }; int32 Flag[2] = { 0, 0 };
		int32 k = 0;
		for (const FJamGameConfig* Cfg : { static_cast<const FJamGameConfig*>(&G), static_cast<const FJamGameConfig*>(&Neutral) })
		{
			UJamSim* Sim = MakeScene(*Cfg, 1);
			const int32 Me = Sim->GetHumanIndex();
			Sim->SetSkater(Me, FVector2D(-34, 0), FVector2D(8, 0), 0);
			TArray<FJamInput> In;
			In.SetNum(Sim->GetSkaters().Num());
			In[Me].bBrake = true;
			for (int32 F = 0; F < 30; ++F) { Sim->Step(In); if (Sim->GetSkaters()[Me].bBraking) ++Flag[k]; }
			V[k++] = Sim->GetSkaters()[Me].Vel.Size();
		}
		TestTrue(*FString::Printf(TEXT("Ctrl from 8 m/s for 30 frames: %.4f m/s, the same as under the neutral block (%.4f)"), V[0], V[1]), V[0] == V[1] && V[0] < 5.5 && V[0] > 4.0);
		TestTrue(*FString::Printf(TEXT("the read-out bBraking is up on Ctrl (%d frames)"), Flag[0]), Flag[0] == 30);
	}
	// A skater standing with its back to the input turns on the spot and then goes: it never drifts away from where it wants to go.
	{
		UJamSim* Sim = MakeScene(G, 1);
		const int32 Me = Sim->GetHumanIndex();
		Sim->SetSkater(Me, FVector2D(0, 0), FVector2D::ZeroVector, 0);
		TArray<FJamInput> In;
		In.SetNum(Sim->GetSkaters().Num());
		In[Me].Move = FVector2D(-1, 0);
		double MaxFwd = 0; int32 To6 = -1;
		for (int32 F = 1; F <= 120 && To6 < 0; ++F) { Sim->Step(In); MaxFwd = FMath::Max(MaxFwd, Sim->GetSkaters()[Me].Pos.X); if (Sim->GetSkaters()[Me].Vel.X <= -6.0) To6 = F; }
		AddInfo(FString::Printf(TEXT("TIMING standing, input straight behind: 6 m/s that way after %d frames, drifted %.3f m the wrong way first"), To6, MaxFwd));
		TestTrue(*FString::Printf(TEXT("a standing skater told to go behind itself turns on the spot first (%.3f m the wrong way, under 0.25)"), MaxFwd), MaxFwd < 0.25);
		TestTrue(*FString::Printf(TEXT("... and is at 6 m/s that way inside a second (%d frames)"), To6), To6 > 0 && To6 <= 60);
	}
	return true;
}

// Burst (job 2): the acceleration is accel_mult times normal while the skater is under 2 m/s and for burst.frames after, and for burst.frames after the
// move input turned more than 60 degrees inside 10 frames; then it settles. The top speed is the same.
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamMovementBurst, "Jam.Core.Movement.Burst", JamMovementTests::Flags)
bool FJamMovementBurst::RunTest(const FString& Parameters)
{
	using namespace JamMovementTests;
	UJamCartridge* C = LoadPreset(*this, TEXT("hockey.regular"));
	if (!C) return false;
	const FJamGameConfig& G = C->Game;
	TestEqual(TEXT("skater.burst.frames default 20"), G.Skater.BurstFrames, 20);
	TestEqual(TEXT("skater.burst.accel_mult default 1.8"), G.Skater.BurstAccelMult, 1.8);
	FJamGameConfig Neutral = G; MakeNeutral(Neutral);
	// (a) From rest on a rink with a top speed far away (40 m/s, so the acceleration shows for the whole window): the per-frame gain is 1.8 times normal until
	// burst.frames after the speed passed 2 m/s, then normal.
	{
		FJamGameConfig Fast = G; Fast.Skater.Speed = 40;
		Fast.Skater.bBurstOwnStop = false;   // lane A121: from rest the burst arms only under the neutral value (case d has the default)
		UJamSim* Sim = MakeScene(Fast, 1);
		const int32 Me = Sim->GetHumanIndex();
		Sim->SetSkater(Me, FVector2D(-34, 0), FVector2D::ZeroVector, 0);
		TArray<FJamInput> In;
		In.SetNum(Sim->GetSkaters().Num());
		In[Me].Move = FVector2D(1, 0);
		TArray<double> V; TArray<int32> Left;
		V.Add(0.0);
		for (int32 F = 1; F <= 60; ++F) { Sim->Step(In); V.Add(Sim->GetSkaters()[Me].Vel.Size()); Left.Add(Sim->GetSkaters()[Me].BurstLeft); }
		int32 Pass2 = -1, LastBurst = -1;
		const double Normal = (Fast.Skater.Accel - Fast.Skater.GlideDrag * (Fast.Rink.IceFriction / 0.015)) / 60.0;
		for (int32 F = 1; F <= 60; ++F)
		{
			if (Pass2 < 0 && V[F - 1] >= UJamSim::BurstSlowSpeed) Pass2 = F;   // the first frame that started at 2 m/s or more
			if (V[F] - V[F - 1] > Normal * 1.4) LastBurst = F;
		}
		const double Early = V[3] - V[2], Late = V[58] - V[57];
		AddInfo(FString::Printf(TEXT("from rest: +%.4f m/s per frame in the burst, +%.4f after it (x %.3f); the first frame at 2 m/s or more is %d, the last burst frame %d"), Early, Late, Early / Late, Pass2, LastBurst));
		TestTrue(*FString::Printf(TEXT("the burst accelerates accel_mult times normal (x %.3f, want 1.8 within 0.05)"), Early / Late), FMath::Abs(Early / Late - Fast.Skater.BurstAccelMult) < 0.05);
		TestEqual(TEXT("the burst runs burst.frames after the last frame under 2 m/s"), LastBurst - (Pass2 - 1), Fast.Skater.BurstFrames);
		TestEqual(TEXT("BurstLeft is 0 once it has run out"), Left.Last(), 0);
	}
	// (b) The top speed is the same and it is reached sooner.
	{
		int32 ToTop[2] = { -1, -1 }; double Top[2] = { 0, 0 };
		int32 k = 0;
		FJamGameConfig AnySlow = G; AnySlow.Skater.bBurstOwnStop = false;   // lane A121: the burst from rest (own_stop false)
		AnySlow.Skater.FreeSpeedMult = Neutral.Skater.FreeSpeedMult;   // lane A185: the same free-skater speed on both arms (the neutral block's), so only the burst differs
		for (const FJamGameConfig* Cfg : { static_cast<const FJamGameConfig*>(&AnySlow), static_cast<const FJamGameConfig*>(&Neutral) })
		{
			UJamSim* Sim = MakeScene(*Cfg, 1);
			const int32 Me = Sim->GetHumanIndex();
			Sim->SetSkater(Me, FVector2D(-34, 0), FVector2D::ZeroVector, 0);
			TArray<FJamInput> In;
			In.SetNum(Sim->GetSkaters().Num());
			In[Me].Move = FVector2D(1, 0);
			for (int32 F = 1; F <= 150; ++F) { Sim->Step(In); if (ToTop[k] < 0 && Sim->GetSkaters()[Me].Vel.Size() >= Cfg->Skater.Speed - 0.01) ToTop[k] = F; }
			Top[k++] = Sim->GetSkaters()[Me].Vel.Size();
		}
		AddInfo(FString::Printf(TEXT("TIMING 0 to top speed (%.2f m/s): %d frames with the burst, %d without"), Top[0], ToTop[0], ToTop[1]));
		TestTrue(*FString::Printf(TEXT("the top speed is unchanged (%.4f against %.4f)"), Top[0], Top[1]), Top[0] == Top[1]);
		TestTrue(*FString::Printf(TEXT("top speed is reached sooner (%d frames against %d)"), ToTop[0], ToTop[1]), ToTop[0] > 0 && ToTop[0] < ToTop[1] * 0.75);
	}
	// (c) The cut. At full speed the burst has run out; a 90-degree turn of the input arms it; a 45-degree turn does not; two 45-degree turns inside 10
	// frames do; the same two turns 12 frames apart do not.
	{
		const FVector2D A(1, 0), B(0.7071, 0.7071), Cc(0, 1);
		auto Cut = [&](const FVector2D& Mid, int32 MidFrames, const FVector2D& End) -> int32
		{
			UJamSim* Sim = MakeScene(G, 1);
			const int32 Me = Sim->GetHumanIndex();
			Sim->SetSkater(Me, FVector2D(-34, -15), FVector2D::ZeroVector, 0);
			TArray<FJamInput> In;
			In.SetNum(Sim->GetSkaters().Num());
			In[Me].Move = A;
			for (int32 F = 0; F < 120; ++F) Sim->Step(In);
			if (Sim->GetSkaters()[Me].BurstLeft != 0) return -1;   // the burst must have run out at full speed
			In[Me].Move = Mid;
			int32 Armed = 0;
			for (int32 F = 0; F < MidFrames; ++F) { Sim->Step(In); Armed = FMath::Max(Armed, Sim->GetSkaters()[Me].BurstLeft); }
			In[Me].Move = End;
			Sim->Step(In);
			return FMath::Max(Armed, Sim->GetSkaters()[Me].BurstLeft);
		};
		TestEqual(TEXT("a 90-degree cut arms the burst for burst.frames"), Cut(Cc, 0, Cc), G.Skater.BurstFrames);
		TestEqual(TEXT("a 45-degree turn does not"), Cut(B, 0, B), 0);
		TestEqual(TEXT("two 45-degree turns 5 frames apart do (90 degrees inside 10 frames)"), Cut(B, 5, Cc), G.Skater.BurstFrames);
		TestEqual(TEXT("two 45-degree turns 12 frames apart do not"), Cut(B, 12, Cc), 0);
		TestEqual(TEXT("a reversal arms it"), Cut(FVector2D(-1, 0), 0, FVector2D(-1, 0)), G.Skater.BurstFrames);
	}
	// (d) Lane A121 (skater.burst.own_stop, default true): the first step is earned. A skater that merely stands starts at the normal acceleration; one that
	// stopped itself (the reverse brake, or the brake button) has the burst when it goes; own_stop false gives the standing skater its burst back.
	{
		TestTrue(TEXT("skater.burst.own_stop is true when the key is absent"), G.Skater.bBurstOwnStop);
		// Frames from rest to 6 m/s, and the most BurstLeft seen; Stop: 0 = standing from the start, 1 = W to full speed, S to still, then go; 2 = W, the brake button to under 2 m/s, then go.
		auto Go = [&](const FJamGameConfig& Cfg, int32 Stop, int32& OutArmed) -> int32
		{
			UJamSim* Sim = MakeScene(Cfg, 1);
			const int32 Me = Sim->GetHumanIndex();
			Sim->SetSkater(Me, FVector2D(-20, -10), FVector2D::ZeroVector, 0);
			TArray<FJamInput> In;
			In.SetNum(Sim->GetSkaters().Num());
			if (Stop > 0)
			{
				In[Me].Move = FVector2D(1, 0);
				for (int32 F = 0; F < 90; ++F) Sim->Step(In);
				In[Me] = FJamInput();
				if (Stop == 1) In[Me].Move = FVector2D(-1, 0); else In[Me].bBrake = true;
				for (int32 F = 0; F < 240 && Sim->GetSkaters()[Me].Vel.Size() > (Stop == 1 ? 0.05 : 1.5); ++F) Sim->Step(In);
				In[Me] = FJamInput();
			}
			In[Me].Move = FVector2D(0, 1);   // off to the side: a new direction either way
			OutArmed = 0;
			const FVector2D V0 = Sim->GetSkaters()[Me].Vel;
			for (int32 F = 1; F <= 120; ++F)
			{
				Sim->Step(In);
				OutArmed = FMath::Max(OutArmed, Sim->GetSkaters()[Me].BurstLeft);
				if (Sim->GetSkaters()[Me].Vel.Y >= 6.0) return F;
			}
			return -1;
		};
		FJamGameConfig Off = G; Off.Skater.bBurstOwnStop = false;
		int32 ArmStand = 0, ArmStop = 0, ArmCtrl = 0, ArmStandOff = 0;
		// Lane A128 (skater.burst.rest_frames): a skater that stands has earned its first step too; lane A121's cases hold with the key at 0.
		FJamGameConfig Own = G; Own.Skater.BurstRestFrames = 0;
		int32 ArmRest = 0;
		const int32 Rested = Go(G, 0, ArmRest);
		AddInfo(FString::Printf(TEXT("TIMING first step to 6 m/s from rest under the defaults (burst.rest_frames %d): %d frames (burst %d)"), G.Skater.BurstRestFrames, Rested, ArmRest));
		TestEqual(TEXT("A128: a skater that stood still has the burst"), ArmRest, G.Skater.BurstFrames);
		const int32 Stand = Go(Own, 0, ArmStand), Stopped = Go(Own, 1, ArmStop), Ctrl = Go(Own, 2, ArmCtrl), StandOff = Go(Off, 0, ArmStandOff);
		AddInfo(FString::Printf(TEXT("TIMING first step to 6 m/s: standing %d frames (burst %d), after its own reverse stop %d (burst %d), after the brake button %d (burst %d); own_stop false, standing: %d (burst %d)"),
			Stand, ArmStand, Stopped, ArmStop, Ctrl, ArmCtrl, StandOff, ArmStandOff));
		TestEqual(TEXT("burst.rest_frames 0: a skater that merely stands has no burst"), ArmStand, 0);
		TestEqual(TEXT("a skater that stopped itself by reversing has it"), ArmStop, G.Skater.BurstFrames);
		TestEqual(TEXT("a skater that stopped itself with the brake button has it"), ArmCtrl, G.Skater.BurstFrames);
		TestEqual(TEXT("own_stop false: the standing skater has it, as before the lane"), ArmStandOff, G.Skater.BurstFrames);
		TestTrue(*FString::Printf(TEXT("the earned first step is faster than the standing start (%d frames against %d)"), Stopped, Stand), Stopped > 0 && Stand > 0 && Stopped < Stand);
		TestTrue(*FString::Printf(TEXT("the earned first step is at least the burst lane A93 gave everyone from rest (%d frames against %d)"), Stopped, StandOff), Stopped <= StandOff);
	}
	return true;
}

// CarrierSprint (job 3): the carrier may sprint; its top speed is base x carry_speed_mult x (1 + carry_bonus), under a free skater's base x (1 + bonus); a
// sprinting defender closes on a sprinting carrier in a straight line; the carrier's bar drains as the defender's. A cartridge cannot break the law: with
// carry_bonus 1 the carrier's sprint is capped at 0.97 of the free sprint.
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamMovementCarrierSprint, "Jam.Core.Movement.CarrierSprint", JamMovementTests::Flags)
bool FJamMovementCarrierSprint::RunTest(const FString& Parameters)
{
	using namespace JamMovementTests;
	UJamCartridge* C = LoadPreset(*this, TEXT("hockey.regular"));
	if (!C) return false;
	const FJamGameConfig& G = C->Game;
	TestEqual(TEXT("skater.sprint.carry_bonus default 0.08"), G.Skater.SprintCarryBonus, 0.08);
	TestEqual(TEXT("skater.sprint.bonus stays 0.15"), G.Skater.SprintBonus, 0.15);
	struct FOut { double Vc = 0, Vd = 0, Gap0 = 0, Gap1 = 0; int32 StaminaC = 0, StaminaD = 0, SprintC = 0, Full = 0; bool bKept = false; };
	auto Run = [&](const FJamGameConfig& Gc, bool bSprint) -> FOut
	{
		FOut O;
		UJamSim* Sim = MakeScene(Gc, 1);
		const int32 Me = Sim->GetHumanIndex();
		const int32 D = FirstOpponent(Sim, Me);
		Sim->SetSkater(Me, FVector2D(-28, 0), FVector2D::ZeroVector, 0);
		Sim->SetSkater(D, FVector2D(-36, 3), FVector2D::ZeroVector, 0);   // 8 m behind, on its own lane (no contact: the speeds alone decide)
		GivePuck(Sim, Me, FVector2D(1, 0));
		O.Gap0 = Sim->GetSkaters()[Me].Pos.X - Sim->GetSkaters()[D].Pos.X;
		TArray<FJamInput> In;
		In.SetNum(Sim->GetSkaters().Num());
		O.bKept = true;
		for (int32 F = 1; F <= 120; ++F)
		{
			In[Me] = FJamInput(); In[Me].Move = FVector2D(1, 0); In[Me].Stick = FVector2D(1, 0); In[Me].bSprint = bSprint;
			In[D] = FJamInput(); In[D].Move = FVector2D(1, 0); In[D].bSprint = bSprint;
			Sim->Step(In);
			if (Sim->CarrierIndex() != Me) O.bKept = false;
		}
		const FJamSkaterState& Sc = Sim->GetSkaters()[Me];
		const FJamSkaterState& Sd = Sim->GetSkaters()[D];
		O.Vc = Sc.Vel.Size(); O.Vd = Sd.Vel.Size(); O.Gap1 = Sc.Pos.X - Sd.Pos.X;
		O.StaminaC = Sc.Stamina; O.StaminaD = Sd.Stamina; O.SprintC = Sc.CarrySprintFrames;
		O.Full = FMath::Max(1, Gc.Skater.SprintDrainFrames) * FMath::Max(1, Gc.Skater.SprintRefillFrames);
		return O;
	};
	const FOut Walk = Run(G, false), Sprint = Run(G, true);
	const double Base = G.Skater.Speed;
	AddInfo(FString::Printf(TEXT("base %.2f m/s. Walking: carrier %.3f, defender %.3f. Sprinting: carrier %.3f (x %.4f of base), defender %.3f (x %.4f); the 8 m gap is %.2f m after 2 s (walking: %.2f m); stamina carrier %d, defender %d of %d; carrier sprint frames %d"),
		Base, Walk.Vc, Walk.Vd, Sprint.Vc, Sprint.Vc / Base, Sprint.Vd, Sprint.Vd / Base, Sprint.Gap1, Walk.Gap1, Sprint.StaminaC, Sprint.StaminaD, Sprint.Full, Sprint.SprintC));
	TestTrue(TEXT("the carrier kept the puck through both runs"), Walk.bKept && Sprint.bKept);
	TestTrue(*FString::Printf(TEXT("the carrier's sprint is base x carry_speed_mult x (1 + carry_bonus) (%.3f, want %.3f within 0.02)"), Sprint.Vc, Base * G.Skater.CarrySpeedMult * (1.0 + G.Skater.SprintCarryBonus)),
		FMath::Abs(Sprint.Vc - Base * G.Skater.CarrySpeedMult * (1.0 + G.Skater.SprintCarryBonus)) < 0.02);
	TestTrue(*FString::Printf(TEXT("the sprint raises the carrier's speed (%.3f > %.3f)"), Sprint.Vc, Walk.Vc), Sprint.Vc > Walk.Vc + 0.3);
	TestTrue(*FString::Printf(TEXT("a sprinting defender is faster than a sprinting carrier (%.3f > %.3f)"), Sprint.Vd, Sprint.Vc), Sprint.Vd > Sprint.Vc + 0.5);
	TestTrue(*FString::Printf(TEXT("... and closes on it in a straight line (gap %.2f m -> %.2f m in 2 s)"), Sprint.Gap0, Sprint.Gap1), Sprint.Gap1 < Sprint.Gap0 - 1.5);
	TestTrue(*FString::Printf(TEXT("the carrier's bar drains as the defender's (%d = %d, under %d)"), Sprint.StaminaC, Sprint.StaminaD, Sprint.Full), Sprint.StaminaC == Sprint.StaminaD && Sprint.StaminaC < Sprint.Full);
	TestEqual(TEXT("120 carrier sprint frames counted"), Sprint.SprintC, 120);
	// The cap: no cartridge makes the carrier's sprint a match for a free one.
	{
		FJamGameConfig Wild = G; Wild.Skater.SprintCarryBonus = 1.0; Wild.Skater.CarrySpeedMult = 1.0;
		const FOut W = Run(Wild, true);
		AddInfo(FString::Printf(TEXT("carry_bonus 1, carry_speed_mult 1: carrier %.3f, defender %.3f (cap %.3f)"), W.Vc, W.Vd, Base * (1.0 + G.Skater.SprintBonus) * UJamSim::CarrierSprintCap));
		TestTrue(*FString::Printf(TEXT("the carrier's sprint is capped under the free sprint (%.3f <= %.3f < %.3f)"), W.Vc, Base * (1.0 + G.Skater.SprintBonus) * UJamSim::CarrierSprintCap, W.Vd),
			W.Vc <= Base * (1.0 + G.Skater.SprintBonus) * UJamSim::CarrierSprintCap + 0.01 && W.Vc < W.Vd - 0.2);
	}
	// carry_bonus 0 (the neutral value): refused, the bar untouched, as A82 shipped it.
	{
		FJamGameConfig Off = G; Off.Skater.SprintCarryBonus = 0.0;
		const FOut O = Run(Off, true);
		TestTrue(*FString::Printf(TEXT("carry_bonus 0: the carrier cannot sprint (%.3f = %.3f, bar %d of %d, sprint frames %d)"), O.Vc, Walk.Vc, O.StaminaC, O.Full, O.SprintC),
			FMath::Abs(O.Vc - Walk.Vc) < 1e-6 && (O.StaminaC < 0 || O.StaminaC == O.Full) && O.SprintC == 0);
	}
	return true;
}

// PuckDistance (job 4): not sprinting, the carried puck rides at carry_reach_mult of the blade's distance (1.2 m of 1.6 m at full aim); sprinting, at the full
// distance; the direction is the aim's; the puck stays carried through both changes of pace; a shot and a pass fire at either distance; another skater's
// blade (no puck) is full length.
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamMovementPuckDistance, "Jam.Core.Movement.PuckDistance", JamMovementTests::Flags)
bool FJamMovementPuckDistance::RunTest(const FString& Parameters)
{
	using namespace JamMovementTests;
	UJamCartridge* C = LoadPreset(*this, TEXT("hockey.regular"));
	if (!C) return false;
	const FJamGameConfig& G = C->Game;
	TestEqual(TEXT("stick.carry_reach_mult default 0.75"), G.Stick.CarryReachMult, 0.75);
	const double Full = UJamSim::SkaterRadius + G.Stick.ReachM, Close = Full * G.Stick.CarryReachMult;
	UJamSim* Sim = MakeScene(G, 1);
	const int32 Me = Sim->GetHumanIndex();
	const int32 D = FirstOpponent(Sim, Me);
	const FVector2D Aim = FVector2D(0.6, 0.8);   // forward and to the side, full aim
	Sim->SetSkater(Me, FVector2D(-30, 0), FVector2D::ZeroVector, 0);
	Sim->SetSkater(D, FVector2D(-30, -12), FVector2D::ZeroVector, 0);
	GivePuck(Sim, Me, Aim);
	TArray<FJamInput> In;
	In.SetNum(Sim->GetSkaters().Num());
	int32 Dropped = 0;
	auto Run = [&](int32 Frames, bool bMove, bool bSprint)
	{
		for (int32 F = 0; F < Frames; ++F)
		{
			In[Me] = FJamInput(); In[Me].Stick = Aim; In[Me].bSprint = bSprint; if (bMove) In[Me].Move = FVector2D(1, 0);
			In[D] = FJamInput(); In[D].Stick = FVector2D(0, 1);
			Sim->Step(In);
			if (Sim->CarrierIndex() != Me) ++Dropped;
		}
	};
	auto Blade = [&]() { return FVector2D::Distance(Sim->GetSkaters()[Me].Pos, Sim->GetSkaters()[Me].BladePos); };
	auto Puck = [&]() { return FVector2D::Distance(Sim->GetSkaters()[Me].Pos, Sim->GetPuck().Pos); };
	auto AimErrDeg = [&]() { const FVector2D R = (Sim->GetSkaters()[Me].BladePos - Sim->GetSkaters()[Me].Pos).GetSafeNormal(); return FMath::RadiansToDegrees(FMath::Acos(FMath::Clamp(FVector2D::DotProduct(R, Aim.GetSafeNormal()), -1.0, 1.0))); };
	Run(20, false, false);
	const double StandBlade = Blade(), StandPuck = Puck(), StandErr = AimErrDeg();
	Run(40, true, false);
	const double WalkBlade = Blade(), WalkPuck = Puck();
	Run(30, true, true);
	const bool bSprinting = Sim->GetSkaters()[Me].bSprinting;
	const double SprintBlade = Blade(), SprintPuck = Puck(), SprintErr = AimErrDeg();
	Run(30, true, false);
	const double BackBlade = Blade(), BackPuck = Puck();
	const double OtherBlade = FVector2D::Distance(Sim->GetSkaters()[D].Pos, Sim->GetSkaters()[D].BladePos);
	AddInfo(FString::Printf(TEXT("full aim: standing blade %.3f m puck %.3f m; skating blade %.3f puck %.3f; sprinting blade %.3f puck %.3f; after the sprint blade %.3f puck %.3f; a skater without the puck: blade %.3f; frames not carried %d of 120; carrier reach %.2f"),
		StandBlade, StandPuck, WalkBlade, WalkPuck, SprintBlade, SprintPuck, BackBlade, BackPuck, OtherBlade, Dropped, Sim->CarrierReachM(Me)));
	TestTrue(*FString::Printf(TEXT("not sprinting the blade is at carry_reach_mult of the full distance (%.3f, want %.3f)"), StandBlade, Close), FMath::Abs(StandBlade - Close) < 1e-6 && FMath::Abs(WalkBlade - Close) < 1e-6);
	TestTrue(*FString::Printf(TEXT("... and the puck is on it, about 1.2 m from the body (%.3f standing, %.3f skating)"), StandPuck, WalkPuck), FMath::Abs(StandPuck - Close) < 0.03 && FMath::Abs(WalkPuck - Close) < 0.1);
	TestTrue(TEXT("the sprint was live for the carrier"), bSprinting);
	TestTrue(*FString::Printf(TEXT("sprinting the blade is at the full distance (%.3f, want %.3f)"), SprintBlade, Full), FMath::Abs(SprintBlade - Full) < 1e-6);
	TestTrue(*FString::Printf(TEXT("... and the puck rides out there (%.3f)"), SprintPuck), FMath::Abs(SprintPuck - Full) < 0.1);
	TestTrue(*FString::Printf(TEXT("after the sprint the puck is drawn back in (blade %.3f, puck %.3f)"), BackBlade, BackPuck), FMath::Abs(BackBlade - Close) < 1e-6 && FMath::Abs(BackPuck - Close) < 0.1);
	TestTrue(*FString::Printf(TEXT("the aim's direction is the cursor's at both distances (%.4f and %.4f degrees off)"), StandErr, SprintErr), StandErr < 0.01 && SprintErr < 0.01);
	TestEqual(TEXT("the puck is carried on every frame through both changes of pace"), Dropped, 0);
	TestTrue(*FString::Printf(TEXT("a skater without the puck holds a full-length blade (%.3f)"), OtherBlade), FMath::Abs(OtherBlade - Full) < 1e-6);
	TestTrue(TEXT("the live reach never passes CarrierReachM"), Full <= Sim->CarrierReachM(Me));
	// Shots and passes fire at either distance (A85's rule holds: CarrierReachM is the full reach).
	for (const bool bSprint : { false, true })
	{
		for (const bool bPass : { false, true })
		{
			UJamSim* S2 = MakeScene(G, 1);
			const int32 M2 = S2->GetHumanIndex();
			int32 Mate = -1;
			for (const FJamSkaterState& S : S2->GetSkaters()) if (S.Index != M2 && S.Team == S2->GetSkaters()[M2].Team) { Mate = S.Index; break; }
			const double Dir = S2->AttackGoalX(S2->GetSkaters()[M2].Team) > 0 ? 1.0 : -1.0;
			S2->SetSkater(M2, FVector2D(-10 * Dir, 0), FVector2D::ZeroVector, Dir > 0 ? 0.0 : UE_DOUBLE_PI);
			S2->SetSkater(Mate, FVector2D(8 * Dir, 6), FVector2D::ZeroVector, Dir > 0 ? 0.0 : UE_DOUBLE_PI);
			GivePuck(S2, M2, FVector2D(Dir, 0));
			TArray<FJamInput> I2;
			I2.SetNum(S2->GetSkaters().Num());
			for (int32 F = 0; F < 30; ++F) { I2[M2] = FJamInput(); I2[M2].Move = FVector2D(Dir, 0); I2[M2].Stick = FVector2D(Dir, 0); I2[M2].bSprint = bSprint; S2->Step(I2); }
			const double Dist = FVector2D::Distance(S2->GetSkaters()[M2].Pos, S2->GetPuck().Pos);
			I2[M2].bShoot = !bPass; I2[M2].bPass = bPass;
			S2->Step(I2);
			const FJamSkaterState& Sk = S2->GetSkaters()[M2];
			TestEqual(*FString::Printf(TEXT("%s, puck %.2f m out: the %s fires"), bSprint ? TEXT("sprinting") : TEXT("not sprinting"), Dist, bPass ? TEXT("pass") : TEXT("shot")), bPass ? Sk.Passes : Sk.Shots, 1);
		}
	}
	return true;
}

// SprintShield (job 4): the sweep's shield lasts sprint_shield_mult of shield_frames while the carrier sprints (6 of 12), so a stick on the side the puck
// left is refused for half as long.
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamMovementSprintShield, "Jam.Core.Movement.SprintShield", JamMovementTests::Flags)
bool FJamMovementSprintShield::RunTest(const FString& Parameters)
{
	using namespace JamMovementTests;
	UJamCartridge* C = LoadPreset(*this, TEXT("hockey.regular"));
	if (!C) return false;
	const FJamGameConfig& G = C->Game;
	TestEqual(TEXT("stick.sweep.sprint_shield_mult default 0.5"), G.Stick.SweepSprintShieldMult, 0.5);
	const FVector2D FwdLeft(0.7071, -0.7071), FwdRight(0.7071, 0.7071);   // yaw 0: forward +x, left -y
	struct FOut { int32 ShieldFrames = 0, ShieldedFrames = 0, Sweeps = 0; bool bSprinting = false, bKept = false; };
	auto Run = [&](const FJamGameConfig& Gc, bool bSprint) -> FOut
	{
		FOut O;
		UJamSim* Sim = MakeScene(Gc, 1);
		const int32 Me = Sim->GetHumanIndex();
		const int32 D = FirstOpponent(Sim, Me);
		Sim->SetSkater(Me, FVector2D(-30, 0), FVector2D::ZeroVector, 0);
		GivePuck(Sim, Me, FwdLeft);
		TArray<FJamInput> In;
		In.SetNum(Sim->GetSkaters().Num());
		for (int32 F = 1; F <= 70; ++F)
		{
			In[Me] = FJamInput(); In[Me].Move = FVector2D(1, 0); In[Me].bSprint = bSprint; In[Me].Stick = F >= 40 ? FwdRight : FwdLeft;   // frame 40: the sweep
			// The defender rides 2 m to the carrier's left, its blade between them: a stick on the side the puck left.
			const FJamSkaterState& Sc = Sim->GetSkaters()[Me];
			Sim->SetSkater(D, Sc.Pos + FVector2D(0, -2.0), Sc.Vel, UE_DOUBLE_PI * 0.5);
			In[D] = FJamInput(); In[D].Stick = FVector2D(0, 0.5);
			Sim->Step(In);
			const FJamSkaterState& S = Sim->GetSkaters()[Me];
			if (F == 40) { O.bSprinting = S.bSprinting; O.Sweeps = S.Sweeps; }
			if (F >= 40 && S.SweepFrames > 0) ++O.ShieldFrames;
			if (F >= 40 && Sim->IsPokeShielded(Sim->GetSkaters()[D], S)) ++O.ShieldedFrames;
		}
		O.bKept = Sim->CarrierIndex() == Me;
		O.ShieldFrames += 1;   // the frame of the sweep itself is shielded (the count above reads SweepFrames after that frame's countdown)
		return O;
	};
	const FOut Walk = Run(G, false), Sprint = Run(G, true);
	FJamGameConfig Same = G; Same.Stick.SweepSprintShieldMult = 1.0;
	const FOut SprintSame = Run(Same, true);
	AddInfo(FString::Printf(TEXT("the sweep's shield: %d frames skating (a stick on the old side refused on %d frames after the sweep), %d frames sprinting (refused on %d); sprint_shield_mult 1: %d sprinting"),
		Walk.ShieldFrames, Walk.ShieldedFrames, Sprint.ShieldFrames, Sprint.ShieldedFrames, SprintSame.ShieldFrames));
	TestTrue(TEXT("the carrier sprinted in the sprint run and not in the other"), Sprint.bSprinting && !Walk.bSprinting);
	TestTrue(TEXT("the sweep was seen in both runs and the puck kept"), Walk.Sweeps >= 1 && Sprint.Sweeps >= 1 && Walk.bKept && Sprint.bKept);
	TestEqual(TEXT("not sprinting: the shield lasts shield_frames"), Walk.ShieldFrames, G.Stick.SweepShieldFrames);
	TestEqual(TEXT("sprinting: the shield lasts sprint_shield_mult of it"), Sprint.ShieldFrames, FMath::RoundToInt32(G.Stick.SweepShieldFrames * G.Stick.SweepSprintShieldMult));
	TestTrue(*FString::Printf(TEXT("a stick on the old side is refused for fewer frames against a sprinting carrier (%d < %d)"), Sprint.ShieldedFrames, Walk.ShieldedFrames), Sprint.ShieldedFrames < Walk.ShieldedFrames && Sprint.ShieldedFrames > 0);
	TestEqual(TEXT("sprint_shield_mult 1: the sprint does not shorten the shield"), SprintSame.ShieldFrames, G.Stick.SweepShieldFrames);
	return true;
}

// MovementNeutral (job 5; re-pinned by lane A95 on the merged tree): the neutral block gives back the pre-vision game on this tree's brain. With this block, A92's
// contact block ({"momentum": false, "carrier_can_hit": true}) and game.ai.sprint 0 written into hockey.regular's text (and the code switch for the one-sided
// sweep shield, which has no key), two matches replay main bb18439's (A94's hockey brain, A91's shot calibrations, before A92 and A93), read from that
// commit's build (.claude/worktrees/clean-main, Jam.Core.NetTrap and Jam.Core.MatchAlwaysEnds, status/A95.md): the same frame and the same hash. A93's
// pins were main 8f6b157's (before A94). With the defaults the same matches differ (the rules are live).
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamMovementNeutral, "Jam.Core.MovementNeutral", JamMovementTests::Flags)
bool FJamMovementNeutral::RunTest(const FString& Parameters)
{
	using namespace JamMovementTests;
	UJamCartridge* C = LoadPreset(*this, TEXT("hockey.regular"));
	if (!C) return false;
	UJamCartridge* N = LoadNeutral(*this, *C, true);
	if (!N) return false;
	// R-0044 as amended (the sweep's shield on both sides) landed with this lane and is a rule, not a key: the code switch brings back the one side.
	N->Game.Stick.bSweepShieldOneSided = true;
	N->Game.Stick.bTeammateTouchTakes = true;   // lane A102 (R-0048 point 2): a rule, not a key
	// Lane A138 (R-0053 point 5): the shared baseline too (every rule since the vision's commit at its neutral value), then this test's own block again, which
	// goes further back than the vision (lanes A92 and A93 off: main bb18439) and owns reverse_brake_decel 0.
	JamBaseline::MakeNeutral(N->Game);
	MakeNeutral(N->Game);
	TestTrue(TEXT("neutral: stick.passive_take true, stick.body_shield false"), N->Game.Stick.bPassiveTake && !N->Game.Stick.bBodyShield);
	TestEqual(TEXT("neutral: skater.reverse_brake_decel 0"), N->Game.Skater.ReverseBrakeDecel, 0.0);
	TestEqual(TEXT("neutral: skater.burst.frames 0"), N->Game.Skater.BurstFrames, 0);
	TestEqual(TEXT("neutral: skater.burst.accel_mult 1"), N->Game.Skater.BurstAccelMult, 1.0);
	TestEqual(TEXT("neutral: skater.sprint.carry_bonus 0"), N->Game.Skater.SprintCarryBonus, 0.0);
	TestEqual(TEXT("neutral: stick.carry_reach_mult 1"), N->Game.Stick.CarryReachMult, 1.0);
	TestEqual(TEXT("neutral: stick.sweep.sprint_shield_mult 1"), N->Game.Stick.SweepSprintShieldMult, 1.0);
	TestTrue(TEXT("neutral: A92's contact block read (momentum false, carrier_can_hit true)"), !N->Game.Contact.bMomentum && N->Game.Contact.bCarrierCanHit);
	TestEqual(TEXT("neutral: the rest of the sprint object keeps its defaults (bonus)"), N->Game.Skater.SprintBonus, C->Game.Skater.SprintBonus);
	TestEqual(TEXT("neutral: the rest of the skater object is the preset's (speed)"), N->Game.Skater.Speed, C->Game.Skater.Speed);
	// Main bb18439, Jam.Core.NetTrap: hockey.regular pro seed 15, 4078 frames, 3:1, hash 874f67830b20dc4f.
	const FBot A = NetTrapMatch(*N, TEXT("pro"), 15, 6000, JamAI::PreA95Tune(JamAI::EDifficulty::Pro));
	AddInfo(FString::Printf(TEXT("neutral blocks, hockey.regular pro seed 15 (the NetTrap match): %lld frames, %d:%d, hash %s (main bb18439: 4078 frames, 3:1, 874f67830b20dc4f)"), A.Frames, A.Score0, A.Score1, *A.Hash));
	TestEqual(TEXT("neutral block: the pro bot match ends on main's frame"), A.Frames, static_cast<int64>(4078));
	TestEqual(TEXT("neutral block: the pro bot match's hash is main's"), A.Hash, FString(TEXT("874f67830b20dc4f")));
	// Main bb18439, Jam.Core.MatchAlwaysEnds: hockey.regular all_star, the regular playtester, seed 387: 9475 frames, 3:2, hash 59762ff73c73f6e3.
	{
		JamAI::FJamSimAdapter Sim(*N);
		JamAI::FJamMatchConfig Cfg = JamAI::ToMatchConfigResolved(*N, TEXT("all_star"));
		char Err[200] = {};
		TestTrue(TEXT("the pre-A95 profile tune applies"), JamAI::ApplyDifficultyTune(JamAI::PreA95Tune(JamAI::EDifficulty::AllStar), Cfg.AI, Err, sizeof(Err)));
		const JamAI::FJamPlaytestStats S = JamAI::RunPlaytestMatch(Sim, Cfg, 387, JamAI::EPlaytester::Regular, 36000, N->Game.Shot.ChargeFramesMax);
		AddInfo(FString::Printf(TEXT("neutral blocks, hockey.regular all_star seed 387 (the regular playtester): %lld frames, %d:%d, hash %016llx (main bb18439: 9475 frames, 3:2, 59762ff73c73f6e3)"),
			static_cast<long long>(S.Frames), S.GoalsFor, S.GoalsAgainst, static_cast<unsigned long long>(S.Hash)));
		TestEqual(TEXT("neutral block: the playtester match ends on main's frame"), static_cast<int64>(S.Frames), static_cast<int64>(9475));
		TestTrue(TEXT("neutral block: the playtester match's hash is main's"), S.Hash == 0x59762ff73c73f6e3ull);
	}
	// The defaults are live: the same match is another match.
	const FBot B = NetTrapMatch(*C, TEXT("pro"), 15, 6000);
	AddInfo(FString::Printf(TEXT("defaults, hockey.regular pro seed 15: %lld frames, %d:%d, hash %s"), B.Frames, B.Score0, B.Score1, *B.Hash));
	TestNotEqual(TEXT("defaults: the pro bot match is another match"), B.Hash, FString(TEXT("874f67830b20dc4f")));
	// Lane A121 (track F2, evolution 2): its neutral block, written as a cartridge author would, gives back the default match of the tree before the lane
	// (evolution 1's final build, Game/logs/a102-tests-jam-full-3-ue.log: "defaults, hockey.regular pro seed 15: 6000 frames, 2:0, hash fc59e23598229ebc").
	{
		FString Raw = C->RawJson;
		TestEqual(TEXT("one game.skater anchor for lane A121's neutral block"), Raw.ReplaceInline(TEXT("\"skater\": {"),
			TEXT("\"stick\": {\"take_grace_frames\": 0}, \"skater\": {\"reverse_brake_decel\": 20, \"burst\": {\"own_stop\": false, \"rest_frames\": 0}, \"spin\": {\"exposed_frames\": 0}, ")), 1);   // lane A128: the blocks stack
		TArray<FString> Errors;
		UJamCartridge* E2 = UJamCartridge::LoadFromString(Raw, Errors);
		for (const FString& E : Errors) AddError(FString::Printf(TEXT("lane A121's neutral block: %s"), *E));
		if (E2)
		{
			TestTrue(TEXT("A121 neutral: take_grace_frames 0, reverse_brake_decel 20, burst.own_stop false"), E2->Game.Stick.TakeGraceFrames == 0 && E2->Game.Skater.ReverseBrakeDecel == 20.0 && !E2->Game.Skater.bBurstOwnStop);
			TestTrue(TEXT("A121 neutral: the rest of the burst object keeps its defaults"), E2->Game.Skater.BurstFrames == C->Game.Skater.BurstFrames && E2->Game.Skater.BurstAccelMult == C->Game.Skater.BurstAccelMult);
			// Lane A138 (R-0053 point 5): the tree before the lane is the shared baseline with lane A102's kept puck back on; its brain was evolution 1 and read no shield.
			JamBaseline::MakeNeutral(E2->Game); JamBaseline::WithKeptPuck(E2->Game); JamBaseline::WithWhistle(E2->Game);   // lane A133: the pin blew the whistle
			const FBot N2 = NetTrapMatch(*E2, TEXT("pro"), 15, 6000, JamBaseline::BrainTune(), true);
			AddInfo(FString::Printf(TEXT("lane A121's neutral block, hockey.regular pro seed 15: %lld frames, %d:%d, hash %s (the tree before the lane: 6000 frames, 2:0, fc59e23598229ebc)"), N2.Frames, N2.Score0, N2.Score1, *N2.Hash));
			// re-pinned to LADDER SET 3, 15 Nov (the Director's ruling 07:25): the level profiles' numbers changed, no rule did
			TestEqual(TEXT("A121 neutral block: the pro bot match's hash is the baseline's"), N2.Hash, FString(TEXT("1d1c4735555c9d61")));
			TestNotEqual(TEXT("A121 defaults: the same match is another match"), B.Hash, N2.Hash);
		}
	}
	// Lane A128 (track F2, evolution 3): its neutral block, written as a cartridge author would, gives back the default match of the tree before the lane
	// (evolution 2's final build, Game/logs/a121-tests-jam-full-2-ue.log: "defaults, hockey.regular pro seed 15: 6000 frames, 1:1, hash c8ae80c1dbdc45b0").
	{
		FString Raw = C->RawJson;
		TestEqual(TEXT("one game.skater anchor for lane A128's neutral block"), Raw.ReplaceInline(TEXT("\"skater\": {"),
			TEXT("\"skater\": {\"burst\": {\"rest_frames\": 0}, \"spin\": {\"exposed_frames\": 0}, ")), 1);
		TArray<FString> Errors;
		UJamCartridge* E3 = UJamCartridge::LoadFromString(Raw, Errors);
		for (const FString& E : Errors) AddError(FString::Printf(TEXT("lane A128's neutral block: %s"), *E));
		if (E3)
		{
			TestTrue(TEXT("A128 neutral: burst.rest_frames 0, spin.exposed_frames 0"), E3->Game.Skater.BurstRestFrames == 0 && E3->Game.Skater.SpinExposedTail == 0);
			TestTrue(TEXT("A128 neutral: the rest of the burst and spin objects keep their defaults"), E3->Game.Skater.BurstFrames == C->Game.Skater.BurstFrames && E3->Game.Skater.bBurstOwnStop == C->Game.Skater.bBurstOwnStop
				&& E3->Game.Skater.SpinFrames == C->Game.Skater.SpinFrames && E3->Game.Skater.SpinStaminaCost == C->Game.Skater.SpinStaminaCost);
			// Lane A138 (R-0053 point 5): the tree before the lane is the shared baseline with lane A102's kept puck and lane A121's three rules back on.
			JamBaseline::MakeNeutral(E3->Game); JamBaseline::WithKeptPuck(E3->Game); JamBaseline::WithCarrierAnswer(E3->Game); JamBaseline::WithWhistle(E3->Game);   // lane A133: the pin blew the whistle
			const FBot N3 = NetTrapMatch(*E3, TEXT("pro"), 15, 6000, JamBaseline::BrainTune(), true);
			AddInfo(FString::Printf(TEXT("lane A128's neutral block, hockey.regular pro seed 15: %lld frames, %d:%d, hash %s (the tree before the lane: 6000 frames, 1:1, c8ae80c1dbdc45b0)"), N3.Frames, N3.Score0, N3.Score1, *N3.Hash));
			TestEqual(TEXT("A128 neutral block: the pro bot match's hash is the baseline's"), N3.Hash, FString(TEXT("c8ae80c1dbdc45b0")));
			TestNotEqual(TEXT("A128 defaults: the same match is another match"), B.Hash, N3.Hash);
		}
	}
	// Lane A147 (track F2, evolution 4): its neutral block, written as a cartridge author would (game.skater.burst.rest_kept_mps 0), on today's game. The
	// match is printed, not pinned (R-0053 point 5: no new pin on a default-profile match while the curve lane re-sets the levels): on main d4bb4da the default
	// match of this seed was 4229 frames, 1:3, hash 7683cee2cf6589d1 (the full Jam filter of that commit), and this line read the same on the lane's final
	// build (MOVEMENT-5.md section 5). JamBaseline::MakeNeutral carries the key's neutral for every older pin.
	{
		FString Raw = C->RawJson;
		TestEqual(TEXT("one game.skater anchor for lane A147's neutral block"), Raw.ReplaceInline(TEXT("\"skater\": {"), TEXT("\"skater\": {\"burst\": {\"rest_kept_mps\": 0}, ")), 1);
		TArray<FString> Errors;
		UJamCartridge* E4 = UJamCartridge::LoadFromString(Raw, Errors);
		for (const FString& E : Errors) AddError(FString::Printf(TEXT("lane A147's neutral block: %s"), *E));
		TestEqual(TEXT("game.skater.burst.rest_kept_mps is 3 when the key is absent"), C->Game.Skater.BurstRestKeptMps, 3.0);
		if (E4)
		{
			TestTrue(TEXT("A147 neutral: burst.rest_kept_mps 0, the rest of the burst object keeps its defaults"), E4->Game.Skater.BurstRestKeptMps == 0.0 && E4->Game.Skater.BurstRestFrames == C->Game.Skater.BurstRestFrames
				&& E4->Game.Skater.BurstFrames == C->Game.Skater.BurstFrames && E4->Game.Skater.bBurstOwnStop == C->Game.Skater.bBurstOwnStop);
			const FBot N4 = NetTrapMatch(*E4, TEXT("pro"), 15, 6000);
			AddInfo(FString::Printf(TEXT("lane A147's neutral block, hockey.regular pro seed 15: %lld frames, %d:%d, hash %s (main d4bb4da's default match: 4229 frames, 1:3, 7683cee2cf6589d1)"), N4.Frames, N4.Score0, N4.Score1, *N4.Hash));
			FJamGameConfig Base = C->Game;
			JamBaseline::MakeNeutral(Base);
			TestEqual(TEXT("A147: the shared baseline carries the key's neutral value"), Base.Skater.BurstRestKeptMps, 0.0);
		}
	}
	return true;
}

// BotMatchPro (job 8): three minutes of bot play at pro on hockey.regular (10,800 frames over as many seeds as it takes), once as the brain plays it and
// once with every carrier holding the sprint: the carrier's frames by pace and the sticks that took the puck from a sprinting carrier against a skating one.
// The numbers are the report's; the test asserts only that the match replays and that a sprinting carrier is taken at least as often per frame.
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamMovementBotMatchPro, "Jam.Core.Movement.BotMatchPro", JamMovementTests::Flags)
bool FJamMovementBotMatchPro::RunTest(const FString& Parameters)
{
	using namespace JamMovementTests;
	UJamCartridge* C = LoadPreset(*this, TEXT("hockey.regular"));
	if (!C) return false;
	for (const bool bCarrierSprints : { false, true })
	{
		FPace Sum;
		int32 Matches = 0;
		for (uint64 Seed = 1; Sum.Frames < 10800 && Seed <= 12; ++Seed)
		{
			const FPace P = PaceMatch(*C, Seed, static_cast<int32>(10800 - Sum.Frames), bCarrierSprints);
			if (Seed == 1)
			{
				const FPace Again = PaceMatch(*C, Seed, static_cast<int32>(10800 - Sum.Frames), bCarrierSprints);
				TestEqual(TEXT("seed 1 replays"), Again.Hash, P.Hash);
			}
			Sum.Frames += P.Frames; Sum.CarryWalk += P.CarryWalk; Sum.CarrySprint += P.CarrySprint; Sum.TakenWalk += P.TakenWalk; Sum.TakenSprint += P.TakenSprint;
			Sum.Goals += P.Goals; Sum.ReverseBrakes += P.ReverseBrakes;
			++Matches;
		}
		const double PerWalk = Sum.CarryWalk > 0 ? 1000.0 * Sum.TakenWalk / Sum.CarryWalk : 0.0, PerSprint = Sum.CarrySprint > 0 ? 1000.0 * Sum.TakenSprint / Sum.CarrySprint : 0.0;
		AddInfo(FString::Printf(TEXT("BOTMATCH pro, %s: %lld frames over %d matches, %d goals, %d reverse brakes; carrier frames skating %lld, sprinting %lld; sticks that took the puck (clean poke or lift by an opponent): %d from a skating carrier (%.2f per 1000 carry frames), %d from a sprinting carrier (%.2f per 1000)"),
			bCarrierSprints ? TEXT("every carrier holds the sprint") : TEXT("as the brain plays it (ai.sprint 0: no bot sprints)"), static_cast<long long>(Sum.Frames), Matches, Sum.Goals, Sum.ReverseBrakes,
			static_cast<long long>(Sum.CarryWalk), static_cast<long long>(Sum.CarrySprint), Sum.TakenWalk, PerWalk, Sum.TakenSprint, PerSprint));
		TestTrue(TEXT("three minutes were played"), Sum.Frames >= 10800);
		if (!bCarrierSprints) TestTrue(TEXT("the brain's carriers sprint only on an open lane (lane A115; before: never): fewer sprinting than skating carry frames"), Sum.CarrySprint < Sum.CarryWalk);
		else TestTrue(TEXT("carriers sprinted"), Sum.CarrySprint > 0);
	}
	return true;
}

// Bar.Movement.CurveSensitivity (not in the gate): the two novice-at-rookie bars (Jam.Playtest.NoviceScoresAtRookie: scores inside 7,200 frames in 10 of 20
// seeds; Jam.Bot.HumanHasSomethingToDo: faceoffs without a human touch inside 600 frames, budget 10.4 %) measured with the neutral block, with each rule
// alone and with all of them, so the curve pass after the three lanes land knows which rule moved what.
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamMovementCurveSensitivity, "Bar.Movement.CurveSensitivity", JamMovementTests::Flags)
bool FJamMovementCurveSensitivity::RunTest(const FString& Parameters)
{
	using namespace JamMovementTests;
	UJamCartridge* C = LoadPreset(*this, TEXT("hockey.regular"));
	if (!C) return false;
	const FJamGameConfig Def = C->Game;
	FJamGameConfig Neutral = Def; MakeNeutral(Neutral);
	struct FRow { const TCHAR* Name; FJamGameConfig Cfg; };
	TArray<FRow> Rows;
	Rows.Add({ TEXT("neutral (main)"), Neutral });
	{ FJamGameConfig G = Neutral; G.Skater.ReverseBrakeDecel = Def.Skater.ReverseBrakeDecel; Rows.Add({ TEXT("reverse brake only"), G }); }
	{ FJamGameConfig G = Neutral; G.Skater.BurstFrames = Def.Skater.BurstFrames; G.Skater.BurstAccelMult = Def.Skater.BurstAccelMult; Rows.Add({ TEXT("burst only"), G }); }
	{ FJamGameConfig G = Neutral; G.Skater.SprintCarryBonus = Def.Skater.SprintCarryBonus; G.Stick.SweepSprintShieldMult = Def.Stick.SweepSprintShieldMult; Rows.Add({ TEXT("carrier sprint + shield only"), G }); }
	{ FJamGameConfig G = Neutral; G.Stick.CarryReachMult = Def.Stick.CarryReachMult; Rows.Add({ TEXT("carry reach 0.75 only"), G }); }
	Rows.Add({ TEXT("defaults (all)"), Def });
	for (const FRow& R : Rows)
	{
		C->Game = R.Cfg;
		int32 Scored = 0, Without = 0, Faceoffs = 0, For = 0, Against = 0;
		for (uint64 Seed = 1; Seed <= 20; ++Seed)
		{
			JamAI::FJamSimAdapter Sim(*C);
			const JamAI::FJamPlaytestStats S = JamAI::RunPlaytestMatch(Sim, JamAI::ToMatchConfigResolved(*C, TEXT("rookie")), Seed, JamAI::EPlaytester::Novice, 36000, C->Game.Shot.ChargeFramesMax);
			if (S.FirstGoalByHuman >= 0 && S.FirstGoalByHuman <= 7200) ++Scored;
			Without += S.FaceoffsWithoutTouch; Faceoffs += S.Faceoffs; For += S.GoalsFor; Against += S.GoalsAgainst;
		}
		AddInfo(FString::Printf(TEXT("CURVE %s: the novice scores inside 7,200 frames at rookie in %d of 20 seeds (bar 10); %d of %d faceoffs without a human touch (budget %d); goals %d:%d"),
			R.Name, Scored, Without, Faceoffs, Faceoffs * 104 / 1000, For, Against));
	}
	C->Game = Def;
	return true;
}

// BackUnderFollowCamera: why the game mode holds the move frame while S is down (AHokejGameMode::ReadHumanInput, lane A93). The third-person camera follows
// the skater's facing camera.lag_frames (4) late and the human's move input is camera-relative. Modelled here with the camera's own filter
// (yaw += (facing - yaw) x (1 - e^(-1/4)) per frame): W for 2.5 s, then S for 2 s, with S read from the live camera and from the camera's yaw at the
// moment S went down. Held frame: still inside 40 frames, then back the way it came. Live frame: "back" turns with the skater.
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamMovementBackUnderFollowCamera, "Jam.Core.Movement.BackUnderFollowCamera", JamMovementTests::Flags)
bool FJamMovementBackUnderFollowCamera::RunTest(const FString& Parameters)
{
	using namespace JamMovementTests;
	UJamCartridge* C = LoadPreset(*this, TEXT("hockey.regular"));
	if (!C) return false;
	struct FOut { int32 Still = -1, Brake = 0; double BackSpeed = 0, BackM = 0, EndSpeed = 0; };
	auto Run = [&](const FJamGameConfig& G, bool bHoldFrame) -> FOut
	{
		FOut O;
		UJamSim* Sim = MakeScene(G, 1);
		const int32 Me = Sim->GetHumanIndex();
		Sim->SetSkater(Me, FVector2D(-34, 0), FVector2D::ZeroVector, 0);
		TArray<FJamInput> In;
		In.SetNum(Sim->GetSkaters().Num());
		const double A = 1.0 - FMath::Exp(-1.0 / 4.0);
		double Cam = 0.0, Held = 0.0;
		auto StepCam = [&]() { Cam += FMath::UnwindRadians(Sim->GetSkaters()[Me].Yaw - Cam) * A; };
		for (int32 F = 0; F < 150; ++F) { In[Me].Move = FVector2D(FMath::Cos(Cam), FMath::Sin(Cam)); Sim->Step(In); StepCam(); }
		Held = Cam;
		const double X0 = Sim->GetSkaters()[Me].Pos.X;
		double MinX = X0;
		for (int32 F = 1; F <= 120; ++F)
		{
			const double Y = bHoldFrame ? Held : Cam;
			In[Me].Move = FVector2D(-FMath::Cos(Y), -FMath::Sin(Y));
			Sim->Step(In);
			StepCam();
			const FJamSkaterState& S = Sim->GetSkaters()[Me];
			if (S.bReverseBraking) ++O.Brake;
			if (O.Still < 0 && S.Vel.Size() < 0.3) O.Still = F;
			if (O.Still >= 0) O.BackSpeed = FMath::Max(O.BackSpeed, -S.Vel.X);
			MinX = FMath::Min(MinX, S.Pos.X);
		}
		O.BackM = X0 - Sim->GetSkaters()[Me].Pos.X;
		O.EndSpeed = Sim->GetSkaters()[Me].Vel.Size();
		return O;
	};
	const FJamGameConfig& G = C->Game;
	FJamGameConfig Neutral = G; MakeNeutral(Neutral);
	const FOut Held = Run(G, true), Live = Run(G, false), Old = Run(Neutral, false);
	AddInfo(FString::Printf(TEXT("FOLLOWCAM W then S held 2 s. Frame held at the press (what the game mode does): still after %d frames, %d brake frames, back at up to %.2f m/s, %.2f m back of the turning point's start after 2 s. Live camera frame: still after %d frames, %d brake frames, back at up to %.2f m/s, %.2f m, end speed %.2f. Main (neutral block, live camera): still after %d, %.2f m, end speed %.2f"),
		Held.Still, Held.Brake, Held.BackSpeed, Held.BackM, Live.Still, Live.Brake, Live.BackSpeed, Live.BackM, Live.EndSpeed, Old.Still, Old.BackM, Old.EndSpeed));
	TestTrue(*FString::Printf(TEXT("held frame: W then S is still inside 40 frames (%d)"), Held.Still), Held.Still > 0 && Held.Still <= 40);
	TestTrue(*FString::Printf(TEXT("held frame: then it skates back the way it came (%.2f m/s, %.2f m back)"), Held.BackSpeed, Held.BackM), Held.BackSpeed > 6.0 && Held.BackM > 3.0);
	TestTrue(*FString::Printf(TEXT("the held frame goes back farther than the live camera frame (%.2f m against %.2f m)"), Held.BackM, Live.BackM), Held.BackM > Live.BackM);
	return true;
}

// Lane A185 (track F2 evolution 9, R-0064 point 2; docs/experiments/MOVEMENT-10.md): skaters without the puck are 15 % faster. FreeSpeed: from rest along +x for
// 150 frames, a free skater (the human and a bot), walking and sprinting, and the carrier, at free_speed_mult 1.15 (the default) and at 1 (the neutral value).
// The free skater's top is 1.15 x, reached in the same time (the frame it passes 95 % of its own top within 2 frames); the carrier's run is the same to the
// digit (the state hash of the whole scene), walking and sprinting.
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamMovementFreeSpeed, "Jam.Core.Movement.FreeSpeed", JamMovementTests::Flags)
bool FJamMovementFreeSpeed::RunTest(const FString& Parameters)
{
	using namespace JamMovementTests;
	UJamCartridge* C = LoadPreset(*this, TEXT("hockey.regular"));
	if (!C) return false;
	TestEqual(TEXT("skater.free_speed_mult default 1.15"), C->Game.Skater.FreeSpeedMult, 1.15);
	struct FRun { double Top = 0; int32 To95 = -1; uint64 Hash = 0; FVector2D Pos; bool bCarried = true; };
	// Who: 0 the human free, 1 a bot free, 2 the human carrying.
	auto Run = [&](double Mult, int32 Who, bool bSprint) -> FRun
	{
		FJamGameConfig G = C->Game;
		G.Skater.FreeSpeedMult = Mult;
		UJamSim* Sim = MakeScene(G, 1);
		const int32 Me = Sim->GetHumanIndex();
		const int32 S = Who == 1 ? FirstOpponent(Sim, Me) : Me;
		Sim->SetSkater(S, FVector2D(-30, 0), FVector2D::ZeroVector, 0);
		if (Who == 2) GivePuck(Sim, S, FVector2D(1, 0));
		TArray<FJamInput> In;
		In.SetNum(Sim->GetSkaters().Num());
		TArray<double> V;
		FRun R;
		for (int32 F = 1; F <= 150; ++F)
		{
			In[S] = FJamInput(); In[S].Move = FVector2D(1, 0); In[S].bSprint = bSprint;
			if (Who == 2) In[S].Stick = FVector2D(1, 0);
			Sim->Step(In);
			V.Add(Sim->GetSkaters()[S].Vel.Size());
			if (Who == 2 && Sim->CarrierIndex() != S) R.bCarried = false;
		}
		for (double X : V) R.Top = FMath::Max(R.Top, X);
		for (int32 i = 0; i < V.Num(); ++i) if (V[i] >= 0.95 * R.Top) { R.To95 = i + 1; break; }
		R.Hash = Sim->StateHash();
		R.Pos = Sim->GetSkaters()[S].Pos;
		return R;
	};
	const double Base = C->Game.Skater.Speed;
	for (int32 Sprint = 0; Sprint < 2; ++Sprint)
	{
		for (int32 Who = 0; Who < 2; ++Who)
		{
			const FRun A = Run(1.0, Who, Sprint != 0), B = Run(1.15, Who, Sprint != 0);
			const TCHAR* Name = Who == 0 ? TEXT("the human") : TEXT("a bot");
			const TCHAR* Gait = Sprint ? TEXT("sprinting") : TEXT("gliding");
			AddInfo(FString::Printf(TEXT("%s free, %s: top %.3f m/s (x %.4f of base) at 1, %.3f (x %.4f) at 1.15; 95 %% of its top in %d and %d frames"), Name, Gait, A.Top, A.Top / Base, B.Top, B.Top / Base, A.To95, B.To95));
			TestTrue(*FString::Printf(TEXT("%s free, %s: 15 %% more top speed (%.3f / %.3f = %.4f)"), Name, Gait, B.Top, A.Top, B.Top / A.Top), FMath::Abs(B.Top / A.Top - 1.15) < 0.005);
			TestTrue(*FString::Printf(TEXT("%s free, %s: in the same time (%d and %d frames to 95 %% of its own top)"), Name, Gait, A.To95, B.To95), FMath::Abs(A.To95 - B.To95) <= 2);
		}
		const FRun A = Run(1.0, 2, Sprint != 0), B = Run(1.15, 2, Sprint != 0);
		AddInfo(FString::Printf(TEXT("the carrier, %s: top %.4f m/s at 1, %.4f at 1.15 (x %.4f of base); hash %016llx / %016llx"), Sprint ? TEXT("sprinting") : TEXT("gliding"), A.Top, B.Top, B.Top / Base,
			static_cast<unsigned long long>(A.Hash), static_cast<unsigned long long>(B.Hash)));
		TestTrue(TEXT("the carrier kept the puck"), A.bCarried && B.bCarried);
		TestTrue(*FString::Printf(TEXT("the carrier skates exactly as before (%s): top %.6f = %.6f, the scene's hash the same"), Sprint ? TEXT("sprinting") : TEXT("gliding"), A.Top, B.Top), A.Top == B.Top && A.Pos == B.Pos && A.Hash == B.Hash);
		const double Want = Base * C->Game.Skater.CarrySpeedMult * (Sprint ? 1.0 + C->Game.Skater.SprintCarryBonus : 1.0);
		TestTrue(*FString::Printf(TEXT("the carrier's top is base x carry_speed_mult%s (%.3f, want %.3f within 0.02)"), Sprint ? TEXT(" x (1 + carry_bonus)") : TEXT(""), B.Top, Want), FMath::Abs(B.Top - Want) < 0.02);
	}
	// The key reads back from a cartridge; out of range is refused.
	{
		TArray<FString> Errors;
		UJamCartridge* V = UJamCartridge::LoadFromString(C->RawJson.Replace(TEXT("\"skater\": {"), TEXT("\"skater\": {\"free_speed_mult\": 1,")), Errors);
		for (const FString& E : Errors) AddError(FString::Printf(TEXT("free_speed_mult 1 variant: %s"), *E));
		if (V) TestEqual(TEXT("free_speed_mult 1 read"), V->Game.Skater.FreeSpeedMult, 1.0);
		Errors.Reset();
		UJamCartridge* Bad = UJamCartridge::LoadFromString(C->RawJson.Replace(TEXT("\"skater\": {"), TEXT("\"skater\": {\"free_speed_mult\": 0.9,")), Errors);
		TestTrue(TEXT("free_speed_mult 0.9 (under 1) is refused"), Bad == nullptr || Errors.Num() > 0);
	}
	return true;
}

// Lane A185: FreeSpeedShipped. Every shipped cartridge has the rule: the six hockey.* cuts beside the cartridge folder (the hockey.test.* figure and visual
// rigs are not shipped), the twelve modes (modes/, not modes/parked/) and the ladder's takes and fallbacks (ladder/): each file found by listing the folders,
// so a cut added later is read too, and each loads to free_speed_mult 1.15 (none overrides it).
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamMovementFreeSpeedShipped, "Jam.Core.Movement.FreeSpeedShipped", JamMovementTests::Flags)
bool FJamMovementFreeSpeedShipped::RunTest(const FString& Parameters)
{
	const FString Root = UJamCartridge::GetCartridgeDir();
	struct FFolder { const TCHAR* Sub; int32 AtLeast; int32 Found = 0; };
	FFolder Folders[] = { { TEXT(""), 6 }, { TEXT("modes"), 12 }, { TEXT("ladder"), 12 } };
	int32 Read = 0;
	for (FFolder& Fo : Folders)
	{
		TArray<FString> Names;
		const FString Dir = FString(Fo.Sub).IsEmpty() ? Root : FPaths::Combine(Root, Fo.Sub);
		IFileManager::Get().FindFiles(Names, *FPaths::Combine(Dir, TEXT("*.cartridge.json")), true, false);
		Names.Sort();
		for (const FString& N : Names)
		{
			if (N.StartsWith(TEXT("hockey.test."))) continue;
			++Fo.Found;
			TArray<FString> Errors;
			UJamCartridge* C = UJamCartridge::LoadFromFile(FPaths::Combine(Dir, N), Errors);
			if (!C) { AddError(FString::Printf(TEXT("%s/%s does not load: %s"), Fo.Sub, *N, Errors.Num() ? *Errors[0] : TEXT("no message"))); continue; }
			++Read;
			TestEqual(*FString::Printf(TEXT("%s/%s: free_speed_mult"), Fo.Sub, *N), C->Game.Skater.FreeSpeedMult, 1.15);
		}
		TestTrue(*FString::Printf(TEXT("'%s': %d shipped cartridges found, at least %d"), Fo.Sub, Fo.Found, Fo.AtLeast), Fo.Found >= Fo.AtLeast);
	}
	AddInfo(FString::Printf(TEXT("%d shipped cartridges read: cuts %d, modes %d, ladder %d"), Read, Folders[0].Found, Folders[1].Found, Folders[2].Found));
	return true;
}

#endif
