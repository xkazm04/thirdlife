// Lane A109 (track S3, fuzz and the loader). Tests that run a corpus of generated cartridges (tools/fuzz/gen.mjs) through the C++ loader and the sim, headless.
//
//   Jam.Core.FuzzSmoke       in the gate: the checked-in tools/fuzz/smoke corpus (about 50 cartridges), 600 frames each.
//   Bar.Fuzz.Cartridges      the long run: JAM_FUZZ_DIR names a corpus folder (manifest.json + one file per cartridge). Optional env:
//                              JAM_FUZZ_FIRST / JAM_FUZZ_LAST   index range of the manifest (default all), so a driver can shard and restart past a crash
//                              JAM_FUZZ_FRAMES                  frames of sim per valid cartridge (default 600)
//                              JAM_FUZZ_LONG_EVERY              every Nth valid cartridge also runs to JAM_FUZZ_LONG_FRAMES (default 36000) and must end (0 = never)
//                              JAM_FUZZ_HARDSTOP                1 = every valid case also idles to its hard stop and must be Over (lane A141 timer oracle)
//                              JAM_FUZZ_OUT                     folder for progress.txt (the case about to run, written before it runs: a crash names its cartridge)
//                                                               and faults.jsonl (one line per fault: class, case, detail)
//   Bar.Fuzz.ModesAndCuts    the twelve modes and every shipped cut through the same checks for 36,000 frames.
//
// Fault classes (tools/fuzz/run.mjs prints them by class): parity (the C++ validator and Node's disagree on verdict or pointers), loader-refuses-valid,
// loader-accepts-invalid, nan (a position or velocity that is not finite), puck-outside, skater-outside, never-ends, hash (one seed, two hashes),
// engine-error (an ensure or an error log line during the case), crash and hang (seen by the driver, from progress.txt).
// The tests report; they fix nothing (a fault is a finding with its cartridge).
#include "Misc/AutomationTest.h"
#include "Misc/FileHelper.h"
#include "Misc/Paths.h"
#include "Misc/DateTime.h"
#include "HAL/FileManager.h"
#include "HAL/PlatformMisc.h"
#include "JamCartridge.h"
#include "JamJson.h"
#include "JamSim.h"
#include "JamAICore.h"
#include "JamBotMatch.h"
#include "JamSimAdapter.h"
#include "JamPlaytester.h"
#include "DifficultyResolve.h"

#if WITH_DEV_AUTOMATION_TESTS

namespace JamFuzz
{
	constexpr EAutomationTestFlags SmokeFlags = EAutomationTestFlags_ApplicationContextMask | EAutomationTestFlags::ProductFilter;
	constexpr EAutomationTestFlags LongFlags = EAutomationTestFlags::EditorContext | EAutomationTestFlags::CommandletContext | EAutomationTestFlags::EngineFilter;

	FString Env(const TCHAR* Name) { return FPlatformMisc::GetEnvironmentVariable(Name); }
	int32 EnvInt(const TCHAR* Name, int32 Default) { const FString V = Env(Name); return V.IsEmpty() ? Default : FCString::Atoi(*V); }

	struct FFaultSink
	{
		FString OutDir;
		TArray<FString> Lines;
		int32 Count = 0;
		void Progress(const FString& Text) const
		{
			if (!OutDir.IsEmpty()) { FFileHelper::SaveStringToFile(Text, *FPaths::Combine(OutDir, TEXT("progress.txt"))); }
		}
		void Fault(FAutomationTestBase& T, const FString& Class, const FString& Case, const FString& Detail)
		{
			++Count;
			const FString Clean = Detail.Replace(TEXT("\""), TEXT("'")).Replace(TEXT("\n"), TEXT(" ")).Replace(TEXT("\\"), TEXT("/"));
			const FString Line = FString::Printf(TEXT("{\"class\":\"%s\",\"case\":\"%s\",\"detail\":\"%s\"}"), *Class, *Case, *Clean.Left(400));
			T.AddError(FString::Printf(TEXT("FUZZFAULT %s %s: %s"), *Class, *Case, *Clean.Left(300)));
			if (!OutDir.IsEmpty())
			{
				FString Old;
				FFileHelper::LoadFileToString(Old, *FPaths::Combine(OutDir, TEXT("faults.jsonl")));
				FFileHelper::SaveStringToFile(Old + Line + TEXT("\n"), *FPaths::Combine(OutDir, TEXT("faults.jsonl")));
			}
		}
	};

