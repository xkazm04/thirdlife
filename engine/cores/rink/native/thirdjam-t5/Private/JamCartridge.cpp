#include "JamCartridge.h"
#include "JamModifiers.h"
#include "JamJson.h"
#include "Misc/FileHelper.h"
#include "Misc/Paths.h"
#include "UObject/Package.h"
#include "Internationalization/Regex.h"
#include "HAL/PlatformMisc.h"

#include "JamSchemaData.inl"

DEFINE_LOG_CATEGORY(LogJamCartridge);

// ---------------------------------------------------------------------------------------------------------------------
// The validator: a port of schema/validate.mjs (schema walker over the embedded schema files + checkEngine).
// ---------------------------------------------------------------------------------------------------------------------
namespace JamValidate
{
	using FJ = FJamJson;
	using FJPtr = TSharedPtr<FJamJson>;

	struct FSchemas
	{
		TMap<FString, FJPtr> Files;   // file name -> parsed schema
		FJPtr Limits;
		bool bOk = false;
		FString Error;
	};

	static const FSchemas& GetSchemas()
	{
		static FSchemas S = []
		{
			FSchemas Out;
			Out.bOk = true;
			for (const FJamEmbeddedSchemaFile& F : JamEmbeddedSchemaFiles)
			{
				const FString Text = FString(UTF8_TO_TCHAR(reinterpret_cast<const char*>(F.Data)));
				FString Err;
				FJPtr Root = FJamJson::Parse(Text, Err);
				if (!Root) { Out.bOk = false; Out.Error = FString::Printf(TEXT("embedded %s: %s"), F.Name, *Err); continue; }
				if (FString(F.Name) == TEXT("limits.json")) Out.Limits = Root;
				else Out.Files.Add(F.Name, Root);
			}
			return Out;
		}();
		return S;
	}

	static FString Show(const FString& P) { return FJ::Show(P); }
	static FString Num(double V) { return FJ::NumberToString(V); }

	static FString Quote(const FString& S)
	{
		FJ Tmp; Tmp.Type = FJ::EType::String; Tmp.String = S;
		return Tmp.ToCompact();
	}

	static FString Describe(const FJ& V)
	{
		switch (V.Type)
		{
		case FJ::EType::Null: return TEXT("null (omit the key instead of writing null)");
		case FJ::EType::Array: return FString::Printf(TEXT("an array of %d item%s"), V.Array.Num(), V.Array.Num() == 1 ? TEXT("") : TEXT("s"));
		case FJ::EType::String: return FString::Printf(TEXT("a string (%s)"), *Quote(V.String.Len() > 40 ? V.String.Left(40) + TEXT("...") : V.String));
		case FJ::EType::Number: return FString::Printf(TEXT("%s (%s)"), V.IsInteger() ? TEXT("a whole number") : TEXT("a number"), *Num(V.Number));
		case FJ::EType::Bool: return FString::Printf(TEXT("a boolean (%s)"), V.Bool ? TEXT("true") : TEXT("false"));
		default: return TEXT("an object");
		}
	}

	static FString Article(const FString& W)
	{
		return (W == TEXT("array") || W == TEXT("object") || W == TEXT("integer")) ? TEXT("an ") + W : TEXT("a ") + W;
	}

	static bool MatchesType(const FJ& V, const FString& T)
	{
		if (T == TEXT("object")) return V.IsObject();
		if (T == TEXT("array")) return V.IsArray();
		if (T == TEXT("string")) return V.IsString();
		if (T == TEXT("number")) return V.IsNumber() && FMath::IsFinite(V.Number);
		if (T == TEXT("integer")) return V.IsInteger();
		if (T == TEXT("boolean")) return V.IsBool();
		if (T == TEXT("null")) return V.IsNull();
		return false;
	}

	static bool DeepEqual(const FJ& A, const FJ& B)
	{
		if (A.Type != B.Type) return false;
		switch (A.Type)
		{
		case FJ::EType::Null: return true;
		case FJ::EType::Bool: return A.Bool == B.Bool;
		case FJ::EType::Number: return A.Number == B.Number;
		case FJ::EType::String: return A.String == B.String;
		case FJ::EType::Array:
			if (A.Array.Num() != B.Array.Num()) return false;
			for (int32 i = 0; i < A.Array.Num(); ++i) if (!DeepEqual(*A.Array[i], *B.Array[i])) return false;
			return true;
		case FJ::EType::Object:
			if (A.Object.Num() != B.Object.Num()) return false;
			for (const auto& KV : A.Object)
			{
				FJPtr Other = B.Get(KV.Key);
				if (!Other || !DeepEqual(*KV.Value, *Other)) return false;
			}
			return true;
		}
		return false;
	}

	struct FCtx { FString File; };

	static FJPtr ResolveRef(const FString& Ref, FCtx& InOutCtx)
	{
		FString File, Frag;
		if (!Ref.Split(TEXT("#"), &File, &Frag)) { File = Ref; Frag.Reset(); }
		const FSchemas& S = GetSchemas();
		if (!File.IsEmpty()) InOutCtx.File = File;
		const FJPtr* Root = S.Files.Find(InOutCtx.File);
		if (!Root) return nullptr;
		FJPtr Node = *Root;
		if (!Frag.IsEmpty())
		{
			TArray<FString> Parts;
			Frag.ParseIntoArray(Parts, TEXT("/"), true);
			for (const FString& P : Parts)
			{
				if (!Node) return nullptr;
				Node = Node->Get(P.Replace(TEXT("~1"), TEXT("/")).Replace(TEXT("~0"), TEXT("~")));
			}
		}
		return Node;
	}

	static void Walk(const FJ& Schema, const FJ& Value, const FString& Ptr, FCtx Ctx, TArray<FString>& Errors)
	{
		if (Schema.IsBool())
		{
			if (!Schema.Bool) Errors.Add(FString::Printf(TEXT("at %s: no value is allowed here."), *Show(Ptr)));
			return;
		}
		if (FJPtr Ref = Schema.Get(TEXT("$ref")))
		{
			FCtx Next = Ctx;
			FJPtr Target = ResolveRef(Ref->String, Next);
			if (!Target) { Errors.Add(FString::Printf(TEXT("at %s: schema $ref \"%s\" does not resolve."), *Show(Ptr), *Ref->String)); return; }
			Walk(*Target, Value, Ptr, Next, Errors);
			return;
		}
		const FString At = FString::Printf(TEXT("at %s:"), *Show(Ptr));

		if (FJPtr Type = Schema.Get(TEXT("type")))
		{
			TArray<FString> Types;
			if (Type->IsArray()) { for (const FJPtr& T : Type->Array) Types.Add(T->String); }
			else Types.Add(Type->String);
			bool bAny = false;
			for (const FString& T : Types) bAny |= MatchesType(Value, T);
			if (!bAny)
			{
				TArray<FString> Names;
				for (const FString& T : Types) Names.Add(Article(T));
				FString Want = Names.Last();
				if (Names.Num() > 1)
				{
					Want = FString::Join(TArrayView<const FString>(Names.GetData(), Names.Num() - 1), TEXT(", ")) + TEXT(" or ") + Names.Last();
				}
				Errors.Add(FString::Printf(TEXT("%s expected %s but found %s."), *At, *Want, *Describe(Value)));
				return;
			}
		}
		if (FJPtr Const = Schema.Get(TEXT("const")))
		{
			if (!DeepEqual(Value, *Const))
				Errors.Add(FString::Printf(TEXT("%s must be exactly %s but found %s."), *At, *Const->ToCompact(), *Value.ToCompact()));
		}
		if (FJPtr Enum = Schema.Get(TEXT("enum")))
		{
			bool bFound = false;
			TArray<FString> Opts;
			for (const FJPtr& E : Enum->Array) { bFound |= DeepEqual(*E, Value); Opts.Add(E->ToCompact()); }
			if (!bFound)
			{
				Errors.Add(FString::Printf(TEXT("%s %s is not allowed; use one of %s."), *At, *Value.ToCompact(), *FString::Join(Opts, TEXT(", "))));
				return;
			}
		}
		if (Value.IsNumber())
		{
			if (FJPtr Min = Schema.Get(TEXT("minimum")); Min && Value.Number < Min->Number)
				Errors.Add(FString::Printf(TEXT("%s %s is below the minimum %s."), *At, *Num(Value.Number), *Num(Min->Number)));
			if (FJPtr Max = Schema.Get(TEXT("maximum")); Max && Value.Number > Max->Number)
				Errors.Add(FString::Printf(TEXT("%s %s is above the maximum %s."), *At, *Num(Value.Number), *Num(Max->Number)));
		}
		if (Value.IsString())
		{
			const int32 L = Value.String.Len();
			if (FJPtr Min = Schema.Get(TEXT("minLength")); Min && L < Min->Number)
				Errors.Add(FString::Printf(TEXT("%s the string is %d characters long; it needs at least %s."), *At, L, *Num(Min->Number)));
			if (FJPtr Max = Schema.Get(TEXT("maxLength")); Max && L > Max->Number)
				Errors.Add(FString::Printf(TEXT("%s the string is %d characters long; the limit is %s."), *At, L, *Num(Max->Number)));
			if (FJPtr Pat = Schema.Get(TEXT("pattern")))
			{
				const FRegexPattern Pattern(Pat->String);
				FRegexMatcher M(Pattern, Value.String);
				if (!M.FindNext())
				{
					FJPtr Desc = Schema.Get(TEXT("description"));
					const FString Why = Desc ? TEXT(": ") + Desc->String : FString::Printf(TEXT(" (pattern %s)"), *Pat->String);
					Errors.Add(FString::Printf(TEXT("%s %s is not valid%s."), *At, *Quote(Value.String), *Why));
				}
			}
		}
		if (Value.IsArray())
		{
			const int32 N = Value.Array.Num();
			if (FJPtr Min = Schema.Get(TEXT("minItems")); Min && N < Min->Number)
				Errors.Add(FString::Printf(TEXT("%s the list has %d item%s; it needs at least %s."), *At, N, N == 1 ? TEXT("") : TEXT("s"), *Num(Min->Number)));
			if (FJPtr Max = Schema.Get(TEXT("maxItems")); Max && N > Max->Number)
				Errors.Add(FString::Printf(TEXT("%s the list has %d items; the limit is %s."), *At, N, *Num(Max->Number)));
			if (FJPtr Items = Schema.Get(TEXT("items")))
			{
				for (int32 i = 0; i < N; ++i) Walk(*Items, *Value.Array[i], FJ::PointerChild(Ptr, i), Ctx, Errors);
			}
		}
		if (Value.IsObject())
		{
			FJPtr Props = Schema.Get(TEXT("properties"));
			if (FJPtr Req = Schema.Get(TEXT("required")))
			{
				for (const FJPtr& R : Req->Array)
				{
					if (!Value.Has(R->String))
						Errors.Add(FString::Printf(TEXT("at %s: required key \"%s\" is missing."), *Show(FJ::PointerChild(Ptr, R->String)), *R->String));
				}
			}
			FJPtr Additional = Schema.Get(TEXT("additionalProperties"));
			for (const auto& KV : Value.Object)
			{
				FJPtr Prop = Props ? Props->Get(KV.Key) : nullptr;
				if (Prop)
				{
					Walk(*Prop, *KV.Value, FJ::PointerChild(Ptr, KV.Key), Ctx, Errors);
				}
				else if (Additional && Additional->IsBool() && !Additional->Bool)
				{
					TArray<FString> Allowed;
					if (Props) for (const auto& P : Props->Object) Allowed.Add(P.Key);
					Errors.Add(FString::Printf(TEXT("at %s: unknown key \"%s\" is not allowed here; remove it.%s"), *Show(FJ::PointerChild(Ptr, KV.Key)), *KV.Key,
						Allowed.Num() ? *FString::Printf(TEXT(" Allowed keys: %s."), *FString::Join(Allowed, TEXT(", "))) : TEXT(" No keys are allowed in this object.")));
				}
				else if (Additional && Additional->IsObject())
				{
					Walk(*Additional, *KV.Value, FJ::PointerChild(Ptr, KV.Key), Ctx, Errors);
				}
			}
		}
	}

	// ---------- engine checks (checkEngine in validate.mjs) ----------

	static double LimitNum(const TCHAR* Key, double Fallback)
	{
		const FSchemas& S = GetSchemas();
		if (S.Limits) if (FJPtr V = S.Limits->Get(Key); V && V->IsNumber()) return V->Number;
		return Fallback;
	}

