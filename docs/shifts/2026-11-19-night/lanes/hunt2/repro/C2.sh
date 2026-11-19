# bash docs/shifts/2026-11-19-night/lanes/hunt2/repro/C2.sh
# run.sh treats even the fixed declaration's expected diagnostic as an incomplete run.
set -u
dir=$(cd "$(dirname "$0")" && pwd)
output=$(bash "$dir/run.sh" C2 2>&1)
rc=$?
if [[ $output == *"C2 declaration rejected"* ]]; then
    errors=$(printf '%s\n' "$output" | grep -E '^(ERROR|SCRIPT ERROR):' || :)
    if [[ "$errors" == "ERROR: ctx.input.declare('aim@x'): '@' is reserved for an aim's record entries" ]] &&
        [[ $(printf '%s\n' "$output" | tail -1) == "REPRO C2: PASS" ]]; then
        echo "REPRO C2: PASS"
        exit 0
    fi
    printf '%s\n' "$output" >&2
    exit 2
fi
printf '%s\n' "$output"
exit "$rc"
