// Third Life rink core: thirdjam's game-mode play rules outside JamCore (see rink_gamemode.h). Each block cites its source.
#include "rink_gamemode.h"
#include <algorithm>

namespace RinkGlue
{
	static bool Contains(const std::vector<std::wstring>& L, const std::wstring& K) { return std::find(L.begin(), L.end(), K) != L.end(); }

	// ---------------------------------------------------------------- bindings: InputMapping.cpp:82-120, 158-170
	FBindings FBindings::Defaults()
	{
		FBindings B;
		auto Set = [&](EVerb V, std::initializer_list<const wchar_t*> Keys, std::initializer_list<const wchar_t*> Pads)
		{
			for (const wchar_t* K : Keys) B.Keys[(int)V].push_back(K);
			for (const wchar_t* K : Pads) B.Keys[(int)V].push_back(K);
		};
		Set(EVerb::Shoot, { L"LeftMouseButton" }, { L"Gamepad_RightTriggerAxis" });
		Set(EVerb::CrossCheck, { L"LeftMouseButton", L"MiddleMouseButton", L"ThumbMouseButton" }, { L"Gamepad_RightTriggerAxis", L"Gamepad_LeftShoulder" });
		Set(EVerb::Pass, { L"RightMouseButton", L"Q" }, { L"Gamepad_RightShoulder", L"Gamepad_FaceButton_Left" });
		Set(EVerb::Check, { L"RightMouseButton" }, { L"Gamepad_RightShoulder" });
		Set(EVerb::Poke, { L"SpaceBar" }, { L"Gamepad_FaceButton_Bottom" });
		Set(EVerb::Deke, { L"MouseScrollUp", L"MouseScrollDown" }, { L"Gamepad_FaceButton_Top" });
		Set(EVerb::Spin, { L"E" }, { L"Gamepad_FaceButton_Right" });
		Set(EVerb::Ability, { L"F" }, { L"Gamepad_RightThumbstick" });
		Set(EVerb::Sprint, { L"LeftShift" }, { L"Gamepad_LeftTriggerAxis" });
		Set(EVerb::Brake, { L"LeftControl" }, { L"Gamepad_LeftThumbstick" });
		Set(EVerb::SkateForward, { L"W", L"Up" }, {});
		Set(EVerb::SkateBack, { L"S", L"Down" }, {});
		Set(EVerb::SkateLeft, { L"A", L"Left" }, {});
		Set(EVerb::SkateRight, { L"D", L"Right" }, {});
		Set(EVerb::Restart, { L"R" }, { L"Gamepad_Special_Left" });
		return B;
	}
	int32 FBindings::Role(EVerb V)
	{
		static const int32 R[(int)EVerb::Count] = { 1, 2, 1, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 };
		return V < EVerb::Count ? R[(int)V] : 0;
	}
	bool FBindings::Has(EVerb V, const std::wstring& Key) const { return V < EVerb::Count && Contains(Keys[(int)V], Key); }
	EVerb FBindings::WithVerbOn(const std::wstring& Key) const
	{
		for (int I = 0; I < (int)EVerb::Count; ++I) if (Role((EVerb)I) == 1 && Has((EVerb)I, Key)) return (EVerb)I;
		return EVerb::Count;
	}
	EVerb FBindings::WithoutVerbOn(const std::wstring& Key) const
	{
		for (int I = 0; I < (int)EVerb::Count; ++I) if (Role((EVerb)I) == 2 && Has((EVerb)I, Key)) return (EVerb)I;
		return EVerb::Count;
	}
	bool FBindings::AnyDown(EVerb V, const std::vector<std::wstring>& Down) const
	{
		for (const std::wstring& K : Keys[(int)V]) if (Contains(Down, K)) return true;
		return false;
	}

