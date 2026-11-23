// Third Life rink core shim: thirdjam's automation tests (IMPLEMENT_SIMPLE_AUTOMATION_TEST + FAutomationTestBase) run outside
// Unreal. A test registers itself; the runner (native/tests/rinktest.cpp) runs them. Semantics as UE 5.9 AutomationTest.h:
// TestEqual of floats and doubles with the default tolerance UE_KINDA_SMALL_NUMBER; AddError fails the test.
#pragma once
#include "CoreMinimal.h"
#include <vector>

// UE 5.9: enum class EAutomationTestFlags with bit operators.
enum class EAutomationTestFlags : uint64 { None = 0, EditorContext = 1 << 0, ClientContext = 1 << 1, ServerContext = 1 << 2, CommandletContext = 1 << 3,
	ProgramContext = 1 << 4, ApplicationContextMask = 0x1f, NonNullRHI = 1 << 8, RequiresUser = 1 << 9, Disabled = 1 << 10, CriticalPriority = 1 << 11,
	HighPriority = 1 << 12, MediumPriority = 1 << 13, LowPriority = 1 << 14, SmokeFilter = 1 << 15, EngineFilter = 1 << 16, ProductFilter = 1 << 17,
	PerfFilter = 1 << 18, StressFilter = 1 << 19, NegativeFilter = 1 << 20, FeatureMask = 0x3f00, PriorityMask = 0x7800, FilterMask = 0x1f8000 };
constexpr EAutomationTestFlags operator|(EAutomationTestFlags A, EAutomationTestFlags B) { return (EAutomationTestFlags)((uint64)A | (uint64)B); }
constexpr EAutomationTestFlags EAutomationTestFlags_ApplicationContextMask = EAutomationTestFlags::ApplicationContextMask;
constexpr EAutomationTestFlags operator&(EAutomationTestFlags A, EAutomationTestFlags B) { return (EAutomationTestFlags)((uint64)A & (uint64)B); }

class FAutomationTestBase;
std::vector<FAutomationTestBase*>& JamShimAutomationTests();

class FAutomationTestBase
{
public:
	FAutomationTestBase(const TCHAR* InName, uint64 InFlags) : Name(InName), Flags(InFlags) { JamShimAutomationTests().push_back(this); }
	virtual ~FAutomationTestBase() = default;
	virtual bool RunTest(const FString& Parameters) = 0;
	const FString& GetTestName() const { return Name; }

