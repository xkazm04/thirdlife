// Lane A41: the zone effect trigger and the headless systems bundle (JamSimAdapter.h, FJamSystems). Headless:
//   UnrealEditor-Cmd.exe Game/ThirdJam.uproject -ExecCmds="Automation RunTests Jam.Effects.ZoneTriggerCarpet+Jam.Bot.BoostPickupsBundle+Jam.Bot.BundleKeepsRegularHash; Quit" -unattended -nullrhi -nosplash -log
#include "Misc/AutomationTest.h"
#include "Misc/FileHelper.h"
#include "Misc/Paths.h"
#include "JamCartridge.h"
#include "JamJson.h"
#include "JamSim.h"
#include "JamEffectSystem.h"
#include "JamRuleSystem.h"
#include "JamZones.h"
#include "JamSimAdapter.h"
#include "DifficultyProfile.h"
#include "JamBotMatch.h"
#include "DifficultyResolve.h"
#include "JamPlaytester.h"

#if WITH_DEV_AUTOMATION_TESTS

namespace JamSystemsTests
{
	constexpr EAutomationTestFlags Flags = EAutomationTestFlags_ApplicationContextMask | EAutomationTestFlags::ProductFilter;

	UJamCartridge* LoadPreset(FAutomationTestBase& T, const FString& Name)
	{
		TArray<FString> Errors;
		UJamCartridge* C = UJamCartridge::LoadFromFile(UJamCartridge::ResolveCartridgePath(Name), Errors);
		for (const FString& E : Errors) T.AddError(FString::Printf(TEXT("%s: %s"), *Name, *E));
		return C;
	}

	// A Designer cut by name from Game/Content/Designer/cached-cuts.json (the file the Designer ships; tools/cuts/sweep.mjs writes the same text out per cut).
	UJamCartridge* LoadCachedCut(FAutomationTestBase& T, const FString& Name)
	{
		const FString Path = FPaths::Combine(FPaths::ProjectContentDir(), TEXT("Designer"), TEXT("cached-cuts.json"));
		FString Text;
		if (!FFileHelper::LoadFileToString(Text, *Path)) { T.AddError(TEXT("cached-cuts.json not found: ") + Path); return nullptr; }
		FString Err;
		TSharedPtr<FJamJson> Root = FJamJson::Parse(Text, Err);
		TSharedPtr<FJamJson> List = Root ? Root->Get(TEXT("cuts")) : nullptr;
		if (!List || !List->IsArray()) { T.AddError(TEXT("cached-cuts.json unreadable: ") + Err); return nullptr; }
		for (const TSharedPtr<FJamJson>& E : List->Array)
		{
			if (!E || !E->IsObject()) continue;
			TSharedPtr<FJamJson> N = E->Get(TEXT("name"));
			if (!N || !N->IsString() || N->String != Name) continue;
			TSharedPtr<FJamJson> Cart = E->Get(TEXT("cartridge"));
			if (!Cart || !Cart->IsObject()) break;
			TArray<FString> Errors;
			UJamCartridge* C = UJamCartridge::LoadFromString(Cart->ToCompact(), Errors);
			for (const FString& Er : Errors) T.AddError(FString::Printf(TEXT("%s: %s"), *Name, *Er));
			return C;
		}
		T.AddError(TEXT("cut not in cached-cuts.json: ") + Name);
		return nullptr;
	}

	// One match through the adapter with the bundle; the systems' counters are read before the adapter goes.
	struct FOutcome
	{
		JamAI::FJamMatchStats Stats;
		int32 ZoneEnters = 0, EffectsStarted = 0, PickupsSpawned = 0, PickupsTaken = 0, Hooks = 0, RuleFires = 0;
		uint64 SystemsHash = 0;
		bool bBuilt = false;
	};

	FOutcome Play(const UJamCartridge& Cart, uint64 Seed, const TCHAR* Level, JamAI::EJamPlayerMode Mode, int64 MaxFrames, const char* Tune = nullptr)
	{
		FOutcome O;
		JamAI::FJamSimAdapter Sim(Cart);
		JamAI::FJamMatchConfig Cfg = JamAI::ToMatchConfigResolved(Cart, Level);
		if (Tune) { char Err[200] = {}; JamAI::ApplyDifficultyTune(Tune, Cfg.AI, Err, sizeof(Err)); }   // lane A202: a brain tune for one test (below)
		O.Stats = JamAI::RunMatch(Sim, Cfg, Seed, Mode, MaxFrames, 600);
		const JamAI::FJamSystems& S = Sim.GetSystems();
		O.bBuilt = Sim.HasSystems() && S.IsBuilt();
		if (O.bBuilt)
		{
			O.ZoneEnters = S.Zones->GetEnterCount();
			O.EffectsStarted = S.Effects->GetEffectsStarted();
			O.PickupsSpawned = S.Effects->GetPickupsSpawned();
			O.PickupsTaken = S.Effects->GetPickupsTaken();
			O.Hooks = S.Rules->GetHookCount();
			O.RuleFires = S.Rules->GetTotalFires();
			O.SystemsHash = S.StateHash();
		}
		return O;
	}
}

