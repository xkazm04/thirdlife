# K3 shell, round 8: K2's show object around the pawns

- The pack's hit-stop port (scripts/hit_stop.gd) and its puck rule are gone; lane K2's skater_show
  (`ctx.cores.view_script("rink", "skater_show")`) is the one owner: thirdjam's hit-stop picks and holds, and the carrier
  the screen shows with the carried puck on the blade socket. The frame runs in thirdjam's order: bus events, step_sim,
  the pawns, after_pawns, render and tick, then the show's render places the puck.
- The match hash did not move: ab881a00fb9af8ef (state 4685cd21e60096f0). Export check headless PASS.
- Film (r8_*): the puck comes to the blade at the pickup and rides on it; the shot reads as a verb (draw back, release,
  follow-through); numbers on the backs (K7). Still skating: contact (K2 round 4). Faint shadows (the style's sun).
- invariants PASS on a quieter machine (solo p50 3.04 ms; stage p99 3.78 ms of 4); one run under load failed p99 at 4.02.
