// Third Life rink core: the Unreal shim. thirdjam's JamCore sources compile against this header set unchanged.
// It carries only what JamCore uses, with Unreal's own semantics where they reach the simulation's numbers:
//   - FMath: Min/Max/Clamp/Abs/Lerp/Unwind*/Round*/Floor*/Atan2 exactly as UE 5.9 GenericPlatformMath.h,
//     UnrealMathUtility.h and UnrealPlatformMathSSE.h define them (float constants such as UE_PI kept float, as in UE).
//   - FVector2D: double, with UE's operator/ (multiply by 1/s), GetSafeNormal (1/sqrt), IsNearlyZero tolerances.
//   - FString / FName: == and Find/Contains/StartsWith/EndsWith/Replace ignore case (UE's defaults); Equals is case-sensitive.
//   - TMap / TSet: iteration in insertion order with UE's sparse-array hole reuse (the last freed slot is filled first).
// Anything here that is not UE's behaviour is listed in native/PATCHES.md under "shim deviations".
#pragma once

#include <cstdint>
#include <cstddef>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cwchar>
#include <cwctype>
#include <cmath>
#include <cstdarg>
#include <string>
#include <vector>
#include <memory>
#include <algorithm>
#include <functional>
#include <utility>
#include <type_traits>
#include <initializer_list>
#include <optional>
#include <emmintrin.h>

// ---------------------------------------------------------------- basic types and macros
typedef int8_t int8;
typedef int16_t int16;
typedef int32_t int32;
typedef int64_t int64;
typedef uint8_t uint8;
typedef uint16_t uint16;
typedef uint32_t uint32;
typedef uint64_t uint64;
typedef wchar_t TCHAR;
typedef char ANSICHAR;
typedef char UTF8CHAR;

#define TEXT_PASTE(x) L##x
#define TEXT(x) TEXT_PASTE(x)
#ifndef JAMCORE_API
#define JAMCORE_API
#endif
#define CORE_API
#define FORCEINLINE inline
#define FORCENOINLINE
#define UE_FORCEINLINE_HINT inline
#define RESTRICT __restrict
#define INDEX_NONE (-1)
#define MAX_int32 ((int32)0x7fffffff)
#define MIN_int32 ((int32)0x80000000)
#define MAX_int64 ((int64)0x7fffffffffffffff)
#define MAX_uint32 ((uint32)0xffffffff)
#define MAX_flt (3.402823466e+38F)
#define MAX_dbl (1.7976931348623158e+308)

#define UE_PI (3.1415926535897932f)
#define UE_SMALL_NUMBER (1.e-8f)
#define UE_KINDA_SMALL_NUMBER (1.e-4f)
#define UE_BIG_NUMBER (3.4e+38f)
#define UE_DOUBLE_PI (3.141592653589793238462643383279502884197169399)
#define UE_DOUBLE_SMALL_NUMBER (1.e-8)
#define UE_DOUBLE_KINDA_SMALL_NUMBER (1.e-4)
#define UE_HALF_PI (1.57079632679f)
#define UE_TWO_PI (6.28318530717f)
#define UE_DOUBLE_HALF_PI (1.57079632679489661923)
#define UE_DOUBLE_TWO_PI (6.28318530717958647692)
#define PI UE_PI
#define SMALL_NUMBER UE_SMALL_NUMBER
#define KINDA_SMALL_NUMBER UE_KINDA_SMALL_NUMBER

// Reflection macros: nothing to generate outside Unreal.
#define UCLASS(...)
#define USTRUCT(...)
#define UENUM(...)
#define UINTERFACE(...)
#define UPROPERTY(...)
#define UFUNCTION(...)
#define UMETA(...)
#define UPARAM(...)
#define GENERATED_BODY(...)
#define GENERATED_USTRUCT_BODY(...)
#define GENERATED_UCLASS_BODY(...)
#define GENERATED_IINTERFACE_BODY(...)
#define GENERATED_UINTERFACE_BODY(...)
#define DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(Name, ...) struct Name { template <typename... A> void Broadcast(A&&...) const {} };
#define DECLARE_DYNAMIC_MULTICAST_DELEGATE_TwoParams(Name, ...) struct Name { template <typename... A> void Broadcast(A&&...) const {} };
#define DECLARE_MULTICAST_DELEGATE_OneParam(Name, ...) struct Name { template <typename... A> void Broadcast(A&&...) const {} };
#define DECLARE_MULTICAST_DELEGATE_TwoParams(Name, ...) struct Name { template <typename... A> void Broadcast(A&&...) const {} };
#define UE_ARRAY_COUNT(a) (sizeof(a) / sizeof((a)[0]))
#define ARRAY_COUNT(a) UE_ARRAY_COUNT(a)

