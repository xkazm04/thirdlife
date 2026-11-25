// Lane A152 (track F2, carrier skill, evolution 5: "Space is worth pressing"; R-0059 point 4, docs/experiments/MOVEMENT-6.md).
// Bar.Movement.PokeTrace (outside the gate's Jam filter: a measurement): every poke the scripted human presses in real matches, each miss with its reason.
//   UnrealEditor-Cmd.exe Game/ThirdJam.uproject -ExecCmds="Automation RunTests Bar.Movement.PokeTrace; Quit" -unattended -nullrhi -Multiprocess -nosplash -log
//   env JAM_POKE_TRACE = "level=pro;player=regular;seeds=12;rows=40;set=stick.poke_take_m:0.5,stick.miss_lock_frames:20" (every part optional)
#include "Misc/AutomationTest.h"
#include "JamCartridge.h"
#include "JamSim.h"
#include "JamEventBus.h"
#include "JamBrain.h"
#include "JamSimAdapter.h"
#include "JamPlaytester.h"
#include "DifficultyResolve.h"
#include "JamBaseline.h"
#include "Misc/FileHelper.h"
#include "Misc/Paths.h"
#include "UObject/Package.h"

#if WITH_DEV_AUTOMATION_TESTS

namespace JamPokeTests
{
	constexpr EAutomationTestFlags Flags = EAutomationTestFlags_ApplicationContextMask | EAutomationTestFlags::ProductFilter;

	UJamCartridge* LoadPreset(FAutomationTestBase& T, const FString& Name)
	{
		TArray<FString> Errors;
		UJamCartridge* C = UJamCartridge::LoadFromFile(UJamCartridge::ResolveCartridgePath(Name), Errors);
		for (const FString& E : Errors) T.AddError(FString::Printf(TEXT("%s: %s"), *Name, *E));
		return C;
	}

	UJamCartridge* Copy(const UJamCartridge& C) { return DuplicateObject<UJamCartridge>(&C, GetTransientPackage()); }

	// Why the sim's IsPokeShielded refuses, in its own order. 0 none, 1 spin, 2 body, 3 grace, 4 sweep.
	enum { WhyNone = 0, WhySpin, WhyBody, WhyGrace, WhySweep };
	int32 ShieldWhy(const UJamSim& Sim, const FJamSkaterState& P, const FJamSkaterState& C)
	{
		const FJamGameConfig& G = Sim.GetConfig();
		if (C.SpinFrames > FMath::Max(0, G.Skater.SpinExposedTail) && C.SpinLength - C.SpinFrames >= G.Skater.SpinExposedHead) return WhySpin;
		if (C.SpinFrames > 0 || C.SpinRecoverLeft > 0) return Sim.InTakeGrace(C) && P.Team != C.Team ? WhyGrace : WhyNone;
		if (Sim.IsBodyShielded(P, C)) return WhyBody;
		if (Sim.InTakeGrace(C) && P.Team != C.Team) return WhyGrace;
		if (C.SweepFrames > 0 && C.SweepSide != 0) return WhySweep;
		return WhyNone;
	}

	// What became of a press. One press has one row: the first that applies, in this order.
	enum EWhy
	{
		Took = 0,          // a clean poke from an opposing carrier
		TookLoose,         // the window met a puck nobody carried (a clean event of strength 0)
		Draw,              // pressed with nothing near: the faceoff's press (the puck more than 3 m away, nobody carrying)
		NobodyCarries,     // pressed with no opposing carrier as the press frame ended (loose, a mate's, or the carrier let go while the hand was on its way)
		AimOff,            // TAKEABLE: on a frame of the window the puck was unshielded and inside the stick's reach of his body; the blade was not on it
		ShieldGrace, ShieldBody, ShieldSweep, ShieldSpin,   // never takeable: this shield stood on most of the window's frames
		PuckLeft,          // never takeable: the carrier passed, shot or lost it inside the window
		Knocked,           // the poker lost control inside the window (a hit)
		BeyondReach,       // never takeable: unshielded but never inside the stick's reach of his body
		Edge,              // the blade was on an unshielded puck on the trace's frame and the sim did not take it (a one-frame edge)
		WhyCount
	};
	const TCHAR* WhyName(int32 W)
	{
		static const TCHAR* N[] = { TEXT("took it"), TEXT("took a loose puck"), TEXT("the draw's press (nothing near)"), TEXT("nobody carries any more"),
			TEXT("TAKEABLE, blade not on it (the aim)"), TEXT("never takeable: the take grace"), TEXT("never takeable: the body between"), TEXT("never takeable: the sweep's shield"),
			TEXT("never takeable: the spin"), TEXT("never takeable: the puck left (pass, shot)"), TEXT("the poker was hit"), TEXT("never takeable: beyond the stick"), TEXT("edge") };
		return W >= 0 && W < WhyCount ? N[W] : TEXT("?");
	}

	struct FPress
	{
		int64 Frame = 0;
		int32 Carrier = -1;
		bool bOpp = false, bSprint = false, bCarrierSprint = false;
		bool bOppAtPress = false, bSprintAtPress = false;   // as the frame before the press ended
		int32 WhyAtPress = 0;
		int32 Why0 = 0;                      // the shield as the press frame ended
		double Blade0 = 0, Body0 = 0, Car0 = 0, Closing = 0, MySpeed = 0, CarSpeed = 0;
		double MinBlade = 1e9, MinBody = 1e9, MinAimDeg = 1e9;   // MinAimDeg: over the takeable frames, the puck's angle off the aimed blade
		int32 NGrace = 0, NBody = 0, NSweep = 0, NSpin = 0, NOpenIn = 0, NOpenBeyond = 0, NGone = 0;
		bool bBladeOnOpen = false;
		bool bKnocked = false, bStumbled = false, bLocked = false;
		int32 Frames = 0, Result = 0;        // Result: 1 clean, -1 armed miss, 0 the window ran out unarmed
		bool bCleanFromOpp = false;
		int32 Why = NobodyCarries;
	};

	struct FTrace
	{
		JamAI::FJamSimAdapter* Sim = nullptr;
		int32 Me = -1;
		int64 LastFrame = -1;
		bool bOpen = false;
		FPress Cur;
		TArray<FPress> Done;
		int32 OwnStumbles = 0, OtherStumbles = 0, PrevStumble = 0, Locks = 0, PrevLock = 0;
		// As the previous frame ended (what the player pressed at): an opposing carrier, its shield against him, its sprint.
		bool bPrevOpp = false, bPrevSprint = false;
		int32 PrevWhy = 0;
		int64 OppFrames = 0, OppSprintFrames = 0, OppNearFrames = 0, OppNearSprintFrames = 0;
	};

