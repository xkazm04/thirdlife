// Lane A209 (track F1, the night; brief A209 item 1): a hand like a person's for the hits, and the audit of every hit the human presses.
// MEASUREMENT ONLY. Nothing here runs in a game or in the gate: RunPlaytestMatch (JamPlaytester.cpp) builds the hand when JAM_PLAYTESTER_HAND=person and
// audits the human's presses always (the audit reads the sim; it writes nothing, so a match is the same with or without it).
//
// The hand (FJamHitHand): a person at mouse and keyboard who wants to hit the man in front of him. It sees a chance (an opponent on his feet within 4 m,
// inside 60 degrees of where he skates or faces, closing or carrying), commits after a REACTION of 12 to 18 frames, steers at him on WASD (eight
// directions: the steer is quantised to 45 degrees after an AIM ERROR of 10 to 20 degrees either side, the same error on the mouse's stick), and presses
// when HIS eye says the bodies (the body check) or the stick (the cross-check) are about to meet, judged on the distance over the closing speed (a person
// does not solve the courses), early or late by up to 8 frames. Body check (RMB) 45 %, cross-check tap (LMB) 40 %, the held brace (LMB held) 15 %.
// Every 20 seconds or so with nobody within 5 m he presses the body check at nobody (the control: no hit from 5 m).
//
// The audit (FJamHitAudit): each press of the human (the input sent: RMB = bCheck, LMB = bLift; the held brace from the hold) with its target (the
// nearest opponent on his feet within 4 m inside 90 degrees of his facing or going), followed until it lands or cannot, and the miss's first reason.
#pragma once

#include "CoreMinimal.h"
#include "JamSim.h"
#include "JamAICore.h"
#include "JamEventBus.h"
#include <cstdint>
#include <cmath>

