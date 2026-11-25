---
name: shift
description: Plan and run a long Third Life work shift (a night or a day) with parallel builders. Reads the campaign state (docs/shifts/STATE.md, git, worktrees, claims, the spark ledger, memory), shows the owner a short state brief, handshakes the scope, the builder count and the Opus/Codex mix with them, writes the shift plan, then launches lanes and runs them with report-based standups (lanes write standup lines; the Director reads them on a timer, lands green work, re-dispatches) and ends with a verdict report the owner reads in the morning. Invoke with /shift (plan + launch now), /shift night [HH:MM start] [HH:MM land-by], /shift standup, /shift verdict, /shift morning, /shift status.
---

# /shift: a long shift of parallel builders, with standups and verdicts

> The owner decides the scope and judges by hand and eye. The Director turns that into lanes, keeps them honest overnight,
> lands what is proven, and hands back a verdict report the owner can act on in five minutes.

Everything that matters lives in tracked files, never only in a conversation:
- **`docs/shifts/STATE.md`**: the campaign memory. `## Now` (focus, next 3), open owner verdicts, the backlog, the
  decisions log, the shift log (one entry per shift).
- **`docs/shifts/<YYYY-MM-DD>-<night|day>/`**: one folder per shift.
  - `PLAN.md`: the agreed scope, the lanes, the times, the landing rule.
  - `lanes/<lane>/BRIEF.md`: each lane's brief.
  - `lanes/<lane>/STANDUP.md`: the lane's own standup lines (the lane writes them).
  - `lanes/<lane>/REPORT.md`: the lane's final report.
  - `standups/<HHMM>.md`: the Director's standup notes.
  - `VERDICT.md`: the shift's verdict report.

The method is shared with `/spark` (`.claude/spark/config.md` is the overlay for gates and repo law; both skills obey it).
`/spark` turns ONE idea into a design and a build. `/shift` runs SEVERAL lanes for hours. A lane may be a spark's work
package, a backlog item, a quality track or an experiment.

## Modes

| Invocation | What it does |
|---|---|
| `/shift` | State brief, then handshake, plan, launch now, standups until the land-by time, verdict |
| `/shift night [start] [land-by]` | Same, unattended. Prepare and preflight everything while the owner is still here; arm a one-shot start at `start` (default now) and standups until `land-by` (default 08:00) |
| `/shift standup` | One standup by hand (normally the timer runs it) |
| `/shift verdict` | Write and publish the verdict report now |
| `/shift morning` | Read the verdict with the owner, take the verdicts, record them, clean up, plan the day |
| `/shift status` | State brief only; change nothing |

## 1. State brief: always first, never from memory alone

Run and read:
1. `git fetch -q; git status --short; git log --oneline -12; git rev-list --count main..origin/main`. Foreign WIP is never yours.
2. `docs/shifts/STATE.md` in full (missing: scaffold it from the spark ledger and memory, and say so).
3. `.claude/sessions.json` (live claims), `node devx/bin/tl.mjs trees list` (worktrees, merged, processes, links).
4. `.spark/Spark/Spark.md` (the ledger's `next:` pointers) and the last `sessions/` note.
5. The auto-memory index: veto signals (deferred topics, the owner's standing rules).
6. Machine: free RAM and disk (`powershell -c "Get-CimInstance Win32_OperatingSystem | % { '{0:N1} GB free of {1:N1}' -f ($_.FreePhysicalMemory/1MB), ($_.TotalVisibleMemorySize/1MB) }"`, `df -h /c`), and who else is running Godot
   (`tasklist | grep -ci godot`). Codex reachable: `codex --version` (0.170+ reaches `gpt-6.2-astra`).
7. Is main's gate green before the shift touches it? `node devx/bin/tl.mjs check --tier fast` (the full gate's last result
   if one ran today). A red gate on arrival is inherited, not the lanes' defect: say so in the brief.

Print the **state brief**, at most 15 lines: focus and what changed since the last shift entry; open owner verdicts (most
blocking first); the top candidate lanes; capacity (RAM free, Codex, usage limits hit recently); anything broken.

## 2. Handshake: the owner agrees the scope, the size and the mix

ONE `AskUserQuestion` call, up to 4 questions. Never ask what STATE.md, the repo or memory already answers.
1. **Scope (multiSelect):** 3-4 candidate lanes from STATE.md's `## Now` and backlog, each with its outcome in one line and
   its cost. Recommended first. A deferred topic (memory) is never offered.
2. **Builders:** how many lanes at once and the mix, with the plan's recommendation first (see § Builder planning). The
   options name the numbers: "4 lanes: 2 Opus-directed Astra (code), 1 Opus (Blender), 1 Astra solo (concept)".
3. **Landing:** land and push by `<time>` (recommended for a night), land on main without pushing, or keep on branches for
   the owner's eye.
4. **The owner's checkpoint, or a blocking decision:** what the owner wants to see in the morning to judge (an exe, stills
   board, a video); or one scouted design fork that blocks a lane.

