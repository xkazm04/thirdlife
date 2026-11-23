// Lane A3: see DifficultyProfile.h. The profile table is the one place the difficulty numbers live
// (docs/experiments/BALANCING.md repeats them with the sweep that chose them).
#include "DifficultyProfile.h"

#include <cstdio>
#include <cstdlib>
#include <cstring>

namespace JamAI
{
	namespace DifficultyLocal
	{
		// pro is the FJamAIParams / FJamBotSkill defaults, so a cartridge without a level and code that never heard of
		// difficulties play the same game.
		FJamDifficultyProfile MakePro()
		{
			const FJamAIParams D;
			// Lane A46 (PAYOFFS.md section 6): the human's teammates pass to the open human in 0.4 of the chances at pro (0 before: the one-timer never reached the human).
			FJamDifficultyProfile P{"pro", D.SpeedScale, D.RedSkill, D.YieldMarginM, D.YieldRadiusM, D.HoldRadiusM, D.StallFrames, D.Opp, 0.4};
			// Lane A112 (CURVE-6.md): the pro's aggression numbers moved in ProOppSkill (JamAICore.h), the brain's default
			P.MateSpeedScale = 1.0;   // lane A112 (R-0048 point 4): the human's mates skate at the human's pace (the same as SpeedScale at pro)
			P.Opp.Hk.DropNoHit9Frames = 45;   // lane A206 (wave 3, EYE 1): pro plays the puck, not the man, for 45 frames after a drop
			P.Opp.Hk.EarlyLongShot9Frames = 600;   // lane A206 (wave 4): no shot from beyond 15 m in the match's first 10 s (Jam.Bot.PlayerBotWins: the first goal at pro fell at frames 358-364, the scrum's shot)
			P.Opp.Hk.Dodge9Share = 0.3;   // lane A206 (evolution 9, wave 2): pro steps off the human's hit in 0.3 of the windows (60 matches: bots felled 6.70 -> 5.02 a match; 0.6: 4.45)
			// Lane A221 (LADDER SET 4, CURVE-14.md): after A218's ring the regular player won pro 71 / 58 (regular / large, 300, the person's path). R-0063's dial:
			// pro's presser keeps its Press job inside the hunt and commits at 8 m (the old hunt radius), the hunt reaches 11 m: law 3's drill 94.0 % at 8 m,
			// straight charge 0, as before. Before: bPressInHunt off, PressCommitM 0, HuntRadiusM 8 (ProOppSkill's).
			P.Opp.Hk.bPressInHunt = true;
			P.Opp.Hk.PressCommitM = 8.0;
			P.Opp.HuntRadiusM = 11.0;
			P.LargeRedSkill = 1.05;   // lane A221 (LADDER SET 4): 1.03 -> 1.05 with the hunt dial above (the regular player on 120 x 60 58 -> 46, 300; 1.08: 43, 100). Before: 1.03, lane A217 (LADDER SET 3): 1.165 -> 1.03 through a person's hand on the closed sim (the regular player on 120 x 60 7 as built; with reach +20: 1.10 30, 1.05 39, 1.00 70, 100 a point). Before:   // lane A189 (CURVE-12.md, pass 2): 1.18 -> 1.165 with the wind-ups 8 / 12, evolution 8 and pressure 0.6 (the regular player on 120 x 60 42.8 -> 46.2, 600). Pass 1: 1.15 -> 1.18 on main 58af359f (the regular player on 120 x 60 56.5 -> 46.2, 600; 1.21: 41.7). Lane A154 (CURVE-8.md): 1.12 -> 1.15 (main 4cab387, after BRAIN-3 / CONTACT-5 / MOVEMENT-5: the regular player on 120 x 60 54.8 at 1.12, 48.2 at 1.15, 43.3 at 1.17 (600)). Lane A133 (CURVE-7.md): 1.065 -> 1.12 (the regular player on 120 x 60 with the hunt 8 and the carry: 69.8 at 1.065, 55.5 at 1.1, 47.8 at 1.13, 41.2 at 1.16 (600); 44.9 at 1.13 (2,000)). Lane A112 (CURVE-6.md): 1.04 -> 1.065 (the regular player on 120 x 60 with the new aggression: 57.1 at 1.04 (2,000)). Lane A95 (CURVE-5.md): 0.97 -> 1.04 (the regular player on 120 x 60 with the vision: 82.8 at 0.97 (600), 41.5 at 1.06 (2,000)). Lane A70: 0.97
			return P;
		}