	// Lane A118 (track S3): the game field a hook's set_param names (SET_PARAM_FIELD in validate.mjs), and its "lo..hi" range from limits.json game_ranges.
	static const TCHAR* SetParamField(const FString& Param)
	{
		static const TCHAR* const Map[][2] = {
			{ TEXT("skater_speed"), TEXT("skater.speed") }, { TEXT("skater_turn_rate"), TEXT("skater.turn_rate") }, { TEXT("shot_speed"), TEXT("shot.speed") },
			{ TEXT("puck_max_speed"), TEXT("puck.max_speed") }, { TEXT("ice_friction"), TEXT("rink.ice_friction") }, { TEXT("board_restitution"), TEXT("rink.board_restitution") },
			{ TEXT("ai_speed_scale"), TEXT("ai.speed_scale") }, { TEXT("ai_red_skill"), TEXT("ai.red_skill") },
		};
		for (const auto& Row : Map) if (Param == Row[0]) return Row[1];
		return nullptr;
	}

	static bool GameRange(const FString& Field, double& Lo, double& Hi)
	{
		const FSchemas& S = GetSchemas();
		FJPtr Ranges = S.Limits ? S.Limits->Get(TEXT("game_ranges")) : nullptr;
		FJPtr R = Ranges && Ranges->IsObject() ? Ranges->Get(Field) : nullptr;
		FString L, H;
		if (!R || !R->IsString() || !R->String.Split(TEXT(".."), &L, &H)) return false;
		Lo = FCString::Atod(*L);
		Hi = FCString::Atod(*H);
		return true;
	}

	static bool IsWallClock(const FString& K)
	{
		static const FRegexPattern P(TEXT("_(seconds?|secs?|ms|millis|milliseconds|minutes?|mins?|hours?)$"));
		FRegexMatcher M(P, K);
		return M.FindNext();
	}

	static FString WallClockToFrames(const FString& K)
	{
		static const FRegexPattern P(TEXT("^(.*)_(seconds?|secs?|ms|millis|milliseconds|minutes?|mins?|hours?)$"));
		FRegexMatcher M(P, K);
		return M.FindNext() ? M.GetCaptureGroup(1) + TEXT("_frames") : K;
	}

	static void CheckParams(const FJPtr& Params, const FString& Ptr, TArray<FString>& Errors)
	{
		if (!Params || !Params->IsObject()) return;
		const int32 MaxKeys = static_cast<int32>(LimitNum(TEXT("max_param_keys"), 16));
		if (Params->Object.Num() > MaxKeys)
			Errors.Add(FString::Printf(TEXT("at %s: %d parameters; the engine allows at most %d."), *Show(Ptr), Params->Object.Num(), MaxKeys));
		static const FRegexPattern Snake(TEXT("^[a-z][a-z0-9]*(_[a-z0-9]+)*$"));
		for (const auto& KV : Params->Object)
		{
			const FString P = FJ::PointerChild(Ptr, KV.Key);
			FRegexMatcher M(Snake, KV.Key);
			if (!M.FindNext() || KV.Key.Len() > 40)
				Errors.Add(FString::Printf(TEXT("at %s: the parameter name %s must be snake_case (lowercase letters and digits separated by single underscores, starting with a letter, at most 40 characters)."), *Show(P), *Quote(KV.Key)));
			else if (IsWallClock(KV.Key))
				Errors.Add(FString::Printf(TEXT("at %s: \"%s\" counts wall-clock time. Time is physics frames (60 per second): rename it to \"%s\" and convert the number."), *Show(P), *KV.Key, *WallClockToFrames(KV.Key)));
			else if (KV.Key.EndsWith(TEXT("_frames")) && !(KV.Value->IsInteger() && KV.Value->Number >= 0))
				Errors.Add(FString::Printf(TEXT("at %s: \"%s\" is a duration in frames and must be a whole number of 0 or more, found %s."), *Show(P), *KV.Key, *KV.Value->ToCompact()));
		}
	}

	static TMap<FString, int32> CheckUniqueIds(const FJPtr& List, const FString& Ptr, const TCHAR* What, TArray<FString>& Errors, const TCHAR* IdKey = TEXT("id"))
	{
		TMap<FString, int32> Seen;
		if (!List || !List->IsArray()) return Seen;
		for (int32 i = 0; i < List->Array.Num(); ++i)
		{
			const FJPtr& Item = List->Array[i];
			FJPtr Id = Item->IsObject() ? Item->Get(IdKey) : nullptr;
			if (!Id || !Id->IsString()) continue;
			if (const int32* First = Seen.Find(Id->String))
			{
				Errors.Add(FString::Printf(TEXT("at %s: duplicate %s %s \"%s\"; it is already used at %s. The %ss in this list must be unique."),
					*Show(FJ::PointerChild(FJ::PointerChild(Ptr, i), IdKey)), What, IdKey, *Id->String, *Show(FJ::PointerChild(FJ::PointerChild(Ptr, *First), IdKey)), IdKey));
			}
			else Seen.Add(Id->String, i);
		}
		return Seen;
	}

	static void CheckCount(const FJPtr& List, int32 Max, const FString& Ptr, const TCHAR* What, TArray<FString>& Errors)
	{
		if (List && List->IsArray() && List->Array.Num() > Max)
			Errors.Add(FString::Printf(TEXT("at %s: %d %s; the engine allows at most %d. Remove %d."), *Show(Ptr), List->Array.Num(), What, Max, List->Array.Num() - Max));
	}

	static void CheckValueAgainst(const FJ& T, const FJ& V, const FString& Ptr, const FString& Label, TArray<FString>& Errors)
	{
		FJPtr KeyV = T.Get(TEXT("key"));
		const FString Name = KeyV && KeyV->IsString() ? KeyV->String : TEXT("?");
		FJPtr TypeV = T.Get(TEXT("type"));
		const FString Type = TypeV && TypeV->IsString() ? TypeV->String : FString();
		FJPtr Min = T.Get(TEXT("min")), Max = T.Get(TEXT("max"));
		const bool bMin = Min && Min->IsNumber(), bMax = Max && Max->IsNumber();
		if (Type == TEXT("number") || Type == TEXT("integer"))
		{
			if (!V.IsNumber()) { Errors.Add(FString::Printf(TEXT("at %s: %s must be a %s but is %s."), *Show(Ptr), *Label, *Type, *Describe(V))); return; }
			if (Type == TEXT("integer") && !V.IsInteger()) { Errors.Add(FString::Printf(TEXT("at %s: %s must be a whole number but is %s."), *Show(Ptr), *Label, *Num(V.Number))); return; }
			if (bMin && bMax && Min->Number > Max->Number) return;
			const FString Range = (bMin && bMax) ? FString::Printf(TEXT(" (allowed range %s to %s)"), *Num(Min->Number), *Num(Max->Number)) : FString();
			if (bMin && V.Number < Min->Number) Errors.Add(FString::Printf(TEXT("at %s: %s is %s, below the minimum %s%s."), *Show(Ptr), *Label, *Num(V.Number), *Num(Min->Number), *Range));
			else if (bMax && V.Number > Max->Number) Errors.Add(FString::Printf(TEXT("at %s: %s is %s, above the maximum %s%s."), *Show(Ptr), *Label, *Num(V.Number), *Num(Max->Number), *Range));
		}
		else if (Type == TEXT("boolean"))
		{
			if (!V.IsBool()) Errors.Add(FString::Printf(TEXT("at %s: %s must be true or false but is %s."), *Show(Ptr), *Label, *Describe(V)));
		}
		else if (Type == TEXT("enum"))
		{
			FJPtr Opts = T.Get(TEXT("options"));
			if (!Opts || !Opts->IsArray()) return;
			bool bFound = false;
			TArray<FString> Names;
			for (const FJPtr& O : Opts->Array) { Names.Add(O->IsString() ? O->String : O->ToCompact()); bFound |= (V.IsString() && O->IsString() && O->String == V.String); }
			if (!bFound) Errors.Add(FString::Printf(TEXT("at %s: %s is %s, which is not an option of \"%s\"; use one of %s."), *Show(Ptr), *Label, *V.ToCompact(), *Name, *FString::Join(Names, TEXT(", "))));
		}
	}

	static void CheckTunables(const FJPtr& Tunables, TArray<FString>& Errors)
	{
		CheckCount(Tunables, static_cast<int32>(LimitNum(TEXT("max_tunables"), 24)), TEXT("/tunables"), TEXT("tunables"), Errors);
		CheckUniqueIds(Tunables, TEXT("/tunables"), TEXT("tunable"), Errors, TEXT("key"));
		if (!Tunables || !Tunables->IsArray()) return;
		for (int32 i = 0; i < Tunables->Array.Num(); ++i)
		{
			const FJ& T = *Tunables->Array[i];
			if (!T.IsObject()) continue;
			const FString P = FString::Printf(TEXT("/tunables/%d"), i);
			FJPtr KeyV = T.Get(TEXT("key"));
			const FString Name = KeyV && KeyV->IsString() ? KeyV->String : FString::Printf(TEXT("#%d"), i);
			FJPtr TypeV = T.Get(TEXT("type"));
			const FString Type = TypeV && TypeV->IsString() ? TypeV->String : FString();
			if (KeyV && KeyV->IsString())
			{
				if (IsWallClock(KeyV->String))
					Errors.Add(FString::Printf(TEXT("at %s: \"%s\" counts wall-clock time. Time is physics frames (60 per second): name it \"%s\"."), *Show(FJ::PointerChild(P, TEXT("key"))), *KeyV->String, *WallClockToFrames(KeyV->String)));
				else if (KeyV->String.EndsWith(TEXT("_frames")) && Type != TEXT("integer"))
					Errors.Add(FString::Printf(TEXT("at %s: tunable \"%s\" is a duration in frames, so its type must be \"integer\"."), *Show(FJ::PointerChild(P, TEXT("type"))), *KeyV->String));
			}
			auto Has = [&T](const TCHAR* K) { return T.Has(K); };
			if (Type == TEXT("number") || Type == TEXT("integer"))
			{
				if (Has(TEXT("options"))) Errors.Add(FString::Printf(TEXT("at %s: only enum tunables have options; remove it from \"%s\"."), *Show(FJ::PointerChild(P, TEXT("options"))), *Name));
				for (const TCHAR* K : { TEXT("min"), TEXT("max") })
					if (!Has(K)) Errors.Add(FString::Printf(TEXT("at %s: %s tunable \"%s\" must declare \"%s\" so its range is bounded."), *Show(FJ::PointerChild(P, K)), *Type, *Name, K));
				FJPtr Min = T.Get(TEXT("min")), Max = T.Get(TEXT("max"));
				if (Min && Max && Min->IsNumber() && Max->IsNumber() && Min->Number > Max->Number)
					Errors.Add(FString::Printf(TEXT("at %s: min %s is above max %s for tunable \"%s\"."), *Show(FJ::PointerChild(P, TEXT("min"))), *Num(Min->Number), *Num(Max->Number), *Name));
				if (Type == TEXT("integer"))
				{
					for (const TCHAR* K : { TEXT("min"), TEXT("max") })
					{
						FJPtr V = T.Get(K);
						if (V && V->IsNumber() && !V->IsInteger())
							Errors.Add(FString::Printf(TEXT("at %s: integer tunable \"%s\" needs a whole-number %s, found %s."), *Show(FJ::PointerChild(P, K)), *Name, K, *Num(V->Number)));
					}
				}
				if (FJPtr D = T.Get(TEXT("default"))) CheckValueAgainst(T, *D, FJ::PointerChild(P, TEXT("default")), FString::Printf(TEXT("the default of tunable \"%s\""), *Name), Errors);
			}
			else if (Type == TEXT("boolean"))
			{
				for (const TCHAR* K : { TEXT("min"), TEXT("max"), TEXT("options") })
					if (Has(K)) Errors.Add(FString::Printf(TEXT("at %s: boolean tunable \"%s\" must not have \"%s\"; remove it."), *Show(FJ::PointerChild(P, K)), *Name, K));
				if (FJPtr D = T.Get(TEXT("default")); D && !D->IsBool())
					Errors.Add(FString::Printf(TEXT("at %s: the default of boolean tunable \"%s\" must be true or false, found %s."), *Show(FJ::PointerChild(P, TEXT("default"))), *Name, *Describe(*D)));
			}
			else if (Type == TEXT("enum"))
			{
				for (const TCHAR* K : { TEXT("min"), TEXT("max") })
					if (Has(K)) Errors.Add(FString::Printf(TEXT("at %s: enum tunable \"%s\" must not have \"%s\"; remove it."), *Show(FJ::PointerChild(P, K)), *Name, K));
				FJPtr Opts = T.Get(TEXT("options"));
				if (!Opts) Errors.Add(FString::Printf(TEXT("at %s: enum tunable \"%s\" must list its options."), *Show(FJ::PointerChild(P, TEXT("options"))), *Name));
				else if (Opts->IsArray())
				{
					TSet<FString> Seen; bool bDup = false; TArray<FString> Names;
					for (const FJPtr& O : Opts->Array) { const FString S = O->IsString() ? O->String : O->ToCompact(); bDup |= Seen.Contains(S); Seen.Add(S); Names.Add(S); }
					if (bDup) Errors.Add(FString::Printf(TEXT("at %s: the options of \"%s\" contain a duplicate."), *Show(FJ::PointerChild(P, TEXT("options"))), *Name));
					if (FJPtr D = T.Get(TEXT("default")); D && !(D->IsString() && Seen.Contains(D->String)))
						Errors.Add(FString::Printf(TEXT("at %s: the default %s of \"%s\" is not one of its options (%s)."), *Show(FJ::PointerChild(P, TEXT("default"))), *D->ToCompact(), *Name, *FString::Join(Names, TEXT(", "))));
				}
			}
		}
	}

