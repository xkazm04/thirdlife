// Lane A132 (track F1, contact feel; R-0054 point 3): the law-1 drill. One scene, used twice: headless by Jam.Core.Contact.LawOneDrill (JamContactTests.cpp) and
// in a Development package by jam.ctrl.Drill 22 (HokejGameMode.cpp), so the scene the gate holds and the take the video shows are the same code.
//
// docs/VISION.md law 1: "If tackle is done between players going to same direction with similar speed, the impact is almost none next to a tackle or cross-check
// from player facing full speed towards the player." The scene stages both hits side by side, with the same press (the body check) on the same frame:
//   the near lane (the human's): the human skates right behind an opponent, both at SpeedMps the same way, and presses check: a NUDGE (a bump: ratio under
//     contact.bump_ratio); both skate on, nobody loses a step;
//   the far lane (2 x LaneM beside it): a teammate at the same speed meets an opponent coming the other way at that speed (closing 2 x SpeedMps) and presses
//     check on the same frame: DOWN, for contact.down_frames_max.
// Everyone else is parked in a corner with no input; the puck lies in the other corner (nobody carries, so no press is refused). The four are scripted with the
// move keys and the check button only. The whistle is switched off for the round (ApplyLiveConfig, rules.penalties) and put back after it: a check on a skater
// without the puck is a foul where the whistle is on, and the foul's faceoff would end the take.
// Two things the scene does by hand, both on the press frame, so that the take is the same every time: the press comes when the far lane's two are two frames
// from touching (so its hit lands inside the bot's six-frame check window), and the human is seated against the near opponent's back at that opponent's own
// velocity (SeatM between the centres: a move of a few centimetres), because two bodies at matched speed never touch by themselves.
// Header only; no state in the sim. docs/experiments/CONTACT-5.md.
#pragma once

#include "CoreMinimal.h"
#include "JamSim.h"
#include "JamEventBus.h"

struct FJamLawOneDrill
{
	static constexpr int32 LeadFrames = 60;      // the four skate this long before the press (the far lane's start gap is set for it)
	static constexpr int32 SettleFrames = 30;    // after the press: the near lane's two are read (on their feet, their speed)
	static constexpr int32 AfterFrames = 170;    // after the press: the round ends (the longest knockdown is 150 frames)
	static constexpr int32 MaxFrames = 400;
	static constexpr double LaneM = 2.5;         // each lane's distance from the line between them
	static constexpr double FollowM = 0.86;      // the human's distance behind the near opponent while they skate (centre to centre; bodies 0.8)
	static constexpr double SeatM = 0.78;        // ... and on the press frame

	double SpeedMps = 8.0;
	bool bHumanHits = false;   // false = the human throws the nudge (the camera rides the near lane); true = the human throws the hit (its hold and kick show)

	// The scene and the run.
	int32 NudgeAtt = -1, NudgeVic = -1, HitAtt = -1, HitVic = -1;
	double Dir = 1.0;
	int32 Frames = 0, PressFrame = -1;
	int32 SeatAt = -1;   // lane A192: the frame the nudge's attacker is seated (the press's frame, or the wind-up's end)
	bool bLive = false, bDone = false, bWhistleWas = false, bFoul = false;
	// What happened.
	int32 NudgeOutcome = 0, HitOutcome = 0, NudgeFrame = -1, HitFrame = -1, HitKnockFrames = 0;
	float NudgeRatio = 0.f, HitRatio = 0.f;
	double NudgeVicSpeedBefore = 0.0, NudgeVicSpeedAfter = 0.0, NudgeAttSpeedAfter = 0.0, HitClosingMps = 0.0;
	bool bNudgeOnFeet = false, bHitVicDown = false;