	void Close(FTrace& T)
	{
		FPress& P = T.Cur;
		if (P.Result == 1) P.Why = P.bCleanFromOpp ? Took : TookLoose;
		else if (!P.bOpp) P.Why = P.Body0 > 3.0 ? Draw : NobodyCarries;
		else if (P.bBladeOnOpen) P.Why = Edge;
		else if (P.NOpenIn > 0) P.Why = AimOff;
		else if (P.bKnocked) P.Why = Knocked;
		else
		{
			const int32 N[] = { P.NGrace, P.NBody, P.NSweep, P.NSpin, P.NGone, P.NOpenBeyond };
			const int32 W[] = { ShieldGrace, ShieldBody, ShieldSweep, ShieldSpin, PuckLeft, BeyondReach };
			int32 Best = 0;
			for (int32 i = 1; i < 6; ++i) if (N[i] > N[Best]) Best = i;
			P.Why = W[Best];
		}
		T.Done.Add(P);
		T.bOpen = false;
	}

	void PokeTrace(void* Ctx, const JamAI::FJamAIWorld&, const JamAI::FJamAIInput*, const JamAI::FJamBrain&, int64_t, bool)
	{
		FTrace& T = *static_cast<FTrace*>(Ctx);
		const UJamSim* Sim = T.Sim->GetSim();
		if (!Sim || Sim->GetFrame() == T.LastFrame) return;
		if (T.Me < 0) { for (const FJamSkaterState& S : Sim->GetSkaters()) if (S.bHuman) T.Me = S.Index; }   // the skaters exist once the match has begun
		if (T.Me < 0) return;
		T.LastFrame = Sim->GetFrame();
		const FJamSkaterState& H = Sim->GetSkaters()[T.Me];
		const FJamPuckState& Puck = Sim->GetPuck();
		const FJamGameConfig& G = Sim->GetConfig();
		const int32 Ci = Sim->CarrierIndex();
		const bool bOpp = Ci >= 0 && Ci != T.Me && Sim->GetSkaters()[Ci].Team != H.Team;
		static const FName Clean(TEXT("clean"));
		int32 Result = 0; bool bFromOpp = false;
		for (const FJamSimEvent& E : Sim->GetFrameEvents())
		{
			if (E.Name != JamEvents::Poke || E.Who != T.Me) continue;
			if (E.Kind == Clean) { Result = 1; bFromOpp = E.Strength > 0.5f; } else Result = -1;
		}
		// the human's stumbles: his own missed poke's, or anything else's (a hit); and the recoveries (the stick lock) his misses start
		if (H.StumbleFrames > 0 && T.PrevStumble == 0) { if (Result == -1) ++T.OwnStumbles; else ++T.OtherStumbles; }
		T.PrevStumble = H.StumbleFrames;
		if (H.StickLockLeft > 0 && T.PrevLock == 0) ++T.Locks;
		T.PrevLock = H.StickLockLeft;
		if (H.bPokeThisFrame)
		{
			if (T.bOpen) Close(T);
			T.bOpen = true;
			T.Cur = FPress();
			FPress& P = T.Cur;
			P.Frame = Sim->GetFrame();
			P.Carrier = Ci; P.bOpp = bOpp;
			P.bOppAtPress = T.bPrevOpp; P.WhyAtPress = T.PrevWhy; P.bSprintAtPress = T.bPrevSprint;
			P.bSprint = H.bSprinting;
			P.Blade0 = FVector2D::Distance(H.BladePos, Puck.Pos); P.Body0 = FVector2D::Distance(H.Pos, Puck.Pos);
			P.MySpeed = H.Vel.Size();
			if (bOpp)
			{
				const FJamSkaterState& C = Sim->GetSkaters()[Ci];
				P.Why0 = ShieldWhy(*Sim, H, C);
				P.bCarrierSprint = C.bSprinting;
				P.Car0 = FVector2D::Distance(H.Pos, C.Pos);
				P.CarSpeed = C.Vel.Size();
				const FVector2D N = (C.Pos - H.Pos).GetSafeNormal();
				P.Closing = FVector2D::DotProduct(H.Vel - C.Vel, N);
			}
		}
		T.bPrevOpp = bOpp;
		T.PrevWhy = bOpp ? ShieldWhy(*Sim, H, Sim->GetSkaters()[Ci]) : 0;
		T.bPrevSprint = bOpp && Sim->GetSkaters()[Ci].bSprinting;
		if (bOpp)
		{
			const bool bNear = FVector2D::Distance(Sim->GetSkaters()[Ci].Pos, H.Pos) <= 3.0;
			++T.OppFrames; if (T.bPrevSprint) ++T.OppSprintFrames;
			if (bNear) { ++T.OppNearFrames; if (T.bPrevSprint) ++T.OppNearSprintFrames; }
		}
		if (!T.bOpen) return;
		FPress& P = T.Cur;
		++P.Frames;
		const double Take = G.Puck.RadiusM + UJamSim::PokeTakeM;
		const double Full = UJamSim::SkaterRadius + G.Stick.ReachM + Take;
		if (Result == 1) { P.Result = 1; P.bCleanFromOpp = bFromOpp; Close(T); return; }
		if (P.bOpp)
		{
			if (!bOpp || Ci != P.Carrier) ++P.NGone;
			else
			{
				const double Db = FVector2D::Distance(H.BladePos, Puck.Pos), Dy = FVector2D::Distance(H.Pos, Puck.Pos);
				P.MinBlade = FMath::Min(P.MinBlade, Db);
				P.MinBody = FMath::Min(P.MinBody, Dy);
				const int32 W = ShieldWhy(*Sim, H, Sim->GetSkaters()[Ci]);
				if (W == WhyGrace) ++P.NGrace; else if (W == WhyBody) ++P.NBody; else if (W == WhySweep) ++P.NSweep; else if (W == WhySpin) ++P.NSpin;
				else if (Dy > Full) ++P.NOpenBeyond;
				else
				{
					++P.NOpenIn;
					const FVector2D Aim = (H.BladePos - H.Pos).GetSafeNormal(), To = (Puck.Pos - H.Pos).GetSafeNormal();
					P.MinAimDeg = FMath::Min(P.MinAimDeg, FMath::RadiansToDegrees(FMath::Acos(FMath::Clamp(FVector2D::DotProduct(Aim, To), -1.0, 1.0))));
					if (Db <= Take && H.CanAct() && Puck.Z < UJamSim::BladeClearM) P.bBladeOnOpen = true;
				}
			}
			if (H.IsDown() || (H.StumbleFrames > 0 && Result != -1)) P.bKnocked = true;
		}
		if (Result == -1) { P.Result = -1; P.bStumbled = H.StumbleFrames > 0; P.bLocked = H.StickLockLeft > 0; Close(T); return; }
		if (H.PokeWindow <= 0) Close(T);
	}

