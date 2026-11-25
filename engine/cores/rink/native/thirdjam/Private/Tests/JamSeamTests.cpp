// Lane A16 (C-0005): the two seams. Jam.Core.Seams proves that no source / no hook (or an empty one) leaves every hash untouched, that a
// modifier resolves and changes the hash, and that rule actions land in the frame of their trigger. Headless, no world. Run:
//   UnrealEditor-Cmd.exe Game/ThirdJam.uproject -ExecCmds="Automation RunTests Jam.Core.Seams; Quit" -unattended -nullrhi -nosplash -log
#include "Misc/AutomationTest.h"
#include "JamCartridge.h"
#include "JamSim.h"
#include "JamEventBus.h"
#include "JamModifiers.h"
#include "JamRuleHooks.h"

#if WITH_DEV_AUTOMATION_TESTS

namespace JamSeamTests
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
		Sim->SkipFaceoff();   // R-0013 countdown; the seams are proven on live play
		return Sim;
	}

	// The same scripted attacker as JamCoreTests::Attack: get behind the puck on the line to the goal, shoot when lined up.
	FJamInput Attack(const UJamSim& Sim, int32 Me)
	{
		const FJamSkaterState& S = Sim.GetSkaters()[Me];
		const FVector2D Puck = Sim.GetPuck().Pos;
		const FVector2D Goal(Sim.AttackGoalX(S.Team), 0.0);
		const FVector2D ToGoal = (Goal - Puck).GetSafeNormal();
		const FVector2D Behind = Puck - ToGoal * 0.7;
		FJamInput In;
		const FVector2D D = Behind - S.Pos;
		In.Move = D.Size() > 0.3 ? D.GetSafeNormal() : ToGoal;
		const FVector2D ToPuck = Puck - S.Pos;
		const double Dist = ToPuck.Size();
		const FVector2D Fwd = S.Forward();
		if (Dist < Sim.GetConfig().Shot.ReachM && FVector2D::DotProduct(Fwd, ToGoal) > 0.97 && FVector2D::DotProduct(Fwd, ToPuck / FMath::Max(Dist, 1e-6)) > 0.6)
		{
			In.bShoot = true;
		}
		return In;
	}

	// Seeded random inputs for every skater; the human attacks. Returns the final hash and collects every frame hash.
	// OutPlayingFrames (lane A52): how many of the steps ran in the Playing phase (OnFrame fires only there; a lifted scripted shot may score inside the run).
	uint64 RunScripted(UJamSim* Sim, uint64 Seed, int32 Frames, TArray<uint64>* OutHashes, int32* OutPlayingFrames = nullptr)
	{
		FJamRandom In(Seed * 7919 + 13);
		TArray<FJamInput> Inputs;
		Inputs.SetNum(Sim->GetSkaters().Num());
		if (OutPlayingFrames) *OutPlayingFrames = 0;
		for (int32 F = 0; F < Frames; ++F)
		{
			if (OutPlayingFrames && Sim->GetPhase() == EJamSimPhase::Playing) ++*OutPlayingFrames;
			for (int32 i = 0; i < Inputs.Num(); ++i)
			{
				if (F % 20 == 0) Inputs[i].Move = In.UnitVector2D() * In.Range(0.3, 1.0);
				Inputs[i].bShoot = In.NextUnit() < 0.08;
				Inputs[i].bCheck = In.NextUnit() < 0.03;
			}
			const int32 Me = Sim->GetHumanIndex();
			Inputs[Me] = Attack(*Sim, Me);
			Sim->Step(Inputs);
			if (OutHashes) OutHashes->Add(Sim->StateHash());
		}
		return Sim->StateHash();
	}

	// A source that returns a fixed list.
	struct FListSource : public IJamModifierSource
	{
		TArray<FJamActiveModifier> List;
		virtual void CollectModifiers(int32 Frame, TArray<FJamActiveModifier>& Out) const override { Out.Append(List); }
	};

	// A hook that records triggers and answers with a fixed action list per trigger.
	struct FScriptHook : public IJamRuleHook
	{
		TMap<EJamRuleTrigger, TArray<FJamRuleActionOut>> Answers;
		TMap<EJamRuleTrigger, int32> Seen;
		int32 FrameForOnFrame = -1;   // OnFrame answers only on this frame
		virtual void OnRuleEvent(const FJamRuleEventIn& In, TArray<FJamRuleActionOut>& Out) override
		{
			Seen.FindOrAdd(In.Trigger)++;
			if (In.Trigger == EJamRuleTrigger::OnFrame && In.Frame != FrameForOnFrame) return;
			if (const TArray<FJamRuleActionOut>* A = Answers.Find(In.Trigger)) Out.Append(*A);
		}
	};

	FJamRuleActionOut Act(EJamRuleAction Action, int32 Team = -1, float Value = 0.f, const TCHAR* Param = nullptr, const TCHAR* Text = nullptr)
	{
		FJamRuleActionOut A;
		A.Action = Action;
		A.Team = Team;
		A.Value = Value;
		if (Param) A.Param = FName(Param);
		if (Text) A.Text = Text;
		return A;
	}

	void EmptyIce(UJamSim* Sim)
	{
		const int32 Me = Sim->GetHumanIndex();
		for (const FJamSkaterState& S : Sim->GetSkaters())
		{
			if (S.Index != Me) Sim->SetSkater(S.Index, FVector2D(-30.0 + S.Index * 6.0, S.Index % 2 ? 18.0 : -18.0), FVector2D::ZeroVector, 0);
		}
	}

	// Runs the scripted human until the first goal (or MaxFrames); returns the goal frame or -1.
	int32 PlayToGoal(UJamSim* Sim, int32 MaxFrames, TArray<FJamSimEvent>* GoalFrameEvents)
	{
		const int32 Me = Sim->GetHumanIndex();
		TArray<FJamInput> Inputs;
		Inputs.SetNum(Sim->GetSkaters().Num());
		for (int32 F = 0; F < MaxFrames; ++F)
		{
			Inputs[Me] = Attack(*Sim, Me);
			Sim->Step(Inputs);
			for (const FJamSimEvent& E : Sim->GetFrameEvents())
			{
				if (E.Name == JamEvents::Goal)
				{
					if (GoalFrameEvents) *GoalFrameEvents = Sim->GetFrameEvents();
					return static_cast<int32>(Sim->GetFrame());
				}
			}
		}
		return -1;
	}