	bool IsLive() const { return bLive; }
	bool IsOurs(int32 i) const { return i == NudgeAtt || i == NudgeVic || i == HitAtt || i == HitVic; }
	// The take is the law's when the near hit was a bump that cost nobody its feet and the far one a knockdown, both inside the same tenth of a second.
	bool IsLawOne() const
	{
		return bDone && !bFoul && NudgeOutcome == UJamSim::ContactBump && bNudgeOnFeet && NudgeVicSpeedAfter > NudgeVicSpeedBefore - 1.0
			&& HitOutcome == UJamSim::ContactDown && NudgeFrame >= 0 && HitFrame >= 0 && FMath::Abs(HitFrame - NudgeFrame) <= 6;
	}

	static void SetWhistle(UJamSim& Sim, bool bOn)
	{
		if (Sim.GetConfig().Rules.bPenalties == bOn) return;
		FJamGameConfig C = Sim.GetConfig();
		C.Rules.bPenalties = bOn;
		Sim.ApplyLiveConfig(C);
	}

	// Places the scene. False when the cut has no human, no teammate for the far lane or fewer than two opponents.
	bool Stage(UJamSim& Sim)
	{
		const double KeepSpeed = SpeedMps;
		const bool bKeepHits = bHumanHits;
		*this = FJamLawOneDrill();
		SpeedMps = KeepSpeed;
		bHumanHits = bKeepHits;
		const TArray<FJamSkaterState>& Sk = Sim.GetSkaters();
		const int32 Human = Sim.GetHumanIndex();
		if (!Sk.IsValidIndex(Human)) return false;
		const int32 Team = Sk[Human].Team;
		int32 Mate = -1;
		for (const FJamSkaterState& S : Sk)
		{
			if (S.Index == Human || S.InBox()) continue;
			if (S.Team == Team) { if (Mate < 0) Mate = S.Index; }
			else if (NudgeVic < 0) NudgeVic = S.Index;
			else if (HitVic < 0) HitVic = S.Index;
		}
		if (Mate < 0 || NudgeVic < 0 || HitVic < 0) return false;
		NudgeAtt = bHumanHits ? Mate : Human;
		HitAtt = bHumanHits ? Human : Mate;
		Dir = Sim.AttackGoalX(Team) >= 0.0 ? 1.0 : -1.0;
		const int32 N = Sk.Num();
		for (int32 i = 0; i < N; ++i) Sim.SetSkater(i, FVector2D(Dir * (-40.0 + i * 1.5), 19.0), FVector2D::ZeroVector, 0);
		Sim.SetPuck(FVector2D(Dir * -38.0, -19.0), FVector2D::ZeroVector);
		const double Fwd = Dir > 0.0 ? 0.0 : UE_DOUBLE_PI, Back = Dir > 0.0 ? UE_DOUBLE_PI : 0.0;
		const FVector2D V(Dir * SpeedMps, 0.0);
		const double X0 = Dir * -12.0;
		Sim.SetSkater(NudgeAtt, FVector2D(X0, -LaneM), V, Fwd);
		Sim.SetSkater(NudgeVic, FVector2D(X0 + Dir * FollowM, -LaneM), V, Fwd);
		Sim.SetSkater(HitAtt, FVector2D(X0, LaneM), V, Fwd);
		Sim.SetSkater(HitVic, FVector2D(X0 + Dir * (2.0 * UJamSim::SkaterRadius + 2.0 * SpeedMps * LeadFrames / 60.0), LaneM), -V, Back);
		bWhistleWas = Sim.GetConfig().Rules.bPenalties;
		SetWhistle(Sim, false);
		bLive = true;
		return true;
	}