#ifndef WITH_DEV_AUTOMATION_TESTS
#define WITH_DEV_AUTOMATION_TESTS 0
#endif
#ifndef WITH_EDITOR
#define WITH_EDITOR 0
#endif
#ifndef UE_BUILD_SHIPPING
#define UE_BUILD_SHIPPING 0
#endif

enum EForceInit { ForceInit, ForceInitToZero };
enum ENoInit { NoInit };
namespace ESearchCase { enum Type { CaseSensitive, IgnoreCase }; }
namespace ESearchDir { enum Type { FromStart, FromEnd }; }

// ---------------------------------------------------------------- logging (routed to a host sink)
namespace ELogVerbosity { enum Type : uint8 { NoLogging = 0, Fatal, Error, Warning, Display, Log, Verbose, VeryVerbose, All = VeryVerbose }; }
struct FJamShimLogCategory { const char* Name; };
// The host (the GDExtension or the CLI) sets the sink; default prints "Category: Verbosity: text" to stdout.
typedef void (*FJamShimLogSink)(const char* Category, ELogVerbosity::Type Verbosity, const wchar_t* Text);
void JamShimSetLogSink(FJamShimLogSink Sink);
void JamShimLog(const FJamShimLogCategory& Cat, ELogVerbosity::Type Verbosity, const wchar_t* Text);
#define DECLARE_LOG_CATEGORY_EXTERN(Name, Default, Compile) extern FJamShimLogCategory Name;
#define DEFINE_LOG_CATEGORY(Name) FJamShimLogCategory Name{ #Name };
#define DEFINE_LOG_CATEGORY_STATIC(Name, Default, Compile) static FJamShimLogCategory Name{ #Name };
#define UE_LOG(Cat, Verb, Fmt, ...) JamShimLog(Cat, ELogVerbosity::Verb, *FString::Printf(Fmt, ##__VA_ARGS__))

[[noreturn]] void JamShimFatal(const char* What, const char* File, int Line);
#define check(x) do { if (!(x)) JamShimFatal(#x, __FILE__, __LINE__); } while (0)
#define checkf(x, ...) do { if (!(x)) JamShimFatal(#x, __FILE__, __LINE__); } while (0)
#define checkSlow(x) ((void)0)
#define checkNoEntry() JamShimFatal("checkNoEntry", __FILE__, __LINE__)
#define verify(x) check(x)
#define ensure(x) (!!(x))
#define ensureMsgf(x, ...) (!!(x))
#define ensureAlways(x) (!!(x))
#define ensureAlwaysMsgf(x, ...) (!!(x))

// ---------------------------------------------------------------- FMath (UE 5.9 semantics)
struct FMath
{
	template <class T> static constexpr T Abs(const T A) { return (A < (T)0) ? (T)-A : A; }
	template <class T> static constexpr T Sign(const T A) { return (A > (T)0) ? (T)1 : ((A < (T)0) ? (T)-1 : (T)0); }
	template <class T> static constexpr T Max(T A, T B) { return (B < A) ? A : B; }
	template <class T> static constexpr T Min(T A, T B) { return (A < B) ? A : B; }
	template <class A, class B, std::enable_if_t<!std::is_same_v<A, B> && std::is_arithmetic_v<A> && std::is_arithmetic_v<B>, int> = 0>
	static constexpr auto Max(A a, B b) { using C = std::common_type_t<A, B>; return Max<C>((C)a, (C)b); }
	template <class A, class B, std::enable_if_t<!std::is_same_v<A, B> && std::is_arithmetic_v<A> && std::is_arithmetic_v<B>, int> = 0>
	static constexpr auto Min(A a, B b) { using C = std::common_type_t<A, B>; return Min<C>((C)a, (C)b); }
	template <class T> static constexpr T Max3(const T A, const T B, const T C) { return Max(Max(A, B), C); }
	template <class T> static constexpr T Min3(const T A, const T B, const T C) { return Min(Min(A, B), C); }
	template <class T> static constexpr T Square(const T A) { return A * A; }
	template <class T> static constexpr T Cube(const T A) { return A * A * A; }
	template <class T> static constexpr T Clamp(const T X, const T MinValue, const T MaxValue) { return Max(Min(X, MaxValue), MinValue); }
	template <class A, class B, class C, std::enable_if_t<!(std::is_same_v<A, B> && std::is_same_v<B, C>), int> = 0>
	static constexpr auto Clamp(A x, B lo, C hi) { using T = std::common_type_t<A, B, C>; return Clamp<T>((T)x, (T)lo, (T)hi); }
	template <class T, class U> static constexpr T Lerp(const T& A, const T& B, const U& Alpha) { return (T)(A + Alpha * (B - A)); }