	void AddError(const FString& S, int32 = 0) { Errors.Add(S); }
	void AddWarning(const FString& S, int32 = 0) { Warnings.Add(S); }
	void AddInfo(const FString& S, int32 = 0) { Infos.Add(S); }
	bool TestTrue(const TCHAR* What, bool V) { if (!V) AddError(FString::Printf(TEXT("Expected '%s' to be true."), What)); return V; }
	bool TestTrue(const FString& What, bool V) { return TestTrue(*What, V); }
	bool TestFalse(const TCHAR* What, bool V) { if (V) AddError(FString::Printf(TEXT("Expected '%s' to be false."), What)); return !V; }
	bool TestFalse(const FString& What, bool V) { return TestFalse(*What, V); }
	bool TestEqual(const TCHAR* What, double A, double B, double Tol = UE_KINDA_SMALL_NUMBER)
	{
		if (!FMath::IsNearlyEqual(A, B, Tol)) { AddError(FString::Printf(TEXT("Expected '%s' to be %f, but it was %f within tolerance %f."), What, B, A, Tol)); return false; }
		return true;
	}
	bool TestEqual(const TCHAR* What, float A, float B, float Tol = UE_KINDA_SMALL_NUMBER) { return TestEqual(What, (double)A, (double)B, (double)Tol); }
	bool TestEqual(const TCHAR* What, const FVector2D& A, const FVector2D& B, double Tol = UE_KINDA_SMALL_NUMBER)
	{
		if (!A.Equals(B, Tol)) { AddError(FString::Printf(TEXT("Expected '%s' to be (%f,%f), but it was (%f,%f)."), What, B.X, B.Y, A.X, A.Y)); return false; }
		return true;
	}
	bool TestEqual(const TCHAR* What, const FString& A, const FString& B)
	{
		if (!A.Equals(B, ESearchCase::CaseSensitive)) { AddError(FString::Printf(TEXT("Expected '%s' to be \"%s\", but it was \"%s\"."), What, *B, *A)); return false; }
		return true;
	}
	bool TestEqual(const TCHAR* What, const TCHAR* A, const TCHAR* B) { return TestEqual(What, FString(A), FString(B)); }
	bool TestEqual(const TCHAR* What, const FString& A, const TCHAR* B) { return TestEqual(What, A, FString(B)); }
	bool TestEqual(const TCHAR* What, const FName& A, const FName& B)
	{
		if (!(A == B)) { AddError(FString::Printf(TEXT("Expected '%s' to be %s, but it was %s."), What, *B.ToString(), *A.ToString())); return false; }
		return true;
	}
	template <class A, class B, std::enable_if_t<(std::is_integral_v<A> || std::is_enum_v<A>) && (std::is_integral_v<B> || std::is_enum_v<B>), int> = 0>
	bool TestEqual(const TCHAR* What, A Actual, B Expected)
	{
		if ((int64)Actual != (int64)Expected) { AddError(FString::Printf(TEXT("Expected '%s' to be %lld, but it was %lld."), What, (long long)Expected, (long long)Actual)); return false; }
		return true;
	}
	// Any other type with == (TArray, structs): UE's generic TestEqual.
	template <class A, class B, std::enable_if_t<!std::is_arithmetic_v<A> && !std::is_enum_v<A> && !std::is_convertible_v<const A&, FString> && !std::is_same_v<A, FName> && !std::is_same_v<A, FVector2D>, int> = 0>
	bool TestEqual(const TCHAR* What, const A& Actual, const B& Expected)
	{
		if (!(Actual == Expected)) { AddError(FString::Printf(TEXT("Expected '%s' to be equal."), What)); return false; }
		return true;
	}
	template <class A, class B> bool TestEqual(const FString& What, const A& Actual, const B& Expected) { return TestEqual(*What, Actual, Expected); }
	template <class A, class B> bool TestNotEqual(const TCHAR* What, const A& Actual, const B& Expected)
	{
		if (Actual == Expected) { AddError(FString::Printf(TEXT("Expected '%s' to differ."), What)); return false; }
		return true;
	}
	template <class A, class B> bool TestNotEqual(const FString& What, const A& Actual, const B& Expected) { return TestNotEqual(*What, Actual, Expected); }
	template <class T> bool TestNotNull(const TCHAR* What, const T* P) { if (!P) { AddError(FString::Printf(TEXT("Expected '%s' to be not null."), What)); return false; } return true; }
	template <class T> bool TestNotNull(const FString& What, const T* P) { return TestNotNull(*What, P); }
	template <class T> bool TestNull(const TCHAR* What, const T* P) { if (P) { AddError(FString::Printf(TEXT("Expected '%s' to be null."), What)); return false; } return true; }
	template <class T> bool TestValid(const TCHAR* What, const TSharedPtr<T>& P) { return TestTrue(What, P.IsValid()); }
	bool HasAnyErrors() const { return Errors.Num() > 0; }

	FString Name;
	uint64 Flags = 0;
	TArray<FString> Errors, Warnings, Infos;
};

#define IMPLEMENT_SIMPLE_AUTOMATION_TEST(TClass, PrettyName, TFlags) \
	class TClass : public FAutomationTestBase \
	{ \
	public: \
		TClass(const TCHAR* InName) : FAutomationTestBase(InName, (uint64)(TFlags)) {} \
		virtual bool RunTest(const FString& Parameters) override; \
	}; \
	namespace { TClass TClass##AutomationTestInstance(TEXT(PrettyName)); }
#define IMPLEMENT_CUSTOM_SIMPLE_AUTOMATION_TEST(TClass, TBaseClass, PrettyName, TFlags) IMPLEMENT_SIMPLE_AUTOMATION_TEST(TClass, PrettyName, TFlags)
#define UTEST_TRUE(What, V) if (!TestTrue(What, V)) return false
#define UTEST_FALSE(What, V) if (!TestFalse(What, V)) return false
#define UTEST_EQUAL(What, A, B) if (!TestEqual(What, A, B)) return false