		FJamDifficultyProfile MakeRookie()
		{
			FJamBotSkill Opp;
			Opp.ReactionFrames = 0;
			Opp.AimErrorDeg = 0.0;
			Opp.ShootExtraM = 20.0;    // lane A189 (CURVE-12.md): 25 -> 20 with red skill 0.97 -> 0.80 after the speed rule (the novice 71.2 -> 83.0, 600, main 58af359f). Lane A112 (CURVE-6.md): reach + 25 m (with the poke: the novice 99.3 -> 86.2; 30 m: 82.3; the rookie scored 0.26 a match on the kept puck). R-0029 P3: 5 (13 before)
			Opp.GuardRadiusM = 10.0;   // R-0029 P1 (5 / 45 before): the rookie back's guard post 10 m out, only within 20 m of its net
			Opp.GuardRangeM = 20.0;
			Opp.bBlockShots = true;
			Opp.BlockMinDistM = 35.0;   // only a shot from near centre ice (90 x 45: 41 m to the net) is blocked
			Opp.AimToleranceDeg = 20.0;
			Opp.LeadFrames = 15;
			Opp.bIntercept = false;
			Opp.bUseAimCone = true;
			Opp.PokeFrames = 10;   // lane A133 (CURVE-7.md): 6 -> 10 (the novice 79.3 -> 86.8 on the integrated tree; 8: 84.3). Lane A112 (R-0050 point 4, CURVE-6.md): the rookie pokes after 6 frames in reach (pro's old timing; never before, R-0017): with the kept puck it had no way to take one but a hit
			Opp.SweepReactFrames = 14;   // lane A51 (R-0034): the rookie's blade reads the carried puck 14 frames late
			Opp.ShotChargeFrames = 0;   // lane A31 (B-to-A-0024): rookie taps its shots
			// Lane A94 (R-0045 law 2): the rookie knows the hockey principles and executes them late and loosely: it reads a change of possession 24 frames
			// late, keeps its shape job in 0.6 of the two-second windows, and passes away from pressure only once it is 0.6 s out. A86 / the final curve tune these.
			Opp.Hk = ProHockeySense();
			Opp.Hk.ShapeShare = 0.6;
			Opp.Hk.LateFrames = 24;
			Opp.Hk.PressureSec = 0.6;
			Opp.SprintShare = 0.2;   // lane A95 (R-0045 law 4, CURVE-5.md): the rookie sprints little (pro 0.35, all_star 1.0)
			Opp.CheckMinClosing = 6.0;   // lane A95 (R-0041 "rookie bots rarely check", CURVE-5.md): checks only from 6 m/s of closing (pro 2, all_star 2); -1 (never) before
			Opp.DrawJumpPct = 100; // 16:23: the rookie centre always jumps early (the human takes the opening touch)
			// Lane A206 (evolution 9, R-0067 point 1, BRAIN-9.md): rookie's bots are clumsy, not absent. Their pace (0.85 x red 0.80 = 0.68 of a mate's on the
			// regular rink: they never arrived, 2.4 s a match in their attacking third) is at least OppPace9. A later read (React9Frames 6) broke rookie's stop
			// window (the drill's 8.5 m stop past rookie's defender 88.5 %, bar 95; with pace 0.95 and no late read 100 %): not used.
			// Eased by execution instead (sweep R1 / R2, the novice on the regular rink, 200 a cell; as shipped with pace 0.95 alone 58.7 at 600): pace 0.9, the poke
			// after 20 frames in reach (10), the aim 6 deg wide (no aim cone), the shot from inside 11.5 m (21.5): 81.5. Each alone: 71.0 / 65.5 / 60.0 / 71.0.
			// The poke at 20 let law 3's straight charge through at rookie (59.5 %); 16: 46.0 %, 14: 4.5 % (the cell 79.5), 12: 0 % (76.5): 14.
			Opp.Hk.OppPace9 = 1.0;   // lane A217 (LADDER SET 3): 0.9 -> 1.0 through a person's hand (the newcomer 93 -> 88, 100; 0.95: 95): rookie's opponents skate at full pace and stay clumsy by aim, poke and reach. Before: 0.9
			Opp.Hk.EarlyLongShot9Frames = 600;   // lane A206 (wave 4): rookie's opponents shoot from beyond 15 m only after the match's first 10 s
			Opp.Hk.bScrumStay9 = true;   // lane A206 (wave 4): rookie's crease keepers stay back from a drop until the puck leaves the scrum (goals against him inside 10 s of a restart 11 -> 4 in 60)
			Opp.Hk.DropNoHit9Frames = 90;   // lane A206 (wave 3, EYE 1): rookie never hits in the 90 frames after a drop
			Opp.Hk.Poke9Frames = 14;
			Opp.Hk.AimError9Deg = 6.0;
			Opp.Hk.ShootExtra9M = 10.0;
			// R-0029 P2: speed 0.85 / red skill 0.75 (0.96 / 0.88 before, tuned against the scripted human); measured with lane A34's novice.
			// Stall 60: the stall rule is what lets a rookie shoot at all (SeasonTakes needs one AI shot per match).
			// Lane A70 (CURVE-2.md): red skill 0.75 -> 0.8, the novice 90.8 -> 85.8 % over 2,000 matches (speed 0.9 moved nothing).
			// Lane A95 (CURVE-5.md, 2,000 matches): red skill 0.8 -> 0.97 with the checks from 6 m/s and the sprint 0.2 (the novice 97.0 -> 84.8 at red 1.0, 600 matches); the
			// principles stay late and loose (0.6, 24 frames): tightening them to pro's took 3.5 points and is not what a rookie is.
			// Lane A189 (CURVE-12.md): red skill 0.97 -> 0.80 with the shot reach 25 -> 20 m (free skaters 15 % faster: the novice 71.2 -> 83.0, 600).
			FJamDifficultyProfile P{"rookie", 0.85, 0.80, 4.0, 25.0, 0.0, 60, Opp, 0.6};   // lane A46: mates pass to the open human in 0.6 of the chances (every chance before)
			P.MateSpeedScale = 1.0;   // lane A112 (R-0048 point 4): the human's mates skate at the human's pace (0.85 before)
			P.bTrueSpeeds = false;    // lane A193 (BRAIN-7.md): rookie's bots plan at skater.speed as before (its matches are main's, hash for hash)
			P.LargeSpeedScale = 0.9;   // R-0029: large-rink rookie offsets from the playtester grid (novice 85 %, 19:43); 1.0 / 0.93 before
			P.LargeRedSkill = 1.125;   // lane A217 (LADDER SET 3): 1.11 -> 1.125 through a person's hand (the newcomer on 120 x 60 90 as built; 1.17: 65; 1.22: 60, 100 a point). Before: 1.11.   // lane A189 (CURVE-12.md): 1.14 -> 1.11 with the shot reach 20 (the novice on 120 x 60 80.5 -> 85.0, 600, main 58af359f). Lane A162 (CURVE-9.md): 1.12 -> 1.14 (main a7d89871, after CONTACT-6 / MOVEMENT-6 / BRAIN-4, the closing press: the novice on 120 x 60 88.5 at 1.12, 83.8 at 1.14 (2,000)). Lane A133 (CURVE-7.md): 0.98 -> 1.12 with the poke 10 (the novice on 120 x 60: 99.5 at 0.98, 97.3 at 1.03, 91.3 at 1.08, 84.7 at 1.12, 75.7 at 1.16 (600)). Lane A112 (CURVE-6.md): 0.9 -> 0.98 (with the poke, the shot range and the mates at 1.0 the novice on 120 x 60: 94.9 at 0.9 (2,000), 93.3 at 0.93, 89.7 at 0.96, 77.7 at 1.02 (600)). Lane A95 (CURVE-5.md): 0.97 -> 0.9 (the novice on 120 x 60 with the vision, 2,000 each: 93.0 at 0.86, 89.0 at 0.89, 86.0 at 0.9, 75.1 at 0.92; 62.0 at 0.97 (600)). Lane A70: 0.97
			return P;
		}