	static float Sqrt(float V) { return sqrtf(V); }
	static double Sqrt(double V) { return sqrt(V); }
	template <class T, std::enable_if_t<std::is_integral_v<T>, int> = 0> static double Sqrt(T V) { return sqrt((double)V); }
	static float InvSqrt(float V) { const __m128 One = _mm_set_ss(1.0f); return _mm_cvtss_f32(_mm_div_ss(One, _mm_sqrt_ss(_mm_set_ss(V)))); }
	static double InvSqrt(double V) { const __m128d One = _mm_set_sd(1.0); return _mm_cvtsd_f64(_mm_div_sd(One, _mm_sqrt_sd(One, _mm_set_sd(V)))); }
	static float Sin(float V) { return sinf(V); }
	static double Sin(double V) { return sin(V); }
	static float Cos(float V) { return cosf(V); }
	static double Cos(double V) { return cos(V); }
	static float Tan(float V) { return tanf(V); }
	static double Tan(double V) { return tan(V); }
	static float Asin(float V) { return asinf((V < -1.f) ? -1.f : ((V < 1.f) ? V : 1.f)); }
	static double Asin(double V) { return asin((V < -1.0) ? -1.0 : ((V < 1.0) ? V : 1.0)); }
	static float Acos(float V) { return acosf((V < -1.f) ? -1.f : ((V < 1.f) ? V : 1.f)); }
	static double Acos(double V) { return acos((V < -1.0) ? -1.0 : ((V < 1.0) ? V : 1.0)); }
	static float Atan(float V) { return atanf(V); }
	static double Atan(double V) { return atan(V); }
	static float Atan2(float Y, float X);   // UE's minimax approximation (shim.cpp)
	static double Atan2(double Y, double X) { if (X == 0.0 && Y == 0.0) return 0.0; return atan2(Y, X); }
	static float Exp(float V) { return expf(V); }
	static double Exp(double V) { return exp(V); }
	static float Loge(float V) { return logf(V); }
	static double Loge(double V) { return log(V); }
	static float Pow(float A, float B) { return powf(A, B); }
	static double Pow(double A, double B) { return pow(A, B); }
	static void SinCos(double* S, double* C, double V) { *S = sin(V); *C = cos(V); }
	static void SinCos(float* S, float* C, float V) { *S = sinf(V); *C = cosf(V); }

	static float FloorToFloat(float F) { return floorf(F); }
	static double FloorToDouble(double F) { return floor(F); }
	static double FloorToFloat(double F) { return floor(F); }
	static float CeilToFloat(float F) { return ceilf(F); }
	static double CeilToDouble(double F) { return ceil(F); }
	static float RoundToFloat(float F) { return FloorToFloat(F + 0.5f); }
	static double RoundToDouble(double F) { return FloorToDouble(F + 0.5); }
	static float TruncToFloat(float F) { return truncf(F); }
	static double TruncToDouble(double F) { return trunc(F); }
	static float Fractional(float V) { return V - TruncToFloat(V); }
	static double Fractional(double V) { return V - TruncToDouble(V); }
	static float Frac(float V) { return V - FloorToFloat(V); }
	static double Frac(double V) { return V - FloorToDouble(V); }
	static float Fmod(float X, float Y) { if (Abs(Y) <= UE_SMALL_NUMBER) return 0.f; return fmodf(X, Y); }
	static double Fmod(double X, double Y) { if (Abs(Y) <= UE_DOUBLE_SMALL_NUMBER) return 0.0; return fmod(X, Y); }

