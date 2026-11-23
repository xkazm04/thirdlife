// Lane A1 tests (headless, no world): Jam.Core.CartridgeRoundTrip, Jam.Core.CartridgeParity, Jam.Core.ScoreOnEmptyNet,
// Jam.Core.Determinism, Jam.Core.PuckNeverTunnels, Jam.Core.Feel. Run:
//   UnrealEditor-Cmd.exe Game/ThirdJam.uproject -ExecCmds="Automation RunTests Jam.Core; Quit" -unattended -nullrhi -nosplash -log
#include "Misc/AutomationTest.h"
#include "Misc/FileHelper.h"
#include "Misc/Paths.h"
#include "HAL/FileManager.h"
#include "JamCartridge.h"
#include "JamJson.h"
#include "JamSim.h"
#include "JamEventBus.h"

#if WITH_DEV_AUTOMATION_TESTS

namespace JamCoreTests
{
	constexpr EAutomationTestFlags Flags = EAutomationTestFlags_ApplicationContextMask | EAutomationTestFlags::ProductFilter;

	UJamCartridge* LoadPreset(FAutomationTestBase& T, const FString& Name)
	{
		TArray<FString> Errors;
		UJamCartridge* C = UJamCartridge::LoadFromFile(UJamCartridge::ResolveCartridgePath(Name), Errors);
		for (const FString& E : Errors) T.AddError(FString::Printf(TEXT("%s: %s"), *Name, *E));
		return C;
	}

	UJamSim* MakeSim(const FJamGameConfig& Config, uint64 Seed, bool bSkipFaceoff = true)
	{
		UJamSim* Sim = NewObject<UJamSim>();
		Sim->Init(Config, Seed);
		// R-0013: a match opens with a 90-frame faceoff countdown; scripted scenes skip it (the Determinism test keeps it).
		if (bSkipFaceoff) Sim->SkipFaceoff();
		return Sim;
	}

	// Scripted attacker: get behind the puck on the line to the goal, then shoot when lined up.
	FJamInput Attack(const UJamSim& Sim, int32 Me)
	{
		const FJamSkaterState& S = Sim.GetSkaters()[Me];
		const FVector2D Puck = Sim.GetPuck().Pos;
		const FVector2D Goal(Sim.AttackGoalX(S.Team), 0.0);
		const FVector2D ToGoal = (Goal - Puck).GetSafeNormal();
		const FVector2D Behind = Puck - ToGoal * 0.7;
		FJamInput In;
		const FVector2D D = Behind - S.Pos;
		In.Move = D.Size() > 0.3 ? D.GetSafeNormal() : ToGoal;
		const FVector2D ToPuck = Puck - S.Pos;
		const double Dist = ToPuck.Size();
		const FVector2D Fwd = S.Forward();
		if (Dist < Sim.GetConfig().Shot.ReachM && FVector2D::DotProduct(Fwd, ToGoal) > 0.97 && FVector2D::DotProduct(Fwd, ToPuck / FMath::Max(Dist, 1e-6)) > 0.6)
		{
			In.bShoot = true;
		}
		return In;
	}
}

