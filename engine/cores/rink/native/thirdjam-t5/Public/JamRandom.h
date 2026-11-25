// The only source of randomness in the simulation (law: randomness only from FJamRandom(seed)).
// PCG32 (O'Neill), seeded from the cartridge seed. Never use FMath::Rand / FRand / RandRange in gameplay code.
#pragma once

#include "CoreMinimal.h"

struct JAMCORE_API FJamRandom
{
	FJamRandom() { Seed(1); }
	explicit FJamRandom(uint64 InSeed) { Seed(InSeed); }

	void Seed(uint64 InSeed, uint64 Stream = 54u)
	{
		State = 0u;
		Inc = (Stream << 1u) | 1u;
		NextU32();
		State += InSeed;
		NextU32();
	}

	uint32 NextU32()
	{
		const uint64 Old = State;
		State = Old * 6364136223846793005ull + Inc;
		const uint32 XorShifted = static_cast<uint32>(((Old >> 18u) ^ Old) >> 27u);
		const uint32 Rot = static_cast<uint32>(Old >> 59u);
		return (XorShifted >> Rot) | (XorShifted << ((0u - Rot) & 31u));
	}

	// [0, 1)
	double NextUnit() { return static_cast<double>(NextU32()) * (1.0 / 4294967296.0); }

	// [Min, Max)
	double Range(double Min, double Max) { return Min + (Max - Min) * NextUnit(); }

	// Integer in [0, N); N must be > 0.
	int32 NextInt(int32 N) { return N <= 0 ? 0 : static_cast<int32>(NextU32() % static_cast<uint32>(N)); }

	// Unit vector on the ice plane (rink x, rink z).
	FVector2D UnitVector2D()
	{
		const double A = NextUnit() * 2.0 * UE_DOUBLE_PI;
		return FVector2D(FMath::Cos(A), FMath::Sin(A));
	}

	uint64 GetState() const { return State; }

private:
	uint64 State = 0;
	uint64 Inc = 1;
};