namespace JamAI
{
	// Indices into FJamPlaytestStats::Hand (one int each, summed over a match). Names in HandKeyNames, in this order.
	enum EHand : int
	{
		// body check (RMB) presses at a man within 4 m in front
		HB_Press = 0, HB_Landed, HB_Down, HB_Bump, HB_Other,
		HB_Carrier, HB_Cooling, HB_Dropped, HB_ManDown, HB_Grace, HB_Early, HB_Late, HB_Gap03, HB_Gap06, HB_Gap10, HB_GapFar,
		HB_Press25, HB_Landed25,                 // of the presses: centres within 2.5 m and inside 60 degrees of his facing or going at the press
		HB_Wide,                                 // of the misses by the gap: the man was more than 30 degrees off his going at the press
		HB_LandDistCm, HB_LandAngDeg, HB_LandFrames,   // sums over landed checks: the centres' distance at the press, the angle off his going, press to contact
		// cross-check (LMB tap) presses at a man within 4 m in front
		HC_Press, HC_Landed, HC_Down, HC_Bump, HC_Strip,
		HC_NoPuck, HC_Reach, HC_Cone, HC_Arm, HC_Back, HC_Shield, HC_Moved, HC_Cooldown,
		HC_Press25, HC_Landed25,
		// the held brace (LMB held 13 frames or more): episodes, landed, bumped, no body met
		HH_Holds, HH_Landed, HH_Bump, HH_None,
		// presses at nobody (no opponent within 5 m) and hits that landed from them
		HN_Press, HN_Landed,
		// presses the audit did not count (an opponent within 5 m but none within 4 m in front)
		HX_Elsewhere,
		// lane A209 wave 1b: a cross-check with no reason at the press, read on the frame its shove was due: the man too far, outside the cone, his back, down
		HC_LFar, HC_LCone, HC_LBack, HC_LDown, HC_Accepted,
		HB_Contact25, HC_Contact25,   // of the presses inside 2.5 m: any contact (a bump included)
		HC25_Base,   // 12 slots: the cross-check misses of the presses inside 2.5 m by reason, HC_NoPuck..HC_Cooldown then HC_LFar..HC_LDown
		HC25_End = HC25_Base + 12,
		// lane A209 wave 3: the hits TAKEN: every bot's pressed body check / cross-check whose man (the nearest opponent in front within 4 m) is the human
		HT_BPress = HC25_End, HT_BLanded, HT_BDown, HT_BBump, HT_BEarly, HT_BGap03, HT_BGap06, HT_BGapFar, HT_BOther,
		HT_CPress, HT_CLanded, HT_CBump, HT_CMiss, HT_BLate,
		HT_CBack,   // lane A215: a bot's cross-check that stumbled or felled the human from behind (his back to the bot), whatever the audit followed
		Hand_Count
	};
	inline int HC25Slot(int Reason) { return Reason >= HC_NoPuck && Reason <= HC_Cooldown ? HC25_Base + (Reason - HC_NoPuck) : Reason >= HC_LFar && Reason <= HC_LDown ? HC25_Base + 8 + (Reason - HC_LFar) : -1; }
	inline const char* HandKeyName(int i)
	{
		static const char* Names[Hand_Count] = {
			"b_press", "b_landed", "b_down", "b_bump", "b_other",
			"b_carrier", "b_cooling", "b_dropped", "b_mandown", "b_grace", "b_early", "b_late", "b_gap03", "b_gap06", "b_gap10", "b_gapfar",
			"b_press25", "b_landed25", "b_wide", "b_land_dist_cm", "b_land_ang_deg", "b_land_frames",
			"c_press", "c_landed", "c_down", "c_bump", "c_strip",
			"c_nopuck", "c_reach", "c_cone", "c_arm", "c_back", "c_shield", "c_moved", "c_cooldown",
			"c_press25", "c_landed25",
			"h_holds", "h_landed", "h_bump", "h_none",
			"n_press", "n_landed", "x_elsewhere", "c_l_far", "c_l_cone", "c_l_back", "c_l_down", "c_accepted", "b_contact25", "c_contact25",
			"c25_nopuck", "c25_reach", "c25_cone", "c25_arm", "c25_back", "c25_shield", "c25_moved", "c25_cooldown", "c25_l_far", "c25_l_cone", "c25_l_back", "c25_l_down",
			"t_b_press", "t_b_landed", "t_b_down", "t_b_bump", "t_b_early", "t_b_gap03", "t_b_gap06", "t_b_gapfar", "t_b_other",
			"t_c_press", "t_c_landed", "t_c_bump", "t_c_miss", "t_b_late", "t_c_back" };
		return (i >= 0 && i < Hand_Count) ? Names[i] : "?";
	}

	inline uint64_t HandMix(uint64_t X)
	{
		X += 0x9E3779B97F4A7C15ull; X = (X ^ (X >> 30)) * 0xBF58476D1CE4E5B9ull; X = (X ^ (X >> 27)) * 0x94D049BB133111EBull; return X ^ (X >> 31);
	}