	static void CheckValues(const FJ& Obj, TArray<FString>& Errors)
	{
		FJPtr Values = Obj.Get(TEXT("values"));
		FJPtr Tunables = Obj.Get(TEXT("tunables"));
		if (!Values || !Values->IsObject()) return;
		TMap<FString, FJPtr> ByKey;
		TArray<FString> Keys;
		if (Tunables && Tunables->IsArray())
			for (const FJPtr& T : Tunables->Array)
				if (T->IsObject()) if (FJPtr K = T->Get(TEXT("key")); K && K->IsString()) { if (!ByKey.Contains(K->String)) Keys.Add(K->String); ByKey.Add(K->String, T); }
		for (const auto& KV : Values->Object)
		{
			const FString P = FJ::PointerChild(TEXT("/values"), KV.Key);
			if (KV.Value->IsNull()) continue;
			FJPtr* T = ByKey.Find(KV.Key);
			if (!T)
			{
				Errors.Add(FString::Printf(TEXT("at %s: \"%s\" is not a declared tunable, so it cannot have a value. Tunable keys are: %s."), *Show(P), *KV.Key, Keys.Num() ? *FString::Join(Keys, TEXT(", ")) : TEXT("(none)")));
				continue;
			}
			CheckValueAgainst(**T, *KV.Value, P, FString::Printf(TEXT("the value of tunable \"%s\""), *KV.Key), Errors);
		}
	}

	static void CollectStrings(const FJ& V, const FString& Ptr, TArray<TPair<FString, FString>>& Out)
	{
		if (V.IsString()) Out.Emplace(Ptr, V.String);
		else if (V.IsArray()) for (int32 i = 0; i < V.Array.Num(); ++i) CollectStrings(*V.Array[i], FJ::PointerChild(Ptr, i), Out);
		else if (V.IsObject()) for (const auto& KV : V.Object) CollectStrings(*KV.Value, FJ::PointerChild(Ptr, KV.Key), Out);
	}

	static constexpr double SpawnMarginM = 0.5;
	static constexpr double DefaultCornerM = 5;

	static bool InsideRink(double X, double Z, double L, double W, double Corner)
	{
		const double Hx = L / 2 - SpawnMarginM;
		const double Hz = W / 2 - SpawnMarginM;
		if (FMath::Abs(X) > Hx || FMath::Abs(Z) > Hz) return false;
		const double R = FMath::Max(0.0, FMath::Min(FMath::Min(Corner - SpawnMarginM, Hx), Hz));
		const double Dx = FMath::Abs(X) - (Hx - R);
		const double Dz = FMath::Abs(Z) - (Hz - R);
		return !(Dx > 0 && Dz > 0 && Dx * Dx + Dz * Dz > R * R);
	}

	static double NumOr(const FJPtr& Obj, const TCHAR* Key, bool& bHas)
	{
		bHas = false;
		if (!Obj || !Obj->IsObject()) return 0;
		FJPtr V = Obj->Get(Key);
		if (V && V->IsNumber()) { bHas = true; return V->Number; }
		return 0;
	}

	// C-0005 (lane A15): the C++ mirror of checkHook in schema/validate.mjs (same pointers, same kinds of failure).
	static void CheckHook(const FJPtr& H, const FString& Ptr, TArray<FString>& Errors)
	{
		if (!H || !H->IsObject()) return;
		FJPtr WhenV = H->Get(TEXT("when"));
		const FString When = WhenV && WhenV->IsString() ? WhenV->String : FString();
		const bool bEvery = H->Has(TEXT("every_frames"));
		if (When == TEXT("on_frame") && !bEvery) Errors.Add(FString::Printf(TEXT("at %s/every_frames: a hook with when \"on_frame\" needs every_frames (60 to 18000 frames, 60 per second)."), *Ptr));
		if (!When.IsEmpty() && When != TEXT("on_frame") && bEvery) Errors.Add(FString::Printf(TEXT("at %s/every_frames: every_frames only applies to when \"on_frame\"; remove it."), *Ptr));
		FJPtr Score = H->Get(TEXT("score"));
		if (Score && !Score->IsObject()) Score.Reset();
		if (When == TEXT("on_score_reached") && !(Score && Score->Has(TEXT("at_least")))) Errors.Add(FString::Printf(TEXT("at %s/score: a hook with when \"on_score_reached\" needs score.at_least (the score that triggers it)."), *Ptr));
		{
			bool bLo, bHi;
			const double Lo = NumOr(Score, TEXT("at_least"), bLo), Hi = NumOr(Score, TEXT("at_most"), bHi);
			if (bLo && bHi && Lo > Hi) Errors.Add(FString::Printf(TEXT("at %s/score/at_least: at_least %s is above at_most %s; no score could ever match."), *Ptr, *Num(Lo), *Num(Hi)));
		}
		FJPtr Then = H->Get(TEXT("then"));
		if (!Then || !Then->IsArray()) return;
		for (int32 j = 0; j < Then->Array.Num(); ++j)
		{
			const FJPtr& A = Then->Array[j];
			if (!A || !A->IsObject()) continue;
			FJPtr DoV = A->Get(TEXT("do"));
			if (!DoV || !DoV->IsString()) continue;
			const FString Do = DoV->String;
			const FString P = FString::Printf(TEXT("%s/then/%d"), *Ptr, j);
			TArray<FString> Needs;
			if (Do == TEXT("add_score") || Do == TEXT("set_score_multiplier") || Do == TEXT("shrink_rink") || Do == TEXT("grow_rink")) Needs = { TEXT("value") };
			else if (Do == TEXT("set_param")) Needs = { TEXT("param"), TEXT("value") };
			else if (Do == TEXT("spawn_pickup")) Needs = { TEXT("kind") };
			else if (Do == TEXT("apply_modifier")) Needs = { TEXT("kind"), TEXT("frames") };
			else if (Do == TEXT("announce")) Needs = { TEXT("text") };
			for (const FString& K : Needs) if (!A->Has(K)) Errors.Add(FString::Printf(TEXT("at %s/%s: the action \"%s\" needs %s."), *P, *K, *Do, *K));
			bool bV;
			const double V = NumOr(A, TEXT("value"), bV);
			if (bV)
			{
				if (Do == TEXT("add_score") && FMath::FloorToDouble(V) != V) Errors.Add(FString::Printf(TEXT("at %s/value: add_score adds whole goals; %s is not a whole number."), *P, *Num(V)));
				if (Do == TEXT("set_score_multiplier") && (V < 1 || V > 5)) Errors.Add(FString::Printf(TEXT("at %s/value: a score multiplier is 1 to 5, found %s."), *P, *Num(V)));
				if ((Do == TEXT("shrink_rink") || Do == TEXT("grow_rink")) && (V < 0.05 || V > 0.5)) Errors.Add(FString::Printf(TEXT("at %s/value: %s takes the fraction to change the rink by, 0.05 to 0.5 (0.1 is 10 percent), found %s."), *P, *Do, *Num(V)));
			}
			// Lane A118: set_param names one of the nine tunables and stays inside its field's range (validate.mjs checkHook).
			if (Do == TEXT("set_param"))
			{
				if (FJPtr Param = A->Get(TEXT("param")); Param && Param->IsString())
				{
					const TCHAR* Field = SetParamField(Param->String);
					double Lo = 0, Hi = 0;
					if (!Field) Errors.Add(FString::Printf(TEXT("at %s/param: set_param can change skater_speed, skater_turn_rate, shot_speed, puck_max_speed, ice_friction, board_restitution, ai_speed_scale, ai_red_skill; \"%s\" is none of them."), *P, *Param->String));
					else if (bV && GameRange(Field, Lo, Hi) && (V < Lo || V > Hi)) Errors.Add(FString::Printf(TEXT("at %s/value: %s lies within %s to %s (the range of game.%s), found %s."), *P, *Param->String, *Num(Lo), *Num(Hi), Field, *Num(V)));
				}
			}
		}
	}

