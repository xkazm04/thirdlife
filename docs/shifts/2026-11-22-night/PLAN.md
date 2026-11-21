# Night of 22 Nov 2026: plan (feel kit, duel reference, hockey playability, editor know-how, the Home)

**Planned with the owner** on 21 Nov at 18:50-19:00 (the day verdict's asks plus one handshake). The research of
19:00 is in `docs/research/`. The common brief is `COMMON.md`; each lane has `lanes/<lane>/BRIEF.md`.

**Base:** main `c7dad86`. It contains:
- the 21 Nov day;
- falls arm A (`aa82c4f`);
- the research files.

**Decisions this plan carries:**
- falls A (landed);
- the colosseum retry after the research (the Director runs it at the end);
- the feel kit;
- `TLBall.set_radius`;
- hockey body-check rate kept;
- hockey playability (puck, speed, AI);
- the duel route: reference pack + card + playbook;
- the builder mix: Opus-directed Astra for code, Opus for design;
- the owner's Astra track: the world builder in use, grind loops shaping the Home in different directions (TWO-WORLDS).

| Lane | Worktree / branch | Route | Selftest | Agent | Started |
|---|---|---|---|---|---|
| N1 feel-kit | `n22-kit` | Opus-directed Astra | 710-719 | | |
| N2 duel-reference | `n22-duel` | Opus | 720-729 | | |
| N3 hockey-play | `n22-hockey` | Opus-directed Astra | 730-739 | | |
| N4 editor-knowhow | `n22-editor` | Opus | foreman | | |
| N5 world-chunks | `n22-chunks` | Opus-directed Astra | 740-749 | | |
| N6 world-directions | `n22-world` + arms `-a/-b/-c` | Opus director, 3 Astra-solo arms | 750-759 | | |

**Landing order:**
1. N1 API early, then N1 full.
2. N4.
3. N2.
4. N3.
5. N5.

N6's arms stay on branches for the owner's pick.

**Merge rules:**
- After N1 lands, merge main into n22-duel and n22-hockey and tell them.
- Run every integration list in a dedicated worktree, never under a running gate in main (the 21 Nov day lesson).

**Director's own work:**
- Re-run the colosseum proof (standard + crazy) once N1, N2 and N4 have landed (target 03:30-04:30).
- The final list on a quiet machine.
- The verdict page.

**Budget:**
- Astra about 4.8 M tokens (N1, N3, N5: about 0.8 M each; N6: 3 x 0.8 M).
- Proof about 35 M Claude tokens.

**Times:**
- Standups hourly at :17.
- Lanes stop at 06:30.
- Verdict 07:15.
- Push by 08:00.