	// Per-frame state checks, called by RunMatch before every frame (the world the bots saw).
	struct FChecker
	{
		const JamAI::FJamSimAdapter* Sim = nullptr;
		bool bNaN = false;
		bool bPuckOut = false;
		bool bSkaterOut = false;
		int64 NaNFrame = -1, PuckOutFrame = -1, SkaterOutFrame = -1;
		FString NaNWhat;
		double WorstPuck = -1e9, WorstSkater = -1e9;

		static bool Bad(double V) { return !FMath::IsFinite(V); }
		void Look(const JamAI::FJamAIWorld& W)
		{
			if (!bNaN)
			{
				bool b = Bad(W.PuckPos.X) || Bad(W.PuckPos.Y) || Bad(W.PuckVel.X) || Bad(W.PuckVel.Y);
				FString What = b ? TEXT("puck") : TEXT("");
				for (int32 i = 0; i < W.NumSkaters && !b; ++i)
				{
					const JamAI::FJamAISkater& S = W.Skaters[i];
					if (Bad(S.Pos.X) || Bad(S.Pos.Y) || Bad(S.Vel.X) || Bad(S.Vel.Y) || Bad(S.Facing.X) || Bad(S.Facing.Y)) { b = true; What = FString::Printf(TEXT("skater %d"), i); }
				}
				if (b) { bNaN = true; NaNFrame = W.Frame; NaNWhat = What; }
			}
			if (bNaN || !Sim) { return; }
			const double Pd = Sim->BoardDistance(W.PuckPos);
			if (Pd > WorstPuck) { WorstPuck = Pd; }
			if (Pd > 1.5 && !bPuckOut) { bPuckOut = true; PuckOutFrame = W.Frame; }
			for (int32 i = 0; i < W.NumSkaters; ++i)
			{
				const double Sd = Sim->BoardDistance(W.Skaters[i].Pos);
				if (Sd > WorstSkater) { WorstSkater = Sd; }
				if (Sd > 0.75 && !bSkaterOut) { bSkaterOut = true; SkaterOutFrame = W.Frame; }
			}
		}
	};

	void TraceMatch(void* Ctx, const JamAI::FJamAIWorld& W, const JamAI::FJamAIInput*, const JamAI::FJamBrain&) { static_cast<FChecker*>(Ctx)->Look(W); }
	void TracePlay(void* Ctx, const JamAI::FJamAIWorld& W, const JamAI::FJamAIInput*, const JamAI::FJamBrain&, int64_t, bool) { static_cast<FChecker*>(Ctx)->Look(W); }

	// Error-level log lines (ensures included) that are not our own fault lines, attributed to the case that runs.
	struct FErrCapture : public FOutputDevice
	{
		TArray<FString> Lines;
		virtual void Serialize(const TCHAR* V, ELogVerbosity::Type Verbosity, const FName& Category) override
		{
			if (Verbosity <= ELogVerbosity::Error && !FCString::Strstr(V, TEXT("FUZZFAULT"))) { Lines.Add(Category.ToString() + TEXT(": ") + V); }
		}
	};

	FString Pointers(const TArray<FString>& Errors)
	{
		TArray<FString> Got;
		for (const FString& E : Errors)
		{
			FString P = E.StartsWith(TEXT("at ")) ? E.Mid(3) : TEXT("?");
			int32 Colon;
			if (P.FindChar(':', Colon)) { P = P.Left(Colon); }
			Got.AddUnique(P);
		}
		Got.Sort();
		return FString::Join(Got, TEXT(" "));
	}

	void ReportChecker(FAutomationTestBase& T, FFaultSink& Sink, const FString& Case, const TCHAR* Run, const FChecker& C)
	{
		if (C.bNaN) { Sink.Fault(T, TEXT("nan"), Case, FString::Printf(TEXT("%s: %s not finite at frame %lld"), Run, *C.NaNWhat, C.NaNFrame)); }
		if (C.bPuckOut) { Sink.Fault(T, TEXT("puck-outside"), Case, FString::Printf(TEXT("%s: puck %.2f m outside the boards (first at frame %lld, worst %.2f)"), Run, 1.5, C.PuckOutFrame, C.WorstPuck)); }
		if (C.bSkaterOut) { Sink.Fault(T, TEXT("skater-outside"), Case, FString::Printf(TEXT("%s: a skater beyond the boards (first at frame %lld, worst %.2f m)"), Run, C.SkaterOutFrame, C.WorstSkater)); }
	}

