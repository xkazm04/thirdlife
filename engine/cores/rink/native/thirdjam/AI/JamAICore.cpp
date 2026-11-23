// Lane A2: brain and player bot (engine-free). See JamAICore.h.
#include "JamAICore.h"

#include <cstdlib>
#include <cstring>
#include <initializer_list>

namespace JamAI
{
	namespace AICoreLocal
	{
		using namespace AIMath;   // lane A55: Clamp, Sign, DegToRad, RadToDeg, Rotate live in JamAICore.h (shared with JamPlaytester.cpp)
		inline double Lerp(double A, double B, double T) { return A + (B - A) * T; }
		inline FVec2 LerpV(const FVec2& A, const FVec2& B, double T) { return A + (B - A) * T; }
		// lane A3: deterministic value in [-1, 1] from two integers (splitmix64 finaliser); no state, no seed
		inline double Hash11(uint64_t A, uint64_t B)
		{
			uint64_t Z = A * 0x9E3779B97F4A7C15ull + B + 0x632BE59BD9B4E019ull;
			Z = (Z ^ (Z >> 30)) * 0xBF58476D1CE4E5B9ull;
			Z = (Z ^ (Z >> 27)) * 0x94D049BB133111EBull;
			Z ^= Z >> 31;
			return static_cast<double>(Z >> 11) * (2.0 / 9007199254740992.0) - 1.0;
		}
		// R-0035 (lane A52): the shooter's charge choice (ChargeWindowFor): inside ChargeCloseM of the net a tap; a lift level must clear the bar by ChargeBarMarginM.
		constexpr double ChargeCloseM = 6.0;
		constexpr double ChargeBarMarginM = 0.1;
		constexpr double ChargeRealNetM = 1.0;   // R-0044 (lane A91): the full wind-up is the bots' shot only at a net of real height (sniper's 1.22)
	}
	using namespace AICoreLocal;
	namespace AICoreLocal
	{
		inline int TeamSize(const FJamAIWorld& W, int Team)
		{
			int N = 0;
			for (int i = 0; i < W.NumSkaters; ++i) { if (W.Skaters[i].Team == Team) { ++N; } }
			return N;
		}
	}
	// Lane A83: the five-a-side parts of the support and the back (defined after Decide)
	bool FiveSupport(const FJamAIWorld& W, int Id, double SlowRadius, FVec2& Out);
	bool FiveSlot(const FJamAIWorld& W, int Id, const FJamBotSkill& Gk, double SlowRadius, FVec2& Out);
	bool MarkSlotMan(const FJamAIWorld& W, int Id, const FJamBotSkill& Gk, FVec2& Out);   // lane A206 (evolution 9, wave 2)
	namespace FiveLocal { int RoleOrdinal(const FJamAIWorld& W, int Id); }   // lane A206 (wave 4): CreaseKeeper and NoCarrierAlone read it above its definition

	double BoardSdf(const FJamAIWorld& W, const FVec2& P, FVec2& OutNormal)
	{
		const double Rc = W.CornerRadius;
		const double Qx = std::fabs(P.X) - (W.HalfLength - Rc);
		const double Qy = std::fabs(P.Y) - (W.HalfWidth - Rc);
		const double Mx = Qx > 0.0 ? Qx : 0.0, My = Qy > 0.0 ? Qy : 0.0;
		const double Inner = Qx > Qy ? Qx : Qy;
		const double D = std::sqrt(Mx * Mx + My * My) + (Inner < 0.0 ? Inner : 0.0) - Rc;
		const double Sx = P.X >= 0.0 ? 1.0 : -1.0, Sy = P.Y >= 0.0 ? 1.0 : -1.0;
		if (Qx > 0.0 && Qy > 0.0) { OutNormal = FVec2(Sx * Qx, Sy * Qy).Normalized(); }
		else if (Qx > Qy) { OutNormal = FVec2(Sx, 0.0); }
		else { OutNormal = FVec2(0.0, Sy); }
		return D;
	}

	bool BoardPeel(const FJamAIWorld& W, const FVec2& Puck, double AttackSign, FVec2& OutDir)
	{
		constexpr double Inward = 1.0;   // 45 degrees off the board
		FVec2 N;
		if (BoardSdf(W, Puck, N) < -1.6)
		{
			return false;
		}
		FVec2 T = N.Perp();
		if (std::fabs(T.X) < 0.2)
		{
			// end board: slide it towards the nearer corner, where the board turns and it can come out
			if (T.Y * Puck.Y < 0.0) { T = -T; }
		}
		else if (T.X * AttackSign < 0.0)
		{
			T = -T;
		}
		OutDir = (T - N * Inward).Normalized();
		return true;
	}

	FVec2 Arrive(const FVec2& From, const FVec2& Target, double SlowRadius)
	{
		const FVec2 D = Target - From;
		const double Dist = D.Length();
		if (Dist < 0.0001)
		{
			return FVec2();
		}
		return D * (1.0 / Dist) * Clamp(Dist / (SlowRadius > 0.001 ? SlowRadius : 0.001), 0.0, 1.0);
	}

	FVec2 Separate(const FVec2& From, const FJamAIWorld& W, int Self, double Radius)
	{
		FVec2 Push;
		for (int i = 0; i < W.NumSkaters; ++i)
		{
			if (i == Self)
			{
				continue;
			}
			const FVec2 D = From - W.Skaters[i].Pos;
			const double Dist = D.Length();
			if (Dist > 0.0001 && Dist < Radius)
			{
				Push += D * (1.0 / Dist) * (1.0 - Dist / Radius);
			}
		}
		return Push.LimitLength(1.0);
	}

	void FJamBrain::Reset()
	{
		Anchor = FVec2(1e6, 0.0);
		AnchorFrame = 0;
		bStalled = false;
		Stalls = 0;
		StallChaser[0] = StallChaser[1] = -1;
		for (int i = 0; i < kMaxSkaters; ++i)
		{
			Used[i] = ERole::Chaser;
			InReach[i] = 0;
			CheckCool[i] = 0;
			LiftLast[i] = -100000;
			for (int k = 0; k <= kMaxReactionFrames; ++k)
			{
				Hist[i][k] = FJamAIInput();
			}
		}
		Tick = 0;
		TeamIntent = FJamAIIntent();
		PlayThinks = 0;
		Faceoffs = 0;
		FaceoffStart = 0;
		DrawJumps = 0;
		DrawPresses = 0;
		for (int i = 0; i < kMaxSkaters; ++i) { Pressed[i] = 0; Charging[i] = 0; bGoalieNow[i] = false; GoalieSideNow[i] = 0; }
		bWasFaceoff = false;
		PuckHistFrame = -1;   // lane A51
		PuckHistCount = 0;
		// lane A94
		for (int k = 0; k < kPhaseHist; ++k) { PossHist[k] = FPoss(); }
		PossFrame = -1;
		PossNow = FPoss();
		for (int i = 0; i < kMaxSkaters; ++i) { Job[i] = EJob::None; CarryFrames[i] = 0; }
		// lane A115
		for (int i = 0; i < kMaxSkaters; ++i) { BrakeHold[i] = 0; BrakeCool[i] = 0; bWantStop[i] = false; bPlaysPuck[i] = false; PassHold[i] = 0; bSecondMan[i] = false; }
		PressCarrier[0] = PressCarrier[1] = PressFirst[0] = PressFirst[1] = -1;
		MeantBrakes = 0;
		Carves = 0;
		for (int i = 0; i < kMaxSkaters; ++i) { DownNear[i] = 0; DownNearFrame[i] = -10; bDownLeaving[i] = false; ClumpRun[i] = 0; ClumpFrame[i] = -10; bClumpSplit[i] = false; }   // lane A202
		DropFrame9 = -100000; bWasDrawOpen9 = false; DropPos9 = FVec2(); FirstDrop9 = -1;
		for (int i = 0; i < kMaxSkaters; ++i) { MeetBy9[i] = -1; MeetStart9[i] = -100000; MeetVel9[i] = FVec2(); }   // lane A206 READY 5 LastPassBy9 = -1; AloneRun9[0] = AloneRun9[1] = 0;   // lane A206 wave 3
		for (int i = 0; i < kMaxSkaters; ++i) { ReceivedFrom9[i] = -1; ReceivedFrame9[i] = -100000; }
	}

	// Lane A51 (R-0034): one entry per frame: the puck's offset from the carrier's body (the carrier's index, -1 loose).
	void FJamBrain::RecordPuck(const FJamAIWorld& W)
	{
		if (W.Frame == PuckHistFrame) { return; }
		if (PuckHistFrame >= 0 && W.Frame != PuckHistFrame + 1) { PuckHistCount = 0; }   // a jump (restart, a skipped frame): the history starts over
		FPuckHist& H = PuckHist[static_cast<int>(W.Frame % kPuckHist)];
		H.Carrier = W.Carrier;
		H.Rel = (W.Carrier >= 0 && W.Carrier < W.NumSkaters) ? W.PuckPos - W.Skaters[W.Carrier].Pos : W.PuckPos;
		PuckHistFrame = W.Frame;
		if (PuckHistCount < kPuckHist) { ++PuckHistCount; }
	}

	FVec2 FJamBrain::PuckSeen(const FJamAIWorld& W, int Id) const
	{
		const int C = W.Carrier;
		if (C < 0 || C >= W.NumSkaters || W.Skaters[C].Team == W.Skaters[Id].Team) { return W.PuckPos; }   // only an opposing carrier is read late
		const int React = W.SweepBotReactFrames >= 0 ? W.SweepBotReactFrames : SkillOf(W, Id).SweepReactFrames;
		if (React <= 0 || React >= kPuckHist || PuckHistCount <= React) { return W.PuckPos; }
		const FPuckHist& H = PuckHist[static_cast<int>((W.Frame - React) % kPuckHist)];
		if (H.Carrier != C) { return W.PuckPos; }   // a fresh carrier is read live
		return W.Skaters[C].Pos + H.Rel;
	}

	const FJamBotSkill& FJamBrain::SkillOf(const FJamAIWorld& W, int Id) const
	{
		const int PlayerTeam = W.PlayerIndex >= 0 ? W.Skaters[W.PlayerIndex].Team : 0;
		return W.Skaters[Id].Team != PlayerTeam ? Params.Opp : Params.Mate;
	}

	// R-0035 (lane A52): the shooter's charge reads the net's height. A bot whose profile charges at all (ShotChargeFrames > 0) holds for the window that
	// lands the puck under the bar: the full charge when full_m clears the bar by the margin (a real 1.22 net), half_frames when half_m does (the 0.61
	// bar), a tap from close (inside ChargeCloseM: the lob is not worth the hold) or when nothing fits. A bot with aim error (rookie's profile when it
	// charges) mis-charges by up to that error in frames (a fixed function of the skater and the 2-second window, like the aim). Pure.
	// UJamSim::LiftForCharge's rule on the brain's copy of the keys: the height a hold of F frames arrives at over the goal line.
	double LiftAtFrames(const FJamAIWorld& W, int F)
	{
		const int Max = W.ChargeFramesMax;
		const int Half = W.LiftHalfFrames;
		if (Max <= 0) { return W.LiftTapM; }
		const double C = static_cast<double>(F < 0 ? 0 : (F > Max ? Max : F));
		if (Half <= 0 || Half >= Max) { return Lerp(W.LiftTapM, W.LiftFullM, C / Max); }
		if (C <= Half) { return Lerp(W.LiftTapM, W.LiftHalfM, C / Half); }
		return Lerp(W.LiftHalfM, W.LiftFullM, (C - Half) / (Max - Half));
	}

	int ChargeWindowFor(const FJamAIWorld& W, int Id, const FJamBotSkill& K)
	{
		const int ChargeFrames = K.Hk.ShotCharge9Frames > K.ShotChargeFrames ? K.Hk.ShotCharge9Frames : K.ShotChargeFrames;   // lane A206 (evolution 9): rookie winds up too
		if (ChargeFrames <= 0 || W.ChargeFramesMax <= 0) { return 0; }
		const FJamAISkater& S = W.Skaters[Id];
		const double Dgoal = W.PuckPos.DistTo(W.OppGoal(S.Team));
		if (Dgoal < ChargeCloseM) { return 0; }
		// The longest hold whose arrival stays under the bar by the margin (the lift grows with the hold).
		int Best = -1;
		for (int F = 0; F <= W.ChargeFramesMax; ++F)
		{
			if (LiftAtFrames(W, F) + ChargeBarMarginM < W.GoalHeightM) { Best = F; } else { break; }
		}
		if (Best <= 0) { return 0; }
		// A real net takes the full charge; a low bar takes the profile's wind-up (pro 10, all_star 18) cut to what clears it (0.61: 10 frames, 0.495 m).
		// R-0044 (lane A91): "a real net" is now said by its height (ChargeRealNetM), not only by the full charge clearing the bar: with shot.lift.full_m 0.5
		// the full charge clears the 0.61 bar by the margin too, and this line gave every charging bot the 30-frame wind-up (ProCharge's mean charge 0.29 ->
		// 0.54): a difficulty change no ruling asked for. Under a low bar the profile's wind-up stands (pro 10, all_star 18), cut to what clears the bar.
		const bool bRealNet = W.GoalHeightM >= ChargeRealNetM;
		int Window = Best >= W.ChargeFramesMax && bRealNet ? W.ChargeFramesMax : (Best < ChargeFrames ? Best : ChargeFrames);
		if (K.AimErrorDeg > 0.0 && Window > 0)
		{
			Window += static_cast<int>(std::lround(K.AimErrorDeg * Hash11(static_cast<uint64_t>(Id) + 17, static_cast<uint64_t>(W.Frame / 120))));
		}
		return Window < 0 ? 0 : (Window > W.ChargeFramesMax ? W.ChargeFramesMax : Window);
	}

