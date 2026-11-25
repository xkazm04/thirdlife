# G1-gate standups (night of 24-25 Nov 2026)

- 07:40 G1: landable G1. world: the trip at hokej's frame 9071 was not a game frame (the tick costs 3.8 ms) but the end of
  the bot's run: the world ran `finish` (the hand bot's `_bot_result` made plain: its whole raw trace, 27k dicts, ~450 ms)
  inside the last tick's 250 ms guard, where the lone runner gives those calls its 10 s setup limit. Fixed in the kernel
  (host/guard.gd, world/pack.gd): the guard calls `finish` as its own call under 10 s. No pack, template or hash change.
  Came in with 89d3b85 (round 5, 23 Nov: raw glue, 9071-frame match, `devices` added to the dump); two-way probe shown.
  kit refs: look_gym moved to engine/tools/skater/look/. Gates green (rink.playtester_seat: CLI not built in a worktree).
  Tree hk-gate, nothing committed.
