// Lane A2: IJamAISim over lane A1's UJamSim, so the bot tests and the tournament run on the real simulation.
// Also the reference for wiring the brain into the game mode: View() is how a world view is built from UJamSim,
// and Step() is how bot inputs become FJamInput.
//
// Lane A41 (from A37's finding in docs/experiments/CUTS.md): the headless path used to run the bare sim, without the rule hooks,
// zones and effects the game mode wires (AHokejGameMode::BuildMatch / StepOnce), so every sweep played every cut without what the
// cut adds. FJamSystems is that wiring as one bundle, and the adapter built from a UJamCartridge carries it: the tournament, the
// cut sweep, the playtester and the Jam.Bot tests all go through it. The FJamGameConfig constructor stays the bare sim (component
// tests that bring their own systems). Order, as in the game mode: rule hook set before UJamSim::Init so the opening faceoff
// reaches it, zone source before Init, effect system bound after Init; per frame the score mirror, the sim step, the zone update,
// the effect step. docs/experiments/SWEEP-WIRING.md has the numbers that moved.
#pragma once

#include "CoreMinimal.h"
#include "JamBotMatch.h"
#include "JamCartridge.h"
#include "JamRandom.h"
#include "JamRuleHooks.h"
#include "JamSim.h"
#include "UObject/StrongObjectPtr.h"
// The three systems of the bundle (TStrongObjectPtr needs the complete types).
#include "JamEffectSystem.h"
#include "JamRuleSystem.h"
#include "JamZones.h"

namespace JamAI
{
	// FJamGameConfig (the loaded cartridge) -> the match config the runner reads (roster, spawns, game.ai).
	JAMCORE_API FJamMatchConfig ToMatchConfig(const FJamGameConfig& G);

	// The three systems the game mode builds around a UJamSim, owned together. Not built (every pointer null) on the bare path.
	struct JAMCORE_API FJamSystems
	{
		TStrongObjectPtr<UJamRuleSystem> Rules;
		TStrongObjectPtr<UJamZoneSystem> Zones;
		TStrongObjectPtr<UJamEffectSystem> Effects;
		TArray<FString> EffectErrors;      // unknown stat names and the like, from UJamEffectSystem::Init (the entry is skipped)
		int32 EndMatchActions = 0;         // rule actions seen through the hook this match
		int32 EndPeriodActions = 0;

		bool IsBuilt() const { return Rules.IsValid() && Zones.IsValid() && Effects.IsValid(); }

		// 1. Before UJamSim::Init: fresh rule and zone systems from the config, bound as the sim's hook and zone source. Hook is the
		//    object the sim calls (the adapter, which forwards to Rules and counts), so a host can observe the actions.
		void BuildBeforeInit(UJamSim& Sim, const FJamGameConfig& G, IJamRuleHook* Hook);
		// 2. After UJamSim::Init: the effect system (binds itself as the modifier source; TAKE 1 effects fire here).
		void BuildAfterInit(UJamSim& Sim, const FString& RawCartridgeJson);
		// Per frame, around UJamSim::Step.
		void BeforeStep(const UJamSim& Sim);   // the score mirror the hooks' conditions read
		void AfterStep(const UJamSim& Sim);    // zone membership and events for this frame, then the effect step
		// The brain's world view gains the slow-ice circles and the no_shoot flags, as the game mode adds them.
		void View(FJamAIWorld& W) const;
		// Forward a rule event to the rule system and count the end_match / end_period actions it emits.
		void OnRuleEvent(const FJamRuleEventIn& In, TArray<FJamRuleActionOut>& Out);
		// FNV-1a 64 over the three systems' hashes (0 when not built).
		uint64 StateHash() const;
		void Release();
	};

	class JAMCORE_API FJamSimAdapter : public IJamAISim, public IJamRuleHook
	{
	public:
		// The bare sim: no rule hooks, zones or effects (component tests that bring their own; the hash of hockey.regular is the same
		// either way, since the preset has none of the three).
		explicit FJamSimAdapter(const FJamGameConfig& InGame);
		// The sim with the game mode's systems built from the cartridge (its game config and raw JSON) on every Reset.
		explicit FJamSimAdapter(const UJamCartridge& Cart);
		virtual ~FJamSimAdapter() override;

		virtual void Reset(const FJamMatchConfig& C, uint64_t Seed) override;
		virtual void View(FJamAIWorld& W) const override;
		virtual FJamAIStepEvents Step(const FJamAIInput* In) override;
		virtual bool IsOver() const override;
		virtual int Winner() const override;
		virtual int Score(int Team) const override;
		virtual uint64_t StateHash() const override;
		virtual double BoardDistance(const FVec2& P) const override;

		// IJamRuleHook: the sim's hook when the systems are built; forwards to the rule system.
		virtual void OnRuleEvent(const FJamRuleEventIn& In, TArray<FJamRuleActionOut>& Out) override;

		UJamSim* GetSim() const { return Sim.Get(); }
		bool HasSystems() const { return bWithSystems; }
		const FJamSystems& GetSystems() const { return Systems; }
		FJamSystems& GetSystems() { return Systems; }

		// Fills W from any UJamSim (the game mode uses this to feed UJamBrain).
		static void BuildWorld(const UJamSim& S, FJamAIWorld& W);

	private:
		FJamGameConfig Game;
		FString RawJson;              // the cartridge text the effect system parses (empty on the bare path)
		bool bWithSystems = false;
		TStrongObjectPtr<UJamSim> Sim;
		FJamSystems Systems;
		TArray<FJamInput> Inputs;
		int64 LastDropFrame = -1;   // lane A3: frame of the last faceoff drop (for FJamAIWorld::FramesSinceDrop)
	};
}