	struct FOpt { FString Level = TEXT("pro"), Player = TEXT("regular"), Set; int32 Seeds = 12, Rows = 30, From = 1; };
	FOpt ReadOpt()
	{
		FOpt O;
		const FString Env = FPlatformMisc::GetEnvironmentVariable(TEXT("JAM_POKE_TRACE"));
		TArray<FString> Parts;
		Env.ParseIntoArray(Parts, TEXT(";"));
		for (const FString& Part : Parts)
		{
			FString K, V;
			if (!Part.Split(TEXT("="), &K, &V)) continue;
			if (K == TEXT("level")) O.Level = V; else if (K == TEXT("player")) O.Player = V; else if (K == TEXT("seeds")) O.Seeds = FCString::Atoi(*V);
			else if (K == TEXT("rows")) O.Rows = FCString::Atoi(*V); else if (K == TEXT("from")) O.From = FCString::Atoi(*V); else if (K == TEXT("set")) O.Set = V;
		}
		return O;
	}

	// "stick.poke_take_m:0.5,stick.miss_lock_frames:20": this lane's keys and the ones its variants need, by name.
	void ApplySet(FJamGameConfig& G, const FString& Set, FAutomationTestBase& T)
	{
		TArray<FString> Parts;
		Set.ParseIntoArray(Parts, TEXT(","));
		for (const FString& Part : Parts)
		{
			FString K, Vs;
			if (!Part.Split(TEXT(":"), &K, &Vs)) continue;
			const double V = FCString::Atod(*Vs);
			if (K == TEXT("stick.stumble_frames")) G.Stick.StumbleFrames = FMath::RoundToInt32(V);
			else if (K == TEXT("stick.take_grace_frames")) G.Stick.TakeGraceFrames = FMath::RoundToInt32(V);
			else if (K == TEXT("stick.body_shield")) G.Stick.bBodyShield = V > 0.5;
			else if (K == TEXT("stick.poke_window_frames")) G.Stick.PokeWindowFrames = FMath::RoundToInt32(V);
			else if (K == TEXT("stick.reach_m")) G.Stick.ReachM = V;
			else if (K == TEXT("stick.poke_assist_deg")) G.Stick.PokeAssistDeg = V;
			else if (K == TEXT("stick.miss_recovery_frames")) G.Stick.MissRecoveryFrames = FMath::RoundToInt32(V);
			else if (K == TEXT("poke_read")) G.Stick.bPlaytesterPokeRead = V > 0.5;   // the instrument's switch (no key)
			else if (K == TEXT("recovery_bots")) G.Stick.bMissRecoveryBots = V > 0.5;   // the measurement's arm (no key)
			else T.AddError(FString::Printf(TEXT("JAM_POKE_TRACE set: unknown key %s"), *K));
		}
	}
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamBarPokeTrace, "Bar.Movement.PokeTrace", JamPokeTests::Flags)
bool FJamBarPokeTrace::RunTest(const FString& Parameters)
{
	using namespace JamPokeTests;
	UJamCartridge* C = LoadPreset(*this, TEXT("hockey.regular"));
	if (!C) return false;
	const FOpt O = ReadOpt();
	const JamAI::EPlaytester Kind = O.Player == TEXT("novice") ? JamAI::EPlaytester::Novice : (O.Player == TEXT("good") ? JamAI::EPlaytester::Good : JamAI::EPlaytester::Regular);
	TArray<FPress> All;
	int32 Matches = 0, Wins = 0, Own = 0, Other = 0, Rows = 0, Locks = 0, Events = 0, EventsClean = 0;
	int64 OppFrames = 0, OppSprintFrames = 0, OppNearFrames = 0, OppNearSprintFrames = 0;
	int64 Frames = 0;
	for (int32 Seed = O.From; Seed < O.From + O.Seeds; ++Seed)
	{
		UJamCartridge* M = Copy(*C);
		ApplySet(M->Game, O.Set, *this);
		JamAI::FJamSimAdapter Sim(*M);
		FTrace T;
		T.Sim = &Sim;
		const JamAI::FJamMatchConfig Cfg = JamAI::ToMatchConfigResolved(*M, *O.Level);
		const JamAI::FJamPlaytestStats S = JamAI::RunPlaytestMatch(Sim, Cfg, static_cast<uint64>(Seed), Kind, 36000, M->Game.Shot.ChargeFramesMax, false, &PokeTrace, &T, 1);
		if (T.bOpen) Close(T);
		++Matches; Frames += S.Frames; if (S.GoalsFor > S.GoalsAgainst) ++Wins;
		Own += T.OwnStumbles; Other += T.OtherStumbles; Locks += T.Locks; Events += S.Pokes; EventsClean += S.PokesClean;
		OppFrames += T.OppFrames; OppSprintFrames += T.OppSprintFrames; OppNearFrames += T.OppNearFrames; OppNearSprintFrames += T.OppNearSprintFrames;
		AddInfo(FString::Printf(TEXT("POKETRACE match %s %s seed %d: %lld frames, %d:%d, hash %016llx | presses %d, events %d (clean %d), stumbles %d (own missed pokes %d, other %d)"), *O.Player, *O.Level, Seed,
			static_cast<long long>(S.Frames), S.GoalsFor, S.GoalsAgainst, static_cast<unsigned long long>(S.Hash), T.Done.Num(), S.Pokes, S.PokesClean, S.Stumbles, T.OwnStumbles, T.OtherStumbles));
		for (const FPress& P : T.Done)
		{
			if (Rows++ < O.Rows)
				AddInfo(FString::Printf(TEXT("POKETRACE press seed %d f %lld: %s | result %d, opp carrier %d (sprinting %d, shield at press %d), body-puck %.2f, blade-puck %.2f, body-carrier %.2f, closing %.1f, my speed %.1f, his %.1f | window %d frames: grace %d body %d sweep %d spin %d open-in-reach %d open-beyond %d gone %d, min blade-puck %.2f, min body-puck %.2f, aim off %.0f deg, stumbled %d"),
					Seed, static_cast<long long>(P.Frame), WhyName(P.Why), P.Result, P.bOpp ? P.Carrier : -1, P.bCarrierSprint ? 1 : 0, P.Why0, P.Body0, P.Blade0, P.Car0, P.Closing, P.MySpeed, P.CarSpeed, P.Frames,
					P.NGrace, P.NBody, P.NSweep, P.NSpin, P.NOpenIn, P.NOpenBeyond, P.NGone, P.MinBlade > 1e8 ? -1.0 : P.MinBlade, P.MinBody > 1e8 ? -1.0 : P.MinBody, P.MinAimDeg > 1e8 ? -1.0 : P.MinAimDeg, P.bStumbled ? 1 : 0));
		}
		All.Append(T.Done);
	}
	// The table: every press by its reason.
	int32 N[WhyCount] = {}, Stumbled[WhyCount] = {};
	for (const FPress& P : All) { ++N[P.Why]; if (P.bStumbled) ++Stumbled[P.Why]; }
	const int32 Total = All.Num();
	int32 OppMisses = 0;
	for (int32 W = AimOff; W < WhyCount; ++W) OppMisses += N[W];
	const double Mn = FMath::Max(1.0, static_cast<double>(Matches));
	AddInfo(FString::Printf(TEXT("POKETRACE table %s at %s, %d matches (seeds %d..%d), set \"%s\": %d presses (%.1f a match), poke events %.1f a match of which clean %.2f (%.1f %%), %d wins; a match: stumbles from his own missed pokes %.2f, other stumbles %.2f, recoveries (stick locks) %.2f"), *O.Player, *O.Level, Matches, O.From, O.From + O.Seeds - 1, *O.Set,
		Total, Total / Mn, Events / Mn, EventsClean / Mn, 100.0 * EventsClean / FMath::Max(1, Events), Wins, Own / Mn, Other / Mn, Locks / Mn));
	// The takeable misses by how far off the aim was (what a cone of that size would have reached).
	{
		int32 A30 = 0, A60 = 0, A90 = 0, A180 = 0;
		for (const FPress& P : All) if (P.Why == AimOff) { if (P.MinAimDeg <= 30.0) ++A30; if (P.MinAimDeg <= 60.0) ++A60; if (P.MinAimDeg <= 90.0) ++A90; ++A180; }
		AddInfo(FString::Printf(TEXT("POKETRACE aim: of the %d takeable misses the puck was within 30 / 60 / 90 degrees of the aimed blade on a takeable frame in %d / %d / %d"), A180, A30, A60, A90));
	}
	for (int32 W = 0; W < WhyCount; ++W)
		AddInfo(FString::Printf(TEXT("POKETRACE row | %-46s | %4d | %5.1f %% of presses | %5.1f %% of the misses on an opposing carrier | stumbled %d"), WhyName(W), N[W], 100.0 * N[W] / FMath::Max(1, Total), W < AimOff ? 0.0 : 100.0 * N[W] / FMath::Max(1, OppMisses), Stumbled[W]));
	// The brief's two bars: presses on an opposing carrier that is not shielding and not in its grace as the press frame ends; of those, on a sprinting carrier.
	// "At the press" = as the frame before the press ended (a take on the press's own frame leaves no carrier to look at afterwards).
	int32 Open = 0, OpenTook = 0, Sprint = 0, SprintTook = 0, SprintOpen = 0, SprintOpenTook = 0, OppAll = 0, OppTook = 0;
	double SumMinBlade = 0; int32 NMin = 0;
	for (const FPress& P : All)
	{
		if (P.Why == AimOff) { SumMinBlade += P.MinBlade; ++NMin; }
		if (!P.bOppAtPress) continue;
		++OppAll; if (P.Why == Took) ++OppTook;
		if (P.bSprintAtPress) { ++Sprint; if (P.Why == Took) ++SprintTook; }
		if (P.WhyAtPress != WhyNone) continue;
		++Open; if (P.Why == Took) ++OpenTook;
		if (P.bSprintAtPress) { ++SprintOpen; if (P.Why == Took) ++SprintOpenTook; }
	}
	AddInfo(FString::Printf(TEXT("POKETRACE sprint %s at %s: an opponent carried for %lld frames, sprinting in %lld (%.1f %%); within 3 m of the human %lld frames, sprinting in %lld (%.1f %%) | presses on a sprinting carrier %d, took %d (%.1f %%); of those not shielding and not in its grace %d, took %d (%.1f %%)"),
		*O.Player, *O.Level, static_cast<long long>(OppFrames), static_cast<long long>(OppSprintFrames), 100.0 * OppSprintFrames / FMath::Max<int64>(1, OppFrames), static_cast<long long>(OppNearFrames), static_cast<long long>(OppNearSprintFrames),
		100.0 * OppNearSprintFrames / FMath::Max<int64>(1, OppNearFrames), Sprint, SprintTook, 100.0 * SprintTook / FMath::Max(1, Sprint), SprintOpen, SprintOpenTook, 100.0 * SprintOpenTook / FMath::Max(1, SprintOpen)));
	AddInfo(FString::Printf(TEXT("POKETRACE bars %s at %s: took %d of %d presses on an opposing carrier (%.1f %%) | THE BAR, carrier not shielding and not in its grace at the press: %d of %d (%.1f %%) | of those a sprinting carrier: %d of %d (%.1f %%) | mean closest blade-puck of the takeable misses %.2f m (the take is inside %.2f)"),
		*O.Player, *O.Level, OppTook, OppAll, 100.0 * OppTook / FMath::Max(1, OppAll), OpenTook, Open, 100.0 * OpenTook / FMath::Max(1, Open), SprintOpenTook, SprintOpen, 100.0 * SprintOpenTook / FMath::Max(1, SprintOpen), NMin ? SumMinBlade / NMin : 0.0, C->Game.Puck.RadiusM + UJamSim::PokeTakeM));
	// A measurement: no bar here (a share measured on a handful of matches is a log line, never an assertion).
	TestTrue(TEXT("the trace ran"), Matches > 0);
	return true;
}