// The test stays inside the namespace (no using-directive): unity builds merge files, and a file-scope using would make LoadPreset ambiguous elsewhere.
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamSeams, "Jam.Core.Seams", JamSeamTests::Flags)
bool FJamSeams::RunTest(const FString& Parameters)
{
	UJamCartridge* C = LoadPreset(*this, TEXT("hockey.regular"));
	if (!C) return false;
	const FJamGameConfig& G = C->Game;

	// 1. No seam, empty source, empty hook: the same hash on every frame.
	TArray<uint64> Plain, WithEmptySource, WithEmptyHook;
	RunScripted(MakeSim(G, 1), 1, 600, &Plain);
	{
		FListSource Empty;
		UJamSim* Sim = MakeSim(G, 1);
		Sim->SetModifierSource(&Empty);
		RunScripted(Sim, 1, 600, &WithEmptySource);
		Sim->SetModifierSource(nullptr);
	}
	{
		FScriptHook Hook;
		UJamSim* Sim = MakeSim(G, 1);
		Sim->SetRuleHook(&Hook);
		Sim->Restart();        // the opening triggers with the hook attached (Restart re-seeds: the same match)
		Sim->SkipFaceoff();
		int32 PlayingFrames = 0;
		RunScripted(Sim, 1, 600, &WithEmptyHook, &PlayingFrames);
		Sim->SetRuleHook(nullptr);
		// Lane A52 (R-0035): the scripted attacker's lifted taps can score inside the 600 frames; OnFrame fires on every Playing frame, not during the pause.
		TestTrue(TEXT("the hook saw OnFrame every Playing frame"), Hook.Seen.FindRef(EJamRuleTrigger::OnFrame) >= PlayingFrames && PlayingFrames >= 300);
		TestTrue(TEXT("the hook saw the opening faceoff"), Hook.Seen.FindRef(EJamRuleTrigger::OnFaceoff) >= 1);
		TestTrue(TEXT("the hook saw period 1 start"), Hook.Seen.FindRef(EJamRuleTrigger::OnPeriodStart) >= 1);
	}
	TestEqual(TEXT("an empty modifier source leaves every frame hash as it was"), WithEmptySource, Plain);
	TestEqual(TEXT("a hook with no actions leaves every frame hash as it was"), WithEmptyHook, Plain);
	AddInfo(FString::Printf(TEXT("hockey.regular seed 1 frame 600 hash %016llx (compare with Jam.Core.Determinism)"), static_cast<unsigned long long>(Plain.Last())));

	// 2. One modifier: resolves per target, clamps, changes the hash.
	{
		FListSource Src;
		FJamActiveModifier M;
		M.Id = 7;
		M.Target = EJamTarget::OtherTeam;
		M.SourceSkater = 0;   // team 0's first skater; the other team gets the modifier
		M.FramesLeft = 100;
		M.Kind = FName(TEXT("slow_them"));
		M.Stats.Add({ EJamStat::SkaterSpeed, 0.5f, 0.f });
		M.Stats.Add({ EJamStat::ShotSpeed, 1.f, 100.f });   // clamps to the schema max 40
		Src.List.Add(M);
		FJamActiveModifier P;
		P.Id = 8;
		P.Target = EJamTarget::Puck;
		P.Stats.Add({ EJamStat::PuckDrag, 1.f, 0.25f });
		Src.List.Add(P);

		UJamSim* Sim = MakeSim(G, 1);
		Sim->SetModifierSource(&Src);
		TArray<FJamInput> None;
		Sim->Step(None);
		int32 Team1 = -1;
		for (const FJamSkaterState& S : Sim->GetSkaters()) if (S.Team == 1) { Team1 = S.Index; break; }
		TestEqual(TEXT("own team keeps the base speed"), Sim->GetEffectiveStat(EJamStat::SkaterSpeed, 0), G.Skater.Speed);
		TestEqual(TEXT("other team skates at half speed"), Sim->GetEffectiveStat(EJamStat::SkaterSpeed, Team1), G.Skater.Speed * 0.5);
		TestEqual(TEXT("shot speed add clamps to the schema max"), Sim->GetEffectiveStat(EJamStat::ShotSpeed, Team1), 40.0);
		TestEqual(TEXT("puck drag adds"), Sim->GetEffectiveStat(EJamStat::PuckDrag, -1), G.Puck.Drag + 0.25);
		TestEqual(TEXT("untouched stat is the base"), Sim->GetEffectiveStat(EJamStat::SkaterAccel, Team1), G.Skater.Accel);
		TestEqual(TEXT("two modifiers active"), Sim->GetActiveModifiers().Num(), 2);
		TestNotEqual(TEXT("an active modifier changes the frame hash"), Sim->StateHash(), Plain[0]);
		// Same modifiers twice = same hash (deterministic).
		UJamSim* Sim2 = MakeSim(G, 1);
		Sim2->SetModifierSource(&Src);
		Sim2->Step(None);
		TestEqual(TEXT("the same modifiers give the same hash"), Sim2->StateHash(), Sim->StateHash());
		// The other team is really slower: a team-1 skater at full input for 120 frames.
		TArray<FJamInput> In;
		In.SetNum(Sim->GetSkaters().Num());
		In[0].Move = FVector2D(1, 0);
		In[Team1].Move = FVector2D(1, 0);
		for (int32 F = 0; F < 120; ++F) Sim->Step(In);
		AddInfo(FString::Printf(TEXT("after 120 frames: skater 0 %.2f m/s, skater %d (other team, x0.5) %.2f m/s"), Sim->GetSkaters()[0].Vel.Size(), Team1, Sim->GetSkaters()[Team1].Vel.Size()));
		TestTrue(TEXT("the modified skater is slower"), Sim->GetSkaters()[Team1].Vel.Size() < Sim->GetSkaters()[0].Vel.Size() * 0.7);
		Sim->SetModifierSource(nullptr);
		Sim2->SetModifierSource(nullptr);
	}

	// 3. Rule actions in the frame of their trigger: AddScore + Announce on a goal, SetParam on a frame, ShrinkRink at the next faceoff, Restart undoes it.
	{
		FScriptHook Hook;
		Hook.Answers.Add(EJamRuleTrigger::OnGoal, { Act(EJamRuleAction::AddScore, -1, 1.f), Act(EJamRuleAction::Announce, -1, 0.f, nullptr, TEXT("GOALS COUNT DOUBLE")),
			Act(EJamRuleAction::ShrinkRink, -1, 0.5f), Act(EJamRuleAction::SpawnPickup, -1, 0.f), Act(EJamRuleAction::ApplyModifier, -1, 0.f) });
		Hook.FrameForOnFrame = 10;
		Hook.Answers.Add(EJamRuleTrigger::OnFrame, { Act(EJamRuleAction::SetParam, -1, 13.f, TEXT("skater_speed")) });

		UJamSim* Sim = MakeSim(G, 1);
		Sim->SetRuleHook(&Hook);
		EmptyIce(Sim);
		TArray<FJamSimEvent> GoalEvents;
		const int32 GoalFrame = PlayToGoal(Sim, 1800, &GoalEvents);
		TestTrue(TEXT("the scripted human scored"), GoalFrame > 0);
		TestEqual(TEXT("SetParam skater_speed landed at frame 10"), Sim->GetConfig().Skater.Speed, 13.0);
		const int32 Human = Sim->GetHumanTeam();
		TestEqual(TEXT("a goal plus AddScore 1 = 2 points, same frame"), Sim->GetScore(Human), 2);
		bool bAnnounced = false;
		for (const FJamSimEvent& E : GoalEvents) if (E.Name == JamEvents::Announce && E.Text == TEXT("GOALS COUNT DOUBLE") && E.Kind == FName(TEXT("rule"))) bAnnounced = true;
		TestTrue(TEXT("announce event with its text in the goal frame"), bAnnounced);
		TArray<FJamRuleRequest> Pickups, Mods;
		Sim->TakePickupRequests(Pickups);
		Sim->TakeModifierRequests(Mods);
		TestEqual(TEXT("one SpawnPickup request queued"), Pickups.Num(), 1);
		TestEqual(TEXT("one ApplyModifier request queued"), Mods.Num(), 1);
		if (Mods.Num()) TestEqual(TEXT("the request carries its cause"), Mods[0].Cause.Trigger, EJamRuleTrigger::OnGoal);
		Sim->TakePickupRequests(Pickups);
		TestEqual(TEXT("requests drain once"), Pickups.Num(), 1);
		TestEqual(TEXT("rink unchanged until the faceoff"), Sim->GetConfig().Rink.LengthM, G.Rink.LengthM);
		TArray<FJamInput> None;
		for (int32 F = 0; F < G.Rules.GoalPauseFrames + 2; ++F) Sim->Step(None);
		TestEqual(TEXT("rink halved at the faceoff"), Sim->GetConfig().Rink.LengthM, FMath::Max(40.0, G.Rink.LengthM * 0.5));
		TestEqual(TEXT("rink revision 1"), Sim->GetRinkRevision(), 1);
		FVector2D N;
		for (const FJamSkaterState& S : Sim->GetSkaters()) TestTrue(*FString::Printf(TEXT("skater %d inside the smaller rink"), S.Index), Sim->BoardDistance(S.Pos, N) < 0);
		Sim->Restart();
		TestEqual(TEXT("Restart restores the rink"), Sim->GetConfig().Rink.LengthM, G.Rink.LengthM);
		TestEqual(TEXT("Restart resets the score"), Sim->GetScore(Human), 0);
		Sim->SetRuleHook(nullptr);
	}

	// 4. EndMatch and SwapNets.
	{
		FScriptHook Hook;
		Hook.Answers.Add(EJamRuleTrigger::OnGoal, { Act(EJamRuleAction::EndMatch) });
		UJamSim* Sim = MakeSim(G, 1);
		Sim->SetRuleHook(&Hook);
		EmptyIce(Sim);
		TestTrue(TEXT("scored"), PlayToGoal(Sim, 1800, nullptr) > 0);
		TestEqual(TEXT("EndMatch on the first goal ends the match"), Sim->GetPhase(), EJamSimPhase::Over);
		TestEqual(TEXT("the scoring team wins"), Sim->GetWinner(), Sim->GetHumanTeam());
		Sim->SetRuleHook(nullptr);

		FScriptHook Swap;
		Swap.FrameForOnFrame = 1;
		Swap.Answers.Add(EJamRuleTrigger::OnFrame, { Act(EJamRuleAction::SwapNets) });
		UJamSim* S2 = MakeSim(G, 1);
		S2->SetRuleHook(&Swap);
		TArray<FJamInput> None;
		S2->Step(None);
		TestTrue(TEXT("nets swapped"), S2->AreNetsSwapped());
		TestEqual(TEXT("team 0 now attacks -x"), S2->AttackGoalX(0), -S2->GoalLineX());
		S2->SetRuleHook(nullptr);
	}
	return true;
}

} // namespace JamSeamTests

#endif
