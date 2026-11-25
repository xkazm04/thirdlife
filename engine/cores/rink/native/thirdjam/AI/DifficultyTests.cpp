// Lane A3: difficulty tests. Headless, no world:
//   UnrealEditor-Cmd ThirdJam.uproject -ExecCmds="Automation RunTests Jam.Bot.DifficultyProfilesResolve; Quit" -nullrhi -unattended -nopause -stdout
//   UnrealEditor-Cmd ThirdJam.uproject -ExecCmds="Automation RunTests Jam.Slow.DifficultyCurve; Quit" ...   (slow: 20 matches)
#include "CoreMinimal.h"
#include "Misc/AutomationTest.h"
#include "Misc/FileHelper.h"

#include "DifficultyProfile.h"
#include "DifficultyResolve.h"
#include "JamBotMatch.h"
#include "JamBrain.h"
#include "JamCartridge.h"
#include "JamSimAdapter.h"

#if WITH_DEV_AUTOMATION_TESTS

namespace JamDifficultyTestsLocal
{
	// hockey.regular with its `"difficulty": "pro"` and `"values": {}` replaced by the given JSON fragments.
	UJamCartridge* Variant(FAutomationTestBase& T, const TCHAR* Cartridge, const FString& AiBody, const FString& ValuesBody)
	{
		FString Json;
		if (!FFileHelper::LoadFileToString(Json, *UJamCartridge::ResolveCartridgePath(Cartridge)))
		{
			T.AddError(FString::Printf(TEXT("FAIL %s does not read"), Cartridge));
			return nullptr;
		}
		const int32 A = Json.ReplaceInline(TEXT("\"difficulty\": \"pro\""), *AiBody);
		const int32 V = Json.ReplaceInline(TEXT("\"values\": {}"), *FString::Printf(TEXT("\"values\": {%s}"), *ValuesBody));
		if (A != 1 || V != 1)
		{
			T.AddError(FString::Printf(TEXT("FAIL %s: expected one ai.difficulty and one empty values to replace (got %d, %d)"), Cartridge, A, V));
			return nullptr;
		}
		TArray<FString> Errors;
		UJamCartridge* C = UJamCartridge::LoadFromString(Json, Errors);
		if (!C)
		{
			T.AddError(FString::Printf(TEXT("FAIL variant {%s} {%s} does not load: %s"), *AiBody, *ValuesBody, *FString::Join(Errors, TEXT("; "))));
		}
		return C;
	}

	bool SameSkill(const JamAI::FJamBotSkill& A, const JamAI::FJamBotSkill& B)
	{
		return A.ReactionFrames == B.ReactionFrames && A.AimErrorDeg == B.AimErrorDeg && A.ShootExtraM == B.ShootExtraM && A.AimToleranceDeg == B.AimToleranceDeg
			&& A.LeadFrames == B.LeadFrames && A.bIntercept == B.bIntercept && A.bUseAimCone == B.bUseAimCone && A.PassToHuman == B.PassToHuman && A.bClearLane == B.bClearLane && A.bBlockShots == B.bBlockShots && A.BlockMinDistM == B.BlockMinDistM
			&& A.PokeFrames == B.PokeFrames && A.bLift == B.bLift && A.bPassOut == B.bPassOut && A.bReadLanes == B.bReadLanes && A.bSeekPickups == B.bSeekPickups
			&& A.DrawJumpPct == B.DrawJumpPct && A.DrawPressPct == B.DrawPressPct && A.DrawPressFrames == B.DrawPressFrames;
	}
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamDifficultyProfilesResolve, "Jam.Bot.DifficultyProfilesResolve",
	EAutomationTestFlags::EditorContext | EAutomationTestFlags::CommandletContext | EAutomationTestFlags::EngineFilter)