Rules:
- The handshake decides. An answer that reframes ("Other", a doctrine) outranks the options: re-scope and record it.
- A lane whose shape is not yet clear is a `/spark` first: offer to run the spark's design waves now (before the owner
  leaves) and its build as the lane.
- Write `PLAN.md` and the STATE.md shift-log entry (`### <date> <night|day>: plan`) **before** launching. A killed
  session then loses nothing.

## 3. Builder planning: how many, which model, which route

Size by the machine and by what the work is. Measured on this repo (spark `astra-trial`, 18 Nov 2026; memory
`project-astra-trial-results`):

| Work | Route | Why |
|---|---|---|
| Code, tooling, gates, review, bug hunts, kernel/runtime | **Opus-directed Astra**: an Opus lane director writes the brief, runs `codex exec` as the builder, verifies every claim and re-runs the gates | won DX (35 > 30 > 24), the bug hunt (59 > 23 > 14), parkour code |
| Concept art, the game's look judged by eye | **Astra solo** (Codex `image_gen`, its own design); the owner sees its raw output | won the boss concept and parkour by eye; Opus directing Astra HURT the art |
| Blender modelling, 3D asset from a concept | **Opus solo** | won Pip in Blender |
| Animation and feel judged by looking | Opus by default; Fable only when the owner asks or the lane judges a figure/mesh by eye (memory `feedback-night-fillers-model-dispatch`) | |
| Small, surgical fix the Director can verify in minutes | **Opus solo** | a Codex round trip costs more than the fix |

Capacity rules:
- RAM: keep the machine 60-80 % used (38-50 GB of 63); hold a lane when free RAM falls under 10 GB. A Godot-heavy lane
  (full gate, world, tour, export) is about 3-6 GB; count them, not the agents.
- Lanes at once: 2-4 is the normal night (the full gate takes ~25 min per worktree and collides on CPU; `perf` is NOT RUN
  when the machine is busy). More lanes only when most are not Godot-heavy.
- Codex budget: a directed lane spends 600-900 k Astra tokens on a big task; say the total in the plan.
- Usage limits: if a model hit its limit in the last 24 h (memory, the last shift log), plan its lanes so the Director can
  finish them.
- Write sets: lanes whose files could collide do not run at once. Each lane claims its scope in `.claude/sessions.json`
  (`tl arch` fails on overlapping claims). The shared selftest is split per block (`engine/tools/selftest.d/NNN-*.sh`): a
  lane adds its own file, never edits another's.

### Calling Codex (the Opus lane director does this, not the builder brief's reader)
```
codex exec -m gpt-6.2-astra -c model_reasoning_effort=high --dangerously-bypass-approvals-and-sandbox \
  --skip-git-repo-check -C <worktree> "<brief>" < /dev/null > <worktree>/.tl/codex-<round>.log 2>&1
```
- Always `< /dev/null` (it hangs on stdin otherwise). Resume by the session id printed in its log, never `--last`
  (several lanes run at once). Plain `gpt-6.2` is refused on the ChatGPT login.
- Astra over-reads "no git": say "read-only git is fine; do not commit" or it rebuilds the gate git-free.
- OpenAI's cybersecurity filter can stop a bug-hunt run: resume it by id with a reworded brief.
- The Opus director re-runs every gate itself and re-grades every claim. Astra's report is a claim, not a proof.

## 4. Launch

Per lane:
1. `git worktree add .claude/worktrees/<shift>-<lane> -b <shift>-<lane> main` (the Director, not the builder). A lane that
   needs the full gate also gets `npm ci` in its `foreman/` and plain copies of the two `site/marble-run-...` jobs (overlay
   `## Gates`).
2. Claim the scope in `.claude/sessions.json`.
3. Write `lanes/<lane>/BRIEF.md`: the goal and the owner's words verbatim, acceptance criteria (3-6 checkable bullets), the
   file scope, the route (§ 3), the time box, and **`lane-rules.md` from this skill folder pasted verbatim** (standups,
   honesty, laws).
4. Launch the agent in the background (`Agent`, `run_in_background: true`, `model` per § 3) with the brief's path and text.
   For an Opus-directed Astra lane the agent is the Opus director; its brief says it builds through Codex.
