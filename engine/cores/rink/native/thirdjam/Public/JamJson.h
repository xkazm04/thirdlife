// A strict JSON reader for cartridges: ordered objects (errors come out in file order, as in Node), duplicate keys are
// errors (schema/README.md), numbers are doubles (Number.isInteger semantics for "integer").
#pragma once

#include "CoreMinimal.h"

struct JAMCORE_API FJamJson
{
	enum class EType : uint8 { Null, Bool, Number, String, Array, Object };

	EType Type = EType::Null;
	bool Bool = false;
	double Number = 0;
	FString String;
	TArray<TSharedPtr<FJamJson>> Array;
	TArray<TPair<FString, TSharedPtr<FJamJson>>> Object;

	bool IsObject() const { return Type == EType::Object; }
	bool IsArray() const { return Type == EType::Array; }
	bool IsNumber() const { return Type == EType::Number; }
	bool IsString() const { return Type == EType::String; }
	bool IsBool() const { return Type == EType::Bool; }
	bool IsNull() const { return Type == EType::Null; }
	bool IsInteger() const { return Type == EType::Number && FMath::IsFinite(Number) && FMath::FloorToDouble(Number) == Number; }

	// Object member or null.
	TSharedPtr<FJamJson> Get(const FString& Key) const;
	bool Has(const FString& Key) const { return Get(Key).IsValid(); }

	// Parses Text. On failure returns null and sets OutError to a sentence starting "at <pointer>:".
	static TSharedPtr<FJamJson> Parse(const FString& Text, FString& OutError);

	// Compact serialisation in the style of JSON.stringify (used for the max_json_bytes count).
	FString ToCompact() const;

	// "/a/b" pointer escaping (~ -> ~0, / -> ~1).
	static FString PointerChild(const FString& Ptr, const FString& Key);
	static FString PointerChild(const FString& Ptr, int32 Index) { return Ptr + TEXT("/") + FString::FromInt(Index); }
	static FString Show(const FString& Ptr) { return Ptr.IsEmpty() ? FString(TEXT("/")) : Ptr; }

	// Number formatting like JavaScript's String(n) for the numbers cartridges use.
	static FString NumberToString(double V);
};
