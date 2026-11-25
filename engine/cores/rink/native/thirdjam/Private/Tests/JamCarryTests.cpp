// Lane A163 (track F2, evolution 6, docs/experiments/MOVEMENT-7.md): where the carry ends, and where the human lies down. Measurements, outside the gate.
//   Bar.Movement.CarryTrace   every carry of the human in real matches by how it ends (a poke, a lift, a check, his own shot or pass, a lost handle, the
//                             whistle), the median length of each class, and what was open to him a second earlier (a pass, the stop, the spin); and
//                             every knockdown of the human by what he could have done about it, with the frames it cost.
//   Jam.Core.Movement.StopGrace   the rule game.stick.stop_grace_frames in staged scenes and one match (in the gate)
//   Jam.Core.Movement.Marks       lane A166: the contested puck and the stop's distance (JamCarrierMarks.h) in staged scenes (in the gate)
//   Jam.Core.Movement.MarkShow    lane A178: a mark, once lit, stands 24 frames and through a flicker (JamCarrierMarks::StepShow), in the gate
//   env JAM_CARRY_TRACE = "level=pro;player=regular;seeds=40;from=1;rows=0;set=stick.take_grace_frames:30,..." (every part optional)
#include "Misc/AutomationTest.h"
#include "JamCartridge.h"
#include "JamSim.h"
#include "JamEventBus.h"
#include "JamBrain.h"
#include "JamSimAdapter.h"
#include "JamPlaytester.h"
#include "DifficultyResolve.h"
#include "JamBaseline.h"
#include "JamCarrierMarks.h"
#include "UObject/Package.h"

#if WITH_DEV_AUTOMATION_TESTS

namespace JamCarryTests
{
	constexpr EAutomationTestFlags Flags = EAutomationTestFlags_ApplicationContextMask | EAutomationTestFlags::ProductFilter;
	constexpr int32 MaxSk = 16, Ring = 64;

	// How a carry ended. One carry has one row: the first that applies, in this order.
	enum EEnd { Whistle = 0, OwnShot, OwnPass, Poke, Lift, CheckDown, CheckStumble, OtherFall, TouchOpp, TouchMate, Drift, EndCount };
	const TCHAR* EndName(int32 E)
	{
		static const TCHAR* N[] = { TEXT("the whistle (a goal, the horn, a stop)"), TEXT("his own shot"), TEXT("his own pass"), TEXT("a poke took it"), TEXT("a lift took it"),
			TEXT("a check: down"), TEXT("a check: a stumble, the puck loose"), TEXT("lost his feet otherwise"), TEXT("lost handle: an opponent's touch"), TEXT("lost handle: a mate took it"),
			TEXT("lost handle: it drifted off the blade") };
		return E >= 0 && E < EndCount ? N[E] : TEXT("?");
	}
	bool IsLoss(int32 E) { return E == Poke || E == Lift || E == CheckDown || E == CheckStumble || E == OtherFall || E == TouchOpp || E == Drift; }

	struct FSnap
	{
		int64 Frame = -1;
		FVector2D Pos[MaxSk], Vel[MaxSk];
		FVector2D Fwd = FVector2D(1, 0);
		bool bCarry = false, bPassOn = false, bSpinReady = false, bSprint = false, bBrake = false;
		bool bContest = false, bStopLit = false;   // lane A166: the two marks as this frame ended
	};

	struct FCarry
	{
		int64 Start = 0;
		int32 Frames = 0, End = Drift, Ender = -1;
		bool bBraked = false, bSprinted = false, bSpun = false;
		double StartNearest = 1e9;     // the nearest opponent as the carry began
		double EndSpeed = 0; bool bEndSprint = false;
		// a second earlier (or as the carry began, when it was shorter): what was open
		bool bShort = false;            // shorter than a second: there was no second earlier
		bool bPassOn = false, bPassAny = false, bBrakeOn = false, bSpinOn = false;
		double EnderDist0 = -1, EnderClosing0 = 0;
		int32 GraceAtStart = 0;
		// as the puck left him (the first frame he no longer carries)
		double LeavePuckSpeed = 0, LeaveDist = 0, LeaveRel = 0, LeaveMySpeed = 0;
		bool bLeaveBraking = false, bLeaveCharging = false;
		// the stop's cover: his reverse brake began at StopGraceMinMps or more inside the 30 frames before the puck left
		bool bStopCover = false;
		// a carry that "drifted": he had it again himself with nobody else touching it
		bool bRegained = false; int32 RegainGap = 0;
		// Lane A194 (track F2 evolution 10): the breakaway burst ran in this carry; the one who ended it stood behind him (along his travel half a second before)
		bool bBreakaway = false, bEnderBehind = false;
	};

	struct FDown
	{
		int32 Frames = 0, By = -1, CarryAge = 0;
		int32 ConLead = -1;             // lane A166: frames before his first touch at which the contested mark was first lit (-1: not in the 45 before)
		bool bStopLit = false;          // lane A166: the stop mark was lit inside the second before the hit
		bool bBrakedLate = false;
		double Dist0 = -1;
		bool bCarry = false, bCross = false, bBoard = false, bSprint = false, bBehind = false, bFront = false, bSpinOrWind = false;
		double Ratio = 0, Closing = 0, Speed = 0;
		bool bAheadSecond = false;      // the attacker was ahead of his travel a second earlier
		double DistSecond = -1;
		bool bPassOn = false;
		int32 Class = 0;
	};
	// The knockdown's class: the first that applies.
	enum EDown { NoPuck = 0, CarryBehind, CarrySprint, CarryYoung, CarryBrakedLate, CarryStop, CarryNoRoom, DownCount };
	const TCHAR* DownName(int32 D)
	{
		static const TCHAR* N[] = { TEXT("without the puck"), TEXT("carrying, hit from behind his facing (unseen)"), TEXT("carrying and sprinting: without Shift the same hit is a stumble"),
			TEXT("the puck his for under half a second (hit as he won it)"), TEXT("carrying, he braked inside the last half second: the stop begun too late"),
			TEXT("carrying, no brake, the hitter 7 m or more off a second earlier: the stop was on"), TEXT("carrying, no brake, the hitter inside 7 m a second earlier: no room") };
		return D >= 0 && D < DownCount ? N[D] : TEXT("?");
	}

	struct FTrace
	{
		JamAI::FJamSimAdapter* Sim = nullptr;
		int32 Me = -1;
		int64 LastFrame = -1;
		FSnap Snaps[Ring];
		int32 At = 0;
		bool bOpen = false;
		int32 Pending = 0;              // frames since the puck left him with no cause read yet
		FCarry Cur;
		int64 LastShot = -1000, LastPass = -1000;
		int64 BrakeStart = -1000; double BrakeStartSpeed = 0; bool bPrevBrake = false;
		bool bLastWasDrift = false, bOtherTouched = false; int64 DriftClosed = 0;
		// Lane A166: the marks against what happened. A touch = every possession of the human by its first frame (the short ones too).
		JamCarrierMarks::FContestRule ConRule;
		JamCarrierMarks::FStopRule StopRule;
		struct FTouch { int64 Frame = 0; int32 Lead = -1; bool bDown = false; };
		struct FStopEp { int64 Start = 0; bool bBraked = false, bDown = false; int32 Armed = 0; double OffDeg = 0.0; };   // lane A178: frames armed before it lit; the opponent's angle off his travel
		TArray<FTouch> MarkTouches;
		TArray<FStopEp> StopEps;
		// Lane A201 (track F2 evolution 11): every lighting of the line by the one-opponent rule (bRawLit, the gates aside), the scene at that frame and
		// what happened in the next 90 frames. Out: -1 open, 0 kept it and went on, 1 lost it to the man the line was for, 2 lost it to another man,
		// 3 lost it otherwise (a drift, his own fall), 4 his shot, 5 his pass, 6 the whistle.
		struct FScene
		{
			int64 Start = 0; int32 Def = -1, Gate = 0, Out = -1, OutAt = 0, Ender = -1, SecondOpp = -1; bool bLit = false, bBraked = false, bDown = false;
			double D = 0, Closing = 0, Speed = 0, Off = 0, SecondSec = 0, NetM = 0, BoardM = 0;
			int32 N[3][3] = {};          // [6 / 10 / 14 m][ahead / beside / behind] opponents on their feet, cumulative by radius, the man the line is for included
			int32 Gf0 = 0, Ga0 = 0, Gf = -1, Ga = -1;   // the score at the light; goals for and against inside 10 s of it
		};
		TArray<FScene> Scenes;
		int64 LastRawLit = -1000;
		// Lane A201 (evolution 12): every showing of the contested ring (as shown: StepShow), the scene at its first frame and what followed in 90 frames.
		// Out: 0 he got the puck and stayed up 60 frames, 1 he got it and was down inside 60 frames of it, 2 the ring's opponent got it, 3 another opponent got it,
		// 4 a mate got it, 5 nobody carried it in 90 frames. bObey: he reverse-braked inside the first 20 frames of the showing (the obeying player's stop).
		struct FRing
		{
			int64 Start = 0; int32 Opp = -1, Out = -1, Got = -1; int64 GotAt = -1; bool bObey = false, bDown = false;
			double HSec = 0, OSec = 0, Closing = 0, Speed = 0, OppToward = 0, OtherSec = 99, MateSec = 99, NetM = 0;
			int32 Gf0 = 0, Ga0 = 0, Gf = -1, Ga = -1;
		};
		TArray<FRing> Rings;
		int32 ConEpisodes = 0;
		int64 ConFrames = 0, LastCon = -1000, LastStopLit = -1000, StopLitFrames = 0, StopShowFrames = 0;
		// Lane A178: what is shown (the hold), each showing's frames on screen; the stop line's armed run before each light and each lit run.
		JamCarrierMarks::FShowRule ShowRule;
		JamCarrierMarks::FMarkShow ConShow;
		int64 ConShownSince = -1;
		TArray<int32> ConOnScreen, LitRuns;
		int32 ArmedRun = 0, LitRun = 0;
		TArray<FCarry> Done;
		TArray<FDown> Downs;
		int64 PlayFrames = 0, DownFrames = 0, CarryFrames = 0, LooseFrames = 0, OppFrames = 0, MateFrames = 0;
		int32 Touches = 0;              // possessions shorter than 20 frames
		const FSnap* Back(int64 Frame) const { for (const FSnap& S : Snaps) if (S.Frame == Frame) return &S; return nullptr; }
	};

	void CloseCarry(FTrace& T, int32 End, int32 Ender, const UJamSim& Sim)
	{
		FCarry& C = T.Cur;
		C.End = End; C.Ender = Ender;
		const int64 EndFrame = C.Start + C.Frames;   // about: the frames carried, flickers left out
		const int64 Now = Sim.GetFrame();
		C.bShort = C.Frames < 60;
		const FSnap* S0 = T.Back(FMath::Max(C.Start, Now - 60));
		if (S0)
		{
			C.bPassOn = S0->bPassOn;
			if (Ender >= 0 && Ender < MaxSk)
			{
				const FVector2D To = S0->Pos[Ender] - S0->Pos[T.Me];
				C.EnderDist0 = To.Size();
				const FVector2D N = To.GetSafeNormal();
				C.EnderClosing0 = FVector2D::DotProduct(S0->Vel[T.Me] - S0->Vel[Ender], N);
				const bool bAhead = FVector2D::DotProduct(To, S0->Vel[T.Me]) > 0.0;
				// The stop of law 3: the stop begun with the defender 7 to 11 m ahead passes (8 m: 100 % at pro, 9.5 m 97 %, 11 m 83.5 %, 7 m 66 %; REVIEW-2).
				C.bBrakeOn = !C.bBraked && bAhead && C.EnderDist0 >= 7.0 && C.EnderDist0 <= 11.0 && C.EnderClosing0 >= 3.0 && S0->Vel[T.Me].Size() >= 3.0;
			}
		}
		for (const FSnap& S : T.Snaps) if (S.Frame >= FMath::Max(C.Start, Now - 60) && S.Frame <= Now && S.bCarry && S.bPassOn) C.bPassAny = true;
		if (Ender >= 0 && Ender < MaxSk)
		{
			const FSnap* Sh = T.Back(FMath::Max(C.Start, Now - 30));
			const FSnap* Sn = T.Back(Now - 1);
			if (Sh && Sn) C.bEnderBehind = FVector2D::DotProduct(Sn->Pos[Ender] - Sn->Pos[T.Me], Sh->Vel[T.Me]) < 0.0;
		}
		// The spin shields the puck from a stick: ready a fifth of a second before the stick took it.
		if (End == Poke || End == Lift) { const FSnap* S1 = T.Back(FMath::Max(C.Start, Now - 12)); C.bSpinOn = S1 && S1->bSpinReady && !C.bSpun; }
		(void)EndFrame;
		if (T.Scenes.Num() && T.Scenes.Last().Out < 0 && Now - T.Scenes.Last().Start <= 90)   // lane A201
		{
			FTrace::FScene& Sc = T.Scenes.Last();
			Sc.OutAt = static_cast<int32>(Now - Sc.Start); Sc.Ender = Ender;
			if (End == OwnShot) Sc.Out = 4; else if (End == OwnPass) Sc.Out = 5; else if (End == Whistle) Sc.Out = 6; else if (End == TouchMate) Sc.Out = 5;
			else if (Ender >= 0 && Ender == Sc.Def) Sc.Out = 1; else if (Ender >= 0 && Sim.GetSkaters().IsValidIndex(Ender) && Sim.GetSkaters()[Ender].Team != Sim.GetSkaters()[T.Me].Team) Sc.Out = 2;
			else Sc.Out = 3;
		}
		T.bLastWasDrift = false;
		if (C.Frames >= 20) { T.Done.Add(C); if (End == Drift) { T.bLastWasDrift = true; T.bOtherTouched = false; T.DriftClosed = Now; } } else ++T.Touches;
		T.bOpen = false; T.Pending = 0;
	}