		FJamDifficultyProfile MakeAllStar()
		{
			FJamBotSkill Opp;
			Opp.ReactionFrames = 0;
			Opp.AimErrorDeg = 0.0;
			Opp.ShootExtraM = 60.0;   // lane A112 (CURVE-6.md): 40 -> 60 (with the hunt 30 and the mates at 1.0: the good player 40.0 -> 32.0, 2,000)
			Opp.AimToleranceDeg = 20.0;
			Opp.LeadFrames = 60;
			Opp.bClearLane = true;
			Opp.PokeFrames = 0;   // lane A79 (R-0041, CURVE-3.md): 2 -> 0, all_star pokes the moment the puck is in reach (with the hunt, below)
			Opp.SweepReactFrames = 5;   // lane A51 (R-0034): all_star reads the carried puck 5 frames late (pro 8, the FJamBotSkill default)
			Opp.ShotChargeFrames = 10;   // lane A95 (CURVE-5.md): 18 -> 10, the pro wind-up (the longer wind-up lost shots to the good player's stick). Lane A31 (B-to-A-0024): 18
			Opp.bLift = true;
			Opp.SprintShare = 1.0;   // lane A95 (R-0045 law 4, R-0041 "hunts", CURVE-5.md): all_star sprints on every chase
			Opp.LiftCooldownFrames = 45;   // lane A95 (B-to-A-0037 point 3): all_star lifts again after 0.75 s (pro 1.5 s; rookie never lifts)
			Opp.bPassOut = true;
			Opp.bReadLanes = true;
			Opp.bSeekPickups = true;
			Opp.DrawPressPct = 0;  // 16:18: no early press; the centre jumps early in half the faceoffs instead (faceoffs without a human touch 2 per 40 matches)
			Opp.DrawJumpPct = 75;   // 16:25 worktree sweep: faceoffs without a human touch at most 2 per 40 matches
			Opp.DrawPressFrames = 8;
			Opp.ForecheckYieldFrames = -1;   // lane A95 (CURVE-5.md): all_star never gives the puck up to the human's forecheck (Director 15:16: 12)
			Opp.bIntercept = true;
			Opp.bUseAimCone = true;
			Opp.bOneTimer = true;   // R-0029 point 4 (lane A39): all_star bots use the one-timer and the deke; pro the one-timer (ProOppSkill); rookie neither
			Opp.bDeke = true;
			Opp.CheckMinClosing = 2.0;   // lane A95 (CURVE-5.md): 3 -> 2 m/s (with A92's model a low-speed press stumbles). Before:   // R-0031 point 2 (lane A45): all_star body-checks the carrier (front or side, never from behind); rookie keeps -1 (never). Lane A70: 5 -> 3 (knockdowns of the good playtester 2.73 -> 3.00 a match at speed 1.3, its win share 26.5 -> 26.8)
			Opp.HuntRadiusM = 30.0;   // lane A112 (CURVE-6.md): 20 -> 30 m. Lane A95 (R-0041 "all_star hunts", CURVE-5.md): 10 -> 20 m. Before: 10.   // lane A79 (R-0041 point 1, CURVE-3.md): the support goes at an opposing carrier within 10 m (good 26.8 -> 21.4, regular 13.3 -> 11.8 at speed 1.3)
			// Lane A94 (R-0045 law 2): all_star executes the hockey principles at once and fully (pro: ProHockeySense, share 0.85, 8 frames late)
			Opp.Hk = ProHockeySense();
			Opp.Hk.ShapeShare = 1.0;
			Opp.Hk.LateFrames = 0;
			Opp.Hk.bReadHumanPressure = true;   // all_star passes away from the human's forecheck too (pro and rookie leave it to forecheck_yield_frames)
			Opp.Hk.BetterByM = 12.0;     // lane A95 (CURVE-5.md): passes to a better-placed teammate only when it is 12 m nearer the net (3 before) ...
			Opp.Hk.PressureSec = 0.3;    // ... and moves the puck under pressure only when it arrives inside 0.3 s (1.4 before; 0.5 read 27.9 at 2,000): all_star carries through the forecheck
			// Lane A153 (R-0058 point 1, BRAIN-4.md): all_star's presser stays on its Press job inside the hunt (30 m: before, it charged from there and the
			// stop-and-go's window sat at 10 to 12 m). The game teaches one stop distance at every level: 8 m, five stick lengths. Neutral: the tune
			// opp.hk_press_in_hunt=0 (brain4=0 and brain3=0 switch it off too). It stays off at pro: it breaks pro's drill (BRAIN-3.md section 6).
			Opp.Hk.bPressInHunt = true;
			// R-0029 pass 2 (with A31's charge): speed 1.08 (bots may push past 1, the sim clamps them at 1.5): the good playtester 30 % / 25 %
			// R-0029 with A39's payoffs on (one-timer, burst, deke): speed 1.15 brings the good playtester back to 23 % at 40 seeds (1.08 measured 38 %, 1.12 33 %); A39 section 9.
			// Lane A70 (CURVE-2.md, 2,000 matches per number): speed 1.15 -> 1.3, the good playtester 40.5 -> 26.5 % (1.2 34.5, 1.32 23.9, 1.4 14.8; checks from
			// 3 or 4 m/s and bot_react_frames 3 moved nothing).
			// Lane A79 (R-0041, CURVE-3.md): the hunt and the instant poke take the win rate, so speed comes back 1.3 -> 1.2 (good 27.0, regular 14.4, novice 3.4).
			// Lane A95 (CURVE-5.md, 2,000 matches): with the levers above red skill 1.0 -> 0.9 and speed 1.2 -> 1.4 (speed last, as the brief orders): the good
			// player 62.0 -> 25.8 at 600 matches; 27.9 at 2,000 (1.5: 30.7, saturated: the sim clamps a bot at 1.5 and pace costs stability).
			// Lane A154 (CURVE-8.md): speed 1.4 -> 1.45 on main 4cab387 (the good player 30.6 at 1.4, 26.9 at 1.45 (2,000); 1.5: 29.7 (600), A95's non-monotonic top;
			// red skill 0.85 / 0.95: 32.3 / 31.5, flat; law 3 at 1.45: 84.5 % from 11 m, 100 % from 12 m).
			FJamDifficultyProfile P{"all_star", 1.15, 0.9,   // lane A217 (LADDER SET 3): speed 1.45 -> 1.15 (with the dodge 0.2, the good player 4 -> 21 through a person's hand; 1.25: 9, 1.05: 40, 100 a point)
				 4.0, 25.0, 0.0, 60, Opp, 0.2};
			P.Opp.Hk.DropNoHit9Frames = 45;   // lane A206 (wave 3, EYE 1)
			P.Opp.Hk.EarlyLongShot9Frames = 600;   // lane A206 (wave 4): no shot from beyond 15 m in the match's first 10 s (Jam.Bot.PlayerBotWins: the first goal at pro fell at frames 358-364, the scrum's shot)
			P.Opp.Hk.Dodge9Share = 0.2;   // lane A217 (LADDER SET 3): 0.5 -> 0.2 with speed 1.45 -> 1.15 and the large rink's 1.47 -> 1.15 (all_star clumsier by execution would need its aim or poke, which Jam.Bot.DifficultyProfilesResolve / Hockey9.Neutral keep ordered and rookie's: the speed carries the set). Before: 0.5;
			P.MateSpeedScale = 1.0;   // lane A112 (R-0048 point 4): the opposing side's speed only; the human's mates skate at the human's pace (1.4 before: 15.5 against his 11.3 m/s)
			P.LargeSpeedScale = 1.15;   // lane A217 (LADDER SET 3): 1.47 -> 1.15 (the dodge 0.2 alone; with the aim / poke mix (the good player on 120 x 60 6 as built (300); mix + 1.37: 4, + 1.25: 26, + 1.15: 54, 100 a point). Before: lane A154 (CURVE-8.md): 1.42 -> 1.47 (main 4cab387: the good player on 120 x 60 30.3 at 1.42, 29.0 at 1.45, 27.3 at 1.47 (600)). Lane A133 (CURVE-7.md): 1.34 -> 1.42 (the good player on 120 x 60: 38.3 at 1.34, 33.8 at 1.38, 27.5 at 1.42 (600); all_star harder than pro there, R-0055 point 3). Lane A112 (CURVE-6.md): 1.22 -> 1.34 (the mates no longer share it; the good player on 120 x 60: 45.0 at 1.22, 37.3 at 1.27, 28.3 at 1.32 (600), 29.1 at 1.32 (2,000)). Lane A95 (CURVE-5.md): the good player on 120 x 60 at speed 1.4: 5.7 % (600), 1.25: 19.2 (2,000), 1.2: 32.3 (600)
			return P;   // lane A46: mates pass to the open human in 0.2 of the chances
		}

