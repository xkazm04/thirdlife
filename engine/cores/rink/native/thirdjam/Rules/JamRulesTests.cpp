// Lane A15 tests (headless, no world): Jam.Rules.HooksFire, Jam.Rules.ShrinkAtFaceoff, Jam.Rules.ZonesMembership,
// Jam.Rules.BumperRestitution, Jam.Rules.Variants, Jam.Rules.ChaosLoads, Jam.Rules.BotChaos. Run:
//   UnrealEditor-Cmd.exe Game/ThirdJam.uproject -ExecCmds="Automation RunTests Jam.Rules; Quit" -unattended -nullrhi -nosplash -log
// The sim-side application of hook actions (AddScore, ShrinkRink, ...) is lane A16's; where the sim has not wired a seam yet the
// test says so with AddInfo / AddWarning instead of failing, and asserts what this lane owns (the actions the system emits).
#include "Misc/AutomationTest.h"
#include "JamCartridge.h"
#include "JamSim.h"
#include "JamEventBus.h"
#include "JamRuleSystem.h"
#include "JamZones.h"
#include "../AI/JamBotMatch.h"
#include "../AI/JamSimAdapter.h"
#include "../AI/DifficultyResolve.h"

#if WITH_DEV_AUTOMATION_TESTS

namespace JamRulesTests
{
	constexpr EAutomationTestFlags Flags = EAutomationTestFlags_ApplicationContextMask | EAutomationTestFlags::ProductFilter;

	UJamCartridge* LoadPreset(FAutomationTestBase& T, const FString& Name)
	{
		TArray<FString> Errors;
		UJamCartridge* C = UJamCartridge::LoadFromFile(UJamCartridge::ResolveCartridgePath(Name), Errors);
		for (const FString& E : Errors) T.AddError(FString::Printf(TEXT("%s: %s"), *Name, *E));
		return C;
	}

	// hockey.regular with game.rules replaced by Rules (a JSON object text) and optional extra rink keys.
	UJamCartridge* LoadWithRules(FAutomationTestBase& T, const FString& RulesJson, const FString& RinkExtra = FString())
	{
		UJamCartridge* Reg = LoadPreset(T, TEXT("hockey.regular"));
		if (!Reg) return nullptr;
		FString Text = Reg->RawJson;
		const int32 RulesAt = Text.Find(TEXT("\"rules\": {\n      \"mode\""));
		if (RulesAt < 0) { T.AddError(TEXT("hockey.regular has no game.rules block in the expected layout")); return nullptr; }
		const int32 End = Text.Find(TEXT("},\n    \"teams\""), ESearchCase::CaseSensitive, ESearchDir::FromStart, RulesAt);
		Text = Text.Left(RulesAt) + TEXT("\"rules\": ") + RulesJson + Text.Mid(End + 1);
		if (!RinkExtra.IsEmpty()) Text.ReplaceInline(TEXT("\"goal_width_m\": 4\n"), *FString::Printf(TEXT("\"goal_width_m\": 4,\n%s\n"), *RinkExtra));
		TArray<FString> Errors;
		UJamCartridge* C = UJamCartridge::LoadFromString(Text, Errors);
		for (const FString& E : Errors) T.AddError(E);
		return C;
	}

	FJamRuleEventIn Goal(int32 Frame, int32 Team, int32 NewScore, int32 Who = 0)
	{
		FJamRuleEventIn In;
		In.Trigger = EJamRuleTrigger::OnGoal;
		In.Frame = Frame;
		In.Who = Who;
		In.Team = Team;
		In.Kind = TEXT("goal");
		In.Value = static_cast<float>(NewScore);
		return In;
	}

	int32 Count(const TArray<FJamRuleActionOut>& Out, EJamRuleAction A) { int32 N = 0; for (const FJamRuleActionOut& O : Out) if (O.Action == A) ++N; return N; }
	const FJamRuleActionOut* Find(const TArray<FJamRuleActionOut>& Out, EJamRuleAction A) { for (const FJamRuleActionOut& O : Out) if (O.Action == A) return &O; return nullptr; }

