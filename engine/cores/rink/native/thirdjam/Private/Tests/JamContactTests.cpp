// Lane A92 (R-0045, docs/VISION.md law 1; docs/experiments/CONTACT.md): contact by momentum.
//   Jam.Core.Contact.SameDirection   two skaters going the same way at the same speed: a pressed check is a bump at most
//   Jam.Core.Contact.HeadOn          head-on at full speed: down for down_frames_max
//   Jam.Core.Contact.StandingBrace   a standing skater: a side body check from 4 m/s stumbles it at most, a front cross-check from the same speed puts it down
//   Jam.Core.Contact.SprintFalls     a sprinting victim falls to the hit a walking one survives
//   Jam.Core.Contact.AttackerBounces a sprinting attacker into a braced skater is the one who stumbles
//   Jam.Core.Contact.CarrierRefused  the carrier's check press is refused; contact.carrier_can_hit true gives the press back
//   Jam.Core.Contact.Fouls           a hit from behind on the carrier and a hit on a skater without the puck still call the foul
//   Jam.Core.ContactNeutral          the neutral block (momentum false, carrier_can_hit true): a three-minute bot match hashes as main at 8f6b157 did
//   Jam.Core.ContactMatch            the same match at pro and at all_star under the model: the contacts by kind and by whom
//   Jam.Core.Contact.Levers          skater.knockdown_frames scales the frames down; skater.check_speed_min scales the hit (5 / value), not the frames
//   Jam.Core.ContactModes            the modes that wrote those two levers (and the raw cut), model against neutral: knockdowns and frames down (a measurement)
//   Jam.Core.ContactTakes            the rookie takes of Jam.Bot.SeasonTakes over ten seeds, model against neutral: the AI's shots and the score (a measurement)
// Lane A101 (track F1, docs/experiments/CONTACT-2.md): every outcome reads.
//   Jam.Core.Contact.Boards          the boards are a body: a hit that pushes a victim within 1.5 m of the boards into them counts x contact.board_bonus and fires the
//                                    board read-out and event; along the boards, away from them, beyond 1.5 m and at board_bonus 1 it is the open-ice hit
//   Jam.Core.Contact.HitStop         the hold by outcome and ratio: stumble 1 or 2 frames, knockdown 2 to 5, bump 0; jam.hitstop scales it
//   Jam.Core.ContactBoardMatch       three pro matches: outcomes by kind, the share of hits near the boards; board_bonus 1 hashes as main at ee14438 did
// Lane A113 (track F1, R-0049 point 1, docs/experiments/CONTACT-3.md): a tackle is an event, not a rhythm.
//   Jam.Core.Contact.ReleaseGrace    a skater released from a knockdown takes a bump at most for contact.release_grace_frames; after it the same hit lands;
//                                    0 = the hit lands at once; the counter is hashed while it runs; the soft hit and the whiff count for the HUD
//   Jam.Core.Contact.HitStopPick     the hit the hold is for: one that involves the human is never hidden by a knockdown between two bots
//   Jam.Core.ContactGraceMatch       release_grace_frames 0 hashes as the baseline (three pro seeds); ten pro matches of 100 s, grace 0 / 90 / 120: knockdowns
//                                    of the human, figures down again within 2 s of their release
// Run:
//   UnrealEditor-Cmd.exe Game/ThirdJam.uproject -ExecCmds="Automation RunTests Jam.Core.Contact; Quit" -unattended -nullrhi -nosplash -log
#include "Misc/AutomationTest.h"
#include "Misc/FileHelper.h"
#include "Misc/Paths.h"
#include "JamBotMatch.h"
#include "DifficultyResolve.h"
#include "JamCartridge.h"
#include "JamEventBus.h"
#include "JamPawns.h"
#include "JamPlaytester.h"
#include "JamSim.h"
#include "JamBaseline.h"
#include "JamContactDrill.h"
#include "JamSimAdapter.h"

#if WITH_DEV_AUTOMATION_TESTS

namespace JamContactTests
{
	constexpr EAutomationTestFlags Flags = EAutomationTestFlags_ApplicationContextMask | EAutomationTestFlags::ProductFilter;
	const FName FoulEvent(TEXT("foul"));

	// ---- the three-minute bot match ------------------------------------------------------------------------------------------------------------
	struct FContactCount
	{
		JamAI::FJamSimAdapter* Sim = nullptr;
		int32 Human = -1;
		int32 Bumps[2] = { 0, 0 };        // [0] on a bot, [1] on the human: bBumpThisFrame frames (the figure's PlayHitReaction)
		int32 Checks[2] = { 0, 0 };       // check events by a bot / by the human
		int32 Downs[2] = { 0, 0 };        // knockdown events of a bot / of the human
		int32 BotOnBotDowns = 0;          // a bot knocked down by a bot
		int32 Lifts[2] = { 0, 0 };        // lift presses by a bot / by the human
		// The model's read-outs, by victim (bot / human): hits resolved as a bump, a stumble, a knockdown; the attacker's recoils and the carrier's refused presses.
		int32 HitBump[2] = { 0, 0 }, HitStumble[2] = { 0, 0 }, HitDown[2] = { 0, 0 }, Recoil[2] = { 0, 0 }, Refused[2] = { 0, 0 };
		int32 CrossStumble[2] = { 0, 0 }, CrossDown[2] = { 0, 0 };   // of those, by a cross-check (the rest by a body check)
		int32 DownFrames[2] = { 0, 0 };                               // frames down, summed (the model's knockdowns only)
		// Lane A101: hits (any outcome) on a victim within ContactBoardRangeM of the boards; of the landed ones, those the boards answered (bContactBoard), by outcome;
		// and the ones the bonus promoted (the ratio without the boards' factor was under the threshold the hit passed).
		int32 NearBoards[2] = { 0, 0 }, BoardStumble[2] = { 0, 0 }, BoardDown[2] = { 0, 0 }, BoardPromotedStumble[2] = { 0, 0 }, BoardPromotedDown[2] = { 0, 0 };
		// Every resolved hit by where and how: [0 = within 1.5 m of the boards, 1 = 1.5 to 3 m][0 = into them (dot of the push and the outward normal 0.5 and up),
		// 1 = glancing (0 to 0.5), 2 = along or away][bump, stumble, down]. The push of a bump is the victim's BumpDir (stale when the bump read-out was gapped).
		int32 Where[2][3][3] = {};
		int32 BoardEvents = 0;                                        // `board` events with Kind skater (the hit's and a skater's own slide into the boards)
		// Lane A113: the release grace. By victim (bot / human): knockdowns (any cause) that begin within ReDownWindow frames of the same skater's release, of
		// those the ones a hit caused (ContactOutcome down), stumbles by a hit in the same window, hits the grace made a bump (bContactGrace) and of those the
		// ones a bot threw; the shortest release-to-down gap of the match; the human's HUD counters at the end.
		static constexpr int32 ReDownWindow = 120, MaxSk = 16;
		int32 ReDown[2] = { 0, 0 }, ReDownByHit[2] = { 0, 0 }, ReStumble[2] = { 0, 0 }, Graced[2] = { 0, 0 }, GracedByBot = 0, ReHitInGrace = 0;
		int32 MinGap = 1000000, GraceAtRelease = -1;
		int32 HumanSoft = 0, HumanMissed = 0, HumanGraced = 0;
		bool bWasDown[MaxSk] = {};
		int64 ReleasedAt[MaxSk] = { -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 };
		int32 GraceBefore[MaxSk] = {};   // GraceFrames after the previous frame: over 1 means the skater was inside its grace when this frame's contacts resolved
		int64 LastFrame = -1;
		FJamShieldShoveTally Shove[2];   // lane A132: UJamSim::ShieldShoveTally at the end of the match ([0] a bot's presses, [1] the human's)
	};

	void Trace(void* Ctx, const JamAI::FJamAIWorld&, const JamAI::FJamAIInput*, const JamAI::FJamBrain&, int64_t, bool)
	{
		FContactCount& C = *static_cast<FContactCount*>(Ctx);
		const UJamSim* Sim = C.Sim->GetSim();
		if (!Sim || Sim->GetFrame() == C.LastFrame) return;   // the trace is called every frame and again on a touch frame
		C.LastFrame = Sim->GetFrame();
		for (const FJamSkaterState& S : Sim->GetSkaters())
		{
			const int32 H = S.Index == C.Human ? 1 : 0;
			if (S.bBumpThisFrame) ++C.Bumps[H];
			if (S.bLiftThisFrame) ++C.Lifts[H];
			if (S.ContactOutcome == UJamSim::ContactBump) ++C.HitBump[H];
			if (S.ContactOutcome == UJamSim::ContactStumble) { ++C.HitStumble[H]; if (S.bContactCross) ++C.CrossStumble[H]; }
			if (S.ContactOutcome == UJamSim::ContactDown) { ++C.HitDown[H]; C.DownFrames[H] += S.KnockFrames; if (S.bContactCross) ++C.CrossDown[H]; }
			if (S.bRecoilThisFrame) ++C.Recoil[H];
			if (S.bCheckRefused) ++C.Refused[H];
			// Lane A113: the release grace.
			if (S.Index < FContactCount::MaxSk)
			{
				const int32 I = S.Index;
				const bool bDown = S.IsDown();
				const bool bInWindow = C.ReleasedAt[I] >= 0 && Sim->GetFrame() - C.ReleasedAt[I] < FContactCount::ReDownWindow;   // inside 2 s: frames 0 to 119 after the release
				if (bDown && !C.bWasDown[I] && C.ReleasedAt[I] >= 0)
				{
					C.MinGap = FMath::Min(C.MinGap, static_cast<int32>(Sim->GetFrame() - C.ReleasedAt[I]));
					if (bInWindow) { ++C.ReDown[H]; if (S.ContactOutcome == UJamSim::ContactDown) ++C.ReDownByHit[H]; }
				}
				if (S.ContactOutcome == UJamSim::ContactStumble && bInWindow) ++C.ReStumble[H];
				if (S.ContactOutcome >= UJamSim::ContactStumble && C.GraceBefore[I] > 1) ++C.ReHitInGrace;   // the rule's own promise: never
				if (S.bContactGrace) { ++C.Graced[H]; if (S.ContactBy != C.Human) ++C.GracedByBot; }
				if (!bDown && C.bWasDown[I]) { C.ReleasedAt[I] = Sim->GetFrame(); if (C.GraceAtRelease < 0) C.GraceAtRelease = S.GraceFrames; }
				C.bWasDown[I] = bDown;
				C.GraceBefore[I] = S.GraceFrames;
				if (H == 1) { C.HumanSoft = S.ChecksSoft; C.HumanMissed = S.ChecksMissed; C.HumanGraced = S.ChecksGraced; }
			}
			if (S.ContactOutcome != UJamSim::ContactNone)
			{
				FVector2D N;
				const double Gap = -Sim->BoardDistance(S.Pos, N);
				if (Gap <= UJamSim::ContactBoardRangeM) ++C.NearBoards[H];
				if (Gap <= 2.0 * UJamSim::ContactBoardRangeM)
				{
					const double Into = FVector2D::DotProduct(S.ContactOutcome == UJamSim::ContactDown ? S.KnockDir : S.BumpDir, N);
					++C.Where[Gap <= UJamSim::ContactBoardRangeM ? 0 : 1][Into >= 0.5 ? 0 : Into > 0.0 ? 1 : 2][S.ContactOutcome - 1];
				}
				if (S.bContactBoard)
				{
					const FJamContactConfig& K = Sim->GetConfig().Contact;
					const double Free = S.ContactRatio / Sim->BoardFactor(S, S.ContactOutcome == UJamSim::ContactDown ? S.KnockDir : S.BumpDir);
					if (S.ContactOutcome == UJamSim::ContactDown) { ++C.BoardDown[H]; if (Free < K.DownRatio) ++C.BoardPromotedDown[H]; }
					else { ++C.BoardStumble[H]; if (Free < K.BumpRatio) ++C.BoardPromotedStumble[H]; }
				}
			}
		}
		int32 Checker = -1;
		for (const FJamSimEvent& E : Sim->GetFrameEvents())
		{
			if (E.Name == JamEvents::Check) { Checker = E.Who; ++C.Checks[E.Who == C.Human ? 1 : 0]; }
			if (E.Name == JamEvents::Board && E.Who >= 0) ++C.BoardEvents;
			if (E.Name == JamEvents::Knockdown)
			{
				++C.Downs[E.Who == C.Human ? 1 : 0];
				if (E.Who != C.Human && Checker >= 0 && Checker != C.Human) ++C.BotOnBotDowns;
			}
		}
	}

	// hockey.regular at a level, penalties off and no score limit inside the three minutes (A73's cut), 10 800 frames, the Regular playtester as the human.
	// File = another cartridge (its own rules kept, Level null = its own level).
	JamAI::FJamPlaytestStats Match(FAutomationTestBase& T, const TCHAR* Level, uint64 Seed, FContactCount& Count, TFunctionRef<void(FJamGameConfig&)> Edit, const FString& File = FString(), int64 Frames = 10800, const char* Tune = nullptr)
	{
		TArray<FString> Errors;
		UJamCartridge* C = UJamCartridge::LoadFromFile(File.IsEmpty() ? UJamCartridge::ResolveCartridgePath(TEXT("hockey.regular")) : File, Errors);
		for (const FString& E : Errors) T.AddError(FString::Printf(TEXT("%s: %s"), File.IsEmpty() ? TEXT("hockey.regular") : *File, *E));
		if (!C) return JamAI::FJamPlaytestStats();
		if (File.IsEmpty())
		{
			C->Game.Rules.ScoreToWin = 99;
			C->Game.Rules.bPenalties = false;
		}
		Edit(C->Game);
		JamAI::FJamSimAdapter Sim(*C);
		Count.Sim = &Sim;
		JamAI::FJamMatchConfig M = JamAI::ToMatchConfigResolved(*C, Level);
		if (Tune && *Tune)   // lane A138: a profile tune on the brain (JamBaseline::BrainTune() for a pinned-hash neutral arm)
		{
			char Err[200] = {};
			if (!JamAI::ApplyDifficultyTune(Tune, M.AI, Err, sizeof(Err))) T.AddError(FString::Printf(TEXT("profile tune: %s"), ANSI_TO_TCHAR(Err)));
		}
		Count.Human = M.PlayerIndex();
		const JamAI::FJamPlaytestStats Out = JamAI::RunPlaytestMatch(Sim, M, Seed, JamAI::EPlaytester::Regular, Frames, C->Game.Shot.ChargeFramesMax, false, &Trace, &Count, 1);
		if (const UJamSim* End = Sim.GetSim()) { Count.Shove[0] = End->ShieldShoveTally[0]; Count.Shove[1] = End->ShieldShoveTally[1]; }
		return Out;
	}

	FString Line(const TCHAR* Label, const JamAI::FJamPlaytestStats& S, const FContactCount& C)
	{
		return FString::Printf(TEXT("%s: frames %lld hash %016llx goals %d:%d | bump read-outs bot %d human %d | check events by bot %d by human %d | knockdowns of bot %d of human %d (bot on bot %d) | ")
			TEXT("lift presses bot %d human %d | hits taken (bump/stumble/down) bot %d/%d/%d human %d/%d/%d | by cross-check (stumble/down) bot %d/%d human %d/%d | down frames bot %d human %d | recoils bot %d human %d | refused carrying bot %d human %d"),
			Label, static_cast<long long>(S.Frames), static_cast<unsigned long long>(S.Hash), S.GoalsFor, S.GoalsAgainst, C.Bumps[0], C.Bumps[1], C.Checks[0], C.Checks[1], C.Downs[0], C.Downs[1],
			C.BotOnBotDowns, C.Lifts[0], C.Lifts[1], C.HitBump[0], C.HitStumble[0], C.HitDown[0], C.HitBump[1], C.HitStumble[1], C.HitDown[1], C.CrossStumble[0], C.CrossDown[0], C.CrossStumble[1], C.CrossDown[1], C.DownFrames[0], C.DownFrames[1], C.Recoil[0], C.Recoil[1], C.Refused[0], C.Refused[1]);
	}

	// ---- the scenes --------------------------------------------------------------------------------------------------------------------------
	// hockey.regular (speed 11, mass 80, knockdown_frames 90), penalties off unless a scene turns them on; faceoff skipped. A = the human's skater, V = the first
	// skater of the other team; everybody else parked along the side boards, the puck far away.
	struct FContactScene
	{
		UJamSim* Sim = nullptr;
		int32 A = -1, V = -1;
		FJamGameConfig Cfg;
		bool Ok() const { return Sim && A >= 0 && V >= 0; }
		const FJamSkaterState& Att() const { return Sim->GetSkaters()[A]; }
		const FJamSkaterState& Vic() const { return Sim->GetSkaters()[V]; }
	};

	FContactScene Make(FAutomationTestBase& T, TFunctionRef<void(FJamGameConfig&)> Edit)
	{
		FContactScene S;
		TArray<FString> Errors;
		UJamCartridge* C = UJamCartridge::LoadFromFile(UJamCartridge::ResolveCartridgePath(TEXT("hockey.regular")), Errors);
		for (const FString& E : Errors) T.AddError(FString::Printf(TEXT("hockey.regular: %s"), *E));
		if (!C) return S;
		S.Cfg = C->Game;
		S.Cfg.Rules.bPenalties = false;
		// Lane A151: the scenes written before it stage their own rule (the boards, the levers, the figure's calls, the stability table) with a body hit from
		// the side on a STANDING skater, at the brace that hit had then. They keep it: the side brace and the braced bounce are off in a scene unless its Edit
		// sets them (Jam.Core.Contact.StandingSides stages both and asserts the shipped values).
		S.Cfg.Contact.StandSideBrace = 0.0;
		S.Cfg.Contact.bBraceExchange = false;
		// Lane A184: the scenes press and land on the same frame as they were written; the wind-ups (shipped at 4) are off in a scene unless its Edit sets them.
		S.Cfg.Contact.CheckWindupFrames = 0;
		S.Cfg.Contact.CrossWindupFrames = 0;
		S.Cfg.Contact.BotCheckWindupFrames = S.Cfg.Contact.BotCrossWindupFrames = -1;   // lane A200: and the bots' own (absent = the shared value)
		S.Cfg.Contact.CheckPullM = 0.0; S.Cfg.Contact.bCrossAnyMan = false; S.Cfg.Contact.CheckReachM = 0.0;   // lane A209: and the hit that finds its man (Jam.Core.Contact.HitFindsMan sets them)
		Edit(S.Cfg);
		S.Sim = NewObject<UJamSim>();
		S.Sim->Init(S.Cfg, 7);
		S.Sim->SkipFaceoff();
		S.A = S.Sim->GetHumanIndex();
		const int32 Team = S.Sim->GetSkaters()[S.A].Team;
		for (const FJamSkaterState& K : S.Sim->GetSkaters()) if (K.Team != Team) { S.V = K.Index; break; }
		const double Hx = S.Cfg.Rink.LengthM * 0.5 - 4.0, Hz = S.Cfg.Rink.WidthM * 0.5 - 3.0;
		int32 N = 0;
		for (const FJamSkaterState& K : S.Sim->GetSkaters())
		{
			if (K.Index == S.A || K.Index == S.V) continue;
			S.Sim->SetSkater(K.Index, FVector2D(-Hx + 2.5 * N, (N % 2 ? 1.0 : -1.0) * Hz), FVector2D::ZeroVector, 0.0);
			++N;
		}
		S.Sim->SetPuck(FVector2D(-20.0, 12.0), FVector2D::ZeroVector);
		return S;
	}

	struct FContactHit
	{
		int32 Outcome = 0;          // the victim's ContactOutcome on the frame of the hit
		float Ratio = 0.f;
		int32 KnockFrames = 0, StumbleFrames = 0;
		bool bCheck = false, bKnock = false, bLiftClean = false, bRecoil = false, bRefused = false, bWindow = false;
		FName Foul;
		float Strength = 0.f;
		int32 AttStumble = 0;
		double AttSpeedBefore = 0, AttSpeedAfter = 0, VicSpeedBefore = 0, VicSpeedAfter = 0;
		int32 Frame = -1;
	};

	// Steps up to Frames; Fill writes the inputs of frame F. Stops on the frame the victim takes a hit (ContactOutcome != 0), a foul or a knockdown.
	FContactHit Run(FContactScene& S, int32 Frames, TFunctionRef<void(TArray<FJamInput>&, int32)> Fill)
	{
		FContactHit H;
		const int32 N = S.Sim->GetSkaters().Num();
		for (int32 F = 0; F < Frames; ++F)
		{
			TArray<FJamInput> In;
			In.SetNum(N);
			Fill(In, F);
			H.AttSpeedBefore = S.Att().Vel.Size();
			H.VicSpeedBefore = S.Vic().Vel.Size();
			S.Sim->Step(In);
			for (const FJamSimEvent& E : S.Sim->GetFrameEvents())
			{
				if (E.Name == JamEvents::Check && E.Who == S.A) { H.bCheck = true; H.Strength = E.Strength; }
				if (E.Name == JamEvents::Knockdown && E.Who == S.V) H.bKnock = true;
				if (E.Name == JamEvents::Lift && E.Who == S.A && E.Strength > 0.5f) H.bLiftClean = true;
				if (E.Name == FoulEvent && E.Who == S.A) H.Foul = E.Kind;
			}
			H.bRefused |= S.Att().bCheckRefused;
			H.bWindow |= S.Att().CheckWindow > 0 || S.Att().bCheckThisFrame;
			if (S.Vic().ContactOutcome != 0 || H.bKnock || !H.Foul.IsNone())
			{
				H.Outcome = S.Vic().ContactOutcome;
				H.Ratio = S.Vic().ContactRatio;
				H.KnockFrames = S.Vic().KnockFrames;
				H.StumbleFrames = S.Vic().StumbleFrames;
				H.bRecoil = S.Att().bRecoilThisFrame;
				H.AttStumble = S.Att().StumbleFrames;
				H.AttSpeedAfter = S.Att().Vel.Size();
				H.VicSpeedAfter = S.Vic().Vel.Size();
				H.Frame = F;
				return H;
			}
		}
		return H;
	}

	// The victim takes the puck on its blade side and is the carrier (the puck 0.45 m ahead of it, as the acceptance drill hands it).
	bool HandPuck(FContactScene& S, int32 To)
	{
		for (int32 F = 0; F < 40; ++F)
		{
			const FJamSkaterState& K = S.Sim->GetSkaters()[To];
			if (S.Sim->CarrierIndex() == To) return true;
			if (F == 0) S.Sim->SetPuck(K.Pos + K.Forward() * 0.45, K.Vel);
			TArray<FJamInput> In;
			In.SetNum(S.Sim->GetSkaters().Num());
			S.Sim->Step(In);
		}
		return S.Sim->CarrierIndex() == To;
	}
	void Carry(FContactScene& S, int32 Who, const FVector2D& Pos, const FVector2D& Vel, double Yaw)
	{
		S.Sim->SetSkater(Who, Pos, Vel, Yaw);
		S.Sim->SetPuck(Pos + FVector2D(FMath::Cos(Yaw), FMath::Sin(Yaw)) * 0.45, Vel);
	}

	FString Facts(const FContactHit& H)
	{
		return FString::Printf(TEXT("outcome %d ratio %.2f knock %d stumble %d check %d strength %.2f recoil %d att %.2f -> %.2f m/s vic %.2f -> %.2f m/s frame %d"), H.Outcome, H.Ratio, H.KnockFrames,
			H.StumbleFrames, H.bCheck ? 1 : 0, H.Strength, H.bRecoil ? 1 : 0, H.AttSpeedBefore, H.AttSpeedAfter, H.VicSpeedBefore, H.VicSpeedAfter, H.Frame);
	}
	const auto NoEdit = [](FJamGameConfig&) {};

	// Lane A113: the grace part of a match line.
	FString GraceLine(const FContactCount& C)
	{
		return FString::Printf(TEXT("knockdowns of human %d of bot %d | down again within %d frames of release: human %d bot %d (by a hit: human %d bot %d) | stumbled by a hit in that window: human %d bot %d | ")
			TEXT("shortest release-to-down gap %d frames | hits the grace made a bump: on human %d on bot %d (thrown by a bot %d) | landed hits on a skater inside its grace %d | ")
			TEXT("grace at the first release %d | human's own: soft %d missed %d met-a-grace %d"),
			C.Downs[1], C.Downs[0], FContactCount::ReDownWindow, C.ReDown[1], C.ReDown[0], C.ReDownByHit[1], C.ReDownByHit[0], C.ReStumble[1], C.ReStumble[0],
			C.MinGap == 1000000 ? -1 : C.MinGap, C.Graced[1], C.Graced[0], C.GracedByBot, C.ReHitInGrace, C.GraceAtRelease, C.HumanSoft, C.HumanMissed, C.HumanGraced);
	}

	// Lane A101: the board part of a match line.
	FString BoardLine(const FContactCount& C)
	{
		const int32 Hits = C.HitBump[0] + C.HitBump[1] + C.HitStumble[0] + C.HitStumble[1] + C.HitDown[0] + C.HitDown[1];
		const int32 Near = C.NearBoards[0] + C.NearBoards[1];
		FString Bins;
		for (int32 B = 0; B < 2; ++B) Bins += FString::Printf(TEXT(" | %s (bump/stumble/down): into %d/%d/%d glancing %d/%d/%d along-or-away %d/%d/%d"), B == 0 ? TEXT("within 1.5 m") : TEXT("1.5 to 3 m"),
			C.Where[B][0][0], C.Where[B][0][1], C.Where[B][0][2], C.Where[B][1][0], C.Where[B][1][1], C.Where[B][1][2], C.Where[B][2][0], C.Where[B][2][1], C.Where[B][2][2]);
		return FString::Printf(TEXT("hits resolved %d, near the boards (1.5 m) %d = %.1f %% (bot %d human %d) | the boards answered: stumble bot %d human %d, down bot %d human %d | promoted by the bonus: to a stumble bot %d human %d, to a knockdown bot %d human %d | board events (skater) %d"),
			Hits, Near, Hits > 0 ? 100.0 * Near / Hits : 0.0, C.NearBoards[0], C.NearBoards[1], C.BoardStumble[0], C.BoardStumble[1], C.BoardDown[0], C.BoardDown[1],
			C.BoardPromotedStumble[0], C.BoardPromotedStumble[1], C.BoardPromotedDown[0], C.BoardPromotedDown[1], C.BoardEvents) + Bins;
	}
}

using namespace JamContactTests;

// ---- Lane A125 (track F1, docs/experiments/CONTACT-4.md): the figure is told what happened, and the human's check finds its man -----------------------
//   Jam.Core.Contact.ShieldShove     R-0050 point 2: a shield that refuses the stick alone (track F2's body shield or take grace; forced by hand here) never refuses the shove:
//                                    the same MMB press from behind shoves the carrier by the contact law and does not take the puck; the spin refuses both
//   Jam.Core.Contact.FigureCalls     the pawn's two by-name figure calls: PlayStumble(DirX, DirZ, Frames) on a stumble's first frame (a bump keeps
//                                    PlayHitReaction), SetBraking(bOn, Decel) from the sim's reverse brake; a figure without them is not called
//   Jam.Core.Contact.CheckReach      contact.check_reach_m: an open check window turns the velocity toward the nearest opponent in the cone ahead; speed kept,
//                                    no teleport; outside the cone, beyond the reach, standing still and at 0 nothing bends
//   Jam.Core.ContactReachMatch       check_reach_m 0 hashes as the baseline (three pro seeds); six three-minute pro matches by reach: the human's presses,
//                                    whiffs and landed hits, knockdowns of the human and of a bot
namespace JamContactTests
{
	struct FReachCount
	{
		FContactCount Base;
		int32 Presses = 0;      // the human's check presses that opened a window
		// Why a press ran out on nobody, read at the press: the nearest standing opponent was beyond 1 m (body to body), or within it and the two closed at under
		// 3 m/s along the line between them (a chase: the contact law gives such a hit nothing either), or neither (the man got away inside the window).
		int32 WhiffFar = 0, WhiffChase = 0, WhiffOther = 0, SeenMissed = 0;
		double PressGap = 0.0, PressClosing = 0.0;
		// Lane A132: the same, read against the man the playtester presses at: the opposing CARRIER (the nearest man is not always him). By whiff: no opposing
		// carrier on the press frame; the carrier beyond 1 m; within 1 m closing under 3 m/s; 3 to 5 m/s (1 m in the 12-frame window needs 5); faster.
		int32 WhiffNoCarrier = 0, WhiffCarrierFar = 0, WhiffCarrierChase = 0, WhiffCarrierSlow = 0, WhiffCarrierFast = 0, PressCarrierNotNearest = 0;
		double CarrierGap = -1.0, CarrierClosing = 0.0;
		int64 Last = -1;
	};

	void TraceReach(void* Ctx, const JamAI::FJamAIWorld& W, const JamAI::FJamAIInput* In, const JamAI::FJamBrain& B, int64_t F, bool bTouch)
	{
		FReachCount& R = *static_cast<FReachCount*>(Ctx);
		const UJamSim* Sim = R.Base.Sim->GetSim();
		if (Sim && Sim->GetFrame() != R.Last)
		{
			R.Last = Sim->GetFrame();
			if (Sim->GetSkaters().IsValidIndex(R.Base.Human))
			{
				const FJamSkaterState& H = Sim->GetSkaters()[R.Base.Human];
				if (H.bCheckThisFrame)
				{
					++R.Presses;
					R.PressGap = 1e9; R.PressClosing = 0.0;
					for (const FJamSkaterState& O : Sim->GetSkaters())
					{
						if (O.Team == H.Team || O.IsDown() || O.InBox()) continue;
						const FVector2D To = O.Pos - H.Pos;
						const double Gap = To.Size() - 2.0 * UJamSim::SkaterRadius;
						if (Gap < R.PressGap) { R.PressGap = Gap; R.PressClosing = FVector2D::DotProduct(H.Vel - O.Vel, To.GetSafeNormal()); }
					}
					const int32 Ci = Sim->CarrierIndex();
					R.CarrierGap = -1.0; R.CarrierClosing = 0.0;
					if (Sim->GetSkaters().IsValidIndex(Ci) && Sim->GetSkaters()[Ci].Team != H.Team)
					{
						const FVector2D To = Sim->GetSkaters()[Ci].Pos - H.Pos;
						R.CarrierGap = FMath::Max(0.0, To.Size() - 2.0 * UJamSim::SkaterRadius);
						R.CarrierClosing = FVector2D::DotProduct(H.Vel - Sim->GetSkaters()[Ci].Vel, To.GetSafeNormal());
						if (R.CarrierGap > R.PressGap + 1e-6) ++R.PressCarrierNotNearest;
					}
				}
				if (H.ChecksMissed > R.SeenMissed)
				{
					if (R.PressGap > 1.0) ++R.WhiffFar; else if (R.PressClosing < 3.0) ++R.WhiffChase; else ++R.WhiffOther;
					if (R.CarrierGap < 0.0) ++R.WhiffNoCarrier; else if (R.CarrierGap > 1.0) ++R.WhiffCarrierFar; else if (R.CarrierClosing < 3.0) ++R.WhiffCarrierChase;
					else if (R.CarrierClosing < 5.0) ++R.WhiffCarrierSlow; else ++R.WhiffCarrierFast;
				}
				R.SeenMissed = H.ChecksMissed;
			}
		}
		Trace(&R.Base, W, In, B, F, bTouch);
	}

