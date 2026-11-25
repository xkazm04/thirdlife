#include "JamEffectTypes.h"
#include "JamJson.h"
#include "BuiltinEffectsData.inl"

namespace JamEffects
{
	const FName EffectStart(TEXT("effect_start"));
	const FName EffectEnd(TEXT("effect_end"));

	const TCHAR* TriggerName(EJamEffectTrigger T)
	{
		switch (T)
		{
		case EJamEffectTrigger::Pickup: return TEXT("pickup");
		case EJamEffectTrigger::GoalFor: return TEXT("goal_for");
		case EJamEffectTrigger::GoalAgainst: return TEXT("goal_against");
		case EJamEffectTrigger::CheckLanded: return TEXT("check_landed");
		case EJamEffectTrigger::CheckReceived: return TEXT("check_received");
		case EJamEffectTrigger::PeriodStart: return TEXT("period_start");
		case EJamEffectTrigger::ZoneEnter: return TEXT("zone_enter");
		case EJamEffectTrigger::ZoneExit: return TEXT("zone_exit");
		case EJamEffectTrigger::Director: return TEXT("director");
		default: return nullptr;
		}
	}

	bool TriggerFromName(FName Name, EJamEffectTrigger& Out)
	{
		for (uint8 i = 0; i < static_cast<uint8>(EJamEffectTrigger::Count); ++i)
		{
			if (Name == FName(TriggerName(static_cast<EJamEffectTrigger>(i)))) { Out = static_cast<EJamEffectTrigger>(i); return true; }
		}
		return false;
	}

	const TCHAR* TargetName(EJamTarget T)
	{
		switch (T)
		{
		case EJamTarget::Self: return TEXT("self");
		case EJamTarget::OwnTeam: return TEXT("own_team");
		case EJamTarget::OtherTeam: return TEXT("other_team");
		case EJamTarget::Everyone: return TEXT("everyone");
		case EJamTarget::Puck: return TEXT("puck");
		case EJamTarget::Rink: return TEXT("rink");
		default: return nullptr;
		}
	}

	bool TargetFromName(FName Name, EJamTarget& Out)
	{
		for (uint8 i = 0; i <= static_cast<uint8>(EJamTarget::Rink); ++i)
		{
			if (Name == FName(TargetName(static_cast<EJamTarget>(i)))) { Out = static_cast<EJamTarget>(i); return true; }
		}
		return false;
	}

	bool StackFromName(FName Name, EJamEffectStack& Out)
	{
		if (Name == TEXT("refresh")) { Out = EJamEffectStack::Refresh; return true; }
		if (Name == TEXT("extend")) { Out = EJamEffectStack::Extend; return true; }
		if (Name == TEXT("ignore")) { Out = EJamEffectStack::Ignore; return true; }
		return false;
	}

	FName DefaultIcon(FName Kind)
	{
		if (Kind == TEXT("speed")) return TEXT("bolt");
		if (Kind == TEXT("precision")) return TEXT("crosshair");
		if (Kind == TEXT("heavy_puck")) return TEXT("weight");
		if (Kind == TEXT("big_puck")) return TEXT("circle");
		if (Kind == TEXT("reverse_other")) return TEXT("swirl");
		return TEXT("star");
	}

	FLinearColor KindColour(FName Kind)
	{
		// Lane A210 (device B's answer to A-to-B-0031 point 3: the speed prop is cyan, A's pedestal and ring were yellow): the colours of contracts/events.md
		// (the pickup kind's colour, linear; the same numbers as UJamEffectsBinder::PickupKindColour and B's PickupColour instances): custom and unknown white.
		if (Kind == TEXT("speed")) return FLinearColor(0.1f, 0.9f, 1.0f);
		if (Kind == TEXT("precision")) return FLinearColor(1.0f, 0.2f, 0.9f);
		if (Kind == TEXT("heavy_puck")) return FLinearColor(0.55f, 0.3f, 1.0f);
		if (Kind == TEXT("big_puck")) return FLinearColor(1.0f, 0.75f, 0.1f);
		if (Kind == TEXT("reverse_other")) return FLinearColor(1.0f, 0.15f, 0.1f);
		return FLinearColor::White;
	}
}