	static void CheckGame(const FJPtr& Game, TArray<FString>& Errors)
	{
		if (!Game || !Game->IsObject()) return;
		FJPtr Rink = Game->Get(TEXT("rink"));
		if (Rink && !Rink->IsObject()) Rink.Reset();
		bool bL, bW, bC, bG;
		const double L = NumOr(Rink, TEXT("length_m"), bL);
		const double W = NumOr(Rink, TEXT("width_m"), bW);
		const double CornerRaw = NumOr(Rink, TEXT("corner_radius_m"), bC);
		const double GoalW = NumOr(Rink, TEXT("goal_width_m"), bG);
		const bool bSize = bL && bW;
		const double Corner = bC ? CornerRaw : DefaultCornerM;

		if (bSize && bC && CornerRaw > FMath::Min(L, W) / 2)
			Errors.Add(FString::Printf(TEXT("at /game/rink/corner_radius_m: %s is more than half of the shorter rink side (%s); lower it."), *Num(CornerRaw), *Num(FMath::Min(L, W) / 2)));
		if (bSize && bG && GoalW >= W)
			Errors.Add(FString::Printf(TEXT("at /game/rink/goal_width_m: the net (%s m) must be narrower than the rink (%s m)."), *Num(GoalW), *Num(W)));
		if (bSize && Rink)
		{
			if (FJPtr Obs = Rink->Get(TEXT("obstacles")); Obs && Obs->IsArray())
			{
				for (int32 i = 0; i < Obs->Array.Num(); ++i)
				{
					bool bX, bZ;
					const double X = NumOr(Obs->Array[i], TEXT("x"), bX), Z = NumOr(Obs->Array[i], TEXT("z"), bZ);
					if (bX && bZ && !InsideRink(X, Z, L, W, Corner))
						Errors.Add(FString::Printf(TEXT("at /game/rink/obstacles/%d: the obstacle at [%s, %s] is outside the rink (x within %s to %s, z within %s to %s, allowing %s m for the boards and the rounded corners)."),
							i, *Num(X), *Num(Z), *Num(-L / 2), *Num(L / 2), *Num(-W / 2), *Num(W / 2), *Num(SpawnMarginM)));
				}
			}
		}

		// C-0005 (lane A15): zones sit inside the rink and carry the size their shape needs (validate.mjs checkGame).
		if (Rink) if (FJPtr Zones = Rink->Get(TEXT("zones")); Zones && Zones->IsArray())
		{
			CheckUniqueIds(Zones, TEXT("/game/rink/zones"), TEXT("zone"), Errors);
			for (int32 i = 0; i < Zones->Array.Num(); ++i)
			{
				const FJPtr& Zn = Zones->Array[i];
				if (!Zn || !Zn->IsObject()) continue;
				const FString P = FString::Printf(TEXT("/game/rink/zones/%d"), i);
				bool bX, bZ;
				const double X = NumOr(Zn, TEXT("x"), bX), Z = NumOr(Zn, TEXT("z"), bZ);
				if (bSize && bX && bZ && !InsideRink(X, Z, L, W, Corner))
					Errors.Add(FString::Printf(TEXT("at %s: the zone centre [%s, %s] is outside the rink (x within %s to %s, z within %s to %s, allowing %s m for the boards and the rounded corners)."),
						*P, *Num(X), *Num(Z), *Num(-L / 2), *Num(L / 2), *Num(-W / 2), *Num(W / 2), *Num(SpawnMarginM)));
				FJPtr ShapeV = Zn->Get(TEXT("shape"));
				const FString Shape = ShapeV && ShapeV->IsString() ? ShapeV->String : FString();
				if (Shape == TEXT("rect"))
				{
					if (!Zn->Has(TEXT("w"))) Errors.Add(FString::Printf(TEXT("at %s/w: a rect zone needs w (its length along the rink, 1 to 160 m)."), *P));
					if (!Zn->Has(TEXT("d"))) Errors.Add(FString::Printf(TEXT("at %s/d: a rect zone needs d (its depth across the rink, 1 to 80 m)."), *P));
					if (Zn->Has(TEXT("r"))) Errors.Add(FString::Printf(TEXT("at %s/r: a rect zone has no radius; remove r or make the shape circle."), *P));
				}
				else if (Shape == TEXT("circle"))
				{
					if (!Zn->Has(TEXT("r"))) Errors.Add(FString::Printf(TEXT("at %s/r: a circle zone needs r (its radius, 0.5 to 40 m)."), *P));
					if (Zn->Has(TEXT("w")) || Zn->Has(TEXT("d"))) Errors.Add(FString::Printf(TEXT("at %s: a circle zone has no w or d; remove them or make the shape rect."), *P));
				}
			}
		}

		FJPtr Rules = Game->Get(TEXT("rules"));
		if (Rules && Rules->IsObject())
		{
			if (FJPtr Hooks = Rules->Get(TEXT("hooks")); Hooks && Hooks->IsArray())
			{
				CheckUniqueIds(Hooks, TEXT("/game/rules/hooks"), TEXT("hook"), Errors);
				for (int32 i = 0; i < Hooks->Array.Num(); ++i) CheckHook(Hooks->Array[i], FString::Printf(TEXT("/game/rules/hooks/%d"), i), Errors);
			}
			FJPtr Mode = Rules->Get(TEXT("mode"));
			const FString M = Mode && Mode->IsString() ? Mode->String : FString();
			if (M == TEXT("first_to") && !Rules->Has(TEXT("score_to_win")))
				Errors.Add(TEXT("at /game/rules/score_to_win: mode \"first_to\" needs score_to_win (1 to 9)."));
			if (M == TEXT("timer") && !Rules->Has(TEXT("timer_frames")))
				Errors.Add(TEXT("at /game/rules/timer_frames: mode \"timer\" needs timer_frames (600 to 18000 frames, 60 per second)."));
		}

		FJPtr Sk = Game->Get(TEXT("skater"));
		{
			bool bMin, bSpeed;
			const double CMin = NumOr(Sk, TEXT("check_speed_min"), bMin), Speed = NumOr(Sk, TEXT("speed"), bSpeed);
			if (bMin && bSpeed && CMin > Speed)
				Errors.Add(FString::Printf(TEXT("at /game/skater/check_speed_min: %s is above the skater's top speed %s, so no check could ever land; lower it."), *Num(CMin), *Num(Speed)));
		}

		// C-0005 (lane A14), the mirror of validate.mjs checkGame: effect ids unique and never a built-in, add within the stat's range
		// width (JamStats::Range), zone only with zone_enter/zone_exit and only a rink.zones id; a pickup kind is a built-in or a declared effect id.
		static const TCHAR* Builtins[] = { TEXT("speed"), TEXT("precision"), TEXT("heavy_puck"), TEXT("big_puck"), TEXT("reverse_other") };
		auto IsBuiltin = [](const FString& K) { for (const TCHAR* B : Builtins) if (K == B) return true; return false; };
		const FString BuiltinList = TEXT("\"speed\", \"precision\", \"heavy_puck\", \"big_puck\", \"reverse_other\"");
		TArray<FString> ZoneIds;
		if (Rink) if (FJPtr Zones = Rink->Get(TEXT("zones")); Zones && Zones->IsArray())
			for (const FJPtr& Z : Zones->Array) if (Z->IsObject()) if (FJPtr Id = Z->Get(TEXT("id")); Id && Id->IsString()) ZoneIds.Add(Id->String);
		auto ZoneList = [&]() { return ZoneIds.Num() ? FString::Printf(TEXT("Zones are: %s."), *FString::Join(ZoneIds, TEXT(", "))) : FString(TEXT("There are no zones in game.rink.zones.")); };
		TArray<FString> EffectIds;
		if (FJPtr Effects = Game->Get(TEXT("effects")); Effects && Effects->IsArray())
		{
			CheckUniqueIds(Effects, TEXT("/game/effects"), TEXT("effect"), Errors);
			for (int32 i = 0; i < Effects->Array.Num(); ++i)
			{
				const FJPtr& E = Effects->Array[i];
				if (!E->IsObject()) continue;
				if (FJPtr Id = E->Get(TEXT("id")); Id && Id->IsString())
				{
					if (IsBuiltin(Id->String)) Errors.Add(FString::Printf(TEXT("at /game/effects/%d/id: \"%s\" is a built-in effect; a custom effect needs another id (the built-ins are %s)."), i, *Id->String, *BuiltinList));
					else EffectIds.Add(Id->String);
				}
				if (FJPtr Stats = E->Get(TEXT("stats")); Stats && Stats->IsArray())
				{
					for (int32 j = 0; j < Stats->Array.Num(); ++j)
					{
						const FJPtr& St = Stats->Array[j];
						bool bAdd;
						const double Add = NumOr(St, TEXT("add"), bAdd);
						FJPtr Name = St->IsObject() ? St->Get(TEXT("stat")) : nullptr;
						EJamStat Stat;
						if (!bAdd || !Name || !Name->IsString() || !JamStats::FromName(FName(*Name->String), Stat)) continue;
						double Lo, Hi;
						JamStats::Range(Stat, Lo, Hi);
						if (FMath::Abs(Add) > Hi - Lo)
							Errors.Add(FString::Printf(TEXT("at /game/effects/%d/stats/%d/add: %s is more than the width of the %s range (%s to %s, width %s); keep add within %s to %s."),
								i, j, *Num(Add), *Name->String, *Num(Lo), *Num(Hi), *Num(Hi - Lo), *Num(-(Hi - Lo)), *Num(Hi - Lo)));
					}
				}
				if (FJPtr Zone = E->Get(TEXT("zone")); Zone && Zone->IsString())
				{
					if (!ZoneIds.Contains(Zone->String)) Errors.Add(FString::Printf(TEXT("at /game/effects/%d/zone: \"%s\" is not the id of any zone. %s"), i, *Zone->String, *ZoneList()));
					FJPtr Tr = E->Get(TEXT("trigger"));
					if (Tr && Tr->IsString() && Tr->String != TEXT("zone_enter") && Tr->String != TEXT("zone_exit"))
						Errors.Add(FString::Printf(TEXT("at /game/effects/%d/zone: zone only applies to the triggers \"zone_enter\" and \"zone_exit\", not \"%s\"; remove it or change the trigger."), i, *Tr->String));
				}
			}
		}
		if (FJPtr Pickups = Game->Get(TEXT("pickups")); Pickups && Pickups->IsArray())
		{
			for (int32 i = 0; i < Pickups->Array.Num(); ++i)
			{
				const FJPtr& P = Pickups->Array[i];
				bool bD;
				const double D = NumOr(P, TEXT("duration_frames"), bD);
				if (bD && !(D > 0))
					Errors.Add(FString::Printf(TEXT("at /game/pickups/%d/duration_frames: a pickup effect must last at least 1 frame, found %s."), i, *Num(D)));
				if (!P->IsObject()) continue;
				if (FJPtr K = P->Get(TEXT("kind")); K && K->IsString() && !IsBuiltin(K->String) && !EffectIds.Contains(K->String))
					Errors.Add(FString::Printf(TEXT("at /game/pickups/%d/kind: \"%s\" is not allowed: use a built-in (%s) or the id of an effect declared in game.effects (declared: %s)."),
						i, *K->String, *BuiltinList, EffectIds.Num() ? *FString::Join(EffectIds, TEXT(", ")) : TEXT("none")));
				if (FJPtr Z = P->Get(TEXT("zone")); Z && Z->IsString() && !ZoneIds.Contains(Z->String))
					Errors.Add(FString::Printf(TEXT("at /game/pickups/%d/zone: \"%s\" is not the id of any zone. %s"), i, *Z->String, *ZoneList()));
			}
		}

		// Lane A84 (R-0041 point 3), the mirror of validate.mjs: one mode ability at most; a pickup ability needs pickups to arrive by.
		if (FJPtr Abilities = Game->Get(TEXT("abilities")); Abilities && Abilities->IsArray())
		{
			FJPtr PickupList = Game->Get(TEXT("pickups"));
			const bool bHasPickups = PickupList && PickupList->IsArray() && PickupList->Array.Num() > 0;
			int32 Modes = 0;
			for (int32 i = 0; i < Abilities->Array.Num(); ++i)
			{
				const FJPtr& A = Abilities->Array[i];
				if (!A->IsObject()) continue;
				FJPtr Tr = A->Get(TEXT("trigger"));
				if (!Tr || !Tr->IsString()) continue;
				if (Tr->String == TEXT("mode") && ++Modes > 1)
					Errors.Add(FString::Printf(TEXT("at /game/abilities/%d/trigger: only one ability may have trigger \"mode\" (F is one key); make this one \"pickup\" or remove it."), i));
				if (Tr->String == TEXT("pickup") && !bHasPickups)
					Errors.Add(FString::Printf(TEXT("at /game/abilities/%d/trigger: a \"pickup\" ability is granted by a boost take, but game.pickups is empty; add a pickup or use trigger \"mode\"."), i));
			}
		}

		FJPtr Teams = Game->Get(TEXT("teams"));
		if (Teams && Teams->IsArray())
		{
			CheckUniqueIds(Teams, TEXT("/game/teams"), TEXT("team"), Errors);
			TArray<FString> Colours;
			for (const FJPtr& T : Teams->Array)
			{
				FJPtr C = T->IsObject() ? T->Get(TEXT("colour_hex")) : nullptr;
				Colours.Add(C && C->IsString() ? C->String.ToLower() : FString());
			}
			if (Colours.Num() == 2 && !Colours[0].IsEmpty() && Colours[0] == Colours[1])
				Errors.Add(TEXT("at /game/teams/1/colour_hex: both teams have the same jersey colour; players could not tell them apart."));
			TArray<FString> Players;
			struct FSp { double X, Z; FString P; };
			TArray<FSp> Spawns;
			for (int32 Ti = 0; Ti < Teams->Array.Num(); ++Ti)
			{
				const FJPtr& T = Teams->Array[Ti];
				if (!T->IsObject()) continue;
				FJPtr List = T->Get(TEXT("skaters"));
				if (!List || !List->IsArray()) continue;
				for (int32 Si = 0; Si < List->Array.Num(); ++Si)
				{
					const FJPtr& S = List->Array[Si];
					if (!S->IsObject()) continue;
					const FString P = FString::Printf(TEXT("/game/teams/%d/skaters/%d"), Ti, Si);
					if (FJPtr Role = S->Get(TEXT("role")); Role && Role->IsString() && Role->String == TEXT("player")) Players.Add(P + TEXT("/role"));
					FJPtr Sp = S->Get(TEXT("spawn"));
					if (Sp && Sp->IsArray() && Sp->Array.Num() == 2 && Sp->Array[0]->IsNumber() && Sp->Array[1]->IsNumber())
					{
						const double X = Sp->Array[0]->Number, Z = Sp->Array[1]->Number;
						if (bSize && !InsideRink(X, Z, L, W, Corner))
							Errors.Add(FString::Printf(TEXT("at %s/spawn: the spawn [%s, %s] is outside the rink (x within %s to %s, z within %s to %s, and inside the rounded corners). Move it toward the centre or enlarge the rink."),
								*P, *Num(X), *Num(Z), *Num(-(L / 2 - SpawnMarginM)), *Num(L / 2 - SpawnMarginM), *Num(-(W / 2 - SpawnMarginM)), *Num(W / 2 - SpawnMarginM)));
						for (const FSp& O : Spawns)
						{
							if (FMath::Sqrt(FMath::Square(O.X - X) + FMath::Square(O.Z - Z)) < 1)
								Errors.Add(FString::Printf(TEXT("at %s/spawn: the spawn [%s, %s] is less than 1 m from the spawn at %s; skaters would start inside each other."), *P, *Num(X), *Num(Z), *O.P));
						}
						Spawns.Add({ X, Z, P + TEXT("/spawn") });
					}
				}
			}
			if (Players.Num() != 1)
			{
				const FString Where = Players.Num() ? FString::Printf(TEXT(" (found at %s)"), *FString::Join(Players, TEXT(", "))) : FString();
				Errors.Add(FString::Printf(TEXT("at /game/teams: exactly one skater across both teams must have role \"player\", found %d%s."), Players.Num(), *Where));
			}
		}
	}