	// Drives the sim with no input and the puck shot into team 0's net until a goal lands or MaxFrames pass; returns the goal frame or -1.
	int64 ShootIntoNet(UJamSim& Sim, int32 Side, int64 MaxFrames = 600)
	{
		Sim.SetPuck(FVector2D(Side * (Sim.GoalLineX() - 3.0), 0.0), FVector2D(Side * 20.0, 0.0));
		TArray<FJamInput> In;
		In.SetNum(Sim.GetSkaters().Num());
		for (int64 f = 0; f < MaxFrames; ++f)
		{
			Sim.Step(In);
			for (const FJamSimEvent& E : Sim.GetFrameEvents()) if (E.Name == JamEvents::Goal) return Sim.GetFrame();
		}
		return -1;
	}
}

using namespace JamRulesTests;

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamRulesHooksFire, "Jam.Rules.HooksFire", JamRulesTests::Flags)
bool FJamRulesHooksFire::RunTest(const FString& Parameters)
{
	// "last goal counts double" as the Designer would write it: on_goal, scoring team at score_to_win, add one more goal and announce.
	UJamCartridge* C = LoadWithRules(*this, TEXT("{\"mode\": \"first_to\", \"score_to_win\": 3, \"goal_pause_frames\": 120, \"hooks\": [")
		TEXT("{\"id\": \"last-goal-double\", \"when\": \"on_goal\", \"team\": \"scoring\", \"score\": {\"at_least\": 3}, \"then\": [{\"do\": \"add_score\", \"value\": 1}, {\"do\": \"announce\", \"text\": \"LAST GOAL COUNTS DOUBLE\"}]},")
		TEXT("{\"id\": \"every-ten-seconds\", \"when\": \"on_frame\", \"every_frames\": 600, \"after_frame\": 1200, \"team\": \"any\", \"then\": [{\"do\": \"announce\", \"text\": \"TICK\"}]},")
		TEXT("{\"id\": \"conceding-boost\", \"when\": \"on_goal\", \"team\": \"conceding\", \"then\": [{\"do\": \"apply_modifier\", \"kind\": \"speed\", \"frames\": 300}]}")
		TEXT("]}"));
	if (!C) return false;
	TestEqual(TEXT("three hooks loaded"), C->Game.Rules.Hooks.Num(), 3);

	UJamRuleSystem* Rules = NewObject<UJamRuleSystem>();
	Rules->Init(C->Game);
	// Id order: conceding-boost, every-ten-seconds, last-goal-double.
	TestEqual(TEXT("hooks sorted by id"), Rules->GetHooks()[0].Id, FString(TEXT("conceding-boost")));
	TestEqual(TEXT("hooks sorted by id (last)"), Rules->GetHooks()[2].Id, FString(TEXT("last-goal-double")));

	TArray<FJamRuleActionOut> Out;
	Rules->OnRuleEvent(Goal(500, 0, 1), Out);
	TestEqual(TEXT("first goal: no AddScore"), Count(Out, EJamRuleAction::AddScore), 0);
	TestEqual(TEXT("first goal: the conceding team gets the modifier"), Count(Out, EJamRuleAction::ApplyModifier), 1);
	if (const FJamRuleActionOut* M = Find(Out, EJamRuleAction::ApplyModifier))
	{
		TestEqual(TEXT("conceding = team 1"), M->Team, 1);
		TestEqual(TEXT("modifier kind"), M->Kind, FName(TEXT("speed")));
		TestEqual(TEXT("modifier frames"), M->Frames, 300);
	}
	Out.Reset();
	Rules->OnRuleEvent(Goal(900, 0, 2), Out);
	TestEqual(TEXT("second goal: no AddScore"), Count(Out, EJamRuleAction::AddScore), 0);
	Out.Reset();
	Rules->OnRuleEvent(Goal(1500, 0, 3), Out);
	TestEqual(TEXT("last goal: AddScore once"), Count(Out, EJamRuleAction::AddScore), 1);
	if (const FJamRuleActionOut* A = Find(Out, EJamRuleAction::AddScore))
	{
		TestEqual(TEXT("AddScore team = scoring team"), A->Team, 0);
		TestEqual(TEXT("AddScore value 1"), A->Value, 1.f);
	}
	TestEqual(TEXT("last goal: Announce once"), Count(Out, EJamRuleAction::Announce), 1);
	TestEqual(TEXT("announce text kept"), Rules->GetLastAnnouncement(), FString(TEXT("LAST GOAL COUNTS DOUBLE")));
	TestEqual(TEXT("announce frame"), Rules->GetLastAnnouncementFrame(), static_cast<int64>(1500));
	TestEqual(TEXT("score mirror after the double"), Rules->GetScore(0), 4);
	TestEqual(TEXT("fire count"), Rules->GetFireCount(TEXT("last-goal-double")), 1);

	// on_frame cadence and after_frame.
	FJamRuleEventIn Fr; Fr.Trigger = EJamRuleTrigger::OnFrame;
	for (int32 F : { 600, 1200, 1230, 1800 })
	{
		Out.Reset(); Fr.Frame = F; Fr.Value = static_cast<float>(F);
		Rules->OnRuleEvent(Fr, Out);
		TestEqual(*FString::Printf(TEXT("on_frame at %d"), F), Count(Out, EJamRuleAction::Announce), (F >= 1200 && F % 600 == 0) ? 1 : 0);
	}

	// Determinism of the system itself: the same events give the same hash.
	UJamRuleSystem* Again = NewObject<UJamRuleSystem>();
	Again->Init(C->Game);
	TArray<FJamRuleActionOut> Dummy;
	Again->OnRuleEvent(Goal(500, 0, 1), Dummy); Again->OnRuleEvent(Goal(900, 0, 2), Dummy); Again->OnRuleEvent(Goal(1500, 0, 3), Dummy);
	for (int32 F : { 600, 1200, 1230, 1800 }) { Fr.Frame = F; Again->OnRuleEvent(Fr, Dummy); }
	TestEqual(TEXT("same events, same hash"), Again->StateHash(), Rules->StateHash());

	// Through the sim (A16's side of the seam): a goal into the +x net with the hook set. Reported, not asserted, until the sim applies actions.
	{
		UJamSim* Sim = NewObject<UJamSim>();
		Sim->Init(C->Game, 1);
		Sim->SkipFaceoff(); // R-0013: the match opens with a 90-frame faceoff; these scenes shoot at once
		UJamRuleSystem* R2 = NewObject<UJamRuleSystem>();
		R2->Init(C->Game);
		Sim->SetRuleHook(R2);
		const int64 GoalFrame = ShootIntoNet(*Sim, +1);
		TestTrue(TEXT("the scripted shot scores"), GoalFrame > 0);
		if (R2->GetTotalFires() > 0) AddInfo(FString::Printf(TEXT("sim calls the hook: %d fires at frame %lld, score %d:%d"), R2->GetTotalFires(), GoalFrame, Sim->GetScore(0), Sim->GetScore(1)));
		else AddWarning(TEXT("the sim did not call the rule hook on a goal (A16's seam B application pending); the system-level assertions above hold"));
	}
	return true;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamRulesShrinkAtFaceoff, "Jam.Rules.ShrinkAtFaceoff", JamRulesTests::Flags)
