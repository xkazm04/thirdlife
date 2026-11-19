# Lane hunt2, round 2: report (worktree n19-hunt2b, from 30cfbed; done at 03:20)

All five items are fixed. The director did them himself: each was small enough to do without an Astra round, so no Codex tokens were
spent. Every fix has a repro going from FAIL to PASS and a permanent check, and every check was run against the HEAD (30cfbed) versions
of the changed files, where it prints FAIL. Details per item are in `findings-round2.txt`.

1. **B8**: `tl ladder` no longer counts a run the verifier rejected. A plain loss still counts. Test:
   `devx/test/ladder.test.mjs` (B8).
2. **A1**: blocks 310-340 FAIL every case of a Godot run that stopped. Checks: seven forced-stop cases and one control in block 360.
3. **C9**: `boot check` and `boot probe` exit 2 when their report cannot be written. Checks: two cases and one control in block 360.
4. **B11**: `avoid_margin` and `avoid_min` are metres under a scaled parent. Check: `hunt2.chase_margin_scaled`.
5. **C8**: the three seeds reject unknown tuning keys. Checks: three smoke cases on copies with a nested typo key.

## Gates

| gate | result |
|---|---|
| `check --tier fast` | PASS; devx.test 226/226 (225 + the B8 test) |
| `selftest.sh hunt2.` | 36/36 |
| `gate.` | 7/7 |
| `cam.` (real Godot) | 8/8 |
| `ground.` (real Godot) | 9/9 |
| `rig.bugfix` (real Godot) | 7/7 |
| `runner.` (real Godot) | 3/3 |
| `check --tier full --only seeds,packs,world` | seeds 39/39, world 8/8 (hashes the same as main's); packs 33/34 |
| `check --tier full --only packs` (alone, 03:19) | PASS, 34/34 verb runs |

- The packs 33/34 failure was hockey `invariants.many_budget` (p50 1.091 ms against 1.0) under load. It passed when re-run alone.
- The full kernel.selftest was not run in this worktree. Its count should be 240 + 15 = 255; the blocks were run one by one, as
  listed above.

## Changed files

- `devx/lib/commands/ladder.mjs`, `devx/test/ladder.test.mjs`
- `engine/tools/selftest.d/310-bugfix-cam.sh`, `320-bugfix-world.sh`, `330-bugfix-rig.sh`, `340-bugfix-runner.sh`, `360-hunt2-fixes.sh`
- `engine/boot/boot.gd` (still 600 lines), `engine/boot/probe.gd`
- `engine/kernel/api/tl_chase_cam.gd`, `engine/kernel/API.md` (line 427)
- `engine/seeds/seed_drive/scripts/main.gd`, `seed_paddle/scripts/main.gd`, `seed_wall/scripts/main.gd`

## Behaviour changes

- **`tl ladder`**: a cell fails when any seed's run was rejected by the verifier. The step detail lists the seed and its failed checks,
  or the runner's exit code.
- **Chase camera under a scaled parent**: it keeps metric clearance, so `hunt2.chase_pull_scaled` now reads 4.30 m at scale 2.
- **Seeds**: a tuning key the seed does not read is an error. Builders who add a key must add it to `TUNING_KEYS`; the comment says so.
- **No state hash moved**: the world and packs hashes are identical.

## For the Director

- **Walker scope, not fixed**: `kernel/world/world.gd:655` writes the main `--out` of `check` and ignores a failure to open it. This
  is the other half of C9.
- **Unchanged from round 1**: B2 and B4 (walker lane); C4 and C6 (owner); `place()` frame (API question).