	// Match() with the press counter: hockey.regular at a level, penalties off, no score limit, the Regular playtester as the human.
	JamAI::FJamPlaytestStats MatchReach(FAutomationTestBase& T, const TCHAR* Level, uint64 Seed, FReachCount& R, TFunctionRef<void(FJamGameConfig&)> Edit, int64 Frames = 10800, const char* Tune = nullptr)
	{
		TArray<FString> Errors;
		UJamCartridge* C = UJamCartridge::LoadFromFile(UJamCartridge::ResolveCartridgePath(TEXT("hockey.regular")), Errors);
		for (const FString& E : Errors) T.AddError(FString::Printf(TEXT("hockey.regular: %s"), *E));
		if (!C) return JamAI::FJamPlaytestStats();
		C->Game.Rules.ScoreToWin = 99;
		C->Game.Rules.bPenalties = false;
		Edit(C->Game);
		JamAI::FJamSimAdapter Sim(*C);
		R.Base.Sim = &Sim;
		JamAI::FJamMatchConfig M = JamAI::ToMatchConfigResolved(*C, Level);
		if (Tune && *Tune)   // lane A138: as Match()
		{
			char Err[200] = {};
			if (!JamAI::ApplyDifficultyTune(Tune, M.AI, Err, sizeof(Err))) T.AddError(FString::Printf(TEXT("profile tune: %s"), ANSI_TO_TCHAR(Err)));
		}
		R.Base.Human = M.PlayerIndex();
		const JamAI::FJamPlaytestStats Out = JamAI::RunPlaytestMatch(Sim, M, Seed, JamAI::EPlaytester::Regular, Frames, C->Game.Shot.ChargeFramesMax, false, &TraceReach, &R, 1);
		if (const UJamSim* End = Sim.GetSim()) { R.Base.Shove[0] = End->ShieldShoveTally[0]; R.Base.Shove[1] = End->ShieldShoveTally[1]; }
		return Out;
	}
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamContactShieldShove, "Jam.Core.Contact.ShieldShove", JamContactTests::Flags)
bool FJamContactShieldShove::RunTest(const FString& Parameters)
{
	// The standing carrier at the centre dot facing +x, the puck in front of it. The attacker presses the lift (MMB) at arm's length (a gap of 0.4 m).
	struct FOut { FContactHit H; double Expect = 0.0; bool bPuckKept = false, bStickHit = false, bOk = false; int32 SpinFrames = 0; };
	// MatchMps (lane A138): contact.ShoveBehindMatchMps for the scene; below 0 = the default (3: on a back the thrust lands by the closing speed).
	auto Scene = [this](const TCHAR* Name, const FVector2D& From, double Speed, bool bStickRefused, bool bSpin, bool bPenalties, double MatchMps = -1.0) -> FOut
	{
		FOut O;
		FContactScene S = Make(*this, [bPenalties, MatchMps](FJamGameConfig& G) { G.Rules.bPenalties = bPenalties; if (MatchMps >= 0.0) G.Contact.ShoveBehindMatchMps = MatchMps; });
		if (!S.Ok()) return O;
		S.Sim->SetSkater(S.V, FVector2D::ZeroVector, FVector2D::ZeroVector, 0.0);
		S.Sim->SetSkater(S.A, FVector2D(-10.0, -10.0), FVector2D::ZeroVector, 0.0);
		if (!TestTrue(*FString::Printf(TEXT("%s: the standing skater carries the puck"), Name), HandPuck(S, S.V))) return O;
		Carry(S, S.V, FVector2D::ZeroVector, FVector2D::ZeroVector, 0.0);
		const FVector2D Dir = -From.GetSafeNormal();
		S.Sim->SetSkater(S.A, From, Dir * Speed, FMath::Atan2(Dir.Y, Dir.X));
		S.Sim->bTestStickRefused = bStickRefused;
		const int32 Press = bSpin ? 1 : 0;
		if (!bSpin) O.Expect = S.Sim->ContactImpulse(S.Att(), S.Vic(), Dir, UJamSim::EContactKind::Cross) / S.Sim->StabilityOf(S.Vic(), Dir, UJamSim::EContactKind::Cross);
		O.H = Run(S, Press + 1, [&](TArray<FJamInput>& In, int32 F) { In[S.V].bSpin = bSpin && F == 0; In[S.A].bLift = F == Press; });
		O.SpinFrames = S.Vic().SpinFrames;
		O.bPuckKept = S.Sim->GetPuck().LastTouch == S.V;
		O.bStickHit = S.Vic().StickHitResult != 0;
		O.bOk = true;
		AddInfo(FString::Printf(TEXT("JAMSHOVE %s: %s | expected ratio by the law %.3f | lift clean %d, puck still the carrier's %d, stick-hit read-out %d, foul %s, spin frames %d"), Name, *Facts(O.H), O.Expect,
			O.H.bLiftClean ? 1 : 0, O.bPuckKept ? 1 : 0, O.bStickHit ? 1 : 0, *O.H.Foul.ToString(), O.SpinFrames));
		return O;
	};
	const FVector2D Behind(-1.2, 0.0), Side(0.0, -1.2);
	// 1. From behind, the body between (the shield refuses the stick), the attacker standing. Lane A138 (R-0053 point 3): a push in the back at matched speed
	//    is a bump: on a back the thrust lands only as far as the attacker is closing (UJamSim::CrossThrust), and here it is not closing at all.
	{
		const FOut O = Scene(TEXT("from behind, body between, attacker standing"), Behind, 0.0, true, false, false);
		if (!O.bOk) return false;
		TestEqual(TEXT("behind, shielded, matched speed: the press is a bump (R-0053 point 3)"), O.H.Outcome, UJamSim::ContactBump);
		TestEqual(TEXT("... with the ratio the contact law gives (no closing speed, no thrust: 0)"), static_cast<double>(O.H.Ratio), O.Expect, 1e-4);
		TestTrue(*FString::Printf(TEXT("... the ratio is 0 (%.3f), the carrier keeps its feet and the puck"), O.H.Ratio), O.H.Ratio < 1e-4f && O.bPuckKept && !O.H.bCheck && !O.H.bKnock);
		TestTrue(TEXT("... and the lift takes nothing (no clean lift, no stick-hit read-out)"), !O.H.bLiftClean && !O.bStickHit);
		// Closing at half the matching speed (1.5 of 3 m/s): half the thrust on top of the closing speed: (1.5 + 1.5) x 80 on an unbraced 384 = 0.625, a stumble.
		const FOut Half = Scene(TEXT("from behind, body between, attacker closing at 1.5 m/s"), Behind, 1.5, true, false, false);
		if (!Half.bOk) return false;
		TestEqual(TEXT("behind, shielded, closing at 1.5 m/s: a stumble"), Half.H.Outcome, UJamSim::ContactStumble);
		TestEqual(TEXT("... with the ratio the contact law gives"), static_cast<double>(Half.H.Ratio), Half.Expect, 1e-4);
		TestTrue(*FString::Printf(TEXT("... which is (1.5 + half the thrust) x mass on the unbraced back (%.3f)"), Half.H.Ratio), FMath::Abs(Half.H.Ratio - 0.625f) < 0.01f);
		// The neutral value (ShoveBehindMatchMps 0): the whole thrust from behind, lane A125's shove: a stumble of 0.625 from a standing attacker.
		const FOut Old = Scene(TEXT("from behind, body between, attacker standing, ShoveBehindMatchMps 0 (lane A125's rule)"), Behind, 0.0, true, false, false, 0.0);
		if (!Old.bOk) return false;
		TestEqual(TEXT("behind, shielded, the neutral value: the standing attacker's thrust alone stumbles the carrier (thrust 3 m/s x 80 kg on an unbraced 384)"), Old.H.Outcome, UJamSim::ContactStumble);
		TestTrue(*FString::Printf(TEXT("... under loose_ratio (%.2f), so the puck stays the carrier's"), Old.H.Ratio), FMath::Abs(Old.H.Ratio - 0.625f) < 0.01f && Old.bPuckKept);
	}
	// 2. The same press at 8 m/s: down by the law; the puck leaves by the knockdown, not by the lift.
	{
		const FOut O = Scene(TEXT("from behind, body between, attacker at 8 m/s"), Behind, 8.0, true, false, false);
		if (!O.bOk) return false;
		TestEqual(TEXT("behind, shielded, 8 m/s: down"), O.H.Outcome, UJamSim::ContactDown);
		TestEqual(TEXT("... with the ratio the contact law gives"), static_cast<double>(O.H.Ratio), O.Expect, 1e-4);
		TestTrue(TEXT("... with the check and knockdown events, and still no clean lift"), O.H.bCheck && O.H.bKnock && !O.H.bLiftClean && !O.bStickHit);
	}
	// 3. With the whistle: a shove from behind that lands is the foul it always was (the contact law's own rule; nothing new). Lane A138: it lands when the
	//    attacker closes (4 m/s here); the push at matched speed is a bump and no foul.
	{
		const FOut O = Scene(TEXT("from behind, body between, attacker at 4 m/s, penalties on"), Behind, 4.0, true, false, true);
		if (!O.bOk) return false;
		TestTrue(TEXT("behind, shielded, closing, penalties on: the shove lands and the from-behind foul is called"), O.H.Outcome >= UJamSim::ContactStumble && !O.H.Foul.IsNone());
		const FOut Still = Scene(TEXT("from behind, body between, attacker standing, penalties on"), Behind, 0.0, true, false, true);
		if (!Still.bOk) return false;
		TestTrue(TEXT("behind, shielded, matched speed, penalties on: a bump, no foul"), Still.H.Outcome == UJamSim::ContactBump && Still.H.Foul.IsNone());
	}
	// 4. From the side, the body between: the shove lands as before, the lift takes nothing (without the shield it took the puck: StandingBrace case 3).
	{
		const FOut O = Scene(TEXT("from the side, body between, 2 m/s"), Side, 2.0, true, false, false);
		if (!O.bOk) return false;
		TestEqual(TEXT("side, shielded: the brace holds, a stumble"), O.H.Outcome, UJamSim::ContactStumble);
		TestEqual(TEXT("... with the ratio the contact law gives"), static_cast<double>(O.H.Ratio), O.Expect, 1e-4);
		TestTrue(TEXT("... and the puck is not taken"), !O.H.bLiftClean && !O.bStickHit && O.bPuckKept);
		const FOut N = Scene(TEXT("from the side, no shield, 2 m/s"), Side, 2.0, false, false, false);
		if (!N.bOk) return false;
		TestEqual(TEXT("side, the seam off: the same shove (the shield never changes the shove)"), static_cast<double>(N.H.Ratio), static_cast<double>(O.H.Ratio), 1e-6);
	}
	// 4b. From the front, the stick refused and no body between (the shape of track F2's take grace: the carrier has just won the puck and faces the
	//     attacker): the shove lands by the law (the thrust ignores the standing brace), the lift takes nothing.
	{
		const FOut O = Scene(TEXT("from the front, stick refused (a take grace), attacker standing"), FVector2D(1.2, 0.0), 0.0, true, false, false);
		if (!O.bOk) return false;
		TestEqual(TEXT("front, stick refused: the press shoves the carrier (a stumble: 240 on an unbraced 480)"), O.H.Outcome, UJamSim::ContactStumble);
		TestEqual(TEXT("... with the ratio the contact law gives"), static_cast<double>(O.H.Ratio), O.Expect, 1e-4);
		TestTrue(TEXT("... and the puck is not taken"), !O.H.bLiftClean && !O.bStickHit && O.bPuckKept);
		const FOut N = Scene(TEXT("from the front, no shield, attacker standing"), FVector2D(1.2, 0.0), 0.0, false, false, false);
		if (!N.bOk) return false;
		TestEqual(TEXT("front, the seam off: the same shove (a stick shield never changes the shove)"), static_cast<double>(N.H.Ratio), static_cast<double>(O.H.Ratio), 1e-6);
	}
	// 5. The spin refuses both, shield or not (R-0040's bar stands).
	{
		const FOut O = Scene(TEXT("from behind, body between, the carrier spins"), Behind, 0.0, true, true, false);
		if (!O.bOk) return false;
		TestTrue(TEXT("the carrier is spinning when the press comes"), O.SpinFrames > 0);
		TestTrue(TEXT("spinning: no shove and no clean lift"), O.H.Outcome == 0 && !O.H.bCheck && !O.H.bLiftClean);
	}
	// 6. The seam off, from behind. A tree without a stick-only shield: the stick lift it was (no shove, the puck lifted; the game before the lane). A tree with
	//    track F2's body shield (game.stick.body_shield, default true): the shield is real here (the puck is on the far side of the body, the carrier's back
	//    is turned): the shove lands and the puck is not taken. Either is right; anything else is not.
	{
		const FOut O = Scene(TEXT("from behind, the seam off"), Behind, 0.0, false, false, false);
		if (!O.bOk) return false;
		const bool bLiftOnly = O.H.Outcome == 0 && O.H.bLiftClean;
		const bool bShoveOnly = O.H.Outcome >= UJamSim::ContactBump && !O.H.bLiftClean && FMath::IsNearlyEqual(static_cast<double>(O.H.Ratio), O.Expect, 1e-4);   // lane A138: at matched speed the shove on a back resolves as a bump
		AddInfo(FString::Printf(TEXT("JAMSHOVE the seam off from behind: %s"), bLiftOnly ? TEXT("a stick lift, no shove (this tree has no stick-only shield)") : bShoveOnly ? TEXT("a shove, the puck not taken (the tree's own body shield refused the stick)") : TEXT("NEITHER")));
		TestTrue(TEXT("the seam off, from behind: a stick lift and no shove (no body shield), or a shove and no take (the tree's body shield)"), bLiftOnly != bShoveOnly);
	}
	// 7. Lane A138 (R-0053 point 5): the rule's own neutral value. contact.bShieldShove false (no key; JamBaseline.h) is main's refusal before lane A125: what
	//    refuses the lift refuses the shove too, from any side and at any speed.
	{
		struct FCase { const TCHAR* Name; FVector2D From; double Speed; };
		for (const FCase& K : { FCase{ TEXT("from behind at 8 m/s"), Behind, 8.0 }, FCase{ TEXT("from the side at 2 m/s"), Side, 2.0 }, FCase{ TEXT("from the front, standing"), FVector2D(1.2, 0.0), 0.0 } })
		{
			FContactScene S = Make(*this, [](FJamGameConfig& G) { G.Contact.bShieldShove = false; });
			if (!S.Ok()) return false;
			S.Sim->SetSkater(S.V, FVector2D::ZeroVector, FVector2D::ZeroVector, 0.0);
			S.Sim->SetSkater(S.A, FVector2D(-10.0, -10.0), FVector2D::ZeroVector, 0.0);
			if (!TestTrue(*FString::Printf(TEXT("bShieldShove false, %s: the standing skater carries the puck"), K.Name), HandPuck(S, S.V))) return false;
			Carry(S, S.V, FVector2D::ZeroVector, FVector2D::ZeroVector, 0.0);
			const FVector2D Dir = -K.From.GetSafeNormal();
			S.Sim->SetSkater(S.A, K.From, Dir * K.Speed, FMath::Atan2(Dir.Y, Dir.X));
			S.Sim->bTestStickRefused = true;
			const FContactHit H = Run(S, 1, [&](TArray<FJamInput>& In, int32 F) { In[S.A].bLift = F == 0; });
			AddInfo(FString::Printf(TEXT("JAMSHOVE bShieldShove false, the stick refused, %s: %s"), K.Name, *Facts(H)));
			TestTrue(*FString::Printf(TEXT("bShieldShove false, %s: the refused lift is no shove (no contact from the press, no check event) and no take"), K.Name), H.Outcome == 0 && !H.bCheck && !H.bLiftClean && S.Sim->GetPuck().LastTouch == S.V);
		}
	}
	return true;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamContactFigureCalls, "Jam.Core.Contact.FigureCalls", JamContactTests::Flags)
bool FJamContactFigureCalls::RunTest(const FString& Parameters)
{
	// 1. The by-name call: a figure that has the function is called with the numbers written by each parameter's own type; one that has not is not.
	{
		UJamFigureCallProbe* P = NewObject<UJamFigureCallProbe>();
		TestTrue(TEXT("PlayStumble by name on a figure that has it (double, double, int32: a Blueprint event's shape)"), AJamSkater::CallFigure(P, TEXT("PlayStumble"), { 0.6, -0.8, 16.0 }));
		TestTrue(*FString::Printf(TEXT("... it received (%.2f, %.2f, %d)"), P->LastDirX, P->LastDirZ, P->LastFrames), P->Stumbles == 1 && FMath::IsNearlyEqual(P->LastDirX, 0.6, 1e-9) && FMath::IsNearlyEqual(P->LastDirZ, -0.8, 1e-9) && P->LastFrames == 16);
		TestTrue(TEXT("SetBraking by name (bool, float)"), AJamSkater::CallFigure(P, TEXT("SetBraking"), { 1.0, 20.0 }));
		TestTrue(*FString::Printf(TEXT("... it received (%d, %.1f)"), P->bLastOn ? 1 : 0, P->LastDecel), P->Brakes == 1 && P->bLastOn && FMath::IsNearlyEqual(P->LastDecel, 20.f, 1e-4f));
		TestTrue(TEXT("SetBraking(false, 0)"), AJamSkater::CallFigure(P, TEXT("SetBraking"), { 0.0, 0.0 }) && P->Brakes == 2 && !P->bLastOn && P->LastDecel == 0.f);
		TestFalse(TEXT("a function of the name with another parameter count is not called"), AJamSkater::CallFigure(P, TEXT("PlayStumble"), { 0.6, -0.8 }));
		TestFalse(TEXT("a function whose parameter is not a number is not called"), AJamSkater::CallFigure(P, TEXT("PlayWrongShape"), { 1.0 }));
		TestFalse(TEXT("a figure without the function is not called (PlayStumble falls back to PlayHitReaction in the pawn)"), AJamSkater::CallFigure(NewObject<UJamSim>(), TEXT("PlayStumble"), { 0.6, -0.8, 16.0 }));
		TestFalse(TEXT("no figure"), AJamSkater::CallFigure(nullptr, TEXT("PlayStumble"), { 0.6, -0.8, 16.0 }));
		TestEqual(TEXT("the probe was called once for the stumble"), P->Stumbles, 1);
	}
	// 2. The stumble's frames, read from the sim on the frame of the hit. A side body check from 4 m/s on a standing skater: a stumble, the full stagger.
	{
		FContactScene S = Make(*this, NoEdit);
		if (!S.Ok()) return false;
		S.Sim->SetSkater(S.V, FVector2D::ZeroVector, FVector2D::ZeroVector, 0.0);
		S.Sim->SetSkater(S.A, FVector2D(0.0, -1.0), FVector2D(0.0, 4.0), PI * 0.5);
		const FContactHit H = Run(S, 12, [&](TArray<FJamInput>& In, int32 F) { In[S.A].bCheck = F == 0; });
		AddInfo(FString::Printf(TEXT("JAMFIG body-check stumble: %s | victim frames for PlayStumble %d, attacker %d, push (%.2f, %.2f)"), *Facts(H), AJamSkater::StumbleFramesFor(S.Vic()), AJamSkater::StumbleFramesFor(S.Att()), S.Vic().BumpDir.X, S.Vic().BumpDir.Y));
		TestEqual(TEXT("a body-check stumble"), H.Outcome, UJamSim::ContactStumble);
		TestEqual(TEXT("... PlayStumble's frames are the sim's stagger_frames (the contact resolves after the skaters moved)"), AJamSkater::StumbleFramesFor(S.Vic()), S.Cfg.Contact.StaggerFrames);
		TestEqual(TEXT("... the attacker did not stumble: no PlayStumble for it"), AJamSkater::StumbleFramesFor(S.Att()), 0);
		TestTrue(TEXT("... the push is the attacker's way (+z)"), S.Vic().BumpDir.Y > 0.9);
		// the frames are exactly the frames without control: the skater can act again after that many steps
		int32 Held = 0;
		for (; Held < 40 && !S.Vic().CanAct(); ++Held) { TArray<FJamInput> In; In.SetNum(S.Sim->GetSkaters().Num()); S.Sim->Step(In); }
		TestEqual(TEXT("... and the sim gives the control back after exactly that many frames"), Held, S.Cfg.Contact.StaggerFrames);
		TestEqual(TEXT("... no PlayStumble on a later frame of the same stumble"), AJamSkater::StumbleFramesFor(S.Vic()), 0);
	}
	// 3. A cross-check's stumble resolves before the skaters move: one frame of it is already spent when the pawn reads it.
	{
		FContactScene S = Make(*this, NoEdit);
		if (!S.Ok()) return false;
		S.Sim->SetSkater(S.V, FVector2D::ZeroVector, FVector2D::ZeroVector, 0.0);
		S.Sim->SetSkater(S.A, FVector2D(-10.0, -10.0), FVector2D::ZeroVector, 0.0);
		TestTrue(TEXT("the standing skater carries the puck"), HandPuck(S, S.V));
		Carry(S, S.V, FVector2D::ZeroVector, FVector2D::ZeroVector, 0.0);
		S.Sim->SetSkater(S.A, FVector2D(0.0, -1.2), FVector2D(0.0, 4.0), PI * 0.5);
		const FContactHit H = Run(S, 6, [&](TArray<FJamInput>& In, int32 F) { In[S.A].bLift = F == 0; });
		TestEqual(TEXT("a cross-check stumble"), H.Outcome, UJamSim::ContactStumble);
		TestEqual(TEXT("... PlayStumble's frames: stagger_frames less the frame already stepped"), AJamSkater::StumbleFramesFor(S.Vic()), S.Cfg.Contact.StaggerFrames - 1);
		int32 Held = 0;
		for (; Held < 40 && !S.Vic().CanAct(); ++Held) { TArray<FJamInput> In; In.SetNum(S.Sim->GetSkaters().Num()); S.Sim->Step(In); }
		TestEqual(TEXT("... and the control is back after exactly that many frames"), Held, S.Cfg.Contact.StaggerFrames - 1);
	}
	// 4. A bump is not a stumble; a knockdown is not a stumble; the attacker's own bounce is one.
	{
		FContactScene S = Make(*this, NoEdit);
		if (!S.Ok()) return false;
		S.Sim->SetSkater(S.V, FVector2D::ZeroVector, FVector2D(8.0, 0.0), 0.0);
		S.Sim->SetSkater(S.A, FVector2D(-0.79, 0.0), FVector2D(8.0, 0.0), 0.0);
		const FContactHit H = Run(S, 12, [&](TArray<FJamInput>& In, int32 F) { In[S.A].bCheck = F == 0; In[S.A].Move = FVector2D(1.0, 0.0); In[S.V].Move = FVector2D(1.0, 0.0); });
		AddInfo(FString::Printf(TEXT("JAMFIG same-way bump: %s"), *Facts(H)));
		TestEqual(TEXT("two skaters going the same way: a bump"), H.Outcome, UJamSim::ContactBump);
		TestEqual(TEXT("... a bump keeps PlayHitReaction: no PlayStumble frames"), AJamSkater::StumbleFramesFor(S.Vic()), 0);
	}
	{
		FContactScene S = Make(*this, NoEdit);
		if (!S.Ok()) return false;
		S.Sim->SetSkater(S.V, FVector2D(1.5, 0.0), FVector2D(-11.0, 0.0), PI);
		S.Sim->SetSkater(S.A, FVector2D(-1.5, 0.0), FVector2D(11.0, 0.0), 0.0);
		const FContactHit H = Run(S, 12, [&](TArray<FJamInput>& In, int32 F) { In[S.A].bCheck = F == 0; });
		TestEqual(TEXT("head-on at full speed: down"), H.Outcome, UJamSim::ContactDown);
		TestEqual(TEXT("... a knockdown is SetKnockedDown's: no PlayStumble frames"), AJamSkater::StumbleFramesFor(S.Vic()), 0);
	}
	{
		// The scene of Jam.Core.Contact.AttackerBounces: a sprinting attacker into a braced standing skater's side is the one who stumbles.
		FContactScene S = Make(*this, NoEdit);
		if (!S.Ok()) return false;
		S.Sim->SetSkater(S.V, FVector2D::ZeroVector, FVector2D::ZeroVector, 0.0);
		S.Sim->SetSkater(S.A, FVector2D(0.0, -1.2), FVector2D(0.0, 5.0), PI * 0.5);
		const FContactHit H = Run(S, 14, [&](TArray<FJamInput>& In, int32 F) { In[S.A].Move = FVector2D(0.0, 1.0); In[S.A].bSprint = true; In[S.A].bCheck = F == 1; });
		AddInfo(FString::Printf(TEXT("JAMFIG the attacker's bounce: %s | attacker's PlayStumble frames %d, push (%.2f, %.2f); victim's %d"), *Facts(H), AJamSkater::StumbleFramesFor(S.Att()), S.Att().BumpDir.X, S.Att().BumpDir.Y,
			AJamSkater::StumbleFramesFor(S.Vic())));
		TestTrue(TEXT("the sprinting attacker bounces off the braced skater"), H.bRecoil);
		TestEqual(TEXT("... its own bounce is a stumble: PlayStumble with the stagger"), AJamSkater::StumbleFramesFor(S.Att()), S.Cfg.Contact.StaggerFrames);
		TestTrue(TEXT("... pushed back against its travel (-z)"), S.Att().BumpDir.Y < -0.9);
	}
	// 5. The braking read-out: the sim's reverse brake, and the deceleration it applied.
	{
		FContactScene S = Make(*this, NoEdit);
		if (!S.Ok()) return false;
		S.Sim->SetSkater(S.A, FVector2D(-5.0, 0.0), FVector2D(10.0, 0.0), 0.0);
		double Before = S.Att().Vel.Size();
		int32 OnFrames = 0, First = -1;
		float FirstDecel = 0.f, MinDecel = 1e9f, MaxDecel = 0.f;
		bool bZeroWhenOff = true;
		for (int32 F = 0; F < 60; ++F)
		{
			TArray<FJamInput> In;
			In.SetNum(S.Sim->GetSkaters().Num());
			In[S.A].Move = FVector2D(F < 5 ? 1.0 : -1.0, 0.0);   // five frames forward, then the input reversed
			S.Sim->Step(In);
			const float D = AJamSkater::BrakeDecelFor(Before, S.Att());
			if (S.Att().bReverseBraking)
			{
				++OnFrames;
				if (First < 0) { First = F; FirstDecel = D; }
				MinDecel = FMath::Min(MinDecel, D); MaxDecel = FMath::Max(MaxDecel, D);
			}
			else if (D != 0.f) bZeroWhenOff = false;
			Before = S.Att().Vel.Size();
		}
		AddInfo(FString::Printf(TEXT("JAMFIG brake: on from frame %d for %d frames, Decel first %.2f min %.2f max %.2f m/s^2 (skater.reverse_brake_decel %.1f)"), First, OnFrames, FirstDecel, MinDecel, MaxDecel, S.Cfg.Skater.ReverseBrakeDecel));
		TestEqual(TEXT("the level rises on the first frame of the reversed input"), First, 5);
		TestTrue(TEXT("... Decel is 0 on every frame the sim does not brake"), bZeroWhenOff);
		TestTrue(TEXT("... and holds for the stop (about speed / decel seconds)"), OnFrames >= 20 && OnFrames <= 35);
		TestEqual(TEXT("... Decel on its first frame is the sim's reverse_brake_decel"), static_cast<double>(FirstDecel), S.Cfg.Skater.ReverseBrakeDecel, 0.01);
		TestTrue(TEXT("... and on every frame of it"), FMath::IsNearlyEqual(static_cast<double>(MinDecel), S.Cfg.Skater.ReverseBrakeDecel, 0.01) && FMath::IsNearlyEqual(static_cast<double>(MaxDecel), S.Cfg.Skater.ReverseBrakeDecel, 0.01));
	}
	return true;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamContactCheckReach, "Jam.Core.Contact.CheckReach", JamContactTests::Flags)
bool FJamContactCheckReach::RunTest(const FString& Parameters)
{
	// The attacker skates +x at Speed; the victim stands Ahead metres ahead and Off metres to its left. A straight line passes it when Off is over two radii (0.8 m).
	struct FOut { FContactHit H; int32 Missed = 0, Target = -2; double SpeedAtPress = 0, SpeedAfterPress = 0, MaxExcess = 0, Turn = 0; bool bOk = false; };
	auto Scene = [this](const TCHAR* Name, double Reach, double Speed, double Ahead, double Off, bool bCarrier = false) -> FOut
	{
		FOut O;
		FContactScene S = Make(*this, [Reach](FJamGameConfig& G) { G.Contact.CheckReachM = Reach; });
		if (!S.Ok()) return O;
		S.Sim->SetSkater(S.V, FVector2D(Ahead, Off), FVector2D::ZeroVector, PI);
		S.Sim->SetSkater(S.A, FVector2D::ZeroVector, FVector2D(Speed, 0.0), 0.0);
		if (bCarrier)
		{
			S.Sim->SetSkater(S.V, FVector2D(30.0, 10.0), FVector2D::ZeroVector, PI);
			if (!TestTrue(*FString::Printf(TEXT("%s: the attacker carries the puck"), Name), HandPuck(S, S.A))) return O;
			S.Sim->SetSkater(S.V, FVector2D(S.Att().Pos.X + Ahead, S.Att().Pos.Y + Off), FVector2D::ZeroVector, PI);
		}
		O.Target = S.Sim->CheckReachTarget(S.Att());
		O.SpeedAtPress = S.Att().Vel.Size();
		FVector2D Prev = S.Att().Pos;
		const FVector2D Vel0 = S.Att().Vel;
		O.H = Run(S, 14, [&](TArray<FJamInput>& In, int32 F)
		{
			if (F > 0) O.MaxExcess = FMath::Max(O.MaxExcess, FVector2D::Distance(Prev, S.Att().Pos) - S.Att().Vel.Size() * UJamSim::DT);   // a step is the velocity x one frame, never more
			if (F == 1)
			{
				O.SpeedAfterPress = S.Att().Vel.Size();
				O.Turn = FMath::RadiansToDegrees(FMath::Acos(FMath::Clamp(FVector2D::DotProduct(S.Att().Vel.GetSafeNormal(), Vel0.GetSafeNormal()), -1.0, 1.0)));
			}
			Prev = S.Att().Pos;
			In[S.A].bCheck = F == 0;
			In[S.A].Move = Speed > 0.0 ? FVector2D(1.0, 0.0) : FVector2D::ZeroVector;
		});
		O.Missed = S.Att().ChecksMissed;
		O.bOk = true;
		AddInfo(FString::Printf(TEXT("JAMREACH %s (reach %.1f, %.1f m/s, man %.1f m ahead %.1f m aside): target %d | %s | missed %d | speed at the press %.2f, a frame later %.2f, turned %.1f deg, a step beyond velocity x frame by at most %.6f m"), Name, Reach, Speed, Ahead, Off,
			O.Target, *Facts(O.H), O.Missed, O.SpeedAtPress, O.SpeedAfterPress, O.Turn, O.MaxExcess));
		return O;
	};
	// 1. The man 1.3 m ahead and 1.1 m aside (a body-to-body gap of 0.9 m, 40 degrees off the facing), the attacker at 8 m/s.
	const FOut Off = Scene(TEXT("reach 0"), 0.0, 8.0, 1.3, 1.1);
	const FOut On = Scene(TEXT("reach 1"), 1.0, 8.0, 1.3, 1.1);
	if (!Off.bOk || !On.bOk) return false;
	TestTrue(TEXT("reach 0: the press runs out on nobody (the whiff), no target"), Off.H.Outcome == 0 && Off.Missed == 1 && Off.Target == -1);
	TestTrue(TEXT("reach 1: the press finds the man"), On.H.Outcome != 0 && On.Missed == 0 && On.Target >= 0);
	TestTrue(*FString::Printf(TEXT("reach 1: the press bends the direction (%.1f deg) ..."), On.Turn), On.Turn > 20.0);
	TestTrue(*FString::Printf(TEXT("... and adds no speed: a frame after the press %.2f m/s, the same press without the reach %.2f m/s"), On.SpeedAfterPress, Off.SpeedAfterPress), On.SpeedAfterPress <= Off.SpeedAfterPress + 1e-6);
	TestTrue(*FString::Printf(TEXT("... and never moves the skater but by its velocity (excess %.6f m)"), On.MaxExcess), On.MaxExcess < 1e-6);
	// The hit is the contact law's: the same closing speed head-on gives the same ratio.
	{
		const FOut Straight = Scene(TEXT("reach 0, straight at the man"), 0.0, 8.0, 1.7, 0.0);
		if (!Straight.bOk) return false;
		TestTrue(*FString::Printf(TEXT("the bent press hits no harder than the same speed straight on (ratio %.2f against %.2f)"), On.H.Ratio, Straight.H.Ratio), On.H.Ratio <= Straight.H.Ratio + 0.05f);
	}
	// 2. Outside the cone (the man beside the attacker, 80 degrees off the facing): nothing bends.
	{
		const FOut O = Scene(TEXT("reach 1, the man beside"), 1.0, 8.0, 0.25, 1.4);
		if (!O.bOk) return false;
		TestTrue(TEXT("outside the cone: no target, the press is a whiff"), O.Target == -1 && O.H.Outcome == 0 && O.Missed == 1);
	}
	// 3. Beyond the reach (a gap of 1.4 m): nothing bends.
	{
		const FOut O = Scene(TEXT("reach 1, the man beyond it"), 1.0, 2.0, 1.7, 1.4);
		if (!O.bOk) return false;
		TestTrue(TEXT("beyond the reach: no target, a whiff"), O.Target == -1 && O.H.Outcome == 0 && O.Missed == 1);
	}
	// 4. Standing still: the reach adds no speed, so the press goes nowhere.
	{
		const FOut O = Scene(TEXT("reach 1, standing still"), 1.0, 0.0, 1.3, 1.1);
		if (!O.bOk) return false;
		TestTrue(*FString::Printf(TEXT("standing still: a target, no speed made of it (%.3f m/s a frame later), a whiff"), O.SpeedAfterPress), O.Target >= 0 && O.SpeedAfterPress < 1e-6 && O.H.Outcome == 0 && O.Missed == 1);
	}
	// 5. The carrier's press is refused: nothing bends.
	{
		const FOut O = Scene(TEXT("reach 1, the attacker carries the puck"), 1.0, 0.0, 1.3, 1.1, true);
		if (!O.bOk) return false;
		TestTrue(TEXT("the carrier: refused, no hit"), O.H.bRefused && O.H.Outcome == 0);
	}
	// 6. A man crossing the attacker's path is led, not chased: the velocity takes his speed across the line between them, so the press turns to where he will be.
	// 7. A bot's press does not bend (the brain aims its own check): the same scene with the bot as the checker finds no target.
	{
		FContactScene S = Make(*this, [](FJamGameConfig& G) { G.Contact.CheckReachM = 1.0; });
		if (!S.Ok()) return false;
		S.Sim->SetSkater(S.V, FVector2D(1.5, -0.6), FVector2D(0.0, 4.0), PI * 0.5);   // 22 degrees to the attacker's right, skating to its left at 4 m/s
		S.Sim->SetSkater(S.A, FVector2D::ZeroVector, FVector2D(8.0, 0.0), 0.0);
		TestTrue(TEXT("the crossing man is the target"), S.Sim->CheckReachTarget(S.Att()) == S.V);
		TestEqual(TEXT("a bot has no target (the reach is the human's)"), S.Sim->CheckReachTarget(S.Vic()), -1);
		TArray<FJamInput> In;
		In.SetNum(S.Sim->GetSkaters().Num());
		In[S.A].bCheck = true;
		In[S.A].Move = FVector2D(1.0, 0.0);
		In[S.V].bCheck = true;
		const FVector2D VicBefore = S.Vic().Vel;
		S.Sim->Step(In);
		AddInfo(FString::Printf(TEXT("JAMREACH a crossing man (1.5 m ahead, 0.6 m to the right, crossing to the left at 4 m/s): the attacker's velocity a frame after the press (%.2f, %.2f), %.2f m/s; the bot's (%.2f, %.2f)"),
			S.Att().Vel.X, S.Att().Vel.Y, S.Att().Vel.Size(), S.Vic().Vel.X, S.Vic().Vel.Y));
		TestTrue(*FString::Printf(TEXT("the press leads the man: the velocity turns to the left, where he is going (vz %.2f), though he is still on the right"), S.Att().Vel.Y), S.Att().Vel.Y > 0.5);
		TestTrue(*FString::Printf(TEXT("... at the speed it had (%.2f m/s)"), S.Att().Vel.Size()), S.Att().Vel.Size() < 8.25);
		TestTrue(TEXT("the bot's own press bends nothing: it keeps its line"), FMath::Abs(S.Vic().Vel.X - VicBefore.X) < 0.3 && S.Vic().Vel.Y > 3.0);
	}
	// The default.
	{
		TArray<FString> Errors;
		const UJamCartridge* C = UJamCartridge::LoadFromFile(UJamCartridge::ResolveCartridgePath(TEXT("hockey.regular")), Errors);
		if (C) TestEqual(TEXT("game.contact.check_reach_m is 1.0 (on, lane A209) when the key is absent"), C->Game.Contact.CheckReachM, 1.0, 1e-12);   // lane A209: was 0 (off)
	}
	return true;
}

// Lane A132 (track F1, evolution 4): the shove under the shields in a match (the brief's item 1). Twelve three-minute matches a level (Match()'s cut: the
// whistle off), the rule as it stands against contact.bShieldShove false (the refusal of main before lane A125). TryLift counts (UJamSim::ShieldShoveTally)
// the lifts pressed at a carrier whose take only the body shield or the take grace refused, by a bot and by the human, how many were a shove and what it did.
// The bar: the human goes down by a cross-check no more than once a match more than with the refusal.
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamContactShoveMatch, "Jam.Core.ContactShoveMatch", JamContactTests::Flags)
bool FJamContactShoveMatch::RunTest(const FString& Parameters)
{
	const int32 Seeds = 12;
	for (const TCHAR* Level : { TEXT("rookie"), TEXT("pro"), TEXT("all_star") })
	{
		double HumanCrossDown[2] = { 0.0, 0.0 };
		for (int32 Arm = 0; Arm < 2; ++Arm)   // 0 = the rule on (the tree), 1 = the refusal restored
		{
			FJamShieldShoveTally T[2];
			int32 CrossDown[2] = { 0, 0 }, CrossStumble[2] = { 0, 0 }, Downs[2] = { 0, 0 }, Lifts[2] = { 0, 0 }, GoalsFor = 0, GoalsAgainst = 0;
			for (uint64 Seed = 1; Seed <= Seeds; ++Seed)
			{
				FContactCount C;
				const JamAI::FJamPlaytestStats S = Match(*this, Level, Seed, C, [Arm](FJamGameConfig& G) { if (Arm == 1) G.Contact.bShieldShove = false; });
				for (int32 H = 0; H < 2; ++H)
				{
					T[H].Presses += C.Shove[H].Presses; T[H].AtArm += C.Shove[H].AtArm; T[H].Shoves += C.Shove[H].Shoves; T[H].FromBehind += C.Shove[H].FromBehind;
					T[H].Bump += C.Shove[H].Bump; T[H].Stumble += C.Shove[H].Stumble; T[H].Down += C.Shove[H].Down;
					CrossDown[H] += C.CrossDown[H]; CrossStumble[H] += C.CrossStumble[H]; Downs[H] += C.Downs[H]; Lifts[H] += C.Lifts[H];
				}
				GoalsFor += S.GoalsFor; GoalsAgainst += S.GoalsAgainst;
			}
			HumanCrossDown[Arm] = static_cast<double>(CrossDown[1]) / Seeds;
			AddInfo(FString::Printf(TEXT("JAMSHOVE TOTAL %s %s, %d three-minute matches: the HUMAN's lift presses %d, at a stick-only shield %d (at arm's length %d), shoves %d (from behind %d): bump %d stumble %d down %d | ")
				TEXT("a BOT's lift presses %d, at a stick-only shield %d (at arm's length %d), shoves %d (from behind %d): bump %d stumble %d down %d | by a cross-check a match: the human down %.2f stumbled %.2f, a bot down %.2f stumbled %.2f | ")
				TEXT("knockdowns a match: of the human %.2f, of a bot %.2f | goals %d:%d"), Level, Arm == 0 ? TEXT("shove rule ON") : TEXT("refusal restored"), Seeds,
				Lifts[1], T[1].Presses, T[1].AtArm, T[1].Shoves, T[1].FromBehind, T[1].Bump, T[1].Stumble, T[1].Down,
				Lifts[0], T[0].Presses, T[0].AtArm, T[0].Shoves, T[0].FromBehind, T[0].Bump, T[0].Stumble, T[0].Down,
				static_cast<double>(CrossDown[1]) / Seeds, static_cast<double>(CrossStumble[1]) / Seeds, static_cast<double>(CrossDown[0]) / Seeds, static_cast<double>(CrossStumble[0]) / Seeds,
				static_cast<double>(Downs[1]) / Seeds, static_cast<double>(Downs[0]) / Seeds, GoalsFor, GoalsAgainst));
			if (Arm == 1) TestEqual(*FString::Printf(TEXT("%s, the refusal restored: no shove under a stick-only shield"), Level), T[0].Shoves + T[1].Shoves, 0);
		}
		TestTrue(*FString::Printf(TEXT("%s: the human goes down by a cross-check no more than once a match more with the rule on (%.2f against %.2f)"), Level, HumanCrossDown[0], HumanCrossDown[1]),
			HumanCrossDown[0] <= HumanCrossDown[1] + 1.0);
	}
	return true;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamContactReachMatch, "Jam.Core.ContactReachMatch", JamContactTests::Flags)