bool FJamDifficultyProfilesResolve::RunTest(const FString& Parameters)
{
	using namespace JamDifficultyTestsLocal;
	using namespace JamAI;

	// pro is the brain's default: code that never heard of a level plays pro
	{
		const FJamAIParams D;
		const FJamDifficultyProfile& P = GetDifficultyProfile(EDifficulty::Pro);
		TestTrue(TEXT("pro profile equals the FJamAIParams defaults"), P.SpeedScale == D.SpeedScale && P.RedSkill == D.RedSkill && P.YieldMarginM == D.YieldMarginM
			&& P.YieldRadiusM == D.YieldRadiusM && P.HoldRadiusM == D.HoldRadiusM && P.StallFrames == D.StallFrames && SameSkill(P.Opp, D.Opp) && SameSkill(D.Mate, FJamBotSkill()));
	}
	// the levels are ordered: rookie is easier than pro, pro easier than all_star
	{
		const FJamDifficultyProfile& R = GetDifficultyProfile(EDifficulty::Rookie);
		const FJamDifficultyProfile& P = GetDifficultyProfile(EDifficulty::Pro);
		const FJamDifficultyProfile& S = GetDifficultyProfile(EDifficulty::AllStar);
		TestTrue(TEXT("reaction rookie >= pro >= all_star"), R.Opp.ReactionFrames >= P.Opp.ReactionFrames && P.Opp.ReactionFrames >= S.Opp.ReactionFrames);
		TestTrue(TEXT("aim error rookie >= pro >= all_star"), R.Opp.AimErrorDeg >= P.Opp.AimErrorDeg && P.Opp.AimErrorDeg >= S.Opp.AimErrorDeg);
		// opponents' hold radius is not ordered: the sweep showed a held-off human touches the puck less (BALANCING.md)
		TestTrue(TEXT("hold radius pro >= all_star"), P.HoldRadiusM >= S.HoldRadiusM);
		TestTrue(TEXT("teammate yield rookie >= pro"), R.YieldMarginM >= P.YieldMarginM && R.YieldRadiusM >= P.YieldRadiusM);
		TestTrue(TEXT("shot range rookie <= pro <= all_star"), R.Opp.ShootExtraM <= P.Opp.ShootExtraM && P.Opp.ShootExtraM <= S.Opp.ShootExtraM);
		TestTrue(TEXT("all_star intercepts"), S.Opp.bIntercept);
		// R-0050 point 4 (lane A112): with the kept puck the rookie pokes too (it had no way to take a carried puck but a hit); the later the easier
		TestTrue(TEXT("R-0017 / R-0050: every level pokes, rookie latest, all_star soonest"), R.Opp.PokeFrames >= P.Opp.PokeFrames && P.Opp.PokeFrames >= S.Opp.PokeFrames && S.Opp.PokeFrames >= 0);
		TestTrue(TEXT("R-0013 draws: the opposing centre jumps early least often at all_star (the human's opening touch)"),
			S.Opp.DrawJumpPct <= P.Opp.DrawJumpPct && S.Opp.DrawJumpPct <= R.Opp.DrawJumpPct && S.Opp.DrawJumpPct > 0);
		TestTrue(TEXT("R-0017: only all_star seeks pickups"), !R.Opp.bSeekPickups && !P.Opp.bSeekPickups && S.Opp.bSeekPickups);
		TestTrue(TEXT("R-0017: all_star passes; pro and all_star read lanes"), S.Opp.bPassOut && P.Opp.bReadLanes && S.Opp.bReadLanes);
		TestTrue(TEXT("reaction inside the ring"), R.Opp.ReactionFrames <= kMaxReactionFrames);
	}
	// names
	{
		EDifficulty L = EDifficulty::Pro;
		TestTrue(TEXT("parse rookie"), ParseDifficulty("rookie", L) && L == EDifficulty::Rookie);
		TestTrue(TEXT("parse all_star"), ParseDifficulty("all_star", L) && L == EDifficulty::AllStar);
		TestFalse(TEXT("All_Star is not a level"), ParseDifficulty("All_Star", L));
		TestFalse(TEXT("hard is not a level"), ParseDifficulty("hard", L));
	}
	// each level resolves to exactly its profile numbers
	const TCHAR* Names[] = { TEXT("rookie"), TEXT("pro"), TEXT("all_star") };
	const EDifficulty Levels[] = { EDifficulty::Rookie, EDifficulty::Pro, EDifficulty::AllStar };
	for (int32 k = 0; k < 3; ++k)
	{
		UJamCartridge* C = Variant(*this, TEXT("hockey.regular"), FString::Printf(TEXT("\"difficulty\": \"%s\""), Names[k]), TEXT(""));
		if (!C) { continue; }
		FJamDifficultyResolution R;
		TestTrue(TEXT("resolves"), ResolveDifficulty(*C, R));
		const FJamDifficultyProfile& P = GetDifficultyProfile(Levels[k]);
		TestTrue(FString::Printf(TEXT("%s: level read from the cartridge"), Names[k]), R.bLevelWritten && R.Level == Levels[k]);
		TestTrue(FString::Printf(TEXT("%s: numbers are the profile's"), Names[k]), R.Params.SpeedScale == P.SpeedScale && R.Params.RedSkill == P.RedSkill
			&& R.Params.YieldMarginM == P.YieldMarginM && R.Params.YieldRadiusM == P.YieldRadiusM && R.Params.HoldRadiusM == P.HoldRadiusM
			&& R.Params.StallFrames == P.StallFrames && SameSkill(R.Params.Opp, P.Opp) && R.Params.Mate.PassToHuman == P.MatesPassShare);
		TestEqual(FString::Printf(TEXT("%s: nothing explicit"), Names[k]), R.ExplicitKeys.Num(), 0);
		TestEqual(TEXT("intercept speed is skater.speed"), R.Params.InterceptSpeed, C->Game.Skater.Speed);
		TestEqual(TEXT("aim cone from shot.aim_cone_deg"), R.Params.AimConeDeg, C->Game.Shot.bHasAimCone ? C->Game.Shot.AimConeDeg : 0.0);
		// the brain's UObject face resolves the same way
		UJamBrain* B = NewObject<UJamBrain>();
		B->ApplyCartridge(*C);
		TestEqual(TEXT("UJamBrain::ApplyCartridge names the level"), B->Difficulty, FName(Names[k]));
		TestEqual(TEXT("UJamBrain::ApplyCartridge hold radius"), static_cast<double>(B->HoldRadiusM), static_cast<double>(static_cast<float>(P.HoldRadiusM)));
	}
	// absent level = pro
	{
		UJamCartridge* C = Variant(*this, TEXT("hockey.regular"), TEXT("\"hold_radius_m\": 4.5"), TEXT(""));
		FJamDifficultyResolution R;
		if (C && ResolveDifficulty(*C, R))
		{
			TestTrue(TEXT("absent level is pro"), !R.bLevelWritten && R.Level == EDifficulty::Pro);
		}
	}
	// explicit game.ai numbers override the profile; the rest of the profile stays
	{
		UJamCartridge* C = Variant(*this, TEXT("hockey.regular"), TEXT("\"difficulty\": \"rookie\", \"hold_radius_m\": 3, \"speed_scale\": 0.7"), TEXT(""));
		FJamDifficultyResolution R;
		if (C && ResolveDifficulty(*C, R))
		{
			const FJamDifficultyProfile& P = GetDifficultyProfile(EDifficulty::Rookie);
			TestEqual(TEXT("explicit hold_radius_m wins"), R.Params.HoldRadiusM, 3.0);
			TestEqual(TEXT("explicit speed_scale wins"), R.Params.SpeedScale, 0.7);
			TestEqual(TEXT("unwritten red_skill stays rookie"), R.Params.RedSkill, P.RedSkill);
			TestEqual(TEXT("unwritten yield_margin_m stays rookie"), R.Params.YieldMarginM, P.YieldMarginM);
			TestTrue(TEXT("rookie skill stays"), SameSkill(R.Params.Opp, P.Opp));
			TestEqual(TEXT("two explicit keys"), R.ExplicitKeys.Num(), 2);
		}
	}
	// Designer values outrank both
	{
		UJamCartridge* C = Variant(*this, TEXT("hockey.regular"), TEXT("\"difficulty\": \"all_star\", \"speed_scale\": 0.7"), TEXT("\"ai_speed_scale\": 0.5, \"ai_red_skill\": 0.4"));
		FJamDifficultyResolution R;
		if (C && ResolveDifficulty(*C, R))
		{
			TestEqual(TEXT("values.ai_speed_scale wins over game.ai.speed_scale"), R.Params.SpeedScale, 0.5);
			TestEqual(TEXT("values.ai_red_skill wins over the profile"), R.Params.RedSkill, 0.4);
			TestTrue(TEXT("all_star skill stays"), SameSkill(R.Params.Opp, GetDifficultyProfile(EDifficulty::AllStar).Opp));
		}
	}
	// an override (sweeps) replaces the level, not the explicit numbers
	{
		UJamCartridge* C = Variant(*this, TEXT("hockey.regular"), TEXT("\"difficulty\": \"rookie\", \"hold_radius_m\": 3"), TEXT(""));
		FJamDifficultyResolution R;
		if (C && ResolveDifficulty(*C, R, TEXT("all_star")))
		{
			TestTrue(TEXT("override level"), R.Level == EDifficulty::AllStar && SameSkill(R.Params.Opp, GetDifficultyProfile(EDifficulty::AllStar).Opp));
			TestEqual(TEXT("explicit number kept under an override"), R.Params.HoldRadiusM, 3.0);
		}
		FJamDifficultyResolution Bad;
		if (C) { TestFalse(TEXT("bad override"), ResolveDifficulty(*C, Bad, TEXT("legend"))); }
	}
	// every shipped preset is pro
	for (const TCHAR* Preset : { TEXT("hockey.regular"), TEXT("hockey.arena.large"), TEXT("hockey.arena.wide"), TEXT("hockey.raw"), TEXT("hockey.boost") })
	{
		TArray<FString> Errors;
		UJamCartridge* C = UJamCartridge::LoadFromFile(UJamCartridge::ResolveCartridgePath(Preset), Errors);
		FJamDifficultyResolution R;
		if (TestNotNull(FString::Printf(TEXT("%s loads"), Preset), C) && ResolveDifficulty(*C, R))
		{
			TestTrue(FString::Printf(TEXT("%s is pro"), Preset), R.bLevelWritten && R.Level == EDifficulty::Pro && R.ExplicitKeys.Num() == 0);
		}
	}
	return !HasAnyErrors();
}