	// Before the step: the four's inputs (everyone else none). On the press frame the human is seated against the near opponent's back.
	void Input(UJamSim& Sim, TArray<FJamInput>& Inputs)
	{
		if (!bLive) return;
		const TArray<FJamSkaterState>& Sk = Sim.GetSkaters();
		for (int32 i = 0; i < Inputs.Num(); ++i) Inputs[i] = FJamInput();
		if (!Inputs.IsValidIndex(NudgeAtt) || !Inputs.IsValidIndex(NudgeVic) || !Inputs.IsValidIndex(HitAtt) || !Inputs.IsValidIndex(HitVic)) return;
		const double Mag = FMath::Clamp(SpeedMps / FMath::Max(Sim.GetEffectiveStat(EJamStat::SkaterSpeed, NudgeAtt), 1e-6), 0.0, 1.0);
		Inputs[NudgeAtt].Move = Inputs[NudgeVic].Move = Inputs[HitAtt].Move = FVector2D(Dir * Mag, 0.0);
		Inputs[HitVic].Move = FVector2D(-Dir * Mag, 0.0);
		auto Seat = [&]()
		{
			const FVector2D VicPos = Sk[NudgeVic].Pos, VicVel = Sk[NudgeVic].Vel;
			const double VicYaw = Sk[NudgeVic].Yaw;
			Sim.SetSkater(NudgeAtt, VicPos - Sk[NudgeVic].Forward() * SeatM, VicVel, VicYaw);
		};
		if (PressFrame >= 0) { if (Frames == SeatAt) Seat(); return; }   // lane A192: seated as the wind-up ends, so the matched-speed touch meets the open window
		const FVector2D To = Sk[HitVic].Pos - Sk[HitAtt].Pos;
		const double Gap = To.Size() - 2.0 * UJamSim::SkaterRadius;
		const double Closing = FVector2D::DotProduct(Sk[HitAtt].Vel - Sk[HitVic].Vel, To.GetSafeNormal());
		// Lane A192: the window opens game.contact.check_windup_frames after the press: the press goes that many frames earlier (0: as before).
		if (Gap > Closing * (2.0 + Sim.GetConfig().Contact.CheckWindupFor(Sk[HitAtt].bHuman)) / 60.0 && Frames < LeadFrames + 30) return;   // lane A200: the presser's own (bot_check_windup_frames for a bot)
		PressFrame = Frames;
		HitClosingMps = Closing;
		NudgeVicSpeedBefore = Sk[NudgeVic].Vel.Size();
		SeatAt = Frames + Sim.GetConfig().Contact.CheckWindupFor(Sk[NudgeAtt].bHuman);   // lane A200: the presser's own (bot_check_windup_frames for a bot)
		if (SeatAt == Frames) Seat();
		Inputs[NudgeAtt].bCheck = true;
		Inputs[HitAtt].bCheck = true;
	}

	// After the step: reads the two hits; ends the round and puts the whistle back.
	void Observe(UJamSim& Sim)
	{
		if (!bLive) return;
		const TArray<FJamSkaterState>& Sk = Sim.GetSkaters();
		static const FName FoulEvent(TEXT("foul"));
		for (const FJamSimEvent& E : Sim.GetFrameEvents()) if (E.Name == FoulEvent) bFoul = true;
		if (NudgeFrame < 0 && Sk[NudgeVic].ContactOutcome != UJamSim::ContactNone && Sk[NudgeVic].ContactBy == NudgeAtt)
		{
			NudgeFrame = Frames; NudgeOutcome = Sk[NudgeVic].ContactOutcome; NudgeRatio = Sk[NudgeVic].ContactRatio;
		}
		if (HitFrame < 0 && Sk[HitVic].ContactOutcome != UJamSim::ContactNone && Sk[HitVic].ContactBy == HitAtt)
		{
			HitFrame = Frames; HitOutcome = Sk[HitVic].ContactOutcome; HitRatio = Sk[HitVic].ContactRatio; HitKnockFrames = Sk[HitVic].KnockFrames;
			bHitVicDown = Sk[HitVic].IsDown();
		}
		if (PressFrame >= 0 && Frames == PressFrame + SettleFrames)
		{
			bNudgeOnFeet = Sk[NudgeVic].CanAct() && Sk[NudgeAtt].CanAct();
			NudgeVicSpeedAfter = Sk[NudgeVic].Vel.Size();
			NudgeAttSpeedAfter = Sk[NudgeAtt].Vel.Size();
		}
		++Frames;
		if ((PressFrame >= 0 && Frames > PressFrame + AfterFrames) || Frames >= MaxFrames || Sim.GetPhase() != EJamSimPhase::Playing)
		{
			SetWhistle(Sim, bWhistleWas);
			bLive = false;
			bDone = true;
		}
	}
};
