// Third Life rink core, LAB (lane K4): see lab_filter.h. Measurement only.
#include "lab_filter.h"

#include "JamSim.h"
#include "JamEventBus.h"
#include <cmath>
#include <cstdio>
#include <cstring>

namespace Lab
{
	namespace
	{
		struct FVerbName { uint32_t Bit; const char* Name; };
		const FVerbName Names[] = {
			{V_Sprint, "sprint"}, {V_Brake, "brake"}, {V_Stop, "stop"}, {V_Deke, "deke"}, {V_Spin, "spin"}, {V_Shield, "shield"},
			{V_Stick, "stick"}, {V_Pass, "pass"}, {V_Saucer, "saucer"}, {V_OneTimer, "onetimer"}, {V_Tap, "tap"}, {V_Charge, "charge"},
			{V_Shoot, "shoot"}, {V_Poke, "poke"}, {V_Lift, "lift"}, {V_Check, "check"}, {V_Brace, "brace"}, {V_Ability, "ability"},
			{V_Draw, "draw"}, {V_Idle, "idle"},
		};
		// press counters (FLabStats::Press index)
		enum { P_Shoot, P_Pass, P_Check, P_Poke, P_Lift, P_Deke, P_Spin, P_Sprint, P_Brake, P_Brace, P_Ability, P_Stop, P_Count };
		const char* PressNames[P_Count] = {"shoot", "pass", "check", "poke", "lift", "deke", "spin", "sprint", "brake", "brace", "ability", "stop"};
	}

	uint32_t AllVerbs()
	{
		uint32_t M = 0;
		for (const FVerbName& V : Names) if (V.Bit != V_Idle) M |= V.Bit;
		return M;
	}

	const char* VerbName(uint32_t Bit)
	{
		for (const FVerbName& V : Names) if (V.Bit == Bit) return V.Name;
		return "?";
	}

	uint32_t ParseVerbs(const char* List, std::string& Err)
	{
		uint32_t M = 0;
		std::string S(List ? List : "");
		size_t At = 0;
		while (At <= S.size())
		{
			size_t Comma = S.find(',', At);
			if (Comma == std::string::npos) Comma = S.size();
			const std::string W = S.substr(At, Comma - At);
			At = Comma + 1;
			if (W.empty() || W == "none") continue;
			bool bFound = false;
			for (const FVerbName& V : Names) if (W == V.Name) { M |= V.Bit; bFound = true; }
			if (W == "all") { M |= AllVerbs(); bFound = true; }
			if (!bFound) { Err = "unknown verb " + W; return 0; }
		}
		return M;
	}

	void FLabSimAdapter::Reset(const JamAI::FJamMatchConfig& C, uint64_t Seed)
	{
		JamAI::FJamSimAdapter::Reset(C, Seed);
		Stats = FLabStats();
		bPrevShootHeldRaw = bPrevPassHeldRaw = false;
		PrevOut = JamAI::FJamAIInput();
		SpellTeam = -1;
		SpellStart = 0;
		PrevShots = PrevPasses = 0;
		PendingPassBy = -1;
		bCarryOpen = false;
		CarryStartF = CarryLastF = 0;
		LastShotF = LastPassF = -1000;
		PrevRiding = -1; PrevScore[0] = PrevScore[1] = 0;
		for (int i = 0; i < JamAI::kMaxSkaters; ++i) LastRelease[i] = -1000;
		LastOppCarryF = LastHitKeyF = -1000;
		PrevCarrierK8 = -1;
		bFollow = bFollowFirst = false;
		FollowStart = 0;
	}

