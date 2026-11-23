#include "JamEffectSystem.h"
#include "JamEventBus.h"
#include "JamZones.h"

DEFINE_LOG_CATEGORY(LogJamEffects);

namespace
{
	inline void Fnv(uint64& H, int64 V)
	{
		for (int i = 0; i < 8; ++i) { H ^= static_cast<uint8>(V >> (i * 8)); H *= 1099511628211ull; }
	}
	inline int64 Q(double V, double Scale) { return static_cast<int64>(FMath::RoundToDouble(V * Scale)); }
}

bool UJamEffectSystem::Init(UJamSim* InSim, const FString& RawCartridgeJson, TArray<FString>& OutErrors)
{
	Sim = InSim;
	if (!Sim) { OutErrors.Add(TEXT("at /: the effect system needs a sim.")); return false; }
	const bool bOk = FJamEffectsConfig::Parse(RawCartridgeJson, Config, OutErrors);
	for (const FString& E : OutErrors) UE_LOG(LogJamEffects, Error, TEXT("JAMEFFECTS %s"), *E);
	Sim->SetModifierSource(this);
	ResetState();
	UE_LOG(LogJamEffects, Log, TEXT("JAMEFFECTS init effects=%d pickups=%d zones=%d builtins=%d seed=%llu"), Config.Effects.Num(), Config.Pickups.Num(), Config.Zones.Num(),
		FJamEffectsConfig::Builtins().Num(), static_cast<unsigned long long>(Sim->GetSeed()));
	return bOk;
}

void UJamEffectSystem::Restart()
{
	if (!Sim) return;
	Sim->SetModifierSource(this);
	ResetState();
}

void UJamEffectSystem::ResetState()
{
	Active.Reset(); ActiveStart.Reset(); ActiveDuration.Reset();
	OnIce.Reset(); FrameEvents.Reset(); PendingEvents.Reset(); Hud.Reset();
	bInStep = false;
	Frame = Sim ? Sim->GetFrame() : 0;
	NextId = 1;
	EffectsStarted = PickupsTaken = PickupsSpawned = 0;
	Rng.Seed(Sim ? Sim->GetSeed() : 1, RngStream);
	LastScore[0] = Sim ? Sim->GetScore(0) : 0;
	LastScore[1] = Sim ? Sim->GetScore(1) : 0;
	LastPeriod = Sim ? Sim->GetPeriod() : 1;
	Timers.SetNum(Config.Pickups.Num());
	for (int32 i = 0; i < Timers.Num(); ++i) Timers[i].NextSpawnFrame = Frame + Config.Pickups[i].SpawnEveryFrames;
	// TAKE 1 starts now.
	Fire(EJamEffectTrigger::PeriodStart, -1, -1);
	ExpireAndRebuildHud();
}

bool UJamEffectSystem::ApplyLiveConfig(const FString& RawCartridgeJson)
{
	FJamEffectsConfig New;
	TArray<FString> Errors;
	FJamEffectsConfig::Parse(RawCartridgeJson, New, Errors);
	for (const FString& E : Errors) UE_LOG(LogJamEffects, Error, TEXT("JAMEFFECTS live %s"), *E);
	if (Errors.Num() && New.Effects.Num() == 0 && New.Pickups.Num() == 0) return false;
	const int32 OldCount = Config.Pickups.Num();
	Config = New;
	Timers.SetNum(Config.Pickups.Num());
	for (int32 i = OldCount; i < Timers.Num(); ++i) Timers[i].NextSpawnFrame = Frame + Config.Pickups[i].SpawnEveryFrames;
	OnIce.RemoveAll([this](const FJamPickupOnIce& P) { return P.PickupIndex >= Config.Pickups.Num() || Config.Find(P.Kind) == nullptr; });
	// The director is the human: self = the human's skater.
	const int32 Human = Sim ? Sim->GetHumanIndex() : -1;
	Fire(EJamEffectTrigger::Director, Human, TeamOf(Human));
	ExpireAndRebuildHud();
	UE_LOG(LogJamEffects, Log, TEXT("JAMEFFECTS live config effects=%d pickups=%d at frame %lld"), Config.Effects.Num(), Config.Pickups.Num(), Frame);
	return true;
}

int32 UJamEffectSystem::TeamOf(int32 Skater) const
{
	return (Sim && Sim->GetSkaters().IsValidIndex(Skater)) ? Sim->GetSkaters()[Skater].Team : -1;
}