	// ---------------------------------------------------------------- the resolver: InputMapping.cpp:320-424 (FJamButtonResolver)
	void FButtonResolver::Press(const std::wstring& Key)
	{
		for (FHeldKey& H : Held) if (H.Key == Key) { if (!H.bDown) { H.bDown = true; H.bNew = true; H.Verb = EVerb::Count; } return; }
		FHeldKey H;
		H.Key = Key;
		H.bDown = true;
		H.bNew = true;
		Held.push_back(H);
	}
	void FButtonResolver::Release(const std::wstring& Key)
	{
		for (FHeldKey& H : Held) if (H.Key == Key) H.bDown = false;
	}
	FButtonVerbs FButtonResolver::Step(const FButtonContext& C, const FBindings& B)
	{
		FButtonVerbs Out;
		for (FHeldKey& H : Held)
		{
			const bool bNew = H.bNew;
			if (bNew)
			{
				H.bNew = false;
				H.bDead = H.bLevelSent = H.bLevelDropped = false;
				H.Steps = 0;
				const EVerb With = B.WithVerbOn(H.Key), Without = B.WithoutVerbOn(H.Key);
				H.Verb = C.bWith ? (With != EVerb::Count ? With : Without) : (Without != EVerb::Count ? Without : With);
				switch (H.Verb)
				{
				case EVerb::Shoot: Out.bShootPress = true; break;
				case EVerb::Pass: Out.bPassPress = true; break;
				case EVerb::Check: Out.bCheck = true; break;
				case EVerb::CrossCheck: Out.bLift = true; break;
				default: break;
				}
			}
			else if (C.bDeadAcrossChange && !H.bDead)
			{
				switch (H.Verb)
				{
				case EVerb::Shoot: case EVerb::Pass: H.bDead = !C.bWith; break;
				case EVerb::CrossCheck: H.bDead = C.bCarrying; break;
				case EVerb::Check: H.bDead = C.bWith; break;
				default: break;
				}
				if (H.bDead && Out.DeadNow == EVerb::Count) Out.DeadNow = H.Verb;
			}
			++H.Steps;
			const bool bWithVerb = H.Verb == EVerb::Shoot || H.Verb == EVerb::Pass;
			bool bLevel = false;
			if (H.bDead)
			{
				if (bWithVerb && H.bDown && H.bLevelSent && !H.bLevelDropped && C.bInReach) bLevel = true;
				else H.bLevelDropped = true;
			}
			else
			{
				switch (H.Verb)
				{
				case EVerb::Shoot: bLevel = H.bDown || bNew; break;
				case EVerb::Pass: bLevel = (H.bDown && H.Steps > C.SaucerDelaySteps) || (!H.bDown && !H.bLevelSent); break;
				case EVerb::CrossCheck: bLevel = (H.bDown || bNew) && H.Steps > C.BraceDelaySteps; break;
				default: break;
				}
			}
			if (bLevel)
			{
				H.bLevelSent = true;
				switch (H.Verb)
				{
				case EVerb::Shoot: Out.bShootHeld = true; break;
				case EVerb::Pass: Out.bPassHeld = true; break;
				case EVerb::CrossCheck: Out.bCrossHeld = true; break;
				default: break;
				}
			}
			if (H.bDown && !H.bDead)
			{
				if (H.Verb == EVerb::Pass) Out.PassHoldSteps = std::max(Out.PassHoldSteps, H.Steps);
				if (H.Verb == EVerb::CrossCheck) Out.CrossHoldSteps = std::max(Out.CrossHoldSteps, H.Steps);
			}
		}
		Held.erase(std::remove_if(Held.begin(), Held.end(), [](const FHeldKey& H) { return !H.bDown && !H.bNew; }), Held.end());
		return Out;
	}

	// ---------------------------------------------------------------- the aim anchor: InputMapping.cpp FJamAimAnchor::Step (A191)
	FVector2D FAimAnchor::Step(const FVector2D& PixelPx, const FVector2D& HitM, const FVector2D& SkaterM, bool bOn, double StandSpeedMps)
	{
		const double Speed = bHave ? FVector2D::Distance(SkaterM, LastSkater) * 60.0 : 1e9;
		const bool bPixelMoved = !bHave || FVector2D::Distance(PixelPx, LastPx) >= 0.5;
		if (!bOn || bPixelMoved || Speed >= StandSpeedMps)
		{
			Offset = HitM - SkaterM;
			bAnchored = false;
			LastPx = PixelPx;
		}
		else bAnchored = true;
		LastSkater = SkaterM;
		bHave = true;
		return SkaterM + Offset;
	}