	// The nearest opponent on his feet (not boxed) within MaxM whose bearing is inside ConeDeg of S's facing or going; -1 none.
	inline int32 HandTarget(const UJamSim& Sim, int32 Pi, double MaxM, double ConeDeg)
	{
		const TArray<FJamSkaterState>& Sk = Sim.GetSkaters();
		const FJamSkaterState& Me = Sk[Pi];
		const FVector2D Fwd = Me.Forward();
		const FVector2D Go = Me.Vel.Size() > 1.0 ? Me.Vel.GetSafeNormal() : Fwd;
		const double C = FMath::Cos(FMath::DegreesToRadians(ConeDeg));
		int32 Best = -1; double BestD = MaxM;
		for (const FJamSkaterState& O : Sk)
		{
			if (O.Team == Me.Team || O.IsDown() || O.InBox()) continue;
			const FVector2D To = O.Pos - Me.Pos; const double D = To.Size();
			if (D > BestD || D < 1e-6) continue;
			if (FVector2D::DotProduct(To, Fwd) < C * D && FVector2D::DotProduct(To, Go) < C * D) continue;
			BestD = D; Best = O.Index;
		}
		return Best;
	}
	inline double HandNearestOpp(const UJamSim& Sim, int32 Pi)
	{
		double Best = 1e9;
		for (const FJamSkaterState& O : Sim.GetSkaters()) if (O.Team != Sim.GetSkaters()[Pi].Team && !O.InBox()) Best = FMath::Min(Best, FVector2D::Distance(O.Pos, Sim.GetSkaters()[Pi].Pos));
		return Best;
	}
	inline double HandAngleOff(const FJamSkaterState& Me, const FVector2D& To)
	{
		const FVector2D Go = Me.Vel.Size() > 1.0 ? Me.Vel.GetSafeNormal() : Me.Forward();
		const FVector2D T = To.GetSafeNormal();
		return FMath::RadiansToDegrees(FMath::Acos(FMath::Clamp(FVector2D::DotProduct(Go, T), -1.0, 1.0)));
	}
	inline double HandAngleOffFacing(const FJamSkaterState& Me, const FVector2D& To)
	{
		const FVector2D T = To.GetSafeNormal();
		return FMath::RadiansToDegrees(FMath::Acos(FMath::Clamp(FVector2D::DotProduct(Me.Forward(), T), -1.0, 1.0)));
	}