FVector2D UJamEffectSystem::PosOf(int32 Skater) const
{
	return (Sim && Sim->GetSkaters().IsValidIndex(Skater)) ? Sim->GetSkaters()[Skater].Pos : FVector2D::ZeroVector;
}

void UJamEffectSystem::Emit(FName Name, int32 Who, const FVector2D& Where, float Strength, FName Kind)
{
	FJamSimEvent E;
	E.Name = Name; E.Who = Who; E.Where = Where; E.Strength = Strength; E.Kind = Kind; E.Frame = Frame;
	(bInStep ? FrameEvents : PendingEvents).Add(E);
}

void UJamEffectSystem::Step()
{
	if (!Sim) return;
	FrameEvents = MoveTemp(PendingEvents);
	PendingEvents.Reset();
	bInStep = true;
	Frame = Sim->GetFrame();

	// 1. Time runs out.
	for (int32 i = 0; i < Active.Num(); ++i) --Active[i].FramesLeft;

	// 2. Triggers from the frame the sim just ran.
	for (const FJamSimEvent& E : Sim->GetFrameEvents())
	{
		if (E.Name == JamEvents::Check) Fire(EJamEffectTrigger::CheckLanded, E.Who, TeamOf(E.Who));
		else if (E.Name == JamEvents::Knockdown && E.Kind == TEXT("check")) Fire(EJamEffectTrigger::CheckReceived, E.Who, TeamOf(E.Who));
	}
	// 2b. Zone triggers (lane A41). The sim never carries zone_enter / zone_exit: UJamZoneSystem computes membership after the sim's
	// step and keeps the events of that frame in its own list. The only IJamZoneSource is that system (R-0019), bound to the sim by
	// the host before Init, so its events are read from there. The puck's events (Who = PuckWho) fire puck / rink targets only.
	if (const IJamZoneSource* Src = Sim->GetZoneSource())
	{
		const UJamZoneSystem* Zones = static_cast<const UJamZoneSystem*>(Src);
		for (const FJamSimEvent& E : Zones->GetFrameEvents())
		{
			const bool bEnter = E.Name == JamEvents::ZoneEnter;
			if (!bEnter && E.Name != JamEvents::ZoneExit) continue;
			if (E.Frame != Frame) continue;   // a stale list (the host did not update the zones this frame) fires nothing
			Fire(bEnter ? EJamEffectTrigger::ZoneEnter : EJamEffectTrigger::ZoneExit, E.Who, TeamOf(E.Who), E.Kind);
		}
	}
	for (int32 T = 0; T < 2; ++T)
	{
		const int32 S = Sim->GetScore(T);
		if (S > LastScore[T])
		{
			int32 Scorer = -1;
			for (const FJamSimEvent& E : Sim->GetFrameEvents()) if (E.Name == JamEvents::Goal && TeamOf(E.Who) == T) Scorer = E.Who;
			Fire(EJamEffectTrigger::GoalFor, Scorer, T);
			Fire(EJamEffectTrigger::GoalAgainst, -1, 1 - T);
		}
		LastScore[T] = S;
	}
	if (Sim->GetPeriod() != LastPeriod)
	{
		LastPeriod = Sim->GetPeriod();
		Fire(EJamEffectTrigger::PeriodStart, -1, -1);
	}

	// 3. The rule system's requests (seam B actions routed to us by the sim).
	TArray<FJamRuleRequest> Requests;
	Sim->TakeModifierRequests(Requests);
	for (const FJamRuleRequest& R : Requests)
	{
		const int32 Team = R.Action.Team >= 0 ? R.Action.Team : R.Cause.Team;
		const bool bMag = R.Action.Value > 0.f;
		if (!RequestEffect(R.Action.Kind, R.Cause.Who, Team, R.Action.Frames, bMag, bMag ? R.Action.Value : 1.0))
			UE_LOG(LogJamEffects, Warning, TEXT("JAMEFFECTS rule apply_modifier names unknown effect \"%s\""), *R.Action.Kind.ToString());
	}
	Requests.Reset();
	Sim->TakePickupRequests(Requests);
	for (const FJamRuleRequest& R : Requests)
	{
		if (!SpawnPickup(R.Action.Kind, FVector2D(1e9, 1e9)))
			UE_LOG(LogJamEffects, Warning, TEXT("JAMEFFECTS rule spawn_pickup names unknown kind \"%s\""), *R.Action.Kind.ToString());
	}

	// 4. Pickups: spawn from the table, take on contact.
	StepPickups();

	// 5. Expiry events and the HUD rows.
	ExpireAndRebuildHud();
	bInStep = false;
}

