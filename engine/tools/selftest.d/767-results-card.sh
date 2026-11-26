# M5 (spark world-sandbox, 26 Nov 2026): RESERVED for lane K, whose case it will hold:
# the results card after a dungeon. The seam made this stub block so the number is taken
# and `selftest.sh home.` already names the case. Until the lane fills it, it runs nothing and says so: the
# verdict's detail reads "stub: no case yet". The lane replaces this whole file with its own case
# (engine/kernel/world/build/LANES.md, M5). Runs on its own too: prints `HOME results-card stub ok`.
home_results_card_cases=(home.results-card.stub)
if ! declare -F verdict >/dev/null; then
  pass=0; fail=0; FILTER=""
  verdict() { if [ -z "$2" ]; then echo "PASS $1${3:+  ($3)}"; pass=$((pass+1)); else echo "FAIL $1: $2"; fail=$((fail+1)); fi; }
  home_results_card_alone=1
fi
if [ -z "$FILTER" ] || [[ "${home_results_card_cases[*]}" == *"$FILTER"* ]]; then
  verdict "home.results-card.stub" "" "stub: no case yet, reserved for lane K (the results card after a dungeon)"
  [ -n "${home_results_card_alone:-}" ] && echo "HOME results-card stub ok"
fi