// Lane A152: the two rules in staged scenes (the gate). The carrier stands at the origin facing +x with the puck settled on its blade; the poker is placed
// and presses once. hockey.regular's own numbers, with this lane's two keys set by each case.
namespace JamPokeTests
{
	struct FPokeScene
	{
		UJamSim* Sim = nullptr;
		int32 Car = -1, Pok = -1;
		TArray<FJamInput> In;
		const FJamSkaterState& C() const { return Sim->GetSkaters()[Car]; }
		const FJamSkaterState& P() const { return Sim->GetSkaters()[Pok]; }
	};

	// bHumanPokes: the human is the poker and an opposing bot seat carries; false: the other way round (the bot seat pokes at the human).
	FPokeScene Stage(const FJamGameConfig& G, bool bHumanPokes, const FVector2D& PokPos, double CarStick = 1.0)
	{
		FPokeScene S;
		S.Sim = NewObject<UJamSim>();
		S.Sim->Init(G, 1);
		S.Sim->SkipFaceoff();
		const int32 Me = S.Sim->GetHumanIndex();
		int32 Opp = -1;
		for (const FJamSkaterState& K : S.Sim->GetSkaters()) if (K.Team != S.Sim->GetSkaters()[Me].Team) { Opp = K.Index; break; }
		S.Car = bHumanPokes ? Opp : Me; S.Pok = bHumanPokes ? Me : Opp;
		const int32 N = S.Sim->GetSkaters().Num();
		for (int32 i = 0; i < N; ++i) S.Sim->SetSkater(i, FVector2D(-40.0 + i * 1.5, 19.0), FVector2D::ZeroVector, 0);
		S.Sim->SetSkater(S.Car, FVector2D::ZeroVector, FVector2D::ZeroVector, 0);
		S.Sim->SetPuck(FVector2D(0.45, 0.0), FVector2D::ZeroVector);
		S.In.SetNum(N);
		S.In[S.Car].Stick = FVector2D(CarStick, 0.0);
		for (int32 i = 0; i < 8; ++i) S.Sim->Step(S.In);
		S.Sim->SetSkater(S.Pok, PokPos, FVector2D::ZeroVector, FMath::Atan2(-PokPos.Y, -PokPos.X));
		return S;
	}

