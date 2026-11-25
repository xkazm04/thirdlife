// Lane T5 (item T5.a): see JamPassFate.h. Reads only.
#include "JamPassFate.h"

#include "JamSim.h"
#include "JamEventBus.h"

DEFINE_LOG_CATEGORY_STATIC(LogJamPass, Log, All);

void FJamPassFateCounts::Add(const FJamPassFateCounts& O)
{
	Passes += O.Passes; Logged += O.Logged; ToCalled += O.ToCalled; AimNone += O.AimNone; AimUnsolved += O.AimUnsolved; AimMiss += O.AimMiss; Previewed += O.Previewed; PreviewSame += O.PreviewSame;
	for (int32 c = 0; c < static_cast<int32>(EJamPassCause::Count); ++c) ByCause[c] += O.ByCause[c];
}

FString FJamPassFateCounts::Summary() const
{
	FString S = FString::Printf(TEXT("passes=%d logged=%d"), Passes, Logged);
	for (int32 c = 0; c < static_cast<int32>(EJamPassCause::Count); ++c)
	{
		S += FString::Printf(TEXT(" %s=%d(%.1f%%)"), FJamPassFateObserver::CauseName(static_cast<EJamPassCause>(c)), ByCause[c], 100.0 * Share(static_cast<EJamPassCause>(c)));
	}
	S += FString::Printf(TEXT(" to_called=%d aim_none=%d aim_unsolved=%d aim_miss=%d previewed=%d preview_same=%d"), ToCalled, AimNone, AimUnsolved, AimMiss, Previewed, PreviewSame);
	return S;
}

const TCHAR* FJamPassFateObserver::CauseName(EJamPassCause C)
{
	switch (C)
	{
	case EJamPassCause::Arrived: return TEXT("arrived");
	case EJamPassCause::Aim: return TEXT("aim");
	case EJamPassCause::Intercept: return TEXT("intercept");
	case EJamPassCause::Drift: return TEXT("drift");
	case EJamPassCause::OnPoint: return TEXT("on_point");
	default: return TEXT("?");
	}
}

void FJamPassFateObserver::ResetMatch()
{
	Open = FOpen();
	HeldPreviewTo = -2;
	PrevLastTouch = -1;
	bPrevPlaying = false;
}

namespace JamPassFateLocal
{
	double CatchRadius(const UJamSim& Sim)
	{
		const double C = Sim.GetConfig().Pass.CatchM;
		return C > 0.0 ? C : UJamSim::DeflectRangeM;   // without game.pass.catch_m a pass is taken in the blade's disc
	}
}

void FJamPassFateObserver::Release(const UJamSim& Sim, int32 Passer, int32 To, bool bSaucer)
{
	const TArray<FJamSkaterState>& Sk = Sim.GetSkaters();
	const FJamPuckState& P = Sim.GetPuck();
	Open = FOpen();
	Open.bOpen = true;
	Open.At = Sim.GetFrame();
	Open.From = Passer;
	Open.To = Sk.IsValidIndex(To) && To != Passer ? To : -1;
	Open.bHuman = Sk.IsValidIndex(Passer) && Sk[Passer].bHuman;
	Open.bSaucer = bSaucer;
	Open.Speed = P.Vel.Size();
	if (Open.To >= 0)
	{
		const FJamSkaterState& T = Sk[Open.To];
		Open.Blade0 = T.BladePos;
		Open.Vel0 = T.Vel;
		// The sim's own solver on the state after the release frame: the launched speed, his blade led on his velocity.
		FVector2D Aim; double V = 0.0, Arr = 0.0, Tf = 0.0;
		Open.bSolved = Sim.AimPassAt(Passer, Open.To, Open.Speed, Aim, V, Arr, Tf);
		Open.MeetAt = Aim;
		Open.MeetS = Tf;
		Open.MeetFrame = Open.At + FMath::Max<int64>(0, FMath::RoundToInt(Tf / UJamSim::DT));
		// Where the launched puck is when it has flown as far as the meeting point (the solver's distance; the launched direction).
		const FVector2D Dir = P.Vel.IsNearlyZero() ? FVector2D::ZeroVector : P.Vel.GetSafeNormal();
		const FVector2D PuckThere = P.Pos + Dir * FVector2D::Distance(P.Pos, Aim);
		Open.AimMissM = FVector2D::Distance(PuckThere, Aim);
	}
	if (Open.bHuman) ++Human.Passes; else ++Bot.Passes;
	if (Open.bHuman && HeldPreviewTo != -2) { Open.PreviewTo = HeldPreviewTo; ++Human.Previewed; if (HeldPreviewTo == Open.To) ++Human.PreviewSame; }
}