	struct FJamHitAudit
	{
		// one open body-check press
		bool bB = false; int32 BT = -1; int64 BFrame = 0; bool bBOpened = false; bool bBMetWindup = false; bool bBManDown = false; bool bBGrace = false;
		double BMinWin = 1e9; int64 BClosed = -1; bool b25 = false; double BDist = 0, BAng = 0; int BReason = -1;
		// one open cross-check press (its shove deferred by the wind-up)
		bool bC = false; int32 CT = -1; int64 CFrame = 0; int CWu = 0; int CReason = -1; bool bC25 = false;
		// the held brace
		int HoldRun = 0; bool bHoldCounted = false; bool bHoldResolved = false;
		// lane A209 wave 3: one open press per bot at the human (the hits taken)
		struct FBot { int64 B = -1; double MinWin = 1e9; bool bMetWu = false; bool bOpened = false; int64 Closed = -1; int64 C = -1; int CWu = 0; };
		FBot Bots[kMaxSkaters];
		void StepTaken(const UJamSim& Sim, int32 Pi, int* H)
		{
			const TArray<FJamSkaterState>& Sk = Sim.GetSkaters();
			const FJamSkaterState& Me = Sk[Pi];
			const int64 F = Sim.GetFrame();
			const double R2 = UJamSim::SkaterRadius * 2.0;
			const bool bOnMe = Me.ContactBy >= 0 && Me.ContactOutcome > 0;
			for (int32 k = 0; k < Sk.Num() && k < kMaxSkaters; ++k)
			{
				const FJamSkaterState& O = Sk[k];
				if (O.Team == Me.Team) continue;
				FBot& Bt = Bots[k];
				const bool bHitMe = bOnMe && Me.ContactBy == k;
				if (bHitMe && Me.bContactCross && !O.bHuman && Me.ContactOutcome >= UJamSim::ContactStumble && FVector2D::DotProduct((Me.Pos - O.Pos).GetSafeNormal(), Me.Forward()) > 0.5) ++H[HT_CBack];   // lane A215
				if (Bt.B >= 0)
				{
					const double D = FVector2D::Distance(O.Pos, Me.Pos);
					if (bHitMe && !Me.bContactCross) { ++H[Me.ContactOutcome >= UJamSim::ContactStumble ? HT_BLanded : HT_BBump]; if (Me.ContactOutcome == UJamSim::ContactDown) ++H[HT_BDown]; Bt.B = -1; }
					else
					{
						bool bOther = false;
						for (const FJamSkaterState& V : Sk) if (V.Index != Pi && V.ContactBy == k && V.ContactOutcome > 0 && !V.bContactCross) bOther = true;
						if (bOther) { ++H[HT_BOther]; Bt.B = -1; }
						else
						{
							if (O.CheckWindow > 0) { Bt.bOpened = true; Bt.MinWin = FMath::Min(Bt.MinWin, D); }
							else if (O.CheckWindupLeft > 0) { if (D < R2 + 0.02) Bt.bMetWu = true; }
							else if (Bt.bOpened && Bt.Closed < 0) Bt.Closed = F;
							if ((Bt.Closed >= 0 && F - Bt.Closed > 10) || F - Bt.B > 40 || (!Bt.bOpened && O.CheckWindupLeft <= 0 && O.CheckWindow <= 0 && F > Bt.B))
							{
								const double G = Bt.MinWin - R2;
								++H[Bt.bMetWu ? HT_BEarly : !Bt.bOpened ? HT_BLate : G < 0.3 ? HT_BGap03 : G < 0.6 ? HT_BGap06 : HT_BGapFar];
								Bt.B = -1;
							}
						}
					}
				}
				if (O.bCheckThisFrame && Bt.B < 0 && !O.bHuman && HandTarget(Sim, k, 4.0, 90.0) == Pi)
				{
					++H[HT_BPress]; Bt = FBot(); Bt.B = F; Bt.bOpened = O.CheckWindow > 0; if (Bt.bOpened) Bt.MinWin = FVector2D::Distance(O.Pos, Me.Pos);
					if (bHitMe && !Me.bContactCross) { ++H[Me.ContactOutcome >= UJamSim::ContactStumble ? HT_BLanded : HT_BBump]; Bt.B = -1; }
				}
				if (Bt.C >= 0)
				{
					if (bHitMe && Me.bContactCross) { ++H[Me.ContactOutcome >= UJamSim::ContactStumble ? HT_CLanded : HT_CBump]; Bt.C = -1; }
					else if (F - Bt.C > Bt.CWu + 2) { ++H[HT_CMiss]; Bt.C = -1; }
				}
				if (O.bLiftThisFrame && Bt.C < 0 && !O.bHuman && ((O.LiftWindupLeft > 0 && O.CrossTarget == Pi) || (bHitMe && Me.bContactCross)))
				{
					++H[HT_CPress]; Bt.C = F; Bt.CWu = Sim.GetConfig().Contact.CrossWindupFor(false);
					if (bHitMe && Me.bContactCross) { ++H[Me.ContactOutcome >= UJamSim::ContactStumble ? HT_CLanded : HT_CBump]; Bt.C = -1; }
				}
			}
		}

		static bool Playing(const UJamSim& Sim) { return Sim.GetPhase() == EJamSimPhase::Playing && !Sim.IsDrawOpen(); }