	struct FPokeOut { bool bClean = false, bMiss = false, bCarrierKept = false; int32 CleanAfter = -1; double PuckFromPoker = 0, BladeFromPuck = 0; };

	// One press with the blade aimed OffDeg off the puck's direction at Mag of its length; the window and four frames more.
	FPokeOut Press(FPokeScene& S, double OffDeg, double Mag)
	{
		FPokeOut O;
		static const FName Clean(TEXT("clean")), Miss(TEXT("miss"));
		const FVector2D To = (S.Sim->GetPuck().Pos - S.P().Pos).GetSafeNormal();
		const double A = FMath::DegreesToRadians(OffDeg);
		S.In[S.Pok].Stick = FVector2D(To.X * FMath::Cos(A) - To.Y * FMath::Sin(A), To.X * FMath::Sin(A) + To.Y * FMath::Cos(A)) * Mag;
		S.In[S.Pok].bPoke = true;
		const int32 Frames = S.Sim->GetConfig().Stick.PokeWindowFrames + 4;
		for (int32 F = 0; F < Frames; ++F)
		{
			S.Sim->Step(S.In);
			S.In[S.Pok].bPoke = false;
			if (F == 0) { O.PuckFromPoker = FVector2D::Distance(S.P().Pos, S.Sim->GetPuck().Pos); O.BladeFromPuck = FVector2D::Distance(S.P().BladePos, S.Sim->GetPuck().Pos); }
			for (const FJamSimEvent& E : S.Sim->GetFrameEvents())
			{
				if (E.Name != JamEvents::Poke || E.Who != S.Pok) continue;
				if (E.Kind == Clean) { if (!O.bClean) O.CleanAfter = F; O.bClean = true; } else if (E.Kind == Miss) O.bMiss = true;
			}
		}
		O.bCarrierKept = S.Sim->GetPuck().LastTouch == S.Car;
		return O;
	}
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamMovementPokeReach, "Jam.Core.Movement.PokeReach", JamPokeTests::Flags)
bool FJamMovementPokeReach::RunTest(const FString& Parameters)
{
	using namespace JamPokeTests;
	UJamCartridge* C = LoadPreset(*this, TEXT("hockey.regular"));
	if (C) { C->Game.Stick.PickupArcM = 0.0; C->Game.Stick.bPickupBody = false; }   // lane A208: re-staged at game.stick.pickup's neutral: this scene measures the poke that reaches and what it takes; the loose puck's pickup has its own (Jam.Core.Possession.*)
	if (!C) return false;
	TestEqual(TEXT("game.stick.poke_assist_deg is 60 when the key is absent"), C->Game.Stick.PokeAssistDeg, 60.0);
	TestEqual(TEXT("game.stick.miss_recovery_frames is 20 when the key is absent"), C->Game.Stick.MissRecoveryFrames, 20);
	{
		FJamGameConfig Neutral = C->Game;
		JamBaseline::MakeNeutral(Neutral);
		TestTrue(TEXT("JamBaseline::MakeNeutral: poke_assist_deg 0, miss_recovery_frames 0, the scripted human's old press"), Neutral.Stick.PokeAssistDeg == 0.0 && Neutral.Stick.MissRecoveryFrames == 0 && !Neutral.Stick.bPlaytesterPokeRead);
	}
	FJamGameConfig On = C->Game, Off = C->Game;
	On.Stick.PokeAssistDeg = 60.0; On.Stick.MissRecoveryFrames = 0;
	Off.Stick.PokeAssistDeg = 0.0; Off.Stick.MissRecoveryFrames = 0;
	const double Full = UJamSim::SkaterRadius + On.Stick.ReachM + On.Puck.RadiusM + UJamSim::PokeTakeM;
	auto Row = [this](const TCHAR* Name, const FPokeScene& S, const FPokeOut& O)
	{
		AddInfo(FString::Printf(TEXT("POKEREACH %s: clean %d (after %d frames), miss event %d, the carrier kept it %d | at the press: the puck %.2f m from the poker's body, %.2f m from its blade"), Name, O.bClean ? 1 : 0, O.CleanAfter, O.bMiss ? 1 : 0, O.bCarrierKept ? 1 : 0, O.PuckFromPoker, O.BladeFromPuck));
	};
	// 1. The aim trails: the blade points 40 degrees off the puck at half its length. The blade rule misses; the poke that reaches takes it.
	{
		FPokeScene A = Stage(Off, true, FVector2D(2.9, 0.0));
		TestFalse(TEXT("the staged carrier is not in a take grace (a placed puck)"), A.Sim->InTakeGrace(A.C()));
		TestEqual(TEXT("the staged carrier carries"), A.Sim->CarrierIndex(), A.Car);
		const FPokeOut Oa = Press(A, 40.0, 0.5);
		Row(TEXT("aim 40 degrees off, poke_assist_deg 0"), A, Oa);
		TestTrue(TEXT("the scene: the puck is inside the stick's reach of the poker's body"), Oa.PuckFromPoker <= Full);
		TestTrue(TEXT("the scene: the blade is not on the puck"), Oa.BladeFromPuck > On.Puck.RadiusM + UJamSim::PokeTakeM);
		TestTrue(TEXT("poke_assist_deg 0 (neutral): a blade that is not on the puck misses, as before"), !Oa.bClean && Oa.bCarrierKept && Oa.bMiss);
		FPokeScene B = Stage(On, true, FVector2D(2.9, 0.0));
		const FPokeOut Ob = Press(B, 40.0, 0.5);
		Row(TEXT("aim 40 degrees off, poke_assist_deg 60"), B, Ob);
		TestTrue(TEXT("poke_assist_deg 60: the human's poke reaches the unshielded puck inside its reach and takes it"), Ob.bClean && !Ob.bCarrierKept && !Ob.bMiss);
		TestEqual(TEXT("... on the frame of the press"), Ob.CleanAfter, 0);
		TestEqual(TEXT("... and the puck is the poker's"), B.Sim->GetPuck().LastTouch, B.Pok);
	}
	// 2. The cone holds: 100 degrees off is not a poke at the puck.
	{
		FPokeScene B = Stage(On, true, FVector2D(2.9, 0.0));
		const FPokeOut Ob = Press(B, 100.0, 0.5);
		Row(TEXT("aim 100 degrees off, poke_assist_deg 60"), B, Ob);
		TestTrue(TEXT("outside the cone the poke does not reach"), !Ob.bClean && Ob.bCarrierKept);
	}
	// 3. Never further than a perfectly aimed blade: from 3.6 m of the carrier the puck is beyond the stick.
	{
		FPokeScene B = Stage(On, true, FVector2D(3.6, 0.0));
		const FPokeOut Ob = Press(B, 0.0, 1.0);
		Row(TEXT("from 3.6 m, aimed straight, poke_assist_deg 60"), B, Ob);
		TestTrue(TEXT("the scene: the puck is beyond the stick's reach"), Ob.PuckFromPoker > Full);
		TestTrue(TEXT("beyond the stick's reach nothing is taken"), !Ob.bClean && Ob.bCarrierKept);
	}
	// 4. The shields refuse it as before: from behind the carrier, the body between.
	{
		FPokeScene B = Stage(On, true, FVector2D(-1.2, 0.0), 0.3);
		TestTrue(TEXT("the scene: the body shields the puck from the poker behind"), B.Sim->IsBodyShielded(B.P(), B.C()));
		const FPokeOut Ob = Press(B, 30.0, 1.0);
		Row(TEXT("from behind, the body between, poke_assist_deg 60"), B, Ob);
		TestTrue(TEXT("the body between refuses the poke that reaches"), !Ob.bClean && Ob.bCarrierKept);
		FJamGameConfig NoShield = On;
		NoShield.Stick.bBodyShield = false;
		FPokeScene D = Stage(NoShield, true, FVector2D(-1.2, 0.0), 0.3);
		const FPokeOut Od = Press(D, 30.0, 1.0);
		Row(TEXT("from behind, body_shield false, poke_assist_deg 60"), D, Od);
		TestTrue(TEXT("... and without the body shield the same poke takes it (the scene was inside reach)"), Od.bClean);
	}
	// 5. Bots keep the blade rule: the bot seat's trailing aim misses the human's puck with the key on.
	{
		FPokeScene B = Stage(On, false, FVector2D(2.9, 0.0));
		TestTrue(TEXT("the scene: the human carries"), B.C().bHuman && B.Sim->CarrierIndex() == B.Car);
		const FPokeOut Ob = Press(B, 40.0, 0.5);
		Row(TEXT("the bot seat pokes at the human, aim 40 degrees off, poke_assist_deg 60"), B, Ob);
		TestTrue(TEXT("a bot's poke does not reach: its blade must be on the puck"), !Ob.bClean && Ob.bCarrierKept);
	}
	// 6. Law 4: a sprinting carrier's puck rides further from its body and is taken from further away. The carrier skates at the standing poker, stick ahead;
	// the poker presses once when the bodies are 4.6 m apart, aimed down the line; the distance between the bodies at the take is read.
	double TakenAt[2] = { 0.0, 0.0 };
	for (int32 Arm = 0; Arm < 2; ++Arm)
	{
		FPokeScene B = Stage(On, true, FVector2D(16.0, 0.0));
		B.In[B.Car].Move = FVector2D(1.0, 0.0);
		B.In[B.Car].bSprint = Arm == 1;
		B.In[B.Pok].Stick = FVector2D(-1.0, 0.0);
		static const FName Clean(TEXT("clean"));
		bool bPressed = false, bSprintSeen = false;
		double PuckOut = 0.0;
		for (int32 F = 0; F < 400 && TakenAt[Arm] <= 0.0; ++F)
		{
			const double D = FVector2D::Distance(B.C().Pos, B.P().Pos);
			B.In[B.Pok].bPoke = !bPressed && D <= 4.6;
			if (B.In[B.Pok].bPoke) bPressed = true;
			PuckOut = FVector2D::Distance(B.C().Pos, B.Sim->GetPuck().Pos);
			bSprintSeen = B.C().bSprinting;
			B.Sim->Step(B.In);
			for (const FJamSimEvent& E : B.Sim->GetFrameEvents()) if (E.Name == JamEvents::Poke && E.Who == B.Pok && E.Kind == Clean) TakenAt[Arm] = FVector2D::Distance(B.C().Pos, B.P().Pos);
			if (bPressed && B.P().PokeWindow <= 0 && TakenAt[Arm] <= 0.0) break;
		}
		AddInfo(FString::Printf(TEXT("POKEREACH law 4, the carrier %s: the puck rode %.2f m from its body; taken with the bodies %.2f m apart"), Arm == 1 ? TEXT("sprints") : TEXT("skates"), PuckOut, TakenAt[Arm]));
		TestTrue(Arm == 1 ? TEXT("the sprinting carrier's puck was taken") : TEXT("the skating carrier's puck was taken"), TakenAt[Arm] > 0.0);
		if (Arm == 1) TestTrue(TEXT("the carrier was sprinting at the take"), bSprintSeen);
	}
	TestTrue(TEXT("law 4: the sprinting carrier's puck is taken from at least 0.2 m further away than the skating carrier's"), TakenAt[1] >= TakenAt[0] + 0.2);
	return true;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamMovementPokeRecovery, "Jam.Core.Movement.PokeRecovery", JamPokeTests::Flags)