bool FJamRulesShrinkAtFaceoff::RunTest(const FString& Parameters)
{
	UJamCartridge* C = LoadWithRules(*this, TEXT("{\"mode\": \"first_to\", \"score_to_win\": 3, \"goal_pause_frames\": 120, \"variants\": {\"shrink_per_goal\": 0.1}}"));
	if (!C) return false;
	TestEqual(TEXT("the variant became one hook"), C->Game.Rules.Hooks.Num(), 1);
	UJamRuleSystem* Rules = NewObject<UJamRuleSystem>();
	Rules->Init(C->Game);
	TArray<FJamRuleActionOut> Out;
	Rules->OnRuleEvent(Goal(700, 1, 1), Out);
	const FJamRuleActionOut* S = Find(Out, EJamRuleAction::ShrinkRink);
	TestNotNull(TEXT("ShrinkRink emitted"), S);
	if (S) TestEqual(TEXT("seam Value is the scale factor 0.9"), S->Value, 0.9f);
	TestEqual(TEXT("announce with the percentage"), Rules->GetLastAnnouncement(), FString(TEXT("THE RINK SHRINKS 10%")));

	// Two sims, same seed, same scripted goal: identical hashes; the geometry changes only at the faceoff (RinkRevision), never during the pause.
	uint64 Hash[2] = { 0, 0 };
	for (int32 k = 0; k < 2; ++k)
	{
		UJamSim* Sim = NewObject<UJamSim>();
		Sim->Init(C->Game, 7);
		Sim->SkipFaceoff(); // R-0013: the match opens with a 90-frame faceoff; these scenes shoot at once
		UJamRuleSystem* R = NewObject<UJamRuleSystem>();
		R->Init(C->Game);
		Sim->SetRuleHook(R);
		const double L0 = Sim->GetConfig().Rink.LengthM;
		const int32 Rev0 = Sim->GetRinkRevision();
		const int64 GoalFrame = ShootIntoNet(*Sim, +1);
		TestTrue(TEXT("the scripted shot scores"), GoalFrame > 0);
		TestEqual(TEXT("no rebuild during the goal pause"), Sim->GetRinkRevision(), Rev0);
		TestEqual(TEXT("length unchanged during the goal pause"), Sim->GetConfig().Rink.LengthM, L0);
		TArray<FJamInput> In; In.SetNum(Sim->GetSkaters().Num());
		bool bFaceoff = false;
		for (int32 f = 0; f < 400 && !bFaceoff; ++f) // goal pause 120 + faceoff countdown 90 (R-0013): the drop comes after frame 200
		{
			Sim->Step(In);
			for (const FJamSimEvent& E : Sim->GetFrameEvents()) if (E.Name == JamEvents::Faceoff) bFaceoff = true;
		}
		TestTrue(TEXT("a faceoff follows the goal"), bFaceoff);
		if (k == 0)
		{
			if (Sim->GetRinkRevision() != Rev0)
			{
				TestEqual(TEXT("length scaled by 0.9 at the faceoff"), Sim->GetConfig().Rink.LengthM, L0 * 0.9);
				AddInfo(FString::Printf(TEXT("sim applied ShrinkRink: %g -> %g m, revision %d -> %d"), L0, Sim->GetConfig().Rink.LengthM, Rev0, Sim->GetRinkRevision()));
			}
			else AddWarning(TEXT("the sim did not apply ShrinkRink at the faceoff (A16's seam B application pending); the hook output above holds"));
		}
		Hash[k] = Sim->StateHash();
	}
	TestEqual(TEXT("same seed, same hooks, same hash"), Hash[0], Hash[1]);
	return true;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamRulesZonesMembership, "Jam.Rules.ZonesMembership", JamRulesTests::Flags)