	void FJamBrain::Think(const FJamAIWorld& W, FJamAIInput* Out)
	{
		// Lane A115 (measurement only, as JAM_BRAIN_CARRIER in JamSimAdapter.cpp): JAM_BRAIN2_OFF=all replays the brain of evolution 1; a list of letters
		// switches single rules off (p pass room, s support, c chase ahead, b brake meant, x stop before the cut, r carry sprint, g gap control, h shield
		// read, m the mates' stick). Unset: the profile's.
		{
			static const char* const Off2 = std::getenv("JAM_BRAIN2_OFF");
			if (Off2 && Off2[0])
			{
				const bool bAll = std::strcmp(Off2, "all") == 0;
				for (FJamBotSkill* K : { &Params.Mate, &Params.Opp })
				{
					if (bAll || std::strchr(Off2, 'p')) { K->Hk.bPassRoom = false; }
					if (bAll || std::strchr(Off2, 's')) { K->Hk.bSupportHuman = false; }
					if (bAll || std::strchr(Off2, 'c')) { K->Hk.bChaseAhead = false; }
					if (bAll || std::strchr(Off2, 'b')) { K->Hk.bBrakeMeant = false; }
					if (bAll || std::strchr(Off2, 'r')) { K->Hk.bCarrySprint = false; }
					if (bAll || std::strchr(Off2, 'x')) { K->Hk.bStopCut = false; }
					if (bAll || std::strchr(Off2, 'g')) { K->Hk.bGapControl = false; }
					if (bAll || std::strchr(Off2, 'h')) { K->Hk.bReadShield = false; }
					if (bAll || std::strchr(Off2, 'm')) { K->Hk.MateStickFrames = -1; }
				}
			}
		}
		// Lane A134 (measurement only, as JAM_BRAIN2_OFF above): JAM_BRAIN3_ON=k plays the opposing side with bPressInHunt (for a run of the law-3 drill,
		// whose levels come from the profile and take no tune). Unset: the profile's.
		{
			static const char* const On3 = std::getenv("JAM_BRAIN3_ON");
			if (On3 && std::strchr(On3, 'k')) { Params.Opp.Hk.bPressInHunt = true; }
		}
		for (int i = 0; i < kMaxSkaters; ++i) { bWantStop[i] = false; bPlaysPuck[i] = false; }
		RecordPuck(W);   // lane A51: before any bot reads the puck
		// Lane A94 (R-0045 law 2): possession, the carry clock and the shape jobs, before any bot decides
		ReadPossession(W);
		for (int i = 0; i < W.NumSkaters; ++i)
		{
			CarryFrames[i] = W.bFrozen ? 0 : (W.CarrierOrHolder() == i ? CarryFrames[i] + 1 : (W.PuckLastTouch == i ? CarryFrames[i] : 0));
		}
		// Lane A206 wave 3: bookkeeping only (nothing steers here): the drop's frame, who passed the puck to whom, how long an opposing carrier near each net
		// has been alone
		if (W.bDrawOpen && !bWasDrawOpen9) { DropFrame9 = W.Frame; DropPos9 = W.PuckPos; if (FirstDrop9 < 0 || W.Frame < FirstDrop9) { FirstDrop9 = W.Frame; } }
		bWasDrawOpen9 = W.bDrawOpen;
		for (int i = 0; i < W.NumSkaters; ++i)
		{
			if (CarryFrames[i] == 1)
			{
				const bool bMate = LastPassBy9 >= 0 && LastPassBy9 < W.NumSkaters && LastPassBy9 != i && W.Skaters[LastPassBy9].Team == W.Skaters[i].Team;
				ReceivedFrom9[i] = bMate ? LastPassBy9 : -1; ReceivedFrame9[i] = W.Frame;
			}
		}
		if (W.PuckPassBy >= 0) { LastPassBy9 = W.PuckPassBy; }
		else if (W.CarrierOrHolder() >= 0 && CarryFrames[W.CarrierOrHolder()] > 1) { LastPassBy9 = -1; }
		for (int Tm = 0; Tm < 2; ++Tm)
		{
			const int Cc = W.Carrier;
			bool bAlone = false;
			if (!W.bFrozen && Cc >= 0 && Cc < W.NumSkaters && W.Skaters[Cc].Team != Tm && W.Skaters[Cc].Pos.DistTo(W.OwnGoal(Tm)) < 35.0)
			{
				bAlone = true;
				for (int o = 0; o < W.NumSkaters; ++o) { if (W.Skaters[o].Team == Tm && !W.Skaters[o].bDown && W.Skaters[o].Pos.DistTo(W.Skaters[Cc].Pos) < 3.0) { bAlone = false; break; } }
			}
			AloneRun9[Tm] = bAlone ? AloneRun9[Tm] + 1 : 0;
		}
		AssignJobs(W);
		TeamIntent = FJamAIIntent();
		if (W.IntentKind >= 1 && W.IntentKind <= 4 && W.IntentFramesLeft > 0)
		{
			TeamIntent.Kind = static_cast<ETeamIntent>(W.IntentKind);
			TeamIntent.IssuedFrame = W.Frame;
			TeamIntent.Frames = W.IntentFramesLeft;
			TeamIntent.Target = W.IntentTarget;
		}
		const FVec2 Pp = W.PuckPos;
		if (Pp.DistTo(Anchor) > Params.StallMoveM || W.Frame < AnchorFrame)
		{
			Anchor = Pp;
			AnchorFrame = W.Frame;
		}
		const bool bWas = bStalled;
		bStalled = !W.bFrozen && (W.Frame - AnchorFrame > Params.StallFrames);
		if (bStalled && !bWas)
		{
			++Stalls;
		}
		// Stall: the nearest support of each team becomes a chaser.
		StallChaser[0] = StallChaser[1] = -1;
		if (bStalled)
		{
			double Best[2] = {1e18, 1e18};
			for (int i = 0; i < W.NumSkaters; ++i)
			{
				const FJamAISkater& S = W.Skaters[i];
				if (W.IsHumanSeat(i) || S.Role != ERole::Support)
				{
					continue;
				}
				const double D = S.Pos.DistTo(Pp);
				if (D < Best[S.Team])
				{
					Best[S.Team] = D;
					StallChaser[S.Team] = i;
				}
			}
		}
		const int PlayerTeam = W.PlayerIndex >= 0 ? W.Skaters[W.PlayerIndex].Team : 0;
		// lane A3: reaction delay. While frozen (goal pause) the ring is cleared, so after a faceoff a bot with delay N stands
		// for N frames; while playing, the input sent is the one decided N thinks ago.
		constexpr int Ring = kMaxReactionFrames + 1;
		if (W.bFaceoffPhase && !bWasFaceoff) { ++Faceoffs; FaceoffStart = W.Frame; }
		bWasFaceoff = W.bFaceoffPhase;
		if (W.bFrozen)
		{
			PlayThinks = 0;
			for (int i = 0; i < kMaxSkaters; ++i)
			{
				for (int k = 0; k < Ring; ++k)
				{
					Hist[i][k] = FJamAIInput();
				}
			}
		}
		else
		{
			++Tick;
			++PlayThinks;
		}
		const int Head = static_cast<int>(Tick % Ring);
		for (int i = 0; i < W.NumSkaters; ++i)
		{
			if (W.IsHumanSeat(i))   // lane A129: the guest's seat too
			{
				continue;
			}
			FJamAIInput In;
			if (W.bFrozen || W.Skaters[i].bDown)
			{
				InReach[i] = 0;
				Charging[i] = 0;
				bGoalieNow[i] = false;
				BrakeHold[i] = 0;   // lane A115
				// R-0013 draw: a centre that jumps early (pokes in the countdown) loses the draw; rookie does it at its rate
				const FJamBotSkill& K = SkillOf(W, i);
				if (W.bFaceoffPhase && W.Skaters[i].bCentre && W.FaceoffCountdown == 6 && K.DrawJumpPct > 0
					&& static_cast<int>((Hash11(static_cast<uint64_t>(FaceoffStart) * 7 + 1, static_cast<uint64_t>(i)) + 1.0) * 50.0) < K.DrawJumpPct)
				{
					In.bPoke = true;
					++DrawJumps;
				}
				Hist[i][Head] = In;
				Out[i] = In;
				continue;
			}
			// lane A3 (R-0009): the back is the net's last line (no goalies): it keeps full speed and reacts at once at every level
			const bool bBackRole = W.Skaters[i].Role == ERole::Back;
			// lane A112 (R-0048 point 4): the level's speed scale is the opposing side's; the human's mates skate at MateSpeedScale when it is set (0 = SpeedScale)
			const bool bHumansMate = W.PlayerIndex >= 0 && W.Skaters[i].Team == PlayerTeam && Params.MateSpeedScale > 0.0;
			double Sc = (bHumansMate ? Params.MateSpeedScale : Params.SpeedScale) * (W.Skaters[i].Team != PlayerTeam && !bBackRole ? Params.RedSkill : 1.0);
			if (SkillOf(W, i).Hk.OppPace9 > 0.0 && !bHumansMate && W.Skaters[i].Team != PlayerTeam && !bBackRole && Sc < SkillOf(W, i).Hk.OppPace9) { Sc = SkillOf(W, i).Hk.OppPace9; }   // lane A206 (evolution 9)
			if (W.Carrier == i) { Sc *= SkillOf(W, i).CarrySpeed; }
			// R-0007 TeamIntent praise: +10% for the praised teammate (the sim caps |Move| at 1, so it lifts scaled-down bots only)
			if (W.PlayerIndex >= 0 && W.Skaters[i].Team == PlayerTeam && TeamIntent.Kind == ETeamIntent::Praise && TeamIntent.Active(W.Frame)
				&& (TeamIntent.Target < 0 || TeamIntent.Target == i))
			{
				Sc *= 1.1;
			}
			bool bShoot = false, bAimed = false, bDeke = false, bPass = false;
			FVec2 Dir;
			if (!(SkillOf(W, i).Hk.bMeetLine9 && MeetPass(W, i, Dir))) { Dir = Decide(W, i, bShoot, bAimed, bDeke, bPass); }   // lane A206 (READY 5): the receiver meets the pass
			// Lane A115: within the slow radius of its spot (Arrive's output shrinks there; a chase is always full length): a reversal here is the stop on the post
			const bool bNearSpot = !bPlaysPuck[i] && Dir.Length() < 0.6;
			if (Dir.Length() > 1.0)
			{
				Dir = Dir.Normalized();
			}
			// Lane A167 (evolution 5): the bot steers round a skater that lies on the ice (FJamHockeySense::AvoidDownedM; 0 = it skates at him)
			{
				const FJamHockeySense& Hd = SkillOf(W, i).Hk;
				if (Hd.AvoidDownedM > 0.0 && Dir.Length() > 0.05) { Dir = SteerRoundDowned(W, i, Dir, Hd.AvoidDownedM, Hd.AvoidDownedOut); }
			}
			if (SkillOf(W, i).Hk.DownedLeaveFrames > 0) { Dir = LeaveDowned(W, i, Dir); }   // lane A202 (evolution 8): a bot does not stand at a downed body
			if (SkillOf(W, i).Hk.bOwnZoneTurn) { Dir = OwnZoneTurn(W, i, Dir); }   // lane A202: a carrier does not skate back into its own zone with open ice ahead
			if (SkillOf(W, i).Hk.ClumpFrames > 0) { Dir = SplitClump(W, i, Dir); }   // lane A202: two mates do not stand in one spot
			if (SkillOf(W, i).Hk.Dodge9Share > 0.0) { Dir = DodgeHit(W, i, Dir); }   // lane A206 (wave 2): step off the human's hit
			// Lane A85 (found by Jam.Core.NetTrap once R-0042's flat tap re-rolled its match): a bot behind a net (between its back and the end boards, inside
			// the net's width + 1.2 m) whose way leads back to the middle goes round the side of the net, not into its back: FJamPlayerBot's rule (lane A3,
			// 16:12) for the bots. Before, a back whose guard spot lay through its own net pressed into the hull until the puck moved (47 frames, hockey.regular
			// pro seed 15, frame 4627: a missed flat tap sliding along the end boards). The side: the one it stands on, or its way's when it stands on the centre line.
			{
				const FVec2 Bp = W.Skaters[i].Pos;
				const double Len = Dir.Length();
				if (std::fabs(Bp.X) > W.GoalX + 1.5 + 0.2 && std::fabs(Bp.Y) < W.GoalHalfWidth + 1.2 && Len > 0.05 && Dir.X * Sign(Bp.X) < 0.0)   // 1.5 = UJamSim::NetDepth: behind the back wall only, never inside or beside the net
				{
					const double Sy = std::fabs(Bp.Y) > 0.5 ? Sign(Bp.Y) : (Dir.Y >= 0.0 ? 1.0 : -1.0);
					Dir = FVec2(0.0, Sy) * Len;
				}
			}
			In.Move = Dir * Sc;
			In.bShoot = bShoot;
			In.bDeke = bDeke;   // R-0029 point 4 (lane A39)
			In.bPass = bPass;   // lane A46: the pass to the human
			StickPlay(W, i, In);
			if (SkillOf(W, i).Hk.LongPassM > 0.0) { LongShotToPass(W, i, In); }   // lane A202 (evolution 8): no shot from far with a mate open nearer
			if (SkillOf(W, i).Hk.bPassCare9) { PassCare(W, i, In); }   // lane A206 (wave 3): a pass for where it puts the puck
			if (SkillOf(W, i).Hk.EarlyLongShot9Frames > 0 && FirstDrop9 >= 0 && W.Frame - FirstDrop9 < SkillOf(W, i).Hk.EarlyLongShot9Frames
				&& W.PuckPos.DistTo(W.OppGoal(W.Skaters[i].Team)) > 15.0) { In.bShoot = false; In.bShootHeld = false; }   // lane A206 (wave 4): no long shot in a rookie match's first 10 s
			if (SkillOf(W, i).Hk.DropNoHit9Frames > 0 && W.Frame - DropFrame9 < SkillOf(W, i).Hk.DropNoHit9Frames) { In.bCheck = false; In.bLift = false; In.bCrossHold = false; }   // lane A206 (wave 3): the puck after a drop, not the man
			// Lane A77 (R-0036): the saucer. A carrier that charges its shots (pro, all_star; rookie's window is 0) whose pass has no flat lane but a saucer lane
			// (W.CarrierBestPass < 0, W.CarrierBestSaucer >= 0) holds pass for W.SaucerHalfFrames and releases it: the sim lifts the puck over the blade in the lane.
			// While it holds, StickPlay keeps the puck inside shot reach (A66's cap). The puck gone, the hold is dropped (the sim fires nothing out of reach).
			if (W.Carrier == i && W.SaucerHalfFrames > 0 && SkillOf(W, i).ShotChargeFrames > 0)
			{
				const bool bWantSaucer = In.bPass && W.CarrierBestPass < 0 && W.CarrierBestSaucer >= 0;
				if (bWantSaucer || PassHold[i] > 0)
				{
					In.bPass = false;
					if (PassHold[i] < W.SaucerHalfFrames) { In.bPassHeld = true; ++PassHold[i]; }
					else { PassHold[i] = 0; }   // the release: the sim's StepPassCharge passes the saucer
				}
			}
			else { PassHold[i] = 0; }
			// Lane A31 (B-to-A-0024 point 1): the carrier charges an aimed shot on the net. While the lined-up decision holds, shoot is held
			// (bShootHeld, never the edge) for the skill's window; at the window's end, or the frame the line-up is lost, the hold is dropped and
			// the sim fires the charged shot on the release (StepCharge). Rookie's window is 0: a tap, as before. Taps by StickPlay (the dump
			// under a forecheck) and Attack's board chip and pass-by-shot never charge.
			{
				const int Window = ChargeWindowFor(W, i, SkillOf(W, i));   // R-0035 (lane A52): the hold picks the height under the bar (the profile's frames before)
				// Lane A47 (B-to-A-0030 fault 9): QA1 saw pro charges of 0.00 to 0.07 with the window at 10. Two causes. (1) The hold asked for
				// W.Carrier == i, and the carrier of record is the last toucher with the puck in reach: a bot arriving on a loose puck or a pass is aimed
				// and in reach before it has touched it, so its first shot went out as a tap through In.bShoot. (2) A hold in progress was released the
				// first frame the line-up or the carrier test flickered (the puck a few centimetres past reach on a fast carry), after one or two frames.
				// Now an aimed shot in reach charges whether or not the bot is the carrier of record, and a hold in progress rides out a frame without
				// the line-up while the bot can still shoot (puck in reach, cooldown over); it releases at the window's end or when the puck is gone.
				const bool bWantCharge = Window > 0 && In.bShoot && bAimed && !W.Skaters[i].bNoShoot;
				const bool bKeepCharge = Window > 0 && Charging[i] > 0 && W.Skaters[i].bCanShoot && !W.Skaters[i].bNoShoot;
				if (bWantCharge || bKeepCharge)
				{
					In.bShoot = false;
					if (Charging[i] < Window) { In.bShootHeld = true; ++Charging[i]; }
					else { Charging[i] = 0; }   // release: the sim fires the charged shot
				}
				else
				{
					Charging[i] = 0;   // a hold in progress is released here (the sim fires whatever charge it has)
				}
			}
			// R-0033 point 2 (lane A50): any skater standing in its own crease takes the stance, not only the back on its LastManGoalie rule. The
			// steering above is untouched: this is the visual intent only (the game mode sends SetGoalieStance on a change).
			if (!bGoalieNow[i])
			{
				int Side = 0;
				if (CreaseStance(W, i, Side)) { bGoalieNow[i] = true; GoalieSideNow[i] = Side; }
			}
			In.bGoalie = bGoalieNow[i];
			In.GoalieSide = bGoalieNow[i] ? GoalieSideNow[i] : 0;
			// R-0013 draw: the opposing centre takes the draw early at the level's rate (else the sim's bot timing decides)
			{
				const FJamBotSkill& K = SkillOf(W, i);
				if (W.bDrawOpen && W.Skaters[i].bCentre && K.DrawPressPct > 0 && PlayThinks >= K.DrawPressFrames
					&& static_cast<int>((Hash11(static_cast<uint64_t>(FaceoffStart) * 7 + 3, static_cast<uint64_t>(i)) + 1.0) * 50.0) < K.DrawPressPct)
				{
					In.bPoke = true;
					++DrawPresses;
				}
			}
			Hist[i][Head] = In;
			int Delay = bBackRole ? 0 : SkillOf(W, i).ReactionFrames;
			if (!bBackRole && SkillOf(W, i).Hk.React9Frames > Delay) { Delay = SkillOf(W, i).Hk.React9Frames; }   // lane A206 (evolution 9): a later read
			if (TeamIntent.Kind == ETeamIntent::Praise && TeamIntent.Active(W.Frame) && W.PlayerIndex >= 0 && W.Skaters[i].Team == PlayerTeam
				&& (TeamIntent.Target < 0 || TeamIntent.Target == i))
			{
				Delay = 0;   // ACE.md 2: a praised teammate reacts at once
			}
			Delay = Delay < 0 ? 0 : (Delay > kMaxReactionFrames ? kMaxReactionFrames : Delay);
			// the steering is the one decided Delay thinks ago; the shot stays live (a delayed shot almost never meets the sim's
			// reach and facing gate: in the sweep any delay >= 2 frames stopped the AI from scoring at all)
			Out[i] = Hist[i][(Head - Delay + Ring) % Ring];
			Out[i].bShoot = In.bShoot;
			Out[i].bShootHeld = In.bShootHeld;   // lane A31: the charge is live like the shot
			Out[i].bPass = In.bPass;
			Out[i].bPassHeld = In.bPassHeld;   // lane A77: the saucer hold is live like the charge
			Out[i].Stick = In.Stick;
			Out[i].bPoke = In.bPoke;
			Out[i].bCheck = In.bCheck;   // R-0031 point 2 (lane A45): the check press is live like the shot (a delayed press misses the 6-frame window)
			Out[i].bLift = In.bLift;
			Out[i].bCrossHold = In.bCrossHold;   // lane A184: the brace is live like the press it replaces
			Out[i].bGoalie = In.bGoalie;
			Out[i].GoalieSide = In.GoalieSide;
			Out[i].bDeke = In.bDeke;   // lane A39: live, like the shot: a delayed deke would miss the moment
			// lane A72 (ask A2): game.ai.sprint. A bot sprints while it chases the puck from more than 6 m without carrying it, in a share of the two-second
			// windows (a fixed coin per bot); the sim spends the same stamina bar as the human's. Absent = 0: no bot ever sets it.
			// Lane A95 (R-0045 law 4): the share is the side's level (FJamBotSkill::SprintShare) unless the cartridge wrote game.ai.sprint for both sides.
			Out[i].bSprint = false;
			const double SprintShare = Params.SprintShare >= 0.0 ? Params.SprintShare : SkillOf(W, i).SprintShare;
			if (SprintShare > 0.0 && W.Carrier != i && !W.bDrawOpen)
			{
				const FVec2 ToPuck = W.PuckPos - W.Skaters[i].Pos;
				const bool bChase = ToPuck.Length() > 6.0 && Out[i].Move.Dot(ToPuck) > 0.0;
				Out[i].bSprint = bChase && (SprintShare >= 1.0
					|| (Hash11(static_cast<uint64_t>(i) + 401, static_cast<uint64_t>(W.Frame / 120)) + 1.0) * 0.5 < SprintShare);
			}
			const FJamHockeySense& Hs2 = SkillOf(W, i).Hk;
			// Lane A115 (R-0048 point 5, VISION law 4): the bot carrier sprints on an open lane: nobody on the lane 15 m ahead of its way, nobody within 6 m, no
			// shot or pass in hand. The sim spends its stamina bar and carries the puck at full reach (easier to take): it sprints only there. A cartridge that
			// writes game.ai.sprint 0 (no bot ever sprints: Jam.Core.ModeKeys.Sprint) stops this sprint too.
			if (Hs2.bCarrySprint && SprintShare > 0.0 && W.SprintCarryBonus > 0.0 && W.CarrierOrHolder() == i && !W.bDrawOpen && Out[i].Move.Length() > 0.5
				&& !Out[i].bShoot && !Out[i].bShootHeld && !Out[i].bPass && !Out[i].bPassHeld && BrakeHold[i] <= 0)
			{
				const FJamSpaceRead Rs = ReadSpace(W, i, Out[i].Move);
				double Near = 1e9;
				for (int o = 0; o < W.NumSkaters; ++o)
				{
					if (W.Skaters[o].Team == W.Skaters[i].Team || W.Skaters[o].bDown) { continue; }
					const double Dn = W.Skaters[o].Pos.DistTo(W.Skaters[i].Pos);
					if (Dn < Near) { Near = Dn; }
				}
				if (Rs.OnLane == 0 && Near > 6.0) { Out[i].bSprint = true; }
			}
			// Lane A115 (R-0048 point 5, REVIEW-1 item 9): the brain brakes on purpose. The sim reads a move more than 120 degrees off the velocity as the hard
			// stop (A93's reverse brake). The brain's steering made that by accident about once a second per bot (2,225 a match at pro). Now a reversal is the
			// stop only where the brain decided one: on its spot (the post, the blue line), turning back for a loose puck within 6 m, the carrier stopping in
			// front of a defender, the presser closing under control. A decided stop is held against the velocity until the skater is slow (one stop), and
			// the next waits BrakeCoolFrames. Every other reversal is carved: the input 115 degrees off the velocity on the input's side (the playtester's rule).
			if (Hs2.bBrakeMeant && W.ReverseBrakeDecel > 0.0)
			{
				constexpr int BrakeHoldFrames = 36, BrakeCoolFrames = 45;
				constexpr double BrakeDoneSpeed = 1.0, LoosePuckNearM = 6.0;
				if (BrakeCool[i] > 0) { --BrakeCool[i]; }
				const FVec2 V = W.Skaters[i].Vel;
				const double Sp = V.Length();
				FVec2& Mv = Out[i].Move;
				const double Lm = Mv.Length();
				const bool bReversal = Sp > BrakeDoneSpeed && Lm > 0.05 && Mv.Dot(V) < -0.5 * Sp * Lm;
				const bool bLooseBehind = bPlaysPuck[i] && W.CarrierOrHolder() < 0 && W.PuckPos.DistTo(W.Skaters[i].Pos) < LoosePuckNearM;
				const bool bDecided = bWantStop[i] || (bReversal && (bNearSpot || bLooseBehind));
				if (BrakeHold[i] > 0)
				{
					if (Sp > BrakeDoneSpeed && (bDecided || bReversal)) { Mv = V * (-1.0 / Sp); --BrakeHold[i]; }
					else { BrakeHold[i] = 0; }
				}
				else if (bDecided && Sp > BrakeDoneSpeed && BrakeCool[i] <= 0)
				{
					BrakeHold[i] = BrakeHoldFrames;
					BrakeCool[i] = BrakeCoolFrames + BrakeHoldFrames;
					++MeantBrakes;
					Mv = V * (-1.0 / Sp);
				}
				else if (bReversal)
				{
					const FVec2 Vd = V * (1.0 / Sp);
					double Side = Vd.Cross(Mv) >= 0.0 ? 1.0 : -1.0;
					// straight back (no side to speak of): turn towards the middle of the rink, never into the boards
					if (std::fabs(Vd.Cross(Mv)) < 0.15 * Lm) { Side = Vd.Cross(-W.Skaters[i].Pos) >= 0.0 ? 1.0 : -1.0; }
					Mv = Rotate(Vd, DegToRad(115.0) * Side) * Lm;
					++Carves;
				}
				if (BrakeHold[i] > 0) { Out[i].bSprint = false; }
			}
		}
	}