bool FJamMovementPokeRecovery::RunTest(const FString& Parameters)
{
	using namespace JamPokeTests;
	UJamCartridge* C = LoadPreset(*this, TEXT("hockey.regular"));
	if (!C) return false;
	static const FName Miss(TEXT("miss"));
	// A bot's miss stays the stumble with the key on: the bot seat pokes short at the human's puck.
	{
		FJamGameConfig G = C->Game;
		G.Stick.PokeAssistDeg = 0.0; G.Stick.MissRecoveryFrames = 20;
		FPokeScene S = Stage(G, false, FVector2D(2.9, 0.0));
		S.In[S.Pok].Stick = FVector2D(-0.5, 0.0);
		S.In[S.Pok].bPoke = true;
		int32 Misses = 0;
		for (int32 F = 0; F < G.Stick.PokeWindowFrames + 1 && Misses == 0; ++F)
		{
			S.Sim->Step(S.In);
			S.In[S.Pok].bPoke = false;
			for (const FJamSimEvent& E : S.Sim->GetFrameEvents()) if (E.Name == JamEvents::Poke && E.Who == S.Pok && E.Kind == Miss) ++Misses;
		}
		TestEqual(TEXT("the bot seat's short poke at the human's puck is a miss"), Misses, 1);
		TestEqual(TEXT("miss_recovery_frames 20: a bot's miss is still the stumble"), S.P().StumbleFrames, G.Stick.StumbleFrames);
		TestEqual(TEXT("... and no stick lock on the bot"), S.P().StickLockLeft, 0);
	}
	for (int32 Arm = 0; Arm < 2; ++Arm)
	{
		FJamGameConfig G = C->Game;
		G.Stick.PokeAssistDeg = 0.0;                       // the blade rule, so the staged press misses
		G.Stick.MissRecoveryFrames = Arm == 1 ? 20 : 0;    // 0 = the neutral value: the stumble
		const int32 N = G.Stick.MissRecoveryFrames;
		FPokeScene S = Stage(G, true, FVector2D(2.9, 0.0));
		// the press: half an aim, the blade stops short of the puck; armed (the carrier is within two bodies + reach + 1 m)
		S.In[S.Pok].Stick = FVector2D(-0.5, 0.0);
		S.In[S.Pok].bPoke = true;
		int32 Misses = 0, Guard = 0;
		while (Misses == 0 && Guard++ < G.Stick.PokeWindowFrames + 2)
		{
			S.Sim->Step(S.In);
			S.In[S.Pok].bPoke = false;
			for (const FJamSimEvent& E : S.Sim->GetFrameEvents()) if (E.Name == JamEvents::Poke && E.Who == S.Pok && E.Kind == Miss) ++Misses;
		}
		TestEqual(TEXT("one miss event when the window runs out"), Misses, 1);
		TestEqual(TEXT("the carrier kept the puck"), S.Sim->GetPuck().LastTouch, S.Car);
		if (Arm == 0)
		{
			TestEqual(TEXT("miss_recovery_frames 0 (neutral): the miss is the stumble of stumble_frames, as before"), S.P().StumbleFrames, G.Stick.StumbleFrames);
			TestEqual(TEXT("... and no stick lock"), S.P().StickLockLeft, 0);
			S.In[S.Pok].Move = FVector2D(0.0, 1.0);
			for (int32 F = 0; F < G.Stick.StumbleFrames - 2; ++F) S.Sim->Step(S.In);
			AddInfo(FString::Printf(TEXT("POKERECOVERY neutral: %d frames into the stumble the poker moves at %.2f m/s"), G.Stick.StumbleFrames - 2, S.P().Vel.Size()));
			TestTrue(TEXT("... no thrust while stumbling"), S.P().Vel.Size() < 0.5);
			continue;
		}
		TestFalse(TEXT("miss_recovery_frames 20: the poker does not stumble"), S.P().IsStumbling());
		TestTrue(TEXT("... it is in control"), S.P().CanAct());
		TestEqual(TEXT("... its stick is locked for miss_recovery_frames"), S.P().StickLockLeft, N);
		// through the recovery it presses everything and skates away: nothing of the stick answers, the legs do
		S.In[S.Pok].Move = FVector2D(0.0, 1.0);
		int32 Pokes = 0, Lifts = 0, Checks = 0;
		for (int32 F = 0; F < N; ++F)
		{
			S.In[S.Pok].bPoke = S.In[S.Pok].bLift = S.In[S.Pok].bCheck = true;
			S.Sim->Step(S.In);
			if (S.P().bPokeThisFrame || S.P().PokeWindow > 0) ++Pokes;
			if (S.P().bLiftThisFrame) ++Lifts;
			if (S.P().bCheckThisFrame || S.P().CheckWindow > 0) ++Checks;
		}
		AddInfo(FString::Printf(TEXT("POKERECOVERY miss_recovery_frames %d: inside the recovery pokes opened %d, lifts %d, checks %d; the poker moves at %.2f m/s after it; stick lock left %d"), N, Pokes, Lifts, Checks, S.P().Vel.Size(), S.P().StickLockLeft));
		TestEqual(TEXT("... no poke opens inside the recovery"), Pokes, 0);
		TestEqual(TEXT("... no lift"), Lifts, 0);
		TestEqual(TEXT("... no check"), Checks, 0);
		TestTrue(TEXT("... the legs answer: it skated away during the recovery"), S.P().Vel.Size() > 1.5);
		TestEqual(TEXT("... the lock has run out"), S.P().StickLockLeft, 0);
		S.Sim->Step(S.In);
		TestTrue(TEXT("the frame after the recovery the poke opens again"), S.P().bPokeThisFrame);
		TestTrue(TEXT("... and the check"), S.P().bCheckThisFrame);
	}
	return true;
}