	// UnrealPlatformMathSSE.h (x64): the times-two forms.
	static int32 TruncToInt32(float F) { return _mm_cvtt_ss2si(_mm_set_ss(F)); }
	static int32 TruncToInt32(double V) { return _mm_cvttsd_si32(_mm_set_sd(V)); }
	static int64 TruncToInt64(double V) { return _mm_cvttsd_si64(_mm_set_sd(V)); }
	static int32 FloorToInt32(float F) { return _mm_cvt_ss2si(_mm_set_ss(F + F - 0.5f)) >> 1; }
	static int32 FloorToInt32(double V) { return _mm_cvtsd_si32(_mm_set_sd(V + V - 0.5)) >> 1; }
	static int64 FloorToInt64(double V) { return _mm_cvtsd_si64(_mm_set_sd(V + V - 0.5)) >> 1; }
	static int32 RoundToInt32(float F) { return _mm_cvt_ss2si(_mm_set_ss(F + F + 0.5f)) >> 1; }
	static int32 RoundToInt32(double V) { return _mm_cvtsd_si32(_mm_set_sd(V + V + 0.5)) >> 1; }
	static int64 RoundToInt64(double V) { return _mm_cvtsd_si64(_mm_set_sd(V + V + 0.5)) >> 1; }
	static int32 CeilToInt32(float F) { return -(_mm_cvt_ss2si(_mm_set_ss(-0.5f - (F + F))) >> 1); }
	static int32 CeilToInt32(double V) { return -(_mm_cvtsd_si32(_mm_set_sd(-0.5 - (V + V))) >> 1); }
	static int64 CeilToInt64(double V) { return -(_mm_cvtsd_si64(_mm_set_sd(-0.5 - (V + V))) >> 1); }
	static int32 TruncToInt(float F) { return TruncToInt32(F); }
	static int64 TruncToInt(double F) { return TruncToInt64(F); }
	static int32 FloorToInt(float F) { return FloorToInt32(F); }
	static int64 FloorToInt(double F) { return FloorToInt64(F); }
	static int32 RoundToInt(float F) { return RoundToInt32(F); }
	static int64 RoundToInt(double F) { return RoundToInt64(F); }
	static int32 CeilToInt(float F) { return CeilToInt32(F); }
	static int64 CeilToInt(double F) { return CeilToInt64(F); }

	static bool IsFinite(float A) { return std::isfinite(A); }
	static bool IsFinite(double A) { return std::isfinite(A); }
	static bool IsNaN(float A) { return std::isnan(A); }
	static bool IsNaN(double A) { return std::isnan(A); }
	static bool IsNearlyZero(float Value, float Tol = UE_SMALL_NUMBER) { return Abs<float>(Value) <= Tol; }
	static bool IsNearlyZero(double Value, double Tol = UE_DOUBLE_SMALL_NUMBER) { return Abs<double>(Value) <= Tol; }
	static bool IsNearlyEqual(float A, float B, float Tol = UE_SMALL_NUMBER) { return Abs<float>(A - B) <= Tol; }
	static bool IsNearlyEqual(double A, double B, double Tol = UE_DOUBLE_SMALL_NUMBER) { return Abs<double>(A - B) <= Tol; }

	static constexpr float RadiansToDegrees(float const& R) { return R * (180.f / UE_PI); }
	static constexpr double RadiansToDegrees(double const& R) { return R * (180.0 / UE_DOUBLE_PI); }
	static constexpr float DegreesToRadians(float const& D) { return D * (UE_PI / 180.f); }
	static constexpr double DegreesToRadians(double const& D) { return D * (UE_DOUBLE_PI / 180.0); }
	template <class T> static constexpr T UnwindRadians(T A)
	{
		while (A > UE_PI) { A -= UE_TWO_PI; }
		while (A < -UE_PI) { A += UE_TWO_PI; }
		return A;
	}
	template <class T> static constexpr T UnwindDegrees(T A)
	{
		while (A > 180.f) { A -= 360.f; }
		while (A < -180.f) { A += 360.f; }
		return A;
	}
	static int32 Rand() { return rand(); }   // not reached by the simulation (JamRandom.h is its only randomness)
};

inline uint64 GFrameCounter = 0;   // UE engine frame counter (JamEventBus logs it when no sim frame is set)

// ---------------------------------------------------------------- containers
struct FDefaultAllocator {};
template <int N> struct TInlineAllocator {};
template <class T> struct TShimSlot { using Type = T; };
struct FShimBool { bool V; FShimBool() : V(false) {} FShimBool(bool b) : V(b) {} };
template <> struct TShimSlot<bool> { using Type = FShimBool; };