bool FJamContactReachMatch::RunTest(const FString& Parameters)
{
	// The neutral value: three pro matches at check_reach_m 0 hash as the track's baseline did on its defaults (evolution 2, R-0051: release grace 120).
	// re-pinned to LADDER SET 3, 15 Nov (the Director's ruling 07:25): the level profiles' numbers changed, no rule did
	const uint64 Baseline[3] = { 0x882e3cc9250346aeull, 0xd0edbf996003c94cull, 0x8ffbad9a6cce3f50ull };
	// The measurement: three-minute pro matches, five a side, the Regular playtester as the human, by reach and by how the playtester presses (lane A132:
	// on its own speed along the line, as before, or on the closing speed). 0.5 and 1.5 were measured too (docs/experiments/CONTACT-4.md section 6).
	struct FArm { double Reach; bool bClosing; };
	const FArm Arms[] = { { 0.0, false }, { 0.0, true }, { 1.0, false }, { 1.0, true } };
	const int32 Seeds = 10;
	double Share[4] = { 0.0, 0.0, 0.0, 0.0 };
	int32 ArmIndex = 0;
	for (const FArm& Arm : Arms)
	{
		const double Reach = Arm.Reach;
		const bool bClosing = Arm.bClosing;
		const TCHAR* Press = bClosing ? TEXT("closing speed") : TEXT("own speed");
		int32 Presses = 0, Missed = 0, Landed = 0, Soft = 0, Graced = 0, HumanDowns = 0, BotDowns = 0, BotChecks = 0, HumanStumbles = 0, GoalsFor = 0, GoalsAgainst = 0, Far = 0, Chase = 0, Other = 0;
		int32 NoCarrier = 0, CarrierFar = 0, CarrierChase = 0, CarrierSlow = 0, CarrierFast = 0, NotNearest = 0;
		for (uint64 Seed = 1; Seed <= Seeds; ++Seed)
		{
			FReachCount R;
			const JamAI::FJamPlaytestStats S = MatchReach(*this, TEXT("pro"), Seed, R, [Reach, bClosing](FJamGameConfig& G) { G.Contact.CheckReachM = Reach; G.Contact.bPlaytesterClosingPress = bClosing; });
			const FContactCount& C = R.Base;
			AddInfo(FString::Printf(TEXT("JAMREACH match pro seed %llu reach %.1f press on %s: frames %lld hash %016llx goals %d:%d | human's presses %d: whiffs %d, too soft %d, met a grace %d, landed %d | check events by a bot %d | knockdowns of human %d of bot %d | stumbles of human %d"),
				static_cast<unsigned long long>(Seed), Reach, Press, static_cast<long long>(S.Frames), static_cast<unsigned long long>(S.Hash), S.GoalsFor, S.GoalsAgainst, R.Presses, C.HumanMissed, C.HumanSoft, C.HumanGraced, C.Checks[1],
				C.Checks[0], C.Downs[1], C.Downs[0], C.HitStumble[1]));
			if (ArmIndex == 0 && Seed <= 3)
			{
				// Lane A138 (R-0053 point 5): the pin is the track's evolution 2 on its own tree (the boards and the release grace on, nothing of the other tracks):
				// the shared baseline with those two steps back on, and check_reach_m 0.
				FReachCount Rn;
				const JamAI::FJamPlaytestStats Sn = MatchReach(*this, TEXT("pro"), Seed, Rn, [](FJamGameConfig& G) { JamBaseline::MakeNeutral(G); JamBaseline::WithBoards(G); JamBaseline::WithReleaseGrace(G); G.Contact.CheckReachM = 0.0; }, 10800, JamBaseline::BrainTune());
				TestEqual(*FString::Printf(TEXT("pro seed %llu: check_reach_m 0 hashes as the baseline did"), static_cast<unsigned long long>(Seed)), FString::Printf(TEXT("%016llx"), static_cast<unsigned long long>(Sn.Hash)),
					FString::Printf(TEXT("%016llx"), static_cast<unsigned long long>(Baseline[Seed - 1])));
			}
			Presses += R.Presses; Missed += C.HumanMissed; Landed += C.Checks[1]; Soft += C.HumanSoft; Graced += C.HumanGraced; HumanDowns += C.Downs[1]; BotDowns += C.Downs[0];
			BotChecks += C.Checks[0]; HumanStumbles += C.HitStumble[1]; GoalsFor += S.GoalsFor; GoalsAgainst += S.GoalsAgainst; Far += R.WhiffFar; Chase += R.WhiffChase; Other += R.WhiffOther;
			NoCarrier += R.WhiffNoCarrier; CarrierFar += R.WhiffCarrierFar; CarrierChase += R.WhiffCarrierChase; CarrierSlow += R.WhiffCarrierSlow; CarrierFast += R.WhiffCarrierFast; NotNearest += R.PressCarrierNotNearest;
		}
		AddInfo(FString::Printf(TEXT("JAMREACH CARRIER pro reach %.1f press on %s: of %d whiffs, read against the opposing carrier on the press frame: no opposing carrier %d, the carrier beyond 1 m %d, within 1 m closing under 3 m/s %d, ")
			TEXT("3 to 5 m/s %d, 5 m/s and faster %d | presses whose nearest man was not the carrier %d of %d"), Reach, Press, Missed, NoCarrier, CarrierFar, CarrierChase, CarrierSlow, CarrierFast, NotNearest, Presses));
		Share[ArmIndex] = Presses > 0 ? 100.0 * Missed / Presses : 0.0;
		AddInfo(FString::Printf(TEXT("JAMREACH TOTAL pro reach %.1f press on %s, %d three-minute matches: human's presses %d, whiffs %d = %.1f %%, too soft %d, met a grace %d, landed %d = %.1f %% | check events by a bot %d | knockdowns a match: of the human %.2f, of a bot %.2f | ")
			TEXT("stumbles of the human %d | goals %d:%d | whiffs by the press: the nearest man beyond 1 m %d, within 1 m closing under 3 m/s (a chase) %d, within 1 m closing faster %d"), Reach, Press, Seeds, Presses, Missed,
			Share[ArmIndex], Soft, Graced, Landed, Presses > 0 ? 100.0 * Landed / Presses : 0.0, BotChecks,
			static_cast<double>(HumanDowns) / Seeds, static_cast<double>(BotDowns) / Seeds, HumanStumbles, GoalsFor, GoalsAgainst, Far, Chase, Other));
		++ArmIndex;
	}
	// Lane A132: what the press on closing speed buys, and what it does not. The brief's bar (the whiff share under 40 %) is met by no arm (58 % -> 49 % at reach
	// 0, 51 % with the reach on top): it is logged, not asserted, and it is the track's next evolution (docs/experiments/CONTACT-5.md section 2).
	// Lane A151 (the Director, 14 Nov 01:55): on main with the ladder set the same ten matches read 55.4 % against 53.0 %, the reverse of lane A132's 49.2 % against
	// 58.4 %: ten matches do not carry a five-point claim either way. Logged, not asserted; the press is decided on 600 matches (docs/experiments/CONTACT-6.md).
	AddInfo(FString::Printf(TEXT("JAMREACH the press on closing speed against the playtester's own speed: %.1f %% against %.1f %% whiffs (reach 0; logged, not asserted)"), Share[1], Share[0]));
	AddInfo(FString::Printf(TEXT("JAMREACH BAR whiff share: own speed %.1f %%, closing speed %.1f %%, own speed + reach 1.0 %.1f %%, closing speed + reach 1.0 %.1f %% (the brief's bar: under 40 %%: %s)"), Share[0], Share[1], Share[2], Share[3],
		FMath::Min(FMath::Min(Share[0], Share[1]), FMath::Min(Share[2], Share[3])) < 40.0 ? TEXT("met") : TEXT("NOT met")));
	return true;
}

// Lane A132 (track F1): the brake read-outs do not outlive a faceoff. (1) The goal pause's glide: a skater still gliding at more than 1 m/s on the pause's last
// frame "brakes" on that frame (the pause holds the brake for everyone), and the faceoff set in the same frame used to leave bBraking up on a skater standing
// on its mark; (2) a restart in the middle of a reverse brake left bBraking and bReverseBraking up until the first step of the new match.
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamContactBrakeFlags, "Jam.Core.Contact.BrakeFlagsAtFaceoff", JamContactTests::Flags)
bool FJamContactBrakeFlags::RunTest(const FString& Parameters)
{
	// 1. A goal with a short pause (rules.goal_pause_frames 3): the attacker is still fast when the faceoff is set.
	{
		FContactScene S = Make(*this, [](FJamGameConfig& G) { G.Rules.GoalPauseFrames = 3; G.Rules.ScoreToWin = 99; });
		if (!S.Ok()) return false;
		const int32 N = S.Sim->GetSkaters().Num();
		const double Gx = S.Sim->AttackGoalX(S.Att().Team);
		const double Dir = Gx >= 0.0 ? 1.0 : -1.0;
		S.Sim->SetSkater(S.A, FVector2D(0.0, 6.0), FVector2D(8.0 * Dir, 0.0), Dir > 0.0 ? 0.0 : PI);
		S.Sim->SetPuck(FVector2D(Gx - Dir * 1.0, 0.0), FVector2D(Dir * 25.0, 0.0));
		bool bPaused = false, bFaceoff = false;
		int32 BrakedInPause = 0, StaleAtFaceoff = 0, StaleInCountdown = 0;
		double SpeedAtFaceoff = -1.0;
		for (int32 F = 0; F < 600; ++F)
		{
			TArray<FJamInput> In;
			In.SetNum(N);
			In[S.A].Move = FVector2D(Dir, 0.0);
			S.Sim->Step(In);
			const EJamSimPhase Ph = S.Sim->GetPhase();
			if (Ph == EJamSimPhase::GoalPause) { bPaused = true; if (S.Att().bBraking) ++BrakedInPause; }
			if (Ph == EJamSimPhase::Faceoff)
			{
				int32 Up = 0;
				for (const FJamSkaterState& K : S.Sim->GetSkaters()) if (K.bBraking || K.bReverseBraking) ++Up;
				if (!bFaceoff) { bFaceoff = true; StaleAtFaceoff = Up; SpeedAtFaceoff = S.Att().Vel.Size(); } else StaleInCountdown += Up;
			}
			if (bFaceoff && Ph == EJamSimPhase::Playing) break;
		}
		AddInfo(FString::Printf(TEXT("JAMBRAKEFLAG goal: paused %d, the attacker braked on %d pause frames, faceoff %d, its speed on the faceoff's frame %.2f m/s, brake read-outs up on that frame %d, through the countdown %d"),
			bPaused ? 1 : 0, BrakedInPause, bFaceoff ? 1 : 0, SpeedAtFaceoff, StaleAtFaceoff, StaleInCountdown));
		TestTrue(TEXT("the goal was scored and the faceoff set"), bPaused && bFaceoff);
		TestTrue(TEXT("the attacker was still braking its glide when the pause ended (the scene is the stale case)"), BrakedInPause >= 2);
		TestTrue(TEXT("the faceoff put it on its mark with no speed"), SpeedAtFaceoff >= 0.0 && SpeedAtFaceoff < 1e-6);
		TestEqual(TEXT("no brake read-out on the frame the faceoff is set"), StaleAtFaceoff, 0);
		TestEqual(TEXT("... and none through the countdown"), StaleInCountdown, 0);
	}
	// 2. A restart in the middle of a reverse brake.
	{
		FContactScene S = Make(*this, NoEdit);
		if (!S.Ok()) return false;
		S.Sim->SetSkater(S.A, FVector2D(0.0, 6.0), FVector2D(8.0, 0.0), 0.0);
		TArray<FJamInput> In;
		In.SetNum(S.Sim->GetSkaters().Num());
		In[S.A].Move = FVector2D(-1.0, 0.0);
		S.Sim->Step(In);
		TestTrue(TEXT("the reverse brake's read-outs are up on the frame of the brake"), S.Att().bBraking && S.Att().bReverseBraking);
		const uint64 Before = S.Sim->StateHash();
		S.Sim->Restart();
		TestFalse(TEXT("a restart leaves no brake read-out behind"), S.Att().bBraking || S.Att().bReverseBraking);
		AddInfo(FString::Printf(TEXT("JAMBRAKEFLAG restart: hash before %016llx, phase after %d"), static_cast<unsigned long long>(Before), static_cast<int32>(S.Sim->GetPhase())));
	}
	return true;
}

// Lane A132 (track F1, R-0054 point 3): the law-1 drill (FJamLawOneDrill, jam.ctrl.Drill 22), headless: the same press on the same frame is a nudge between two
// skaters going the same way at the same speed and a knockdown for the longest time between two meeting head-on. Both roles of the human, the whistle on and off.
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamContactLawOneDrill, "Jam.Core.Contact.LawOneDrill", JamContactTests::Flags)
bool FJamContactLawOneDrill::RunTest(const FString& Parameters)
{
	for (int32 Case = 0; Case < 4; ++Case)
	{
		const bool bWhistle = (Case & 1) != 0, bHumanHits = (Case & 2) != 0;
		TArray<FString> Errors;
		UJamCartridge* C = UJamCartridge::LoadFromFile(UJamCartridge::ResolveCartridgePath(TEXT("hockey.regular")), Errors);
		for (const FString& E : Errors) AddError(FString::Printf(TEXT("hockey.regular: %s"), *E));
		if (!C) return false;
		FJamGameConfig Cfg = C->Game;
		Cfg.Rules.bPenalties = bWhistle;
		UJamSim* Sim = NewObject<UJamSim>();
		Sim->Init(Cfg, 7);
		Sim->SkipFaceoff();
		FJamLawOneDrill D;
		D.bHumanHits = bHumanHits;
		const FString Name = FString::Printf(TEXT("whistle %s, the human throws the %s"), bWhistle ? TEXT("on") : TEXT("off"), bHumanHits ? TEXT("hit") : TEXT("nudge"));
		if (!D.Stage(*Sim)) { AddError(Name + TEXT(": the drill did not stage")); continue; }
		TestFalse(*(Name + TEXT(": the whistle is off for the round")), Sim->GetConfig().Rules.bPenalties);
		const int32 N = Sim->GetSkaters().Num();
		for (int32 Guard = 0; D.IsLive() && Guard < 500; ++Guard)
		{
			TArray<FJamInput> In;
			In.SetNum(N);
			D.Input(*Sim, In);
			Sim->Step(In);
			D.Observe(*Sim);
		}
		AddInfo(FString::Printf(TEXT("JAMLAW1 %s: press at frame %d | nudge: outcome %d ratio %.2f at %d, the victim %.2f -> %.2f m/s, the attacker %.2f m/s, both on their feet %d | hit: outcome %d ratio %.2f at %d, closing %.1f m/s, down for %d frames | foul %d | law one %d"),
			*Name, D.PressFrame, D.NudgeOutcome, D.NudgeRatio, D.NudgeFrame, D.NudgeVicSpeedBefore, D.NudgeVicSpeedAfter, D.NudgeAttSpeedAfter, D.bNudgeOnFeet ? 1 : 0, D.HitOutcome, D.HitRatio, D.HitFrame,
			D.HitClosingMps, D.HitKnockFrames, D.bFoul ? 1 : 0, D.IsLawOne() ? 1 : 0));
		TestTrue(*(Name + TEXT(": the round ended")), D.bDone);
		TestTrue(*FString::Printf(TEXT("%s: the press came after about a second of skating (frame %d)"), *Name, D.PressFrame), D.PressFrame >= 40 && D.PressFrame <= 80);
		TestEqual(*(Name + TEXT(": from behind at matched speed: a bump")), D.NudgeOutcome, UJamSim::ContactBump);
		TestTrue(*FString::Printf(TEXT("%s: ... under bump_ratio (%.2f)"), *Name, D.NudgeRatio), D.NudgeRatio < static_cast<float>(Cfg.Contact.BumpRatio));
		TestTrue(*(Name + TEXT(": ... both keep their feet")), D.bNudgeOnFeet);
		TestTrue(*FString::Printf(TEXT("%s: ... and the victim its speed (%.2f of %.2f m/s half a second later)"), *Name, D.NudgeVicSpeedAfter, D.NudgeVicSpeedBefore), D.NudgeVicSpeedAfter > D.NudgeVicSpeedBefore - 1.0);
		TestEqual(*(Name + TEXT(": head-on at full closing speed: down")), D.HitOutcome, UJamSim::ContactDown);
		TestEqual(*(Name + TEXT(": ... for down_frames_max")), D.HitKnockFrames, Cfg.Contact.DownFramesMax);
		TestTrue(*FString::Printf(TEXT("%s: the two hits land within six frames of each other (%d and %d)"), *Name, D.NudgeFrame, D.HitFrame), D.NudgeFrame >= 0 && D.HitFrame >= 0 && FMath::Abs(D.HitFrame - D.NudgeFrame) <= 6);
		TestFalse(*(Name + TEXT(": no foul is called")), D.bFoul);
		TestTrue(*(Name + TEXT(": the take is law one")), D.IsLawOne());
		TestEqual(*(Name + TEXT(": the whistle is back as the cut had it")), Sim->GetConfig().Rules.bPenalties, bWhistle);
	}
	return true;
}

// ---- Lane A101 (track F1): every outcome reads -------------------------------------------------------------------------------------------------

// The boards are a body. One hit, five places: a side body check on a standing skater (facing along the boards or +x, the hit from its side, seen and braced).
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamContactBoards, "Jam.Core.Contact.Boards", JamContactTests::Flags)
bool FJamContactBoards::RunTest(const FString& Parameters)
{
	struct FOut { FContactHit H; bool bBoardReadout = false, bContactBoard = false; int32 BoardEvents = 0, BoardHits = 0; float BoardStrength = -1.f; FVector2D BoardDir = FVector2D::ZeroVector; double BoardGap = -1.0; uint64 Hash = 0; };
	// Speed = the attacker's speed along Dir; the victim stands at VPos facing VYaw, the attacker starts 1 m away along -Dir.
	auto Hit = [&](const TCHAR* Name, double Bonus, const FVector2D& VPos, double VYaw, const FVector2D& Dir, double Speed) -> FOut
	{
		FOut O;
		FContactScene S = Make(*this, [&](FJamGameConfig& G) { G.Contact.BoardBonus = Bonus; });
		if (!S.Ok()) return O;
		S.Sim->SetSkater(S.V, VPos, FVector2D::ZeroVector, VYaw);
		S.Sim->SetSkater(S.A, VPos - Dir * 1.0, Dir * Speed, FMath::Atan2(Dir.Y, Dir.X));
		O.H = Run(S, 12, [&](TArray<FJamInput>& In, int32 F) { In[S.A].bCheck = F == 0; });
		O.bBoardReadout = S.Vic().bBoardHitThisFrame;
		O.bContactBoard = S.Vic().bContactBoard;
		O.BoardHits = S.Vic().ContactBoardHits;
		for (const FJamSimEvent& E : S.Sim->GetFrameEvents())
		{
			if (E.Name != JamEvents::Board || E.Who != S.V) continue;
			++O.BoardEvents;
			O.BoardStrength = E.Strength;
			O.BoardDir = E.Dir;
			FVector2D N;
			O.BoardGap = FMath::Abs(S.Sim->BoardDistance(E.Where, N));
		}
		// The echo: the victim's own slide into the boards inside half a second is the hit already announced.
		for (int32 F = 0; F < 30; ++F)
		{
			TArray<FJamInput> In;
			In.SetNum(S.Sim->GetSkaters().Num());
			S.Sim->Step(In);
			for (const FJamSimEvent& E : S.Sim->GetFrameEvents()) if (E.Name == JamEvents::Board && E.Who == S.V) ++O.BoardEvents;
		}
		O.Hash = S.Sim->StateHash();
		AddInfo(FString::Printf(TEXT("JAMBOARDS %s (board_bonus %.2f, %.1f m/s): %s | board read-out %d contact_board %d board events %d strength %.2f"), Name, Bonus, Speed, *Facts(O.H),
			O.bBoardReadout ? 1 : 0, O.bContactBoard ? 1 : 0, O.BoardEvents, O.BoardStrength));
		return O;
	};
	FJamGameConfig Cfg;
	{
		FContactScene S0 = Make(*this, NoEdit);
		if (!S0.Ok()) return false;
		Cfg = S0.Cfg;
	}
	TestEqual(TEXT("contact.board_bonus defaults to 1.25"), Cfg.Contact.BoardBonus, 1.25);
	const double Hz = Cfg.Rink.WidthM * 0.5;
	const FVector2D In(0.0, 1.0);   // into the +z side boards
	const double Bonus = Cfg.Contact.BoardBonus;
	// 1. Open ice: the reference hit (4 m/s: a stumble, CONTACT.md's 0.61).
	const FOut Open = Hit(TEXT("open ice"), Bonus, FVector2D::ZeroVector, 0.0, In, 4.0);
	TestEqual(TEXT("open ice, 4 m/s on a standing skater: a stumble"), Open.H.Outcome, UJamSim::ContactStumble);
	TestTrue(TEXT("open ice: no board read-out, no board event"), !Open.bBoardReadout && !Open.bContactBoard && Open.BoardEvents == 0);
	// 2. The same hit 1 m from the boards, straight into them: the ratio counts x board_bonus, the read-out and the event fire with the check's strength.
	const FOut Into = Hit(TEXT("1 m from the boards, into them"), Bonus, FVector2D(0.0, Hz - 1.0), 0.0, In, 4.0);
	TestTrue(*FString::Printf(TEXT("into the boards: ratio %.3f = open ice %.3f x %.2f"), Into.H.Ratio, Open.H.Ratio, Bonus), FMath::IsNearlyEqual(static_cast<double>(Into.H.Ratio), Open.H.Ratio * Bonus, 0.005));
	TestTrue(TEXT("into the boards: the victim's board read-out fires (PlayBoardHit) and the hit is counted"), Into.bBoardReadout && Into.bContactBoard && Into.BoardHits == 1);
	TestEqual(TEXT("into the boards: one board event for the victim, also through its slide into the boards (the echo is the same hit)"), Into.BoardEvents, 1);
	TestTrue(*FString::Printf(TEXT("... with the check's strength (%.2f = %.2f)"), Into.BoardStrength, Into.H.Strength), Into.H.bCheck && FMath::IsNearlyEqual(Into.BoardStrength, Into.H.Strength, 0.001f));
	TestTrue(TEXT("... on the boards, its Dir the normal into the rink"), Into.BoardGap < 0.01 && FVector2D::DotProduct(Into.BoardDir, In) < -0.99);
	// 3. Along the boards, away from them, and beyond the range: the open-ice hit.
	const FOut Along = Hit(TEXT("1 m from the boards, along them"), Bonus, FVector2D(0.0, Hz - 1.0), PI * 0.5, FVector2D(1.0, 0.0), 4.0);
	const FOut Away = Hit(TEXT("1.45 m from the boards, away from them"), Bonus, FVector2D(0.0, Hz - 1.45), 0.0, -In, 4.0);
	const FOut Far = Hit(TEXT("2 m from the boards, into them"), Bonus, FVector2D(0.0, Hz - 2.0), 0.0, In, 4.0);
	for (const FOut* O : { &Along, &Away, &Far })
	{
		TestTrue(*FString::Printf(TEXT("no boards in the hit: ratio %.3f = open ice %.3f"), O->H.Ratio, Open.H.Ratio), FMath::IsNearlyEqual(O->H.Ratio, Open.H.Ratio, 0.005f));
		TestTrue(TEXT("... and no board read-out at the hit"), !O->bBoardReadout && !O->bContactBoard);
	}
	// 4. Half the bonus at 75.5 degrees off straight in (dot 0.25): the factor is linear in 2 x dot up to 60 degrees.
	{
		const FVector2D Dir = FVector2D(FMath::Sqrt(1.0 - 0.25 * 0.25), 0.25);
		const FOut Half = Hit(TEXT("1 m from the boards, dot 0.25"), Bonus, FVector2D(0.0, Hz - 1.0), FMath::Atan2(Dir.Y, Dir.X) + PI * 0.5, Dir, 4.0);
		TestTrue(*FString::Printf(TEXT("dot 0.25: ratio %.3f = open ice x %.3f"), Half.H.Ratio, 1.0 + (Bonus - 1.0) * 0.5), FMath::IsNearlyEqual(static_cast<double>(Half.H.Ratio), Open.H.Ratio * (1.0 + (Bonus - 1.0) * 0.5), 0.01));
	}
	// 5. The hit the boards decide: 6.5 m/s stumbles a braced skater on open ice (0.89) and puts it down against the boards (1.11).
	const FOut OpenHard = Hit(TEXT("open ice"), Bonus, FVector2D::ZeroVector, 0.0, In, 6.5);
	const FOut IntoHard = Hit(TEXT("1 m from the boards, into them"), Bonus, FVector2D(0.0, Hz - 1.0), 0.0, In, 6.5);
	TestEqual(TEXT("6.5 m/s on open ice: a stumble"), OpenHard.H.Outcome, UJamSim::ContactStumble);
	TestEqual(TEXT("6.5 m/s into the boards: down"), IntoHard.H.Outcome, UJamSim::ContactDown);
	TestTrue(TEXT("... with the board read-out"), IntoHard.bBoardReadout && IntoHard.H.bKnock);
	// 6. The neutral value: board_bonus 1 is the open-ice hit at the boards: same ratio, no read-out, no event; and the state after it hashes as a sim that
	// never heard of the boards would (the same scene with the bonus left at its default but the victim's hit resolved 2 m out differs: so compare 1.0 against 1.0 twice
	// and against the default, which must differ once the knockdown lasts longer).
	const FOut Neutral = Hit(TEXT("1 m from the boards, into them"), 1.0, FVector2D(0.0, Hz - 1.0), 0.0, In, 6.5);
	TestTrue(*FString::Printf(TEXT("board_bonus 1: ratio %.3f = open ice %.3f"), Neutral.H.Ratio, OpenHard.H.Ratio), FMath::IsNearlyEqual(Neutral.H.Ratio, OpenHard.H.Ratio, 0.005f));
	TestEqual(TEXT("board_bonus 1: a stumble, as on open ice"), Neutral.H.Outcome, UJamSim::ContactStumble);
	TestTrue(TEXT("board_bonus 1: no board read-out and no board event at the hit"), !Neutral.bBoardReadout && !Neutral.bContactBoard && Neutral.BoardHits == 0);
	TestTrue(TEXT("board_bonus 1 and 1.25 end in different states (the bonus is a rule), two runs at 1 in the same"), Neutral.Hash != IntoHard.Hash
		&& Neutral.Hash == Hit(TEXT("1 m from the boards, into them (again)"), 1.0, FVector2D(0.0, Hz - 1.0), 0.0, In, 6.5).Hash);
	// 7. The key loads, its range holds.
	FString Json;
	if (TestTrue(TEXT("hockey.regular reads"), FFileHelper::LoadFileToString(Json, *UJamCartridge::ResolveCartridgePath(TEXT("hockey.regular")))))
	{
		TArray<FString> Errors;
		FString One = Json;
		TestEqual(TEXT("one game.skater anchor"), One.ReplaceInline(TEXT("\"skater\": {"), TEXT("\"contact\": { \"board_bonus\": 1 }, \"skater\": {")), 1);
		UJamCartridge* N = UJamCartridge::LoadFromString(One, Errors);
		for (const FString& E : Errors) AddError(FString::Printf(TEXT("board_bonus 1: %s"), *E));
		if (TestNotNull(TEXT("contact.board_bonus 1 loads"), N)) TestEqual(TEXT("... and reads back"), N->Game.Contact.BoardBonus, 1.0);
		FString Bad = Json;
		Bad.ReplaceInline(TEXT("\"skater\": {"), TEXT("\"contact\": { \"board_bonus\": 0.5 }, \"skater\": {"));
		Errors.Reset();
		UJamCartridge* B = UJamCartridge::LoadFromString(Bad, Errors);
		TestTrue(TEXT("contact.board_bonus under 1 is out of range"), B == nullptr || Errors.Num() > 0);
	}
	return true;
}

// ---- Lane A113 (track F1, R-0049 point 1): a tackle is an event, not a rhythm -------------------------------------------------------------------

// One head-on hit at full speed puts the victim down; it is released; the same hit comes again Wait frames after the release.
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamContactReleaseGrace, "Jam.Core.Contact.ReleaseGrace", JamContactTests::Flags)
bool FJamContactReleaseGrace::RunTest(const FString& Parameters)
{
	struct FOut { bool bOk = false; FContactHit First, Second; int32 GraceAtRelease = -1, GraceAfter30 = -1, GraceAtHit = -1, DownFor = 0, AttGraced = 0, AttSoft = 0, VicGraced = 0, AttStumble = 0; bool bGraceFlag = false; uint64 Hash = 0; };
	auto Scene = [&](const TCHAR* Name, TFunctionRef<void(FJamGameConfig&)> Edit, int32 Wait) -> FOut
	{
		FOut O;
		FContactScene S = Make(*this, Edit);
		if (!S.Ok()) return O;
		const double Top = S.Cfg.Skater.Speed;
		auto Charge = [&]()
		{
			S.Sim->SetSkater(S.V, FVector2D(0.6, 0.0), FVector2D(-Top, 0.0), PI);
			S.Sim->SetSkater(S.A, FVector2D(-0.6, 0.0), FVector2D(Top, 0.0), 0.0);
			return Run(S, 12, [&](TArray<FJamInput>& In, int32 F) { In[S.A].bCheck = F == 0; });
		};
		O.First = Charge();
		if (!TestTrue(*FString::Printf(TEXT("%s: the first hit puts the victim down"), Name), O.First.bKnock && S.Vic().IsDown())) return O;
		TArray<FJamInput> None;
		None.SetNum(S.Sim->GetSkaters().Num());
		// Park the attacker away from the fallen victim, wait for the release.
		S.Sim->SetSkater(S.A, FVector2D(-12.0, 0.0), FVector2D::ZeroVector, 0.0);
		while (S.Vic().IsDown() && O.DownFor < 400) { S.Sim->Step(None); ++O.DownFor; }
		O.GraceAtRelease = S.Vic().GraceFrames;
		for (int32 F = 0; F < Wait; ++F)
		{
			S.Sim->Step(None);
			if (F == 29) O.GraceAfter30 = S.Vic().GraceFrames;
		}
		O.GraceAtHit = S.Vic().GraceFrames;
		O.Second = Charge();
		O.bGraceFlag = S.Vic().bContactGrace;
		O.AttGraced = S.Att().ChecksGraced;
		O.AttSoft = S.Att().ChecksSoft;
		O.VicGraced = S.Vic().ContactGraced;
		O.AttStumble = S.Att().StumbleFrames;
		O.Hash = S.Sim->StateHash();
		O.bOk = true;
		AddInfo(FString::Printf(TEXT("JAMGRACE scene %s: down for %d frames, grace at release %d, after 30 frames %d, at the second charge %d | second hit: %s | grace flag %d attacker graced %d soft %d"),
			Name, O.DownFor, O.GraceAtRelease, O.GraceAfter30, O.GraceAtHit, *Facts(O.Second), O.bGraceFlag ? 1 : 0, O.AttGraced, O.AttSoft));
		return O;
	};
	const FJamContactConfig K;
	TestEqual(TEXT("the default grace is 120 frames (R-0051)"), K.ReleaseGraceFrames, 120);
	// 1. Inside the grace: the biggest hit in the game is a bump.
	const FOut In = Scene(TEXT("grace 120, hit 10 frames after the release"), NoEdit, 10);
	if (!In.bOk) return false;
	TestEqual(TEXT("the release starts the grace at contact.release_grace_frames"), In.GraceAtRelease, 120);
	TestTrue(*FString::Printf(TEXT("the grace is running at the second charge (%d)"), In.GraceAtHit), In.GraceAtHit > 90 && In.GraceAtHit <= 110);
	TestEqual(TEXT("inside the grace: a bump"), In.Second.Outcome, UJamSim::ContactBump);
	TestTrue(TEXT("... no check event, no knockdown event, the victim stays up and in control"), !In.Second.bCheck && !In.Second.bKnock && In.Second.KnockFrames == 0 && In.Second.StumbleFrames == 0);
	TestTrue(*FString::Printf(TEXT("... the read-out keeps the hit's real ratio (%.2f, past down_ratio)"), In.Second.Ratio), In.Second.Ratio >= K.DownRatio);
	TestTrue(TEXT("... the victim's grace read-out and the attacker's counter say why (no TOO SOFT for it)"), In.bGraceFlag && In.VicGraced == 1 && In.AttGraced == 1 && In.AttSoft == 0);
	TestTrue(*FString::Printf(TEXT("... the same hit landed the first time (ratio %.2f, down %d frames)"), In.First.Ratio, In.First.KnockFrames), In.First.Outcome == UJamSim::ContactDown && In.First.bKnock);
	TestTrue(*FString::Printf(TEXT("... the attacker pays as for any bump: this full-speed charge bounces it (recoil, %d frames of stumble)"), In.AttStumble), In.Second.bRecoil && In.AttStumble > 0);
	// 2. The countdown: 30 frames on, 90 are left; after the grace the same hit lands again.
	const FOut After = Scene(TEXT("grace 120, hit 130 frames after the release"), NoEdit, 130);
	TestEqual(TEXT("30 frames after the release 90 frames of grace are left"), After.GraceAfter30, 90);
	TestEqual(TEXT("130 frames after the release the grace is over"), After.GraceAtHit, 0);
	TestTrue(TEXT("after the grace the same hit lands: down, with its events"), After.Second.Outcome == UJamSim::ContactDown && After.Second.bCheck && After.Second.bKnock && !After.bGraceFlag && After.AttGraced == 0);
	// 3. The neutral value: no grace, the hit 10 frames after the release lands (the rhythm device B played).
	const FOut Zero = Scene(TEXT("grace 0, hit 10 frames after the release"), [](FJamGameConfig& G) { G.Contact.ReleaseGraceFrames = 0; }, 10);
	TestTrue(TEXT("release_grace_frames 0: no grace starts"), Zero.GraceAtRelease == 0 && Zero.GraceAtHit == 0);
	TestTrue(TEXT("release_grace_frames 0: the hit right after the release lands"), Zero.Second.Outcome == UJamSim::ContactDown && Zero.Second.bKnock && !Zero.bGraceFlag);
	TestTrue(TEXT("grace 0 and the default grace end in different states (the grace is a rule)"), Zero.Hash != In.Hash);
	// 4. The grace belongs to the momentum model: lane A92's neutral block starts none (it hashes as the game before the model).
	const FOut Old = Scene(TEXT("contact.momentum false"), [](FJamGameConfig& G) { G.Contact.SetNeutral(); }, 10);
	TestTrue(TEXT("contact.momentum false: no grace starts, the old rule's hit lands"), Old.GraceAtRelease == 0 && Old.Second.bKnock);
	// 5. A longer grace is a longer grace.
	const FOut Long = Scene(TEXT("grace 200, hit 100 frames after the release"), [](FJamGameConfig& G) { G.Contact.ReleaseGraceFrames = 200; }, 100);
	TestTrue(TEXT("release_grace_frames 200: 100 frames after the release the hit is still a bump"), Long.GraceAtRelease == 200 && Long.Second.Outcome == UJamSim::ContactBump && !Long.Second.bKnock);
	// 6. The counter is state: the hash sees it (one field changed on a live sim, then put back).
	{
		FContactScene S = Make(*this, NoEdit);
		if (S.Ok())
		{
			FJamSkaterState& V = const_cast<FJamSkaterState&>(S.Vic());   // test only
			const uint64 H0 = S.Sim->StateHash();
			V.GraceFrames = 5;
			const uint64 H5 = S.Sim->StateHash();
			V.GraceFrames = 6;
			const uint64 H6 = S.Sim->StateHash();
			V.GraceFrames = 0;
			TestTrue(TEXT("StateHash() covers GraceFrames (0 / 5 / 6 differ) and gives the hash back at 0"), H0 != H5 && H5 != H6 && S.Sim->StateHash() == H0);
			V.bContactGrace = true; V.ChecksSoft = 3; V.ChecksMissed = 2; V.ChecksGraced = 1; V.ContactGraced = 4;
			TestEqual(TEXT("the read-outs (bContactGrace, ChecksSoft, ChecksMissed, ChecksGraced, ContactGraced) are not hashed"), S.Sim->StateHash(), H0);
		}
	}
	// 7. The soft hit and the whiff count on the attacker (the HUD's TOO SOFT and MISSED).
	{
		FContactScene S = Make(*this, NoEdit);
		if (S.Ok())
		{
			// Both gliding the same way at the same speed, the attacker behind: a bump (lane A92's SameDirection).
			S.Sim->SetSkater(S.V, FVector2D::ZeroVector, FVector2D(8.0, 0.0), 0.0);
			S.Sim->SetSkater(S.A, FVector2D(-0.78, 0.0), FVector2D(8.0, 0.0), 0.0);
			const FContactHit H = Run(S, 12, [&](TArray<FJamInput>& In2, int32 F) { In2[S.A].bCheck = F == 0; In2[S.A].Move = FVector2D(0.7, 0.0); In2[S.V].Move = FVector2D(0.7, 0.0); });
			AddInfo(FString::Printf(TEXT("JAMGRACE soft: %s | attacker soft %d missed %d graced %d"), *Facts(H), S.Att().ChecksSoft, S.Att().ChecksMissed, S.Att().ChecksGraced));
			TestTrue(TEXT("a pressed check that resolves as a bump counts as soft on the attacker, not as a miss"), H.Outcome == UJamSim::ContactBump && S.Att().ChecksSoft == 1 && S.Att().ChecksMissed == 0 && S.Att().ChecksGraced == 0);
		}
		FContactScene W = Make(*this, NoEdit);
		if (W.Ok())
		{
			// Nobody near: the window (12 frames for the human) runs out.
			W.Sim->SetSkater(W.V, FVector2D(15.0, 0.0), FVector2D::ZeroVector, PI);
			W.Sim->SetSkater(W.A, FVector2D(-15.0, 0.0), FVector2D(4.0, 0.0), 0.0);
			int32 MissedAt = -1;
			for (int32 F = 0; F < 30; ++F)
			{
				TArray<FJamInput> In2;
				In2.SetNum(W.Sim->GetSkaters().Num());
				In2[W.A].bCheck = F == 0;
				W.Sim->Step(In2);
				if (MissedAt < 0 && W.Att().ChecksMissed > 0) MissedAt = F;
			}
			AddInfo(FString::Printf(TEXT("JAMGRACE whiff: missed %d at frame %d soft %d"), W.Att().ChecksMissed, MissedAt, W.Att().ChecksSoft));
			TestTrue(TEXT("a press that meets nobody counts one miss when its window closes, and no soft hit"), W.Att().ChecksMissed == 1 && W.Att().ChecksSoft == 0);
			TestEqual(TEXT("... on the frame the human's window (12 frames) closes"), MissedAt, UJamSim::HumanCheckWindowFrames);
		}
	}
	// 8. The key loads, its range holds.
	FString Json;
	if (TestTrue(TEXT("hockey.regular reads"), FFileHelper::LoadFileToString(Json, *UJamCartridge::ResolveCartridgePath(TEXT("hockey.regular")))))
	{
		TArray<FString> Errors;
		FString One = Json;
		TestEqual(TEXT("one game.skater anchor"), One.ReplaceInline(TEXT("\"skater\": {"), TEXT("\"contact\": { \"release_grace_frames\": 0 }, \"skater\": {")), 1);
		UJamCartridge* N = UJamCartridge::LoadFromString(One, Errors);
		for (const FString& E : Errors) AddError(FString::Printf(TEXT("release_grace_frames 0: %s"), *E));
		if (TestNotNull(TEXT("contact.release_grace_frames 0 loads"), N)) TestEqual(TEXT("... and reads back"), N->Game.Contact.ReleaseGraceFrames, 0);
		for (const TCHAR* BadValue : { TEXT("-1"), TEXT("301"), TEXT("1.5") })
		{
			FString Bad = Json;
			Bad.ReplaceInline(TEXT("\"skater\": {"), *FString::Printf(TEXT("\"contact\": { \"release_grace_frames\": %s }, \"skater\": {"), BadValue));
			Errors.Reset();
			UJamCartridge* B = UJamCartridge::LoadFromString(Bad, Errors);
			TestTrue(*FString::Printf(TEXT("contact.release_grace_frames %s is refused"), BadValue), B == nullptr || Errors.Num() > 0);
		}
	}
	return true;
}

