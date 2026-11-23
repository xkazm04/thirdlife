// Third Life rink core: thirdjam's playtester on the human's skater (see rink_playtester.h). Every line cites JamPlaytester.cpp (HEAD).
#include "rink_playtester.h"

namespace RinkGlue
{
	void FPlaytesterSeat::Reset(JamAI::EPlaytester Kind, uint64 Seed, int ChargeFramesMax, bool bSprint, const UJamSim& Sim)
	{
		Tester = JamAI::FJamPlaytester();
		Tester.Reset(Kind, Seed);                                         // 869
		Tester.ChargeFramesMax = ChargeFramesMax;                         // 870
		Tester.bSprint = bSprint;                                         // 871
		// 872-907 with no JAM_PLAYTESTER_* variable set: the measurement arms off, the config's switches as the config says.
		const FJamGameConfig& G = Sim.GetConfig();
		Tester.bRestStick = false;
		Tester.bOldVerbs = false;
		Tester.bOldCheck = !G.Contact.bPlaytesterClosingPress;
		Tester.bCourseCheck = !Tester.bOldCheck && G.Contact.bPlaytesterCoursePress;
		Tester.BraceMode = (G.Contact.bCrossHold && G.Contact.bMomentum && G.Skater.bCheckEnabled) ? 1 : 0;
		Tester.bContestBrake = false;
		Tester.ContestOnlyNth = 0;
		Tester.bStopMarkStopOnly = false;
		Tester.StopDefTowardMps = 0.0;
		Tester.bStopMarkBrake = false;
		Tester.StopOnlyNth = 0;
		Tester.StopHandFrames = -1;
		Tester.bPokeReadOn = G.Stick.bPlaytesterPokeRead;
		if (G.Stick.bPokeRulesOff) Tester.bPokeReadOn = false;
		Tester.StickVariant = 0;
		bOn = true;
	}

	// RunPlaytestMatch's PlaytesterAbility (JamPlaytester.cpp:814-852), copied: a held, ready ability is used where a player would.
	static bool PlaytesterAbility(const UJamSim& Sm, int P, const JamAI::FJamAIInput& I)
	{
		const FJamAbilityConfig* A = Sm.HeldAbility(P);
		if (!A) { return false; }
		const FJamSkaterState& K = Sm.GetSkaters()[P];
		if (K.AbilityCharges == 0 || Sm.GetFrame() + 1 < K.AbilityReadyFrame || !K.AbilityArmed.IsNone() || K.ShieldFrames > 0 || !K.CanAct()) { return false; }
		const bool bCarry = Sm.CarrierIndex() == P;
		const FVector2D Fwd = K.Forward();
		if (A->Kind == FName(TEXT("shotgun")))
		{
			if (!bCarry) { return false; }
			if (I.bShoot || (I.bShootHeld && K.ChargeFrames == 0)) { return true; }
			const FVector2D ToGoal = (FVector2D(Sm.AttackGoalX(K.Team), 0.0) - K.Pos).GetSafeNormal();
			if (FVector2D::DotProduct(Fwd, ToGoal) < 0.7) { return false; }
			for (const FJamSkaterState& O : Sm.GetSkaters())
			{
				if (O.Team == K.Team || O.IsDown() || O.InBox()) { continue; }
				const FVector2D D = O.Pos - K.Pos;
				const double Along = FVector2D::DotProduct(D, Fwd);
				if (Along > 0.5 && Along < 15.0 && FMath::Abs(FVector2D::CrossProduct(Fwd, D)) <= 1.0) { return true; }
			}
			return false;
		}
		if (A->Kind == FName(TEXT("hip_check")))
		{
			if (I.bCheck) { return true; }
			const int C = Sm.CarrierIndex();
			return C >= 0 && Sm.GetSkaters()[C].Team != K.Team && FVector2D::Distance(Sm.GetSkaters()[C].Pos, K.Pos) <= 1.2;
		}
		if (A->Kind == FName(TEXT("slow_puck"))) { return bCarry; }
		if (A->Kind == FName(TEXT("shield")))
		{
			if (!bCarry) { return false; }
			const int O = Sm.NearestOpponent(K);
			return O >= 0 && FVector2D::Distance(Sm.GetSkaters()[O].Pos, K.Pos) <= 4.0;
		}
		return false;
	}

	JamAI::FJamAIInput FPlaytesterSeat::Think(const JamAI::FJamAIWorld& W, const UJamSim& Sim, int Pi)
	{
		JamAI::FJamAIInput I = Tester.Think(W);                           // 984
		I.bAbility = PlaytesterAbility(Sim, Pi, I);                       // 992
		return I;
	}
}