	void FLabSimAdapter::Filter(JamAI::FJamAIInput& H, const UJamSim& S, int Pi)
	{
		const JamAI::FJamAIInput Raw = H;
		const bool bShootRelease = bPrevShootHeldRaw && !Raw.bShootHeld;
		const bool bPassRelease = bPrevPassHeldRaw && !Raw.bPassHeld;
		bPrevShootHeldRaw = Raw.bShootHeld;
		bPrevPassHeldRaw = Raw.bPassHeld;
		if (Remove == 0) return;
		if (Remove & V_Idle) { H = JamAI::FJamAIInput(); return; }
		const bool bFaceoff = S.GetPhase() == EJamSimPhase::Faceoff || S.IsDrawOpen();
		if (bFaceoff)
		{
			// The draw is its own verb: every other ablation leaves the faceoff as the hand played it.
			if (Remove & V_Draw) { H.bPoke = H.bLift = H.bShoot = H.bCheck = false; }
			return;
		}
		const FJamSkaterState& K = S.GetSkaters()[Pi];
		const bool bCarrying = S.CarrierIndex() == Pi;
		auto Drop = [&](bool& B) { if (B) { ++Stats.Removed; B = false; } };
		if (Remove & V_Sprint) Drop(H.bSprint);
		if (Remove & V_Brake) Drop(H.bBrake);
		if (Remove & V_Deke) Drop(H.bDeke);
		if (Remove & V_Spin) Drop(H.bSpin);
		if (Remove & V_Poke) Drop(H.bPoke);
		if (Remove & V_Lift) Drop(H.bLift);
		if (Remove & V_Check) Drop(H.bCheck);
		if (Remove & V_Brace) Drop(H.bCrossHold);
		if (Remove & V_Ability) Drop(H.bAbility);
		if (Remove & V_Pass) { Drop(H.bPass); Drop(H.bPassHeld); }
		else if (Remove & V_Saucer) { Drop(H.bPassHeld); if (bPassRelease) H.bPass = true; }
		if (Remove & V_Shoot) { Drop(H.bShoot); Drop(H.bShootHeld); }
		else
		{
			if (Remove & V_Charge) { Drop(H.bShootHeld); if (bShootRelease) H.bShoot = true; }
			if (Remove & V_Tap) { if (!(Remove & V_Charge) || !bShootRelease) Drop(H.bShoot); }
		}
		if (Remove & V_OneTimer)
		{
			const int Win = S.GetConfig().Shot.OneTimerWindowFrames;
			// UJamSim::TryShoot's own test (JamSim.cpp:2829) on the frame the step will run (Frame + 1).
			const bool bIn = Win > 0 && K.PassReceivedFrame >= 0 && (S.GetFrame() + 1) - K.PassReceivedFrame <= Win;
			if (bIn) { Drop(H.bShoot); Drop(H.bShootHeld); }
		}
		if (Remove & V_Stick)
		{
			if (H.Stick.X != 0.0 || H.Stick.Y != 0.0) ++Stats.Removed;
			H.Stick = JamAI::FVec2();
		}
		else if ((Remove & V_Shield) && bCarrying && !H.bPass && !H.bShoot && !bPassRelease && !bShootRelease && !H.bShootHeld && !H.bPassHeld)
		{
			// The carry with the blade at rest (ahead at half reach): no sweep, no far-side carry; the stick still aims a pass or a shot.
			if (H.Stick.X != 0.0 || H.Stick.Y != 0.0) ++Stats.Removed;
			H.Stick = JamAI::FVec2();
		}
		if (Remove & V_Stop)
		{
			// UJamSim::StepSkater's reverse brake (JamSim.cpp:1397): input more than 120 deg off a velocity over 1e-6. The hand that never stops this way
			// carves instead: the input is turned to 115 deg off the velocity on the side it was on (the playtester's own carve, JamPlaytester.h BrakeIntent).
			const double Vx = K.Vel.X, Vy = K.Vel.Y;
			const double V = std::sqrt(Vx * Vx + Vy * Vy);
			const double Mx = H.Move.X, My = H.Move.Y;
			const double Mag = std::sqrt(Mx * Mx + My * My);
			if (Mag > 0.05 && V > 0.5 && (Mx * Vx + My * Vy) < -0.5 * Mag * V && !H.bBrake)
			{
				const double Side = (Vx * My - Vy * Mx) >= 0.0 ? 1.0 : -1.0;
				const double A = std::atan2(Vy, Vx) + Side * (115.0 * 3.14159265358979323846 / 180.0);
				H.Move = JamAI::FVec2(std::cos(A) * Mag, std::sin(A) * Mag);
				++Stats.Removed;
			}
		}
	}

