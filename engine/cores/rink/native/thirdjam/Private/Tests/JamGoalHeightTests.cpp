// Lane A50 (R-0033 point 2): Jam.Core.GoalHeight and Jam.Core.CreaseStance. Headless, no world. Run:
//   UnrealEditor-Cmd.exe Game/ThirdJam.uproject -ExecCmds="Automation RunTests Jam.Core.GoalHeight; Quit" -unattended -nullrhi -nosplash -log
#include "Misc/AutomationTest.h"
#include "Misc/FileHelper.h"
#include "JamCartridge.h"
#include "JamSim.h"
#include "JamAICore.h"

#if WITH_DEV_AUTOMATION_TESTS

namespace JamGoalHeightTests
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

	// hockey.regular with game.rink.goal_height_m written in (or the key removed when Height < 0).
	UJamCartridge* WithGoalHeight(FAutomationTestBase& T, double Height, TArray<FString>& Errors)
	{
		FString Json;
		if (!FFileHelper::LoadFileToString(Json, *UJamCartridge::ResolveCartridgePath(TEXT("hockey.regular")))) { T.AddError(TEXT("hockey.regular not readable")); return nullptr; }
		const FString Needle = TEXT("\"goal_width_m\":");
		const int32 At = Json.Find(Needle);
		if (At < 0) { T.AddError(TEXT("hockey.regular has no goal_width_m to anchor on")); return nullptr; }
		if (Height >= 0.0) Json.InsertAt(At, FString::Printf(TEXT("\"goal_height_m\": %g, "), Height));
		return UJamCartridge::LoadFromString(Json, Errors);
	}
}

using namespace JamGoalHeightTests;