	// One valid cartridge through the sim: brain-vs-brain twice (hash), the playtester twice (hash, abilities, sprint), and optionally a long run.
	// Lane A141 (track S3, evolution 3, item 4): the timer oracle. Whatever the cartridge's rules and hooks do, a match with nobody playing (idle inputs: no goal can come, no
	// clock can be beaten by play) must be Over by its hard stop: max(33000, timer + 6000) frames (JamSim.cpp MatchHardStopFrames) and always under the 36,000-frame cap every
	// tool assumes. Checked on every smoke case; the sim steps alone (no brain), so it costs about a tenth of a brain match.
	// Real idle runs left to spend (the formula check below runs on every case): -1 = every case, N = the next N cases that carry hooks (the smoke gate: an idle run is
	// about 7 microseconds a frame, 33,000+ frames, so the gate spends 4 of them and keeps the 10-second budget; Bar.Fuzz.Cartridges runs them all with JAM_FUZZ_HARDSTOP=1).
	int32 GHardStopRealRuns = 0;

	void HardStopOracle(FAutomationTestBase& T, FFaultSink& Sink, const FString& Case, const UJamCartridge& Cart)
	{
		const bool bTimer = Cart.Game.Rules.Mode == FName(TEXT("timer")) && Cart.Game.Rules.TimerFrames > 0;
		const int64 Stop = bTimer ? FMath::Max<int64>(33000, static_cast<int64>(Cart.Game.Rules.TimerFrames) + 6000) : 33000;
		if (Stop >= 36000) { Sink.Fault(T, TEXT("never-ends"), Case, FString::Printf(TEXT("hard stop %lld is not under the 36,000-frame cap"), static_cast<long long>(Stop))); return; }
		const bool bReal = GHardStopRealRuns < 0 || (GHardStopRealRuns > 0 && Cart.Game.Rules.Hooks.Num() > 0);
		if (!bReal) { return; }
		if (GHardStopRealRuns > 0) { --GHardStopRealRuns; }
		UJamSim* Sim = NewObject<UJamSim>();
		if (!Sim->Init(Cart.Game, static_cast<uint64>(Cart.Seed))) { Sink.Fault(T, TEXT("harness"), Case, TEXT("hard-stop oracle: sim init failed")); return; }
		TArray<FJamInput> Inputs;
		Inputs.SetNum(Sim->GetSkaters().Num());
		while (Sim->GetPhase() != EJamSimPhase::Over && Sim->GetFrame() <= Stop + 60) { Sim->Step(Inputs); }
		if (Sim->GetPhase() != EJamSimPhase::Over) { Sink.Fault(T, TEXT("never-ends"), Case, FString::Printf(TEXT("idle match not over by its hard stop %lld (frame %lld)"), static_cast<long long>(Stop), static_cast<long long>(Sim->GetFrame()))); }
		else if (Sim->GetFrame() > Stop + 1) { Sink.Fault(T, TEXT("never-ends"), Case, FString::Printf(TEXT("idle match ended at frame %lld, after its hard stop %lld"), static_cast<long long>(Sim->GetFrame()), static_cast<long long>(Stop))); }
	}