	// ---------------------------------------------------------------- the human's controls
	void FHumanControls::Reset()
	{
		Buttons.Reset();
		Last = FButtonVerbs();
		Anchor.Reset();
		bCursorAiming = false;
		bBackYawHeld = false;
		BackYawRad = 0;
		MouseAimPx = FVector2D::ZeroVector;
		PrevDown.clear();
		Intent = 0; Target = -1; Frames = 0; IntentFrame = 0;
	}

	// InputMapping.cpp:432-442 (JamControls::HasPuckForButtons, jam.ctrl.OurPuckShoots 1)
	bool HasPuckForButtons(const UJamSim& Sim, int32 Skater)
	{
		const TArray<FJamSkaterState>& Sk = Sim.GetSkaters();
		if (!Sk.IsValidIndex(Skater)) return false;
		const int32 Carrier = Sim.CarrierIndex();
		if (Carrier == Skater) return true;
		if (Carrier >= 0) return false;
		const int32 LastT = Sim.GetPuck().LastTouch;
		return Sk.IsValidIndex(LastT) && Sk[LastT].Team == Sk[Skater].Team;
	}

	// InputMapping.cpp:463-486 (SaucerHoldFrames, BraceHoldFrames, ButtonContext; cvar defaults 13, 13, HeldAcrossChange 1)
	FButtonContext ButtonContext(const UJamSim& Sim, int32 Skater)
	{
		FButtonContext C;
		C.bWith = HasPuckForButtons(Sim, Skater);
		C.bCarrying = Sim.CarrierIndex() == Skater;
		const TArray<FJamSkaterState>& Sk = Sim.GetSkaters();
		C.bInReach = Sk.IsValidIndex(Skater) && FVector2D::Distance(Sk[Skater].Pos, Sim.GetPuck().Pos) <= Sim.CarrierReachM(Skater);
		C.bDeadAcrossChange = true;
		const int32 Half = Sim.GetConfig().Pass.SaucerHalfFrames;
		const int32 SaucerHold = Half <= 0 ? Half : FMath::Max(Half, 13);
		C.SaucerDelaySteps = Half > 0 && Sim.GetConfig().Pass.PowerFullFrames <= 0 ? FMath::Max(0, SaucerHold - Half) : 0;
		C.BraceDelaySteps = FMath::Max(0, FMath::Max(UJamSim::CrossHoldTapFrames, 13) - UJamSim::CrossHoldTapFrames);
		return C;
	}