void UJamEffectSystem::ExpireAndRebuildHud()
{
	for (int32 i = Active.Num() - 1; i >= 0; --i)
	{
		if (Active[i].FramesLeft <= 0)
		{
			const FJamActiveModifier& M = Active[i];
			const int32 Who = M.Target == EJamTarget::Self ? M.SourceSkater : -1;
			Emit(JamEffects::EffectEnd, Who, PosOf(Who), 0.f, M.Kind);
			Active.RemoveAt(i); ActiveStart.RemoveAt(i); ActiveDuration.RemoveAt(i);
		}
	}
	Hud.Reset();
	for (int32 i = 0; i < Active.Num(); ++i)
	{
		const FJamActiveModifier& M = Active[i];
		FJamEffectHudEntry H;
		H.Target = M.Target;
		H.Skater = M.Target == EJamTarget::Self ? M.SourceSkater : -1;
		const int32 SrcTeam = M.SourceSkater >= 0 ? TeamOf(M.SourceSkater) : M.Team;
		H.Team = (M.Target == EJamTarget::OwnTeam) ? SrcTeam : (M.Target == EJamTarget::OtherTeam && SrcTeam >= 0) ? 1 - SrcTeam : -1;
		H.EffectId = M.Kind;
		const FJamEffectDef* Def = Config.Find(M.Kind);
		H.Kind = Def ? Def->Kind : FName(TEXT("custom"));
		H.Icon = Def ? Def->Icon : JamEffects::DefaultIcon(H.Kind);
		H.FramesLeft = M.FramesLeft;
		H.DurationFrames = FMath::Max(1, ActiveDuration[i]);
		H.Colour = JamEffects::KindColour(H.Kind);
		Hud.Add(H);
	}
}

void UJamEffectSystem::CollectModifiers(int32 InFrame, TArray<FJamActiveModifier>& Out) const
{
	Out.Append(Active);
}

void UJamEffectSystem::Fire(EJamEffectTrigger Trigger, int32 SourceSkater, int32 Team, FName ZoneId)
{
	for (const FJamEffectDef& Def : Config.Effects)
	{
		if (Def.Trigger != Trigger) continue;
		if (Trigger == EJamEffectTrigger::ZoneEnter || Trigger == EJamEffectTrigger::ZoneExit)
		{
			if (!Def.Zone.IsNone() && Def.Zone != ZoneId) continue;
			// Who entered decides the reach: the puck's events fire puck / rink / everyone targets (self and the teams have nobody
			// to attach to); a skater's events fire self / own_team / other_team / everyone (the puck did not move onto the zone).
			const bool bPuckEvent = SourceSkater < 0;
			const bool bPuckTarget = Def.Target == EJamTarget::Puck || Def.Target == EJamTarget::Rink;
			if (bPuckEvent ? !(bPuckTarget || Def.Target == EJamTarget::Everyone) : bPuckTarget) continue;
		}
		Apply(Def, SourceSkater, Team, Def.DurationFrames, false, 1.0);
	}
}

bool UJamEffectSystem::RequestEffect(FName EffectId, int32 SourceSkater, int32 Team, int32 FramesOverride, bool bHasMagnitude, double Magnitude)
{
	const FJamEffectDef* Def = Config.Find(EffectId);
	if (!Def) return false;
	if (Team < 0) Team = TeamOf(SourceSkater);
	return Apply(*Def, SourceSkater, Team, FramesOverride > 0 ? FramesOverride : Def->DurationFrames, bHasMagnitude, Magnitude);
}

