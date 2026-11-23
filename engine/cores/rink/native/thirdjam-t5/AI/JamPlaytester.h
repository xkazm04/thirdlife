// Lane A34 (R-0028 point 3): a human-like playtester for the human's slot, and the fun metrics of one match.
//
// FJamPlaytester plays like a person would through a pad: it sees the world late (a reaction ring of N frames), aims with an error that
// drifts every two seconds, moves an analog stick that ramps instead of snapping, holds the shoot button to charge and lets go to shoot,
// and (the novice) stops pressing anything for half a second every ten seconds. Its decisions read only FJamAIWorld and its output is one
// FJamAIInput, which FJamSimAdapter::Step copies into FJamInput field by field: the same path the pawn's input takes in the game mode.
// No wall clock, no engine randomness: every "random" number is a hash of (seed, frame window, salt), so a match replays exactly.
//
// RunPlaytestMatch runs one match of the playtester against the brain on lane A1's UJamSim (through FJamSimAdapter: the checks, pokes and
// knockdowns come from UJamSim::GetFrameEvents, which IJamAISim does not carry) and fills FJamPlaytestStats, the fun metrics the
// tournament commandlet prints as thirdjam.playtest/1 JSON lines (-player=novice|regular|good) and tools/playtest/run.mjs tabulates.
// Nothing here changes a profile or a sim number: it measures.
#pragma once

#include "JamAICore.h"
#include "JamBotMatch.h"

namespace JamAI
{
	enum class EPlaytester : uint8_t { Novice, Regular, Good };

	// The person behind the pad. Numbers from briefs/A34-playtester.md (reaction 12 / 6 / 3 frames, aim noise 10 / 5 / 2 degrees, the novice's
	// lapse); the rest are this lane's reading of a first-time, a regular and a good player, listed in docs/experiments/PLAYTEST.md.
	struct FJamPlaytesterProfile
	{
		int ReactionFrames = 6;          // the world is seen this many frames late (0..kMaxReactionFrames)
		double AimNoiseDeg = 5.0;        // the aim point drifts up to this far off the goal centre; re-rolled every AimWindowFrames
		int AimWindowFrames = 120;
		int LapseEveryFrames = 0;        // every this many frames of play the player stops pressing for LapseFrames (0 = never)
		int LapseFrames = 30;
		double StickRamp = 0.2;          // how much |Move| may change per frame (an analog stick pushed over, not snapped)
		double ShootRangeM = 20.0;       // starts charging when the puck is this near the goal (metres from the goal centre)
		double ReleaseToleranceDeg = 6.0; // lets go when the facing is within this of the (noisy) aim
		int PatienceFrames = 40;         // ... or after holding this long, lined up or not (the shot still needs the sim's 60-degree front gate)
		double PassAheadM = 5.0;         // passes when a teammate is this much nearer the goal, open, and a defender closes
		double PressureM = 4.0;          // "a defender closes" = an opponent within this of me
		double CheckFromBehindDot = 0.5; // a check is attempted when my closing direction . the carrier's facing is below this (0.5 = the sim's foul line)
		int DrawReactionFrames = 12;     // presses for the draw this many frames after the drop
		double ChaseLeadS = 0.5;         // leads a moving puck / carrier by this many seconds of its velocity
		bool bGoalside = true;           // defends goalside of an opposing carrier that is nearer our net than we are
		// R-0029 point 4 (lane A39): how often the player uses the one-timer and the deke when the chance is there (per cent of 2-second windows:
		// the good player always, the regular one half the time, the novice never). The breakaway burst is the sim's: nobody presses for it.
		int OneTimerPct = 50;
		int DekePct = 50;
		// Lane A51 (R-0034): stick handling. The regular and good players carry the puck on the far side from a defender within SweepDefenderM in front
		// (a sweep when the side changes) and spin when a defender closes from behind at speed; the novice knows neither.
		bool bStickHandling = false;
		double SweepDefenderM = 2.5;
		// Lane A72 (ask A3): the sprint (Shift held) on a breakaway (carrying with the burst running or no opponent within 8 m) or a chase of a puck more
		// than 10 m away that no teammate carries, in this per cent of the 2-second windows: good 100, regular 50, novice never. Only when the run asks for it
		// (RunPlaytestMatch bSprint, the commandlet's -playersprint): off by default so every curve measured before stays comparable.
		int SprintPct = 0;
		// Lane A95 (R-0045 laws 3 and 4, brief A95 job 3): the vision's verbs, used on purpose and only when the cartridge has them.
		//  - BrakeIntent: when the wanted direction reverses against the velocity (the sim's reverse brake), the player means to stop: 2 always (stop and go),
		//    1 only to stop on a target within BrakeNearM (the puck it skated past), 0 never; otherwise the reversal is carved into a turn (115 degrees off the
		//    velocity), so no class brakes by accident (the analog ramp passes through a reversed input on any about-turn).
		//  - CutPct: per cent of the 2-second windows the carrier makes a sharp cut (75 degrees for CutFrames) away from a defender closing on its lane inside
		//    CutDefenderM: the sim's first-step burst arms on it (a 60-degree turn inside 10 frames). The novice never cuts.
		//  - CarrySprintPct: per cent of the windows the carrier holds sprint while its lane is open (no opponent within 6 m, none on the lane 15 m ahead).
		int BrakeIntent = 0;
		double BrakeNearM = 6.0;
		int CutPct = 0;
		int CutFrames = 10;
		double CutDefenderM = 5.0;
		// Lane A151 (track F1): with the press on course and time, the share of the hits it sees coming that the player presses for (per cent of 2-second
		// windows, as OneTimerPct). 100 = every one: 5.2 to 5.9 landed checks a match where the press of lane A132 landed 3.2 to 3.9 (600 matches a cell),
		// which moves the ladder's all_star cell by 5.3 points. 60 (every profile): 4.2 to 4.5 landed a match, whiffs 16 % at pro (54 %), and the three cells
		// move -3.7 / +2.0 / +2.4 (600 seeds, paired; CONTACT-6.md section 2).
		int CheckPct = 60;
		int CarrySprintPct = 0;
		// Lane A152 (track F2, R-0059 point 4): the poke when it can land. The player aims the blade where the puck will be when its hand arrives (its own
		// reaction ahead, on the carrier's and its own velocity) and does not press into a take grace that will still run then or a body between (the
		// brain's BodyShields). The regular and the good player; the novice presses whenever the puck is near. Only with FJamPlaytester::bPokeReadOn.
		bool bPokeRead = false;
	};
	FJamPlaytesterProfile PlaytesterProfile(EPlaytester Kind);
	const char* PlaytesterName(EPlaytester Kind);
	bool ParsePlaytester(const char* Name, EPlaytester& Out);

