// The least of Unreal that thirdjam's camera code needs to compile outside the engine (K3 shell's oracle).
// Nothing here is thirdjam's logic: the camera's own lines are copied verbatim from its source by make_oracle.sh.
// Types follow UE 5.x: FVector2D and FVector are double, FRotator float (pitch, yaw, roll in degrees).
#pragma once
#include <cmath>
#include <cstdint>
#include <type_traits>
#include <vector>
#include <initializer_list>

typedef int32_t int32;
typedef int64_t int64;
typedef uint8_t uint8;
typedef uint64_t uint64;
#define UPROPERTY(...)
#define USTRUCT(...)
#define UENUM(...)
#define UCLASS(...)
#define UFUNCTION(...)
#define GENERATED_BODY()
#define JAMGAME_API
#define KINDA_SMALL_NUMBER (1.e-4f)
#ifndef PI
#define PI (3.1415926535897932f)
#endif
#define UE_DOUBLE_PI (3.141592653589793238462643383279502884197169399)

struct FMath
{
	template <class T> static T Abs(T A) { return A < (T)0 ? -A : A; }
	template <class T> static T Sign(T A) { return A > (T)0 ? (T)1 : (A < (T)0 ? (T)-1 : (T)0); }
	template <class T, class U> static auto Max(T A, U B) -> typename std::common_type<T, U>::type { typedef typename std::common_type<T, U>::type R; return (R)A >= (R)B ? (R)A : (R)B; }
	template <class T, class U> static auto Min(T A, U B) -> typename std::common_type<T, U>::type { typedef typename std::common_type<T, U>::type R; return (R)A <= (R)B ? (R)A : (R)B; }
	template <class T> static T Max3(T A, T B, T C) { return Max(Max(A, B), C); }
	template <class T, class U, class V> static auto Clamp(T X, U Lo, V Hi) -> typename std::common_type<T, U, V>::type
	{
		typedef typename std::common_type<T, U, V>::type R;
		return (R)X < (R)Lo ? (R)Lo : ((R)X < (R)Hi ? (R)X : (R)Hi);
	}
	template <class T> static T Square(T A) { return A * A; }
	static float Sqrt(float A) { return std::sqrt(A); }
	static double Sqrt(double A) { return std::sqrt(A); }
	static float Exp(float A) { return std::exp(A); }
	static double Exp(double A) { return std::exp(A); }
	static float Sin(float A) { return std::sin(A); }
	static double Sin(double A) { return std::sin(A); }
	static float Cos(float A) { return std::cos(A); }
	static double Cos(double A) { return std::cos(A); }
	static float Tan(float A) { return std::tan(A); }
	static double Tan(double A) { return std::tan(A); }
	static float Atan(float A) { return std::atan(A); }
	static double Atan(double A) { return std::atan(A); }
	static float Acos(float A) { return std::acos(A); }
	static double Acos(double A) { return std::acos(A); }
	static float Atan2(float Y, float X) { return std::atan2(Y, X); }
	static double Atan2(double Y, double X) { return std::atan2(Y, X); }
	static float DegreesToRadians(float D) { return D * (PI / 180.f); }
	static double DegreesToRadians(double D) { return D * (UE_DOUBLE_PI / 180.0); }
	static float RadiansToDegrees(float R) { return R * (180.f / PI); }
	static double RadiansToDegrees(double R) { return R * (180.0 / UE_DOUBLE_PI); }
	template <class T> static T UnwindDegrees(T A) { while (A > (T)180) A -= (T)360; while (A < (T)-180) A += (T)360; return A; }
	template <class T, class U> static auto Lerp(const T& A, const T& B, U Alpha) -> T { return A + (B - A) * Alpha; }
};

struct FVector2D
{
	double X = 0, Y = 0;
	FVector2D() {}
	FVector2D(double InX, double InY) : X(InX), Y(InY) {}
	static const FVector2D ZeroVector;
	FVector2D operator+(const FVector2D& B) const { return FVector2D(X + B.X, Y + B.Y); }
	FVector2D operator-(const FVector2D& B) const { return FVector2D(X - B.X, Y - B.Y); }
	FVector2D operator-() const { return FVector2D(-X, -Y); }
	FVector2D operator*(double S) const { return FVector2D(X * S, Y * S); }
	FVector2D operator/(double S) const { return FVector2D(X / S, Y / S); }
	FVector2D& operator+=(const FVector2D& B) { X += B.X; Y += B.Y; return *this; }
	FVector2D& operator-=(const FVector2D& B) { X -= B.X; Y -= B.Y; return *this; }
	FVector2D& operator/=(double S) { X /= S; Y /= S; return *this; }
	double Size() const { return std::sqrt(X * X + Y * Y); }
	double SizeSquared() const { return X * X + Y * Y; }
	bool IsNearlyZero(double T = 1.e-8) const { return std::fabs(X) <= T && std::fabs(Y) <= T; }
	FVector2D GetSafeNormal(double T = 1.e-8) const { const double S = SizeSquared(); if (S > T) { const double K = 1.0 / std::sqrt(S); return FVector2D(X * K, Y * K); } return FVector2D(); }
	static double Distance(const FVector2D& A, const FVector2D& B) { return (A - B).Size(); }
	static double DistSquared(const FVector2D& A, const FVector2D& B) { return (A - B).SizeSquared(); }
	static double DotProduct(const FVector2D& A, const FVector2D& B) { return A.X * B.X + A.Y * B.Y; }
};
inline const FVector2D FVector2D::ZeroVector = FVector2D();
inline FVector2D operator*(double S, const FVector2D& V) { return V * S; }