	void SimulateCase(FAutomationTestBase& T, FFaultSink& Sink, const FString& Case, const UJamCartridge& Cart, int32 Frames, bool bLong, int32 LongFrames, bool bHardStop = false)
	{
		if (bHardStop) { HardStopOracle(T, Sink, Case, Cart); }
		const JamAI::FJamMatchConfig Cfg = JamAI::ToMatchConfigResolved(Cart);
		const uint64 Seed = static_cast<uint64>(Cart.Seed);
		// brain vs brain, twice
		JamAI::FJamMatchStats St[2];
		for (int32 Run = 0; Run < 2; ++Run)
		{
			JamAI::FJamSimAdapter Adapter(Cart);
			FChecker Chk;
			Chk.Sim = &Adapter;
			St[Run] = JamAI::RunMatch(Adapter, Cfg, Seed, JamAI::EJamPlayerMode::Brain, Frames, 600, &TraceMatch, &Chk, 1);
			if (Run == 0) { ReportChecker(T, Sink, Case, TEXT("brain"), Chk); }
			// after the last step the trace has not seen the final state
			if (Run == 0 && Adapter.GetSim())
			{
				const UJamSim* S = Adapter.GetSim();
				const FJamPuckState& P = S->GetPuck();
				if (!FMath::IsFinite(P.Pos.X) || !FMath::IsFinite(P.Pos.Y)) { Sink.Fault(T, TEXT("nan"), Case, TEXT("brain: puck not finite after the last frame")); }
				for (const FJamSkaterState& K : S->GetSkaters()) { if (!FMath::IsFinite(K.Pos.X) || !FMath::IsFinite(K.Pos.Y) || !FMath::IsFinite(K.Vel.X) || !FMath::IsFinite(K.Vel.Y)) { Sink.Fault(T, TEXT("nan"), Case, FString::Printf(TEXT("brain: skater %d not finite after the last frame"), K.Index)); break; } }
			}
		}
		if (St[0].Hash != St[1].Hash || St[0].Frames != St[1].Frames || St[0].NumHashes != St[1].NumHashes)
		{
			Sink.Fault(T, TEXT("hash"), Case, FString::Printf(TEXT("brain seed %llu: hash %016llx / %016llx, frames %lld / %lld"), Seed, static_cast<unsigned long long>(St[0].Hash), static_cast<unsigned long long>(St[1].Hash), static_cast<long long>(St[0].Frames), static_cast<long long>(St[1].Frames)));
		}
		// the playtester (abilities, sprint, stick verbs), twice
		JamAI::FJamPlaytestStats Ps[2];
		for (int32 Run = 0; Run < 2; ++Run)
		{
			JamAI::FJamSimAdapter Adapter(Cart);
			FChecker Chk;
			Chk.Sim = &Adapter;
			Ps[Run] = JamAI::RunPlaytestMatch(Adapter, Cfg, Seed, Run == 0 ? JamAI::EPlaytester::Good : JamAI::EPlaytester::Good, Frames, Cart.Game.Shot.ChargeFramesMax, true, &TracePlay, &Chk, 1);
			if (Run == 0) { ReportChecker(T, Sink, Case, TEXT("playtester"), Chk); }
		}
		if (Ps[0].Hash != Ps[1].Hash || Ps[0].Frames != Ps[1].Frames)
		{
			Sink.Fault(T, TEXT("hash"), Case, FString::Printf(TEXT("playtester seed %llu: hash %016llx / %016llx, frames %lld / %lld"), Seed, static_cast<unsigned long long>(Ps[0].Hash), static_cast<unsigned long long>(Ps[1].Hash), static_cast<long long>(Ps[0].Frames), static_cast<long long>(Ps[1].Frames)));
		}
		if (bLong)
		{
			JamAI::FJamSimAdapter Adapter(Cart);
			FChecker Chk;
			Chk.Sim = &Adapter;
			// the sim stops a match at max(33000, timer + 6000) frames (JamSim.cpp MatchHardStopFrames): the cap here is that plus a margin
			const int32 Cap = (Cart.Game.Rules.Mode == FName(TEXT("timer")) && Cart.Game.Rules.TimerFrames > 0) ? FMath::Max(LongFrames, Cart.Game.Rules.TimerFrames + 7000) : LongFrames;
			const JamAI::FJamMatchStats L = JamAI::RunMatch(Adapter, Cfg, Seed, JamAI::EJamPlayerMode::Brain, Cap, 600, &TraceMatch, &Chk, 1);
			ReportChecker(T, Sink, Case, TEXT("long"), Chk);
			if (!L.bOver) { Sink.Fault(T, TEXT("never-ends"), Case, FString::Printf(TEXT("brain match not over after %lld frames, %d:%d"), static_cast<long long>(L.Frames), L.Goals[0], L.Goals[1])); }
		}
	}

	struct FCase { FString Name, File, Kind; bool bOk = false; FString Pointers; };

