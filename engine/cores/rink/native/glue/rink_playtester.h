// Third Life rink core: thirdjam's playtester (AI/JamPlaytester.h FJamPlaytester: novice, regular, good) seated on the human's skater
// exactly as JamAI::RunPlaytestMatch seats it (AI/JamPlaytester.cpp:809-1000), so the core can play the human-like hand and expose
// its per-frame decision. Only what reaches the sim is taken over: the setup with no JAM_PLAYTESTER_* environment (every
// measurement arm off; the config-driven switches as the config says) and the per-frame ability rule; RunPlaytestMatch's statistics
// are not.
#pragma once

#include "CoreMinimal.h"
#include "JamSim.h"
#include "JamPlaytester.h"

namespace RinkGlue
{
	struct FPlaytesterSeat
	{
		JamAI::FJamPlaytester Tester;
		bool bOn = false;
		// RunPlaytestMatch's setup (JamPlaytester.cpp:855-905 with the environment absent).
		void Reset(JamAI::EPlaytester Kind, uint64 Seed, int ChargeFramesMax, bool bSprint, const UJamSim& Sim);
		// One frame: Tester.Think on the world, then the ability press (JamPlaytester.cpp:984-993).
		JamAI::FJamAIInput Think(const JamAI::FJamAIWorld& W, const UJamSim& Sim, int Pi);
	};
}