bool UJamEffectSystem::Apply(const FJamEffectDef& Def, int32 SourceSkater, int32 Team, int32 Frames, bool bHasMagnitude, double Magnitude)
{
	if (!Sim || Def.Stats.Num() == 0) return false;
	if (!Sim->GetSkaters().IsValidIndex(SourceSkater)) SourceSkater = -1;
	if (SourceSkater >= 0) Team = TeamOf(SourceSkater);
	EJamTarget Target = Def.Target;
	// Nobody caused it: the relative targets widen.
	if (SourceSkater < 0 && (Target == EJamTarget::Self)) Target = Team >= 0 ? EJamTarget::OwnTeam : EJamTarget::Everyone;
	if (Team < 0 && (Target == EJamTarget::OwnTeam || Target == EJamTarget::OtherTeam)) Target = EJamTarget::Everyone;
	Frames = FMath::Clamp(Frames, 1, JamEffects::MaxDurationFrames);
	const int32 AffectedTeam = Target == EJamTarget::OwnTeam ? Team : Target == EJamTarget::OtherTeam ? 1 - Team : -1;
	const int32 Key = Target == EJamTarget::Self ? SourceSkater : AffectedTeam;

	// Stack policy against the same effect on the same target.
	for (int32 i = 0; i < Active.Num(); ++i)
	{
		FJamActiveModifier& M = Active[i];
		if (M.Kind != Def.Id || M.Target != Target) continue;
		const int32 MTeam = M.SourceSkater >= 0 ? TeamOf(M.SourceSkater) : M.Team;
		const int32 MKey = Target == EJamTarget::Self ? M.SourceSkater : Target == EJamTarget::OwnTeam ? MTeam : Target == EJamTarget::OtherTeam ? 1 - MTeam : -1;
		if (MKey != Key) continue;
		switch (Def.Stack)
		{
		case EJamEffectStack::Refresh: M.FramesLeft = Frames; ActiveDuration[i] = Frames; break;
		case EJamEffectStack::Extend: M.FramesLeft = FMath::Min(M.FramesLeft + Frames, JamEffects::MaxDurationFrames); ActiveDuration[i] = FMath::Max(ActiveDuration[i], M.FramesLeft); break;
		case EJamEffectStack::Ignore: break;
		}
		return true;
	}

	FJamActiveModifier M;
	M.Id = NextId++;
	M.Target = Target;
	M.SourceSkater = SourceSkater;
	M.Team = Team;
	M.FramesLeft = Frames;
	M.Kind = Def.Id;
	Def.BuildStats(bHasMagnitude, Magnitude, M.Stats);
	Active.Add(M);
	ActiveStart.Add(Frame);
	ActiveDuration.Add(Frames);
	++EffectsStarted;
	const int32 Who = Target == EJamTarget::Self ? SourceSkater : -1;
	Emit(JamEffects::EffectStart, Who, PosOf(SourceSkater), 0.f, Def.Id);
	return true;
}

bool UJamEffectSystem::PickSpot(const FJamPickupDef* Def, FVector2D& Out)
{
	if (!Sim) return false;
	const FJamRinkConfig& R = Sim->GetConfig().Rink;
	const FJamZoneDef* Zone = Def && !Def->Zone.IsNone() ? Config.FindZone(Def->Zone) : nullptr;
	double MinX = -R.LengthM * 0.5 + PickupBoardMarginM, MaxX = -MinX, MinZ = -R.WidthM * 0.5 + PickupBoardMarginM, MaxZ = -MinZ;
	if (Zone)
	{
		const double Hx = Zone->bCircle ? Zone->R : Zone->W * 0.5, Hz = Zone->bCircle ? Zone->R : Zone->D * 0.5;
		MinX = FMath::Max(MinX, Zone->X - Hx); MaxX = FMath::Min(MaxX, Zone->X + Hx);
		MinZ = FMath::Max(MinZ, Zone->Z - Hz); MaxZ = FMath::Min(MaxZ, Zone->Z + Hz);
	}
	// Up to 16 seeded tries inside the boards (and the zone), out of the net mouths; the last try stands even if it is poor.
	for (int32 Try = 0; Try < 16; ++Try)
	{
		const FVector2D P(Rng.Range(MinX, MaxX), Rng.Range(MinZ, MaxZ));
		FVector2D N;
		const bool bInside = Sim->BoardDistance(P, N) < -PickupBoardMarginM + 0.5;
		const bool bInZone = !Zone || Zone->Contains(P);
		const bool bOffNets = FMath::Abs(P.X) < R.GoalLineX() - 1.0 || FMath::Abs(P.Y) > R.GoalWidthM;
		Out = P;
		if (bInside && bInZone && bOffNets) return true;
	}
	return true;
}

bool UJamEffectSystem::SpawnPickup(FName Kind, FVector2D Pos, int32 PickupIndex)
{
	if (!Sim || !Config.Find(Kind)) return false;
	if (PickupIndex < 0) for (int32 i = 0; i < Config.Pickups.Num(); ++i) if (Config.Pickups[i].Kind == Kind) { PickupIndex = i; break; }
	FVector2D N;
	if (Sim->BoardDistance(Pos, N) >= 0.0) PickSpot(Config.Pickups.IsValidIndex(PickupIndex) ? &Config.Pickups[PickupIndex] : nullptr, Pos);
	FJamPickupOnIce P;
	P.Id = NextId++;
	P.PickupIndex = PickupIndex;
	P.Kind = Kind;
	P.Pos = Pos;
	P.SpawnFrame = Frame;
	OnIce.Add(P);
	++PickupsSpawned;
	Emit(JamEvents::PickupSpawn, -1, Pos, 0.f, Kind);
	return true;
}