	// What the playtester decided this frame (diagnostics; the match counts them).
	enum class EPlaytesterAct : uint8_t { Idle, Draw, Chase, Carry, Charge, Pass, Support, Forecheck, Poke, Check, Lapse, OneTimer, Deke, Sweep, Spin, Count };

	class JAMCORE_API FJamPlaytester   // lane A56: exported so the JamNet soak (Bar.Net.Soak*) can seat two playtesters as the two humans
	{
	public:
		FJamPlaytesterProfile P;
		int ChargeFramesMax = 30;        // game.shot.charge_frames_max (the sim's; FJamAIWorld does not carry it)
		bool bSprint = false;            // lane A72 (ask A3): the profile's SprintPct applies (RunPlaytestMatch bSprint)
		bool bRestStick = false;         // lane A86 (R-0043 point 2): the old stick (left at rest while carrying, the before arm); env JAM_PLAYTESTER_STICK=rest
		int Cuts = 0;                    // lane A95: cuts made (the stats read it)
		bool bOldVerbs = false;          // lane A95: the before arm of job 3 (env JAM_PLAYTESTER_VERBS=old): no brake intent, no cut, no carry sprint (measurement only)
		int CoursePctOverride = -1;      // lane A151, measurement only: env JAM_PLAYTESTER_CHECK=course:NN plays the press on course and time at NN per cent of the chances (-1 = the profile's CheckPct)
		bool bCourseCheck = false;       // lane A151: the check press on course and time (contact.bPlaytesterCoursePress, or env JAM_PLAYTESTER_CHECK=course; =closing forces lane A132's press)
		// Lane A184 (track F1, evolution 9): the held cross-check. BraceMode 0 = never; 1 = as a person would (the rule's own switch, contact.cross_hold: held from
		// BraceFromM out when skating at an opposing carrier, closing at BraceClosingMps or more and not into his back; the body-check press is not made while
		// braced); 2 = held whenever it does not carry (the "held all match" arm: env JAM_PLAYTESTER_BRACE=always; =off forces 0; measurement only).
		// Lane A192 (evolution 10): a person uses both. He commits to the brace only on a long run: the carrier more than BraceMinM (body to body) and at most
		// BraceFromM away, closing at BraceClosingMps or more, not into his back; he keeps it on that carrier while he still closes on him. On a short approach
		// (the man already inside BraceMinM, or closing slower) he presses the body check as before. Env JAM_PLAYTESTER_BRACE_CLOSING tunes the speed (a
		// measurement's arm).
		int BraceMode = 0;
		int BraceTarget = -1;
		double BraceClosingMps = 6.0;
		static constexpr double BraceMinM = 2.5;
		static constexpr double BraceFromM = 6.0;
		bool bOldCheck = false;          // lane A132: the check press on the playtester's own speed along the line, as before (contact.bPlaytesterClosingPress false, or env JAM_PLAYTESTER_CHECK=old for a measurement's before arm)
		// Lane A134 (track Q2, evolution 3, item 1): the scripted human reads the body shield and the take grace as a person does (the HUD and the figure
		// show both): no poke and no lift the sim would refuse (StickCannotTake), so the poke is there the frame the puck is in the open.
		// env JAM_PLAYTESTER_READ=0 | 1 forces it (measurement). Off: it swings into every shield (14 pokes a match on the big ice, 0.7 clean).
		bool bReadShield = false;
		// Lane A166 (track F2 evolution 7; env JAM_PLAYTESTER_CONTEST=brake, off by default: every measurement before stays comparable): the player obeys the
		// contested-puck mark (JamCarrierMarks::Contested, set by RunPlaytestMatch each frame): without the puck he brakes instead of racing an opponent to it.
		bool bContestBrake = false;
		bool bContestedNow = false;
		int ContestOnlyNth = 0;          // lane A201: JAM_PLAYTESTER_CONTEST=brake:N obeys only the N-th showing of the ring (0 = every showing)
		int ContestBrakeFrames = 0;      // frames the decision braked for it (the stats read it)
		// Lane A178 (track F2 evolution 8; env JAM_PLAYTESTER_STOPMARK=brake | stop, off by default): the player obeys the stop's line (JamCarrierMarks::StopMark
		// lit, set by RunPlaytestMatch each frame with the opponent's place). brake = law 3's whole move as drill 21 plays it (FJamCarryDrill, the first move):
		// when the line lights he pulls back and to the open side until he is slower than 2 m/s (45 frames at most), cuts 60 degrees off his line to the side the
		// opponent is not on for StopCutFrames, then the script goes on; not again for StopBrakeRearm frames. stop = the stop alone (he brakes StopOnlyFrames
		// and the script goes on straight): the arm that shows what the line is worth to a player who reads "stop" and no more.
		bool bStopMarkBrake = false;
		bool bStopMarkStopOnly = false;
		bool bStopLitNow = false;
		double StopDefTowardMps = 0.0;   // env JAM_PLAYTESTER_STOPMARK_DEFTOWARD: the instrument's line lights only for an opponent skating at him this fast (a measurement's arm; 0 = the shipped rule)
		FVec2 StopDef, StopLine = FVec2(1.0, 0.0);
		double StopSide = 1.0;
		int StopPhase = 0;               // 0 none, 1 the stop, 2 the cut
		long long StopPhaseStart = 0, StopBrakeNext = -1;
		int StopBrakes = 0;
		int StopOnlyNth = 0, StopCandidates = 0;
		int StopHandFrames = -1;                  // lane A201: env JAM_PLAYTESTER_STOPMARK_HAND: frames from the light to the stop reaching the sim (-1 = the class's own ReactionFrames)
		long long StopPendingAt = -1;             // ... the frame the decided stop is pressed
		FVec2 StopPendingDef;   // lane A201: JAM_PLAYTESTER_STOPMARK=brake:N obeys only the N-th light of the match (0 = every light)
		enum { StopOnlyFrames = 24, StopCutFrames = 45, StopBrakeRearm = 84 };
		bool bPokeReadOn = false;        // lane A152: the profile's bPokeRead applies (stick.bPlaytesterPokeRead, or env JAM_PLAYTESTER_POKE=read; =old forces the press as it was)
		// Lane A200 (track F1, evolution 11; CONTACT-12.md): the hits he can see coming, and his answer to them. A hit is SEEN when an opponent within
		// DodgeSeeM in front of him (inside 100 degrees of his facing) begins a body check's wind-up while closing on him at 1 m/s or more, or a cross-check's
		// wind-up aimed at him (FJamAISkater::CheckWindupLeft, CrossWindupLeft / CrossTarget); its episode lasts the wind-up and, for the body check, the bot's
		// window (UJamSim::CheckWindowFrames). Counted always (SeenHits, SeenLanded: that man's hit landed on him, a stumble or a fall), output untouched.
		// bDodge (env JAM_PLAYTESTER_DODGE=on, or =N for N frames of reaction; off by default: every measurement before stays comparable): DodgeReactFrames
		// after the wind-up began (a person's reaction to the figure's take, not the profile's ring) he flicks the stick across the man's line and away from
		// him (past the analog ramp; on the side his skating leans), no check press, until the episode ends. Dodges: the episodes he answered.
		bool bDodge = false;
		int DodgeReactFrames = 6;
		static constexpr double DodgeSeeM = 5.0;
		int SeenHits = 0, SeenLanded = 0, Dodges = 0;
		void NoteHitOnMe(int By) { if (DodgeWho >= 0 && By == DodgeWho) { bSeenLanded = true; } }
		int StickVariant = 0;            // lane A86 measurement arms (env JAM_PLAYTESTER_STICK): 0 aim, 2 carry (no cursor on a loose puck), 3 front (the carry aim within 60 deg of facing)

