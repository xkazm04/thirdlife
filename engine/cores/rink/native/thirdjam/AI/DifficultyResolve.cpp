// Lane A3: see DifficultyResolve.h.
#include "DifficultyResolve.h"

#include "JamCartridge.h"
#include "JamJson.h"
#include "JamSimAdapter.h"

namespace JamAI
{
	bool ResolveDifficulty(const UJamCartridge& Cart, FJamDifficultyResolution& Out, const TCHAR* DifficultyOverride)
	{
		Out = FJamDifficultyResolution();
		TSharedPtr<FJamJson> Ai, Values;
		FString ParseErr;
		if (TSharedPtr<FJamJson> Root = FJamJson::Parse(Cart.RawJson, ParseErr))
		{
			if (TSharedPtr<FJamJson> Game = Root->Get(TEXT("game")); Game && Game->IsObject())
			{
				Ai = Game->Get(TEXT("ai"));
			}
			Values = Root->Get(TEXT("values"));
		}
		if (Ai && Ai->IsObject())
		{
			if (TSharedPtr<FJamJson> L = Ai->Get(TEXT("difficulty")); L && L->IsString())
			{
				Out.bLevelWritten = ParseDifficulty(TCHAR_TO_UTF8(*L->String), Out.Level);
			}
		}
		if (DifficultyOverride && *DifficultyOverride)
		{
			if (!ParseDifficulty(TCHAR_TO_UTF8(DifficultyOverride), Out.Level))
			{
				return false;
			}
		}
		ApplyDifficultyProfile(GetDifficultyProfile(Out.Level), Out.Params);
		{
			// R-0009 point 4: the level's large-rink offsets
			const FJamDifficultyProfile& Prof = GetDifficultyProfile(Out.Level);
			if (Cart.Game.Rink.LengthM >= LargeRinkM)
			{
				if (Prof.LargeSpeedScale > 0.0) { Out.Params.SpeedScale = Prof.LargeSpeedScale; }
				if (Prof.LargeRedSkill > 0.0) { Out.Params.RedSkill = Prof.LargeRedSkill; }
			}
		}
		// 2. explicit game.ai numbers (the loaded values, which the loader read from exactly these keys)
		const FJamAiConfig& G = Cart.Game.Ai;
		struct FKey { const TCHAR* Name; double* Dst; double Src; };
		const FKey Keys[] = {
			{ TEXT("yield_margin_m"), &Out.Params.YieldMarginM, G.YieldMarginM }, { TEXT("yield_radius_m"), &Out.Params.YieldRadiusM, G.YieldRadiusM },
			{ TEXT("hold_radius_m"), &Out.Params.HoldRadiusM, G.HoldRadiusM }, { TEXT("speed_scale"), &Out.Params.SpeedScale, G.SpeedScale },
			{ TEXT("red_skill"), &Out.Params.RedSkill, G.RedSkill },
		};
		for (const FKey& K : Keys)
		{
			if (Ai && Ai->IsObject() && Ai->Has(K.Name))
			{
				*K.Dst = K.Src;
				if (K.Dst == &Out.Params.SpeedScale) { Out.Params.MateSpeedScale = 0.0; }   // lane A112: a cartridge's own speed scale is every bot's (the mode keeps its character)
				Out.ExplicitKeys.Add(FString(TEXT("game.ai.")) + K.Name);
			}
		}
		// lane A72 (asks A4, A5): the opposing bots' reaction delay and body check from the cartridge (the level's Opp skill otherwise)
		if (Ai && Ai->IsObject() && Ai->Has(TEXT("react_frames")))
		{
			Out.Params.Opp.ReactionFrames = FMath::Clamp(G.ReactFrames, 0, kMaxReactionFrames);
			Out.ExplicitKeys.Add(TEXT("game.ai.react_frames"));
		}
		if (Ai && Ai->IsObject() && Ai->Has(TEXT("body_check")))
		{
			const double Share = FMath::Clamp(G.BodyCheck, 0.0, 1.0);
			Out.Params.Opp.BodyCheckShare = Share;
			// a chance is the level's rule at the closing speed the sim lands a check on; at rookie (never) a share above 0 turns the rule on
			Out.Params.Opp.CheckMinClosing = Share > 0.0 ? Cart.Game.Skater.CheckSpeedMin : -1.0;
			Out.ExplicitKeys.Add(TEXT("game.ai.body_check"));
		}
		if (Ai && Ai->IsObject() && Ai->Has(TEXT("sprint")))
		{
			Out.Params.SprintShare = FMath::Clamp(G.Sprint, 0.0, 1.0);   // lane A72 (ask A2)
			Out.ExplicitKeys.Add(TEXT("game.ai.sprint"));
		}
		// 3. Designer values (the loader already folded them into Cart.Game.Ai; a value outranks the game field)
		if (Values && Values->IsObject())
		{
			if (Values->Has(TEXT("ai_speed_scale"))) { Out.Params.SpeedScale = G.SpeedScale; Out.Params.MateSpeedScale = 0.0; Out.ExplicitKeys.Add(TEXT("values.ai_speed_scale")); }
			if (Values->Has(TEXT("ai_red_skill"))) { Out.Params.RedSkill = G.RedSkill; Out.ExplicitKeys.Add(TEXT("values.ai_red_skill")); }
		}
		// sim facts the skills read
		Out.Params.InterceptSpeed = Cart.Game.Skater.Speed;
		Out.Params.FreeSpeedMult = Cart.Game.Skater.FreeSpeedMult;   // lane A193 (track Q2 evolution 7): read only by the true-speed rules
		Out.Params.AimConeDeg = Cart.Game.Shot.bHasAimCone ? Cart.Game.Shot.AimConeDeg : 0.0;
		return true;
	}

	FJamMatchConfig ToMatchConfigResolved(const UJamCartridge& Cart, const TCHAR* DifficultyOverride)
	{
		FJamMatchConfig C = ToMatchConfig(Cart.Game);
		FJamDifficultyResolution R;
		ResolveDifficulty(Cart, R, DifficultyOverride);
		C.AI = R.Params;
		return C;
	}
}
