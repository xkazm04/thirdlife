# Juice day and night, 27-28 Nov 2026 (08:30 -> 07:45): editor fixes, and A/B spikes for the five asks

**The owner (27 Nov ~08:00, leaving for 24 h), verbatim:** "I will be off for 24 hours, keep the effort from last night,
for decision questions try to create spikes and evaluate both, I will get into this tomorrow and evaluate together"

**No handshake** (the owner is away). The Director carries last night's handshake over: 5 Opus agents at most, RAM up to
80 %, no CPU cap, editor first and then by hand, land and push. The five asks of last night's verdict
(`docs/shifts/2026-11-27-night/VERDICT.md`, "Asks") are decision questions, so each becomes a **spike with two arms**.
Both arms are built and measured the same way, and both are kept for the owner to play. Nothing is decided for the owner.

## Another session runs today
The Home sandbox session runs its own day shift (`docs/shifts/2026-11-27-day/`, lanes LP-look in `d27-look` and four research
lanes). Its claim is `day-2026-11-27-sandbox` in `.claude/sessions.json`: `engine/kernel/world/build/**`, the walker,
`toon_cel`/`water_cel` shaders, `foreman/prompts/world_edit*`, `foreman/src/world_edit*`, `contracts/BUILD.md`,
`docs/research/sandbox/**`, selftest blocks 768-779. This shift never edits those. Both sessions land through
`.claude/worktrees/d25-main` (branch main): stage per file, check `git status` before every merge.
This shift's claim is `juice-day-2026-11-27` (exact foreman/src files, the planner/builder prompts, `engine/ui/create/**`,
`engine/cores/rink/**`, `engine/templates/rink_game/**`, this folder). Selftest blocks: T 800-809, spikes 810-819.