	bool LoadManifest(FAutomationTestBase& T, const FString& Dir, TArray<FCase>& Out)
	{
		FString Text;
		if (!FFileHelper::LoadFileToString(Text, *FPaths::Combine(Dir, TEXT("manifest.json")))) { return false; }
		FString Err;
		TSharedPtr<FJamJson> Root = FJamJson::Parse(Text, Err);
		if (!Root) { T.AddError(FString::Printf(TEXT("fuzz manifest: %s"), *Err)); return false; }
		for (const TSharedPtr<FJamJson>& C : Root->Get(TEXT("cases"))->Array)
		{
			FCase K;
			if (!C->Get(TEXT("name")).IsValid() || !C->Get(TEXT("file")).IsValid() || !C->Get(TEXT("kind")).IsValid() || !C->Get(TEXT("ok")).IsValid() || !C->Get(TEXT("pointers")).IsValid()) { T.AddError(TEXT("fuzz manifest: a case lacks a field")); continue; }
			K.Name = C->Get(TEXT("name"))->String;
			K.File = C->Get(TEXT("file"))->String;
			K.Kind = C->Get(TEXT("kind"))->String;
			K.bOk = C->Get(TEXT("ok"))->Bool;
			TArray<FString> P;
			for (const TSharedPtr<FJamJson>& X : C->Get(TEXT("pointers"))->Array) { P.Add(X->String); }
			P.Sort();
			K.Pointers = FString::Join(P, TEXT(" "));
			Out.Add(K);
		}
		return true;
	}

	// The whole check of one case: the validator pair, the loader, then the sim for a valid one.
	void RunCase(FAutomationTestBase& T, FFaultSink& Sink, const FString& Dir, const FCase& K, int32 Frames, bool bLong, int32 LongFrames, int32& Simulated, bool bHardStop = false)
	{
		FString Text;
		if (!FFileHelper::LoadFileToString(Text, *FPaths::Combine(Dir, K.File))) { Sink.Fault(T, TEXT("harness"), K.Name, TEXT("case file unreadable")); return; }
		TArray<FString> VErr;
		FErrCapture Cap;
		GLog->AddOutputDevice(&Cap);
		const bool bGot = UJamCartridge::Validate(Text, VErr);
		const FString GotPtrs = Pointers(VErr);
		if (bGot != K.bOk || GotPtrs != K.Pointers)
		{
			Sink.Fault(T, TEXT("parity"), K.Name, FString::Printf(TEXT("node ok=%d [%s], c++ ok=%d [%s] first: %s"), K.bOk, *K.Pointers, bGot, *GotPtrs, VErr.Num() ? *VErr[0] : TEXT("-")));
		}
		TArray<FString> LErr;
		UJamCartridge* Cart = UJamCartridge::LoadFromString(Text, LErr);
		if (K.bOk && !Cart) { Sink.Fault(T, TEXT("loader-refuses-valid"), K.Name, LErr.Num() ? *LErr[0] : TEXT("no message")); }
		if (!K.bOk && Cart) { Sink.Fault(T, TEXT("loader-accepts-invalid"), K.Name, FString::Printf(TEXT("node refuses with [%s]"), *K.Pointers)); }
		if (!K.bOk && !Cart && LErr.Num() == 0) { Sink.Fault(T, TEXT("loader-silent-refusal"), K.Name, TEXT("refused without a message")); }
		if (!K.bOk && !Cart && LErr.Num() > 0 && Pointers(LErr) != K.Pointers && K.Pointers != TEXT("/") && !LErr[0].StartsWith(TEXT("at "))) { Sink.Fault(T, TEXT("loader-no-pointer"), K.Name, LErr[0]); }
		if (Cart && K.bOk)
		{
			++Simulated;
			SimulateCase(T, Sink, K.Name, *Cart, Frames, bLong, LongFrames, bHardStop);
		}
		GLog->RemoveOutputDevice(&Cap);
		// an error-level line (an ensure, an assert message, a log error) while a valid cartridge loaded or ran, or while an invalid one was refused
		if (Cap.Lines.Num() > 0) { Sink.Fault(T, TEXT("engine-error"), K.Name, FString::Printf(TEXT("%d error line(s), first: %s"), Cap.Lines.Num(), *Cap.Lines[0])); }
	}