using namespace JamCoreTests;

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamCartridgeRoundTrip, "Jam.Core.CartridgeRoundTrip", JamCoreTests::Flags)
bool FJamCartridgeRoundTrip::RunTest(const FString& Parameters)
{
	TArray<FString> Files;
	IFileManager::Get().FindFiles(Files, *FPaths::Combine(UJamCartridge::GetCartridgeDir(), TEXT("*.json")), true, false);
	// Lane A67 (R-0036): the Director's choices in modes/ go through the same loader and sim checks.
	TArray<FString> Modes;
	IFileManager::Get().FindFiles(Modes, *FPaths::Combine(UJamCartridge::GetCartridgeDir(), TEXT("modes"), TEXT("*.cartridge.json")), true, false);
	for (const FString& M : Modes) Files.Add(FString(TEXT("modes/")) + M);
	Files.Sort();
	TestTrue(TEXT("the cartridge folder has files"), Files.Num() > 0);
	for (const FString& F : Files)
	{
		TArray<FString> Errors;
		UJamCartridge* C = UJamCartridge::LoadFromFile(FPaths::Combine(UJamCartridge::GetCartridgeDir(), F), Errors);
		for (const FString& E : Errors) AddError(FString::Printf(TEXT("%s: %s"), *F, *E));
		if (!C) continue;
		TestEqual(*FString::Printf(TEXT("%s has two teams"), *F), C->Game.Teams.Num(), 2);
		UJamSim* Sim = MakeSim(C->Game, static_cast<uint64>(C->Seed));
		TestTrue(*FString::Printf(TEXT("%s has a human skater"), *F), Sim->GetSkaters().IsValidIndex(Sim->GetHumanIndex()) && Sim->GetSkaters()[Sim->GetHumanIndex()].bHuman);
		// Spawns sit inside the boards in the sim's own geometry.
		for (const FJamSkaterState& S : Sim->GetSkaters())
		{
			FVector2D N;
			TestTrue(*FString::Printf(TEXT("%s skater %d inside the boards"), *F, S.Index), Sim->BoardDistance(S.Pos, N) < 0);
		}
		AddInfo(FString::Printf(TEXT("%s: id=%s rink=%gx%g skaters=%d visual=%s tier=%s"), *F, *C->Id, C->Game.Rink.LengthM, C->Game.Rink.WidthM,
			Sim->GetSkaters().Num(), *C->Game.Skater.Visual.ToString(), *C->Game.Look.Tier));
	}

	// Defaults for absent keys and values overrides (schema/DEFAULTS.md, README "Tunables").
	{
		UJamCartridge* Reg = JamCoreTests::LoadPreset(*this, TEXT("hockey.regular"));
		if (Reg)
		{
			FString Text = Reg->RawJson;
			Text.ReplaceInline(TEXT("\"values\": {}"), TEXT("\"values\": {\"skater_speed\": 11, \"goal_pause_frames\": 90}"));
			TArray<FString> Errors;
			UJamCartridge* C = UJamCartridge::LoadFromString(Text, Errors);
			for (const FString& E : Errors) AddError(E);
			if (C)
			{
				TestEqual(TEXT("values override skater.speed"), C->Game.Skater.Speed, 11.0);
				TestEqual(TEXT("values override goal_pause_frames"), C->Game.Rules.GoalPauseFrames, 90);
				TestEqual(TEXT("absent visual = humanoid_b1"), C->Game.Skater.Visual, FName(TEXT("humanoid_b1")));
				TestEqual(TEXT("absent knockdown_frames = 90"), C->Game.Skater.KnockdownFrames, 90);
				TestTrue(TEXT("aim cone present"), C->Game.Shot.bHasAimCone);
				TestEqual(TEXT("team 0 colour from hex"), C->Game.Teams[0].Colour.ToFColorSRGB(), FColor(0x1D, 0x4E, 0xD8));
			}
		}
	}

	// The embedded schema equals schema/ on disk (regenerate with Game/Source/JamCore/Tools/gen-schema-data.mjs).
	const FString SchemaDir = FPaths::ConvertRelativePathToFull(FPaths::Combine(FPaths::ProjectDir(), TEXT(".."), TEXT("schema")));
	if (IFileManager::Get().DirectoryExists(*SchemaDir))
	{
		for (const TCHAR* Name : { TEXT("cartridge.schema.json"), TEXT("game.schema.json"), TEXT("limits.json") })
		{
			TArray<uint8> Disk;
			FFileHelper::LoadFileToArray(Disk, *FPaths::Combine(SchemaDir, Name));
			FString Gen;
			FFileHelper::LoadFileToString(Gen, *FPaths::Combine(FPaths::GameSourceDir(), TEXT("JamCore/Private/JamSchemaData.inl")));
			// Cheap staleness check: the byte count of each file appears in the generated array as its length.
			const FString Marker = FString::Printf(TEXT("JamSchema_%s"), *FString(Name).Replace(TEXT("."), TEXT("_")));
			TestTrue(*FString::Printf(TEXT("%s embedded"), Name), Gen.Contains(Marker));
			int32 Count = 0;
			const int32 Start = Gen.Find(Marker);
			const int32 End = Gen.Find(TEXT("};"), ESearchCase::CaseSensitive, ESearchDir::FromStart, Start);
			for (int32 i = Start; i >= 0 && i < End; ++i) if (Gen[i] == ',') ++Count;
			TestEqual(*FString::Printf(TEXT("%s embedded copy is current (bytes)"), Name), Count, Disk.Num());
		}
	}
	return true;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamCartridgeParity, "Jam.Core.CartridgeParity", JamCoreTests::Flags)