		void SetErr(char* Err, int ErrLen, const char* Msg, const char* Pair)
		{
			if (Err && ErrLen > 0)
			{
				std::snprintf(Err, static_cast<size_t>(ErrLen), "%s: %s", Msg, Pair);
			}
		}

		bool SetSkill(FJamBotSkill& K, const char* Key, double V)
		{
			if (std::strcmp(Key, "reaction_frames") == 0) { K.ReactionFrames = static_cast<int>(V); return true; }
			if (std::strcmp(Key, "aim_error_deg") == 0) { K.AimErrorDeg = V; return true; }
			if (std::strcmp(Key, "shoot_extra_m") == 0) { K.ShootExtraM = V; return true; }
			if (std::strcmp(Key, "aim_tolerance_deg") == 0) { K.AimToleranceDeg = V; return true; }
			if (std::strcmp(Key, "lead_frames") == 0) { K.LeadFrames = static_cast<int>(V); return true; }
			if (std::strcmp(Key, "intercept") == 0) { K.bIntercept = V != 0.0; return true; }
			if (std::strcmp(Key, "use_aim_cone") == 0) { K.bUseAimCone = V != 0.0; return true; }
			if (std::strcmp(Key, "block_shots") == 0) { K.bBlockShots = V != 0.0; return true; }
			if (std::strcmp(Key, "block_min_dist_m") == 0) { K.BlockMinDistM = V; return true; }
			if (std::strcmp(Key, "clear_lane") == 0) { K.bClearLane = V != 0.0; return true; }
			if (std::strcmp(Key, "poke_frames") == 0) { K.PokeFrames = static_cast<int>(V); return true; }
			if (std::strcmp(Key, "lift") == 0) { K.bLift = V != 0.0; return true; }
			if (std::strcmp(Key, "pass_out") == 0) { K.bPassOut = V != 0.0; return true; }
			if (std::strcmp(Key, "read_lanes") == 0) { K.bReadLanes = V != 0.0; return true; }
			if (std::strcmp(Key, "seek_pickups") == 0) { K.bSeekPickups = V != 0.0; return true; }
			if (std::strcmp(Key, "draw_jump_pct") == 0) { K.DrawJumpPct = static_cast<int>(V); return true; }
			if (std::strcmp(Key, "draw_press_pct") == 0) { K.DrawPressPct = static_cast<int>(V); return true; }
			if (std::strcmp(Key, "draw_press_frames") == 0) { K.DrawPressFrames = static_cast<int>(V); return true; }
			if (std::strcmp(Key, "guard_radius_m") == 0) { K.GuardRadiusM = V; return true; }
			if (std::strcmp(Key, "guard_range_m") == 0) { K.GuardRangeM = V; return true; }
			if (std::strcmp(Key, "carry_speed") == 0) { K.CarrySpeed = V; return true; }
			if (std::strcmp(Key, "forecheck_yield_frames") == 0) { K.ForecheckYieldFrames = static_cast<int>(V); return true; }
			if (std::strcmp(Key, "pass_to_human") == 0) { K.PassToHuman = V; return true; }   // lane A46: a 0..1 share (was 0 | 1)
			if (std::strcmp(Key, "shot_charge_frames") == 0) { K.ShotChargeFrames = static_cast<int>(V); return true; }   // lane A31
			if (std::strcmp(Key, "one_timer") == 0) { K.bOneTimer = V != 0.0; return true; }   // R-0029 point 4 (lane A39)
			if (std::strcmp(Key, "deke") == 0) { K.bDeke = V != 0.0; return true; }
			if (std::strcmp(Key, "check_min_closing") == 0) { K.CheckMinClosing = V; return true; }   // R-0031 point 2 (lane A45); -1 = never
			if (std::strcmp(Key, "check_from_behind") == 0) { K.bCheckFromBehind = V != 0.0; return true; }
			if (std::strcmp(Key, "cross_hold_closing") == 0) { K.CrossHoldClosing = V; return true; }   // lane A184: the bots' brace; -1 = never
			if (std::strcmp(Key, "hunt_radius_m") == 0) { K.HuntRadiusM = V; return true; }   // R-0041 point 1 (lane A79)
			// Lane A94 (R-0045 law 2): the hockey principles. hk_on 0 | 1 switches all four; the others tune one.
			if (std::strcmp(Key, "hk_on") == 0) { K.Hk.bCarryOrPass = K.Hk.bAttackShape = K.Hk.bDefenceShape = K.Hk.bTransition = V != 0.0; return true; }
			if (std::strcmp(Key, "hk_carry_or_pass") == 0) { K.Hk.bCarryOrPass = V != 0.0; return true; }
			// Lane A115 (BRAIN-2.md): the rules of evolution 2, one by one (brain2 switches all of them on both sides)
			if (std::strcmp(Key, "hk_pass_room") == 0) { K.Hk.bPassRoom = V != 0.0; return true; }
			if (std::strcmp(Key, "hk_support_human") == 0) { K.Hk.bSupportHuman = V != 0.0; return true; }
			if (std::strcmp(Key, "hk_chase_ahead") == 0) { K.Hk.bChaseAhead = V != 0.0; return true; }
			if (std::strcmp(Key, "hk_brake_meant") == 0) { K.Hk.bBrakeMeant = V != 0.0; return true; }
			if (std::strcmp(Key, "hk_carry_sprint") == 0) { K.Hk.bCarrySprint = V != 0.0; return true; }
			if (std::strcmp(Key, "hk_stop_cut") == 0) { K.Hk.bStopCut = V != 0.0; return true; }
			if (std::strcmp(Key, "hk_gap_control") == 0) { K.Hk.bGapControl = V != 0.0; return true; }
			if (std::strcmp(Key, "hk_read_shield") == 0) { K.Hk.bReadShield = V != 0.0; return true; }
			if (std::strcmp(Key, "hk_round_lead_s") == 0) { K.Hk.RoundLeadS = V; return true; }   // lane A138
			if (std::strcmp(Key, "hk_round_max_mps") == 0) { K.Hk.RoundMaxMps = V; return true; }
			if (std::strcmp(Key, "hk_spin_end_share") == 0) { K.Hk.SpinEndShare = V; return true; }
			// Lane A134 (BRAIN-3.md): the rules of evolution 3, one by one (brain3 switches all of them on both sides)
			if (std::strcmp(Key, "hk_yield_arrive_s") == 0) { K.Hk.YieldArriveS = V; return true; }
			if (std::strcmp(Key, "hk_backcheck_mps") == 0) { K.Hk.BackcheckMps = V; return true; }
			if (std::strcmp(Key, "hk_step_up_m") == 0) { K.Hk.StepUpM = V; return true; }
			if (std::strcmp(Key, "hk_mate_check_closing") == 0) { K.Hk.MateCheckClosing = V; return true; }
			if (std::strcmp(Key, "hk_mate_check_max_team") == 0) { K.Hk.MateCheckMaxTeam = static_cast<int>(V); return true; }
			if (std::strcmp(Key, "hk_shot_max_angle_deg") == 0) { K.Hk.ShotMaxAngleDeg = V; return true; }
			if (std::strcmp(Key, "hk_pincer_m") == 0) { K.Hk.PincerM = V; return true; }
			// Lane A153 (BRAIN-4.md): the rules of evolution 4 (brain4 switches them, and a level's hk_press_in_hunt, off)
			if (std::strcmp(Key, "hk_mate_finish_m") == 0) { K.Hk.MateFinishM = V; return true; }
			if (std::strcmp(Key, "hk_carry_clock_s") == 0) { K.Hk.CarryClockS = V; return true; }
			// Lane A167 (BRAIN-5.md): the rules of evolution 5 (brain5 switches them off)
			if (std::strcmp(Key, "hk_avoid_downed_m") == 0) { K.Hk.AvoidDownedM = V; return true; }
			if (std::strcmp(Key, "hk_press_three") == 0) { K.Hk.bPressThree = V != 0.0; return true; }
			if (std::strcmp(Key, "hk_press_commit_m") == 0) { K.Hk.PressCommitM = V; return true; }
			if (std::strcmp(Key, "hk_press_three_commit_m") == 0) { K.Hk.PressThreeCommitM = V; return true; }
			if (std::strcmp(Key, "hk_avoid_downed_out") == 0) { K.Hk.AvoidDownedOut = V; return true; }
			if (std::strcmp(Key, "hk_press_retreat_cap") == 0) { K.Hk.PressRetreatCap = V; return true; }
			// Lane A181 (BRAIN-6.md): the rules of evolution 6 (brain6 switches them off)
			if (std::strcmp(Key, "hk_fresh_take_frames") == 0) { K.Hk.FreshTakeFrames = static_cast<int>(V); return true; }
			if (std::strcmp(Key, "hk_second_man_hunts") == 0) { K.Hk.bSecondManHunts = V != 0.0; return true; }
			if (std::strcmp(Key, "hk_cover_best_pass") == 0) { K.Hk.bCoverBestPass = V != 0.0; return true; }
			if (std::strcmp(Key, "hk_step_up_max_team") == 0) { K.Hk.StepUpMaxTeam = static_cast<int>(V); return true; }
			// Lane A193 (BRAIN-7.md): the rules of evolution 7 (brain7 switches them off)
			if (std::strcmp(Key, "hk_true_speed") == 0) { K.Hk.bTrueSpeed = V != 0.0; return true; }
			if (std::strcmp(Key, "hk_true_gap") == 0) { K.Hk.bTrueGap = V != 0.0; return true; }
			if (std::strcmp(Key, "hk_windup_brake") == 0) { K.Hk.bWindupLeadNoBrake = V != 0.0; return true; }   // lane A200 (CONTACT-12.md): no wind-up lead on a braking carrier
			// Lane A202 (BRAIN-8.md): the rules of evolution 8 (brain8 switches them on and off)
			if (std::strcmp(Key, "hk_downed_leave_frames") == 0) { K.Hk.DownedLeaveFrames = static_cast<int>(V); return true; }
			if (std::strcmp(Key, "hk_long_pass_m") == 0) { K.Hk.LongPassM = V; return true; }
			if (std::strcmp(Key, "hk_own_zone_turn") == 0) { K.Hk.bOwnZoneTurn = V != 0.0; return true; }
			if (std::strcmp(Key, "hk_clump_frames") == 0) { K.Hk.ClumpFrames = static_cast<int>(V); return true; }
			if (std::strcmp(Key, "hk_true_lead") == 0) { K.Hk.bTrueLead = V != 0.0; return true; }   // lane A202 item 4 (off; not in brain8)
			if (std::strcmp(Key, "hk_mate_true_scale") == 0) { K.Hk.bMateTrueScale = V != 0.0; return true; }

			// Lane A206 (BRAIN-9.md): the rules of evolution 9 (brain9 switches them on and off)
			if (std::strcmp(Key, "hk_shoot_extra9_m") == 0) { K.Hk.ShootExtra9M = V; return true; }
			if (std::strcmp(Key, "hk_aim_cone9") == 0) { K.Hk.bAimCone9 = V != 0.0; return true; }
			if (std::strcmp(Key, "hk_opp_pace9") == 0) { K.Hk.OppPace9 = V; return true; }
			if (std::strcmp(Key, "hk_aim_error9_deg") == 0) { K.Hk.AimError9Deg = V; return true; }
			if (std::strcmp(Key, "hk_react9_frames") == 0) { K.Hk.React9Frames = static_cast<int>(V); return true; }
			if (std::strcmp(Key, "hk_net_front9") == 0) { K.Hk.bNetFront9 = V != 0.0; return true; }
			if (std::strcmp(Key, "hk_chip_up9") == 0) { K.Hk.bChipUp9 = V != 0.0; return true; }
			if (std::strcmp(Key, "hk_drive_net9_m") == 0) { K.Hk.DriveNet9M = V; return true; }
			if (std::strcmp(Key, "hk_pressure9_s") == 0) { K.Hk.Pressure9S = V; return true; }
			if (std::strcmp(Key, "hk_drop_no_hit9_frames") == 0) { K.Hk.DropNoHit9Frames = static_cast<int>(V); return true; }
			if (std::strcmp(Key, "hk_pass_care9") == 0) { K.Hk.bPassCare9 = V != 0.0; return true; }
			if (std::strcmp(Key, "hk_net_never_empty9") == 0) { K.Hk.bNetNeverEmpty9 = V != 0.0; return true; }
			if (std::strcmp(Key, "hk_early_long_shot9_frames") == 0) { K.Hk.EarlyLongShot9Frames = static_cast<int>(V); return true; }
			if (std::strcmp(Key, "hk_scrum_stay9") == 0) { K.Hk.bScrumStay9 = V != 0.0; return true; }
			if (std::strcmp(Key, "hk_meet_line9") == 0) { K.Hk.bMeetLine9 = V != 0.0; return true; }
			if (std::strcmp(Key, "hk_crease_keeper9") == 0) { K.Hk.bCreaseKeeper9 = V != 0.0; return true; }
			if (std::strcmp(Key, "hk_defend_team9") == 0) { K.Hk.bDefendTeam9 = V != 0.0; return true; }
			if (std::strcmp(Key, "hk_dodge9_share") == 0) { K.Hk.Dodge9Share = V; return true; }
			if (std::strcmp(Key, "hk_drive_first9") == 0) { K.Hk.bDriveFirst9 = V != 0.0; return true; }
			if (std::strcmp(Key, "hk_shot_lane9") == 0) { K.Hk.bShotLane9 = V != 0.0; return true; }
			if (std::strcmp(Key, "hk_mark_man9") == 0) { K.Hk.bMarkMan9 = V != 0.0; return true; }
			if (std::strcmp(Key, "hk_ahead_weak9") == 0) { K.Hk.bAheadWeak9 = V != 0.0; return true; }
			if (std::strcmp(Key, "hk_meet_pass9") == 0) { K.Hk.bMeetPass9 = V != 0.0; return true; }
			if (std::strcmp(Key, "hk_poke9_frames") == 0) { K.Hk.Poke9Frames = static_cast<int>(V); return true; }
			if (std::strcmp(Key, "hk_one_timer9") == 0) { K.Hk.bOneTimer9 = V != 0.0; return true; }
			if (std::strcmp(Key, "hk_shot_charge9_frames") == 0) { K.Hk.ShotCharge9Frames = static_cast<int>(V); return true; }

			if (std::strcmp(Key, "hk_mate_drive_m") == 0) { K.Hk.MateDriveM = V; return true; }
			if (std::strcmp(Key, "hk_screen_frames") == 0) { K.Hk.ScreenFrames = static_cast<int>(V); return true; }
			if (std::strcmp(Key, "hk_press_in_hunt") == 0) { K.Hk.bPressInHunt = V != 0.0; return true; }
			if (std::strcmp(Key, "hk_mate_stick_frames") == 0) { K.Hk.MateStickFrames = static_cast<int>(V); return true; }
			if (std::strcmp(Key, "hk_attack_shape") == 0) { K.Hk.bAttackShape = V != 0.0; return true; }
			if (std::strcmp(Key, "hk_defence_shape") == 0) { K.Hk.bDefenceShape = V != 0.0; return true; }
			if (std::strcmp(Key, "hk_transition") == 0) { K.Hk.bTransition = V != 0.0; return true; }
			if (std::strcmp(Key, "hk_share") == 0) { K.Hk.ShapeShare = V; return true; }
			if (std::strcmp(Key, "hk_late_frames") == 0) { K.Hk.LateFrames = static_cast<int>(V); return true; }
			if (std::strcmp(Key, "hk_pressure_s") == 0) { K.Hk.PressureSec = V; return true; }
			if (std::strcmp(Key, "hk_min_carry_frames") == 0) { K.Hk.MinCarryFrames = static_cast<int>(V); return true; }
			if (std::strcmp(Key, "hk_better_by_m") == 0) { K.Hk.BetterByM = V; return true; }
			if (std::strcmp(Key, "hk_read_human_pressure") == 0) { K.Hk.bReadHumanPressure = V != 0.0; return true; }
			if (std::strcmp(Key, "lift_cooldown_frames") == 0) { K.LiftCooldownFrames = static_cast<int>(V); return true; }   // lane A95
			if (std::strcmp(Key, "sprint_share") == 0) { K.SprintShare = V; return true; }   // lane A95 (R-0045 law 4): the side's chase sprint share
			return false;
		}
	}
	using namespace DifficultyLocal;