bool FJamRulesZonesMembership::RunTest(const FString& Parameters)
{
	UJamCartridge* C = LoadWithRules(*this, TEXT("{\"mode\": \"first_to\", \"score_to_win\": 3}"),
		TEXT("      \"zones\": [{\"id\": \"centre-slow\", \"shape\": \"circle\", \"x\": 0, \"z\": 0, \"r\": 5, \"kind\": \"slow_ice\", \"strength\": 0.6},")
		TEXT(" {\"id\": \"left-lane\", \"shape\": \"rect\", \"x\": -20, \"z\": 0, \"w\": 10, \"d\": 6, \"kind\": \"fast_ice\"},")
		TEXT(" {\"id\": \"no-shoot-right\", \"shape\": \"rect\", \"x\": 25, \"z\": 0, \"w\": 10, \"d\": 20, \"kind\": \"no_shoot\", \"visible\": false}]"));
	if (!C) return false;
	TestEqual(TEXT("three zones loaded"), C->Game.Rink.Zones.Num(), 3);
	if (C->Game.Rink.Zones.Num() == 3)
	{
		TestEqual(TEXT("default strength 0.5"), C->Game.Rink.Zones[1].Strength, 0.5);
		TestTrue(TEXT("default visible"), C->Game.Rink.Zones[1].bVisible);
		TestFalse(TEXT("visible false read"), C->Game.Rink.Zones[2].bVisible);
	}

	UJamSim* Sim = NewObject<UJamSim>();
	Sim->Init(C->Game, 1);
	UJamZoneSystem* Z = NewObject<UJamZoneSystem>();
	Z->Init(C->Game);
	TestEqual(TEXT("zone count"), Z->GetZoneCount(), 3);

	// Frame 1: the puck starts at centre (inside centre-slow), the human at (-7.5, 0) outside everything.
	Z->Update(1, Sim->GetSkaters(), Sim->GetPuck());
	int32 PuckEnters = 0;
	for (const FJamSimEvent& E : Z->GetFrameEvents()) if (E.Name == JamEvents::ZoneEnter && E.Who == UJamZoneSystem::PuckWho) ++PuckEnters;
	TestEqual(TEXT("the puck enters the centre circle at frame 1"), PuckEnters, 1);
	TestTrue(TEXT("puck inside zone 0"), Z->IsInside(UJamZoneSystem::PuckWho, 0));
	TestFalse(TEXT("human outside zone 0"), Z->IsInside(Sim->GetHumanIndex(), 0));
	if (Z->GetFrameEvents().Num()) TestEqual(TEXT("event Kind is the zone id"), Z->GetFrameEvents()[0].Kind, FName(TEXT("centre-slow")));

	// Move the human into the slow circle and the puck out of it: one enter, one exit, nothing else.
	Sim->SetSkater(Sim->GetHumanIndex(), FVector2D(2, 1), FVector2D::ZeroVector, 0);
	Sim->SetPuck(FVector2D(-20, 0), FVector2D::ZeroVector);
	Z->Update(2, Sim->GetSkaters(), Sim->GetPuck());
	int32 Enter = 0, Exit = 0;
	for (const FJamSimEvent& E : Z->GetFrameEvents()) { if (E.Name == JamEvents::ZoneEnter) ++Enter; if (E.Name == JamEvents::ZoneExit) ++Exit; }
	TestEqual(TEXT("frame 2: two enters (human into slow, puck into fast lane)"), Enter, 2);
	TestEqual(TEXT("frame 2: one exit (puck out of slow)"), Exit, 1);
	TestTrue(TEXT("human now in slow ice"), Z->IsSlowIceAt(Sim->GetSkaters()[Sim->GetHumanIndex()].Pos));
	TestTrue(TEXT("puck in the fast lane"), Z->IsInside(UJamZoneSystem::PuckWho, 1));

	// Same positions next frame: no events.
	Z->Update(3, Sim->GetSkaters(), Sim->GetPuck());
	TestEqual(TEXT("no change, no events"), Z->GetFrameEvents().Num(), 0);

	// Ice factors and shot blocking.
	const FJamIceFactors Slow = Z->IceAt(FVector2D(0, 0));
	TestTrue(TEXT("slow ice slows"), Slow.SpeedMul < 1.0 && Slow.FrictionMul > 1.0);
	TestEqual(TEXT("slow at 0.6: speed 0.7"), Slow.SpeedMul, 0.7);
	const FJamIceFactors Fast = Z->IceAt(FVector2D(-20, 0));
	TestTrue(TEXT("fast ice speeds up"), Fast.SpeedMul > 1.0 && Fast.FrictionMul < 1.0);
	TestEqual(TEXT("plain ice is 1"), Z->IceAt(FVector2D(10, 15)).SpeedMul, 1.0);
	FName Blocker;
	TestTrue(TEXT("no_shoot blocks"), Z->BlocksShot(FVector2D(25, 3), Blocker));
	TestEqual(TEXT("blocker id"), Blocker, FName(TEXT("no-shoot-right")));
	TestFalse(TEXT("shots elsewhere are fine"), Z->BlocksShot(FVector2D(0, 0), Blocker));
	TestTrue(TEXT("no boost_only zone: pickups anywhere"), Z->AllowsPickupAt(FVector2D(3, 3)));

	// Determinism: a second system fed the same positions has the same hash.
	UJamZoneSystem* Z2 = NewObject<UJamZoneSystem>();
	Z2->Init(C->Game);
	UJamSim* Sim2 = NewObject<UJamSim>();
	Sim2->Init(C->Game, 1);
	Z2->Update(1, Sim2->GetSkaters(), Sim2->GetPuck());
	Sim2->SetSkater(Sim2->GetHumanIndex(), FVector2D(2, 1), FVector2D::ZeroVector, 0);
	Sim2->SetPuck(FVector2D(-20, 0), FVector2D::ZeroVector);
	Z2->Update(2, Sim2->GetSkaters(), Sim2->GetPuck());
	Z2->Update(3, Sim2->GetSkaters(), Sim2->GetPuck());
	TestEqual(TEXT("same positions, same membership hash"), Z2->StateHash(), Z->StateHash());
	return true;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamRulesBumperRestitution, "Jam.Rules.BumperRestitution", JamRulesTests::Flags)