bool FJamCartridgeParity::RunTest(const FString& Parameters)
{
	const FString Path = FPaths::Combine(FPaths::GameSourceDir(), TEXT("JamCore/Tools/parity.json"));
	FString Text;
	if (!FFileHelper::LoadFileToString(Text, *Path)) { AddWarning(TEXT("parity.json not found (source tree absent); skipped")); return true; }
	FString Err;
	TSharedPtr<FJamJson> Root = FJamJson::Parse(Text, Err);
	if (!Root) { AddError(Err); return false; }
	int32 Agree = 0, Total = 0;
	for (const TSharedPtr<FJamJson>& Case : Root->Get(TEXT("cases"))->Array)
	{
		++Total;
		const FString Name = Case->Get(TEXT("name"))->String;
		const bool bOk = Case->Get(TEXT("ok"))->Bool;
		TArray<FString> Want;
		for (const TSharedPtr<FJamJson>& P : Case->Get(TEXT("pointers"))->Array) Want.Add(P->String);
		TArray<FString> Errors;
		const bool bGot = UJamCartridge::Validate(Case->Get(TEXT("text"))->String, Errors);
		TArray<FString> Got;
		for (const FString& E : Errors)
		{
			FString P = E.StartsWith(TEXT("at ")) ? E.Mid(3) : TEXT("?");
			int32 Colon;
			if (P.FindChar(':', Colon)) P = P.Left(Colon);
			Got.AddUnique(P);
		}
		Got.Sort();
		Want.Sort();
		// "not json" fixtures: Node reports "/", so do we.
		const bool bSame = (bGot == bOk) && Got == Want;
		if (bSame) ++Agree;
		else AddError(FString::Printf(TEXT("parity %s: node ok=%d [%s], c++ ok=%d [%s] first error: %s"), *Name, bOk, *FString::Join(Want, TEXT(" ")),
			bGot, *FString::Join(Got, TEXT(" ")), Errors.Num() ? *Errors[0] : TEXT("-")));
	}
	AddInfo(FString::Printf(TEXT("parity %d of %d cases agree with schema/validate.mjs"), Agree, Total));
	return Agree == Total;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamScoreOnEmptyNet, "Jam.Core.ScoreOnEmptyNet", JamCoreTests::Flags)
bool FJamScoreOnEmptyNet::RunTest(const FString& Parameters)
{
	UJamCartridge* C = JamCoreTests::LoadPreset(*this, TEXT("hockey.regular"));
	if (!C) return false;
	UJamSim* Sim = MakeSim(C->Game, 1);
	const int32 Me = Sim->GetHumanIndex();
	// Empty the ice: everybody else to the side boards, standing still.
	for (const FJamSkaterState& S : Sim->GetSkaters())
	{
		if (S.Index != Me) Sim->SetSkater(S.Index, FVector2D(-40.0 + S.Index * 12.0, S.Index % 2 ? 25.0 : -25.0), FVector2D::ZeroVector, 0);
	}
	TArray<FJamInput> Inputs;
	Inputs.SetNum(Sim->GetSkaters().Num());
	int32 GoalFrame = -1, Shots = 0;
	for (int32 F = 0; F < 1800 && GoalFrame < 0; ++F)
	{
		Inputs[Me] = Attack(*Sim, Me);
		Sim->Step(Inputs);
		for (const FJamSimEvent& E : Sim->GetFrameEvents())
		{
			if (E.Name == JamEvents::Shot) ++Shots;
			if (E.Name == JamEvents::Goal) { GoalFrame = static_cast<int32>(Sim->GetFrame()); TestEqual(TEXT("goal credited to the shooter"), E.Who, Me); }
		}
	}
	AddInfo(FString::Printf(TEXT("goal at frame %d after %d shot(s); score %d:%d"), GoalFrame, Shots, Sim->GetScore(0), Sim->GetScore(1)));
	TestTrue(TEXT("scored within 1800 frames"), GoalFrame > 0);
	TestEqual(TEXT("team 0 scored"), Sim->GetScore(0), 1);
	TestEqual(TEXT("goal pause running"), Sim->GetPhase(), EJamSimPhase::GoalPause);
	// The pause ends in a faceoff at centre.
	TArray<FJamInput> None;
	bool bFaceoff = false;
	for (int32 F = 0; F < C->Game.Rules.GoalPauseFrames + UJamSim::FaceoffCountdownFrames + 2 && !bFaceoff; ++F)
	{
		Sim->Step(None);
		for (const FJamSimEvent& E : Sim->GetFrameEvents()) bFaceoff |= (E.Name == JamEvents::Faceoff);
	}
	TestTrue(TEXT("faceoff drop after goal_pause_frames + the countdown (R-0013)"), bFaceoff);
	TestTrue(TEXT("puck dropped near centre"), Sim->GetPuck().Pos.Size() <= UJamSim::FaceoffDropM + 1e-9);
	return true;
}