// The goal opening is game.rink.goal_height_m tall (0.61 by default, the operator's half-height net): a puck 0.8 m over the line is no goal at 0.61 and a
// goal at a real net's 1.22; the puck on the ice is a goal at both; the loader reads the key and the schema holds its range (0.3..1.5).
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamGoalHeight, "Jam.Core.GoalHeight", JamGoalHeightTests::Flags)
bool FJamGoalHeight::RunTest(const FString&)
{
	UJamCartridge* C = LoadPreset(*this, TEXT("hockey.regular"));
	if (!C) return false;
	FJamGameConfig Cfg = C->Game;
	TestEqual(TEXT("absent key: the default is 0.61"), Cfg.Rink.GoalHeightM, 0.61);
	{
		UJamSim* Sim = MakeSim(Cfg, 1);
		const FVector2D InNet(Sim->GoalLineX() + 0.5, 0.0);
		TestTrue(TEXT("0.61: the puck on the ice inside the mouth is a goal"), Sim->InGoal(InNet, 1));
		TestTrue(TEXT("0.61: a puck 0.5 m up is a goal"), Sim->InGoal(InNet, 1, 0.5));
		TestFalse(TEXT("0.61: a puck 0.8 m up is over the bar"), Sim->InGoal(InNet, 1, 0.8));
		TestFalse(TEXT("0.61: a puck at the bar is no goal"), Sim->InGoal(InNet, 1, 0.61));
		TestFalse(TEXT("the other net does not count this puck"), Sim->InGoal(InNet, -1));
		TestFalse(TEXT("a puck wide of the post is no goal at any height"), Sim->InGoal(FVector2D(InNet.X, Cfg.Rink.GoalWidthM * 0.5 + 0.2), 1, 0.0));
	}
	Cfg.Rink.GoalHeightM = 1.22;
	{
		UJamSim* Sim = MakeSim(Cfg, 1);
		const FVector2D InNet(-(Sim->GoalLineX() + 0.5), 0.0);
		TestTrue(TEXT("1.22: a puck 0.8 m up is a goal"), Sim->InGoal(InNet, -1, 0.8));
		TestFalse(TEXT("1.22: a puck 1.3 m up is over the bar"), Sim->InGoal(InNet, -1, 1.3));
		TestTrue(TEXT("1.22: on the ice still a goal"), Sim->InGoal(InNet, -1));
	}
	// A puck on the ice into the net scores at the default bar.
	{
		UJamSim* Sim = MakeSim(C->Game, 1);
		Sim->SetPuck(FVector2D(Sim->GoalLineX() - 1.0, 0.0), FVector2D(12.0, 0.0));
		TArray<FJamInput> In; In.Init(FJamInput(), Sim->GetSkaters().Num());
		for (int32 f = 0; f < 30 && Sim->GetScore(0) + Sim->GetScore(1) == 0; ++f) Sim->Step(In);
		TestEqual(TEXT("a puck on the ice into the +x net scores for team 0"), Sim->GetScore(0), 1);
	}
	// R-0035 (lane A52): a real lifted shot. Skater 0 (team 0, attacking +x) charges shoot for the full charge_frames_max from 12 m out and releases: the
	// puck arrives shot.lift.full_m over the goal line; this scene sets full_m 0.95 (a cartridge may: the default is 0.47 since R-0044, under the bar), so it sails over the 0.61 bar (no goal, the puck flies over the net) and goes in at 1.22
	// (the same seed, the same scene).
	for (const double Bar : { 0.61, 1.22 })
	{
		FJamGameConfig Lifted = C->Game;
		Lifted.Rink.GoalHeightM = Bar;
		Lifted.Shot.LiftFullM = 0.95;   // the sailing full charge is a cartridge choice since the 01:40 calibration (default 0.47 since R-0044)
		UJamSim* Sim = MakeSim(Lifted, 1);
		const double Gx = Sim->AttackGoalX(0);
		for (const FJamSkaterState& S : Sim->GetSkaters()) Sim->SetSkater(S.Index, FVector2D(-30.0, 12.0 + 2.5 * S.Index), FVector2D::ZeroVector, 0.0);
		Sim->SetSkater(0, FVector2D(Gx - 12.0, 0.0), FVector2D::ZeroVector, 0.0);
		Sim->SetPuck(FVector2D(Gx - 12.0 + 0.8, 0.0), FVector2D::ZeroVector);
		TArray<FJamInput> In; In.Init(FJamInput(), Sim->GetSkaters().Num());
		for (int32 f = 0; f < Lifted.Shot.ChargeFramesMax; ++f) { In[0].bShootHeld = true; Sim->Step(In); }
		In[0].bShootHeld = false;
		bool bFlewOver = false;
		for (int32 f = 0; f < 120 && Sim->GetPhase() == EJamSimPhase::Playing; ++f)
		{
			Sim->Step(In);
			if (Sim->GetPuck().Pos.X > Gx + UJamSim::NetDepth) bFlewOver = true;
		}
		if (Bar < 1.0)
		{
			TestEqual(TEXT("0.61: the full charge from 12 m arrives at 0.95 and is no goal"), Sim->GetScore(0), 0);
			TestTrue(TEXT("0.61: it flew over the net"), bFlewOver);
		}
		else
		{
			TestEqual(TEXT("1.22: the same full charge from 12 m is a goal"), Sim->GetScore(0), 1);
		}
	}
	// The loader and the schema.
	{
		TArray<FString> Errors;
		UJamCartridge* H = WithGoalHeight(*this, 1.22, Errors);
		for (const FString& E : Errors) AddError(E);
		if (H) TestEqual(TEXT("goal_height_m 1.22 loads"), H->Game.Rink.GoalHeightM, 1.22);
		Errors.Reset();
		UJamCartridge* Low = WithGoalHeight(*this, 0.2, Errors);
		TestTrue(TEXT("0.2 is below the range (0.3) and refused"), Low == nullptr || Errors.Num() > 0);
		bool bPointer = false;
		for (const FString& E : Errors) if (E.Contains(TEXT("/game/rink/goal_height_m"))) bPointer = true;
		TestTrue(TEXT("the error names the key's pointer"), bPointer);
		Errors.Reset();
		UJamCartridge* High = WithGoalHeight(*this, 2.0, Errors);
		TestTrue(TEXT("2.0 is above the range (1.5) and refused"), High == nullptr || Errors.Num() > 0);
	}
	return true;
}