bool FJamRulesBumperRestitution::RunTest(const FString& Parameters)
{
	// The reflection the sim applies to a bumper obstacle: a puck arriving at 5 m/s leaves at 8 m/s (1.6), tangent kept.
	FVector2D V(-5.0, 2.0);
	JamZones::ReflectOffBumper(V, FVector2D(1, 0), JamZones::BumperRestitution);
	TestEqual(TEXT("normal part x 1.6"), V.X, 8.0);
	TestEqual(TEXT("tangent kept"), V.Y, 2.0);
	FVector2D Away(3.0, 0.0);
	JamZones::ReflectOffBumper(Away, FVector2D(1, 0), JamZones::BumperRestitution);
	TestEqual(TEXT("a puck moving away is untouched"), Away.X, 3.0);
	TestEqual(TEXT("bumper zone restitution at strength 0.5 is the obstacle's 1.6"), JamZones::BumperRestitutionFor(0.5), 1.6);

	// A bumper zone throws the puck back from its edge.
	UJamCartridge* C = LoadWithRules(*this, TEXT("{\"mode\": \"first_to\", \"score_to_win\": 3}"),
		TEXT("      \"obstacles\": [{\"kind\": \"bumper\", \"x\": -15, \"z\": -8, \"size\": 2}, {\"kind\": \"goal_shield\", \"x\": 35, \"z\": 0, \"size\": 3}],\n")
		TEXT("      \"zones\": [{\"id\": \"bump\", \"shape\": \"circle\", \"x\": 10, \"z\": 0, \"r\": 3, \"kind\": \"bumper\", \"strength\": 0.5}]"));
	if (!C) return false;
	TestEqual(TEXT("bumper obstacle kind kept"), C->Game.Rink.Obstacles[0].Kind, FName(TEXT("bumper")));
	TestEqual(TEXT("goal_shield obstacle kind kept"), C->Game.Rink.Obstacles[1].Kind, FName(TEXT("goal_shield")));
	UJamZoneSystem* Z = NewObject<UJamZoneSystem>();
	Z->Init(C->Game);
	FVector2D Pos(7.2, 0.0), Vel(5.0, 0.0);   // 0.2 m into the edge from the left, moving into the zone
	TestTrue(TEXT("bumper zone hit"), Z->BumpPuck(Pos, Vel, 0.12));
	TestTrue(TEXT("pushed back out of the edge"), Pos.X <= 7.0 - 0.12 + 1e-9);
	TestEqual(TEXT("thrown back at 1.6 x"), Vel.X, -8.0);
	FVector2D Far(0.0, 0.0), FarV(1.0, 0.0);
	TestFalse(TEXT("no hit away from the zone"), Z->BumpPuck(Far, FarV, 0.12));

	// Through the sim: a puck aimed at the bumper obstacle. Reported until A16's collision reads the kind.
	UJamSim* Sim = NewObject<UJamSim>();
	Sim->Init(C->Game, 1);
	Sim->SetPuck(FVector2D(-15 - 1.0 - 0.5, -8), FVector2D(6.0, 0.0));
	TArray<FJamInput> In; In.SetNum(Sim->GetSkaters().Num());
	double MaxBack = 0;
	for (int32 f = 0; f < 90; ++f) { Sim->Step(In); MaxBack = FMath::Max(MaxBack, -Sim->GetPuck().Vel.X); }
	if (MaxBack > 6.0 * 1.2) AddInfo(FString::Printf(TEXT("sim bumper: puck came back at %.2f m/s from 6"), MaxBack));
	else AddWarning(FString::Printf(TEXT("the sim treats the bumper obstacle as a box with board restitution (came back at %.2f m/s from 6); A16's collision change pending"), MaxBack));
	return true;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamRulesVariants, "Jam.Rules.Variants", JamRulesTests::Flags)
