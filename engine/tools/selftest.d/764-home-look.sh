# M5 (spark world-sandbox, 26 Nov 2026): RESERVED for lane L, whose case it will hold:
# the land look: cosine brush, slope rock, blurred paint. The seam made this stub block so the number is taken
# and `selftest.sh home.` already names the case. Until the lane fills it, it runs nothing and says so: the
# verdict's detail reads "stub: no case yet". The lane replaces this whole file with its own case
# (engine/kernel/world/build/LANES.md, M5). Runs on its own too: prints `HOME look stub ok`.
home_look_cases=(home.look.stub)
if ! declare -F verdict >/dev/null; then
  pass=0; fail=0; FILTER=""
  verdict() { if [ -z "$2" ]; then echo "PASS $1${3:+  ($3)}"; pass=$((pass+1)); else echo "FAIL $1: $2"; fail=$((fail+1)); fi; }
  home_look_alone=1
fi
if [ -z "$FILTER" ] || [[ "${home_look_cases[*]}" == *"$FILTER"* ]]; then
  verdict "home.look.stub" "" "stub: no case yet, reserved for lane L (the land look: cosine brush, slope rock, blurred paint)"
  [ -n "${home_look_alone:-}" ] && echo "HOME look stub ok"
fi