void UJamEffectSystem::StepPickups()
{
	if (Sim->GetPhase() != EJamSimPhase::Playing) return;
	// Spawns, table order.
	for (int32 i = 0; i < Config.Pickups.Num() && i < Timers.Num(); ++i)
	{
		const FJamPickupDef& D = Config.Pickups[i];
		if (Frame < Timers[i].NextSpawnFrame) continue;
		Timers[i].NextSpawnFrame += FMath::Max(1, D.SpawnEveryFrames);
		int32 Count = 0;
		for (const FJamPickupOnIce& P : OnIce) if (P.PickupIndex == i) ++Count;
		if (Count >= FMath::Max(1, D.MaxOnIce)) continue;
		if (!Config.Find(D.Kind)) continue;
		FVector2D Spot;
		PickSpot(&D, Spot);
		SpawnPickup(D.Kind, Spot, i);
	}
	// Takes: the nearest standing skater within reach, lowest index on a tie.
	const TArray<FJamSkaterState>& Sk = Sim->GetSkaters();
	for (int32 p = OnIce.Num() - 1; p >= 0; --p)
	{
		const FJamPickupOnIce P = OnIce[p];
		int32 Taker = -1;
		double Best = PickupRadiusM + UJamSim::SkaterRadius;
		for (const FJamSkaterState& S : Sk)
		{
			if (S.IsDown()) continue;
			const double Dist = FVector2D::Distance(S.Pos, P.Pos);
			if (Dist < Best) { Best = Dist; Taker = S.Index; }
		}
		if (Taker < 0) continue;
		OnIce.RemoveAt(p);
		++PickupsTaken;
		Emit(JamEvents::PickupTake, Taker, P.Pos, 0.f, P.Kind);
		const FJamEffectDef* Def = Config.Find(P.Kind);
		if (Def)
		{
			const FJamPickupDef* PD = Config.Pickups.IsValidIndex(P.PickupIndex) ? &Config.Pickups[P.PickupIndex] : nullptr;
			Apply(*Def, Taker, TeamOf(Taker), PD ? PD->DurationFrames : Def->DurationFrames, PD ? PD->bHasMagnitude : false, PD ? PD->Magnitude : 1.0);
		}
		Sim->NotifyPickupTaken(Taker, P.Kind);
	}
}

TArray<FJamEffectHudEntry> UJamEffectSystem::GetHudFeedFor(int32 Skater) const
{
	TArray<FJamEffectHudEntry> Out;
	const int32 Team = TeamOf(Skater);
	for (const FJamEffectHudEntry& H : Hud) if (H.Covers(Skater, Team)) Out.Add(H);
	return Out;
}

FName UJamEffectSystem::GetBoostKindFor(int32 Skater) const
{
	const int32 Team = TeamOf(Skater);
	for (int32 i = Hud.Num() - 1; i >= 0; --i) if (Hud[i].Covers(Skater, Team)) return Hud[i].Kind;
	return NAME_None;
}

uint64 UJamEffectSystem::StateHash() const
{
	uint64 H = 14695981039346656037ull;
	Fnv(H, Frame); Fnv(H, NextId); Fnv(H, static_cast<int64>(Rng.GetState()));
	for (int32 i = 0; i < Active.Num(); ++i)
	{
		const FJamActiveModifier& M = Active[i];
		Fnv(H, M.Id); Fnv(H, static_cast<int64>(M.Target)); Fnv(H, M.SourceSkater); Fnv(H, M.Team); Fnv(H, M.FramesLeft); Fnv(H, ActiveStart[i]);
		for (const FJamStatModifier& S : M.Stats) { Fnv(H, static_cast<int64>(S.Stat)); Fnv(H, Q(S.Multiply, 1000)); Fnv(H, Q(S.Add, 1000)); }
	}
	for (const FJamPickupOnIce& P : OnIce) { Fnv(H, P.Id); Fnv(H, P.PickupIndex); Fnv(H, Q(P.Pos.X, 1000)); Fnv(H, Q(P.Pos.Y, 1000)); Fnv(H, P.SpawnFrame); }
	for (const FTimer& T : Timers) Fnv(H, T.NextSpawnFrame);
	return H;
}