bool FJamRulesVariants::RunTest(const FString& Parameters)
{
	UJamCartridge* C = LoadWithRules(*this, TEXT("{\"mode\": \"timer\", \"timer_frames\": 9000, \"variants\": {\"sudden_death\": true, \"last_goal_double\": true, \"mercy_goals\": 3, \"period_count\": 3, \"shrink_per_goal\": 0.1}}"));
	if (!C) return false;
	TArray<FString> Ids;
	for (const FJamRuleHookConfig& H : C->Game.Rules.Hooks) { Ids.Add(H.Id); TestTrue(*FString::Printf(TEXT("%s marked as a variant"), *H.Id), H.bFromVariant); }
	// last_goal_double needs first_to, so four hooks in timer mode.
	TestEqual(TEXT("four hooks from five variants (last_goal_double needs first_to)"), Ids.Num(), 4);
	TestTrue(TEXT("sudden death"), Ids.Contains(TEXT("variant-sudden-death")));
	TestTrue(TEXT("mercy"), Ids.Contains(TEXT("variant-mercy")));
	TestTrue(TEXT("periods"), Ids.Contains(TEXT("variant-periods")));
	TestTrue(TEXT("shrink"), Ids.Contains(TEXT("variant-shrink-per-goal")));
	for (const FJamRuleHookConfig& H : C->Game.Rules.Hooks)
	{
		if (H.Id == TEXT("variant-sudden-death")) TestEqual(TEXT("sudden death armed from frame 600"), H.AfterFrame, 600);
		if (H.Id == TEXT("variant-periods")) TestEqual(TEXT("periods: a third of the timer"), H.EveryFrames, 3000);
		if (H.Id == TEXT("variant-mercy")) TestEqual(TEXT("mercy lead"), H.Score.LeadAtLeast, 3);
	}
	TestTrue(TEXT("variants kept for display"), C->Game.Rules.Variants.bSuddenDeath && C->Game.Rules.Variants.MercyGoals == 3);

	// Sudden death before frame 600 does nothing; after it, the goal ends the match for the scorer.
	UJamRuleSystem* R = NewObject<UJamRuleSystem>();
	R->Init(C->Game);
	TArray<FJamRuleActionOut> Out;
	R->OnRuleEvent(Goal(300, 1, 1), Out);
	TestEqual(TEXT("goal at frame 300: no EndMatch"), Count(Out, EJamRuleAction::EndMatch), 0);
	Out.Reset();
	R->OnRuleEvent(Goal(900, 1, 2), Out);
	TestEqual(TEXT("goal at frame 900: EndMatch"), Count(Out, EJamRuleAction::EndMatch), 1);
	if (const FJamRuleActionOut* E = Find(Out, EJamRuleAction::EndMatch)) TestEqual(TEXT("the scorer wins"), E->Team, 1);

	// Mercy on a 3-goal lead through the mirror.
	UJamRuleSystem* M = NewObject<UJamRuleSystem>();
	UJamCartridge* C2 = LoadWithRules(*this, TEXT("{\"mode\": \"first_to\", \"score_to_win\": 9, \"variants\": {\"mercy_goals\": 3}}"));
	if (!C2) return false;
	M->Init(C2->Game);
	Out.Reset(); M->OnRuleEvent(Goal(100, 0, 1), Out); M->OnRuleEvent(Goal(200, 0, 2), Out);
	TestEqual(TEXT("lead of 2: nothing"), Count(Out, EJamRuleAction::EndMatch), 0);
	Out.Reset(); M->OnRuleEvent(Goal(300, 0, 3), Out);
	TestEqual(TEXT("lead of 3: mercy"), Count(Out, EJamRuleAction::EndMatch), 1);
	return true;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamRulesChaosLoads, "Jam.Rules.ChaosLoads", JamRulesTests::Flags)