// Seeded random inputs for every skater, with shoot and check presses.
static uint64 RunScripted(UJamSim* Sim, uint64 Seed, int32 Frames, TArray<uint64>* OutHashes)
{
	FJamRandom In(Seed * 7919 + 13);
	TArray<FJamInput> Inputs;
	Inputs.SetNum(Sim->GetSkaters().Num());
	for (int32 F = 0; F < Frames; ++F)
	{
		for (int32 i = 0; i < Inputs.Num(); ++i)
		{
			if (F % 20 == 0) Inputs[i].Move = In.UnitVector2D() * In.Range(0.3, 1.0);
			Inputs[i].bShoot = In.NextUnit() < 0.08;
			Inputs[i].bCheck = In.NextUnit() < 0.03;
		}
		// The human chases the puck, so shots and goals happen.
		const int32 Me = Sim->GetHumanIndex();
		Inputs[Me] = JamCoreTests::Attack(*Sim, Me);
		Sim->Step(Inputs);
		if (OutHashes) OutHashes->Add(Sim->StateHash());
	}
	return Sim->StateHash();
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamDeterminism, "Jam.Core.Determinism", JamCoreTests::Flags)
bool FJamDeterminism::RunTest(const FString& Parameters)
{
	for (const TCHAR* Preset : { TEXT("hockey.regular"), TEXT("hockey.raw") })
	{
		UJamCartridge* C = JamCoreTests::LoadPreset(*this, Preset);
		if (!C) continue;
		TArray<uint64> A, B, Other;
		const double T0 = FPlatformTime::Seconds();
		RunScripted(MakeSim(C->Game, 1, false), 1, 600, &A);
		const double Ms = (FPlatformTime::Seconds() - T0) * 1000.0;
		RunScripted(MakeSim(C->Game, 1, false), 1, 600, &B);
		RunScripted(MakeSim(C->Game, 2, false), 2, 600, &Other);
		int32 FirstDiff = -1;
		for (int32 i = 0; i < A.Num(); ++i) if (A[i] != B[i]) { FirstDiff = i; break; }
		TestEqual(*FString::Printf(TEXT("%s: two runs at seed 1 agree on every frame"), Preset), FirstDiff, -1);
		TestNotEqual(*FString::Printf(TEXT("%s: seed 2 differs from seed 1 by frame 600"), Preset), A.Last(), Other.Last());
		// Restart() reproduces the match from frame 0.
		UJamSim* Sim = MakeSim(C->Game, 1, false);
		RunScripted(Sim, 1, 300, nullptr);
		Sim->Restart();
		TestEqual(*FString::Printf(TEXT("%s: restart reproduces the run"), Preset), RunScripted(Sim, 1, 600, nullptr), A.Last());
		AddInfo(FString::Printf(TEXT("%s seed 1 frame 600 hash %016llx; 600 frames in %.2f ms (%.4f ms/frame)"), Preset, static_cast<unsigned long long>(A.Last()), Ms, Ms / 600.0));
	}
	return true;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamPuckNeverTunnels, "Jam.Core.PuckNeverTunnels", JamCoreTests::Flags)
