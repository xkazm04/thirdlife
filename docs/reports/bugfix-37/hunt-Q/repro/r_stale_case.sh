# bash docs/reports/astra-trial/d5/repro/r_stale_case.sh
set -eu
scratch=$(mktemp -d docs/reports/astra-trial/d5/repro/r_selftest_XXXXXX)
trap 'rm -f "$scratch/kit.bot.json"; rmdir "$scratch"' EXIT
export TL_SELFTEST_DIR="$scratch"
case_name=rig.vehicle_drives
clean=0
bash engine/tools/selftest.sh "$case_name" || clean=$?
# A retained claim from an earlier invocation in the configured reports directory.
echo '{"rig_vehicle_ok":true,"car_top_speed":99,"steer_wheel_yaw":0.25}' > "$scratch/kit.bot.json"
stale=0
bash engine/tools/selftest.sh "$case_name" || stale=$?
if [ "$clean" -ne 0 ] && [ "$stale" -eq 0 ]; then
  echo "REPRO stale_case: FAIL identical selected case, empty report directory exit 1, retained result exit 0"
else
  echo "REPRO stale_case: control statuses clean=$clean stale=$stale"
fi