template <class T, class Alloc = FDefaultAllocator>
class TArray
{
	using S = typename TShimSlot<std::remove_const_t<T>>::Type;
	std::vector<S> V;
	T* P() { return reinterpret_cast<T*>(V.data()); }
	const T* P() const { return reinterpret_cast<const T*>(V.data()); }
public:
	typedef T ElementType;
	TArray() = default;
	TArray(std::initializer_list<T> L) { for (const T& X : L) Add(X); }
	TArray(const T* Ptr, int32 Count) { Append(Ptr, Count); }
	template <class A2> TArray(const TArray<T, A2>& O) { Append(O); }
	TArray(const TArray&) = default;
	TArray(TArray&&) = default;
	TArray& operator=(const TArray&) = default;
	TArray& operator=(TArray&&) = default;
	template <class A2> TArray& operator=(const TArray<T, A2>& O) { Reset(); Append(O); return *this; }

	int32 Num() const { return (int32)V.size(); }
	bool IsEmpty() const { return V.empty(); }
	int32 Max() const { return (int32)V.capacity(); }
	bool IsValidIndex(int32 i) const { return i >= 0 && i < Num(); }
	T* GetData() { return P(); }
	const T* GetData() const { return P(); }
	T& operator[](int32 i) { check(IsValidIndex(i)); return P()[i]; }
	const T& operator[](int32 i) const { check(IsValidIndex(i)); return P()[i]; }
	T* begin() { return P(); }
	T* end() { return P() + Num(); }
	const T* begin() const { return P(); }
	const T* end() const { return P() + Num(); }
	T& Last(int32 i = 0) { return (*this)[Num() - 1 - i]; }
	const T& Last(int32 i = 0) const { return (*this)[Num() - 1 - i]; }
	T& Top() { return Last(); }
	const T& Top() const { return Last(); }
	T Pop(bool = true) { T R = std::move(Last()); V.pop_back(); return R; }

	int32 Add(const T& X) { V.push_back(S(X)); return Num() - 1; }
	int32 Add(T&& X) { V.push_back(S(std::move(X))); return Num() - 1; }
	T& Add_GetRef(const T& X) { Add(X); return Last(); }
	T& Add_GetRef(T&& X) { Add(std::move(X)); return Last(); }
	template <class... A> int32 Emplace(A&&... Args) { V.push_back(S(T(std::forward<A>(Args)...))); return Num() - 1; }
	template <class... A> T& Emplace_GetRef(A&&... Args) { Emplace(std::forward<A>(Args)...); return Last(); }
	int32 AddDefaulted(int32 Count = 1) { const int32 At = Num(); for (int32 i = 0; i < Count; ++i) V.push_back(S(T())); return At; }
	T& AddDefaulted_GetRef() { AddDefaulted(); return Last(); }
	int32 AddZeroed(int32 Count = 1) { const int32 At = Num(); V.resize(V.size() + Count); std::memset((void*)(V.data() + At), 0, sizeof(S) * Count); return At; }
	T& AddZeroed_GetRef() { AddZeroed(); return Last(); }
	int32 AddUninitialized(int32 Count = 1) { const int32 At = Num(); V.resize(V.size() + Count); return At; }
	int32 AddUnique(const T& X) { const int32 i = Find(X); return i != INDEX_NONE ? i : Add(X); }
	void Insert(const T& X, int32 At) { V.insert(V.begin() + At, S(X)); }
	void Insert(T&& X, int32 At) { V.insert(V.begin() + At, S(std::move(X))); }
	template <class A2> void Append(const TArray<T, A2>& O) { for (const T& X : O) Add(X); }
	void Append(const T* Ptr, int32 Count) { for (int32 i = 0; i < Count; ++i) Add(Ptr[i]); }
	void Append(std::initializer_list<T> L) { for (const T& X : L) Add(X); }
	TArray& operator+=(const TArray& O) { Append(O); return *this; }
	void Init(const T& X, int32 N) { V.assign(N, S(X)); }
	void SetNum(int32 N, bool = true) { V.resize(N); }
	void SetNumZeroed(int32 N, bool = true) { const int32 Old = Num(); V.resize(N); if (N > Old) std::memset((void*)(V.data() + Old), 0, sizeof(S) * (N - Old)); }
	void SetNumUninitialized(int32 N, bool = true) { V.resize(N); }
	void Reserve(int32 N) { V.reserve(N); }
	void Reset(int32 N = 0) { V.clear(); if (N) V.reserve(N); }
	void Empty(int32 N = 0) { V.clear(); V.shrink_to_fit(); if (N) V.reserve(N); }
	void Shrink() { V.shrink_to_fit(); }
	void RemoveAt(int32 i, int32 Count = 1, bool = true) { V.erase(V.begin() + i, V.begin() + i + Count); }
	void RemoveAtSwap(int32 i, int32 Count = 1, bool = true)
	{
		// UE: the hole is filled from the end of the array.
		for (int32 k = 0; k < Count; ++k)
		{
			const int32 LastI = Num() - 1;
			if (i + k != LastI) V[i + k] = std::move(V[LastI]);
			V.pop_back();
		}
	}
	int32 Remove(const T& X) { const int32 Before = Num(); V.erase(std::remove_if(V.begin(), V.end(), [&](const S& E) { return *reinterpret_cast<const T*>(&E) == X; }), V.end()); return Before - Num(); }
	int32 RemoveSingle(const T& X) { const int32 i = Find(X); if (i == INDEX_NONE) return 0; RemoveAt(i); return 1; }
	template <class Pr> int32 RemoveAll(Pr Pred) { const int32 Before = Num(); V.erase(std::remove_if(V.begin(), V.end(), [&](const S& E) { return Pred(*reinterpret_cast<const T*>(&E)); }), V.end()); return Before - Num(); }
	template <class Pr> int32 RemoveAllSwap(Pr Pred) { return RemoveAll(Pred); }