	void FLabSimAdapter::EndCarry(int64_t Frame, int How)
	{
		Stats.CarryFrames += CarryLastF - CarryStartF + 1;
		switch (How) { case 0: ++Stats.CarryEndShot; break; case 1: ++Stats.CarryEndPass; break; case 2: ++Stats.CarryEndLost; break;
			case 3: ++Stats.CarryEndKept; break; case 4: ++Stats.CarryEndGoal; break; default: ++Stats.CarryEndOther; break; }
		bCarryOpen = false;
		(void)Frame;
	}

	void FLabSimAdapter::NoteEvent(int64_t Frame)
	{
		if (Stats.LastEventFrame >= 0)
		{
			const int64_t G = Frame - Stats.LastEventFrame;
			Stats.GapSum += G;
			if (G > Stats.GapMax) Stats.GapMax = G;
			if (G > 600) ++Stats.LongGaps;
		}
		++Stats.Events;
		Stats.LastEventFrame = Frame;
	}

	void FLabSimAdapter::Observe(const UJamSim& S, int Pi, const JamAI::FJamAIInput& H)
	{
		++Stats.Frames;
		const bool bLive = S.GetPhase() == EJamSimPhase::Playing && !S.IsDrawOpen();
		// presses: rising edges of what reached the sim
		auto Edge = [&](bool Now, bool Was, int Idx) { if (Now && !Was) ++Stats.Press[Idx]; };
		Edge(H.bShoot || H.bShootHeld, PrevOut.bShoot || PrevOut.bShootHeld, P_Shoot);
		Edge(H.bPass || H.bPassHeld, PrevOut.bPass || PrevOut.bPassHeld, P_Pass);
		Edge(H.bCheck, PrevOut.bCheck, P_Check);
		Edge(H.bPoke, PrevOut.bPoke, P_Poke);
		Edge(H.bLift, PrevOut.bLift, P_Lift);
		Edge(H.bDeke, PrevOut.bDeke, P_Deke);
		Edge(H.bSpin, PrevOut.bSpin, P_Spin);
		Edge(H.bSprint, PrevOut.bSprint, P_Sprint);
		Edge(H.bBrake, PrevOut.bBrake, P_Brake);
		Edge(H.bCrossHold, PrevOut.bCrossHold, P_Brace);
		Edge(H.bAbility, PrevOut.bAbility, P_Ability);
		PrevOut = H;
		const TArray<FJamSkaterState>& Sk = S.GetSkaters();
		if (Pi >= 0 && Sk.IsValidIndex(Pi)) Stats.Press[P_Stop] = Sk[Pi].ReverseBrakes;   // the sim's own count of reverse-brake stops begun (JamSim.cpp:1406)
		const int64_t F = S.GetFrame();
		// lane K8: how each goal crossed the line, and the human's takes with and without a key
		{
			for (const FJamSkaterState& K : Sk) if (K.Index < JamAI::kMaxSkaters && (K.bShotThisFrame || K.bPassThisFrame)) LastRelease[K.Index] = F;
			for (int T = 0; T < 2; ++T)
			{
				if (S.GetScore(T) > PrevScore[T] && bDebugGoals)
				{
					const FJamPuckState& Pk = S.GetPuck();
					std::fprintf(stderr, "GOAL f=%lld team=%d puck=(%.3f,%.3f) prev=(%.3f,%.3f) vel=(%.2f,%.2f) z=%.2f last=%d prevRiding=%d sinceRelease=%lld passFrames=%d", (long long)F, T, Pk.Pos.X, Pk.Pos.Y, Pk.PrevPos.X, Pk.PrevPos.Y,
						Pk.Vel.X, Pk.Vel.Y, Pk.Z, Pk.LastTouch, PrevRiding, PrevRiding >= 0 ? (long long)(F - LastRelease[PrevRiding]) : -1LL, Pk.PassFrames);
#if defined(RINK_THIRDLIFE)
					std::fprintf(stderr, " held=%d", Pk.TlHeldBy);
#endif
					if (Sk.IsValidIndex(Pk.LastTouch)) { const FJamSkaterState& L = Sk[Pk.LastTouch]; std::fprintf(stderr, " toucher=(%.3f,%.3f) blade=(%.3f,%.3f) shot=%d pass=%d team=%d", L.Pos.X, L.Pos.Y, L.BladePos.X, L.BladePos.Y, L.bShotThisFrame ? 1 : 0, L.bPassThisFrame ? 1 : 0, L.Team); }
					std::fprintf(stderr, "\n");
				}
				if (S.GetScore(T) > PrevScore[T])
				{
					const bool bWalk = PrevRiding >= 0 && Sk.IsValidIndex(PrevRiding) && Sk[PrevRiding].Team == T && F - LastRelease[PrevRiding] > 45;
					if (bWalk) ++Stats.GoalsWalk[T]; else ++Stats.GoalsSent[T];
					if (bFollow && Pi >= 0 && Sk.IsValidIndex(Pi) && T == Sk[Pi].Team) { ++Stats.PassThenGoal; if (!bFollowFirst) ++Stats.PassThenShot; }
					bFollow = false;
				}
				PrevScore[T] = S.GetScore(T);
			}
			{
				const int Lt = S.GetPuck().LastTouch;
				if (Pi >= 0 && Sk.IsValidIndex(Pi) && Sk.IsValidIndex(PrevRiding) && Lt != PrevRiding && Sk.IsValidIndex(Lt) && Sk[Lt].Team != Sk[PrevRiding].Team)
				{
					const bool bKey = H.bPoke || H.bLift || H.bCheck || H.bCrossHold || F - LastHitKeyF <= 30;
					if (Lt == Pi) { if (bKey) ++Stats.RideTakesKey; else ++Stats.RideTakesNoKey; }
					if (Lt == Pi && !bKey && bDebugGoals)
					{
						const FJamSkaterState& R0 = Sk[PrevRiding];
						std::fprintf(stderr, "TAKE f=%lld rider=%d shot=%d pass=%d canact=%d stumble=%d down=%d deke=%d spin=%d body_gap=%.2f rider_to_puck=%.2f puck_speed=%.1f rider_speed=%.1f human_speed=%.1f\n", (long long)F, PrevRiding,
							R0.bShotThisFrame ? 1 : 0, R0.bPassThisFrame ? 1 : 0, R0.CanAct() ? 1 : 0, R0.IsStumbling() ? 1 : 0, R0.IsDown() ? 1 : 0, R0.DekeFrames, R0.SpinFrames,
							FVector2D::Distance(R0.Pos, Sk[Pi].Pos) - 0.8, FVector2D::Distance(R0.Pos, S.GetPuck().Pos), S.GetPuck().Vel.Size(), R0.Vel.Size(), Sk[Pi].Vel.Size());
					}
					else if (PrevRiding == Pi) ++Stats.RideTakesOffHuman;
					else ++Stats.RideTakesBots;
				}
			}
			PrevRiding = S.RidingCarrier();
			if (H.bPoke || H.bLift || H.bCheck || H.bCrossHold) LastHitKeyF = F;
			const int Ck = S.CarrierIndex();
			if (Pi >= 0 && Sk.IsValidIndex(Pi))
			{
				if (Ck >= 0 && Sk[Ck].Team != Sk[Pi].Team) LastOppCarryF = F;
				if (Ck == Pi && PrevCarrierK8 != Pi && F - LastOppCarryF <= 20) { if (F - LastHitKeyF <= 30) ++Stats.TakesKey; else ++Stats.TakesNoKey; }
			}
			PrevCarrierK8 = Ck;
		}
		// goals (the goal's frame already belongs to the goal pause) and the human's shots and passes, live or not
		for (const FJamSimEvent& E : S.GetFrameEvents())
		{
			if (E.Name == JamEvents::Goal) { NoteEvent(F); if (Stats.FirstGoal < 0) Stats.FirstGoal = F; if (bCarryOpen) EndCarry(F, 4); }
		}
		if (Pi >= 0 && Sk.IsValidIndex(Pi))
		{
			if (Sk[Pi].Shots > PrevShots) LastShotF = F;
			if (Sk[Pi].Passes > PrevPasses) { LastPassF = F; PendingPassBy = Pi; }
			PrevShots = Sk[Pi].Shots; PrevPasses = Sk[Pi].Passes;
		}
		// the draw: the human's result as the centre, and who carries two seconds after the drop
		if (Pi >= 0 && Sk.IsValidIndex(Pi)) { if (Sk[Pi].DrawResult > 0) ++Stats.DrawsWon; else if (Sk[Pi].DrawResult < 0) ++Stats.DrawsLost; }
		for (const FJamSimEvent& E : S.GetFrameEvents()) if (E.Name == JamEvents::Faceoff && E.Who < 0) { Stats.DropFrame = F; ++Stats.Drops; }
		if (Stats.DropFrame >= 0 && F - Stats.DropFrame == 120 && Pi >= 0)
		{
			const int Cd = S.CarrierIndex();
			if (Cd >= 0) { if (Sk[Cd].Team == Sk[Pi].Team) ++Stats.DrawsKeptAt2s; else ++Stats.DrawsOppAt2s; }
		}
		if (!bLive) { if (bCarryOpen) EndCarry(F, 5); PendingPassBy = -1; if (bFollow && !bFollowFirst) ++Stats.PassThenNone; bFollow = false; return; }
		++Stats.PlayFrames;
		// speeds
		for (const FJamSkaterState& K : Sk)
		{
			const double V = K.Vel.Size();
			if (K.Index == Pi) { Stats.HumanSum += V; ++Stats.HumanN; if (V > Stats.HumanMax) Stats.HumanMax = V; if (V > 10.0) ++Stats.HumanFast; }
			else if (K.Team == 0 || K.Team == 1) { Stats.BotSum[K.Team] += V; ++Stats.BotN[K.Team]; if (V > Stats.BotMax[K.Team]) Stats.BotMax[K.Team] = V; if (V > 10.0) ++Stats.BotFast[K.Team]; }
		}
		// the shape of play around the puck
		{
			const FJamPuckState& Pk = S.GetPuck();
			int In3 = 0, In2 = 0;
			for (const FJamSkaterState& K : Sk)
			{
				if (K.IsDown() || K.InBox()) continue;
				const double D = FVector2D::Distance(K.Pos, Pk.Pos);
				if (D <= 3.0) ++In3;
				if (D <= 2.0) ++In2;
			}
			if (In3 >= 5) ++Stats.PileFrames;
			if (In2 >= 4) ++Stats.ScrumFrames;
			if (BoardDistance(JamAI::FVec2(Pk.Pos.X, Pk.Pos.Y)) > -1.5) ++Stats.BoardPuckFrames;   // FJamSimAdapter::BoardDistance (signed, inside negative)
			const bool bLoose = S.CarrierIndex() < 0;
			if (bLoose) ++Stats.LooseFrames;
			if (bLoose && Pk.Vel.Size() < 1.0) { ++Stats.DeadPuckFrames; if (++Stats.DeadRun == 60) ++Stats.DeadSpells; }
			else Stats.DeadRun = 0;
		}
		// events: shots, landed hits
		for (const FJamSimEvent& E : S.GetFrameEvents())
		{
			if (E.Name == JamEvents::Shot && Sk.IsValidIndex(E.Who)) { ++Stats.Shots[Sk[E.Who].Team]; NoteEvent(F); }
		}
		for (const FJamSkaterState& K : Sk) if (K.ContactOutcome >= UJamSim::ContactStumble && K.ContactBy >= 0) { ++Stats.HitsLanded; NoteEvent(F); }
		// possession by team: a loose puck stays with the team that carried it last
		const int C = S.CarrierIndex();
		if (C >= 0)
		{
			const int T = Sk[C].Team;
			if (T != SpellTeam)
			{
				if (SpellTeam >= 0) { Stats.SpellFrames[SpellTeam] += F - SpellStart; ++Stats.Spells[SpellTeam]; ++Stats.Changes; NoteEvent(F); }
				SpellTeam = T; SpellStart = F;
			}
			// a human pass lands with the next carrier who is not the passer (the passer taking it back cancels it)
			// (the puck is still in the passer's reach for a few frames after it left: only a re-take 15 frames on cancels it)
			if (PendingPassBy >= 0 && F > LastPassF)
			{
				if (C != PendingPassBy)
				{
					if (T == Sk[PendingPassBy].Team) { ++Stats.PassesCompleted; if (bFollow && !bFollowFirst) ++Stats.PassThenNone; bFollow = true; bFollowFirst = false; FollowStart = F; }
					else ++Stats.PassesIntercepted;
					PendingPassBy = -1;
				}
				else if (F - LastPassF > 15) PendingPassBy = -1;
			}
		}
		if (SpellTeam >= 0) ++Stats.TeamFrames[SpellTeam];
		// lane K8: the human's completed pass, followed
		if (bFollow && Pi >= 0 && Sk.IsValidIndex(Pi))
		{
			bool bMateShot = false;
			for (const FJamSimEvent& E : S.GetFrameEvents()) if (E.Name == JamEvents::Shot && Sk.IsValidIndex(E.Who) && E.Who != Pi && Sk[E.Who].Team == Sk[Pi].Team) bMateShot = true;
			const bool bOpp = C >= 0 && Sk[C].Team != Sk[Pi].Team;
			if (!bFollowFirst)
			{
				if (bMateShot) { ++Stats.PassThenShot; bFollowFirst = true; }
				else if (C == Pi && F > FollowStart) { ++Stats.PassThenBack; bFollowFirst = true; }
				else if (bOpp) { ++Stats.PassThenLost; bFollowFirst = true; }
			}
			if (bOpp) bFollow = false;
			else if (F - FollowStart > 300) { if (!bFollowFirst) ++Stats.PassThenNone; bFollow = false; }
		}
		// the human's carries: from the frame he becomes the carrier to his shot, his pass, or another skater carrying (a loose frame in between, the puck
		// a stride ahead of the blade, does not end it)
		if (Pi >= 0)
		{
			if (C == Pi) { if (!bCarryOpen) { bCarryOpen = true; ++Stats.Carries; CarryStartF = F; } CarryLastF = F; }
			if (bCarryOpen)
			{
				if (LastShotF == F) EndCarry(F, 0);
				else if (LastPassF == F) EndCarry(F, 1);
				else if (C >= 0 && C != Pi) EndCarry(F, Sk[C].Team == Sk[Pi].Team ? 3 : 2);
			}
		}
	}