		void Reset(EPlaytester Kind, uint64_t Seed);
		// One frame: the decision on this frame's world, delayed by the reaction ring, then the analog ramp.
		FJamAIInput Think(const FJamAIWorld& W);
		EPlaytesterAct LastAct() const { return Act; }
		int ActCount(EPlaytesterAct A) const { return Acts[static_cast<int>(A)]; }

	private:
		uint64_t Seed = 0;
		int64_t Tick = 0;
		FJamAIInput Ring[kMaxReactionFrames + 1] = {};
		FVec2 MoveOut;                   // the stick as held after the ramp
		bool bHolding = false;           // shoot held
		int HoldFrames = 0;
		int64_t LastPassFrame = -1000;
		int SaucerHold = 0;              // lane A77 (R-0036): frames pass has been held for a saucer (0 = none)
		int64_t LastCheckFrame = -1000;
		int64_t LastDekeFrame = -1000;   // R-0029 point 4 (lane A39)
		int64_t PlayFrames = 0;          // unfrozen frames seen (the lapse clock)
		bool BrakeRing[kMaxReactionFrames + 1] = {};   // lane A95: the brake intent decided with each ring entry
		bool bBrakeWanted = false;       // lane A95: this frame's decision (Decide -> Think)
		int64_t CutUntil = -1;           // lane A95: the cut runs until this frame
		int64_t LastCutFrame = -1000;
		FVec2 CutDir;                    // lane A95: rink frame
		EPlaytesterAct Act = EPlaytesterAct::Idle;
		int Acts[static_cast<int>(EPlaytesterAct::Count)] = {};

