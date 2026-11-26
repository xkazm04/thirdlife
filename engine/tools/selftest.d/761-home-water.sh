# M5 (spark world-sandbox, 26 Nov 2026): RESERVED for lane W, whose case it will hold:
# water: flood, drain, pour. The seam made this stub block so the number is taken
# and `selftest.sh home.` already names the case. Until the lane fills it, it runs nothing and says so: the
# verdict's detail reads "stub: no case yet". The lane replaces this whole file with its own case
# (engine/kernel/world/build/LANES.md, M5). Runs on its own too: prints `HOME water stub ok`.
home_water_cases=(home.water.stub)
if ! declare -F verdict >/dev/null; then
  pass=0; fail=0; FILTER=""
  verdict() { if [ -z "$2" ]; then echo "PASS $1${3:+  ($3)}"; pass=$((pass+1)); else echo "FAIL $1: $2"; fail=$((fail+1)); fi; }
  home_water_alone=1
fi
if [ -z "$FILTER" ] || [[ "${home_water_cases[*]}" == *"$FILTER"* ]]; then
  verdict "home.water.stub" "" "stub: no case yet, reserved for lane W (water: flood, drain, pour)"
  [ -n "${home_water_alone:-}" ] && echo "HOME water stub ok"
fi
