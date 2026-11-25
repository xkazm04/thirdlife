#include "JamJson.h"

namespace
{
	struct FParser
	{
		const TCHAR* S = nullptr;
		int32 Len = 0;
		int32 Pos = 0;
		FString Error;

		bool Fail(const FString& Ptr, const FString& Why)
		{
			if (Error.IsEmpty())
			{
				Error = FString::Printf(TEXT("at %s: the file is not valid JSON (%s at character %d)."), *FJamJson::Show(Ptr), *Why, Pos);
			}
			return false;
		}

		void SkipWs()
		{
			while (Pos < Len && (S[Pos] == ' ' || S[Pos] == '\t' || S[Pos] == '\n' || S[Pos] == '\r')) ++Pos;
		}

		bool ParseString(FString& Out, const FString& Ptr)
		{
			if (Pos >= Len || S[Pos] != '"') return Fail(Ptr, TEXT("expected a string"));
			++Pos;
			Out.Reset();
			while (Pos < Len)
			{
				const TCHAR C = S[Pos++];
				if (C == '"') return true;
				if (C < 0x20) return Fail(Ptr, TEXT("control character in a string"));
				if (C != '\\') { Out.AppendChar(C); continue; }
				if (Pos >= Len) break;
				const TCHAR E = S[Pos++];
				switch (E)
				{
				case '"': Out.AppendChar('"'); break;
				case '\\': Out.AppendChar('\\'); break;
				case '/': Out.AppendChar('/'); break;
				case 'b': Out.AppendChar('\b'); break;
				case 'f': Out.AppendChar('\f'); break;
				case 'n': Out.AppendChar('\n'); break;
				case 'r': Out.AppendChar('\r'); break;
				case 't': Out.AppendChar('\t'); break;
				case 'u':
				{
					if (Pos + 4 > Len) return Fail(Ptr, TEXT("bad \\u escape"));
					uint32 Code = 0;
					for (int32 i = 0; i < 4; ++i)
					{
						const TCHAR H = S[Pos++];
						Code <<= 4;
						if (H >= '0' && H <= '9') Code |= H - '0';
						else if (H >= 'a' && H <= 'f') Code |= H - 'a' + 10;
						else if (H >= 'A' && H <= 'F') Code |= H - 'A' + 10;
						else return Fail(Ptr, TEXT("bad \\u escape"));
					}
					Out.AppendChar(static_cast<TCHAR>(Code));
					break;
				}
				default: return Fail(Ptr, TEXT("bad escape"));
				}
			}
			return Fail(Ptr, TEXT("unterminated string"));
		}

		bool ParseNumber(double& Out, const FString& Ptr)
		{
			const int32 Start = Pos;
			if (Pos < Len && S[Pos] == '-') ++Pos;
			if (Pos >= Len) return Fail(Ptr, TEXT("bad number"));
			if (S[Pos] == '0') { ++Pos; }
			else if (S[Pos] >= '1' && S[Pos] <= '9') { while (Pos < Len && FChar::IsDigit(S[Pos])) ++Pos; }
			else return Fail(Ptr, TEXT("bad number"));
			if (Pos < Len && S[Pos] == '.')
			{
				++Pos;
				if (Pos >= Len || !FChar::IsDigit(S[Pos])) return Fail(Ptr, TEXT("bad number"));
				while (Pos < Len && FChar::IsDigit(S[Pos])) ++Pos;
			}
			if (Pos < Len && (S[Pos] == 'e' || S[Pos] == 'E'))
			{
				++Pos;
				if (Pos < Len && (S[Pos] == '+' || S[Pos] == '-')) ++Pos;
				if (Pos >= Len || !FChar::IsDigit(S[Pos])) return Fail(Ptr, TEXT("bad number"));
				while (Pos < Len && FChar::IsDigit(S[Pos])) ++Pos;
			}
			const FString Lit(Pos - Start, S + Start);
			Out = FCString::Atod(*Lit);
			if (!FMath::IsFinite(Out)) return Fail(Ptr, TEXT("number out of range"));
			return true;
		}

		bool Literal(const TCHAR* Word)
		{
			const int32 N = FCString::Strlen(Word);
			if (Pos + N <= Len && FCString::Strncmp(S + Pos, Word, N) == 0) { Pos += N; return true; }
			return false;
		}