// The hit the hold is for (AJamSkater::HitStopPick; the game mode's HitStopRoute holds on it).
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamContactHitStopPick, "Jam.Core.Contact.HitStopPick", JamContactTests::Flags)
bool FJamContactHitStopPick::RunTest(const FString& Parameters)
{
	const FName Cause(TEXT("check")), Front(TEXT("front")), SideL(TEXT("side_l"));
	const int32 Human = 0;
	auto Skaters = []() { TArray<FJamSkaterState> Sk; Sk.SetNum(6); for (int32 I = 0; I < 6; ++I) Sk[I].Index = I; return Sk; };
	auto Event = [](FName Name, int32 Who, float Strength, FName Kind) { FJamSimEvent E; E.Name = Name; E.Who = Who; E.Strength = Strength; E.Kind = Kind; return E; };
	const FJamContactConfig K;
	// 1. A stumble of the human, alone: its check event's strength (the log line used to print 0.00).
	{
		TArray<FJamSkaterState> Sk = Skaters();
		Sk[Human].ContactOutcome = UJamSim::ContactStumble; Sk[Human].ContactRatio = 0.8f; Sk[Human].ContactBy = 4;
		const TArray<FJamSimEvent> Ev = { Event(JamEvents::Check, 4, 0.45f, SideL) };
		const FJamHitStopPick P = AJamSkater::HitStopPick(Sk, Ev, Human, K.BumpRatio);
		TestTrue(TEXT("a stumble the human takes: victim, checker, outcome, ratio"), P.Victim == Human && P.Checker == 4 && P.Outcome == UJamSim::ContactStumble && FMath::IsNearlyEqual(P.Ratio, 0.8f));
		TestTrue(*FString::Printf(TEXT("... with its check event's strength (%.2f) and the kind stumble"), P.Strength), FMath::IsNearlyEqual(P.Strength, 0.45f) && P.Kind == FName(TEXT("stumble")));
		TestEqual(TEXT("... held 2 frames (ratio 0.8, past the middle of the band)"), AJamSkater::HitStopFramesFor(P.Outcome, P.Ratio, K, 3), 2);
	}
	// 2. The same frame also carries a knockdown between two bots: the human's stumble is still the hit (the route held nothing).
	{
		TArray<FJamSkaterState> Sk = Skaters();
		Sk[Human].ContactOutcome = UJamSim::ContactStumble; Sk[Human].ContactRatio = 0.5f; Sk[Human].ContactBy = 4;
		Sk[2].ContactOutcome = UJamSim::ContactDown; Sk[2].ContactRatio = 2.f; Sk[2].ContactBy = 5;
		const TArray<FJamSimEvent> Ev = { Event(JamEvents::Check, 4, 0.3f, SideL), Event(JamEvents::Check, 5, 0.9f, Front), Event(JamEvents::Knockdown, 2, 0.9f, Cause) };
		const FJamHitStopPick P = AJamSkater::HitStopPick(Sk, Ev, Human, K.BumpRatio);
		TestTrue(TEXT("a bot-on-bot knockdown and a stumble of the human in one frame: the stumble is picked"), P.Victim == Human && P.Checker == 4 && P.Outcome == UJamSim::ContactStumble);
		TestTrue(*FString::Printf(TEXT("... with its own strength (%.2f), 1 frame"), P.Strength), FMath::IsNearlyEqual(P.Strength, 0.3f) && AJamSkater::HitStopFramesFor(P.Outcome, P.Ratio, K, 3) == 1);
	}
	// 3. Two knockdowns in one frame, the human's fall listed first: the human's is the hit, with its own checker and kind.
	{
		TArray<FJamSkaterState> Sk = Skaters();
		Sk[Human].ContactOutcome = UJamSim::ContactDown; Sk[Human].ContactRatio = 1.4f; Sk[Human].ContactBy = 4;
		Sk[2].ContactOutcome = UJamSim::ContactDown; Sk[2].ContactRatio = 3.f; Sk[2].ContactBy = 5;
		const TArray<FJamSimEvent> Ev = { Event(JamEvents::Check, 4, 0.5f, SideL), Event(JamEvents::Knockdown, Human, 0.5f, Cause), Event(JamEvents::Check, 5, 1.f, Front), Event(JamEvents::Knockdown, 2, 1.f, Cause) };
		const FJamHitStopPick P = AJamSkater::HitStopPick(Sk, Ev, Human, K.BumpRatio);
		TestTrue(TEXT("two knockdowns in one frame: the human's fall is picked, not the last one"), P.Victim == Human && P.Checker == 4 && P.Kind == SideL && FMath::IsNearlyEqual(P.Strength, 0.5f) && FMath::IsNearlyEqual(P.Ratio, 1.4f));
		TestEqual(TEXT("... held 3 frames (ratio 1.4)"), AJamSkater::HitStopFramesFor(P.Outcome, P.Ratio, K, 3), 3);
	}
	// 4. A knockdown between two bots only: nothing to hold.
	{
		TArray<FJamSkaterState> Sk = Skaters();
		Sk[2].ContactOutcome = UJamSim::ContactDown; Sk[2].ContactRatio = 2.f; Sk[2].ContactBy = 5;
		const TArray<FJamSimEvent> Ev = { Event(JamEvents::Check, 5, 0.9f, Front), Event(JamEvents::Knockdown, 2, 0.9f, Cause) };
		TestEqual(TEXT("a knockdown between two bots holds nothing"), AJamSkater::HitStopPick(Sk, Ev, Human, K.BumpRatio).Victim, -1);
	}
	// 5. A knockdown the human lands; and a knockdown the momentum model did not resolve (the frame's check event names the checker; the base holds).
	{
		TArray<FJamSkaterState> Sk = Skaters();
		Sk[3].ContactOutcome = UJamSim::ContactDown; Sk[3].ContactRatio = 2.34f; Sk[3].ContactBy = Human;
		const TArray<FJamSimEvent> Ev = { Event(JamEvents::Check, Human, 0.8f, Front), Event(JamEvents::Knockdown, 3, 0.8f, Cause) };
		const FJamHitStopPick P = AJamSkater::HitStopPick(Sk, Ev, Human, K.BumpRatio);
		TestTrue(TEXT("a knockdown the human lands"), P.Victim == 3 && P.Checker == Human && P.Outcome == UJamSim::ContactDown && P.Kind == Front && AJamSkater::HitStopFramesFor(P.Outcome, P.Ratio, K, 3) == 5);
		TArray<FJamSkaterState> Old = Skaters();
		const FJamHitStopPick Q = AJamSkater::HitStopPick(Old, Ev, Human, K.BumpRatio);
		TestTrue(TEXT("contact.momentum false: the check event names the checker, outcome none, the base holds"), Q.Victim == 3 && Q.Checker == Human && Q.Outcome == UJamSim::ContactNone && AJamSkater::HitStopFramesFor(Q.Outcome, Q.Ratio, K, 3) == 3);
	}
	// 6. The human's own bounce (its hit was a bump, it stumbles): 1 frame; a knockdown by another cause (the shotgun) holds nothing.
	{
		TArray<FJamSkaterState> Sk = Skaters();
		Sk[Human].bRecoilThisFrame = true;
		Sk[3].ContactOutcome = UJamSim::ContactBump; Sk[3].ContactBy = Human;
		const FJamHitStopPick P = AJamSkater::HitStopPick(Sk, TArray<FJamSimEvent>(), Human, K.BumpRatio);
		TestTrue(TEXT("the human's bounce: the human holds with the skater it bounced off, 1 frame"), P.Victim == Human && P.Checker == 3 && P.Kind == FName(TEXT("bounce")) && AJamSkater::HitStopFramesFor(P.Outcome, P.Ratio, K, 3) == 1);
		const TArray<FJamSimEvent> Shot = { Event(JamEvents::Knockdown, Human, 1.f, FName(TEXT("shotgun"))) };
		TestEqual(TEXT("a knockdown by the shotgun is not a check: nothing picked (as before)"), AJamSkater::HitStopPick(Skaters(), Shot, Human, K.BumpRatio).Victim, -1);
	}
	return true;
}

// The neutral proof and the brief's measurement. Baseline = this track's evolution 1 (board_bonus 1.25): pro seeds 1 to 3, three minutes.
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamContactGraceMatch, "Jam.Core.ContactGraceMatch", JamContactTests::Flags)
bool FJamContactGraceMatch::RunTest(const FString& Parameters)
{
	// re-pinned to LADDER SET 3, 15 Nov (the Director's ruling 07:25): the level profiles' numbers changed, no rule did
	const uint64 Baseline[3] = { 0x882e3cc9250346aeull, 0xd0edbf996003c94cull, 0x7010c1a5c690f9b7ull };
	for (uint64 Seed = 1; Seed <= 3; ++Seed)
	{
		FContactCount Cn;
		const JamAI::FJamPlaytestStats Sn = Match(*this, TEXT("pro"), Seed, Cn, [](FJamGameConfig& G) { JamBaseline::MakeNeutral(G); JamBaseline::WithBoards(G); }, FString(), 10800, JamBaseline::BrainTune());   // lane A138 (R-0053 point 5): the shared baseline with the boards back on = lane A101's tree, release_grace_frames 0
		AddInfo(Line(*FString::Printf(TEXT("JAMGRACE match pro seed %llu release_grace_frames 0"), static_cast<unsigned long long>(Seed)), Sn, Cn));
		TestEqual(*FString::Printf(TEXT("pro seed %llu: release_grace_frames 0 hashes as the baseline did"), static_cast<unsigned long long>(Seed)), FString::Printf(TEXT("%016llx"), static_cast<unsigned long long>(Sn.Hash)),
			FString::Printf(TEXT("%016llx"), static_cast<unsigned long long>(Baseline[Seed - 1])));
		TestEqual(*FString::Printf(TEXT("pro seed %llu: at release_grace_frames 0 no hit meets a grace"), static_cast<unsigned long long>(Seed)), Cn.Graced[0] + Cn.Graced[1], 0);
		FContactCount C;
		const JamAI::FJamPlaytestStats S = Match(*this, TEXT("pro"), Seed, C, [](FJamGameConfig&) {});
		AddInfo(Line(*FString::Printf(TEXT("JAMGRACE match pro seed %llu release_grace_frames 120 (the default)"), static_cast<unsigned long long>(Seed)), S, C));
		AddInfo(FString::Printf(TEXT("JAMGRACE grace pro seed %llu three minutes, grace 120 (the default): %s"), static_cast<unsigned long long>(Seed), *GraceLine(C)));
		TestEqual(*FString::Printf(TEXT("pro seed %llu: on the default no hit lands on a skater inside its grace, three minutes"), static_cast<unsigned long long>(Seed)), C.ReHitInGrace, 0);
		AddInfo(FString::Printf(TEXT("JAMGRACE grace pro seed %llu three minutes, grace 0: %s"), static_cast<unsigned long long>(Seed), *GraceLine(Cn)));
	}
	// The brief's measurement: 100 s at pro, five a side, the scripted human (the Regular playtester), ten seeds, grace 0 (before) / 90 (the first ruling) / 120
	// (the default, R-0051).
	const int32 Arms[3] = { 0, 90, 120 };
	for (int32 A = 0; A < 3; ++A)
	{
		const int32 Grace = Arms[A];
		int32 HumanDowns = 0, HumanMax = 0, BotDowns = 0, ReDown = 0, ReDownByHit = 0, ReStumble = 0, Graced = 0, GracedByBot = 0, InGrace = 0, MinGap = 1000000, Over4 = 0, Soft = 0, Missed = 0;
		FString PerSeed;
		for (uint64 Seed = 1; Seed <= 10; ++Seed)
		{
			FContactCount C;
			const JamAI::FJamPlaytestStats S = Match(*this, TEXT("pro"), Seed, C, [Grace](FJamGameConfig& G) { G.Contact.ReleaseGraceFrames = Grace; G.Stick.FaceoffWinnerShieldFrames = 0; }, FString(), 6000);   // lane A208: the faceoff winner's shield is the release grace's state: off here, this test measures the release grace
			AddInfo(FString::Printf(TEXT("JAMGRACE 100s pro seed %llu grace %d: frames %lld hash %016llx goals %d:%d | %s"), static_cast<unsigned long long>(Seed), Grace, static_cast<long long>(S.Frames),
				static_cast<unsigned long long>(S.Hash), S.GoalsFor, S.GoalsAgainst, *GraceLine(C)));
			HumanDowns += C.Downs[1]; HumanMax = FMath::Max(HumanMax, C.Downs[1]); BotDowns += C.Downs[0];
			ReDown += C.ReDown[0] + C.ReDown[1]; ReDownByHit += C.ReDownByHit[0] + C.ReDownByHit[1]; ReStumble += C.ReStumble[0] + C.ReStumble[1];
			Graced += C.Graced[0] + C.Graced[1]; GracedByBot += C.GracedByBot; InGrace += C.ReHitInGrace; MinGap = FMath::Min(MinGap, C.MinGap);
			if (C.Downs[1] >= 5) ++Over4;
			Soft += C.HumanSoft; Missed += C.HumanMissed;
			PerSeed += FString::Printf(TEXT("%s%d"), Seed > 1 ? TEXT(" ") : TEXT(""), C.Downs[1]);
		}
		AddInfo(FString::Printf(TEXT("JAMGRACE 100s pro TOTAL grace %d, ten seeds: knockdowns of the human %d (per seed: %s; most %d; matches with five or more %d) of a bot %d | figures down again within 120 frames of release %d (by a hit %d) | ")
			TEXT("stumbled by a hit in that window %d | shortest release-to-down gap %d frames | hits the grace made a bump %d (thrown by a bot %d) | landed hits inside a grace %d | human's soft hits %d misses %d"),
			Grace, HumanDowns, *PerSeed, HumanMax, Over4, BotDowns, ReDown, ReDownByHit, ReStumble, MinGap == 1000000 ? -1 : MinGap, Graced, GracedByBot, InGrace, Soft, Missed));
		if (Grace > 0) TestEqual(*FString::Printf(TEXT("grace %d: no hit lands (stumble or knockdown) on a skater inside its grace, ten matches"), Grace), InGrace, 0);
		if (Grace == 0) TestEqual(TEXT("grace 0: no hit meets a grace"), Graced, 0);
	}
	return true;
}

// The hold reads the hit (AJamSkater::HitStopFramesFor; the game mode's HitStopRoute calls it with jam.hitstop as the base).
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamContactHitStop, "Jam.Core.Contact.HitStop", JamContactTests::Flags)
bool FJamContactHitStop::RunTest(const FString& Parameters)
{
	const FJamContactConfig K;   // the defaults: bump 0.4, down 1, full 3
	struct FRow { int32 Outcome; float Ratio; int32 Base; int32 Want; const TCHAR* Name; };
	const FRow Rows[] = {
		{ UJamSim::ContactBump, 0.30f, 3, 0, TEXT("a bump holds nothing") },
		{ UJamSim::ContactStumble, 0.40f, 3, 1, TEXT("the lightest stumble: 1") },
		{ UJamSim::ContactStumble, 0.69f, 3, 1, TEXT("a stumble under the middle of its band: 1") },
		{ UJamSim::ContactStumble, 0.70f, 3, 2, TEXT("a stumble from the middle of its band: 2") },
		{ UJamSim::ContactStumble, 0.99f, 3, 2, TEXT("the hardest stumble: 2") },
		{ UJamSim::ContactDown, 1.00f, 3, 2, TEXT("a knockdown at down_ratio: 2") },
		{ UJamSim::ContactDown, 1.40f, 3, 3, TEXT("a knockdown at 1.4 (a full-speed charge into a braced skater): 3") },
		{ UJamSim::ContactDown, 2.00f, 3, 4, TEXT("a knockdown at 2.0, the middle of the band: 4") },
		{ UJamSim::ContactDown, 2.34f, 3, 5, TEXT("a knockdown at 2.34 (the acceptance drill's check): 5 (lane A132: 4 before)") },
		{ UJamSim::ContactDown, 3.00f, 3, 6, TEXT("a knockdown at down_full_ratio: 6 (lane A132: 5 before)") },
		{ UJamSim::ContactDown, 4.61f, 3, 6, TEXT("head-on at full speed: 6") },
		{ UJamSim::ContactNone, 0.00f, 3, 3, TEXT("a knockdown the model did not resolve (contact.momentum false): the base, as before") },
		{ UJamSim::ContactDown, 3.00f, 0, 0, TEXT("jam.hitstop 0: off") },
		{ UJamSim::ContactStumble, 0.90f, 0, 0, TEXT("jam.hitstop 0: off for a stumble too") },
		{ UJamSim::ContactDown, 3.00f, 6, 6, TEXT("jam.hitstop 6: the biggest hit holds 6 (the cap)") },
		{ UJamSim::ContactStumble, 0.45f, 6, 2, TEXT("jam.hitstop 6: the lightest stumble 2") },
		{ UJamSim::ContactStumble, 0.45f, 1, 1, TEXT("jam.hitstop 1: a landed hit never under 1") },
	};
	for (const FRow& R : Rows) TestEqual(R.Name, AJamSkater::HitStopFramesFor(R.Outcome, R.Ratio, K, R.Base), R.Want);
	// Never shorter for a harder hit, across the two bands.
	int32 Last = 0;
	for (int32 I = 40; I <= 500; ++I)
	{
		const float Ratio = I / 100.f;
		const int32 Frames = AJamSkater::HitStopFramesFor(Ratio >= K.DownRatio ? UJamSim::ContactDown : UJamSim::ContactStumble, Ratio, K, 3);
		if (Frames < Last) { AddError(FString::Printf(TEXT("the hold shrinks at ratio %.2f: %d after %d"), Ratio, Frames, Last)); break; }
		Last = Frames;
	}
	TestEqual(TEXT("the sweep ends on 6 frames"), Last, 6);
	// Lane A132: the biggest hit holds three times the smallest knockdown, and every whole number of frames between is some hit's.
	TestEqual(TEXT("the smallest knockdown holds 2"), AJamSkater::HitStopFramesFor(UJamSim::ContactDown, static_cast<float>(K.DownRatio), K, 3), 2);
	{
		bool bSeen[7] = {};
		for (int32 I = 100; I <= 300; ++I) bSeen[FMath::Clamp(AJamSkater::HitStopFramesFor(UJamSim::ContactDown, I / 100.f, K, 3), 0, 6)] = true;
		TestTrue(TEXT("2, 3, 4, 5 and 6 frames each belong to a knockdown between ratio 1.0 and 3.0"), bSeen[2] && bSeen[3] && bSeen[4] && bSeen[5] && bSeen[6] && !bSeen[0] && !bSeen[1]);
	}
	return true;
}

// Three pro matches (the brief's measurement), the bonus against its neutral value; the neutral arm must hash as main at ee14438 did (the Director's gate log
// premerge-automation-ue-20261113-184648.log: Jam.Core.ContactMatch, pro, seeds 1 to 3).
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamContactBoardMatch, "Jam.Core.ContactBoardMatch", JamContactTests::Flags)
bool FJamContactBoardMatch::RunTest(const FString& Parameters)
{
	// re-pinned to LADDER SET 3, 15 Nov (the Director's ruling 07:25): the level profiles' numbers changed, no rule did
	const uint64 Main[3] = { 0x882e3cc9250346aeull, 0xf91450e41956b406ull, 0x7010c1a5c690f9b7ull };
	for (uint64 Seed = 1; Seed <= 3; ++Seed)
	{
		FContactCount C;
		const JamAI::FJamPlaytestStats S = Match(*this, TEXT("pro"), Seed, C, [](FJamGameConfig&) {});
		AddInfo(Line(*FString::Printf(TEXT("JAMBOARDS match pro seed %llu board_bonus 1.25"), static_cast<unsigned long long>(Seed)), S, C));
		AddInfo(FString::Printf(TEXT("JAMBOARDS boards pro seed %llu board_bonus 1.25: %s"), static_cast<unsigned long long>(Seed), *BoardLine(C)));
		FContactCount Cn;
		const JamAI::FJamPlaytestStats Sn = Match(*this, TEXT("pro"), Seed, Cn, [](FJamGameConfig& G) { JamBaseline::MakeNeutral(G); }, FString(), 10800, JamBaseline::BrainTune());   // lane A138 (R-0053 point 5): the shared baseline = the game main had at ee14438
		AddInfo(Line(*FString::Printf(TEXT("JAMBOARDS match pro seed %llu board_bonus 1.00"), static_cast<unsigned long long>(Seed)), Sn, Cn));
		AddInfo(FString::Printf(TEXT("JAMBOARDS boards pro seed %llu board_bonus 1.00: %s"), static_cast<unsigned long long>(Seed), *BoardLine(Cn)));
		TestEqual(*FString::Printf(TEXT("pro seed %llu: board_bonus 1 hashes as main did"), static_cast<unsigned long long>(Seed)), FString::Printf(TEXT("%016llx"), static_cast<unsigned long long>(Sn.Hash)),
			FString::Printf(TEXT("%016llx"), static_cast<unsigned long long>(Main[Seed - 1])));
		TestEqual(*FString::Printf(TEXT("pro seed %llu: at board_bonus 1 the boards answer no hit"), static_cast<unsigned long long>(Seed)), Cn.BoardStumble[0] + Cn.BoardStumble[1] + Cn.BoardDown[0] + Cn.BoardDown[1], 0);
	}
	return true;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamContactSameDirection, "Jam.Core.Contact.SameDirection", JamContactTests::Flags)
bool FJamContactSameDirection::RunTest(const FString& Parameters)
{
	// Both glide along +x at 8 m/s; the attacker touches the victim from behind, then from the side, and presses check.
	struct FCase { const TCHAR* Name; FVector2D Offset; };
	for (const FCase& C : { FCase{ TEXT("from behind"), FVector2D(-0.78, 0.0) }, FCase{ TEXT("from the side"), FVector2D(0.0, -0.78) } })
	{
		FContactScene S = Make(*this, NoEdit);
		if (!S.Ok()) return false;
		S.Sim->SetSkater(S.V, FVector2D::ZeroVector, FVector2D(8.0, 0.0), 0.0);
		S.Sim->SetSkater(S.A, C.Offset, FVector2D(8.0, 0.0), 0.0);
		const FContactHit H = Run(S, 12, [&](TArray<FJamInput>& In, int32 F) { In[S.A].bCheck = F == 0; In[S.A].Move = FVector2D(0.7, 0.0); In[S.V].Move = FVector2D(0.7, 0.0); });
		AddInfo(FString::Printf(TEXT("same direction, same speed, %s: %s"), C.Name, *Facts(H)));
		TestEqual(*FString::Printf(TEXT("%s: the pressed check is a bump"), C.Name), H.Outcome, UJamSim::ContactBump);
		TestFalse(*FString::Printf(TEXT("%s: no check event, no knockdown"), C.Name), H.bCheck || H.bKnock);
		TestTrue(*FString::Printf(TEXT("%s: the victim keeps its feet and its control"), C.Name), S.Vic().CanAct());
		TestTrue(*FString::Printf(TEXT("%s: the victim keeps its speed (%.2f of %.2f m/s)"), C.Name, H.VicSpeedAfter, H.VicSpeedBefore), H.VicSpeedAfter > H.VicSpeedBefore - 0.5);
	}
	return true;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamContactHeadOn, "Jam.Core.Contact.HeadOn", JamContactTests::Flags)
bool FJamContactHeadOn::RunTest(const FString& Parameters)
{
	FContactScene S = Make(*this, NoEdit);
	if (!S.Ok()) return false;
	const double Top = S.Cfg.Skater.Speed;
	S.Sim->SetSkater(S.V, FVector2D(0.6, 0.0), FVector2D(-Top, 0.0), PI);
	S.Sim->SetSkater(S.A, FVector2D(-0.6, 0.0), FVector2D(Top, 0.0), 0.0);
	const FContactHit H = Run(S, 12, [&](TArray<FJamInput>& In, int32 F) { In[S.A].bCheck = F == 0; });
	AddInfo(FString::Printf(TEXT("head-on at %.1f m/s each: %s"), Top, *Facts(H)));
	TestEqual(TEXT("head-on at full speed: down"), H.Outcome, UJamSim::ContactDown);
	TestTrue(TEXT("the check and the knockdown events"), H.bCheck && H.bKnock);
	TestEqual(TEXT("down for down_frames_max (skater.knockdown_frames 90)"), H.KnockFrames, S.Cfg.Contact.DownFramesMax);
	TestTrue(*FString::Printf(TEXT("the ratio %.2f is past down_full_ratio %.1f: the biggest hit in the game"), H.Ratio, S.Cfg.Contact.DownFullRatio), H.Ratio >= S.Cfg.Contact.DownFullRatio);
	TestTrue(TEXT("strength 1 (closing speed over skater.speed, clamped)"), H.Strength > 0.99f);
	// The same press with the same closing speed halved lands a shorter knockdown: the frames follow the ratio.
	FContactScene S2 = Make(*this, NoEdit);
	S2.Sim->SetSkater(S2.V, FVector2D(0.6, 0.0), FVector2D(-3.0, 0.0), PI);
	S2.Sim->SetSkater(S2.A, FVector2D(-0.6, 0.0), FVector2D(4.0, 0.0), 0.0);
	const FContactHit H2 = Run(S2, 12, [&](TArray<FJamInput>& In, int32 F) { In[S2.A].bCheck = F == 0; });
	AddInfo(FString::Printf(TEXT("head-on at 4 and 3 m/s: %s"), *Facts(H2)));
	TestEqual(TEXT("head-on at 4 + 3 m/s: down"), H2.Outcome, UJamSim::ContactDown);
	TestTrue(*FString::Printf(TEXT("... for fewer frames (%d) than the full-speed hit (%d), at least down_frames_min"), H2.KnockFrames, H.KnockFrames),
		H2.KnockFrames < H.KnockFrames && H2.KnockFrames >= S2.Cfg.Contact.DownFramesMin);
	return true;
}

// The two older levers under the model. skater.knockdown_frames scales the frames down (value / 90): the head-on at full speed lies 250 at 150. skater.check_speed_min
// scales the hit (5 / value) for the outcome only: at 2.5 the side check from 4 m/s that stumbled a standing skater (0.61) puts it down (1.22), for down_frames_min
// (the physical ratio is under down_ratio), not for the maximum.
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamContactLevers, "Jam.Core.Contact.Levers", JamContactTests::Flags)
bool FJamContactLevers::RunTest(const FString& Parameters)
{
	{
		FContactScene S = Make(*this, [](FJamGameConfig& G) { G.Skater.KnockdownFrames = 150; });
		if (!S.Ok()) return false;
		const double Top = S.Cfg.Skater.Speed;
		S.Sim->SetSkater(S.V, FVector2D(0.6, 0.0), FVector2D(-Top, 0.0), PI);
		S.Sim->SetSkater(S.A, FVector2D(-0.6, 0.0), FVector2D(Top, 0.0), 0.0);
		const FContactHit H = Run(S, 12, [&](TArray<FJamInput>& In, int32 F) { In[S.A].bCheck = F == 0; });
		AddInfo(FString::Printf(TEXT("knockdown_frames 150, head-on at full speed: %s"), *Facts(H)));
		TestEqual(TEXT("knockdown_frames 150: the biggest hit lies down_frames_max x 150 / 90 = 250"), H.KnockFrames, 250);
	}
	for (const double CheckMin : { 5.0, 2.5 })
	{
		FContactScene S = Make(*this, [&](FJamGameConfig& G) { G.Skater.CheckSpeedMin = CheckMin; });
		if (!S.Ok()) return false;
		S.Sim->SetSkater(S.V, FVector2D::ZeroVector, FVector2D::ZeroVector, 0.0);
		S.Sim->SetSkater(S.A, FVector2D(0.0, -1.0), FVector2D(0.0, 4.0), PI * 0.5);
		const FContactHit H = Run(S, 12, [&](TArray<FJamInput>& In, int32 F) { In[S.A].bCheck = F == 0; });
		AddInfo(FString::Printf(TEXT("check_speed_min %.1f, side check from 4 m/s on a standing skater: %s"), CheckMin, *Facts(H)));
		if (CheckMin > 4.0) TestEqual(TEXT("check_speed_min 5: a stumble"), H.Outcome, UJamSim::ContactStumble);
		else
		{
			TestEqual(TEXT("check_speed_min 2.5: the same hit weighs double and puts it down"), H.Outcome, UJamSim::ContactDown);
			TestEqual(TEXT("... for down_frames_min: the frames read the physical ratio"), H.KnockFrames, S.Cfg.Contact.DownFramesMin);
		}
	}
	return true;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamContactStandingBrace, "Jam.Core.Contact.StandingBrace", JamContactTests::Flags)