	int32 Find(const T& X) const { for (int32 i = 0; i < Num(); ++i) if (P()[i] == X) return i; return INDEX_NONE; }
	bool Find(const T& X, int32& Out) const { Out = Find(X); return Out != INDEX_NONE; }
	int32 FindLast(const T& X) const { for (int32 i = Num() - 1; i >= 0; --i) if (P()[i] == X) return i; return INDEX_NONE; }
	template <class K> int32 IndexOfByKey(const K& Key) const { for (int32 i = 0; i < Num(); ++i) if (P()[i] == Key) return i; return INDEX_NONE; }
	template <class Pr> int32 IndexOfByPredicate(Pr Pred) const { for (int32 i = 0; i < Num(); ++i) if (Pred(P()[i])) return i; return INDEX_NONE; }
	template <class Pr> T* FindByPredicate(Pr Pred) { for (int32 i = 0; i < Num(); ++i) if (Pred(P()[i])) return &P()[i]; return nullptr; }
	template <class Pr> const T* FindByPredicate(Pr Pred) const { for (int32 i = 0; i < Num(); ++i) if (Pred(P()[i])) return &P()[i]; return nullptr; }
	template <class K> T* FindByKey(const K& Key) { for (int32 i = 0; i < Num(); ++i) if (P()[i] == Key) return &P()[i]; return nullptr; }
	template <class K> const T* FindByKey(const K& Key) const { for (int32 i = 0; i < Num(); ++i) if (P()[i] == Key) return &P()[i]; return nullptr; }
	template <class Pr> TArray FilterByPredicate(Pr Pred) const { TArray R; for (const T& X : *this) if (Pred(X)) R.Add(X); return R; }
	template <class K> bool Contains(const K& X) const { for (int32 i = 0; i < Num(); ++i) if (P()[i] == X) return true; return false; }
	template <class Pr> bool ContainsByPredicate(Pr Pred) const { return IndexOfByPredicate(Pred) != INDEX_NONE; }

	// UE's Sort is an unstable introsort; the comparators JamCore passes are total orders (ties broken by index), so any sort agrees.
	void Sort() { std::sort(begin(), end()); }
	template <class Pr> void Sort(Pr Pred) { std::sort(begin(), end(), Pred); }
	void StableSort() { std::stable_sort(begin(), end()); }
	template <class Pr> void StableSort(Pr Pred) { std::stable_sort(begin(), end(), Pred); }
	void Swap(int32 A, int32 B) { std::swap(P()[A], P()[B]); }

	bool operator==(const TArray& O) const { if (Num() != O.Num()) return false; for (int32 i = 0; i < Num(); ++i) if (!(P()[i] == O.P()[i])) return false; return true; }
	bool operator!=(const TArray& O) const { return !(*this == O); }
};

template <class T> using TArrayView = TArray<T>;