		TSharedPtr<FJamJson> ParseValue(const FString& Ptr, int32 Depth)
		{
			if (Depth > 64) { Fail(Ptr, TEXT("nested too deep")); return nullptr; }
			SkipWs();
			if (Pos >= Len) { Fail(Ptr, TEXT("unexpected end")); return nullptr; }
			TSharedPtr<FJamJson> V = MakeShared<FJamJson>();
			const TCHAR C = S[Pos];
			if (C == '{')
			{
				V->Type = FJamJson::EType::Object;
				++Pos;
				SkipWs();
				if (Pos < Len && S[Pos] == '}') { ++Pos; return V; }
				while (true)
				{
					SkipWs();
					FString Key;
					if (!ParseString(Key, Ptr)) return nullptr;
					const FString ChildPtr = FJamJson::PointerChild(Ptr, Key);
					for (const auto& KV : V->Object)
					{
						if (KV.Key == Key)
						{
							Error = FString::Printf(TEXT("at %s: duplicate key \"%s\"; a key may appear only once in an object."), *FJamJson::Show(ChildPtr), *Key);
							return nullptr;
						}
					}
					SkipWs();
					if (Pos >= Len || S[Pos] != ':') { Fail(Ptr, TEXT("expected ':'")); return nullptr; }
					++Pos;
					TSharedPtr<FJamJson> Child = ParseValue(ChildPtr, Depth + 1);
					if (!Child) return nullptr;
					V->Object.Emplace(Key, Child);
					SkipWs();
					if (Pos < Len && S[Pos] == ',') { ++Pos; continue; }
					if (Pos < Len && S[Pos] == '}') { ++Pos; return V; }
					Fail(Ptr, TEXT("expected ',' or '}'"));
					return nullptr;
				}
			}
			if (C == '[')
			{
				V->Type = FJamJson::EType::Array;
				++Pos;
				SkipWs();
				if (Pos < Len && S[Pos] == ']') { ++Pos; return V; }
				while (true)
				{
					TSharedPtr<FJamJson> Child = ParseValue(FJamJson::PointerChild(Ptr, V->Array.Num()), Depth + 1);
					if (!Child) return nullptr;
					V->Array.Add(Child);
					SkipWs();
					if (Pos < Len && S[Pos] == ',') { ++Pos; continue; }
					if (Pos < Len && S[Pos] == ']') { ++Pos; return V; }
					Fail(Ptr, TEXT("expected ',' or ']'"));
					return nullptr;
				}
			}
			if (C == '"')
			{
				V->Type = FJamJson::EType::String;
				if (!ParseString(V->String, Ptr)) return nullptr;
				return V;
			}
			if (C == '-' || FChar::IsDigit(C))
			{
				V->Type = FJamJson::EType::Number;
				if (!ParseNumber(V->Number, Ptr)) return nullptr;
				return V;
			}
			if (Literal(TEXT("true"))) { V->Type = FJamJson::EType::Bool; V->Bool = true; return V; }
			if (Literal(TEXT("false"))) { V->Type = FJamJson::EType::Bool; V->Bool = false; return V; }
			if (Literal(TEXT("null"))) { V->Type = FJamJson::EType::Null; return V; }
			Fail(Ptr, TEXT("unexpected character"));
			return nullptr;
		}
	};
}

TSharedPtr<FJamJson> FJamJson::Get(const FString& Key) const
{
	for (const auto& KV : Object)
	{
		if (KV.Key == Key) return KV.Value;
	}
	return nullptr;
}

TSharedPtr<FJamJson> FJamJson::Parse(const FString& Text, FString& OutError)
{
	FParser P;
	P.S = *Text;
	P.Len = Text.Len();
	// A UTF-8 byte order mark is tolerated (Node's readFileSync + JSON.parse would not be, but editors add it).
	if (P.Len > 0 && P.S[0] == 0xFEFF) P.Pos = 1;
	TSharedPtr<FJamJson> Root = P.ParseValue(FString(), 0);
	if (Root)
	{
		P.SkipWs();
		if (P.Pos != P.Len) { P.Fail(FString(), TEXT("text after the end of the JSON value")); Root.Reset(); }
	}
	if (!Root) OutError = P.Error;
	return Root;
}

FString FJamJson::PointerChild(const FString& Ptr, const FString& Key)
{
	return Ptr + TEXT("/") + Key.Replace(TEXT("~"), TEXT("~0")).Replace(TEXT("/"), TEXT("~1"));
}

FString FJamJson::NumberToString(double V)
{
	if (FMath::FloorToDouble(V) == V && FMath::Abs(V) < 1e15)
	{
		return FString::Printf(TEXT("%lld"), static_cast<long long>(V));
	}
	// Shortest representation that round-trips, which is what JavaScript prints for ordinary numbers.
	for (int32 Digits = 1; Digits <= 17; ++Digits)
	{
		const FString S = FString::Printf(TEXT("%.*g"), Digits, V);
		if (FCString::Atod(*S) == V) return S;
	}
	return FString::Printf(TEXT("%.17g"), V);
}

static void AppendQuoted(FString& Out, const FString& S)
{
	Out.AppendChar('"');
	for (const TCHAR C : S)
	{
		switch (C)
		{
		case '"': Out += TEXT("\\\""); break;
		case '\\': Out += TEXT("\\\\"); break;
		case '\n': Out += TEXT("\\n"); break;
		case '\r': Out += TEXT("\\r"); break;
		case '\t': Out += TEXT("\\t"); break;
		case '\b': Out += TEXT("\\b"); break;
		case '\f': Out += TEXT("\\f"); break;
		default:
			if (C < 0x20) Out += FString::Printf(TEXT("\\u%04x"), static_cast<uint32>(C));
			else Out.AppendChar(C);
		}
	}
	Out.AppendChar('"');
}

FString FJamJson::ToCompact() const
{
	FString Out;
	switch (Type)
	{
	case EType::Null: return TEXT("null");
	case EType::Bool: return Bool ? TEXT("true") : TEXT("false");
	case EType::Number: return NumberToString(Number);
	case EType::String: AppendQuoted(Out, String); return Out;
	case EType::Array:
		Out.AppendChar('[');
		for (int32 i = 0; i < Array.Num(); ++i) { if (i) Out.AppendChar(','); Out += Array[i]->ToCompact(); }
		Out.AppendChar(']');
		return Out;
	case EType::Object:
		Out.AppendChar('{');
		for (int32 i = 0; i < Object.Num(); ++i)
		{
			if (i) Out.AppendChar(',');
			AppendQuoted(Out, Object[i].Key);
			Out.AppendChar(':');
			Out += Object[i].Value->ToCompact();
		}
		Out.AppendChar('}');
		return Out;
	}
	return Out;
}