5. Record the lane in PLAN.md: worktree, branch, model/route, agent id (for SendMessage), start time.

For a night: preflight before the owner leaves: disk > 20 GB free, sleep off
(`powercfg /change standby-timeout-ac 0`), Codex logged in, every worktree created and its class cache built
(`"$G" --headless --path engine --import`). Then arm the timers (§ 5). Give the owner the start time, the standup cadence
and the land-by time.

## 5. Standups: report-based, on a timer

Arm with `CronCreate` (session-only; the Director's session must stay open all shift):
- a one-shot start at `start` when it is later than now: "/shift launch <shift>" runs § 4 step 4 for every lane;
- a recurring standup every 60-90 min at an off-minute (e.g. `17 */1 * * *`): "/shift standup <shift>";
- a one-shot verdict 45 min before `land-by`: "/shift verdict <shift>".

A standup (by timer or by hand):
1. Read each lane's `STANDUP.md` (its newest lines), any finished agent's notification/report, the machine (RAM, Godot
   count, disk), and the claims.
2. Decide per lane, one line each: **on track**, **blocked** (answer it, or re-scope; never leave a blocked lane idle for
   two standups), **done -> review**, **over time -> cut to a clean point**.
3. **Review and land** every lane that says done: read its diff (`git diff main...<branch>`), re-run its acceptance checks
   yourself, compute the overlap with main, then merge on main and run the overlay's pre-merge gate list on the merged
   tree (the WHOLE list on the first merge of the shift). Red on main means revert the merge, not fix forward at 4 am.
   On a loaded machine, wall-clock checks (hockey `invariants.many_budget`, the kernel suite's 1800 s limit, perf) are
   not evidence either way: A/B them against the pre-merge tree, and run the whole kernel suite and perf alone on the
   quiet machine before the verdict (seen 19 and 20 Nov).
4. **Re-dispatch:** when a lane landed and time remains, give it its next item from PLAN.md or the backlog (SendMessage to
   the same agent keeps its context), within the scope the owner agreed. Do not invent a new direction overnight.
5. Fill idle capacity only with lanes the handshake accepted (memory: idle capacity is waste, but scope is the owner's).
6. Write `standups/<HHMM>.md` (at most 15 lines: lanes, decisions, landings with SHAs, machine) and append one line to the
   STATE.md shift-log entry.

## 6. Verdict report: what the owner reads in the morning

`/shift verdict` (45 min before land-by, or by hand):
1. Final landings, then on main: the full gate, `tl arch --index` (generated docs on main only), the exe if the shift
   touched the game (`bash engine/tools/export.sh --commit <sha>` then `export.sh check`). Push if the handshake said so;
   confirm `git rev-list --count origin/main..main` is 0.
2. Write `VERDICT.md`, one block per lane:
   - **Verdict:** landed (SHA), held (why, branch kept), cut (what is unfinished), failed (what was learned).
   - **Evidence:** the gate lines and counts, the stills/video/exe path; never a lane's word on its own.
   - **For your eye:** exactly what to play or look at, and how (`dist/PLAY-LATEST.cmd`, walk where, press what).
   - **Asks:** owner decisions the lane raised, as a short choice list.
   Plus: the route scoreboard (which model/route did what and whether it held; feeds § 3), cost (Codex tokens, agent count),
   and what the next shift should do.
3. Publish it as an Artifact page (stills inline, one card per lane, the asks as a list to answer in chat); load the
   `artifact-design` skill first. Give the link in the final message.
4. Release the shift's claims in `.claude/sessions.json`; delete the timers (`CronDelete`).

## 7. Morning

`/shift morning`: open VERDICT.md and the page with the owner; the owner plays and answers the asks. Record each verdict in
STATE.md (`## Decisions`, and `## Now`), move accepted follow-ups into the backlog, archive the lane reports (they are
already in the shift folder, tracked). Clean up: `tl trees remove <name> --apply` for every landed or dropped lane
(it unlinks junctions first; a "Filename too long" leftover is removed with Node `fs.rmSync`, after confirming no links
remain). Then plan the day: a `/shift` day or a `/spark`.

## 8. Wrap: every shift, even a short one

1. STATE.md: the shift-log entry (done, evidence SHAs, open), `## Now`, decisions, backlog.
2. Commit your own paths only (`git add <paths>` per file, never `-A`, never stash); the shift folder and STATE.md are
   tracked.
3. Auto-memory: one project memory per shift only if it changes what the next session should know.
4. `## Skill improvement log` below: one dated line per lesson; a lesson seen twice moves into the rules above.
5. End with: what landed, what waits for the owner, what the next shift should do.

## Repo law
- `CLAUDE.md` and `.claude/spark/config.md` (`## Gates`, `## Repo law`) bind every lane.
- Builders never run git that writes; the Director lands. Stage per file. Never stash, never `reset --hard`.
- Never kill a process you did not start; prefer `--headless`.
- Contracts are Director-only. Hockey decisions and win measurement are deferred (memory) until the owner reopens them.
- A stopped run is never a pass; a NOT RUN is not a PASS; fewer completed tests than main is a stopped run.
- The owner's hand and eye are the bar: a lane that changes what the player sees or feels lands with stills or a video
  in VERDICT.md, and is not called "fixed" until it was reproduced as a person meets it.

## Skill improvement log
- 2026-11-18: skill created from the GTAI `/gta` shift design (pof) and this repo's three sparks of 17-18 Nov; the
  route table comes from the astra-trial scores.
- 2026-11-19 (first run, night of 19 Nov): agents cannot write files named REPORT.md (harness refusal): ask lanes for
  REPORT.txt and the full report in the final message; the Director saves it as REPORT.md.
- 2026-11-19: two lanes picked the same selftest block number (360): assign each lane a block range in its brief.
- 2026-11-19: measuring clips and frames reached 775 MB in one lane: lanes keep raw captures under .tl/ and commit only
  sheets, notes and clips of 20 s or less; the Director converts large PNGs to JPG before staging.
- 2026-11-19: hockey invariants.many_budget fails packs whenever lanes load the machine: re-run packs alone and A/B it
  against the pre-merge commit before calling a regression; perf needs `tl perf run --quiet-only --wait 600` after the lanes.
- 2026-11-19: re-dispatching landed lanes from their own "next" lists (SendMessage, fresh worktree from main) kept the
  machine busy all night inside the agreed scope; all lanes finished by 05:10 and the verdict ran early.
- 2026-11-19 (day): a lane's "landable" standup line was missed twice: lanes also send a message when they are landable.
- 2026-11-19 (day): a lane tree cut before another lane's dependent pack landed passed its own gates and broke 11 bots
  on main (reverted): re-cut a lane's tree from main before its last round when merged work uses its API.
- 2026-11-19 (day): starting the verdict's full gate at the last standup, on a quiet machine, let perf run (2/2) and kept
  the verdict inside the land-by time; Astra spend ran 2x the plan because resumed sessions recount their context.
- 2026-11-19 (evening): an operator passing Astra only a measurement (720p glyph heights against a readability floor)
  fixed the HUD in one round without directing the design: measured feedback is the right lever on an Astra-alone lane.
- 2026-11-20 (night, the diorama duel): six arms building the same pillar twice made the shared window lock the
  bottleneck (10-20 min a capture); two Astra rounds fit, a third did not. Plan captures as a queue or give
  pictures-only tours their own lock class.
- 2026-11-20: arms split by file scope merged without a textual conflict, but together broke a global size budget no arm
  could see (tl_style.gd 611/600): the combine runs the fast tier before anything else.
- 2026-11-20: a classic-proof baseline must be the same world as the worktree (same site jobs, `--load=block` tours), or
  its noise floor measures another village.
- 2026-11-20: an Astra operator let round 1 re-run whole suites itself for 2 h; a Director time check ("end the round,
  verify yourself, spend the rest on the look") recovered the arm. Operators verify; Astra builds.
- 2026-11-20 (day): integration gates ran world,packs in the default style only; a cel figure stance under
  `TL_STYLE=crisp` moved example.kit's hash unseen through an integration (cel-astra caught it). When looks live behind a
  style switch, run `world,packs` under every style the shift changes (and classic) before calling hashes held.
- 2026-11-21 (night): `tl assets scan` on a checkout whose engine/.godot class cache predates a merge writes the OLD kit hashes (the scan imports only when no cache exists); a Director "re-scan" overwrote a correct manifest and made every fresh lane tree red. After merging engine code, re-import (`$G --headless --path engine --import`) before any scan or gate in the main checkout; a hash disagreement between a fresh tree and main means main is stale.
- 2026-11-21 (night): the Director's proof-job script lacked `--allow-edit` and both jobs failed in 0 ms; a script that
  starts real work gets one dry start checked within 5 minutes, not at the next standup.
- 2026-11-21: a lane's late rounds pushed a file over the size ratchet only at merge (harden_case.gd 626/600): run the
  fast tier on the merged tree before the slow list, every landing (second sighting after 20 Nov: now a rule of § 5).
- 2026-11-21: the full gate saturates the machine by itself (its own parallel steps, CPU 100 %): its kernel cut, hockey
  many_budget and perf NOT RUN are not evidence even on an otherwise empty machine. The final list's uncapped suite,
  classic packs and `tl perf run --quiet-only` read them alone (377/0, p50 0.921 ms, perf 6/6).
- 2026-11-21: edit tracked JSON by text, never by re-serialising (7.0 became 7 across a whole file); and a critic that
  captures early misses a late twist: proof jobs need the Director's own late captures until the contract films late.
- 2026-11-21 (day): merging a lane while the pre-merge list ran in the main checkout changed files under the running
  gate (twice). Run integration lists in a dedicated worktree at the merged SHA, or hold merges until the list ends.
- 2026-11-21 (day): an agent's backgrounded `cd <tree> && ... &` line left a later relative write in the main checkout
  (twice, it blocked a merge): briefs say "absolute paths only, never cd in a backgrounded line".
- 2026-11-21 (day): Director-chained `foreman quality retry --adapter ...` ran the job in the foreground and queued the
  next command for hours; run Foreman job commands detached, one per line.
- 2026-11-22 (night, extended to 09:00 as a quality loop): lanes in 60-75 min rounds (gap -> build -> window clip -> landable)
  landed 13 duel, 17 editor, 4 hockey and 3 kernel rounds. The first round handed over while the lane kept editing mixed
  two rounds in one tree and could not be split: rule "after a landable message, no edits until landed" from then on.
- 2026-11-22: two proof jobs started in the same second both took the first new site/ folder (a folder diff); proof.sh now
  reads the job id from its own log. And the Director's message times drifted 30 min ahead of `date`: stamp from `date`.
- 2026-11-22: an Opus-directed Astra lane (N1 on the world = alone bug) went silent for 4+ hours with Codex running and
  missed two stops. A lane with no STANDUP line for 60 min gets a status ask at the next standup and a stop at the second.
- 2026-11-22: the uncapped suite at the end caught a test whose fixed sample point a game change had moved a skater into
  (style.frame.rink): a game lane's AI change needs the uncapped suite (or its style.frame blocks) before the verdict.
- 2026-11-22 (day): a lane told "verify the cause first" proved E6 both ways in an hour and found the real mechanism (a
  moved body filed at its next-step transform), where the night's lane chased a symptom (body order) silently for hours:
  for a determinism bug, the brief asks for a two-way probe (make A behave like B, and B like A) before any fix.
- 2026-11-22 (day): with all lanes done by 16:45, starting the verdict's final list then (full gate, uncapped suite,
  quiet perf, export) and cancelling the later timers kept the push inside the land-by time with every wall-clock step
  read alone.
- 2026-11-23 (night, research): a research-only lane that played the owner's earlier game beside ours produced the most
  valuable finding in a week (our metrics scored the slop better than the reference): when the owner calls a game bad, run
  a teardown against a game he accepted before any more tuning, and carry his past rulings into the briefs.
- 2026-11-23 (night): Opus-directed Astra used as a read-only survey (rank every mechanism that could cause the symptom)
  then fixes by hand cost 177 k tokens and fed three rounds: for visual bug hunts, prefer the survey to an Astra build.
- 2026-11-23 (night): a World lane ran only the selftest blocks it touched; the verdict's uncapped suite found that its
  shader fix broke two classic-look byte pins and a blend test that encoded an owner-accepted design. Second sighting
  after 22 Nov (style.frame.rink): any lane that changes engine/style or the draw layer runs the uncapped kernel suite
  before "landable", not only its own blocks.
- 2026-11-25 (night): the Director landed a balance cartridge into a pack after running only the Godot blocks and packs; the editor's C++-verdict fixture pins that cartridge's bytes and went red unseen until the next lane's run. When a landing touches a file another suite pins (cartridges, schemas, fixtures), run every suite that reads it (here foreman `npm test`), not only the lane's own.
- 2026-11-25 (night, editor path): every blocking editor defect (a change wiping the game, the base filling the line
  budget, the design check refusing the base's own key, HUD-off captures misleading the critic) was found by a REAL paid
  job, none by the unit tests, which were green each time. After any change to the job route, run one real job (cheapest:
  reopen a finished job and send one change) before calling the route done; give it a 40-minute stop.
- 2026-11-25: a lane added an optional key to a shared base while another lane's validator listed the base's keys by
  hand; both suites stayed green and only the merged real job failed. A validator of another module's data reads that
  module's declared keys, never a copy.
- 2026-11-25: Godot makes .uid files on import; a tree that imported before landing hides a missing tracked .uid
  (lint_base.gd) that the fast tier then fails on in the main checkout. Run the fast tier in the main checkout after
  the merge, before the slow list.