bool FJamContactStandingBrace::RunTest(const FString& Parameters)
{
	// 1. A side body check from 4 m/s on a standing skater (facing +x; the attacker comes along +z from its left): a stumble at most.
	{
		FContactScene S = Make(*this, NoEdit);
		if (!S.Ok()) return false;
		S.Sim->SetSkater(S.V, FVector2D::ZeroVector, FVector2D::ZeroVector, 0.0);
		S.Sim->SetSkater(S.A, FVector2D(0.0, -1.0), FVector2D(0.0, 4.0), PI * 0.5);
		const FContactHit H = Run(S, 12, [&](TArray<FJamInput>& In, int32 F) { In[S.A].bCheck = F == 0; });
		AddInfo(FString::Printf(TEXT("side body check from 4 m/s on a standing skater: %s"), *Facts(H)));
		TestTrue(TEXT("side body check from 4 m/s: the standing skater is hit"), H.Outcome != 0);
		TestTrue(TEXT("... and stumbles at most (the brace holds)"), H.Outcome <= UJamSim::ContactStumble && !H.bKnock);
		TestTrue(*FString::Printf(TEXT("... the ratio %.2f is under down_ratio"), H.Ratio), H.Ratio < S.Cfg.Contact.DownRatio);
	}
	// 2. A cross-check from the front at the same 4 m/s (the standing skater carries the puck: the cross-check is the lift at the carrier): down.
	// 3. The same cross-check from the side: the brace holds, a stumble.
	struct FCase { const TCHAR* Name; FVector2D From; bool bDown; };
	for (const FCase& C : { FCase{ TEXT("from the front"), FVector2D(1.0, 0.0), true }, FCase{ TEXT("from the side"), FVector2D(0.0, -1.0), false } })
	{
		FContactScene S = Make(*this, NoEdit);
		if (!S.Ok()) return false;
		S.Sim->SetSkater(S.V, FVector2D::ZeroVector, FVector2D::ZeroVector, 0.0);
		S.Sim->SetSkater(S.A, FVector2D(-10.0, -10.0), FVector2D::ZeroVector, 0.0);
		TestTrue(*FString::Printf(TEXT("%s: the standing skater carries the puck"), C.Name), HandPuck(S, S.V));
		Carry(S, S.V, FVector2D::ZeroVector, FVector2D::ZeroVector, 0.0);
		const FVector2D Dir = -C.From;
		S.Sim->SetSkater(S.A, C.From * 1.2, Dir * 4.0, FMath::Atan2(Dir.Y, Dir.X));   // a gap of 0.4 m: inside cross_reach_m 0.5
		const FContactHit H = Run(S, 6, [&](TArray<FJamInput>& In, int32 F) { In[S.A].bLift = F == 0; });
		AddInfo(FString::Printf(TEXT("cross-check from 4 m/s %s on a standing carrier: %s lift_clean %d"), C.Name, *Facts(H), H.bLiftClean ? 1 : 0));
		if (C.bDown)
		{
			TestEqual(TEXT("front cross-check from 4 m/s: the standing skater goes down (the thrust ignores the brace)"), H.Outcome, UJamSim::ContactDown);
			TestTrue(TEXT("... with the check and the knockdown events"), H.bCheck && H.bKnock);
		}
		else
		{
			TestEqual(TEXT("side cross-check from 4 m/s: the brace holds, a stumble"), H.Outcome, UJamSim::ContactStumble);
		}
		TestTrue(*FString::Printf(TEXT("%s: the carrier no longer has the puck"), C.Name), S.Sim->CarrierIndex() != S.V);
	}
	// 4. The same front cross-check pressed from the blade's length (a gap of 0.8 m, beyond cross_reach_m): the stick lift only, nobody is shoved.
	// 5. From behind at arm's length: the stick lift only (no shove, no foul).
	for (int32 Case = 0; Case < 2; ++Case)
	{
		FContactScene S = Make(*this, [](FJamGameConfig& G) { G.Rules.bPenalties = true; G.Stick.bBodyShield = false; });
		// Lane A102: stick.body_shield false here: this case is about the shove (none from behind); with the body shield a lift from behind does not take a puck held ahead (Jam.Core.Movement.BodyShield).
		if (!S.Ok()) return false;
		S.Sim->SetSkater(S.V, FVector2D::ZeroVector, FVector2D::ZeroVector, 0.0);
		S.Sim->SetSkater(S.A, FVector2D(-10.0, -10.0), FVector2D::ZeroVector, 0.0);
		TestTrue(TEXT("the standing skater carries the puck"), HandPuck(S, S.V));
		Carry(S, S.V, FVector2D::ZeroVector, FVector2D::ZeroVector, 0.0);
		const FVector2D From = Case == 0 ? FVector2D(1.6, 0.0) : FVector2D(-1.2, 0.0);
		S.Sim->SetSkater(S.A, From, -From.GetSafeNormal() * 4.0, FMath::Atan2(-From.Y, -From.X));
		const FContactHit H = Run(S, 1, [&](TArray<FJamInput>& In, int32 F) { In[S.A].bLift = F == 0; });
		bool bLift = false;
		for (const FJamSimEvent& E : S.Sim->GetFrameEvents()) if (E.Name == JamEvents::Lift && E.Who == S.A && E.Strength > 0.5f) bLift = true;
		TestTrue(Case == 0 ? TEXT("a lift from the blade's length: the puck is lifted") : TEXT("a lift from behind: the puck is lifted"), bLift);
		TestTrue(Case == 0 ? TEXT("... and nobody is shoved (beyond cross_reach_m)") : TEXT("... and nobody is shoved, no foul (a lift from behind stays a stick lift)"),
			S.Vic().ContactOutcome == 0 && !H.bCheck && !H.bKnock && H.Foul.IsNone() && S.Vic().CanAct());
	}
	// StabilityOf by the numbers (mass 80, stability_mps 6: 480 kg m/s neutral).
	{
		FContactScene S = Make(*this, NoEdit);
		const FJamContactConfig& K = S.Cfg.Contact;
		const double Base = S.Cfg.Skater.Mass * K.StabilityMps;
		S.Sim->SetSkater(S.V, FVector2D::ZeroVector, FVector2D::ZeroVector, 0.0);
		const FJamSkaterState& V = S.Vic();
		TestEqual(TEXT("standing, body hit from the side: x stand_brace"), S.Sim->StabilityOf(V, FVector2D(0, 1), UJamSim::EContactKind::Body), Base * K.StandBrace, 1e-6);
		TestEqual(TEXT("standing, body hit from the front: x stand_brace"), S.Sim->StabilityOf(V, FVector2D(-1, 0), UJamSim::EContactKind::Body), Base * K.StandBrace, 1e-6);
		TestEqual(TEXT("standing, cross-check from the front: the brace ignored"), S.Sim->StabilityOf(V, FVector2D(-1, 0), UJamSim::EContactKind::Cross), Base, 1e-6);
		TestEqual(TEXT("standing, cross-check from the side: braced"), S.Sim->StabilityOf(V, FVector2D(0, 1), UJamSim::EContactKind::Cross), Base * K.StandBrace, 1e-6);
		TestEqual(TEXT("standing, hit from behind: unbraced x unseen_stability"), S.Sim->StabilityOf(V, FVector2D(1, 0), UJamSim::EContactKind::Body), Base * K.UnseenStability, 1e-6);
		S.Sim->SetSkater(S.V, FVector2D::ZeroVector, FVector2D(S.Cfg.Skater.Speed, 0.0), 0.0);
		TestEqual(TEXT("at top speed, from the side: x speed_stability"), S.Sim->StabilityOf(S.Vic(), FVector2D(0, 1), UJamSim::EContactKind::Body), Base * K.SpeedStability, 1e-6);
	}
	return true;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamContactSprintFalls, "Jam.Core.Contact.SprintFalls", JamContactTests::Flags)
bool FJamContactSprintFalls::RunTest(const FString& Parameters)
{
	// The victim skates along +x at 5 m/s; the attacker hits it from its left at 3.5 m/s. Walking it stumbles, sprinting (Shift held, the same speed) it falls.
	FContactHit Hits[2];
	for (int32 Sprint = 0; Sprint < 2; ++Sprint)
	{
		FContactScene S = Make(*this, NoEdit);
		if (!S.Ok()) return false;
		// Two frames of the victim's own skating first, so the sprint flag is up when the hit comes; then both are placed for the contact.
		S.Sim->SetSkater(S.V, FVector2D(-0.2, 0.0), FVector2D(5.0, 0.0), 0.0);
		S.Sim->SetSkater(S.A, FVector2D(-12.0, -12.0), FVector2D::ZeroVector, 0.0);
		auto Skate = [&](TArray<FJamInput>& In) { In[S.V].Move = FVector2D(1.0, 0.0); In[S.V].bSprint = Sprint == 1; };
		Run(S, 2, [&](TArray<FJamInput>& In, int32) { Skate(In); });
		TestTrue(*FString::Printf(TEXT("%s: the sprint flag"), Sprint ? TEXT("sprinting") : TEXT("walking")), S.Vic().bSprinting == (Sprint == 1));
		S.Sim->SetSkater(S.V, FVector2D::ZeroVector, FVector2D(5.0, 0.0), 0.0);
		S.Sim->SetSkater(S.A, FVector2D(0.05, -0.9), FVector2D(5.0, 3.5), PI * 0.5);
		Hits[Sprint] = Run(S, 12, [&](TArray<FJamInput>& In, int32 F) { Skate(In); In[S.A].bCheck = F == 0; });
		AddInfo(FString::Printf(TEXT("side hit closing 3.5 m/s on a %s victim at 5 m/s: %s"), Sprint ? TEXT("sprinting") : TEXT("walking"), *Facts(Hits[Sprint])));
	}
	TestEqual(TEXT("the walking victim survives: a stumble"), Hits[0].Outcome, UJamSim::ContactStumble);
	TestEqual(TEXT("the sprinting victim falls to the same hit"), Hits[1].Outcome, UJamSim::ContactDown);
	TestTrue(*FString::Printf(TEXT("the sprint's ratio %.2f is the walk's %.2f over sprint_stability"), Hits[1].Ratio, Hits[0].Ratio), Hits[1].Ratio > Hits[0].Ratio * 1.2f);
	return true;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamContactAttackerBounces, "Jam.Core.Contact.AttackerBounces", JamContactTests::Flags)
bool FJamContactAttackerBounces::RunTest(const FString& Parameters)
{
	// A standing braced skater (facing +x). The attacker runs into its side at 5 m/s: sprinting it is the one who stumbles; walking in at 3 m/s it keeps its feet.
	FContactHit Hits[2];
	for (int32 Sprint = 0; Sprint < 2; ++Sprint)
	{
		FContactScene S = Make(*this, NoEdit);
		if (!S.Ok()) return false;
		const double V0 = Sprint ? 5.0 : 3.0;
		S.Sim->SetSkater(S.V, FVector2D::ZeroVector, FVector2D::ZeroVector, 0.0);
		S.Sim->SetSkater(S.A, FVector2D(0.0, -1.2), FVector2D(0.0, V0), PI * 0.5);
		Hits[Sprint] = Run(S, 14, [&](TArray<FJamInput>& In, int32 F) { In[S.A].Move = FVector2D(0.0, Sprint ? 1.0 : 0.3); In[S.A].bSprint = Sprint == 1; In[S.A].bCheck = F == 1; });
		AddInfo(FString::Printf(TEXT("%s into a standing braced skater's side: %s attacker stumble frames %d"), Sprint ? TEXT("sprinting at 5 m/s") : TEXT("walking at 3 m/s"), *Facts(Hits[Sprint]), Hits[Sprint].AttStumble));
		if (Sprint)
		{
			TestTrue(TEXT("the braced skater stays up"), Hits[1].Outcome != 0 && Hits[1].Outcome < UJamSim::ContactDown);
			TestTrue(TEXT("the sprinting attacker is the one who stumbles (recoil)"), Hits[1].bRecoil && Hits[1].AttStumble == S.Cfg.Contact.StaggerFrames && !S.Att().CanAct());
			TestTrue(*FString::Printf(TEXT("... and loses the speed it gave (%.2f -> %.2f m/s)"), Hits[1].AttSpeedBefore, Hits[1].AttSpeedAfter), Hits[1].AttSpeedAfter < Hits[1].AttSpeedBefore * 0.5);
		}
		else
		{
			TestTrue(TEXT("walking in at 3 m/s: no recoil, the attacker keeps its feet"), Hits[0].Outcome != 0 && !Hits[0].bRecoil && S.Att().CanAct());
		}
	}
	return true;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamContactCarrierRefused, "Jam.Core.Contact.CarrierRefused", JamContactTests::Flags)
bool FJamContactCarrierRefused::RunTest(const FString& Parameters)
{
	for (int32 CanHit = 0; CanHit < 2; ++CanHit)
	{
		FContactScene S = Make(*this, [&](FJamGameConfig& G) { G.Contact.bCarrierCanHit = CanHit == 1; });
		if (!S.Ok()) return false;
		S.Sim->SetSkater(S.A, FVector2D(-6.0, 0.0), FVector2D::ZeroVector, 0.0);
		S.Sim->SetSkater(S.V, FVector2D(10.0, 10.0), FVector2D::ZeroVector, PI);
		TestTrue(TEXT("the attacker carries the puck"), HandPuck(S, S.A));
		// Head-on at 8 m/s each with the puck on the attacker's stick: the hit that is the biggest in the game without the puck.
		Carry(S, S.A, FVector2D(-0.6, 0.0), FVector2D(8.0, 0.0), 0.0);
		S.Sim->SetSkater(S.V, FVector2D(0.6, 0.0), FVector2D(-8.0, 0.0), PI);
		const FContactHit H = Run(S, 14, [&](TArray<FJamInput>& In, int32 F) { In[S.A].bCheck = F == 0; });
		AddInfo(FString::Printf(TEXT("carrier_can_hit %d: refused %d window %d %s"), CanHit, H.bRefused ? 1 : 0, H.bWindow ? 1 : 0, *Facts(H)));
		if (!CanHit)
		{
			TestTrue(TEXT("the carrier's press is refused (bCheckRefused)"), H.bRefused);
			TestFalse(TEXT("... no check window opens, no check animation"), H.bWindow);
			TestTrue(TEXT("... the victim takes no hit: no check, no knockdown"), H.Outcome == 0 && !H.bCheck && !H.bKnock);
			TestEqual(TEXT("... counted once"), S.Att().ChecksRefused, 1);
		}
		else
		{
			TestFalse(TEXT("carrier_can_hit true: the press is not refused"), H.bRefused);
			TestTrue(TEXT("... and the carrier's check lands"), H.Outcome == UJamSim::ContactDown && H.bCheck && H.bKnock);
		}
	}
	// A take in the same breath finishes its hit: the victim carried the puck a moment ago (inside stick.foul_grace_frames), the attacker's body takes it at the
	// contact, and its check, pressed before the contact, still lands (the acceptance drill's step 7 found the refusal: A92's status, 16:17).
	{
		FContactScene S = Make(*this, NoEdit);
		S.Sim->SetSkater(S.V, FVector2D::ZeroVector, FVector2D::ZeroVector, PI);
		S.Sim->SetSkater(S.A, FVector2D(-10.0, -10.0), FVector2D::ZeroVector, 0.0);
		TestTrue(TEXT("the victim carries the puck"), HandPuck(S, S.V));
		Carry(S, S.V, FVector2D(0.7, 0.0), FVector2D(-2.5, 0.0), PI);   // the puck 0.45 m ahead of the victim: between the two bodies
		S.Sim->SetSkater(S.A, FVector2D(-0.7, 0.0), FVector2D(6.0, 0.0), 0.0);
		const FContactHit H = Run(S, 14, [&](TArray<FJamInput>& In, int32 F) { In[S.A].bCheck = F == 0; });
		AddInfo(FString::Printf(TEXT("head-on at a carrier with the puck between: refused %d %s"), H.bRefused ? 1 : 0, *Facts(H)));
		TestTrue(TEXT("a check at a carrier with the puck between the bodies lands (not refused)"), !H.bRefused && H.bCheck && H.Outcome >= UJamSim::ContactStumble);
	}
	// The same for the cross-check: the victim carried a moment ago and the puck is gone from it (parked here); the lift at arm's length from its front finds no
	// carrier, and the thrust still lands on the skater that just lost it. Once the grace is over the same press hits nobody.
	for (const int32 Wait : { 2, 30 })
	{
		FContactScene S = Make(*this, NoEdit);
		S.Sim->SetSkater(S.V, FVector2D::ZeroVector, FVector2D::ZeroVector, PI);
		S.Sim->SetSkater(S.A, FVector2D(-10.0, -10.0), FVector2D::ZeroVector, 0.0);
		TestTrue(TEXT("the victim carries the puck"), HandPuck(S, S.V));
		S.Sim->SetPuck(FVector2D(-20.0, 12.0), FVector2D::ZeroVector);
		Run(S, Wait, [](TArray<FJamInput>&, int32) {});
		S.Sim->SetSkater(S.V, FVector2D::ZeroVector, FVector2D::ZeroVector, PI);
		S.Sim->SetSkater(S.A, FVector2D(-1.2, 0.0), FVector2D(4.0, 0.0), 0.0);
		const FContactHit H = Run(S, 2, [&](TArray<FJamInput>& In, int32 F) { In[S.A].bLift = F == 0; });
		AddInfo(FString::Printf(TEXT("cross-check %d frames after the victim lost the puck: %s"), Wait, *Facts(H)));
		if (Wait <= 10) TestTrue(TEXT("a cross-check on the skater that just lost the puck still lands (inside the grace)"), H.bCheck && H.Outcome == UJamSim::ContactDown);
		else TestTrue(TEXT("... and hits nobody once the grace is over"), H.Outcome == 0 && !H.bCheck);
	}
	// The carrier's cross-check: a carrier's lift finds no opposing carrier, so it is a miss as before.
	{
		FContactScene S = Make(*this, NoEdit);
		S.Sim->SetSkater(S.A, FVector2D(-6.0, 0.0), FVector2D::ZeroVector, 0.0);
		S.Sim->SetSkater(S.V, FVector2D(10.0, 10.0), FVector2D::ZeroVector, PI);
		TestTrue(TEXT("the attacker carries the puck"), HandPuck(S, S.A));
		// the cross-check: a carrier's lift finds no opposing carrier, so it is a miss as before
		Carry(S, S.A, FVector2D(-0.7, 0.0), FVector2D(3.0, 0.0), 0.0);
		S.Sim->SetSkater(S.V, FVector2D(0.7, 0.0), FVector2D::ZeroVector, PI);
		const FContactHit H = Run(S, 8, [&](TArray<FJamInput>& In, int32 F) { In[S.A].bLift = F == 0; });
		TestTrue(TEXT("the carrier's cross-check hits nobody"), H.Outcome == 0 && !H.bCheck && !H.bKnock && !H.bLiftClean);
	}
	return true;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamContactFouls, "Jam.Core.Contact.Fouls", JamContactTests::Flags)
bool FJamContactFouls::RunTest(const FString& Parameters)
{
	auto Penalties = [](FJamGameConfig& G) { G.Rules.bPenalties = true; };
	// 1. From behind on the carrier, closing 6 m/s: the hit lands and the foul is called.
	{
		FContactScene S = Make(*this, Penalties);
		if (!S.Ok()) return false;
		S.Sim->SetSkater(S.V, FVector2D::ZeroVector, FVector2D::ZeroVector, 0.0);
		S.Sim->SetSkater(S.A, FVector2D(-10.0, -10.0), FVector2D::ZeroVector, 0.0);
		TestTrue(TEXT("the victim carries the puck"), HandPuck(S, S.V));
		Carry(S, S.V, FVector2D::ZeroVector, FVector2D(3.0, 0.0), 0.0);
		S.Sim->SetSkater(S.A, FVector2D(-0.9, 0.0), FVector2D(9.0, 0.0), 0.0);
		const FContactHit H = Run(S, 12, [&](TArray<FJamInput>& In, int32 F) { In[S.A].bCheck = F == 0; });
		AddInfo(FString::Printf(TEXT("from behind on the carrier: %s foul %s"), *Facts(H), *H.Foul.ToString()));
		TestTrue(TEXT("from behind on the carrier: the hit lands"), H.bCheck && H.Outcome >= UJamSim::ContactStumble);
		TestEqual(TEXT("... and the foul is foul_from_behind"), H.Foul.ToString(), FString(TEXT("foul_from_behind")));
		TestTrue(TEXT("... the fouler sits in the box"), S.Att().InBox());
	}
	// 2. From the front on a skater without the puck: foul_no_puck.
	{
		FContactScene S = Make(*this, Penalties);
		S.Sim->SetSkater(S.V, FVector2D(0.6, 0.0), FVector2D(-4.0, 0.0), PI);
		S.Sim->SetSkater(S.A, FVector2D(-0.6, 0.0), FVector2D(6.0, 0.0), 0.0);
		const FContactHit H = Run(S, 12, [&](TArray<FJamInput>& In, int32 F) { In[S.A].bCheck = F == 0; });
		AddInfo(FString::Printf(TEXT("from the front on a skater without the puck: %s foul %s"), *Facts(H), *H.Foul.ToString()));
		TestEqual(TEXT("a hit on a skater without the puck: foul_no_puck"), H.Foul.ToString(), FString(TEXT("foul_no_puck")));
	}
	// 3. A clean hit from the front on the carrier: no foul. And a bump from behind (same speed) is no foul either: nothing landed.
	{
		FContactScene S = Make(*this, Penalties);
		S.Sim->SetSkater(S.V, FVector2D::ZeroVector, FVector2D::ZeroVector, PI);
		S.Sim->SetSkater(S.A, FVector2D(-10.0, -10.0), FVector2D::ZeroVector, 0.0);
		TestTrue(TEXT("the victim carries the puck"), HandPuck(S, S.V));
		Carry(S, S.V, FVector2D(0.6, 0.0), FVector2D(-4.0, 0.0), PI);
		S.Sim->SetSkater(S.A, FVector2D(-0.6, 0.0), FVector2D(6.0, 0.0), 0.0);
		const FContactHit H = Run(S, 12, [&](TArray<FJamInput>& In, int32 F) { In[S.A].bCheck = F == 0; });
		TestTrue(TEXT("from the front on the carrier: the hit lands, no foul"), H.bCheck && H.Foul.IsNone());
		TestTrue(TEXT("... and the puck is loose"), S.Sim->CarrierIndex() != S.V);
	}
	{
		FContactScene S = Make(*this, Penalties);
		S.Sim->SetSkater(S.V, FVector2D::ZeroVector, FVector2D::ZeroVector, 0.0);
		S.Sim->SetSkater(S.A, FVector2D(-10.0, -10.0), FVector2D::ZeroVector, 0.0);
		TestTrue(TEXT("the victim carries the puck"), HandPuck(S, S.V));
		Carry(S, S.V, FVector2D::ZeroVector, FVector2D(8.0, 0.0), 0.0);
		S.Sim->SetSkater(S.A, FVector2D(-0.78, 0.0), FVector2D(8.0, 0.0), 0.0);
		// Lane A185 (R-0064 point 2): the pusher is a free skater with skater.free_speed_mult on its top speed and thrust; its input over that factor is
		// the same push as before the lane (top and thrust both scale with the input's size), so "the same speed" stays the scene it was.
		const double FreeIn = 0.7 / FMath::Max(1.0, S.Sim->GetConfig().Skater.FreeSpeedMult);
		const FContactHit H = Run(S, 12, [&](TArray<FJamInput>& In, int32 F) { In[S.A].bCheck = F == 0; In[S.A].Move = FVector2D(FreeIn, 0.0); In[S.V].Move = FVector2D(0.7, 0.0); });
		TestTrue(TEXT("a bump from behind at the same speed: no check, no foul"), H.Outcome == UJamSim::ContactBump && !H.bCheck && H.Foul.IsNone());
	}
	return true;
}

// The neutral block gives back the pre-vision game (re-pinned by lane A95 on the merged tree): with A92's block, A93's movement block and game.ai.sprint 0 written
// into the cartridge's text (and A93's one-sided sweep shield switch, which has no key), two regular-playtester matches replay main bb18439 (A94's brain, before
// A92 and A93; read from that commit's build, Jam.Core.MatchAlwaysEnds): hash for hash, and the model resolves nothing. A92's pins were main 8f6b157's.
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamContactNeutral, "Jam.Core.ContactNeutral", JamContactTests::Flags)
bool FJamContactNeutral::RunTest(const FString& Parameters)
{
	struct FMain { const TCHAR* Cart; const TCHAR* Level; uint64 Seed; int64 Frames; uint64 Hash; };
	for (const FMain& M : { FMain{ TEXT("hockey.boost"), TEXT("pro"), 150, 8633, 0x1a33b22080d0f0dfull }, FMain{ TEXT("hockey.regular"), TEXT("all_star"), 387, 9475, 0x59762ff73c73f6e3ull } })
	{
		FString Raw;
		if (!TestTrue(*FString::Printf(TEXT("%s reads"), M.Cart), FFileHelper::LoadFileToString(Raw, *UJamCartridge::ResolveCartridgePath(M.Cart)))) continue;
		TestEqual(TEXT("one game.skater anchor"), Raw.ReplaceInline(TEXT("\"skater\": {"), TEXT("\"contact\": {\"momentum\": false, \"carrier_can_hit\": true}, \"stick\": {\"carry_reach_mult\": 1, \"lift_cone_deg\": 180, \"sweep\": {\"sprint_shield_mult\": 1}}, ")
			TEXT("\"skater\": {\"reverse_brake_decel\": 0, \"burst\": {\"frames\": 0, \"accel_mult\": 1}, \"sprint\": {\"carry_bonus\": 0}, ")), 1);
		TestEqual(TEXT("one game.ai anchor"), Raw.ReplaceInline(TEXT("\"ai\": {"), TEXT("\"ai\": {\"sprint\": 0, ")), 1);
		TArray<FString> Errors;
		UJamCartridge* C = UJamCartridge::LoadFromString(Raw, Errors);
		for (const FString& E : Errors) AddError(FString::Printf(TEXT("neutral blocks in %s: %s"), M.Cart, *E));
		if (!C) continue;
		C->Game.Stick.bSweepShieldOneSided = true;
		C->Game.Skater.FreeSpeedMult = 1.0;   // lane A185 (track F2): no free-skater speed
		C->Game.Skater.BreakawaySpeedBonus = 0.2;   // lane A194 (track F2): the breakaway's bonus before that lane
		C->Game.Stick.bBodyShield = false; C->Game.Stick.bPassiveTake = true; C->Game.Stick.bTeammateTouchTakes = true;   // lane A102: the game before its two stick rules
		C->Game.Stick.TakeGraceFrames = 0;   // lane A121: and before the take grace (the block's burst.frames 0 and reverse_brake_decel 0 cover its other two)
		C->Game.Skater.SpinExposedTail = 0;   // lane A128: and before the spin's price (burst.frames 0 covers its standing start)
		C->Game.Contact.bPlaytesterClosingPress = false;   // lane A132: and played by the scripted human's old check press (on its own speed)
		C->Game.Stick.PokeAssistDeg = 0.0; C->Game.Stick.MissRecoveryFrames = 0;   // lane A152 (track F2): and before the poke that reaches and the miss's recovery
		C->Game.Contact.bCrossHold = false; C->Game.Contact.CheckWindupFrames = 0; C->Game.Contact.CrossWindupFrames = 0;   // lane A184: and before the held cross-check and the wind-ups
		C->Game.Contact.BotCheckWindupFrames = C->Game.Contact.BotCrossWindupFrames = -1;   // lane A200: and the bots' own
		C->Game.Contact.CheckPullM = 0.0; C->Game.Contact.bCrossAnyMan = false; C->Game.Contact.CheckReachM = 0.0;   // lane A209: and before the hit that finds its man
		C->Game.Skater.bChargeDiesOnLoss = false;   // lane A203 (track K1): and before the charge that dies with the puck
		JamBaseline::PassShotNeutral(C->Game);   // lane A207 (track P1): and before the pass by power, aimed and caught, and the doubled shot
		C->Game.Stick.PickupArcM = 0.0; C->Game.Stick.bPickupBody = false;   // lane A208 (track F0): and before the loose puck is his who touches it
		C->Game.Stick.PickupRingM = 0.0;   // lane A218 (track F0): and before the human's ring
		C->Game.Stick.FaceoffCentreGapM = 0.0; C->Game.Stick.FaceoffWinnerShieldFrames = 0; C->Game.Stick.FaceoffNoHitFrames = 0; C->Game.Puck.bNetOwnWall = false; C->Game.Puck.bNetMouthOnly = false;   // lane A208: and before the faceoff and the nets' rules
		FContactCount Count;
		JamAI::FJamSimAdapter Sim(*C);
		Count.Sim = &Sim;
		JamAI::FJamMatchConfig Cfg = JamAI::ToMatchConfigResolved(*C, M.Level);
		JamAI::EDifficulty Lv = JamAI::EDifficulty::Pro;
		JamAI::ParseDifficulty(TCHAR_TO_ANSI(M.Level), Lv);
		char Err[200] = {};
		TestTrue(TEXT("the pre-A95 profile tune applies (lane A95's profile numbers back to bb18439's)"), JamAI::ApplyDifficultyTune(JamAI::PreA95Tune(Lv, C->Game.Rink.LengthM >= JamAI::LargeRinkM), Cfg.AI, Err, sizeof(Err)));
		Count.Human = Cfg.PlayerIndex();
		const JamAI::FJamPlaytestStats S = JamAI::RunPlaytestMatch(Sim, Cfg, M.Seed, JamAI::EPlaytester::Regular, 36000, C->Game.Shot.ChargeFramesMax, false, &JamContactTests::Trace, &Count, 1);
		AddInfo(Line(*FString::Printf(TEXT("JAMCONTACT neutral %s %s seed %llu (main bb18439: %lld frames, %016llx)"), M.Cart, M.Level, M.Seed, M.Frames, M.Hash), S, Count));
		TestEqual(*FString::Printf(TEXT("%s %s: ends on main's frame"), M.Cart, M.Level), static_cast<int64>(S.Frames), M.Frames);
		TestEqual(*FString::Printf(TEXT("%s %s: the neutral blocks' match hash is main's"), M.Cart, M.Level), FString::Printf(TEXT("%016llx"), static_cast<unsigned long long>(S.Hash)),
			FString::Printf(TEXT("%016llx"), static_cast<unsigned long long>(M.Hash)));
		TestEqual(*FString::Printf(TEXT("%s %s: the model resolved nothing"), M.Cart, M.Level), Count.HitBump[0] + Count.HitBump[1] + Count.HitStumble[0] + Count.HitStumble[1] + Count.HitDown[0] + Count.HitDown[1] + Count.Refused[0] + Count.Refused[1], 0);
	}
	// The neutral block as a cartridge text loads and reads back; an unknown key in game.contact is an error.
	FString Json;
	if (TestTrue(TEXT("hockey.regular reads"), FFileHelper::LoadFileToString(Json, *UJamCartridge::ResolveCartridgePath(TEXT("hockey.regular")))))
	{
		TArray<FString> Errors;
		FString Neutral = Json;
		TestEqual(TEXT("one game.pass / game.skater anchor"), Neutral.ReplaceInline(TEXT("\"skater\": {"), TEXT("\"contact\": { \"momentum\": false, \"carrier_can_hit\": true }, \"skater\": {")), 1);
		UJamCartridge* N = UJamCartridge::LoadFromString(Neutral, Errors);
		for (const FString& E : Errors) AddError(FString::Printf(TEXT("neutral block: %s"), *E));
		if (N) TestTrue(TEXT("the neutral block reads: momentum false, carrier_can_hit true"), !N->Game.Contact.bMomentum && N->Game.Contact.bCarrierCanHit);
		UJamCartridge* D = UJamCartridge::LoadFromString(Json, Errors);
		if (D) TestTrue(TEXT("absent game.contact: the model (momentum true, carrier_can_hit false, lunge 1.5, thrust 3)"), D->Game.Contact.bMomentum && !D->Game.Contact.bCarrierCanHit
			&& D->Game.Contact.LungeMps == 1.5 && D->Game.Contact.ThrustMps == 3.0);
		FString Tuned = Json;
		Tuned.ReplaceInline(TEXT("\"skater\": {"), TEXT("\"contact\": { \"stand_brace\": 2, \"down_frames_max\": 200 }, \"skater\": {"));
		UJamCartridge* Tn = UJamCartridge::LoadFromString(Tuned, Errors);
		if (TestNotNull(TEXT("a tuned block loads"), Tn)) TestTrue(TEXT("... and reads back"), Tn->Game.Contact.StandBrace == 2.0 && Tn->Game.Contact.DownFramesMax == 200);
		FString Bad = Json;
		Bad.ReplaceInline(TEXT("\"skater\": {"), TEXT("\"contact\": { \"brace\": 2 }, \"skater\": {"));
		Errors.Reset();
		UJamCartridge* B = UJamCartridge::LoadFromString(Bad, Errors);
		TestTrue(TEXT("an unknown key in game.contact is an error"), B == nullptr || Errors.Num() > 0);
	}
	return true;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamContactMatch, "Jam.Core.ContactMatch", JamContactTests::Flags)
bool FJamContactMatch::RunTest(const FString& Parameters)
{
	for (const TCHAR* Level : { TEXT("pro"), TEXT("all_star") })
	{
		FContactCount C;
		const JamAI::FJamPlaytestStats S = Match(*this, Level, 1, C, [](FJamGameConfig&) {});
		TestEqual(*FString::Printf(TEXT("%s: the match ran its three minutes"), Level), static_cast<int64>(S.Frames), static_cast<int64>(10800));
		AddInfo(Line(*FString::Printf(TEXT("JAMCONTACT match %s seed 1"), Level), S, C));
		for (uint64 Seed = 2; Seed <= 3; ++Seed)
		{
			FContactCount Cs;
			const JamAI::FJamPlaytestStats Ss = Match(*this, Level, Seed, Cs, [](FJamGameConfig&) {});
			AddInfo(Line(*FString::Printf(TEXT("JAMCONTACT match %s seed %llu"), Level, static_cast<unsigned long long>(Seed)), Ss, Cs));
			FContactCount Cn;
			const JamAI::FJamPlaytestStats Sn = Match(*this, Level, Seed, Cn, [](FJamGameConfig& G) { G.Contact.SetNeutral(); });
			AddInfo(Line(*FString::Printf(TEXT("JAMCONTACT neutral %s seed %llu"), Level, static_cast<unsigned long long>(Seed)), Sn, Cn));
		}
		// Two runs agree (the model draws from the sim's seeded generator only).
		FContactCount C2;
		const JamAI::FJamPlaytestStats S2 = Match(*this, Level, 1, C2, [](FJamGameConfig&) {});
		TestEqual(*FString::Printf(TEXT("%s: two runs of the match agree"), Level), FString::Printf(TEXT("%016llx"), static_cast<unsigned long long>(S.Hash)), FString::Printf(TEXT("%016llx"), static_cast<unsigned long long>(S2.Hash)));
	}
	return true;
}

// A measurement, no bar of its own: the cuts that wrote skater.check_speed_min or skater.knockdown_frames, three minutes each at their own level and rules (the
// match may end earlier by its own rules), the model against the neutral block: knockdowns, stumbles and frames down.
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamContactModes, "Jam.Core.ContactModes", JamContactTests::Flags)
bool FJamContactModes::RunTest(const FString& Parameters)
{
	const TCHAR* Files[] = { TEXT("modes/hockey.mode.bruisers"), TEXT("modes/hockey.mode.fog-of-war"), TEXT("modes/hockey.mode.cage"), TEXT("modes/hockey.mode.glass-house"), TEXT("hockey.raw") };
	for (const TCHAR* F : Files)
	{
		const FString Path = FPaths::Combine(UJamCartridge::GetCartridgeDir(), FString(F) + TEXT(".cartridge.json"));
		for (int32 Neutral = 0; Neutral < 2; ++Neutral)
		{
			FContactCount C;
			int32 CheckMinX10 = 0, KnockCfg = 0;
			const JamAI::FJamPlaytestStats S = Match(*this, nullptr, 1, C, [&](FJamGameConfig& G) { if (Neutral) G.Contact.SetNeutral(); CheckMinX10 = FMath::RoundToInt32(G.Skater.CheckSpeedMin * 10.0); KnockCfg = G.Skater.KnockdownFrames; }, Path);
			AddInfo(FString::Printf(TEXT("JAMCONTACT mode %s (check_speed_min %.1f, knockdown_frames %d) %s: frames %lld goals %d:%d | knockdowns of bot %d of human %d (bot on bot %d) | stumbles bot %d human %d | ")
				TEXT("model's frames down bot %d human %d | check events by bot %d by human %d | fouls %d"), F, CheckMinX10 / 10.0, KnockCfg, Neutral ? TEXT("neutral") : TEXT("model"), static_cast<long long>(S.Frames), S.GoalsFor, S.GoalsAgainst,
				C.Downs[0], C.Downs[1], C.BotOnBotDowns, C.HitStumble[0], C.HitStumble[1], C.DownFrames[0], C.DownFrames[1], C.Checks[0], C.Checks[1], S.Fouls));
		}
	}
	return true;
}

// A measurement, no bar of its own: Jam.Bot.SeasonTakes wants the AI to shoot at least once in a match of a minute or more, on seeds 1, 2, 7. The rookie bots never
// check and never cross-check, so under the model they only take hits; this prints, for the two rookie takes over seeds 1..10, the AI's shots and the score under
// the model and under the neutral block (= main), with the same runner as that test (the scripted human, PlayerBot).
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamContactTakes, "Jam.Core.ContactTakes", JamContactTests::Flags)
bool FJamContactTakes::RunTest(const FString& Parameters)
{
	for (int32 Take = 1; Take <= 2; ++Take)
	{
		const FString Name = FString::Printf(TEXT("take-%d"), Take);
		const FString Path = FPaths::Combine(UJamCartridge::GetCartridgeDir(), TEXT("ladder"), Name + TEXT(".cartridge.json"));
		for (int32 Neutral = 0; Neutral < 2; ++Neutral)
		{
			TArray<FString> Errors;
			UJamCartridge* Cart = UJamCartridge::LoadFromFile(Path, Errors);
			if (!TestNotNull(*FString::Printf(TEXT("%s loads"), *Name), Cart)) continue;
			if (Neutral) Cart->Game.Contact.SetNeutral();
			const JamAI::FJamMatchConfig C = JamAI::ToMatchConfigResolved(*Cart);
			const int32 Pi = C.PlayerIndex();
			const int32 Team = C.Skaters[Pi].Team;
			FString Row;
			int32 Zero = 0, Total = 0, Wins = 0, GoalsFor = 0, GoalsAgainst = 0;
			for (uint64 Seed = 1; Seed <= 10; ++Seed)
			{
				JamAI::FJamSimAdapter Sim(*Cart);
				const JamAI::FJamMatchStats A = JamAI::RunMatch(Sim, C, Seed, JamAI::EJamPlayerMode::PlayerBot, 36000, 60);
				int32 AiShots = 0;
				for (int32 i = 0; i < A.NumSkaters; ++i) AiShots += i == Pi ? 0 : A.Shots[i];
				Row += FString::Printf(TEXT(" s%llu %d:%d shots %d;"), static_cast<unsigned long long>(Seed), A.Goals[Team], A.Goals[1 - Team], AiShots);
				Zero += (AiShots == 0 && A.Frames >= 3600) ? 1 : 0;
				Total += AiShots;
				Wins += (A.bOver && A.Winner == Team) ? 1 : 0;
				GoalsFor += A.Goals[Team];
				GoalsAgainst += A.Goals[1 - Team];
			}
			AddInfo(FString::Printf(TEXT("JAMCONTACT takes %s %s: AI shots total %d, matches of a minute or more without an AI shot %d of 10, human wins %d of 10, goals %d:%d |%s"), *Name,
				Neutral ? TEXT("neutral") : TEXT("model"), Total, Zero, Wins, GoalsFor, GoalsAgainst, *Row));
		}
	}
	return true;
}