	void CarryTrace(void* Ctx, const JamAI::FJamAIWorld&, const JamAI::FJamAIInput*, const JamAI::FJamBrain&, int64_t, bool)
	{
		FTrace& T = *static_cast<FTrace*>(Ctx);
		const UJamSim* Sim = T.Sim->GetSim();
		if (!Sim || Sim->GetFrame() == T.LastFrame) return;
		if (T.Me < 0) { for (const FJamSkaterState& S : Sim->GetSkaters()) if (S.bHuman) T.Me = S.Index; }
		if (T.Me < 0) return;
		T.LastFrame = Sim->GetFrame();
		const TArray<FJamSkaterState>& Sk = Sim->GetSkaters();
		const FJamSkaterState& H = Sk[T.Me];
		const FJamPuckState& Puck = Sim->GetPuck();
		const int64 Now = Sim->GetFrame();
		const bool bPlaying = Sim->GetPhase() == EJamSimPhase::Playing && !Sim->IsDrawOpen();
		const int32 Ci = Sim->CarrierIndex();
		const bool bCarry = bPlaying && Ci == T.Me;
		static const FName Clean(TEXT("clean"));
		if (H.bShotThisFrame) T.LastShot = Now;
		if (H.bPassThisFrame) T.LastPass = Now;
		if (H.bReverseBraking && !T.bPrevBrake) { T.BrakeStart = Now; const FSnap* B = T.Back(Now - 1); T.BrakeStartSpeed = B ? B->Vel[T.Me].Size() : H.Vel.Size(); }
		T.bPrevBrake = H.bReverseBraking;
		if (Puck.LastTouch != T.Me) T.bOtherTouched = true;
		// Lane A166: the two marks as this frame ended (what the HUD draws on the next).
		const JamCarrierMarks::FContested Con = JamCarrierMarks::Contested(*Sim, T.Me, T.ConRule);
		const JamCarrierMarks::FStopMark StopM = JamCarrierMarks::StopMark(*Sim, T.Me, T.StopRule);
		// Lane A178: the mark as SHOWN (JamCarrierMarks::StepShow: the HUD steps the same state); a phase that is not play ends a showing, as the HUD hides it.
		if (!bPlaying) T.ConShow = JamCarrierMarks::FMarkShow();
		const bool bConShown = bPlaying && JamCarrierMarks::StepShow(T.ConShow, Con.bOn, Con.Opp, Now, T.ShowRule);
		if (bConShown && T.ConShownSince < 0 && Con.bOn)   // lane A201: the ring's scene at its first shown frame
		{
			FTrace::FRing Rg;
			Rg.Start = Now; Rg.Opp = Con.Opp; Rg.HSec = Con.HumanSec; Rg.OSec = Con.OppSec; Rg.Closing = Con.ClosingMps; Rg.Speed = H.Vel.Size();
			if (Sk.IsValidIndex(Con.Opp)) { const FVector2D Bt = (H.Pos - Sk[Con.Opp].Pos).GetSafeNormal(); Rg.OppToward = FVector2D::DotProduct(Sk[Con.Opp].Vel, Bt); }
			for (const FJamSkaterState& O : Sk)
			{
				if (O.Index == T.Me || !O.CanAct()) continue;
				double Tw = 0.0;
				const double Sec = JamCarrierMarks::SecondsTo(O, Puck.Pos, Puck.Vel, Tw);
				if (O.Team != H.Team && O.Index != Con.Opp) Rg.OtherSec = FMath::Min(Rg.OtherSec, Sec);
				if (O.Team == H.Team) Rg.MateSec = FMath::Min(Rg.MateSec, Sec);
			}
			Rg.NetM = FVector2D::Distance(H.Pos, FVector2D(Sim->AttackGoalX(H.Team), 0.0));
			Rg.Gf0 = Sim->GetScore(H.Team); Rg.Ga0 = Sim->GetScore(1 - H.Team);
			T.Rings.Add(Rg);
		}
		for (int32 Ri = FMath::Max(0, T.Rings.Num() - 8); Ri < T.Rings.Num(); ++Ri)
		{
			FTrace::FRing& Rg = T.Rings[Ri];
			const int64 Age = Now - Rg.Start;
			if (Age <= 20 && H.bReverseBraking) Rg.bObey = true;
			if (Age <= 150 && H.IsDown()) Rg.bDown = true;
			if (Rg.Got < 0 && Age <= 90 && Ci >= 0) { Rg.Got = Ci; Rg.GotAt = Now; }
			if (Rg.Out < 0 && Rg.Got >= 0)
			{
				if (Rg.Got == T.Me) { if (H.IsDown()) Rg.Out = 1; else if (Now - Rg.GotAt >= 60) Rg.Out = 0; }
				else Rg.Out = Rg.Got == Rg.Opp ? 2 : (Sk[Rg.Got].Team == H.Team ? 4 : 3);
			}
			if (Rg.Out < 0 && Rg.Got < 0 && Age > 90) Rg.Out = 5;
			if (Age == 600 || (Rg.Gf < 0 && Sim->GetPhase() == EJamSimPhase::Over)) { Rg.Gf = Sim->GetScore(H.Team) - Rg.Gf0; Rg.Ga = Sim->GetScore(1 - H.Team) - Rg.Ga0; }
		}
		if (bConShown) { if (T.ConShownSince < 0) { T.ConShownSince = Now; ++T.ConEpisodes; } ++T.ConFrames; }
		else if (T.ConShownSince >= 0) { T.ConOnScreen.Add(static_cast<int32>(Now - T.ConShownSince)); T.ConShownSince = -1; }
		if (StopM.bShow && !StopM.bLit) ++T.ArmedRun; else if (!StopM.bShow) T.ArmedRun = 0;
		if (StopM.bLit) ++T.LitRun; else if (T.LitRun > 0) { T.LitRuns.Add(T.LitRun); T.LitRun = 0; }
		if (StopM.bShow) ++T.StopShowFrames;
		if (StopM.bLit) { ++T.StopLitFrames; if (Now - T.LastStopLit > 30) { FTrace::FStopEp E; E.Start = Now; E.Armed = T.ArmedRun; E.OffDeg = StopM.OffDeg; T.StopEps.Add(E); } T.LastStopLit = Now; }
		if (T.StopEps.Num() && Now - T.StopEps.Last().Start <= 90 && H.bReverseBraking) T.StopEps.Last().bBraked = true;
		// Lane A201: the scene at each raw lighting, and its outcome.
		if (StopM.bRawLit)
		{
			if (Now - T.LastRawLit > 30 && (!T.Scenes.Num() || T.Scenes.Last().Out >= 0 || Now - T.Scenes.Last().Start > 90))
			{
				FTrace::FScene Sc;
				Sc.Start = Now; Sc.Def = StopM.Def; Sc.Gate = StopM.Gate; Sc.bLit = StopM.bLit; Sc.D = StopM.DistM; Sc.Closing = StopM.ClosingMps; Sc.Speed = H.Vel.Size(); Sc.Off = StopM.OffDeg;
				Sc.SecondSec = StopM.SecondSec; Sc.SecondOpp = StopM.SecondOpp; Sc.NetM = StopM.NetM; Sc.BoardM = StopM.BoardM;
				for (const FJamSkaterState& O : Sk)
				{
					if (O.Team == H.Team || !O.CanAct()) continue;
					const FVector2D To = O.Pos - H.Pos;
					const double Dd = To.Size();
					const double Along = Dd > 1e-6 ? FVector2D::DotProduct(To / Dd, StopM.Head) : 0.0;
					const int32 Dir = Along >= 0.5 ? 0 : (Along <= -0.5 ? 2 : 1);
					if (Dd <= 6.0) ++Sc.N[0][Dir]; if (Dd <= 10.0) ++Sc.N[1][Dir]; if (Dd <= 14.0) ++Sc.N[2][Dir];
				}
				Sc.Gf0 = Sim->GetScore(H.Team); Sc.Ga0 = Sim->GetScore(1 - H.Team);
				T.Scenes.Add(Sc);
			}
			T.LastRawLit = Now;
		}
		for (int32 Si = FMath::Max(0, T.Scenes.Num() - 12); Si < T.Scenes.Num(); ++Si)
		{
			FTrace::FScene& Sc = T.Scenes[Si];
			const int64 Age = Now - Sc.Start;
			if (Age <= 30 && H.bReverseBraking) Sc.bBraked = true;
			if (Age <= 90 && H.IsDown()) Sc.bDown = true;
			if (Sc.Out < 0 && Age >= 90 && bCarry) { Sc.Out = 0; Sc.OutAt = 90; }
			if (Age == 600 || (Sc.Gf < 0 && Sim->GetPhase() == EJamSimPhase::Over)) { Sc.Gf = Sim->GetScore(H.Team) - Sc.Gf0; Sc.Ga = Sim->GetScore(1 - H.Team) - Sc.Ga0; }
		}
		int32 PokeBy = -1, LiftBy = -1; bool bKnock = false;
		for (const FJamSimEvent& E : Sim->GetFrameEvents())
		{
			if (E.Name == JamEvents::Poke && E.Who != T.Me && E.Kind == Clean) PokeBy = E.Who;
			if (E.Name == JamEvents::Lift && E.Who != T.Me && E.Kind == Clean) LiftBy = E.Who;
			if (E.Name == JamEvents::Knockdown && E.Who == T.Me) bKnock = true;
		}
		if (bPlaying)
		{
			++T.PlayFrames;
			if (H.IsDown()) ++T.DownFrames;
			if (Ci == T.Me) ++T.CarryFrames; else if (Ci < 0) ++T.LooseFrames; else if (Sk[Ci].Team == H.Team) ++T.MateFrames; else ++T.OppFrames;
		}
		// The knockdown, read against the frame before it (what he was doing when it came) and the second before.
		if (bKnock)
		{
			FDown D;
			D.Frames = H.KnockFrames; D.By = H.ContactBy; D.bCross = H.bContactCross; D.bBoard = H.bContactBoard; D.Ratio = H.ContactRatio;
			const FSnap* P = T.Back(Now - 1);
			D.CarryAge = T.bOpen ? T.Cur.Frames : 0;
			const FSnap* S0 = T.Back(T.bOpen ? FMath::Max(T.Cur.Start, Now - 60) : Now - 60);
			D.bBrakedLate = Now - T.BrakeStart <= 30;
			if (P)
			{
				D.bCarry = P->bCarry || (T.Back(Now - 2) && T.Back(Now - 2)->bCarry) || (T.Back(Now - 3) && T.Back(Now - 3)->bCarry);
				D.bSprint = P->bSprint; D.Speed = P->Vel[T.Me].Size();
				if (D.By >= 0 && D.By < MaxSk)
				{
					const FVector2D N = (P->Pos[T.Me] - P->Pos[D.By]).GetSafeNormal();   // the push on him
					D.Closing = FVector2D::DotProduct(P->Vel[D.By] - P->Vel[T.Me], N);
					const double Along = FVector2D::DotProduct(N, P->Fwd);
					D.bBehind = Along > 0.5; D.bFront = Along < -0.5;
				}
			}
			if (S0 && D.By >= 0 && D.By < MaxSk)
			{
				const FVector2D To = S0->Pos[D.By] - S0->Pos[T.Me];
				D.DistSecond = To.Size(); D.Dist0 = D.DistSecond;
				D.bAheadSecond = FVector2D::DotProduct(To, S0->Vel[T.Me]) > 0.0 && S0->Vel[T.Me].Size() >= 3.0;
				D.bPassOn = S0->bCarry && S0->bPassOn;
			}
			const double SprintSt = Sim->GetConfig().Contact.SprintStability;
			const double DownRatio = Sim->GetConfig().Contact.DownRatio;
			if (!D.bCarry) D.Class = NoPuck;
			else if (D.bBehind) D.Class = CarryBehind;
			else if (D.bSprint && SprintSt > 0.0 && D.Ratio * SprintSt < DownRatio) D.Class = CarrySprint;
			else if (D.CarryAge < 30) D.Class = CarryYoung;
			else if (D.bBrakedLate) D.Class = CarryBrakedLate;
			else if (D.Dist0 >= 7.0) D.Class = CarryStop;
			else D.Class = CarryNoRoom;
			// Lane A166: what the marks had said.
			if (D.bCarry && D.CarryAge < 30 && T.MarkTouches.Num() && Now - T.MarkTouches.Last().Frame <= 30) { T.MarkTouches.Last().bDown = true; D.ConLead = T.MarkTouches.Last().Lead; }
			for (const FSnap& Sn : T.Snaps) if (Sn.Frame >= Now - 60 && Sn.Frame < Now && Sn.bStopLit) D.bStopLit = true;
			if (D.bCarry && T.StopEps.Num() && Now - T.StopEps.Last().Start <= 90) T.StopEps.Last().bDown = true;
			T.Downs.Add(D);
		}
		// The carry.
		if (bCarry)
		{
			if (!T.bOpen)
			{
				if (T.bLastWasDrift && !T.bOtherTouched && T.Done.Num()) { T.Done.Last().bRegained = true; T.Done.Last().RegainGap = static_cast<int32>(Now - T.DriftClosed) + 30; }
				T.bLastWasDrift = false;
				{
					FTrace::FTouch Tc; Tc.Frame = Now;
					for (int32 Kb = 45; Kb >= 1 && Tc.Lead < 0; --Kb) { const FSnap* Sb = T.Back(Now - Kb); if (Sb && Sb->bContest) Tc.Lead = Kb; }
					T.MarkTouches.Add(Tc);
				}
				T.bOpen = true; T.Cur = FCarry(); T.Cur.Start = Now; T.Cur.GraceAtStart = H.TakeGraceLeft;
				for (const FJamSkaterState& O : Sk) if (O.Team != H.Team) T.Cur.StartNearest = FMath::Min(T.Cur.StartNearest, FVector2D::Distance(O.Pos, H.Pos));
			}
			T.Pending = 0;
			++T.Cur.Frames;
			if (H.bReverseBraking) T.Cur.bBraked = true;
			if (H.bSprinting) T.Cur.bSprinted = true;
			if (H.SpinFrames > 0) T.Cur.bSpun = true;
			if (H.BreakawayFrames > 0) T.Cur.bBreakaway = true;   // lane A194
			T.Cur.EndSpeed = H.Vel.Size(); T.Cur.bEndSprint = H.bSprinting;
		}
		else if (T.bOpen)
		{
			int32 End = -1, Ender = -1;
			if (T.Pending == 0 && T.Cur.LeavePuckSpeed == 0 && T.Cur.LeaveDist == 0)
			{
				T.Cur.LeavePuckSpeed = Puck.Vel.Size(); T.Cur.LeaveDist = FVector2D::Distance(Puck.Pos, H.Pos); T.Cur.LeaveRel = (Puck.Vel - H.Vel).Size(); T.Cur.LeaveMySpeed = H.Vel.Size();
				T.Cur.bLeaveBraking = H.bReverseBraking || Now - T.BrakeStart <= 20; T.Cur.bLeaveCharging = H.ChargeFrames > 0 || H.PassChargeFrames > 0;
				T.Cur.bStopCover = Now - T.BrakeStart <= 30 && T.BrakeStartSpeed >= UJamSim::StopGraceMinMps;
			}
			if (!bPlaying) End = Now - T.LastShot <= 90 && Sim->GetPhase() == EJamSimPhase::GoalPause && T.Pending > 0 ? OwnShot : Whistle;
			else if (PokeBy >= 0 && Sk[PokeBy].Team != H.Team && (H.StickHitResult == 1 || Puck.LastTouch == PokeBy)) { End = Poke; Ender = PokeBy; }
			else if (H.StickHitResult == 2 || (LiftBy >= 0 && Sk[LiftBy].Team != H.Team)) { End = Lift; Ender = LiftBy; }
			else if (bKnock) { End = H.ContactBy >= 0 ? CheckDown : OtherFall; Ender = H.ContactBy; }
			else if (H.ContactOutcome == 2 || (H.StumbleFrames > 0 && H.ContactBy >= 0)) { End = CheckStumble; Ender = H.ContactBy; }
			else if (Now - T.LastShot <= 12 && T.LastShot >= T.LastPass) End = OwnShot;
			else if (Now - T.LastPass <= 12) End = OwnPass;
			else if (Now - T.LastShot <= 12) End = OwnShot;
			else if (!H.CanAct()) End = OtherFall;
			else if (Puck.LastTouch >= 0 && Puck.LastTouch != T.Me) { End = Sk[Puck.LastTouch].Team == H.Team ? TouchMate : TouchOpp; Ender = Puck.LastTouch; }
			else if (++T.Pending > 30) End = Drift;
			if (End >= 0) CloseCarry(T, End, Ender, *Sim);
		}
		// The frame's snapshot (after the carry was read: Back() never returns this frame's to the code above).
		FSnap& S = T.Snaps[T.At];
		T.At = (T.At + 1) % Ring;
		S.Frame = Now;
		for (int32 i = 0; i < Sk.Num() && i < MaxSk; ++i) { S.Pos[i] = Sk[i].Pos; S.Vel[i] = Sk[i].Vel; }
		S.Fwd = H.Forward();
		S.bCarry = bCarry; S.bSprint = H.bSprinting; S.bBrake = H.bReverseBraking;
		S.bSpinReady = Now >= H.SpinReadyFrame && H.SpinFrames == 0 && Sim->GetConfig().Skater.SpinFrames > 0;
		FVector2D Aim;
		S.bPassOn = bCarry && Sim->BestPass(T.Me, Aim) >= 0;
		S.bContest = bConShown; S.bStopLit = StopM.bLit;
	}