	static void CheckEngine(const FJ& Obj, TArray<FString>& Errors)
	{
		if (!Obj.IsObject()) return;
		CheckGame(Obj.Get(TEXT("game")), Errors);
		const int32 Size = Obj.ToCompact().Len();
		const int32 MaxBytes = static_cast<int32>(LimitNum(TEXT("max_json_bytes"), 24000));
		if (Size > MaxBytes) Errors.Add(FString::Printf(TEXT("at /: the cartridge is %d characters; the engine allows at most %d. Shorten lists and text."), Size, MaxBytes));

		CheckTunables(Obj.Get(TEXT("tunables")), Errors);
		CheckValues(Obj, Errors);

		FJPtr RulesL = Obj.Get(TEXT("rules"));
		CheckCount(RulesL, static_cast<int32>(LimitNum(TEXT("max_rules"), 24)), TEXT("/rules"), TEXT("rules"), Errors);
		CheckUniqueIds(RulesL, TEXT("/rules"), TEXT("rule"), Errors);
		if (RulesL && RulesL->IsArray())
			for (int32 i = 0; i < RulesL->Array.Num(); ++i)
				if (RulesL->Array[i]->IsObject()) CheckParams(RulesL->Array[i]->Get(TEXT("params")), FString::Printf(TEXT("/rules/%d/params"), i), Errors);

		FJPtr Ents = Obj.Get(TEXT("entities"));
		CheckCount(Ents, static_cast<int32>(LimitNum(TEXT("max_entities"), 32)), TEXT("/entities"), TEXT("entities"), Errors);
		TMap<FString, int32> EntityIds = CheckUniqueIds(Ents, TEXT("/entities"), TEXT("entity"), Errors);
		if (Ents && Ents->IsArray())
		{
			int64 Total = 0;
			for (int32 i = 0; i < Ents->Array.Num(); ++i)
			{
				const FJPtr& E = Ents->Array[i];
				if (!E->IsObject()) continue;
				FJPtr Count = E->Get(TEXT("count"));
				Total += (Count && Count->IsInteger()) ? static_cast<int64>(Count->Number) : 1;
				CheckParams(E->Get(TEXT("params")), FString::Printf(TEXT("/entities/%d/params"), i), Errors);
			}
			const int32 MaxInst = static_cast<int32>(LimitNum(TEXT("max_total_entity_instances"), 400));
			if (Total > MaxInst)
				Errors.Add(FString::Printf(TEXT("at /entities: the counts add up to %lld entity instances; the engine allows at most %d. Lower some \"count\" values or remove entities."), Total, MaxInst));
		}

		FJPtr Ai = Obj.Get(TEXT("ai"));
		CheckCount(Ai, static_cast<int32>(LimitNum(TEXT("max_ai"), 16)), TEXT("/ai"), TEXT("ai behaviours"), Errors);
		CheckUniqueIds(Ai, TEXT("/ai"), TEXT("ai behaviour"), Errors);
		if (Ai && Ai->IsArray())
		{
			for (int32 i = 0; i < Ai->Array.Num(); ++i)
			{
				const FJPtr& A = Ai->Array[i];
				if (!A->IsObject()) continue;
				CheckParams(A->Get(TEXT("params")), FString::Printf(TEXT("/ai/%d/params"), i), Errors);
				FJPtr Applies = A->Get(TEXT("applies_to"));
				if (Applies && Applies->IsArray() && Ents && Ents->IsArray())
				{
					TArray<FString> Known; EntityIds.GetKeys(Known);
					for (int32 j = 0; j < Applies->Array.Num(); ++j)
					{
						const FJPtr& Ref = Applies->Array[j];
						if (Ref->IsString() && !EntityIds.Contains(Ref->String))
							Errors.Add(FString::Printf(TEXT("at /ai/%d/applies_to/%d: \"%s\" is not the id of any entity. Entity ids are: %s."), i, j, *Ref->String, Known.Num() ? *FString::Join(Known, TEXT(", ")) : TEXT("(none)")));
					}
				}
			}
		}

		if (FJPtr Theme = Obj.Get(TEXT("theme")); Theme && Theme->IsObject())
		{
			CheckCount(Theme->Get(TEXT("palette")), static_cast<int32>(LimitNum(TEXT("max_palette"), 8)), TEXT("/theme/palette"), TEXT("palette colours"), Errors);
			CheckCount(Theme->Get(TEXT("mood_words")), static_cast<int32>(LimitNum(TEXT("max_mood_words"), 8)), TEXT("/theme/mood_words"), TEXT("mood words"), Errors);
			CheckUniqueIds(Theme->Get(TEXT("palette")), TEXT("/theme/palette"), TEXT("palette colour"), Errors, TEXT("name"));
		}

		const FSchemas& S = GetSchemas();
		if (S.Limits)
		{
			if (FJPtr Blocked = S.Limits->Get(TEXT("blocked_terms")); Blocked && Blocked->IsArray() && Blocked->Array.Num())
			{
				TArray<TPair<FString, FString>> Strings;
				CollectStrings(Obj, FString(), Strings);
				for (const auto& PS : Strings)
				{
					const FString Low = PS.Value.ToLower();
					for (const FJPtr& T : Blocked->Array)
					{
						const FString Term = T->IsString() ? T->String : T->ToCompact();
						if (Low.Contains(Term.ToLower()))
						{
							Errors.Add(FString::Printf(TEXT("at %s: the text contains a term that is not allowed in this game (\"%s\"). Reword it."), *Show(PS.Key), *Term));
							break;
						}
					}
				}
			}
		}
	}

	static bool ValidateTree(const FJ& Root, TArray<FString>& OutErrors)
	{
		const FSchemas& S = GetSchemas();
		if (!S.bOk)
		{
			OutErrors.Add(FString::Printf(TEXT("at /: the loader's embedded schema is broken (%s)."), *S.Error));
			return false;
		}
		TArray<FString> Errors;
		const FJPtr* Envelope = S.Files.Find(TEXT("cartridge.schema.json"));
		FCtx Ctx{ TEXT("cartridge.schema.json") };
		Walk(**Envelope, Root, FString(), Ctx, Errors);
		CheckEngine(Root, Errors);
		// Unique, in first-seen order (new Set(errors) in Node).
		for (const FString& E : Errors) OutErrors.AddUnique(E);
		return OutErrors.Num() == 0;
	}
}

// ---------------------------------------------------------------------------------------------------------------------
// Loader
// ---------------------------------------------------------------------------------------------------------------------

namespace
{
	using FJPtr = TSharedPtr<FJamJson>;

	FJPtr Obj(const FJPtr& Parent, const TCHAR* Key)
	{
		if (!Parent) return nullptr;
		FJPtr V = Parent->Get(Key);
		return (V && V->IsObject()) ? V : nullptr;
	}

	// Named ReadNumber / ReadInteger (not ReadNum / ReadInt): lane A14 defines ReadNum / ReadInt with another return type in Effects/JamEffectTypes.cpp,
	// and UBT unity builds put both files in one translation unit (C2264), lane A16, R-0003 point 5.
	void ReadNumber(const FJPtr& O, const TCHAR* Key, double& Out) { if (O) if (FJPtr V = O->Get(Key); V && V->IsNumber()) Out = V->Number; }
	void ReadInteger(const FJPtr& O, const TCHAR* Key, int32& Out) { if (O) if (FJPtr V = O->Get(Key); V && V->IsNumber()) Out = static_cast<int32>(V->Number); }
	void ReadBool(const FJPtr& O, const TCHAR* Key, bool& Out) { if (O) if (FJPtr V = O->Get(Key); V && V->IsBool()) Out = V->Bool; }
	void ReadName(const FJPtr& O, const TCHAR* Key, FName& Out) { if (O) if (FJPtr V = O->Get(Key); V && V->IsString()) Out = FName(*V->String); }
	void ReadStr(const FJPtr& O, const TCHAR* Key, FString& Out) { if (O) if (FJPtr V = O->Get(Key); V && V->IsString()) Out = V->String; }
	void ReadColour(const FJPtr& O, const TCHAR* Key, FLinearColor& Out) { if (O) if (FJPtr V = O->Get(Key); V && V->IsString()) UJamCartridge::HexToLinear(V->String, Out); }

	// C-0005 (lane A15): one game.rules.hooks[] entry.
	FJamRuleHookConfig ReadHook(const FJPtr& H)
	{
		FJamRuleHookConfig Out;
		ReadStr(H, TEXT("id"), Out.Id);
		ReadName(H, TEXT("when"), Out.When);
		ReadInteger(H, TEXT("every_frames"), Out.EveryFrames);
		ReadInteger(H, TEXT("after_frame"), Out.AfterFrame);
		ReadName(H, TEXT("team"), Out.Team);
		if (FJPtr Sc = Obj(H, TEXT("score")))
		{
			Out.Score.bHas = true;
			ReadInteger(Sc, TEXT("at_least"), Out.Score.AtLeast);
			ReadInteger(Sc, TEXT("at_most"), Out.Score.AtMost);
			ReadInteger(Sc, TEXT("lead_at_least"), Out.Score.LeadAtLeast);
		}
		if (H) if (FJPtr Then = H->Get(TEXT("then")); Then && Then->IsArray())
		{
			for (const FJPtr& A : Then->Array)
			{
				FJamRuleActionConfig Ac;
				ReadName(A, TEXT("do"), Ac.Do);
				ReadName(A, TEXT("team"), Ac.Team);
				if (A && A->Has(TEXT("value"))) { Ac.bHasValue = true; ReadNumber(A, TEXT("value"), Ac.Value); }
				ReadName(A, TEXT("param"), Ac.Param);
				ReadName(A, TEXT("kind"), Ac.Kind);
				ReadInteger(A, TEXT("frames"), Ac.Frames);
				ReadStr(A, TEXT("text"), Ac.Text);
				Out.Then.Add(Ac);
			}
		}
		return Out;
	}

	FJamRuleActionConfig MakeAction(const TCHAR* Do, const TCHAR* Team = nullptr, bool bHasValue = false, double Value = 0, const FString& Text = FString())
	{
		FJamRuleActionConfig A;
		A.Do = FName(Do);
		if (Team) A.Team = FName(Team);
		A.bHasValue = bHasValue;
		A.Value = Value;
		A.Text = Text;
		return A;
	}

	// C-0005 (lane A15): game.rules.variants -> hooks, appended after the explicit hooks. Mirror of expandVariants in schema/validate.mjs
	// (the test rules.test.mjs checks the two agree on hockey.chaos). sudden_death is armed from frame 600 so every match lasts 10 s.
	void ExpandVariants(FJamRulesConfig& R)
	{
		const FJamRuleVariantsConfig& V = R.Variants;
		if (V.bSuddenDeath)
		{
			FJamRuleHookConfig H; H.Id = TEXT("variant-sudden-death"); H.When = TEXT("on_goal"); H.AfterFrame = 600; H.bFromVariant = true;
			H.Then.Add(MakeAction(TEXT("end_match"), TEXT("scoring")));
			H.Then.Add(MakeAction(TEXT("announce"), nullptr, false, 0, TEXT("SUDDEN DEATH: that goal wins it")));
			R.Hooks.Add(H);
		}
		if (V.bLastGoalDouble && R.Mode == FName(TEXT("first_to")) && R.ScoreToWin > 0)
		{
			FJamRuleHookConfig H; H.Id = TEXT("variant-last-goal-double"); H.When = TEXT("on_goal"); H.bFromVariant = true;
			H.Score.bHas = true; H.Score.AtLeast = R.ScoreToWin;
			H.Then.Add(MakeAction(TEXT("add_score"), TEXT("scoring"), true, 1));
			H.Then.Add(MakeAction(TEXT("announce"), nullptr, false, 0, TEXT("LAST GOAL COUNTS DOUBLE")));
			R.Hooks.Add(H);
		}
		if (V.MercyGoals > 0)
		{
			FJamRuleHookConfig H; H.Id = TEXT("variant-mercy"); H.When = TEXT("on_goal"); H.bFromVariant = true;
			H.Score.bHas = true; H.Score.LeadAtLeast = V.MercyGoals;
			H.Then.Add(MakeAction(TEXT("end_match"), TEXT("scoring")));
			H.Then.Add(MakeAction(TEXT("announce"), nullptr, false, 0, FString::Printf(TEXT("MERCY: a lead of %d ends it"), V.MercyGoals)));
			R.Hooks.Add(H);
		}
		if (V.PeriodCount > 1)
		{
			FJamRuleHookConfig H; H.Id = TEXT("variant-periods"); H.When = TEXT("on_frame"); H.Team = TEXT("any"); H.bFromVariant = true;
			H.EveryFrames = (R.Mode == FName(TEXT("timer")) && R.TimerFrames > 0) ? FMath::Max(60, R.TimerFrames / V.PeriodCount) : 3600;
			H.Then.Add(MakeAction(TEXT("end_period")));
			R.Hooks.Add(H);
		}
		if (V.ShrinkPerGoal > 0)
		{
			FJamRuleHookConfig H; H.Id = TEXT("variant-shrink-per-goal"); H.When = TEXT("on_goal"); H.Team = TEXT("any"); H.bFromVariant = true;
			H.Then.Add(MakeAction(TEXT("shrink_rink"), nullptr, true, V.ShrinkPerGoal));
			H.Then.Add(MakeAction(TEXT("announce"), nullptr, false, 0, FString::Printf(TEXT("THE RINK SHRINKS %d%%"), FMath::RoundToInt32(V.ShrinkPerGoal * 100))));
			R.Hooks.Add(H);
		}
	}