template <class K, class V>
struct TPair
{
	K Key;
	V Value;
	TPair() = default;
	TPair(const K& InK, const V& InV) : Key(InK), Value(InV) {}
	template <class K2, class V2> TPair(K2&& InK, V2&& InV) : Key(std::forward<K2>(InK)), Value(std::forward<V2>(InV)) {}
	bool operator==(const TPair& O) const { return Key == O.Key && Value == O.Value; }
};
template <class K, class V> TPair<K, V> MakeTuple(const K& k, const V& v) { return TPair<K, V>(k, v); }

// UE TSparseArray order: elements in slot order; a removal leaves a hole that the next add fills (last freed first).
template <class E>
class TShimSparse
{
public:
	std::vector<std::optional<E>> Slots;
	std::vector<int32> Free;
	int32 Count = 0;
	int32 AddSlot(E&& X)
	{
		int32 i;
		if (!Free.empty()) { i = Free.back(); Free.pop_back(); Slots[i].emplace(std::move(X)); }
		else { i = (int32)Slots.size(); Slots.emplace_back(std::move(X)); }
		++Count;
		return i;
	}
	void RemoveSlot(int32 i) { Slots[i].reset(); Free.push_back(i); --Count; }
	void Clear() { Slots.clear(); Free.clear(); Count = 0; }
	template <class EE> struct It
	{
		using Vec = std::conditional_t<std::is_const_v<EE>, const std::vector<std::optional<E>>, std::vector<std::optional<E>>>;
		Vec* Vp; size_t i;
		void Skip() { while (i < Vp->size() && !(*Vp)[i].has_value()) ++i; }
		EE& operator*() const { return *(*Vp)[i]; }
		EE* operator->() const { return &*(*Vp)[i]; }
		It& operator++() { ++i; Skip(); return *this; }
		bool operator!=(const It& O) const { return i != O.i; }
		bool operator==(const It& O) const { return i == O.i; }
	};
	It<E> begin() { It<E> r{ &Slots, 0 }; r.Skip(); return r; }
	It<E> end() { return It<E>{ &Slots, Slots.size() }; }
	It<const E> begin() const { It<const E> r{ &Slots, 0 }; r.Skip(); return r; }
	It<const E> end() const { return It<const E>{ &Slots, Slots.size() }; }
};

template <class K, class V>
class TMap
{
	TShimSparse<TPair<K, V>> D;
	int32 IndexOf(const K& Key) const { for (size_t i = 0; i < D.Slots.size(); ++i) if (D.Slots[i] && D.Slots[i]->Key == Key) return (int32)i; return INDEX_NONE; }
public:
	typedef TPair<K, V> ElementType;
	int32 Num() const { return D.Count; }
	bool IsEmpty() const { return D.Count == 0; }
	V& Add(const K& Key, const V& Value) { const int32 i = IndexOf(Key); if (i != INDEX_NONE) { D.Slots[i]->Value = Value; return D.Slots[i]->Value; } return D.Slots[D.AddSlot(TPair<K, V>(Key, Value))]->Value; }
	V& Add(const K& Key, V&& Value) { const int32 i = IndexOf(Key); if (i != INDEX_NONE) { D.Slots[i]->Value = std::move(Value); return D.Slots[i]->Value; } return D.Slots[D.AddSlot(TPair<K, V>(Key, std::move(Value)))]->Value; }
	V& Add(const K& Key) { return Add(Key, V()); }
	template <class... A> V& Emplace(const K& Key, A&&... Args) { return Add(Key, V(std::forward<A>(Args)...)); }
	V& FindOrAdd(const K& Key) { const int32 i = IndexOf(Key); if (i != INDEX_NONE) return D.Slots[i]->Value; return Add(Key, V()); }
	V& FindOrAdd(const K& Key, const V& Def) { const int32 i = IndexOf(Key); if (i != INDEX_NONE) return D.Slots[i]->Value; return Add(Key, Def); }
	V* Find(const K& Key) { const int32 i = IndexOf(Key); return i == INDEX_NONE ? nullptr : &D.Slots[i]->Value; }
	const V* Find(const K& Key) const { const int32 i = IndexOf(Key); return i == INDEX_NONE ? nullptr : &D.Slots[i]->Value; }
	V FindRef(const K& Key) const { const V* p = Find(Key); return p ? *p : V(); }
	V& FindChecked(const K& Key) { V* p = Find(Key); check(p); return *p; }
	const V& FindChecked(const K& Key) const { const V* p = Find(Key); check(p); return *p; }
	V& operator[](const K& Key) { return FindChecked(Key); }
	const V& operator[](const K& Key) const { return FindChecked(Key); }
	bool Contains(const K& Key) const { return IndexOf(Key) != INDEX_NONE; }
	int32 Remove(const K& Key) { const int32 i = IndexOf(Key); if (i == INDEX_NONE) return 0; D.RemoveSlot(i); return 1; }
	void Empty(int32 = 0) { D.Clear(); }
	void Reset() { D.Clear(); }
	void Reserve(int32) {}
	int32 GetKeys(TArray<K>& Out) const { Out.Reset(); for (const auto& P : D) Out.Add(P.Key); return Out.Num(); }
	void GenerateKeyArray(TArray<K>& Out) const { GetKeys(Out); }
	void GenerateValueArray(TArray<V>& Out) const { Out.Reset(); for (const auto& P : D) Out.Add(P.Value); }
	auto begin() { return D.begin(); }
	auto end() { return D.end(); }
	auto begin() const { return D.begin(); }
	auto end() const { return D.end(); }
};