	FJamInput FHumanControls::Read(const FRawInput& Raw, const UJamSim& Sim, int32 Human)
	{
		FJamInput In;
		if (!Sim.GetSkaters().IsValidIndex(Human)) return In;
		// Enhanced Input between steps: a new press is Press(Key) (DebugButton, InputMapping.cpp:1046-1058); a release is Release(Key).
		for (const std::wstring& K : Raw.Pressed) if (Bindings.WithVerbOn(K) != EVerb::Count || Bindings.WithoutVerbOn(K) != EVerb::Count) Buttons.Press(K);
		for (const std::wstring& K : Raw.Down)
			if (!Contains(Raw.Pressed, K) && !Contains(PrevDown, K) && (Bindings.WithVerbOn(K) != EVerb::Count || Bindings.WithoutVerbOn(K) != EVerb::Count)) Buttons.Press(K);
		for (const std::wstring& K : PrevDown) if (!Contains(Raw.Down, K)) Buttons.Release(K);
		for (const std::wstring& K : Raw.Pressed) if (!Contains(Raw.Down, K)) Buttons.Release(K);   // a tap released before the step still counts once
		PrevDown = Raw.Down;

		// HokejGameMode.cpp:937-958: camera-relative move; a pull back is read in the camera frame of the moment it began (lane A93).
		double Yaw = Sim.GetSkaters()[Human].Yaw;
		if (Raw.bHasCameraYaw) Yaw = Raw.CameraYaw;
		const FVector2D Axis = FVector2D(FMath::Clamp(Raw.Axis.X, -1.0, 1.0), FMath::Clamp(Raw.Axis.Y, -1.0, 1.0));   // OnMove: ClampAxes(-1, 1) (InputMapping.cpp:950-953)
		double MoveYaw = Yaw;
		if (Axis.Y < -0.3)
		{
			if (!bBackYawHeld) { bBackYawHeld = true; BackYawRad = Yaw; }
			MoveYaw = BackYawRad;
		}
		else bBackYawHeld = false;
		const FVector2D MoveFwd(FMath::Cos(MoveYaw), FMath::Sin(MoveYaw));
		const FVector2D MoveRight(-FMath::Sin(MoveYaw), FMath::Cos(MoveYaw));
		const FVector2D Fwd(FMath::Cos(Yaw), FMath::Sin(Yaw));
		const FVector2D Right(-FMath::Sin(Yaw), FMath::Cos(Yaw));
		In.Move = MoveFwd * Axis.Y + MoveRight * Axis.X;

		// HokejGameMode.cpp:961 + InputMapping.cpp:488-503: the two-role buttons resolved by this frame's possession.
		Last = Buttons.Step(ButtonContext(Sim, Human), Bindings);
		In.bShootHeld = Last.bShootHeld;
		In.bPassHeld = Last.bPassHeld;
		In.bCheck = Last.bCheck;
		In.bLift = Last.bLift;
		In.bCrossHold = Last.bCrossHeld && Sim.CarrierIndex() != Human;
		In.bBrake = Bindings.AnyDown(EVerb::Brake, Raw.Down);     // HokejGameMode.cpp:962
		In.bSprint = Bindings.AnyDown(EVerb::Sprint, Raw.Down);   // HokejGameMode.cpp:963

		// HokejGameMode.cpp:966-990: the stick. The pad's right stick; else the cursor on the ice (FJamAimAnchor + CursorAimFromHit's hysteresis);
		// else the accumulated mouse delta (OnStickMouse: clamped to 200 px, InputMapping.cpp:971-977; 100 px = one reach at mouse_sensitivity 1).
		MouseAimPx += Raw.MouseDeltaPx;
		{
			const double L = MouseAimPx.Size();
			if (L > 200.0) MouseAimPx *= 200.0 / L;
		}
		FVector2D Aim = FVector2D(FMath::Clamp(Raw.StickAxis.X, -1.0, 1.0), FMath::Clamp(Raw.StickAxis.Y, -1.0, 1.0));
		FVector2D StickRink = FVector2D::ZeroVector;
		const FVector2D SkaterPos = Sim.GetSkaters()[Human].Pos;
		if (Aim.SizeSquared() >= 0.01)
		{
			StickRink = Fwd * Aim.Y + Right * Aim.X;
		}
		else if (Raw.bCursorOnIce)
		{
			// HokejGameMode.cpp:741-767 (CursorAimRink, CursorAimFromHit)
			const FVector2D AimM = Anchor.Step(Raw.CursorPx, Raw.CursorHitM, SkaterPos, Raw.bHasCursorPx, 0.3);   // no pixel (a bot's aim): no anchor
			const FVector2D Delta = AimM - SkaterPos;
			const double Dist = Delta.Size();
			const double Enter = bCursorAiming ? 0.5 : 0.7;
			if (Dist < Enter) bCursorAiming = false;
			else
			{
				bCursorAiming = true;
				const double Mag = 0.5 + 0.5 * FMath::Clamp((Dist - 0.5) / 2.5, 0.0, 1.0);
				StickRink = Delta / Dist * Mag;
			}
			MouseAimPx = FVector2D::ZeroVector;   // Pi->ResetMouseAim()
		}
		else
		{
			Anchor.Reset();   // HokejGameMode.cpp:749: no ice under the cursor
			Aim = MouseAimPx * (0.01 * Sim.GetConfig().Stick.MouseSensitivity);
			if (Aim.SizeSquared() > 1.0) Aim.Normalize();
			if (Aim.SizeSquared() >= 0.0025) StickRink = Fwd * Aim.Y + Right * Aim.X;
		}
		In.Stick = StickRink;
		// HokejGameMode.cpp:992-996: the single-role edges (latched on the press, consumed by the step).
		for (const std::wstring& K : Raw.Pressed)
		{
			if (Bindings.Has(EVerb::Poke, K)) In.bPoke = true;
			if (Bindings.Has(EVerb::Deke, K)) In.bDeke = true;
			if (Bindings.Has(EVerb::Spin, K)) In.bSpin = true;
			if (Bindings.Has(EVerb::Ability, K)) In.bAbility = true;
		}
		return In;
	}

