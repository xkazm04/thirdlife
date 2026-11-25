# K1 round 1: spike (16:51-17:01)

Question: can godot-cpp be built here for Godot 4.7.2 and a hello-world extension load headless? **Yes.**

- godot-cpp has no 4.7 branch; `master` (7fd5c4bc, 19 Nov 2026) supports api_version 4.3..4.8. Built with
  `custom_api_file=<our extension_api.json>` dumped from the exact console exe `tl doctor` finds
  (Godot v4.7.2.stable.official.ed1daf0bf), so the bindings match our engine byte for byte.
- Toolchain: SCons 4.11.1 (Python 3.12.1), MSVC 2022 Community, `-j12`; cold build of godot-cpp + extension 4 m 53 s.
  (Passing options through `SConscript(..., {dict})` does not reach godot-cpp's options; they go on the scons command line.)
- Hello: `HelloCore : RefCounted` with `step(n)` and `greet()`; `.gdextension` with `compatibility_minimum = "4.7"`;
  `godot --headless --path <proj> --script res://smoke.gd` prints `SMOKE hello from native, frame 3600`, exit 0.
- Not yet shown: the release template build and loading in an exported exe (round 4 acceptance).
- Frames: none this round (no picture exists yet; rule 3 starts when the core drives a figure, lanes K2/K3).
- Spike files are under the worktree's `.tl/` (gitignored); the real build script lands in round 2/4.