struct FVector
{
	double X = 0, Y = 0, Z = 0;
	FVector() {}
	FVector(double InX, double InY, double InZ) : X(InX), Y(InY), Z(InZ) {}
	FVector(const FVector2D& V, double InZ) : X(V.X), Y(V.Y), Z(InZ) {}
	static const FVector ZeroVector;
	FVector operator+(const FVector& B) const { return FVector(X + B.X, Y + B.Y, Z + B.Z); }
	FVector operator-(const FVector& B) const { return FVector(X - B.X, Y - B.Y, Z - B.Z); }
	FVector operator*(double S) const { return FVector(X * S, Y * S, Z * S); }
};
inline const FVector FVector::ZeroVector = FVector();

struct FRotator
{
	float Pitch = 0, Yaw = 0, Roll = 0;
	FRotator() {}
	FRotator(float P, float Y, float R) : Pitch(P), Yaw(Y), Roll(R) {}
};

// A rotation and a translation, no scale. The rotation matrix is UE's FRotationMatrix (FRotator to axes); Rotator() gives
// back the rotator it was made from (UE would round-trip through a quaternion: differences far below the checks' 1e-4).
struct FTransform
{
	FRotator R;
	FVector T;
	FTransform() {}
	FTransform(const FRotator& InR, const FVector& InT) : R(InR), T(InT) {}
	static const FTransform Identity;
	FVector GetLocation() const { return T; }
	FRotator Rotator() const { return R; }
	FVector InverseTransformPositionNoScale(const FVector& W) const
	{
		const double P = R.Pitch * (UE_DOUBLE_PI / 180.0), Y = R.Yaw * (UE_DOUBLE_PI / 180.0), Ro = R.Roll * (UE_DOUBLE_PI / 180.0);
		const double SP = std::sin(P), CP = std::cos(P), SY = std::sin(Y), CY = std::cos(Y), SR = std::sin(Ro), CR = std::cos(Ro);
		const FVector Ax(CP * CY, CP * SY, SP);
		const FVector Ay(SR * SP * CY - CR * SY, SR * SP * SY + CR * CY, -SR * CP);
		const FVector Az(-(CR * SP * CY + SR * SY), CY * SR - CR * SP * SY, CR * CP);
		const FVector D = W - T;
		return FVector(D.X * Ax.X + D.Y * Ax.Y + D.Z * Ax.Z, D.X * Ay.X + D.Y * Ay.Y + D.Z * Ay.Z, D.X * Az.X + D.Y * Az.Y + D.Z * Az.Z);
	}
};
inline const FTransform FTransform::Identity = FTransform();

template <class T> struct TArray : public std::vector<T>
{
	int32 Num() const { return (int32)this->size(); }
	bool IsValidIndex(int32 I) const { return I >= 0 && I < Num(); }
	void Add(const T& V) { this->push_back(V); }
};

// HUDFeed.h (thirdjam): the presentation frame's fields the camera reads.
enum class EJamPhase : uint8 { Play, GoalPause, Win, Lose, Paused };
struct FJamPresentationSkater { FVector2D PosM; float YawDeg = 0.f; int32 TeamId = 0; bool bHuman = false; };
struct FJamPresentationFrame
{
	int64 SimFrame = 0;
	float RinkLengthM = 120.f, RinkWidthM = 60.f, CornerRadiusM = 0.f;
	TArray<FJamPresentationSkater> Skaters;
	FVector2D PuckM;
	int32 HumanIndex = 0;
	int32 AttackSign = 1;
	float NetInsetM = 4.f;
	EJamPhase Phase = EJamPhase::Play;
	FVector GetFarNetWorldCm() const;   // body copied from HUDFeed.cpp by make_oracle.sh
};