	void FillGame(const FJPtr& G, FJamGameConfig& C)
	{
		// Defaults are the struct initialisers (schema/DEFAULTS.md); a present key overrides them.
		FJPtr Rink = Obj(G, TEXT("rink"));
		ReadNumber(Rink, TEXT("length_m"), C.Rink.LengthM);
		ReadNumber(Rink, TEXT("width_m"), C.Rink.WidthM);
		ReadNumber(Rink, TEXT("corner_radius_m"), C.Rink.CornerRadiusM);
		ReadNumber(Rink, TEXT("board_restitution"), C.Rink.BoardRestitution);
		ReadNumber(Rink, TEXT("ice_friction"), C.Rink.IceFriction);
		ReadNumber(Rink, TEXT("goal_width_m"), C.Rink.GoalWidthM);
		ReadNumber(Rink, TEXT("goal_height_m"), C.Rink.GoalHeightM);   // R-0033 point 2 (lane A50)
		if (Rink) if (FJPtr Obs = Rink->Get(TEXT("obstacles")); Obs && Obs->IsArray())
		{
			for (const FJPtr& O : Obs->Array)
			{
				FJamObstacle Ob;
				ReadName(O, TEXT("kind"), Ob.Kind);
				ReadNumber(O, TEXT("x"), Ob.X);
				ReadNumber(O, TEXT("z"), Ob.Z);
				ReadNumber(O, TEXT("size"), Ob.Size);
				C.Rink.Obstacles.Add(Ob);
			}
		}
		// C-0005 (lane A15): zones.
		if (Rink) if (FJPtr Zones = Rink->Get(TEXT("zones")); Zones && Zones->IsArray())
		{
			for (const FJPtr& Zn : Zones->Array)
			{
				FJamZoneConfig Zc;
				ReadStr(Zn, TEXT("id"), Zc.Id);
				ReadName(Zn, TEXT("shape"), Zc.Shape);
				ReadNumber(Zn, TEXT("x"), Zc.X);
				ReadNumber(Zn, TEXT("z"), Zc.Z);
				ReadNumber(Zn, TEXT("w"), Zc.W);
				ReadNumber(Zn, TEXT("d"), Zc.D);
				ReadNumber(Zn, TEXT("r"), Zc.R);
				ReadName(Zn, TEXT("kind"), Zc.Kind);
				ReadNumber(Zn, TEXT("strength"), Zc.Strength);
				ReadBool(Zn, TEXT("visible"), Zc.bVisible);
				C.Rink.Zones.Add(Zc);
			}
		}

		FJPtr Sk = Obj(G, TEXT("skater"));
		ReadNumber(Sk, TEXT("speed"), C.Skater.Speed);
		ReadNumber(Sk, TEXT("accel"), C.Skater.Accel);
		ReadNumber(Sk, TEXT("turn_rate"), C.Skater.TurnRate);
		ReadNumber(Sk, TEXT("lateral_grip"), C.Skater.LateralGrip);
		ReadNumber(Sk, TEXT("mass"), C.Skater.Mass);
		ReadNumber(Sk, TEXT("glide_drag"), C.Skater.GlideDrag);
		ReadNumber(Sk, TEXT("brake_decel"), C.Skater.BrakeDecel);
		ReadBool(Sk, TEXT("check_enabled"), C.Skater.bCheckEnabled);
		ReadNumber(Sk, TEXT("check_speed_min"), C.Skater.CheckSpeedMin);
		ReadInteger(Sk, TEXT("knockdown_frames"), C.Skater.KnockdownFrames);
		ReadName(Sk, TEXT("visual"), C.Skater.Visual);
		ReadNumber(Sk, TEXT("pass_speed"), C.Skater.PassSpeed);
		ReadInteger(Sk, TEXT("pass_lead_frames"), C.Skater.PassLeadFrames);
		ReadNumber(Sk, TEXT("carry_speed_mult"), C.Skater.CarrySpeedMult);   // lane A82 (R-0041 point 6)
		ReadNumber(Sk, TEXT("free_speed_mult"), C.Skater.FreeSpeedMult);   // lane A185 (track F2 evolution 9, R-0064 point 2)
		ReadBool(Sk, TEXT("charge_dies_on_loss"), C.Skater.bChargeDiesOnLoss);   // lane A203 (track K1 evolution 4): false = the neutral value
		ReadNumber(Sk, TEXT("reverse_brake_decel"), C.Skater.ReverseBrakeDecel);   // lane A93 (R-0045 law 3)
		// Lane A93 (R-0045 law 3): game.skater.burst { frames, accel_mult }
		if (const FJPtr Bu = Obj(Sk, TEXT("burst")))
		{
			ReadInteger(Bu, TEXT("frames"), C.Skater.BurstFrames);
			ReadNumber(Bu, TEXT("accel_mult"), C.Skater.BurstAccelMult);
			ReadBool(Bu, TEXT("own_stop"), C.Skater.bBurstOwnStop);   // lane A121 (track F2): the first step is earned by a stop or a cut of the skater's own
			ReadInteger(Bu, TEXT("rest_frames"), C.Skater.BurstRestFrames);   // lane A128 (track F2): and by standing still (the standing start)
			ReadNumber(Bu, TEXT("rest_kept_mps"), C.Skater.BurstRestKeptMps);   // lane A147 (track F2): a bump, a slide or a turn on the spot does not spend it
		}
		// R-0029 point 4 (lane A39): game.skater.breakaway { speed_bonus, frames }
		if (const FJPtr Ba = Obj(Sk, TEXT("breakaway")))
		{
			ReadNumber(Ba, TEXT("speed_bonus"), C.Skater.BreakawaySpeedBonus);
			ReadInteger(Ba, TEXT("frames"), C.Skater.BreakawayFrames);
		}
		// Lane A49: game.skater.sprint { bonus, drain_frames, refill_frames }
		if (const FJPtr Sp = Obj(Sk, TEXT("sprint")))
		{
			ReadNumber(Sp, TEXT("bonus"), C.Skater.SprintBonus);
			ReadInteger(Sp, TEXT("drain_frames"), C.Skater.SprintDrainFrames);
			ReadInteger(Sp, TEXT("refill_frames"), C.Skater.SprintRefillFrames);
			ReadNumber(Sp, TEXT("carry_bonus"), C.Skater.SprintCarryBonus);   // lane A93 (R-0045 law 4)
		}
		// R-0035 (lane A52): game.skater.goalie { reach_m, block_height_m }
		if (const FJPtr Gk = Obj(Sk, TEXT("goalie")))
		{
			ReadNumber(Gk, TEXT("reach_m"), C.Skater.GoalieReachM);
			ReadNumber(Gk, TEXT("block_height_m"), C.Skater.GoalieBlockHeightM);
			ReadNumber(Gk, TEXT("read_mps"), C.Skater.GoalieReadMps);   // lane A207
			ReadNumber(Gk, TEXT("read_max_m"), C.Skater.GoalieReadMaxM);
		}
		// Lane A51 (R-0034): game.skater.spin { frames, cooldown_frames, speed_mult, stamina_cost }
		if (const FJPtr Sn = Obj(Sk, TEXT("spin")))
		{
			ReadInteger(Sn, TEXT("frames"), C.Skater.SpinFrames);
			ReadInteger(Sn, TEXT("cooldown_frames"), C.Skater.SpinCooldownFrames);
			ReadNumber(Sn, TEXT("speed_mult"), C.Skater.SpinSpeedMult);
			ReadNumber(Sn, TEXT("stamina_cost"), C.Skater.SpinStaminaCost);
			ReadInteger(Sn, TEXT("exposed_frames"), C.Skater.SpinExposedTail);   // lane A128 (track F2): the spin's price, its exposed end
		}

		const FJPtr St = G->Get(TEXT("stick"));
		ReadNumber(St, TEXT("reach_m"), C.Stick.ReachM);
		ReadInteger(St, TEXT("poke_window_frames"), C.Stick.PokeWindowFrames);
		ReadNumber(St, TEXT("lift_range_m"), C.Stick.LiftRangeM);
		ReadNumber(St, TEXT("lift_cone_deg"), C.Stick.LiftConeDeg);   // lane A95 (B-to-A-0037)
		ReadInteger(St, TEXT("stumble_frames"), C.Stick.StumbleFrames);
		ReadInteger(St, TEXT("foul_grace_frames"), C.Stick.FoulGraceFrames);
		ReadNumber(St, TEXT("reception_m"), C.Stick.ReceptionM);   // lane A46
		ReadNumber(St, TEXT("mouse_sensitivity"), C.Stick.MouseSensitivity);
		ReadNumber(St, TEXT("carry_reach_mult"), C.Stick.CarryReachMult);   // lane A93 (R-0045 law 4)
		ReadBool(St, TEXT("body_shield"), C.Stick.bBodyShield);   // lane A102 (track F2): puck protection with the body
		ReadBool(St, TEXT("passive_take"), C.Stick.bPassiveTake);   // lane A102 (R-0048): false = a carried puck leaves its carrier only by a press
		ReadInteger(St, TEXT("take_grace_frames"), C.Stick.TakeGraceFrames);   // lane A121 (R-0049 point 2): no poke or lift on a skater that just won the puck
		ReadNumber(St, TEXT("poke_assist_deg"), C.Stick.PokeAssistDeg);   // lane A152 (track F2, R-0059 point 4): a person's poke reaches for a carried puck inside its stick's reach
		ReadInteger(St, TEXT("stop_grace_frames"), C.Stick.StopGraceFrames);   // lane A163: a person's stop with the puck earns the take grace
		ReadInteger(St, TEXT("miss_recovery_frames"), C.Stick.MissRecoveryFrames);   // lane A152: a missed poke locks the stick instead of the stumble
		// Lane A208 (track F0): game.stick.pickup { arc_m, arc_deg, body, sting_mps }: the loose puck is his who touches it
		if (const FJPtr Pu = Obj(St, TEXT("pickup")))
		{
			ReadNumber(Pu, TEXT("arc_m"), C.Stick.PickupArcM);
			ReadNumber(Pu, TEXT("arc_deg"), C.Stick.PickupArcDeg);
			ReadNumber(Pu, TEXT("pass_arc_m"), C.Stick.PickupPassArcM);   // lane A207 (wave 2c)
			ReadNumber(Pu, TEXT("pass_arc_deg"), C.Stick.PickupPassArcDeg);
			ReadBool(Pu, TEXT("body"), C.Stick.bPickupBody);
			ReadNumber(Pu, TEXT("sting_mps"), C.Stick.PickupStingMps);
			ReadNumber(Pu, TEXT("body_catch_mps"), C.Stick.PickupBodyCatchMps);
			ReadBool(Pu, TEXT("block_carried"), C.Stick.bPickupBlockCarried);
		}
		// Lane A208 (the eye's list 1): game.stick.faceoff { centre_gap_m, winner_shield_frames, no_hit_frames, no_hit_m }
		if (const FJPtr Fo = Obj(St, TEXT("faceoff")))
		{
			ReadNumber(Fo, TEXT("centre_gap_m"), C.Stick.FaceoffCentreGapM);
			ReadInteger(Fo, TEXT("winner_shield_frames"), C.Stick.FaceoffWinnerShieldFrames);
			ReadInteger(Fo, TEXT("no_hit_frames"), C.Stick.FaceoffNoHitFrames);
			ReadNumber(Fo, TEXT("no_hit_m"), C.Stick.FaceoffNoHitM);
		}
		// R-0029 point 4 (lane A39): game.stick.deke { offset_m, commit_frames }
		if (const FJPtr Dk = Obj(St, TEXT("deke")))
		{
			ReadNumber(Dk, TEXT("offset_m"), C.Stick.DekeOffsetM);
			ReadInteger(Dk, TEXT("commit_frames"), C.Stick.DekeCommitFrames);
		}
		// Lane A51 (R-0034): game.stick.sweep { min_deg_per_frame, shield_frames, bot_react_frames }
		if (const FJPtr Sw = Obj(St, TEXT("sweep")))
		{
			ReadNumber(Sw, TEXT("min_deg_per_frame"), C.Stick.SweepMinDegPerFrame);
			ReadInteger(Sw, TEXT("shield_frames"), C.Stick.SweepShieldFrames);
			ReadInteger(Sw, TEXT("bot_react_frames"), C.Stick.SweepBotReactFrames);
			ReadNumber(Sw, TEXT("sprint_shield_mult"), C.Stick.SweepSprintShieldMult);   // lane A93 (R-0045 law 4)
		}

		FJPtr Pk = Obj(G, TEXT("puck"));
		UJamCartridge::HexToLinear(TEXT("#111111"), C.Puck.Colour);
		ReadNumber(Pk, TEXT("radius_m"), C.Puck.RadiusM);
		ReadNumber(Pk, TEXT("max_speed"), C.Puck.MaxSpeed);
		ReadNumber(Pk, TEXT("drag"), C.Puck.Drag);
		ReadColour(Pk, TEXT("colour_hex"), C.Puck.Colour);
		ReadNumber(Pk, TEXT("carry_assist"), C.Puck.CarryAssist);
		ReadInteger(Pk, TEXT("count"), C.Puck.Count);
		// R-0035 (lane A52): the lifted puck
		ReadNumber(Pk, TEXT("gravity_mps2"), C.Puck.GravityMps2);
		ReadNumber(Pk, TEXT("ice_restitution"), C.Puck.IceRestitution);
		if (const FJPtr Nt = Obj(Pk, TEXT("net"))) { ReadBool(Nt, TEXT("own_wall"), C.Puck.bNetOwnWall); ReadBool(Nt, TEXT("mouth_only"), C.Puck.bNetMouthOnly); }   // lane A208: game.puck.net

		FJPtr Shot = Obj(G, TEXT("shot"));
		ReadNumber(Shot, TEXT("reach_m"), C.Shot.ReachM);
		ReadNumber(Shot, TEXT("speed"), C.Shot.Speed);
		ReadInteger(Shot, TEXT("cooldown_frames"), C.Shot.CooldownFrames);
		if (Shot && Shot->Has(TEXT("aim_cone_deg"))) { C.Shot.bHasAimCone = true; ReadNumber(Shot, TEXT("aim_cone_deg"), C.Shot.AimConeDeg); }
		ReadInteger(Shot, TEXT("charge_frames_max"), C.Shot.ChargeFramesMax);
		ReadNumber(Shot, TEXT("charge_speed_bonus"), C.Shot.ChargeSpeedBonus);
		ReadInteger(Shot, TEXT("tap_frames"), C.Shot.TapFrames);   // R-0044 (lane A91)
		ReadNumber(Shot, TEXT("speed_scale"), C.Shot.SpeedScale);   // lane A207
		ReadNumber(Shot, TEXT("fade_m"), C.Shot.FadeM);   // lane A207 (wave 2b)
		ReadBool(Shot, TEXT("deflect"), C.Shot.bDeflect);
		// R-0029 point 4 (lane A39): game.shot.one_timer { window_frames, cone_bonus_deg }
		if (const FJPtr Ot = Obj(Shot, TEXT("one_timer")))
		{
			ReadInteger(Ot, TEXT("window_frames"), C.Shot.OneTimerWindowFrames);
			ReadNumber(Ot, TEXT("cone_bonus_deg"), C.Shot.OneTimerConeBonusDeg);
		}
		// R-0035 (lane A52): game.shot.lift { tap_m, half_m, full_m, half_frames }
		if (const FJPtr Lf = Obj(Shot, TEXT("lift")))
		{
			ReadNumber(Lf, TEXT("tap_m"), C.Shot.LiftTapM);
			ReadNumber(Lf, TEXT("half_m"), C.Shot.LiftHalfM);
			ReadNumber(Lf, TEXT("full_m"), C.Shot.LiftFullM);
			ReadInteger(Lf, TEXT("half_frames"), C.Shot.LiftHalfFrames);
		}
		// Lane A77 (R-0036): game.pass.saucer { half_frames, lift_m }
		if (const FJPtr Ps = Obj(G, TEXT("pass")))
		{
			if (const FJPtr Sc = Obj(Ps, TEXT("saucer")))
			{
				ReadInteger(Sc, TEXT("half_frames"), C.Pass.SaucerHalfFrames);
				ReadNumber(Sc, TEXT("lift_m"), C.Pass.SaucerLiftM);
			}
			// Lane A207: game.pass.power { full_frames, reach_share, arrive_mps }, game.pass.aim { cone_deg }, catch_m, clear_own_body
			if (const FJPtr Pw = Obj(Ps, TEXT("power")))
			{
				ReadInteger(Pw, TEXT("full_frames"), C.Pass.PowerFullFrames);
				ReadNumber(Pw, TEXT("reach_share"), C.Pass.PowerReachShare);
				ReadNumber(Pw, TEXT("arrive_mps"), C.Pass.PowerArriveMps);
			}
			if (const FJPtr Am = Obj(Ps, TEXT("aim"))) ReadNumber(Am, TEXT("cone_deg"), C.Pass.AimConeDeg);
			ReadNumber(Ps, TEXT("catch_m"), C.Pass.CatchM);
			ReadBool(Ps, TEXT("clear_own_body"), C.Pass.bClearOwnBody);
		}
		// Lane A92 (R-0045): game.contact, contact by momentum (absent = the defaults; the neutral block is momentum false + carrier_can_hit true).
		if (const FJPtr Ct = Obj(G, TEXT("contact")))
		{
			ReadBool(Ct, TEXT("momentum"), C.Contact.bMomentum);
			ReadBool(Ct, TEXT("carrier_can_hit"), C.Contact.bCarrierCanHit);
			ReadNumber(Ct, TEXT("lunge_mps"), C.Contact.LungeMps);
			ReadNumber(Ct, TEXT("thrust_mps"), C.Contact.ThrustMps);
			ReadNumber(Ct, TEXT("cross_reach_m"), C.Contact.CrossReachM);
			ReadNumber(Ct, TEXT("stability_mps"), C.Contact.StabilityMps);
			ReadNumber(Ct, TEXT("stand_speed_mps"), C.Contact.StandSpeedMps);
			ReadNumber(Ct, TEXT("stand_brace"), C.Contact.StandBrace);
			ReadNumber(Ct, TEXT("speed_stability"), C.Contact.SpeedStability);
			ReadNumber(Ct, TEXT("sprint_stability"), C.Contact.SprintStability);
			ReadNumber(Ct, TEXT("spin_stability"), C.Contact.SpinStability);
			ReadNumber(Ct, TEXT("unseen_stability"), C.Contact.UnseenStability);
			ReadNumber(Ct, TEXT("bump_ratio"), C.Contact.BumpRatio);
			ReadNumber(Ct, TEXT("loose_ratio"), C.Contact.LooseRatio);
			ReadNumber(Ct, TEXT("down_ratio"), C.Contact.DownRatio);
			ReadNumber(Ct, TEXT("down_full_ratio"), C.Contact.DownFullRatio);
			ReadInteger(Ct, TEXT("down_frames_min"), C.Contact.DownFramesMin);
			ReadInteger(Ct, TEXT("down_frames_max"), C.Contact.DownFramesMax);
			ReadInteger(Ct, TEXT("stagger_frames"), C.Contact.StaggerFrames);
			ReadNumber(Ct, TEXT("board_bonus"), C.Contact.BoardBonus);   // lane A101 (track F1): the boards are a body; 1 = the neutral value
			ReadInteger(Ct, TEXT("release_grace_frames"), C.Contact.ReleaseGraceFrames);   // lane A113 (R-0049 point 1): 0 = the neutral value
			ReadNumber(Ct, TEXT("check_reach_m"), C.Contact.CheckReachM);   // lane A125 (track F1): the check finds its man; 0 = the neutral value
			ReadNumber(Ct, TEXT("downed_radius_m"), C.Contact.DownedRadiusM);   // lane A157 (track F1): nobody stands in a man who is down; 0 = the neutral value
			ReadInteger(Ct, TEXT("check_cooldown_frames"), C.Contact.CheckCooldownFrames);   // lane A157: a check press has a cooldown; 0 = the neutral value
			ReadBool(Ct, TEXT("check_cooldown_restart"), C.Contact.bCheckCooldownRestart);   // lane A165: a press inside the cooldown restarts it; false = the neutral value
			ReadInteger(Ct, TEXT("board_slam_frames"), C.Contact.BoardSlamFrames);   // lane A165: the board slam, earned and paid; 0 = the neutral value
			ReadInteger(Ct, TEXT("take_shield_frames"), C.Contact.TakeShieldFrames);   // lane A177: a hit inside a carry's first frames is capped at a stumble; 0 = the neutral value
			ReadBool(Ct, TEXT("take_shield_human_side"), C.Contact.bTakeShieldHumanSide);   // lane A177: only for a side with a human on it; false = every skater
			ReadInteger(Ct, TEXT("take_shield_stagger_max"), C.Contact.TakeShieldStaggerMax);   // lane A177: the capped hit's stumble scales up to this; 0 = flat
			ReadInteger(Ct, TEXT("lunge_frames"), C.Contact.LungeFrames);   // lane A157: the lunge as a motion; 0 = the neutral value
			ReadNumber(Ct, TEXT("lunge_step_mps"), C.Contact.LungeStepMps);   // lane A157: its forward step; 0 = the neutral value
			ReadBool(Ct, TEXT("cross_hold"), C.Contact.bCrossHold);   // lane A184: the held cross-check; false = the neutral value
			ReadInteger(Ct, TEXT("check_windup_frames"), C.Contact.CheckWindupFrames);   // lane A184: the body check's wind-up; 0 = the neutral value
			ReadInteger(Ct, TEXT("cross_windup_frames"), C.Contact.CrossWindupFrames);   // lane A184: the cross-check's wind-up; 0 = the neutral value
			ReadInteger(Ct, TEXT("bot_check_windup_frames"), C.Contact.BotCheckWindupFrames);   // lane A200: the bots' own; absent = the shared value
			ReadInteger(Ct, TEXT("bot_cross_windup_frames"), C.Contact.BotCrossWindupFrames);   // lane A200: the bots' own; absent = the shared value
			ReadNumber(Ct, TEXT("check_pull_m"), C.Contact.CheckPullM);   // lane A209: the human's hit finds its man in the wind-up; 0 = the neutral value
			ReadBool(Ct, TEXT("cross_any_man"), C.Contact.bCrossAnyMan);   // lane A209: the human's cross-check shoves a man without the puck; false = the neutral value
			ReadInteger(Ct, TEXT("cross_live_frames"), C.Contact.CrossLiveFrames);   // lane A215: the cross-check's live window after its wind-up; 0 = the neutral value
			ReadBool(Ct, TEXT("cross_back_human"), C.Contact.bCrossBackHuman);   // lane A215: the human's tap in a carrier's back; false = the neutral value
		}
		// Lane A132 (track F1), measurement only (as JAM_PLAYTESTER_VERBS in JamPlaytester.cpp): with JAM_TEST_SHIELD_SHOVE=0 in the environment every cartridge
		// loads with the shove rule at its neutral value (contact.bShieldShove false: the refusal of main before lane A125; the rule has no key), so the three
		// cells can be played with and without it by the same binaries. Never set in a game or in the gate.
		{
			static const bool bNoShieldShove = FPlatformMisc::GetEnvironmentVariable(TEXT("JAM_TEST_SHIELD_SHOVE")) == TEXT("0");
			if (bNoShieldShove) C.Contact.bShieldShove = false;
		}
		// Lane A151 (track F1), measurement only, the same pattern: JAM_TEST_A151="name=value;..." in the environment sets this lane's rules that have no key
		// yet on every cartridge that loads, so one set of binaries plays each rule alone on paired seeds (tools/perf/results/a151). Never set in a game or the gate.
		{
			static const FString Seam = FPlatformMisc::GetEnvironmentVariable(TEXT("JAM_TEST_A151"));
			if (!Seam.IsEmpty())
			{
				TArray<FString> Pairs;
				Seam.ParseIntoArray(Pairs, TEXT(";"));
				for (const FString& Pair : Pairs)
				{
					FString Name, Value;
					if (!Pair.Split(TEXT("="), &Name, &Value)) continue;
					const double V = FCString::Atod(*Value);
					if (Name == TEXT("side_brace")) C.Contact.StandSideBrace = V;
					else if (Name == TEXT("brace_exchange")) C.Contact.bBraceExchange = V != 0.0;
					else if (Name == TEXT("late_press")) C.Contact.LatePressFrames = FMath::RoundToInt32(V);
					else if (Name == TEXT("take_shield")) C.Contact.TakeShieldFrames = FMath::RoundToInt32(V);   // lane A177: law 3's drill with the take shield on (measurement only)
					else if (Name == TEXT("take_shield_max")) C.Contact.TakeShieldStaggerMax = FMath::RoundToInt32(V);
					else if (Name == TEXT("cross_hold")) C.Contact.bCrossHold = V != 0.0;   // lane A184: law 3's drill and the proofs with the rules on (measurement only)
					else if (Name == TEXT("check_windup")) C.Contact.CheckWindupFrames = FMath::RoundToInt32(V);
					else if (Name == TEXT("cross_windup")) C.Contact.CrossWindupFrames = FMath::RoundToInt32(V);
					else if (Name == TEXT("bot_check_windup")) C.Contact.BotCheckWindupFrames = FMath::RoundToInt32(V);   // lane A200: the gate and law 3 at the bots' arms (measurement only)
					else if (Name == TEXT("bot_cross_windup")) C.Contact.BotCrossWindupFrames = FMath::RoundToInt32(V);
					else if (Name == TEXT("check_reach")) C.Contact.CheckReachM = V;   // lane A209: the arms of tonight (measurement only)
					else if (Name == TEXT("check_pull")) C.Contact.CheckPullM = V;
					else if (Name == TEXT("cross_any")) C.Contact.bCrossAnyMan = V != 0.0;
					else if (Name == TEXT("bot_pull")) C.Contact.BotCheckPullM = V;   // lane A209 wave 3
					else if (Name == TEXT("hold_reset")) C.Contact.bHoldResetAtFaceoff = V != 0.0;   // lane A209: the brace fault's fix off (the neutral proof)
					else if (Name == TEXT("cross_live")) C.Contact.CrossLiveFrames = FMath::RoundToInt32(V);   // lane A215: the live window's arms (measurement only)
					else if (Name == TEXT("cross_back")) C.Contact.bCrossBackHuman = V != 0.0;   // lane A215: measurement only
					else if (Name == TEXT("pickup_off")) { if (V != 0.0) { C.Stick.PickupArcM = 0.0; C.Stick.bPickupBody = false; } }   // lane A215: the cross-check with and without A208's pickup (measurement only)
					// A151-SEAM-MORE
				}
			}
		}

		FJPtr Rules = Obj(G, TEXT("rules"));
		ReadName(Rules, TEXT("mode"), C.Rules.Mode);
		ReadInteger(Rules, TEXT("score_to_win"), C.Rules.ScoreToWin);
		ReadInteger(Rules, TEXT("timer_frames"), C.Rules.TimerFrames);
		ReadInteger(Rules, TEXT("goal_pause_frames"), C.Rules.GoalPauseFrames);
		ReadBool(Rules, TEXT("penalties"), C.Rules.bPenalties);
		ReadInteger(Rules, TEXT("penalty_frames"), C.Rules.PenaltyFrames);   // lane A72 (ask A8)
		// C-0005 (lane A15): hooks as written, then the variants expanded into hooks (schema/validate.mjs expandVariants is the Node mirror).
		if (Rules) if (FJPtr Hooks = Rules->Get(TEXT("hooks")); Hooks && Hooks->IsArray())
		{
			for (const FJPtr& Hk : Hooks->Array) C.Rules.Hooks.Add(ReadHook(Hk));
		}
		if (FJPtr Var = Obj(Rules, TEXT("variants")))
		{
			ReadBool(Var, TEXT("sudden_death"), C.Rules.Variants.bSuddenDeath);
			ReadBool(Var, TEXT("last_goal_double"), C.Rules.Variants.bLastGoalDouble);
			ReadInteger(Var, TEXT("mercy_goals"), C.Rules.Variants.MercyGoals);
			ReadInteger(Var, TEXT("period_count"), C.Rules.Variants.PeriodCount);
			ReadNumber(Var, TEXT("shrink_per_goal"), C.Rules.Variants.ShrinkPerGoal);
			ExpandVariants(C.Rules);
		}

		if (FJPtr Teams = G->Get(TEXT("teams")); Teams && Teams->IsArray())
		{
			for (const FJPtr& T : Teams->Array)
			{
				FJamTeamConfig Team;
				ReadStr(T, TEXT("id"), Team.Id);
				ReadStr(T, TEXT("colour_hex"), Team.ColourHex);
				UJamCartridge::HexToLinear(Team.ColourHex, Team.Colour);
				if (FJPtr List = T->Get(TEXT("skaters")); List && List->IsArray())
				{
					for (const FJPtr& S : List->Array)
					{
						FJamSkaterSpawn Sp;
						ReadName(S, TEXT("role"), Sp.Role);
						if (FJPtr P = S->Get(TEXT("spawn")); P && P->IsArray() && P->Array.Num() == 2)
						{
							Sp.X = P->Array[0]->Number;
							Sp.Z = P->Array[1]->Number;
						}
						Team.Skaters.Add(Sp);
					}
				}
				C.Teams.Add(Team);
			}
		}

		FJPtr Ai = Obj(G, TEXT("ai"));
		ReadNumber(Ai, TEXT("yield_margin_m"), C.Ai.YieldMarginM);
		ReadNumber(Ai, TEXT("yield_radius_m"), C.Ai.YieldRadiusM);
		ReadNumber(Ai, TEXT("hold_radius_m"), C.Ai.HoldRadiusM);
		ReadNumber(Ai, TEXT("speed_scale"), C.Ai.SpeedScale);
		ReadNumber(Ai, TEXT("red_skill"), C.Ai.RedSkill);
		ReadInteger(Ai, TEXT("react_frames"), C.Ai.ReactFrames);   // lane A72 (ask A4)
		ReadNumber(Ai, TEXT("body_check"), C.Ai.BodyCheck);       // lane A72 (ask A5)
		ReadNumber(Ai, TEXT("sprint"), C.Ai.Sprint);              // lane A72 (ask A2)

		if (FJPtr Pickups = G->Get(TEXT("pickups")); Pickups && Pickups->IsArray())
		{
			for (const FJPtr& P : Pickups->Array)
			{
				FJamPickupConfig Pc;
				ReadName(P, TEXT("kind"), Pc.Kind);
				ReadInteger(P, TEXT("spawn_every_frames"), Pc.SpawnEveryFrames);
				ReadInteger(P, TEXT("duration_frames"), Pc.DurationFrames);
				const FString K = Pc.Kind.ToString();
				Pc.Magnitude = K == TEXT("speed") ? 1.5 : K == TEXT("precision") ? 2.0 : K == TEXT("heavy_puck") ? 2.0 : K == TEXT("big_puck") ? 1.5 : 1.0;
				ReadNumber(P, TEXT("magnitude"), Pc.Magnitude);
				C.Pickups.Add(Pc);
			}
		}

		// Lane A84 (R-0041 point 3): game.abilities[]; absent numbers stay 0 and the sim applies the kind's default.
		if (FJPtr Abilities = G->Get(TEXT("abilities")); Abilities && Abilities->IsArray())
		{
			for (const FJPtr& A : Abilities->Array)
			{
				FJamAbilityConfig Ac;
				ReadName(A, TEXT("kind"), Ac.Kind);
				ReadName(A, TEXT("trigger"), Ac.Trigger);
				ReadInteger(A, TEXT("charges"), Ac.Charges);
				ReadInteger(A, TEXT("cooldown_frames"), Ac.CooldownFrames);
				ReadInteger(A, TEXT("duration_frames"), Ac.DurationFrames);
				ReadNumber(A, TEXT("magnitude"), Ac.Magnitude);
				C.Abilities.Add(Ac);
			}
		}

		FJPtr Look = Obj(G, TEXT("look"));
		UJamCartridge::HexToLinear(TEXT("#38BDF8"), C.Look.TrimColour);
		ReadStr(Look, TEXT("tier"), C.Look.Tier);
		ReadColour(Look, TEXT("trim_colour_hex"), C.Look.TrimColour);
		ReadNumber(Look, TEXT("fog_density"), C.Look.FogDensity);
		ReadBool(Look, TEXT("wet_ice"), C.Look.bWetIce);
		ReadNumber(Look, TEXT("trim_emissive"), C.Look.TrimEmissive);   // B-to-A-0018 point 5 (lane A21): absent stays -1 = the tier's default

		FJPtr Cam = Obj(G, TEXT("camera"));
		ReadName(Cam, TEXT("mode"), C.Camera.Mode);
		ReadNumber(Cam, TEXT("distance_m"), C.Camera.DistanceM);
		ReadNumber(Cam, TEXT("height_m"), C.Camera.HeightM);
		ReadNumber(Cam, TEXT("look_ahead_m"), C.Camera.LookAheadM);
		ReadInteger(Cam, TEXT("lag_frames"), C.Camera.LagFrames);
		ReadNumber(Cam, TEXT("fov_deg"), C.Camera.FovDeg);
		ReadBool(Cam, TEXT("radar"), C.Camera.bRadar);
		ReadNumber(Cam, TEXT("boards_margin_m"), C.Camera.BoardsMarginM);
		ReadNumber(Cam, TEXT("end_height_m"), C.Camera.EndHeightM);
		ReadNumber(Cam, TEXT("far_net_bias"), C.Camera.FarNetBias);
	}