		// After the step of a frame: Sent = the human's input for that frame (the presses), Sim = the state after it.
		void Step(const UJamSim& Sim, int32 Pi, const FJamAIInput& Sent, int* H)
		{
			const TArray<FJamSkaterState>& Sk = Sim.GetSkaters();
			if (!Sk.IsValidIndex(Pi)) return;
			const FJamSkaterState& Me = Sk[Pi];
			const int64 F = Sim.GetFrame();
			const double R2 = UJamSim::SkaterRadius * 2.0;
			// this frame's hits by the human
			int32 BodyOn = -1, BodyOut = 0, CrossOn = -1, CrossOut = 0, BraceOut = 0;
			for (const FJamSkaterState& V : Sk)
			{
				if (V.ContactBy != Pi || V.ContactOutcome <= 0) continue;
				if (V.bContactCross) { if (V.bCrossBraceHit) BraceOut = FMath::Max(BraceOut, (int)V.ContactOutcome); else { CrossOn = V.Index; CrossOut = V.ContactOutcome; } }
				else { BodyOn = V.Index; BodyOut = V.ContactOutcome; }
			}
			// ---- the body check
			if (bB)
			{
				if (BodyOn >= 0)
				{
					if (b25) ++H[HB_Contact25];
					if (BodyOut >= UJamSim::ContactStumble)
					{
						++H[BodyOn == BT ? HB_Landed : HB_Other]; if (BodyOn == BT && BodyOut == UJamSim::ContactDown) ++H[HB_Down];
						if (BodyOn == BT) { if (b25) ++H[HB_Landed25]; H[HB_LandDistCm] += (int)(BDist * 100.0); H[HB_LandAngDeg] += (int)BAng; H[HB_LandFrames] += (int)(F - BFrame); }
					}
					else ++H[HB_Bump];
					bB = false;
				}
				else
				{
					const FJamSkaterState& T = Sk[BT];
					const double D = FVector2D::Distance(T.Pos, Me.Pos);
					if (Me.CheckWindow > 0) { bBOpened = true; BMinWin = FMath::Min(BMinWin, D); if (T.IsDown() || T.InBox()) bBManDown = true; if (T.ShieldFrames > 0 && D < R2 + 0.05) bBGrace = true; }
					else if (Me.CheckWindupLeft > 0) { if (D < R2 + 0.02) bBMetWindup = true; }
					else if (bBOpened && BClosed < 0) BClosed = F;
					const bool bWindupGone = !bBOpened && Me.CheckWindupLeft <= 0 && Me.CheckWindow <= 0 && F > BFrame;
					if (BReason >= 0 || bWindupGone || (BClosed >= 0 && (D < R2 + 0.02 || F - BClosed > 15)) || F - BFrame > 60)
					{
						int R = BReason;
						if (R < 0)
						{
							if (bWindupGone) R = (Me.IsDown() || Me.IsStumbling()) ? HB_ManDown : HB_Dropped;
							else if (bBManDown) R = HB_ManDown;
							else if (bBGrace) R = HB_Grace;
							else if (bBMetWindup) R = HB_Early;
							else if (BClosed >= 0 && D < R2 + 0.02) R = HB_Late;
							else { const double G = BMinWin - R2; R = G < 0.3 ? HB_Gap03 : G < 0.6 ? HB_Gap06 : G < 1.0 ? HB_Gap10 : HB_GapFar; if (BAng > 30.0) ++H[HB_Wide]; }
						}
						++H[R]; bB = false;
					}
				}
			}
			if (Sent.bCheck && !bB)
			{
				const int32 T = HandTarget(Sim, Pi, 4.0, 90.0);
				const double Near = HandNearestOpp(Sim, Pi);
				const bool bRunning = Me.CheckWindupLeft > 0 && !Me.bCheckThisFrame && !Me.bCheckRefused;   // a press inside a running wind-up is the same press
				if (!bRunning)
				{
					if (T < 0) { if (Near >= 5.0) { ++H[HN_Press]; if (BodyOut >= UJamSim::ContactStumble) ++H[HN_Landed]; } else ++H[HX_Elsewhere]; }
					else
					{
						++H[HB_Press];
						bB = true; BT = T; BFrame = F; bBOpened = Me.CheckWindow > 0; bBMetWindup = bBManDown = bBGrace = false; BMinWin = 1e9; BClosed = -1; BReason = -1;
						const FVector2D To = Sk[T].Pos - Me.Pos;
						BDist = To.Size(); BAng = HandAngleOff(Me, To);
						b25 = BDist <= 2.5 && (BAng <= 60.0 || HandAngleOffFacing(Me, To) <= 60.0);
						if (b25) ++H[HB_Press25];
						if (Me.bCheckRefused) BReason = HB_Carrier;
						else if (!Me.bCheckThisFrame) BReason = HB_Cooling;
						if (bBOpened) BMinWin = BDist;
						if (BodyOn >= 0) { bB = false; if (b25) ++H[HB_Contact25]; ++H[BodyOut >= UJamSim::ContactStumble ? HB_Landed : HB_Bump]; if (BodyOut >= UJamSim::ContactStumble && b25) ++H[HB_Landed25]; }   // the late press: landed on its own frame
						else if (BReason >= 0) { ++H[BReason]; bB = false; }
					}
				}
			}
			// ---- the cross-check (tap)
			if (bC)
			{
				if (CrossOn >= 0)
				{
					if (bC25) ++H[HC_Contact25];
					if (CrossOut >= UJamSim::ContactStumble) { ++H[HC_Landed]; if (CrossOut == UJamSim::ContactDown) ++H[HC_Down]; if (bC25) ++H[HC_Landed25]; } else ++H[HC_Bump];
					bC = false;
				}
				else
				{
					if (CReason < 0 && F == CFrame + CWu && Sk.IsValidIndex(CT))
					{
						const FJamSkaterState& O = Sk[CT];
						const FVector2D To = O.Pos - Me.Pos;
						const FJamGameConfig& Cf = Sim.GetConfig();
						if (O.IsDown() || O.InBox()) CReason = HC_LDown;
						else if (To.Size() > R2 + Cf.Contact.CrossReachM) CReason = HC_LFar;
						else if (Cf.Stick.LiftConeDeg < 180.0 && HandAngleOffFacing(Me, To) > Cf.Stick.LiftConeDeg) CReason = HC_LCone;
						else if (FVector2D::DotProduct(To.GetSafeNormal(), O.Forward()) > 0.5) CReason = HC_LBack;
					}
					if (F - CFrame > CWu + 2 + Sim.GetConfig().Contact.CrossLiveFrames) { const int Rs = CReason >= 0 ? CReason : HC_Moved; ++H[Rs]; if (bC25 && HC25Slot(Rs) >= 0) ++H[HC25Slot(Rs)]; bC = false; }
				}
			}
			if (Sent.bLift && !bC)
			{
				const int32 T = HandTarget(Sim, Pi, 4.0, 90.0);
				int32 T2 = T;
				if (T >= 0 && Sim.CarrierIndex() != Pi)
				{
					++H[HC_Press];
					const FJamSkaterState& O = Sk[T];
					const FVector2D To = O.Pos - Me.Pos; const double D = To.Size();
					bC25 = D <= 2.5 && (HandAngleOff(Me, To) <= 60.0 || HandAngleOffFacing(Me, To) <= 60.0);
					if (bC25) ++H[HC_Press25];
					const FJamGameConfig& Cf = Sim.GetConfig();
					const bool bCarrierish = Sim.CarrierIndex() == T || F - O.LastCarryFrame <= Cf.Stick.FoulGraceFrames;
					const bool bBack = FVector2D::DotProduct(To.GetSafeNormal(), O.Forward()) > 0.5;
					int R = -1;
					// lane A209: with the pull on the human's shove reaches a man without the puck (cross_any_man) and from check_pull_m farther
					const bool bPull = Cf.Contact.CheckPullM > 0.0 && Cf.Contact.CrossWindupFor(true) > 0;
					const bool bAny = bPull && Cf.Contact.bCrossAnyMan;
					const double Extra = bPull ? Cf.Contact.CheckPullM : 0.0;
					if (!Me.bLiftThisFrame) R = HC_Cooldown;
					else if (!bCarrierish && !bAny) R = HC_NoPuck;
					else if (D > R2 + FMath::Max(Cf.Stick.LiftRangeM, Cf.Contact.CrossReachM + Extra)) R = HC_Reach;
					else if (Cf.Stick.LiftConeDeg < 180.0 && HandAngleOffFacing(Me, To) > Cf.Stick.LiftConeDeg) R = HC_Cone;
					else if (bCarrierish && D > R2 + Cf.Contact.CrossReachM + Extra) R = HC_Arm;
					else if (bBack) R = HC_Back;
					else if (O.ShieldFrames > 0 || O.SpinFrames > 0 || O.SweepFrames > 0) R = HC_Shield;
					if (Me.LiftWindupLeft > 0 && Sk.IsValidIndex(Me.CrossTarget)) { R = -1; ++H[HC_Accepted]; T2 = Me.CrossTarget; } else T2 = T;   // the sim took the shove: its reasons come on the frame it is due
					CWu = Cf.Contact.CrossWindupFor(true); CReason = R; CT = T2; CFrame = F; bC = true;
					if (CrossOn >= 0) { bC = false; ++H[CrossOut >= UJamSim::ContactStumble ? HC_Landed : HC_Bump]; if (CrossOut >= UJamSim::ContactStumble && bC25) ++H[HC_Landed25]; }
					// a strip on the press (the lift took the puck) is counted beside the shove's outcome
					for (const FJamSimEvent& E : Sim.GetFrameEvents()) if (E.Name == JamEvents::Lift && E.Who == Pi && E.Strength > 0.5f) ++H[HC_Strip];
				}
			}
			StepTaken(Sim, Pi, H);   // lane A209 wave 3: the hits taken
			// ---- the held brace
			if (Sent.bCrossHold && Playing(Sim)) { ++HoldRun; } else { if (bHoldCounted && !bHoldResolved) ++H[HH_None]; HoldRun = 0; bHoldCounted = bHoldResolved = false; }
			if (HoldRun >= 13 && !bHoldCounted) { bHoldCounted = true; ++H[HH_Holds]; }
			if (bHoldCounted && !bHoldResolved && BraceOut > 0) { bHoldResolved = true; ++H[BraceOut >= UJamSim::ContactStumble ? HH_Landed : HH_Bump]; }
		}
	};

