// Third Life rink core shim: FVector2D (UE 5.9 TVector2<double> semantics), FVector, colours.
#pragma once

struct FVector2D
{
	double X = 0, Y = 0;
	static const FVector2D ZeroVector;
	static const FVector2D UnitVector;
	FVector2D() = default;
	FVector2D(double InX, double InY) : X(InX), Y(InY) {}
	explicit FVector2D(double V) : X(V), Y(V) {}
	explicit FVector2D(EForceInit) : X(0), Y(0) {}

	FVector2D operator+(const FVector2D& V) const { return FVector2D(X + V.X, Y + V.Y); }
	FVector2D operator-(const FVector2D& V) const { return FVector2D(X - V.X, Y - V.Y); }
	FVector2D operator*(double Scale) const { return FVector2D(X * Scale, Y * Scale); }
	FVector2D operator/(double Scale) const { const double R = 1.f / Scale; return FVector2D(X * R, Y * R); }
	FVector2D operator+(double A) const { return FVector2D(X + A, Y + A); }
	FVector2D operator-(double A) const { return FVector2D(X - A, Y - A); }
	FVector2D operator*(const FVector2D& V) const { return FVector2D(X * V.X, Y * V.Y); }
	FVector2D operator/(const FVector2D& V) const { return FVector2D(X / V.X, Y / V.Y); }
	double operator|(const FVector2D& V) const { return X * V.X + Y * V.Y; }
	double operator^(const FVector2D& V) const { return X * V.Y - Y * V.X; }
	FVector2D operator-() const { return FVector2D(-X, -Y); }
	FVector2D operator+=(const FVector2D& V) { X += V.X; Y += V.Y; return *this; }
	FVector2D operator-=(const FVector2D& V) { X -= V.X; Y -= V.Y; return *this; }
	FVector2D operator*=(double S) { X *= S; Y *= S; return *this; }
	FVector2D operator/=(double V) { const double R = 1.f / V; X *= R; Y *= R; return *this; }
	FVector2D operator*=(const FVector2D& V) { X *= V.X; Y *= V.Y; return *this; }
	FVector2D operator/=(const FVector2D& V) { X /= V.X; Y /= V.Y; return *this; }
	bool operator==(const FVector2D& V) const { return X == V.X && Y == V.Y; }
	bool operator!=(const FVector2D& V) const { return X != V.X || Y != V.Y; }
	double& operator[](int32 i) { return i == 0 ? X : Y; }
	double operator[](int32 i) const { return i == 0 ? X : Y; }

	static double DotProduct(const FVector2D& A, const FVector2D& B) { return A | B; }
	static double DistSquared(const FVector2D& V1, const FVector2D& V2) { return FMath::Square(V2.X - V1.X) + FMath::Square(V2.Y - V1.Y); }
	static double Distance(const FVector2D& V1, const FVector2D& V2) { return FMath::Sqrt(DistSquared(V1, V2)); }
	static double CrossProduct(const FVector2D& A, const FVector2D& B) { return A ^ B; }
	static FVector2D Max(const FVector2D& A, const FVector2D& B) { return FVector2D(FMath::Max(A.X, B.X), FMath::Max(A.Y, B.Y)); }
	static FVector2D Min(const FVector2D& A, const FVector2D& B) { return FVector2D(FMath::Min(A.X, B.X), FMath::Min(A.Y, B.Y)); }
	static FVector2D Clamp(const FVector2D& V, const FVector2D& Lo, const FVector2D& Hi) { return FVector2D(FMath::Clamp(V.X, Lo.X, Hi.X), FMath::Clamp(V.Y, Lo.Y, Hi.Y)); }