	// Lane A202 (track Q2, evolution 8; BRAIN-8.md): the four rules. Each reads only the world and its own per-bot run; off (its FJamHockeySense value
	// neutral) it is never called.
	// LeaveDowned (DownedLeaveFrames): inside 1.2 m of a downed skater for that many frames (the bot not carrying), the move goes out from his body, half
	// the bot's own move across that line kept, until 2 m from him; then the run starts again.
	FVec2 FJamBrain::LeaveDowned(const FJamAIWorld& W, int Id, const FVec2& Dir)
	{
		const FJamAISkater& S = W.Skaters[Id];
		if (DownNearFrame[Id] != W.Frame - 1) { DownNear[Id] = 0; bDownLeaving[Id] = false; }
		DownNearFrame[Id] = W.Frame;
		int Near = -1;
		double Nd = 1e9;
		for (int o = 0; o < W.NumSkaters; ++o)
		{
			if (o == Id || !W.Skaters[o].bDown) { continue; }
			const double Dd = W.Skaters[o].Pos.DistTo(S.Pos);
			if (Dd < Nd) { Nd = Dd; Near = o; }
		}
		if (Near < 0 || W.CarrierOrHolder() == Id || Nd > (bDownLeaving[Id] ? 2.0 : 1.2)) { DownNear[Id] = 0; bDownLeaving[Id] = false; return Dir; }
		if (!bDownLeaving[Id] && ++DownNear[Id] < SkillOf(W, Id).Hk.DownedLeaveFrames) { return Dir; }
		bDownLeaving[Id] = true;
		FVec2 Away = S.Pos - W.Skaters[Near].Pos;
		Away = Away.Length() > 1e-3 ? Away.Normalized() : (Dir.Length() > 1e-3 ? Dir.Normalized() * -1.0 : FVec2(1.0, 0.0));
		const FVec2 Across = Dir - Away * Dir.Dot(Away);
		return (Away + Across * 0.5).Normalized();
	}
	// OwnZoneTurn (bOwnZoneTurn): the carrier in its own zone (behind its blue line, a quarter of the half length from the centre) whose move leads back
	// towards its own end while no standing opponent is within 8 m ahead of it up the ice turns its move up the ice (the side it leans to kept).
	FVec2 FJamBrain::OwnZoneTurn(const FJamAIWorld& W, int Id, const FVec2& Dir) const
	{
		const FJamAISkater& S = W.Skaters[Id];
		const double As = W.OppGoal(S.Team).X >= 0.0 ? 1.0 : -1.0;
		const double Len = Dir.Length();
		if (W.CarrierOrHolder() != Id || Len < 0.05 || S.Pos.X * As > -W.HalfLength * 0.25 || Dir.X * As > -0.2 * Len) { return Dir; }
		for (int o = 0; o < W.NumSkaters; ++o)
		{
			const FJamAISkater& O = W.Skaters[o];
			if (O.Team == S.Team || O.bDown) { continue; }
			const FVec2 Rel = O.Pos - S.Pos;
			const double Rl = Rel.Length();
			if (Rl < 8.0 && Rel.X * As > 0.7 * Rl) { return Dir; }
		}
		const double Side = std::fabs(Dir.Y) > 0.05 * Len ? Sign(Dir.Y) : (S.Pos.Y > 0.0 ? -1.0 : 1.0);
		return FVec2(As, 0.5 * Side).Normalized() * Len;
	}
	// SplitClump (ClumpFrames): a bot without the puck inside 1.5 m of a standing team-mate for that many frames gives way, unless it is the one that keeps
	// its line (the carrier, the human, else the lower index): its move takes a push straight away from him until 3 m apart.
	FVec2 FJamBrain::SplitClump(const FJamAIWorld& W, int Id, const FVec2& Dir)
	{
		const FJamAISkater& S = W.Skaters[Id];
		if (ClumpFrame[Id] != W.Frame - 1) { ClumpRun[Id] = 0; bClumpSplit[Id] = false; }
		ClumpFrame[Id] = W.Frame;
		const int Ch = W.CarrierOrHolder();
		int Mate = -1;
		double Md = 1e9;
		for (int o = 0; o < W.NumSkaters; ++o)
		{
			const FJamAISkater& O = W.Skaters[o];
			if (o == Id || O.Team != S.Team || O.bDown) { continue; }
			const double Dd = O.Pos.DistTo(S.Pos);
			if (Dd < Md) { Md = Dd; Mate = o; }
		}
		const bool bIKeep = Ch == Id || (Mate >= 0 && !W.IsHumanSeat(Mate) && Mate != Ch && Id < Mate);
		// lane A206 wave 3 (bDefendTeam9): defending (an opposing carrier), a bot gives way inside 3 m after 20 frames unless both play the puck
		const bool bDef9 = SkillOf(W, Id).Hk.bDefendTeam9 && Ch >= 0 && Ch < W.NumSkaters && W.Skaters[Ch].Team != S.Team
			&& !(Mate >= 0 && W.PuckPos.DistTo(S.Pos) < 3.0 && W.PuckPos.DistTo(W.Skaters[Mate].Pos) < 3.0);
		const double NearM = bDef9 ? 3.0 : 1.5, FarM = bDef9 ? 4.5 : 3.0;
		const int RunF = bDef9 ? 20 : SkillOf(W, Id).Hk.ClumpFrames;
		if (Mate < 0 || bIKeep || Md > (bClumpSplit[Id] ? FarM : NearM)) { ClumpRun[Id] = 0; bClumpSplit[Id] = false; return Dir; }
		if (!bClumpSplit[Id] && ++ClumpRun[Id] < RunF) { return Dir; }
		bClumpSplit[Id] = true;
		FVec2 Away = S.Pos - W.Skaters[Mate].Pos;
		Away = Away.Length() > 1e-3 ? Away.Normalized() : FVec2(0.0, S.Pos.Y > 0.0 ? -1.0 : 1.0);
		const FVec2 Out = Dir + Away;
		const double L = Dir.Length() > 0.6 ? Dir.Length() : 0.6;
		return Out.Length() > 1e-3 ? Out.Normalized() * L : Away * L;
	}
	// LongShotToPass (LongPassM): the shot decided this frame by the carrier (or holder) further than LongPassM from the net, while a team-mate stands
	// open 5 m nearer the net (no standing opponent within 3 m of him), is not taken: the sim's pass goes instead when its receiver is such a mate,
	// else the carrier carries on (the carry-or-pass reads move the puck when a lane opens).
	// Lane A206 (track Q2, evolution 9; BRAIN-9.md): DriveNet (DriveNet9M). The carrier (or holder) inside DriveNet9M of the net whose lane to it is open (no
	// standing opponent within 1.5 m of the line puck -> net in the 6 m ahead) goes at the net: Attack skips carry-or-pass, so no opponent's arrival makes it
	// pass; it shoots when its reach and facing allow (the shot is decided before), and a defender stepping into the lane gives carry-or-pass back.
	bool FJamBrain::DriveNet(const FJamAIWorld& W, int Id, const FVec2& Aim, double Dgoal) const
	{
		const FJamAISkater& S = W.Skaters[Id];
		if (W.CarrierOrHolder() != Id || Dgoal > SkillOf(W, Id).Hk.DriveNet9M || Dgoal < 2.0) { return false; }
		for (int o = 0; o < W.NumSkaters; ++o)
		{
			const FJamAISkater& O = W.Skaters[o];
			if (O.Team == S.Team || O.bDown) { continue; }
			const FVec2 Rel = O.Pos - W.PuckPos;
			const double Along = Rel.Dot(Aim);
			if (Along > 0.0 && Along < 6.0 && std::fabs(Rel.Cross(Aim)) < 1.5) { return false; }
		}
		return true;
	}
	// Lane A206 (track Q2, evolution 9, wave 2; BRAIN-9.md): DodgeHit (Dodge9Share). A bot on its feet without the puck, of the side against the human, reads
	// his hit coming: he is within 4.5 m and closing on it at 3 m/s or more, or his check winds up with it the nearest man in front of him within 3 m, or his
	// cross-check winds up with it as the target. In Dodge9Share of the two-second windows (a fixed coin per bot) its move is the step off the line of the
	// hit: across his line of approach at full stride, on the side it already leans to (towards the middle when it is on the line).
	FVec2 FJamBrain::DodgeHit(const FJamAIWorld& W, int Id, const FVec2& Dir) const
	{
		const int Hi = W.PlayerIndex;
		const FJamAISkater& S = W.Skaters[Id];
		// not against the human carrier: a defender does not step out of his way (that emptied all_star's large rink: 59 -> 86.5 for the good player)
		if (Hi < 0 || Hi >= W.NumSkaters || W.Skaters[Hi].Team == S.Team || W.Skaters[Hi].bDown || S.bDown || W.CarrierOrHolder() == Id || W.CarrierOrHolder() == Hi) { return Dir; }
		const FJamAISkater& H = W.Skaters[Hi];
		const FVec2 Rel = S.Pos - H.Pos;
		const double D = Rel.Length();
		if (D < 1e-3 || D > 4.5) { return Dir; }
		const FVec2 U = Rel * (1.0 / D);
		const double Closing = (H.Vel - S.Vel).Dot(U);
		bool bCheckAtMe = false;
		if (H.CheckWindupLeft > 0 && D < 3.0 && H.Facing.Normalized().Dot(U) > 0.5)
		{
			bCheckAtMe = true;
			for (int o = 0; o < W.NumSkaters; ++o)
			{
				if (o == Id || W.Skaters[o].Team == H.Team || W.Skaters[o].bDown) { continue; }
				const FVec2 Ro = W.Skaters[o].Pos - H.Pos;
				if (Ro.Length() < D && H.Facing.Normalized().Dot(Ro.Normalized()) > 0.5) { bCheckAtMe = false; break; }
			}
		}
		const bool bCrossAtMe = H.CrossWindupLeft > 0 && H.CrossTarget == Id;
		if (!(Closing >= 3.0 || bCheckAtMe || bCrossAtMe)) { return Dir; }
		const double Coin = (Hash11(static_cast<uint64_t>(Id) + 719, static_cast<uint64_t>(W.Frame / 120)) + 1.0) * 0.5;
		if (Coin >= SkillOf(W, Id).Hk.Dodge9Share) { return Dir; }
		const FVec2 Across = U.Perp();
		double Side = S.Vel.Dot(Across);
		if (std::fabs(Side) < 0.5) { Side = Across.Dot(FVec2(0.0, 0.0) - S.Pos); }
		return Across * (Side >= 0.0 ? 1.0 : -1.0) + U * 0.3;
	}
	// Lane A206 (track Q2, evolution 9, wave 3; BRAIN-9.md): PassCare (bPassCare9). The pass of this frame (an edge or a saucer's hold) by the carrier is not
	// made when it goes to a mate nearer than 5 m, or in the carrier's first 20 frames with the puck, or straight back to the mate it came from inside 60
	// frames while he is no nearer the net than the carrier, or along a line that runs within 3 m of its own net; unless an opposing skater on its feet is
	// within 2 m (the pass out of pressure stays). The receiver is the sim's (CarrierBestPass / HolderBestPass). The carrier carries on.
	void FJamBrain::PassCare(const FJamAIWorld& W, int Id, FJamAIInput& In) const
	{
		if (!(In.bPass || In.bPassHeld) || W.CarrierOrHolder() != Id) { return; }
		const FJamAISkater& S = W.Skaters[Id];
		for (int o = 0; o < W.NumSkaters; ++o) { if (W.Skaters[o].Team != S.Team && !W.Skaters[o].bDown && W.Skaters[o].Pos.DistTo(S.Pos) < 2.0) { return; } }
		const int To = W.Carrier == Id ? W.CarrierBestPass : W.HolderBestPass;
		bool bVeto = CarryFrames[Id] < 20;
		if (To >= 0 && To < W.NumSkaters)
		{
			const FVec2 G = W.OppGoal(S.Team), Own = W.OwnGoal(S.Team), Rp = W.Skaters[To].Pos;
			if (Rp.DistTo(S.Pos) < 5.0) { bVeto = true; }
			if (To == ReceivedFrom9[Id] && W.Frame - ReceivedFrame9[Id] < 60 && Rp.DistTo(G) >= S.Pos.DistTo(G)) { bVeto = true; }
			const FVec2 L = Rp - S.Pos;
			const double Ll = L.Length();
			if (Ll > 1e-3)
			{
				const double Along = Clamp((Own - S.Pos).Dot(L) / Ll, 0.0, Ll);
				if ((S.Pos + L * (Along / Ll)).DistTo(Own) < 3.0) { bVeto = true; }   // item 12: never through the own crease
			}
		}
		if (bVeto) { In.bPass = false; In.bPassHeld = false; }
	}
	// Lane A206 (wave 3): NoCarrierAlone (bDefendTeam9). An opposing carrier inside 35 m of this bot's net has had nobody of its team within 3 m for more
	// than 30 frames: the bot of its team nearest him (the human aside) goes at him (Attack: the chase, the stick, the body as its level plays them).
	bool FJamBrain::NoCarrierAlone(const FJamAIWorld& W, int Id) const
	{
		const FJamAISkater& S = W.Skaters[Id];
		if (S.Team < 0 || S.Team > 1 || AloneRun9[S.Team] <= 30 || W.Carrier < 0 || W.Carrier >= W.NumSkaters) { return false; }
		const FVec2 Cp = W.Skaters[W.Carrier].Pos;
		int Best = -1; double Bd = 1e18;
		for (int o = 0; o < W.NumSkaters; ++o)
		{
			if (W.Skaters[o].Team != S.Team || W.IsHumanSeat(o) || W.Skaters[o].bDown) { continue; }
			// wave 4: the crease man (the first back of a five) keeps the crease: he is never the one sent
			if (W.Skaters[o].Role == ERole::Back && TeamSize(W, S.Team) >= 5 && FiveLocal::RoleOrdinal(W, o) == 0) { continue; }
			const double D = W.Skaters[o].Pos.DistTo(Cp);
			if (D < Bd) { Bd = D; Best = o; }
		}
		return Best == Id;
	}
	// Lane A206 (wave 4, EYE 3): CreaseKeeper (bCreaseKeeper9). The first back of a five, while the other side carries the puck within 45 m of his net
	// (or a puck flies at it faster than 6 m/s), stands 1.5 m out on the line net -> puck, and on a shot steps onto the shot's line.
	bool FJamBrain::CreaseKeeper(const FJamAIWorld& W, int Id, FVec2& Out) const
	{
		const FJamAISkater& S = W.Skaters[Id];
		if (S.Role != ERole::Back || TeamSize(W, S.Team) < 5 || FiveLocal::RoleOrdinal(W, Id) != 0) { return false; }
		const FVec2 OwnGoal = W.OwnGoal(S.Team), Pp = W.PuckPos;
		const int Ch = W.CarrierOrHolder();
		const double Pv = W.PuckVel.Length();
		const bool bShot = Pv > 6.0 && W.PuckVel.Dot(OwnGoal - Pp) > 0.0 && Ch < 0;
		const bool bTheirs = Ch >= 0 && Ch < W.NumSkaters && W.Skaters[Ch].Team != S.Team;
		if (bTheirs && W.Skaters[Ch].Pos.DistTo(OwnGoal) < 12.0) { return false; }   // a carrier inside 12 m: the old last man (LastManGoalie / the guard, the deke's read: Jam.Core.Payoffs.Deke)
		// wave 4 (EYE LIST 3): from the drop until the puck leaves the scrum (8 m from the dot, at most 3 s) he stays back whoever has it
		const bool bScrum = SkillOf(W, Id).Hk.bScrumStay9 && W.Frame - DropFrame9 < 180 && Pp.DistTo(DropPos9) < 8.0;
		// wave 4 (bNetNeverEmpty9): the puck outside the end his side attacks (its third of the rink) and not his own carry
		const double Up = Sign(-OwnGoal.X);
		const bool bNotAttacking = SkillOf(W, Id).Hk.bNetNeverEmpty9 && Pp.X * Up < W.HalfLength / 3.0 && Ch != Id;
		if (!(bTheirs || bShot || bScrum || bNotAttacking)) { return false; }
		if (!bNotAttacking && Pp.DistTo(OwnGoal) > 45.0) { return false; }
		// squared to the carrier when there is one (as LastManGoalie: a deke moves the puck, not the man), else to the puck
		const FVec2 Ref = bTheirs ? W.Skaters[Ch].Pos : Pp;
		FVec2 T = OwnGoal + (Ref - OwnGoal).Normalized() * 1.5;
		// never in or behind the net (Jam.Core.NetTrap: with the puck behind the goal line the old clamp put him on the goal centre, pressing the hull):
		// at least 1.5 m out in front of the goal line, on the puck's post
		if ((T.X - OwnGoal.X) * Up < 1.5) { T.X = OwnGoal.X + Up * 1.5; T.Y = Clamp(T.Y, -W.GoalHalfWidth, W.GoalHalfWidth); }
		if (bShot)
		{
			const FVec2 Dv = W.PuckVel * (1.0 / Pv);
			const double Tg = std::fabs(Dv.X) > 1e-6 ? (OwnGoal.X - Pp.X) / Dv.X : -1.0;
			if (Tg > 0.0 && std::fabs(Pp.Y + Dv.Y * Tg) < W.GoalHalfWidth + 1.0)
			{
				double Along = (S.Pos - Pp).Dot(Dv);
				Along = Along < 0.0 ? 0.0 : (Along > Tg ? Tg : Along);
				T = Pp + Dv * Along;
			}
		}
		Out = Arrive(S.Pos, T - S.Vel * 0.25, 1.0);
		return true;
	}
	// Lane A206 (track Q2, evolution 9, READY 5; BRAIN-9.md): MeetPass (bMeetLine9). A pass in flight aimed at this bot (Puck.PassTo == Id, by another skater,
	// nobody carrying): for kEvo9MeetHoldFrames from the frame he first sees it he keeps the velocity he had then (the passer led him on it); after that he
	// skates to the point where the puck's line passes nearest him (slowing inside 1 m) and plays nothing else, until the pass is caught or taken (the
	// sim clears PassTo) or 90 frames have gone.
	bool FJamBrain::MeetPass(const FJamAIWorld& W, int Id, FVec2& Out)
	{
		const FJamAISkater& S = W.Skaters[Id];
		if (W.PuckPassFrames <= 0 || W.PuckPassTo != Id || W.PuckPassBy < 0 || W.PuckPassBy == Id || W.CarrierOrHolder() >= 0 || S.bDown) { MeetBy9[Id] = -1; return false; }
		if (MeetBy9[Id] != W.PuckPassBy || W.Frame - MeetStart9[Id] > 120 || W.Frame < MeetStart9[Id]) { MeetBy9[Id] = W.PuckPassBy; MeetStart9[Id] = W.Frame; MeetVel9[Id] = S.Vel; }
		const int64_t Age = W.Frame - MeetStart9[Id];
		if (Age > 90) { return false; }
		bPlaysPuck[Id] = true;
		const double Top = FreeSpeed(SkillOf(W, Id).Hk) * Params.SpeedScale;
		if (Age < kEvo9MeetHoldFrames)
		{
			const double V = MeetVel9[Id].Length();
			Out = V > 0.5 ? MeetVel9[Id] * (1.0 / (Top > 1.0 ? Top : 1.0)) : FVec2();
			Out = Out.LimitLength(1.0);
			return true;
		}
		const FVec2 Pv = W.PuckVel;
		const double P2 = Pv.Dot(Pv);
		FVec2 Q = W.PuckPos;
		if (P2 > 1e-6)
		{
			double T = (S.Pos - W.PuckPos).Dot(Pv) / P2;
			T = T < 0.0 ? 0.0 : (T > 3.0 ? 3.0 : T);
			Q = W.PuckPos + Pv * T;
		}
		Out = Arrive(S.Pos, Q, 1.0);
		return true;
	}
	void FJamBrain::LongShotToPass(const FJamAIWorld& W, int Id, FJamAIInput& In) const
	{
		if (!In.bShoot || W.CarrierOrHolder() != Id) { return; }
		const int Team = W.Skaters[Id].Team;
		const FVec2 G = W.OppGoal(Team);
		const double Dg = W.PuckPos.DistTo(G);
		if (Dg <= SkillOf(W, Id).Hk.LongPassM) { return; }
		auto OpenNearer = [&W, Team, &G, Dg](int m)
		{
			if (m < 0 || m >= W.NumSkaters || W.Skaters[m].Team != Team || W.Skaters[m].bDown || W.Skaters[m].Pos.DistTo(G) > Dg - 5.0) { return false; }
			for (int o = 0; o < W.NumSkaters; ++o)
			{
				if (W.Skaters[o].Team != Team && !W.Skaters[o].bDown && W.Skaters[o].Pos.DistTo(W.Skaters[m].Pos) < 3.0) { return false; }
			}
			return true;
		};
		bool bAny = false;
		for (int m = 0; m < W.NumSkaters && !bAny; ++m) { bAny = m != Id && OpenNearer(m); }
		if (!bAny) { return; }
		In.bShoot = false;
		const int To = W.Carrier == Id ? W.CarrierBestPass : W.HolderBestPass;
		if (OpenNearer(To)) { In.bPass = true; }
	}