// Lane A95 (B-to-A-0037): the cone on the stick lift and on the cross-check's shove (game.stick.lift_cone_deg, default 70). A standing carrier with an attacker
// standing beside it at arm's length (0.3 m between the bodies: inside contact.cross_reach_m and stick.lift_range_m), the attacker's facing turned Theta off the
// line to the carrier; one lift press. Inside the cone the lift is clean (the event's Dir is the unit vector attacker -> victim) and the thrust lands; outside it
// the swing is a miss and nothing lands. With the cone at 180 (the key's "no cone", before A95) every angle lifts.
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamLiftCone, "Jam.Core.LiftCone", JamContactTests::Flags)
bool FJamLiftCone::RunTest(const FString& Parameters)
{
	using namespace JamContactTests;
	struct FOut { bool bClean = false; bool bShove = false; FVector2D Dir = FVector2D::ZeroVector; FVector2D Want = FVector2D::ZeroVector; };
	auto Try = [&](double ConeDeg, double ThetaDeg) -> FOut
	{
		FOut O;
		FContactScene S = Make(*this, [&](FJamGameConfig& G) { G.Stick.LiftConeDeg = ConeDeg; });
		if (!S.Ok()) return O;
		S.Sim->SetSkater(S.V, FVector2D::ZeroVector, FVector2D::ZeroVector, 0.0);
		S.Sim->SetSkater(S.A, FVector2D(0.0, -20.0), FVector2D::ZeroVector, 0.0);
		if (!HandPuck(S, S.V)) { AddError(TEXT("the victim does not carry")); return O; }
		const double R = S.Sim->SkaterRadius;
		const FVector2D APos(0.0, -(2.0 * R + 0.3));   // beside the carrier (not from behind: Dir . victim's facing = 0)
		const double ToV = UE_DOUBLE_PI * 0.5;         // the line attacker -> victim is +y
		S.Sim->SetSkater(S.A, APos, FVector2D::ZeroVector, ToV + FMath::DegreesToRadians(ThetaDeg));
		O.Want = (S.Vic().Pos - APos).GetSafeNormal();
		TArray<FJamInput> In;
		In.SetNum(S.Sim->GetSkaters().Num());
		In[S.A].bLift = true;
		S.Sim->Step(In);
		for (const FJamSimEvent& E : S.Sim->GetFrameEvents())
		{
			if (E.Name == JamEvents::Lift && E.Who == S.A && E.Strength > 0.5f) { O.bClean = true; O.Dir = E.Dir; }
		}
		O.bShove = S.Vic().ContactOutcome != 0;
		return O;
	};
	for (const double Theta : { 0.0, 30.0, 60.0, 80.0, 110.0, 160.0 })
	{
		const FOut D = Try(70.0, Theta);
		const FOut N = Try(180.0, Theta);
		AddInfo(FString::Printf(TEXT("theta %.0f deg: cone 70 lift %s shove %s dir (%.2f, %.2f) | cone 180 lift %s shove %s"), Theta, D.bClean ? TEXT("clean") : TEXT("miss"), D.bShove ? TEXT("yes") : TEXT("no"),
			D.Dir.X, D.Dir.Y, N.bClean ? TEXT("clean") : TEXT("miss"), N.bShove ? TEXT("yes") : TEXT("no")));
		const bool bInside = Theta <= 70.0;
		TestEqual(*FString::Printf(TEXT("cone 70, %.0f deg: clean lift only inside"), Theta), D.bClean, bInside);
		TestEqual(*FString::Printf(TEXT("cone 70, %.0f deg: the shove lands only inside"), Theta), D.bShove, bInside);
		if (D.bClean) TestTrue(*FString::Printf(TEXT("%.0f deg: the clean lift's Dir is attacker -> victim"), Theta), D.Dir.Equals(D.Want, 0.01));
		TestTrue(*FString::Printf(TEXT("cone 180 (no cone), %.0f deg: the lift is clean"), Theta), N.bClean);
	}
	return true;
}

// ---- Lane A151 (track F1, evolution 5, docs/experiments/CONTACT-6.md): the press that lands, traced -------------------------------------------------------
//   Jam.Core.ContactPressMatch       the scripted human's check presses in ten three-minute pro matches, each read twice against the sim's check window: on
//                                    the state the playtester DECIDED on (its whole input arrives ReactionFrames later: 6 for the regular player) and on the
//                                    frame the sim got the press: the course (closest approach of the two bodies on their velocities), the frames to contact
//                                    against the window as delivered, whether the bodies had already met; a whiff frame by frame; by how the script presses
namespace JamContactTests
{
	struct FPressCourse { double Dist = 0, Closing = 0, Across = 0, Cpa = 0, Frames = -1; };
	// The course of a man at P moving at V (both relative to the presser): centres, closing along the line, speed across it, closest approach, frames to contact.
	FPressCourse CourseOf(const FVector2D& P, const FVector2D& V)
	{
		FPressCourse C;
		const double R2 = 2.0 * UJamSim::SkaterRadius;
		const FVector2D Nn = P.GetSafeNormal();
		C.Dist = P.Size();
		C.Closing = -FVector2D::DotProduct(V, Nn);
		C.Across = FMath::Abs(FVector2D::DotProduct(V, FVector2D(-Nn.Y, Nn.X)));
		const double V2 = V.SizeSquared();
		const double Tc = V2 > 1e-9 ? FMath::Max(0.0, -FVector2D::DotProduct(P, V) / V2) : 0.0;
		C.Cpa = (P + V * Tc).Size();
		if (C.Dist <= R2) C.Frames = 0.0;
		else if (C.Cpa < R2 && V2 > 1e-9)
		{
			const double Bq = FVector2D::DotProduct(P, V), Cq = P.SizeSquared() - R2 * R2;   // |P + V t| = R2: the first root
			const double Disc = Bq * Bq - V2 * Cq;
			C.Frames = Disc >= 0.0 ? 60.0 * (-Bq - FMath::Sqrt(Disc)) / V2 : -1.0;
		}
		return C;
	}

	struct FPressTrace
	{
		FContactCount Base;
		static constexpr int32 MaxSk = 16, Watch = 30, Classes = 6, Results = 5, MaxDump = 3, RingLen = 16;
		int32 Delay = 6;   // the playtester's ReactionFrames (the regular player)
		// The states after each of the last RingLen steps: entry Count - 1 is what the sim stood on when it got this frame's input, entry Count - 1 - Delay is
		// what the playtester decided that input on.
		FVector2D RingPos[RingLen][MaxSk], RingVel[RingLen][MaxSk];
		int32 RingCarrier[RingLen];
		int64 Count = 0;
		int64 LastTouch[MaxSk];   // the frame the human's body last met this skater's (centres at two radii after the step)
		int32 SeenMissed = 0, SeenSoft = 0, SeenGraced = 0;
		// The open press.
		bool bOpen = false;
		int32 Target = -1, Class = 0, Age = 0, Result = -1, MinFrame = 0, LateContact = -1, SinceTouch = 1000;
		FPressCourse Dec, Got;
		double MinDist = 0;
		TArray<FString> Lines;
		// Totals. Class, read on the DECISION state: 0 no opposing carrier, 1 off course (closest approach of the centres 0.8 m or more), 2 on course but the
		// bodies meet before the press arrives, 3 on course and the bodies meet inside the window as delivered, 4 on course but after it, 5 already touching.
		// Result: 0 landed (a check event), 1 too soft (a bump), 2 met a grace, 3 whiff, 4 the window closed some other way (the human took the puck, went down).
		int32 Presses = 0, N[Classes][Results] = {};
		int32 CpaBin[4] = {};            // whiffs off course by closest approach at the decision: 0.8-1.0, 1.0-1.3, 1.3-1.8, beyond
		int32 LateBin[3] = {};           // whiffs: the bodies met after the window, within 13-18, 19-30 frames of the press; never within 30
		int32 TouchBin[3] = {};          // whiffs: the human's body met the man's 1 to 6 frames before the press arrived, 7 to 12, not within 12
		int32 GotApart = 0, GotOff = 0;  // whiffs: on the frame the sim got the press the two were already separating; were off course
		double SumDecDist = 0, SumDecClosing = 0, SumDecCpa = 0, SumGotDist = 0, SumGotClosing = 0, SumMinDist = 0;
		int32 WhiffsWithMan = 0;
		TArray<FString> Dumps;
		int64 Last = -1;
		void Reset() { Count = 0; Last = -1; bOpen = false; SeenMissed = SeenSoft = SeenGraced = 0; for (int64& T : LastTouch) T = -1000; }
	};

	void TracePress(void* Ctx, const JamAI::FJamAIWorld& W, const JamAI::FJamAIInput* In, const JamAI::FJamBrain& B, int64_t F, bool bTouch)
	{
		FPressTrace& R = *static_cast<FPressTrace*>(Ctx);
		const UJamSim* Sim = R.Base.Sim->GetSim();
		if (Sim && Sim->GetFrame() != R.Last && Sim->GetSkaters().IsValidIndex(R.Base.Human) && R.Base.Human < FPressTrace::MaxSk)
		{
			R.Last = Sim->GetFrame();
			const TArray<FJamSkaterState>& Sk = Sim->GetSkaters();
			const FJamSkaterState& H = Sk[R.Base.Human];
			const int32 Hi = R.Base.Human;
			const double R2 = 2.0 * UJamSim::SkaterRadius;
			bool bCheckEvent = false;
			for (const FJamSimEvent& E : Sim->GetFrameEvents()) if (E.Name == JamEvents::Check && E.Who == Hi) bCheckEvent = true;
			auto LineOf = [&](int32 Age) -> FString
			{
				const FJamSkaterState* O = Sk.IsValidIndex(R.Target) ? &Sk[R.Target] : nullptr;
				const FVector2D To = O ? O->Pos - H.Pos : FVector2D::ZeroVector;
				const FVector2D Nn = To.GetSafeNormal();
				const FVector2D Mv(In[Hi].Move.X, In[Hi].Move.Y);
				return FString::Printf(TEXT("  +%02d window %2d | human at (%6.2f, %6.2f) vel (%6.2f, %6.2f) push (%5.2f, %5.2f)%s%s | man at (%6.2f, %6.2f) vel (%6.2f, %6.2f)%s | centres %.2f m closing %6.2f m/s | puck at (%6.2f, %6.2f) carrier %d"),
					Age, H.CheckWindow, H.Pos.X, H.Pos.Y, H.Vel.X, H.Vel.Y, Mv.X, Mv.Y, In[Hi].bPoke ? TEXT(" POKE") : TEXT(""), H.IsStumbling() ? TEXT(" stumbling") : TEXT(""),
					O ? O->Pos.X : 0.0, O ? O->Pos.Y : 0.0, O ? O->Vel.X : 0.0, O ? O->Vel.Y : 0.0, O && O->IsDown() ? TEXT(" down") : TEXT(""), To.Size(),
					O ? FVector2D::DotProduct(H.Vel - O->Vel, Nn) : 0.0, Sim->GetPuck().Pos.X, Sim->GetPuck().Pos.Y, Sim->CarrierIndex());
			};
			if (H.bCheckThisFrame && R.Count > R.Delay + 1)
			{
				// A new press (the playtester leaves 30 frames between presses, so no window is open).
				++R.Presses;
				R.bOpen = true; R.Age = 0; R.Result = -1; R.LateContact = -1; R.Lines.Reset(); R.MinDist = 1e9; R.MinFrame = 0; R.SinceTouch = 1000;
				const int32 Dx = static_cast<int32>((R.Count - 1 - R.Delay) % FPressTrace::RingLen), Gx = static_cast<int32>((R.Count - 1) % FPressTrace::RingLen);
				const int32 Dc = R.RingCarrier[Dx];
				R.Target = Dc >= 0 && Dc < FPressTrace::MaxSk && Sk.IsValidIndex(Dc) && Sk[Dc].Team != H.Team ? Dc : -1;
				R.Class = 0; R.Dec = FPressCourse(); R.Got = FPressCourse();
				if (R.Target >= 0)
				{
					R.Dec = CourseOf(R.RingPos[Dx][R.Target] - R.RingPos[Dx][Hi], R.RingVel[Dx][R.Target] - R.RingVel[Dx][Hi]);
					R.Got = CourseOf(R.RingPos[Gx][R.Target] - R.RingPos[Gx][Hi], R.RingVel[Gx][R.Target] - R.RingVel[Gx][Hi]);
					R.Class = R.Dec.Dist <= R2 ? 5 : R.Dec.Frames < 0.0 ? 1 : R.Dec.Frames <= R.Delay ? 2 : R.Dec.Frames <= R.Delay + UJamSim::HumanCheckWindowFrames ? 3 : 4;
					R.SinceTouch = static_cast<int32>(FMath::Min<int64>(1000, Sim->GetFrame() - R.LastTouch[R.Target]));
					static const TCHAR* Names[] = { TEXT(""), TEXT("OFF COURSE"), TEXT("ON COURSE, THE BODIES MEET BEFORE THE PRESS ARRIVES"), TEXT("ON COURSE, INSIDE THE WINDOW"), TEXT("ON COURSE, AFTER THE WINDOW"), TEXT("TOUCHING") };
					R.Lines.Add(FString::Printf(TEXT("  decided %d frames before, on: centres %.2f m, closing %.2f m/s along the line, %.2f m/s across it, closest approach of the centres %.2f m (contact under %.2f), contact in %.1f frames (the window as delivered: frames %d to %d) => %s"),
						R.Delay, R.Dec.Dist, R.Dec.Closing, R.Dec.Across, R.Dec.Cpa, R2, R.Dec.Frames, R.Delay + 1, R.Delay + UJamSim::HumanCheckWindowFrames, Names[R.Class]));
					R.Lines.Add(FString::Printf(TEXT("  the sim got it on: centres %.2f m, closing %.2f m/s, closest approach %.2f m, contact in %.1f frames; the bodies last met %d frames before"),
						R.Got.Dist, R.Got.Closing, R.Got.Cpa, R.Got.Frames, R.SinceTouch >= 1000 ? -1 : R.SinceTouch));
				}
			}
			if (R.bOpen)
			{
				if (R.Target >= 0)
				{
					const double D = FVector2D::Distance(Sk[R.Target].Pos, H.Pos);
					if (D < R.MinDist && R.Result < 0) { R.MinDist = D; R.MinFrame = R.Age; }
					if (R.Result == 3 && R.LateContact < 0 && D <= R2 + 1e-3) R.LateContact = R.Age;
				}
				if (R.Lines.Num() < FPressTrace::Watch + 3) R.Lines.Add(LineOf(R.Age));
				if (R.Result < 0)
				{
					if (bCheckEvent) R.Result = 0;
					else if (H.ChecksSoft > R.SeenSoft) R.Result = 1;
					else if (H.ChecksGraced > R.SeenGraced) R.Result = 2;
					else if (H.ChecksMissed > R.SeenMissed) R.Result = 3;
					else if (H.CheckWindow == 0) R.Result = 4;
					if (R.Result >= 0)
					{
						++R.N[R.Class][R.Result];
						if (R.Result == 3 && R.Target >= 0)
						{
							++R.WhiffsWithMan;
							R.SumDecDist += R.Dec.Dist; R.SumDecClosing += R.Dec.Closing; R.SumDecCpa += R.Dec.Cpa; R.SumGotDist += R.Got.Dist; R.SumGotClosing += R.Got.Closing; R.SumMinDist += R.MinDist;
							if (R.Class == 1) ++R.CpaBin[R.Dec.Cpa < 1.0 ? 0 : R.Dec.Cpa < 1.3 ? 1 : R.Dec.Cpa < 1.8 ? 2 : 3];
							++R.TouchBin[R.SinceTouch <= 6 ? 0 : R.SinceTouch <= 12 ? 1 : 2];
							if (R.Got.Closing < 0.0) ++R.GotApart;
							if (R.Got.Frames < 0.0) ++R.GotOff;
						}
						if (R.Result != 3) R.bOpen = false;
					}
				}
				if (R.bOpen && R.Result == 3 && (R.Age >= FPressTrace::Watch || R.LateContact >= 0))
				{
					++R.LateBin[R.LateContact < 0 ? 2 : R.LateContact <= 18 ? 0 : 1];
					if (R.Dumps.Num() < FPressTrace::MaxDump && R.Target >= 0)
					{
						FString D = FString::Printf(TEXT("JAMPRESS WHIFF frame by frame (the sim got the press at frame %lld; the man = skater %d, the opposing carrier when it was decided):\n"), static_cast<long long>(Sim->GetFrame() - R.Age), R.Target);
						for (int32 i = 0; i < R.Lines.Num() && i < 16; ++i) D += R.Lines[i] + TEXT("\n");
						D += FString::Printf(TEXT("  => closest the centres came inside the window: %.2f m at +%d; bodies met after the window: %s"), R.MinDist, R.MinFrame, R.LateContact >= 0 ? *FString::Printf(TEXT("at +%d"), R.LateContact) : TEXT("not within 30 frames"));
						R.Dumps.Add(D);
					}
					R.bOpen = false;
				}
				++R.Age;
			}
			R.SeenMissed = H.ChecksMissed; R.SeenSoft = H.ChecksSoft; R.SeenGraced = H.ChecksGraced;
			const int32 Wx = static_cast<int32>(R.Count % FPressTrace::RingLen);
			for (const FJamSkaterState& S : Sk)
			{
				if (S.Index >= FPressTrace::MaxSk) continue;
				R.RingPos[Wx][S.Index] = S.Pos; R.RingVel[Wx][S.Index] = S.Vel;
				if (S.Team != H.Team && !S.IsDown() && FVector2D::Distance(S.Pos, H.Pos) <= R2 + 1e-4) R.LastTouch[S.Index] = Sim->GetFrame();
			}
			R.RingCarrier[Wx] = Sim->CarrierIndex();
			++R.Count;
		}
		Trace(&R.Base, W, In, B, F, bTouch);
	}

	JamAI::FJamPlaytestStats MatchPress(FAutomationTestBase& T, const TCHAR* Level, uint64 Seed, FPressTrace& R, TFunctionRef<void(FJamGameConfig&)> Edit, int64 Frames = 10800)
	{
		TArray<FString> Errors;
		UJamCartridge* C = UJamCartridge::LoadFromFile(UJamCartridge::ResolveCartridgePath(TEXT("hockey.regular")), Errors);
		for (const FString& E : Errors) T.AddError(FString::Printf(TEXT("hockey.regular: %s"), *E));
		if (!C) return JamAI::FJamPlaytestStats();
		C->Game.Rules.ScoreToWin = 99;
		C->Game.Rules.bPenalties = false;
		C->Game.Contact.bCrossHold = false;   // lane A184: these matches measure the check press; with the held cross-check on the scripted human braces instead
		Edit(C->Game);
		JamAI::FJamSimAdapter Sim(*C);
		R.Base = FContactCount();
		R.Base.Sim = &Sim;
		R.Reset();
		JamAI::FJamMatchConfig M = JamAI::ToMatchConfigResolved(*C, Level);
		R.Base.Human = M.PlayerIndex();
		R.Delay = JamAI::PlaytesterProfile(JamAI::EPlaytester::Regular).ReactionFrames;
		return JamAI::RunPlaytestMatch(Sim, M, Seed, JamAI::EPlaytester::Regular, Frames, C->Game.Shot.ChargeFramesMax, false, &TracePress, &R, 1);
	}

	void ReportPress(FAutomationTestBase& T, const TCHAR* Arm, const FPressTrace& R, int32 Seeds, int32 Landed, int32& OutWhiffs, int32& OutPresses, int32& OutLanded)
	{
		static const TCHAR* ClassNames[] = { TEXT("no opposing carrier when decided"), TEXT("off course"), TEXT("on course, the bodies meet before the press arrives"), TEXT("on course, inside the window as delivered"),
			TEXT("on course, after the window"), TEXT("touching when decided") };
		int32 ByResult[FPressTrace::Results] = {};
		for (int32 c = 0; c < FPressTrace::Classes; ++c) for (int32 r = 0; r < FPressTrace::Results; ++r) ByResult[r] += R.N[c][r];
		OutWhiffs = ByResult[3]; OutPresses = R.Presses; OutLanded = ByResult[0];
		T.AddInfo(FString::Printf(TEXT("JAMPRESS TOTAL %s, %d three-minute pro matches: presses %d (a match %.1f) | landed %d = %.1f %% (a match %.2f) | too soft %d | met a grace %d | WHIFF %d = %.1f %% | closed otherwise %d | check events of the human %d"),
			Arm, Seeds, R.Presses, static_cast<double>(R.Presses) / Seeds, ByResult[0], R.Presses > 0 ? 100.0 * ByResult[0] / R.Presses : 0.0, static_cast<double>(ByResult[0]) / Seeds, ByResult[1], ByResult[2], ByResult[3],
			R.Presses > 0 ? 100.0 * ByResult[3] / R.Presses : 0.0, ByResult[4], Landed));
		for (int32 c = 0; c < FPressTrace::Classes; ++c)
		{
			const int32 All = R.N[c][0] + R.N[c][1] + R.N[c][2] + R.N[c][3] + R.N[c][4];
			T.AddInfo(FString::Printf(TEXT("JAMPRESS CLASS %s | by the state the press was DECIDED on (%d frames before the sim got it): %s: presses %d -> landed %d, too soft %d, grace %d, whiff %d, other %d"),
				Arm, R.Delay, ClassNames[c], All, R.N[c][0], R.N[c][1], R.N[c][2], R.N[c][3], R.N[c][4]));
		}
		const int32 Wm = FMath::Max(1, R.WhiffsWithMan);
		T.AddInfo(FString::Printf(TEXT("JAMPRESS WHIFFS %s: %d whiffs at a man | the means when DECIDED: centres %.2f m, closing %.2f m/s, closest approach %.2f m | when the sim GOT the press: centres %.2f m, closing %.2f m/s; already separating %d, off course %d | ")
			TEXT("closest the centres came inside the window %.2f m | off course when decided, by the closest approach: 0.8 to 1.0 m %d, 1.0 to 1.3 m %d, 1.3 to 1.8 m %d, beyond %d | ")
			TEXT("the bodies had met 1 to 6 frames before the press arrived %d, 7 to 12 frames %d, not within 12 %d | the bodies met after the window within 13 to 18 frames of the press %d, 19 to 30 %d, not within 30 %d"),
			Arm, R.WhiffsWithMan, R.SumDecDist / Wm, R.SumDecClosing / Wm, R.SumDecCpa / Wm, R.SumGotDist / Wm, R.SumGotClosing / Wm, R.GotApart, R.GotOff, R.SumMinDist / Wm,
			R.CpaBin[0], R.CpaBin[1], R.CpaBin[2], R.CpaBin[3], R.TouchBin[0], R.TouchBin[1], R.TouchBin[2], R.LateBin[0], R.LateBin[1], R.LateBin[2]));
		for (const FString& D : R.Dumps) T.AddInfo(D);
	}
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamContactPressMatch, "Jam.Core.ContactPressMatch", JamContactTests::Flags)
bool FJamContactPressMatch::RunTest(const FString& Parameters)
{
	// Ten matches show the mechanism (which state a press is decided on, what the sim gets); the shares are decided on 600 matches a cell
	// (tools/perf/results/a151, check_presses and check_whiffs on the playtest line), never on these ten (the Director, 14 Nov 01:55).
	const int32 Seeds = 10;
	struct FArm { const TCHAR* Name; bool bCourse; int32 Late; };
	const FArm Arms[] = { { TEXT("the press on closing speed inside 1.8 m (lane A132)"), false, 0 }, { TEXT("the press on course and time"), true, 0 },
		{ TEXT("the press on closing speed, the late press 6 frames"), false, 6 } };
	int32 Whiffs[3] = { 0, 0, 0 }, Presses[3] = { 0, 0, 0 }, Lands[3] = { 0, 0, 0 };
	int32 ArmIndex = 0;
	for (const FArm& Arm : Arms)
	{
		FPressTrace* R = new FPressTrace();
		int32 Landed = 0;
		for (uint64 Seed = 1; Seed <= Seeds; ++Seed)
		{
			const JamAI::FJamPlaytestStats S = MatchPress(*this, TEXT("pro"), Seed, *R, [&Arm](FJamGameConfig& G) { G.Contact.bPlaytesterCoursePress = Arm.bCourse; G.Contact.LatePressFrames = Arm.Late; G.Contact.StandSideBrace = 0.0; G.Contact.bBraceExchange = false; });
			Landed += S.ChecksLanded;
			AddInfo(FString::Printf(TEXT("JAMPRESS match %s pro seed %llu: frames %lld hash %016llx goals %d:%d | check_presses %d check_whiffs %d checks_landed %d"), Arm.Name, static_cast<unsigned long long>(Seed),
				static_cast<long long>(S.Frames), static_cast<unsigned long long>(S.Hash), S.GoalsFor, S.GoalsAgainst, S.CheckPresses, S.CheckWhiffs, S.ChecksLanded));
		}
		ReportPress(*this, Arm.Name, *R, Seeds, Landed, Whiffs[ArmIndex], Presses[ArmIndex], Lands[ArmIndex]);
		TestTrue(*FString::Printf(TEXT("%s: the scripted human pressed its check"), Arm.Name), Presses[ArmIndex] > 0);
		delete R;
		++ArmIndex;
	}
	AddInfo(FString::Printf(TEXT("JAMPRESS BAR (ten matches: the mechanism, not the verdict): whiffs %d of %d = %.1f %% on closing speed, %d of %d = %.1f %% on course and time, %d of %d = %.1f %% on closing speed with the late press; landed a match %.2f / %.2f / %.2f"),
		Whiffs[0], Presses[0], Presses[0] ? 100.0 * Whiffs[0] / Presses[0] : 0.0, Whiffs[1], Presses[1], Presses[1] ? 100.0 * Whiffs[1] / Presses[1] : 0.0, Whiffs[2], Presses[2], Presses[2] ? 100.0 * Whiffs[2] / Presses[2] : 0.0,
		static_cast<double>(Lands[0]) / Seeds, static_cast<double>(Lands[1]) / Seeds, static_cast<double>(Lands[2]) / Seeds));
	// The Director, 14 Nov 02:27: a statistic over a handful of matches is a logged line, never an assertion. The two reads below are logged; the shares are
	// decided on the 600-match cells (CONTACT-6.md section 2), and this test pins no hash of a shipped cut's match.
	AddInfo(FString::Printf(TEXT("JAMPRESS READ (logged, not asserted): on course and time the script whiffs %s as often as on closing speed; with the late press the old press whiffs %s"),
		Presses[0] > 0 && Presses[1] > 0 && 2.0 * Whiffs[1] / Presses[1] < static_cast<double>(Whiffs[0]) / Presses[0] ? TEXT("less than half") : TEXT("NOT less than half"), Whiffs[2] < Whiffs[0] ? TEXT("less") : TEXT("NOT less")));
	return true;
}

// ---- Lane A151 (track F1, evolution 5, CONTACT-6.md section 3): a standing skater is braced, not a wall and not a rocket ---------------------------------
//   Jam.Core.Contact.StandingSides   a standing skater hit at 9 m/s closing from the side, the front and behind, pressed and unpressed, before the rule
//                                    (contact.StandSideBrace 0, bBraceExchange false: the equal bounce) and with it: from the side it holds (a bump, under
//                                    2 m/s after), from the front it goes down, from behind it goes down for longer, and the attacker pays
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamContactStandingSides, "Jam.Core.Contact.StandingSides", JamContactTests::Flags)
bool FJamContactStandingSides::RunTest(const FString& Parameters)
{
	struct FOut { int32 Outcome = 0, Knock = 0, VicStumble = 0, AttStumble = 0, Frame = -1; float Ratio = 0.f; double VicAfter = 0, AttAfter = 0, AttBefore = 0, AttAlongAfter = 0; bool bRecoil = false, bMet = false; };
	struct FArm { const TCHAR* Name; double Side; bool bExchange; };
	const FArm Arms[] = { { TEXT("before (side brace 0, equal bounce)"), 0.0, false }, { TEXT("side brace 5 alone"), 5.0, false }, { TEXT("the braced bounce alone"), 0.0, true }, { TEXT("the rule (side brace 5, braced bounce)"), 5.0, true } };
	struct FCase { const TCHAR* Name; FVector2D From; double Speed; bool bPress; };
	// The victim stands at the centre dot facing +x. From = where the attacker starts (1.3 m out: a gap of 0.5 m); it glides at the victim at Speed.
	const FCase Cases[] = {
		{ TEXT("side, pressed, 9 m/s"), FVector2D(0.0, -1.3), 9.0, true },
		{ TEXT("front, pressed, 9 m/s"), FVector2D(1.3, 0.0), 9.0, true },
		{ TEXT("behind, pressed, 9 m/s"), FVector2D(-1.3, 0.0), 9.0, true },
		{ TEXT("side, no press, 9 m/s"), FVector2D(0.0, -1.3), 9.0, false },
		{ TEXT("front, no press, 9 m/s"), FVector2D(1.3, 0.0), 9.0, false },
		{ TEXT("behind, no press, 9 m/s"), FVector2D(-1.3, 0.0), 9.0, false },
		{ TEXT("side, pressed, 11 m/s (top speed)"), FVector2D(0.0, -1.3), 11.0, true },
		{ TEXT("15 degrees ahead of the side, pressed, 9 m/s"), FVector2D(0.3365, -1.2557), 9.0, true },
		{ TEXT("front, pressed, 4 m/s"), FVector2D(1.3, 0.0), 4.0, true },
		{ TEXT("side, pressed, 4 m/s"), FVector2D(0.0, -1.3), 4.0, true },
	};
	constexpr int32 NumCases = UE_ARRAY_COUNT(Cases), NumArms = UE_ARRAY_COUNT(Arms);
	FOut Out[NumArms][NumCases];
	for (int32 a = 0; a < NumArms; ++a)
	{
		for (int32 c = 0; c < NumCases; ++c)
		{
			const FArm& Arm = Arms[a];
			const FCase& K = Cases[c];
			FOut& O = Out[a][c];
			FContactScene S = Make(*this, [&Arm](FJamGameConfig& G) { G.Contact.StandSideBrace = Arm.Side; G.Contact.bBraceExchange = Arm.bExchange; });
			if (!S.Ok()) return false;
			S.Sim->SetSkater(S.V, FVector2D::ZeroVector, FVector2D::ZeroVector, 0.0);
			const FVector2D Dir = -K.From.GetSafeNormal();
			S.Sim->SetSkater(S.A, K.From, Dir * K.Speed, FMath::Atan2(Dir.Y, Dir.X));
			for (int32 F = 0; F < 24 && !O.bMet; ++F)
			{
				TArray<FJamInput> In;
				In.SetNum(S.Sim->GetSkaters().Num());
				In[S.A].bCheck = K.bPress && F == 0;
				O.AttBefore = S.Att().Vel.Size();
				S.Sim->Step(In);
				if (S.Vic().Vel.Size() > 1e-3 || S.Vic().ContactOutcome != 0 || S.Vic().IsDown())
				{
					O.bMet = true; O.Frame = F;
					O.Outcome = S.Vic().ContactOutcome; O.Ratio = S.Vic().ContactRatio; O.Knock = S.Vic().KnockFrames; O.VicStumble = S.Vic().StumbleFrames;
					O.AttStumble = S.Att().StumbleFrames; O.bRecoil = S.Att().bRecoilThisFrame;
					O.VicAfter = S.Vic().Vel.Size(); O.AttAfter = S.Att().Vel.Size(); O.AttAlongAfter = FVector2D::DotProduct(S.Att().Vel, Dir);
				}
			}
			AddInfo(FString::Printf(TEXT("JAMSTAND %s | %s: %s ratio %.2f | the standing skater leaves at %.2f m/s%s | the attacker %.2f -> %.2f m/s (%.2f along its way)%s | met at frame %d"), Arm.Name, K.Name,
				!O.bMet ? TEXT("NO CONTACT") : O.Outcome == UJamSim::ContactDown ? TEXT("DOWN") : O.Outcome == UJamSim::ContactStumble ? TEXT("STUMBLE") : O.Outcome == UJamSim::ContactBump ? TEXT("BUMP") : TEXT("no hit (a collision)"),
				O.Ratio, O.VicAfter, O.Knock > 0 ? *FString::Printf(TEXT(", down %d frames"), O.Knock) : O.VicStumble > 0 ? *FString::Printf(TEXT(", stumbling %d frames"), O.VicStumble) : TEXT(", on its feet"),
				O.AttBefore, O.AttAfter, O.AttAlongAfter, O.bRecoil ? *FString::Printf(TEXT(", RECOILS: stumbling %d frames"), O.AttStumble) : TEXT(""), O.Frame));
			TestTrue(*FString::Printf(TEXT("%s | %s: the two met"), Arm.Name, K.Name), O.bMet);
		}
	}
	// The shipped values (JamCartridge.h): the side brace 5, the braced bounce on. Make() switches both off for the older scenes; the arms above set them.
	TestEqual(TEXT("the shipped side brace"), FJamContactConfig().StandSideBrace, 5.0, 1e-12);
	TestTrue(TEXT("the shipped bounce is the braced one"), FJamContactConfig().bBraceExchange);
	// Before: the equal bounce gives the standing skater 0.6 x the closing speed whatever the law said, and a pressed side hit at 9 m/s fells it (ratio 1.17).
	TestTrue(*FString::Printf(TEXT("before: an unpressed 9 m/s collision from the side leaves the standing skater at 0.6 x the closing speed (%.2f m/s)"), Out[0][3].VicAfter), FMath::Abs(Out[0][3].VicAfter - 0.6 * Out[0][3].AttBefore) < 0.05);
	TestEqual(TEXT("before: a pressed side hit at 9 m/s fells the standing skater"), Out[0][0].Outcome, UJamSim::ContactDown);
	// The rule.
	const FOut* R = Out[3];
	TestEqual(TEXT("the rule: from the side at 9 m/s a standing skater holds: a bump"), R[0].Outcome, UJamSim::ContactBump);
	TestTrue(*FString::Printf(TEXT("... ratio under bump_ratio 0.4 (%.2f)"), R[0].Ratio), R[0].Ratio < 0.4f);
	TestTrue(*FString::Printf(TEXT("... and leaves the hit under 2 m/s (%.2f)"), R[0].VicAfter), R[0].VicAfter < 2.0);
	TestTrue(*FString::Printf(TEXT("... and the attacker pays: it recoils (stumbling %d frames) and is all but stopped (%.2f m/s)"), R[0].AttStumble, R[0].AttAfter), R[0].bRecoil && R[0].AttStumble > 0 && R[0].AttAfter < 2.0);
	TestEqual(TEXT("the rule: from the front at 9 m/s the standing skater goes down"), R[1].Outcome, UJamSim::ContactDown);
	TestEqual(TEXT("... with the ratio it had before (the front keeps stand_brace)"), static_cast<double>(R[1].Ratio), static_cast<double>(Out[0][1].Ratio), 1e-6);
	TestEqual(TEXT("the rule: from behind at 9 m/s the standing skater goes down"), R[2].Outcome, UJamSim::ContactDown);
	TestTrue(*FString::Printf(TEXT("... for longer than from the front (%d against %d frames)"), R[2].Knock, R[1].Knock), R[2].Knock > R[1].Knock);
	TestEqual(TEXT("... exactly as before (unseen: no brace either way)"), R[2].Knock, Out[0][2].Knock);
	TestTrue(*FString::Printf(TEXT("the rule: an unpressed 9 m/s collision from the side moves the standing skater under 2 m/s (%.2f; before %.2f)"), R[3].VicAfter, Out[0][3].VicAfter), R[3].VicAfter < 2.0 && R[3].VicAfter > 0.0);
	TestTrue(*FString::Printf(TEXT("... and stops the one who ran into it (%.2f m/s along its way; before %.2f)"), R[3].AttAlongAfter, Out[0][3].AttAlongAfter), FMath::Abs(R[3].AttAlongAfter) < 1.0);
	TestEqual(TEXT("the rule: an unpressed collision from behind is the equal bounce (unseen: no brace)"), R[5].VicAfter, Out[0][5].VicAfter, 1e-9);
	TestTrue(*FString::Printf(TEXT("the rule: not a wall: from the side at top speed (11 m/s) the standing skater stumbles (outcome %d, ratio %.2f)"), R[6].Outcome, R[6].Ratio), R[6].Outcome == UJamSim::ContactStumble);
	TestTrue(*FString::Printf(TEXT("the rule: between side and front the brace falls off (15 degrees ahead of the side: ratio %.2f between the side %.2f and the front %.2f)"), R[7].Ratio, R[0].Ratio, R[1].Ratio),
		R[7].Ratio > R[0].Ratio && R[7].Ratio < R[1].Ratio);
	// The carrier is not braced from the side (law 3's gate): the same pressed side hit at 9 m/s on a standing CARRIER is what it was before the lane.
	{
		FContactScene S = Make(*this, [](FJamGameConfig& G) { G.Contact.StandSideBrace = 5.0; G.Contact.bBraceExchange = true; });
		if (!S.Ok()) return false;
		S.Sim->SetSkater(S.V, FVector2D::ZeroVector, FVector2D::ZeroVector, 0.0);
		S.Sim->SetSkater(S.A, FVector2D(-10.0, -10.0), FVector2D::ZeroVector, 0.0);
		TestTrue(TEXT("the standing skater carries the puck"), HandPuck(S, S.V));
		Carry(S, S.V, FVector2D::ZeroVector, FVector2D::ZeroVector, 0.0);
		S.Sim->SetSkater(S.A, FVector2D(0.0, -1.3), FVector2D(0.0, 9.0), PI * 0.5);
		const FContactHit H = Run(S, 12, [&](TArray<FJamInput>& In, int32 F) { In[S.A].bCheck = F == 0; });
		AddInfo(FString::Printf(TEXT("JAMSTAND the rule | side, pressed, 9 m/s, the standing skater CARRIES the puck: %s"), *Facts(H)));
		TestEqual(TEXT("the rule: a standing CARRIER hit from the side at 9 m/s goes down, as before the lane"), H.Outcome, UJamSim::ContactDown);
		TestEqual(TEXT("... with the ratio it had (stand_brace, no side brace with the puck)"), static_cast<double>(H.Ratio), static_cast<double>(Out[0][0].Ratio), 1e-2);
	}
	// Each half alone: the side brace decides the outcome, the braced bounce decides the speed.
	TestEqual(TEXT("side brace alone: a bump from the side at 9 m/s"), Out[1][0].Outcome, UJamSim::ContactBump);
	TestTrue(*FString::Printf(TEXT("the braced bounce alone: the unpressed side collision moves the standing skater less (%.2f against %.2f m/s)"), Out[2][3].VicAfter, Out[0][3].VicAfter), Out[2][3].VicAfter < Out[0][3].VicAfter);
	return true;
}

