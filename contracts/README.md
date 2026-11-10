# Third Life: Phase 0 contracts (kernelApi 0.1)

Written by the Director on 2026-11-10 before the Phase 0 fan-out. **Builders read these; only the Director edits them.**
If a contract blocks you or is wrong, do not work around it silently: keep going on what is unaffected and put the
question, with your proposed wording, in your final report.

| File | Seam it fixes |
|---|---|
| `PACK.md`, `pack.schema.json` | what a pack is: manifest keys, directories, entry and bot scripts, the fence |
| `RUNNER.md` | how anything outside Godot (the Foreman, a builder, the Director) runs the engine and what JSON comes back |
| `JOB.md` | the Foreman's job log events and states; the construction site will render exactly this log |
| `KIT-RIG-STYLE.md` | what kit parts, rigs and the style layer expose to the kernel and to packs; material ids |

## Ownership (disjoint; never write outside your own scope)

| Work package | Owns | Godot project root |
|---|---|---|
| WP1 kernel + host | `engine/project.godot`, `engine/kernel/**`, `engine/tools/**`, `engine/packs/.gitkeep` | `engine/` |
| WP2 rigs + kit + style | `kitlab/**` (with `kitlab/kits/**`, `kitlab/rigs/**`, `kitlab/style/**` as the deliverable) | `kitlab/` |
| WP3 Foreman | `foreman/**` | none (Node 24, TypeScript) |
| WP4 seed packs (later) | `engine/seeds/**`; moves `kitlab/{kits,rigs,style}` into `engine/` as its first step | `engine/` |

WP2 builds in its own Godot project so two builders never share a `.godot` cache. Its three deliverable directories use
the **same `res://` paths they will have in the engine** (`res://kits/...`, `res://rigs/...`, `res://style/...`), so
moving them into `engine/` changes no path.

## Global rules

- **Class names.** WP1 owns every global `class_name` starting with `TL` except the prefixes `TLKit`, `TLRig`, `TLStyle`
  and `TLMesh`, which are WP2's. Nothing else declares a global class. Pack scripts never use `class_name`.
- **No shared base classes across WP1 and WP2.** The seam is duck-typed: method and property names in
  `KIT-RIG-STYLE.md`. The kernel checks `has_method` and reports a readable error.
- **Absent value = omit the key.** Never `null`, never `0` as "not set". Applies to every JSON file here.
- **Unknown keys are errors** in every schema (manifest, layout, style, job events). A silently ignored key is a defect.
- **Lists, not singletons**, for anything a game might have more than one of.
- **Time is physics frames.** The sim runs at a fixed 60 Hz. Tests, bots, captures and watchdogs count frames, never wall
  clock. A check that depends on wall time is a defect (Phase A found two such flakes under GPU load).
- **Determinism.** Same pack, same seed, same number of frames gives the same `state_hash`. All randomness comes from
  the seeded generator the kernel hands out.
- **Machine.** Windows 11, Git Bash. Godot console exe:
  `C:/Users/kazda/kiro/gtai-spike/tools/godot/Godot_v4.7.2-stable_win64_console.exe` (env `TL_GODOT` overrides).
  Node 24, ffmpeg on PATH. Other sessions run Godot tests and a GPU benchmark on this machine: never kill a process you
  did not start, kill every process you start, open windows at `--position 0,1440`, prefer `--headless`.
- **No git commands at all** (the Director owns the repository). No network except what your brief names.
- **Journal** in `JOURNAL.md` at the top of your scope after every completed step (time from `date`, what, result).
  It is the resume point if a usage limit cuts you off. You cannot write files named like reports; return your report
  as text in your final message.
- **Report what is true.** The Director re-runs everything. Say plainly what failed, what you skipped and what you could
  not verify.