using namespace JamSystemsTests;

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamEffectsZoneTriggerCarpet, "Jam.Effects.ZoneTriggerCarpet", JamSystemsTests::Flags)
bool FJamEffectsZoneTriggerCarpet::RunTest(const FString& Parameters)
{
	// Carpet Cut: effect carpet-stick (target puck, trigger zone_enter on zone carpet-band). A37's sweep counted 291 entries and 0 effects
	// started: the effect system read the sim's events, the zone events live in UJamZoneSystem. Now it reads them through the sim's zone source.
	UJamCartridge* C = LoadCachedCut(*this, TEXT("Carpet Cut"));
	if (!C) return false;
	TestEqual(TEXT("the cut carries one zone"), C->Game.Rink.Zones.Num(), 1);

	// 1. Unit: the puck placed inside the band starts the effect on the next step; a skater alone does not (the target is the puck).
	{
		UJamSim* Sim = NewObject<UJamSim>();
		UJamZoneSystem* Zones = NewObject<UJamZoneSystem>();
		Zones->Init(C->Game);
		Sim->SetZoneSource(Zones);
		Sim->Init(C->Game, 1);
		Sim->SkipFaceoff();
		UJamEffectSystem* Fx = NewObject<UJamEffectSystem>();
		TArray<FString> Errors;
		Fx->Init(Sim, C->RawJson, Errors);
		for (const FString& E : Errors) AddError(E);
		TArray<FJamInput> Inputs;
		Inputs.SetNum(Sim->GetSkaters().Num());
		auto Step = [&]() { Sim->Step(Inputs); Zones->Update(Sim->GetFrame(), Sim->GetSkaters(), Sim->GetPuck()); Fx->Step(); };
		const FJamZoneConfig& Z = C->Game.Rink.Zones[0];
		TestEqual(TEXT("the band is carpet-band"), Z.Id, FString(TEXT("carpet-band")));
		// Everyone starts outside the band: move the puck far away first so the first Update settles membership.
		Sim->SetPuck(FVector2D(Z.X + Z.W * 0.5 + 10.0, Z.Z), FVector2D::ZeroVector);   // 10 m past the band's edge, inside the 90 x 45 rink
		Step();
		const int32 Started0 = Fx->GetEffectsStarted();
		// A skater steps onto the band: zone_enter for a skater, no puck-target effect.
		Sim->SetSkater(0, FVector2D(Z.X, Z.Z), FVector2D::ZeroVector, 0.0);
		Step();
		TestTrue(TEXT("the skater's entry was seen"), Zones->GetEnterCount() >= 1);
		TestEqual(TEXT("a skater's entry does not start the puck effect"), Fx->GetEffectsStarted(), Started0);
		// The puck rolls onto the band: carpet-stick starts, puck drag x3 from the next frame.
		const double Drag0 = Sim->GetEffectiveStat(EJamStat::PuckDrag, -1);
		Sim->SetPuck(FVector2D(Z.X, Z.Z), FVector2D::ZeroVector);
		Step();
		TestEqual(TEXT("the puck's entry starts carpet-stick"), Fx->GetEffectsStarted(), Started0 + 1);
		int32 Starts = 0;
		for (const FJamSimEvent& E : Fx->GetFrameEvents()) if (E.Name == JamEffects::EffectStart && E.Kind == FName(TEXT("carpet-stick"))) ++Starts;
		TestEqual(TEXT("effect_start carpet-stick emitted"), Starts, 1);
		Step();
		TestEqual(TEXT("puck drag x3 while sticky"), Sim->GetEffectiveStat(EJamStat::PuckDrag, -1), Drag0 * 3.0);
	}

	// 2. The bots play the cut through the bundle: entries and effect starts are counted, two runs agree.
	const FOutcome A = Play(*C, 1, nullptr, JamAI::EJamPlayerMode::PlayerBot, 36000);
	const FOutcome B = Play(*C, 1, nullptr, JamAI::EJamPlayerMode::PlayerBot, 36000);
	TestTrue(TEXT("the bundle is built"), A.bBuilt);
	TestTrue(TEXT("the match ended"), A.Stats.bOver);
	TestTrue(TEXT("zone entries counted"), A.ZoneEnters >= 1);
	TestTrue(TEXT("at least one effect started"), A.EffectsStarted >= 1);
	TestEqual(TEXT("two runs agree (sim hash)"), A.Stats.Hash, B.Stats.Hash);
	TestEqual(TEXT("two runs agree (systems hash)"), A.SystemsHash, B.SystemsHash);
	TestEqual(TEXT("two runs agree (frames)"), A.Stats.Frames, B.Stats.Frames);
	AddInfo(FString::Printf(TEXT("Carpet Cut seed 1: %lld frames, %d:%d, %d zone entries, %d effects started, sim hash %016llx"), static_cast<long long>(A.Stats.Frames),
		A.Stats.Goals[0], A.Stats.Goals[1], A.ZoneEnters, A.EffectsStarted, static_cast<unsigned long long>(A.Stats.Hash)));
	return true;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamBotBoostPickupsBundle, "Jam.Bot.BoostPickupsBundle", JamSystemsTests::Flags)