	// schema/README.md "Tunables": a tunable named after a game field dials that field.
	void ApplyValues(const FJPtr& Values, FJamGameConfig& C)
	{
		if (!Values || !Values->IsObject()) return;
		for (const auto& KV : Values->Object)
		{
			if (!KV.Value->IsNumber()) continue;
			if (!UJamCartridge::ApplyValueKey(C, KV.Key, KV.Value->Number))
			{
				UE_LOG(LogJamCartridge, Verbose, TEXT("value \"%s\" names no game field; kept for the Designer only"), *KV.Key);
			}
		}
	}
}

bool UJamCartridge::ApplyValueKey(FJamGameConfig& C, const FString& K, double V)
{
	if (K == TEXT("skater_speed")) C.Skater.Speed = V;
	else if (K == TEXT("skater_turn_rate")) C.Skater.TurnRate = V;
	else if (K == TEXT("shot_speed")) C.Shot.Speed = V;
	else if (K == TEXT("puck_max_speed")) C.Puck.MaxSpeed = V;
	else if (K == TEXT("ice_friction")) C.Rink.IceFriction = V;
	else if (K == TEXT("board_restitution")) C.Rink.BoardRestitution = V;
	else if (K == TEXT("ai_speed_scale")) C.Ai.SpeedScale = V;
	else if (K == TEXT("ai_red_skill")) C.Ai.RedSkill = V;
	else if (K == TEXT("goal_pause_frames")) C.Rules.GoalPauseFrames = static_cast<int32>(V);
	else return false;
	return true;
}