		int DodgeWho = -1;               // lane A200: the man of the hit he sees coming (-1 none)
		int64_t DodgeStart = 0, DodgeEnd = 0;
		bool bSeenLanded = false, bDodged = false;
		void TrackThreat(const FJamAIWorld& W);
		// A fixed number in [-1, 1] for (seed, window, salt).
		double Noise(int64_t Window, int Salt) const;
		FJamAIInput Decide(const FJamAIWorld& W);
	};

	// The fun metrics of one match (brief A34 point 2). Frames, never seconds; -1 = never happened.
	struct FJamPlaytestStats
	{
		uint64_t Seed = 0;
		int PlayerIndex = -1;
		int PlayerTeam = 0;
		int GoalsFor = 0, GoalsAgainst = 0;
		int GoalsByHuman = 0;            // goals whose last toucher was the human
		int64_t Frames = 0, PlayFrames = 0;
		bool bOver = false;
		int Winner = -1;
		uint64_t Hash = 0;
		int Touches = 0;                 // the human became the puck's last toucher
		int Carries3s = 0;               // spells as the carrier of at least 180 frames
		int64_t CarryFrames = 0;         // frames as the carrier
		int Shots = 0, ShotsOnTarget = 0; // on target: the puck's line at the shot crosses the goal line inside the mouth
		int ShotsOpp = 0;                // shots by the other team
		int ShotsMates = 0;
		int LeadChanges = 0;             // the leading team changes (ties in between allowed)
		int64_t FirstTouch = -1, FirstShot = -1, FirstGoalFor = -1, FirstGoalByHuman = -1, FirstGoalAgainst = -1;
		int Faceoffs = 0, FaceoffsWithoutTouch = 0, MaxFaceoffToTouch = 0;
		// lane A3 (R-0029): in the faceoff windows that ran out without a human touch, frames by who held the puck
		int64_t WoMateFrames = 0, WoOppFrames = 0, WoLooseFrames = 0;
		int ChecksLanded = 0, ChecksTaken = 0, Fouls = 0;
		// Lane A151 (track F1): the human's check presses that opened a window (bCheckThisFrame frames) and the windows that ran out on nobody
		// (FJamSkaterState::ChecksMissed, the HUD's MISSED). Read-outs on the playtest line: check_presses, check_whiffs.
		int CheckPresses = 0, CheckWhiffs = 0;
		// Lane A157 (track F1, evolution 6): read-outs on the playtest line.
		// downed_*: B-to-A-0041 point 2's bar. DownedFrames: frames any skater lay on the ice. A skater on its feet with its root within 0.6 m (B's bar) or
		// 0.9 m (at the downed skater's 0.4 m body circle: standing on the lying figure) of a downed skater's root: the spells longer than 6 frames, the
		// longest spell, the pair-frames; the frames the sim's push-out turned a course (FJamSkaterState::DownedPushFrames, all skaters).
		int64_t DownedFrames = 0, DownedIn06Frames = 0, DownedIn09Frames = 0, DownedPushFrames = 0;
		int DownedIn06Spells = 0, DownedIn06Max = 0, DownedIn09Spells = 0, DownedIn09Max = 0;
		// hits_*: item 4, the board slam's read. Landed hits (a pressed check or a cross-check: FJamSkaterState::ContactOutcome stumble or down) by where:
		// the boards answered (bContactBoard: the victim within 1.5 m of the boards and pushed into them, game.contact.board_bonus above 1) or open ice;
		// the frames down they gave; the human's own (ContactBy = the human).
		int HitsBoardDown = 0, HitsOpenDown = 0, HitsBoardStumble = 0, HitsOpenStumble = 0, HitsHumanBoard = 0, HitsHumanOpen = 0;
		int64_t HitsBoardDownFrames = 0, HitsOpenDownFrames = 0;
		// Items 2 and 3: the human's presses the cooldown dropped and lunges that met nobody (FJamSkaterState::ChecksCooling, LungesMissed); the bots' summed,
		// with the bots' presses that opened a window (bCheckThisFrame frames).
		int ChecksCooling = 0, LungesMissed = 0, BotChecksCooling = 0, BotLungesMissed = 0, BotCheckPresses = 0;
		// Lane A165 (track F1, evolution 7): board slams (FJamSkaterState::bContactSlam) of any skater, the frames down they gave, the human's own.
		int Slams = 0, SlamsHuman = 0;
		// Lane A177 (track F1, evolution 8; REVIEW-3 item 2): the human's knockdowns by what he held. KdWon: the puck his for under half a second (frames since
		// he won it under 30: "hit as he won it"); KdWon15: of those, inside 15 frames; KdCarry: carrying for longer; KdNoPuck: the rest. HumanDownFrames:
		// play frames he lay on the ice; HumanStumbleFrames: play frames he stumbled. ShieldHuman / ShieldBots: hits the take shield capped
		// (FJamSkaterState::ContactShielded), on the human and on every other skater.
		int KdWon = 0, KdWon15 = 0, KdCarry = 0, KdNoPuck = 0, ShieldHuman = 0, ShieldBots = 0;
		// Lane A184 (track F1, evolution 9): the held cross-check and the hits. CrossLanded: the human's cross-checks that stumbled or felled (pressed or
		// braced); BraceLanded: of those, out of the brace; KdGiven: knockdowns the human's hits gave (any kind); BraceFrames / BraceHits: the human's frames
		// braced and hits out of the brace (FJamSkaterState::CrossBraceFrames / CrossBraceHits); BotBraceHits: every other skater's hits out of a brace;
		// BotCrossLanded / BotChecksLanded: the bots' landed cross-checks and body checks (stumble or down), every bot.
		int CrossLanded = 0, BraceLanded = 0, KdGiven = 0, BraceFrames = 0, BraceHits = 0, BotBraceHits = 0, BotCrossLanded = 0, BotChecksLanded = 0;
		// Lane A200 (track F1, evolution 11): the hits he saw coming and those that landed anyway (FJamPlaytester::SeenHits / SeenLanded), the ones he
		// answered with the dodge (Dodges), and every landed hit of an opponent on him (BotHitsOnHuman: body or cross, stumble or down).
		int SeenHits = 0, SeenLanded = 0, Dodges = 0, BotHitsOnHuman = 0;
		// Lane A209 (track F1, the night): the audit of the human's hit presses (JamHitHand.h, EHand: index names in HandKeyName), "hand" in the JSON line.
		int Hand[96] = {};
		int64_t HumanDownFrames = 0, HumanStumbleFrames = 0;
		int64_t SlamDownFrames = 0;
		int FoulsFromBehind = 0, FoulsNoPuck = 0;   // the two kinds of foul (contracts/events.md): from behind on the carrier; on a skater without the puck
		int64_t BoxFrames = 0;           // frames the human sat in the penalty box
		int Pokes = 0, PokesClean = 0, Lifts = 0, Passes = 0;
		int PassesReceived = 0;          // lane A46: teammates' passes seated on the human's blade (UJamSim's FJamSkaterState::PassesReceived)
		// R-0029 point 4 (lane A39): the payoffs the human used (one-timer shots, bursts, dekes) and the human's goals within 180 frames of one of them
		int OneTimers = 0, Breakaways = 0, Dekes = 0, PayoffGoals = 0;
		// lane A72 (asks A2, A3): frames the human sprinted, and frames any bot sprinted (summed over the bots)
		int64_t SprintFrames = 0, BotSprintFrames = 0;
		// lane A95: the vision's verbs: the human's reverse-brake stops, frames sprinting with the puck, frames in the first-step burst; the bots' summed
		int Cuts = 0;
		int64_t RevBrakes = 0, CarrySprintFrames = 0, BurstFrames = 0, BotRevBrakes = 0, BotCarrySprintFrames = 0;
		int Knockdowns = 0;              // the human knocked down (any cause)
		int KnockdownsAll = 0;           // lane A84: every knockdown in the match (any skater, any cause)
		int Stumbles = 0;                // lane A126: the human's StumbleFrames going from 0 to above 0
		int BoardHits = 0;               // lane A126: skater `board` events of any skater
		int KnockdownsByShotgun = 0;     // lane A126: knockdown events with cause shotgun (any skater)
		int64_t HoldMateFrames = 0, HoldOppFrames = 0, HoldNoneFrames = 0;   // lane A126: play frames by puck holder: the human's side, the other side, nobody
		int AbilitiesUsed = 0;           // lane A84: the human's ability uses (F, event `ability` Strength 1)
		int64_t IdleFrames = 0;          // frames beyond 900 since the human's last touch (play frames only)
		int IdleSpells = 0;              // spells without a touch that reached 900 frames
		int64_t MaxNoTouch = 0;          // the longest spell without a touch
		int Acts[static_cast<int>(EPlaytesterAct::Count)] = {};
	};