	const FJamDifficultyProfile& GetDifficultyProfile(EDifficulty Level)
	{
		static const FJamDifficultyProfile Rookie = MakeRookie();
		static const FJamDifficultyProfile Pro = MakePro();
		static const FJamDifficultyProfile AllStar = MakeAllStar();
		switch (Level)
		{
		case EDifficulty::Rookie: return Rookie;
		case EDifficulty::AllStar: return AllStar;
		default: return Pro;
		}
	}

	const char* DifficultyName(EDifficulty Level)
	{
		return GetDifficultyProfile(Level).Name;
	}

	bool ParseDifficulty(const char* Name, EDifficulty& Out)
	{
		if (!Name) { return false; }
		if (std::strcmp(Name, "rookie") == 0) { Out = EDifficulty::Rookie; return true; }
		if (std::strcmp(Name, "pro") == 0) { Out = EDifficulty::Pro; return true; }
		if (std::strcmp(Name, "all_star") == 0) { Out = EDifficulty::AllStar; return true; }
		return false;
	}

	void ApplyDifficultyProfile(const FJamDifficultyProfile& Profile, FJamAIParams& P)
	{
		P.SpeedScale = Profile.SpeedScale;
		P.MateSpeedScale = Profile.MateSpeedScale;   // lane A112
		P.RedSkill = Profile.RedSkill;
		P.YieldMarginM = Profile.YieldMarginM;
		P.YieldRadiusM = Profile.YieldRadiusM;
		P.HoldRadiusM = Profile.HoldRadiusM;
		P.StallFrames = Profile.StallFrames;
		P.Opp = Profile.Opp;
		P.Mate = FJamBotSkill();
		P.Mate.PassToHuman = Profile.MatesPassShare;
		P.Mate.Hk = ProHockeySense();   // lane A94 (R-0045 law 2): the human's teammates play the pro hockey sense at every level
		// Lane A138: the human's mates go round a shielding body at any speed (lane A115's rule; mate.hk_round_max_mps). The cap of 3 m/s is the opposing
		// side's: it is what lets the human's stop-and-go beat a defender (law 3). A mate that only chased an opposing carrier won fewer pucks: on the big
		// ice 46.3 % of pro matches had a 30 s stretch without a human touch with the cap on both sides, 39 % with the mates' off (600 seeds; INTEGRATION.md).
		P.Mate.Hk.RoundMaxMps = 0.0;
		// Lane A134 (track Q2, evolution 3; BRAIN-3.md): the human's side takes a kept puck back, and a bot shoots from where a shot can score.
		// No level's number moves: the rules are the same at every level (the tune key brain3=0 gives back lane A138's tree).
		SetEvolution3(P.Opp.Hk, true, false);
		SetEvolution3(P.Mate.Hk, true, true);
		SetEvolution4(P.Opp.Hk, true, false);   // lane A153 (track Q2, evolution 4; BRAIN-4.md): on leaves a level's bPressInHunt as its profile set it
		SetEvolution4(P.Mate.Hk, true, true);
		SetEvolution5(P.Opp.Hk, true);   // lane A167 (track Q2, evolution 5; BRAIN-5.md): every value neutral as shipped
		SetEvolution5(P.Mate.Hk, true);
		SetEvolution6(P.Opp.Hk, true);   // lane A181 (track Q2, evolution 6; BRAIN-6.md): every value neutral as shipped
		SetEvolution6(P.Mate.Hk, true);
		SetEvolution7(P.Opp.Hk, Profile.bTrueSpeeds);   // lane A193 (track Q2, evolution 7; BRAIN-7.md): the brain plans with the true speeds (skater.free_speed_mult); not at rookie
		SetEvolution7(P.Mate.Hk, Profile.bTrueSpeeds);
		ShipEvolution8(P.Opp.Hk);   // lane A202 (track Q2, evolution 8; BRAIN-8.md): the four rules as kEvo8Ship* say (all on since 16:52)
		ShipEvolution8(P.Mate.Hk);
		SetEvolution9(P.Opp.Hk, true, false);   // lane A206 (track Q2, evolution 9; BRAIN-9.md): ships on; brain9=0 (and every older brainN=0) is evolution 8
		SetEvolution9(P.Mate.Hk, true, true);
		P.Mate.Hk.bScrumStay9 = P.Opp.Hk.bScrumStay9;   // lane A206 (wave 4): the scrum's stay-back is the level's, both sides (rookie)
		// Lane A189 (CURVE-12.md): a level's own step-up distance survives the evolutions (SetEvolution3 zeroes the opposing side's StepUpM, a rule of the
		// human's side there). With hk_second_man_hunts and hk_step_up_max_team (kept by SetEvolution6 on) it is all_star's brain dial (BRAIN-6.md). 0 = none (every level today).
		if (Profile.Opp.Hk.StepUpM > 0.0) { P.Opp.Hk.StepUpM = Profile.Opp.Hk.StepUpM; }
		P.Mate.SprintShare = ProOppSkill().SprintShare;   // lane A95 (R-0045 law 4): the human's teammates sprint as pro bots do at every level
	}