	// The person-like hand (see the file's head). Seeded by the match; draws its numbers on each commitment.
	struct FJamHitHand
	{
		uint64_t Seed = 0; uint64_t Draws = 0;
		int32 T = -1; int Kind = 0;               // 0 body, 1 cross tap, 2 hold
		int64 SeenAt = 0, PressAt = -1, Until = 0, NextFree = 0, NextNobody = 600;
		int React = 15, Err = 0; double AimDeg = 0.0;
		int HoldFrom = -1;
		bool bLiftLatch = false;

		uint64_t Draw() { return HandMix(Seed * 0x100000001B3ull + (++Draws)); }
		int Range(int Lo, int Hi) { return Lo + static_cast<int>(Draw() % static_cast<uint64_t>(Hi - Lo + 1)); }

		static FVec2 Quantise8(const FVec2& V)
		{
			const double L = V.Length(); if (L < 1e-9) return V;
			const double A = std::atan2(V.Y, V.X); const double Q = std::round(A / (UE_DOUBLE_PI / 4.0)) * (UE_DOUBLE_PI / 4.0);
			return FVec2(std::cos(Q), std::sin(Q));
		}
		static FVec2 Rot(const FVec2& V, double Deg) { const double R = FMath::DegreesToRadians(Deg), c = std::cos(R), s = std::sin(R); return FVec2(V.X * c - V.Y * s, V.X * s + V.Y * c); }