// R-0033 point 2: any skater in its own crease takes the goalie stance while an opposing carrier is inside its blue line (JamAI::CreaseStance), and the
// brain carries it on a non-back's output; a carrier, a skater far from the crease, one behind the goal line and a carrier outside the blue line do not.
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamCreaseStance, "Jam.Core.CreaseStance", JamGoalHeightTests::Flags)
bool FJamCreaseStance::RunTest(const FString&)
{
	using namespace JamAI;
	FJamAIWorld W;
	W.NumSkaters = 4;
	W.HalfLength = 45.0; W.HalfWidth = 22.5; W.GoalX = 41.0; W.GoalHalfWidth = 2.0;
	W.PlayerIndex = -1;
	// Team 0 defends -x. Skater 0 (support) stands in its crease at (-40, 0); skater 1 (back) is 21 m out; team 1's skater 2 carries at (-32, 3), inside the blue line (|x| > 15).
	W.Skaters[0].Team = 0; W.Skaters[0].Role = ERole::Support; W.Skaters[0].Pos = FVec2(-40.0, 0.0);
	W.Skaters[1].Team = 0; W.Skaters[1].Role = ERole::Back; W.Skaters[1].Pos = FVec2(-20.0, 5.0);
	W.Skaters[2].Team = 1; W.Skaters[2].Role = ERole::Chaser; W.Skaters[2].Pos = FVec2(-32.0, 3.0); W.Skaters[2].bHasPuck = true;
	W.Skaters[3].Team = 1; W.Skaters[3].Role = ERole::Back; W.Skaters[3].Pos = FVec2(20.0, 0.0);
	W.PuckPos = W.Skaters[2].Pos + FVec2(-0.8, 0.0);
	W.Carrier = 2;
	int Side = 99;
	TestTrue(TEXT("the support in its crease takes the stance"), CreaseStance(W, 0, Side));
	TestEqual(TEXT("the carrier at +z is to the right of a team-0 goalie facing up-ice"), Side, 1);
	TestFalse(TEXT("the back 21 m out does not"), CreaseStance(W, 1, Side));
	TestFalse(TEXT("the carrier itself does not"), CreaseStance(W, 2, Side));
	TestFalse(TEXT("a skater at the far end does not"), CreaseStance(W, 3, Side));
	W.Skaters[2].Pos = FVec2(-10.0, 3.0);
	TestFalse(TEXT("the carrier outside the blue line: no stance"), CreaseStance(W, 0, Side));
	W.Skaters[2].Pos = FVec2(-32.0, -0.5);
	TestTrue(TEXT("back inside: stance"), CreaseStance(W, 0, Side));
	TestEqual(TEXT("a carrier within a metre of the centre line: centre"), Side, 0);
	W.Skaters[0].Pos = FVec2(-42.0, 0.0);
	TestFalse(TEXT("behind the goal line: no stance"), CreaseStance(W, 0, Side));
	W.Skaters[0].Pos = FVec2(-40.0, 0.0);
	W.Carrier = 0;
	TestFalse(TEXT("carrying the puck: no stance"), CreaseStance(W, 0, Side));
	W.Carrier = 2;
	W.bFrozen = true;
	TestFalse(TEXT("a frozen world (goal pause): no stance"), CreaseStance(W, 0, Side));
	W.bFrozen = false;
	// Through the brain: the support's output carries the stance (the back's rule alone never set it for a support).
	FJamBrain Brain;
	FJamAIInput Out[kMaxSkaters];
	Brain.Think(W, Out);
	TestTrue(TEXT("Think: the support's input says goalie"), Out[0].bGoalie);
	TestEqual(TEXT("Think: its side"), Out[0].GoalieSide, 0);
	TestFalse(TEXT("Think: the back far out says no goalie"), Out[1].bGoalie);
	return true;
}

#endif