void FJamPassFateObserver::Close(const UJamSim& Sim, const TCHAR* Fate, int32 Taker)
{
	if (!Open.bOpen) return;
	using namespace JamPassFateLocal;
	const TArray<FJamSkaterState>& Sk = Sim.GetSkaters();
	const double Catch = CatchRadius(Sim);
	const int64 Now = Sim.GetFrame();
	const bool bMate = FCString::Strcmp(Fate, TEXT("mate")) == 0;
	const bool bOpp = FCString::Strcmp(Fate, TEXT("opp")) == 0;
	double Drift = Open.DriftM;
	if (Open.To >= 0 && Drift < 0.0 && Sk.IsValidIndex(Open.To))
	{
		const double T = static_cast<double>(Now - Open.At) * UJamSim::DT;
		Drift = FVector2D::Distance(Sk[Open.To].BladePos, Open.Blade0 + Open.Vel0 * T);
	}
	EJamPassCause Cause;
	if (bMate) Cause = EJamPassCause::Arrived;
	else if (Open.To < 0 || !Open.bSolved || Open.AimMissM >= Catch) Cause = EJamPassCause::Aim;
	else if (bOpp && Now <= Open.MeetFrame + 2) Cause = EJamPassCause::Intercept;
	else if (Drift >= Catch) Cause = EJamPassCause::Drift;
	else Cause = EJamPassCause::OnPoint;

	FJamPassFateCounts& C = Open.bHuman ? Human : Bot;
	++C.Logged;
	++C.ByCause[static_cast<int32>(Cause)];
	if (bMate && Taker == Open.To && Open.To >= 0) ++C.ToCalled;
	if (Cause == EJamPassCause::Aim) { if (Open.To < 0) ++C.AimNone; else if (!Open.bSolved) ++C.AimUnsolved; else ++C.AimMiss; }
	if (bLog)
	{
		UE_LOG(LogJamPass, Display, TEXT("JAMPASS %sf=%lld from=%d to=%d fate=%s cause=%s human=%d taker=%d frames=%lld meet_f=%lld solved=%d aim_miss_m=%.2f drift_m=%.2f miss_at_meet_m=%.2f speed=%.1f saucer=%d preview_to=%d"),
			*Tag, Open.At, Open.From, Open.To, Fate, CauseName(Cause), Open.bHuman ? 1 : 0, Taker, Now - Open.At, Open.MeetFrame - Open.At, Open.bSolved ? 1 : 0,
			Open.AimMissM, Drift, Open.MissAtMeetM, Open.Speed, Open.bSaucer ? 1 : 0, Open.PreviewTo);
	}
	Open.bOpen = false;
}

void FJamPassFateObserver::Observe(const UJamSim& Sim)
{
	const TArray<FJamSkaterState>& Sk = Sim.GetSkaters();
	const FJamPuckState& P = Sim.GetPuck();
	const int64 Now = Sim.GetFrame();
	const bool bPlaying = Sim.GetPhase() == EJamSimPhase::Playing;

	// 1. The solved meeting frame reached with the pass still on its way: where is the called receiver against the path he was led on?
	if (Open.bOpen && Open.To >= 0 && Open.DriftM < 0.0 && Now >= Open.MeetFrame && P.LastTouch == Open.From && Sk.IsValidIndex(Open.To))
	{
		Open.DriftM = FVector2D::Distance(Sk[Open.To].BladePos, Open.MeetAt);
		Open.MissAtMeetM = FVector2D::Distance(Sk[Open.To].BladePos, P.Pos);
	}
	// 2. Another skater touched it: the pass's fate (a mate who caught it and passes on in the same frame is closed first, then his pass opens).
	if (Open.bOpen && P.LastTouch >= 0 && P.LastTouch != Open.From && Sk.IsValidIndex(P.LastTouch) && Sk.IsValidIndex(Open.From))
	{
		Close(Sim, Sk[P.LastTouch].Team == Sk[Open.From].Team ? TEXT("mate") : TEXT("opp"), P.LastTouch);
	}
	// 3. The play stopped (a goal, out of play, the end) with the pass open.
	if (Open.bOpen && !bPlaying) Close(Sim, TEXT("dead"), -1);
	// 4. Nobody inside 180 frames (the sim's own flight length).
	if (Open.bOpen && Now - Open.At > UJamSim::PassFlightFrames) Close(Sim, TEXT("loose"), -1);
	// 5. Releases this frame (the passer playing the puck again first closes his own open pass).
	for (const FJamSkaterState& S : Sk)
	{
		if (Open.bOpen && S.Index == Open.From && (S.bPassThisFrame || S.bShotThisFrame)) Close(Sim, TEXT("self"), S.Index);
		if (!S.bPassThisFrame) continue;
		// A pass caught and passed on inside one frame by a skater after the passer in the step's order: he touched it first.
		if (Open.bOpen && Sk.IsValidIndex(Open.From)) Close(Sim, S.Team == Sk[Open.From].Team ? TEXT("mate") : TEXT("opp"), S.Index);
		int32 To = -1;
		bool bSaucer = false;
		for (const FJamSimEvent& E : Sim.GetFrameEvents())
		{
			if (E.Name != JamEvents::Pass || E.Who != S.Index) continue;
			const FString K = E.Kind.ToString();
			bSaucer = K.StartsWith(TEXT("saucer_"));
			int32 Ix = INDEX_NONE;
			if (K.FindLastChar(TEXT('_'), Ix)) To = FCString::Atoi(*K.Mid(Ix + 1));
		}
		Release(Sim, S.Index, To, bSaucer);
	}
	// The human's hold now (for his next release): the preview the power meter and the brain read.
	HeldPreviewTo = -2;
	const int32 Hi = Sim.GetHumanIndex();
	if (Sk.IsValidIndex(Hi) && Sk[Hi].PassChargeFrames > 0 && Sim.CarrierIndex() == Hi)
	{
		FVector2D Aim;
		HeldPreviewTo = Sim.HumanPassTarget(Hi, Sk[Hi].BladePos - Sk[Hi].Pos, Sk[Hi].PassChargeFrames, Aim);
	}
	PrevLastTouch = P.LastTouch;
	bPrevPlaying = bPlaying;
}

void FJamPassFateObserver::Finish(const UJamSim& Sim)
{
	if (Open.bOpen) Close(Sim, TEXT("dead"), -1);
}