bool FJamBotBoostPickupsBundle::RunTest(const FString& Parameters)
{
	// hockey.boost through FJamSimAdapter(const UJamCartridge&): the three pickup kinds spawn and are taken by the bots (R-0017 point 4: all_star
	// detours for pickups), the brain's world view carries them, two runs agree. Before A41 this path had no effect system at all.
	UJamCartridge* C = LoadPreset(*this, TEXT("hockey.boost"));
	if (!C) return false;
	C->Game.Stick.PickupArcM = 0.0; C->Game.Stick.bPickupBody = false;   // lane A208: and at game.stick.pickup's neutral: under the pickup seed 1 re-rolls again and no bot drives over a pickup (the pickups' path is what this test pins)
	// Lane A202: the match is read with evolution 8 off (brain8=0): with its four rules on seed 1 re-rolls and no bot happens to take a pickup in it; the
	// pickups' path is what this test pins, not the brain's play.
	// re-pinned to LADDER SET 3, 15 Nov (the Director's ruling 07:25): the level profiles' numbers changed, no rule did: the sample match is played at
	// all_star's numbers before the set (speed 1.45, dodge 0.5), on which seed 1 has its bot take a pickup with an effect.
	const FOutcome A = Play(*C, 1, TEXT("all_star"), JamAI::EJamPlayerMode::PlayerBot, 36000, "brain8=0;speed_scale=1.45;opp.hk_dodge9_share=0.5");
	const FOutcome B = Play(*C, 1, TEXT("all_star"), JamAI::EJamPlayerMode::PlayerBot, 36000, "brain8=0;speed_scale=1.45;opp.hk_dodge9_share=0.5");
	TestTrue(TEXT("the bundle is built"), A.bBuilt);
	TestTrue(TEXT("pickups spawned"), A.PickupsSpawned >= 1);
	TestTrue(TEXT("at least one pickup taken"), A.PickupsTaken >= 1);
	TestTrue(TEXT("every take started an effect"), A.EffectsStarted >= A.PickupsTaken);
	TestEqual(TEXT("two runs agree (sim hash)"), A.Stats.Hash, B.Stats.Hash);
	TestEqual(TEXT("two runs agree (systems hash)"), A.SystemsHash, B.SystemsHash);
	// The world view the brain reads carries the pickups lying on the ice (BuildWorld reads the sim's modifier source).
	{
		JamAI::FJamSimAdapter Sim(*C);
		Sim.Reset(JamAI::ToMatchConfigResolved(*C, TEXT("all_star")), 1);
		JamAI::FJamAIInput In[JamAI::kMaxSkaters];
		int32 Seen = 0;
		for (int32 f = 0; f < 3000 && Seen == 0; ++f)
		{
			for (int32 i = 0; i < JamAI::kMaxSkaters; ++i) In[i] = JamAI::FJamAIInput();
			Sim.Step(In);
			JamAI::FJamAIWorld W;
			Sim.View(W);
			Seen = W.NumPickups;
		}
		TestTrue(TEXT("the brain's view sees a pickup within 3000 idle frames"), Seen >= 1);
	}
	AddInfo(FString::Printf(TEXT("hockey.boost all_star seed 1: %lld frames, over %s, %d spawned, %d taken, %d effects started, sim hash %016llx"), static_cast<long long>(A.Stats.Frames),
		A.Stats.bOver ? TEXT("yes") : TEXT("no"), A.PickupsSpawned, A.PickupsTaken, A.EffectsStarted, static_cast<unsigned long long>(A.Stats.Hash)));
	return true;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamBotBundleKeepsRegularHash, "Jam.Bot.BundleKeepsRegularHash", JamSystemsTests::Flags)