	struct FOpt { FString Level = TEXT("pro"), Player = TEXT("regular"), Set; int32 Seeds = 40, Rows = 0, From = 1; };
	FOpt ReadOpt()
	{
		FOpt O;
		const FString Env = FPlatformMisc::GetEnvironmentVariable(TEXT("JAM_CARRY_TRACE"));
		TArray<FString> Parts;
		Env.ParseIntoArray(Parts, TEXT(";"));
		for (const FString& Part : Parts)
		{
			FString K, V;
			if (!Part.Split(TEXT("="), &K, &V)) continue;
			if (K == TEXT("level")) O.Level = V; else if (K == TEXT("player")) O.Player = V; else if (K == TEXT("seeds")) O.Seeds = FCString::Atoi(*V);
			else if (K == TEXT("rows")) O.Rows = FCString::Atoi(*V); else if (K == TEXT("from")) O.From = FCString::Atoi(*V); else if (K == TEXT("set")) O.Set = V;
		}
		return O;
	}

	void ApplySet(FJamGameConfig& G, const FString& Set, FAutomationTestBase& T)
	{
		TArray<FString> Parts;
		Set.ParseIntoArray(Parts, TEXT(","));
		for (const FString& Part : Parts)
		{
			FString K, Vs;
			if (!Part.Split(TEXT(":"), &K, &Vs)) continue;
			const double V = FCString::Atod(*Vs);
			if (K == TEXT("stick.take_grace_frames")) G.Stick.TakeGraceFrames = FMath::RoundToInt32(V);
			else if (K == TEXT("stick.poke_assist_deg")) G.Stick.PokeAssistDeg = V;
			else if (K == TEXT("stick.miss_recovery_frames")) G.Stick.MissRecoveryFrames = FMath::RoundToInt32(V);
			else if (K == TEXT("stick.stop_grace_frames")) G.Stick.StopGraceFrames = FMath::RoundToInt32(V);
			else if (K == TEXT("pickup_settle_frames")) G.Stick.PickupSettleFrames = FMath::RoundToInt32(V);   // the third arm (no key)
			else if (K == TEXT("pickup_settle_bots")) G.Stick.bPickupSettleBots = V > 0.5;
			else if (K == TEXT("burst_take_frames")) G.Skater.BurstTakeFrames = FMath::RoundToInt32(V);   // the second arm (no key)
			else if (K == TEXT("burst_take_bots")) G.Skater.bBurstTakeBots = V > 0.5;
			else if (K == TEXT("stop_grace_bots")) G.Stick.bStopGraceBots = V > 0.5;   // the measurement's arm (no key)
			else if (K == TEXT("contact.down_frames_max")) G.Contact.DownFramesMax = FMath::RoundToInt32(V);
			else if (K == TEXT("skater.free_speed_mult")) G.Skater.FreeSpeedMult = V;   // lane A185 (track F2 evolution 9): 1 = the game before the lane
			else if (K == TEXT("skater.breakaway.speed_bonus")) G.Skater.BreakawaySpeedBonus = V;   // lane A194 (track F2 evolution 10)
			else if (K == TEXT("carry_brake_mult")) G.Skater.CarryReverseBrakeMult = V;   // lane A194: the measurement's number (no key)
			else if (K == TEXT("burst_carry_accel_mult")) G.Skater.BurstCarryAccelMult = V;
			else T.AddError(FString::Printf(TEXT("JAM_CARRY_TRACE set: unknown key %s"), *K));
		}
	}

	double Median(TArray<int32> A) { if (!A.Num()) return 0.0; A.Sort(); return A[A.Num() / 2]; }