// Lane A118 (track S3): the schema range of the game field a set_param tunable names; false for a name that is not one of the nine.
bool UJamCartridge::SetParamRange(const FString& Param, double& OutLo, double& OutHi)
{
	const TCHAR* Field = JamValidate::SetParamField(Param);
	// Lane A141: goal_pause_frames is no hook tunable (its 30..600 lies above the -20..20 value limit) but the sim keeps clamping it for callers that bypass the validators.
	if (!Field && Param == TEXT("goal_pause_frames")) Field = TEXT("rules.goal_pause_frames");
	return Field && JamValidate::GameRange(Field, OutLo, OutHi);
}

bool UJamCartridge::HexToLinear(const FString& Hex, FLinearColor& Out)
{
	if (Hex.Len() != 7 || Hex[0] != '#') return false;
	for (int32 i = 1; i < 7; ++i) if (!FChar::IsHexDigit(Hex[i])) return false;
	const FColor C = FColor::FromHex(Hex);
	Out = FLinearColor::FromSRGBColor(C);
	Out.A = 1.f;
	return true;
}

bool UJamCartridge::Validate(const FString& Json, TArray<FString>& OutErrors)
{
	FString ParseError;
	TSharedPtr<FJamJson> Root = FJamJson::Parse(Json, ParseError);
	if (!Root) { OutErrors.Add(ParseError); return false; }
	return JamValidate::ValidateTree(*Root, OutErrors);
}

UJamCartridge* UJamCartridge::LoadFromString(const FString& Json, TArray<FString>& OutErrors, UObject* Outer)
{
	FString ParseError;
	TSharedPtr<FJamJson> Root = FJamJson::Parse(Json, ParseError);
	if (!Root) { OutErrors.Add(ParseError); return nullptr; }
	if (!JamValidate::ValidateTree(*Root, OutErrors)) return nullptr;

	UJamCartridge* C = NewObject<UJamCartridge>(Outer ? Outer : GetTransientPackage());
	C->RawJson = Json;
	ReadStr(Root, TEXT("id"), C->Id);
	ReadStr(Root, TEXT("title"), C->Title);
	if (FJPtr Theme = Obj(Root, TEXT("theme"))) ReadStr(Theme, TEXT("name"), C->ThemeName);
	if (FJPtr Meta = Obj(Obj(Root, TEXT("game")), TEXT("meta")))
	{
		ReadStr(Meta, TEXT("pitch"), C->MetaPitch);
		if (FJPtr Facts = Meta->Get(TEXT("facts")); Facts && Facts->IsArray())
		{
			for (const FJPtr& F : Facts->Array) if (F && F->IsString()) C->MetaFacts.Add(F->String);
		}
	}
	if (FJPtr Seed = Root->Get(TEXT("seed")); Seed && Seed->IsNumber()) C->Seed = static_cast<int64>(Seed->Number);
	FillGame(Root->Get(TEXT("game")), C->Game);
	ApplyValues(Root->Get(TEXT("values")), C->Game);
	return C;
}

UJamCartridge* UJamCartridge::LoadFromFile(const FString& Path, TArray<FString>& OutErrors, UObject* Outer)
{
	FString Text;
	if (!FFileHelper::LoadFileToString(Text, *Path))
	{
		OutErrors.Add(FString::Printf(TEXT("at /: cannot read the cartridge file %s."), *Path));
		return nullptr;
	}
	UJamCartridge* C = LoadFromString(Text, OutErrors, Outer);
	if (C) C->SourcePath = Path;
	return C;
}

FString UJamCartridge::GetCartridgeDir()
{
	return FPaths::Combine(FPaths::ProjectContentDir(), TEXT("Cartridges"));
}

FString UJamCartridge::ResolveCartridgePath(const FString& NameOrPath)
{
	if (NameOrPath.EndsWith(TEXT(".json"))) return NameOrPath;
	return FPaths::Combine(GetCartridgeDir(), NameOrPath + TEXT(".cartridge.json"));
}