	FVec2 FJamBrain::Decide(const FJamAIWorld& W, int Id, bool& bShoot, bool& bAimed, bool& bDeke, bool& bPass)
	{
		const FJamAISkater& S = W.Skaters[Id];
		const FVec2 Pp = W.PuckPos;
		const FVec2 Me = S.Pos;
		const FVec2 OppGoal = W.OppGoal(S.Team);
		const FVec2 OwnGoal = W.OwnGoal(S.Team);
		ERole Role = S.Role == ERole::Player ? ERole::Chaser : S.Role;
		const FVec2 Dirg = (OppGoal - Pp).Normalized();
		double D = Me.DistTo(Pp);
		FVec2 Out;
		bGoalieNow[Id] = false;
		GoalieSideNow[Id] = 0;

		// R-0017: a pickup within 8 m, nearer than the puck, while not carrying (all_star only)
		if (SkillOf(W, Id).bSeekPickups && W.Carrier != Id)
		{
			int Best = -1;
			double Bd = 8.0;
			for (int p = 0; p < W.NumPickups; ++p)
			{
				const double Pd = W.PickupPos[p].DistTo(Me);
				if (Pd < Bd && Pd < D) { Bd = Pd; Best = p; }
			}
			if (Best >= 0)
			{
				Used[Id] = S.Role;
				return Arrive(Me, W.PickupPos[Best], 0.5) + Separate(Me, W, Id, Params.SeparateRadius) * 1.2;
			}
		}

		bool bHasMateChaser = false;
		FVec2 MateChaser;
		for (int o = 0; o < W.NumSkaters; ++o)
		{
			if (o != Id && W.Skaters[o].Team == S.Team && W.Skaters[o].Role == ERole::Chaser)
			{
				MateChaser = W.Skaters[o].Pos;
				bHasMateChaser = true;
			}
		}

		bool bYield = false;
		if (W.PlayerIndex >= 0)
		{
			const FJamAISkater& P = W.Skaters[W.PlayerIndex];
			const double Db = P.Pos.DistTo(Pp);
			if (S.Team == P.Team)
			{
				// teammates yield when the human is nearer the puck (by the margin) and close to it
				bYield = Db <= D + Params.YieldMarginM && Db < Params.YieldRadiusM;
				// Lane A115 (REVIEW-CODE.md, severity 2): a human who is down or in the box takes no puck: his mates do not stand off it.
				const FJamHockeySense& Hy = SkillOf(W, Id).Hk;
				if (Hy.bChaseAhead && P.bDown) { bYield = false; }
				// Lane A115: the yield is for a loose puck and the human's own carry. An opposing carrier is nobody's to leave alone: while the human forechecks
				// it, his mates go at it too (on the big rinks, three a side, the human forechecked alone for a third of the match while both mates stood off).
				const int Ch = W.CarrierOrHolder();
				if (Hy.bSupportHuman && Ch >= 0 && Ch < W.NumSkaters && W.Skaters[Ch].Team != S.Team) { bYield = false; }
				// Lane A134 (evolution 3): a loose puck is the human's by arrival, read with his real velocity and facing: a mate leaves it only while he
				// reaches it no later than YieldArriveS after the mate would (before: by distance, so a mate stood off a puck the human had to turn round
				// for while an opponent took it).
				if (Hy.YieldArriveS >= 0.0 && Ch < 0 && !P.bDown && Db < Params.YieldRadiusM)
				{
					bYield = ArriveSec(W, W.PlayerIndex, FreeSpeed(Hy)) <= ArriveSec(W, Id, FreeSpeed(Hy) * ((Hy.bMateTrueScale && Params.MateSpeedScale > 0.0) ? Params.MateSpeedScale : Params.SpeedScale)) + Hy.YieldArriveS;   // lane A193: both free skaters
				}
			}
			else if (Role != ERole::Back)
			{
				// opponents hold back while the human works the puck
				bYield = (Db < Params.HoldRadiusM && D > 3.0) || (Params.bFaceoffCourtesy && W.PuckLastTouch < 0);
			}
		}
		if (bStalled && Role == ERole::Support && StallChaser[S.Team] == Id)
		{
			Role = ERole::Chaser;
		}
		// Lane A115 (REVIEW-CODE.md, severity 3): the passer is not the chaser of its own pass. A puck that left this bot faster than 6 m/s and that a
		// teammate reaches first (LoosePuckOwner) is that teammate's: the passer takes the support's place. Teams with shape jobs get the same from AssignJobs.
		bool bOwnPass = false;
		if (SkillOf(W, Id).Hk.bChaseAhead && Job[Id] == EJob::None && !bStalled && W.CarrierOrHolder() < 0 && W.PuckLastTouch == Id && Role != ERole::Back
			&& W.PuckVel.Length() > 6.0 && W.PuckVel.Dot(Pp - Me) > 0.0)
		{
			const int Own = LoosePuckOwner(W, S.Team, FreeSpeed(SkillOf(W, Id).Hk) * Params.SpeedScale);   // lane A193: a loose puck: everyone is free
			bOwnPass = Own >= 0 && Own != Id;
		}
		if (bOwnPass) { Role = ERole::Support; D = 99.0; }
		if (bYield && D > 2.0 && !bStalled)
		{
			// Lane A94: a back of a team that plays the shapes keeps its post (it never takes the human's puck: its D is 99 like the others')
			const FJamHockeySense& Ys = SkillOf(W, Id).Hk;
			if (!(Role == ERole::Back && (Ys.bAttackShape || Ys.bDefenceShape))) { Role = ERole::Support; }
			D = 99.0;
		}
		// R-0007 TeamIntent defend / space for the human's teammates (pass is read in Attack)
		const bool bMate = W.PlayerIndex >= 0 && S.Team == W.Skaters[W.PlayerIndex].Team;
		if (bMate && TeamIntent.Active(W.Frame) && D > 2.5)
		{
			if (TeamIntent.Kind == ETeamIntent::Defend && S.Role != ERole::Back && Pp.X * OppGoal.X > 0.0)
			{
				// ACE.md 2: with the puck in our attacking half, fall back to 8 m in front of the own net on the puck's side
				FVec2 T(OwnGoal.X + Sign(-OwnGoal.X) * 8.0, Clamp(Pp.Y, -8.0, 8.0));
				Used[Id] = ERole::Back;
				return Arrive(Me, T - S.Vel * 0.25, Params.ArriveSlowRadius) + Separate(Me, W, Id, Params.SeparateRadius) * 1.2;
			}
			else if (TeamIntent.Kind == ETeamIntent::Space)
			{
				// free ice: the point ahead of the puck on the far side from the nearest opponent, kept inside the boards
				FVec2 Near = Pp;
				double Best = 1e18;
				for (int o = 0; o < W.NumSkaters; ++o)
				{
					if (W.Skaters[o].Team == S.Team) { continue; }
					const double Dd = W.Skaters[o].Pos.DistTo(Me);
					if (Dd < Best) { Best = Dd; Near = W.Skaters[o].Pos; }
				}
				FVec2 T = Pp + FVec2(Sign(OppGoal.X) * 12.0, (Near.Y > Me.Y ? -1.0 : 1.0) * 10.0);
				T.X = Clamp(T.X, -W.GoalX + 2.0, W.GoalX - 2.0);
				T.Y = Clamp(T.Y, -W.HalfWidth + 4.0, W.HalfWidth - 4.0);
				Used[Id] = ERole::Support;
				return Arrive(Me, T, Params.ArriveSlowRadius) + Separate(Me, W, Id, Params.SeparateRadius) * 1.2;
			}
		}
		Used[Id] = Role;

		// R-0041 point 1 (lane A79): a hunting support goes at an opposing carrier within its skill's HuntRadiusM (a yielding bot's D is 99, so it stays out)
		const FJamBotSkill& Hk = SkillOf(W, Id);
		const bool bHunt = Hk.HuntRadiusM > 0.0 && D < 90.0 && W.Carrier >= 0 && W.Skaters[W.Carrier].Team != S.Team && !W.Skaters[W.Carrier].bDown
			&& W.Skaters[W.Carrier].Pos.DistTo(Me) < Hk.HuntRadiusM;
		// Lane A94 (R-0045 law 2): a bot with a shape job plays it (AssignJobs); the stall, the hunt and a yield to the human's puck keep the old roles
		// Lane A134: bPressInHunt keeps the presser on its job inside the hunt radius (off as shipped: the hunt takes it off, as before)
		// Lane A167: ... until the carrier is inside PressCommitM, where the presser commits as a hunting bot does (0 = it never does)
		// Lane A206 wave 4 (bCreaseKeeper9): the first back keeps the crease while the other side has the puck near our net
		if (Hk.Hk.bCreaseKeeper9 && D > 2.5 && CreaseKeeper(W, Id, Out))
		{
			// the goalie stance and its side as LastManGoalie sets them (the deke reads the side: Jam.Core.Payoffs.Deke)
			Used[Id] = ERole::Back; bGoalieNow[Id] = true;
			const int Cc = W.CarrierOrHolder();
			const double Cy = (Cc >= 0 && Cc < W.NumSkaters) ? W.Skaters[Cc].Pos.Y : Pp.Y;
			GoalieSideNow[Id] = std::fabs(Cy) < 1.0 ? 0 : static_cast<int>(Sign(Cy)) * (S.Team == 0 ? 1 : -1);
			return Out;
		}
		// Lane A206 wave 3 (bDefendTeam9): an opposing carrier near our net alone for over 30 frames: the nearest bot goes at him
		if (Hk.Hk.bDefendTeam9 && !bYield && W.CarrierOrHolder() != Id && NoCarrierAlone(W, Id))
		{
			Used[Id] = ERole::Chaser;
			Out = Attack(W, Id, Me, Pp, Dirg, D, bShoot, bAimed, bDeke, bPass);
			return Out + Separate(Me, W, Id, Params.SeparateRadius) * 1.2;
		}
		const bool bPressKeeps = Hk.Hk.bPressInHunt && Job[Id] == EJob::Press && !(Hk.Hk.bSecondManHunts && bSecondMan[Id])   // lane A181: a second man hunts
			&& !(Hk.Hk.PressCommitM > 0.0 && W.Carrier >= 0 && W.Carrier < W.NumSkaters && W.Skaters[W.Carrier].Pos.DistTo(Me) < Hk.Hk.PressCommitM);
		if (Job[Id] != EJob::None && !bStalled && (!bHunt || bPressKeeps) && W.CarrierOrHolder() != Id && !(bYield && Job[Id] == EJob::Puck))
		{
			bool bToPuck = false;
			if (JobSteer(W, Id, Out, bToPuck))
			{
				Used[Id] = Job[Id] == EJob::Point ? ERole::Back : ((Job[Id] == EJob::Puck || Job[Id] == EJob::Press) ? ERole::Chaser : ERole::Support);
				if (bToPuck) { Out = Attack(W, Id, Me, Pp, Dirg, D, bShoot, bAimed, bDeke, bPass); }
				return Out + Separate(Me, W, Id, Params.SeparateRadius) * 1.2;
			}
		}
		// Lane A167 (evolution 5): the chaser of a team without shape jobs closes under control (FJamHockeySense::bPressThree): goal-side of an opposing
		// carrier that goes, it plays the Press job's gap (JobSteer, EJob::Press) instead of the charge; the stick and the body play as before (StickPlay).
		if (Hk.Hk.bPressThree && Job[Id] == EJob::None && Role == ERole::Chaser && !bStalled && W.Carrier >= 0 && W.Carrier < W.NumSkaters
			&& W.Skaters[W.Carrier].Team != S.Team && !W.Skaters[W.Carrier].bDown && TeamSize(W, S.Team) < 5)
		{
			const FVec2 Cp = W.Skaters[W.Carrier].Pos;
			const FVec2 Vc = W.Skaters[W.Carrier].Vel;
			const FVec2 Ug = (OwnGoal - Cp).Normalized();
			if (Vc.Length() >= 3.0 && Me.DistTo(Cp) >= (Hk.Hk.PressThreeCommitM > 2.5 ? Hk.Hk.PressThreeCommitM : 2.5) && (Me - Cp).Dot(Ug) > 0.0)
			{
				const double Gap = Clamp(Vc.Length() * 0.3, 1.0, 3.0);
				const FVec2 T = Cp + Ug * Gap + FVec2(0.0, -Sign(Cp.Y) * 0.8);
				const double Gs = GapSpeed(Hk.Hk);   // lane A193: the chaser's own top speed (bTrueGap)
				Out = Arrive(Me, T, 1.5) + (Vc * (1.0 / (Gs > 1.0 ? Gs : 1.0))).LimitLength(Hk.Hk.PressRetreatCap);
				return Out + Separate(Me, W, Id, Params.SeparateRadius) * 1.2;
			}
		}
		if (Role == ERole::Chaser || (Role == ERole::Support && (D < Params.PounceRadius || bHunt)))
		{
			Out = Attack(W, Id, Me, Pp, Dirg, D, bShoot, bAimed, bDeke, bPass);
		}
		else if (Role == ERole::Back)
		{
			// Lane A134 (evolution 3): the back of a team without shape jobs steps up: an opposing carrier in our half within StepUpM of it is met from the front
			bool bStepUp = false;
			if (Hk.Hk.StepUpM > 0.0 && Job[Id] == EJob::None && D < Hk.Hk.StepUpM && W.Carrier >= 0 && W.Skaters[W.Carrier].Team != S.Team && !W.Skaters[W.Carrier].bDown
				&& Pp.X * OwnGoal.X > 0.0 && TeamSize(W, S.Team) < Hk.Hk.StepUpMaxTeam)   // lane A181: 5 as shipped (three a side); a level may lift it
			{
				const FVec2 Cp = W.Skaters[W.Carrier].Pos;
				bStepUp = (Me - Cp).Dot(OwnGoal - Cp) > 0.0;
			}
			if (D < 2.5 || bStepUp)
			{
				Out = Attack(W, Id, Me, Pp, Dirg, D, bShoot, bAimed, bDeke, bPass);
			}
			else if (SkillOf(W, Id).Hk.bMarkMan9 && MarkSlotMan(W, Id, SkillOf(W, Id), Out))
			{
				// lane A206 (wave 2): the second back marks the man in front of our net
			}
			else if (FiveSlot(W, Id, SkillOf(W, Id), Params.ArriveSlowRadius, Out))
			{
				// lane A83: the second back of a five holds the slot
			}
			else if (LastManGoalie(W, Id))
			{
				// R-0013 point 3: the carrier is inside our blue line and nobody stands between: hold the crease, squared to the
				// carrier (on the line goal centre -> carrier, 1.5 m out); the stick (StickPlay) pokes when the puck comes into reach
				const FVec2 C = W.Skaters[W.Carrier].Pos;
				FVec2 T = OwnGoal + (C - OwnGoal).Normalized() * 1.5;
				if (std::fabs(T.X) > W.GoalX) { T.X = OwnGoal.X; }
				Used[Id] = ERole::Back;
				Out = Arrive(Me, T - S.Vel * 0.25, 1.0);
				// Lane A31 (B-to-A-0024 point 3): the goalie intent for the visual. Side = where the carrier is, seen from the goalie facing
				// up-ice (Unreal frame: facing +x, left is -y; team 1 faces -x). Within a metre of the centre line: centre.
				bGoalieNow[Id] = true;
				const double Cy = C.Y;
				GoalieSideNow[Id] = std::fabs(Cy) < 1.0 ? 0 : static_cast<int>(Sign(Cy)) * (S.Team == 0 ? 1 : -1);
				// Lane A206 wave 3 (bDefendTeam9): the man in the crease plays a shot: onto its line (his body blocks), not standing on his post
				const double Pv9 = W.PuckVel.Length();
				if (SkillOf(W, Id).Hk.bDefendTeam9 && Pv9 > 6.0 && W.PuckVel.Dot(OwnGoal - Pp) > 0.0)
				{
					const FVec2 Dv = W.PuckVel * (1.0 / Pv9);
					const double Tg = std::fabs(Dv.X) > 1e-6 ? (OwnGoal.X - Pp.X) / Dv.X : -1.0;
					if (Tg > 0.0 && std::fabs(Pp.Y + Dv.Y * Tg) < W.GoalHalfWidth + 1.0)
					{
						double Along = (Me - Pp).Dot(Dv);
						Along = Along < 0.0 ? 0.0 : (Along > Tg ? Tg : Along);
						Out = Arrive(Me, Pp + Dv * Along - S.Vel * 0.25, 1.0);
					}
				}
			}
			else
			{
				FVec2 T;
				const FJamBotSkill& Gk = SkillOf(W, Id);
				if (Pp.X * OwnGoal.X > 0.0 || Pp.DistTo(OwnGoal) < Gk.GuardRangeM)
				{
					// lane A3 (R-0009, feel QA): puck in our half or in shooting range: guard the net, on the line goal centre -> puck, at most
					// GuardRadiusM from the goal centre, so a long shot meets a body (no goalies in this game)
					const FVec2 ToPuck = Pp - OwnGoal;
					const double L = ToPuck.Length();
					double R = L * 0.5 < Gk.GuardRadiusM ? L * 0.5 : Gk.GuardRadiusM;
					// lane A206 wave 3 (bDefendTeam9, EYE 3): an opposing carrier inside 35 m: the guard stands in the crease (1.5 m out), not on a post 5-10 m out
					if (Gk.Hk.bDefendTeam9 && W.Carrier >= 0 && W.Carrier < W.NumSkaters && W.Skaters[W.Carrier].Team != S.Team && L < 35.0 && R > 1.5) { R = 1.5; }
					T = OwnGoal + ToPuck.Normalized() * R;
					if (std::fabs(T.X) > W.GoalX) { T.X = OwnGoal.X; }
				}
				else
				{
					const FVec2 Gl = OwnGoal + FVec2(Sign(-OwnGoal.X) * 3.0, 0.0);
					T = Gl + (Pp - Gl).LimitLength(Params.BackRadius);
				}
				Out = Arrive(Me, T - S.Vel * 0.25, Params.ArriveSlowRadius);   // damped: stop on the post, do not slide through it
				// lane A3 (R-0009): a shot on our net: step onto its path (the closest point of the puck's line). R-0029 point 4 (lane A39): a back
				// committed by an opponent's deke steps onto the line the puck's old side would have taken (it is beaten to the other post).
				const double Pv = W.PuckVel.Length();
				const bool bCommitted = W.DekeCommitFrames > 0 && W.DekeCommitSkater >= 0 && W.DekeCommitSkater < W.NumSkaters && W.Skaters[W.DekeCommitSkater].Team != S.Team;
				const FVec2 Pb = bCommitted ? Pp - W.DekeCommitOffset : Pp;
				if (SkillOf(W, Id).bBlockShots && Pp.DistTo(OwnGoal) >= SkillOf(W, Id).BlockMinDistM && Pv > 6.0 && W.PuckVel.Dot(OwnGoal - Pp) > 0.0)
				{
					const FVec2 Dir = W.PuckVel * (1.0 / Pv);
					const double Tg = std::fabs(Dir.X) > 1e-6 ? (OwnGoal.X - Pb.X) / Dir.X : -1.0;
					const double Yg = Pb.Y + Dir.Y * Tg;
					if (Tg > 0.0 && std::fabs(Yg) < W.GoalHalfWidth + 1.0)
					{
						double Along = (Me - Pb).Dot(Dir);
						Along = Along < 0.0 ? 0.0 : (Along > Tg ? Tg : Along);
						const FVec2 Block = Pb + Dir * Along;
						// damped: aim ahead of our own drift so the skater stops on the line instead of sliding through it
						Out = Arrive(Me, Block - S.Vel * 0.25, 1.0);
					}
				}
			}
		}
		else if (Role == ERole::Support && S.Role != ERole::Back && SkillOf(W, Id).Hk.bSupportHuman && W.PlayerIndex >= 0 && W.CarrierOrHolder() == W.PlayerIndex
			&& W.Skaters[W.PlayerIndex].Team == S.Team)
		{
			// Lane A115: the human carries: this mate offers him an open lane beside or ahead (before: it stood between its own net and the puck, behind him)
			// Lane A153: in the first frames of his carry the mate nearest his nearest opponent screens it instead (ScreenPoint)
			FVec2 Sc;
			Out = ScreenPoint(W, Id, Sc) ? Arrive(Me, Sc, 1.0) : Arrive(Me, OfferLane(W, Id, W.PlayerIndex), Params.ArriveSlowRadius);
		}
		else if (Role == ERole::Support && FiveSupport(W, Id, Params.ArriveSlowRadius, Out))
		{
			// lane A83: a five's forecheck second man and weak-side support
		}
		else
		{
			const double Lane = S.Spawn.Y;
			FVec2 Between = LerpV(OwnGoal, Pp, 0.6);
			Between.X += Sign(OppGoal.X) * 4.0;
			Between.Y = Lerp(Between.Y, Lane, 0.5);
			if (bHasMateChaser && Between.DistTo(MateChaser) < Params.MinSeparation)
			{
				Between += (Between - MateChaser).Normalized() * Params.MinSeparation;
			}
			Out = Arrive(Me, Between, Params.ArriveSlowRadius);
			// R-0017: a support that reads lanes stands in the pass lane from the opposing carrier to its nearest teammate
			const int C = W.Carrier;
			if (SkillOf(W, Id).bReadLanes && C >= 0 && W.Skaters[C].Team != S.Team)
			{
				int Mate = -1;
				double Best = 1e18;
				for (int o = 0; o < W.NumSkaters; ++o)
				{
					if (o == C || W.Skaters[o].Team != W.Skaters[C].Team || W.Skaters[o].bDown) { continue; }
					const double Dd = W.Skaters[o].Pos.DistTo(W.Skaters[C].Pos);
					if (Dd < Best) { Best = Dd; Mate = o; }
				}
				if (Mate >= 0 && Best < 30.0)
				{
					const FVec2 PassLane = LerpV(W.Skaters[C].Pos, W.Skaters[Mate].Pos, 0.45);
					Out = Arrive(Me, PassLane - S.Vel * 0.2, Params.ArriveSlowRadius);
				}
			}
		}
		Out += Separate(Me, W, Id, Params.SeparateRadius) * 1.2;
		return Out;
	}

	// Lane A83 (R-0041 point 2): five a side. A team of five plays three forwards and two backs (player|chaser, chaser|support, support, back, back);
	// the second skater of a role on its team (by index) plays that role's five-a-side part, so the middle is not a pile. Teams of four or fewer
	// never reach these functions (bit-identical to 3 v 3). Engine-free, pure: no state of the brain is read or written except through Out.
	namespace FiveLocal
	{
		int TeamCount(const FJamAIWorld& W, int Team)
		{
			int N = 0;
			for (int o = 0; o < W.NumSkaters; ++o) { if (W.Skaters[o].Team == Team) { ++N; } }
			return N;
		}
		// 0 for the first skater of its spawn role on its team, 1 for the second, ...
		int RoleOrdinal(const FJamAIWorld& W, int Id)
		{
			int N = 0;
			for (int o = 0; o < Id; ++o) { if (W.Skaters[o].Team == W.Skaters[Id].Team && W.Skaters[o].Role == W.Skaters[Id].Role) { ++N; } }
			return N;
		}
		// The opposing carrier deep in its own end (its defensive third): the forecheck's moment.
		bool OppCarrierDeep(const FJamAIWorld& W, int Id)
		{
			const int C = W.Carrier;
			if (C < 0 || C >= W.NumSkaters || W.Skaters[C].Team == W.Skaters[Id].Team) { return false; }
			const FVec2 OppGoal = W.OppGoal(W.Skaters[Id].Team);
			const FVec2 Cp = W.Skaters[C].Pos;
			return Cp.X * OppGoal.X > 0.0 && std::fabs(Cp.X) > W.HalfLength / 3.0;
		}
		// The carrier's nearest standing teammate (its outlet), -1 when none within 30 m.
		int Outlet(const FJamAIWorld& W, int C)
		{
			int Mate = -1;
			double Best = 30.0;
			for (int o = 0; o < W.NumSkaters; ++o)
			{
				if (o == C || W.Skaters[o].Team != W.Skaters[C].Team || W.Skaters[o].bDown) { continue; }
				const double Dd = W.Skaters[o].Pos.DistTo(W.Skaters[C].Pos);
				if (Dd < Best) { Best = Dd; Mate = o; }
			}
			return Mate;
		}
		// Lane A181 (evolution 6): whom the Cover job covers: the carrier's nearest team-mate (Outlet), or, with bCoverBestPass, the one its pass would go to
		int CoverMate(const FJamAIWorld& W, int C, bool bBestPass)
		{
			if (bBestPass)
			{
				const int Bp = W.Carrier == C ? W.CarrierBestPass : (W.Holder == C ? W.HolderBestPass : -1);
				if (Bp >= 0 && Bp < W.NumSkaters && Bp != C && W.Skaters[Bp].Team == W.Skaters[C].Team && !W.Skaters[Bp].bDown) { return Bp; }
			}
			return Outlet(W, C);
		}
	}

	// The supports of a five. The first support is the forecheck's second man (F2): with the opposing carrier deep in its end it takes away the
	// outlet (stands on the pass lane to the carrier's nearest teammate, nearer the carrier), while the chaser (F1) presses the puck. The second
	// support covers the weak side: the far side of the rink from the puck, a little ahead of it when we have the puck or it is loose (the back-door
	// lane for a cross-ice pass), back in our half on the far post's lane when they have it. Returns false when the 3 v 3 support play stands.
	bool FiveSupport(const FJamAIWorld& W, int Id, double SlowRadius, FVec2& Out)
	{
		using namespace FiveLocal;
		const FJamAISkater& S = W.Skaters[Id];
		if (S.Role != ERole::Support || TeamCount(W, S.Team) < 5) { return false; }
		const FVec2 Me = S.Pos;
		const FVec2 Pp = W.PuckPos;
		const FVec2 OwnGoal = W.OwnGoal(S.Team);
		const FVec2 OppGoal = W.OppGoal(S.Team);
		const int Ord = RoleOrdinal(W, Id);
		const int C = W.Carrier;
		if (Ord == 0)
		{
			if (!OppCarrierDeep(W, Id)) { return false; }
			const int M = Outlet(W, C);
			if (M < 0) { return false; }
			const FVec2 Lane = LerpV(W.Skaters[C].Pos, W.Skaters[M].Pos, 0.4);
			Out = Arrive(Me, Lane - S.Vel * 0.2, SlowRadius);
			return true;
		}
		// the weak side: the side of the rink away from the puck (the spawn's side when the puck is near the middle)
		const double Side = std::fabs(Pp.Y) > 2.0 ? -Sign(Pp.Y) : (S.Spawn.Y != 0.0 ? Sign(S.Spawn.Y) : 1.0);
		const bool bTheirs = C >= 0 && C < W.NumSkaters && W.Skaters[C].Team != S.Team;
		FVec2 T;
		if (bTheirs)
		{
			// back-check: the far lane, between our net and the puck, a third of the width out
			T = LerpV(OwnGoal, Pp, 0.45);
			T.Y = Side * W.HalfWidth * 0.35;
		}
		else
		{
			// ahead of the puck towards their net, on the far side: open for the cross-ice pass and the back door
			T = FVec2(Lerp(Pp.X, OppGoal.X, 0.3), Side * W.HalfWidth * 0.45);
		}
		T.X = Clamp(T.X, -W.GoalX + 3.0, W.GoalX - 3.0);
		Out = Arrive(Me, T, SlowRadius);
		return true;
	}

	// The second back of a five holds the slot: with the puck within the profile's guard range of our net (pro 45 m: about our half; rookie 20 m)
	// it stands the guard radius + 2 m out in front of our net (pro 7 m, rookie 12 m), shaded a third of the way towards the puck's side (the first
	// back keeps the guard post on the goal-puck line and the crease). Further out: when we carry it in their half, the trailer at their point on
	// the far side from the puck; otherwise a quarter of the way up our half, shaded to the puck's side (the breakout outlet). It steps onto a
	// shot's path like the first back. Returns false for the first back and for teams of four or fewer. FIVE.md: slot 12 % -> 38 % (pro, regular
	// playtester), the trailer 40 %, the profile's depth brings the rookie novice back to 93 % (65 % at a fixed 7 m).
	bool FiveSlot(const FJamAIWorld& W, int Id, const FJamBotSkill& Gk, double SlowRadius, FVec2& Out)
	{
		using namespace FiveLocal;
		const FJamAISkater& S = W.Skaters[Id];
		if (S.Role != ERole::Back || TeamCount(W, S.Team) < 5 || RoleOrdinal(W, Id) == 0) { return false; }
		const FVec2 Me = S.Pos;
		const FVec2 Pp = W.PuckPos;
		const FVec2 OwnGoal = W.OwnGoal(S.Team);
		const double Up = Sign(-OwnGoal.X);   // up-ice from our net
		FVec2 T;
		if (Pp.DistTo(OwnGoal) < Gk.GuardRangeM)
		{
			// the slot, as deep as the profile's guard post allows (pro 7 m out; rookie, whose back guards 10 m out within 20 m, 12 m and only then)
			T = FVec2(OwnGoal.X + Up * (Gk.GuardRadiusM + 2.0), Clamp(Pp.Y * 0.3, -3.0, 3.0));
		}
		else if (W.Carrier >= 0 && W.Carrier < W.NumSkaters && W.Skaters[W.Carrier].Team == S.Team)
		{
			// we carry it in their half: the trailer at their point, on the far side from the puck (the cross-ice pass and the late shot)
			T = FVec2(Up * W.HalfLength * 0.45, -Sign(Pp.Y) * W.HalfWidth * 0.3);
		}
		else
		{
			T = FVec2(Up * -W.HalfLength * 0.25, Clamp(Pp.Y * 0.4, -6.0, 6.0));
		}
		Out = Arrive(Me, T - S.Vel * 0.25, SlowRadius);
		const double Pv = W.PuckVel.Length();
		if (Gk.bBlockShots && Pp.DistTo(OwnGoal) >= Gk.BlockMinDistM && Pv > 6.0 && W.PuckVel.Dot(OwnGoal - Pp) > 0.0)
		{
			const FVec2 Dir = W.PuckVel * (1.0 / Pv);
			const double Tg = std::fabs(Dir.X) > 1e-6 ? (OwnGoal.X - Pp.X) / Dir.X : -1.0;
			const double Yg = Pp.Y + Dir.Y * Tg;
			if (Tg > 0.0 && std::fabs(Yg) < W.GoalHalfWidth + 1.0)
			{
				double Along = (Me - Pp).Dot(Dir);
				Along = Along < 0.0 ? 0.0 : (Along > Tg ? Tg : Along);
				if (Along < Tg - 0.5) { Out = Arrive(Me, Pp + Dir * Along - S.Vel * 0.25, 1.0); }   // only a lane it can reach in front of the net
			}
		}
		return true;
	}

	// Lane A206 (track Q2, evolution 9, wave 2; BRAIN-9.md): MarkSlotMan (bMarkMan9). The second back of a five, the puck within its guard range of our net and
	// not on its way at the net, marks the standing opponent nearest our net (not the carrier, within 20 m of it): goal-side of him by 1.5 m, moving with him,
	// instead of standing on the slot spot (FiveSlot). Nobody to mark: false (FiveSlot as before).
	bool MarkSlotMan(const FJamAIWorld& W, int Id, const FJamBotSkill& Gk, FVec2& Out)
	{
		using namespace FiveLocal;
		const FJamAISkater& S = W.Skaters[Id];
		if (S.Role != ERole::Back || TeamCount(W, S.Team) < 5 || RoleOrdinal(W, Id) == 0) { return false; }
		const FVec2 OwnGoal = W.OwnGoal(S.Team);
		if (W.PuckPos.DistTo(OwnGoal) >= Gk.GuardRangeM) { return false; }
		const double Pv = W.PuckVel.Length();
		if (Pv > 6.0 && W.PuckVel.Dot(OwnGoal - W.PuckPos) > 0.0) { return false; }   // a shot on our net: FiveSlot blocks it
		const int C = W.CarrierOrHolder();
		int Mark = -1;
		double Best = 20.0;
		for (int o = 0; o < W.NumSkaters; ++o)
		{
			const FJamAISkater& O = W.Skaters[o];
			if (O.Team == S.Team || O.bDown || o == C) { continue; }
			const double D = O.Pos.DistTo(OwnGoal);
			if (D < Best) { Best = D; Mark = o; }
		}
		if (Mark < 0) { return false; }
		const FJamAISkater& O = W.Skaters[Mark];
		const FVec2 T = O.Pos + (OwnGoal - O.Pos).Normalized() * 1.5 + O.Vel * 0.3;
		Out = Arrive(S.Pos, T, 1.0);
		return true;
	}

	bool FJamBrain::LastManGoalie(const FJamAIWorld& W, int Id) const
	{
		const int C = W.Carrier;
		const FJamAISkater& S = W.Skaters[Id];
		if (C < 0 || W.Skaters[C].Team == S.Team)
		{
			return false;
		}
		const FVec2 OwnGoal = W.OwnGoal(S.Team);
		const FVec2 Cp = W.Skaters[C].Pos;
		// inside our blue line: the outer third of the rink on our side
		if (Cp.X * OwnGoal.X <= 0.0 || std::fabs(Cp.X) < W.HalfLength / 3.0)
		{
			return false;
		}
		const FVec2 Line = Cp - OwnGoal;
		const double L = Line.Length();
		if (L < 1e-6) { return false; }
		const FVec2 U = Line * (1.0 / L);
		for (int o = 0; o < W.NumSkaters; ++o)
		{
			if (o == Id || W.Skaters[o].Team != S.Team || W.Skaters[o].bDown) { continue; }
			const FVec2 Rel = W.Skaters[o].Pos - OwnGoal;
			const double Along = Rel.Dot(U);
			if (Along > 0.0 && Along < L && std::fabs(Rel.Cross(U)) < 2.5) { return false; }   // a teammate stands between
		}
		return true;
	}