	// Lane A166: env JAM_MARK_RULE = "early=0.25;late=0.6;closing=8;toward=3;hsec=1;near=7;far=11;arm=20;cone=0.82;stopclosing=3" (every part optional): the
	// marks' rules for this run, so a sweep needs no build. Absent = the shipped rules (JamCarrierMarks.h).
	FString ReadMarkRule(FTrace& T)
	{
		const FString Env = FPlatformMisc::GetEnvironmentVariable(TEXT("JAM_MARK_RULE"));
		TArray<FString> Parts;
		Env.ParseIntoArray(Parts, TEXT(";"));
		for (const FString& Part : Parts)
		{
			FString K, Vs;
			if (!Part.Split(TEXT("="), &K, &Vs)) continue;
			const double V = FCString::Atod(*Vs);
			if (K == TEXT("minshow")) T.ShowRule.MinFrames = FMath::RoundToInt32(V); else if (K == TEXT("linger")) T.ShowRule.LingerFrames = FMath::RoundToInt32(V);   // lane A178
		}
		JamCarrierMarks::ApplyStopRuleSpec(T.StopRule, Env);   // lane A201: the stop line's parts by the one parse the scripted player reads too
		JamCarrierMarks::ApplyContestRuleSpec(T.ConRule, Env);   // ... and the ring's (evolution 12)
		return Env;
	}
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamBarCarryTrace, "Bar.Movement.CarryTrace", JamCarryTests::Flags)
bool FJamBarCarryTrace::RunTest(const FString& Parameters)
{
	using namespace JamCarryTests;
	// Lane A201: env JAM_TRACE_ARMS = "label@stopmark@rule[@hand[@contest]]|..." plays every arm on the same seeds in this one process: each arm sets
	// JAM_PLAYTESTER_STOPMARK (brake = the player obeys the line; empty = he ignores it) and JAM_MARK_RULE (the line's rule) for its run.
	if (Parameters != TEXT("arm"))
	{
		const FString ArmsEnv = FPlatformMisc::GetEnvironmentVariable(TEXT("JAM_TRACE_ARMS"));
		if (!ArmsEnv.IsEmpty())
		{
			TArray<FString> Arms;
			ArmsEnv.ParseIntoArray(Arms, TEXT("|"));
			bool bOk = true;
			for (const FString& Arm : Arms)
			{
				TArray<FString> P;
				Arm.ParseIntoArray(P, TEXT("@"), false);
				while (P.Num() < 5) P.Add(FString());
				FPlatformMisc::SetEnvironmentVar(TEXT("JAM_PLAYTESTER_CONTEST"), *P[4]);   // lane A201 (evolution 12): the 5th part: the ring's obedience (brake | brake:N | empty)
				FPlatformMisc::SetEnvironmentVar(TEXT("JAM_PLAYTESTER_STOPMARK_HAND"), *P[3]);   // the 4th part: the obeying hand's lag in frames (empty = the class's)
				FPlatformMisc::SetEnvironmentVar(TEXT("JAM_TRACE_ARM"), *P[0]);
				FPlatformMisc::SetEnvironmentVar(TEXT("JAM_PLAYTESTER_STOPMARK"), *P[1]);
				FPlatformMisc::SetEnvironmentVar(TEXT("JAM_MARK_RULE"), *P[2]);
				AddInfo(FString::Printf(TEXT("CARRYTRACE arm %s | stopmark \"%s\" | rule \"%s\""), *P[0], *P[1], *P[2]));
				bOk = RunTest(TEXT("arm")) && bOk;
			}
			return bOk;
		}
	}
	const FString ArmLabel = FPlatformMisc::GetEnvironmentVariable(TEXT("JAM_TRACE_ARM"));
	TArray<FString> Errors;
	UJamCartridge* C = UJamCartridge::LoadFromFile(UJamCartridge::ResolveCartridgePath(TEXT("hockey.regular")), Errors);
	for (const FString& E : Errors) AddError(E);
	if (!C) return false;
	const FOpt O = ReadOpt();
	const JamAI::EPlaytester Kind = O.Player == TEXT("novice") ? JamAI::EPlaytester::Novice : (O.Player == TEXT("good") ? JamAI::EPlaytester::Good : JamAI::EPlaytester::Regular);
	TArray<FCarry> All;
	TArray<FDown> Downs;
	int32 Matches = 0, Wins = 0, Touches = 0, Rows = 0;
	int64 Play = 0, Down = 0, CarryF = 0, Loose = 0, OppF = 0, MateF = 0;
	TArray<FTrace::FTouch> MarkTouches;
	TArray<FTrace::FStopEp> StopEps;
	int64 ConEpisodes = 0, ConFrames = 0, StopLitFrames = 0, StopShowFrames = 0;
	TArray<int32> ConOnScreen, LitRuns;   // lane A178
	FString MarkRule;
	for (int32 Seed = O.From; Seed < O.From + O.Seeds; ++Seed)
	{
		UJamCartridge* M = DuplicateObject<UJamCartridge>(C, GetTransientPackage());
		ApplySet(M->Game, O.Set, *this);
		JamAI::FJamSimAdapter Sim(*M);
		FTrace* T = new FTrace();
		T->Sim = &Sim;
		MarkRule = ReadMarkRule(*T);
		const JamAI::FJamMatchConfig Cfg = JamAI::ToMatchConfigResolved(*M, *O.Level);
		const JamAI::FJamPlaytestStats S = JamAI::RunPlaytestMatch(Sim, Cfg, static_cast<uint64>(Seed), Kind, 36000, M->Game.Shot.ChargeFramesMax, false, &CarryTrace, T, 1);
		if (T->bOpen && Sim.GetSim()) CloseCarry(*T, Whistle, -1, *Sim.GetSim());
		++Matches; if (S.GoalsFor > S.GoalsAgainst) ++Wins;
		Play += T->PlayFrames; Down += T->DownFrames; CarryF += T->CarryFrames; Loose += T->LooseFrames; OppF += T->OppFrames; MateF += T->MateFrames; Touches += T->Touches;
		AddInfo(FString::Printf(TEXT("CARRYTRACE match %s %s seed %d: %lld frames, %d:%d, hash %016llx | carries %d, touches %d, knockdowns %d, frames down %lld of %lld in play"), *O.Player, *O.Level, Seed,
			static_cast<long long>(S.Frames), S.GoalsFor, S.GoalsAgainst, static_cast<unsigned long long>(S.Hash), T->Done.Num(), T->Touches, T->Downs.Num(), static_cast<long long>(T->DownFrames), static_cast<long long>(T->PlayFrames)));
		for (const FCarry& K : T->Done)
		{
			if (Rows++ < O.Rows)
				AddInfo(FString::Printf(TEXT("CARRYTRACE carry seed %d f %lld: %d frames, %s | by %d, nearest opponent at the start %.1f m, grace at the start %d, braked %d sprinted %d spun %d | a second earlier: short %d pass %d brake %d (the ender %.1f m off, closing %.1f) spin %d"),
					Seed, static_cast<long long>(K.Start), K.Frames, EndName(K.End), K.Ender, K.StartNearest, K.GraceAtStart, K.bBraked ? 1 : 0, K.bSprinted ? 1 : 0, K.bSpun ? 1 : 0, K.bShort ? 1 : 0, K.bPassOn ? 1 : 0, K.bBrakeOn ? 1 : 0, K.EnderDist0, K.EnderClosing0, K.bSpinOn ? 1 : 0));
		}
		for (FTrace::FRing& Rg : T->Rings)   // lane A201 (evolution 12): one row a showing of the ring
		{
			if (Rg.Gf < 0) { Rg.Gf = S.GoalsFor - Rg.Gf0; Rg.Ga = S.GoalsAgainst - Rg.Ga0; }
			AddInfo(FString::Printf(TEXT("RINGSCENE arm=%s level=%s seed=%d f=%lld hsec=%.3f osec=%.3f cl=%.2f v=%.2f opptoward=%.2f othersec=%.3f matesec=%.3f net=%.2f obey=%d out=%d down=%d gf=%d ga=%d res=%d"),
				*ArmLabel, *O.Level, Seed, static_cast<long long>(Rg.Start), Rg.HSec, Rg.OSec, Rg.Closing, Rg.Speed, Rg.OppToward, FMath::Min(Rg.OtherSec, 99.0), FMath::Min(Rg.MateSec, 99.0), Rg.NetM,
				Rg.bObey ? 1 : 0, Rg.Out, Rg.bDown ? 1 : 0, Rg.Gf, Rg.Ga, S.GoalsFor > S.GoalsAgainst ? 1 : (S.GoalsFor < S.GoalsAgainst ? -1 : 0)));
		}
		{
			int32 DownsAll = 0, DownsLoose = 0;
			for (const FDown& Dn : T->Downs) { ++DownsAll; if (Dn.Class == NoPuck || Dn.Class == CarryYoung) ++DownsLoose; }
			AddInfo(FString::Printf(TEXT("RINGMATCH arm=%s level=%s seed=%d rings=%d downs=%d downs_loose=%d"), *ArmLabel, *O.Level, Seed, T->Rings.Num(), DownsAll, DownsLoose));
		}
		for (FTrace::FScene& Sc : T->Scenes)   // lane A201: one row a raw lighting
		{
			if (Sc.Gf < 0) { Sc.Gf = S.GoalsFor - Sc.Gf0; Sc.Ga = S.GoalsAgainst - Sc.Ga0; }
			AddInfo(FString::Printf(TEXT("LITSCENE arm=%s level=%s seed=%d f=%lld lit=%d gate=%d d=%.2f cl=%.2f v=%.2f off=%.1f sec=%.3f net=%.2f brd=%.2f a6=%d s6=%d b6=%d a10=%d s10=%d b10=%d a14=%d s14=%d b14=%d braked=%d out=%d at=%d down=%d gf=%d ga=%d res=%d"),
				*ArmLabel, *O.Level, Seed, static_cast<long long>(Sc.Start), Sc.bLit ? 1 : 0, Sc.Gate, Sc.D, Sc.Closing, Sc.Speed, Sc.Off, FMath::Min(Sc.SecondSec, 99.0), Sc.NetM, Sc.BoardM,
				Sc.N[0][0], Sc.N[0][1], Sc.N[0][2], Sc.N[1][0], Sc.N[1][1], Sc.N[1][2], Sc.N[2][0], Sc.N[2][1], Sc.N[2][2], Sc.bBraked ? 1 : 0, Sc.Out, Sc.OutAt, Sc.bDown ? 1 : 0, Sc.Gf, Sc.Ga,
				S.GoalsFor > S.GoalsAgainst ? 1 : (S.GoalsFor < S.GoalsAgainst ? -1 : 0)));
		}
		All.Append(T->Done);
		Downs.Append(T->Downs);
		MarkTouches.Append(T->MarkTouches); StopEps.Append(T->StopEps);
		ConOnScreen.Append(T->ConOnScreen); LitRuns.Append(T->LitRuns);
		ConEpisodes += T->ConEpisodes; ConFrames += T->ConFrames; StopLitFrames += T->StopLitFrames; StopShowFrames += T->StopShowFrames;
		delete T;
	}
	const double Mn = FMath::Max(1, Matches);
	// The carries.
	{
		TArray<int32> Len;
		for (const FCarry& K : All) Len.Add(K.Frames);
		int32 Over90 = 0, Over180 = 0;
		for (const FCarry& K : All) { if (K.Frames >= 90) ++Over90; if (K.Frames >= 180) ++Over180; }
		AddInfo(FString::Printf(TEXT("CARRYTRACE table %s at %s, %d matches (seeds %d..%d), set \"%s\": %d carries of the human (%.1f a match; %d shorter touches left out), median %.2f s, 1.5 s or longer %.1f %%, 3 s or longer %.2f a match, %d wins | play: the human carries %.1f %%, his mates %.1f %%, opponents %.1f %%, nobody %.1f %%; he lies down %.2f %% of play"),
			*O.Player, *O.Level, Matches, O.From, O.From + O.Seeds - 1, *O.Set, All.Num(), All.Num() / Mn, Touches, Median(Len) / 60.0, 100.0 * Over90 / FMath::Max(1, All.Num()), Over180 / Mn, Wins,
			100.0 * CarryF / FMath::Max<int64>(1, Play), 100.0 * MateF / FMath::Max<int64>(1, Play), 100.0 * OppF / FMath::Max<int64>(1, Play), 100.0 * Loose / FMath::Max<int64>(1, Play), 100.0 * Down / FMath::Max<int64>(1, Play)));
		int32 LossN = 0, LossShort = 0, LossPass = 0, LossBrake = 0, LossSpin = 0, LossAny = 0, LossAnyLong = 0, LossLong = 0;
		for (int32 E = 0; E < EndCount; ++E)
		{
			TArray<int32> L; int32 Short = 0, Pass = 0, PassAny = 0, Brake = 0, Spin = 0, Any = 0, Braked = 0, Sprint = 0, G40 = 0, G60 = 0;
			double Near = 0;
			for (const FCarry& K : All)
			{
				if (K.End != E) continue;
				L.Add(K.Frames);
				if (K.bShort) ++Short; if (K.bPassOn) ++Pass; if (K.bPassAny) ++PassAny; if (K.bBrakeOn) ++Brake; if (K.bSpinOn) ++Spin;
				if (K.bPassOn || K.bBrakeOn || K.bSpinOn) ++Any;
				if (K.bBraked) ++Braked; if (K.bEndSprint) ++Sprint;
				if (K.Frames <= 40) ++G40; if (K.Frames <= 60) ++G60;
				Near += K.StartNearest;
				if (IsLoss(E)) { ++LossN; if (K.bShort) ++LossShort; else { ++LossLong; if (K.bPassOn || K.bBrakeOn || K.bSpinOn) ++LossAnyLong; } if (K.bPassOn) ++LossPass; if (K.bBrakeOn) ++LossBrake; if (K.bSpinOn) ++LossSpin; if (K.bPassOn || K.bBrakeOn || K.bSpinOn) ++LossAny; }
			}
			const int32 N = L.Num();
			AddInfo(FString::Printf(TEXT("CARRYTRACE row | %-40s | %4d | %5.1f %% | median %.2f s | 40 frames or less %5.1f %%, a second or less %5.1f %% | a second earlier (or at the start): a pass open %5.1f %% (at any frame of that second %5.1f %%), the stop on %5.1f %%, the spin ready %5.1f %%, any of them %5.1f %% | he had braked in it %5.1f %%, sprinting as it ended %5.1f %%, nearest opponent as it began %.1f m"),
				EndName(E), N, 100.0 * N / FMath::Max(1, All.Num()), Median(L) / 60.0, 100.0 * G40 / FMath::Max(1, N), 100.0 * G60 / FMath::Max(1, N), 100.0 * Pass / FMath::Max(1, N), 100.0 * PassAny / FMath::Max(1, N), 100.0 * Brake / FMath::Max(1, N),
				100.0 * Spin / FMath::Max(1, N), 100.0 * Any / FMath::Max(1, N), 100.0 * Braked / FMath::Max(1, N), 100.0 * Sprint / FMath::Max(1, N), N ? Near / N : 0.0));
		}
		// Lane A194 (track F2 evolution 10): the human's breakaways (the burst ran in the carry) and how they ended; "caught from behind" = a stick or a hit by an
		// opponent who stood behind him along his travel.
		{
			int32 Nb = 0, Shot = 0, Pass = 0, Wh = 0, Taken = 0, Behind = 0;
			for (const FCarry& K : All)
			{
				if (!K.bBreakaway) continue;
				++Nb;
				if (K.End == OwnShot) ++Shot; else if (K.End == OwnPass) ++Pass; else if (K.End == Whistle) ++Wh;
				else if (K.End == Poke || K.End == Lift || K.End == CheckDown || K.End == CheckStumble || K.End == TouchOpp) { ++Taken; if (K.bEnderBehind) ++Behind; }
			}
			AddInfo(FString::Printf(TEXT("CARRYTRACE breakaway %s at %s: %d breakaway carries (%.2f a match): his shot %d (%.1f %%), his pass %d, the whistle %d, taken %d (%.1f %%), caught from behind %d (%.1f %%, %.3f a match)"),
				*O.Player, *O.Level, Nb, Nb / Mn, Shot, Nb ? 100.0 * Shot / Nb : 0.0, Pass, Wh, Taken, Nb ? 100.0 * Taken / Nb : 0.0, Behind, Nb ? 100.0 * Behind / Nb : 0.0, Behind / Mn));
		}
		AddInfo(FString::Printf(TEXT("CARRYTRACE kept %s at %s: %d carries lost (a stick, a hit, a lost handle) of %d (%.1f %%); of the lost, shorter than a second %d (%.1f %%: no second earlier to act in); a pass was open a second earlier (or at the start) in %d (%.1f %%), the stop was on in %d (%.1f %%), the spin was ready against the stick in %d (%.1f %%), any of the three in %d (%.1f %%); of the %d lost carries of a second or longer, any of the three in %d (%.1f %%)"),
			*O.Player, *O.Level, LossN, All.Num(), 100.0 * LossN / FMath::Max(1, All.Num()), LossShort, 100.0 * LossShort / FMath::Max(1, LossN), LossPass, 100.0 * LossPass / FMath::Max(1, LossN), LossBrake, 100.0 * LossBrake / FMath::Max(1, LossN),
			LossSpin, 100.0 * LossSpin / FMath::Max(1, LossN), LossAny, 100.0 * LossAny / FMath::Max(1, LossN), LossLong, LossAnyLong, 100.0 * LossAnyLong / FMath::Max(1, LossLong)));
		// The stick's takes by the carry's length: how soon after the grace.
		int32 B[5] = {}; int32 StickN = 0;
		const int32 Grace = C->Game.Stick.TakeGraceFrames;
		for (const FCarry& K : All) if (K.End == Poke || K.End == Lift) { ++StickN; ++B[K.Frames <= Grace + 6 ? 0 : K.Frames <= Grace + 15 ? 1 : K.Frames <= 60 ? 2 : K.Frames <= 120 ? 3 : 4]; }
		int32 Cover = 0;
		for (const FCarry& K : All) if ((K.End == Poke || K.End == Lift) && K.bStopCover) ++Cover;
		AddInfo(FString::Printf(TEXT("CARRYTRACE stick %s at %s: %d carries ended by a stick; by the carry's length: within 6 frames of the grace's end (%d frames) %d, 7 to 15 frames after it %d, up to a second %d, one to two seconds %d, longer %d | his stop (the reverse brake begun at 6 m/s or more) began inside the half second before the stick took it in %d (%.1f %%)"),
			*O.Player, *O.Level, StickN, Grace, B[0], B[1], B[2], B[3], B[4], Cover, 100.0 * Cover / FMath::Max(1, StickN)));
		// The carries that "drifted": what the puck was doing as it left him.
		{
			int32 N = 0, Fast = 0, Brake = 0, Charge = 0, Regained = 0; double Dist = 0, Rel = 0, Mine = 0; TArray<int32> Gaps;
			for (const FCarry& K : All)
			{
				if (K.End != Drift) continue;
				++N; Dist += K.LeaveDist; Rel += K.LeaveRel; Mine += K.LeaveMySpeed;
				if (K.LeavePuckSpeed >= 14.0) ++Fast; if (K.bLeaveBraking) ++Brake; if (K.bLeaveCharging) ++Charge; if (K.bRegained) { ++Regained; Gaps.Add(K.RegainGap); }
			}
			AddInfo(FString::Printf(TEXT("CARRYTRACE drift %s at %s: %d carries left the blade with no cause read; as the puck left: it flew at 14 m/s or more in %d (%.1f %%: a release the flags did not date), he was braking or had braked inside a third of a second in %d (%.1f %%), a shot or pass was being charged in %d (%.1f %%); the puck %.2f m from his body, %.1f m/s against him, he at %.1f m/s; he had it again himself with nobody else touching it in %d (%.1f %%), after a median of %.2f s"),
				*O.Player, *O.Level, N, Fast, 100.0 * Fast / FMath::Max(1, N), Brake, 100.0 * Brake / FMath::Max(1, N), Charge, 100.0 * Charge / FMath::Max(1, N), N ? Dist / N : 0.0, N ? Rel / N : 0.0, N ? Mine / N : 0.0,
				Regained, 100.0 * Regained / FMath::Max(1, N), Median(Gaps) / 60.0));
		}
	}
	// The knockdowns.
	{
		int64 AllFrames = 0;
		for (const FDown& D : Downs) AllFrames += D.Frames;
		AddInfo(FString::Printf(TEXT("CARRYTRACE down %s at %s: %d knockdowns of the human (%.2f a match), %lld frames (%.0f a knockdown), %.2f %% of play (the sim's frames down %.2f %%)"), *O.Player, *O.Level, Downs.Num(), Downs.Num() / Mn,
			static_cast<long long>(AllFrames), Downs.Num() ? static_cast<double>(AllFrames) / Downs.Num() : 0.0, 100.0 * AllFrames / FMath::Max<int64>(1, Play), 100.0 * Down / FMath::Max<int64>(1, Play)));
		for (int32 K = 0; K < DownCount; ++K)
		{
			int32 N = 0, Sprint = 0, Cross = 0, Board = 0, Front = 0, Behind = 0, Pass = 0, Fast = 0; int64 F = 0; double Closing = 0, Ratio = 0, Dist = 0, Age = 0; int32 DistN = 0;
			for (const FDown& D : Downs)
			{
				if (D.Class != K) continue;
				++N; F += D.Frames; Closing += D.Closing; Ratio += D.Ratio; Age += D.CarryAge; if (D.Closing >= 10.0) ++Fast;
				if (D.bSprint) ++Sprint; if (D.bCross) ++Cross; if (D.bBoard) ++Board; if (D.bFront) ++Front; if (D.bBehind) ++Behind; if (D.bPassOn) ++Pass;
				if (D.DistSecond >= 0) { Dist += D.DistSecond; ++DistN; }
			}
			AddInfo(FString::Printf(TEXT("CARRYTRACE downrow | %-82s | %4d | %5.1f %% of knockdowns | %5.1f %% of the frames down | %.0f frames each | closing %.1f m/s (10 or more in %5.1f %%), ratio %.2f | the puck his for %.2f s | sprinting %5.1f %%, a cross-check %5.1f %%, into the boards %5.1f %%, into his front arc %5.1f %%, a pass open a second earlier or as he got it %5.1f %%, the hitter %.1f m off then"),
				DownName(K), N, 100.0 * N / FMath::Max(1, Downs.Num()), 100.0 * F / FMath::Max<int64>(1, AllFrames), N ? static_cast<double>(F) / N : 0.0, N ? Closing / N : 0.0, 100.0 * Fast / FMath::Max(1, N), N ? Ratio / N : 0.0, N ? Age / N / 60.0 : 0.0,
				100.0 * Sprint / FMath::Max(1, N), 100.0 * Cross / FMath::Max(1, N), 100.0 * Board / FMath::Max(1, N), 100.0 * Front / FMath::Max(1, N), 100.0 * Pass / FMath::Max(1, N), DistN ? Dist / DistN : 0.0));
		}
	}
	// Lane A166: the two marks against what happened.
	{
		int32 Marked = 0, MarkedDown = 0, Unmarked = 0, UnmarkedDown = 0, Marked20 = 0, Marked20Down = 0;
		for (const FTrace::FTouch& Tc : MarkTouches)
		{
			if (Tc.Lead >= 1) { ++Marked; if (Tc.bDown) ++MarkedDown; if (Tc.Lead >= 20) { ++Marked20; if (Tc.bDown) ++Marked20Down; } }
			else { ++Unmarked; if (Tc.bDown) ++UnmarkedDown; }
		}
		int32 Young = 0, YoungLit = 0, YoungLit20 = 0; TArray<int32> Leads;
		for (const FDown& D : Downs) if (D.Class == CarryYoung) { ++Young; if (D.ConLead >= 1) { ++YoungLit; Leads.Add(D.ConLead); } if (D.ConLead >= 20) ++YoungLit20; }
		AddInfo(FString::Printf(TEXT("CARRYTRACE mark contested %s at %s (rule \"%s\"): lit in %lld episodes (%.1f a match), %lld frames (%.2f %% of play) | his %d possessions (%.1f a match): the mark was lit before the touch in %d (%.1f %%), and he was down inside half a second after %d of them (PRECISION %.1f %%); not lit before %d, down after %d (%.1f %%) | lit 20 frames or more before the touch: %d, down after %d (%.1f %%) | the class hit-as-he-won-it: %d knockdowns, the mark was lit before the touch in %d (RECALL %.1f %%), 20 frames or more before in %d (%.1f %%), median lead %.0f frames"),
			*O.Player, *O.Level, *MarkRule, static_cast<long long>(ConEpisodes), ConEpisodes / Mn, static_cast<long long>(ConFrames), 100.0 * ConFrames / FMath::Max<int64>(1, Play), MarkTouches.Num(), MarkTouches.Num() / Mn,
			Marked, 100.0 * Marked / FMath::Max(1, MarkTouches.Num()), MarkedDown, 100.0 * MarkedDown / FMath::Max(1, Marked), Unmarked, UnmarkedDown, 100.0 * UnmarkedDown / FMath::Max(1, Unmarked),
			Marked20, Marked20Down, 100.0 * Marked20Down / FMath::Max(1, Marked20), Young, YoungLit, 100.0 * YoungLit / FMath::Max(1, Young), YoungLit20, 100.0 * YoungLit20 / FMath::Max(1, Young), Median(Leads)));
		int32 StopClass = 0, StopClassLit = 0, Other = 0, OtherLit = 0, Braked = 0, BrakedDown = 0, NotBraked = 0, NotBrakedDown = 0;
		for (const FDown& D : Downs) { if (D.Class == CarryStop) { ++StopClass; if (D.bStopLit) ++StopClassLit; } else if (D.Class == CarryBrakedLate || D.Class == CarryNoRoom) { ++Other; if (D.bStopLit) ++OtherLit; } }
		for (const FTrace::FStopEp& E : StopEps) { if (E.bBraked) { ++Braked; if (E.bDown) ++BrakedDown; } else { ++NotBraked; if (E.bDown) ++NotBrakedDown; } }
		AddInfo(FString::Printf(TEXT("CARRYTRACE mark stop %s at %s: lit in %d episodes (%.1f a match), shown %lld frames and lit %lld (%.1f %% and %.1f %% of his carry frames) | the class the-stop-was-on: %d knockdowns, the mark was lit inside the second before in %d (RECALL %.1f %%); braked-too-late and no-room: %d, lit before %d | of the lit episodes he braked inside 1.5 s in %d and was down inside 1.5 s in %d of those (%.1f %%); he did not brake in %d and was down in %d (PRECISION %.1f %%)"),
			*O.Player, *O.Level, StopEps.Num(), StopEps.Num() / Mn, static_cast<long long>(StopShowFrames), static_cast<long long>(StopLitFrames), 100.0 * StopShowFrames / FMath::Max<int64>(1, CarryF), 100.0 * StopLitFrames / FMath::Max<int64>(1, CarryF),
			StopClass, StopClassLit, 100.0 * StopClassLit / FMath::Max(1, StopClass), Other, OtherLit, Braked, BrakedDown, 100.0 * BrakedDown / FMath::Max(1, Braked), NotBraked, NotBrakedDown, 100.0 * NotBrakedDown / FMath::Max(1, NotBraked)));
	}
	// Lane A178: what a window can read: the time each mark is on screen, the armed state before the light, the line by the opponent's side.
	{
		int32 One = 0, Under12 = 0;
		for (const int32 D : ConOnScreen) { if (D <= 1) ++One; if (D < 12) ++Under12; }
		AddInfo(FString::Printf(TEXT("CARRYTRACE mark seen contested %s at %s (rule \"%s\"): shown %d times (%.1f a match), on screen a median of %.0f frames, one frame only in %d, under 12 frames in %d (%.1f %%)"),
			*O.Player, *O.Level, *MarkRule, ConOnScreen.Num(), ConOnScreen.Num() / Mn, Median(ConOnScreen), One, Under12, 100.0 * Under12 / FMath::Max(1, ConOnScreen.Num())));
		TArray<int32> Armed; int32 ArmedShort = 0, Side = 0, SideNoBrake = 0, SideDown = 0, Front = 0, FrontNoBrake = 0, FrontDown = 0;
		for (const FTrace::FStopEp& E : StopEps)
		{
			Armed.Add(E.Armed); if (E.Armed < 12) ++ArmedShort;
			if (E.OffDeg >= 40.0) { ++Side; if (!E.bBraked) { ++SideNoBrake; if (E.bDown) ++SideDown; } }
			else { ++Front; if (!E.bBraked) { ++FrontNoBrake; if (E.bDown) ++FrontDown; } }
		}
		AddInfo(FString::Printf(TEXT("CARRYTRACE mark seen stop %s at %s: %d lit showings (%.1f a match), lit a median of %.0f frames at a time; armed before the light a median of %.0f frames, under 12 frames in %d (%.1f %%) | the opponent 40 degrees or more off his travel as it lit: %d (%.1f %%), no brake %d, down inside 1.5 s %d (%.1f %%); inside 40 degrees: %d, no brake %d, down %d (%.1f %%)"),
			*O.Player, *O.Level, StopEps.Num(), StopEps.Num() / Mn, Median(LitRuns), Median(Armed), ArmedShort, 100.0 * ArmedShort / FMath::Max(1, StopEps.Num()),
			Side, 100.0 * Side / FMath::Max(1, StopEps.Num()), SideNoBrake, SideDown, 100.0 * SideDown / FMath::Max(1, SideNoBrake), Front, FrontNoBrake, FrontDown, 100.0 * FrontDown / FMath::Max(1, FrontNoBrake)));
	}
	TestTrue(TEXT("the trace ran"), Matches > 0);
	return true;
}

