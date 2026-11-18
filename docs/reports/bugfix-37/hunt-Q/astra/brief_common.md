# Brief for Astra: bug hunt (read fully before starting)

You work in a git worktree of the Third Life repo (Godot 4.7.2 sandbox). Your cwd is the worktree root.
Read `CLAUDE.md` (root) and `docs/reports/astra-trial/brief/laws.md`: they bind you.

HARD RULES
- Run NO git commands at all (no status/diff/log/show/add). Read files from disk only.
- Do NOT edit any engine code or any file outside `docs/reports/astra-trial/d5/repro/` and your own candidates file named below.
- Godot console exe: `C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe` (call it G). Always `--headless`.
  The project is already imported (`engine/.godot` exists). Verified pattern (works): a script `extends SceneTree` with
  `func _initialize():` ... `quit()`, saved in `docs/reports/astra-trial/d5/repro/`, run from the worktree root as
  `timeout 120 "$G" --headless --path engine --script "$PWD/docs/reports/astra-trial/d5/repro/<name>.gd"`; inside it,
  `load("res://kernel/...")` resolves engine files. Class names (TL*) resolve too. If you need physics frames, use
  `_process`/`_physics_process` on the SceneTree or add nodes to `root` and count frames, then `quit()`.
- Other processes run Godot on this machine. Never kill a process you did not start. Every Godot run you start must end
  (use `timeout 120` in front, and `quit()` in the script). Use `--position 0,1440` if a window is ever needed (avoid windows).
- Time box: you have about 35 minutes. Stop and write up what you have by then.

TASK
Find REAL defects in the files assigned to you below (these were changed today: the walker gained gravity, jump, slides,
acceleration, physics interpolation and a ground-avoiding camera; the figure's gait and moves; the ground's holes, rim bend and
antialiasing). Kinds of defect: wrong behaviour, crashes, leaks (nodes/resources never freed), determinism breaks (wall clock,
unseeded randomness, iteration order of Dictionaries hashed, float paths that differ between runs), edge cases that misbehave
(zero/negative/empty inputs, division by zero, NaN, off-by-one, frame 0, missing keys), contract violations (CLAUDE.md laws,
contracts/*.md, engine/kernel/API.md, the file's own doc comments contradicting its code).
The lanes' own reports are in `docs/reports/walker-feel/` (M.md, M2.md, T.md, T2.md, L.md). Things they explicitly list as left
open / known are NOT findings.

QUALITY BAR (very important): a false report scores NEGATIVE. A finding with no working reproduction scores little.
For each finding you report you MUST have written a reproduction and RUN it, and it must print evidence of the defect
(e.g. a line `REPRO <id>: FAIL expected X got Y`). Prefer a small headless GDScript (`extends SceneTree`) that instantiates the
real class (preload the real .gd by res:// path) and calls the real function with the edge input. A python repro is fine for
.py files. Things you suspect but could not reproduce go in a separate "suspicions" section, clearly labelled.
Do not pad: 2 solid findings beat 8 weak ones. Check that the "defect" is not intended behaviour per the doc comments / lane reports.

OUTPUT
1. Reproductions: `docs/reports/astra-trial/d5/repro/<prefix>_<short_name>.gd` (or .py/.sh), each runnable from the worktree root.
   Put the exact run command as a comment at the top of each file.
2. Candidates file (named below), markdown, one section per finding:
   - title; `file:line` (current line numbers); severity high/medium/low with one-line reason
   - what goes wrong and when (inputs/conditions)
   - exact reproduction command (from worktree root)
   - what it printed (paste the decisive lines verbatim)
   - why this is not intended behaviour (cite the doc comment/contract)
   Then a "Suspicions (not reproduced)" list.
3. Your final message: a short summary listing each finding with file:line and the repro command.