	bool CreaseStance(const FJamAIWorld& W, int Id, int& OutSide)
	{
		OutSide = 0;
		if (Id < 0 || Id >= W.NumSkaters || W.bFrozen) { return false; }
		const FJamAISkater& S = W.Skaters[Id];
		if (S.bDown || W.Carrier == Id) { return false; }
		const int C = W.Carrier;
		if (C < 0 || W.Skaters[C].Team == S.Team) { return false; }
		const FVec2 OwnGoal = W.OwnGoal(S.Team);
		const FVec2 Cp = W.Skaters[C].Pos;
		// the carrier inside our blue line: the outer third of the rink on our side (LastManGoalie's rule)
		if (Cp.X * OwnGoal.X <= 0.0 || std::fabs(Cp.X) < W.HalfLength / 3.0) { return false; }
		// in the crease: within CreaseStanceM of the goal centre, on the ice side of the goal line
		if (S.Pos.DistTo(OwnGoal) > CreaseStanceM || std::fabs(S.Pos.X) > W.GoalX) { return false; }
		OutSide = std::fabs(Cp.Y) < 1.0 ? 0 : static_cast<int>(AICoreLocal::Sign(Cp.Y)) * (S.Team == 0 ? 1 : -1);
		return true;
	}

	void FJamBrain::StickPlay(const FJamAIWorld& W, int Id, FJamAIInput& In)
	{
		const FJamAISkater& S = W.Skaters[Id];
		const FJamBotSkill& K = SkillOf(W, Id);
		const int C = W.Carrier;
		const bool bOppCarrier = C >= 0 && W.Skaters[C].Team != S.Team;
		// R-0029 point 4 (lane A39): during an opponent's deke commit the blade and the poke follow the puck's old side: the back reads where the
		// puck was, not where it went, for deke.commit_frames (and the flight of a shot released inside the window).
		const bool bCommitted = W.DekeCommitFrames > 0 && W.DekeCommitSkater >= 0 && W.DekeCommitSkater < W.NumSkaters && W.Skaters[W.DekeCommitSkater].Team != S.Team;
		// Lane A51 (R-0034): against an opposing carrier the blade and the poke read the puck's place on the body SweepReactFrames late (PuckSeen), so a
		// sweep inside the stick's reach beats the poke; the deke commit (A39) wins over it while it runs.
		const FVec2 PuckRef = bCommitted ? W.PuckPos - W.DekeCommitOffset : PuckSeen(W, Id);
		const FVec2 To = PuckRef - S.Pos;
		const double D = To.Length();
		const double Blade = W.SkaterRadius + W.StickReach;
		// the blade follows the puck when it is near (zero aim = the sim's default, ahead at half reach)
		if (D > 1e-6 && D < Blade + 1.0)
		{
			// Lane A66: on its own puck inside its shooting range the bot draws the blade inside shot reach. Since A51 the sim carries the puck out to
			// the blade's full reach (0.4 + stick.reach_m 1.2 = 1.6 m, past shot.reach_m 1.5), and a blade aimed at the puck's own distance held it
			// there: carried, but beyond TryShoot's and the charge's reach, and the bot never shot (Jam.Bot.SeasonTakes take-3 / take-4 seed 1,
			// docs/experiments/STICK.md section 8). Outside the range the long carry stays as A51 made it (the passes to the human come from there).
			// R-0042 (lane A85): the sim's carrier reach now covers the blade's full length and the bots shoot without this cap (SeasonTakes take-1 AI shots
			// 1 / 1 / 4, ProCharge green), but the cap stays, measured (docs/experiments/MECHANICS-3.md section 3): without it a bot carries in the 1.5-1.65 m
			// band where the brain's W.Carrier (JamSimAdapter: shot.reach_m) does not see a carrier; with W.Carrier left there Jam.Core.NetTrap fails (a pro
			// bot that does not know it carries presses into the net hull for 47 frames), and with W.Carrier moved to the carrier reach three curve gates
			// move (HumanHasSomethingToDo, PassesToHuman at rookie, ModeKeys.Sprint). The cap and W.Carrier go together, with the curve (A79).
			double MaxFrac = 1.0;
			if (W.PuckLastTouch == Id && !bOppCarrier && W.StickReach > 0.01 && (W.PuckPos.DistTo(W.OppGoal(S.Team)) < W.ShotReach + K.ShootExtraM || PassHold[Id] > 0))   // PassHold: lane A77, the saucer's hold needs the puck in pass reach
			{
				const double Cap = (W.ShotReach - 0.1 - W.SkaterRadius) / W.StickReach;
				if (Cap > 0.2 && Cap < MaxFrac) { MaxFrac = Cap; }
			}
			In.Stick = To * (1.0 / D) * Clamp((D - W.SkaterRadius) / (W.StickReach > 0.01 ? W.StickReach : 0.01), 0.2, MaxFrac);
		}
		InReach[Id] = (bOppCarrier && D <= Blade) ? InReach[Id] + 1 : 0;
		// HOOK (lane A115 for track F2's game.stick.body_shield, lane A102): the carrier's body is between this bot's stick and the puck: the sim refuses the
		// poke and the lift (158 of 200 pro lifts in A102's carry drill), so the bot presses neither and goes round the body (Attack) or checks it (below: a
		// body check is never shielded). Dead until FJamSimAdapter::BuildWorld fills W.bBodyShield.
		bool bShielded = K.Hk.bReadShield && bOppCarrier && StickCannotTake(W, Id, C);   // the body shield, or the carrier's take grace (lane A121)
		// Lane A138: the spin's exposed end (BodyShields is false there: the sim lets a stick take the puck). The bot answers a share of the spins it meets
		// (FJamHockeySense::SpinEndShare, a fixed coin per bot and spin: the frame the spin ends on names the spin); the others it reads as the shield it was.
		if (K.Hk.bReadShield && bOppCarrier && !bShielded && K.Hk.SpinEndShare < 1.0)
		{
			const FJamAISkater& Tc = W.Skaters[C];
			if (Tc.SpinFrames > 0 && Tc.SpinFrames <= W.SpinExposedFrames
				&& (K.Hk.SpinEndShare <= 0.0 || (Hash11(static_cast<uint64_t>(Id) * 31 + static_cast<uint64_t>(C) + 503, static_cast<uint64_t>(W.Frame + Tc.SpinFrames)) + 1.0) * 0.5 >= K.Hk.SpinEndShare))
			{
				bShielded = true;
			}
		}
		// poke: the level's timing (frames the puck must sit inside reach); rookie never pokes
		// Lane A115: the stick of the human's mates (FJamHockeySense::MateStickFrames), where the skill itself has none
		const bool bMateStick = K.Hk.MateStickFrames >= 0 && W.PlayerIndex >= 0 && W.Skaters[W.PlayerIndex].Team == S.Team;
		int PokeFrames = (K.PokeFrames < 0 && bMateStick) ? K.Hk.MateStickFrames : K.PokeFrames;
		if (PokeFrames >= 0 && K.Hk.Poke9Frames > PokeFrames) { PokeFrames = K.Hk.Poke9Frames; }   // lane A206 (evolution 9): a slower stick
		if (PokeFrames >= 0 && bOppCarrier && S.bCanPoke && InReach[Id] > PokeFrames && !bShielded)
		{
			In.bPoke = true;
			InReach[Id] = 0;
		}
		// lift at contact
		// Lane A95 (B-to-A-0037): only inside the sim's cone (a swing outside it is a miss) and not again inside the level's cooldown.
		// Lane A138 (track I1, R-0053 point 3): a lift the shield refuses is a shove (lane A125), and from behind that shove is a push in the back: the
		// from-behind foul where the whistle is on, not a play the brain chooses where it is off. Whatever the bot's other rules (the shield read on or off),
		// it presses no lift on a shielded carrier it stands behind (the push along the carrier's facing above 0.35, the body check's own margin below),
		// unless its skill checks from behind. Dead while the sim's shove rule is off or no shield is up (W.bShieldShove, StickCannotTake).
		bool bBehindShove = false;
		if (W.bShieldShove && bOppCarrier && !K.bCheckFromBehind && StickCannotTake(W, Id, C))
		{
			const FVec2 Nb = (W.Skaters[C].Pos - S.Pos).Normalized();
			bBehindShove = Nb.Dot(W.Skaters[C].Facing.Normalized()) > 0.35;
		}
		if ((K.bLift || bMateStick) && bOppCarrier && S.bCanLift && !bShielded && !bBehindShove && W.Skaters[C].Pos.DistTo(S.Pos) <= 2.0 * W.SkaterRadius + W.LiftRange * 0.9
			&& W.Frame - LiftLast[Id] >= (K.bLift ? K.LiftCooldownFrames : 90)
			&& (W.LiftConeDeg >= 180.0 || (W.Skaters[C].Pos - S.Pos).Normalized().Dot(S.Facing) >= std::cos(W.LiftConeDeg * 3.14159265358979323846 / 180.0)))
		{
			In.bLift = true;
			LiftLast[Id] = W.Frame;
		}
		// pass out of pressure: a defender within 2 m and an open teammate (no opponent within 3 m of it, within 25 m)
		if (K.bPassOut && C == Id && !In.bShoot)
		{
			bool bPressure = false, bOpen = false;
			for (int o = 0; o < W.NumSkaters; ++o)
			{
				if (W.Skaters[o].Team != S.Team && !W.Skaters[o].bDown && W.Skaters[o].Pos.DistTo(S.Pos) < 2.0) { bPressure = true; }
			}
			for (int t = 0; t < W.NumSkaters && bPressure && !bOpen; ++t)
			{
				if (t == Id || W.Skaters[t].Team != S.Team || W.Skaters[t].bDown || W.Skaters[t].Pos.DistTo(S.Pos) > 25.0) { continue; }
				bool bFree = true;
				for (int o = 0; o < W.NumSkaters; ++o)
				{
					if (W.Skaters[o].Team != S.Team && W.Skaters[o].Pos.DistTo(W.Skaters[t].Pos) < 3.0) { bFree = false; }
				}
				bOpen = bFree;
			}
			In.bPass = In.bPass || (bPressure && bOpen);   // lane A46: Attack's pass to the human stays
		}
		// Director 15:16: a carrier under the human's forecheck gives the puck up after the level's frames: pass, else dump it
		if (C == Id && W.PlayerIndex >= 0 && W.Skaters[W.PlayerIndex].Team != S.Team && !W.Skaters[W.PlayerIndex].bDown
			&& W.Skaters[W.PlayerIndex].Pos.DistTo(W.PuckPos) <= W.SkaterRadius + W.StickReach)
		{
			++Pressed[Id];
		}
		else
		{
			Pressed[Id] = 0;
		}
		if (K.ForecheckYieldFrames >= 0 && Pressed[Id] > K.ForecheckYieldFrames)
		{
			In.bPass = true;
			if (Pressed[Id] > K.ForecheckYieldFrames + 8 && S.bCanShoot) { In.bShoot = true; }
		}
		// R-0031 point 2 (lane A45; ends R-0017 point 4 for pro and all_star): the body check. Only on the opposing carrier, only when the closing speed along the
		// line to it and the bot's own speed along that line are both at least the skill's CheckMinClosing (the sim lands on the checker's own speed above
		// check_speed_min; the hit's strength is the closing speed), only from the front or the side (the push along the carrier's facing above 0.35 is left alone:
		// the sim's foul_from_behind band is 0.5, the margin covers the frames to contact), only when standing. One press per CheckCoolFrames: bCheck is a level in
		// the sim (held = re-armed and PlayCheck every frame). Pressed inside CheckArmGapM of contact: at 5 m/s that is the sim's 6-frame window. A skill with
		// CheckMinClosing < 0 (rookie) never presses, so no bot earns the box for a check on a skater without the puck or from behind.
		In.bCheck = false;
		if (CheckCool[Id] > 0) { --CheckCool[Id]; }
		// Lane A134 (evolution 3): the human's mates check too (FJamHockeySense::MateCheckClosing): a kept puck leaves by a body, not by a stick from behind
		const double CheckMin = (K.CheckMinClosing < 0.0 && bMateStick && K.Hk.MateCheckClosing >= 0.0 && TeamSize(W, S.Team) < K.Hk.MateCheckMaxTeam) ? K.Hk.MateCheckClosing : K.CheckMinClosing;
		// Lane A181 (evolution 6): no check on a carrier that has only just won the puck (FJamHockeySense::FreshTakeFrames): the puck, not the man
		const bool bFreshTake = K.Hk.FreshTakeFrames > 0 && bOppCarrier && CarryFrames[C] < K.Hk.FreshTakeFrames;
		if (CheckMin >= 0.0 && bOppCarrier && !bFreshTake && !S.bDown && CheckCool[Id] <= 0 && !W.bFaceoffPhase)
		{
			constexpr int CheckCoolFrames = 30;
			constexpr double CheckArmGapM = 0.5;
			const FJamAISkater& T = W.Skaters[C];
			const FVec2 Rel = T.Pos - S.Pos;
			const double Dist = Rel.Length();
			// Lane A184 (game.contact.check_windup_frames): the window opens that many frames after the press, so the press goes as much earlier: the arm gap
			// grows by the ground the closing speed covers in the wind-up (0 frames: the gap as it was, the same presses).
			// Lane A200: a bot's own length (W.BotCheckWindup(): bot_check_windup_frames, absent = the shared one); with FJamHockeySense::bWindupLeadNoBrake
			// (off) no lead on a carrier that is braking.
			const int BotWu = W.BotCheckWindup();
			const bool bLead = BotWu > 0 && Dist > 1e-6 && !(K.Hk.bWindupLeadNoBrake && T.bBraking);
			const double WindupLeadM = bLead ? Clamp((S.Vel - T.Vel).Dot(Rel * (1.0 / Dist)), 0.0, 1e9) * BotWu / 60.0 : 0.0;
			if (Dist > 1e-6 && Dist <= 2.0 * W.SkaterRadius + CheckArmGapM + WindupLeadM && !T.bDown && T.GraceFrames <= 0)   // lane A113 (R-0049 point 1): no check starts on a skater inside its release grace
			{
				const FVec2 N = Rel * (1.0 / Dist);   // the push: checker towards the carrier
				const double Closing = (S.Vel - T.Vel).Dot(N);
				const double Own = S.Vel.Dot(N);
				const double Along = N.Dot(T.Facing.Normalized());
				// lane A72 (ask A5): game.ai.body_check takes a share of the chances; the coin is only thrown below 1, so a level's own rule is unchanged
				const bool bTake = K.BodyCheckShare >= 1.0
					|| (K.BodyCheckShare > 0.0 && (Hash11(static_cast<uint64_t>(Id) + 307, static_cast<uint64_t>(W.Frame / 60)) + 1.0) * 0.5 < K.BodyCheckShare);
				if (bTake && Closing >= CheckMin && Own > CheckMin && (K.bCheckFromBehind || Along <= 0.35))
				{
					In.bCheck = true;
					CheckCool[Id] = CheckCoolFrames;
				}
			}
		}
		// Lane A184 (track F1, evolution 9; game.contact.cross_hold): the bot's brace. Held on an opposing carrier it is closing on at K.CrossHoldClosing or more,
		// from the front or the side (the sim's braced hit is not into a back), within CrossHoldRangeM of contact; let go otherwise, so the sim's brace re-arms
		// after it was spent. -1 (every level) = never: the input stays false.
		In.bCrossHold = false;
		if (K.CrossHoldClosing >= 0.0 && bOppCarrier && C != Id && !bFreshTake && !S.bDown && !W.bFaceoffPhase)
		{
			constexpr double CrossHoldRangeM = 4.0;
			const FJamAISkater& T = W.Skaters[C];
			const FVec2 Rel = T.Pos - S.Pos;
			const double Dist = Rel.Length();
			if (Dist > 1e-6 && Dist <= 2.0 * W.SkaterRadius + CrossHoldRangeM && !T.bDown && T.GraceFrames <= 0)
			{
				const FVec2 N = Rel * (1.0 / Dist);
				if ((S.Vel - T.Vel).Dot(N) >= K.CrossHoldClosing && N.Dot(T.Facing.Normalized()) <= 0.35) In.bCrossHold = true;
			}
		}
		// R-0019: never shoot from inside a no_shoot zone
		if (S.bNoShoot) { In.bShoot = false; }
	}

