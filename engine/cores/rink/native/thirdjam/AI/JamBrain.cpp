// Lane A2: see JamBrain.h.
#include "JamBrain.h"
#include "DifficultyResolve.h"
#include "ProfilingDebugging/CpuProfilerTrace.h"
#include "ProfilingDebugging/CsvProfiler.h"

// Lane A106 (track Q3): the brain's cost per frame, measurable in a Development package (CSV column Jam/BrainThink, Insights timer JamBrainThink).
// Instrumentation only: no decision reads it.
CSV_DEFINE_CATEGORY(Jam, true);

void UJamBrain::ApplyCartridge(const UJamCartridge& Cart, const TCHAR* DifficultyOverride)
{
	JamAI::FJamDifficultyResolution R;
	JamAI::ResolveDifficulty(Cart, R, DifficultyOverride);
	Core.Params = R.Params;
	Difficulty = FName(JamAI::DifficultyName(R.Level));
	YieldMarginM = static_cast<float>(R.Params.YieldMarginM);
	YieldRadiusM = static_cast<float>(R.Params.YieldRadiusM);
	HoldRadiusM = static_cast<float>(R.Params.HoldRadiusM);
	SpeedScale = static_cast<float>(R.Params.SpeedScale);
	RedSkill = static_cast<float>(R.Params.RedSkill);
}

void UJamBrain::ApplyParams()
{
	Core.Params.YieldMarginM = YieldMarginM;
	Core.Params.YieldRadiusM = YieldRadiusM;
	Core.Params.HoldRadiusM = HoldRadiusM;
	Core.Params.SpeedScale = SpeedScale;
	Core.Params.RedSkill = RedSkill;
}

void UJamBrain::ResetBrain()
{
	ApplyParams();
	Core.Reset();
}

void UJamBrain::Think(const JamAI::FJamAIWorld& W, JamAI::FJamAIInput* Out)
{
	TRACE_CPUPROFILER_EVENT_SCOPE(JamBrainThink);
	CSV_SCOPED_TIMING_STAT(Jam, BrainThink);
	Core.Think(W, Out);
}

JamAI::FJamAIInput UJamPlayerBot::Think(const JamAI::FJamAIWorld& W) const
{
	JamAI::FJamPlayerBot Bot;
	if (!bWinnerVariant)
	{
		Bot.ShootRangeM = 22.0;
		Bot.bPeelToMiddle = false;
	}
	return Bot.Think(W);
}
