# M6 SEAM (27 Nov 2026, lane S6): RESERVED for lane P, whose case it will hold:
# the rules in the visit: facade, hidden blocks, launch, teleport, say, the run clock, the finish card, zone looks. The seam made this stub block so the number is taken
# and `selftest.sh home.` already names the case. Until the lane fills it, it runs nothing and says so: the
# verdict's detail reads "stub: no case yet". The lane replaces this whole file with its own case
# (engine/kernel/world/build/LANES.md, M6). Runs on its own too: prints `HOME rules-play stub ok`.
home_rules_play_cases=(home.rules-play.stub)
if ! declare -F verdict >/dev/null; then
  pass=0; fail=0; FILTER=""
  verdict() { if [ -z "$2" ]; then echo "PASS $1${3:+  ($3)}"; pass=$((pass+1)); else echo "FAIL $1: $2"; fail=$((fail+1)); fi; }
  home_rules_play_alone=1
fi
if [ -z "$FILTER" ] || [[ "${home_rules_play_cases[*]}" == *"$FILTER"* ]]; then
  verdict "home.rules-play.stub" "" "stub: no case yet, reserved for lane P (the rules in the visit: facade, hidden blocks, launch, teleport, say, the run clock, the finish card, zone looks)"
  [ -n "${home_rules_play_alone:-}" ] && echo "HOME rules-play stub ok"
fi