// Lane A152: the neutral values are the game before the lane. No pinned hash (a shipped cut's match moves with every landing): the same seeds played twice
// in this run, once with the two keys and the instrument's switch at their neutral values, once with all three on and the lane's code closed by its test
// seam (stick.bPokeRulesOff); the two hashes must equal each other. The third arm (all on, the seam open) is logged: it is another match.
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamMovementPokeNeutral, "Jam.Core.Movement.PokeNeutral", JamPokeTests::Flags)
bool FJamMovementPokeNeutral::RunTest(const FString& Parameters)
{
	using namespace JamPokeTests;
	UJamCartridge* C = LoadPreset(*this, TEXT("hockey.regular"));
	if (!C) return false;
	for (uint64 Seed = 3; Seed <= 4; ++Seed)
	{
		uint64 Hash[3] = {};
		int32 Pokes[3] = {}, Stumbles[3] = {};
		for (int32 Arm = 0; Arm < 3; ++Arm)
		{
			UJamCartridge* M = Copy(*C);
			FJamStickConfig& K = M->Game.Stick;
			if (Arm == 0) { K.PokeAssistDeg = 0.0; K.MissRecoveryFrames = 0; K.bPlaytesterPokeRead = false; K.bPokeRulesOff = false; }
			else { K.PokeAssistDeg = 60.0; K.MissRecoveryFrames = 20; K.bPlaytesterPokeRead = true; K.bPokeRulesOff = Arm == 1; }
			JamAI::FJamSimAdapter Sim(*M);
			const JamAI::FJamMatchConfig Cfg = JamAI::ToMatchConfigResolved(*M, TEXT("pro"));
			const JamAI::FJamPlaytestStats S = JamAI::RunPlaytestMatch(Sim, Cfg, Seed, JamAI::EPlaytester::Regular, 7200, M->Game.Shot.ChargeFramesMax);
			Hash[Arm] = S.Hash; Pokes[Arm] = S.Pokes; Stumbles[Arm] = S.Stumbles;
		}
		AddInfo(FString::Printf(TEXT("POKENEUTRAL pro seed %llu, 7200 frames: keys neutral %016llx (poke events %d, stumbles %d) | keys on, the seam closed %016llx (%d, %d) | keys on %016llx (%d, %d)"), Seed,
			static_cast<unsigned long long>(Hash[0]), Pokes[0], Stumbles[0], static_cast<unsigned long long>(Hash[1]), Pokes[1], Stumbles[1], static_cast<unsigned long long>(Hash[2]), Pokes[2], Stumbles[2]));
		TestEqual(FString::Printf(TEXT("seed %llu: the neutral values play the match the code before the lane plays (the seam closed)"), Seed), Hash[0], Hash[1]);
		TestTrue(FString::Printf(TEXT("seed %llu: the match was played (the human pressed pokes)"), Seed), Pokes[0] > 0);
	}
	return true;
}