## Lanes
| Lane | What | Model | Tree / branch | Lands |
|---|---|---|---|---|
| T-editor | Lane T's queue: a rivals sentence reaches every bot package; a hand-off from a drawing package reaches the cartridge; the builder reads the cartridge's keys before "no key"; a new attack lands in the bot run; banners mid-screen; every balance note shown | Opus | d25-hard-a / d27-tofu | main, per round |
| S1-bots | Ask 1: should a new move tell the bots by default? A = the Planner adds "bots use it and answer it" by default; B = as now (the person writes a second sentence) | Opus | A d25-court / d27-sp-bots, B d27-sp-bots-b | held: both arms on branches |
| S2-juice | Ask 2: a juice pass for every new ability? A = automatic on every new ability; B = a "make it juicy" choice in Create, run only when picked | Opus | A d25-robot / d27-sp-juice, B d27-sp-juice-b | held |
| S4-core | Ask 4: a C++ lane for rink-core bots? A = a native core patch (bots use cartridge abilities, a dive block); B = no C++ (the pack drives the bots' ability use) | Opus | A d25-arsenal / d27-sp-core, B d27-sp-core-b | held |
| S35-packs | Asks 3 and 5, on the packs, by the editor as a person: 3A clean the old bends (biplane test pilot, karts reversal rule) vs 3B leave; 5A accept shield's `bot_call` change vs 5B bots hold big moves while a call charges | Opus | d25-biplane / d27-sp-packs | packs + menu rows for every arm |
| queued JB-back | The hand juice back as ONE sentence each (J4b's method) for robots, shield wall and Arsenal, after T's routing fixes land | Opus | d25-shield / d27-back | main (docs) + menu rows |

When a lane finishes and time remains, the Director re-dispatches inside this scope: JB-back first, then T rounds on new
findings, then a second crazy ability per game through the editor (the same juice standard).

## Spike rules (S lanes)
- Same base (main 8be26d61), same jobs (copies), same sentences, same seeds and the same measures for both arms.
- Each arm ends with something the owner can play: a pack path and a menu title (or, for a code arm the main exe cannot
  run, an exe from its branch), a clip of 30 s or less, and its cost (time, tokens, lines changed, risk to other games).
- `SPIKE.md` in the lane folder: the question in the owner's words, the arms, the test, a results table (A vs B), what
  each arm broke or risks, how to play each, and the lane's recommendation **separately** at the end. The owner decides.
- The Director commits each code arm on its own branch (`d27-sp-*`, `d27-sp-*-b`) and pushes the branches. Nothing from
  a spike's code merges to main today. Docs (SPIKE.md, stills, clips) land on main.

## Times
- 08:30 launch T, S1, S2, S4, S35. The full tier on main (`d25-kart` at 8be26d61, NOT RUN last night) runs first.
- Standups every 2 hours at :47 (09:47 ... 05:47). Lanes also send a message when landable.
- 06:15 (28 Nov) verdict: final landings; on main the fast tier, npm test, the touched blocks and the full tier; the exe;
  menu rows; VERDICT.md and the page. Push by 07:45.

## Landing and pushing
- T and JB-back land on main through d25-main, verified by the Director on the merged tree (fast tier, foreman npm test,
  create., one real job each round).
- **Push rule (after last night's slip):** push main only when every commit in `origin/main..main` is this shift's, or
  the other session has said yes. Otherwise the push waits, and the verdict says why.
- Menu rows (`dungeons.user.json`) and `.tl/proof-games/` copies are Director-only.

## The machine
- RAM at most 80 %, disk floor 12 GB: `bash C:/Users/kazda/kiro/third-life/.claude/worktrees/d25-main/docs/shifts/2026-11-27-night/tools/room.sh --wait` before every heavy step.
- 08:05: RAM 33 GB free of 63, disk 94 GB free, Godot 0.

## Launched (27 Nov 08:20)
| Lane | Model | Tree / branch | Agent |
|---|---|---|---|
| T-editor | Opus | d25-hard-a / d27-tofu | afc8d4a043aaaba2c |
| S1-bots | Opus | d25-court / d27-sp-bots, d27-sp-bots-b | a135346cf9707fbec |
| S2-juice | Opus | d25-robot / d27-sp-juice, d27-sp-juice-b | a6501167640509a75 |
| S4-core | Opus | d25-arsenal / d27-sp-core, d27-sp-core-b | aa817277ec7862b99 |
| S35-packs | Opus | d25-biplane / d27-sp-packs | a59bff4e2efa2b504 |
- Timers: standups cron 924acbe6 (every 2 h at :47; the scheduler's offset puts the first at 09:17); verdict cron e3c0a5a1 (28 Nov 06:13, one-shot).
- The full tier on main 8be26d61 runs in d25-kart (detached), log `.tl/d27-full.log`.
- ~10:05: S4-core done (arms committed: d27-sp-core 4490f92a, d27-sp-core-b f2ebac62, pushed). JB-back launched in its slot: Opus, d25-shield / d27-back, agent ae071b1603133b2f6. T got S4/S35 findings as items 7-9 (rules.json scope, exe crash on a refused rules file, a frozen measure must be said).
- 11:16: J2nd launched (second crazy ability for karts, biplane, half-court through the fixed editor; Opus, d25-kart / d27-second).
- 16:14: J2b launched (second crazy ability for robots and shield wall; Opus, d25-biplane / d27-second-b). JB-back and S4 done; S2, S35 done earlier.
- 19:30: T2-editor (d25-court / d27-tofu2: items 23, 24, 26-28, 31, 32) and N-newcomer (d27-newc / d27-newcomer: a newcomer's first minute in robots, shield, Arsenal) launched. T keeps 25, 29, 33+40, 34, 35, 37-39.
- 21:35: lane T hung twice (15:34-19:20, 19:23-21:20); its round 5 landed by the Director (5e5da87a). T3-editor launched (fresh agent, d25-hard-a): items 34, 35, 37-39, 43-45; 30 and 36 as write-ups.