	void FLabSimAdapter::View(JamAI::FJamAIWorld& W) const
	{
		JamAI::FJamSimAdapter::View(W);
		if (SignalKind > 0 && !W.bFrozen) { W.IntentKind = SignalKind; W.IntentTarget = -1; W.IntentFramesLeft = 600; }
	}

	JamAI::FJamAIStepEvents FLabSimAdapter::Step(const JamAI::FJamAIInput* In)
	{
		const UJamSim* S = GetSim();
		const int Pi = S ? S->GetHumanIndex() : -1;
		JamAI::FJamAIInput Local[JamAI::kMaxSkaters];
		const int N = S ? FMath::Min(S->GetSkaters().Num(), JamAI::kMaxSkaters) : 0;
		for (int i = 0; i < N; ++i) Local[i] = In[i];
		if (Pi >= 0 && Pi < N)
		{
			if (Plan) Local[Pi] = Plan->Think(*S, Pi, Local, N);
			Filter(Local[Pi], *S, Pi);
		}
		if (Plan && Plan->bCheckClone && S) Plan->CheckBegin(*S);
		const JamAI::FJamAIStepEvents Ev = JamAI::FJamSimAdapter::Step(Local);
		if (Plan && Plan->bCheckClone && S) Plan->CheckEnd(*S, Local, N);
		if (S && Pi >= 0 && Pi < N)
		{
			Observe(*S, Pi, Local[Pi]);
		}
		return Ev;
	}

