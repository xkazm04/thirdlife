# Check the kit parts and rigs through the example bot and its measurements.
# needs: example bot reports from 060-examples.sh for the ex.numbers summary.

# ---------------------------------------------------------------- kit and rigs under the kernel (WP4)
# one pack, one bot run; each line below is one claim the bot measured (kernel/examples/ex_kit)
check kit.lint 0 lint "--pack=$EX/ex_kit" -- '"bypasses":\[\]'
check kit.bot 0 bot "--pack=$EX/ex_kit" --frames=3000 -- '"id":"bot.ok","ok":true'
kit_claim() {  # kit_claim <case name> <ERE the kit.bot report must match> <note>
  if [ -n "$FILTER" ] && [[ "$1" != *"$FILTER"* ]] && [[ "kit.bot" != *"$FILTER"* ]]; then return; fi
  local why=""; grep -Eq -- "$2" "$(report_of kit.bot)" 2>/dev/null || why="the kit.bot report lacks /$2/"
  FILTER="" verdict "$1" "$why" "$3"
}
kit_claim kit.ball_on_ice_slides_by_law '"kit_ice_ok":true.*"ice_friction_measured":0\.1[0-9]*,"ice_friction_law":0\.1,' "a TLKit ball on a TLKit ice patch: friction $(number kit.bot ice_friction_measured), law 0.1"
kit_claim kit.wall_and_crate_break '"kit_fracture_ok":true.*"wall_pieces":16,' "barrier_wall into $(number kit.bot wall_pieces) pieces, crate into $(number kit.bot crate_pieces), settled and baked"
kit_claim rig.biped_walks_and_skates '"rig_biped_ok":true.*"walk_speed":2\.[23]' "TLRigs biped: walk $(number kit.bot walk_speed) m/s, leg swing $(number kit.bot leg_swing), skate $(number kit.bot skate_speed) m/s"
kit_claim rig.vehicle_drives '"rig_vehicle_ok":true' "TLRigs vehicle: top $(number kit.bot car_top_speed) m/s, wheel yaw $(number kit.bot steer_wheel_yaw) rad when steering right"
kit_claim standin.fallback_still_works '"standin_fallback_ok":true' "stand-in rigs given by hand: walk $(number kit.bot standin_walk_speed) m/s, car $(number kit.bot standin_car_top_speed) m/s"
check kit.invariants 0 invariants "--pack=$EX/ex_kit" --frames=1200 -- '"id":"invariants.determinism","ok":true' '"id":"invariants.below_ground","ok":true'

if [ -z "$FILTER" ] || [[ "ex.numbers" == *"$FILTER"* ]]; then
  echo "     ex.kit: $(grep -o '"summary":"[^"]*"' "$(report_of kit.bot)" 2>/dev/null | head -1 | cut -d'"' -f4)"
  for ex in slide bounce shuffle wall walker car; do
    echo "     ex.$ex: $(grep -o '"summary":"[^"]*"' "$(report_of ex.$ex.bot)" 2>/dev/null | head -1 | cut -d'"' -f4)"
  done
fi