void FJamEffectDef::BuildStats(bool bHasMagnitude, double Magnitude, TArray<FJamStatModifier>& Out) const
{
	for (const FJamEffectStat& S : Stats)
	{
		FJamStatModifier M;
		M.Stat = S.Stat;
		double Mul = S.Multiply;
		double Add = S.Add;
		if (bHasMagnitude)
		{
			const FName Name(JamStats::ToName(S.Stat));
			if (bBuiltin)
			{
				if (MagnitudeStats.Contains(Name)) Mul = Magnitude;
				else if (InverseMagnitudeStats.Contains(Name)) Mul = Magnitude > 0 ? 1.0 / Magnitude : Mul;
			}
			else
			{
				Mul = 1.0 + (S.Multiply - 1.0) * Magnitude;
				Add = S.Add * Magnitude;
			}
		}
		M.Multiply = static_cast<float>(FMath::Clamp(Mul, JamEffects::MinMultiply, JamEffects::MaxMultiply));
		M.Add = static_cast<float>(Add);
		Out.Add(M);
	}
}

namespace
{
	using FJ = FJamJson;
	using FJPtr = TSharedPtr<FJamJson>;

	FJPtr Child(const FJPtr& O, const TCHAR* Key) { return (O && O->IsObject()) ? O->Get(Key) : nullptr; }
	bool ReadName(const FJPtr& O, const TCHAR* Key, FName& Out) { FJPtr V = Child(O, Key); if (V && V->IsString()) { Out = FName(*V->String); return true; } return false; }
	bool ReadNum(const FJPtr& O, const TCHAR* Key, double& Out) { FJPtr V = Child(O, Key); if (V && V->IsNumber()) { Out = V->Number; return true; } return false; }
	bool ReadInt(const FJPtr& O, const TCHAR* Key, int32& Out) { double D; if (ReadNum(O, Key, D)) { Out = static_cast<int32>(D); return true; } return false; }

	bool ParseEffect(const FJPtr& E, int32 Index, const FString& Ptr, FJamEffectDef& Out, TArray<FString>& Errors)
	{
		if (!E || !E->IsObject()) return false;
		ReadName(E, TEXT("id"), Out.Id);
		FName Kind; if (ReadName(E, TEXT("kind"), Kind)) Out.Kind = Kind;
		FName T; if (ReadName(E, TEXT("target"), T)) JamEffects::TargetFromName(T, Out.Target);
		ReadInt(E, TEXT("duration_frames"), Out.DurationFrames);
		FName Tr; if (ReadName(E, TEXT("trigger"), Tr)) JamEffects::TriggerFromName(Tr, Out.Trigger);
		ReadName(E, TEXT("zone"), Out.Zone);
		FName St; if (ReadName(E, TEXT("stack"), St)) JamEffects::StackFromName(St, Out.Stack);
		if (!ReadName(E, TEXT("icon"), Out.Icon)) Out.Icon = JamEffects::DefaultIcon(Out.Kind);
		bool bOk = true;
		if (FJPtr Stats = Child(E, TEXT("stats")); Stats && Stats->IsArray())
		{
			for (int32 j = 0; j < Stats->Array.Num(); ++j)
			{
				const FJPtr& S = Stats->Array[j];
				FJamEffectStat Fs;
				FName StatName;
				ReadName(S, TEXT("stat"), StatName);
				if (!JamStats::FromName(StatName, Fs.Stat))
				{
					Errors.Add(FString::Printf(TEXT("at %s/%d/stats/%d/stat: \"%s\" is not a stat the modifier seam knows; use one of the EJamStat names (skater_speed, shot_speed, puck_drag, ...)."), *Ptr, Index, j, *StatName.ToString()));
					bOk = false;
					continue;
				}
				ReadNum(S, TEXT("multiply"), Fs.Multiply);
				ReadNum(S, TEXT("add"), Fs.Add);
				Out.Stats.Add(Fs);
			}
		}
		auto ReadNames = [&](const TCHAR* Key, TArray<FName>& Dst)
		{
			if (FJPtr L = Child(E, Key); L && L->IsArray()) for (const FJPtr& N : L->Array) if (N->IsString()) Dst.Add(FName(*N->String));
		};
		ReadNames(TEXT("magnitude_stats"), Out.MagnitudeStats);
		ReadNames(TEXT("inverse_magnitude_stats"), Out.InverseMagnitudeStats);
		return bOk;
	}
}

const FJamEffectDef* FJamEffectsConfig::Find(FName Id) const
{
	for (const FJamEffectDef& E : Effects) if (E.Id == Id) return &E;
	for (const FJamEffectDef& E : Builtins()) if (E.Id == Id) return &E;
	return nullptr;
}