// Lane A163: the stop tucks the puck (game.stick.stop_grace_frames), staged, in the gate. The carrier picks the puck up at rest, skates +x until it moves at
// AtSpeed, then reverses its input; a defender stands 2.6 m ahead inside its front arc (no body shield: only a grace can refuse that stick).
namespace JamCarryTests
{
	struct FStop { int32 Grace = -1, GraceFrames = 0; double Speed = 0; bool bRefused = false; };
	FStop StopScene(const FJamGameConfig& G, bool bHumanCarries, double AtSpeed)
	{
		FStop R;
		UJamSim* Sim = NewObject<UJamSim>();
		Sim->Init(G, 1);
		Sim->SkipFaceoff();
		const int32 Me = Sim->GetHumanIndex();
		int32 Opp = -1;
		for (const FJamSkaterState& K : Sim->GetSkaters()) if (K.Team != Sim->GetSkaters()[Me].Team) { Opp = K.Index; break; }
		const int32 Car = bHumanCarries ? Me : Opp, Def = bHumanCarries ? Opp : Me;
		const int32 N = Sim->GetSkaters().Num();
		for (int32 i = 0; i < N; ++i) Sim->SetSkater(i, FVector2D(-40.0 + i * 1.5, 19.0), FVector2D::ZeroVector, 0);
		Sim->SetSkater(Car, FVector2D(-20.0, 0.0), FVector2D::ZeroVector, 0);
		Sim->SetPuck(FVector2D(-19.55, 0.0), FVector2D::ZeroVector);
		TArray<FJamInput> In;
		In.SetNum(N);
		In[Car].Stick = FVector2D(1.0, 0.0);
		for (int32 i = 0; i < 8; ++i) Sim->Step(In);
		In[Car].Move = FVector2D(1.0, 0.0);
		int32 Guard = 0;
		while (Sim->GetSkaters()[Car].Vel.Size() < AtSpeed && Guard++ < 240) Sim->Step(In);
		if (Sim->CarrierIndex() != Car || Guard >= 240) return R;
		R.Speed = Sim->GetSkaters()[Car].Vel.Size();
		Sim->SetSkater(Def, Sim->GetSkaters()[Car].Pos + FVector2D(2.6, 0.0), FVector2D::ZeroVector, UE_DOUBLE_PI);
		In[Car].Move = FVector2D(-1.0, 0.0);
		Sim->Step(In);
		if (!Sim->GetSkaters()[Car].bReverseBraking) return R;
		R.Grace = Sim->GetSkaters()[Car].TakeGraceLeft;
		R.bRefused = Sim->IsPokeShielded(Sim->GetSkaters()[Def], Sim->GetSkaters()[Car]);
		for (int32 F = 0; F < 200 && Sim->InTakeGrace(Sim->GetSkaters()[Car]); ++F) { ++R.GraceFrames; Sim->Step(In); }
		return R;
	}
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamMovementStopGrace, "Jam.Core.Movement.StopGrace", JamCarryTests::Flags)
bool FJamMovementStopGrace::RunTest(const FString& Parameters)
{
	using namespace JamCarryTests;
	TArray<FString> Errors;
	UJamCartridge* C = UJamCartridge::LoadFromFile(UJamCartridge::ResolveCartridgePath(TEXT("hockey.regular")), Errors);
	for (const FString& E : Errors) AddError(E);
	if (!C) return false;
	C->Game.Stick.PickupArcM = 0.0; C->Game.Stick.bPickupBody = false;   // lane A208: re-staged at game.stick.pickup's neutral: this scene measures the stop's grace against a poke; the loose puck's pickup has its own (Jam.Core.Possession.*)
	TestEqual(TEXT("game.stick.stop_grace_frames is 0 when the key is absent: the rule ships at its neutral value"), C->Game.Stick.StopGraceFrames, 0);
	TestFalse(TEXT("... and the measurement's arm is off"), C->Game.Stick.bStopGraceBots);
	const int32 N = 30;
	{
		FJamGameConfig G = C->Game;
		G.Stick.StopGraceFrames = 0;
		const FStop R = StopScene(G, true, 8.0);
		TestTrue(TEXT("the scene stages: the human carries at 8 m/s and its reverse brake begins"), R.Grace >= 0 && R.Speed >= 8.0);
		TestEqual(TEXT("key 0 (neutral): the stop earns no grace"), R.Grace, 0);
		TestFalse(TEXT("key 0: the defender's stick is not refused"), R.bRefused);
	}
	{
		FJamGameConfig G = C->Game;
		G.Stick.StopGraceFrames = N;
		const FStop R = StopScene(G, true, 8.0);
		TestEqual(TEXT("key 30: a person's stop begun with the puck at 8 m/s gives its puck the grace"), R.Grace, N);
		TestTrue(TEXT("key 30: the defender's stick is refused on the stop's first frame"), R.bRefused);
		TestEqual(TEXT("key 30: the grace runs stop_grace_frames frames"), R.GraceFrames, N);
		AddInfo(FString::Printf(TEXT("STOPGRACE key %d: the stop began at %.2f m/s, grace %d as its first frame ended, %d frames in the grace"), N, R.Speed, R.Grace, R.GraceFrames));
		const FStop Slow = StopScene(G, true, 4.0);
		TestTrue(TEXT("the slow scene stages under StopGraceMinMps"), Slow.Grace >= 0 && Slow.Speed < UJamSim::StopGraceMinMps);
		TestEqual(TEXT("key 30: a reverse begun under 6 m/s earns nothing (a shuffle on the spot is not a stop)"), Slow.Grace, 0);
		const FStop Bot = StopScene(G, false, 8.0);
		TestTrue(TEXT("the bot scene stages"), Bot.Grace >= 0);
		TestEqual(TEXT("key 30: a bot carrier's stop earns nothing (a person's rule)"), Bot.Grace, 0);
		G.Stick.bStopGraceBots = true;
		TestEqual(TEXT("... and with the measurement's arm it does"), StopScene(G, false, 8.0).Grace, N);
		G.Stick.bStopGraceBots = false;
		G.Stick.TakeGraceFrames = 0;
		TestEqual(TEXT("take_grace_frames 0: no grace of any kind, the stop's neither"), StopScene(G, true, 8.0).Grace, 0);
	}
	// In a match: the key at 0 is the cartridge as it ships, hash for hash; the key on is another match. No constant: the hashes are compared with each other.
	{
		uint64 H[3] = {};
		for (int32 Arm = 0; Arm < 3; ++Arm)
		{
			UJamCartridge* M = DuplicateObject<UJamCartridge>(C, GetTransientPackage());
			if (Arm == 1) M->Game.Stick.StopGraceFrames = 0;
			if (Arm == 2) M->Game.Stick.StopGraceFrames = N;
			JamAI::FJamSimAdapter Sim(*M);
			const JamAI::FJamMatchConfig Cfg = JamAI::ToMatchConfigResolved(*M, TEXT("pro"));
			H[Arm] = JamAI::RunPlaytestMatch(Sim, Cfg, 3, JamAI::EPlaytester::Regular, 7200, M->Game.Shot.ChargeFramesMax).Hash;
		}
		TestTrue(TEXT("pro seed 3: the key at 0 is the shipped cartridge's match"), H[0] == H[1]);
		// Lane A185 (R-0064 point 2): with the free skaters 15 % faster seed 3 may no longer hold a stop that the key changes; the next seeds are asked until one does.
		uint64 Live = H[2];
		int32 LiveSeed = 3;
		for (int32 Sd = 4; Sd <= 12 && Live == H[0]; ++Sd)
		{
			uint64 Hs[2] = {};
			for (int32 Arm = 0; Arm < 2; ++Arm)
			{
				UJamCartridge* M = DuplicateObject<UJamCartridge>(C, GetTransientPackage());
				if (Arm == 1) M->Game.Stick.StopGraceFrames = N;
				JamAI::FJamSimAdapter Sim(*M);
				const JamAI::FJamMatchConfig Cfg = JamAI::ToMatchConfigResolved(*M, TEXT("pro"));
				Hs[Arm] = JamAI::RunPlaytestMatch(Sim, Cfg, Sd, JamAI::EPlaytester::Regular, 7200, M->Game.Shot.ChargeFramesMax).Hash;
			}
			if (Hs[0] != Hs[1]) { Live = Hs[1]; LiveSeed = Sd; break; }
		}
		AddInfo(FString::Printf(TEXT("STOPGRACE the key at 30 is live on pro seed %d"), LiveSeed));
		TestTrue(*FString::Printf(TEXT("pro: the key at 30 is another match (the rule is live in a match; seed %d)"), LiveSeed), Live != H[0] || LiveSeed != 3);
		AddInfo(FString::Printf(TEXT("STOPGRACE match pro seed 3, 7200 frames: shipped %016llx, key 0 %016llx, key 30 %016llx"), static_cast<unsigned long long>(H[0]), static_cast<unsigned long long>(H[1]), static_cast<unsigned long long>(H[2])));
	}
	return true;
}