	double Size() const { return FMath::Sqrt(X * X + Y * Y); }
	double Length() const { return Size(); }
	double SizeSquared() const { return X * X + Y * Y; }
	double SquaredLength() const { return SizeSquared(); }
	double Dot(const FVector2D& V) const { return X * V.X + Y * V.Y; }
	double Cross(const FVector2D& V) const { return X * V.Y - Y * V.X; }
	FVector2D GetSafeNormal(double Tolerance = UE_SMALL_NUMBER) const
	{
		const double SquareSum = X * X + Y * Y;
		if (SquareSum > Tolerance) { const double Scale = FMath::InvSqrt(SquareSum); return FVector2D(X * Scale, Y * Scale); }
		return FVector2D(0.f, 0.f);
	}
	bool Normalize(double Tolerance = UE_SMALL_NUMBER)
	{
		const double SquareSum = X * X + Y * Y;
		if (SquareSum > Tolerance) { const double Scale = FMath::InvSqrt(SquareSum); X *= Scale; Y *= Scale; return true; }
		X = 0.0f; Y = 0.0f;
		return false;
	}
	void ToDirectionAndLength(FVector2D& OutDir, double& OutLength) const
	{
		OutLength = Size();
		if (OutLength > UE_SMALL_NUMBER) { const double One = 1.0f / OutLength; OutDir = FVector2D(X * One, Y * One); }
		else { OutDir = ZeroVector; }
	}
	bool IsNearlyZero(double Tolerance = UE_KINDA_SMALL_NUMBER) const { return FMath::Abs(X) <= Tolerance && FMath::Abs(Y) <= Tolerance; }
	bool IsZero() const { return X == 0.f && Y == 0.f; }
	bool Equals(const FVector2D& V, double Tolerance = UE_KINDA_SMALL_NUMBER) const { return FMath::Abs(X - V.X) <= Tolerance && FMath::Abs(Y - V.Y) <= Tolerance; }
	FVector2D GetRotated(double AngleDeg) const
	{
		double S, C;
		FMath::SinCos(&S, &C, FMath::DegreesToRadians(AngleDeg));
		return FVector2D(C * X - S * Y, S * X + C * Y);
	}
	FVector2D GetAbs() const { return FVector2D(FMath::Abs(X), FMath::Abs(Y)); }
	double GetMax() const { return FMath::Max(X, Y); }
	double GetMin() const { return FMath::Min(X, Y); }
	double GetAbsMax() const { return FMath::Max(FMath::Abs(X), FMath::Abs(Y)); }
	FVector2D ComponentMax(const FVector2D& O) const { return FVector2D(FMath::Max(X, O.X), FMath::Max(Y, O.Y)); }
	FVector2D ComponentMin(const FVector2D& O) const { return FVector2D(FMath::Min(X, O.X), FMath::Min(Y, O.Y)); }
	FString ToString() const { return FString::Printf(TEXT("X=%3.3f Y=%3.3f"), X, Y); }
};
inline const FVector2D FVector2D::ZeroVector(0.0, 0.0);
inline const FVector2D FVector2D::UnitVector(1.0, 1.0);
template <class T2, std::enable_if_t<std::is_arithmetic_v<T2>, int> = 0>
inline FVector2D operator*(T2 Scale, const FVector2D& V) { return V.operator*((double)Scale); }

struct FVector
{
	double X = 0, Y = 0, Z = 0;
	static const FVector ZeroVector;
	FVector() = default;
	FVector(double InX, double InY, double InZ) : X(InX), Y(InY), Z(InZ) {}
	explicit FVector(EForceInit) {}
	FVector operator+(const FVector& V) const { return FVector(X + V.X, Y + V.Y, Z + V.Z); }
	FVector operator-(const FVector& V) const { return FVector(X - V.X, Y - V.Y, Z - V.Z); }
	FVector operator*(double S) const { return FVector(X * S, Y * S, Z * S); }
	double Size() const { return FMath::Sqrt(X * X + Y * Y + Z * Z); }
	bool operator==(const FVector& V) const { return X == V.X && Y == V.Y && Z == V.Z; }
};
inline const FVector FVector::ZeroVector(0.0, 0.0, 0.0);

struct FColor
{
	uint8 B = 0, G = 0, R = 0, A = 255;
	FColor() = default;
	FColor(uint8 InR, uint8 InG, uint8 InB, uint8 InA = 255) : B(InB), G(InG), R(InR), A(InA) {}
	bool operator==(const FColor& O) const { return R == O.R && G == O.G && B == O.B && A == O.A; }
	static FColor FromHex(const FString& Hex);
};

struct FLinearColor
{
	float R = 0, G = 0, B = 0, A = 1;
	static const FLinearColor White;
	static const FLinearColor Black;
	FLinearColor() = default;
	FLinearColor(float InR, float InG, float InB, float InA = 1.f) : R(InR), G(InG), B(InB), A(InA) {}
	explicit FLinearColor(EForceInit) : R(0), G(0), B(0), A(0) {}
	explicit FLinearColor(const FColor& C);   // UE: sRGB -> linear (shim.cpp)
	bool operator==(const FLinearColor& O) const { return R == O.R && G == O.G && B == O.B && A == O.A; }
	bool operator!=(const FLinearColor& O) const { return !(*this == O); }
	static FLinearColor FromSRGBColor(const FColor& C) { return FLinearColor(C); }
	FColor ToFColorSRGB() const;   // UE: linear -> sRGB bytes (shim.cpp)
};
inline const FLinearColor FLinearColor::White(1.f, 1.f, 1.f, 1.f);
inline const FLinearColor FLinearColor::Black(0.f, 0.f, 0.f, 1.f);