	bool RunCorpus(FAutomationTestBase& T, const FString& Dir, const FString& OutDir, int32 First, int32 Last, int32 Frames, int32 LongEvery, int32 LongFrames, const TCHAR* Label, bool bHardStop = false)
	{
		TArray<FCase> Cases;
		if (!LoadManifest(T, Dir, Cases)) { T.AddWarning(FString::Printf(TEXT("%s: no fuzz corpus at %s; skipped"), Label, *Dir)); return true; }
		FFaultSink Sink;
		Sink.OutDir = OutDir;
		if (!OutDir.IsEmpty()) { IFileManager::Get().MakeDirectory(*OutDir, true); }
		if (Last < 0 || Last >= Cases.Num()) { Last = Cases.Num() - 1; }
		int32 Simulated = 0, Done = 0, ValidSeen = 0;
		const double Start = FPlatformTime::Seconds();
		for (int32 i = First; i <= Last; ++i)
		{
			const FCase& K = Cases[i];
			Sink.Progress(FString::Printf(TEXT("%d\t%s\t%s"), i, *K.Name, *K.File));
			const bool bLong = K.bOk && ((LongEvery > 0 && (++ValidSeen % LongEvery == 0)) || K.Name.StartsWith(TEXT("min-")));
			RunCase(T, Sink, Dir, K, Frames, bLong, LongFrames, Simulated, bHardStop);
			++Done;
		}
		Sink.Progress(FString::Printf(TEXT("done\t%d\t%d"), First, Last));
		T.AddInfo(FString::Printf(TEXT("%s: %d cases (%d..%d of %d), %d simulated for %d frames each, %d faults, %.1f s"), Label, Done, First, Last, Cases.Num(), Simulated, Frames, Sink.Count, FPlatformTime::Seconds() - Start));
		return Sink.Count == 0;
	}
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamFuzzSmoke, "Jam.Core.FuzzSmoke", JamFuzz::SmokeFlags)
bool FJamFuzzSmoke::RunTest(const FString& Parameters)
{
	const FString Dir = FPaths::ConvertRelativePathToFull(FPaths::Combine(FPaths::ProjectDir(), TEXT(".."), TEXT("tools"), TEXT("fuzz"), TEXT("smoke")));
	if (!IFileManager::Get().DirectoryExists(*Dir)) { AddWarning(TEXT("tools/fuzz/smoke not found (source tree absent); skipped")); return true; }
	JamFuzz::GHardStopRealRuns = 4;
	const bool bSmoke = JamFuzz::RunCorpus(*this, Dir, FString(), 0, -1, 600, 0, 0, TEXT("fuzz smoke"), true);   // lane A141: the hard-stop formula on every case, 4 real idle runs
	// Lane A118 (track S3, evolution 2): the regression corpus of the seven fault classes (tools/fuzz/regress, from tools/fuzz/found by gen-regress.mjs). Every valid
	// case also runs the long match, which must end; nothing may leave the boards or go non-finite; both validators and the loader agree on every file.
	JamFuzz::GHardStopRealRuns = 0;
	const FString Regress = FPaths::ConvertRelativePathToFull(FPaths::Combine(FPaths::ProjectDir(), TEXT(".."), TEXT("tools"), TEXT("fuzz"), TEXT("regress")));
	const bool bRegress = JamFuzz::RunCorpus(*this, Regress, FString(), 0, -1, 600, 1, 36000, TEXT("fuzz regress"));
	return bSmoke && bRegress;
}