	FVec2 FJamBrain::Attack(const FJamAIWorld& W, int Id, const FVec2& Me, const FVec2& Pp, const FVec2& Dirg, double D, bool& bShoot, bool& bAimed, bool& bDeke, bool& bPass) const
	{
		const FJamAISkater& S = W.Skaters[Id];
		const FJamBotSkill& K = SkillOf(W, Id);
		bPlaysPuck[Id] = true;   // lane A115: the brake rule in Think reads it
		const FVec2 Fwd = S.Facing.Normalized();
		const FVec2 OppGoal = W.OppGoal(S.Team);
		const double Dgoal = Pp.DistTo(OppGoal);
		const double GeoTol = RadToDeg(std::atan2(1.4, Dgoal > 1.0 ? Dgoal : 1.0));
		double Tol = K.AimToleranceDeg < GeoTol ? K.AimToleranceDeg : GeoTol;
		// lane A3: aim error. The bot lines up on a point off the goal centre by up to AimErrorDeg; the error is a fixed
		// function of the skater and a 2-second window, so the approach does not jitter.
		FVec2 Aim = Dirg;
		const double AimErr = K.Hk.AimError9Deg > K.AimErrorDeg ? K.Hk.AimError9Deg : K.AimErrorDeg;   // lane A206 (evolution 9): a wider aim
		const double ShootExtra = K.Hk.ShootExtra9M > 0.0 ? K.Hk.ShootExtra9M : K.ShootExtraM;          // lane A206: the shot's reach
		if (AimErr > 0.0)
		{
			Aim = Rotate(Dirg, DegToRad(AimErr * Hash11(static_cast<uint64_t>(Id) + 1, static_cast<uint64_t>(W.Frame / 120))));
		}
		bool bFaceOk = Fwd.Dot(Aim) > std::cos(DegToRad(Tol));
		if ((K.bUseAimCone || K.Hk.bAimCone9) && Params.AimConeDeg > 0.0 && AimErr <= 0.0)
		{
			// lane A3: the sim snaps a shot facing inside the cone onto the goal centre; a bot that knows it shoots there
			bFaceOk = bFaceOk || Fwd.Dot(Dirg) > std::cos(DegToRad(Params.AimConeDeg * 0.9));
		}
		const bool bNearWall = std::fabs(Pp.Y) > W.HalfWidth - 2.0 && Dgoal > 6.0;
		// Lane A153 (evolution 4, REVIEW-2 item 10): a mate inside MateFinishM with an open lane finishes its chance (JamAICore.h)
		// bDrive: the lane to the net is open inside the larger of MateFinishM and MateDriveM (the mate keeps the puck and goes); bFinish: inside MateFinishM (it shoots)
		bool bFinish = false, bDrive = false;
		const double ZoneM = K.Hk.MateFinishM > K.Hk.MateDriveM ? K.Hk.MateFinishM : K.Hk.MateDriveM;
		if (ZoneM > 0.0 && Dgoal < ZoneM && Dgoal > 3.0 && !bNearWall && W.CarrierOrHolder() == Id
			&& W.PlayerIndex >= 0 && W.PlayerIndex != Id && W.Skaters[W.PlayerIndex].Team == S.Team)
		{
			const FVec2 Tg = OppGoal - Pp;
			bDrive = RadToDeg(std::atan2(std::fabs(Tg.Y), std::fabs(Tg.X))) <= 60.0;
			const double Lane = Dgoal - 3.0;
			for (int o = 0; o < W.NumSkaters && bDrive; ++o)
			{
				if (W.Skaters[o].Team == S.Team || W.Skaters[o].bDown) { continue; }
				const FVec2 Rel = W.Skaters[o].Pos - Pp;
				const double Along = Rel.Dot(Dirg);
				if (Along > 0.0 && Along < Lane && std::fabs(Rel.Cross(Dirg)) < 1.2) { bDrive = false; }
			}
			bFinish = bDrive && Dgoal < K.Hk.MateFinishM;
			if (bFinish && Params.AimConeDeg > 0.0) { bFaceOk = bFaceOk || Fwd.Dot(Dirg) > std::cos(DegToRad(Params.AimConeDeg * 0.9)); }
		}
		bool bOkShot = bFaceOk && (Dgoal < W.ShotReach + ShootExtra || bFinish) && !bNearWall;
		if (bOkShot && K.bClearLane)
		{
			// lane A3: no shot into a defender's body; keep carrying instead
			const FVec2 Lane = Fwd;
			for (int o = 0; o < W.NumSkaters && bOkShot; ++o)
			{
				if (W.Skaters[o].Team == S.Team) { continue; }
				const FVec2 Rel = W.Skaters[o].Pos - Pp;
				const double Along = Rel.Dot(Lane);
				if (Along > 0.0 && Along < Dgoal && std::fabs(Rel.Cross(Lane)) < 1.2) { bOkShot = false; }
			}
		}
		// Lane A134 (evolution 3, shot selection): no aimed shot from the corner by the goal line (further off the net's axis than ShotMaxAngleDeg, where
		// the mouth is a slit): the carrier takes the puck to the slot (Push below) or passes (carry or pass). A stalled puck is still shot away.
		bool bSharp = false;
		if (K.Hk.ShotMaxAngleDeg > 0.0)
		{
			const FVec2 Tg = OppGoal - Pp;
			bSharp = RadToDeg(std::atan2(std::fabs(Tg.Y), std::fabs(Tg.X))) > K.Hk.ShotMaxAngleDeg || Pp.X * Sign(OppGoal.X) > W.GoalX;
			if (bSharp) { bOkShot = false; }
		}
		if (bStalled && Fwd.Dot(Dirg) > 0.0)
		{
			bOkShot = true;
		}
		if (D < W.CarrierReach() && bOkShot && S.bCanShoot)   // R-0042 (lane A85): the carrier's reach (the blade's full length included)
		{
			bShoot = true;
			bAimed = true;   // lane A31: the one shot worth charging
		}
		// R-0029 point 4 (lane A39): the one-timer. A pass just landed on the blade: shoot at once while the window is open, the net is in range and the
		// facing is inside the widened cone (the sim adds one_timer.cone_bonus_deg; the brain assumes the default 8 on top of the aim cone).
		if ((K.bOneTimer || K.Hk.bOneTimer9) && S.OneTimerFrames > 0 && S.bCanShoot && D < W.CarrierReach() && Dgoal < W.ShotReach + ShootExtra + 10.0 && !bNearWall && !bSharp
			&& Fwd.Dot(Dirg) > std::cos(DegToRad((Params.AimConeDeg > 0.0 ? Params.AimConeDeg : 0.0) + 8.0)))
		{
			bShoot = true;
		}
		// The deke against the last man: the carrier inside 12 m of the net, facing it, with an opponent holding the crease on its line: one tap, no shot
		// until the puck has moved, then the shot (the sim aims it at the open post).
		if (K.bDeke && W.Carrier == Id)
		{
			if (S.DekeFrames > 0)
			{
				bShoot = S.bDekeSettled && S.bCanShoot && Fwd.Dot(Dirg) > std::cos(DegToRad(20.0));
			}
			else if (S.bCanDeke && Dgoal > 5.0 && Dgoal < 12.0 && Fwd.Dot(Dirg) > std::cos(DegToRad(20.0)))
			{
				for (int o = 0; o < W.NumSkaters; ++o)
				{
					const FJamAISkater& O = W.Skaters[o];
					if (O.Team == S.Team || O.bDown) { continue; }
					const FVec2 Rel = O.Pos - Pp;
					const double Along = Rel.Dot(Dirg);
					if (Along > 0.0 && Along < Dgoal && std::fabs(Rel.Cross(Dirg)) < 2.0 && O.Pos.DistTo(OppGoal) < 5.0) { bDeke = true; bShoot = false; break; }
				}
			}
		}
		// lane A3 / lane A46 (PAYOFFS.md section 6): a teammate carrying the puck passes to the human in a share of the chances when the human is open: standing,
		// 5-25 m away, ahead of or level with the puck up the ice, no opponent within 2 m of the lane (lane A3's lane check). The share is mate.pass_to_human
		// (rookie 0.6, pro 0.4, all_star 0.2); the human's `pass` signal (R-0007) makes it 0.9 while it runs. The coin is a fixed function of the skater and the
		// 2-second window (no randomness). The chaser and the support pass; the back only while the human calls `space` or `pass`. The pass itself is the sim's
		// (bPass: the lead solved for the receiver) when the sim would pick the human (W.CarrierBestPass); else lane A3's aimed tap at the human, from 8 m or more
		// (17.9 m/s minus puck.drag 0.5 per metre arrives under the 14 m/s cap of the body reception). A shot decided above (one-timer, aimed shot) comes first.
		const bool bPassIntent = TeamIntent.Kind == ETeamIntent::Pass && TeamIntent.Active(W.Frame);
		// lane A206 (wave 2): a mate driving at the net with an open lane (DriveNet) gives the puck to the human only when he is set up for the one-timer
		const bool bDrive9 = K.Hk.bDriveFirst9 && K.Hk.DriveNet9M > 0.0 && !bSharp && !bShoot && DriveNet(W, Id, Aim, Dgoal);
		const bool bSpaceIntent = TeamIntent.Kind == ETeamIntent::Space && TeamIntent.Active(W.Frame);
		const double Share = bPassIntent ? 0.9 : K.PassToHuman;
		if (Share > 0.0 && W.PlayerIndex >= 0 && W.Skaters[W.PlayerIndex].Team == S.Team && W.Carrier == Id && S.bCanShoot && !bShoot
			&& (S.Role != ERole::Back || bPassIntent || bSpaceIntent))
		{
			const FJamAISkater& H = W.Skaters[W.PlayerIndex];
			const FVec2 To = H.Pos + H.Vel * 0.3 - Pp;
			const double Dh = To.Length();
			const double Coin = (Hash11(static_cast<uint64_t>(Id) + 101, static_cast<uint64_t>(W.Frame / 120)) + 1.0) * 0.5;   // [0, 1) per 2-second window
			const bool bAheadOrLevel = (H.Pos.X - Pp.X) * (OppGoal.X >= 0.0 ? 1.0 : -1.0) > -1.0;
			// set up for a shot: inside 26 m of the net and squared to it within 15 degrees (a one-timer position: PASSING.md section 2)
			const FVec2 HToGoal = OppGoal - H.Pos;
			const bool bSetUp = HToGoal.Length() < 26.0 && H.Facing.Normalized().Dot(HToGoal.Normalized()) > std::cos(DegToRad(15.0));
			// A set-up human is passed to in every chance (the pass every player makes); the share decides the other open chances.
			// Lane A115 (REVIEW-1 item 6: his after a mate's pass two seconds later in 11 % at pro): only where he has room. No pass onto a marked blade:
			// the nearest standing opponent at least 3 m from him (2 m when he is set up for the one-timer).
			bool bRoom = true;
			if (K.Hk.bPassRoom)
			{
				double Free = 1e9;
				for (int o = 0; o < W.NumSkaters; ++o)
				{
					if (W.Skaters[o].Team == S.Team || W.Skaters[o].bDown) { continue; }
					const double Df = W.Skaters[o].Pos.DistTo(H.Pos);
					if (Df < Free) { Free = Df; }
				}
				bRoom = Free > (bSetUp ? 2.0 : 3.0);
			}
			if (bRoom && (bSetUp || (Coin < Share && bAheadOrLevel && !bDrive && !bDrive9)) && Dh > 5.0 && Dh < 25.0 && !H.bDown)   // lane A153: a mate that goes to the net passes only to a human set up for the one-timer
			{
				bool bClear = true;
				for (int o = 0; o < W.NumSkaters && bClear; ++o)
				{
					if (W.Skaters[o].Team == S.Team) { continue; }
					const FVec2 Rel = W.Skaters[o].Pos - Pp;
					const double Along = Rel.Dot(To) / Dh;
					bClear = !(Along > 0.0 && Along < Dh && std::fabs(Rel.Cross(To) / Dh) < 2.0);
				}
				if (bClear)
				{
					if (W.CarrierBestPass == W.PlayerIndex) { bPass = true; }
					else if (Dh > 8.0 && Fwd.Dot(To * (1.0 / Dh)) > std::cos(DegToRad(15.0))) { bShoot = true; }
				}
			}
		}
		// R-0007 pass intent: the carrier turns to face the human (lead 1.5 x velocity) so the pass above can fire
		if (bPassIntent && W.PlayerIndex >= 0 && W.Skaters[W.PlayerIndex].Team == S.Team && D < W.CarrierReach() + 0.5)   // R-0042 (lane A85)
		{
			const FJamAISkater& H = W.Skaters[W.PlayerIndex];
			const FVec2 Lead = H.Pos + H.Vel * 1.5;
			if (Lead.DistTo(Pp) < 25.0) { return (Lead - Me).Normalized(); }
		}
		// lane A2: chip a puck off the boards (dribbling cannot: no skater fits between the board and the puck)
		FVec2 Bn;
		if (bBoardPeel && S.bCanShoot && BoardSdf(W, Pp, Bn) > -1.0 && Fwd.Dot(-Bn) > 0.6 && Fwd.X * (OppGoal.X >= 0.0 ? 1.0 : -1.0) > (K.Hk.bChipUp9 ? 0.5 : -0.2))   // lane A206: up the ice only
		{
			bShoot = true;
		}
		// Approach direction: towards the goal, or off the boards when the puck lies on them (lane A2 addition: the
		// Godot brain only aimed at the goal, which on an end board puts the approach point outside the rink).
		FVec2 Push = Aim;
		if (bSharp && W.CarrierOrHolder() == Id)
		{
			// the slot: 9 m out from the goal line on the net's axis
			const FVec2 Slot = OppGoal - FVec2(Sign(OppGoal.X) * 9.0, 0.0);
			if (Slot.DistTo(Pp) > 1.0) { Push = (Slot - Pp).Normalized(); }
		}
		// Lane A94 (R-0045 law 2): carry or pass. The carrier reads the lane ahead (ReadSpace on its way to the net) and its teammates. It passes (the sim's
		// BestPass picks the receiver) when the first opponent on the lane arrives inside PressureSec, when two opponents stand on the lane inside 12 m (a set
		// defence: charging it is the wrong decision), or, after MinCarryFrames, when a teammate is open and better placed; a shot decided above comes first.
		// With no pass on, a wall or a lane closed inside 4 m turns the carry 55 degrees to the side away from the first opponent (never into the boards).
		const bool bDriveNet = K.Hk.DriveNet9M > 0.0 && !bShoot && !bPass && !bSharp && DriveNet(W, Id, Aim, Dgoal);   // lane A206 (evolution 9): it goes at the net
		if (K.Hk.bCarryOrPass && W.CarrierOrHolder() == Id && !bShoot && !bPass && !bDeke && S.DekeFrames <= 0 && !bDriveNet)
		{
			const bool bVsHuman = W.PlayerIndex >= 0 && W.PlayerIndex < W.NumSkaters && W.Skaters[W.PlayerIndex].Team != S.Team;
			const FJamSpaceRead R = ReadSpace(W, Id, Aim, K.Hk.BetterByM, (bVsHuman && !K.Hk.bReadHumanPressure) ? W.PlayerIndex : -1);
			const bool bPressure = R.ArriveSec < (K.Hk.Pressure9S > 0.0 ? K.Hk.Pressure9S : K.Hk.PressureSec) || (R.FirstOpp >= 0 && R.FirstOppDist < 5.0);   // pressure, or the lane closes (lane A206: Pressure9S)
			const bool bWall = R.OnLane >= 2 && R.FirstOppDist < 12.0;
			const bool bBetter = R.NumBetter > 0 && CarryFrames[Id] >= K.Hk.MinCarryFrames && !bDrive;   // lane A153: a mate that goes to the net does not look for a better-placed one
			const int BestTo = W.Carrier == Id ? W.CarrierBestPass : W.HolderBestPass;
			const bool bMateOpen = R.NumOpen > 0 && (BestTo >= 0 || (W.Carrier == Id && W.CarrierBestSaucer >= 0));
			// the human's teammates give it to the open human first (PASSING.md: the sim's pass when the sim would pick the human, else an aimed tap from 8 m)
			const int Hi = W.PlayerIndex;
			const bool bHumanOpen = Hi >= 0 && Hi < W.NumSkaters && W.Skaters[Hi].Team == S.Team && R.bOpen[Hi];
			// Lane A115: the human open and ahead of the play (2 m up the ice from the puck, or better placed) gets a small preference: when the pass of the
			// sim would go to another teammate, the carrier turns to him and gives it by the aimed tap, unless pressure makes it pass at once.
			const bool bHumanAhead = K.Hk.bPassRoom && bHumanOpen && !bDrive
				&& ((W.Skaters[Hi].Pos.X - Pp.X) * (OppGoal.X >= 0.0 ? 1.0 : -1.0) > 2.0 || R.bBetter[Hi]);
			bool bTurnToHuman = false;
			if ((bPressure || bWall || bBetter || (bHumanOpen && !bDrive && CarryFrames[Id] >= K.Hk.MinCarryFrames)) && bHumanOpen && S.bCanShoot)
			{
				const FVec2 To = W.Skaters[Hi].Pos - Pp;
				if (BestTo == Hi) { bPass = true; }
				else if (To.Length() > 8.0 && Fwd.Dot(To.Normalized()) > std::cos(DegToRad(15.0))) { bShoot = true; }
				else if (bPressure || bWall) { bPass = true; }
				else if (bHumanAhead && To.Length() > 8.0) { bTurnToHuman = true; }
			}
			else if (bHumanAhead && !bPressure && !bWall && BestTo != Hi && W.Skaters[Hi].Pos.DistTo(Pp) > 8.0 && CarryFrames[Id] >= K.Hk.MinCarryFrames)
			{
				bTurnToHuman = true;   // not in a shooting position yet: line up on him
			}
			else if ((bPressure || bWall || bBetter) && bMateOpen && S.bCanShoot)
			{
				bPass = true;
			}
			else if ((bWall || (R.FirstOpp >= 0 && R.FirstOppDist < 4.0)) && R.FirstOpp >= 0)
			{
				// Lane A115 (VISION law 3: stop, cut, go): a carrier that runs at more than 5 m/s into a defender standing inside 4 m on its lane, with no
				// pass on, stops first (Think holds the brake until it is slow), then cuts: the cut starts from a standstill, where the first-step burst is.
				if (K.Hk.bBrakeMeant && K.Hk.bStopCut && R.FirstOppDist < 4.0 && S.Vel.Dot(Aim) > 5.0) { bWantStop[Id] = true; }
				const double Side = (W.Skaters[R.FirstOpp].Pos - Pp).Cross(Aim) > 0.0 ? 1.0 : -1.0;   // > 0: the opponent is to the right of the way
				FVec2 Cut = Rotate(Aim, DegToRad(55.0) * Side);
				FVec2 N;
				if (BoardSdf(W, Pp + Cut * 4.0, N) > -2.0) { Cut = Rotate(Aim, -DegToRad(55.0) * Side); }
				Push = Cut;
			}
			if (bTurnToHuman && !bShoot && !bPass)
			{
				const FJamAISkater& Hm = W.Skaters[Hi];
				return ((Hm.Pos + Hm.Vel * 0.4) - Me).Normalized();
			}
		}
		// Lane A153 (evolution 4): the carry clock of a team without shape jobs (JamAICore.h): after CarryClockS with the puck the carrier moves it or
		// shoots it at the net; until it faces up the ice it carries on towards the net (Push is the aim).
		if (K.Hk.CarryClockS > 0.0 && W.CarrierOrHolder() == Id && !bShoot && !bPass && !bDeke && S.DekeFrames <= 0 && S.bCanShoot
			&& CarryFrames[Id] > static_cast<int>(K.Hk.CarryClockS * 60.0) && TeamSize(W, S.Team) < 5)
		{
			const int ClockTo = W.Carrier == Id ? W.CarrierBestPass : W.HolderBestPass;
			if (ClockTo >= 0) { bPass = true; }
			else if (Fwd.Dot(Dirg) > 0.5 && !S.bNoShoot) { bShoot = true; }
		}
		// R-0019: the carrier takes the puck round any slow-ice circle whose edge comes within 3 m of its straight line to the net
		if (W.Carrier == Id)
		{
			for (int z = 0; z < W.NumSlowIce; ++z)
			{
				const FVec2 Rel = W.SlowIceCentre[z] - Pp;
				const double Along = Rel.Dot(Dirg);
				if (Along <= 0.0 || Along > Dgoal) { continue; }
				const double Side = Rel.Cross(Dirg);   // > 0: the centre lies to one side of the line
				const double R = W.SlowIceRadius[z];
				if (std::fabs(Side) - R < 3.0)
				{
					const FVec2 Off = Dirg.Perp() * (Side > 0.0 ? 1.0 : -1.0);   // towards the far side from the centre
					const FVec2 Round = W.SlowIceCentre[z] + Off * (R + 3.5);
					Push = (Round - Pp).Normalized();
					break;
				}
			}
		}
		if (bBoardPeel)
		{
			BoardPeel(W, Pp, OppGoal.X >= 0.0 ? 1.0 : -1.0, Push);
		}
		// HOOK (lane A115 for track F2's body shield): the opposing carrier's body is between this bot's stick and the puck: go round it, to the point beside
		// the carrier (2 m off, on this bot's nearer side) and half a metre ahead of it, where the puck is in the open again. Dead until W.bBodyShield is filled.
		{
			const int Cs = W.CarrierOrHolder();
			// Lane A134 (evolution 3): the pincer of a team without shape jobs. The human is on an opposing carrier: his mate comes from the other side,
			// so the carrier's body cannot be between the puck and both sticks (the back keeps its own way: it meets the carrier from the front).
			if (K.Hk.PincerM > 0.0 && Job[Id] == EJob::None && S.Role != ERole::Back && Cs >= 0 && Cs < W.NumSkaters && W.Skaters[Cs].Team != S.Team && !W.Skaters[Cs].bDown
				&& W.PlayerIndex >= 0 && W.PlayerIndex != Id && W.Skaters[W.PlayerIndex].Team == S.Team && !W.Skaters[W.PlayerIndex].bDown && TeamSize(W, S.Team) < 5)
			{
				const FJamAISkater& Cp = W.Skaters[Cs];
				const FVec2 Hp = W.Skaters[W.PlayerIndex].Pos;
				const double Dh = Hp.DistTo(Cp.Pos);
				if (Dh < K.Hk.PincerM && Dh > 1e-6)
				{
					const FVec2 Far = Cp.Pos + (Cp.Pos - Hp) * (1.4 / Dh) + Cp.Vel * 0.3;
					if (Me.DistTo(Far) > 0.5) { return (Far - Me).Normalized(); }
				}
			}
			if (K.Hk.bReadShield && Cs >= 0 && Cs < W.NumSkaters && W.Skaters[Cs].Team != S.Team && BodyShields(W, Id, Cs)
				&& (K.Hk.RoundMaxMps <= 0.0 || W.Skaters[Cs].Vel.Length() < K.Hk.RoundMaxMps))   // lane A138: a carrier that goes is chased, not shadowed
			{
				const FJamAISkater& Cr = W.Skaters[Cs];
				const FVec2 Cf = Cr.Facing.Normalized();
				const double SideR = (Me - Cr.Pos).Cross(Cf) >= 0.0 ? -1.0 : 1.0;
				const FVec2 Round = Cr.Pos + Cf.Perp() * (SideR * 2.0) + Cf * 0.5 + Cr.Vel * K.Hk.RoundLeadS;
				return (Round - Me).Normalized();
			}
			// HOOK (lane A115 for track F2's take grace, lane A121): the opposing carrier has just won the puck and no stick can take it for the frames
			// left. The decision: close and contain. The bot goes to the point 1.8 m goal-side of the carrier (between it and our net, at stick length),
			// so that the poke or the lift is there the frame the grace ends; the body check (StickPlay) is not refused and goes when its speeds are met.
			// Dead until FJamAISkater::TakeGraceFrames is filled.
			if (K.Hk.bReadShield && Cs >= 0 && Cs < W.NumSkaters && W.Skaters[Cs].Team != S.Team && W.Skaters[Cs].TakeGraceFrames > 0)
			{
				const FJamAISkater& Cg = W.Skaters[Cs];
				const FVec2 Contain = Cg.Pos + (W.OwnGoal(S.Team) - Cg.Pos).Normalized() * 1.8 + Cg.Vel * 0.3;
				return (Contain - Me).Normalized();
			}
			// Lane A134 (evolution 3): the backcheck of a team without shape jobs. Behind an opposing carrier that goes, the stick is refused (the body
			// shields the puck) and a chase at the carrier's own speed never ends: the bot skates for the carrier's lane to our net instead, and meets it
			// from the front once it is goal-side. Within 2.5 m of the carrier it plays the puck and the body as before.
			if (K.Hk.BackcheckMps > 0.0 && Job[Id] == EJob::None && Cs >= 0 && Cs < W.NumSkaters && W.Skaters[Cs].Team != S.Team && !W.Skaters[Cs].bDown
				&& W.Skaters[Cs].Vel.Length() > K.Hk.BackcheckMps && TeamSize(W, S.Team) < 5)
			{
				const FJamAISkater& Cb = W.Skaters[Cs];
				const FVec2 Ug = (W.OwnGoal(S.Team) - Cb.Pos).Normalized();
				if ((Me - Cb.Pos).Dot(Ug) <= 0.0 && Me.DistTo(Cb.Pos) > 2.5)
				{
					return (BackcheckPoint(W, Id, Cs, FreeSpeed(K.Hk) * Params.SpeedScale) - Me).Normalized();   // lane A193: the backchecker is free; the carrier at its measured speed
				}
			}
		}
		const FVec2 ToPuck = Pp - Me;
		const double Lateral = ToPuck.X * Push.Y - ToPuck.Y * Push.X;
		if (ToPuck.Dot(Push) > 0.0 && std::fabs(Lateral) < 1.3)
		{
			return (Pp + Push * 3.0 - Me).Normalized();
		}
		const double LeadMps = K.Hk.bTrueLead ? FreeSpeed(K.Hk) * Params.SpeedScale : 8.0;   // lane A202 (item 4): off = Godot's 8 m/s
		double Lead = Clamp(D / LeadMps, 0.0, K.LeadFrames / 60.0);
		// Lane A206 (evolution 9, wave 2): a team-mate's pass in flight is met where it will be (the intercept solve, up to 2 s ahead), not chased where it is
		// (wave 2 on A207's pass: the sim's own pass in flight, Puck.PassFrames / PassBy through the adapter)
		const bool bMeetPass = K.Hk.bMeetPass9 && W.CarrierOrHolder() < 0 && W.PuckPassFrames > 0 && W.PuckPassBy >= 0 && W.PuckPassBy < W.NumSkaters && W.PuckPassBy != Id
			&& W.Skaters[W.PuckPassBy].Team == S.Team;
		if (K.bIntercept || bMeetPass)
		{
			// lane A3: earliest t with |Pp + V t - Me| = speed * t (speed = own top speed), capped like the plain lead
			const FVec2 R = Pp - Me;
			const FVec2 V = W.PuckVel.LimitLength(25.0);
			const double Sp = FreeSpeed(K.Hk) * Params.SpeedScale;   // lane A193: the chaser is free
			const double A = V.Dot(V) - Sp * Sp, B = 2.0 * R.Dot(V), C = R.Dot(R);
			double T = -1.0;
			if (std::fabs(A) < 1e-9)
			{
				T = std::fabs(B) > 1e-9 ? -C / B : -1.0;
			}
			else
			{
				const double Disc = B * B - 4.0 * A * C;
				if (Disc >= 0.0)
				{
					const double Sq = std::sqrt(Disc);
					const double T1 = (-B - Sq) / (2.0 * A), T2 = (-B + Sq) / (2.0 * A);
					const double Lo = T1 < T2 ? T1 : T2, Hi = T1 < T2 ? T2 : T1;
					T = Lo > 0.0 ? Lo : Hi;
				}
			}
			Lead = Clamp(T > 0.0 ? T : D / LeadMps, 0.0, bMeetPass && !K.bIntercept ? 2.0 : K.LeadFrames / 60.0);   // lane A206: the met pass up to 2 s
		}
		const FVec2 Tgt = Pp + W.PuckVel.LimitLength(25.0) * Lead;
		FVec2 Behind = Tgt - Push * 1.2;
		// slow deterministic sway of the approach line so two pursuers do not lock the puck in a corner
		if (!bDriveNet) { Behind += Push.Perp() * std::sin(static_cast<double>(W.Frame) * 0.015 + static_cast<double>(Id % 7)) * Params.SwayM; }   // lane A206: a drive at the net goes straight
		FVec2 Want = Behind - Me;
		if (ToPuck.Dot(Push) < 0.0 && D < 4.0)
		{
			FVec2 Side = Push.Perp() * (Lateral <= 0.0 ? 1.0 : -1.0);
			FVec2 SideN;
			if (bBoardPeel && BoardSdf(W, Behind + Side * 2.5, SideN) > -1.0)
			{
				Side = -Side;   // lane A2: swing round on the ice side, never through the boards
			}
			Want = Behind + Side * 2.5 - Me;
		}
		// Lane A206 (evolution 9): a drive inside its shot's range plus 4 m slows to keep the puck on its blade and square up to the net (at full pace the
		// dribble ran 2 to 3 m ahead of the stick and the facing swung 30 to 130 degrees off the net: no shot in range)
		if (bDriveNet && Dgoal < W.ShotReach + (K.Hk.ShootExtra9M > 0.0 ? K.Hk.ShootExtra9M : K.ShootExtraM) + 4.0) { return Want.Normalized() * 0.55; }
		return Want.Normalized();
	}