template <class T>
class TSet
{
	TShimSparse<T> D;
	int32 IndexOf(const T& X) const { for (size_t i = 0; i < D.Slots.size(); ++i) if (D.Slots[i] && *D.Slots[i] == X) return (int32)i; return INDEX_NONE; }
public:
	TSet() = default;
	TSet(std::initializer_list<T> L) { for (const T& X : L) Add(X); }
	int32 Num() const { return D.Count; }
	bool IsEmpty() const { return D.Count == 0; }
	void Add(const T& X, bool* bAlready = nullptr) { const bool b = IndexOf(X) != INDEX_NONE; if (bAlready) *bAlready = b; if (!b) D.AddSlot(T(X)); }
	bool Contains(const T& X) const { return IndexOf(X) != INDEX_NONE; }
	const T* Find(const T& X) const { const int32 i = IndexOf(X); return i == INDEX_NONE ? nullptr : &*D.Slots[i]; }
	int32 Remove(const T& X) { const int32 i = IndexOf(X); if (i == INDEX_NONE) return 0; D.RemoveSlot(i); return 1; }
	void Empty(int32 = 0) { D.Clear(); }
	void Reset() { D.Clear(); }
	TArray<T> Array() const { TArray<T> R; for (const T& X : D) R.Add(X); return R; }
	auto begin() { return D.begin(); }
	auto end() { return D.end(); }
	auto begin() const { return D.begin(); }
	auto end() const { return D.end(); }
};

// ---------------------------------------------------------------- smart pointers
template <class T>
class TSharedPtr
{
	std::shared_ptr<T> P;
public:
	TSharedPtr() = default;
	TSharedPtr(std::nullptr_t) {}
	explicit TSharedPtr(std::shared_ptr<T> In) : P(std::move(In)) {}
	template <class U, std::enable_if_t<std::is_convertible_v<U*, T*>, int> = 0> TSharedPtr(const TSharedPtr<U>& O) : P(O.Std()) {}
	bool IsValid() const { return (bool)P; }
	explicit operator bool() const { return (bool)P; }
	T* Get() const { return P.get(); }
	T* operator->() const { return P.get(); }
	T& operator*() const { return *P; }
	T& ToSharedRef() const { return *P; }
	void Reset() { P.reset(); }
	const std::shared_ptr<T>& Std() const { return P; }
	bool operator==(const TSharedPtr& O) const { return P == O.P; }
	bool operator!=(const TSharedPtr& O) const { return P != O.P; }
	bool operator==(std::nullptr_t) const { return !P; }
	bool operator!=(std::nullptr_t) const { return (bool)P; }
};
template <class T, class... A> TSharedPtr<T> MakeShared(A&&... Args) { return TSharedPtr<T>(std::make_shared<T>(std::forward<A>(Args)...)); }
template <class T> TSharedPtr<T> MakeShareable(T* Raw) { return TSharedPtr<T>(std::shared_ptr<T>(Raw)); }

template <class T> T&& MoveTemp(T& X) { return static_cast<T&&>(X); }
template <class T> T&& MoveTemp(T&& X) { return static_cast<T&&>(X); }
template <class T> T CopyTemp(const T& X) { return X; }
template <class T> void Swap(T& A, T& B) { std::swap(A, B); }
template <class T> inline uint32 GetTypeHash(const T& X) { return (uint32)std::hash<T>()(X); }

#include "ShimString.h"
#include "ShimMath.h"
#include "ShimObject.h"