bool FJamBotBundleKeepsRegularHash::RunTest(const FString& Parameters)
{
	// hockey.regular has no hooks, zones, effects or pickups: the bundle must leave its sim hash exactly where the bare sim puts it (the brief's law).
	// hockey.chaos has a zone and hooks: there the bundle changes the hash by design.
	UJamCartridge* R = LoadPreset(*this, TEXT("hockey.regular"));
	if (!R) return false;
	const JamAI::FJamMatchConfig Cfg = JamAI::ToMatchConfigResolved(*R, nullptr);
	JamAI::FJamSimAdapter Bare(R->Game);
	JamAI::FJamSimAdapter Bundle(*R);
	const JamAI::FJamMatchStats A = JamAI::RunMatch(Bare, Cfg, 1, JamAI::EJamPlayerMode::PlayerBot, 6000, 600);
	const JamAI::FJamMatchStats B = JamAI::RunMatch(Bundle, Cfg, 1, JamAI::EJamPlayerMode::PlayerBot, 6000, 600);
	TestTrue(TEXT("the bundle is built"), Bundle.HasSystems() && Bundle.GetSystems().IsBuilt());
	TestEqual(TEXT("hockey.regular: bare sim and bundle agree on the hash"), A.Hash, B.Hash);
	TestEqual(TEXT("hockey.regular: and on the frames"), A.Frames, B.Frames);
	TestEqual(TEXT("hockey.regular: every checkpoint hash agrees"), A.NumHashes, B.NumHashes);
	for (int32 i = 0; i < A.NumHashes && i < B.NumHashes; ++i) if (A.Hashes[i] != B.Hashes[i]) { AddError(FString::Printf(TEXT("checkpoint %d differs"), i)); break; }
	TestEqual(TEXT("hockey.regular: no effect started"), Bundle.GetSystems().Effects->GetEffectsStarted(), 0);
	AddInfo(FString::Printf(TEXT("hockey.regular seed 1: bare %016llx bundle %016llx after %lld frames"), static_cast<unsigned long long>(A.Hash), static_cast<unsigned long long>(B.Hash), static_cast<long long>(B.Frames)));
	// A34's grid path (RunPlaytestMatch, the novice at rookie) on both grid rinks: the bundle leaves every seed's hash and length where the bare sim puts them.
	for (const TCHAR* Name : { TEXT("hockey.regular"), TEXT("hockey.arena.large") })
	{
		UJamCartridge* G = LoadPreset(*this, Name);
		if (!G) continue;
		const JamAI::FJamMatchConfig CfgG = JamAI::ToMatchConfigResolved(*G, TEXT("rookie"));
		for (uint64 Seed = 1; Seed <= 3; ++Seed)
		{
			JamAI::FJamSimAdapter BareG(G->Game);
			JamAI::FJamSimAdapter BundleG(*G);
			const JamAI::FJamPlaytestStats PA = JamAI::RunPlaytestMatch(BareG, CfgG, Seed, JamAI::EPlaytester::Novice, 36000, G->Game.Shot.ChargeFramesMax);
			const JamAI::FJamPlaytestStats PB = JamAI::RunPlaytestMatch(BundleG, CfgG, Seed, JamAI::EPlaytester::Novice, 36000, G->Game.Shot.ChargeFramesMax);
			const bool bSame = PA.Hash == PB.Hash && PA.Frames == PB.Frames;
			const FString Msg = FString::Printf(TEXT("%s rookie novice seed %llu: bare %016llx (%lld frames) bundle %016llx (%lld frames)"), Name, Seed,
				static_cast<unsigned long long>(PA.Hash), static_cast<long long>(PA.Frames), static_cast<unsigned long long>(PB.Hash), static_cast<long long>(PB.Frames));
			if (bSame) AddInfo(TEXT("PASS ") + Msg); else AddError(TEXT("FAIL ") + Msg);
		}
	}
	if (UJamCartridge* Ch = LoadPreset(*this, TEXT("hockey.chaos")))
	{
		const JamAI::FJamMatchConfig CfgC = JamAI::ToMatchConfigResolved(*Ch, nullptr);
		JamAI::FJamSimAdapter BareC(Ch->Game);
		JamAI::FJamSimAdapter BundleC(*Ch);
		const JamAI::FJamMatchStats AC = JamAI::RunMatch(BareC, CfgC, 1, JamAI::EJamPlayerMode::PlayerBot, 6000, 600);
		const JamAI::FJamMatchStats BC = JamAI::RunMatch(BundleC, CfgC, 1, JamAI::EJamPlayerMode::PlayerBot, 6000, 600);
		TestNotEqual(TEXT("hockey.chaos: the bundle changes the hash (zones and hooks are live)"), AC.Hash, BC.Hash);
		AddInfo(FString::Printf(TEXT("hockey.chaos seed 1: bare %016llx (%lld frames) bundle %016llx (%lld frames), %d hooks, %d fires, %d zone entries"),
			static_cast<unsigned long long>(AC.Hash), static_cast<long long>(AC.Frames), static_cast<unsigned long long>(BC.Hash), static_cast<long long>(BC.Frames),
			BundleC.GetSystems().Rules->GetHookCount(), BundleC.GetSystems().Rules->GetTotalFires(), BundleC.GetSystems().Zones->GetEnterCount()));
	}
	return true;
}

#endif