// Lane A118 (track S3, evolution 2): set_param cannot make the sim non-finite. A value outside the field's range (the found cartridge's puck_max_speed -20,
// which the validators now refuse) is clamped by the sim for any caller that bypasses the validator; an unknown name changes nothing.
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamFuzzSetParamClamp, "Jam.Core.FuzzSetParamClamp", JamFuzz::SmokeFlags)
bool FJamFuzzSetParamClamp::RunTest(const FString& Parameters)
{
	TArray<FString> Errors;
	UJamCartridge* Cart = UJamCartridge::LoadFromFile(FPaths::Combine(UJamCartridge::GetCartridgeDir(), TEXT("hockey.regular.cartridge.json")), Errors);
	if (!TestNotNull(TEXT("hockey.regular loads"), Cart)) return false;
	double Lo = 0, Hi = 0;
	TestTrue(TEXT("puck_max_speed has a range"), UJamCartridge::SetParamRange(TEXT("puck_max_speed"), Lo, Hi));
	TestEqual(TEXT("puck_max_speed range 10..60"), FString::Printf(TEXT("%g..%g"), Lo, Hi), FString(TEXT("10..60")));
	TestFalse(TEXT("warp_factor has no range"), UJamCartridge::SetParamRange(TEXT("warp_factor"), Lo, Hi));
	UJamSim* Sim = NewObject<UJamSim>();
	Sim->Init(Cart->Game, 1);
	Sim->SetParam(FName(TEXT("puck_max_speed")), -20.0);
	TestEqual(TEXT("puck_max_speed -20 is clamped to 10"), Sim->GetConfig().Puck.MaxSpeed, 10.0);
	Sim->SetParam(FName(TEXT("ice_friction")), -19.928);
	TestEqual(TEXT("ice_friction -19.9 is clamped to 0"), Sim->GetConfig().Rink.IceFriction, 0.0);
	Sim->SetParam(FName(TEXT("skater_speed")), 0.0);
	TestEqual(TEXT("skater_speed 0 is clamped to 3"), Sim->GetConfig().Skater.Speed, 3.0);
	const double Speed = Sim->GetConfig().Skater.Speed;
	TestFalse(TEXT("an unknown name is refused"), Sim->SetParam(FName(TEXT("warp_factor")), 5.0));
	TestEqual(TEXT("... and changes nothing"), Sim->GetConfig().Skater.Speed, Speed);
	TArray<FJamInput> In;
	for (int32 f = 0; f < 3000; ++f)
	{
		Sim->Step(In);
		const FJamPuckState& P = Sim->GetPuck();
		if (!FMath::IsFinite(P.Pos.X) || !FMath::IsFinite(P.Pos.Y)) { AddError(FString::Printf(TEXT("puck not finite at frame %d"), f)); break; }
	}
	return true;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamFuzzCartridges, "Bar.Fuzz.Cartridges", JamFuzz::LongFlags)