	class FJamSimAdapter;
	// One match on UJamSim: the brain plays every other skater at the config's AI params, the playtester plays the human.
	// lane A71: the per-frame log (tools/soak/playtest/idle.mjs). Called after a frame's step every TraceEvery frames and on every frame the human touches the puck;
	// SinceTouch = play frames since the human's last touch. Null / 0 = no trace, and the match is the same either way.
	using FJamPlaytestTraceFn = void (*)(void* Ctx, const FJamAIWorld& W, const FJamAIInput* In, const FJamBrain& Brain, int64_t SinceTouch, bool bHumanTouch);
	FJamPlaytestStats RunPlaytestMatch(FJamSimAdapter& Sim, const FJamMatchConfig& C, uint64_t Seed, EPlaytester Kind, int64_t MaxFrames, int ChargeFramesMax,
		bool bSprint = false, FJamPlaytestTraceFn Trace = nullptr, void* TraceCtx = nullptr, int TraceEvery = 0);
	// bSprint (lane A72, ask A3): the regular and good players press sprint (FJamPlaytesterProfile::SprintPct); false keeps every earlier measurement comparable.
	// One thirdjam.playtest/1 JSON line (no newline) into Buf. Returns the length written.
	int FormatPlaytestJson(const FJamPlaytestStats& S, const char* Cartridge, const char* Difficulty, EPlaytester Kind, char* Buf, int BufLen);
}
