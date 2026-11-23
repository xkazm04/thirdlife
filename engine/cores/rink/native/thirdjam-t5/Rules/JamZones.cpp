#include "JamZones.h"
#include "JamEventBus.h"
#include "JamRuleSystem.h"

namespace
{
	const FName KindSlow(TEXT("slow_ice"));
	const FName KindFast(TEXT("fast_ice"));
	const FName KindBumper(TEXT("bumper"));
	const FName KindNoShoot(TEXT("no_shoot"));
	const FName KindBoostOnly(TEXT("boost_only"));
}

FJamIceFactors JamZones::IceFactors(FName Kind, double Strength)
{
	FJamIceFactors F;
	const double S = FMath::Clamp(Strength, 0.0, 1.0);
	if (Kind == KindSlow) { F.SpeedMul = 1.0 - 0.5 * S; F.FrictionMul = 1.0 + 3.0 * S; }
	else if (Kind == KindFast) { F.SpeedMul = 1.0 + 0.5 * S; F.FrictionMul = FMath::Max(0.2, 1.0 - 0.8 * S); }
	return F;
}

void UJamZoneSystem::Init(const FJamGameConfig& Config)
{
	Zones.Reset();
	for (const FJamZoneConfig& Z : Config.Rink.Zones)
	{
		if (Zones.Num() >= MaxZones) { UE_LOG(LogJamRules, Warning, TEXT("JAMZONES zone %s dropped: more than %d zones"), *Z.Id, MaxZones); continue; }
		Zones.Add(Z);
	}
	Inside.Reset();
	ResetMatch();
	UE_LOG(LogJamRules, Log, TEXT("JAMZONES %d zones ready"), Zones.Num());
}

void UJamZoneSystem::ResetMatch()
{
	for (uint32& M : Inside) M = 0;
	FrameEvents.Reset();
	EnterCount = ExitCount = 0;
}

void UJamZoneSystem::Update(int64 Frame, const TArray<FJamSkaterState>& Skaters, const FJamPuckState& Puck)
{
	FrameEvents.Reset();
	if (Inside.Num() != Skaters.Num() + 1) Inside.Init(0, Skaters.Num() + 1);
	auto Visit = [&](int32 Who, const FVector2D& Pos)
	{
		uint32& Mask = MaskFor(Who);
		for (int32 z = 0; z < Zones.Num(); ++z)
		{
			const uint32 Bit = 1u << z;
			const bool bNow = Zones[z].Contains(Pos);
			const bool bWas = (Mask & Bit) != 0;
			if (bNow == bWas) continue;
			FJamSimEvent E;
			E.Name = bNow ? JamEvents::ZoneEnter : JamEvents::ZoneExit;
			E.Who = Who;
			E.Where = Pos;
			E.Strength = static_cast<float>(Zones[z].Strength);
			E.Kind = FName(*Zones[z].Id);
			E.Frame = Frame;
			FrameEvents.Add(E);
			if (bNow) { Mask |= Bit; ++EnterCount; } else { Mask &= ~Bit; ++ExitCount; }
		}
	};
	Visit(PuckWho, Puck.Pos);
	for (const FJamSkaterState& S : Skaters) Visit(S.Index, S.Pos);
}

FJamIceFactors UJamZoneSystem::IceAt(const FVector2D& PosM) const
{
	FJamIceFactors F;
	for (const FJamZoneConfig& Z : Zones)
	{
		if ((Z.Kind != KindSlow && Z.Kind != KindFast) || !Z.Contains(PosM)) continue;
		const FJamIceFactors Zf = JamZones::IceFactors(Z.Kind, Z.Strength);
		F.SpeedMul *= Zf.SpeedMul;
		F.FrictionMul *= Zf.FrictionMul;
	}
	return F;
}

bool UJamZoneSystem::BlocksShot(const FVector2D& PosM, FName& OutZoneId) const
{
	const int32 I = ZoneIndexAt(PosM, KindNoShoot);
	if (I < 0) return false;
	OutZoneId = FName(*Zones[I].Id);
	return true;
}

bool UJamZoneSystem::BumpPuck(FVector2D& Pos, FVector2D& Vel, double RadiusM) const
{
	bool bHit = false;
	for (const FJamZoneConfig& Z : Zones)
	{
		if (Z.Kind != KindBumper) continue;
		FVector2D N;
		const double D = Z.EdgeDistance(Pos, N);   // negative inside
		if (D - RadiusM >= 0) continue;              // the puck's edge is clear of the zone
		Pos += N * (RadiusM - D);
		JamZones::ReflectOffBumper(Vel, N, JamZones::BumperRestitutionFor(Z.Strength));
		bHit = true;
	}
	return bHit;
}

bool UJamZoneSystem::AllowsPickupAt(const FVector2D& PosM) const
{
	bool bAny = false;
	for (const FJamZoneConfig& Z : Zones)
	{
		if (Z.Kind != KindBoostOnly) continue;
		bAny = true;
		if (Z.Contains(PosM)) return true;
	}
	return !bAny;
}

bool UJamZoneSystem::IsInside(int32 Who, int32 ZoneIndex) const
{
	return Zones.IsValidIndex(ZoneIndex) && (MaskFor(Who) & (1u << ZoneIndex)) != 0;
}

int32 UJamZoneSystem::ZoneIndexAt(const FVector2D& P, FName Kind) const
{
	for (int32 z = 0; z < Zones.Num(); ++z)
	{
		if (!Kind.IsNone() && Zones[z].Kind != Kind) continue;
		if (Zones[z].Contains(P)) return z;
	}
	return -1;
}

uint64 UJamZoneSystem::StateHash() const
{
	uint64 H = 1469598103934665603ull;
	auto Add = [&H](uint64 V) { for (int32 i = 0; i < 8; ++i) { H ^= (V >> (i * 8)) & 0xFF; H *= 1099511628211ull; } };
	for (uint32 M : Inside) Add(M);
	Add(static_cast<uint64>(EnterCount));
	Add(static_cast<uint64>(ExitCount));
	return H;
}