// Lane A152: the pass-by drill (a measurement, outside the gate). A bot seat carries the puck down the x axis, skating or sprinting, stick ahead; the human
// stands beside its lane (0.8 to 2.4 m off, either side, seeded) and pokes as a person does: the aim and the press are decided on the world it sees and
// reach the sim Late frames afterwards (6 = the regular player's reaction, 3 = the good player's). 200 seeds a row; the share of passes in which the poke took the puck.
namespace JamPokeTests
{
	struct FDrillRow { int32 Took = 0, Presses = 0, Pressed = 0, N = 0; double PuckOut = 0.0, Speed = 0.0; };   // Pressed: passes in which the puck came inside the stick's reach and he pressed

	FDrillRow PassBy(const FJamGameConfig& G, bool bSprint, int32 Late, int32 Seeds)
	{
		FDrillRow R;
		static const FName Clean(TEXT("clean"));
		for (int32 Seed = 1; Seed <= Seeds; ++Seed)
		{
			const double U = FMath::Frac(Seed * 0.6180339887), V = FMath::Frac(Seed * 0.7548776662);
			const double Off = (0.8 + 1.6 * U) * (V < 0.5 ? 1.0 : -1.0);
			FPokeScene S = Stage(G, true, FVector2D(16.0, Off));
			S.Sim->SetSkater(S.Pok, FVector2D(16.0, Off), FVector2D::ZeroVector, UE_DOUBLE_PI);   // facing up the rink, at the carrier coming
			S.In[S.Car].Move = FVector2D(1.0, 0.0);
			S.In[S.Car].bSprint = bSprint;
			TArray<FJamInput> Ring;
			Ring.SetNum(Late + 1);
			bool bTook = false, bPressed = false;
			for (int32 F = 0; F < 400 && S.C().Pos.X < 22.0 && !bTook; ++F)
			{
				// the decision on what it sees now
				FJamInput D;
				const FVector2D Tp = S.Sim->GetPuck().Pos - S.P().Pos;
				const double Dp = Tp.Size();
				if (S.Sim->CarrierIndex() == S.Car && Dp > 1e-6 && Dp < UJamSim::SkaterRadius + G.Stick.ReachM + 1.0)
				{
					const double Reach = Dp - UJamSim::SkaterRadius;
					D.Stick = Tp / Dp * (Reach < G.Stick.ReachM ? FMath::Clamp(Reach / G.Stick.ReachM, 0.2, 1.0) : 1.0);
					D.bPoke = Dp <= UJamSim::SkaterRadius + G.Stick.ReachM;
				}
				Ring[F % (Late + 1)] = D;
				const FJamInput Out = F >= Late ? Ring[(F - Late) % (Late + 1)] : FJamInput();
				S.In[S.Pok].Stick = Out.Stick;
				S.In[S.Pok].bPoke = Out.bPoke && S.P().CanAct() && S.Sim->GetFrame() + 1 >= S.P().PokeReadyFrame && S.P().PokeWindow <= 0;
				if (FMath::Abs(S.C().Pos.X - 12.0) < 0.1) { R.PuckOut = FVector2D::Distance(S.C().Pos, S.Sim->GetPuck().Pos); R.Speed = S.C().Vel.Size(); }
				S.Sim->Step(S.In);
				if (S.P().bPokeThisFrame) { ++R.Presses; bPressed = true; }
				for (const FJamSimEvent& E : S.Sim->GetFrameEvents()) if (E.Name == JamEvents::Poke && E.Who == S.Pok && E.Kind == Clean && E.Strength > 0.5f) bTook = true;
			}
			++R.N; if (bTook) ++R.Took; if (bPressed) ++R.Pressed;
		}
		return R;
	}
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamBarPokeDrill, "Bar.Movement.PokeDrill", JamPokeTests::Flags)
bool FJamBarPokeDrill::RunTest(const FString& Parameters)
{
	using namespace JamPokeTests;
	UJamCartridge* C = LoadPreset(*this, TEXT("hockey.regular"));
	if (!C) return false;
	const double Degs[] = { 0.0, 45.0, 60.0, 90.0, 180.0 };
	for (int32 Late : { 6, 3, 0 })
	{
		for (double Deg : Degs)
		{
			FJamGameConfig G = C->Game;
			G.Stick.PokeAssistDeg = Deg;
			const FDrillRow A = PassBy(G, false, Late, 200), B = PassBy(G, true, Late, 200);
			AddInfo(FString::Printf(TEXT("POKEDRILL the hand %d frames late, poke_assist_deg %3.0f | the carrier skates (%.1f m/s, the puck %.2f m out): took the puck in %d of the %d passes he pressed in (%.1f %%; %d passes, %d presses) | sprints (%.1f m/s, %.2f m out): %d of %d (%.1f %%; %d passes, %d presses)"),
				Late, Deg, A.Speed, A.PuckOut, A.Took, A.Pressed, 100.0 * A.Took / FMath::Max(1, A.Pressed), A.N, A.Presses, B.Speed, B.PuckOut, B.Took, B.Pressed, 100.0 * B.Took / FMath::Max(1, B.Pressed), B.N, B.Presses));
		}
	}
	return true;
}

#endif