	const char* PreA95Tune(EDifficulty Level, bool bLargeRink)
	{
		switch (Level)
		{
		case EDifficulty::Rookie: return bLargeRink
			? "brain2=0;sprint=-1;opp.sprint_share=0;mate.sprint_share=0;opp.lift_cooldown_frames=0;red_skill=0.97;opp.check_min_closing=-1;opp.poke_frames=-1;opp.shoot_extra_m=5;mate_speed_scale=0"
			: "brain2=0;sprint=-1;opp.sprint_share=0;mate.sprint_share=0;opp.lift_cooldown_frames=0;red_skill=0.8;opp.check_min_closing=-1;opp.poke_frames=-1;opp.shoot_extra_m=5;mate_speed_scale=0";
		case EDifficulty::AllStar: return "brain2=0;sprint=-1;opp.sprint_share=0;mate.sprint_share=0;opp.lift_cooldown_frames=0;speed_scale=1.2;red_skill=1.0;opp.shot_charge_frames=18;"
			"opp.forecheck_yield_frames=12;opp.check_min_closing=3;opp.hunt_radius_m=10;opp.hk_better_by_m=3;opp.hk_pressure_s=1.4;opp.shoot_extra_m=40;mate_speed_scale=0";
		default: return bLargeRink
			? "brain2=0;sprint=-1;opp.sprint_share=0;mate.sprint_share=0;opp.lift_cooldown_frames=0;red_skill=0.97;opp.shoot_extra_m=13;opp.hunt_radius_m=0;opp.check_min_closing=4;opp.poke_frames=6;opp.hk_pressure_s=1.4;opp.hk_better_by_m=3;mate_speed_scale=0"
			: "brain2=0;sprint=-1;opp.sprint_share=0;mate.sprint_share=0;opp.lift_cooldown_frames=0;red_skill=0.95;opp.shoot_extra_m=13;opp.hunt_radius_m=0;opp.check_min_closing=4;opp.poke_frames=6;opp.hk_pressure_s=1.4;opp.hk_better_by_m=3;mate_speed_scale=0";
		}
	}