	bool FHumanControls::RestartPressed(const FRawInput& Raw) const
	{
		for (const std::wstring& K : Raw.Pressed) if (Bindings.Has(EVerb::Restart, K)) return true;
		return false;
	}

	// SignalSystem.cpp:46-48 (keys One..Four, pads DPad Down/Up/Left/Right = defend, space, pass, praise) and 264-325 (AnswererFor, Issue, Make).
	void FHumanControls::StepSignals(const FRawInput& Raw, const UJamSim& Sim, int32 Seat)
	{
		static const wchar_t* Keys[4] = { L"One", L"Two", L"Three", L"Four" };
		static const wchar_t* Pads[4] = { L"Gamepad_DPad_Down", L"Gamepad_DPad_Up", L"Gamepad_DPad_Left", L"Gamepad_DPad_Right" };
		for (int32 Slot = 0; Slot < 4; ++Slot)
		{
			if (!Contains(Raw.Pressed, Keys[Slot]) && !Contains(Raw.Pressed, Pads[Slot])) continue;
			const int32 Want = Slot + 1;   // EJamTeamIntent: Defend 1, Space 2, Pass 3, Praise 4
			if (Sim.GetPhase() != EJamSimPhase::Playing) continue;
			const int64 Now = Sim.GetFrame();
			if (Intent != 0 && Now - IntentFrame < 60) continue;   // JamSignals::RepeatCooldownFrames (SignalSystem.h:24)
			const TArray<FJamSkaterState>& Sk = Sim.GetSkaters();
			if (!Sk.IsValidIndex(Seat)) continue;
			int32 Nearest = -1;
			double BestD = 1e30;
			for (const FJamSkaterState& S : Sk)
			{
				if (S.Index == Seat || S.bHuman || S.Team != Sk[Seat].Team) continue;
				const double D = FVector2D::DistSquared(S.Pos, Sk[Seat].Pos);
				if (D < BestD) { BestD = D; Nearest = S.Index; }
			}
			if (Nearest < 0) continue;
			Intent = Want;
			Target = (Want == 4 || Want == 3) ? Nearest : -1;
			Frames = Want == 3 ? 180 : 300;   // FJamTeamIntent::DefaultFrames
			IntentFrame = Now;
		}
	}

	// HokejGameMode.cpp:1320-1331 (UJamSignalSystem::GetActiveIntent, FJamTeamIntent::IsActive / FramesLeft)
	void FHumanControls::ApplyIntent(JamAI::FJamAIWorld& W, int64 Frame) const
	{
		const bool bActive = Intent != 0 && Frame >= IntentFrame && Frame < IntentFrame + Frames;
		if (!bActive) return;
		W.IntentKind = Intent;
		W.IntentTarget = Target;
		W.IntentFramesLeft = static_cast<int32>(IntentFrame + Frames - Frame);
	}
}