// Lane A178: what is shown is not the rule frame by frame (JamCarrierMarks::StepShow), in the gate: no sim, the state alone.
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamMovementMarkShow, "Jam.Core.Movement.MarkShow", JamCarryTests::Flags)
bool FJamMovementMarkShow::RunTest(const FString& Parameters)
{
	using namespace JamCarrierMarks;
	const FShowRule K;
	TestTrue(TEXT("the least time on screen is 24 frames and a gap of 12 does not end a showing"), K.MinFrames == 24 && K.LingerFrames == 12);
	// The rule says yes for ONE frame: the mark stands 24.
	{
		FMarkShow S;
		int32 Shown = 0;
		for (int64 F = 100; F < 200; ++F) if (StepShow(S, F == 100, 5, F)) ++Shown;
		TestEqual(TEXT("one frame of the rule: 24 frames on screen"), Shown, 24);
		TestEqual(TEXT("... one showing, and it remembers who was coming"), S.Showings == 1 ? S.Opp : -1, 5);
	}
	// A flicker (on 5, off 8, on 5): one showing, on screen from the first yes to 12 frames after the last, 24 at least.
	{
		FMarkShow S;
		int32 Shown = 0;
		for (int64 F = 0; F < 100; ++F) if (StepShow(S, F < 5 || (F >= 13 && F < 18), 3, F)) ++Shown;
		TestEqual(TEXT("a flicker is one showing"), S.Showings, 1);
		TestEqual(TEXT("... on screen from frame 0 to frame 17 + 12"), Shown, 30);
	}
	// A long yes: shown while the rule holds and 12 frames more; then a new yes two seconds later is a second showing.
	{
		FMarkShow S;
		int32 Shown = 0;
		for (int64 F = 0; F < 300; ++F) if (StepShow(S, F < 60 || F == 200, 3, F)) ++Shown;
		TestEqual(TEXT("60 frames of the rule: 72 on screen; a yes at frame 200: 24 more"), Shown, 72 + 24);
		TestEqual(TEXT("... two showings"), S.Showings, 2);
	}
	// The clock goes back (a restart): the state starts again.
	{
		FMarkShow S;
		StepShow(S, true, 3, 5000);
		TestFalse(TEXT("a restart: nothing shown at frame 10 from a showing of frame 5000"), StepShow(S, false, -1, 10));
	}
	// The package's screen again: MinFrames 1 and no linger is the rule frame by frame.
	{
		FShowRule Raw; Raw.MinFrames = 1; Raw.LingerFrames = 0;
		FMarkShow S;
		int32 Shown = 0;
		for (int64 F = 0; F < 50; ++F) if (StepShow(S, F == 3 || F == 4 || F == 9, 3, F, Raw)) ++Shown;
		TestEqual(TEXT("minshow 1, linger 0: shown exactly while the rule says yes"), Shown, 3);
		TestEqual(TEXT("... and a gap is a new showing"), S.Showings, 2);
	}
	return true;
}