	bool ApplyDifficultyTune(const char* Text, FJamAIParams& P, char* Err, int ErrLen)
	{
		const char* Cur = Text;
		char Pair[160];
		while (Cur && *Cur)
		{
			const char* Start = Cur;
			const char* End = std::strchr(Cur, ';');
			const size_t Len = End ? static_cast<size_t>(End - Cur) : std::strlen(Cur);
			Cur = End ? End + 1 : nullptr;
			if (Len == 0) { continue; }
			if (Len >= sizeof(Pair)) { SetErr(Err, ErrLen, "pair too long", ""); return false; }
			std::memcpy(Pair, Start, Len);
			Pair[Len] = 0;
			char* Eq = std::strchr(Pair, '=');
			if (!Eq) { SetErr(Err, ErrLen, "no '=' in pair", Pair); return false; }
			*Eq = 0;
			char* NumEnd = nullptr;
			const double V = std::strtod(Eq + 1, &NumEnd);
			if (NumEnd == Eq + 1 || *NumEnd != 0) { *Eq = '='; SetErr(Err, ErrLen, "not a number", Pair); return false; }
			const char* Key = Pair;
			bool bOk = true;
			// lane A206: every brain switch at 0 also switches evolution 9 off (its rules stand on all of them)
			if (std::strncmp(Key, "brain", 5) == 0 && V == 0.0) { SetEvolution9(P.Opp.Hk, false, false); SetEvolution9(P.Mate.Hk, false, true); }
			if (std::strncmp(Key, "opp.", 4) == 0) { bOk = SetSkill(P.Opp, Key + 4, V); }
			else if (std::strncmp(Key, "mate.", 5) == 0) { bOk = SetSkill(P.Mate, Key + 5, V); }
			else if (std::strcmp(Key, "speed_scale") == 0) { P.SpeedScale = V; }
			else if (std::strcmp(Key, "red_skill") == 0) { P.RedSkill = V; }
			else if (std::strcmp(Key, "mate_speed_scale") == 0) { P.MateSpeedScale = V; }   // lane A112 (R-0048 point 4): 0 = speed_scale
			else if (std::strcmp(Key, "yield_margin_m") == 0) { P.YieldMarginM = V; }
			else if (std::strcmp(Key, "yield_radius_m") == 0) { P.YieldRadiusM = V; }
			else if (std::strcmp(Key, "hold_radius_m") == 0) { P.HoldRadiusM = V; }
			else if (std::strcmp(Key, "stall_frames") == 0) { P.StallFrames = static_cast<int>(V); }
			else if (std::strcmp(Key, "brain2") == 0)   // lane A115: 0 = the brain of evolution 1 (and with it evolution 3, which stands on it: lane A134)
			{
				SetEvolution2(P.Opp.Hk, V != 0.0); SetEvolution2(P.Mate.Hk, V != 0.0);
				if (V == 0.0) { SetEvolution3(P.Opp.Hk, false, false); SetEvolution3(P.Mate.Hk, false, true); SetEvolution4(P.Opp.Hk, false, false); SetEvolution4(P.Mate.Hk, false, true); SetEvolution5(P.Opp.Hk, false); SetEvolution5(P.Mate.Hk, false); SetEvolution6(P.Opp.Hk, false); SetEvolution6(P.Mate.Hk, false); SetEvolution7(P.Opp.Hk, false); SetEvolution7(P.Mate.Hk, false); SetEvolution8(P.Opp.Hk, false); SetEvolution8(P.Mate.Hk, false); }
			}
			else if (std::strcmp(Key, "brain3") == 0)   // lane A134: 0 = lane A138's tree (and with it evolution 4: lane A153)
			{
				SetEvolution3(P.Opp.Hk, V != 0.0, false); SetEvolution3(P.Mate.Hk, V != 0.0, true);
				if (V == 0.0) { SetEvolution4(P.Opp.Hk, false, false); SetEvolution4(P.Mate.Hk, false, true); SetEvolution5(P.Opp.Hk, false); SetEvolution5(P.Mate.Hk, false); SetEvolution6(P.Opp.Hk, false); SetEvolution6(P.Mate.Hk, false); SetEvolution7(P.Opp.Hk, false); SetEvolution7(P.Mate.Hk, false); SetEvolution8(P.Opp.Hk, false); SetEvolution8(P.Mate.Hk, false); }
			}
			else if (std::strcmp(Key, "brain9") == 0) { SetEvolution9(P.Opp.Hk, V != 0.0, false); SetEvolution9(P.Mate.Hk, V != 0.0, true); }   // lane A206: 0 = evolution 8 as shipped
			else if (std::strcmp(Key, "brain8") == 0) { SetEvolution8(P.Opp.Hk, V != 0.0); SetEvolution8(P.Mate.Hk, V != 0.0); }   // lane A202: 0 = evolution 7, 1 = every rule of evolution 8 on
			else if (std::strcmp(Key, "brain7") == 0) { SetEvolution7(P.Opp.Hk, V != 0.0); SetEvolution7(P.Mate.Hk, V != 0.0); if (V == 0.0) { SetEvolution8(P.Opp.Hk, false); SetEvolution8(P.Mate.Hk, false); } }   // lane A193: 0 = evolution 6
			else if (std::strcmp(Key, "brain6") == 0) { SetEvolution6(P.Opp.Hk, V != 0.0); SetEvolution6(P.Mate.Hk, V != 0.0); if (V == 0.0) { SetEvolution7(P.Opp.Hk, false); SetEvolution7(P.Mate.Hk, false); SetEvolution8(P.Opp.Hk, false); SetEvolution8(P.Mate.Hk, false); } }   // lane A181: 0 = evolution 5
			else if (std::strcmp(Key, "brain5") == 0) { SetEvolution5(P.Opp.Hk, V != 0.0); SetEvolution5(P.Mate.Hk, V != 0.0); if (V == 0.0) { SetEvolution6(P.Opp.Hk, false); SetEvolution6(P.Mate.Hk, false); SetEvolution7(P.Opp.Hk, false); SetEvolution7(P.Mate.Hk, false); SetEvolution8(P.Opp.Hk, false); SetEvolution8(P.Mate.Hk, false); } }   // lane A167: 0 = evolution 4
			else if (std::strcmp(Key, "brain4") == 0) { SetEvolution4(P.Opp.Hk, V != 0.0, false); SetEvolution4(P.Mate.Hk, V != 0.0, true); if (V == 0.0) { SetEvolution5(P.Opp.Hk, false); SetEvolution5(P.Mate.Hk, false); SetEvolution6(P.Opp.Hk, false); SetEvolution6(P.Mate.Hk, false); SetEvolution7(P.Opp.Hk, false); SetEvolution7(P.Mate.Hk, false); SetEvolution8(P.Opp.Hk, false); SetEvolution8(P.Mate.Hk, false); } }   // lane A153: 0 = evolution 3 (all_star's presser hunts again)
			else if (std::strcmp(Key, "sprint") == 0) { P.SprintShare = V; }   // lane A95: as game.ai.sprint (both sides; -1 = the levels' shares)
			else if (std::strcmp(Key, "guard_range_m") == 0) { P.GuardRangeM = V; P.Opp.GuardRangeM = V; P.Mate.GuardRangeM = V; }   // both sides (opp.* / mate.* for one)
			else if (std::strcmp(Key, "guard_radius_m") == 0) { P.GuardRadiusM = V; P.Opp.GuardRadiusM = V; P.Mate.GuardRadiusM = V; }
			else { bOk = false; }
			if (!bOk) { *Eq = '='; SetErr(Err, ErrLen, "unknown tune key", Pair); return false; }
		}
		return true;
	}
}