// Slow (20 matches): rookie must give the scripted human more wins than all_star, seeds 1-5, on both preset rinks (a tie on wins
// is decided by goal difference).
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamDifficultyCurve, "Jam.Slow.DifficultyCurve",
	EAutomationTestFlags::EditorContext | EAutomationTestFlags::CommandletContext | EAutomationTestFlags::EngineFilter)

bool FJamDifficultyCurve::RunTest(const FString& Parameters)
{
	using namespace JamAI;
	bool bOk = true;
	for (const TCHAR* Preset : { TEXT("hockey.regular"), TEXT("hockey.arena.large") })
	{
		TArray<FString> Errors;
		UJamCartridge* C = UJamCartridge::LoadFromFile(UJamCartridge::ResolveCartridgePath(Preset), Errors);
		if (!C) { AddError(FString::Printf(TEXT("FAIL %s does not load"), Preset)); bOk = false; continue; }
		int32 Wins[2] = {0, 0}, Diff[2] = {0, 0};
		const TCHAR* Levels[2] = { TEXT("rookie"), TEXT("all_star") };
		for (int32 k = 0; k < 2; ++k)
		{
			const FJamMatchConfig Cfg = ToMatchConfigResolved(*C, Levels[k]);
			const int32 Pi = Cfg.PlayerIndex();
			const int32 Us = Cfg.Skaters[Pi].Team;
			for (uint64 Seed = 1; Seed <= 5; ++Seed)
			{
				FJamSimAdapter Sim(*C);   // lane A41: with the game mode's systems
				const FJamMatchStats S = RunMatch(Sim, Cfg, Seed, EJamPlayerMode::PlayerBot, 36000, 600);
				Wins[k] += (S.bOver && S.Winner == Us) ? 1 : 0;
				Diff[k] += S.Goals[Us] - S.Goals[1 - Us];
			}
		}
		const FString Msg = FString::Printf(TEXT("%s seeds 1-5: human wins rookie %d (goal diff %+d), all_star %d (goal diff %+d)"), Preset, Wins[0], Diff[0], Wins[1], Diff[1]);
		// five seeds are a small sample (the 20-seed sweep is 90% vs 25%): equal wins pass when rookie has the better goal difference
		if (Wins[0] > Wins[1] || (Wins[0] == Wins[1] && Diff[0] > Diff[1])) { AddInfo(TEXT("PASS ") + Msg); }
		else { AddError(TEXT("FAIL ") + Msg); bOk = false; }
	}
	return bOk;
}

#endif