// Lane A166: the two marks' rules in staged scenes (the gate). No match, no statistic: the rule says yes where the picture is the one it was written for.
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamMovementMarks, "Jam.Core.Movement.Marks", JamCarryTests::Flags)
bool FJamMovementMarks::RunTest(const FString& Parameters)
{
	using namespace JamCarryTests;
	TArray<FString> Errors;
	UJamCartridge* C = UJamCartridge::LoadFromFile(UJamCartridge::ResolveCartridgePath(TEXT("hockey.regular")), Errors);
	for (const FString& E : Errors) AddError(E);
	if (!C) return false;
	// The contested puck: the puck lies at the origin, the human and an opponent skate at it from 6 m on either side.
	{
		UJamSim* Sim = NewObject<UJamSim>();
		Sim->Init(C->Game, 1);
		Sim->SkipFaceoff();
		const int32 Me = Sim->GetHumanIndex();
		int32 Opp = -1, Mate = -1;
		for (const FJamSkaterState& K : Sim->GetSkaters()) { if (K.Team != Sim->GetSkaters()[Me].Team) { if (Opp < 0) Opp = K.Index; } else if (K.Index != Me && Mate < 0) Mate = K.Index; }
		const int32 N = Sim->GetSkaters().Num();
		auto Park = [&]() { for (int32 i = 0; i < N; ++i) Sim->SetSkater(i, FVector2D(-40.0 + i * 1.5, 19.0), FVector2D::ZeroVector, 0); Sim->SetPuck(FVector2D::ZeroVector, FVector2D::ZeroVector); };
		// Lane A171 (REVIEW-3 item 1): the rule is quiet for AfterDropFrames after a drop (SkipFaceoff is a drop). On the drop's own frame the staged
		// head-on is not contested; the scene below is staged once that second has passed.
		{
			Park();
			Sim->SetSkater(Me, FVector2D(-6.0, 0.0), FVector2D(8.0, 0.0), 0.0);
			Sim->SetSkater(Opp, FVector2D(6.0, 0.0), FVector2D(-8.0, 0.0), UE_DOUBLE_PI);
			JamCarrierMarks::FContestRule Quiet;
			Quiet.AfterDropFrames = 60;
			TestFalse(TEXT("head-on for a loose puck in the second after a drop, with the quiet second on (AfterDropFrames 60): no ring"), JamCarrierMarks::Contested(*Sim, Me, Quiet).bOn);
			TestTrue(TEXT("the shipped rule has no quiet second (at pro the draw is where he is flattened)"), JamCarrierMarks::FContestRule().AfterDropFrames == 0);
			JamCarrierMarks::FContestRule NoWait;
			NoWait.AfterDropFrames = 0;
			TestTrue(TEXT("... the same scene with AfterDropFrames 0: contested, as before"), JamCarrierMarks::Contested(*Sim, Me, NoWait).bOn);
			Park();
			TArray<FJamInput> Idle;
			Idle.SetNum(N);
			for (int32 i = 0; i < Quiet.AfterDropFrames; ++i) Sim->Step(Idle);
			TestTrue(TEXT("a second after the drop the quiet rule is awake"), Sim->GetFrame() - Sim->GetDropFrame() >= Quiet.AfterDropFrames);
		}
		Park();
		TestTrue(TEXT("the staged puck is loose"), Sim->CarrierIndex() < 0);
		Sim->SetSkater(Me, FVector2D(-6.0, 0.0), FVector2D(8.0, 0.0), 0.0);
		Sim->SetSkater(Opp, FVector2D(6.0, 0.0), FVector2D(-8.0, 0.0), UE_DOUBLE_PI);
		const JamCarrierMarks::FContested A = JamCarrierMarks::Contested(*Sim, Me);
		TestTrue(TEXT("head-on for a loose puck, both 6 m off at 8 m/s: contested"), A.bOn && A.Opp == Opp);
		TestTrue(TEXT("... the human has it in about half a second (4.4 m at 8 m/s), the opponent too, closing at 16 m/s"), FMath::IsNearlyEqual(A.HumanSec, 0.55, 0.02) && FMath::IsNearlyEqual(A.OppSec, 0.55, 0.02) && FMath::IsNearlyEqual(A.ClosingMps, 16.0, 0.1));
		AddInfo(FString::Printf(TEXT("MARKS contested: human %.2f s, opponent %.2f s, closing %.1f m/s"), A.HumanSec, A.OppSec, A.ClosingMps));
		{
			// Lane A201 (evolution 12): the ring is about one man. A second opponent at the puck within OthersSec after the human: no ring (the scene of
			// MOVEMENT-12 section 9 where holding off costs the match); with the gate off (0) the ring of before.
			int32 Opp2 = -1;
			for (const FJamSkaterState& K : Sim->GetSkaters()) if (K.Team != Sim->GetSkaters()[Me].Team && K.Index != Opp) { Opp2 = K.Index; break; }
			if (Opp2 >= 0)
			{
				const FVector2D Park2 = Sim->GetSkaters()[Opp2].Pos;
				Sim->SetSkater(Opp2, FVector2D(0.0, 5.5), FVector2D(0.0, -8.0), -UE_DOUBLE_PI / 2.0);
				JamCarrierMarks::FContestRule Before; Before.OthersSec = 0.0;
				TestFalse(TEXT("A201: a second opponent at the puck with them: no ring (OthersSec 0.3 s)"), JamCarrierMarks::Contested(*Sim, Me).bOn);
				TestTrue(TEXT("A201: ... with the gate off (OthersSec 0): the ring of before"), JamCarrierMarks::Contested(*Sim, Me, Before).bOn);
				Sim->SetSkater(Opp2, Park2, FVector2D::ZeroVector, 0.0);
				TestTrue(TEXT("A201: ... and alone with the one man again: the ring"), JamCarrierMarks::Contested(*Sim, Me).bOn);
			}
			JamCarrierMarks::FContestRule Spec;
			JamCarrierMarks::ApplyContestRuleSpec(Spec, TEXT("others=0.4;opptoward=3;hsec=0.8"));
			TestTrue(TEXT("A201: the ring's parse (the one the trace and the scripted player share)"), Spec.OthersSec == 0.4 && Spec.OppTowardMps == 3.0 && Spec.HumanSecMax == 0.8);
			TestTrue(TEXT("A201: the shipped ring: the second opponent's gate 0.3 s, the man's own approach off"), JamCarrierMarks::FContestRule().OthersSec == 0.3 && JamCarrierMarks::FContestRule().OppTowardMps == 0.0);
		}
		Sim->SetSkater(Opp, FVector2D(6.0, 0.0), FVector2D(8.0, 0.0), 0.0);
		TestFalse(TEXT("the opponent skates away: not contested"), JamCarrierMarks::Contested(*Sim, Me).bOn);
		Sim->SetSkater(Opp, FVector2D(20.0, 0.0), FVector2D(-8.0, 0.0), UE_DOUBLE_PI);
		TestFalse(TEXT("the opponent is two seconds off: the puck is the human's, not contested"), JamCarrierMarks::Contested(*Sim, Me).bOn);
		Sim->SetSkater(Opp, FVector2D(2.5, 0.0), FVector2D(-8.0, 0.0), UE_DOUBLE_PI);
		TestFalse(TEXT("the opponent is there half a second before him: it is the opponent's puck (the human is the one who arrives second)"), JamCarrierMarks::Contested(*Sim, Me).bOn);
		Sim->SetSkater(Opp, FVector2D(-6.0, 3.0), FVector2D(8.0, -4.0), 0.0);
		TestFalse(TEXT("side by side for the same puck (no closing between the two): not contested"), JamCarrierMarks::Contested(*Sim, Me).bOn);
		Sim->SetSkater(Opp, FVector2D(6.0, 0.0), FVector2D(-8.0, 0.0), UE_DOUBLE_PI);
		Sim->SetSkater(Me, FVector2D(-6.0, 0.0), FVector2D::ZeroVector, 0.0);
		TestFalse(TEXT("the human stands: not contested (he is not going for it)"), JamCarrierMarks::Contested(*Sim, Me).bOn);
		if (Mate >= 0)
		{
			Sim->SetSkater(Me, FVector2D(-6.0, 0.0), FVector2D(8.0, 0.0), 0.0);
			Sim->SetSkater(Opp, FVector2D(-40.0, 19.0), FVector2D::ZeroVector, 0.0);
			Sim->SetSkater(Mate, FVector2D(6.0, 0.0), FVector2D(-8.0, 0.0), UE_DOUBLE_PI);
			TestFalse(TEXT("a mate skates at the same puck: not contested"), JamCarrierMarks::Contested(*Sim, Me).bOn);
		}
	}
	// The stop's distance: the human carries at 8 m/s along +x; a defender stands ahead and skates at him at 5 m/s.
	{
		UJamSim* Sim = NewObject<UJamSim>();
		Sim->Init(C->Game, 1);
		Sim->SkipFaceoff();
		const int32 Me = Sim->GetHumanIndex();
		int32 Opp = -1;
		for (const FJamSkaterState& K : Sim->GetSkaters()) if (K.Team != Sim->GetSkaters()[Me].Team) { Opp = K.Index; break; }
		const int32 N = Sim->GetSkaters().Num();
		for (int32 i = 0; i < N; ++i) Sim->SetSkater(i, FVector2D(-40.0 + i * 1.5, 19.0), FVector2D::ZeroVector, 0);
		Sim->SetSkater(Me, FVector2D(-25.0, 0.0), FVector2D::ZeroVector, 0);
		Sim->SetPuck(FVector2D(-24.55, 0.0), FVector2D::ZeroVector);
		TArray<FJamInput> In;
		In.SetNum(N);
		In[Me].Stick = FVector2D(1.0, 0.0);
		for (int32 i = 0; i < 8; ++i) Sim->Step(In);
		In[Me].Move = FVector2D(1.0, 0.0);
		int32 Guard = 0;
		while (Sim->GetSkaters()[Me].Vel.Size() < 8.0 && Guard++ < 240) Sim->Step(In);
		TestTrue(TEXT("the scene stages: the human carries at 8 m/s"), Sim->CarrierIndex() == Me && Sim->GetSkaters()[Me].Vel.Size() >= 8.0);
		const FVector2D HP = Sim->GetSkaters()[Me].Pos;
		// Lane A201: the window's scenes read the one-opponent rule (the gates off: the others stand parked about 18 m off, inside the own-half gate's 1.5 s);
		// the gates have their own scenes below.
		JamCarrierMarks::FStopRule Window;
		Window.SecondSec = 0.0; Window.SlotM = 0.0; Window.BoardRoomM = 0.0; Window.OwnHalfSecondSec = 0.0;
		auto At = [&](double Dx, double Dy, double Vx) { Sim->SetSkater(Opp, HP + FVector2D(Dx, Dy), FVector2D(Vx, 0.0), UE_DOUBLE_PI); return JamCarrierMarks::StopMark(*Sim, Me, Window); };
		TestFalse(TEXT("nobody ahead: no mark"), JamCarrierMarks::StopMark(*Sim, Me).bShow);
		const JamCarrierMarks::FStopMark Far = At(15.0, 0.0, -5.0);
		TestTrue(TEXT("a closing defender 15 m ahead: the mark is armed, not lit"), Far.bShow && !Far.bLit && Far.Def == Opp);
		TestTrue(TEXT("... and stands five stick lengths (8.5 m, lane A194) from the human, towards him"), FMath::IsNearlyEqual(FVector2D::Distance(Far.At, HP), 8.5, 0.01) && Far.At.X > HP.X);
		const JamCarrierMarks::FStopMark Lit = At(10.0, 0.0, -5.0);
		TestTrue(TEXT("the defender 10 m ahead closing at 13 m/s: lit (the stop passes from 9.5 m to 7 m, plus the hand's lead)"), Lit.bShow && Lit.bLit);
		TestTrue(TEXT("the defender 12 m ahead closing at 13 m/s: lit already (a quarter second of lead for the hand: 9 m + 3.25 m; lane A185: the far edge 9.5 -> 9 m)"), At(12.0, 0.0, -5.0).bLit);
		TestFalse(TEXT("the defender 13.5 m ahead closing at 13 m/s: armed, not yet lit (REVIEW-3: a stop begun out there loses the feet at pro and at all_star)"), At(13.5, 0.0, -5.0).bLit);
		TestFalse(TEXT("the defender 13.5 m ahead standing still (closing at 8 m/s: 9 m + 2 m): armed, not yet lit"), At(13.5, 0.0, 0.0).bLit);
		TestTrue(TEXT("the defender 7.75 m ahead: still lit"), At(7.75, 0.0, -5.0).bLit);
		TestFalse(TEXT("A201 (evolution 12): the defender 7.25 m ahead: gone (the bar goes out at 7.5 m: a press begun later loses the feet)"), At(7.25, 0.0, -5.0).bShow);
		TestFalse(TEXT("the defender 6 m ahead: gone (a stop begun here loses the feet)"), At(6.0, 0.0, -5.0).bShow);
		TestFalse(TEXT("the defender 10 m to the side of his travel: no mark"), At(0.0, 10.0, 0.0).bShow);
		TestFalse(TEXT("the defender 10 m behind: no mark"), At(-10.0, 0.0, 12.0).bShow);
		TestFalse(TEXT("the defender 10 m ahead skating away faster than the human: no mark (nothing closes)"), At(10.0, 0.0, 12.0).bShow);
		AddInfo(FString::Printf(TEXT("MARKS stop: armed at %.1f m (closing %.1f m/s), lit at %.1f m"), Far.DistM, Far.ClosingMps, Lit.DistM));
		// Lane A178: armed from the moment he carries at an opponent ahead (the two closing at 2 m/s or more); lit keeps its 8 m/s.
		const JamCarrierMarks::FStopMark Slow = At(8.0, 0.0, 5.0);
		TestTrue(TEXT("the defender 8 m ahead backing off at 5 m/s (closing at 3): the pale line is there, not lit"), Slow.bShow && !Slow.bLit);
		const JamCarrierMarks::FStopMark Wide = At(8.0, 8.0, -5.0);
		TestTrue(TEXT("the defender 45 degrees off his travel: the mark knows the angle, and its place across his path is straight ahead of him"),
			Wide.bShow && FMath::IsNearlyEqual(Wide.OffDeg, 45.0, 1.0) && FMath::IsNearlyEqual(Wide.AtPath.Y, HP.Y, 0.01) && FMath::IsNearlyEqual(Wide.AtPath.X - HP.X, 8.5, 0.01) && Wide.At.Y > HP.Y + 1.0);
		// Lane A201 (track F2 evolution 11, MOVEMENT-12.md): the gates keep the line pale where the stop does not pay. Each is read with its own number
		// here, so the scenes hold whatever the shipped numbers are; the shipped rule's own scenes follow.
		{
			int32 Opp2 = -1;
			for (const FJamSkaterState& K : Sim->GetSkaters()) if (K.Team != Sim->GetSkaters()[Me].Team && K.Index != Opp) { Opp2 = K.Index; break; }
			const FVector2D Park2 = Opp2 >= 0 ? Sim->GetSkaters()[Opp2].Pos : FVector2D::ZeroVector;
			JamCarrierMarks::FStopRule Off;   // every gate off: lane A194's line
			Off.SecondSec = 0.0; Off.SlotM = 0.0; Off.BoardRoomM = 0.0; Off.OwnHalfSecondSec = 0.0;
			JamCarrierMarks::FStopRule Two = Off;
			Two.SecondSec = 0.5;
			Sim->SetSkater(Opp, HP + FVector2D(10.0, 0.0), FVector2D(-5.0, 0.0), UE_DOUBLE_PI);
			const JamCarrierMarks::FStopMark Solo = JamCarrierMarks::StopMark(*Sim, Me, Two);
			const double V = Sim->GetSkaters()[Me].Vel.Size();
			const double Decel = C->Game.Skater.ReverseBrakeDecel * C->Game.Skater.CarryReverseBrakeMult;
			TestTrue(TEXT("A201: the stopping point lies on his travel where his reverse brake ends (v^2 / 2a)"), FMath::IsNearlyEqual(FVector2D::Distance(Solo.StopAt, HP), V * V / (2.0 * Decel), 0.01) && Solo.StopAt.X > HP.X);
			TestTrue(FString::Printf(TEXT("A201: one opponent closing, the others parked far off: lit, no gate (the second man %.2f s from the stopping point)"), Solo.SecondSec), Solo.bLit && Solo.bRawLit && Solo.Gate == 0 && Solo.SecondSec > 0.5);
			if (Opp2 >= 0)
			{
				Sim->SetSkater(Opp2, Solo.StopAt + FVector2D(0.0, 3.0), FVector2D::ZeroVector, 0);
				const JamCarrierMarks::FStopMark Crowd = JamCarrierMarks::StopMark(*Sim, Me, Two);
				TestTrue(FString::Printf(TEXT("A201: a second opponent 3 m from the stopping point (%.2f s at a free skater's speed): pale, the second man's gate"), Crowd.SecondSec),
					Crowd.bShow && !Crowd.bLit && Crowd.bRawLit && Crowd.Gate == 1 && Crowd.SecondOpp == Opp2 && Crowd.Def == Opp);
				TestTrue(TEXT("A201: ... and with the gates off it is lit as lane A194's line was"), JamCarrierMarks::StopMark(*Sim, Me, Off).bLit);
				Sim->SetSkater(Opp2, Park2, FVector2D::ZeroVector, 0);
			}
			JamCarrierMarks::FStopRule Slot = Off; Slot.SlotM = Solo.NetM + 1.0;
			TestTrue(TEXT("A201: inside the slot's distance of the net he attacks: pale (gate 2)"), JamCarrierMarks::StopMark(*Sim, Me, Slot).Gate == 2 && !JamCarrierMarks::StopMark(*Sim, Me, Slot).bLit);
			JamCarrierMarks::FStopRule Own = Off; Own.OwnHalfSecondSec = Solo.SecondSec + 0.5;
			const bool bOwnHalf = Solo.NetM >= Sim->GoalLineX();
			TestTrue(FString::Printf(TEXT("A201: in his own half (%d: %.1f m from the net he attacks, the centre line at %.1f) with the second man nearer than the own-half time: pale (gate 4); in the other half the gate does not apply"),
				bOwnHalf ? 1 : 0, Solo.NetM, Sim->GoalLineX()), bOwnHalf ? (JamCarrierMarks::StopMark(*Sim, Me, Own).Gate == 4 && !JamCarrierMarks::StopMark(*Sim, Me, Own).bLit) : JamCarrierMarks::StopMark(*Sim, Me, Own).bLit);
			Own.OwnHalfSecondSec = FMath::Max(0.01, Solo.SecondSec - 0.5);
			TestTrue(TEXT("A201: ... and alone with his man (the second man farther than the own-half time): lit, as drill 21 is"), JamCarrierMarks::StopMark(*Sim, Me, Own).bLit);
			JamCarrierMarks::FStopRule Wall = Off; Wall.BoardRoomM = Solo.BoardM + 1.0;
			TestTrue(TEXT("A201: the stopping point closer to the boards than the room asked: pale (gate 3)"), JamCarrierMarks::StopMark(*Sim, Me, Wall).Gate == 3 && !JamCarrierMarks::StopMark(*Sim, Me, Wall).bLit);
			JamCarrierMarks::FStopRule Spec;
			JamCarrierMarks::ApplyStopRuleSpec(Spec, TEXT("second=0.7;slot=11;own=1.5;boards=1.5;far=9.25"));
			TestTrue(TEXT("A201: the measurement's parse reads every gate by name (the one parse the HUD's rule, the trace and the scripted player share)"),
				Spec.SecondSec == 0.7 && Spec.SlotM == 11.0 && Spec.OwnHalfSecondSec == 1.5 && Spec.BoardRoomM == 1.5 && Spec.LitFarM == 9.25);
			// The shipped rule: the others parked at the far end (drill 21's scene: alone with his man), then one of them 3 m from the stopping point.
			const JamCarrierMarks::FStopRule Shipped;
			TArray<FVector2D> Parked;
			for (const FJamSkaterState& K : Sim->GetSkaters()) Parked.Add(K.Pos);
			for (const FJamSkaterState& K : Sim->GetSkaters()) if (K.Index != Me && K.Index != Opp) Sim->SetSkater(K.Index, FVector2D(35.0 + K.Index * 0.5, 19.0), FVector2D::ZeroVector, 0);
			const JamCarrierMarks::FStopMark Alone = JamCarrierMarks::StopMark(*Sim, Me, Shipped);
			TestTrue(FString::Printf(TEXT("A201: the shipped rule lights alone with his man (the second man %.2f s off, his own half %d)"), Alone.SecondSec, Alone.NetM >= Sim->GoalLineX() ? 1 : 0), Alone.bLit && Alone.Gate == 0);
			if (Opp2 >= 0)
			{
				Sim->SetSkater(Opp2, Alone.StopAt + FVector2D(0.0, 3.0), FVector2D::ZeroVector, 0);
				TestFalse(TEXT("A201: ... and keeps it pale with a second man 3 m from the stopping point"), JamCarrierMarks::StopMark(*Sim, Me, Shipped).bLit);
			}
			for (const FJamSkaterState& K : Sim->GetSkaters()) if (K.Index != Me && K.Index != Opp) Sim->SetSkater(K.Index, Parked[K.Index], FVector2D::ZeroVector, 0);
			AddInfo(FString::Printf(TEXT("MARKS stop A201: the stopping point %.2f m ahead at %.1f m/s, the second man %.2f s off, the net %.1f m, the boards %.1f m from the stopping point"),
				FVector2D::Distance(Solo.StopAt, HP), V, Solo.SecondSec, Solo.NetM, Solo.BoardM));
		}
		// he brakes: the mark has said what it had to say
		At(10.0, 0.0, -5.0);
		In[Me].Move = FVector2D(-1.0, 0.0);
		Sim->Step(In);
		Sim->SetSkater(Opp, Sim->GetSkaters()[Me].Pos + FVector2D(10.0, 0.0), FVector2D(-5.0, 0.0), UE_DOUBLE_PI);
		TestTrue(TEXT("the human reverses: the sim brakes"), Sim->GetSkaters()[Me].bReverseBraking);
		TestFalse(TEXT("... and the mark is gone while he brakes"), JamCarrierMarks::StopMark(*Sim, Me).bShow);
	}
	return true;
}

#endif
