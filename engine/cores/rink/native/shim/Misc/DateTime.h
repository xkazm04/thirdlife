// Third Life rink core shim: FDateTime as thirdjam's tests use it (a stamp in a file name).
#pragma once
#include "CoreMinimal.h"
struct FDateTime
{
	static FDateTime Now() { return FDateTime(); }
	FString ToString() const { return FString(TEXT("now")); }
	FString ToString(const TCHAR*) const { return FString(TEXT("now")); }
};