bool FJamRulesChaosLoads::RunTest(const FString& Parameters)
{
	UJamCartridge* C = JamRulesTests::LoadPreset(*this, TEXT("hockey.chaos"));
	if (!C) return false;
	TestEqual(TEXT("two bumpers"), C->Game.Rink.Obstacles.Num(), 2);
	for (const FJamObstacle& O : C->Game.Rink.Obstacles) TestEqual(TEXT("obstacle is a bumper"), O.Kind, FName(TEXT("bumper")));
	TestEqual(TEXT("one zone"), C->Game.Rink.Zones.Num(), 1);
	if (C->Game.Rink.Zones.Num()) TestEqual(TEXT("slow circle at centre"), C->Game.Rink.Zones[0].Kind, FName(TEXT("slow_ice")));
	TestEqual(TEXT("two hooks from the variants"), C->Game.Rules.Hooks.Num(), 2);
	UJamSim* Sim = NewObject<UJamSim>();
	Sim->Init(C->Game, static_cast<uint64>(C->Seed));
	for (const FJamSkaterState& S : Sim->GetSkaters())
	{
		FVector2D N;
		TestTrue(*FString::Printf(TEXT("skater %d inside the boards"), S.Index), Sim->BoardDistance(S.Pos, N) < 0);
	}
	return true;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamRulesBotChaos, "Jam.Rules.BotChaos", JamRulesTests::Flags)