// ---- Lane A151 (track F1, evolution 5, CONTACT-6.md section 2): the late press --------------------------------------------------------------------------
//   Jam.Core.Contact.LatePress       contact.LatePressFrames 6: a human's check pressed 1 to 6 frames after its body met an opponent's with no check open is
//                                    that hit (the outcome and the ratio of the press made in time); a press 7 frames after opens a window and runs out;
//                                    0 (the neutral value) = no such press; a bot's late press is nothing
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamContactLatePress, "Jam.Core.Contact.LatePress", JamContactTests::Flags)
bool FJamContactLatePress::RunTest(const FString& Parameters)
{
	struct FLate { int32 ContactFrame = -1, HitFrame = -1, Outcome = 0, Knock = 0, ChecksLate = 0, Missed = 0, VicLate = 0, AttOutcome = 0, LateLeftAfterContact = 0; float Ratio = 0.f; double VicAfter = 0, AttAfter = 0; bool bCheck = false; };
	// The victim stands at the centre dot facing +x; the human glides at it head-on at 9 m/s from 1.3 m (a gap of 0.5 m: the bodies meet in the fourth step).
	// PressAt = the frame of the press (-1 none); bVictim = the standing bot presses instead of the human.
	auto Play = [this](const TCHAR* Name, int32 LateFrames, int32 PressAt, bool bVictim) -> FLate
	{
		FLate O;
		FContactScene S = Make(*this, [LateFrames](FJamGameConfig& G) { G.Contact.LatePressFrames = LateFrames; });
		if (!S.Ok()) return O;
		S.Sim->SetSkater(S.V, FVector2D::ZeroVector, FVector2D::ZeroVector, 0.0);
		S.Sim->SetSkater(S.A, FVector2D(1.3, 0.0), FVector2D(-9.0, 0.0), PI);
		for (int32 F = 0; F < 32; ++F)
		{
			TArray<FJamInput> In;
			In.SetNum(S.Sim->GetSkaters().Num());
			In[bVictim ? S.V : S.A].bCheck = F == PressAt;
			S.Sim->Step(In);
			for (const FJamSimEvent& E : S.Sim->GetFrameEvents()) if (E.Name == JamEvents::Check && E.Who == S.A) O.bCheck = true;
			if (O.ContactFrame < 0 && S.Vic().Vel.Size() > 1e-3) { O.ContactFrame = F; O.LateLeftAfterContact = S.Att().LateFrames; }
			if (O.HitFrame < 0 && S.Vic().ContactOutcome != 0)
			{
				O.HitFrame = F; O.Outcome = S.Vic().ContactOutcome; O.Ratio = S.Vic().ContactRatio; O.Knock = S.Vic().KnockFrames;
				O.VicAfter = S.Vic().Vel.Size(); O.AttAfter = S.Att().Vel.Size();
			}
			if (S.Att().ContactOutcome != 0) O.AttOutcome = S.Att().ContactOutcome;
		}
		O.ChecksLate = S.Att().ChecksLate; O.Missed = S.Att().ChecksMissed; O.VicLate = S.Vic().ChecksLate;
		AddInfo(FString::Printf(TEXT("JAMLATE %s (late_press_frames %d, press at frame %d by %s): the bodies met at frame %d | hit at frame %d outcome %d ratio %.3f down %d frames | the victim %.2f m/s, the attacker %.2f m/s after | check event %d | late presses resolved %d, whiffs %d"),
			Name, LateFrames, PressAt, bVictim ? TEXT("the bot") : TEXT("the human"), O.ContactFrame, O.HitFrame, O.Outcome, O.Ratio, O.Knock, O.VicAfter, O.AttAfter, O.bCheck ? 1 : 0, O.ChecksLate, O.Missed));
		return O;
	};
	const FLate Ref = Play(TEXT("pressed in time"), 6, 0, false);
	const FLate None = Play(TEXT("no press"), 6, -1, false);
	if (!TestTrue(TEXT("the bodies meet (no press)"), None.ContactFrame >= 0) || !TestTrue(TEXT("the press in time lands on the frame the bodies meet"), Ref.HitFrame == None.ContactFrame)) return false;
	const int32 C = None.ContactFrame;
	TestEqual(TEXT("pressed in time: down"), Ref.Outcome, UJamSim::ContactDown);
	TestEqual(TEXT("no press: no hit"), None.Outcome, 0);
	TestEqual(TEXT("no press: the human keeps the meeting for late_press_frames (the counter reads 7 after the contact's step: 6 presses to come)"), None.LateLeftAfterContact, 7);
	TestEqual(TEXT("no press: nothing resolved, nothing missed"), None.ChecksLate + None.Missed, 0);
	for (int32 After : { 1, 3, 6 })
	{
		const FLate L = Play(*FString::Printf(TEXT("pressed %d frames late"), After), 6, C + After, false);
		TestEqual(*FString::Printf(TEXT("%d frames late: the press is the hit, on its own frame"), After), L.HitFrame, C + After);
		TestEqual(*FString::Printf(TEXT("%d frames late: the outcome of the press made in time"), After), L.Outcome, Ref.Outcome);
		TestEqual(*FString::Printf(TEXT("%d frames late: and its ratio (the velocities the two met with)"), After), static_cast<double>(L.Ratio), static_cast<double>(Ref.Ratio), 1e-3);
		TestTrue(*FString::Printf(TEXT("%d frames late: and its frames down (%d against %d: the late one has already counted its own frame)"), After, L.Knock, Ref.Knock), FMath::Abs(L.Knock - Ref.Knock) <= 1);
		TestTrue(*FString::Printf(TEXT("%d frames late: the victim leaves as from the hit in time (%.2f against %.2f m/s)"), After, L.VicAfter, Ref.VicAfter), FMath::Abs(L.VicAfter - Ref.VicAfter) < 0.5);
		TestTrue(*FString::Printf(TEXT("%d frames late: a check event, one late press counted, no whiff"), After), L.bCheck && L.ChecksLate == 1 && L.Missed == 0);
	}
	{
		const FLate L = Play(TEXT("pressed 7 frames late"), 6, C + 7, false);
		TestEqual(TEXT("7 frames late: no hit"), L.Outcome, 0);
		TestTrue(TEXT("7 frames late: the press opens a window that runs out (a whiff), nothing resolved late"), L.ChecksLate == 0 && L.Missed == 1 && !L.bCheck);
	}
	{
		const FLate L = Play(TEXT("the neutral value, pressed 1 frame late"), 0, C + 1, false);
		TestEqual(TEXT("late_press_frames 0: no hit"), L.Outcome, 0);
		TestTrue(TEXT("late_press_frames 0: the press is a whiff as before, and nothing was kept"), L.ChecksLate == 0 && L.Missed == 1 && L.LateLeftAfterContact == 0);
	}
	{
		const FLate L = Play(TEXT("the bot presses 1 frame late"), 6, C + 1, true);
		TestTrue(TEXT("a bot's late press is nothing: no hit on the human, nothing resolved"), L.AttOutcome == 0 && L.VicLate == 0);
	}
	return true;
}
// ---- Lane A157 (track F1, evolution 6, CONTACT-7.md section 1): nobody stands in a man who is down -------------------------------------------------------
//   Jam.Core.Contact.DownedPushOut   game.contact.downed_radius_m 0.6: a skater on its feet is kept 1.0 m (root to root) from a downed skater, alone gives
//                                    way, goes round him, and the downed skater's slide is the slide of a skater nobody touched; 0 (the neutral value) = the
//                                    ordinary 0.4 m body circle: the skater stops 0.8 m from the root and pushes the downed man along; the hit that fells
//                                    is the same hit at either value
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamContactDownedPushOut, "Jam.Core.Contact.DownedPushOut", JamContactTests::Flags)
bool FJamContactDownedPushOut::RunTest(const FString& Parameters)
{
	struct FOut
	{
		int32 HitFrame = -1, Knock = 0, Outcome = 0, In06 = 0, In09 = 0, LastInKeep = -1, Push = 0, Frames = 0, VicPush = 0;
		float Ratio = 0.f;
		double MinDist = 1e9, MinSpeedAfter6 = 1e9;
		FVector2D VicEnd = FVector2D::ZeroVector, AttEnd = FVector2D::ZeroVector;
		TArray<FVector2D> VicPath;
	};
	// The victim stands at the centre dot with its back to the human, who glides at it at 9 m/s from 1.3 m and presses: down (a hit from behind: the long
	// knockdown; the whistle is off in the scene). From the frame after the hit the human:
	//   Into  skates straight at the man on the ice, every frame;
	//   Away  is lifted off the scene (the downed man's own slide: the reference);
	//   On    keeps its course, the line through the body.
	enum { Into, Away, On };
	auto Play = [this](const TCHAR* Name, double Radius, int32 Mode) -> FOut
	{
		FOut O;
		FContactScene S = Make(*this, [Radius](FJamGameConfig& G) { G.Contact.DownedRadiusM = Radius; });
		if (!S.Ok()) return O;
		S.Sim->SetSkater(S.V, FVector2D::ZeroVector, FVector2D::ZeroVector, PI);
		S.Sim->SetSkater(S.A, FVector2D(1.3, 0.0), FVector2D(-9.0, 0.0), PI);
		const double Keep = FMath::Max(2.0 * UJamSim::SkaterRadius, UJamSim::SkaterRadius + Radius);
		for (int32 F = 0; F < 240; ++F)
		{
			TArray<FJamInput> In;
			In.SetNum(S.Sim->GetSkaters().Num());
			In[S.A].bCheck = F == 0;
			if (O.HitFrame >= 0 && Mode == Into) In[S.A].Move = (S.Vic().Pos - S.Att().Pos).GetSafeNormal();
			if (O.HitFrame >= 0 && Mode == On) In[S.A].Move = FVector2D(-1.0, 0.0);
			S.Sim->Step(In);
			if (O.HitFrame < 0)
			{
				if (S.Vic().ContactOutcome == 0) continue;
				O.HitFrame = F; O.Outcome = S.Vic().ContactOutcome; O.Ratio = S.Vic().ContactRatio; O.Knock = S.Vic().KnockFrames;
				if (Mode == Away) S.Sim->SetSkater(S.A, FVector2D(20.0, 10.0), FVector2D::ZeroVector, 0.0);
				continue;
			}
			if (!S.Vic().IsDown()) break;
			const int32 After = F - O.HitFrame;
			const double D = FVector2D::Distance(S.Att().Pos, S.Vic().Pos);
			++O.Frames;
			O.VicPath.Add(S.Vic().Pos);
			O.VicEnd = S.Vic().Pos; O.AttEnd = S.Att().Pos;
			if (Mode == Away) continue;
			O.MinDist = FMath::Min(O.MinDist, D);
			if (D < 0.6) ++O.In06;
			if (D < 0.9) ++O.In09;
			if (D < Keep - 1e-6) O.LastInKeep = After;
			if (After > 6) O.MinSpeedAfter6 = FMath::Min(O.MinSpeedAfter6, S.Att().Vel.Size());
		}
		O.Push = S.Att().DownedPushFrames; O.VicPush = S.Vic().DownedPushFrames;
		AddInfo(FString::Printf(TEXT("JAMDOWNED %s (downed_radius_m %.2f, keep %.2f m): hit at frame %d outcome %d ratio %.3f down %d frames | %d frames lying: closest root to root %.3f m, frames within 0.6 m %d, within 0.9 m %d, last frame inside the keep-out %d after the hit | push-out frames %d | the downed man ends at (%.3f, %.3f), the skater at (%.3f, %.3f), its slowest after frame 6: %.2f m/s"),
			Name, Radius, Keep, O.HitFrame, O.Outcome, O.Ratio, O.Knock, O.Frames, O.MinDist, O.In06, O.In09, O.LastInKeep, O.Push, O.VicEnd.X, O.VicEnd.Y, O.AttEnd.X, O.AttEnd.Y, O.MinSpeedAfter6));
		return O;
	};
	auto SamePath = [](const FOut& X, const FOut& Y)
	{
		if (X.VicPath.Num() != Y.VicPath.Num()) return 1e9;
		double Worst = 0.0;
		for (int32 i = 0; i < X.VicPath.Num(); ++i) Worst = FMath::Max(Worst, FVector2D::Distance(X.VicPath[i], Y.VicPath[i]));
		return Worst;
	};
	const FOut Into0 = Play(TEXT("into him, the neutral value"), 0.0, Into);
	const FOut Away0 = Play(TEXT("nobody near, the neutral value"), 0.0, Away);
	const FOut On0 = Play(TEXT("on course, the neutral value"), 0.0, On);
	const FOut Into6 = Play(TEXT("into him"), 0.6, Into);
	const FOut Away6 = Play(TEXT("nobody near"), 0.6, Away);
	const FOut On6 = Play(TEXT("on course"), 0.6, On);
	const FOut Into2 = Play(TEXT("into him, a radius under the body's own"), 0.2, Into);
	if (!TestTrue(TEXT("the staged hit fells the victim"), Into0.Outcome == UJamSim::ContactDown && Into0.Knock >= 90)) return false;
	// The hit itself is the ordinary collision at any value.
	TestTrue(TEXT("the hit that fells is the same hit with the key on (outcome, ratio, frames down)"), Into6.Outcome == Into0.Outcome && Into6.Ratio == Into0.Ratio && Into6.Knock == Into0.Knock && Into6.HitFrame == Into0.HitFrame);
	// The neutral value: the game as it was.
	TestTrue(*FString::Printf(TEXT("neutral: a skater skating into a downed man stops at the two body circles (closest %.3f m: never under 0.8, B's 0.6 m bar already holds)"), Into0.MinDist), Into0.MinDist > 0.8 - 1e-6 && Into0.In06 == 0);
	TestTrue(*FString::Printf(TEXT("neutral: and stays there, on the lying figure (%d of %d frames within 0.9 m)"), Into0.In09, Into0.Frames), Into0.In09 > Into0.Frames / 2);
	TestTrue(*FString::Printf(TEXT("neutral: and pushes the downed man along (he ends %.2f m from where his own slide ends)"), FVector2D::Distance(Into0.VicEnd, Away0.VicEnd)), FVector2D::Distance(Into0.VicEnd, Away0.VicEnd) > 0.3);
	TestEqual(TEXT("neutral: the push-out never runs"), Into0.Push + On0.Push + Into0.VicPush, 0);
	// The key on.
	TestTrue(*FString::Printf(TEXT("0.6: inside the keep-out (1.0 m) for the first %d frames after the hit at most (eased out at 6 m/s), never again"), Into6.LastInKeep), Into6.LastInKeep <= 3 && On6.LastInKeep <= 3);
	TestTrue(TEXT("0.6: no frame within 0.6 m, and none within 0.9 m after the easing"), Into6.In06 == 0 && Into6.In09 <= 2 && On6.In06 == 0 && On6.In09 <= 2);
	TestTrue(*FString::Printf(TEXT("0.6: the downed man slides as if nobody were near (the largest difference of his path %.2e m, skating into him; %.2e m, on course)"), SamePath(Into6, Away6), SamePath(On6, Away6)), SamePath(Into6, Away6) < 1e-9 && SamePath(On6, Away6) < 1e-9);
	TestTrue(TEXT("0.6: the rule ran on the skater on its feet, never on the downed one"), Into6.Push > 0 && On6.Push > 0 && Into6.VicPush == 0 && On6.VicPush == 0);
	TestTrue(*FString::Printf(TEXT("0.6: the skater who keeps his course goes round the body and is past it when the man gets up (x %.2f against the downed man's %.2f), never slower than %.2f m/s"), On6.AttEnd.X, On6.VicEnd.X, On6.MinSpeedAfter6),
		On6.AttEnd.X < On6.VicEnd.X - 1.0 && On6.MinSpeedAfter6 > 2.0);
	TestTrue(*FString::Printf(TEXT("neutral: the same skater is still behind the body it pushes (x %.2f against %.2f)"), On0.AttEnd.X, On0.VicEnd.X), On0.AttEnd.X > On0.VicEnd.X);
	// A radius under the body's own circle keeps the two circles apart (0.8 m), without the push on the downed man.
	TestTrue(*FString::Printf(TEXT("0.2: the keep-out is never less than the two body circles (closest %.3f m), and the downed man is not pushed"), Into2.MinDist), Into2.MinDist > 0.8 - 1e-6 && SamePath(Into2, Away0) < 1e-9);
	// Lane A165: the body's own circle is hard. A skater put 0.3 m from a downed man's root (where a pile-up squeezes it) is out of the two circles in one
	// step and out of the keep-out three steps later.
	{
		FContactScene S = Make(*this, [](FJamGameConfig& G) { G.Contact.DownedRadiusM = 0.6; });
		if (!S.Ok()) return false;
		S.Sim->SetSkater(S.V, FVector2D::ZeroVector, FVector2D::ZeroVector, PI);
		S.Sim->SetSkater(S.A, FVector2D(1.3, 0.0), FVector2D(-9.0, 0.0), PI);
		int32 HitFrame = -1;
		double D1 = -1.0, D4 = -1.0;
		for (int32 F = 0; F < 40; ++F)
		{
			TArray<FJamInput> In;
			In.SetNum(S.Sim->GetSkaters().Num());
			In[S.A].bCheck = F == 0;
			S.Sim->Step(In);
			if (HitFrame < 0) { if (S.Vic().ContactOutcome == UJamSim::ContactDown) HitFrame = F; continue; }
			const double D = FVector2D::Distance(S.Att().Pos, S.Vic().Pos);
			if (F == HitFrame + 10) S.Sim->SetSkater(S.A, S.Vic().Pos + FVector2D(0.0, 0.3), FVector2D::ZeroVector, 0.0);
			if (F == HitFrame + 11) D1 = D;
			if (F == HitFrame + 14) D4 = D;
		}
		AddInfo(FString::Printf(TEXT("JAMDOWNED squeezed (downed_radius_m 0.60): put 0.3 m from the downed man's root: %.3f m one step later, %.3f m four steps later"), D1, D4));
		TestTrue(*FString::Printf(TEXT("0.6: a skater squeezed 0.3 m from the root is out of the two body circles in one step (%.3f m)"), D1), D1 > 0.8 - 1e-6);
		TestTrue(*FString::Printf(TEXT("0.6: ... and out of the keep-out three steps later (%.3f m)"), D4), D4 > 1.0 - 1e-6);
	}
	return true;
}
// ---- Lane A157 (track F1, evolution 6, CONTACT-7.md sections 2 and 3): a check is a commitment -------------------------------------------------------------
//   Jam.Core.Contact.CheckCooldown   game.contact.check_cooldown_frames 40: of a button mashed every 12 frames two presses in five open a window, the hit
//                                    that meets the body between two of them does not land, a single press timed for it does; 0 (the neutral value):
//                                    every press opens a window and the masher's hit lands
//   Jam.Core.Contact.Lunge           game.contact.lunge_frames 12, lunge_step_mps 1.5: a press steps the body forward 1.5 m/s and holds its line (a quarter
//                                    of the turn); the lunge that meets nobody costs 3 m/s; the one that meets a body is the hit it was (the impulse's
//                                    lunge is the motion now); no second lunge inside one; both 0 (the neutral value): a press moves nothing
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamContactCheckCooldown, "Jam.Core.Contact.CheckCooldown", JamContactTests::Flags)
bool FJamContactCheckCooldown::RunTest(const FString& Parameters)
{
	struct FOut { int32 Presses = 0, Cooling = 0, Missed = 0, WindowFrames = 0, Outcome = 0, HitFrame = -1, ContactFrame = -1; };
	// The victim stands at the centre dot facing the human, who glides at it at 9 m/s from Start metres. Mash > 0: check pressed every Mash frames from
	// frame 0; Single >= 0: one press on that frame. 80 frames.
	auto Play = [this](const TCHAR* Name, int32 Cooldown, double Start, int32 Mash, int32 Single) -> FOut
	{
		FOut O;
		FContactScene S = Make(*this, [Cooldown](FJamGameConfig& G) { G.Contact.CheckCooldownFrames = Cooldown; });
		if (!S.Ok()) return O;
		S.Sim->SetSkater(S.V, FVector2D::ZeroVector, FVector2D::ZeroVector, 0.0);
		S.Sim->SetSkater(S.A, FVector2D(Start, 0.0), FVector2D(-9.0, 0.0), PI);
		for (int32 F = 0; F < 80; ++F)
		{
			TArray<FJamInput> In;
			In.SetNum(S.Sim->GetSkaters().Num());
			In[S.A].bCheck = (Mash > 0 && F % Mash == 0) || F == Single;
			S.Sim->Step(In);
			if (S.Att().bCheckThisFrame) ++O.Presses;
			if (S.Att().CheckWindow > 0) ++O.WindowFrames;
			if (O.ContactFrame < 0 && S.Vic().Vel.Size() > 1e-3) O.ContactFrame = F;
			if (O.HitFrame < 0 && S.Vic().ContactOutcome != 0) { O.HitFrame = F; O.Outcome = S.Vic().ContactOutcome; }
		}
		O.Cooling = S.Att().ChecksCooling; O.Missed = S.Att().ChecksMissed;
		AddInfo(FString::Printf(TEXT("JAMCOOL %s (check_cooldown_frames %d, from %.2f m, mash every %d, single press at %d): presses that opened a window %d, dropped %d, windows run out %d, frames with a window open %d of 80 | the bodies met at frame %d, hit at frame %d outcome %d"),
			Name, Cooldown, Start, Mash, Single, O.Presses, O.Cooling, O.Missed, O.WindowFrames, O.ContactFrame, O.HitFrame, O.Outcome));
		return O;
	};
	// Far away (the bodies never meet in 80 frames): the press accounting.
	const FOut Far0 = Play(TEXT("mashed on open ice, the neutral value"), 0, 30.0, 12, -1);
	const FOut Far40 = Play(TEXT("mashed on open ice"), 40, 30.0, 12, -1);
	TestTrue(TEXT("neutral: every one of the 7 presses opens a window, none is dropped"), Far0.Presses == 7 && Far0.Cooling == 0);
	TestTrue(*FString::Printf(TEXT("neutral: the masher's window is open nearly all the time (%d of 80 frames)"), Far0.WindowFrames), Far0.WindowFrames >= 70);
	TestTrue(TEXT("40: the presses at frames 0 and 48 open a window, the five between and after are dropped"), Far40.Presses == 2 && Far40.Cooling == 5);
	TestTrue(*FString::Printf(TEXT("40: the masher's window is open %d of 80 frames (two windows of 12)"), Far40.WindowFrames), Far40.WindowFrames >= 22 && Far40.WindowFrames <= 24);
	// The bodies meet about frame 27, between the masher's two windows under the cooldown.
	const FOut None = Play(TEXT("no press"), 0, 4.85, 0, -1);
	if (!TestTrue(*FString::Printf(TEXT("the staged bodies meet between frames 20 and 40 (frame %d)"), None.ContactFrame), None.ContactFrame >= 20 && None.ContactFrame <= 40)) return false;
	const FOut Mash0 = Play(TEXT("mashed into him, the neutral value"), 0, 4.85, 12, -1);
	const FOut Mash40 = Play(TEXT("mashed into him"), 40, 4.85, 12, -1);
	const FOut Timed0 = Play(TEXT("one timed press, the neutral value"), 0, 4.85, 0, None.ContactFrame - 3);
	const FOut Timed40 = Play(TEXT("one timed press"), 40, 4.85, 0, None.ContactFrame - 3);
	TestTrue(TEXT("neutral: the mashed button lands the hit (a window is always open)"), Mash0.Outcome >= UJamSim::ContactStumble && Mash0.HitFrame == None.ContactFrame);
	TestEqual(TEXT("40: the mashed button does not (the bodies meet between its two windows)"), Mash40.Outcome, 0);
	TestTrue(TEXT("a press timed for the contact lands at either value, the same hit"), Timed0.Outcome >= UJamSim::ContactStumble && Timed40.Outcome == Timed0.Outcome && Timed40.HitFrame == Timed0.HitFrame);
	return true;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamContactLunge, "Jam.Core.Contact.Lunge", JamContactTests::Flags)
bool FJamContactLunge::RunTest(const FString& Parameters)
{
	struct FOut { double Speed1 = 0, Speed16 = 0, SpeedMax = 0, Yaw5 = 0; int32 Missed = 0, LeftAfterHit = -1, Outcome = 0, HitFrame = -1, Left1 = 0; float Ratio = 0.f; };
	// The human at Pos gliding at Speed along -x (facing it), the victim at the centre dot facing the human (or parked far away: bVictim false).
	// Presses on the frames in Press; Turn: move input across its course from frame 0. 30 frames.
	auto Play = [this](const TCHAR* Name, int32 Frames, double Step, double StartX, double Speed, bool bVictim, bool bTurn, std::initializer_list<int32> Press) -> FOut
	{
		FOut O;
		FContactScene S = Make(*this, [Frames, Step](FJamGameConfig& G) { G.Contact.LungeFrames = Frames; G.Contact.LungeStepMps = Step; });
		if (!S.Ok()) return O;
		S.Sim->SetSkater(S.V, bVictim ? FVector2D::ZeroVector : FVector2D(0.0, 11.0), FVector2D::ZeroVector, 0.0);
		S.Sim->SetSkater(S.A, FVector2D(StartX, 0.0), FVector2D(-Speed, 0.0), PI);
		const double Yaw0 = S.Att().Yaw;
		for (int32 F = 0; F < 30; ++F)
		{
			TArray<FJamInput> In;
			In.SetNum(S.Sim->GetSkaters().Num());
			for (int32 P : Press) if (P == F) In[S.A].bCheck = true;
			if (bTurn) In[S.A].Move = FVector2D(0.0, 1.0);
			S.Sim->Step(In);
			const double V = S.Att().Vel.Size();
			O.SpeedMax = FMath::Max(O.SpeedMax, V);
			if (F == 0) { O.Speed1 = V; O.Left1 = S.Att().LungeLeft; }
			if (F == 15) O.Speed16 = V;
			if (F == 4) O.Yaw5 = FMath::Abs(FMath::FindDeltaAngleRadians(Yaw0, S.Att().Yaw));
			if (O.HitFrame < 0 && S.Vic().ContactOutcome != 0) { O.HitFrame = F; O.Outcome = S.Vic().ContactOutcome; O.Ratio = S.Vic().ContactRatio; O.LeftAfterHit = S.Att().LungeLeft; }
		}
		O.Missed = S.Att().LungesMissed;
		AddInfo(FString::Printf(TEXT("JAMLUNGE %s (lunge_frames %d, lunge_step_mps %.1f, %.1f m/s from x %.1f): speed after the press's frame %.2f, after 16 frames %.2f, highest %.2f m/s | turned %.3f rad in 5 frames | lunge frames left after the press's frame %d | lunges missed %d | hit at frame %d outcome %d ratio %.3f, lunge left after it %d"),
			Name, Frames, Step, Speed, StartX, O.Speed1, O.Speed16, O.SpeedMax, O.Yaw5, O.Left1, O.Missed, O.HitFrame, O.Outcome, O.Ratio, O.LeftAfterHit));
		return O;
	};
	// From a standstill.
	const FOut Stand0 = Play(TEXT("standing, the neutral value"), 0, 0.0, 10.0, 0.0, false, false, { 0 });
	const FOut Stand = Play(TEXT("standing"), 12, 1.5, 10.0, 0.0, false, false, { 0 });
	TestTrue(TEXT("neutral: a press moves nothing, no lunge runs, none is missed"), Stand0.SpeedMax < 1e-6 && Stand0.Left1 == 0 && Stand0.Missed == 0);
	TestTrue(*FString::Printf(TEXT("12 / 1.5: a standing skater's press steps it forward (%.2f m/s after the press's frame), 12 frames of lunge to come"), Stand.Speed1), Stand.Speed1 > 1.3 && Stand.Speed1 <= 1.5 && Stand.Left1 == 12);
	TestTrue(*FString::Printf(TEXT("12 / 1.5: the lunge met nobody: one miss, and the skater stands again (%.2f m/s)"), Stand.Speed16), Stand.Missed == 1 && Stand.Speed16 < 1e-6);
	// At speed, nobody there.
	const FOut Glide0 = Play(TEXT("gliding, the neutral value"), 0, 0.0, 10.0, 6.0, false, false, { 0 });
	const FOut Glide = Play(TEXT("gliding"), 12, 1.5, 10.0, 6.0, false, false, { 0 });
	TestTrue(*FString::Printf(TEXT("12 / 1.5: the step is on top of the glide (%.2f against %.2f m/s)"), Glide.Speed1, Glide0.Speed1), Glide.Speed1 > Glide0.Speed1 + 1.3);
	TestTrue(*FString::Printf(TEXT("12 / 1.5: the miss costs the step and as much again (%.2f against %.2f m/s after 16 frames)"), Glide.Speed16, Glide0.Speed16), Glide.Missed == 1 && Glide.Speed16 < Glide0.Speed16 - 1.2 && Glide.Speed16 > Glide0.Speed16 - 1.8);
	const FOut Twice = Play(TEXT("gliding, pressed again inside the lunge"), 12, 1.5, 10.0, 6.0, false, false, { 0, 6 });
	TestTrue(*FString::Printf(TEXT("12 / 1.5: no second lunge inside one (highest speed %.2f m/s, one miss)"), Twice.SpeedMax), Twice.SpeedMax < 7.6 && Twice.Missed == 1);
	// Committed to its line.
	const FOut Turn0 = Play(TEXT("turning, the neutral value"), 0, 0.0, 10.0, 6.0, false, true, { 0 });
	const FOut Turn = Play(TEXT("turning"), 12, 1.5, 10.0, 6.0, false, true, { 0 });
	TestTrue(*FString::Printf(TEXT("12 / 1.5: a lunging skater turns a quarter of what it would (%.3f against %.3f rad in 5 frames)"), Turn.Yaw5, Turn0.Yaw5), Turn0.Yaw5 > 0.05 && Turn.Yaw5 > 0.2 * Turn0.Yaw5 && Turn.Yaw5 < 0.3 * Turn0.Yaw5);
	// Into a body: the hit it was.
	const FOut Hit0 = Play(TEXT("the hit, the neutral value"), 0, 0.0, 1.3, 9.0, true, false, { 0 });
	const FOut Hit = Play(TEXT("the hit"), 12, 1.5, 1.3, 9.0, true, false, { 0 });
	if (!TestTrue(TEXT("the staged press lands at the neutral value"), Hit0.Outcome >= UJamSim::ContactStumble)) return false;
	TestTrue(*FString::Printf(TEXT("12 / 1.5: the lunge that meets a body is the hit it was (outcome %d against %d, ratio %.3f against %.3f: the impulse's lunge is the motion now)"), Hit.Outcome, Hit0.Outcome, Hit.Ratio, Hit0.Ratio),
		Hit.Outcome == Hit0.Outcome && FMath::Abs(Hit.Ratio - Hit0.Ratio) < 0.03 * Hit0.Ratio);
	TestTrue(TEXT("12 / 1.5: it ends in the body: no lunge left, no miss charged"), Hit.LeftAfterHit == 0 && Hit.Missed == 0);
	return true;
}
// ---- Lane A165 (track F1, evolution 7, CONTACT-8.md) ---------------------------------------------------------------------------------------------------------
//   Jam.Core.Contact.CooldownRestart  game.contact.check_cooldown_restart with check_cooldown_frames 36: a button mashed every 12 frames opens ONE window
//                                     and no other; a press every 37 frames opens every one; a dropped press costs a whole cooldown from that press;
//                                     false (the neutral value): the cooldown of lane A157 (a window every 36 frames); with no cooldown the key is not read
//   Jam.Core.Contact.BoardSlam        game.contact.board_slam_frames 30: a knockdown within 1 m of the boards closing along their normal at 4 m/s or more
//                                     lasts 30 frames longer and fires the board read-out and event; along the boards, beyond 1 m, under 4 m/s along the
//                                     normal it is the hit it was; 0 (the neutral value): no slam
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamContactCooldownRestart, "Jam.Core.Contact.CooldownRestart", JamContactTests::Flags)
bool FJamContactCooldownRestart::RunTest(const FString& Parameters)
{
	struct FOut { int32 Presses = 0, Cooling = 0, WindowFrames = 0, Outcome = 0, HitFrame = -1, ContactFrame = -1; };
	// The victim stands at the centre dot facing the human, who glides at it at 9 m/s from Start metres; Press says on which frames check is pressed. 160 frames.
	auto Play = [this](const TCHAR* Name, int32 Cooldown, bool bRestart, double Start, TFunctionRef<bool(int32)> Press) -> FOut
	{
		FOut O;
		FContactScene S = Make(*this, [Cooldown, bRestart](FJamGameConfig& G) { G.Contact.CheckCooldownFrames = Cooldown; G.Contact.bCheckCooldownRestart = bRestart; });
		if (!S.Ok()) return O;
		S.Sim->SetSkater(S.V, FVector2D::ZeroVector, FVector2D::ZeroVector, 0.0);
		S.Sim->SetSkater(S.A, FVector2D(Start, 0.0), FVector2D(-9.0, 0.0), PI);
		for (int32 F = 0; F < 160; ++F)
		{
			TArray<FJamInput> In;
			In.SetNum(S.Sim->GetSkaters().Num());
			In[S.A].bCheck = Press(F);
			S.Sim->Step(In);
			if (S.Att().bCheckThisFrame) ++O.Presses;
			if (S.Att().CheckWindow > 0) ++O.WindowFrames;
			if (O.ContactFrame < 0 && S.Vic().Vel.Size() > 1e-3) O.ContactFrame = F;
			if (O.HitFrame < 0 && S.Vic().ContactOutcome != 0) { O.HitFrame = F; O.Outcome = S.Vic().ContactOutcome; }
		}
		O.Cooling = S.Att().ChecksCooling;
		AddInfo(FString::Printf(TEXT("JAMRESTART %s (check_cooldown_frames %d, restart %d, from %.2f m): presses that opened a window %d, dropped %d, frames with a window open %d of 160 | the bodies met at frame %d, hit at frame %d outcome %d"),
			Name, Cooldown, bRestart ? 1 : 0, Start, O.Presses, O.Cooling, O.WindowFrames, O.ContactFrame, O.HitFrame, O.Outcome));
		return O;
	};
	auto Every = [](int32 N) { return [N](int32 F) { return F % N == 0; }; };
	// From 28 m the bodies do not meet in 160 frames: the press accounting.
	const FOut Plain = Play(TEXT("mashed every 12, the cooldown alone"), 36, false, 28.0, Every(12));
	const FOut Mash = Play(TEXT("mashed every 12, restart"), 36, true, 28.0, Every(12));
	const FOut Timed = Play(TEXT("pressed every 37, restart"), 36, true, 28.0, Every(37));
	const FOut Rest = Play(TEXT("pressed at 0, 20 and 60, restart"), 36, true, 28.0, [](int32 F) { return F == 0 || F == 20 || F == 60; });
	const FOut Early = Play(TEXT("pressed at 0, 20 and 50, restart"), 36, true, 28.0, [](int32 F) { return F == 0 || F == 20 || F == 50; });
	const FOut NoCool = Play(TEXT("mashed every 12, restart without a cooldown"), 0, true, 28.0, Every(12));
	TestTrue(*FString::Printf(TEXT("false (neutral): the masher opens a window every 36 frames (%d presses of 14, %d dropped)"), Plain.Presses, Plain.Cooling), Plain.Presses == 5 && Plain.Cooling == 9);
	TestTrue(*FString::Printf(TEXT("true: the masher opens ONE window and no other (%d press, %d dropped, %d frames open)"), Mash.Presses, Mash.Cooling, Mash.WindowFrames), Mash.Presses == 1 && Mash.Cooling == 13 && Mash.WindowFrames == 12);
	TestTrue(*FString::Printf(TEXT("true: a press every 37 frames opens every window (%d of 5, none dropped)"), Timed.Presses), Timed.Presses == 5 && Timed.Cooling == 0);
	TestTrue(TEXT("true: a dropped press at 20 moves the cooldown to 56: the press at 60 opens a window"), Rest.Presses == 2 && Rest.Cooling == 1);
	TestTrue(TEXT("true: ... and the press at 50 does not (36 frames from the first, inside 36 from the dropped one)"), Early.Presses == 1 && Early.Cooling == 2);
	TestTrue(TEXT("true with check_cooldown_frames 0: the key is not read, every press opens a window"), NoCool.Presses == 14 && NoCool.Cooling == 0);
	// The bodies meet about frame 27.
	const FOut None = Play(TEXT("no press"), 36, true, 4.85, [](int32) { return false; });
	if (!TestTrue(*FString::Printf(TEXT("the staged bodies meet between frames 20 and 40 (frame %d)"), None.ContactFrame), None.ContactFrame >= 20 && None.ContactFrame <= 40)) return false;
	const FOut MashHit = Play(TEXT("mashed into him, restart"), 36, true, 4.85, Every(12));
	const int32 At = None.ContactFrame - 3;
	const FOut TimedHit = Play(TEXT("one timed press, restart"), 36, true, 4.85, [At](int32 F) { return F == At; });
	TestEqual(TEXT("true: the mashed button does not land the hit"), MashHit.Outcome, 0);
	TestTrue(TEXT("true: the press timed for the contact lands it"), TimedHit.Outcome >= UJamSim::ContactStumble && TimedHit.HitFrame == None.ContactFrame);
	return true;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamContactBoardSlam, "Jam.Core.Contact.BoardSlam", JamContactTests::Flags)
