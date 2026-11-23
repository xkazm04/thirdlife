#include "JamRuleSystem.h"

DEFINE_LOG_CATEGORY(LogJamRules);

namespace
{
	const FName SelScoring(TEXT("scoring"));
	const FName SelConceding(TEXT("conceding"));
	const FName SelAny(TEXT("any"));
	const FName DoShrink(TEXT("shrink_rink"));
	const FName DoGrow(TEXT("grow_rink"));
}

void UJamRuleSystem::Init(const FJamGameConfig& Config)
{
	Hooks = Config.Rules.Hooks;
	// Id order is the evaluation order (contracts/depth.md section 3; the brief). Stable so equal ids (rejected by the validator anyway) keep file order.
	Hooks.StableSort([](const FJamRuleHookConfig& A, const FJamRuleHookConfig& B) { return A.Id < B.Id; });
	for (const FJamRuleHookConfig& H : Hooks)
	{
		EJamRuleTrigger T;
		if (!JamRules::TriggerFromName(H.When, T)) UE_LOG(LogJamRules, Warning, TEXT("JAMRULES hook %s: unknown trigger %s (never fires)"), *H.Id, *H.When.ToString());
		for (const FJamRuleActionConfig& A : H.Then)
		{
			EJamRuleAction Act;
			if (!JamRules::ActionFromName(A.Do, Act)) UE_LOG(LogJamRules, Warning, TEXT("JAMRULES hook %s: unknown action %s (skipped)"), *H.Id, *A.Do.ToString());
		}
	}
	ResetMatch();
	UE_LOG(LogJamRules, Log, TEXT("JAMRULES %d hooks ready"), Hooks.Num());
}

void UJamRuleSystem::ResetMatch()
{
	FireCounts.Init(0, Hooks.Num());
	Scores[0] = Scores[1] = 0;
	TotalFires = 0;
	LastAnnouncement.Reset();
	LastAnnouncementFrame = -1;
	PendingAnnouncements.Reset();
}

void UJamRuleSystem::SetScore(int32 Team, int32 Score)
{
	if (Team == 0 || Team == 1) Scores[Team] = FMath::Max(0, Score);
}

int32 UJamRuleSystem::GetFireCount(const FString& HookId) const
{
	for (int32 i = 0; i < Hooks.Num(); ++i) if (Hooks[i].Id == HookId) return FireCounts.IsValidIndex(i) ? FireCounts[i] : 0;
	return 0;
}

int32 UJamRuleSystem::ResolveTeam(FName Selector, int32 EventTeam)
{
	if (Selector == SelScoring) return EventTeam;
	if (Selector == SelConceding) return (EventTeam == 0 || EventTeam == 1) ? 1 - EventTeam : -1;
	return -1;
}

bool UJamRuleSystem::ScoreMatches(const FJamRuleScoreCondition& C, int32 TeamScore, int32 OtherScore)
{
	if (!C.bHas) return true;
	if (C.AtLeast >= 0 && TeamScore < C.AtLeast) return false;
	if (C.AtMost >= 0 && TeamScore > C.AtMost) return false;
	if (C.LeadAtLeast >= 0 && TeamScore - OtherScore < C.LeadAtLeast) return false;
	return true;
}

float UJamRuleSystem::SeamValue(FName Do, bool bHasValue, double Value)
{
	if (!bHasValue) return 0.f;
	if (Do == DoShrink) return static_cast<float>(FMath::Clamp(1.0 - Value, 0.01, 1.0));
	if (Do == DoGrow) return static_cast<float>(FMath::Max(1.0, 1.0 + Value));
	return static_cast<float>(Value);
}

bool UJamRuleSystem::HookMatches(const FJamRuleHookConfig& H, const FJamRuleEventIn& In, int32& OutTeam) const
{
	EJamRuleTrigger T;
	if (!JamRules::TriggerFromName(H.When, T) || T != In.Trigger) return false;
	if (In.Frame < H.AfterFrame) return false;
	if (T == EJamRuleTrigger::OnFrame && (H.EveryFrames <= 0 || In.Frame % H.EveryFrames != 0)) return false;
	OutTeam = ResolveTeam(H.Team, In.Team);
	if (H.Score.bHas)
	{
		if (OutTeam == 0 || OutTeam == 1) return ScoreMatches(H.Score, Scores[OutTeam], Scores[1 - OutTeam]);
		// any: either team satisfies the condition.
		return ScoreMatches(H.Score, Scores[0], Scores[1]) || ScoreMatches(H.Score, Scores[1], Scores[0]);
	}
	return true;
}

void UJamRuleSystem::OnRuleEvent(const FJamRuleEventIn& In, TArray<FJamRuleActionOut>& Out)
{
	// Keep the score mirror current: OnGoal / OnScoreReached carry the scoring team's new score in Value (JamRuleHooks.h).
	if ((In.Trigger == EJamRuleTrigger::OnGoal || In.Trigger == EJamRuleTrigger::OnScoreReached) && (In.Team == 0 || In.Team == 1))
	{
		Scores[In.Team] = FMath::Max(0, FMath::RoundToInt32(In.Value));
	}
	for (int32 i = 0; i < Hooks.Num(); ++i)
	{
		const FJamRuleHookConfig& H = Hooks[i];
		int32 Team = -1;
		if (!HookMatches(H, In, Team)) continue;
		if (FireCounts.IsValidIndex(i)) ++FireCounts[i];
		++TotalFires;
		for (const FJamRuleActionConfig& A : H.Then)
		{
			FJamRuleActionOut O;
			if (!JamRules::ActionFromName(A.Do, O.Action)) continue;
			O.Team = A.Team.IsNone() ? Team : ResolveTeam(A.Team, In.Team);
			O.Value = SeamValue(A.Do, A.bHasValue, A.Value);
			O.Param = A.Param;
			O.Kind = A.Kind;
			O.Frames = A.Frames;
			O.Text = A.Text;
			if (O.Action == EJamRuleAction::AddScore && (O.Team == 0 || O.Team == 1)) Scores[O.Team] = FMath::Max(0, Scores[O.Team] + FMath::RoundToInt32(O.Value));
			if (O.Action == EJamRuleAction::Announce)
			{
				LastAnnouncement = O.Text;
				LastAnnouncementFrame = In.Frame;
				PendingAnnouncements.Add(O.Text);
			}
			Out.Add(MoveTemp(O));
		}
		UE_LOG(LogJamRules, Verbose, TEXT("JAMRULES fired %s at frame %d (%s team %d)"), *H.Id, In.Frame, JamRules::TriggerName(In.Trigger), Team);
	}
}

uint64 UJamRuleSystem::StateHash() const
{
	uint64 H = 1469598103934665603ull;
	auto Add = [&H](uint64 V) { for (int32 i = 0; i < 8; ++i) { H ^= (V >> (i * 8)) & 0xFF; H *= 1099511628211ull; } };
	Add(static_cast<uint64>(Scores[0]));
	Add(static_cast<uint64>(Scores[1]));
	Add(static_cast<uint64>(TotalFires));
	for (int32 C : FireCounts) Add(static_cast<uint64>(C));
	return H;
}