bool FJamFuzzCartridges::RunTest(const FString& Parameters)
{
	const FString Dir = JamFuzz::Env(TEXT("JAM_FUZZ_DIR"));
	if (Dir.IsEmpty()) { AddWarning(TEXT("JAM_FUZZ_DIR not set; skipped")); return true; }
	JamFuzz::GHardStopRealRuns = JamFuzz::EnvInt(TEXT("JAM_FUZZ_HARDSTOP"), 0) != 0 ? -1 : 0;   // lane A141: JAM_FUZZ_HARDSTOP=1 idles every valid case to its hard stop
	return JamFuzz::RunCorpus(*this, Dir, JamFuzz::Env(TEXT("JAM_FUZZ_OUT")), JamFuzz::EnvInt(TEXT("JAM_FUZZ_FIRST"), 0), JamFuzz::EnvInt(TEXT("JAM_FUZZ_LAST"), -1),
		JamFuzz::EnvInt(TEXT("JAM_FUZZ_FRAMES"), 600), JamFuzz::EnvInt(TEXT("JAM_FUZZ_LONG_EVERY"), 0), JamFuzz::EnvInt(TEXT("JAM_FUZZ_LONG_FRAMES"), 36000), TEXT("fuzz cartridges"), JamFuzz::EnvInt(TEXT("JAM_FUZZ_HARDSTOP"), 0) != 0);
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamFuzzModesAndCuts, "Bar.Fuzz.ModesAndCuts", JamFuzz::LongFlags)
bool FJamFuzzModesAndCuts::RunTest(const FString& Parameters)
{
	using namespace JamFuzz;
	const FString OutDir = Env(TEXT("JAM_FUZZ_OUT"));
	FFaultSink Sink;
	Sink.OutDir = OutDir;
	if (!OutDir.IsEmpty()) { IFileManager::Get().MakeDirectory(*OutDir, true); }
	const FString Root = UJamCartridge::GetCartridgeDir();
	TArray<FString> Files;
	{
		TArray<FString> A, B, C;
		IFileManager::Get().FindFiles(A, *FPaths::Combine(Root, TEXT("*.cartridge.json")), true, false);
		IFileManager::Get().FindFiles(B, *FPaths::Combine(Root, TEXT("modes"), TEXT("*.cartridge.json")), true, false);
		IFileManager::Get().FindFiles(C, *FPaths::Combine(Root, TEXT("ladder"), TEXT("*.cartridge.json")), true, false);
		for (const FString& F : A) Files.Add(F);
		for (const FString& F : B) Files.Add(FString(TEXT("modes/")) + F);
		for (const FString& F : C) Files.Add(FString(TEXT("ladder/")) + F);
	}
	Files.Sort();
	const int32 Frames = EnvInt(TEXT("JAM_FUZZ_LONG_FRAMES"), 36000);
	const int32 Seeds = EnvInt(TEXT("JAM_FUZZ_SEEDS"), 2);
	int32 Done = 0, Idx = -1;
	const int32 First = EnvInt(TEXT("JAM_FUZZ_FIRST"), 0);
	for (const FString& F : Files)
	{
		if (++Idx < First) { continue; }
		Sink.Progress(FString::Printf(TEXT("%d\tmodes %s\t"), Idx, *F));
		TArray<FString> Errors;
		UJamCartridge* Cart = UJamCartridge::LoadFromFile(FPaths::Combine(Root, F), Errors);
		if (!Cart) { Sink.Fault(*this, TEXT("loader-refuses-valid"), F, Errors.Num() ? *Errors[0] : TEXT("no message")); continue; }
		// a timer match ends at max(33000, timer + 6000) frames at the latest (JamSim.cpp MatchHardStopFrames): the cap adds a margin
		const int32 FileFrames = (Cart->Game.Rules.Mode == FName(TEXT("timer")) && Cart->Game.Rules.TimerFrames > 0) ? FMath::Max(Frames, Cart->Game.Rules.TimerFrames + 7000) : Frames;
		for (int32 S = 0; S < Seeds; ++S)
		{
			const uint64 Seed = static_cast<uint64>(Cart->Seed) + S * 7919;
			const JamAI::FJamMatchConfig Cfg = JamAI::ToMatchConfigResolved(*Cart);
			const FString Case = FString::Printf(TEXT("%s#%d"), *F, S);
			JamAI::FJamMatchStats St[2];
			for (int32 Run = 0; Run < 2; ++Run)
			{
				JamAI::FJamSimAdapter Adapter(*Cart);
				FChecker Chk;
				Chk.Sim = &Adapter;
				St[Run] = JamAI::RunMatch(Adapter, Cfg, Seed, JamAI::EJamPlayerMode::Brain, FileFrames, 600, &TraceMatch, &Chk, 1);
				if (Run == 0) { ReportChecker(*this, Sink, Case, TEXT("brain"), Chk); }
			}
			if (!St[0].bOver) { Sink.Fault(*this, TEXT("never-ends"), Case, FString::Printf(TEXT("brain match not over after %lld frames, %d:%d"), static_cast<long long>(St[0].Frames), St[0].Goals[0], St[0].Goals[1])); }
			if (St[0].Hash != St[1].Hash || St[0].Frames != St[1].Frames) { Sink.Fault(*this, TEXT("hash"), Case, FString::Printf(TEXT("seed %llu: hash %016llx / %016llx"), Seed, static_cast<unsigned long long>(St[0].Hash), static_cast<unsigned long long>(St[1].Hash))); }
			// the human's slot played by the playtester, to reach abilities and the sprint
			JamAI::FJamSimAdapter Adapter(*Cart);
			FChecker Chk;
			Chk.Sim = &Adapter;
			const JamAI::FJamPlaytestStats P = JamAI::RunPlaytestMatch(Adapter, Cfg, Seed, JamAI::EPlaytester::Good, FileFrames, Cart->Game.Shot.ChargeFramesMax, true, &TracePlay, &Chk, 1);
			ReportChecker(*this, Sink, Case, TEXT("playtester"), Chk);
			if (!P.bOver) { Sink.Fault(*this, TEXT("never-ends"), Case, FString::Printf(TEXT("playtester match not over after %lld frames"), static_cast<long long>(P.Frames))); }
			AddInfo(FString::Printf(TEXT("%s seed %llu: brain %s %lld frames %d:%d hash %016llx; playtester %s %lld frames"), *Case, Seed, St[0].bOver ? TEXT("over") : TEXT("NOT OVER"), static_cast<long long>(St[0].Frames), St[0].Goals[0], St[0].Goals[1], static_cast<unsigned long long>(St[0].Hash), P.bOver ? TEXT("over") : TEXT("NOT OVER"), static_cast<long long>(P.Frames)));
			++Done;
		}
	}
	Sink.Progress(TEXT("done\tmodes"));
	AddInfo(FString::Printf(TEXT("modes and cuts: %d files, %d runs of up to %d frames, %d faults"), Files.Num(), Done, Frames, Sink.Count));
	return Sink.Count == 0;
}

#endif
