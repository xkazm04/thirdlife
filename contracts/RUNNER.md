# Runner contract (kernelApi 0.1): how the engine is run from outside

WP1 implements this. WP3 (the Foreman's Verifier) and every builder call it. It is the only door into the engine.

## Invocation

```
<TL_GODOT> [--headless] --path <TL_ENGINE_DIR> res://kernel/host/host.tscn -- <verb> --pack=<dir> [options] --report=<file.json>
```

- `TL_GODOT`: the Godot console executable. `TL_ENGINE_DIR`: the `engine/` directory (default: `<repository>/engine`).
  Both are environment variables; the Godot default is in `contracts/README.md`.
- `--pack` is an absolute directory or a `res://` path. `--report` is an absolute file path; the runner always writes
  it, on success and on failure, and also prints the same JSON as the **last line** of stdout.
- `engine/tools/tl.sh <verb> ...` is a thin convenience wrapper for humans; the Foreman spawns the executable directly.
- Windows are needed only for `capture`, and the caller passes `--position 0,1440` for it. Everything else runs `--headless`.
- The last stdout line and the report file agree in content (parsed values), not byte for byte.
- A `lint` report carries `level: "V1"` (it covers V0 and V1).

| Verb | Level | Options | What it does |
|---|---|---|---|
| `lint` | V0 + V1 | none | manifest against the schema, directory layout, the fence, size limits; composability figures |
| `smoke` | V2 | `--seed=<int>` (default 1), `--frames=<int>` (default 3600) | loads the pack, runs the frames, fails on any script error or watchdog trip |
| `invariants` | V3 | `--seed`, `--frames` | `smoke` twice with the same seed and compares `state_hash`; plus budgets below |
| `bot` | V4 | `--test=<tests/x.gd>`, `--seed`, `--frames=<max>` (default 36000) | runs one bot to `_bot_done()` or the frame budget |
| `capture` | V5 input | `--cam=<name>`, `--frame=<int>` (default 120), `--out=<file.png>`, `--res=1920x1080` | renders one named view at an exact physics frame |

## Exit codes

`0` passed. `1` ran and a check failed. `2` could not run (bad arguments, pack not found, engine error before the sim).
`3` the watchdog had to stop it (runaway script, error storm, memory). The report says which.
A bot that simply does not finish within `--frames` is exit `1`, outcome `failed`, with `bot.completed` false. *(Amended 2026-11-10.)*

## Report `tl.verify/1`

```json
{
  "schema": "tl.verify/1",
  "verb": "smoke",
  "level": "V2",
  "pack": "seed.paddle",
  "packVersion": "0.1.0",
  "kernelApi": "0.1",
  "ok": true,
  "outcome": "passed",
  "seed": 1,
  "frames": 3600,
  "durationMs": 4210,
  "checks": [ { "id": "smoke.no_script_errors", "ok": true, "detail": "0 errors in 3600 frames" } ],
  "metrics": { "state_hash": "9f2c...", "frame_ms_p50": 0.4, "frame_ms_p99": 1.1, "entities_max": 212, "bodies_max": 40 },
  "errors": [ { "kind": "script_error", "file": "scripts/main.gd", "line": 41, "message": "Invalid call ..." } ]
}
```

- `outcome` is one of `passed`, `failed`, `not_run`, `watchdog`. It always agrees with the exit code.
- `checks[].id` values are stable strings, namespaced by verb: `lint.schema`, `lint.layout`, `lint.fence`,
  `lint.capabilities`, `lint.size`, `smoke.loads`, `smoke.no_script_errors`, `smoke.watchdog`,
  `invariants.determinism`, `invariants.below_ground`, `invariants.frame_budget`, `invariants.entity_budget`,
  `bot.completed`, `bot.ok`, `capture.written`. More may be added; none of these may be renamed.
- `errors[].kind` is one of `schema`, `layout`, `fence`, `capability`, `size`, `script_error`, `watchdog`, `load`,
  `determinism`, `budget`, `bot`, `engine`.
- `lint` adds `"composability": { "gdscript_lines": {"scripts": 0, "gen": 0, "tests": 0}, "kit_parts_added": 0, "bypasses": [] }`.
- `bot` adds `"bot": { "test": "tests/bot_match.gd", "done": true, "frames": 5400, "result": { "ok": true, "summary": "..." } }`.
- `capture` adds `"capture": { "cam": "hero", "frame": 120, "file": "<abs path>", "width": 1920, "height": 1080 }`.
- Absent values are omitted. `errors` and `checks` are always present (possibly empty).

## Amendments of 2026-11-10 (after WP1)

- **Additive fields.** Readers accept unknown `checks[].id` values and unknown keys inside `metrics`. Top-level keys
  are fixed. In use: check `smoke.no_engine_errors`; metrics `tick_ms_max`, `state_hash_b`; the `smoke.*` checks also
  appear inside `invariants`, `bot` and `capture` reports.
- **`capture --test=<tests/x.gd>`** runs that bot while capturing, so the image shows the game being played.
- **Captures use Direct3D 12** (`TL_RENDER_DRIVERS`, default `d3d12`), so every image comes from one backend.
- **Wall-clock exceptions.** Three limits read a clock because nothing else can: a single tick over 250 ms, a setup
  call over 10 s, and the physics p99 budget (judged on the better of two runs). Game logic never does.
- The engine runs pack code in a worker process under a supervisor; the process the caller starts is the supervisor.

## Budgets (V3; defaults, a pack cannot raise them)

Nothing with a physics body below `y = -50`. Physics step p99 at most 8 ms headless. At most 5,000 nodes under
`ctx.root` and at most 600 physics bodies. A single `_pack_tick` or `_bot_tick` taking more than 250 ms trips the
watchdog; so does a script error count above 20.

## Script errors

The runner must detect GDScript runtime and parse errors that Godot only prints. "Zero script errors" means zero, and a
pack that prints an error and carries on fails V2.

## Amendments of 2026-11-10, second round (after WP4 and WP3b)

- **Capture.** The process the caller starts (the supervisor) always runs `--headless`; it opens the capture window
  itself, off the visible desktop. The caller never passes `--position`.
- **`invariants` also replays the pack's first bot twice** with the same seed and compares the two state hashes
  (check id `invariants.bot_deterministic`), in addition to the idle run. A pack with input-dependent
  non-determinism fails V3.
- **Hashes are comparable only within one kernel version.**
- **Wall-clock limits under load.** The frame budget and the tick limit can misfire when other Godot processes load the
  machine. A caller re-runs a verdict whose only failure is clock-based once (see `JOB.md`).

### Added after WP5 (2026-11-10)

- `invariants` takes `--bot-frames=<max>` (default 36000); metrics `bot_state_hash`, `bot_frames`, and
  `bot_state_hash_b` when the two bot runs differ.
- A `smoke.loads` detail may end with `; WARNING: ...` (for example a pack script that never runs because it was
  attached after `add_child`). A warning fails nothing.
