# M6 SEAM (27 Nov 2026, lane S6): RESERVED for lane T, whose case it will hold:
# the Rules hand tool: presets, zones in build mode, the rules ghost. The seam made this stub block so the number is taken
# and `selftest.sh home.` already names the case. Until the lane fills it, it runs nothing and says so: the
# verdict's detail reads "stub: no case yet". The lane replaces this whole file with its own case
# (engine/kernel/world/build/LANES.md, M6). Runs on its own too: prints `HOME rules-tool stub ok`.
home_rules_tool_cases=(home.rules-tool.stub)
if ! declare -F verdict >/dev/null; then
  pass=0; fail=0; FILTER=""
  verdict() { if [ -z "$2" ]; then echo "PASS $1${3:+  ($3)}"; pass=$((pass+1)); else echo "FAIL $1: $2"; fail=$((fail+1)); fi; }
  home_rules_tool_alone=1
fi
if [ -z "$FILTER" ] || [[ "${home_rules_tool_cases[*]}" == *"$FILTER"* ]]; then
  verdict "home.rules-tool.stub" "" "stub: no case yet, reserved for lane T (the Rules hand tool: presets, zones in build mode, the rules ghost)"
  [ -n "${home_rules_tool_alone:-}" ] && echo "HOME rules-tool stub ok"
fi
