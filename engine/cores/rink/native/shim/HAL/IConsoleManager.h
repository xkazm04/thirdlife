// Third Life rink core shim: Unreal console variables hold their shipped default (no console here).
#pragma once
#include "CoreMinimal.h"
enum EConsoleVariableFlags { ECVF_Default = 0, ECVF_Cheat = 1, ECVF_ReadOnly = 4, ECVF_Scalability = 8 };
template <class T>
class TAutoConsoleVariable
{
	T Value;
public:
	TAutoConsoleVariable(const TCHAR*, const T& Default, const TCHAR* = nullptr, uint32 = 0) : Value(Default) {}
	T GetValueOnGameThread() const { return Value; }
	T GetValueOnAnyThread() const { return Value; }
	T GetValueOnRenderThread() const { return Value; }
};
