# Locate divergence in idle and bot replays, down to the frame and state key.
# Check the invariant reports for a pack that exceeds its budgets.

# ---------------------------------------------------------------- V3
check bad.nondeterminism 1 invariants "--pack=$EX/bad_nondeterminism" --frames=300 -- '"id":"invariants.determinism","ok":false' '"kind":"determinism"'
# idle runs agree, bot runs do not: only the bot replay of `invariants` can see it (WP5)
check bad.bot_nondeterminism 1 invariants "--pack=$EX/bad_bot_nondeterminism" --frames=300 -- '"id":"invariants.determinism","ok":true' '"id":"invariants.bot_deterministic","ok":false' '"kind":"determinism","file":"tests/bot.gd"'
# the located re-run (kernel/host/diverge.gd): a determinism failure names the exact frame and the first part that differs
check diverge.late_frame 1 invariants "--pack=$EX/bad_late_nondeterminism" --frames=900 -- '"id":"invariants.determinism","ok":false,"detail":"[^"]*first difference at frame 437[:"]'
check diverge.late_part 1 invariants "--pack=$EX/bad_late_nondeterminism" --frames=900 -- '"id":"invariants.determinism","ok":false,"detail":"[^"]*first difference at frame [0-9]+: body World.Crate'
check diverge.bot_state_key 1 invariants "--pack=$EX/bad_late_nondeterminism" --frames=300 -- '"id":"invariants.determinism","ok":true' '"id":"invariants.bot_deterministic","ok":false,"detail":"[^"]*first difference at frame 200: [^"]*_pack_state.flips'
check diverge.frame_zero 1 invariants "--pack=$EX/bad_nondeterminism" --frames=300 -- '"id":"invariants.determinism","ok":false,"detail":"[^"]*first difference at frame 0: [^"]*body World.'
check bad.budget 1 invariants "--pack=$EX/bad_budget" --frames=600 -- '"id":"invariants.below_ground","ok":false' '"kind":"budget"'