	// Lane A94 (R-0045 law 2): the space read (JamAICore.h). Pure.
	FJamSpaceRead ReadSpace(const FJamAIWorld& W, int Carrier, const FVec2& Ahead, double BetterByM, int IgnoreOpp)
	{
		FJamSpaceRead R;
		if (Carrier < 0 || Carrier >= W.NumSkaters) { return R; }
		const FJamAISkater& S = W.Skaters[Carrier];
		const FVec2 Cp = S.Pos;
		const FVec2 U = Ahead.Normalized();
		const FVec2 Goal = W.OppGoal(S.Team);
		const double MyGoalD = W.PuckPos.DistTo(Goal);
		for (int o = 0; o < W.NumSkaters; ++o)
		{
			const FJamAISkater& O = W.Skaters[o];
			if (O.Team == S.Team || O.bDown || o == IgnoreOpp) { continue; }
			const FVec2 Rel = O.Pos - Cp;
			const double Dist = Rel.Length();
			if (Dist < 2.2) { R.ArriveSec = 0.0; }
			const double Along = Rel.Dot(U);
			if (Along > 0.0 && Along <= 15.0 && std::fabs(Rel.Cross(U)) < 2.5 + Along * 0.2)
			{
				++R.OnLane;
				if (Dist < R.FirstOppDist) { R.FirstOppDist = Dist; R.FirstOpp = o; }
				const double Closing = Dist > 1e-6 ? (S.Vel - O.Vel).Dot(Rel * (1.0 / Dist)) : 0.0;
				const double T = (Dist > 1.0 ? Dist - 1.0 : 0.0) / (Closing > 1.5 ? Closing : 1.5);
				if (T < R.ArriveSec) { R.ArriveSec = T; }
			}
		}
		for (int t = 0; t < W.NumSkaters; ++t)
		{
			const FJamAISkater& M = W.Skaters[t];
			if (t == Carrier || M.Team != S.Team || M.bDown) { continue; }
			double Free = 1e9;
			const FVec2 L = M.Pos - Cp;
			const double Ld = L.Length();
			bool bLane = Ld > 1e-6;
			const FVec2 Lu = bLane ? L * (1.0 / Ld) : FVec2();
			for (int o = 0; o < W.NumSkaters; ++o)
			{
				const FJamAISkater& O = W.Skaters[o];
				if (O.Team == S.Team || O.bDown) { continue; }
				const double Df = O.Pos.DistTo(M.Pos);
				if (Df < Free) { Free = Df; }
				if (bLane)
				{
					const FVec2 Rel = O.Pos - Cp;
					const double Along = Rel.Dot(Lu);
					if (Along > 0.5 && Along < Ld && std::fabs(Rel.Cross(Lu)) < 1.5) { bLane = false; }   // a body or a blade on the line
				}
			}
			R.MateFree[t] = Free;
			R.bLaneOpen[t] = bLane;
			R.bOpen[t] = bLane && Free > 3.0 && Ld >= 4.0 && Ld <= 30.0;
			R.bBetter[t] = R.bOpen[t] && M.Pos.DistTo(Goal) < MyGoalD - BetterByM;
			if (R.bOpen[t]) { ++R.NumOpen; }
			if (R.bBetter[t]) { ++R.NumBetter; }
		}
		return R;
	}

	// Lane A115 (evolution 2): the pure reads of JamAICore.h.
	int LoosePuckOwner(const FJamAIWorld& W, int Team, double SkaterSpeed)
	{
		constexpr double Drag = 0.5, ReachM = 1.0, TurnSec = 0.2, OwnPassLateSec = 1.0, OwnPassSpeed = 6.0;
		const double Sp = SkaterSpeed > 1.0 ? SkaterSpeed : 1.0;
		const FVec2 Pp = W.PuckPos;
		const FVec2 Pv = W.PuckVel.LimitLength(30.0);
		int Best = -1;
		double BestT = 1e18, BestD = 1e18;
		for (int i = 0; i < W.NumSkaters; ++i)
		{
			const FJamAISkater& K = W.Skaters[i];
			if (K.Team != Team || K.bDown) { continue; }
			double T = 2.5;   // not inside two seconds
			for (int k = 0; k <= 20; ++k)
			{
				const double t = 0.1 * k;
				FVec2 At = Pp + Pv * ((1.0 - std::exp(-Drag * t)) / Drag);
				At.X = Clamp(At.X, -W.HalfLength + 0.5, W.HalfLength - 0.5);   // the boards stop it (no bounce read)
				At.Y = Clamp(At.Y, -W.HalfWidth + 0.5, W.HalfWidth - 0.5);
				const double Cover = Sp * (t > TurnSec ? t - TurnSec : 0.0) + ReachM;
				if ((K.Pos + K.Vel * (t < TurnSec ? t : TurnSec)).DistTo(At) <= Cover) { T = t; break; }
			}
			const double Dn = K.Pos.DistTo(Pp);
			if (T >= 2.5) { T = 2.5 + Dn / Sp; }   // out of reach inside two seconds: by the distance now
			if (i == W.PuckLastTouch && Pv.Length() > OwnPassSpeed && Pv.Dot(Pp - K.Pos) > 0.0) { T += OwnPassLateSec; }
			if (T < BestT - 1e-9 || (std::fabs(T - BestT) <= 1e-9 && Dn < BestD)) { BestT = T; BestD = Dn; Best = i; }
		}
		return Best;
	}

	double ArriveSec(const FJamAIWorld& W, int i, double Speed)
	{
		constexpr double Drag = 0.5, ReachM = 1.0, TurnMinSec = 0.2, TurnMaxSec = 0.8;
		if (i < 0 || i >= W.NumSkaters) { return 1e9; }
		const double Sp = Speed > 1.0 ? Speed : 1.0;
		const FJamAISkater& K = W.Skaters[i];
		const FVec2 Pp = W.PuckPos;
		const FVec2 Pv = W.PuckVel.LimitLength(30.0);
		const FVec2 Head = K.Vel.Length() > 1.0 ? K.Vel.Normalized() : K.Facing.Normalized();
		for (int k = 0; k <= 20; ++k)
		{
			const double t = 0.1 * k;
			FVec2 At = Pp + Pv * ((1.0 - std::exp(-Drag * t)) / Drag);
			At.X = Clamp(At.X, -W.HalfLength + 0.5, W.HalfLength - 0.5);
			At.Y = Clamp(At.Y, -W.HalfWidth + 0.5, W.HalfWidth - 0.5);
			const FVec2 To = At - K.Pos;
			const double L = To.Length();
			if (L <= ReachM) { return t; }
			const double Turn = TurnMinSec + (TurnMaxSec - TurnMinSec) * 0.5 * (1.0 - Head.Dot(To * (1.0 / L)));
			const double Cover = Sp * (t > Turn ? t - Turn : 0.0) + ReachM;
			if ((K.Pos + K.Vel * (t < Turn ? t : Turn)).DistTo(At) <= Cover) { return t; }
		}
		return 2.5 + K.Pos.DistTo(Pp) / Sp;
	}

	FVec2 SteerRoundDowned(const FJamAIWorld& W, int Id, const FVec2& Move, double KeepM, double OutShare)
	{
		constexpr double LookM = 2.5;
		const double Len = Move.Length();
		if (KeepM <= 0.0 || Len < 1e-6 || Id < 0 || Id >= W.NumSkaters) { return Move; }
		const FVec2 M = Move * (1.0 / Len);
		const FVec2 Me = W.Skaters[Id].Pos;
		int Best = -1;
		double BestD = 1e18;
		for (int d = 0; d < W.NumSkaters; ++d)
		{
			if (d == Id || !W.Skaters[d].bDown) { continue; }
			const FVec2 Rel = W.Skaters[d].Pos - Me;
			const double Dist = Rel.Length();
			if (Dist > KeepM + LookM || Dist >= BestD) { continue; }
			if (Dist > KeepM && (Rel.Dot(M) <= 0.0 || std::fabs(Rel.Cross(M)) >= KeepM)) { continue; }   // behind the move, or the line clears his circle
			Best = d; BestD = Dist;
		}
		if (Best < 0) { return Move; }
		const FVec2 Rel = W.Skaters[Best].Pos - Me;
		if (BestD < 1e-6) { return Move; }
		const FVec2 To = Rel * (1.0 / BestD);
		const double Side = To.Cross(M) >= 0.0 ? 1.0 : -1.0;   // the side of him the move already leans to (counter-clockwise from the line to him: +)
		if (BestD > KeepM)
		{
			// outside his circle: the tangent on that side
			return Rotate(To, Side * std::asin(KeepM / BestD)) * Len;
		}
		// inside it: out and round (mostly out near his body, mostly round near the circle's edge)
		const double In = 1.0 - BestD / KeepM;
		if (OutShare > 0.0) { return (Rotate(To, Side * kPi * 0.5) * (1.0 - OutShare) + To * (-OutShare)).Normalized() * Len; }
		return (Rotate(To, Side * kPi * 0.5) * (1.0 - 0.5 * In) + To * (-(0.4 + In))).Normalized() * Len;
	}

	FVec2 BackcheckPoint(const FJamAIWorld& W, int Id, int Carrier, double Speed)
	{
		const FJamAISkater& S = W.Skaters[Id];
		const FJamAISkater& Cr = W.Skaters[Carrier];
		const FVec2 Goal = W.OwnGoal(S.Team);
		const FVec2 Ln = Goal - Cr.Pos;
		const double Len = Ln.Length();
		if (Len < 6.0) { return Goal + (Cr.Pos - Goal).Normalized() * 1.5; }
		const FVec2 Ug = Ln * (1.0 / Len);
		const double Sp = Speed > 1.0 ? Speed : 1.0;
		const double Cs = Cr.Vel.Length() > 3.0 ? Cr.Vel.Length() : 3.0;
		const double Last = Len - 4.0;
		for (double s = 2.0; s < Last; s += 2.0)
		{
			const FVec2 Pt = Cr.Pos + Ug * s;
			if (S.Pos.DistTo(Pt) / Sp <= s / Cs) { return Pt; }
		}
		return Cr.Pos + Ug * Last;
	}

	FVec2 OfferLane(const FJamAIWorld& W, int Id, int Carrier)
	{
		const FJamAISkater& S = W.Skaters[Id];
		if (Carrier < 0 || Carrier >= W.NumSkaters) { return S.Pos; }
		const FJamAISkater& Cr = W.Skaters[Carrier];
		const double Up = Sign(W.OppGoal(S.Team).X);
		const FVec2 Cp = Cr.Pos + Cr.Vel * 0.5;
		static const double Spots[3][2] = { { 2.0, 10.0 }, { 8.0, 9.0 }, { 13.0, 6.0 } };   // metres up the ice from the carrier, metres to the side
		FVec2 Best = Cp + FVec2(Up * 8.0, S.Pos.Y >= Cp.Y ? 9.0 : -9.0);
		double BestScore = -1e18;
		for (int Side = -1; Side <= 1; Side += 2)
		{
			for (int k = 0; k < 3; ++k)
			{
				FVec2 T = Cp + FVec2(Up * Spots[k][0], Side * Spots[k][1]);
				T.X = Clamp(T.X, -W.GoalX + 4.0, W.GoalX - 4.0);
				T.Y = Clamp(T.Y, -W.HalfWidth + 3.0, W.HalfWidth - 3.0);
				const FVec2 L = T - Cr.Pos;
				const double Ld = L.Length();
				if (Ld < 4.0) { continue; }   // squeezed against the boards onto the carrier: no lane
				const FVec2 Lu = L * (1.0 / Ld);
				double Free = 1e9, Lane = 1e9;
				for (int o = 0; o < W.NumSkaters; ++o)
				{
					const FJamAISkater& O = W.Skaters[o];
					if (O.Team == S.Team || O.bDown) { continue; }
					const double Df = O.Pos.DistTo(T);
					if (Df < Free) { Free = Df; }
					const double Along = Clamp((O.Pos - Cr.Pos).Dot(Lu), 0.0, Ld);
					const double Dl = (Cr.Pos + Lu * Along).DistTo(O.Pos);
					if (Dl < Lane) { Lane = Dl; }
				}
				bool bTaken = false;
				for (int m = 0; m < W.NumSkaters; ++m)
				{
					if (m == Id || m == Carrier || W.Skaters[m].Team != S.Team || W.Skaters[m].bDown) { continue; }
					if (W.Skaters[m].Pos.DistTo(T) < 4.0) { bTaken = true; }
				}
				if (bTaken) { continue; }
				const double Score = (Lane > 2.0 ? 2.0 : 0.0) + (Free < 6.0 ? Free : 6.0) / 6.0 + Spots[k][0] / 20.0 - S.Pos.DistTo(T) / 30.0;
				if (Score > BestScore) { BestScore = Score; Best = T; }
			}
		}
		return Best;
	}

	bool FJamBrain::ScreenPoint(const FJamAIWorld& W, int Id, FVec2& Out) const
	{
		const FJamHockeySense& H = SkillOf(W, Id).Hk;
		const int Hi = W.PlayerIndex;
		if (H.ScreenFrames <= 0 || Hi < 0 || Hi >= W.NumSkaters || W.CarrierOrHolder() != Hi || CarryFrames[Hi] >= H.ScreenFrames || W.Skaters[Hi].Team != W.Skaters[Id].Team) { return false; }
		const FVec2 Hp = W.Skaters[Hi].Pos;
		int Opp = -1;
		double Bd = 8.0;
		for (int o = 0; o < W.NumSkaters; ++o)
		{
			if (W.Skaters[o].Team == W.Skaters[Id].Team || W.Skaters[o].bDown) { continue; }
			const double Dd = W.Skaters[o].Pos.DistTo(Hp);
			if (Dd < Bd) { Bd = Dd; Opp = o; }
		}
		if (Opp < 0 || Bd < 1.5) { return false; }   // nobody near him, or the opponent is on him already: no room to stand between
		const FVec2 Op = W.Skaters[Opp].Pos;
		const double Mine = W.Skaters[Id].Pos.DistTo(Op);
		int Others = 0;
		for (int m = 0; m < W.NumSkaters; ++m)
		{
			if (m == Id || m == Hi || W.Skaters[m].Team != W.Skaters[Id].Team || W.Skaters[m].Role == ERole::Back) { continue; }
			++Others;   // the line-up's other forwards, standing or not: the rule is the team's shape, not the moment's
			if (!W.Skaters[m].bDown && W.Skaters[m].Pos.DistTo(Op) < Mine - 1e-9) { return false; }   // a nearer mate screens; this one offers a lane
		}
		// No other forward in the line-up (three a side: the human, one forward, the back): the only forward offers the lane. Measured on the big ice at pro with
		// the screen played by that forward: 59.8 % of matches with a 30 s stretch without the puck against 56.2 % (BRAIN-4.md section 3).
		if (Others == 0) { return false; }
		Out = Op + W.Skaters[Opp].Vel * 0.2 + (Hp - Op).Normalized() * 1.2;
		return true;
	}

	bool BodyShields(const FJamAIWorld& W, int Poker, int Carrier)
	{
		if (!W.bBodyShield || Poker < 0 || Carrier < 0 || Poker >= W.NumSkaters || Carrier >= W.NumSkaters) { return false; }
		const FJamAISkater& P = W.Skaters[Poker];
		const FJamAISkater& C = W.Skaters[Carrier];
		if (P.Team == C.Team) { return false; }
		const FVec2 Rel = C.Pos - P.Pos;
		const double D = Rel.Length();
		if (D > W.BodyShieldRangeM || D < 1e-6) { return false; }
		if (C.SpinFrames > 0 && C.SpinFrames <= W.SpinExposedFrames) { return false; }   // lane A138: the spin's exposed end (lane A128): the body is no longer between
		const FVec2 N = Rel * (1.0 / D);   // the line defender -> carrier
		const FVec2 ToPuck = W.PuckPos - C.Pos;
		if (ToPuck.Dot(N) < std::cos(DegToRad(W.BodyShieldFarDeg)) * ToPuck.Length()) { return false; }   // the puck is not behind the body, seen from the defender
		return C.Facing.Normalized().Dot(N) > -std::cos(DegToRad(W.BodyShieldFrontDeg));                    // the defender is not in front of the carrier
	}

	bool StickCannotTake(const FJamAIWorld& W, int Poker, int Carrier)
	{
		if (Carrier < 0 || Carrier >= W.NumSkaters) { return false; }
		return W.Skaters[Carrier].TakeGraceFrames > 0 || BodyShields(W, Poker, Carrier);
	}

	// Lane A94: the team in possession: the carrier's, else the last toucher's (a loose puck belongs to the team that touched it last); none while frozen,
	// in the faceoff countdown, or before the first touch. Since = the frame it changed. One entry per frame in the ring (the late read).
	void FJamBrain::ReadPossession(const FJamAIWorld& W)
	{
		if (W.Frame == PossFrame) { return; }
		int Team = -1;
		if (!W.bFrozen && !W.bFaceoffPhase)
		{
			const int Ch = W.CarrierOrHolder();
			if (Ch >= 0 && Ch < W.NumSkaters) { Team = W.Skaters[Ch].Team; }
			else if (W.PuckLastTouch >= 0 && W.PuckLastTouch < W.NumSkaters) { Team = W.Skaters[W.PuckLastTouch].Team; }
		}
		if (Team != PossNow.Team) { PossNow.Team = Team; PossNow.Since = W.Frame; }
		if (PossFrame >= 0 && W.Frame != PossFrame + 1)
		{
			for (int k = 0; k < kPhaseHist; ++k) { PossHist[k] = PossNow; }   // a jump: the history starts over
		}
		PossHist[static_cast<int>(((W.Frame % kPhaseHist) + kPhaseHist) % kPhaseHist)] = PossNow;
		PossFrame = W.Frame;
	}

	FJamBrain::FPoss FJamBrain::PossAt(const FJamAIWorld& W, int Late) const
	{
		if (Late <= 0) { return PossNow; }
		if (Late >= kPhaseHist) { Late = kPhaseHist - 1; }
		const int64_t F = W.Frame - Late;
		if (F < 0) { return FPoss(); }
		return PossHist[static_cast<int>(F % kPhaseHist)];
	}

	// Lane A94: the shape jobs of each team of five or more whose bots have the sense on. Attack (we have it): the carrier, or the nearest skater to a loose
	// puck, has the puck; the other forwards by distance to it: the close support, then the far side / net front; the backs hold the points. Defence:
	// one forward presses (the nearest goal-side one; in the transition the nearest at all), the next covers the carrier's nearest pass, the rest take the
	// far side; the backs keep their posts (guard, slot, crease). The human takes a place in the order like any forward and is given nothing. A bot whose
	// coin (ShapeShare, per two-second window) misses plays its old role.
	void FJamBrain::AssignJobs(const FJamAIWorld& W)
	{
		for (int i = 0; i < kMaxSkaters; ++i) { Job[i] = EJob::None; JobOrd[i] = 0; JobLoose[i] = false; }
		Owner[0] = Owner[1] = -1;
		for (int Team = 0; Team < 2; ++Team)
		{
			int Bot = -1, N = 0;
			for (int i = 0; i < W.NumSkaters; ++i)
			{
				if (W.Skaters[i].Team != Team) { continue; }
				++N;
				if (Bot < 0 && !W.IsHumanSeat(i)) { Bot = i; }
			}
			if (Bot < 0 || N < 5) { continue; }
			const FJamHockeySense& H = SkillOf(W, Bot).Hk;
			if (!(H.bAttackShape || H.bDefenceShape)) { continue; }
			const FPoss P = PossAt(W, H.LateFrames);
			if (P.Team < 0) { continue; }
			const bool bAttack = P.Team == Team;
			if ((bAttack && !H.bAttackShape) || (!bAttack && !H.bDefenceShape)) { continue; }
			const bool bTrans = H.bTransition && (W.Frame - P.Since) < H.TransitionFrames;
			const int C = W.CarrierOrHolder();
			const bool bOurs = C >= 0 && C < W.NumSkaters && W.Skaters[C].Team == Team;
			const bool bTheirs = C >= 0 && C < W.NumSkaters && W.Skaters[C].Team != Team;
			const FVec2 Pp = W.PuckPos;
			const FVec2 Cp = (C >= 0 && C < W.NumSkaters) ? W.Skaters[C].Pos : Pp;
			const FVec2 OwnGoal = W.OwnGoal(Team);
			// forwards (the human included), standing
			int Fw[kMaxSkaters], NF = 0;
			for (int i = 0; i < W.NumSkaters; ++i)
			{
				const FJamAISkater& S = W.Skaters[i];
				if (S.Team != Team || S.bDown) { continue; }
				if (S.Role != ERole::Back) { Fw[NF++] = i; }
			}
			auto Take = [&](int k) { const int v = Fw[k]; for (int j = k; j + 1 < NF; ++j) { Fw[j] = Fw[j + 1]; } --NF; return v; };
			auto Nearest = [&](const FVec2& To, bool bGoalSide) {
				int Best = -1; double Bd = 1e18;
				for (int k = 0; k < NF; ++k)
				{
					const FVec2 M = W.Skaters[Fw[k]].Pos;
					if (bGoalSide && (M - To).Dot(OwnGoal - To) <= 0.0 && M.DistTo(To) > 4.0) { continue; }
					const double D = M.DistTo(To);
					if (D < Bd) { Bd = D; Best = k; }
				}
				return Best;
			};
			int Count[8] = {};
			auto Give = [&](int i, EJob J) { const int c = Count[static_cast<int>(J)]++; if (!W.IsHumanSeat(i)) { Job[i] = J; JobOrd[i] = c; } };
			if (bAttack)
			{
				int& Own = Owner[Team];
				Own = bOurs ? C : -1;
				if (Own < 0)
				{
					// a loose puck (a pass on its way, a rebound): the skater nearest it goes (measured: the skater nearest where it will be in 0.4 s, with the
					// shape formed round that skater, beat the human to loose pucks: its touches 23.8 -> 22.0 a minute, the pile 11.9 -> 12.6 %; BRAIN.md)
					// Lane A115 (REVIEW-CODE.md, severity 3): with bChaseAhead the owner is the skater that reaches where the puck will be first, and a passer is
					// not the owner of its own pass (on a 15 m pass it was, for half the flight: it chased its own pass).
					if (H.bChaseAhead) { Own = LoosePuckOwner(W, Team, FreeSpeed(H) * Params.SpeedScale); }   // lane A193
					else
					{
						double Bd = 1e18;
						for (int i = 0; i < W.NumSkaters; ++i)
						{
							if (W.Skaters[i].Team != Team || W.Skaters[i].bDown) { continue; }
							const double D = W.Skaters[i].Pos.DistTo(Pp);
							if (D < Bd) { Bd = D; Own = i; }
						}
					}
				}
				if (Own >= 0) { Give(Own, EJob::Puck); }
				for (int k = 0; k < NF; ++k) { if (Fw[k] == Own) { Take(k); break; } }
				const int Ks = Nearest(Cp, false);
				if (Ks >= 0) { Give(Take(Ks), EJob::Support); }
				while (NF > 0) { Give(Take(0), EJob::Far); }
				for (int i = 0; i < W.NumSkaters; ++i)
				{
					if (W.Skaters[i].Team == Team && !W.Skaters[i].bDown && W.Skaters[i].Role == ERole::Back && i != Own) { Give(i, EJob::Point); }
				}
			}
			else
			{
				int Kp = bTrans ? Nearest(Cp, false) : Nearest(Cp, true);
				if (Kp < 0) { Kp = Nearest(Cp, false); }
				// Lane A181 (evolution 6): the first presser of an opposing skater's carry is remembered; a later one is a second man (bSecondManHunts)
				for (int i = 0; i < W.NumSkaters; ++i) { if (W.Skaters[i].Team == Team) { bSecondMan[i] = false; } }
				if (!bTheirs) { PressCarrier[Team] = -1; PressFirst[Team] = -1; }
				else if (Kp >= 0)
				{
					if (PressCarrier[Team] != C) { PressCarrier[Team] = C; PressFirst[Team] = Fw[Kp]; }
					bSecondMan[Fw[Kp]] = Fw[Kp] != PressFirst[Team];
				}
				// Lane A206 wave 3 (bDefendTeam9): the human is not his side's presser unless he is on the carrier (goal-side within 6 m): the nearest bot goes
				if (H.bDefendTeam9 && Kp >= 0 && W.IsHumanSeat(Fw[Kp]) && bTheirs
					&& !(W.Skaters[Fw[Kp]].Pos.DistTo(Cp) < 6.0 && (W.Skaters[Fw[Kp]].Pos - Cp).Dot(OwnGoal - Cp) > 0.0))
				{
					int Bk = -1; double Bd = 1e18;
					for (int k = 0; k < NF; ++k)
					{
						if (W.IsHumanSeat(Fw[k])) { continue; }
						const double D = W.Skaters[Fw[k]].Pos.DistTo(Cp) + ((W.Skaters[Fw[k]].Pos - Cp).Dot(OwnGoal - Cp) > 0.0 ? 0.0 : 6.0);
						if (D < Bd) { Bd = D; Bk = k; }
					}
					if (Bk >= 0) { Kp = Bk; }
				}
				if (Kp >= 0) { Give(Take(Kp), EJob::Press); }
				if (bTheirs && NF > 0)
				{
					const int M = FiveLocal::CoverMate(W, C, H.bCoverBestPass);
					const int Kc = M >= 0 ? Nearest(LerpV(Cp, W.Skaters[M].Pos, 0.4), false) : -1;
					if (Kc >= 0) { Give(Take(Kc), EJob::Cover); }
				}
				while (NF > 0) { Give(Take(0), EJob::Weak); }
			}
			// executed loosely: a bot whose coin misses this window plays its old role (the puck's owner always goes)
			if (H.ShapeShare < 1.0)
			{
				for (int i = 0; i < W.NumSkaters; ++i)
				{
					if (W.Skaters[i].Team != Team || Job[i] == EJob::None || Job[i] == EJob::Puck) { continue; }
					const double Coin = (Hash11(static_cast<uint64_t>(i) + 503, static_cast<uint64_t>(W.Frame / 120)) + 1.0) * 0.5;
					if (Coin >= H.ShapeShare) { JobLoose[i] = true; }
				}
			}
		}
	}

