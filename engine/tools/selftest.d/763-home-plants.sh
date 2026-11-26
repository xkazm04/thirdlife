# M5 (spark world-sandbox, 26 Nov 2026): RESERVED for lane L, whose case it will hold:
# plants: meadow, flowers, tall grass. The seam made this stub block so the number is taken
# and `selftest.sh home.` already names the case. Until the lane fills it, it runs nothing and says so: the
# verdict's detail reads "stub: no case yet". The lane replaces this whole file with its own case
# (engine/kernel/world/build/LANES.md, M5). Runs on its own too: prints `HOME plants stub ok`.
home_plants_cases=(home.plants.stub)
if ! declare -F verdict >/dev/null; then
  pass=0; fail=0; FILTER=""
  verdict() { if [ -z "$2" ]; then echo "PASS $1${3:+  ($3)}"; pass=$((pass+1)); else echo "FAIL $1: $2"; fail=$((fail+1)); fi; }
  home_plants_alone=1
fi
if [ -z "$FILTER" ] || [[ "${home_plants_cases[*]}" == *"$FILTER"* ]]; then
  verdict "home.plants.stub" "" "stub: no case yet, reserved for lane L (plants: meadow, flowers, tall grass)"
  [ -n "${home_plants_alone:-}" ] && echo "HOME plants stub ok"
fi
