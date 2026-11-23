// Third Life rink core: the parts of thirdjam's game mode that change PLAY but live outside JamCore (in JamGame), ported
// so the shell cannot get them subtly wrong. The shell (lane K3) sends raw device state; this turns it into FJamInput exactly
// as AHokejGameMode::ReadHumanInput + JamControls::ApplyButtons do, keeps the team signal the brain reads (UJamSignalSystem),
// and restarts as AHokejGameMode::RestartMatch does. engine/cores/rink/GAMEMODE.md is the table of what was ported and why.
//
// Source of every rule: thirdjam HEAD 8dc713c6, Game/Source/JamGame (cited as file:line at each piece). Defaults of the
// console variables the rules read are the shipped ones (jam.ctrl.OurPuckShoots 1, HeldAcrossChange 1, SaucerHoldFrames 13,
// BraceHoldFrames 13, AimAnchor 1, AimAnchorSpeed 0.3).
#pragma once

#include "CoreMinimal.h"
#include "JamSim.h"
#include "JamAICore.h"
#include <string>
#include <vector>

namespace RinkGlue
{
	// InputMapping.h:EJamVerb order (InputMapping.cpp:82 GVerbs).
	enum class EVerb : int32 { Shoot, CrossCheck, Pass, Check, Poke, Deke, Spin, Ability, Sprint, Brake, SkateForward, SkateBack, SkateLeft, SkateRight, Restart, Count };

	// FJamBindings::Defaults (InputMapping.cpp:98-120); keys by Unreal's EKeys names (the shell maps its devices to these names).
	struct FBindings
	{
		std::vector<std::wstring> Keys[(int)EVerb::Count];
		static FBindings Defaults();
		static int32 Role(EVerb V);   // GVerbs[].Role: 1 with the puck, 2 without, 0 single-role
		bool Has(EVerb V, const std::wstring& Key) const;
		EVerb WithVerbOn(const std::wstring& Key) const;      // InputMapping.cpp:158
		EVerb WithoutVerbOn(const std::wstring& Key) const;   // InputMapping.cpp:164
		bool AnyDown(EVerb V, const std::vector<std::wstring>& Down) const;
	};

	// FJamButtonVerbs / FJamButtonContext (InputMapping.h:95-120).
	struct FButtonVerbs
	{
		bool bShootHeld = false, bPassHeld = false, bCheck = false, bLift = false, bCrossHeld = false, bShootPress = false, bPassPress = false;
		EVerb DeadNow = EVerb::Count;
		int32 PassHoldSteps = 0, CrossHoldSteps = 0;
	};
	struct FButtonContext
	{
		bool bWith = false, bCarrying = false, bInReach = false, bDeadAcrossChange = true;
		int32 SaucerDelaySteps = 0, BraceDelaySteps = 0;
	};

	// FJamButtonResolver (InputMapping.h:122-148, InputMapping.cpp:320-424).
	struct FButtonResolver
	{
		void Press(const std::wstring& Key);
		void Release(const std::wstring& Key);
		FButtonVerbs Step(const FButtonContext& C, const FBindings& B);
		void Reset() { Held.clear(); }
	private:
		struct FHeldKey { std::wstring Key; EVerb Verb = EVerb::Count; bool bDown = false, bNew = false, bDead = false, bLevelSent = false, bLevelDropped = false; int32 Steps = 0; };
		std::vector<FHeldKey> Held;
	};

	// FJamAimAnchor (InputMapping.h:152-167, InputMapping.cpp FJamAimAnchor::Step).
	struct FAimAnchor
	{
		FVector2D Step(const FVector2D& PixelPx, const FVector2D& HitM, const FVector2D& SkaterM, bool bOn, double StandSpeedMps);
		void Reset() { bHave = false; bAnchored = false; }
	private:
		bool bHave = false, bAnchored = false;
		FVector2D LastPx, LastSkater, Offset;
	};

	// JamControls::HasPuckForButtons (InputMapping.cpp:432-442) and ButtonContext (474-486): exposed for the HUD's hints.
	bool HasPuckForButtons(const UJamSim& Sim, int32 Skater);
	FButtonContext ButtonContext(const UJamSim& Sim, int32 Skater);

	// One frame of the person's devices, as the shell reads them.
	struct FRawInput
	{
		std::vector<std::wstring> Down;      // keys held now (EKeys names: "LeftMouseButton", "Q", "SpaceBar", "Gamepad_RightTriggerAxis", ...)
		std::vector<std::wstring> Pressed;   // keys that went down since the last step (a tap released before the step is here and not in Down)
		FVector2D Axis;                      // skate axis, x right, y forward, each clamped to [-1, 1] (IA_Move: WASD composite or the left stick)
		bool bHasCameraYaw = false;
		double CameraYaw = 0;                // radians in rink coordinates: the camera looks along (cos, sin)
		FVector2D StickAxis;                 // the pad's right stick, each axis clamped to [-1, 1]
		bool bCursorOnIce = false;           // the cursor is shown and its ray meets the ice
		FVector2D CursorPx, CursorHitM;      // its pixel and its ice point (rink metres)
		bool bHasCursorPx = false;           // a real pixel was given (absent or negative = none: a bot's aim; FJamAimAnchor anchors a still pixel only)
		FVector2D MouseDeltaPx;              // hidden-cursor mouse motion since the last step (IA_StickMouse)
	};

	// The human's controls and signals, stepped once per sim frame before UJamSim::Step.
	class FHumanControls
	{
	public:
		void Reset();
		// AHokejGameMode::ReadHumanInput (HokejGameMode.cpp:931-1043) with JamControls::ApplyButtons (InputMapping.cpp:488-503).
		FJamInput Read(const FRawInput& Raw, const UJamSim& Sim, int32 Human);
		// True when Raw pressed a key bound to Restart (FJamBindings::Defaults: R, Gamepad_Special_Left).
		bool RestartPressed(const FRawInput& Raw) const;
		// Signals 1-4 (SignalSystem.cpp:40-50 keys, 287-325 Issue): the intent the brain reads, given on a press of One..Four / the D-pad.
		void StepSignals(const FRawInput& Raw, const UJamSim& Sim, int32 Seat);
		// AHokejGameMode::GatherInputs (HokejGameMode.cpp:1320-1331): the active intent into the brain's world view.
		void ApplyIntent(JamAI::FJamAIWorld& W, int64 Frame) const;
		const FButtonVerbs& LastButtons() const { return Last; }
		int32 IntentKind() const { return Intent; }
		int64 IntentIssued() const { return IntentFrame; }
		int32 IntentTarget() const { return Target; }
		int32 IntentFrames() const { return Frames; }
	private:
		FBindings Bindings = FBindings::Defaults();
		FButtonResolver Buttons;
		FButtonVerbs Last;
		FAimAnchor Anchor;
		bool bCursorAiming = false;
		bool bBackYawHeld = false;
		double BackYawRad = 0;
		FVector2D MouseAimPx;
		std::vector<std::wstring> PrevDown;
		int32 Intent = 0, Target = -1, Frames = 0;
		int64 IntentFrame = 0;
	};
}