	// Lane A94: where a bot with a shape job goes (JamAICore.h, AssignJobs). bToPuck = play the puck (Attack: the chase, the stick, the shot).
	bool FJamBrain::JobSteer(const FJamAIWorld& W, int Id, FVec2& Out, bool& bToPuck) const
	{
		const FJamAISkater& S = W.Skaters[Id];
		const FVec2 Me = S.Pos;
		const FVec2 Pp = W.PuckPos;
		const FVec2 OwnGoal = W.OwnGoal(S.Team);
		const FVec2 OppGoal = W.OppGoal(S.Team);
		const double Up = Sign(OppGoal.X);
		const int C = W.CarrierOrHolder();
		const bool bCarrier = C >= 0 && C < W.NumSkaters;
		const FVec2 Cp = bCarrier ? W.Skaters[C].Pos : Pp;
		const FVec2 Vc = bCarrier ? W.Skaters[C].Vel : W.PuckVel * 0.3;
		const double PuckSide = std::fabs(Cp.Y) > 2.0 ? Sign(Cp.Y) : (Me.Y >= Cp.Y ? -1.0 : 1.0);   // the far side is -PuckSide
		FVec2 T;
		bool bLanes = false;
		switch (Job[Id])
		{
		case EJob::Puck:
			bToPuck = true;
			return true;
		case EJob::Support:
		{
			// the outlet: 4 m behind and 6 m beside the carrier (7 m off, kept at 7 below), on the middle's side, moving with it
			const double Side = std::fabs(Cp.Y) > 3.0 ? -Sign(Cp.Y) : (Me.Y >= Cp.Y ? 1.0 : -1.0);
			T = Cp + FVec2(-Up * 4.0, Side * 6.0) + Vc * 0.4;
			if (SkillOf(W, Id).Hk.bNetFront9 && bCarrier && W.Skaters[C].Team == S.Team) { T = Cp + FVec2(Up * 1.0, Side * 6.0) + Vc * 0.4; }   // lane A206 (evolution 9): level with him, not behind
			// Lane A115: the human carries: his close support stands where his pass lane is open (beside or ahead), not at a fixed spot behind him
			if (SkillOf(W, Id).Hk.bSupportHuman && bCarrier && C == W.PlayerIndex)
			{
				FVec2 Sc;
				if (ScreenPoint(W, Id, Sc)) { Out = Arrive(Me, Sc, 1.0); return true; }   // lane A153: the screen is played on its spot (no 7 m of room from the puck)
				T = OfferLane(W, Id, C);
			}
			bLanes = true;
			break;
		}
		case EJob::Far:
			if (JobOrd[Id] > 0 && SkillOf(W, Id).Hk.bAheadWeak9) { T = FVec2(Cp.X + Up * 7.0, -PuckSide * W.HalfWidth * 0.45); }   // lane A206 (wave 2): a second ahead on the weak side
			else if (JobOrd[Id] > 0) { T = FVec2(Cp.X - Up * 2.0, PuckSide * W.HalfWidth * 0.75); }                 // a second: the puck's side, wide on the boards
			else if (Cp.X * Up > (SkillOf(W, Id).Hk.bNetFront9 ? 0.0 : W.HalfLength / 3.0 - 2.0)) { T = FVec2(OppGoal.X - Up * 5.0, -PuckSide * 2.5); }   // in their end: the net front, the far post   // lane A206 (evolution 9): from the attacking half
			else { T = FVec2(Cp.X + Up * 10.0, -PuckSide * W.HalfWidth * 0.4); }                              // else the far lane, ahead of the puck
			bLanes = true;
			break;
		case EJob::Point:
		{
			// the backs trail the puck by 7 m, at most to their blue line, at least 8 m out of their own net; one on each side
			const double A = Clamp(Cp.X * Up - 7.0, -W.GoalX + 8.0, W.HalfLength / 3.0 - 1.5);
			const double Side = FiveLocal::RoleOrdinal(W, Id) == 0 ? -1.0 : 1.0;
			T = FVec2(A * Up, Side * W.HalfWidth * 0.3);
			bLanes = true;
			break;
		}
		case EJob::Press:
		{
			// goal-side, gap control: in front of a fast carrier at its speed's gap (a third of a second, 1-3 m), taking the middle away (steers it to the
			// boards); a slow carrier, a loose puck, or a presser not goal-side plays the puck
			const FVec2 Ug = (OwnGoal - Cp).Normalized();
			const double Spd = Vc.Length();
			const bool bGoalSide = (Me - Cp).Dot(Ug) > 0.0;
			// Lane A115 (lane A102's report: the "gap control" of the pro arrived head-on at 11 m/s, and a stop-and-go beat it 200 times of 200): closing under
			// control, within what the sim can do (a body faces its move: nobody skates backwards, so "back off at the carrier's speed" would turn the
			// presser's back to the puck and its lift cone away). Goal-side of a carrier that comes at it faster than 3 m/s, between 3.5 and 12 m off, the
			// presser stops (a decided stop: Think holds the brake) and waits on the line carrier -> net, facing the carrier, creeping: standing it is braced
			// (law 1) and its momentum is not committed, so a stop or a cut finds it still there. Inside 3.5 m it steps up and plays the puck and the body as
			// before; a slow carrier, a carrier going away, a presser not goal-side: as before.
			if (SkillOf(W, Id).Hk.bGapControl && bCarrier && bGoalSide)
			{
				const FVec2 Rel = Me - Cp;
				const double Dist = Rel.Length();
				const double Coming = Dist > 1e-6 ? Vc.Dot(Rel) / Dist : 0.0;
				if (Coming > 3.0 && Dist > 3.5 && Dist < 12.0)
				{
					const FVec2 Lat = Rel - Ug * Rel.Dot(Ug);   // off the line carrier -> net
					Out = (Rel * (-0.12 / Dist) - Lat * 0.5).LimitLength(1.0);
					if (S.Vel.Length() > 2.0 && S.Vel.Dot(Rel) < 0.0) { bWantStop[Id] = true; }   // still skating at the carrier: stop and let it come
					return true;
				}
			}
			if (!bCarrier || Spd < 3.0 || Me.DistTo(Cp) < 2.5 || !bGoalSide) { bToPuck = true; return true; }
			const double Gap = Clamp(Spd * 0.3, 1.0, 3.0);
			T = Cp + Ug * Gap + FVec2(0.0, -Sign(Cp.Y) * 0.8);
			const double Gs = GapSpeed(SkillOf(W, Id).Hk);   // lane A193: the presser's own top speed (bTrueGap)
			Out = Arrive(Me, T, 1.5) + Vc * (1.0 / (Gs > 1.0 ? Gs : 1.0));
			return true;
		}
		case EJob::Cover:
		{
			// the carrier's nearest pass: on the lane, nearer the receiver than the carrier (goal-side of the pass). A loose puck: goal-side of the opponent
			// nearest our net (not the one nearest the puck).
			const int M = bCarrier ? FiveLocal::CoverMate(W, C, SkillOf(W, Id).Hk.bCoverBestPass) : -1;
			if (M >= 0) { T = LerpV(Cp, W.Skaters[M].Pos, 0.7) - S.Vel * 0.2; break; }
			int Mark = -1, Np = -1;
			double Bp = 1e18, Bg = 1e18;
			for (int o = 0; o < W.NumSkaters; ++o) { if (W.Skaters[o].Team != S.Team && W.Skaters[o].Pos.DistTo(Pp) < Bp) { Bp = W.Skaters[o].Pos.DistTo(Pp); Np = o; } }
			for (int o = 0; o < W.NumSkaters; ++o)
			{
				if (o == Np || W.Skaters[o].Team == S.Team || W.Skaters[o].bDown) { continue; }
				const double G = W.Skaters[o].Pos.DistTo(OwnGoal);
				if (G < Bg) { Bg = G; Mark = o; }
			}
			if (Mark < 0) { T = LerpV(OwnGoal, Pp, 0.45); T.Y = -PuckSide * W.HalfWidth * 0.3; break; }
			T = LerpV(W.Skaters[Mark].Pos, OwnGoal, 0.25);
			break;
		}
		case EJob::Weak:
			// the far side between the puck and our net (the back-door pass), never behind the play; a second weak skater takes the high slot
			if (JobOrd[Id] > 0) { T = OwnGoal + FVec2(Up * 12.0, 0.0); T.Y = Clamp(Pp.Y * 0.3, -4.0, 4.0); break; }
			T = LerpV(OwnGoal, Pp, 0.45);
			T.Y = -PuckSide * W.HalfWidth * 0.3;
			if (SkillOf(W, Id).Hk.bShotLane9 && bCarrier && W.Skaters[C].Team != S.Team)   // lane A206 (wave 2): in the shooting lane
			{
				const double Lc = Cp.DistTo(OwnGoal);
				if (Lc < 35.0 && Lc > 12.0) { const double Out9 = Lc * 0.35 > 9.0 ? Lc * 0.35 : 9.0; T = Cp + (OwnGoal - Cp).Normalized() * Out9; }
			}
			break;
		default:
			return false;
		}
		if (bLanes)
		{
			// nobody in a teammate's lane: off the line carrier -> teammate by 3 m
			for (int m = 0; m < W.NumSkaters; ++m)
			{
				if (m == Id || m == C || W.Skaters[m].Team != S.Team || W.Skaters[m].bDown) { continue; }
				const FVec2 L = W.Skaters[m].Pos - Cp;
				const double Ld = L.Length();
				if (Ld < 4.0) { continue; }
				const FVec2 Lu = L * (1.0 / Ld);
				const FVec2 Rel = T - Cp;
				const double Along = Rel.Dot(Lu);
				const double Lat = Rel.Cross(Lu);
				if (Along > 2.0 && Along < Ld - 2.0 && std::fabs(Lat) < 2.0) { T += Lu.Perp() * ((Lat >= 0.0 ? -1.0 : 1.0) * 3.0); }
			}
		}
		// Space: a shape job keeps its distance from the puck (the close support 7 m, the others 9 m; in defence only while the puck is more than 12 m from
		// our net, where the slot and the far post collapse on it): the puck's own skater and the presser play it, the rest give it room and options.
		{
			const bool bDefence = Job[Id] == EJob::Cover || Job[Id] == EJob::Weak;
			const double MinD = Job[Id] == EJob::Support ? 7.0 : 9.0;
			if (!bDefence || Pp.DistTo(OwnGoal) > 12.0)
			{
				FVec2 Off = T - Pp;
				if (Off.Length() < MinD)
				{
					if (Off.Length() < 0.5) { Off = FVec2(-Up, 0.0); }
					// wide first: push along y (away from the puck's side of the target) so a deep breakout spreads to the boards rather than back into the net
					const double Need = std::sqrt(MinD * MinD - (Off.X * Off.X < MinD * MinD ? Off.X * Off.X : 0.0));
					const double Sy = std::fabs(Off.Y) > 0.3 ? Sign(Off.Y) : (Pp.Y >= 0.0 ? -1.0 : 1.0);
					T.Y = Pp.Y + Sy * Need;
					if (std::fabs(T.Y) > W.HalfWidth - 2.0) { T.Y = Pp.Y - Sy * Need; }   // no room on that side: the other
				}
			}
		}
		if (JobLoose[Id])
		{
			// loosely: the spot is off by up to 4 m (a fixed function of the skater and the two-second window) and the bot gets there at three quarters' pace
			T += FVec2(Hash11(static_cast<uint64_t>(Id) + 611, static_cast<uint64_t>(W.Frame / 120)), Hash11(static_cast<uint64_t>(Id) + 613, static_cast<uint64_t>(W.Frame / 120))) * 4.0;
		}
		T.X = Clamp(T.X, -W.GoalX + 1.5, W.GoalX - 1.5);
		T.Y = Clamp(T.Y, -W.HalfWidth + 2.0, W.HalfWidth - 2.0);
		Out = Arrive(Me, T, Params.ArriveSlowRadius) * (JobLoose[Id] ? 0.75 : 1.0);
		return true;
	}

	FJamAIInput FJamPlayerBot::Think(const FJamAIWorld& W) const
	{
		FJamAIInput In;
		if (W.bFrozen || W.PlayerIndex < 0)
		{
			return In;
		}
		const FJamAISkater& Me = W.Skaters[W.PlayerIndex];
		// lane A3 (R-0013): a centre takes the draw with a person's reaction time after the drop
		if (W.bDrawOpen && Me.bCentre && W.FramesSinceDrop >= DrawReactionFrames)
		{
			In.bPoke = true;
		}
		// lane A3 (R-0013 / Director 14:45): forecheck: against an opposing carrier the blade follows the puck and pokes once it is in reach
		if (W.Carrier >= 0 && W.Skaters[W.Carrier].Team != Me.Team)
		{
			const FVec2 Tp = W.PuckPos - Me.Pos;
			const double Dp = Tp.Length();
			if (Dp > 1e-6 && Dp < W.SkaterRadius + W.StickReach + 1.0)
			{
				In.Stick = Tp * (1.0 / Dp) * (Dp - W.SkaterRadius < W.StickReach ? (Dp - W.SkaterRadius > 0.2 * W.StickReach ? (Dp - W.SkaterRadius) / W.StickReach : 0.2) : 1.0);
				// HOOK (lane A115 for track F2): no swing the sim would refuse (the carrier's take grace, or its body between): dead until the adapter fills the fields
				const bool bNoStick = StickCannotTake(W, W.PlayerIndex, W.Carrier);
				if (Me.bCanPoke && Dp <= W.SkaterRadius + W.StickReach && !bNoStick) { In.bPoke = true; }
				// and lifts the carrier's stick at contact range
				if (Me.bCanLift && !bNoStick && W.Skaters[W.Carrier].Pos.DistTo(Me.Pos) <= 2.0 * W.SkaterRadius + W.LiftRange * 0.9) { In.bLift = true; }
			}
		}
		// Work in the attacking frame: the opponents' goal at +x (rotate 180 deg for team 1; keeps handedness).
		const double Sg = Me.Team == 0 ? 1.0 : -1.0;
		const double Gx = W.GoalX;
		const double Hz = W.HalfWidth;
		const FVec2 Pos = Me.Pos * Sg;
		const FVec2 Face = (Me.Facing * Sg).Normalized();
		const FVec2 Puck = W.PuckPos * Sg;
		FVec2 Others[kMaxSkaters];
		int NumOthers = 0;
		for (int i = 0; i < W.NumSkaters; ++i)
		{
			if (i != W.PlayerIndex)
			{
				Others[NumOthers++] = W.Skaters[i].Pos * Sg;
			}
		}
		const FVec2 Goal(Gx, 0.0);
		FVec2 Aim = Goal;
		const double Dgoal = (Goal - Puck).Length();
		FVec2 Dirg = (Aim - Puck).Normalized();
		// detour around a skater standing in the lane puck -> goal
		for (int k = 0; k < NumOthers; ++k)
		{
			const FVec2& O = Others[k];
			if (O.X < Gx - 6.0 && O.X > Puck.X - 0.5 && O.X < Puck.X + 8.0)
			{
				const FVec2 Rel = O - Puck;
				const double Along = Rel.Dot(Dirg);
				const double Side = Rel.Cross(Dirg);
				if (Along > 0.0 && std::fabs(Side) < 2.2)
				{
					const double Sgn = Puck.Y - O.Y >= 0.0 ? 1.0 : -1.0;
					Aim = FVec2(O.X + 3.0, O.Y + Sgn * 3.5);
					Dirg = (Aim - Puck).Normalized();
				}
			}
		}
		if (std::fabs(Puck.Y) > Hz - 1.6)
		{
			// pinned on a board: peel it off the wall
			Dirg = bPeelToMiddle ? FVec2(1.0, -Sign(Puck.Y) * 0.7).Normalized() : FVec2(1.0, 0.0);
		}
		if (bPeelToMiddle && Puck.X < -Gx + 2.0)
		{
			// behind the own goal line: bring it out to the middle
			Dirg = FVec2(1.0, -Puck.Y * 0.15).Normalized();
		}
		FVec2 Peel;
		if (bBoardPeel && BoardPeel(W, Puck, 1.0, Peel))
		{
			// lane A2: any board, end boards included (the rink is symmetric, so the attacking frame is fine)
			Dirg = Peel;
		}
		const FVec2 ToPuck = Puck - Pos;
		const FVec2 Behind = Puck - Dirg * 1.2;
		FVec2 Want;
		const double Lateral = ToPuck.Cross(Dirg);
		if (ToPuck.Dot(Dirg) > 0.0 && std::fabs(Lateral) < 1.3)
		{
			Want = Puck + Dirg * 3.0 - Pos;   // lined up behind it: push through
		}
		else
		{
			Want = Behind - Pos;
			if (ToPuck.Dot(Dirg) < 0.0 && ToPuck.Length() < 4.0)
			{
				// in front of the puck: swing wide first
				FVec2 Perp = Dirg.Perp() * (Lateral <= 0.0 ? 1.0 : -1.0);
				FVec2 SideN;
				if (bBoardPeel && BoardSdf(W, Behind + Perp * 2.5, SideN) > -1.0)
				{
					Perp = -Perp;   // lane A2: swing round on the ice side, never through the boards
				}
				Want = Behind + Perp * 2.5 - Pos;
			}
		}
		for (int k = 0; k < NumOthers; ++k)
		{
			const FVec2 Dd = Pos - Others[k];
			const double L = Dd.Length();
			if (L < 1.2 && L > 0.01)
			{
				Want += Dd.Normalized() * (1.2 - L) * 3.0;
			}
		}
		// lane A3 (forecheck): against an opposing carrier, skate to where the puck will be (a lead of up to 1 s on its velocity, in the
		// attacking frame) instead of lining up behind it; trailing a carrier at equal speed never closes the gap
		if (bForecheckLead && W.Carrier >= 0 && W.Skaters[W.Carrier].Team != Me.Team)
		{
			const FVec2 PuckV = W.PuckVel * Sg;
			const double Lead = Clamp(ToPuck.Length() / 10.0, 0.0, 1.0);
			FVec2 Tgt = Puck + PuckV * Lead;
			// the carrier's body is between us and the puck (riding the boards): come round it on the ice side
			const FVec2 Cp = W.Skaters[W.Carrier].Pos * Sg;
			const FVec2 ToC = Cp - Pos;
			if (ToC.Length() < ToPuck.Length() && ToC.Dot(ToPuck) > 0.0 && std::fabs(ToC.Cross(ToPuck.Normalized())) < 1.5)
			{
				FVec2 Side = ToPuck.Normalized().Perp();
				if (Side.Dot(FVec2(0.0, 0.0) - Cp) < 0.0) { Side = -Side; }   // the side that faces the middle of the rink
				Tgt = Cp + Side * 2.5 + PuckV * Lead;
			}
			// never chase into either net: a target behind a goal line in front of the net mouth stays a metre out
			// (the sim lets a skater into the net, where it got stuck for 400 frames in the 16:06 trace, regular pro seed 15)
			if (std::fabs(Tgt.Y) < W.GoalHalfWidth + 1.5 && std::fabs(Tgt.X) > Gx - 1.0) { Tgt.X = Sign(Tgt.X) * (Gx - 1.0); }
			Want = Tgt - Pos;
		}
		// lane A3 (16:12): never steer into either net mouth (the sim lets a skater into the net and it can stick there for many
		// seconds; the 16:11 trace scan had the scripted human inside a net up to 34 s per match on the large rink)
		{
			FVec2 T = Pos + Want;
			if (std::fabs(T.Y) < W.GoalHalfWidth + 1.0 && std::fabs(T.X) > Gx - 1.0)
			{
				T.X = Sign(T.X) * (Gx - 1.0);
				Want = T - Pos;
			}
			// behind a net (between its back and the end boards) and heading for the middle: go round the side of the net,
			// not into its back (the 16:12 trace: the human pushed into the back of the net for up to 2 minutes)
			if (std::fabs(Pos.X) > Gx + 0.3 && std::fabs(Pos.Y) < W.GoalHalfWidth + 1.2 && Want.X * Sign(Pos.X) < 0.0)
			{
				const double Sy = Pos.Y >= 0.0 ? 1.0 : -1.0;
				Want = FVec2(0.0, Sy);
			}
		}
		const FVec2 Dir = Want.Length() > 0.05 ? Want.Normalized() : FVec2();
		In.Move = Dir * Sg;
		// lane A2: chip a puck off the boards, facing inwards and not backwards
		FVec2 Bn;
		if (bBoardPeel && Me.bCanShoot && BoardSdf(W, Puck, Bn) > -1.0 && Face.Dot(-Bn) > 0.6 && Face.X > -0.2)
		{
			In.bShoot = true;
		}
		// shoot: puck close and in front, goal close enough, facing the goal mouth, clear lane
		const double FaceDot = bPeelToMiddle ? 0.97 : 0.95;
		if (Me.bCanShoot && Dgoal < ShootRangeM && Face.X > 0.3 && Face.Dot((Goal - Puck).Normalized()) > FaceDot)
		{
			const double Zg = Puck.Y + Face.Y / Face.X * (Gx - Puck.X);
			bool bClear = true;
			for (int k = 0; k < NumOthers; ++k)
			{
				const FVec2 Rel2 = Others[k] - Puck;
				if (Rel2.Dot(Face) > 0.0 && std::fabs(Rel2.Cross(Face)) < 1.0 && Others[k].X < Gx - 1.0)
				{
					bClear = false;
				}
			}
			if (std::fabs(Zg) < W.GoalHalfWidth + 0.5 && bClear)
			{
				In.bShoot = true;
			}
		}
		return In;
	}
}