	std::string StatsJson(const FLabStats& S)
	{
		char B[4096];
		int N = std::snprintf(B, sizeof(B),
			"{\"tool\":\"rinklab.stats/1\",\"frames\":%lld,\"play_frames\":%lld,\"team_frames\":[%lld,%lld],\"spells\":[%d,%d],\"spell_frames\":[%lld,%lld],"
			"\"changes\":%d,\"carries\":%d,\"carry_frames\":%lld,\"carry_end\":{\"shot\":%d,\"pass\":%d,\"lost\":%d,\"kept\":%d,\"goal\":%d,\"other\":%d},"
			"\"passes_completed\":%d,\"passes_intercepted\":%d,\"removed\":%d,"
			"\"human_max\":%.3f,\"human_mean\":%.3f,\"human_fast\":%lld,\"bot_max\":[%.3f,%.3f],\"bot_mean\":[%.3f,%.3f],\"bot_fast_share\":[%.4f,%.4f],"
			"\"events\":%d,\"gap_mean\":%.1f,\"gap_max\":%lld,\"long_gaps\":%d,\"shots\":[%d,%d],\"hits_landed\":%d,\"first_goal\":%lld,\"pile_frames\":%lld,\"scrum_frames\":%lld,\"dead_puck_frames\":%lld,\"dead_spells\":%d,\"board_puck_frames\":%lld,\"loose_frames\":%lld,\"draws\":[%d,%d],\"drops\":%d,\"drop_carrier_2s\":[%d,%d],\"goals_walk\":[%d,%d],\"goals_sent\":[%d,%d],\"takes_key\":%d,\"takes_nokey\":%d,\"ride_takes\":[%d,%d,%d,%d],\"pass_then\":{\"shot\":%d,\"back\":%d,\"lost\":%d,\"none\":%d,\"goal\":%d},\"press\":{",
			(long long)S.Frames, (long long)S.PlayFrames, (long long)S.TeamFrames[0], (long long)S.TeamFrames[1], S.Spells[0], S.Spells[1],
			(long long)S.SpellFrames[0], (long long)S.SpellFrames[1], S.Changes, S.Carries, (long long)S.CarryFrames,
			S.CarryEndShot, S.CarryEndPass, S.CarryEndLost, S.CarryEndKept, S.CarryEndGoal, S.CarryEndOther, S.PassesCompleted, S.PassesIntercepted, S.Removed,
			S.HumanMax, S.HumanN ? S.HumanSum / S.HumanN : 0.0, (long long)S.HumanFast, S.BotMax[0], S.BotMax[1],
			S.BotN[0] ? S.BotSum[0] / S.BotN[0] : 0.0, S.BotN[1] ? S.BotSum[1] / S.BotN[1] : 0.0,
			S.BotN[0] ? double(S.BotFast[0]) / S.BotN[0] : 0.0, S.BotN[1] ? double(S.BotFast[1]) / S.BotN[1] : 0.0,
			S.Events, S.Events > 1 ? double(S.GapSum) / (S.Events - 1) : 0.0, (long long)S.GapMax, S.LongGaps, S.Shots[0], S.Shots[1], S.HitsLanded,
			(long long)S.FirstGoal, (long long)S.PileFrames, (long long)S.ScrumFrames, (long long)S.DeadPuckFrames, S.DeadSpells, (long long)S.BoardPuckFrames,
			(long long)S.LooseFrames, S.DrawsWon, S.DrawsLost, S.Drops, S.DrawsKeptAt2s, S.DrawsOppAt2s, S.GoalsWalk[0], S.GoalsWalk[1], S.GoalsSent[0], S.GoalsSent[1], S.TakesKey, S.TakesNoKey, S.RideTakesKey, S.RideTakesNoKey, S.RideTakesOffHuman, S.RideTakesBots, S.PassThenShot, S.PassThenBack, S.PassThenLost, S.PassThenNone, S.PassThenGoal);
		for (int i = 0; i < P_Count; ++i) N += std::snprintf(B + N, sizeof(B) - N, "%s\"%s\":%d", i ? "," : "", PressNames[i], S.Press[i]);
		N += std::snprintf(B + N, sizeof(B) - N, "}}");
		return std::string(B, N);
	}
}
