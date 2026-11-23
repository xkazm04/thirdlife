// Third Life rink core shim: thirdjam's pure pawn helpers (verbatim, generated include) and CallFigure without Unreal reflection.
#include "JamPawns.h"
#include "HAL/IConsoleManager.h"
#include "JamEventBus.h"   // JamPawns.cpp:13 (the helpers read JamEvents)

#include "pawn_helpers.gen.inc"

// AJamSkater::CallFigure (JamPawns.cpp:422-451) finds a UFUNCTION by name through reflection and calls it when every parameter
// is a bool or a number and the count matches. No reflection here: the by-name table below is the reflected signatures of the
// one class the tests call it on (UJamFigureCallProbe, JamPawns.h:313-326): PlayStumble(double, double, int32),
// SetBraking(bool, float), PlayWrongShape(FName: not a number). Any other object has none of them. Shim deviation (PATCHES.md).
bool AJamSkater::CallFigure(UObject* Figure, FName Function, std::initializer_list<double> ArgsIn)
{
	UJamFigureCallProbe* P = dynamic_cast<UJamFigureCallProbe*>(Figure);
	if (!P) return false;
	const std::vector<double> Args(ArgsIn);
	if (Function == FName(TEXT("PlayStumble")))
	{
		if (Args.size() != 3) return false;
		P->PlayStumble(Args[0], Args[1], static_cast<int32>(FMath::RoundToInt64(Args[2])));
		return true;
	}
	if (Function == FName(TEXT("SetBraking")))
	{
		if (Args.size() != 2) return false;
		P->SetBraking(Args[0] != 0.0, static_cast<float>(Args[1]));
		return true;
	}
	return false;   // PlayWrongShape takes an FName (not a number): not called; any other name: no such function
}