		// Replaces the human's hit presses (and, while committed, his steer and his stick) in In. Sim = the state before this frame's step.
		void Apply(const UJamSim& Sim, int32 Pi, FJamAIInput& In)
		{
			In.bCheck = false; In.bLift = false; In.bCrossHold = false;   // the hits are the hand's
			const TArray<FJamSkaterState>& Sk = Sim.GetSkaters();
			if (!Sk.IsValidIndex(Pi)) return;
			const FJamSkaterState& Me = Sk[Pi];
			const int64 F = Sim.GetFrame();
			if (!FJamHitAudit::Playing(Sim) || !Me.CanAct() || Sim.CarrierIndex() == Pi) { T = -1; PressAt = -1; HoldFrom = -1; return; }
			// the control: a press at nobody now and then
			if (T < 0 && F >= NextNobody && HandNearestOpp(Sim, Pi) >= 5.5) { In.bCheck = true; NextNobody = F + 1200 + Range(0, 600); NextFree = F + 40; return; }
			if (T >= 0 && (!Sk.IsValidIndex(T) || Sk[T].IsDown() || Sk[T].InBox() || F > Until)) { T = -1; PressAt = -1; HoldFrom = -1; NextFree = F + 30; }
			if (T < 0)
			{
				if (F < NextFree) return;
				const int32 C = HandTarget(Sim, Pi, 4.0, 60.0);
				if (C < 0) return;
				const FJamSkaterState& O = Sk[C];
				const FVector2D N = (O.Pos - Me.Pos).GetSafeNormal();
				const double Closing = FVector2D::DotProduct(Me.Vel - O.Vel, N);
				const bool bCarrier = Sim.CarrierIndex() == C;
				if (!bCarrier && Closing < 1.0) return;
				// a person takes the carrier's chance; a man without the puck now and then
				if (!bCarrier && (Draw() % 100) >= 35) { NextFree = F + 30; return; }
				T = C; SeenAt = F; React = Range(12, 18); Err = Range(-8, 8); AimDeg = (Draw() & 1 ? 1.0 : -1.0) * Range(10, 20);
				const int K = Range(0, 99); Kind = K < 45 ? 0 : K < 85 ? 1 : 2;
				PressAt = -1; HoldFrom = -1; Until = F + 150;
			}
			const FJamSkaterState& O = Sk[T];
			if (F < SeenAt + React) return;   // he has not reacted yet: the playtester's own skating
			const FVector2D To = O.Pos - Me.Pos;
			const double D = To.Size();
			const FVector2D N = To.GetSafeNormal();
			const double Closing = FMath::Max(0.5, FVector2D::DotProduct(Me.Vel - O.Vel, N));
			// steer: at where he will be in a beat, off by the aim error, on eight keys
			const double Lead = FMath::Min(0.4, (D - 0.8) / Closing);
			const FVector2D Lp = O.Pos + O.Vel * Lead - Me.Pos;
			const FVec2 Want = Rot(FVec2(Lp.X, Lp.Y).Normalized(), AimDeg);
			In.Move = Quantise8(Want);
			In.Stick = Rot(FVec2(N.X, N.Y), AimDeg);
			const FJamContactConfig& K = Sim.GetConfig().Contact;
			if (Kind == 2)
			{
				// the brace: held from about 3 m out until he meets him or the chance is gone
				if (HoldFrom < 0 && D - 0.8 <= 2.5) HoldFrom = static_cast<int>(F - SeenAt);
				if (HoldFrom >= 0) { In.bCrossHold = true; if (F == SeenAt + HoldFrom) In.bLift = true; }
				if (Me.bCrossSpent) { T = -1; HoldFrom = -1; NextFree = F + 45; }
				return;
			}
			// his eye's time to the meeting: the gap over the closing speed (the stick's reach for the cross-check)
			const double Gap = Kind == 0 ? D - 0.8 : D - 0.8 - 0.6;
			const double ToMeet = 60.0 * FMath::Max(0.0, Gap) / Closing;
			const int Wu = Kind == 0 ? K.CheckWindupFor(true) : K.CrossWindupFor(true);
			if (PressAt < 0 && ToMeet <= Wu + 3.0 - Err) PressAt = F;   // Err > 0: late by that many frames; < 0: early
			if (PressAt >= 0 && F >= PressAt)
			{
				if (Kind == 0) In.bCheck = true; else In.bLift = true;
				T = -1; PressAt = -1; NextFree = F + 45;
			}
		}
	};
}