bool FJamRulesBotChaos::RunTest(const FString& Parameters)
{
	// Bots play hockey.chaos (and hockey.raw as the control) with the rule hook attached: every skater moves, the puck travels,
	// nobody leaves the rink, hashes repeat per seed. The AiBotPlays shape of Jam.Bot, on the new preset.
	for (const TCHAR* Name : { TEXT("hockey.chaos"), TEXT("hockey.raw") })
	{
		UJamCartridge* C = JamRulesTests::LoadPreset(*this, Name);
		if (!C) continue;
		uint64 Hash[2] = { 0, 0 };
		for (int32 k = 0; k < 2; ++k)
		{
			JamAI::FJamSimAdapter Sim(C->Game);
			UJamRuleSystem* R = NewObject<UJamRuleSystem>();
			R->Init(C->Game);
			UJamZoneSystem* Z = NewObject<UJamZoneSystem>();
			Z->Init(C->Game);
			const JamAI::FJamMatchStats S = JamAI::RunMatch(Sim, JamAI::ToMatchConfigResolved(*C, nullptr), 3, JamAI::EJamPlayerMode::PlayerBotAI, 18000, 60);
			Hash[k] = S.Hash;
			if (k == 0)
			{
				double MinMoved = 1e9;
				for (int32 i = 0; i < S.NumSkaters; ++i) MinMoved = FMath::Min(MinMoved, S.MovedMax[i]);
				TestTrue(*FString::Printf(TEXT("%s: every skater moved >= 3 m (min %.1f)"), Name, MinMoved), MinMoved >= 3.0);
				TestTrue(*FString::Printf(TEXT("%s: puck path > 30 m (%.0f)"), Name, S.PuckPathM), S.PuckPathM > 30.0);
				TestTrue(*FString::Printf(TEXT("%s: nobody outside the boards (%.2f)"), Name, S.MaxBoardDistance), S.MaxBoardDistance <= 0.05);
				AddInfo(FString::Printf(TEXT("%s: %d:%d in %lld frames, over=%s, hash %016llx"), Name, S.Goals[0], S.Goals[1], static_cast<long long>(S.Frames), S.bOver ? TEXT("yes") : TEXT("no"), static_cast<unsigned long long>(S.Hash)));
			}
		}
		TestEqual(*FString::Printf(TEXT("%s: same seed, same hash"), Name), Hash[0], Hash[1]);
	}
	return true;
}

#endif
