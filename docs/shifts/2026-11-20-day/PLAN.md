# Day of 20 Nov 2026: plan (crisp cel vs toy diorama, two teams)

**Asked by the owner at 10:20** (verbatim in `COMMON.md`): two builders on evolving crisp cel and two on diorama, each
team one Astra and one Fable, focused on the world (surface, sky, nature) and the character; 10 hours of looping to
show each look's full potential, so the owner can decide between them.

**The Director's calls (from the owner's words; no handshake needed):**
- **A team, not a duel:** in each team Astra owns the frame and the figure, and Fable owns surfaces and nature. This
  follows last night's scoreboard (Astra led the frame; Fable led surfaces) and the owner's pick of Astra's figure.
- **Both teams start from the same code**, so the comparison is about the look:
  - `d20-dio` is `diorama-combined` with Fable's figure reverted and Astra's merged (`d20-base` 37772a6);
  - `d20-cel` is the same plus `style_crisp.json`, a copy of today's style (d966639).
  - Every diorama feature is behind style keys, so the cel team may reuse any of them.
- **Landing:** branches only, for the owner's eye. Nothing lands on main except these shift docs.
- **Rules:** as last night. No pack changes, classic exact, hashes unchanged. GPU up to 2x is acceptable today if the
  picture earns it.

**Briefs:** `COMMON.md` (with the lane rules), `TEAMS.md`. Every arm in a team gets the same text.

| Arm | Worktree / branch | Builder | Selftest block | Agent | Started |
|---|---|---|---|---|---|
| cel-astra | `d20-cel-astra` | Astra via Codex, Opus operator | 600-609 | a517d8ecba9eaf0bd | 10:40 |
| cel-fable | `d20-cel-fable` | Fable 5.2 | 610-619 | af1707fe9e7eb3989 | 10:40 |
| dio-astra | `d20-dio-astra` | Astra via Codex, Opus operator | 620-629 | af57f4c7669360e51 | 10:40 |
| dio-fable | `d20-dio-fable` | Fable 5.2 | 630-639 | a23e518e05a231a0f | 10:40 |

**Integration trees:** `d20-cel` and `d20-dio` (the Director).

**Times:**
- Start 10:40. Standups at :07 every hour.
- Integrations at 13:30, 16:30 and 19:45. Each one:
  1. The Director commits each arm's work and merges the team's two arms.
  2. Gates.
  3. Exports `dist/day/<team>/ThirdLife` with PLAY cmd files, takes the shot set, and merges back into the arms.
- Arms stop hard at 19:45. Verdict about 20:45: one page with both looks side by side, and both exes.

**Base gates (`d20-base`):** fast PASS 10:26; `world,packs,kit` and selftests are running. A defect found there is fixed
on `d20-base` and merged into the arms at the first integration.

**Risks:**
- The window lock serialises captures, with four arms plus the Director.
- Fable usage limits.
- Astra token spend: about 1.5-2.5 M per arm over 10 h.