bool FJamContactBoardSlam::RunTest(const FString& Parameters)
{
	struct FOut { FContactHit H; bool bSlam = false, bContactBoard = false; int32 Slams = 0, BoardEvents = 0; };
	// The victim stands Gap metres from the +z side boards facing along them; the attacker comes from 1 m away at Speed along a line AngleDeg off straight
	// at the boards (0 = straight in, 90 = along them), and presses.
	auto Hit = [this](const TCHAR* Name, int32 SlamFrames, double Bonus, double Gap, double AngleDeg, double Speed) -> FOut
	{
		FOut O;
		FContactScene S = Make(*this, [SlamFrames, Bonus](FJamGameConfig& G) { G.Contact.BoardSlamFrames = SlamFrames; G.Contact.BoardBonus = Bonus; });
		if (!S.Ok()) return O;
		const double Hz = S.Cfg.Rink.WidthM * 0.5;
		const double A = FMath::DegreesToRadians(AngleDeg);
		const FVector2D Dir(FMath::Sin(A), FMath::Cos(A));
		const FVector2D VPos(0.0, Hz - Gap);
		S.Sim->SetSkater(S.V, VPos, FVector2D::ZeroVector, 0.0);
		S.Sim->SetSkater(S.A, VPos - Dir * 1.0, Dir * Speed, FMath::Atan2(Dir.Y, Dir.X));
		O.H = Run(S, 12, [&](TArray<FJamInput>& In, int32 F) { In[S.A].bCheck = F == 0; });
		O.bSlam = S.Vic().bContactSlam; O.bContactBoard = S.Vic().bContactBoard; O.Slams = S.Vic().ContactSlams;
		for (const FJamSimEvent& E : S.Sim->GetFrameEvents()) if (E.Name == JamEvents::Board && E.Who == S.V) ++O.BoardEvents;
		AddInfo(FString::Printf(TEXT("JAMSLAM %s (board_slam_frames %d, board_bonus %.2f, %.1f m from the boards, %.0f degrees off straight in, %.1f m/s = %.1f m/s along the normal): outcome %d ratio %.3f down %d frames | slam %d (counted %d) board read-out %d board events %d"),
			Name, SlamFrames, Bonus, Gap, AngleDeg, Speed, Speed * FMath::Cos(A), O.H.Outcome, O.H.Ratio, O.H.KnockFrames, O.bSlam ? 1 : 0, O.Slams, O.bContactBoard ? 1 : 0, O.BoardEvents));
		return O;
	};
	const FOut Off = Hit(TEXT("straight in, the neutral value"), 0, 1.25, 0.8, 0.0, 9.0);
	const FOut On = Hit(TEXT("straight in"), 30, 1.25, 0.8, 0.0, 9.0);
	if (!TestEqual(TEXT("the staged hit fells the victim at the neutral value"), Off.H.Outcome, UJamSim::ContactDown)) return false;
	TestTrue(TEXT("0 (neutral): no slam, nothing counted; the board hit of lane A101 as it was"), !Off.bSlam && Off.Slams == 0 && Off.bContactBoard && Off.BoardEvents == 1);
	TestTrue(TEXT("30: the same hit is a slam (the same outcome and ratio)"), On.bSlam && On.Slams == 1 && On.H.Outcome == Off.H.Outcome && On.H.Ratio == Off.H.Ratio);
	TestEqual(TEXT("30: ... and lasts 30 frames longer"), On.H.KnockFrames, Off.H.KnockFrames + 30);
	TestTrue(TEXT("30: ... with the board read-out and one board event"), On.bContactBoard && On.BoardEvents == 1);
	// Not earned: along the boards, beyond 1 m, too little speed along the normal.
	const FOut Along0 = Hit(TEXT("along the boards, the neutral value"), 0, 1.25, 0.8, 90.0, 9.0);
	const FOut Along = Hit(TEXT("along the boards"), 30, 1.25, 0.8, 90.0, 9.0);
	TestTrue(TEXT("30, along the boards: down, no slam, the frames of the neutral value"), Along.H.Outcome == UJamSim::ContactDown && !Along.bSlam && Along.Slams == 0 && Along.H.KnockFrames == Along0.H.KnockFrames);
	const FOut Far0 = Hit(TEXT("1.3 m out, the neutral value"), 0, 1.25, 1.3, 0.0, 9.0);
	const FOut Far = Hit(TEXT("1.3 m out"), 30, 1.25, 1.3, 0.0, 9.0);
	TestTrue(TEXT("30, 1.3 m from the boards: the board bonus still counts, no slam, the frames of the neutral value"), Far.H.Outcome == UJamSim::ContactDown && Far.bContactBoard && !Far.bSlam && Far.H.KnockFrames == Far0.H.KnockFrames);
	const FOut Oblique0 = Hit(TEXT("70 degrees off, the neutral value"), 0, 1.25, 0.8, 70.0, 9.0);
	const FOut Oblique = Hit(TEXT("70 degrees off"), 30, 1.25, 0.8, 70.0, 9.0);
	TestTrue(TEXT("30, 70 degrees off straight in (3.1 m/s along the normal): down, no slam"), Oblique.H.Outcome == UJamSim::ContactDown && !Oblique.bSlam && Oblique.H.KnockFrames == Oblique0.H.KnockFrames);
	const FOut Angled = Hit(TEXT("30 degrees off"), 30, 1.25, 0.8, 30.0, 9.0);
	TestTrue(TEXT("30, 30 degrees off straight in (7.8 m/s along the normal): a slam"), Angled.H.Outcome == UJamSim::ContactDown && Angled.bSlam);
	// A slam is a board hit whatever board_bonus says.
	const FOut NoBonus0 = Hit(TEXT("straight in, board_bonus 1, the neutral value"), 0, 1.0, 0.8, 0.0, 9.0);
	const FOut NoBonus = Hit(TEXT("straight in, board_bonus 1"), 30, 1.0, 0.8, 0.0, 9.0);
	TestTrue(TEXT("board_bonus 1, slam 0: down, no board read-out (lane A101's neutral)"), NoBonus0.H.Outcome == UJamSim::ContactDown && !NoBonus0.bContactBoard && NoBonus0.BoardEvents == 0);
	TestTrue(TEXT("board_bonus 1, slam 30: the slam fires the board read-out and event itself, 30 frames on top"), NoBonus.bSlam && NoBonus.bContactBoard && NoBonus.BoardEvents == 1 && NoBonus.H.KnockFrames == NoBonus0.H.KnockFrames + 30);
	return true;
}
// ---- Lane A177 (track F1, evolution 8, CONTACT-9.md section 1): a hit inside a carry's first frames is capped at a stumble --------------------------------
//   Jam.Core.Contact.TakeShield      game.contact.take_shield_frames 15: a skater that WON the puck (it came from somebody else) is hit four frames later
//                                    by the hit that fells it at the neutral value: a stumble of stagger_frames, the puck loose, its feet kept; the same
//                                    hit after the 15 frames, on a puck that was placed, and under take_shield_human_side on a side without a human, fells
//                                    it as before; take_shield_stagger_max 45: the capped stumble grows with the hit; 0 (the neutral value): nothing is armed
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamContactTakeShield, "Jam.Core.Contact.TakeShield", JamContactTests::Flags)
bool FJamContactTakeShield::RunTest(const FString& Parameters)
{
	struct FOut { int32 ShieldAtWin = -1, Outcome = 0, Stumble = 0, Knock = 0, Shielded = 0, HitAge = -1, AttOutcome = 0; float Ratio = 0.f; bool bShieldFlag = false, bPuckLoose = false, bWon = false; };
	// A third skater carries a placed puck and is lifted away; the victim is put on the loose puck and wins it (a puck that changed hands). Wait frames
	// later the human is sent at it head-on at Speed from 1.3 m and presses: the bodies meet four steps after. bPlaced: the victim gets a placed puck instead
	// (nobody lost it: no take).
	auto Play = [this](const TCHAR* Name, int32 Frames, bool bHumanSide, int32 StaggerMax, int32 Wait, double Speed, bool bPlaced) -> FOut
	{
		FOut O;
		FContactScene S = Make(*this, [=](FJamGameConfig& G) { G.Contact.TakeShieldFrames = Frames; G.Contact.bTakeShieldHumanSide = bHumanSide; G.Contact.TakeShieldStaggerMax = StaggerMax; });
		if (!S.Ok()) return O;
		auto StepIdle = [&S]() { TArray<FJamInput> In; In.SetNum(S.Sim->GetSkaters().Num()); S.Sim->Step(In); };
		const FVector2D Spot(0.0, 0.0);
		S.Sim->SetSkater(S.A, FVector2D(20.0, 8.0), FVector2D::ZeroVector, PI);
		if (bPlaced)
		{
			S.Sim->SetSkater(S.V, Spot, FVector2D::ZeroVector, 0.0);
			if (!HandPuck(S, S.V)) { AddError(TEXT("the placed puck was not picked up")); return O; }
		}
		else
		{
			int32 Third = -1;
			for (const FJamSkaterState& K : S.Sim->GetSkaters()) if (K.Index != S.A && K.Index != S.V) { Third = K.Index; break; }
			if (Third < 0) { AddError(TEXT("no third skater in the scene")); return O; }
			const FVector2D Park = S.Sim->GetSkaters()[Third].Pos;
			S.Sim->SetSkater(S.V, FVector2D(-20.0, -8.0), FVector2D::ZeroVector, 0.0);
			S.Sim->SetSkater(Third, Spot, FVector2D::ZeroVector, 0.0);
			if (!HandPuck(S, Third)) { AddError(TEXT("the third skater did not pick the placed puck up")); return O; }
			const FVector2D PuckAt = S.Sim->GetPuck().Pos;
			S.Sim->SetSkater(Third, Park, FVector2D::ZeroVector, 0.0);
			S.Sim->SetSkater(S.V, PuckAt - FVector2D(0.45, 0.0), FVector2D::ZeroVector, 0.0);
			for (int32 F = 0; F < 40 && S.Sim->CarrierIndex() != S.V; ++F) StepIdle();
		}
		O.bWon = S.Sim->CarrierIndex() == S.V;
		if (!O.bWon) { AddError(FString::Printf(TEXT("%s: the victim did not get the puck"), Name)); return O; }
		O.ShieldAtWin = S.Vic().TakeShieldLeft;
		for (int32 F = 0; F < Wait; ++F) StepIdle();
		S.Sim->SetSkater(S.A, S.Vic().Pos + FVector2D(1.3, 0.0), FVector2D(-Speed, 0.0), PI);
		for (int32 F = 0; F < 12; ++F)
		{
			TArray<FJamInput> In;
			In.SetNum(S.Sim->GetSkaters().Num());
			In[S.A].bCheck = F == 0;
			S.Sim->Step(In);
			if (S.Att().ContactOutcome != 0) O.AttOutcome = S.Att().ContactOutcome;
			if (S.Vic().ContactOutcome == 0) continue;
			O.Outcome = S.Vic().ContactOutcome; O.Ratio = S.Vic().ContactRatio; O.Stumble = S.Vic().StumbleFrames; O.Knock = S.Vic().KnockFrames;
			O.bShieldFlag = S.Vic().bContactShield; O.HitAge = Wait + F + 1;
			O.bPuckLoose = S.Sim->CarrierIndex() != S.V;
			break;
		}
		O.Shielded = S.Vic().ContactShielded;
		AddInfo(FString::Printf(TEXT("JAMSHIELD %s (take_shield_frames %d, human side only %d, stagger max %d, %s puck, the hit %d frames after the take at %.0f m/s): shield left at the take %d | outcome %d ratio %.3f stumble %d knock %d | capped %d (counted %d) | the puck loose %d"),
			Name, Frames, bHumanSide ? 1 : 0, StaggerMax, bPlaced ? TEXT("a placed") : TEXT("a won"), O.HitAge, Speed, O.ShieldAtWin, O.Outcome, O.Ratio, O.Stumble, O.Knock, O.bShieldFlag ? 1 : 0, O.Shielded, O.bPuckLoose ? 1 : 0));
		return O;
	};
	const FOut Off = Play(TEXT("the neutral value"), 0, false, 0, 0, 9.0, false);
	if (!TestTrue(TEXT("the staged hit fells the fresh carrier at the neutral value"), Off.bWon && Off.Outcome == UJamSim::ContactDown && Off.Knock > 0)) return false;
	TestTrue(TEXT("0 (neutral): nothing is armed at the take, nothing capped"), Off.ShieldAtWin == 0 && !Off.bShieldFlag && Off.Shielded == 0);
	const FOut On = Play(TEXT("inside the shield"), 15, false, 0, 0, 9.0, false);
	TestEqual(TEXT("15: the take arms the shield for 15 frames"), On.ShieldAtWin, 15);
	TestTrue(*FString::Printf(TEXT("15: the same hit %d frames after the take is a stumble of stagger_frames, the same ratio, no knockdown"), On.HitAge), On.Outcome == UJamSim::ContactStumble && On.Stumble == 16 && On.Knock == 0 && On.Ratio == Off.Ratio);
	TestTrue(TEXT("15: it is counted, and the puck comes loose (the stumble's own rule)"), On.bShieldFlag && On.Shielded == 1 && On.bPuckLoose);
	const FOut Late = Play(TEXT("after the shield"), 15, false, 0, 14, 9.0, false);
	TestTrue(*FString::Printf(TEXT("15: the hit %d frames after the take fells him as before"), Late.HitAge), Late.HitAge > 15 && Late.Outcome == UJamSim::ContactDown && Late.Knock == Off.Knock && !Late.bShieldFlag);
	const FOut Placed = Play(TEXT("a placed puck"), 15, false, 0, 0, 9.0, true);
	TestTrue(TEXT("15: a puck that was placed is not a puck won: no shield, down"), Placed.ShieldAtWin == 0 && Placed.Outcome == UJamSim::ContactDown);
	const FOut Side = Play(TEXT("the human's side only, the victim a bot of the other side"), 15, true, 0, 0, 9.0, false);
	TestTrue(TEXT("take_shield_human_side: a side without a human gets no shield, down"), Side.ShieldAtWin == 0 && Side.Outcome == UJamSim::ContactDown);
	// The cap that scales: the stumble grows with the hit.
	const FOut Flat = Play(TEXT("a hard hit, the flat cap"), 15, false, 0, 0, 14.0, false);
	const FOut Soft = Play(TEXT("the scaled cap"), 15, false, 45, 0, 9.0, false);
	const FOut Hard = Play(TEXT("a hard hit, the scaled cap"), 15, false, 45, 0, 14.0, false);
	TestTrue(*FString::Printf(TEXT("flat: a hit of ratio %.2f is the same 16-frame stumble as one of %.2f"), Flat.Ratio, On.Ratio), Flat.Outcome == UJamSim::ContactStumble && Flat.Stumble == 16 && Flat.Ratio > On.Ratio);
	TestTrue(*FString::Printf(TEXT("stagger max 45: the stumble follows the hit (%d frames at ratio %.2f, %d at %.2f), never a knockdown"), Soft.Stumble, Soft.Ratio, Hard.Stumble, Hard.Ratio),
		Soft.Outcome == UJamSim::ContactStumble && Hard.Outcome == UJamSim::ContactStumble && Soft.Stumble >= 16 && Hard.Stumble > Soft.Stumble && Hard.Stumble <= 45 && Hard.Knock == 0);
	return true;
}

// Lane A184 (track F1, evolution 9; R-0064 points 1 and 5; docs/experiments/CONTACT-10.md): the held cross-check and the wind-ups.
//   cross_hold: a hold of CrossHoldTapFrames braces; the braced body delivers the pressed cross-check's own hit by closing speed (the frames down at 4 / 8 / 12
//   / 16 m/s, held against pressed); the brace is spent until the release; a tap never braces; braced, no poke and no lift; off (the neutral value): nothing.
//   check_windup_frames / cross_windup_frames: the window opens, the swing lands, that many frames after the press; the figure is told on the press.
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FJamContactCrossHold, "Jam.Core.Contact.CrossHold", JamContactTests::Flags)
bool FJamContactCrossHold::RunTest(const FString& Parameters)
{
	struct FHit { int32 Outcome = 0, Knock = 0, Stumble = 0, Frame = -1; float Ratio = 0.f; bool bCross = false, bBraceHit = false; };
	auto Idle = [](FContactScene& S) { TArray<FJamInput> In; In.SetNum(S.Sim->GetSkaters().Num()); return In; };
	// The victim stands at the origin with a placed puck, facing +x; the attacker comes from +x along -x at Speed, facing it (closing = Speed).
	auto Hit = [&](bool bHeld, double Speed, bool bRule) -> FHit
	{
		FHit O;
		FContactScene S = Make(*this, [=](FJamGameConfig& G) { G.Contact.bCrossHold = bRule; });
		if (!S.Ok()) return O;
		S.Sim->SetSkater(S.V, FVector2D(0.0, 0.0), FVector2D::ZeroVector, 0.0);
		if (!HandPuck(S, S.V)) { AddError(TEXT("the victim did not pick the placed puck up")); return O; }
		S.Sim->SetSkater(S.V, FVector2D(0.0, 0.0), FVector2D::ZeroVector, 0.0);
		const double R2 = 2.0 * UJamSim::SkaterRadius;
		if (bHeld)
		{
			S.Sim->SetSkater(S.A, FVector2D(20.0, 8.0), FVector2D::ZeroVector, PI);
			for (int32 F = 0; F < UJamSim::CrossHoldTapFrames + 2; ++F) { TArray<FJamInput> In = Idle(S); In[S.A].bCrossHold = true; S.Sim->Step(In); }
			S.Sim->SetSkater(S.A, FVector2D(R2 + 0.02, 0.0), FVector2D(-Speed, 0.0), PI);
		}
		else
		{
			S.Sim->SetSkater(S.A, FVector2D(R2 + S.Cfg.Contact.CrossReachM - 0.05, 0.0), FVector2D(-Speed, 0.0), PI);
		}
		for (int32 F = 0; F < 6; ++F)
		{
			TArray<FJamInput> In = Idle(S);
			In[S.A].bCrossHold = bHeld;
			In[S.A].bLift = !bHeld && F == 0;
			S.Sim->Step(In);
			if (S.Vic().ContactOutcome == 0) continue;
			O.Outcome = S.Vic().ContactOutcome; O.Knock = S.Vic().KnockFrames; O.Stumble = S.Vic().StumbleFrames; O.Ratio = S.Vic().ContactRatio;
			O.bCross = S.Vic().bContactCross; O.bBraceHit = S.Vic().bCrossBraceHit; O.Frame = F;
			break;
		}
		AddInfo(FString::Printf(TEXT("JAMBRACE %s at %.0f m/s of closing (cross_hold %d): outcome %d ratio %.3f down %d stumble %d cross %d out of the brace %d (frame %d)"),
			bHeld ? TEXT("held") : TEXT("pressed"), Speed, bRule ? 1 : 0, O.Outcome, O.Ratio, O.Knock, O.Stumble, O.bCross ? 1 : 0, O.bBraceHit ? 1 : 0, O.Frame));
		return O;
	};
	// 1. The table: the held cross-check is the pressed one's hit, by closing speed.
	int32 PrevKnock = -1;
	for (const double V : { 4.0, 8.0, 12.0, 16.0 })
	{
		const FHit P = Hit(false, V, true), H = Hit(true, V, true);
		TestTrue(*FString::Printf(TEXT("%.0f m/s: the pressed cross-check lands"), V), P.Outcome >= UJamSim::ContactBump && P.bCross);
		TestTrue(*FString::Printf(TEXT("%.0f m/s: the held one lands out of the brace as a cross-check"), V), H.Outcome >= UJamSim::ContactBump && H.bCross && H.bBraceHit);
		TestEqual(*FString::Printf(TEXT("%.0f m/s: the same outcome held and pressed"), V), H.Outcome, P.Outcome);
		TestTrue(*FString::Printf(TEXT("%.0f m/s: the same frames down held (%d) and pressed (%d), within 3 (the held man glides a frame before the bodies meet)"), V, H.Knock, P.Knock), FMath::Abs(H.Knock - P.Knock) <= 3);
		TestTrue(*FString::Printf(TEXT("%.0f m/s: more momentum, no fewer frames down (%d after %d)"), V, H.Knock, PrevKnock), H.Knock >= PrevKnock);
		PrevKnock = H.Knock;
	}
	// 2. The neutral value: the held button does nothing.
	{
		const FHit Off = Hit(true, 12.0, false);
		TestTrue(TEXT("cross_hold false: the held body meets the man and no cross-check lands"), !Off.bCross && Off.Outcome == 0);
	}
	// 3. The brace is spent until the release; a tap never braces; braced, no poke and no lift.
	{
		FContactScene S = Make(*this, [](FJamGameConfig& G) { G.Contact.bCrossHold = true; });
		if (!S.Ok()) return false;
		S.Sim->SetSkater(S.A, FVector2D(20.0, 8.0), FVector2D::ZeroVector, PI);
		for (int32 F = 0; F < UJamSim::CrossHoldTapFrames - 3; ++F) { TArray<FJamInput> In = Idle(S); In[S.A].bCrossHold = true; S.Sim->Step(In); }
		TestFalse(TEXT("a tap (held under CrossHoldTapFrames) is not braced"), S.Att().bCrossBraced);
		{ TArray<FJamInput> In = Idle(S); S.Sim->Step(In); }
		TestEqual(TEXT("the release resets the hold"), S.Att().CrossHoldFrames, 0);
		for (int32 F = 0; F < UJamSim::CrossHoldTapFrames; ++F) { TArray<FJamInput> In = Idle(S); In[S.A].bCrossHold = true; S.Sim->Step(In); }
		TestTrue(TEXT("held CrossHoldTapFrames: braced"), S.Att().bCrossBraced);
		{
			TArray<FJamInput> In = Idle(S); In[S.A].bCrossHold = true; In[S.A].bPoke = true; In[S.A].bLift = true;
			S.Sim->Step(In);
			TestTrue(TEXT("braced: the poke and the lift are not swung"), !S.Att().bPokeThisFrame && !S.Att().bLiftThisFrame && S.Att().bCrossBraced);
		}
		S.Sim->SetSkater(S.V, FVector2D(0.0, 0.0), FVector2D::ZeroVector, 0.0);
		S.Sim->SetSkater(S.A, FVector2D(2.0 * UJamSim::SkaterRadius + 0.02, 0.0), FVector2D(-10.0, 0.0), PI);
		bool bFirst = false;
		for (int32 F = 0; F < 4 && !bFirst; ++F) { TArray<FJamInput> In = Idle(S); In[S.A].bCrossHold = true; S.Sim->Step(In); bFirst = S.Vic().bCrossBraceHit; }
		TestTrue(TEXT("the first body met takes the braced hit"), bFirst);
		TestTrue(TEXT("then the brace is spent while the button stays down"), S.Att().bCrossSpent && !S.Att().bCrossBraced && S.Att().CrossBraceHits == 1);
		int32 Second = -1;
		for (const FJamSkaterState& K : S.Sim->GetSkaters()) if (K.Team == S.Vic().Team && K.Index != S.V) { Second = K.Index; break; }
		if (Second >= 0 && S.Att().CanAct())
		{
			S.Sim->SetSkater(Second, S.Att().Pos + FVector2D(-2.0 * UJamSim::SkaterRadius - 0.02, 3.0), FVector2D::ZeroVector, 0.0);
			S.Sim->SetSkater(S.A, S.Att().Pos + FVector2D(0.0, 3.0), FVector2D(-6.0, 0.0), PI);
			bool bSecond = false;
			for (int32 F = 0; F < 4; ++F) { TArray<FJamInput> In = Idle(S); In[S.A].bCrossHold = true; S.Sim->Step(In); bSecond |= S.Sim->GetSkaters()[Second].bCrossBraceHit; }
			TestFalse(TEXT("a second body met with the button still down takes no braced hit"), bSecond);
		}
		{ TArray<FJamInput> In = Idle(S); S.Sim->Step(In); }
		TestTrue(TEXT("the release re-arms the brace"), !S.Att().bCrossSpent && S.Att().CrossHoldFrames == 0);
	}
	// 4. The wind-ups.
	{
		FContactScene S = Make(*this, [](FJamGameConfig& G) { G.Contact.CheckWindupFrames = 6; G.Contact.CrossWindupFrames = 5; });
		if (!S.Ok()) return false;
		S.Sim->SetSkater(S.A, FVector2D(20.0, 8.0), FVector2D::ZeroVector, PI);
		int32 Open = -1, Told = 0;
		for (int32 F = 0; F < 10 && Open < 0; ++F)
		{
			TArray<FJamInput> In = Idle(S); In[S.A].bCheck = F == 0; S.Sim->Step(In);
			if (F == 0) Told = S.Att().WindupFrames;
			if (S.Att().CheckWindow > 0) Open = F;
		}
		TestEqual(TEXT("check_windup_frames 6: the figure is told 6 on the press"), Told, 6);
		TestEqual(TEXT("check_windup_frames 6: the window opens 6 frames after the press"), Open, 6);
		// Lane A192: the stick's part is the press's (the strip on frame 0), the shove lands on its man 5 frames later (a standing carrier at arm's length, facing).
		S.Sim->SetSkater(S.V, FVector2D(0.0, 0.0), FVector2D::ZeroVector, 0.0);
		if (!HandPuck(S, S.V)) { AddError(TEXT("the victim did not pick the placed puck up")); return false; }
		S.Sim->SetSkater(S.V, FVector2D(0.0, 0.0), FVector2D::ZeroVector, 0.0);
		S.Sim->SetSkater(S.A, FVector2D(2.0 * UJamSim::SkaterRadius + S.Cfg.Contact.CrossReachM - 0.1, 0.0), FVector2D::ZeroVector, PI);
		int32 Swing = -1, Pressed = -1, Shove = -1, ToldX = -1;
		for (int32 F = 0; F < 12 && Shove < 0; ++F)
		{
			TArray<FJamInput> In = Idle(S); In[S.A].bLift = F == 0; S.Sim->Step(In);
			if (S.Att().bLiftThisFrame) { Pressed = F; ToldX = S.Att().WindupFrames; }
			for (const FJamSimEvent& E : S.Sim->GetFrameEvents()) if (E.Name == JamEvents::Lift && E.Who == S.A) Swing = F;
			if (S.Vic().ContactOutcome != 0 && S.Vic().bContactCross) Shove = F;
			S.Sim->SetSkater(S.V, FVector2D(0.0, 0.0), FVector2D::ZeroVector, 0.0);
			S.Sim->SetSkater(S.A, FVector2D(2.0 * UJamSim::SkaterRadius + S.Cfg.Contact.CrossReachM - 0.1, 0.0), FVector2D::ZeroVector, PI);
		}
		TestTrue(*FString::Printf(TEXT("cross_windup_frames 5: pressed and swung (the strip) on frame 0 (%d, %d), told 5 (%d), the shove lands on frame 5 (%d)"), Pressed, Swing, ToldX, Shove),
			Pressed == 0 && Swing == 0 && ToldX == 5 && Shove == 5);
	}
	{
		FContactScene S = Make(*this, [](FJamGameConfig& G) { G.Contact.CheckWindupFrames = 0; G.Contact.CrossWindupFrames = 0; });
		if (!S.Ok()) return false;
		TArray<FJamInput> In = Idle(S); In[S.A].bCheck = true; S.Sim->Step(In);
		TestTrue(TEXT("the wind-ups at 0 (neutral): the window opens on the press, nothing is told"), S.Att().CheckWindow > 0 && S.Att().WindupFrames == 0 && S.Att().CheckWindupLeft == 0);
	}
	// 5. Lane A200 (track F1, evolution 11; CONTACT-12.md): the bots' own wind-ups (bot_check_windup_frames, bot_cross_windup_frames). The sim decides by
	// FJamSkaterState::bHuman (hashed; SeatGuest sets it on both peers): the human keeps the shared length, a bot waits its own, the online guest is a human.
	{
		// Press a check on frame 0 with skater Who standing alone; the frame its window opens (-1 none in 16) and the frames the figure was told.
		auto CheckOpen = [&](FContactScene& S, int32 Who, int32& Told) -> int32
		{
			for (const FJamSkaterState& K : S.Sim->GetSkaters()) S.Sim->SetSkater(K.Index, FVector2D(-27.0 + 6.0 * K.Index, -10.0), FVector2D::ZeroVector, 0.0);
			Told = 0;
			for (int32 F = 0; F < 90; ++F) { TArray<FJamInput> In = Idle(S); S.Sim->Step(In); }   // any cooldown of an earlier press runs out
			for (const FJamSkaterState& K : S.Sim->GetSkaters()) S.Sim->SetSkater(K.Index, FVector2D(-27.0 + 6.0 * K.Index, -10.0), FVector2D::ZeroVector, 0.0);
			for (int32 F = 0; F < 16; ++F)
			{
				TArray<FJamInput> In = Idle(S); In[Who].bCheck = F == 0; S.Sim->Step(In);
				if (F == 0) Told = S.Sim->GetSkaters()[Who].WindupFrames;
				if (S.Sim->GetSkaters()[Who].CheckWindow > 0) return F;
			}
			return -1;
		};
		FContactScene S = Make(*this, [](FJamGameConfig& G) { G.Contact.CheckWindupFrames = 4; G.Contact.CrossWindupFrames = 4; G.Contact.BotCheckWindupFrames = 8; G.Contact.BotCrossWindupFrames = 10; });
		if (!S.Ok()) return false;
		TestTrue(TEXT("the attacker is the human, the victim a bot"), S.Att().bHuman && !S.Vic().bHuman);
		int32 Told = 0;
		const int32 HumanOpen = CheckOpen(S, S.A, Told);
		TestTrue(*FString::Printf(TEXT("bots 8: the human's press keeps the shared 4 (told %d, opens on frame %d)"), Told, HumanOpen), Told == 4 && HumanOpen == 4);
		const int32 BotOpen = CheckOpen(S, S.V, Told);
		TestTrue(*FString::Printf(TEXT("bots 8: a bot's press waits 8 (told %d, opens on frame %d)"), Told, BotOpen), Told == 8 && BotOpen == 8);
		// The bot's cross-check: the strip is the press's, the shove lands on frame 10 (a standing carrier at arm's length, facing).
		S.Sim->SetSkater(S.A, FVector2D(0.0, 0.0), FVector2D::ZeroVector, 0.0);
		if (!HandPuck(S, S.A)) { AddError(TEXT("the human did not pick the placed puck up")); return false; }
		auto Place = [&]() {
			S.Sim->SetSkater(S.A, FVector2D(0.0, 0.0), FVector2D::ZeroVector, 0.0);
			S.Sim->SetSkater(S.V, FVector2D(2.0 * UJamSim::SkaterRadius + S.Cfg.Contact.CrossReachM - 0.1, 0.0), FVector2D::ZeroVector, PI);
		};
		Place();
		int32 ToldX = -1, Shove = -1;
		for (int32 F = 0; F < 16 && Shove < 0; ++F)
		{
			TArray<FJamInput> In = Idle(S); In[S.V].bLift = F == 0; S.Sim->Step(In);
			if (S.Vic().bLiftThisFrame) ToldX = S.Vic().WindupFrames;
			if (S.Att().ContactOutcome != 0 && S.Att().bContactCross) Shove = F;
			Place();
		}
		TestTrue(*FString::Printf(TEXT("bot_cross_windup_frames 10: a bot's shove is told 10 (%d) and lands on frame 10 (%d)"), ToldX, Shove), ToldX == 10 && Shove == 10);
		// The online guest's seat is a human: SeatGuest (on both peers at frame 0) makes the bot slot a human and its press keeps the shared 4.
		FContactScene G = Make(*this, [](FJamGameConfig& C) { C.Contact.CheckWindupFrames = 4; C.Contact.BotCheckWindupFrames = 8; });
		if (!G.Ok()) return false;
		TestTrue(*FString::Printf(TEXT("the victim's seat can be the guest's (frame %lld)"), G.Sim->GetFrame()), G.Sim->SeatGuest(G.V));
		const int32 GuestOpen = CheckOpen(G, G.V, Told);
		TestTrue(*FString::Printf(TEXT("the guest (bHuman) keeps the shared 4 (told %d, opens on frame %d)"), Told, GuestOpen), Told == 4 && GuestOpen == 4);
	}
	{
		// Absent (the neutral value): a bot waits the shared length.
		FContactScene S = Make(*this, [](FJamGameConfig& G) { G.Contact.CheckWindupFrames = 6; });
		if (!S.Ok()) return false;
		TestTrue(TEXT("bot keys absent in the shipped cartridge"), S.Cfg.Contact.BotCheckWindupFrames < 0 && S.Cfg.Contact.BotCrossWindupFrames < 0);
		for (const FJamSkaterState& K : S.Sim->GetSkaters()) S.Sim->SetSkater(K.Index, FVector2D(-27.0 + 6.0 * K.Index, -10.0), FVector2D::ZeroVector, 0.0);
		int32 Open = -1, Told = 0;
		for (int32 F = 0; F < 12 && Open < 0; ++F)
		{
			TArray<FJamInput> In = Idle(S); In[S.V].bCheck = F == 0; S.Sim->Step(In);
			if (F == 0) Told = S.Vic().WindupFrames;
			if (S.Vic().CheckWindow > 0) Open = F;
		}
		TestTrue(*FString::Printf(TEXT("bot keys absent: a bot waits the shared 6 (told %d, opens on frame %d)"), Told, Open), Told == 6 && Open == 6);
	}
	return true;
}

#endif
