# Day of 21 Nov 2026: plan (the game quality bar)

**Planned:** with the owner, 10:00-11:00 on 21 Nov, through the spark `game-quality-bar`. There were two waves of
questions and a go-gate. Decisions and rejected options are in `.spark/Spark/ideas/game-quality-bar.md`.
The common brief is `COMMON.md`; each lane has `lanes/<lane>/BRIEF.md`.

**Base:** main `df58f0b`: last night's lanes, plus the JOB.md design room and quality loop, plus the TLHit stub (API 1.12).
The fast gate is green on `df58f0b`.

| Lane | Worktree / branch | Route | Selftest block | Agent | Started |
|---|---|---|---|---|---|
| L1 editor-quality | `n21d-editor` | Opus | foreman tests | (filled at launch) | |
| L2 fight-clips | `n21d-clips` | Opus | 660-669 | | |
| L3 falls | `n21d-falls` + arms `n21d-falls-a/-b/-c` | Opus director, 3 Astra arms | 670-679 | | |
| L4 hockey-mechanics | `n21d-hockey` | Opus-directed Astra | 680-689 | | |
| L5 hockey-crazy | `n21d-crazy` | Opus-directed Astra | 690-699 | | |
| L6 crisp-harden | `n21d-harden` | Opus | 700-709 | | |

**Director's own work:**
- Land L2 early (L4 waits on its clips and `stick_yaw`), then merge main into L4's tree.
- Land L1 as soon as its core is landable, then run the colosseum proof re-run, standard and crazy (`.tl/proof/`, same
  sentence, the new editor), for the side-by-side with last night's.
- Commit each falls arm to its branch for the owner's pick; no arm lands today.

**Landing order:** L2, L1 (the proof starts after it), L6, L4, L5. Run the whole pre-merge list on the first merged tree.
Run `world,packs` under crisp and classic.

**Times:**
- Standups hourly at :17.
- Lanes stop at 18:30.
- Land and push by 19:00.
- The proof jobs finish by about 21:00; the verdict page comes after them.

**Budget:**
- Astra: about 4.2 M tokens (L3: 3 arms × about 0.8 M; L4 and L5: about 0.8 M each).
- Proof: about 35 M Claude tokens, plus revise rounds.

**Risks:**
- Three lanes touch hockey and rigs; the file splits are in COMMON.md.
- Hockey's p50 budget (0.92 of 1.0 ms quiet).
- The machine: 30 GB free at the start; hold a lane under 10 GB.
- `tl_biped.gd` sits at the 600-line cap.