const FJamZoneDef* FJamEffectsConfig::FindZone(FName Id) const
{
	for (const FJamZoneDef& Z : Zones) if (Z.Id == Id) return &Z;
	return nullptr;
}

bool FJamEffectsConfig::IsBuiltin(FName Kind)
{
	for (const FJamEffectDef& E : Builtins()) if (E.Id == Kind) return true;
	return false;
}

FString FJamEffectsConfig::BuiltinsJson()
{
	return FString(UTF8_TO_TCHAR(reinterpret_cast<const char*>(JamBuiltinEffectsJson)));
}

const TArray<FJamEffectDef>& FJamEffectsConfig::Builtins()
{
	static TArray<FJamEffectDef> List;
	static bool bParsed = false;
	if (!bParsed)
	{
		bParsed = true;
		FString Err;
		TSharedPtr<FJamJson> Root = FJamJson::Parse(BuiltinsJson(), Err);
		TArray<FString> Errors;
		if (FJPtr L = Child(Root, TEXT("effects")); L && L->IsArray())
		{
			for (int32 i = 0; i < L->Array.Num(); ++i)
			{
				FJamEffectDef D;
				D.bBuiltin = true;
				if (ParseEffect(L->Array[i], i, TEXT("/effects"), D, Errors)) List.Add(D);
			}
		}
		ensureMsgf(Errors.Num() == 0 && List.Num() == 5, TEXT("builtin-effects.json: %s"), Errors.Num() ? *Errors[0] : TEXT("expected five effects"));
	}
	return List;
}

bool FJamEffectsConfig::Parse(const FString& RawCartridgeJson, FJamEffectsConfig& Out, TArray<FString>& OutErrors)
{
	FString Err;
	TSharedPtr<FJamJson> Root = FJamJson::Parse(RawCartridgeJson, Err);
	if (!Root) { OutErrors.Add(Err); return false; }
	FJPtr Game = Child(Root, TEXT("game"));
	if (!Game) { OutErrors.Add(TEXT("at /game: required key \"game\" is missing.")); return false; }
	return ParseGame(*Game, Out, OutErrors);
}

bool FJamEffectsConfig::ParseGame(const FJamJson& Game, FJamEffectsConfig& Out, TArray<FString>& OutErrors)
{
	Out = FJamEffectsConfig();
	bool bOk = true;
	if (FJPtr L = Game.Get(TEXT("effects")); L && L->IsArray())
	{
		for (int32 i = 0; i < L->Array.Num(); ++i)
		{
			FJamEffectDef D;
			if (ParseEffect(L->Array[i], i, TEXT("/game/effects"), D, OutErrors)) Out.Effects.Add(D);
			else bOk = false;
		}
	}
	if (FJPtr L = Game.Get(TEXT("pickups")); L && L->IsArray())
	{
		for (const FJPtr& P : L->Array)
		{
			FJamPickupDef D;
			ReadName(P, TEXT("kind"), D.Kind);
			ReadInt(P, TEXT("spawn_every_frames"), D.SpawnEveryFrames);
			ReadInt(P, TEXT("duration_frames"), D.DurationFrames);
			D.bHasMagnitude = ReadNum(P, TEXT("magnitude"), D.Magnitude);
			if (!D.bHasMagnitude && IsBuiltin(D.Kind))
			{
				// DEFAULTS.md: the built-in's own multiplier (its definition carries it): 1.5 speed, 2 precision, 2 heavy_puck, 1.5 big_puck.
				D.bHasMagnitude = false;
			}
			ReadName(P, TEXT("zone"), D.Zone);
			ReadInt(P, TEXT("max_on_ice"), D.MaxOnIce);
			Out.Pickups.Add(D);
		}
	}
	if (FJPtr Rink = Game.Get(TEXT("rink")); Rink && Rink->IsObject())
	{
		if (FJPtr L = Rink->Get(TEXT("zones")); L && L->IsArray())
		{
			for (const FJPtr& Z : L->Array)
			{
				FJamZoneDef D;
				ReadName(Z, TEXT("id"), D.Id);
				FName Shape; ReadName(Z, TEXT("shape"), Shape);
				D.bCircle = Shape == TEXT("circle");
				ReadNum(Z, TEXT("x"), D.X); ReadNum(Z, TEXT("z"), D.Z);
				ReadNum(Z, TEXT("w"), D.W); ReadNum(Z, TEXT("d"), D.D); ReadNum(Z, TEXT("r"), D.R);
				Out.Zones.Add(D);
			}
		}
	}
	return bOk;
}