bool FJamPuckNeverTunnels::RunTest(const FString& Parameters)
{
	UJamCartridge* C = JamCoreTests::LoadPreset(*this, TEXT("hockey.regular"));
	if (!C) return false;
	FJamGameConfig Cfg = C->Game;
	for (const double MaxSpeed : { 30.0, 60.0 })
	{
		Cfg.Puck.MaxSpeed = MaxSpeed;
		UJamSim* Sim = MakeSim(Cfg, 1);
		for (const FJamSkaterState& S : Sim->GetSkaters()) Sim->SetSkater(S.Index, FVector2D(-20.0 + S.Index * 3.0, 20.0), FVector2D::ZeroVector, 0);
		const double GL = Sim->GoalLineX();
		const double Hw = Cfg.Rink.GoalWidthM * 0.5;
		FJamRandom R(5);
		TArray<FJamInput> None;
		int32 Escapes = 0, BackDoorGoals = 0, Launches = 0;
		double MaxSeen = 0;
		bool bFromBehind = false;
		for (int32 F = 0; F < 600; ++F)
		{
			if (F % 20 == 0)
			{
				// Alternate: at a post from the front, at the back wall from behind, at a side wall from outside.
				const int32 Kind = (F / 20) % 3;
				const double Side = ((F / 60) % 2) ? 1.0 : -1.0;
				FVector2D Target, From;
				if (Kind == 0) { Target = FVector2D(Side * GL, (R.NextUnit() < 0.5 ? -Hw : Hw)); From = Target + FVector2D(-Side * R.Range(3, 10), R.Range(-6, 6)); }
				else if (Kind == 1) { Target = FVector2D(Side * (GL + UJamSim::NetDepth), R.Range(-Hw, Hw)); From = Target + FVector2D(Side * 2.0, R.Range(-0.5, 0.5)); }
				else { Target = FVector2D(Side * (GL + 0.75), Hw); From = Target + FVector2D(R.Range(-0.5, 0.5), 2.0); }
				bFromBehind = Kind != 0;
				Sim->SetPuck(From, (Target - From).GetSafeNormal() * MaxSpeed);
				++Launches;
			}
			const int32 Before = Sim->GetScore(0) + Sim->GetScore(1);
			Sim->Step(None);
			if (Sim->GetScore(0) + Sim->GetScore(1) > Before && bFromBehind) ++BackDoorGoals;
			if (Sim->GetPhase() != EJamSimPhase::Playing) { Sim->Restart(); Sim->SkipFaceoff(); Sim->SetPuck(Sim->GetPuck().Pos, FVector2D::ZeroVector); }
			FVector2D N;
			const double D = Sim->BoardDistance(Sim->GetPuck().Pos, N) + Cfg.Puck.RadiusM;
			MaxSeen = FMath::Max(MaxSeen, D);
			if (D > 0.01) ++Escapes;
			for (const FJamSkaterState& S : Sim->GetSkaters()) if (Sim->BoardDistance(S.Pos, N) > 0.01) ++Escapes;
		}
		AddInfo(FString::Printf(TEXT("max %g m/s: %d launches, worst board overlap %.4f m, escapes %d, goals through a net wall %d"), MaxSpeed, Launches, MaxSeen, Escapes, BackDoorGoals));
		TestEqual(*FString::Printf(TEXT("max %g: puck stays inside the rink"), MaxSpeed), Escapes, 0);
		TestEqual(*FString::Printf(TEXT("max %g: no goal through the side or back of a net"), MaxSpeed), BackDoorGoals, 0);
	}
	return true;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamFeel, "Jam.Core.Feel", JamCoreTests::Flags)
bool FJamFeel::RunTest(const FString& Parameters)
{
	UJamCartridge* C = JamCoreTests::LoadPreset(*this, TEXT("hockey.regular"));
	if (!C) return false;
	UJamSim* Sim = MakeSim(C->Game, 1);
	const int32 Me = Sim->GetHumanIndex();
	for (const FJamSkaterState& S : Sim->GetSkaters()) if (S.Index != Me) Sim->SetSkater(S.Index, FVector2D(-40.0 + S.Index * 3.0, 25.0), FVector2D::ZeroVector, 0);
	Sim->SetSkater(Me, FVector2D(-50, -10), FVector2D::ZeroVector, 0);
	Sim->SetPuck(FVector2D(0, 25), FVector2D::ZeroVector);
	TArray<FJamInput> In;
	In.SetNum(Sim->GetSkaters().Num());
	In[Me].Move = FVector2D(1, 0);
	int32 ToTop = -1;
	for (int32 F = 1; F <= 120; ++F) { Sim->Step(In); if (ToTop < 0 && Sim->GetSkaters()[Me].Vel.Size() >= 7.99) ToTop = F; }
	AddInfo(FString::Printf(TEXT("0 to 8 m/s in %d frames (Godot: about 40; lane A93's first-step burst from rest: 23; lane A121: a standing skater has no burst, 41; lane A128: the standing start)"), ToTop));
	// Lane A93 (R-0045 law 3): the first-step burst (acceleration x 1.8 for 20 frames) took 0 to 8 m/s from 41 frames to 23. Lane A121 (track F2;
	// skater.burst.own_stop, default true): the first step is earned by a stop or a cut of the skater's own, so a skater that merely stands is back in the
	// 35..45 window; Jam.Core.Movement.Burst measures the burst itself (cases a and b with own_stop false, case d the earned step).
	// Lane A128 (track F2, evolution 3; skater.burst.rest_frames): a skater that starts from rest has earned its first step: 26 frames or fewer again.
	TestTrue(TEXT("a standing skater reaches top speed in 20..26 frames (the standing start; 35..45 with burst.rest_frames 0)"), ToTop >= 20 && ToTop <= 26);
	In[Me].Move = FVector2D::ZeroVector;
	Sim->SetSkater(Me, FVector2D(-55, -10), FVector2D(8, 0), 0);
	for (int32 F = 0; F < 300; ++F) Sim->Step(In);
	const double Glide = Sim->GetSkaters()[Me].Vel.Size();
	AddInfo(FString::Printf(TEXT("after 5 s of glide from 8 m/s: %.3f m/s"), Glide));
	TestTrue(TEXT("glide keeps more than 7 m/s after 5 s"), Glide > 7.0);
	return true;
}

#endif

#if WITH_DEV_AUTOMATION_TESTS
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamLiveConfig, "Jam.Core.LiveConfig", JamCoreTests::Flags)
bool FJamLiveConfig::RunTest(const FString& Parameters)
{
	// R-0010: the 120 x 60 speed-8 rink this test was written for is hockey.arena.large now (regular is 90 x 45 speed 11)
	UJamCartridge* C = JamCoreTests::LoadPreset(*this, TEXT("hockey.arena.large"));
	if (!C) return false;
	UJamSim* Sim = JamCoreTests::MakeSim(C->Game, 1);
	TArray<FJamInput> In;
	In.SetNum(Sim->GetSkaters().Num());
	for (int32 F = 0; F < 120; ++F) Sim->Step(In);
	const int64 FrameBefore = Sim->GetFrame();
	const FVector2D PosBefore = Sim->GetSkaters()[0].Pos;
	FJamGameConfig N = C->Game;
	N.Skater.Speed = 12;
	N.Shot.Speed = 25;
	N.Rink.IceFriction = 0.05;
	N.Rink.LengthM = 90; // geometry: must be held back
	const TArray<FString> Held = Sim->ApplyLiveConfig(N);
	TestEqual(TEXT("frame kept"), Sim->GetFrame(), FrameBefore);
	TestEqual(TEXT("positions kept"), Sim->GetSkaters()[0].Pos, PosBefore);
	TestEqual(TEXT("skater.speed live"), Sim->GetConfig().Skater.Speed, 12.0);
	TestEqual(TEXT("shot.speed live"), Sim->GetConfig().Shot.Speed, 25.0);
	TestEqual(TEXT("ice_friction live"), Sim->GetConfig().Rink.IceFriction, 0.05);
	TestEqual(TEXT("rink length held back"), Sim->GetConfig().Rink.LengthM, 120.0);
	TestTrue(TEXT("held list names rink.length_m"), Held.Contains(TEXT("rink.length_m")));
	// The new top speed is reachable. Lane A93: 90 frames, not 120: with the first-step burst the human is at 12 m/s after 42 frames and has skated into the
	// opposing centre 19 m up the ice by frame 114 (4.8 m/s at the bump); the measurement is taken before that meeting.
	In[Sim->GetHumanIndex()].Move = FVector2D(1, 0);
	for (int32 F = 0; F < 90; ++F) Sim->Step(In);
	const double V = Sim->GetSkaters()[Sim->GetHumanIndex()].Vel.Size();
	AddInfo(FString::Printf(TEXT("after a live skater.speed 12: %.2f m/s"), V));
	TestTrue(TEXT("skater goes faster than the old 8 m/s"), V > 9.0);
	return true;
}
#endif
